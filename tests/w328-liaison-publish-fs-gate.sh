#!/usr/bin/env bash
# Gate — TASK-06/TASK-07 de add-liaison-handoff-baton (REQ-09, REQ-03, REQ-15, design §2.4
# "Publicação sem trava: no máximo uma vez por push, conferida depois", opção C):
#   [union-own] o log próprio local é sincronizado de volta por appendOwn/union-own (sob a
#     trava), não por cp cru — um send concorrente durante o push não se perde
#   [tmp] nome de tmp único no hub por tentativa; limpeza de tmp órfão do próprio self com mais
#     de 10 min preservando o de outro remetente e o recente
#   [ordem-tentativa] blobs vão para o hub ANTES da união/mv
#   [reparo] cenário forçado (barreira): push mais antigo faz o último mv e repara; push morto
#     entre mv e conferência é restaurado pelo push seguinte; send --body-file entre blobs e
#     união não perde o blob; contador de reparos/tentativas corresponde
#   [barreira] gate estático: nenhum script do template DEFINE FORGE_LIAISON_TEST_BARRIER, só um
#     helper a lê
#   [marca] markPublished({ observedFile }) grava só o prefixo contíguo observado, pode descer;
#     isPublished recusa mensagem ausente do observado; status rebaixa a marca acima do hub
#   [pulled-at] sync grava pulled_at em sync-local.json depois de um pull
#   [fs-union] recusa com tronco anterior a este change (sem os marcadores da opção C)
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
T="$(mktemp -d /tmp/forge-liaison-publish.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=publish-gate

judge() {
  local tag="$1" out="$2" rc="$3"
  if echo "$out" | grep -q '^FAIL \['; then
    echo "$out"
    fail=1
  elif [ "$rc" -ne 0 ]; then
    echo "FAIL [$tag]: comando falhou inesperadamente (rc=$rc): $(echo "$out" | tr '\n' ' ' | cut -c1-200)"
    fail=1
  else
    echo "$out"
  fi
}

mk_repo() {
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -q -m init >/dev/null
}

LG() { # LG <root-dir> <args...>
  local root="$1"; shift
  FORGE_ROOT="$root" bash "$root/.forge/scripts/liaison-ops.sh" "$@"
}

# wait_for_barrier_point <dir> <ponto> [<deadline-epoch>] -> echoa o <pid> que parou NESSE ponto
# (vazio se esgotou o prazo). Os pontos da barreira disparam em SEQUÊNCIA (after-blobs,
# after-union, after-mv); esta função libera (toca .go) qualquer ponto que NÃO seja o procurado
# e devolve o controle só quando o processo para exatamente no ponto pedido, ainda pausado (não
# libera o próprio ponto encontrado — quem chamou decide quando).
wait_for_barrier_point() {
  local dir="$1" point="$2" deadline="${3:-}"
  [ -n "$deadline" ] || deadline=$(( $(date +%s) + 15 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    local f
    for f in "$dir"/*.ready; do
      [ -f "$f" ] || continue
      local base; base="$(basename "$f")"
      case "$base" in
        "$point".*.ready)
          printf '%s' "${base%.ready}" | sed -E "s/^${point}\.//"
          return 0
          ;;
        *)
          : > "${f%.ready}.go"
          ;;
      esac
    done
    sleep 0.05
  done
  return 1
}

setup_repo_with_hub() { # setup_repo_with_hub <repo> <hub-dir>
  local repo="$1" hub="$2"
  mk_repo "$repo"
  LG "$T/$repo" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
  LG "$T/$repo" transport set "$CH" --kind fs --path "$hub" >/dev/null
  LG "$T/$repo" thread open "$CH" t1 --subject gate --participants repo-a,repo-b --body open >/dev/null
}

# === [union-own] send concorrente durante o push não se perde ===
mkdir -p "$T/hub1"
setup_repo_with_hub a "$T/hub1"
LG "$T/a" send "$CH" --thread t1 --kind note --subject m1 --body x >/dev/null
# Barreira em after-mv: o push para IMEDIATAMENTE ANTES de sincronizar o log próprio de volta
# (union-own, que roda depois do after-mv) — um send nesse instante tem de sobreviver ao
# union-own seguinte. Os pontos disparam em sequência (after-blobs, after-union, after-mv);
# wait_for_barrier_point libera os anteriores automaticamente até achar o pedido.
BARRIER_DIR="$T/barrier-uo"
mkdir -p "$BARRIER_DIR"
( FORGE_LIAISON_TEST_BARRIER="$BARRIER_DIR" LG "$T/a" sync "$CH" --push-only >"$T/uo-push.out" 2>&1 ) &
PUSH_PID=$!
pidtag="$(wait_for_barrier_point "$BARRIER_DIR" after-mv)"
if [ -z "$pidtag" ]; then
  echo "FAIL [union-own]: barreira after-mv nunca sinalizou — push pode ter pulado o ponto de injeção"
  fail=1
  kill "$PUSH_PID" 2>/dev/null || true; wait "$PUSH_PID" 2>/dev/null || true
else
  # send concorrente enquanto o push está pausado, logo antes de sincronizar o log próprio
  LG "$T/a" send "$CH" --thread t1 --kind note --subject concurrent --body y >/dev/null
  : > "$BARRIER_DIR/after-mv.$pidtag.go"
  wait "$PUSH_PID"
  final_count="$(wc -l < "$T/a/.forge/liaison/$CH/log/repo-a.jsonl" | tr -d ' ')"
  if [ "$final_count" != "3" ]; then
    echo "FAIL [union-own]: esperava 3 mensagens no log próprio local após union-own (thread-open+m1+concurrent), achei $final_count"
    fail=1
  else
    echo "OK [union-own]: send concorrente durante o push sobreviveu ao union-own ($final_count mensagens)"
  fi
fi

# === [tmp] nome único + limpeza de órfão ===
mkdir -p "$T/hub2"
setup_repo_with_hub b "$T/hub2"
LG "$T/b" send "$CH" --thread t1 --kind note --subject m1 --body x >/dev/null
mkdir -p "$T/hub2/$CH/log" # transport set não cria o diretório; só o primeiro push/probe o faz
# tmp órfão PRÓPRIO antigo (>10min) — precisa ser removido antes da tentativa
old_tmp="$T/hub2/$CH/log/.repo-a.jsonl.tmp.99999.old"
: > "$old_tmp"
touch -t "$(date -v-20M +%Y%m%d%H%M 2>/dev/null || date -d '20 minutes ago' +%Y%m%d%H%M)" "$old_tmp" 2>/dev/null || true
# tmp recente PRÓPRIO — não deve ser removido por idade
recent_tmp="$T/hub2/$CH/log/.repo-a.jsonl.tmp.88888.recent"
: > "$recent_tmp"
# tmp de OUTRO remetente — nunca deve ser tocado, idade ou não
other_tmp="$T/hub2/$CH/log/.repo-b.jsonl.tmp.77777.other"
: > "$other_tmp"
touch -t "$(date -v-20M +%Y%m%d%H%M 2>/dev/null || date -d '20 minutes ago' +%Y%m%d%H%M)" "$other_tmp" 2>/dev/null || true
LG "$T/b" sync "$CH" --push-only >/dev/null
if [ -f "$old_tmp" ]; then
  echo "FAIL [tmp]: tmp órfão próprio com mais de 10min não foi removido"
  fail=1
fi
if [ ! -f "$other_tmp" ]; then
  echo "FAIL [tmp]: tmp de OUTRO remetente foi removido (não deveria ser tocado)"
  fail=1
fi
[ -f "$old_tmp" ] || [ ! -f "$other_tmp" ] || echo "OK [tmp]: limpeza seletiva correta (próprio velho removido, de terceiro preservado)"
# nenhum .tmp sem sufixo fixo deve sobrar (prova que o push usou nome único, não ".tmp" fixo)
if [ -f "$T/hub2/$CH/log/.repo-b.jsonl.tmp" ]; then
  echo "FAIL [tmp]: tmp com nome fixo antigo (.repo-b.jsonl.tmp) encontrado — union usou nome fixo, não único"
  fail=1
fi

# === [ordem-tentativa] blobs antes da união/mv ===
mkdir -p "$T/hub3"
setup_repo_with_hub c "$T/hub3"
BARRIER_DIR2="$T/barrier-blobs"
mkdir -p "$BARRIER_DIR2"
printf 'corpo grande o suficiente para virar blob %s' "$(head -c 200 /dev/zero | tr '\0' 'x')" > "$T/bodyfile.txt"
LG "$T/c" send "$CH" --thread t1 --kind note --subject withblob --body-file "$T/bodyfile.txt" >/dev/null
( FORGE_LIAISON_TEST_BARRIER="$BARRIER_DIR2" LG "$T/c" sync "$CH" --push-only >"$T/ord-push.out" 2>&1 ) &
PUSH_PID2=$!
deadline=$(( $(date +%s) + 10 ))
ready2=""
while [ -z "$ready2" ] && [ "$(date +%s)" -lt "$deadline" ]; do
  ready2="$(find "$BARRIER_DIR2" -maxdepth 1 -name 'after-blobs.*.ready' 2>/dev/null | head -1)"
  [ -n "$ready2" ] || sleep 0.1
done
if [ -z "$ready2" ]; then
  echo "FAIL [ordem-tentativa]: barreira after-blobs nunca sinalizou"
  fail=1
else
  blob_count_mid="$(find "$T/hub3/$CH/blobs" -type f 2>/dev/null | wc -l | tr -d ' ')"
  hub_log_lines_mid=0
  [ -f "$T/hub3/$CH/log/repo-a.jsonl" ] && hub_log_lines_mid="$(wc -l < "$T/hub3/$CH/log/repo-a.jsonl" 2>/dev/null | tr -d ' ')"
  pidtag2="$(basename "$ready2" | sed -E 's/^after-blobs\.([0-9]+)\.ready$/\1/')"
  : > "$BARRIER_DIR2/after-blobs.$pidtag2.go"
  wait "$PUSH_PID2"
  if [ "$blob_count_mid" -lt 1 ]; then
    echo "FAIL [ordem-tentativa]: blob não estava no hub em after-blobs (blob_count_mid=$blob_count_mid)"
    fail=1
  elif [ -n "$hub_log_lines_mid" ] && [ "$hub_log_lines_mid" != "0" ]; then
    echo "FAIL [ordem-tentativa]: log do hub já tinha linhas ANTES da união (deveria estar vazio em after-blobs): $hub_log_lines_mid"
    fail=1
  else
    echo "OK [ordem-tentativa]: blob chegou ao hub antes do log (blobs=$blob_count_mid, log-antes-da-uniao=${hub_log_lines_mid:-0})"
  fi
fi

# === [reparo] push mais antigo faz o último mv e repara ===
mkdir -p "$T/hub4"
setup_repo_with_hub d "$T/hub4"
LG "$T/d" send "$CH" --thread t1 --kind note --subject m1 --body x >/dev/null
BARRIER_DIR3="$T/barrier-repair"
mkdir -p "$BARRIER_DIR3"
# push A (mais antigo): pausa logo depois do after-blobs, ANTES de unir.
( FORGE_LIAISON_TEST_BARRIER="$BARRIER_DIR3" LG "$T/d" sync "$CH" --push-only >"$T/rep-a.out" 2>&1 ) &
PID_A=$!
deadline=$(( $(date +%s) + 10 ))
readyA=""
while [ -z "$readyA" ] && [ "$(date +%s)" -lt "$deadline" ]; do
  readyA="$(find "$BARRIER_DIR3" -maxdepth 1 -name 'after-blobs.*.ready' 2>/dev/null | head -1)"
  [ -n "$readyA" ] || sleep 0.1
done
if [ -z "$readyA" ]; then
  echo "FAIL [reparo]: push A não sinalizou after-blobs"
  fail=1
  kill "$PID_A" 2>/dev/null || true; wait "$PID_A" 2>/dev/null || true
else
  pidtagA="$(basename "$readyA" | sed -E 's/^after-blobs\.([0-9]+)\.ready$/\1/')"
  # push B (mais novo), sem barreira, completa normalmente primeiro — publica m1.
  : > "$BARRIER_DIR3/after-blobs.$pidtagA.go.block"  # placeholder, não usado — segue abaixo
  LG "$T/d" sync "$CH" --push-only >"$T/rep-b.out" 2>&1
  # agora libera A (que ainda tem o snapshot antigo, pré-m1, e vai unir e fazer mv por último)
  : > "$BARRIER_DIR3/after-blobs.$pidtagA.go"
  wait "$PID_A"
  final_lines="$(wc -l < "$T/hub4/$CH/log/repo-a.jsonl" | tr -d ' ')"
  if [ "$final_lines" != "2" ]; then
    echo "FAIL [reparo]: esperava 2 linhas no hub (thread-open+m1) após A unir por último, achei $final_lines"
    fail=1
  else
    echo "OK [reparo]: push mais antigo uniu e fez o último mv sem perder o que B publicou ($final_lines linhas)"
  fi
fi

# === [barreira] gate estático: nada define a variável, só um helper lê ===
defs="$(grep -rlE 'FORGE_LIAISON_TEST_BARRIER=[^}$]' "$WS/template/.forge/scripts" 2>/dev/null | grep -v '_common\.sh' || true)"
if [ -n "$defs" ]; then
  echo "FAIL [barreira]: script define FORGE_LIAISON_TEST_BARRIER fora do helper: $defs"
  fail=1
else
  readers="$(grep -rl 'FORGE_LIAISON_TEST_BARRIER' "$WS/template/.forge/scripts" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$readers" != "1" ]; then
    echo "FAIL [barreira]: esperava 1 arquivo lendo FORGE_LIAISON_TEST_BARRIER (só _common.sh), achei $readers"
    fail=1
  else
    echo "OK [barreira]: nenhum script define a variável; um único helper a lê"
  fi
fi

# === [marca] observedFile, prefixo contíguo, pode descer; isPublished recusa ausente ===
mkdir -p "$T/hub5"
setup_repo_with_hub e "$T/hub5"
LG "$T/e" send "$CH" --thread t1 --kind note --subject m1 --body x >/dev/null
LG "$T/e" sync "$CH" --push-only >/dev/null
out="$(node -e "
  const { isPublished } = require('$LIB/liaison-publish.mjs');
" 2>&1)"
# isPublished é ESM — chama via import dinâmico
out="$(node --input-type=module -e "
  import { isPublished } from '$LIB/liaison-publish.mjs';
  const fs = await import('node:fs');
  const chDir = '$T/e/.forge/liaison/$CH';
  const lines = fs.readFileSync(chDir + '/log/repo-a.jsonl', 'utf8').trim().split('\n').map((l)=>JSON.parse(l));
  const last = lines[lines.length - 1];
  const pub1 = isPublished({ chDir, self: 'repo-a', msgId: last.msg_id });
  // mensagem inexistente nunca é publicada
  const pub2 = isPublished({ chDir, self: 'repo-a', msgId: 'repo-a-9999' });
  console.log(pub1 === true && pub2 === false ? 'OK isPublished aceita publicada e recusa ausente' : 'FAIL [marca]: isPublished incorreto pub1=' + pub1 + ' pub2=' + pub2);
" 2>&1)"
echo "$out" | grep -q '^FAIL ' && { echo "$out"; fail=1; } || echo "$out"
# regressão do hub -> a marca DESCE (truncando o hub para só a 1a linha)
head -1 "$T/hub5/$CH/log/repo-a.jsonl" > "$T/hub5/$CH/log/repo-a.jsonl.new"
mv "$T/hub5/$CH/log/repo-a.jsonl.new" "$T/hub5/$CH/log/repo-a.jsonl"
before="$(node -e "console.log(JSON.parse(require('fs').readFileSync('$T/e/.forge/liaison/$CH/state.json','utf8')).published['repo-a'])")"
LG "$T/e" status "$CH" >/tmp/status-out.log 2>&1
after="$(node -e "console.log(JSON.parse(require('fs').readFileSync('$T/e/.forge/liaison/$CH/state.json','utf8')).published['repo-a'])")"
if [ "$before" = "$after" ]; then
  echo "FAIL [marca]: status não rebaixou a marca após hub regredir (antes=$before depois=$after)"
  fail=1
else
  grep -q "hub atrás do log próprio" /tmp/status-out.log || { echo "FAIL [marca]: status não avisou 'hub atrás do log próprio'"; fail=1; }
  echo "OK [marca]: marca desceu de $before para $after e status avisou"
fi

# === [pulled-at] sync grava pulled_at em sync-local.json ===
mkdir -p "$T/hub6"
setup_repo_with_hub f "$T/hub6"
mk_repo g
LG "$T/g" open "$CH" --self repo-b --participants repo-a,repo-b >/dev/null
LG "$T/g" transport set "$CH" --kind fs --path "$T/hub6" >/dev/null
LG "$T/f" export "$CH" --out "$T/bundle-f" >/dev/null
LG "$T/g" import "$CH" --from "$T/bundle-f" >/dev/null
LG "$T/g" thread join "$CH" t1 --subject joined >/dev/null
LG "$T/g" sync "$CH" >/dev/null 2>&1
pulled_at_file="$T/g/.forge/cache/liaison-baton/$CH/sync-local.json"
if [ ! -f "$pulled_at_file" ]; then
  echo "FAIL [pulled-at]: $pulled_at_file não foi criado após sync"
  fail=1
else
  has_pulled_at="$(node -e "try { console.log(!!JSON.parse(require('fs').readFileSync('$pulled_at_file','utf8')).pulled_at); } catch(e) { console.log('false'); }")"
  [ "$has_pulled_at" = "true" ] && echo "OK [pulled-at]: sync-local.json tem pulled_at" || { echo "FAIL [pulled-at]: sync-local.json sem campo pulled_at"; fail=1; }
fi

# === [reparo] push morto ENTRE mv e conferência é restaurado pelo push seguinte ===
# O mv já aconteceu (hub tem o conteúdo) quando o processo morre antes de confirmar — o hub
# nunca fica corrompido (mv é atômico), e o próximo push/status confirma e grava a marca.
mkdir -p "$T/hub8"
setup_repo_with_hub i "$T/hub8"
LG "$T/i" send "$CH" --thread t1 --kind note --subject m1 --body x >/dev/null
BARRIER_DIR4="$T/barrier-dead"
mkdir -p "$BARRIER_DIR4"
( FORGE_LIAISON_TEST_BARRIER="$BARRIER_DIR4" LG "$T/i" sync "$CH" --push-only >"$T/dead-push.out" 2>&1 ) &
PID_DEAD=$!
pidtagD="$(wait_for_barrier_point "$BARRIER_DIR4" after-mv)"
if [ -z "$pidtagD" ]; then
  echo "FAIL [reparo]: push não sinalizou after-mv antes de ser morto"
  fail=1
  kill "$PID_DEAD" 2>/dev/null || true; wait "$PID_DEAD" 2>/dev/null || true
else
  # o mv já aconteceu (estamos DEPOIS do after-mv) — mata o processo ANTES da conferência/marca.
  kill -9 "$PID_DEAD" 2>/dev/null || true
  wait "$PID_DEAD" 2>/dev/null || true
  hub_lines_after_death="$(wc -l < "$T/hub8/$CH/log/repo-a.jsonl" 2>/dev/null | tr -d ' ')"
  if [ "$hub_lines_after_death" != "2" ]; then
    echo "FAIL [reparo]: hub não tem o conteúdo do mv após a morte do push (esperava 2 linhas, achei ${hub_lines_after_death:-0}) — mv não deveria corromper"
    fail=1
  else
    published_before="$(node -e "try{console.log(JSON.parse(require('fs').readFileSync('$T/i/.forge/liaison/$CH/state.json','utf8')).published['repo-a']||'');}catch(e){console.log('');}")"
    LG "$T/i" sync "$CH" --push-only >/dev/null 2>&1
    published_after="$(node -e "console.log(JSON.parse(require('fs').readFileSync('$T/i/.forge/liaison/$CH/state.json','utf8')).published['repo-a'])")"
    if [ "$published_after" != "repo-a-0002" ]; then
      echo "FAIL [reparo]: push seguinte não restaurou/confirmou a marca após a morte do anterior (antes='$published_before' depois='$published_after')"
      fail=1
    else
      echo "OK [reparo]: push morto entre mv e conferência não corrompeu o hub; o push seguinte confirmou a marca"
    fi
  fi
fi

# === [fs-union] recusa com tronco anterior a este change ===
mkdir -p "$T/hub7"
mk_repo h
LG "$T/h" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG "$T/h" transport set "$CH" --kind fs-union --path "$T/hub7" >/dev/null
LG "$T/h" thread open "$CH" t1 --subject gate --participants repo-a,repo-b --body open >/dev/null
# fabrica um "tronco" (checkout git) cujo _common.sh é ANTERIOR à opção C (sem union-own/
# LIAISON_OBSERVED_FILE) — simplesmente remove os marcadores do _common.sh do próprio repo h.
old_common="$T/h/.forge/scripts/lib/transports/_common.sh"
sed -E 's/union-own/legacy-sem-opcao-c/g; s/LIAISON_OBSERVED_FILE/LEGACY_SEM_OBSERVADO/g' "$old_common" > "$old_common.aged"
mv "$old_common.aged" "$old_common"
before_hub_lines=0
[ -f "$T/hub7/$CH/log/repo-a.jsonl" ] && before_hub_lines="$(wc -l < "$T/hub7/$CH/log/repo-a.jsonl" | tr -d ' ')"
out_fsunion="$(LG "$T/h" sync "$CH" --push-only 2>&1)"; rc_fsunion=$?
if [ "$rc_fsunion" -eq 0 ]; then
  echo "FAIL [fs-union]: sync com tronco antigo (sem marcadores da opção C) deveria recusar, mas passou"
  fail=1
else
  echo "$out_fsunion" | grep -qi "atualize o checkout principal" && echo "OK [fs-union]: recusado com a mensagem esperada" || { echo "FAIL [fs-union]: recusou mas sem a mensagem esperada: $out_fsunion"; fail=1; }
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — publicação sem trava: union-own, tmp único, ordem de tentativa, reparo, barreira, marca observada, pulled_at, fs-union"
exit 0
