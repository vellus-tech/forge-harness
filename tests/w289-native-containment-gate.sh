#!/usr/bin/env bash
# ORDINAL: w289 atribuído no merge de add-liaison-native-bridge
# Gate — cadastro `native allow|revoke|pin` e detector `native containment` (TASK-12/TASK-13,
# STORY-07, REQ-12, design §2.7/§4.3):
#   A lógica de escrita (allow/revoke/pin, idempotência, revogação, reativação, self_identity,
#   formato, schema) e o detector dos quatro tipos (allowlist-changed, hook-line-changed,
#   hook-unwired, remote-identity-mismatch), inclusive o caso sem mudança e os rc 2 (git
#   indisponível, intervalo inválido, hooks.manifest corrompido), são exercitados pela API no
#   driver `tests/w289-native-containment-gate.driver.mjs` — a recusa do CLI NÃO é fronteira (achado
#   A-01 do /forge:analyze: qualquer gate dentro de uma sessão do Claude Code tem `claude` como
#   ancestral, então o CLI recusaria ali por construção), então a lógica de escrita é exercitada
#   diretamente pela API, sem passar pela recusa.
#
#   Este .sh isola o ambiente git e exercita só a recusa do CLI (checagem [1] a cada marcador de
#   ambiente, checagem [2] por ancestral `claude` simulado via `ps` de fixture no PATH, para os
#   três subcomandos allow/revoke/pin) e o caminho completo do CLI uma vez (checagem [3]) com
#   `env -i` + `ps` de fixture que NÃO reporta ancestral `claude` — o mesmo contorno que um
#   agente poderia fazer, coerente com a decisão de que a recusa não é fronteira.
set -euo pipefail
# Isolamento git (LDG-0201): GIT_* herdado do ambiente faria os comandos git deste gate
# obedecerem ao repositório de quem o invocou, nunca ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPS="$WS/template/.forge/scripts/liaison-ops.sh"
T="$(mktemp -d /tmp/forge-native-containment.XXXXXX)"
trap 'rm -rf "$T"' EXIT

n=0
fail=0
ok() { n=$((n + 1)); echo "OK [$n] $1"; }
bad() { n=$((n + 1)); fail=$((fail + 1)); echo "FAIL [$n] $1"; }

echo "[driver] lógica de escrita (allow/revoke/pin) e detector (containment) pela API"
if node "$WS/tests/w289-native-containment-gate.driver.mjs"; then
  ok "driver.mjs — lógica de escrita e detector pela API"
else
  bad "driver.mjs — allow/revoke/pin/containment: driver reprovou (ver saída acima)"
fi

# --- fixture do CLI ---------------------------------------------------------------------------
mk_repo() { # mk_repo <dir>
  local dir="$1"
  mkdir -p "$dir/.forge"
  for d in scripts templates hooks schemas rules commands ledger; do
    [ -d "$WS/template/.forge/$d" ] && cp -R "$WS/template/.forge/$d" "$dir/.forge/"
  done
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  git -C "$dir" init -q
  git -C "$dir" config user.email "op@test"
  git -C "$dir" config user.name "Operator"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" remote add origin https://github.com/acme/widget.git
  git -C "$dir" commit --allow-empty -qm "chore: init"
}

REPO="$T/repo"
mk_repo "$REPO"
CADASTRO="$REPO/.forge/liaison/allowed-workspaces.json"

run() { # run <cmd...> — nunca aborta o gate; preenche OUT e RC
  set +e
  OUT="$("$@" 2>&1)"
  RC=$?
  set -e
}

# --- [1] recusa do CLI por cada marcador de ambiente (allow) ----------------------------------
echo "[1] native allow recusa por cada marcador de ambiente, sem tocar o arquivo"
for marker in CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_PID CLAUDE_CODE_ENTRYPOINT; do
  before="$(md5sum "$CADASTRO" 2>/dev/null || true)"
  run env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_PID -u CLAUDE_CODE_ENTRYPOINT \
    "$marker=1" FORGE_ROOT="$REPO" bash "$OPS" native allow github.com/acme/other --reason teste
  after="$(md5sum "$CADASTRO" 2>/dev/null || true)"
  if [ "$RC" -eq 0 ]; then
    bad "allow com marcador '$marker' presente deveria recusar (rc 0): $OUT"
    continue
  fi
  if ! grep -qi "operador\|terminal" <<<"$OUT"; then
    bad "allow com marcador '$marker': recusou mas sem a mensagem de ato do operador: $OUT"
    continue
  fi
  if [ "$before" != "$after" ]; then
    bad "allow com marcador '$marker': arquivo foi tocado apesar da recusa"
    continue
  fi
  ok "allow recusa com marcador '$marker' presente, sem tocar o arquivo"
done

# --- [2] recusa do CLI por ancestral claude simulado (allow/revoke/pin) -----------------------
echo "[2] native allow|revoke|pin recusam por ancestral 'claude' simulado via ps de fixture"
PSFAKE_CLAUDE="$T/psfake-claude"
mkdir -p "$PSFAKE_CLAUDE"
cat > "$PSFAKE_CLAUDE/ps" <<'PSEOF'
#!/usr/bin/env bash
case "$*" in
  *"-o comm="*) echo "claude" ;;
  *"-o ppid="*) echo "1" ;;
  *) exec /bin/ps "$@" ;;
esac
PSEOF
chmod +x "$PSFAKE_CLAUDE/ps"

for sub in allow revoke pin; do
  before="$(md5sum "$CADASTRO" 2>/dev/null || true)"
  case "$sub" in
    allow|revoke) args=(native "$sub" github.com/acme/other --reason teste) ;;
    pin) args=(native pin) ;;
  esac
  run env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_PID -u CLAUDE_CODE_ENTRYPOINT \
    PATH="$PSFAKE_CLAUDE:$PATH" FORGE_ROOT="$REPO" bash "$OPS" "${args[@]}"
  after="$(md5sum "$CADASTRO" 2>/dev/null || true)"
  if [ "$RC" -eq 0 ]; then
    bad "native $sub com ancestral 'claude' simulado deveria recusar (rc 0): $OUT"
    continue
  fi
  if ! grep -qi "operador\|terminal" <<<"$OUT"; then
    bad "native $sub com ancestral 'claude' simulado: recusou mas sem a mensagem de ato do operador: $OUT"
    continue
  fi
  if [ "$before" != "$after" ]; then
    bad "native $sub com ancestral 'claude' simulado: arquivo foi tocado apesar da recusa"
    continue
  fi
  ok "native $sub recusa com ancestral 'claude' simulado, sem tocar o arquivo"
done

# --- [3] caminho completo do CLI, uma vez, fora de sessão (env -i + ps de fixture + git local) -
echo "[3] native allow — caminho completo do CLI com env -i, ps de fixture sem ancestral claude, HOME e git config de fixture"
PSFAKE_HUMAN="$T/psfake-human"
mkdir -p "$PSFAKE_HUMAN"
cat > "$PSFAKE_HUMAN/ps" <<'PSEOF'
#!/usr/bin/env bash
case "$*" in
  *"-o comm="*) echo "login" ;;
  *"-o ppid="*) echo "1" ;;
  *) exec /bin/ps "$@" ;;
esac
PSEOF
chmod +x "$PSFAKE_HUMAN/ps"

REALNODE="$(command -v node)"
REALGIT="$(command -v git)"
REALBASH="$(command -v bash)"
FAKEHOME="$T/fakehome"
mkdir -p "$FAKEHOME"

set +e
OUT3="$(env -i \
  PATH="$PSFAKE_HUMAN:$(dirname "$REALNODE"):$(dirname "$REALGIT"):$(dirname "$REALBASH"):/usr/bin:/bin" \
  HOME="$FAKEHOME" \
  FORGE_ROOT="$REPO" \
  "$REALBASH" "$OPS" native allow github.com/acme/human-path --reason "operador fora da sessão" 2>&1)"
RC3=$?
set -e
if [ "$RC3" -ne 0 ]; then
  bad "caminho completo do CLI (env -i + ps de fixture sem claude) deveria passar (rc 0): $OUT3"
elif ! grep -q "github.com/acme/human-path" "$CADASTRO" 2>/dev/null; then
  bad "caminho completo do CLI: cadastro não contém a identidade liberada: $(cat "$CADASTRO" 2>/dev/null || echo '<ausente>')"
else
  ok "caminho completo do CLI (env -i, ps de fixture sem ancestral claude, HOME/git de fixture) grava o cadastro"
fi

if [ "$fail" -gt 0 ]; then
  echo
  echo "$fail de $n checagem(ns) reprovada(s)."
  exit 1
fi
echo
echo "PASS native-containment-gate — $n checagens."
