# Tasks — gate-assert-visibility

> Tasks do change `gate-assert-visibility`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (1 commit), rastreável a uma seção do `bugfix.md`, e declara o que toca.
> Conversão-padrão (todas as tasks de arquivo, salvo nota em contrário): cada site bare do catálogo (`bugfix.md` §1) vira `condição || { echo "FAIL [n]: <motivo> (<contexto>)"; exit 1; }`, preservando o `[n]` do cenário já presente no arquivo (`bugfix.md` §2). Nenhum veredito muda para entrada já coberta pela suíte hoje.

## Wave 1 — Red (teste + declaração, sem replay ainda)

- [X] TASK-01 — cria `tests/gate-assert-visibility-gate.sh` (mecânica do `bugfix.md` §5: remove/restaura `tests/fixtures/brownfield/src/billing.ts` via `trap ... EXIT`, roda `tests/w80-suite-gate.sh`, assere presença de `FAIL [2]` na saída) e grava a declaração via `/forge:red record --test-path tests/gate-assert-visibility-gate.sh --test-id "[1]" --command "bash tests/gate-assert-visibility-gate.sh" --failure-pattern 'FAIL \[1\]: w80-suite-gate\.sh saiu' --fix-files tests/w80-suite-gate.sh --reproduces "bugfix.md §1"`. **Não roda `/forge:red replay` aqui** — o motor exige HEAD verde antes de derivar a árvore base, e `tests/w80-suite-gate.sh:25` (um dos `fix_files`) ainda está bare neste ponto; rodar replay agora falharia por "não passa em HEAD", não por observar o Red (ver `bugfix.md` §5, nota de sequenciamento). DoD: teste commitado, `evidence/red/red-evidence.json` existe com `status: pending` e os campos acima (rastreia: `bugfix.md` §5/§5.1; paths: `tests/gate-assert-visibility-gate.sh`, `.forge/specs/active/gate-assert-visibility/evidence/red/red-evidence.json`; depende: —)

## Wave 2 — Conversão por arquivo (20 tasks, independentes entre si, todas dependem só do Red)

- [X] TASK-02 — converte `tests/changelog-merge-gate.sh` (linhas 40, 41, 49 — 3 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/changelog-merge-gate.sh`; depende: TASK-01)
- [X] TASK-03 — converte `tests/check-authz-gate.sh` (linhas 97, 98, 99, 124 — 4 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/check-authz-gate.sh`; depende: TASK-01)
- [X] TASK-04 — converte `tests/gw1-conflict-gate.sh` (linha 38 — 1 site) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/gw1-conflict-gate.sh`; depende: TASK-01)
- [X] TASK-05 — converte `tests/gw2-rules-anchor-gate.sh` (linhas 54, 74 — 2 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/gw2-rules-anchor-gate.sh`; depende: TASK-01)
- [X] TASK-06 — converte `tests/gw3-data-governance-gate.sh` (linhas 28, 29, 45, 58, 71 — 5 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/gw3-data-governance-gate.sh`; depende: TASK-01)
- [X] TASK-07 — converte `tests/w102-capability-packs-gate.sh` (linha 32 — 1 site) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w102-capability-packs-gate.sh`; depende: TASK-01)
- [X] TASK-08 — converte `tests/w13-init-gate.sh` (linhas 28, 29, 30, 31 — 4 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w13-init-gate.sh`; depende: TASK-01)
- [ ] TASK-09 — converte `tests/w14-adapters-gate.sh` (linhas 25, 26, 27, 33, 34, 37, 54, 59, 61, 62, 63 — 11 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w14-adapters-gate.sh`; depende: TASK-01)
- [ ] TASK-10 — converte `tests/w20-spec-gate.sh` (linhas 29, 30, 31 — 3 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w20-spec-gate.sh`; depende: TASK-01)
- [ ] TASK-11 — converte `tests/w21-pipeline-gate.sh` (linha 86 — 1 site) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w21-pipeline-gate.sh`; depende: TASK-01)
- [ ] TASK-12 — converte `tests/w22-close-gate.sh` (linha 78 — 1 site; a 106 já está segura, não tocar) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w22-close-gate.sh`; depende: TASK-01)
- [ ] TASK-13 — converte `tests/w30-schemas-gate.sh` (linha 75 — 1 site) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w30-schemas-gate.sh`; depende: TASK-01)
- [ ] TASK-14 — converte `tests/w32-archive-gate.sh` (linhas 68, 87, 168 — 3 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w32-archive-gate.sh`; depende: TASK-01)
- [ ] TASK-15 — converte `tests/w33-publish-gate.sh` (linha 83 — 1 site) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w33-publish-gate.sh`; depende: TASK-01)
- [ ] TASK-16 — converte `tests/w41-graph-gate.sh` (linha 113 — 1 site) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w41-graph-gate.sh`; depende: TASK-01)
- [ ] TASK-17 — converte `tests/w43-c4-gate.sh` (linhas 27, 55, 80 — 3 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w43-c4-gate.sh`; depende: TASK-01)
- [ ] TASK-18 — converte `tests/w50-story-shard-gate.sh` (linha 239 — 1 site, formato especial: descarta o echo informativo, vira `[ "$task_count" -eq 0 ] || { echo "FAIL [8]: ..."; exit 1; }` seguido do `OK [8]` já existente) (rastreia: `bugfix.md` §2 "Caso especial"; paths: `tests/w50-story-shard-gate.sh`; depende: TASK-01)
- [ ] TASK-19 — converte `tests/w51-waves-progress-gate.sh` (linhas 86, 104, 129 — 3 sites) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w51-waves-progress-gate.sh`; depende: TASK-01)
- [ ] TASK-20 — converte `tests/w80-suite-gate.sh` (linhas 25, 35 — 2 sites) ao idioma A. Este é o arquivo que `TASK-01` declarou em `--fix-files` — depois desta task, `tests/gate-assert-visibility-gate.sh` passa em HEAD, o que destrava o `TASK-22`. **Nota operacional:** entre este commit e o do `TASK-22`, a evidência do Red ainda está `pending` — `pre-push`/CI (`red-evidence.sh ci`) reprovariam um push nessa janela; não empurrar a branch até o `TASK-22` fechar (rastreia: `bugfix.md` §1/§2/§5; paths: `tests/w80-suite-gate.sh`; depende: TASK-01)
- [ ] TASK-21 — converte `tests/w91-stage-contract-gate.sh` (linha 46 — 1 site) ao idioma A (rastreia: `bugfix.md` §1/§2; paths: `tests/w91-stage-contract-gate.sh`; depende: TASK-01)

## Wave 3 — Fechamento

- [ ] TASK-22 — roda `/forge:red replay` sobre a evidência gravada no TASK-01 (agora `tests/w80-suite-gate.sh:25` está convertido pelo TASK-20, então `tests/gate-assert-visibility-gate.sh` passa em HEAD e o motor consegue derivar a árvore pré-correção). DoD: `evidence/red/red-evidence.json` com `status: observed`, confirmando que o teste falhava na base por comportamento (`FAIL [1]: ...`) e passa em HEAD (rastreia: `bugfix.md` §5/§5.1; paths: `.forge/specs/active/gate-assert-visibility/evidence/red/red-evidence.json`; depende: TASK-01, TASK-20)
- [ ] TASK-23 — roda a suíte completa (`tests/run-all.sh`) e confirma: (a) 100% verde, mesmo conjunto de vereditos que a árvore pré-correção para toda entrada já coberta (`bugfix.md` §3); (b) nenhum gate ficou vermelho por regressão de conversão — se algum ficar, investiga caso a caso (regressão da task vs. violação real que o caso b mascarava, `bugfix.md` §5 "Pendência declarada") antes de fechar a task (execução, não edição — não altera o arquivo) (rastreia: `bugfix.md` §3/§5; paths: `tests/run-all.sh`; depende: TASK-02, TASK-03, TASK-04, TASK-05, TASK-06, TASK-07, TASK-08, TASK-09, TASK-10, TASK-11, TASK-12, TASK-13, TASK-14, TASK-15, TASK-16, TASK-17, TASK-18, TASK-19, TASK-20, TASK-21, TASK-22)
- [ ] TASK-24 — registra `tests/w111-liaison-sync-gate.sh:259` (asserção vazia `grep ... && true`, achado incidental fora de escopo) como novo item do ledger durável (`known-bug`, P3) via `ledger-ops.sh add` (rastreia: `bugfix.md` §1/§6; paths: `.forge/ledger/LEDGER.md`, `.forge/ledger/ledger.json`; depende: —)

## Rastreabilidade

| Seção do `bugfix.md` | Tasks |
|---|---|
| §5/§5.1 (Red — teste + declaração) | TASK-01 |
| §1/§2 catálogo de 52 sites (20 arquivos) | TASK-02 … TASK-21 |
| §2 caso especial (`w50-story-shard-gate.sh:239`) | TASK-18 |
| §5/§5.1 (Red — replay/observação, após o fix_files convertido) | TASK-20, TASK-22 |
| §3 (comportamento inalterado) / §5 (guarda de regressão) | TASK-23 |
| §1/§6 (achado incidental `w111-liaison-sync-gate.sh:259`) | TASK-24 |
