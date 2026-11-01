# Proposal — add-migration-review-rule

> Change `add-migration-review-rule` (type: `feature`, scale 2) — criado em 2026-10-31 por milton.

## 1. Por quê (problema / motivação)

Issue #241. O template traz `rules/data/schema-evolution.md` (como escrever uma migration segura, expand/migrate/contract) mas nenhuma regra exige que uma migration seja revisada por alguém com olhar de dados antes do merge. Num projeto adotante (fintech regulada, multi-tenant, PostgreSQL com dbmate e EF Core), a primeira revisão especializada de dados achou 30 problemas, 5 bloqueantes, que já tinham passado pela revisão geral de código: tabela multi-tenant sem RLS; tabela do ambiente de dados de cartão (CDE) sem RLS; privilégio DML amplo por default privilege; índice único global em CPF/CNPJ/e-mail vazando existência de cadastro entre tenants; expurgo de dado sensível num `DO $$` sob timeout que nunca termina em tabela grande. A revisão geral de código não confere dono de tabela, default privilege, lock de índice nem retomada de backfill — é um olhar que falta.

## 2. O que muda

Uma rule nova, `rules/data/migration-review.md` (`based_on: []`), que:

1. Exige revisão especializada de dados (agente `data-engineer` ou `data-relational`) antes do merge de todo PR que toque migration, sobre um clone da head do PR, além da revisão de código.
2. Traz o checklist de 13 itens objetivos da issue (cabeçalho de fase/timeout, RLS ENABLE+FORCE, sem política PUBLIC, privilégio mínimo por tabela, chave única prefixada por tenant, índice CONCURRENTLY em arquivo próprio, sem FK entre donos/sem CASCADE em dado financeiro, dinheiro em centavos, coluna sensível classificada no mesmo PR, backfill idempotente com retomada, contract só após expand promovido, tabela append-only com trigger ENABLE ALWAYS, suíte de integração provando 3 casos de RLS).
3. Permite exceção a um item só por registro explícito no arquivo de evidência (`migration-review.md`, REQ-05), com o item de backlog associado que a resolve (e, para o item 2/RLS, o ADR ou registro formal exigido por `data-config-sql.md`).
4. Um script determinístico, `check-migration-review.sh`, que detecta se o PR (diff contra a base) toca arquivo de migration e, nesse caso, exige evidência de parecer anexado — ver decisão 2 abaixo.

## 3. O que NÃO muda (fora de escopo)

- `schema-evolution.md` não é reescrita; a rule nova complementa (exige revisão), não substitui o "como migrar" (expand/migrate/contract) já normado ali. Itens 8 (dinheiro) e 10 (backfill/expurgo) do checklist **referenciam** `money-as-cents.md`/`schema-evolution.md`, não repetem a norma.
- `data-config-sql.md` não é reescrita; ela já exige RLS obrigatório com exceção só por ADR/registro formal — a rule nova herda esse mecanismo para o item 2 do checklist (não cria um segundo caminho de exceção mais leve para RLS; os outros 12 itens usam o mecanismo próprio da rule nova, mais leve).
- Checklist equivalente para NoSQL (MongoDB) ou outros bancos relacionais (SQL Server, MySQL) não é desta entrega — **decisão 1**: o checklist dos 13 itens é PostgreSQL-específico (RLS, `lock_timeout`, `CONCURRENTLY`, `DEFAULT PRIVILEGES` são sintaxe/semântica de PostgreSQL). Uma versão NoSQL exigiria itens próprios (ex.: filtro de tenant obrigatório no repositório, write concern, chave de partição) e fica registrada como item de ledger, não bloqueia esta entrega.
- A issue cita `rules/data/migrations.md` como rule existente; esse arquivo não existe no template (existe `schema-evolution.md`) — imprecisão da issue, registrada para não propagar a referência errada.

## 4. Impacto

- **Capacidades afetadas:** nenhuma capacidade de produto; afeta a maquinaria do próprio template (`template/.forge/rules/data/`, `template/.forge/scripts/`).
- **Paths afetados:** `template/.forge/rules/data/migration-review.md` (novo), `template/.forge/scripts/check-migration-review.sh` (novo), `template/.forge/scripts/lib/check-migration-review.mjs` (novo), `template/.forge/scripts/lib/check-data-governance.mjs` (editado, REQ-06), `template/.forge/hooks/git/pre-push` (editado — bloco novo de wiring, modelado no bloco `no-ai-attribution` existente; ver design §2.4), testes correspondentes (`tests/migration-review-gate.sh` + fixtures; extensão de `tests/gw3-data-governance-gate.sh`).
- **Dependências:** nenhuma spec ativa; depende de `rules/data/schema-evolution.md`, `rules/data/data-governance.md` e do agente `data-engineer`/`data-relational` já existentes (não são modificados).
- **Riscos:**
  - Falso negativo do detector de migration (padrão de path de migration varia por stack) — mitigado por lista de padrões default cobrindo dbmate/EF Core/Flyway/Alembic + lista configurável via `FORGE.md`, e pela regra textual continuar valendo como norma mesmo sem o gate declarado.
  - Gate mecânico sem rede (`gh`/API) para ler o corpo do PR — resolvido com fonte única de evidência em arquivo committed (`migration-review.md`), não no corpo do PR; ver REQ-05.
  - Extensão de `check-data-governance.sh` para `.sql` (decisão 3 revisada) é aditiva sobre `CODE_EXTS`/`SENSITIVE_MARKER_RE` já existentes — risco de regressão mitigado por manter a suíte `tests/gw3-data-governance-gate.sh` verde sem alteração (REQ-06).

## 5. Decisões abertas da issue — decididas nesta entrega

1. **Escopo PostgreSQL-only:** confirmado. NoSQL/outros bancos ficam fora de escopo; registrar item de ledger para checklist equivalente de NoSQL quando houver demanda real de um projeto adotante.
2. **Gate mecânico vs. norma:** **decidido por MECÂNICO**, com fallback de norma. Justificativa: o harness já trata "escape hatch operado por script, nunca por memória do agente" como princípio estabelecido (ver histórico de dívida deste projeto); um gate só-norma depende do orquestrador lembrar de aplicá-lo em todo PR, o que é exatamente o modo de falha que a issue descreve (a revisão geral de código já existe e não pegou os 5 bloqueantes). O script (`check-migration-review.sh`) é deliberadamente simples e determinístico: detecta arquivo de migration no diff (por convenção de path, configurável) e falha se não houver, no arquivo de evidência committed `migration-review.md` (REQ-05), a linha de revisão ou de exceção (com backlog) para aquele arquivo. Ele não lê o corpo do PR (sem rede/`gh`, NFR-01) e não analisa o SQL em si — isso é trabalho do especialista humano/agente, não do script.
3. **Ligar a `data-classification.json` e estender `check-data-governance.sh` para ler código:** **decidido por FAZER, em escopo mínimo** (revisão desta decisão após inspecionar `check-data-governance.mjs`: o verificador já foi estendido para ler `.go/.kt/.ts/.rego/.py`, não só `.md` — a premissa "só lê .md" da issue está desatualizada). Adicionar `.sql` a `CODE_EXTS` e aceitar comentário `--` no marcador `forge:sensitive-field` é uma extensão pequena e aditiva sobre uma estrutura já existente (REQ-06), não um parser de SQL novo — por isso cabe nesta entrega sem o risco que motivou a recusa original (não há parsing de DDL, só o mesmo grep de marcador de comentário usado nas outras linguagens). O item 9 do checklist referencia essa extensão e `data-classification.json` como autoridade.

## 6. Próximos passos

`/forge:requirements` → `/forge:design` → `/forge:tasks` → `/forge:implement` → `/forge:verify` → `/forge:archive`, com gate HITL em cada fase (requirements_reviewed, design_reviewed, tasks_reviewed, implementation_verified, human_archive_approval).
