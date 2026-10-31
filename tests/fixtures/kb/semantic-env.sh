# semantic-env.sh — preparo compartilhado dos gates do /forge:kb (incluído por `source`).
#
# kb_env_setup — gates do caminho lexical: monta uma raiz de fixture com CÓPIA da maquinaria do
#   template (o kb.sh real) e sobe um servidor HTTP local em outro processo (alvo do canário de rede).
#   Não exige devDependencies, pins nem fixtures de modelo.
#
# Exige: WS, T definidos. Define: R (raiz), SRV (dir servido), PORT, KBSH, função kb,
# semantic_env_teardown.
kb_env_setup() {
  local fx="$WS/tests/fixtures/kb"
  R="$T/root"; SRV="$T/srv"; mkdir -p "$R" "$SRV" "$T/bin"
  cp -R "$WS/template/.forge" "$R/.forge"
  KBSH="$R/.forge/scripts/kb.sh"
  printf 'pong\n' > "$SRV/ping"
  node "$fx/serve.mjs" "$SRV" > "$T/port" 2> "$T/serve.err" &
  SERVE_PID=$!
  local i=0; until [ -s "$T/port" ]; do i=$((i + 1)); [ "$i" -gt 100 ] && { echo "FAIL [setup] servidor local não subiu: $(cat "$T/serve.err")"; exit 1; }; sleep 0.1; done
  PORT="$(head -1 "$T/port")"
}
kb() { PATH="$T/bin:$PATH" FORGE_ROOT="$R" bash "$KBSH" "$@"; }
semantic_env_teardown() { if [ -n "${SERVE_PID:-}" ]; then kill "$SERVE_PID" 2>/dev/null || true; wait "$SERVE_PID" 2>/dev/null || true; fi; }
