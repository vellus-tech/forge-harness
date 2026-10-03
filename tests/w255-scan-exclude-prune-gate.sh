#!/usr/bin/env bash
# Gate W255 — `forge_find_prune` não poda nada e não tem invocador (issue #149).
#
# Três defeitos no MESMO trecho de `template/.forge/scripts/lib/scan-exclude.sh`, todos no antigo
# `forge_find_prune` (ecoava a cláusula -prune como STRING para uso com `eval`):
#
#   (1) aspas simples em torno de cada padrão são ECOADAS como caracteres literais — `eval` nunca
#       as interpreta como delimitador de shell;
#   (2) `(` e `)` sem escape são metacaracteres de shell — `eval` tenta abrir subshell e quebra
#       com "syntax error near unexpected token `('" ANTES do `find` sequer rodar;
#   (3) `-false` colado ao ÚLTIMO padrão da lista (`vendor`) vira `-name 'vendor' -false`, que
#       NUNCA casa — `vendor` some da exclusão em silêncio.
#
# E, além dos três defeitos: NENHUM script do template chamava a função — a lib existia, órfã.
#
# Desenho: `forge_find_prune_args <array>` preenche um ARRAY (`\(`, `-name`, padrão, `-o`
# repetido, `\) -prune -o`), SEM `-false`; uso é `find "$P" "${arr[@]}" ...` (bash 3.2, array
# nunca eval). `doctor.sh::find_marker` vira o invocador real (issue #153, próxima da mesma
# família, depende deste invocador estar wired).
#
#   [1] RED reproduzido: `eval` sobre a string antiga quebra com erro de sintaxe (parênteses) —
#       prova da causa raiz, não só do sintoma
#   [2] positiva: `src/package.json` (fora de qualquer exclusão) é listado
#   [3] negativa por padrão: cada padrão do default de `FORGE_SCAN_EXCLUDE` materializado como
#       diretório — incluindo `.forge.bak-1` (glob) e `vendor` (ÚLTIMO da lista, o que o `-false`
#       colado anulava) — não aparece na listagem
#   [4] PBT: para subconjuntos gerados de `FORGE_SCAN_EXCLUDE` (incluindo o singleton `vendor`
#       sozinho, o singleton do primeiro item, e o conjunto completo), nenhum arquivo sob
#       diretório excluído do subconjunto é listado e todo arquivo fora deles é
#   [5] invocador real: `doctor.sh::find_marker` chama `forge_find_prune_args` e o `doctor.sh`
#       roda de ponta a ponta com o marcador podado corretamente
#   [6] mutação: recolocar `-false` no fim da cláusula faz `vendor` reaparecer na listagem —
#       prova de que o gate depende do desenho real, não de coincidência de fixture
set -uo pipefail
# Isolamento git (LDG-0201): variáveis herdadas de sessão paralela mal isolada não devem
# direcionar `git init` deste gate para o repositório real.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_SRC="$WS/template/.forge/scripts/lib/scan-exclude.sh"
DOCTOR_SRC="$WS/template/.forge/scripts/doctor.sh"
[ -f "$LIB_SRC" ] || { echo "FAIL [setup]: $LIB_SRC ausente"; exit 1; }
[ -f "$DOCTOR_SRC" ] || { echo "FAIL [setup]: $DOCTOR_SRC ausente"; exit 1; }

T="$(mktemp -d /tmp/forge-w255.XXXXXX)"
trap 'rm -rf "$T"' EXIT
FAIL=0

# ── fixture: um diretório por padrão default, mais `src/` fora de qualquer exclusão ────────────
DEFAULT_PATS=(.git node_modules .forge.bak-1 dist build out obj coverage vendor)
mkdir -p "$T/src"
echo '{}' > "$T/src/package.json"
for d in "${DEFAULT_PATS[@]}"; do
  mkdir -p "$T/$d"
  echo '{}' > "$T/$d/package.json"
done

# ── [1] RED reproduzido: a forma antiga (string + eval) quebra com erro de sintaxe ──────────────
echo "[1] RED: forma antiga (eval de string com parênteses sem escape) quebra"
old_eval_out="$(bash -c '
  pat_out=""
  for pat in .git node_modules ".forge.bak-*" dist build out obj coverage vendor; do
    pat_out="$pat_out -name '"'"'$pat'"'"' -o"
  done
  clause="( ${pat_out% -o} -false ) -prune -o"
  eval "find \"'"$T"'\" $clause -name package.json -print"
' 2>&1)"
if ! grep -q "syntax error" <<<"$old_eval_out"; then
  echo "FAIL [1]: forma antiga deveria quebrar com syntax error (eval de parênteses sem escape); saiu:"
  echo "$old_eval_out"
  FAIL=1
else
  echo "  ok: $(head -1 <<<"$old_eval_out")"
fi

# ── carrega a lib REAL (array, sem eval do find) ────────────────────────────────────────────────
# shellcheck disable=SC1090
. "$LIB_SRC"

list_files() {  # list_files <root> — lista arquivos package.json sobreviventes à poda
  local root="$1" prune=()
  forge_find_prune_args prune
  find "$root" "${prune[@]}" -name package.json -print 2>/dev/null | LC_ALL=C sort
}

echo "[2] positiva: src/package.json (fora de qualquer exclusão) é listado"
out2="$(list_files "$T")"
if ! grep -qF "$T/src/package.json" <<<"$out2"; then
  echo "FAIL [2]: src/package.json ausente da listagem"; echo "$out2"; FAIL=1
else
  echo "  ok"
fi

echo "[3] negativa: nenhum padrão default aparece, inclusive .forge.bak-1 (glob) e vendor (último)"
for d in "${DEFAULT_PATS[@]}"; do
  if grep -qF "$T/$d/package.json" <<<"$out2"; then
    echo "FAIL [3]: $d/package.json NÃO deveria ter sido listado (padrão: $d)"; FAIL=1
  fi
done
[ "$FAIL" -eq 0 ] && echo "  ok: $(wc -l <<<"$out2" | tr -d ' ') arquivo(s) sobrevivente(s), só src/"

# ── [4] PBT: subconjuntos de FORGE_SCAN_EXCLUDE materializados como diretórios ──────────────────
echo "[4] PBT: subconjuntos gerados de FORGE_SCAN_EXCLUDE"
subsets=(
  "vendor"                                   # singleton: o padrão que o -false anulava
  ".git"                                     # singleton: o primeiro da lista
  ".forge.bak-1"                             # singleton com glob no default original ('.forge.bak-*')
  ".git node_modules vendor"                 # subconjunto misto, vendor no meio/fim
  ".git node_modules .forge.bak-1 dist build out obj coverage vendor"  # conjunto completo
)
pbt_i=0
for subset in "${subsets[@]}"; do
  pbt_i=$((pbt_i + 1))
  Tp="$T/pbt-$pbt_i"
  mkdir -p "$Tp/src"
  echo '{}' > "$Tp/src/package.json"
  # shellcheck disable=SC2206
  excluded=($subset)
  for d in "${excluded[@]}"; do
    mkdir -p "$Tp/$d"
    echo '{}' > "$Tp/$d/package.json"
  done
  out_p="$(FORGE_SCAN_EXCLUDE="$subset" bash -c '. "'"$LIB_SRC"'"; prune=(); forge_find_prune_args prune; find "'"$Tp"'" "${prune[@]}" -name package.json -print' | LC_ALL=C sort)"
  if ! grep -qF "$Tp/src/package.json" <<<"$out_p"; then
    echo "FAIL [4.$pbt_i]: subset='$subset' — src/package.json deveria estar presente"; FAIL=1
  fi
  for d in "${excluded[@]}"; do
    if grep -qF "$Tp/$d/package.json" <<<"$out_p"; then
      echo "FAIL [4.$pbt_i]: subset='$subset' — $d/package.json não deveria estar presente"; FAIL=1
    fi
  done
done
[ "$FAIL" -eq 0 ] && echo "  ok: ${#subsets[@]} subconjunto(s) verificado(s)"

# ── [5] invocador real: doctor.sh::find_marker usa a lib, e doctor.sh roda de ponta a ponta ─────
echo "[5] invocador real: doctor.sh::find_marker consome forge_find_prune_args"
if ! grep -q 'forge_find_prune_args' "$DOCTOR_SRC"; then
  echo "FAIL [5]: doctor.sh não referencia forge_find_prune_args — lib continua órfã"; FAIL=1
else
  Td="$T/doctor-e2e"
  mkdir -p "$Td/node_modules" "$Td/vendor"
  echo '{"name":"root"}' > "$Td/package.json"
  echo '{"name":"nm"}' > "$Td/node_modules/package.json"
  echo '{"name":"vendor"}' > "$Td/vendor/package.json"
  git -C "$Td" init -q
  report="$(FORGE_ROOT="$Td" bash "$DOCTOR_SRC" --report 2>&1)"
  rc=$?
  if [ "$rc" -ge 2 ]; then
    echo "FAIL [5]: doctor.sh --report falhou (rc=$rc)"; echo "$report"; FAIL=1
  else
    echo "  ok: doctor.sh rodou (rc=$rc)"
  fi
fi

# ── [6] mutação: recolocar -false faz vendor reaparecer ─────────────────────────────────────────
echo "[6] mutação: -false de volta na cláusula faz vendor reaparecer"
LIB_MUT="$T/scan-exclude-mutated.sh"
cp "$LIB_SRC" "$LIB_MUT"
# injeta uma variante mutada de forge_find_prune_args que recoloca -false ao fim da cláusula —
# sem tocar no arquivo real: acrescenta uma função com outro nome que reintroduz o defeito (3).
cat >> "$LIB_MUT" <<'EOF'

forge_find_prune_args_MUTATED() {
  local __out="$1" pat _tmp=()
  for pat in $FORGE_SCAN_EXCLUDE; do
    if [ ${#_tmp[@]} -eq 0 ]; then _tmp+=('('); else _tmp+=('-o'); fi
    _tmp+=('-name' "$pat")
  done
  if [ ${#_tmp[@]} -gt 0 ]; then
    _tmp+=('-false' ')' '-prune' '-o')
  fi
  eval "$__out=(\"\${_tmp[@]}\")"
}
EOF
out_mut="$(bash -c '. "'"$LIB_MUT"'"; prune=(); forge_find_prune_args_MUTATED prune; find "'"$T"'" "${prune[@]}" -name package.json -print' | LC_ALL=C sort)"
if ! grep -qF "$T/vendor/package.json" <<<"$out_mut"; then
  echo "FAIL [6]: mutação (-false reintroduzido) deveria fazer vendor REAPARECER — gate não depende do desenho real"
  FAIL=1
else
  echo "  ok: mutante reintroduz o defeito (vendor reaparece), confirmando que o gate mede o mecanismo certo"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "GATE W255: FAIL"
  exit 1
fi
echo "GATE W255: PASS"
