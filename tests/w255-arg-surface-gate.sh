#!/usr/bin/env bash
# Gate W255 — superfície completa de argumentos de liaison-ops.sh, deferral-ops.sh e wave-ops.sh
# (issue #133): flag desconhecida aceita e flag engolida como valor de outra flag.
#
# Causa raiz: a guarda `forge_reject_flag_as_value` (lib/arg-guards.sh, issue #103) era aplicada
# por sítio, sem cobertura VERIFICÁVEL. 11 sítios de liaison-ops.sh liam "$2" cru
# (`--thread) filter_thread="$2"`), `deferral-ops.sh test/status` não recusavam argumento extra
# nenhum, e `wave-ops.sh` nem sequer sourceava a guarda.
#
#   [1]  liaison open --self --participants (2 flags com valor)
#   [2]  liaison inbox --thread (engolindo --show / --titles-only, os dois booleanos do subcomando)
#   [3]  liaison read --upto (flag única — self-par é o único caso possível)
#   [4]  liaison export --out (idem)
#   [5]  liaison import --from (idem)
#   [6]  liaison peer set --path (idem)
#   [7]  liaison transport set --kind/--path/--remote/--branch (4 flags, pares exaustivos)
#   [8]  deferral-ops test <id> <arg extra> — sem laço de parsing antes da #133, arg extra sumia
#   [9]  deferral-ops status <change> <arg extra> — idem, sem laço nenhum
#  [10]  wave-ops plan/open/close/status — arg extra recusado (script inteiro não sourceava a guarda)
#  [11]  wave-ops close --gate sem valor / --gate com flag-como-valor / flag desconhecida
#  [P]   controles de uso legítimo — todos os subcomandos acima em rc 0 com valores reais
#  [E]   teste ESTRUTURAL — enumera, em todo `*-ops.sh` do template, todo `--flag) x="$2"` que não
#        chama forge_reject_flag_as_value/forge_require_value na mesma linha; exige ZERO.
#  [M]   mutação — remover a guarda de `--thread` em `inbox` faz o par (thread, show) sair rc 0.
#
# Propriedade PBT (enumeração exaustiva, não amostragem): para cada subcomando e cada par (F, G)
# do seu conjunto de flags com valor (G pode repetir F quando o conjunto tem um elemento só),
# `cmd --F --G` sai rc≠0 citando G.
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem ao
# repositório de quem invoca o gate, não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/arvore-rastreada.sh"
REPO_SNAPSHOT_BEFORE="$(arvore_retrato "$WS" tudo)"

T="$(mktemp -d /tmp/forge-w255.XXXXXX)"
trap 'rm -rf "$T"' EXIT

_run_to() { # _run_to <segundos> -- <cmd...> — teto de tempo (macOS não tem `timeout` por padrão)
  local secs="$1"; shift
  [ "${1:-}" = "--" ] && shift
  perl -e "alarm $secs; exec @ARGV" -- "$@"
}

cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q
_run_to 20 -- git -C "$T" add -A
_run_to 20 -- git -C "$T" -c user.email=t@t -c user.name=t commit -qm init >/dev/null

LO="$T/.forge/scripts/liaison-ops.sh"
DFO="$T/.forge/scripts/deferral-ops.sh"
WO="$T/.forge/scripts/wave-ops.sh"

_lo()  { _run_to 20 -- env FORGE_ROOT="$T" bash "$LO" "$@"; }
_dfo() { _run_to 20 -- env FORGE_ROOT="$T" bash "$DFO" "$@"; }
_wo()  { _run_to 20 -- env FORGE_ROOT="$T" bash "$WO" "$@"; }

fails=0
_assert_rejects() { # _assert_rejects <label> <flag-citada> -- <cmd...>
  local label="$1" cited="$2"; shift 2
  [ "${1:-}" = "--" ] && shift
  local out rc
  set +e
  out="$("$@" 2>&1)"; rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL [$label]: '$*' devolveu rc=0 — got: $out"; fails=$((fails + 1)); return 1
  fi
  if ! grep -q -- "$cited" <<<"$out"; then
    echo "FAIL [$label]: mensagem não cita '$cited' — got: $out"; fails=$((fails + 1)); return 1
  fi
  echo "OK [$label] — $out" | head -1
  return 0
}

_assert_ok() { # _assert_ok <label> -- <cmd...>
  local label="$1"; shift
  [ "${1:-}" = "--" ] && shift
  local out rc
  set +e
  out="$("$@" 2>&1)"; rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "FAIL [$label]: '$*' devolveu rc=$rc — got: $out"; fails=$((fails + 1)); return 1
  fi
  echo "OK [$label] — $out" | head -1
  return 0
}

CHAN="canal-w255"
CH="ch-w255"
mkdir -p "$T/.forge/specs/active/$CH"

_lo open "$CHAN" --self repo-a --participants repo-a,repo-b >/dev/null

# =================================================================================================
# [1] liaison open --self --participants
# =================================================================================================
echo "== [1] liaison open =="
_assert_rejects 1a --participants -- _lo open canal-w255-open1 --self --participants
_assert_rejects 1b --self -- _lo open canal-w255-open2 --participants --self
_assert_ok 1c -- _lo open canal-w255-open3 --self repo-a --participants repo-a,repo-c

# =================================================================================================
# [2] liaison inbox --thread (engole --show / --titles-only)
# =================================================================================================
echo "== [2] liaison inbox =="
_assert_rejects 2a --show -- _lo inbox "$CHAN" --thread --show
_assert_rejects 2b --titles-only -- _lo inbox "$CHAN" --thread --titles-only
_assert_ok 2c -- _lo inbox "$CHAN" --thread th-inexistente

# =================================================================================================
# [3]-[6] flags únicas — self-par é o único par possível
# =================================================================================================
echo "== [3] liaison read --upto =="
_assert_rejects 3 --upto -- _lo read "$CHAN" --upto --upto

echo "== [4] liaison export --out =="
_assert_rejects 4 --out -- _lo export "$CHAN" --out --out
_assert_ok 4p -- _lo export "$CHAN" --out "$T/export-ok"

echo "== [5] liaison import --from =="
_assert_rejects 5 --from -- _lo import "$CHAN" --from --from

echo "== [6] liaison peer set --path =="
_assert_rejects 6 --path -- _lo peer set "$CHAN" repo-b --path --path

# =================================================================================================
# [7] liaison transport set --kind/--path/--remote/--branch — pares exaustivos
# =================================================================================================
echo "== [7] liaison transport set (pares exaustivos 4x4) =="
T_FLAGS=(--kind --path --remote --branch)
t7_bad=0
for f in "${T_FLAGS[@]}"; do
  for g in "${T_FLAGS[@]}"; do
    t7_n=$((${t7_n:-0} + 1))
    set +e
    out="$(_lo transport set "$CHAN" "$f" "$g" 2>&1)"; rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
      echo "FAIL [7]: 'transport set $f $g' devolveu rc=0 — got: $out"; t7_bad=$((t7_bad + 1)); continue
    fi
    grep -q -- "$g" <<<"$out" || { echo "FAIL [7]: 'transport set $f $g' não cita '$g' — got: $out"; t7_bad=$((t7_bad + 1)); }
  done
done
[ "$t7_bad" -eq 0 ] || { echo "FAIL [7]: $t7_bad de $t7_n pares aceitaram flag como valor"; exit 1; }
echo "OK [7] — $t7_n pares (4x4) recusados"
_assert_ok 7p -- _lo transport set "$CHAN" --kind fs --path "$T/hub-w255"

# =================================================================================================
# [8]-[9] deferral-ops test/status — argumento extra sem laço de parsing antes da #133
# =================================================================================================
echo "== [8] deferral-ops test <id> <arg extra> =="
_dfo raise "$CH" --reason "motivo w255" >/dev/null
_assert_rejects 8 lixo -- _dfo test "$CH" DEFER-01 --lixo
set +e
_dfo resolve "$CH" DEFER-01 --note "resolvido para o teste" >/dev/null 2>&1
set -e
_assert_ok 8p -- _dfo test "$CH" DEFER-01

echo "== [9] deferral-ops status <change> <arg extra> =="
_assert_rejects 9 lixo -- _dfo status "$CH" --lixo x
_assert_ok 9p -- _dfo status "$CH"

# =================================================================================================
# [10]-[11] wave-ops — script inteiro não sourceava a guarda
# =================================================================================================
echo "== [10] wave-ops plan/open/status — argumento extra recusado =="
mkdir -p "$T/.forge/specs/active/$CH/stories"
cat > "$T/.forge/specs/active/$CH/stories/S1.md" <<'EOF'
---
story_id: S1
depends_on: []
---
EOF
_assert_rejects 10a lixo -- _wo plan "$CH" --lixo
_assert_ok 10a-p -- _wo plan "$CH"
_assert_rejects 10b lixo -- _wo open "$CH" W0 --lixo
_assert_ok 10b-p -- _wo open "$CH" W0
_assert_rejects 10c lixo -- _wo status "$CH" --lixo

echo "== [11] wave-ops close --gate =="
_assert_rejects 11a "--gate" -- _wo close "$CH" W0 --gate
_assert_rejects 11b "--gate" -- _wo close "$CH" W0 --gate --gate
_assert_rejects 11c lixo -- _wo close "$CH" W0 --lixo
_assert_ok 11p -- _wo close "$CH" W0 --gate OK

[ "$fails" -eq 0 ] || { echo "FAIL: $fails cenário(s) reprovaram acima"; exit 1; }

# =================================================================================================
# [E] Teste ESTRUTURAL — universo de sítios `--flag) x="$2"` sem guarda em *-ops.sh, exige ZERO.
# =================================================================================================
echo "== [E] estrutural — sítios sem guarda em template/.forge/scripts/*-ops.sh =="
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
unguarded=0
unguarded_lines=""
for f in "$WS"/template/.forge/scripts/*-ops.sh; do
  # Sítio candidato: `--flag) var="$2"` (com ou sem indentação/espaços). Sem guarda: a MESMA linha
  # não chama forge_reject_flag_as_value nem forge_require_value.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # ledger-ops.sh chama a guarda através de um alias local fino (`_require_value() { forge_require_value "$@"; }`)
    # — reconhecido aqui porque delega ao mesmo primitivo, sem reimplementar pertencimento.
    if ! grep -q "forge_reject_flag_as_value\|forge_require_value\|_require_value" <<<"$line"; then
      unguarded=$((unguarded + 1))
      unguarded_lines="$unguarded_lines
$(basename "$f"): $line"
    fi
  done < <(grep -nE '^\s*--[a-zA-Z0-9-]+\).*[a-zA-Z_][a-zA-Z0-9_]*="\$2"' "$f" || true)
done
if [ "$unguarded" -ne 0 ]; then
  echo "FAIL [E]: $unguarded sítio(s) SEM guarda encontrados:$unguarded_lines"
  exit 1
fi
# Universo não-vazio: os scripts *-ops.sh existem e têm pelo menos um sítio TOTAL (guardado ou não)
# — sem isso, um glob que não casa nada aprovaria em silêncio.
total_sites=0
for f in "$WS"/template/.forge/scripts/*-ops.sh; do
  n="$(grep -cE '^\s*--[a-zA-Z0-9-]+\).*[a-zA-Z_][a-zA-Z0-9_]*="\$2"' "$f" || true)"
  total_sites=$((total_sites + n))
done
forge_universe_check "w255/arg-surface" "$total_sites" "sítio(s) --flag) x=\$2 em *-ops.sh" "varredura estrutural [E]" "$WS" \
  || { echo "FAIL [E]: universo de sítios vazio aprovaria em silêncio"; exit 1; }
echo "OK [E] — $total_sites sítio(s) examinados no template, 0 sem guarda"

# =================================================================================================
# [M] Mutação — remover a guarda de --thread em inbox faz o par (thread, show) sair rc 0.
# =================================================================================================
echo "== [M] mutação — remoção da guarda de --thread em inbox =="
LOORIG="$T/liaison-ops.orig"
cp "$LO" "$LOORIG"

_scn_m_rejects() { set +e; local o r; o="$(_lo inbox "$CHAN" --thread --show 2>&1)"; r=$?; set -e; [ "$r" -ne 0 ] && grep -q -- "--show" <<<"$o"; }

_scn_m_rejects || { echo "FAIL [M]: pré-condição — inbox --thread --show não reprova antes da mutação"; exit 1; }

perl -0pi -e 's/--thread\) forge_reject_flag_as_value inbox --thread "\$\{2-\}" "--thread, --show, --titles-only"; filter_thread="\$2"; shift 2 ;;/--thread) filter_thread="\$2"; shift 2 ;;/' "$LO"
cmp -s "$LO" "$LOORIG" && { echo "FAIL [M]: perl não alterou liaison-ops.sh — regex não casou"; exit 1; }

if _scn_m_rejects; then
  echo "FAIL [M]: inbox --thread --show AINDA reprova depois de remover a guarda — mutação não muta nada"; exit 1
fi

cp "$LOORIG" "$LO"
cmp -s "$LO" "$LOORIG" || { echo "FAIL [M]: restauração de liaison-ops.sh não bateu byte a byte"; exit 1; }
_scn_m_rejects || { echo "FAIL [M]: recontrole — inbox --thread --show não voltou a reprovar depois da restauração"; exit 1; }
echo "OK [M] — mutação reintroduziu o defeito isoladamente; restauração e recontrole OK"

# ── sentinela do repositório real: nada vazou do sandbox ───────────────────────────────────────
arvore_sentinela_fim "$WS" "$REPO_SNAPSHOT_BEFORE" "w255-arg-surface" tudo || exit $?

echo "PASS w255-arg-surface"
