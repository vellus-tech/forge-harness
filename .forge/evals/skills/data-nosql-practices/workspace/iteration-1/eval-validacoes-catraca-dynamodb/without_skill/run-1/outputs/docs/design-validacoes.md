# Desenho de dados — validações de catraca (DynamoDB)

## Sumário executivo

A tabela `validacoes-catraca`, hoje em homologação, tinha três problemas que a impediriam de sustentar produção: partição quente na escrita (chave primária era a data do dia, concentrando os ~12.000 registros/s de pico numa única partição lógica), leitura de histórico do app do passageiro feita por `Scan` sobre a tabela inteira (a maior fatia do tráfego de leitura, ~3.000 req/s, varrendo ~40 milhões de itens a cada chamada) e uma GSI de status sem isolamento por tenant, além de pedir `ConsistentRead` numa GSI — o que o DynamoDB não suporta e derruba a chamada em runtime. Refiz a chave primária para `cartaoId` (partição) + `timestamp#validacaoId` (ordenação), troquei a GSI de status por um índice esparso por tenant, e removi a escrita redundante e sem limite de crescimento na tabela `cartoes-transporte`. Ficam pendentes duas decisões de produto antes do go-live: retenção/TTL e migração (ou descarte) dos dados de homologação.

## Padrões de acesso considerados

- Escrita de pico ~12.000 validações/s, toda com a data do dia corrente (fonte: `docs/padroes-de-acesso-validacoes.md`).
- Histórico de um cartão nos últimos 30 dias, ordenado por data — maior parte do tráfego de leitura, ~3.000 req/s.
- Painel do operador: validações `RECEBIDA` ainda não conciliadas, por tenant, tolerando alguns segundos de atraso.
- Um cartão frequente passa de 2.000 validações/ano.
- Multi-tenant por operadora.

## Chave primária

- **PK** `cartaoId` — cardinalidade alta (milhões de cartões), então o pico de escrita se distribui entre partições em vez de concentrar num único valor por dia, que era o desenho anterior (`data_validacao` como hash key).
- **SK** `"<timestampISO>#<validacaoId>"` — ordena as validações de um cartão por data e permite Query por intervalo (`sk >= <30 dias atrás>`) para o histórico do app, sem `Scan`. O `validacaoId` no final evita colisão quando duas validações do mesmo cartão caem no mesmo timestamp.

Essa mudança resolve as duas maiores fontes de risco do desenho anterior: hot partition na escrita e `Scan` completo na leitura de maior volume.

## GSI `pendentes-por-tenant`

- **PK** `gsi1_pk` = `tenant`. **SK** `gsi1_sk` = `"RECEBIDA#<timestampISO>"`.
- Índice esparso: o handler só grava `gsi1_pk`/`gsi1_sk` enquanto o status é `RECEBIDA`; ao conciliar, quem fizer essa transição precisa remover (`REMOVE`) os dois atributos para o item sair do índice. Isso mantém a GSI pequena (só os pendentes) em vez de crescer com todo o histórico.
- Isolar por tenant corrige um vazamento de dados entre operadoras que existia na GSI anterior (`status` como hash key misturava validações de todas as operadoras na mesma consulta).
- A leitura é eventualmente consistente (comportamento padrão do DynamoDB para GSI) — compatível com a tolerância "alguns segundos de atraso" descrita para o painel, e evita o erro de runtime que `ConsistentRead: true` causaria numa Query de GSI (não suportado pelo DynamoDB).

## `cartoes-transporte`

O handler `registrarValidacao` fazia um segundo write (`UpdateCommand` com `list_append`) para manter, dentro do item do cartão, uma lista de todas as passagens — usada supostamente para o extrato do app. Removi essa escrita: ela crescia sem limite por cartão (2.000+ validações/ano num cartão frequente, sem teto de retenção), arriscava estourar o limite de 400 KB por item do DynamoDB, e não era atômica com o `Put` principal (falha parcial deixava os dois registros inconsistentes). A leitura de histórico passa a vir direto da Query em `validacoes-catraca` (ver `historicoCartao.ts`), que já cobre o mesmo caso de uso. Não toquei na tabela `cartoes-transporte` em si — ela pode ter outros atributos de cadastro fora do escopo desta mudança.

## Script de backfill

`services/validacoes/scripts/backfill/reprocessarTarifas.ts` faz `Scan` paginado por `Segment`/`TotalSegments` e usa `LastEvaluatedKey` de forma opaca — não referencia nomes de atributos de chave. Continua funcionando sem alteração com a chave nova.

## Decisões em aberto (não resolvidas nesta mudança)

1. **TTL / retenção.** `docs/padroes-de-acesso-validacoes.md` não define por quanto tempo uma validação precisa ficar na tabela "quente". Deixei o atributo `expira_em` reservado no Terraform (bloco `ttl` com `enabled = false`) para não exigir migração de schema quando a decisão vier, mas não inventei um prazo. Precisa de decisão de produto/compliance antes de habilitar.
2. **Migração dos dados de homologação.** A chave primária mudou (`data_validacao`/`validacao_id` → `cartaoId`/`sk`). Terraform não faz alteração de `hash_key`/`range_key` in-place — qualquer `apply` com essa mudança força destruição e recriação da tabela. Como a tabela em homologação ainda não é produção ("entra em produção no próximo sprint"), a recomendação é recriar a tabela do zero para produção, tratando os ~40 milhões de itens de homologação como dado de teste descartável — mas isso precisa de confirmação de quem opera a homologação, para garantir que nenhum outro processo depende desses dados.
3. **Handler de conciliação.** Não existe, no escopo desta mudança, um handler que transicione o status de `RECEBIDA` para conciliado. Quando ele for escrito, precisa incluir a remoção de `gsi1_pk`/`gsi1_sk` do item (ver comentário em `registrarValidacao.ts`), senão a GSI esparsa deixa de ser esparsa.
