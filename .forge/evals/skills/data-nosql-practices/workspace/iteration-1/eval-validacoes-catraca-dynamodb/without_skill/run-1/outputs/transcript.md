# Transcript — eval-validacoes-catraca-dynamodb / without_skill / run-1

## Contexto

Tarefa: ajustar `services/validacoes/infra/dynamodb.tf` e os handlers em `services/validacoes/src/handlers`, e escrever `docs/design-validacoes.md`, para a tabela DynamoDB de validações de catraca (homologação, ~40 milhões de itens, entra em produção no próximo sprint). Padrões de acesso em `docs/padroes-de-acesso-validacoes.md`. Backfill em `services/validacoes/scripts` pode ficar como está se estiver ok. Execução sem carregar nenhum skill/agente do repositório (baseline `without_skill`) — só conhecimento próprio do modelo.

## Passos

1. Li `docs/padroes-de-acesso-validacoes.md`: pico de ~12.000 escritas/s (mesma data em todas), leitura dominante é histórico de cartão nos últimos 30 dias (~3.000 req/s), painel do operador consulta `RECEBIDA` não conciliadas por tenant tolerando segundos de atraso, cartão frequente passa de 2.000 validações/ano, multi-tenant por operadora.
2. Li `services/validacoes/infra/dynamodb.tf`: tabela `validacoes-catraca` com hash key `data_validacao` (a data do dia) e range key `validacao_id`, GSI `por-status` com hash key `status`.
3. Li `services/validacoes/src/handlers/registrarValidacao.ts` e `historicoCartao.ts`.
4. Li `services/validacoes/scripts/backfill/reprocessarTarifas.ts`.

## Problemas identificados (com o desenho original)

- **Partição quente na escrita.** `data_validacao` (a data do dia) como hash key significa que todo o pico de ~12.000 escritas/s de um dia inteiro cai numa única partição lógica — anti-padrão clássico de hot partition em DynamoDB.
- **`Scan` na leitura de maior volume.** `historicoCartao` fazia `ScanCommand` + `FilterExpression` sobre a tabela inteira (~40 milhões de itens) a cada requisição, para o fluxo com mais tráfego de leitura (~3.000 req/s). Não escala em custo nem em latência.
- **`ConsistentRead: true` numa Query de GSI.** O DynamoDB não suporta leitura fortemente consistente em Global Secondary Index — essa chamada falharia em runtime (bug de correção, não só de desenho).
- **GSI sem isolamento por tenant.** `por-status` usava `status` como hash key; a consulta de pendentes misturava validações de todas as operadoras, um vazamento de dados entre tenants, além de concentrar a GSI inteira em poucos valores possíveis de `status` (outra partição quente).
- **Escrita redundante sem limite de crescimento.** `registrarValidacao` também fazia `list_append` num item de `cartoes-transporte` para acumular todas as passagens do cartão — cresce sem teto (cartão frequente > 2.000/ano), arrisca o limite de 400 KB por item, e não é atômico com o `Put` principal.

## Decisões de desenho

- Redesenhei a chave primária de `validacoes-catraca` para PK `cartaoId` + SK `"<timestampISO>#<validacaoId>"`: distribui a escrita entre milhões de cartões e transforma a leitura de histórico em Query direta por intervalo, sem `Scan`.
- Troquei a GSI `por-status` por uma GSI esparsa `pendentes-por-tenant` (PK `gsi1_pk` = tenant, SK `gsi1_sk` = `"RECEBIDA#<timestampISO>"`), populada só enquanto o status é `RECEBIDA`; documentei que quem conciliar precisa remover esses atributos.
- Removi `ConsistentRead: true` da consulta de pendentes (GSI não suporta, e o painel tolera atraso de qualquer forma).
- Removi a escrita em `cartoes-transporte` de dentro de `registrarValidacao`; a leitura de histórico passa a vir só de `validacoes-catraca`.
- Deixei retenção/TTL como decisão em aberto (não inventei um prazo) — reservei o atributo `expira_em` no Terraform com `enabled = false`.
- Sinalizei em `docs/design-validacoes.md` que a mudança de hash/range key força destruição e recriação da tabela no Terraform, e que a migração (ou descarte) dos dados de homologação precisa de confirmação de quem opera aquele ambiente.
- Não alterei o backfill: ele usa `Scan` + `LastEvaluatedKey` de forma opaca, sem depender dos nomes de atributos de chave, então segue funcionando com a chave nova.
- Não alterei a tabela `cartoes-transporte` (fora do escopo — pode ter outros atributos de cadastro).

## Entregáveis

- `outputs/services/validacoes/infra/dynamodb.tf`
- `outputs/services/validacoes/src/handlers/registrarValidacao.ts`
- `outputs/services/validacoes/src/handlers/historicoCartao.ts`
- `outputs/docs/design-validacoes.md`

## Observação sobre o processo

Execução isolada, sem consultar `.forge/skills`, `.forge/agents`, `plugin/` nem `.forge/evals` deste repositório — apenas o fixture (`docs/padroes-de-acesso-validacoes.md`, `dynamodb.tf`, handlers, backfill) e conhecimento geral de DynamoDB. Nenhum comando de escrita externa (git commit/push, npm test, gh, etc.) foi executado, conforme instruído.
