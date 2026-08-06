# Verification — red-first-ci-authority

- **Commit sob verificação:** working tree sobre `f8e4520` (branch `develop`)
- **Verificado em:** 2026-08-04
- **Veredito global: PASS.** `npm test` → **PASS=74 FAIL=0 SKIP=0** (325s) — um gate a mais que a execução anterior (`w109`).

## Tabela REQ-a-REQ

| REQ | Veredito | Evidência |
|---|---|---|
| REQ-01 — varredura num comando só | PASS | `red-evidence.sh ci` percorre `specs/active/*/manifest.yaml`, filtra `type: bugfix`, roda `ensure` + `check-red-first check` por change e agrega. `w109[1]` (sem change ativo → 0), `w109[2]` (pendente → ≠0 nomeando), `w109[3]` (Red real observado → 0), `w109[4]` (feature ignorada, sem aparecer no relato). |
| REQ-01 — escopo não é escolhido por quem invoca | PASS | `w109[5]`: `ci <change-id>` sai ≠0. O guard é explícito no script, com o motivo em comentário. |
| REQ-02 — CI é a autoridade | PASS | Step "Red-first replay (autoridade do CI)" em `.github/workflows/ci.yml`, depois do `npm ci`, sem `continue-on-error`. Executado localmente contra o estado atual do repo: `OK ci — nenhum change ativo type:bugfix` (exit 0). |
| REQ-03 — consumidores recebem o gate | PASS | `template/github/workflows/red-first.yml` com `fetch-depth: 0` e instalação de dependências. `w109[6]` cobre os dois instaladores e a não-sobrescrita de workflow existente. |
| REQ-04 — a norma registra a fronteira | PASS | `rules/testing/regression-red-first.md` ganhou "A execução de referência é a do CI", dizendo o que fecha (ambiente, cache) e repetindo que os três vetores adversariais seguem abertos. `commands/testing/red.md` documenta o subcomando; `plugin-sync-gate` verde. |
| NFR-01 — zero-dep | PASS | Só bash, `awk`, `git` e builtins do node. |
| NFR-03 — nada muda localmente | PASS | `spec-verify.sh`, `archive-spec.sh` e o pre-push intocados; `w106`/`w107`/`w108` verdes na suíte. |

## Prova de que o teste pode falhar

`w109[6]` é o caso que cobre paridade — e paridade é exatamente o tipo de asserção que passa por
acidente. Desliguei a materialização apenas em `installer/install.sh` (`if false && …`) e reexecutei:
o gate reprovou com "installer/install.sh não materializou red-first.yml — paridade quebrada".
Mutação revertida em seguida.

Ao reverter, `git checkout -- installer/install.sh` levou junto a edição real (que ainda não estava
commitada) e o arquivo voltou ao HEAD sem a fiação. Detectado no `grep` de conferência logo depois,
reaplicado e revalidado. Registro porque o erro é reincidível: reverter mutação com `git checkout`
em arquivo com mudança não commitada apaga a mudança.

## Fronteira (o que este change NÃO fecha)

Fecha o vetor do **ambiente controlado pelo autor** e encerra a discussão sobre cache local.
Permanecem abertos, e agora explicitamente na rule: **comando declarado arbitrário** (o `command`
vem do artefato que o autor escreve), **defeito introduzido no próprio PR** e **waiver
inverificável**. Os três exigem revisão humana.

## Comandos executados

- `npm test` → PASS=74 FAIL=0 SKIP=0
- `bash tests/w109-red-ci-gate.sh` → PASS (6 casos)
- `FORGE_ROOT=$(pwd) bash template/.forge/scripts/red-evidence.sh ci` → OK (exit 0)
- `bash tests/plugin-sync-gate.sh` → PASS
- `bash tests/w13-init-gate.sh` → OK (init sem regressão)
