#!/usr/bin/env bash
# Gate W274 — `forge update --skip-postcheck` pula o `doctor.sh --report` do fim do update, o default continua rodando o doctor, e os gates que chamam `forge update` dezenas de vezes sem testar o doctor usam a flag.
#
# POR QUE ESTE GATE EXISTE. O `update` roda `doctor.sh --report` como pós-checagem (~2s por chamada). w239, w217 e w214 chamam `forge update` dezenas de vezes e nenhum deles prova nada sobre esse doctor — o w239 [7] e o w217 [6] invocam o doctor DIRETAMENTE quando é ele o sujeito. Somados, eram ~10min da suíte serial do CI. A flag existe para esses gates; o consumidor real continua recebendo o diagnóstico no fim de todo update.
#
#   [1]  sem a flag, o doctor do fim do update RODA (marcador gravado com o argumento --report) — controle: o default não mudou
#   [2]  com --skip-postcheck, o doctor NÃO roda (marcador intocado), o update sai rc 0 e conclui; e o doctor.sh instalado é o marcador (sem isso, a ausência do marcador não provaria nada)
#   [3]  --help documenta --skip-postcheck
#   [4]  w239, w217, w214, w101, w133, w168, w109 e w250 passam --skip-postcheck em TODA invocação de `forge update` que não é --dry-run (o --dry-run sai antes do doctor); contador de controle >= 1 invocação por gate, contra o arquivo em disco
#   [5]  os gates cujo sujeito é o doctor pós-update (w63 [g], w94, w137, w153, npx-pack) NÃO usam a flag — a cobertura do doctor real continua na suíte
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$WS/bin/forge.mjs"
TPL="$WS/template/.forge"
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w274.XXXXXX")"
trap 'rm -rf "$T"' EXIT

# Template com o doctor.sh trocado por um marcador: o update entrega o marcador ao consumidor e,
# se a pós-checagem rodar, é ELE que roda — gravando os argumentos recebidos em $W274_MARCA.
TPLM="$T/tpl-marcador"
cp -R "$TPL" "$TPLM"
cat > "$TPLM/scripts/doctor.sh" <<'EOF'
#!/usr/bin/env bash
# doctor marcador do w274
printf 'doctor-rodou %s\n' "$*" >> "${W274_MARCA:?}"
exit 0
EOF

consumidor() {  # consumidor <nome> -> ecoa <dir> com .forge instalado e lock gravado pelo template real
  local d="$T/$1"
  mkdir -p "$d"
  git -C "$d" init -q || { echo "FAIL (setup): git init falhou para $1"; exit 1; }
  node "$FORGE" init --target "$d" --slug demo --name Demo --desc t --yes --no-plugin >"$d.init.log" 2>&1 \
    || { echo "FAIL (setup): init falhou para $1"; cat "$d.init.log"; exit 1; }
  # update de preparo contra o template real: grava o machinery.lock, que prova o doctor.sh intocado
  # e deixa o update seguinte entregar o marcador (ATUALIZADO) em vez de preservá-lo como deriva.
  node "$FORGE" update --target "$d" --no-plugin --no-backup --source "$TPL" >"$d.prep.log" 2>&1 \
    || { echo "FAIL (setup): update de preparo falhou para $1"; cat "$d.prep.log"; exit 1; }
  printf '%s\n' "$d"
}

echo "[1] sem a flag: o doctor do fim do update roda (default inalterado)"
C1="$(consumidor c1)"
M1="$T/marca1.txt"
out1="$(W274_MARCA="$M1" node "$FORGE" update --target "$C1" --no-plugin --no-backup --source "$TPLM" 2>&1)"; rc1=$?
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: update saiu rc=$rc1"; echo "$out1" | tail -20; exit 1; }
cmp -s "$C1/.forge/scripts/doctor.sh" "$TPLM/scripts/doctor.sh" || { echo "FAIL [1] (setup): o update não entregou o doctor marcador — o cenário não mediria nada"; echo "$out1" | grep -i doctor; exit 1; }
[ -f "$M1" ] && grep -qx 'doctor-rodou --report' "$M1" \
  || { echo "FAIL [1]: sem --skip-postcheck o doctor --report do fim do update NÃO rodou (marcador: '$(cat "$M1" 2>/dev/null)')"; exit 1; }
echo "OK [1]"

echo "[2] com --skip-postcheck: o doctor não roda, o update conclui rc 0"
C2="$(consumidor c2)"
M2="$T/marca2.txt"
out2="$(W274_MARCA="$M2" node "$FORGE" update --target "$C2" --no-plugin --no-backup --source "$TPLM" --skip-postcheck 2>&1)"; rc2=$?
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: update --skip-postcheck saiu rc=$rc2"; echo "$out2" | tail -20; exit 1; }
cmp -s "$C2/.forge/scripts/doctor.sh" "$TPLM/scripts/doctor.sh" || { echo "FAIL [2] (controle): o doctor marcador não foi entregue — a ausência do marcador não provaria que o doctor foi pulado"; exit 1; }
[ ! -e "$M2" ] || { echo "FAIL [2]: com --skip-postcheck o doctor rodou mesmo assim (marcador: '$(cat "$M2")')"; exit 1; }
grep -q 'Forge atualizado em' <<<"$out2" || { echo "FAIL [2]: update --skip-postcheck não concluiu (linha final ausente)"; echo "$out2" | tail -20; exit 1; }
echo "OK [2]"

echo "[3] --help documenta --skip-postcheck"
help="$(node "$FORGE" --help 2>&1)"
grep -q -- '--skip-postcheck' <<<"$help" || { echo "FAIL [3]: --help não documenta --skip-postcheck"; exit 1; }
echo "OK [3]"

echo "[4] os gates que não testam o doctor passam --skip-postcheck em toda invocação real de update"
# Invocação de update = linha que chama o forge.mjs (node "$FORGE"/"$bin"/"$WS/bin/forge.mjs" ... update,
# ou o vetor de argumentos ['update', ...] / [FORGE, 'update', ...] do PBT em node).
inv_re='(forge\.mjs"?|\$FORGE"?|\$bin"?|\$WS[0-9]*/bin/forge\.mjs"?) update |\[(FORGE, )?.update.,'
total=0
for g in w239-update-preserva-deriva w217-heavy-mutex-partition w214-update-exceptions w101-update-preserve w133-gitignore-reconcile w168-liaison-log-merge-union w109-red-ci w250-data-engineer-agents; do
  f="$WS/tests/$g-gate.sh"
  [ -f "$f" ] || { echo "FAIL [4]: $f ausente"; exit 1; }
  n="$(grep -E "$inv_re" "$f" | grep -vE '^[[:space:]]*#' | grep -cv -- '--dry-run')"
  [ "$n" -ge 1 ] || { echo "FAIL [4]: nenhuma invocação de update reconhecida em $g — o padrão não mede o que pensa"; exit 1; }
  sem="$(grep -nE "$inv_re" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -v -- '--dry-run' | grep -v -- '--skip-postcheck')"
  [ -z "$sem" ] || { echo "FAIL [4]: $g chama forge update sem --skip-postcheck:"; echo "$sem"; exit 1; }
  total=$((total + n))
done
echo "OK [4] ($total invocações)"

echo "[5] os gates cujo sujeito é o doctor pós-update continuam rodando o doctor real"
for g in w63-forge-update w94-hookspath-preserve w137-worktree-machinery w153-upgrade-safety npx-pack; do
  f="$WS/tests/$g-gate.sh"
  [ -f "$f" ] || { echo "FAIL [5]: $f ausente"; exit 1; }
  grep -q -- '--skip-postcheck' "$f" && { echo "FAIL [5]: $g usa --skip-postcheck, mas o doctor pós-update é sujeito dele"; exit 1; }
done
echo "OK [5]"

echo "PASS w274-skip-postcheck-gate"
