# Análise de benchmark — skill `data-nosql-practices`

Fonte: `workspace/iteration-1/benchmark.json` (gerado por `scripts.aggregate_benchmark`, 2026-09-28T19:58:57Z). 3 evals × 1 run por configuração (`with_skill` / `without_skill`); `runs_per_configuration: 3` no metadata é nominal — o benchmark.json só contém 1 run por eval/configuração (6 runs no total, não 18). Tokens e tool_calls vêm zerados em todos os runs (métrica não instrumentada nesta agregação); a análise de recursos usa só `time_seconds`.

## Resultado

| Métrica | Com skill | Sem skill | Delta |
|---|---|---|---|
| Pass rate | 67.3% (±7.5pp, min 60% máx 75%) | 19.0% (±20.1pp, min 0% máx 40%) | **+0.48** |
| Tempo | 164.7s (±41.4s) | 128.3s (±56.9s) | +36.3s |

**Veredito: agrega** (delta 0.48 ≥ 0.15). A skill quase quadruplica a taxa de acerto (67% vs 19%) ao custo de ~36s a mais por execução — trade-off favorável dado o domínio (revisão de dados transacionais de dinheiro, onde falso-negativo é caro).

## Asserções não discriminantes

Nenhuma asserção passa 100% em ambas as configurações — as 15 asserções (6+5+4, uma por eval) discriminam em algum grau. As que mais se aproximam de não discriminar:

- **`scan-trocado-por-query-no-handler-e-mantido-no-backfill`** (eval 2): passa em ambas as configurações (com e sem skill) — único caso onde sem skill empata com skill. O agente troca Scan por Query no handler e preserva o Scan do backfill mesmo sem o catálogo, porque o próprio prompt já nomeia os dois arquivos e o padrão é razoavelmente óbvio no código. Não diferencia valor da skill.
- **`item-por-validacao-sem-list-append`** (eval 2): também passa nas duas configurações. Eliminar `list_append` é a correção mais direta pedida no prompt; o catálogo (N-09) não parece necessário para chegar lá.

## Onde o artefato ajudou

- **Recusa a implementar Redis como fonte de verdade (eval 3, `redis-saldo-fonte-de-verdade`)**: com skill, o agente declara CONFLITO citando `data-governance.md`/`data-cache.md` e "Redis nunca é fonte de verdade" explicitamente, devolve a decisão ao orquestrador (3 de 4 asserções passam). Sem skill, o agente entrega exatamente o desenho vetado (chaves `INCRBY`/`LPUSH` como store primário) e nem cita a rule — 0 de 4 passam. É o caso de maior separação: a seção "Escopo" do SKILL.md, que cita textualmente a regra "Redis nunca é fonte de verdade" e a decisão H-01(a), foi decisiva.
- **Rótulo do catálogo (ids N-xx) e arquivo:linha (eval 1)**: com skill o relatório cita a maioria dos ids corretos com localização; sem skill, nenhum id N-xx aparece — o agente descreve os achados em prosa livre, sem se ancorar num catálogo. A asserção `achados-com-id-do-catalogo-e-arquivo-linha` falha nas duas configurações (o with_skill perde 2 de 6 ids, o without_skill perde todos), mas a diferença qualitativa é grande.
- **Distinção "GSI de baixa cardinalidade" / "leitura forte em GSI" (eval 2)**: com skill, o design justifica explicitamente a reprojeção pela concentração de escrita numa partição e evita `ConsistentRead` em GSI e `projection_type = "ALL"`; sem skill, a run mantém um GSI com `ALL` (falha adicional que a skill evita).
- **Escalação em vez de implementação silenciosa**: nas 3 evals, a skill empurra o agente a tratar divergência de rule como bloqueio explícito (CONFLITO, ADR pendente) em vez de seguir e entregar. Esse padrão de comportamento (protocolo passo 2 "Rules do projeto... Divergência relevante vira CONFLITO") aparece consistentemente nos transcripts com skill e está ausente sem ela.

## Onde o artefato atrapalhou ou não foi suficiente

- **Nenhum run passa 100%** mesmo com skill (75%, 67%, 60%) — a skill não é suficiente para cobrir sozinha nenhuma das três evals.
- **Chave de partição sem tenant (eval 2, `chave-de-particao-reprojetada`)**: falha em ambas as configurações. Com e sem skill, o agente reprojeta a partition key para incluir o cartão mas deixa o tenant só no GSI, não na PK. A seção "Escopo"/best-practices do artefato não fixa esse ponto com força suficiente (o texto do SKILL.md não cita explicitamente "tenant na partition key", só o índice composto do lado MongoDB).
- **"Uma linha por regra" incompleta (eval 1, `uma-linha-por-regra-e-runtime-nao-verificado`)**: falha mesmo com skill — o relatório lista a maioria das regras mas omite N-01 (que o próprio `scan.sh` reportou como FOUND) e várias sem ocorrência (N-02, N-03, N-05, N-12, N-14, N-16). O protocolo do SKILL.md (passo 5: "uma linha por regra, inclusive as limpas") é claro na letra, mas o agente não fecha a lista completa do catálogo N-01 a N-23 — sugere que o artefato descreve a exigência sem dar um checklist mecânico dos 23 ids para conferência.
- **Migração de chave em homologação registrada de forma incompleta (eval 2, `troca-de-chave-exige-tabela-nova`)**: falha nas duas configurações — o design reconhece que a troca de chave não é in-place, mas não registra "criar tabela nova e copiar/migrar os itens"; numa run recomenda até tratar os 40M itens de homologação como descartáveis, o oposto do esperado.
- **P-S-S omitido (eval 3)**: mesmo com skill, a topologia P-S-S (que a "Escopo" do SKILL.md cita: "topologia P-S-S (N-07)") não aparece no texto gravado, apesar da regra do MongoDB como store durável estar correta. A citação da topologia está enterrada numa frase densa do parágrafo de Escopo, competindo com write concern e transação — pode não estar salientando o suficiente para o agente reproduzir.

## Trechos do artefato ignorados, ambíguos ou contraditórios

- **"Uma linha por regra, inclusive as limpas" (Protocolo, passo 5)** é instrução textualmente clara, mas nenhum run com skill cumpriu integralmente — sugere que falta um mecanismo de verificação (ex.: apontar para a lista completa de ids do catálogo, ou exigir que o agente rode um "checklist" dos 23 N-xx antes de fechar o relatório) em vez de só instruir em prosa.
- **P-S-S citado só uma vez, dentro de uma frase longa** ("Escopo": "...write concern `majority` e topologia P-S-S (N-07), salvo ADR..."): a run com skill do eval 3 pegou write concern e transação mas perdeu a topologia — indício de que informação colocada em subcláusula de uma frase mais longa tem menor taxa de retenção do que a que abre um item numerado do Protocolo.
- **Tenant na partition key do DynamoDB não é mencionado no SKILL.md nem no Escopo** — o artefato fala de tenant só no contexto do MongoDB (rule `data-transactional-nosql.md`, "campo tenant, filtro obrigatório de tenant"). Para DynamoDB (chave-valor persistente), o SKILL.md não replica a mesma exigência de tenant-first na partition key; isso é consistente com a falha idêntica nas duas configurações (a skill não tinha como ajudar aqui, porque não cobre o ponto).
- Nenhuma contradição interna encontrada no SKILL.md nos trechos lidos.

## Melhorias concretas, priorizadas

1. **Adicionar exigência explícita de tenant na partition key do DynamoDB**, análoga à do MongoDB, em `references/best-practices.md` (ou no próprio "Escopo" do SKILL.md) — cobre a falha idêntica nas duas configurações do eval 2 (`chave-de-particao-reprojetada`) e é a lacuna mais acionável, porque hoje o artefato simplesmente não fala nisso.
2. **Transformar "uma linha por regra" num checklist mecânico**: listar os 23 ids (N-01 a N-23) num bloco fixo (tabela ou lista) no Protocolo ou em `references/antipatterns.md`, com instrução de preencher status para cada um antes de fechar o relatório — reduz a chance de omitir ids que o próprio `scan.sh` já reportou (caso do eval 1, N-01 ignorado apesar de FOUND).
3. **Separar a topologia P-S-S em item próprio do Protocolo ou do Escopo**, fora da frase longa sobre write concern/transação — informação em subcláusula tem menor recall observado; um item dedicado ("MongoDB do transacional de negócio roda em P-S-S — citar sempre que indicar o store") teria mais chance de sobreviver à produção do relatório.
4. **Explicitar no Protocolo (ou em antipatterns.md) o registro de migração de chave em produção/homologação**: "toda troca de partition key implica tabela nova + cópia/migração dos itens existentes, nunca alteração in-place" — hoje isso fica implícito e as duas configurações do eval 2 (`troca-de-chave-exige-tabela-nova`) falham, inclusive sugerindo descartar dados de homologação.
5. **Achatar a densidade de ids na frase de citação de rule** (ex. "Redis nunca é fonte de verdade") em uma frase autônoma e citável — já funciona bem (eval 3 passa 3/4 com skill), mas vale reforçar como modelo para os outros dois pontos acima, já que é o padrão que melhor sobreviveu à produção do relatório final.

Nenhuma melhoria proposta requer reescrever a estrutura do artefato — são reforços pontuais em `references/best-practices.md`/`antipatterns.md` e ajuste de ênfase textual no `SKILL.md`.
