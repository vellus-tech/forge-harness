# Tasks — add-ledger-evidence-aging

> Tasks do change `add-ledger-evidence-aging`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (commit de vermelho + commit de implementação), rastreável a um REQ/seção do design, e declara o que toca.
> Cada task declara `Teste (comando)` e `Padrão de falha`: o Red é provado por execução antes do Green.

O gate de teste do change vive num arquivo só, `tests/ledger-evidence-aging-gate.sh` (sem número `wNNN`: o ordinal é decidido na hora do merge, convenção do projeto; o `run-all.sh` descobre qualquer `tests/*-gate.sh`). O gate aceita um grupo de cenários como primeiro argumento (`schema`, `stale`, `verify`, `supersede`, `closed`, `wiring`, `docs`, `mutation`; sem argumento roda todos), de modo que cada task prova o próprio vermelho isoladamente. Cada task acrescenta os cenários do seu grupo ao gate no commit de vermelho, e o código no commit de implementação.

## Wave 1 — Contrato de dados

- [ ] TASK-01 — Schema aditivo: `last_verified`, `evidence` (objeto inline em `items`), `supersedes`, `links.superseded_by`, status `superseded`; esqueleto do gate com fixture hermética, retrato do ledger real e contador de cenários (rastreia: REQ-01, design §2.1, §2.7; paths: `template/.forge/schemas/ledger.schema.json`, `tests/ledger-evidence-aging-gate.sh`; depende: —)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh schema`
  - Padrão de falha: `FAIL \[schema`

## Wave 2 — Portas novas do `ledger-ops.sh`

- [ ] TASK-02 — Módulo `lib/ledger-aging.mjs` (função pura `ageReport` + CLI) e subcomando `stale` com limiar `--days` > `forge.yaml ledger.stale_days` > 30, `--as-of`, `--strict`, inconsistências e recusas rc 2 (rastreia: REQ-05, NFR-02, design §2.4; paths: `template/.forge/scripts/lib/ledger-aging.mjs`, `template/.forge/scripts/ledger-ops.sh`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-01)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh stale`
  - Padrão de falha: `FAIL \[stale`
- [ ] TASK-03 — Subcomando `verify` com validação de conteúdo mínimo por `kind` (file, commit, test, command), `observed` ≥ 20 caracteres, recusa de status encerrado, carimbo de `last_verified`, bloco `CORREÇÃO DE REGISTRO` no veredito `changed`; aviso do `note --kind measurement`; `_validate_enum_field` descendo em `evidence.items` (rastreia: REQ-02, REQ-03, NFR-03, design §2.2; paths: `template/.forge/scripts/ledger-ops.sh`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-02)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh verify`
  - Padrão de falha: `FAIL \[verify`
- [ ] TASK-04 — Supersessão: `add --supersedes` com escrita única das duas entradas, recusas de `add`/`update --status superseded`, trava de saída de `superseded` em `update --status` e `promote`, `resolve` recusando `superseded`, subcomando `show` com cadeia nas duas direções e guarda de ciclo/elo quebrado, sufixos `reverificado`/`substitui` do `list`, `spec-new.sh --from-ledger` sem elo para item `superseded` (rastreia: REQ-04, design §2.3; paths: `template/.forge/scripts/ledger-ops.sh`, `template/.forge/scripts/spec-new.sh`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-03)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh supersede`
  - Padrão de falha: `FAIL \[supersede`

## Wave 3 — Leitores e fiação no ciclo de vida

- [ ] TASK-05 — `superseded` nos conjuntos encerrados inventariados (`ledger-render.mjs`, `note` e `status` do `ledger-ops.sh`) com asserção por sítio no gate; render de `reverificado em` e `↳ substitui` sem mudar a renderização de entradas sem os campos novos (rastreia: REQ-07, REQ-06, design §2.3, §2.5; paths: `template/.forge/scripts/lib/ledger-render.mjs`, `template/.forge/scripts/ledger-ops.sh`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-04)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh closed`
  - Padrão de falha: `FAIL \[closed`
- [ ] TASK-06 — Fiação: sufixo de envelhecimento no `ledger-ops.sh status` e marca ` · sem reverificação há <idade>d` no `list` (ambos com degradação para limiar inválido e sem commit HEAD), e linha advisory no `doctor.sh` delegando a `ledger-ops.sh stale`, sem alterar o código de saída (rastreia: REQ-06, design §2.4; paths: `template/.forge/scripts/ledger-ops.sh`, `template/.forge/scripts/doctor.sh`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-05)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh wiring`
  - Padrão de falha: `FAIL \[wiring`

## Wave 4 — Documentação, provas de mutação e suíte

- [ ] TASK-07 — Configuração e documentação: `ledger.stale_days` em `forge.yaml` e `forge.schema.json`, usage/help do `ledger-ops.sh`, `commands/harness/ledger.md` (verify, show, stale, `--supersedes`, árvore da evidência), regra 7 em `ledger-consultation.md`, instrução de reverificar item marcado em `resume.md`, `npm run build:plugin` para as cópias em `plugin/forge/commands/` (rastreia: REQ-08, design §2.6; paths: `template/.forge/forge.yaml`, `template/.forge/schemas/forge.schema.json`, `template/.forge/scripts/ledger-ops.sh`, `template/.forge/commands/harness/ledger.md`, `template/.forge/commands/harness/resume.md`, `plugin/forge/commands/ledger.md`, `plugin/forge/commands/resume.md`, `template/.forge/rules/conventions/ledger-consultation.md`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-06)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh docs`
  - Padrão de falha: `FAIL \[docs`
- [ ] TASK-08 — Provas de mutação com controle, mutação e recontrole (validação de evidência removida, carimbo de `last_verified` removido, `superseded` fora do `CLOSED` do renderizador contra oráculo fixo), restauração conferida por `cmp`, todas sobre cópias na fixture (rastreia: REQ-09, design §2.7; paths: `tests/ledger-evidence-aging-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh mutation`
  - Padrão de falha: `FAIL \[mutation`
- [ ] TASK-09 — Fechamento: `CHANGELOG.md` (seção não publicada), badge/inventário do `README.md`, gates existentes do ledger verdes, suíte completa `npm test` verde (rastreia: REQ-08, REQ-09, NFR-01; paths: `CHANGELOG.md`, `README.md`; depende: TASK-08)
  - Teste (comando): `bash tests/w200-readme-inventory-gate.sh`
  - Padrão de falha: `FAIL`

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 | TASK-01 |
| REQ-02 | TASK-03 |
| REQ-03 | TASK-03 |
| REQ-04 | TASK-04 |
| REQ-05 | TASK-02 |
| REQ-06 | TASK-05, TASK-06 |
| REQ-07 | TASK-05 |
| REQ-08 | TASK-07, TASK-09 |
| REQ-09 | TASK-01, TASK-08, TASK-09 |
| NFR-01 | TASK-02, TASK-09 |
| NFR-02 | TASK-02 |
| NFR-03 | TASK-03, TASK-04 |
