#!/usr/bin/env bash
# ORDINAL: w290 atribuído no merge de add-liaison-native-bridge
# Gate — gancho de saída `guard-cross-session-send.sh`: classificação de destino e varredura de
# segredo (TASK-14/TASK-15, parte 1, STORY-08, design §2.5 etapas 1 a 4, REQ-04, REQ-05) e
# contenção por workspace, origem cruzada e destino declarado (TASK-16/TASK-17, parte 2,
# STORY-09, etapas 5 e 6, REQ-06, REQ-07) — a parte 2 é anexada a este arquivo quando a TASK-16
# entra; os casos da parte 1 continuam verdes.
#
# A lógica mora no driver `tests/w290-native-send-guard-gate.driver.mjs` (fixtures de registro de
# sessões, socket real via node:net, transcript sintético e cópia da árvore para o teste de
# leitor único, exercitando a API de `native-send-guard.mjs` e, para os casos que precisam do
# processo real, o próprio script `guard-cross-session-send.sh` via stdin) — este .sh só isola o
# ambiente git e repassa o resultado.
set -euo pipefail
# Isolamento git (LDG-0201): GIT_* herdado do ambiente faria os `git init` de fixture do driver
# obedecerem ao repositório de quem invocou o gate.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

node "$WS/tests/w290-native-send-guard-gate.driver.mjs"
echo "PASS native-send-guard-gate"
