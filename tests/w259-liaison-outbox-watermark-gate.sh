#!/usr/bin/env bash
# Gate W259 — issue #109: liaison não distinguia mensagem ENVIADA de PUBLICADA.
#
# `state.json` tinha só `cursors` (avanço de LEITURA) — nenhum `sync` gravava o que este
# remetente publicou no hub, e `status` não comparava o log próprio com a marca. Uma mensagem
# `send`ada mas nunca `sync`ada ficava sem aviso nenhum: o remetente achava que a contraparte já
# via a mensagem, quando ela nunca saiu da árvore local.
#
#   [1] `send` sem `sync`: `status` mostra "1 própria(s) não publicada(s)" (positiva) — SEM
#       "(há Xmin)", porque nunca houve publicação (não há `published_at` contra o que medir).
#   [2] depois do `sync`: a linha desaparece; `state.json` ganha `published[self]` apontando o
#       último msg_id do log próprio e `published_at[self]` (carimbo do push).
#   [3] DA-23 — `(há Xmin)` mede contra `published_at`, NUNCA contra `created_at` (data do HEAD
#       do commit, determinística e alheia ao relógio de parede): fixa `created_at` em
#       2020-01-01 (commit inicial com `GIT_COMMITTER_DATE`/`GIT_AUTHOR_DATE`), publica agora
#       (published_at = "agora" real), reescreve `published_at` para "agora - 5min" e manda uma
#       segunda mensagem. Se `status` medisse `created_at`, o "(há Xmin)" mostraria uma distância
#       de milhares de dias; medindo `published_at` mostra minutos.
#   [4] propriedade PBT: para sequências geradas de `send`/`sync` intercalados, a contagem de não
#       publicadas impressa por `status` é sempre igual ao número de mensagens PRÓPRIAS ausentes
#       do log do hub (medido diretamente no hub, sem depender do mecanismo sob teste).
#   [5] contador de controle — universo de trials com zero mensagem reprova o cenário.
#   [6] mutação: `sync` sem gravar `published` (cópia isolada de liaison-ops.sh, nunca o arquivo
#       real) faz a contagem pós-sync do cenário [2] ficar > 0 — controle e recontrole por `cmp`.
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem
# ao repositório de quem invocou o gate, e não aos repositórios sintéticos criados aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w259.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT
FAIL=0

CH=contracts-fare
TH=fare-grpc-v1
HUBROOT="$T/hub"
HUB="$HUBROOT/$CH"
A=axis-go-cloud
B=axis-fare-validator

# mk_repo <nome> [data-do-commit-inicial-ISO8601] — data fixa faz created_at (HEAD, _git_date)
# determinístico entre cenários; default = agora.
mk_repo() {
  local dir="$T/$1" when="${2:-}"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  cp -R "$WS/template/.forge/ledger" "$dir/.forge/"
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  if [ -n "$when" ]; then
    GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git -C "$dir" commit --allow-empty -qm init >/dev/null
  else
    git -C "$dir" commit --allow-empty -qm init >/dev/null
  fi
}
LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }
_msgid() { local s="$1"; s="${s#*— }"; printf '%s' "${s%% *}"; }

# ── cenários [1]-[3]: fixture própria, created_at FIXO em 2020-01-01 ────────────────────────────
mk_repo "$A" "2020-01-01T00:00:00Z"
mk_repo "$B"
LG "$A" open "$CH" --self "$A" --participants "$A,$B" >/dev/null
LG "$B" open "$CH" --self "$B" --participants "$A,$B" >/dev/null
LG "$A" transport set "$CH" --kind fs --path "$HUBROOT" >/dev/null
LG "$B" transport set "$CH" --kind fs --path "$HUBROOT" >/dev/null
LG "$A" thread open "$CH" "$TH" --subject "abertura" --participants "$A,$B" --body "abertura" >/dev/null

echo "[1] send sem sync: status mostra a contagem certa, sem parêntese de tempo"
# 2 mensagens próprias no log neste ponto: a de abertura da thread (kind: thread-open, gravada
# por `thread open` acima) MAIS a que este cenário envia agora — ambas nunca sincronizadas.
M1="$(_msgid "$(LG "$A" send "$CH" --thread "$TH" --kind note --subject s1 --body b1)")"
ST1="$(LG "$A" status "$CH" 2>&1)"
if ! grep -qE '2 própria\(s\) não publicada\(s\)$' <<<"$ST1"; then
  echo "FAIL [1]: linha de não-publicadas ausente, contagem errada, ou com parêntese indevido (sem published_at ainda): $ST1"
  FAIL=1
else
  echo "OK [1]: $ST1"
fi

echo "[2] depois do sync: a linha some, published/published_at gravados"
LG "$A" sync "$CH" >/dev/null
ST2="$(LG "$A" status "$CH" 2>&1)"
if grep -q "não publicada" <<<"$ST2"; then
  echo "FAIL [2]: status ainda mostra não-publicadas depois do sync: $ST2"
  FAIL=1
else
  STATE_A="$T/$A/.forge/liaison/$CH/state.json"
  PUB_ID="$(node -e "console.log((JSON.parse(require('fs').readFileSync('$STATE_A','utf8')).published||{})['$A']||'')")"
  PUB_AT="$(node -e "console.log((JSON.parse(require('fs').readFileSync('$STATE_A','utf8')).published_at||{})['$A']||'')")"
  if [ "$PUB_ID" != "$M1" ]; then
    echo "FAIL [2]: published[$A]='$PUB_ID', esperado '$M1'"
    FAIL=1
  elif [ -z "$PUB_AT" ]; then
    echo "FAIL [2]: published_at[$A] ausente"
    FAIL=1
  else
    echo "OK [2]: published=$PUB_ID published_at=$PUB_AT (status: $ST2)"
  fi
fi

echo "[3] (há Xmin) mede contra published_at, não contra created_at (2020-01-01, milhares de dias atrás)"
STATE_A="$T/$A/.forge/liaison/$CH/state.json"
# Reescreve published_at para "agora - 5min" — precisão determinística, sem depender de sleep.
FIVE_MIN_AGO="$(node -e "console.log(new Date(Date.now()-5*60000).toISOString().replace(/\.\d+Z$/,'Z'))")"
node -e "
const fs=require('fs');
const f='$STATE_A';
const s=JSON.parse(fs.readFileSync(f,'utf8'));
s.published_at['$A']='$FIVE_MIN_AGO';
fs.writeFileSync(f, JSON.stringify(s,null,2)+'\n');
"
M2="$(_msgid "$(LG "$A" send "$CH" --thread "$TH" --kind note --subject s2 --body b2)")"
ST3="$(LG "$A" status "$CH" 2>&1)"
if ! grep -qE '1 própria\(s\) não publicada\(s\) \(há [0-9]+min\)' <<<"$ST3"; then
  echo "FAIL [3]: parêntese de tempo ausente ou em formato inesperado: $ST3"
  FAIL=1
elif grep -qE '\(há [0-9]+d' <<<"$ST3"; then
  echo "FAIL [3]: mediu contra created_at (2020-01-01) em vez de published_at — apareceram dias: $ST3"
  FAIL=1
else
  MIN="$(grep -oE 'há [0-9]+min' <<<"$ST3" | grep -oE '[0-9]+')"
  if [ "$MIN" -lt 3 ] || [ "$MIN" -gt 7 ]; then
    echo "FAIL [3]: elapsed fora da janela esperada (3-7min, published_at ajustado para -5min): ${MIN}min — $ST3"
    FAIL=1
  else
    echo "OK [3]: $ST3"
  fi
fi

# ── [4]/[5]: propriedade PBT — send/sync intercalados ───────────────────────────────────────────
echo "== [4] propriedade: contagem de não-publicadas == mensagens próprias ausentes do log do hub =="
TOTAL=0
run_trial() {  # run_trial <nome> <sequência: 's' send | 'y' sync, ex: "s s y s">
  local nome="$1" seq="$2"
  TOTAL=$((TOTAL + 1))
  local dir="pbt-$TOTAL"
  mk_repo "$dir"
  LG "$dir" open "$CH" --self "$dir" --participants "$dir,peer-$TOTAL" >/dev/null
  LG "$dir" transport set "$CH" --kind fs --path "$HUBROOT-pbt$TOTAL" >/dev/null
  LG "$dir" thread open "$CH" "$TH" --subject t --participants "$dir,peer-$TOTAL" --body t >/dev/null
  local n=0
  for tok in $seq; do
    case "$tok" in
      s) n=$((n + 1)); LG "$dir" send "$CH" --thread "$TH" --kind note --subject "s$n" --body "b$n" >/dev/null ;;
      y) LG "$dir" sync "$CH" >/dev/null ;;
    esac
  done
  local hub_file="$HUBROOT-pbt$TOTAL/$CH/log/$dir.jsonl"
  local own_file="$T/$dir/.forge/liaison/$CH/log/$dir.jsonl"
  local expected
  expected="$(node -e "
    const fs=require('fs');
    const own=fs.existsSync('$own_file')?fs.readFileSync('$own_file','utf8').split('\n').filter(Boolean).map((l)=>JSON.parse(l).msg_id):[];
    const hub=fs.existsSync('$hub_file')?new Set(fs.readFileSync('$hub_file','utf8').split('\n').filter(Boolean).map((l)=>JSON.parse(l).msg_id)):new Set();
    console.log(own.filter((id)=>!hub.has(id)).length);
  ")"
  local st actual
  st="$(LG "$dir" status "$CH" 2>&1)"
  actual="$(grep -oE '[0-9]+ própria\(s\) não publicada\(s\)' <<<"$st" | grep -oE '^[0-9]+' || echo 0)"
  [ -n "$actual" ] || actual=0
  if [ "$actual" != "$expected" ]; then
    echo "FAIL [4/$nome]: status mostrou $actual não-publicada(s), hub diz que deveriam ser $expected: $st"
    FAIL=1
  else
    echo "OK [4/$nome]: seq='$seq' -> $actual não-publicada(s) (bate com o hub)"
  fi
}

run_trial "so-envia"          "s s s"
run_trial "envia-e-sincroniza" "s y"
run_trial "intercalado"        "s y s s y s"
run_trial "sync-sem-mensagem"  "y"
run_trial "so-sync-vazio"      ""
run_trial "muitas-antes-de-sync" "s s s s s y"

echo "[5] contador de controle — universo de trials com zero mensagem reprova o cenário"
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w259/pbt-trials" "$TOTAL" "trial(s) de PBT" "$T" "$WS" \
  || { echo "FAIL [5]"; FAIL=1; }
set +e
out5="$(forge_universe_check "w259/pbt-trials" 0 "trial(s)" "contrapositiva" "$WS" 2>&1)"; rc5=$?
set -e
[ "$rc5" -ne 0 ] || { echo "FAIL [5]: universo vazio aprovou — $out5"; FAIL=1; }
[ "$FAIL" -ne 0 ] || echo "OK [5]: $TOTAL trial(s), contrapositiva reprova universo vazio"

# ── [6]: mutação — sync sem gravar published deixa a contagem pós-sync > 0 ─────────────────────
echo "[6] mutação: sync sem gravar 'published' faz a contagem pós-sync ficar > 0"
LIAISON_SRC="$WS/template/.forge/scripts/liaison-ops.sh"
LIAISON_MUT="$T/liaison-ops-mutated.sh"
cp "$LIAISON_SRC" "$LIAISON_MUT"
# Neutraliza a chamada que grava a marca d'água (nome da função introduzida por esta correção:
# markPublished, em lib/liaison-publish.mjs) sem tocar em mais nada do arquivo.
perl -0pi -e "s/markPublished\(/(() => ({}))\(/g" "$LIAISON_MUT"
if ! grep -q '(() => ({}))(' "$LIAISON_MUT"; then
  echo "FAIL [6]: a mutação não pegou — ajuste o padrão do perl (a chamada markPublished mudou de forma?)"
  FAIL=1
else
  mk_repo mut-a
  mk_repo mut-b
  LG mut-a open "$CH" --self mut-a --participants mut-a,mut-b >/dev/null
  LG mut-a transport set "$CH" --kind fs --path "$HUBROOT-mut" >/dev/null
  LG mut-a thread open "$CH" "$TH" --subject t --participants mut-a,mut-b --body t >/dev/null
  MUT_M1="$(_msgid "$(LG mut-a send "$CH" --thread "$TH" --kind note --subject s1 --body b1)")"
  MUT_REAL="$T/mut-a/.forge/scripts/liaison-ops.sh"
  cp "$MUT_REAL" "$T/mut-a-original.sh"
  cp "$LIAISON_MUT" "$MUT_REAL"
  set +e
  MUT_SYNC_OUT="$(LG mut-a sync "$CH" 2>&1)"; MUT_SYNC_RC=$?
  MUT_ST_OUT="$(LG mut-a status "$CH" 2>&1)"
  set -e
  cp "$T/mut-a-original.sh" "$MUT_REAL"
  if [ "$MUT_SYNC_RC" -ne 0 ]; then
    echo "FAIL [6]: sync mutado saiu rc=$MUT_SYNC_RC (deveria continuar publicando, só sem gravar a marca): $MUT_SYNC_OUT"
    FAIL=1
  elif ! grep -qE '[1-9][0-9]* própria\(s\) não publicada\(s\)' <<<"$MUT_ST_OUT"; then
    echo "FAIL [6]: mutante (published não gravado) NÃO deixou contagem > 0 pós-sync — o gate não está medindo o mecanismo certo: $MUT_ST_OUT"
    FAIL=1
  else
    echo "  ok: mutante reintroduz o defeito da issue #109 (contagem > 0 mesmo depois do sync): $MUT_ST_OUT"
  fi
  # recontrole: cópia intocada continua idêntica ao arquivo real
  if ! cmp -s "$LIAISON_SRC" "$WS/template/.forge/scripts/liaison-ops.sh"; then
    echo "FAIL [6]: recontrole — o arquivo real do template mudou durante o teste (não deveria)"
    FAIL=1
  else
    echo "OK [6]"
  fi
fi

if [ "$FAIL" -ne 0 ]; then
  echo "GATE W259: FAIL"
  exit 1
fi
echo "PASS w259-liaison-outbox-watermark-gate"
