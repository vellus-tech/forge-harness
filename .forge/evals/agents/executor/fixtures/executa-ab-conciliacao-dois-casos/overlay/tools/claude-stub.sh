#!/usr/bin/env bash
# Stub offline do Claude CLI usado no smoke do eval harness (CI sem login do Claude).
# Aceita a mesma linha de comando do runner claude-code: -p "<prompt>" --output-format stream-json.
# Cada invocação é registrada em .eval-runner/calls.jsonl na raiz do projeto.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPT=""; STREAM=false
while [ $# -gt 0 ]; do
  case "$1" in
    -p) PROMPT="${2:-}"; shift 2 ;;
    --output-format) [ "${2:-}" = "stream-json" ] && STREAM=true; shift 2 ;;
    *) shift ;;
  esac
done
WITH_SKILL=false
printf '%s' "$PROMPT" | grep -q 'name: conciliacao-csv' && WITH_SKILL=true
CASE="$(printf '%s' "$PROMPT" | grep -o 'caso-[a-z0-9-]*' | tail -1)"
mkdir -p "$ROOT/.eval-runner"
printf '{"n":%s,"case":"%s","with_skill":%s,"stream_json":%s}\n' \
  "$(( $(cat "$ROOT/.eval-runner/calls.jsonl" 2>/dev/null | wc -l) + 1 ))" "${CASE:-desconhecido}" "$WITH_SKILL" "$STREAM" \
  >> "$ROOT/.eval-runner/calls.jsonl"
case "$CASE" in
  caso-arquivo-corrompido) echo "erro: extrato-maio.csv linha 17: separador inconsistente" >&2; exit 2 ;;
  caso-lote-grande) sleep 20; echo "lote processado" ;;
esac
if [ "$WITH_SKILL" = true ]; then IN=1180; OUT=95; else IN=240; OUT=110; fi
echo '{"type":"system","subtype":"init","model":"stub"}'
if [ "$CASE" = "caso-extrato-longo" ]; then
  for i in $(seq -w 1 700); do echo "{\"type\":\"assistant\",\"text\":\"linha $i de 700\"}"; done
fi
echo "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"Conciliação concluída (with_skill=$WITH_SKILL).\"}]}}"
echo "{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"usage\":{\"input_tokens\":$IN,\"output_tokens\":$OUT}}"
