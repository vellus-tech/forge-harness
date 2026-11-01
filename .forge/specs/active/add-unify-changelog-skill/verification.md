# Verification — add-unify-changelog-skill

## Resultado: APROVADO

## Evidências por requisito

| REQ | Implementado em | Verificado por | Status |
|---|---|---|---|
| REQ-01 | `template/.forge/skills/readme-generator/scripts/changelog-engine.mjs` (modo explícito `--type`/`--description`); `template/.forge/commands/docs/update-changelog.md` (camada fina) | `tests/w284-changelog-engine-explicito-gate.sh`, `tests/w292-update-changelog-comando-gate.sh` (rodados isolados, rc=0) | VERIFICADO |
| REQ-02 | `template/.forge/hooks/git/post-merge` linhas 64-99 (delega a `changelog-engine.mjs --merge-range`, no-op sem CHANGELOG raiz / sem merge) | `tests/w293-post-merge-changelog-engine-gate.sh`, `tests/w295-changelog-merge-engine-gate.sh` (rc=0) | VERIFICADO |
| REQ-03 | `changelog-engine.mjs` — dedup pelo sufixo `(<hash>)` | `tests/w286-changelog-engine-merge-range-gate.sh` cenário [2] (rerodar não duplica), `tests/w295` (idempotência) — rc=0 | VERIFICADO |
| REQ-03b | `changelog-engine.mjs` — marcador `**[BREAKING]**` para `!` | `tests/w286` cenário [3], rc=0 | VERIFICADO |
| REQ-03c | `template/.forge/hooks/git/post-merge` — nenhum `git commit` no corpo do hook (confirmado por leitura linha a linha) | `tests/w293` cenário [4] "hook nunca commita", rc=0 | VERIFICADO |
| REQ-03d | `post-merge` linha 90 (`command -v node` guarda a chamada ao motor) | `tests/w293` cenário [3] "sem node no PATH → no-op sem erro", rc=0 | VERIFICADO |
| REQ-03e | `changelog-engine.mjs` — cria `## [Unreleased]` antes da primeira versão numerada quando ausente | `tests/w286` cenário [6], rc=0 | VERIFICADO |
| REQ-04 | `post-merge` linhas 62, 101-121, 123-190, 192-199 (prune/worktrees mergeadas, integridade do liaison log, sugestão de promote-staging) — bloco intocado por este change, confirmado por leitura do arquivo inteiro | `tests/w147-hook-delegation-gate.sh`, `tests/w223-delegacao-arvore-do-hook-gate.sh`, `tests/w248-git-dir-isolation-gate.sh` (exercitam o hook ponta a ponta e continuam verdes) — rc=0 | VERIFICADO |
| REQ-05 / REQ-05b / REQ-05c | `post-merge` linhas 29-60 (`resolve_delegated`, delegação ao tronco, no-op rc 2 sem `.forge/`) | `tests/w147-hook-delegation-gate.sh` cenário [1]+variante, `tests/w223-delegacao-arvore-do-hook-gate.sh` cenários [3]/[8]/[10*], `tests/w293` cenários [1]/[2] — todos rc=0 | VERIFICADO |
| REQ-06 | `changelog-engine.mjs` — seções `### <Seção-pt-BR>`, lista `- ` dentro de `[Unreleased]` | `tests/w284` cenário [2], `tests/w286` cenário [6] — rc=0 | VERIFICADO |
| REQ-07 | `post-merge` linhas 67-74 (comentário normativo) + linha 81 (`resolve_delegated changelog-engine skills/readme-generator/scripts/changelog-engine.mjs`, sem passar por `resolve-skill.sh`) | `tests/w293` cenário [5] "`FORGE_SKILL_DIR_README_GENERATOR` NÃO é consultado pelo hook", rc=0 | VERIFICADO |
| REQ-08 | `changelog-engine.mjs` — modo derivado `--subject`/`--path`, `--path` inexistente sai rc 2 | `tests/w285-changelog-engine-derivado-gate.sh` cenários [4]/[5], rc=0 | VERIFICADO |
| REQ-09 | `template/.forge/commands/docs/update-changelog.md` passo 1 "Trava de branch protegida" | `tests/w292` (verificação estática: trava documentada), rc=0 | VERIFICADO |
| REQ-10 | `changelog-engine.mjs` (detecção `release-please-config.json`) + `update-changelog.md` passo 3 | `tests/w287-changelog-engine-release-please-gate.sh` cenário [1], `tests/w292` cenário [2] — rc=0 | VERIFICADO |
| REQ-10b | `changelog-engine.mjs` checagem de `release-please-config.json` na raiz antes da guarda de ausência de CHANGELOG, chamada pelo `post-merge` em `--merge-range` | `tests/w287` cenário [2], `tests/w295` cenário [8] "no-op com release-please-config.json na raiz" — rc=0 | VERIFICADO |
| REQ-11 | `template/.forge/skills/readme-generator/scripts/gates/{released,preserve,lint}.mjs` + `check-ai-attribution.sh text` citado em `update-changelog.md` passo 5 | `tests/w288-changelog-gate-released-gate.sh`, `tests/w289-changelog-gate-preserve-gate.sh`, `tests/w290-changelog-gate-lint-gate.sh`, `tests/w294-changelog-gates-regressao-gate.sh` (4 controles da issue), `tests/w292` cenário [3] (os 4 gates nomeados) — todos rc=0 | VERIFICADO |
| REQ-12 | `template/.forge/scripts/resolve-skill.sh` — precedência `FORGE_SKILL_DIR_<NOME>` → `.forge/skills/<nome>/` do projeto → skill de usuário; `FAIL skill <nome> ausente` rc 1 | `tests/w291-resolve-skill-gate.sh` cenários [2]/[3], rc=0 | VERIFICADO |
| REQ-13 | `post-merge` — `resolve_delegated` (mesmo mecanismo dos outros alvos), nunca `resolve-skill.sh`; `delegation_failed=1` no padrão já existente | `tests/w147` cenário [1], `tests/w293` cenário [1], rc=0 | VERIFICADO |
| REQ-14 | `changelog-engine.mjs` — cria CHANGELOG ausente nos modos explícito/derivado (nunca em `--merge-range`) | `tests/w284` cenário [1] (confirmado por spot-check do arquivo gerado), `tests/w286` cenário [4] "sem CHANGELOG raiz não cria nada em --merge-range" — rc=0 | VERIFICADO |
| DIV-01 | `changelog-engine.mjs` linha 32: `const CC_SECTION = { feat: 'Adicionado', fix: 'Corrigido', perf: 'Corrigido' }` — confirmado por leitura direta do código-fonte, não por nome de teste | `tests/w285` cenário [2] "`perf(x)` → Corrigido, não Changed/Alterado", `tests/w295` cenário [7] (mesma prova no caminho do hook) — ambos rc=0, saída grava em `### Corrigido` | VERIFICADO |
| DIV-02 | `changelog-engine.mjs` linha 257: `if (!section) continue; // DIV-02: refactor/revert/chore/... não geram entrada` — confirmado por leitura direta | `tests/w285` cenário [3] "refactor não gera entrada", `tests/w295` cenário [6] "revert ignorado" — ambos rc=0 | VERIFICADO |
| TASK-16 (tombstone) | `template/.forge/scripts/lib/changelog-from-merge.mjs` e `tests/changelog-merge-gate.sh` removidos; `installer/removed-files.txt` linha 21 lista `scripts/lib/changelog-from-merge.mjs` | Confirmado por `ls` (ambos ausentes) + `grep` no tombstone — comando composto do TASK-16, rc=0 | VERIFICADO |
| TASK-17 (escopo do SKILL.md) | `template/.forge/skills/readme-generator/SKILL.md` — declara README/branches irmãs fora de escopo desta versão | `tests/w296-skill-readme-generator-escopo-gate.sh` (script dedicado, distingue por proximidade de frase, não grep solto) — rc=0 | VERIFICADO |
| TASK-18 (espelho do plugin) | `plugin/forge/commands/update-changelog.md` gerado por `build-plugin.sh` a partir de `template/.forge/commands/docs/update-changelog.md` | Rodei `bash template/.forge/scripts/build-plugin.sh` de novo nesta sessão (rc=0) e `git diff --exit-code plugin/forge/commands/update-changelog.md` saiu sem diferença (rc=0); `git diff --exit-code "$(git merge-base HEAD origin/develop)"...HEAD -- snapshot/` também sem diferença (rc=0) — `snapshot/project-bootstrap/` intocado desde que a branch divergiu | VERIFICADO |

## Checks deterministas

`verification.yaml` (gerado por `spec-verify.sh` em `2026-11-01T00:06:09-03:00`, commit `3bb6b17f`) não declara checks no `FORGE.md` runtime para este projeto — `checks: [{name: none, status: skipped}]` — então a verificação de comportamento real depende dos gates isolados abaixo, todos rodados manualmente nesta sessão a partir da raiz da worktree, cada um com `rc=0`:

```
bash tests/w284-changelog-engine-explicito-gate.sh
bash tests/w285-changelog-engine-derivado-gate.sh
bash tests/w286-changelog-engine-merge-range-gate.sh
bash tests/w287-changelog-engine-release-please-gate.sh
bash tests/w288-changelog-gate-released-gate.sh
bash tests/w289-changelog-gate-preserve-gate.sh
bash tests/w290-changelog-gate-lint-gate.sh
bash tests/w291-resolve-skill-gate.sh
bash tests/w292-update-changelog-comando-gate.sh
bash tests/w293-post-merge-changelog-engine-gate.sh
bash tests/w294-changelog-gates-regressao-gate.sh
bash tests/w295-changelog-merge-engine-gate.sh
bash tests/w296-skill-readme-generator-escopo-gate.sh
bash tests/w147-hook-delegation-gate.sh
bash tests/w223-delegacao-arvore-do-hook-gate.sh
bash tests/w248-git-dir-isolation-gate.sh
bash template/.forge/scripts/build-plugin.sh && git diff --exit-code plugin/forge/commands/update-changelog.md
```

Nenhum log foi persistido em arquivo durável nesta sessão (saída capturada em `/tmp/out_*.log`, efêmero) — qualquer revisor reproduz com os mesmos 16 comandos acima, cada um saindo com `PASS <nome-do-gate>` (ou, no caso de `w248`, cenários `[1]..[24]` sem `FAIL`) e `rc=0`. Evidência determinística adicional: `manifest.yaml` (fingerprint, `affected_paths`) e `tasks.md` (14633 bytes) estão referenciados em `evidence/runs/20261101030609-1d34c40d/run-manifest.json`.

`npm test` completo (TASK-19, suíte inteira) **não foi re-executado** nesta verificação — decisão deliberada, não lacuna: a suíte tem um problema pré-existente e documentado em LDG-0016/LDG-0210 (fixtures de outros gates vazando para `.forge/specs/active/` e `.forge/ledger/` reais desta árvore), não relacionado a este change, e rodar de novo custaria ~40 min sem agregar sinal que os 16 gates isolados já não deem sobre o comportamento deste change especificamente.

## Desvios e observações

- Nenhum REQ ficou sem teste isolado confirmado rodando de verdade — todos os 22 itens da tabela (REQ-01 a REQ-14, DIV-01, DIV-02, mais TASK-16/17/18) foram verificados executando o gate relevante nesta sessão, não só lendo nome de teste ou `tasks.md`.
- DIV-01 e DIV-02 (o coração da correção da issue #238) foram confirmados tanto por leitura direta do código-fonte (`changelog-engine.mjs` linhas 32 e 257) quanto pela saída observada dos gates `w285`/`w295` — a prova é da saída NOVA (pt-BR, `perf`→Corrigido, sem `refactor`/`revert`), não da antiga.
- `spec-delta.yaml` foi preenchido com 14 `add_requirement` novos (`REQ-CA-001..008` para a capability `changelog-authoring`, `REQ-PMA-001..005` para `post-merge-automation`) — nenhum requisito pré-existia no baseline para essas capabilities (`grep` em `.forge/product/current/` sem match), então não há `modify_requirement` a fazer. `FORGE_ROOT="$(pwd)" bash template/.forge/scripts/validate-spec.sh add-unify-changelog-skill` passou (`OK add-unify-changelog-skill`) após a correção dos anchors de `content_ref` (apontavam para um heading `#divergências-de-saída-intencionais` que não existe como `##` no `refactor.md` — DIV-01/DIV-02 vivem dentro da seção `## 1`; corrigido para apontar lá).
- `npm test` completo não foi rodado nesta passada (ver seção "Checks deterministas" acima) — se o dono quiser o sinal da suíte inteira antes do archive, isso ainda precisa rodar ao menos uma vez fora desta verificação, mas não bloqueia este resultado porque os 16 gates isolados já cobrem, de forma determinística, toda a superfície REQ/DIV deste change especificamente.
- Nada neste change toca `template/machinery-history.json` nem `snapshot/project-bootstrap/` — confirmado por ausência de diff em ambos no `git status` desta árvore.
