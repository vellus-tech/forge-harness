# Verification — red-replay-graft-base

- **Commit sob verificação:** `62eef2a` (branch `develop`)
- **Verificado em:** 2026-08-03
- **Veredito global: PASS.** Suíte completa `npm test` → **PASS=73 FAIL=0 SKIP=0** (260s).

## Tabela item-a-item (bugfix.md)

| Item | Veredito | Evidência |
|---|---|---|
| §1 — ancestry deriva base já corrigida quando teste e fix vêm no mesmo commit | PASS | `w108[1]` reproduz o arranjo (squash + commit posterior de ruído no mesmo `fix_file`) e falhava com "teste já passa na árvore base"; o Red foi observado pelo próprio motor no change (`base_strategy: ancestry`, base `4810189` — o commit do teste em vermelho). |
| §1 — falha de gate shell classificada como `unknown` | PASS | `w108[4]` conferia `classify('FAIL [1] (…)')` e falhava com `unknown`; a mesma execução do replay recusava a evidência pelo item 3. |
| §2 — ancestry não se aplica quando o commit do caso carrega a correção | PASS | `red-replay.mjs:deriveBase` calcula `caseCarriesFix` via `commitTouches` e só tenta ancestry quando falso. `w107[1]` (TDD normal) segue por ancestry — sem regressão. |
| §2 — revert-synthesis reverte a correção, não a última mexida | PASS | `deriveBase` escolhe `caseCommit` para os arquivos que ele toca, com `findFixLastCommit` como fallback. `w107[4]` (squash com revert aplicável) segue verde e continua gravando `revert_patch`. |
| §2 — `test-graft` quando o patch reverso não aplica | PASS | `replay()` troca de worktree ao pegar a exceção do `applyRevert` e segue por `descriptor.fallback`; `graftTest` materializa o `test_path` do `caseCommit` preservando o bit de execução. `w108[1]` fecha com `base_strategy: test-graft`. |
| §2 — `graft_from` registrado | PASS | `w108[2]` confere `base_commit == parent(caseCommit)` e `graft_from == caseCommit`. Campo no schema, no template do artefato, na persistência (`red-evidence-ops.mjs`) e no validador. |
| §2 — falha de gate shell é comportamental | PASS | Assinatura `shell-gate` ancorada (`/^FAIL \[[^\]\n]+\]/m`) em `red-classify.mjs`; `w108[4]` cobre os quatro casos, incluindo os dois que **não** podem casar (prosa com o termo no meio da frase; `SyntaxError` continua build-error). |
| §3 — vereditos de recusa preservados sobre a base enxertada | PASS | `w108[3]`: squash que não corrige nada de fato é recusado por "não reproduz" (item 2) mesmo com o enxerto disponível; status não vira `observed`. |
| §3 — `w107[1]`/`w107[4]` sem regressão | PASS | `bash tests/w107-red-replay-gate.sh` → `PASS w107-red-replay-gate` (20 casos). |
| §3 — tabela de assinaturas do classificador | PASS | `bash tests/w106-red-first-gate.sh` → `PASS w106-red-first-gate` (17 casos). |

## Efeito no caso que motivou o change

`hookspath-respect-custom` (teste e correção no mesmo commit `0510b3f`, revert não aplicável no HEAD)
passou de "teste já passa na árvore base" — afirmação falsa — para **Red observado**:
`base_strategy: test-graft`, `base_commit: 8d17ce2` (pai real do squash), `graft_from: 0510b3f`,
`classification: behavioral`, excerpt `FAIL [1] (hooksPath sobrescrito)`. `validate-spec` daquele
change agora aprova.

## Comandos executados

- `npm test` → PASS=73 FAIL=0 SKIP=0
- `bash tests/w108-red-graft-gate.sh` → PASS (5 casos)
- `bash tests/w107-red-replay-gate.sh` → PASS (sem regressão)
- `bash tests/w106-red-first-gate.sh` → PASS (sem regressão)
- `FORGE_ROOT=$(pwd) bash template/.forge/scripts/red-evidence.sh replay red-replay-graft-base` → Red observado (ancestry, base 4810189)

## Observações (não bloqueantes)

- O `w108[5]` nasceu com verde falso: lia `res.errors` de uma função que devolve um **array**, e
  qualquer entrada passava. Corrigido no mesmo ciclo, com asserção explícita sobre o contrato de
  retorno — o defeito só apareceu porque a correção do validador foi conferida à mão depois.
- A lista de estratégias de base existia duplicada (validador em literal + schema JSON). Virou
  `BASE_STRATEGIES` exportada; o schema segue com a própria cópia, por ser artefato de contrato.
