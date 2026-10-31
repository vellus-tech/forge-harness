# semantic-env.sh — preparo compartilhado dos gates do /forge:kb (incluído por `source`).
#
# kb_env_setup — gates do caminho lexical: monta uma raiz de fixture com CÓPIA da maquinaria do
#   template (o kb.sh real) e sobe um servidor HTTP local em outro processo (alvo do canário de rede).
#   Não exige devDependencies, pins nem fixtures de modelo.
# semantic_env_setup — gates da camada semântica: tudo acima, mais as devDependencies conferidas, o
#   `npm` substituto no PATH e os pins de modelos da cópia trocados por modelos ONNX de fixture
#   servidos em 127.0.0.1. Depois disso, `kb semantic install` roda o instalador de produção sem
#   nenhum override.
#
# Exige: WS, T definidos. Define: R (raiz), SRV (dir servido), PORT, KBSH, função kb,
# função kb_fixture_pins [--broken-embedder], semantic_env_teardown.
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
semantic_env_setup() {
  [ -d "$WS/node_modules/onnxruntime-web" ] && [ -d "$WS/node_modules/@huggingface/tokenizers" ] || {
    echo "FAIL [setup] devDependencies ausentes em $WS/node_modules (rode npm ci) — sem elas o teste de inferência real não roda, e pular seria verde falso"; exit 1; }
  kb_env_setup
  cp "$WS/tests/fixtures/kb/fake-npm.sh" "$T/bin/npm"; chmod +x "$T/bin/npm"
  export FAKE_NPM_SOURCE="$WS" FAKE_NPM_LOG="$T/npm.log"
  kb_fixture_pins
}
kb_fixture_pins() {
  node "$WS/tests/fixtures/kb/make-semantic-fixture.mjs" "$SRV" "http://127.0.0.1:$PORT" "$@"
  cp "$SRV/models.json" "$R/.forge/scripts/lib/kb-pins/models.json"
}
kb() { PATH="$T/bin:$PATH" FORGE_ROOT="$R" bash "$KBSH" "$@"; }
semantic_env_teardown() { if [ -n "${SERVE_PID:-}" ]; then kill "$SERVE_PID" 2>/dev/null || true; wait "$SERVE_PID" 2>/dev/null || true; fi; }
