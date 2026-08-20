#!/usr/bin/env bash
# lib/heavy-mutex.sh — mutex por MÁQUINA para carga pesada (issue #52).
#
# ONDA W1 — âncora. A W0 importou o protocolo legado como linha de base; esta onda ancora o
# caminho. Este arquivo nasceu como cópia fiel do protocolo que os quatro
# repositórios do canal `axis-contracts` já usam, importado de `Axis.PadSimulator`
# (`.forge/hooks/git/lib/heavy-mutex.sh`) e de `axis-go-cloud`
# (`.githooks/pre-push.d/06-dotnet-suites.sh:105-129`), com os nomes ajustados à API do harness.
#
# Importar o defeito antes de corrigi-lo é deliberado: a partir daqui todo Vermelho da suíte é
# COMPORTAMENTAL contra código real, e não "arquivo não existe" — que não é Vermelho legítimo,
# porque não distingue "a proteção falta" de "a proteção falhou". É também o que dá a linha de
# base contra a qual medir as correções (rule `testing/regression-red-first.md`).
#
# Os dois defeitos que as ondas seguintes corrigem, ambos medidos em campo:
#
#   1. O lock resolve por `$TMPDIR`, que no macOS é por usuário e por contexto de invocação —
#      quatro valores distintos observados ativos na mesma máquina. Duas suítes pesadas adquirem
#      cada uma o seu lock privado e rodam juntas, contaminando exatamente a medição que o mutex
#      existe para proteger.
#   2. `while ! mkdir` é exclusão mútua sem ORDEM. Quem solta e retoma já está a poucas instruções
#      do `mkdir`; quem espera de fora dorme num intervalo de polling. A janela livre é de
#      microssegundos contra segundos, então a chance não melhora com paciência: é inanição, não
#      lentidão. Medido: 1305 segundos de fila para descobrir um erro de sintaxe de 8 segundos.
#
# A ordem de correção é inegociável — ancorar o caminho ANTES de enfileirar. Uma fila por
# `$TMPDIR` é tão particionada quanto um lock por `$TMPDIR`, e o efeito seria duas filas justas
# disputando o mesmo daemon Docker.
LC_ALL=C
export LC_ALL

_FHM_LOCK=""
_FHM_OWNED="false"

# 0 quando <pid> é ancestral deste processo. Reentrância por LINHAGEM, não por variável de
# ambiente: quem empurra via `heavy-run.sh -- git push` já detém o lock, e o wrapper não exporta
# marcador algum. Se o hook tentasse readquirir, o push recusaria a si mesmo.
_fhm_is_ancestor() {
  local target="$1" cur="$$" hops=0
  case "$target" in ''|*[!0-9]*) return 1 ;; esac
  # Teto de saltos: uma cadeia de PPID corrompida (ou um PID reciclado apontando para si) não pode
  # transformar a checagem em laço infinito dentro de um hook de push.
  while [ "$cur" -gt 1 ] && [ "$hops" -lt 64 ]; do
    [ "$cur" = "$target" ] && return 0
    cur="$(ps -o ppid= -p "$cur" 2>/dev/null | tr -d '[:space:]')"
    [ -n "$cur" ] || return 1
    hops=$((hops + 1))
  done
  return 1
}


# ── âncora (D1) ──────────────────────────────────────────────────────────────────────────────────
# TRÊS alvos, TRÊS regimes, porque duas coisas diferentes estão sendo validadas: validamos POSSE do
# que criamos e PROPRIEDADES do que o sistema fornece. Misturar os dois transforma a trava de
# squatting numa recusa universal — medido: `/tmp` no macOS é symlink para `private/tmp` e nos dois
# SOs pertence ao root, então a regra estrita `-L ⇒ erro; -O falso ⇒ erro` recusaria a própria
# âncora default, em toda instalação.
_fhm_die69() { echo "heavy-mutex: $1" >&2; return 69; }

_fhm_resolve_root() {  # ecoa "<root>\t<proveniência>"; rc 69 se inutilizável
  local root="${FORGE_HEAVY_MUTEX_ROOT:-}" tab
  tab="$(printf '\t')"
  if [ -n "$root" ]; then
    # Declarada por quem chama: regime ESTRITO. `-L` primeiro, porque `-d` e `-O` seguem symlink.
    [ -L "$root" ] && { _fhm_die69 "FORGE_HEAVY_MUTEX_ROOT '$root' é um symlink — recusado. Um terceiro que plante o nome desvia o lock em silêncio, e `mkdir -p` aceitaria."; return 69; }
    if [ ! -d "$root" ]; then
      # `mkdir` simples, nunca `-p` e nunca `-m`: medido, `mkdir -p` ACEITA symlink pré-existente e
      # o `pwd -P` segue o link; e `-p` sobre diretório existente não corrige permissão.
      mkdir "$root" 2>/dev/null || { _fhm_die69 "não consegui criar FORGE_HEAVY_MUTEX_ROOT '$root'"; return 69; }
    fi
    [ -O "$root" ] || { _fhm_die69 "FORGE_HEAVY_MUTEX_ROOT '$root' não pertence ao uid corrente — recusado."; return 69; }
    printf '%s%sFORGE_HEAVY_MUTEX_ROOT (isolado — não serializa com o resto da máquina)\n' "$root" "$tab"
    return 0
  fi
  # Default fornecido pelo sistema: exigir `-d`, `-w` e `-k` (sticky). NUNCA `-L`, NUNCA `-O`.
  # E NÃO normalizar com `pwd -P`: o caminho precisa ser a MESMA STRING que o legado imprime e
  # resolve, porque comparar diagnósticos entre migrado e legado é o instrumento de detecção de
  # partição durante toda a migração.
  root="/tmp"
  [ -d "$root" ] || { _fhm_die69 "'$root' não existe"; return 69; }
  [ -w "$root" ] || { _fhm_die69 "'$root' não é gravável"; return 69; }
  [ -k "$root" ] || { _fhm_die69 "'$root' não tem sticky bit — recusado: um diretório mundialmente gravável sem sticky permite que terceiro remova o lock alheio."; return 69; }
  printf '%s%sdefault fixo /tmp\n' "$root" "$tab"
  return 0
}

_fhm_resource() {
  local r="${FORGE_HEAVY_MUTEX_RESOURCE:-}"
  [ -n "$r" ] || r="forge-heavy-suite"
  printf '%s' "$r"
}

# Sidecar que NÓS criamos: regime estrito, igual à âncora declarada.
_fhm_ensure_sidecar() {  # _fhm_ensure_sidecar <caminho>
  local d="$1"
  [ -L "$d" ] && { _fhm_die69 "sidecar '$d' é um symlink — recusado."; return 69; }
  if [ ! -d "$d" ]; then
    mkdir "$d" 2>/dev/null || { _fhm_die69 "não consegui criar o sidecar '$d'"; return 69; }
  fi
  [ -O "$d" ] || { _fhm_die69 "sidecar '$d' não pertence ao uid corrente — recusado."; return 69; }
  return 0
}

forge_heavy_mutex_path() {
  local res rr root prov tab
  tab="$(printf '\t')"
  res="$(_fhm_resource)"
  while [ $# -gt 0 ]; do
    case "$1" in
      --resource) res="$2"; shift 2 ;;
      *) echo "heavy-mutex: argumento desconhecido '$1'" >&2; return 64 ;;
    esac
  done
  rr="$(_fhm_resolve_root)" || return 69
  root="${rr%%$tab*}"; prov="${rr#*$tab}"
  printf '%s/%s.lock%s%s\n' "$root" "$res" "$tab" "$prov"
  return 0
}

forge_heavy_mutex_acquire() {
  local label="carga pesada" timeout="${FORGE_HEAVY_MUTEX_TIMEOUT_S:-1800}" waited=0 holder
  while [ $# -gt 0 ]; do
    case "$1" in
      --label) label="$2"; shift 2 ;;
      --timeout) timeout="$2"; shift 2 ;;
      *) echo "heavy-mutex: argumento desconhecido '$1'" >&2; return 64 ;;
    esac
  done

  local rr root prov res tab
  tab="$(printf '\t')"
  res="$(_fhm_resource)"
  rr="$(_fhm_resolve_root)" || return 69
  root="${rr%%$tab*}"; prov="${rr#*$tab}"
  _fhm_ensure_sidecar "$root/$res.q" || return 69
  _FHM_LOCK="$root/$res.lock"

  # DEFEITO 2, importado de propósito nesta onda: polling sem fila.
  while ! mkdir "$_FHM_LOCK" 2>/dev/null; do
    holder="$(cat "$_FHM_LOCK/pid" 2>/dev/null || echo '')"

    if [ -n "$holder" ] && _fhm_is_ancestor "$holder"; then
      echo "heavy-mutex: lock já detido por processo ancestral (PID $holder) — seguindo sem readquirir." >&2
      _FHM_OWNED="false"
      FORGE_HEAVY_MUTEX_REENTRANT=1
      export FORGE_HEAVY_MUTEX_REENTRANT
      return 0
    fi

    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
      echo "heavy-mutex: lock órfão de PID $holder removido (processo não existe mais)." >&2
      rm -rf "$_FHM_LOCK"
      continue
    fi

    if [ "$waited" -ge "$timeout" ]; then
      echo "heavy-mutex: TIMEOUT após ${waited}s esperando o mutex da máquina." >&2
      echo "  lock ........ $_FHM_LOCK (âncora: $prov)" >&2
      echo "  detentor .... PID ${holder:-desconhecido}" >&2
      return 75
    fi
    # `${label}` com chaves e o texto seguinte separado: `$label…` fez o bash tratar a reticência
    # multibyte como parte do NOME da variável, e o hook morria com "unbound variable" sob `set -u`.
    if [ "$waited" = 0 ]; then
      echo "heavy-mutex: AGUARDANDO — ${label}" >&2
      echo "  lock ........ $_FHM_LOCK (âncora: $prov)" >&2
      echo "  detentor .... PID ${holder:-'?'}" >&2
    fi
    sleep 1
    waited=$((waited + 1))
  done

  printf '%s\n' "$$" > "$_FHM_LOCK/pid"
  _FHM_OWNED="true"
  # Recibo SEMPRE, mesmo sem contenção: é o análogo do contador de controle para um primitivo que
  # não itera universo. Sem ele, "rodei com o mutex e não houve disputa" e "rodei sem o mutex
  # porque a biblioteca sumiu" produzem o MESMO silêncio no log.
  echo "heavy-mutex: adquirido — $_FHM_LOCK (âncora: $prov), recurso $res, espera ${waited}s" >&2
  FORGE_HEAVY_MUTEX_HELD_PATH="$_FHM_LOCK"
  export FORGE_HEAVY_MUTEX_HELD_PATH
  return 0
}

# Libera SÓ o que é nosso. Liberar lock alheio é pior que vazar o próprio: o vazamento é
# reclamado em minutos pela detecção de órfão, a liberação indevida põe duas suítes a rodar já.
forge_heavy_mutex_release() {
  [ "$_FHM_OWNED" = "true" ] || return 0
  [ -n "$_FHM_LOCK" ] || return 0
  local holder
  holder="$(cat "$_FHM_LOCK/pid" 2>/dev/null || echo '')"
  [ "$holder" = "$$" ] && rm -rf "$_FHM_LOCK"
  _FHM_OWNED="false"
  return 0
}
