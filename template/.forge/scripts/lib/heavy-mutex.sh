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
_FHM_NONCE=""
_FHM_QDIR=""
_FHM_QSWITCH=""
_FHM_TICKET=""
_FHM_WAIT_START=""
_FHM_CLOCK="hires"

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
  # TRAVA DE TESTE — asserção POSITIVA, não backstop. Um backstop por "existência antes/depois" não
  # detecta um cenário que crie E remova o lock real, porque "inexistente" bate nas duas pontas.
  # Com esta trava, um cenário que esqueça de montar a caixa falha alto em vez de tocar o /tmp da
  # máquina — e a suíte jamais vira a carga que o mutex existe para impedir. Aconteceu de verdade
  # durante a implementação: os cenários da onda W0 isolavam por TMPDIR, a W1 passou a ignorar
  # TMPDIR, e a suíte criou o sidecar no /tmp real sem que nada reclamasse.
  if [ "${FORGE_HEAVY_MUTEX_TESTING:-}" = "1" ] && [ -z "$root" ]; then
    _fhm_die69 "FORGE_HEAVY_MUTEX_TESTING=1 exige FORGE_HEAVY_MUTEX_ROOT — recusado para não tocar o lock real da máquina."
    return 69
  fi
  if [ -n "$root" ]; then
    # Declarada por quem chama: regime ESTRITO. `-L` primeiro, porque `-d` e `-O` seguem symlink.
    [ -L "$root" ] && { _fhm_die69 "FORGE_HEAVY_MUTEX_ROOT '$root' é um symlink — recusado. Um terceiro que plante o nome desvia o lock em silêncio, e `mkdir -p` aceitaria."; return 69; }
    if [ ! -d "$root" ]; then
      # `mkdir` simples, nunca `-p` e nunca `-m`: medido, `mkdir -p` ACEITA symlink pré-existente e
      # o `pwd -P` segue o link; e `-p` sobre diretório existente não corrige permissão.
      #
      # O `mkdir` que falha porque OUTRO acabou de criar não é âncora inutilizável — é corrida
      # benigna, e é o caso comum quando N consumidores sobem juntos. Confundir os dois faz o
      # primeiro a chegar vencer e todos os demais receberem 69: medido com cinco concorrentes,
      # quatro morriam assim. Reconferimos o estado antes de reprovar.
      mkdir "$root" 2>/dev/null || [ -d "$root" ] || { _fhm_die69 "não consegui criar FORGE_HEAVY_MUTEX_ROOT '$root'"; return 69; }
      [ -L "$root" ] && { _fhm_die69 "FORGE_HEAVY_MUTEX_ROOT '$root' virou symlink durante a criação — recusado."; return 69; }
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
    # Mesma corrida benigna da âncora declarada: com N consumidores subindo juntos, só um vence o
    # `mkdir` e os demais receberiam 69 sobre um sidecar que existe e é válido.
    mkdir "$d" 2>/dev/null || [ -d "$d" ] || { _fhm_die69 "não consegui criar o sidecar '$d'"; return 69; }
    [ -L "$d" ] && { _fhm_die69 "sidecar '$d' virou symlink durante a criação — recusado."; return 69; }
  fi
  [ -O "$d" ] || { _fhm_die69 "sidecar '$d' não pertence ao uid corrente — recusado."; return 69; }
  return 0
}


# ── identidade e liveness (D3) ───────────────────────────────────────────────────────────────────
# `kill -0` NÃO serve para liveness aqui, e a razão é medida: devolve `Operation not permitted`
# para processo VIVO de outro uid — classificando-o como morto — e devolve 0 para ZUMBI, que já
# não segura recurso nenhum. Uma única chamada de `ps` entrega liveness E token, funciona entre
# uids e elimina as duas assimetrias.
#
# `LC_ALL=C` é obrigatório e `LC_TIME` sozinho basta para quebrar: o mesmo PID rende
# `Thu Aug 20 13:53:00 2026` sob C e `qui 20 ago 13:53:00 2026` sob pt_BR. Sem fixar, o token
# gravado por um processo nunca bateria com o recomputado por outro de locale diferente.
# Há padding à direita em `lstart` e em `state`, daí o trim.
_fhm_token() {  # _fhm_token <pid>
  LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | tr -s ' ' | sed 's/^ *//;s/ *$//'
}

# Só o PRIMEIRO caractere interessa: medido, o macOS produz `S`, `R`, `Z` e `Ss` para o pid 1, e o
# Linux produz `S` e `Z`. Casar o primeiro caractere funciona nos dois.
_fhm_state1() {  # _fhm_state1 <pid>
  LC_ALL=C ps -o state= -p "$1" 2>/dev/null | sed 's/^ *//' | cut -c1
}

_fhm_alive() {  # _fhm_alive <pid> <token-gravado> — 0 se vivo E é o mesmo processo
  local pid="$1" want="$2" now st
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  now="$(_fhm_token "$pid")"
  [ -n "$now" ] || return 1
  st="$(_fhm_state1 "$pid")"
  [ "$st" = "Z" ] && return 1
  # Token gravado ausente é lock do protocolo LEGADO: ele não grava token. Aí a única identidade
  # disponível é o PID, e tratamos como vivo — recusar seria remover lock legado vivo, que é
  # exatamente o dano que a interoperabilidade existe para impedir.
  [ -n "$want" ] || return 0
  [ "$now" = "$want" ]
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


# ── fila FIFO (D4) ───────────────────────────────────────────────────────────────────────────────
# DUAS CAMADAS, e a de justiça nunca enfraquece a de segurança. Segurança é o `mkdir`: se dois
# tentam, um perde, sempre. Justiça é: só TENTA quem é cabeça da fila. No empate, ambos tentam, o
# `mkdir` decide, o perdedor volta a esperar — a injustiça fica confinada a microssegundos, contra
# os minutos que a fila ordena.
#
# Por que a fila NÃO pode ser o mecanismo de exclusão: P1 lê o relógio e é desescalonado antes de
# criar o ticket; P2 lê depois, cria, varre, vê-se sozinho e entra; P1 volta, cria o ticket mais
# antigo, varre, julga-se o menor e TAMBÉM entra. A ordem de leitura do relógio e a ordem de
# visibilidade da criação não são a mesma ordem, e resolução de relógio nenhuma conserta isso.
#
# Por que isso mata a inanição medida: quem solta e retoma é um PROCESSO NOVO — pega ticket novo,
# vai para o fim. Estar a poucas instruções do `mkdir` deixa de ser o que decide.

# Microssegundos em 20 dígitos: a ordem lexicográfica do glob passa a coincidir com a numérica.
# Sem `perl`, cai para resolução de 1s arredondando para CIMA — medido, truncar para baixo dá ao
# degradado até 1 segundo de vantagem sistemática, e ele furaria a fila de todo mundo do segundo.
_fhm_now_us20() {
  local us
  us="$(perl -MTime::HiRes -e 'printf "%.0f", Time::HiRes::time()*1000000' 2>/dev/null)"
  if [ -n "$us" ]; then _FHM_CLOCK="hires"; else _FHM_CLOCK="degradado"; us="$(date +%s)999999"; fi
  printf '%020d' "$us" 2>/dev/null || printf '%020d' 0
}

_fhm_queue_enabled() { [ -f "$_FHM_QSWITCH" ]; }

# Recolhe o PRÓPRIO ticket. Remoção SIMÉTRICA à criação: `mv` para `.reaping.` e só então
# `rm -rf`. Medido, a criação por staging+`mv` nunca é observada parcial, mas o `rm -rf` direto
# produz observações de ticket sem `pid`/`token`; a assimetria estava na ponta errada.
_fhm_leave_queue() {
  [ -n "${_FHM_TICKET:-}" ] || return 0
  [ -d "$_FHM_TICKET" ] || { _FHM_TICKET=""; return 0; }
  local reap="$_FHM_QDIR/.reaping.$(basename "$_FHM_TICKET").${_FHM_NONCE:-x}"
  mv "$_FHM_TICKET" "$reap" 2>/dev/null && rm -rf "$reap" 2>/dev/null
  _FHM_TICKET=""
  return 0
}

# Enfileira com o carimbo dado, com PÓS-VERIFICAÇÃO obrigatória. `mv src dst` com `dst` existente
# devolve rc 0 e ANINHA (medido nos dois SOs): sem conferir, o processo acredita ter enfileirado,
# o ticket no disco pertence a outro, ele nunca é cabeça, e volta ao timeout sobre recurso livre —
# o estado absorvente reproduzido pelo código que o corrige.
_fhm_enqueue() {  # _fhm_enqueue <us20>
  local stamp="$1" stag dest
  stag="$_FHM_QDIR/.staging.$$.$stamp"
  rm -rf "$stag" 2>/dev/null
  mkdir -p "$stag" 2>/dev/null || return 1
  printf '%s\n' "$$" > "$stag/pid" || return 1
  printf '%s\n' "$(_fhm_token "$$")" > "$stag/token" 2>/dev/null
  dest="$_FHM_QDIR/$stamp.$$"
  mv "$stag" "$dest" 2>/dev/null || { rm -rf "$stag"; return 1; }
  if [ ! -f "$dest/pid" ] || [ "$(cat "$dest/pid" 2>/dev/null)" != "$$" ]; then
    echo "heavy-mutex: destino de ticket ocupado por terceiro — reenfileirando com carimbo novo" >&2
    rm -rf "$dest/.staging.$$.$stamp" 2>/dev/null
    return 1
  fi
  _FHM_TICKET="$dest"
  return 0
}

# Menor ticket VIVO. Varre e recolhe mortos no caminho, idempotentemente, por qualquer participante.
_fhm_head_ticket() {
  local f base tpid ttok head=""
  for f in "$_FHM_QDIR"/*; do
    [ -d "$f" ] || continue
    base="$(basename "$f")"
    tpid="$(cat "$f/pid" 2>/dev/null || echo '')"
    ttok="$(cat "$f/token" 2>/dev/null || echo '')"
    if [ -z "$tpid" ] || ! _fhm_alive "$tpid" "$ttok"; then
      mv "$f" "$_FHM_QDIR/.reaping.$base.dead" 2>/dev/null && rm -rf "$_FHM_QDIR/.reaping.$base.dead" 2>/dev/null
      continue
    fi
    [ -z "$head" ] && head="$base"
  done
  printf '%s' "$head"
}


# Reivindica e remove um lock ÓRFÃO com exclusividade.
#
# Por que não basta `rm -rf`: a decisão de "isto é órfão" nasce de uma leitura e o `rm` acontece
# DEPOIS. Entre os dois, o dono pode ter liberado e um terceiro criado o lock — e o `rm` cai sobre
# o lock de quem acabou de vencer a corrida, JÁ CONFIRMADO. Medido: duas cargas pesadas
# entrelaçadas na testemunha, que é a falha de segurança que este primitivo existe para impedir.
# A confirmação de posse não cobre isso: ela é um INSTANTE, e a remoção vem depois dela — detectar
# na entrada não protege quem já entrou, então a proteção tem de estar do lado de quem remove.
#
# `mv` para nome exclusivo é `rename(2)`, atômico: dois reivindicantes competem e só um leva o
# diretório, porque o outro falha com a origem já ausente. Quem levou RECONFERE o que tem na mão e
# devolve se não for mais o órfão que motivou a decisão. É o mesmo princípio do `release`, que
# confere PID e nonce antes de remover: nunca destrua o que você não provou ser seu.
_fhm_reclaim_orphan() {  # _fhm_reclaim_orphan <pid-esperado>
  local want="$1" reap p2 t2
  reap="${_FHM_LOCK}.reaping.$$.$(date +%s).${RANDOM:-0}"
  mv "$_FHM_LOCK" "$reap" 2>/dev/null || return 1
  p2="$(cat "$reap/pid" 2>/dev/null || echo '')"
  t2="$(cat "$reap/token" 2>/dev/null || echo '')"
  if [ "$p2" = "$want" ] && ! _fhm_alive "$p2" "$t2"; then
    echo "heavy-mutex: lock órfão de PID $want removido em $_FHM_LOCK (processo morto, zumbi ou PID reciclado)." >&2
    rm -rf "$reap" 2>/dev/null
    return 0
  fi
  if [ ! -d "$_FHM_LOCK" ] && mv "$reap" "$_FHM_LOCK" 2>/dev/null; then
    return 1
  fi
  echo "heavy-mutex: reivindicação de órfão atropelou um detentor novo (PID ${p2:-?}); evidência em $reap" >&2
  return 1
}


# Escreve os metadados e CONFIRMA a posse; devolve 1 quando o lock foi revogado no meio, e o
# chamador RETENTA em vez de desistir. Desistir transformaria uma corrida benigna em falha de
# push: medido com cinco concorrentes, três saíam com rc 75 sobre um recurso que estava LIVRE.
_fhm_claim() {  # _fhm_claim <label>
  local label="$1"
  # `pid` PRIMEIRO, porque é o campo que o legado lê: estreita ao máximo a janela em que o lock
  # existe sem dono legível. Todo `rc` de escrita é conferido — um `printf` que falhe é falha de
  # AQUISIÇÃO, não um aviso solto no stderr.
  printf '%s\n' "$$" > "$_FHM_LOCK/pid" || { echo "heavy-mutex: não consegui escrever $_FHM_LOCK/pid" >&2; return 1; }
  # Sonda de teste: reproduz determinística e exclusivamente a revogação por consumidor legado
  # dentro da janela, para que o cenário [19] meça a decisão e não dependa de vencer uma corrida.
  [ "${FORGE_HEAVY_MUTEX_REVOKE_PROBE:-}" = "1" ] && rm -rf "$_FHM_LOCK"
  printf '%s\n' "$(_fhm_token "$$")" > "$_FHM_LOCK/token" 2>/dev/null
  printf '%s\n' "$_FHM_NONCE" > "$_FHM_LOCK/nonce" 2>/dev/null
  printf '%s\n' "$(date +%s)" > "$_FHM_LOCK/acquired_at" 2>/dev/null
  printf '%s\n' "${label}" > "$_FHM_LOCK/label" 2>/dev/null

  # CONFIRMAÇÃO DE POSSE. Escrever `pid` primeiro ESTREITA a janela (medido: mediana 87 µs, p95
  # 130 µs), não a fecha — e um consumidor legado que a atravesse remove o nosso lock e segue.
  # Sem esta releitura, o processo continua se comportando como detentor de um lock que não existe
  # mais, tendo produzido apenas uma linha `No such file or directory` que ninguém lê: duas suítes
  # pesadas rodando juntas, que é o defeito que o mutex existe para impedir.
  if [ ! -d "$_FHM_LOCK" ] || [ "$(cat "$_FHM_LOCK/pid" 2>/dev/null)" != "$$" ] \
     || [ "$(cat "$_FHM_LOCK/nonce" 2>/dev/null)" != "$_FHM_NONCE" ]; then
    echo "heavy-mutex: lock revogado durante a janela de escrita — refazendo a aquisição ($_FHM_LOCK)" >&2
    _FHM_OWNED="false"
    return 1
  fi
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
  _FHM_QDIR="$root/$res.q"
  _FHM_QSWITCH="$root/$res.q.enabled"
  # WAIT_START é o instante em que ESTE processo começou a esperar, e é o carimbo do ticket mesmo
  # que ele só venha a ser criado mais tarde — é o que preserva a espera já investida quando o
  # interruptor liga no meio do voo, em vez de mandar para o fim quem esperava há vinte minutos.
  _FHM_WAIT_START="$(_fhm_now_us20)"
  _FHM_TICKET=""

  local incomplete=0 holder htok
  _FHM_NONCE="$$.$(date +%s).${RANDOM:-0}"
  local qon="DESLIGADA" head
  if _fhm_queue_enabled; then
    qon="LIGADA"
    _fhm_enqueue "$_FHM_WAIT_START" || _fhm_enqueue "$(_fhm_now_us20)" || true
  fi

  while : ; do
    # PORTÃO DE JUSTIÇA: só a cabeça TENTA. Com a fila desligada, todos tentam — que é o
    # comportamento legado, e é o que mantém a migração monótona em corretude.
    if _fhm_queue_enabled; then
      # O próprio ticket pode ter sido varrido por terceiro. Não reenfileirar tornaria "não sou
      # cabeça" um estado ABSORVENTE: medido, o processo espera o teto inteiro com o lock LIVRE.
      if [ -z "${_FHM_TICKET:-}" ] || [ ! -d "$_FHM_TICKET" ]; then
        _FHM_TICKET=""
        _fhm_enqueue "$_FHM_WAIT_START" || _fhm_enqueue "$(_fhm_now_us20)" || true
      fi
      head="$(_fhm_head_ticket)"
      if [ -n "$head" ] && [ -n "${_FHM_TICKET:-}" ] && [ "$head" != "$(basename "$_FHM_TICKET")" ]; then
        if [ "$waited" -ge "$timeout" ]; then
          echo "heavy-mutex: TIMEOUT após ${waited}s na fila (posição alcançada: cabeça é $head)." >&2
          echo "  lock ........ $_FHM_LOCK (âncora: $prov)" >&2
          _fhm_leave_queue
          return 75
        fi
        [ "$waited" = 0 ] && { echo "heavy-mutex: AGUARDANDO — ${label}" >&2; echo "  lock ........ $_FHM_LOCK (âncora: $prov)" >&2; echo "  fila ........ LIGADA — cabeça é $head" >&2; }
        sleep "${FORGE_HEAVY_MUTEX_POLL_S:-1}"
        waited=$((waited + ${FORGE_HEAVY_MUTEX_POLL_S:-1}))
        continue
      fi
    fi
    if mkdir "$_FHM_LOCK" 2>/dev/null; then
      if _fhm_claim "${label}"; then break; fi
      if [ "$waited" -ge "$timeout" ]; then _fhm_leave_queue; return 75; fi
      sleep "${FORGE_HEAVY_MUTEX_POLL_S:-1}"
      waited=$((waited + ${FORGE_HEAVY_MUTEX_POLL_S:-1}))
      continue
    fi
    holder="$(cat "$_FHM_LOCK/pid" 2>/dev/null || echo '')"
    htok="$(cat "$_FHM_LOCK/token" 2>/dev/null || echo '')"

    if [ -z "$holder" ]; then
      # Lock SEM dono legível é o estado da janela entre o `mkdir` e a escrita do `pid`. Reclamar
      # no primeiro poll é apagar o lock de quem acabou de vencer a corrida — é o que o legado faz,
      # e é uma corrida real. Contamos observações consecutivas em vez de comparar mtime, o que
      # evitaria a divergência `stat -f %m` (BSD) contra `stat -c %Y` (GNU).
      incomplete=$((incomplete + 1))
      if [ "$incomplete" -ge "${FORGE_HEAVY_MUTEX_INCOMPLETE_POLLS:-5}" ]; then
        echo "heavy-mutex: lock incompleto (sem pid) por $incomplete poll(s) — reclamando $_FHM_LOCK" >&2
        rm -rf "$_FHM_LOCK"
        incomplete=0
        continue
      fi
    else
      incomplete=0
      if _fhm_alive "$holder" "$htok" && _fhm_is_ancestor "$holder"; then
        echo "heavy-mutex: lock já detido por processo ancestral (PID $holder) — seguindo sem readquirir." >&2
        _FHM_OWNED="false"
        FORGE_HEAVY_MUTEX_REENTRANT=1
        export FORGE_HEAVY_MUTEX_REENTRANT
        _fhm_leave_queue
        return 0
      fi
      if ! _fhm_alive "$holder" "$htok"; then
        _fhm_reclaim_orphan "$holder" || true
        continue
      fi
    fi

    if [ "$waited" -ge "$timeout" ]; then
      echo "heavy-mutex: TIMEOUT após ${waited}s esperando o mutex da máquina." >&2
      echo "  lock ........ $_FHM_LOCK (âncora: $prov)" >&2
      echo "  detentor .... PID ${holder:-desconhecido}" >&2
      _fhm_leave_queue
      return 75
    fi
    if [ "$waited" = 0 ]; then
      echo "heavy-mutex: AGUARDANDO — ${label}" >&2
      echo "  lock ........ $_FHM_LOCK (âncora: $prov)" >&2
      echo "  detentor .... PID ${holder:-'?'}" >&2
    fi
    sleep "${FORGE_HEAVY_MUTEX_POLL_S:-1}"
    waited=$((waited + ${FORGE_HEAVY_MUTEX_POLL_S:-1}))
  done

  _FHM_OWNED="true"
  _fhm_leave_queue
  # Recibo SEMPRE, mesmo sem contenção: é o análogo do contador de controle para um primitivo que
  # não itera universo. Sem ele, "rodei com o mutex e não houve disputa" e "rodei sem o mutex
  # porque a biblioteca sumiu" produzem o MESMO silêncio no log.
  echo "heavy-mutex: adquirido — $_FHM_LOCK (âncora: $prov), recurso $res, fila $qon, espera ${waited}s, relógio ${_FHM_CLOCK:-hires}" >&2
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
  local nonce; nonce="$(cat "$_FHM_LOCK/nonce" 2>/dev/null || echo '')"
  # Confere PID e NONCE: o token identifica um processo, o nonce identifica ESTA aquisição.
  if [ "$holder" = "$$" ] && [ "$nonce" = "${_FHM_NONCE:-}" ]; then
    rm -rf "$_FHM_LOCK"
    # `rm -rf` pode falhar com "Directory not empty" sob criação concorrente. Conferir a remoção,
    # tentar de novo, e nunca ASSUMIR que removeu — um lock que sobra bloqueia a máquina inteira.
    if [ -d "$_FHM_LOCK" ]; then
      rm -rf "$_FHM_LOCK"
      [ -d "$_FHM_LOCK" ] && echo "heavy-mutex: NÃO consegui remover $_FHM_LOCK — o próximo adquirente vai tratá-lo como órfão; confira o caminho." >&2
    fi
  fi
  _FHM_OWNED="false"
  return 0
}
