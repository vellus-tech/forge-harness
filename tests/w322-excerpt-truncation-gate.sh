#!/usr/bin/env bash
# Gate W322 — LDG-0020: truncateExcerpt (lib/red-replay.mjs) guardava só a CAUDA do excerto
# (últimos EXCERPT_MAX_CHARS chars). Em teste de integração verboso (log de depuração do host
# preenchendo o fim da saída), a asserção (Expected/Actual) ficava ANTES do trecho guardado —
# check-red-first.sh reclassificava o excerto armazenado como 'unknown', mesmo com Red observado
# de verdade pelo replay (que classifica contra a saída INTEIRA, não o excerto truncado).
#   [1] saída curta (<= EXCERPT_MAX_CHARS) não é tocada — idêntica, sem marcador de truncamento
#   [2] saída longa, asserção no INÍCIO (cenário real do achado) + failure_pattern declarado —
#       a janela em torno do match preserva a asserção; só cauda (comportamento antigo) perderia
#   [3] saída longa, asserção no MEIO — mesma garantia, independente de onde a asserção caia
#   [4] saída longa SEM failure_pattern (ou pattern que não casa) — cai para cabeça+cauda, nunca
#       só cauda; cobre cabeça e cauda da saída original
#   [5] MUTAÇÃO (sandbox) — reverter para o comportamento antigo (só cauda) faz [2] falhar
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"

probe() { # probe <lib-dir> <output-file> <pattern-or-empty>
  node --input-type=module -e "
    import { truncateExcerpt } from '$1/red-replay.mjs';
    import { readFileSync } from 'node:fs';
    const text = readFileSync(process.argv[1], 'utf8');
    const pattern = process.argv[2] || undefined;
    process.stdout.write(truncateExcerpt(text, pattern));
  " "$2" "$3"
}

T="$(mktemp -d /tmp/forge-w322.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] saída curta não é tocada"
printf 'linha curta\nAssert.Equal() Failure\nExpected: 1\nActual: 2\n' > "$T/short.txt"
out1="$(probe "$LIB" "$T/short.txt" '')"
[ "$out1" = "$(cat "$T/short.txt")" ] || { echo "FAIL [1]: saída curta foi alterada"; exit 1; }
echo "OK [1]"

echo "[2] saída longa, asserção no início + failure_pattern — janela preserva a asserção"
{
  printf 'Assert.Equal() Failure\nExpected: 1\nActual: 2\n'
  for i in $(seq 1 2000); do printf 'log de depuração do host linha %d - ruído verboso que enche a saída\n' "$i"; done
} > "$T/head.txt"
out2="$(probe "$LIB" "$T/head.txt" 'Assert\.Equal\(\) Failure')"
grep -q "Expected: 1" <<<"$out2" || { echo "FAIL [2]: janela não preservou a asserção do início ($out2)"; exit 1; }
grep -q "Actual: 2" <<<"$out2" || { echo "FAIL [2]: janela não preservou Actual ($out2)"; exit 1; }
echo "OK [2]"

echo "[3] saída longa, asserção no meio — mesma garantia"
{
  for i in $(seq 1 1000); do printf 'ruído antes da asserção linha %d\n' "$i"; done
  printf 'Assert.Equal() Failure\nExpected: 1\nActual: 2\n'
  for i in $(seq 1 1000); do printf 'ruído depois da asserção linha %d\n' "$i"; done
} > "$T/mid.txt"
out3="$(probe "$LIB" "$T/mid.txt" 'Assert\.Equal\(\) Failure')"
grep -q "Expected: 1" <<<"$out3" || { echo "FAIL [3]: janela não preservou a asserção do meio ($out3)"; exit 1; }
echo "OK [3]"

echo "[4] sem failure_pattern (ou sem match) — cabeça + cauda, nunca só cauda"
out4="$(probe "$LIB" "$T/head.txt" '')"
grep -q "Assert.Equal() Failure" <<<"$out4" || { echo "FAIL [4]: fallback sem pattern perdeu a cabeça da saída ($out4)"; exit 1; }
grep -q "linha 2000" <<<"$out4" || { echo "FAIL [4]: fallback sem pattern perdeu a cauda da saída"; exit 1; }
echo "OK [4]"

echo "[5] MUTAÇÃO (sandbox) — reverter truncateExcerpt para só-cauda faz [2] falhar"
MT="$(mktemp -d /tmp/forge-w322-mut.XXXXXX)"
mkdir -p "$MT/lib"
cp "$LIB/red-replay.mjs" "$MT/lib/red-replay.mjs"
cp "$LIB"/*.mjs "$MT/lib/" 2>/dev/null || true
RR="$MT/lib/red-replay.mjs"
python3 - "$RR" <<'PYEOF'
import re, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    content = fh.read()
replacement = (
    "export function truncateExcerpt(s) {\n"
    "  const text = String(s || '');\n"
    "  if (text.length <= EXCERPT_MAX_CHARS) return text;\n"
    "  return `…(truncado — ${text.length} chars)…\\n${text.slice(-EXCERPT_MAX_CHARS)}`;\n"
    "}\n"
)
new_content, n = re.subn(
    r"export function truncateExcerpt\(s, pattern\) \{.*?\n\}\n",
    replacement,
    content,
    count=1,
    flags=re.DOTALL,
)
if n != 1:
    sys.exit(1)
with open(path, "w", encoding="utf-8") as fh:
    fh.write(new_content)
PYEOF
grep -q "function truncateExcerpt(s) {" "$RR" || { echo "FAIL [5]: mutação não casou o padrão (python)"; rm -rf "$MT"; exit 1; }
mut_out="$(probe "$MT/lib" "$T/head.txt" 'Assert\.Equal\(\) Failure')"
if grep -q "Expected: 1" <<<"$mut_out"; then
  echo "FAIL [5]: mutação deveria perder a asserção (comportamento só-cauda), mas ela sobreviveu"; rm -rf "$MT"; exit 1
fi
echo "OK [5] — mutação (só cauda) perde a asserção do início, como [2] previa"
rm -rf "$MT"

echo "OK"
