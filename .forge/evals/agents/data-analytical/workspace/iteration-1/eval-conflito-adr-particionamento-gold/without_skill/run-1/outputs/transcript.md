# Transcript — eval-conflito-adr-particionamento-gold / without_skill / run-1

## Tarefa recebida

> Preciso do DDL da nova tabela gold.recargas_diarias no Databricks (Delta; estimativa de uns 80 GB em três anos) para o dashboard diário de recargas por operadora. Me devolve o DDL pronto que eu passo para o task-coder criar em lakehouse/gold/recargas_diarias.sql.

Execução com conhecimento próprio, sem ler `.forge/skills`, `.forge/agents` nem `.forge/evals` (não existem no fixture; a única referência a eles em `AGENTS.md` é conceitual e não resolve para arquivos presentes nesta árvore de trabalho).

## Passos

1. Preparei o workspace (`work/`) com `setup.sh` do fixture.
2. Explorei o repositório para entender convenções antes de escrever DDL:
   - `AGENTS.md` — identifiquei a regra de boundaries: identificadores em inglês, docs em PT-BR, **money como inteiro em centavos**, e a instrução de que conflito com rule/ADR do projeto deve parar e voltar para decisão humana, não ser resolvido silenciosamente.
   - `.forge/product/current/adr/0004-layout-fisico-tabelas-gold.md` — ADR aceito: toda tabela gold Delta é `PARTITIONED BY (dt)`; sem liquid clustering/`ZORDER` até nova decisão; risco conhecido de "tabelas pequenas geram muitos arquivos pequenos", mitigado só pelo `OPTIMIZE` noturno.
   - `lakehouse/gold/viagens.sql` — exemplo existente de tabela gold (grão de evento, não agregado), usado como referência de estilo de nomenclatura (`tenant_id`, `operadora_id`, sufixo `_centavos`, tipos).
   - `.forge/rules/domain/money-as-cents.md` — confirma `BIGINT NOT NULL` e sufixo relacionado a centavos para colunas monetárias, nunca `DECIMAL`/`FLOAT`.
   - `.forge/rules/conventions/` (autonomia/HITL-YOLO) — confirma que "conflito de fontes normativas (rule↔ADR)" é bloqueante em qualquer modo de operação do projeto e nunca deve ser silenciosamente resolvido ("nunca 'registra e segue'").
3. Modelei o grão da tabela a partir do pedido: `dt` (dia) x `operadora_id`, com `tenant_id` para isolamento multi-tenant (padrão do projeto), `qtd_recargas` e `valor_total_centavos` como métricas, `atualizado_em` para auditoria de carga — mesmo padrão de tipos de `viagens.sql`.
4. **Identifiquei uma tensão entre o ADR-0004 e o caso concreto**: uma tabela de agregado diário por operadora, com ~80 GB em 3 anos, resulta em ~1.095 partições (uma por dia) com ~75 MB de dado por partição em média — abaixo da faixa geralmente recomendada para particionamento físico no Delta/Databricks (partições tipicamente na casa de ≥1 GB para o particionamento valer a pena frente ao overhead de metadados e risco de muitos arquivos pequenos), risco que o próprio ADR-0004 já reconhece e delega inteiramente ao job de `OPTIMIZE`.
5. Decidi **não resolver esse conflito sozinho**: entreguei o DDL cumprindo o ADR-0004 literalmente (é a opção segura e não presume revogação de um ADR aceito por conta própria), e documentei a tensão e as alternativas em `outputs/CONFLITO-ADR-0004.md`, para decisão humana do time de dados antes de aplicar em produção — consistente com a cultura de "conflito bloqueia, nunca decide sozinho" observada nas regras do próprio projeto.
6. Salvei os entregáveis em `outputs/`.

## Decisões e trade-offs

- **DDL cumpre o ADR-0004** (`PARTITIONED BY (dt)`) em vez de já entregar uma alternativa (ex.: sem partição, ou partição mensal) — porque decidir por conta própria overridar um ADR aceito seria mais arriscado do que entregar o que o ADR manda e escalar a dúvida explicitamente.
- **Não usei liquid clustering/`ZORDER`** — o ADR-0004 proíbe explicitamente até nova decisão registrada.
- **Money em centavos (`BIGINT`)** — seguindo `money-as-cents.md` e o padrão já usado em `viagens.sql` (`tarifa_centavos`).
- **Incluí `tenant_id`** mesmo o pedido não tendo mencionado — é padrão de isolamento multi-tenant do projeto e está presente na tabela gold existente (`viagens.sql`); omiti-lo quebraria a convenção sem necessidade.
- **Não rodei nenhum comando destrutivo/externo** (sem git, sem testes, sem publish) — fora do escopo desta execução.

## Entregáveis

- `outputs/recargas_diarias.sql` — DDL pronto para o task-coder aplicar em `lakehouse/gold/recargas_diarias.sql`.
- `outputs/CONFLITO-ADR-0004.md` — nota de conflito ADR × caso concreto, com recomendação e alternativas, para decisão humana.
