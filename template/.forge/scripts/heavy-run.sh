#!/usr/bin/env bash
# heavy-run.sh — executa um comando sob o mutex de carga pesada da MÁQUINA (issue #52).
#
# Existe porque a carga que mais disputa CPU e daemon Docker nasce FORA do `git push` e nunca
# passaria por um hook: `dotnet test` da suíte completa, `gradle`, `docker compose up --build`.
#
# Superset estrito do contrato publicado no canal `axis-contracts` (`axis-go-cloud-0127`):
#   - `--` obrigatório antes do comando;
#   - stdout pertence INTEIRAMENTE ao comando, telemetria só em stderr — a saída de suíte pesada é
#     parseada por terceiros, e uma linha nossa no meio quebra quem consome;
#   - exit code do comando propagado sem tradução;
#   - `64` uso inválido · `69` âncora inutilizável · `75` timeout com o comando NÃO executado ·
#     `130`/`143`/`129` para INT/TERM/HUP, com o comando morto antes e o lock liberado na hora.
#
# `69` e `75` são deliberadamente distintos: um diz "espere", o outro diz "conserte a máquina".
#
# O shebang passou de `sh` para `bash`: a biblioteca usa `[ -O ]`, `[ -k ]`, `BASH_SUBSHELL`,
# `trap -p` e `10#`. É item explícito da migração.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/heavy-mutex.sh"
# Delegação em alvo ausente é ERRO, não no-op (issue #49, instância 4): se o diretório da
# biblioteca existe e o arquivo não, a instalação está pela metade e seguir sem mutex é rodar
# carga pesada desprotegida em silêncio.
if [ ! -f "$LIB" ] && [ -d "$SCRIPT_DIR/lib" ]; then
  echo "heavy-run: $SCRIPT_DIR/lib/ existe e heavy-mutex.sh não — delegação em alvo ausente." >&2
  exit 69
fi
[ -f "$LIB" ] || { echo "heavy-run: biblioteca do mutex não encontrada em $LIB" >&2; exit 69; }
# shellcheck disable=SC1090
. "$LIB"

_hr_usage() {
  echo "uso: heavy-run.sh [--resource <n>] [--label <t>] -- <comando> [args...]" >&2
  echo "     heavy-run.sh status|sweep [--resource <n>] [--legacy]" >&2
  echo "     heavy-run.sh queue enable|disable|state [--resource <n>]" >&2
}

# Aliases de compatibilidade. Existem para não exigir reescrita da memória muscular de quem opera
# as máquinas — mas dois nomes da MESMA grandeza com valores diferentes é ERRO, nunca precedência
# silenciosa: escolher um em silêncio é como uma configuração deixa de ser lida sem ninguém notar.
_hr_alias() {  # _hr_alias <destino> <nome-a> <valor-a> <nome-b> <valor-b> [multiplicador-b]
  local dest="$1" na="$2" va="$3" nb="$4" vb="$5" mult="${6:-1}" vbn
  if [ -n "$vb" ]; then vbn=$(( vb * mult )); else vbn=""; fi
  if [ -n "$va" ] && [ -n "$vbn" ] && [ "$va" != "$vbn" ]; then
    echo "heavy-run: $na=$va e $nb=$vb dizem a mesma coisa com valores diferentes — corrija um dos dois." >&2
    return 64
  fi
  if [ -n "$va" ]; then printf '%s' "$va"; elif [ -n "$vbn" ]; then printf '%s' "$vbn"; fi
  return 0
}

RES=""; LABEL=""; SUB=""
case "${1:-}" in
  status|sweep|queue) SUB="$1"; shift ;;
esac

LEGACY=0; QACT=""
if [ "$SUB" = "queue" ]; then
  QACT="${1:-}"; shift || true
  case "$QACT" in enable|disable|state) : ;; *) _hr_usage; exit 64 ;; esac
fi

ARGS_OK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --resource) RES="${2:-}"; shift 2 ;;
    --label) LABEL="${2:-}"; shift 2 ;;
    --legacy) LEGACY=1; shift ;;
    --) shift; ARGS_OK=1; break ;;
    -*) echo "heavy-run: flag desconhecida '$1'" >&2; _hr_usage; exit 64 ;;
    *) echo "heavy-run: argumento inesperado '$1' (o comando vem depois de '--')" >&2; _hr_usage; exit 64 ;;
  esac
done

[ -n "$RES" ] && { FORGE_HEAVY_MUTEX_RESOURCE="$RES"; export FORGE_HEAVY_MUTEX_RESOURCE; }

# Resolve o caminho dos sidecars para os subcomandos de operação.
_hr_paths() {
  local pp; pp="$(forge_heavy_mutex_path)" || return 69
  HR_LOCK="${pp%%	*}"
  HR_BASE="${HR_LOCK%.lock}"
}

case "$SUB" in
  status)
    _hr_paths || exit 69
    forge_heavy_mutex_status
    exit $?
    ;;
  queue)
    _hr_paths || exit 69
    case "$QACT" in
      enable)  : > "$HR_BASE.q.enabled" && echo "heavy-run: fila LIGADA para $HR_BASE" >&2 ;;
      disable) rm -f "$HR_BASE.q.enabled" && echo "heavy-run: fila DESLIGADA para $HR_BASE" >&2 ;;
      state)   [ -f "$HR_BASE.q.enabled" ] && echo "LIGADA" || echo "DESLIGADA" ;;
    esac
    exit 0
    ;;
  sweep)
    _hr_paths || exit 69
    n=0
    if [ -d "$HR_LOCK" ]; then
      hp="$(cat "$HR_LOCK/pid" 2>/dev/null || echo '')"
      ht="$(cat "$HR_LOCK/token" 2>/dev/null || echo '')"
      if [ -n "$hp" ] && ! _fhm_alive "$hp" "$ht"; then
        _FHM_LOCK="$HR_LOCK" _fhm_reclaim_orphan "$hp" && n=$((n+1))
      fi
    fi
    echo "heavy-run: sweep — $n lock(s) órfão(s) removido(s)" >&2
    if [ "$LEGACY" = "1" ]; then
      # Caminhos LEGADOS derivados de TMPDIR. É o instrumento que teria transformado catorze horas
      # de bloqueio invisível numa linha: um lock em `$TMPDIR/...` não é visto por quem resolve
      # `/tmp/...`, e nenhuma detecção de órfão alcança o arquivo que ela não está olhando.
      base="$(basename "$HR_BASE")"
      for cand in "${TMPDIR:-/tmp}/$base.lock" "/tmp/$base.lock"; do
        [ "$cand" = "$HR_LOCK" ] && continue
        [ -d "$cand" ] || continue
        lp="$(cat "$cand/pid" 2>/dev/null || echo '?')"
        echo "heavy-run: LEGADO vivo em $cand (pid $lp) — este caminho NÃO serializa com $HR_LOCK" >&2
      done
    fi
    exit 0
    ;;
esac

[ "$ARGS_OK" = "1" ] && [ $# -gt 0 ] || { echo "heavy-run: comando obrigatório após '--'" >&2; _hr_usage; exit 64; }

TMO="$(_hr_alias FORGE_HEAVY_MUTEX_TIMEOUT_S FORGE_HEAVY_MUTEX_TIMEOUT_S "${FORGE_HEAVY_MUTEX_TIMEOUT_S:-}" HEAVY_RUN_TIMEOUT_SECONDS "${HEAVY_RUN_TIMEOUT_SECONDS:-}")" || exit 64
[ -n "$TMO" ] || TMO="$(_hr_alias t x "" AXIS_HEAVY_SUITE_WAIT "${AXIS_HEAVY_SUITE_WAIT:-}" 60)" || exit 64
[ -n "$TMO" ] && { FORGE_HEAVY_MUTEX_TIMEOUT_S="$TMO"; export FORGE_HEAVY_MUTEX_TIMEOUT_S; }
POLL="$(_hr_alias p FORGE_HEAVY_MUTEX_POLL_S "${FORGE_HEAVY_MUTEX_POLL_S:-}" HEAVY_RUN_POLL_SECONDS "${HEAVY_RUN_POLL_SECONDS:-}")" || exit 64
[ -n "$POLL" ] && { FORGE_HEAVY_MUTEX_POLL_S="$POLL"; export FORGE_HEAVY_MUTEX_POLL_S; }

forge_heavy_mutex_acquire --label "${LABEL:-$*}" || exit $?

# Aqui o wrapper é DONO do próprio processo e não hospeda handler de terceiro — por isso o
# re-raise é incondicional e os códigos 130/143/129 do contrato se mantêm. A biblioteca, que vive
# dentro do processo alheio, não pode ter a mesma regra: lá a transparência manda.
HR_CHILD=""
_hr_sig() {
  [ -n "$HR_CHILD" ] && kill -"$1" "$HR_CHILD" 2>/dev/null
  forge_heavy_mutex_release
  trap - "$1"
  kill -"$1" $$
}
trap 'forge_heavy_mutex_release' EXIT
for s in INT TERM HUP; do trap "_hr_sig $s" "$s"; done

"$@" &
HR_CHILD=$!
wait "$HR_CHILD"
rc=$?
forge_heavy_mutex_release
exit "$rc"
