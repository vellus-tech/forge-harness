#!/usr/bin/env bash
# ORDINAL: w286 atribuído no merge de add-liaison-native-bridge
# Gate — leitores compartilhados da mensageria nativa entre sessões (TASK-06/TASK-07, STORY-04):
#   `template/.forge/scripts/lib/native-transcript.mjs` (design §2.6, REQ-02, REQ-08),
#   `template/.forge/scripts/lib/native-registry.mjs` (design §2.5 "Resolução no registro",
#   REQ-02, REQ-07) e `template/.forge/scripts/lib/native-workspace.mjs` (design §2.5 "Raiz de
#   workspace", REQ-02, REQ-07). A lógica de cada checagem (fixtures de transcript sintético,
#   registro de sessões com sockets reais via node:net, repositórios git de fixture) mora no
#   driver `tests/w286-native-readers-gate.driver.mjs` — este .sh só isola o ambiente git e repassa o
#   resultado.
set -euo pipefail
# Isolamento git (LDG-0201): variáveis GIT_* herdadas do ambiente fariam os `git init`/`git
# remote`/`git worktree` de fixture do driver obedecerem ao repositório de quem invocou o gate.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

node "$WS/tests/w286-native-readers-gate.driver.mjs"
echo "PASS native-readers-gate"
