#!/usr/bin/env bash
# Gate W140 — recuperação do liaison sob reescrita de história e sob backlog acima do teto (issue #48).
#
# Os dois defeitos que este gate fixa são de SILÊNCIO, não de corrupção: o canal continuava
# reportando "OK" enquanto um remetente inteiro ficava invisível. Por isso cada cenário exige
# observar mensagens APLICADAS — um teste de quarentena que não vê nenhuma aplicação passaria por
# acidente exatamente no estado defeituoso.
#
#   [1] divergência em DUAS posições quarentena SÓ elas — as 73 posteriores são aplicadas
#   [2] conflicts/ nomeia CADA posição quarentenada (não um agregado por remetente)
#   [3] a réplica MANTÉM a versão conhecida das posições divergentes (não há buraco no log)
#   [4] bundle com DUAS versões da mesma posição quarentena a posição inteira (nenhuma aplicada)
#   [5] backlog acima do teto é aplicado em LOTES — sync repetido converge, nada de "nada foi aplicado"
#   [6] o lote é prefixo determinístico por seq — nunca abre buraco de seq no log local
#   [7] status e render NOMEIAM as posições em quarentena (remetente, seq, msg_id), não só um total
#   [8] resolvida a divergência na origem, o registro de quarentena some (não fica ruído eterno)
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
T="$(mktemp -d /tmp/forge-w140.XXXXXX)"
trap 'rm -rf "$T"' EXIT

CH=contract-rewrite
CH2=backlog-canal
HUB="$T/hub"
HUB2="$T/hub2"
SELF=axis-fare-validator
PEER=axis-go-cloud
TWIN=axis-pad-simulator
BULK=axis-device-platform

mk_repo() {
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/" || return 1
  cp -R "$WS/template/.forge/templates" "$dir/.forge/" || return 1
  git -C "$dir" init -q || return 1
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null
}

LG() { # LG <repo> <args...>
  local repo="$1"; shift
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"
}

# gen_log <outfile> <channel> <sender> <thread> <n> [marks-json] [twin-seq]
# Escreve o log completo de um remetente com seq 1..n (seq=1 é o thread-open). `marks` reescreve o
# subject de posições nomeadas (mesmo msg_id, mesmo seq, content_sha diferente = história
# reescrita). `twin-seq` duplica aquela posição com um segundo msg_id e outro conteúdo — o caso
# "duas cópias do mesmo log escrevendo em paralelo".
# O content_sha vem SEMPRE de computeContentSha real; o teste nunca reimplementa o hash.
gen_log() {
  local marks="${6:-}"
  [ -n "$marks" ] || marks='{}'
  node - "$LIB" "$1" "$2" "$3" "$4" "$5" "$marks" "${7:-0}" <<'NODEEOF'
const { writeFileSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, out, channel, sender, thread, nRaw, marksRaw, twinRaw] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const n = Number(nRaw);
  const marks = JSON.parse(marksRaw);
  const twinSeq = Number(twinRaw);
  const mk = (seq, suffix, idSuffix) => {
    const msg = {
      msg_id: `${sender}-${String(seq).padStart(4, '0')}${idSuffix || ''}`,
      channel,
      thread_id: thread,
      sender,
      seq,
      lamport: seq,
      kind: seq === 1 ? 'thread-open' : 'note',
      in_reply_to: null,
      requires_ack: false,
      subject: `msg ${seq}${suffix ? ' — ' + suffix : ''}`,
      refs: { change_id: null, contract_files: [], commit: null },
      created_at: '2026-01-01T00:00:00Z',
      trust: 'self',
    };
    if (seq === 1) msg.participants = [sender, 'axis-fare-validator'];
    msg.content_sha = M.computeContentSha(msg);
    return JSON.stringify(msg);
  };
  const lines = [];
  for (let seq = 1; seq <= n; seq++) {
    lines.push(mk(seq, marks[String(seq)] || '', ''));
    if (seq === twinSeq) lines.push(mk(seq, 'GEMEA PARALELA', 'b'));
  }
  writeFileSync(out, lines.join('\n') + '\n');
})();
NODEEOF
}

seqs_of() { # seqs_of <jsonl> -> seqs ordenados separados por espaço ('' se ausente/vazio)
  node -e '
const fs = require("fs");
const p = process.argv[1];
if (!fs.existsSync(p)) { process.stdout.write(""); process.exit(0); }
const s = fs.readFileSync(p, "utf8").trim();
if (!s) { process.stdout.write(""); process.exit(0); }
process.stdout.write(s.split("\n").map((l) => JSON.parse(l).seq).sort((a, b) => a - b).join(" "));
' "$1"
}

field_at() { # field_at <jsonl> <seq> <campo>
  node -e '
const fs = require("fs");
const [p, seq, f] = process.argv.slice(1);
if (!fs.existsSync(p)) { process.stdout.write(""); process.exit(0); }
const s = fs.readFileSync(p, "utf8").trim();
if (!s) { process.stdout.write(""); process.exit(0); }
const m = s.split("\n").map((l) => JSON.parse(l)).find((x) => Number(x.seq) === Number(seq));
process.stdout.write(m ? String(m[f]) : "");
' "$1" "$2" "$3"
}

contiguous_from_1() { # contiguous_from_1 "<seqs>" <n> -> rc 0 se for exatamente 1..n sem buraco
  local expected="" i=1
  while [ "$i" -le "$2" ]; do expected="$expected $i"; i=$((i + 1)); done
  [ "$1" = "${expected# }" ]
}

REPLOG="$T/rep/.forge/liaison/$CH/log/$PEER.jsonl"
CONF="$T/rep/.forge/liaison/$CH/conflicts"

# --- montagem -----------------------------------------------------------------------------------
mk_repo rep || { echo "FAIL [setup]: não foi possível montar o repositório de teste"; exit 1; }
LG rep open "$CH" --self "$SELF" --participants "$SELF,$PEER,$TWIN" >/dev/null \
  || { echo "FAIL [setup]: open do canal $CH reprovou"; exit 1; }
LG rep transport set "$CH" --kind fs --path "$HUB" >/dev/null \
  || { echo "FAIL [setup]: transport set reprovou"; exit 1; }
LG rep transport probe "$CH" >/dev/null \
  || { echo "FAIL [setup]: probe do transporte fs reprovou"; exit 1; }

# Estado inicial: o hub tem o remetente completo até seq=131 e a réplica sincroniza tudo.
gen_log "$HUB/$CH/log/$PEER.jsonl" "$CH" "$PEER" contract-thread 131 || { echo "FAIL [setup]: gen_log inicial falhou"; exit 1; }
out0="$(LG rep sync "$CH" 2>&1)"
grep -q "131 nova" <<<"$out0" || { echo "FAIL [setup]: réplica não recebeu as 131 mensagens iniciais: $out0"; exit 1; }
sha130_antes="$(field_at "$REPLOG" 130 content_sha)"
sha131_antes="$(field_at "$REPLOG" 131 content_sha)"
[ -n "$sha130_antes" ] && [ -n "$sha131_antes" ] \
  || { echo "FAIL [setup]: posições 130/131 não existem na réplica — cenário sem valor"; exit 1; }

echo "[1] divergência em duas posições quarentena só elas — as 73 posteriores são aplicadas"
# Cenário LITERAL da issue: reescreve seq=130 e seq=131 já replicadas (mesmo msg_id, mesmo seq,
# content_sha diferente) e publica 73 mensagens novas depois (132..204).
gen_log "$HUB/$CH/log/$PEER.jsonl" "$CH" "$PEER" contract-thread 204 \
  '{"130":"HISTORIA REESCRITA","131":"HISTORIA REESCRITA"}' \
  || { echo "FAIL [1]: gen_log da reescrita falhou"; exit 1; }
out1="$(LG rep sync "$CH" 2>&1)"; rc1=$?
grep -q "73 nova" <<<"$out1" \
  || { echo "FAIL [1]: as 73 mensagens posteriores à divergência não foram aplicadas — saída: $out1"; exit 1; }
seqs1="$(seqs_of "$REPLOG")"
[ -n "$seqs1" ] || { echo "FAIL [1]: log local vazio — nenhuma mensagem observada, cenário vazio"; exit 1; }
n1="$(wc -w <<<"$seqs1" | tr -d ' ')"
[ "$n1" -eq 204 ] || { echo "FAIL [1]: réplica ficou com $n1 mensagens, esperado 204"; exit 1; }
contiguous_from_1 "$seqs1" 204 || { echo "FAIL [1]: seq não contíguo 1..204 na réplica: $seqs1"; exit 1; }
[ "$rc1" -ne 0 ] || { echo "FAIL [1]: sync com reescrita de história deveria sair com rc != 0 (sinal alto)"; exit 1; }
grep -q "divergência" <<<"$out1" || { echo "FAIL [1]: saída não reporta divergência: $out1"; exit 1; }
echo "OK [1]"

echo "[2] conflicts/ nomeia cada posição quarentenada, não um agregado por remetente"
for s in 130 131; do
  [ -f "$CONF/$PEER.seq-$s.divergence.json" ] \
    || { echo "FAIL [2]: posição seq=$s não tem registro próprio em conflicts/ (achado: $(ls "$CONF" 2>/dev/null | tr '\n' ' '))"; exit 1; }
  grep -q "\"seq\": $s" "$CONF/$PEER.seq-$s.divergence.json" \
    || { echo "FAIL [2]: registro de seq=$s não carrega o campo seq"; cat "$CONF/$PEER.seq-$s.divergence.json"; exit 1; }
  grep -q "\"sender\": \"$PEER\"" "$CONF/$PEER.seq-$s.divergence.json" \
    || { echo "FAIL [2]: registro de seq=$s não nomeia o remetente"; cat "$CONF/$PEER.seq-$s.divergence.json"; exit 1; }
done
[ ! -f "$CONF/$PEER.divergence.json" ] \
  || { echo "FAIL [2]: registro agregado por remetente ainda existe — não dá para agir sobre a posição"; exit 1; }
n_reg="$(find "$CONF" -name "$PEER.seq-*.divergence.json" | wc -l | tr -d ' ')"
[ "$n_reg" -eq 2 ] || { echo "FAIL [2]: esperados 2 registros de posição, achados $n_reg"; exit 1; }
echo "OK [2]"

echo "[3] a réplica mantém a versão conhecida das posições divergentes (sem buraco no log)"
[ "$(field_at "$REPLOG" 130 content_sha)" = "$sha130_antes" ] \
  || { echo "FAIL [3]: seq=130 local foi sobrescrito pela versão reescrita"; exit 1; }
[ "$(field_at "$REPLOG" 131 content_sha)" = "$sha131_antes" ] \
  || { echo "FAIL [3]: seq=131 local foi sobrescrito pela versão reescrita"; exit 1; }
grep -q "REESCRITA" "$REPLOG" && { echo "FAIL [3]: conteúdo reescrito entrou na réplica"; exit 1; }
echo "OK [3]"

echo "[4] bundle com duas versões da mesma posição quarentena a posição inteira"
gen_log "$HUB/$CH/log/$TWIN.jsonl" "$CH" "$TWIN" twin-thread 5 '{}' 3 \
  || { echo "FAIL [4]: gen_log do gêmeo falhou"; exit 1; }
out4="$(LG rep sync "$CH" 2>&1)"
twinlog="$T/rep/.forge/liaison/$CH/log/$TWIN.jsonl"
seqs4="$(seqs_of "$twinlog")"
[ -n "$seqs4" ] || { echo "FAIL [4]: nada do remetente gêmeo foi aplicado — a quarentena calou o remetente inteiro: $out4"; exit 1; }
[ "$seqs4" = "1 2 4 5" ] \
  || { echo "FAIL [4]: esperado '1 2 4 5' (seq=3 quarentenada por inteiro, demais aplicadas), obtido '$seqs4'"; exit 1; }
[ -f "$CONF/$TWIN.seq-3.divergence.json" ] \
  || { echo "FAIL [4]: posição gêmea seq=3 não foi registrada em conflicts/"; exit 1; }
echo "OK [4]"

echo "[5] backlog acima do teto é aplicado em lotes — sync repetido converge"
LG rep open "$CH2" --participants "$SELF,$BULK" >/dev/null \
  || { echo "FAIL [5]: open do canal $CH2 reprovou"; exit 1; }
LG rep transport set "$CH2" --kind fs --path "$HUB2" >/dev/null \
  || { echo "FAIL [5]: transport set do canal $CH2 reprovou"; exit 1; }
LG rep transport probe "$CH2" >/dev/null || { echo "FAIL [5]: probe do canal $CH2 reprovou"; exit 1; }
gen_log "$HUB2/$CH2/log/$BULK.jsonl" "$CH2" "$BULK" backlog-thread 205 \
  || { echo "FAIL [5]: gen_log do backlog falhou"; exit 1; }
BULKLOG="$T/rep/.forge/liaison/$CH2/log/$BULK.jsonl"

out5a="$(LG rep sync "$CH2" 2>&1)"; rc5a=$?
grep -q "nada foi aplicado" <<<"$out5a" \
  && { echo "FAIL [5]: backlog acima do teto ainda vira estado terminal ('nada foi aplicado'): $out5a"; exit 1; }
[ "$rc5a" -eq 0 ] || { echo "FAIL [5]: primeiro lote deveria sair com rc 0 — saída: $out5a"; exit 1; }
grep -q "200 nova" <<<"$out5a" || { echo "FAIL [5]: primeiro lote não aplicou 200 mensagens: $out5a"; exit 1; }
grep -q "5 restante" <<<"$out5a" || { echo "FAIL [5]: primeiro lote não reporta quantas faltam: $out5a"; exit 1; }

out5b="$(LG rep sync "$CH2" 2>&1)"
grep -q "5 nova" <<<"$out5b" || { echo "FAIL [5]: segundo lote não aplicou as 5 restantes: $out5b"; exit 1; }
seqs5="$(seqs_of "$BULKLOG")"
[ -n "$seqs5" ] || { echo "FAIL [5]: log de backlog vazio — cenário sem valor"; exit 1; }
n5="$(wc -w <<<"$seqs5" | tr -d ' ')"
[ "$n5" -eq 205 ] || { echo "FAIL [5]: convergência incompleta — $n5 de 205 mensagens"; exit 1; }
out5c="$(LG rep sync "$CH2" 2>&1)"
grep -q "0 nova" <<<"$out5c" || { echo "FAIL [5]: sync após convergir não é no-op: $out5c"; exit 1; }
echo "OK [5]"

echo "[6] o lote é prefixo determinístico por seq — nunca abre buraco de seq"
# Refaz o mesmo backlog numa réplica limpa, com as linhas do bundle EMBARALHADAS: o prefixo
# aplicado tem de ser 1..200 mesmo assim (a ordem do arquivo não pode decidir o corte).
mk_repo rep2 || { echo "FAIL [6]: não foi possível montar rep2"; exit 1; }
LG rep2 open "$CH2" --self "$SELF" --participants "$SELF,$BULK" >/dev/null \
  || { echo "FAIL [6]: open em rep2 reprovou"; exit 1; }
LG rep2 transport set "$CH2" --kind fs --path "$T/hub3" >/dev/null || { echo "FAIL [6]: transport set em rep2 reprovou"; exit 1; }
LG rep2 transport probe "$CH2" >/dev/null || { echo "FAIL [6]: probe em rep2 reprovou"; exit 1; }
gen_log "$T/hub3/$CH2/log/$BULK.jsonl" "$CH2" "$BULK" backlog-thread 205 || { echo "FAIL [6]: gen_log em rep2 falhou"; exit 1; }
node -e '
const fs = require("fs");
const p = process.argv[1];
const lines = fs.readFileSync(p, "utf8").trim().split("\n");
lines.reverse();
fs.writeFileSync(p, lines.join("\n") + "\n");
' "$T/hub3/$CH2/log/$BULK.jsonl" || { echo "FAIL [6]: não foi possível embaralhar o bundle"; exit 1; }
out6="$(LG rep2 sync "$CH2" 2>&1)"
seqs6="$(seqs_of "$T/rep2/.forge/liaison/$CH2/log/$BULK.jsonl")"
[ -n "$seqs6" ] || { echo "FAIL [6]: nada aplicado em rep2 — cenário sem valor: $out6"; exit 1; }
n6="$(wc -w <<<"$seqs6" | tr -d ' ')"
[ "$n6" -eq 200 ] || { echo "FAIL [6]: lote aplicou $n6 mensagens, esperado exatamente 200"; exit 1; }
contiguous_from_1 "$seqs6" 200 || { echo "FAIL [6]: lote não é prefixo contíguo 1..200 (buraco de seq): $seqs6"; exit 1; }
echo "OK [6]"

echo "[7] status e render nomeiam as posições em quarentena (remetente, seq, msg_id)"
st7="$(LG rep status "$CH" 2>&1)"
grep -q "$PEER" <<<"$st7" || { echo "FAIL [7]: status não nomeia o remetente com posição em quarentena: $st7"; exit 1; }
grep -q "seq=130" <<<"$st7" || { echo "FAIL [7]: status não nomeia a posição seq=130: $st7"; exit 1; }
grep -q "$PEER-0130" <<<"$st7" || { echo "FAIL [7]: status não nomeia o msg_id da posição quarentenada: $st7"; exit 1; }
st7g="$(LG rep status 2>&1)"
grep -q "seq=130" <<<"$st7g" || { echo "FAIL [7]: status global não menciona posição em quarentena: $st7g"; exit 1; }
LG rep render "$CH" >/dev/null || { echo "FAIL [7]: render reprovou"; exit 1; }
CHMD="$T/rep/.forge/liaison/$CH/CHANNEL.md"
[ -f "$CHMD" ] || { echo "FAIL [7]: CHANNEL.md não foi gerado"; exit 1; }
grep -q "seq=130" "$CHMD" || { echo "FAIL [7]: CHANNEL.md não nomeia a posição seq=130"; exit 1; }
grep -q "$PEER-0131" "$CHMD" || { echo "FAIL [7]: CHANNEL.md não nomeia o msg_id da posição seq=131"; exit 1; }
echo "OK [7]"

echo "[8] resolvida a divergência na origem, o registro de quarentena some"
gen_log "$HUB/$CH/log/$PEER.jsonl" "$CH" "$PEER" contract-thread 204 \
  || { echo "FAIL [8]: gen_log da restauração falhou"; exit 1; }
out8="$(LG rep sync "$CH" 2>&1)"
grep -q "$PEER@seq=" <<<"$out8" \
  && { echo "FAIL [8]: sync ainda acusa divergência do remetente já restaurado: $out8"; exit 1; }
[ ! -f "$CONF/$PEER.seq-130.divergence.json" ] \
  || { echo "FAIL [8]: registro de quarentena sobreviveu à resolução — ruído eterno no status"; exit 1; }
seqs8="$(seqs_of "$REPLOG")"
[ "$(wc -w <<<"$seqs8" | tr -d ' ')" -eq 204 ] || { echo "FAIL [8]: réplica perdeu mensagens na restauração: $seqs8"; exit 1; }
st8="$(LG rep status "$CH" 2>&1)"
grep -q "seq=130" <<<"$st8" && { echo "FAIL [8]: status continua reportando quarentena já resolvida: $st8"; exit 1; }
# O registro do gêmeo (outro remetente) NÃO pode ser varrido junto — a limpeza é por posição.
[ -f "$CONF/$TWIN.seq-3.divergence.json" ] \
  || { echo "FAIL [8]: a limpeza apagou o registro de outro remetente ainda divergente"; exit 1; }
echo "OK [8]"

echo "PASS w140-liaison-quarantine-batch-gate"
