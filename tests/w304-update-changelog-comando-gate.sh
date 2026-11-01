#!/usr/bin/env bash
# Gate W304 — verificacao estatica de template/.forge/commands/docs/update-changelog.md (TASK-09).
#
# Cenarios:
#   [1] trava de branch protegida (develop/master/main) documentada nos Passos a Executar
#   [2] deteccao de release-please-config.json documentada (REQ-10)
#   [3] os 4 gates nomeados explicitamente, incluindo check-ai-attribution.sh text
#   [4] nenhuma instrucao de "git commit" no corpo (comando nunca commita)
#   [5] resolve-skill.sh citado (REQ-12)
#   [6] resolve-skill.sh pelo caminho do consumidor (.forge/scripts/)
#   [7] versão anterior guardada antes do motor, usada pelos gates e restaurada em falha
#   [8] awk de extração das linhas novas: anterior vazio e multiconjunto
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$WS/template/.forge/commands/docs/update-changelog.md"

[ -f "$CMD" ] || { echo "FAIL: comando nao encontrado em $CMD"; exit 1; }
body="$(cat "$CMD")"

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] trava de branch protegida documentada"
case "$body" in
  *develop*master*main*|*develop*|*master*|*main*)
    echo "$body" | grep -qiE 'develop.{0,40}master.{0,40}main|branch protegida' \
      || { echo "FAIL: comando nao documenta trava de branch protegida (develop/master/main)"; exit 1; }
    ;;
  *) echo "FAIL: comando nao menciona develop/master/main"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] deteccao de release-please-config.json documentada"
echo "$body" | grep -q 'release-please-config.json' \
  || { echo "FAIL: comando nao documenta deteccao de release-please-config.json"; exit 1; }
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] os 4 gates nomeados explicitamente"
for gate in released preserve lint; do
  echo "$body" | grep -q "$gate" || { echo "FAIL: comando nao nomeia o gate '$gate'"; exit 1; }
done
echo "$body" | grep -q 'check-ai-attribution.sh text' \
  || { echo "FAIL: comando nao documenta check-ai-attribution.sh text"; exit 1; }
echo "OK [3]"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] nenhuma instrucao de git commit no corpo (negacoes do tipo 'nunca'/'nenhum' nao contam)"
if echo "$body" | grep -iE 'git commit' | grep -viE 'nunca|nenhum|não commit|nao commit'; then
  echo "FAIL: comando instrui commit"; exit 1
fi
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] resolve-skill.sh citado"
echo "$body" | grep -q 'resolve-skill.sh' || { echo "FAIL: comando nao chama resolve-skill.sh"; exit 1; }
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] resolve-skill.sh pelo caminho do consumidor (.forge/scripts/), nunca template/"
echo "$body" | grep -q 'bash \.forge/scripts/resolve-skill\.sh' || { echo "FAIL [6]: comando não chama .forge/scripts/resolve-skill.sh"; exit 1; }
if echo "$body" | grep -q 'template/\.forge/scripts/resolve-skill\.sh'; then echo "FAIL [6]: comando cita template/.forge/scripts/resolve-skill.sh, inexistente no consumidor"; exit 1; fi
echo "OK [6]"

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
echo "[7] versão anterior guardada antes do motor, usada pelos gates e restaurada em falha"
echo "$body" | grep -q 'cp "\$CL" "\$ANTERIOR"' || { echo "FAIL [7]: comando não guarda a versão anterior"; exit 1; }
echo "$body" | grep -q 'released.mjs" "\$ANTERIOR" "\$CL"' || { echo "FAIL [7]: released não compara com a versão anterior"; exit 1; }
echo "$body" | grep -q 'lint.mjs" "\$CL" --since "\$ANTERIOR"' || { echo "FAIL [7]: lint não restrito às entradas novas"; exit 1; }
echo "$body" | grep -q 'cp "\$ANTERIOR" "\$CL"' || { echo "FAIL [7]: comando não restaura o arquivo quando um gate falha"; exit 1; }
echo "$body" | grep -qF "velha[\$0]-- <= 0' \"\$ANTERIOR\" \"\$CL\" > \"\$NOVAS\"" || { echo "FAIL [7]: check-ai-attribution não restrito às linhas novas"; exit 1; }
echo "$body" | grep -q 'check-ai-attribution.sh text "\$NOVAS"' || { echo "FAIL [7]: check-ai-attribution não roda sobre as linhas novas"; exit 1; }
snap=$(echo "$body" | grep -n 'cp "\$CL" "\$ANTERIOR"' | head -1 | cut -d: -f1)
eng=$(echo "$body" | grep -n 'changelog-engine.mjs" --root' | head -1 | cut -d: -f1)
[ -n "$snap" ] && [ -n "$eng" ] && [ "$snap" -lt "$eng" ] || { echo "FAIL [7]: a cópia da versão anterior não vem antes da chamada ao motor"; exit 1; }
echo "OK [7]"

# ── [8] ──────────────────────────────────────────────────────────────────────────────────────
echo "[8] extração das linhas novas (awk do comando) com arquivo anterior vazio e com linha repetida"
T="$(mktemp -d /tmp/forge-w304.XXXXXX)"
trap 'rm -rf "$T"' EXIT
prog="$(echo "$body" | grep -o "awk '[^']*'" | head -1 | sed "s/^awk '//; s/'\$//")"
[ -n "$prog" ] || { echo "FAIL [8]: comando não traz o awk de extração das linhas novas"; exit 1; }
: > "$T/ant-vazio"; printf '# Changelog\n- entrada nova\n' > "$T/cl-novo"
n="$(awk "$prog" "$T/ant-vazio" "$T/cl-novo" | grep -c 'entrada nova')"
[ "$n" -eq 1 ] || { echo "FAIL [8]: com anterior vazio, a linha nova não foi extraída (CHANGELOG criado agora sairia sem verificação)"; exit 1; }
printf 'a\nb\n' > "$T/ant"; printf 'a\nb\na\nc\n' > "$T/cl"
[ "$(awk "$prog" "$T/ant" "$T/cl" | tr '\n' ' ')" = "a c " ] || { echo "FAIL [8]: linha nova idêntica a uma antiga não foi extraída (multiconjunto)"; exit 1; }
echo "OK [8]"

echo "PASS w304-update-changelog-comando"
