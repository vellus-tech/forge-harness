# Tasks — add-migration-review-rule

> Tasks do change `add-migration-review-rule` (issue #241), ordenadas por dependência.
> Convenção do dogfood: a maquinaria executável vive em `template/.forge/`; todo comando de teste roda a partir da raiz do repositório, nunca com `cd template`.

## Wave 1 — Rule nova

- [X] TASK-01 — Criar `template/.forge/rules/data/migration-review.md` com frontmatter, os 13 itens do checklist (REQ-03), seção de exceção (REQ-04) e seção "quem revisa" (REQ-02) (rastreia: REQ-01, REQ-02, REQ-03, REQ-04; paths: `template/.forge/rules/data/migration-review.md`, `tests/migration-review-gate.sh`; depende: —)
  - Teste (comando): `bash template/.forge/scripts/validate-rules.sh && bash tests/migration-review-gate.sh`
  - Padrão de falha: `No such file or directory.*migration-review\.md|FAIL \[1\]|FAIL \[2\]`
  - Setup do teste: criar `tests/migration-review-gate.sh` com `[1]` `[ -f template/.forge/rules/data/migration-review.md ]` (falha: arquivo ausente) e `[2]` asserções de conteúdo por `grep` — presença dos 13 itens (um grep por item, âncora curta e específica: "RLS", "FORCE", "CONCURRENTLY", "DEFAULT PRIVILEGES", "tenant_id", "NOT VALID", "ON DELETE CASCADE", "money-as-cents", "data-classification", "schema-evolution", "down.*recusa\|destruiria dado", "ENABLE ALWAYS", "três casos"), da seção de exceção ("backlog", "item="), de quem revisa ("data-engineer\|data-relational", "clone da head"), e das referências a `schema-evolution.md`/`data-governance.md`/`data-config-sql.md` — porque `based_on: []` faz `validate-rules.mjs` pular a validação de conteúdo da rule, só conferindo frontmatter/existência (REQ-01 precisa do `grep`, não só do validator).

## Wave 2 — Script determinístico `check-migration-review` (modo `range`)

- [X] TASK-02 — Criar `template/.forge/scripts/lib/check-migration-review.mjs`: `range <rev-range>` com as duas formas (`base..head` via `git diff --name-only`; sha único/sem pai via `git diff-tree --root -r --name-only`), filtro por padrões de migration (lista fixa dbmate/EF Core/Flyway/Alembic), leitura da evidência via `git show <head>:migration-review.md` (nunca do disco neste modo), matching de linhas `- [x]`/`- [exception] ... item=N backlog=... [adr=...]`, saída PASS/FAIL (rastreia: REQ-05; paths: `template/.forge/scripts/lib/check-migration-review.mjs`; depende: TASK-01)
  - Teste (comando): `node template/.forge/scripts/lib/check-migration-review.mjs range <rev-range>` (chamado direto, sem wrapper — o wrapper só chega na TASK-03), exercitado por `bash tests/migration-review-gate.sh`
  - Padrão de falha: `Cannot find module.*check-migration-review\.mjs|FAIL \[3\]|FAIL \[4\]|FAIL \[5\]|FAIL \[6\]|FAIL \[7\]|FAIL \[8\]|FAIL \[9\]`
  - Setup do teste: construir um repositório git temporário (`git init`, `user.email`/`user.name`, `commit.gpgsign false`) com commits sintéticos sob `tests/migration-review-gate.sh`, e cobrir: `[3]` `base..head` sem arquivo de migration no diff → `PASS (sem migration)`; `[4]` migration nova sem `migration-review.md` no commit `head` → `FAIL` nomeando o arquivo; `[5]` migration nova com `migration-review.md` (commitado) contendo `- [x] <path>` → `PASS`; `[6]` exceção válida (`item=5 backlog=PROJ-1`, item ≠ 2) → `PASS (exceção ...)`; `[7]` exceção do item 2 sem `adr=` → `FAIL` (evidência inválida); `[8]` `range` com rev-range inexistente → `FAIL (range inválido)`, nunca `PASS`; `[9]` sha único sem pai (commit raiz, via `git diff-tree --root -r --name-only`) com migration → resolve corretamente **mesmo** com uma alteração não commitada e suja na working tree (prova de que não lê o disco); `[9b]` criar/editar `migration-review.md` com `- [x]` só na working tree, sem commitar (não existe no commit `head` sendo avaliado), e confirmar que o gate ainda dá `FAIL` — prova direta do achado do round 2 (evidência vem do blob, nunca do disco, no modo `range`).

## Wave 3 — Script `check-migration-review` modo `--path` + wrapper

- [X] TASK-03 — Adicionar ao `check-migration-review.mjs` o modo `--path <dir>` (walker recursivo próprio, sem reuso de `collect()` por extensão; evidência lida do disco, `<dir>/migration-review.md` ou `--evidence <path>`) e criar o wrapper `template/.forge/scripts/check-migration-review.sh` (bash, resolve `FORGE_ROOT`, delega aos dois modos) (rastreia: REQ-05; paths: mesmo `.mjs`, `template/.forge/scripts/check-migration-review.sh`; depende: TASK-02)
  - Teste (comando): `bash template/.forge/scripts/check-migration-review.sh --path <dir>`, exercitado por `bash tests/migration-review-gate.sh`
  - Padrão de falha: `No such file or directory.*check-migration-review\.sh|FAIL \[10\]|FAIL \[11\]`
  - Setup do teste: antes de criar o wrapper, `[10]` chama `bash template/.forge/scripts/check-migration-review.sh --path <dir>` e falha com "No such file or directory" (arquivo ainda não existe — Red); depois de implementado, `[10]` passa a cobrar `--path` em diretório fixture sem migration → `PASS (sem migration)`, e `[11]` `--path` em diretório fixture com migration e `migration-review.md` local (no disco, sem commit) → `PASS` (aqui, diferente do modo `range`, ler do disco é o comportamento correto — é inspeção ad-hoc, não avaliação de push).

## Wave 4 — Wiring no `pre-push`

- [X] TASK-04 — Adicionar bloco `MIGRATION_REVIEW_CHECK` no `template/.forge/hooks/git/pre-push`, imediatamente após o bloco `AI_CHECK` existente, espelhando o cálculo de `range` por ref (`$INPUT`) e chamando `check-migration-review.sh range "$range"`; bloqueia o push em `FAIL` (rastreia: REQ-05 "Integração no ciclo"; paths: `template/.forge/hooks/git/pre-push`, `tests/migration-review-gate.sh`; depende: TASK-03)
  - Teste (comando): `bash tests/migration-review-gate.sh`
  - Padrão de falha: `FAIL \[12\]|FAIL \[13\]|FAIL \[14\]`
  - Setup do teste: mesmo padrão de `tests/w223-delegacao-arvore-do-hook-gate.sh` (invocação determinística do hook, sem push de rede real), com **três correções sobre a descrição genérica** (achado de round de revisão): (i) a invocação precisa do `cd "$R" &&` antes do `printf ... | bash`, como em `w223` — sem ele o hook rodaria contra o git do runner, não contra `$R`; (ii) **não copiar `.forge/scripts/` inteiro** de `template/.forge/` — isso incluiria `scripts/tests/` e ativaria o bloco `HARNESS_SUITE` do hook (rodaria `run-all.sh` completo dentro do teste) e os demais blocos delegados (`DOCS_LIB`, `RED_LIB`, `AI_CHECK`, `ACKS`), tornando `[13]` não-determinístico; copiar só `check-migration-review.sh` + `lib/check-migration-review.mjs` (e `lib/` mínimo que eles importam) e stubar os irmãos como `w223` faz (`check_docs_reviewed() { return 0; }`-style, uma linha por bloco irmão, ou scripts vazios com `exit 0`); (iii) copiar `.forge/hooks/` só o `pre-push` em si. Com isso: `printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA" "$ZERO" | bash "$R/.forge/hooks/git/pre-push" origin "file://$R"` dentro de `(cd "$R" && ...)` (`$ZERO` = 40 zeros, ref nova — mesma convenção de `w223`). `[12]` sem `migration-review.md` commitado → push recusado, saída cita "migration sem parecer de revisão"; `[13]` com evidência completa commitada → push aceito, determinístico; `[14]` repositório com `.forge/scripts/` **inteiro ausente** (harness não instalado, cenário (a) do REQ-05 — não "script isolado ausente", que é o cenário (b) e bloqueia, igual ao `AI_CHECK` hoje) → push não é afetado por este bloco.

## Wave 5 — Extensão de `check-data-governance.mjs` (REQ-06, independente das Waves 1-4)

- [X] TASK-05 — Adicionar `.sql` a `CODE_EXTS` e `--` ao `SENSITIVE_MARKER_RE` em `template/.forge/scripts/lib/check-data-governance.mjs`; criar fixtures `tests/fixtures/data-governance/sql-sensitive-field-{pass,fail}/` e `tests/fixtures/data-governance/sql-log-pan-fail/` (rastreia: REQ-06; paths: `template/.forge/scripts/lib/check-data-governance.mjs`, `tests/fixtures/data-governance/sql-*`, `tests/gw3-data-governance-gate.sh`; depende: —)
  - Teste (comando): `bash tests/gw3-data-governance-gate.sh`
  - Padrão de falha: `FAIL \[9\].*sql.*CONFLICT esperado|sensitive-field.*sql.*não reprovou`
  - Setup do teste: adicionar ao `tests/gw3-data-governance-gate.sh` o caso `[9]` arquivo `.sql` com `-- forge:sensitive-field="cpf"` sem `data-classification.json` correspondente → `CONFLICT` (falha antes da mudança: `.sql` não está em `CODE_EXTS`, o arquivo nem é examinado, saída `OK` incorreta); com entrada correspondente → `OK`; caso `[10]` `.sql` com PAN em chamada `log.info(...)` na mesma linha → `CONFLICT`; `.sql` sem o padrão (DDL comum, sem marcador nem log) → `OK`, sem falso positivo.

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 | TASK-01 |
| REQ-02 | TASK-01 |
| REQ-03 | TASK-01 |
| REQ-04 | TASK-01, TASK-02 |
| REQ-05 | TASK-02, TASK-03, TASK-04 |
| REQ-06 | TASK-05 |
