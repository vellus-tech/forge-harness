# Verification — hookspath-respect-custom

Commit: `9982e59` · Verified: 2026-07-09T19:23:15Z · Veredito: **PASS**

Bugfix scale 1. Verificação cética da matriz de comportamento (§2), do que deve
permanecer inalterado (§3) e dos testes de regressão (§5) contra o código real.

## Matriz de comportamento esperado (§2)

| Estado de `core.hooksPath` | Esperado | Status | Evidência |
|---|---|---|---|
| ausente/default | setar `.forge/hooks/git` | PASS | `bin/forge.mjs:132,139-140` (guard `cur===` retorna antes; senão seta+loga); `installer/install.sh:93-95`. Gate [2]. |
| já `.forge/hooks/git` | no-op idempotente, **sem nota** | PASS | `bin/forge.mjs:132` `return` mudo; `installer/install.sh:87-88` `:` no-op. Gate [5] verifica ausência da nota "customizado". |
| customizado (outro valor) | preservar + nota informativa no stdout | PASS | `bin/forge.mjs:133-137` preserva e imprime nota (3 linhas); `installer/install.sh:89-92`. Gate [1] confere valor `.githooks` intacto + `grep -qi customizado`. |

## Comportamento inalterado (§3)

| Item | Status | Evidência |
|---|---|---|
| init novo (sem hooksPath) segue setando `.forge/hooks/git` | PASS | `tests/w13-init-gate.sh` verde ([6] hooksPath+pre-commit ativos); gate w94 [2]. |
| update não regride caminho feliz | PASS | `tests/w63-forge-update-gate.sh` verde; gate w94 [5]. |
| install.sh (sem Node) segue a mesma regra — paridade | PASS | `installer/install.sh:85-99` espelha `wireHooksPath`: guard de repo, no-op para valor correto, preserva+nota para customizado, seta para ausente. Gate w94 [4] exercita o bash real. |
| conteúdo dos hooks não muda | PASS | Diff toca apenas a decisão de setar/não-setar; nenhum arquivo em `.forge/hooks/git/*` alterado. |

## Testes de regressão (§5)

| Caso | Status | Evidência |
|---|---|---|
| repro do bug (repo com `.githooks` → init --force/update → preserva) | PASS | gate w94 [1] (init --force) e [3] (update). |
| caminho feliz preservado | PASS | gate w94 [2] e [5]. |
| nota informativa emitida no stdout | PASS | gate w94 [1] `grep -qi customizado`; [5] confere que a nota **não** aparece no caso idempotente. |

## Paridade bin/forge.mjs ↔ install.sh

Equivalência real, não superficial. Ambos: (a) checam se é repo git via `rev-parse
--git-dir` e, se não, logam e saem; (b) leem `cur` via `config --get core.hooksPath`
tolerando unset; (c) `cur === .forge/hooks/git` → no-op silencioso; (d) `cur` não-vazio
diferente → preservam + imprimem a mesma nota (mesmas 3 frases PT); (e) `cur` vazio →
`config core.hooksPath .forge/hooks/git` + log. Única diferença é idiomática (JS vs bash),
sem divergência de decisão.

## Cobertura de escrita de `core.hooksPath` (item 5 — busca por terceiro writer)

`grep -rn core.hooksPath` (excl. node_modules/.git): os únicos pontos que **escrevem**
`config core.hooksPath` são `bin/forge.mjs:139` e `installer/install.sh:94` — ambos
corrigidos. `wireHooksPath` é o helper único, chamado em init (`:304`) e update (`:437`).
`template/.forge/scripts/` **não** escreve hooksPath (só docs/commands o mencionam em prosa).
Sem terceiro caminho não-corrigido — **nenhum gap**.

## Checks deterministas

- `bash tests/w94-hookspath-preserve-gate.sh` → PASS (5/5)
- `bash tests/w13-init-gate.sh` → OK
- `bash tests/w63-forge-update-gate.sh` → PASS
- `npm test` → **PASS=41 FAIL=0 SKIP=0 (72s)**
- `validate-spec.sh hookspath-respect-custom` → OK
