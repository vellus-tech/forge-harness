#!/usr/bin/env bash
# Gate — TASK-13/TASK-14 de add-liaison-handoff-baton (REQ-01, REQ-11, design §2.2/§2.3/§4.1):
#   [paridade] schema liaison-message.schema.json x validateEnvelope dão o mesmo veredito na
#     camada de ENVELOPE de baton (objeto, kind=note, requires_ack=false, op no padrão aberto)
#   [validate-baton] bateria de validateBaton, um caso por regra (campos por op, limites,
#     aritmética do lease, in_reply_to)
#   [content-sha] baton entra no content_sha
#   [fonte-unica] BATON_OPS/BATON_STATES/BATON_VERDICTS/BATON_VERB_FLAGS vêm de um só lugar
#   [compat] import da última tag publicada sem baton aceita as seis operações sem conflito;
#     import deste harness aceita op desconhecido sem conflito (malformed na dobra)
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
SCHEMA="$WS/template/.forge/schemas/liaison-message.schema.json"
T="$(mktemp -d /tmp/forge-liaison-baton-envelope.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0

# judge <tag> <output> <rc> — decide pass/fail de um probe isolado (nunca aborta o gate: sem
# set -e, uma falha inesperada de processo — import ausente, exceção não tratada — não teria
# "FAIL [...]" no próprio texto, e um grep simples a deixaria passar batido; o output cru vira
# FAIL [<tag>] explícito).
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

# [fonte-unica] liaison-ops.sh nunca declara uma segunda tabela de flags/ops/estados/vereditos —
# confere textualmente que ele só LÊ de liaison-baton.mjs, nunca redefine os arrays.
if grep -qE "^\s*(BATON_OPS|BATON_STATES|BATON_VERDICTS|BATON_VERB_FLAGS)\s*=" "$WS/template/.forge/scripts/liaison-ops.sh" 2>/dev/null; then
  echo "FAIL [fonte-unica]: liaison-ops.sh redefine uma das tabelas (deveria só importar de liaison-baton.mjs)"
  fail=1
fi

out="$(node --input-type=module -e "
import { BATON_OPS, BATON_STATES, BATON_VERDICTS, BATON_VERB_FLAGS } from '$LIB/liaison-baton.mjs';
const opsOk = Array.isArray(BATON_OPS) && BATON_OPS.length === 6;
const statesOk = Array.isArray(BATON_STATES) && BATON_STATES.length === 4;
const verdictsOk = Array.isArray(BATON_VERDICTS) && BATON_VERDICTS.length >= 15;
const flagsOk = typeof BATON_VERB_FLAGS === 'object' && Object.keys(BATON_VERB_FLAGS).length === 8;
console.log(opsOk && statesOk && verdictsOk && flagsOk ? 'OK fonte unica presente e com a forma esperada' : 'FAIL [fonte-unica]: forma inesperada ops='+opsOk+' states='+statesOk+' verdicts='+verdictsOk+' flags='+flagsOk);
" 2>&1)"; rc=$?
judge "fonte-unica" "$out" "$rc"

# === [paridade] bateria de envelopes válidos/inválidos: schema x validateEnvelope ===
out="$(node --input-type=module -e "
import { validateEnvelope, computeContentSha } from '$LIB/liaison-merge.mjs';
import { readFileSync } from 'node:fs';

function mk(partial) {
  const msg = { msg_id: 'repo-a-0001', channel: 'ch', thread_id: 't1', sender: 'repo-a', seq: 1, lamport: 1,
    kind: 'note', in_reply_to: null, requires_ack: false, subject: 'x', created_at: '2026-01-01T00:00:00Z', trust: 'self', ...partial };
  msg.content_sha = computeContentSha(msg);
  return msg;
}

const schema = JSON.parse(readFileSync('$SCHEMA', 'utf8'));
// mini-validador SÓ das regras de baton do schema (sem ajv em runtime, mesma disciplina do
// resto do repositório): confere os pontos que o allOf/properties declaram.
function schemaAcceptsBaton(msg) {
  if (!Object.prototype.hasOwnProperty.call(msg, 'baton') || msg.baton === null) return true;
  const b = msg.baton;
  if (typeof b !== 'object' || Array.isArray(b)) return false;
  if (typeof b.op !== 'string' || !/^[a-z][a-z-]{0,31}\$/.test(b.op)) return false;
  // allOf: baton presente exige kind=note e requires_ack=false
  if (msg.kind !== 'note') return false;
  if (msg.requires_ack !== false) return false;
  return true;
}

const cases = [
  ['objeto valido, kind note, requires_ack false', mk({ baton: { op: 'offer' } }), true],
  ['baton nao e objeto', mk({ baton: 'nope' }), false],
  ['kind diferente de note', mk({ kind: 'question', baton: { op: 'offer' } }), false],
  ['requires_ack true', mk({ requires_ack: true, baton: { op: 'offer' } }), false],
  ['op fora do padrao (maiuscula)', mk({ baton: { op: 'Offer' } }), false],
  ['op fora do padrao (muito longo)', mk({ baton: { op: 'a'.repeat(40) } }), false],
  ['op desconhecido mas no padrao (versao futura)', mk({ baton: { op: 'transfer' } }), true],
  ['sem baton', mk({}), true],
];

let bad = [];
for (const [label, msg, expected] of cases) {
  const schemaResult = schemaAcceptsBaton(msg);
  const envResult = validateEnvelope(msg).length === 0;
  if (schemaResult !== expected) bad.push('schema diverge do esperado em: ' + label + ' (schema=' + schemaResult + ' esperado=' + expected + ')');
  if (envResult !== expected) bad.push('validateEnvelope diverge do esperado em: ' + label + ' (validateEnvelope=' + envResult + ' esperado=' + expected + ')');
  if (schemaResult !== envResult) bad.push('schema e validateEnvelope DIVERGEM ENTRE SI em: ' + label);
}
console.log(bad.length ? 'FAIL [paridade]: ' + bad.join(' | ') : 'OK paridade schema x validateEnvelope em ' + cases.length + ' casos');
" 2>&1)"; rc=$?
judge "paridade" "$out" "$rc"

# === [content-sha] baton entra no content_sha ===
out="$(node --input-type=module -e "
import { computeContentSha } from '$LIB/liaison-merge.mjs';
const base = { msg_id: 'a-0001', channel: 'ch', thread_id: 't1', sender: 'a', seq: 1, lamport: 1, kind: 'note', in_reply_to: null, requires_ack: false, subject: 'x', created_at: '2026-01-01T00:00:00Z', trust: 'self', baton: { op: 'offer' } };
const sha1 = computeContentSha(base);
const changed = { ...base, baton: { op: 'offer', session: 's1' } };
const sha2 = computeContentSha(changed);
console.log(sha1 !== sha2 ? 'OK content_sha muda quando baton muda' : 'FAIL [content-sha]: content_sha nao mudou ao alterar subcampo de baton');
" 2>&1)"; rc=$?
judge "content-sha" "$out" "$rc"

# === [validate-baton] bateria, um caso por regra ===
out="$(node --input-type=module -e "
import { validateBaton } from '$LIB/liaison-baton.mjs';

function mk(baton, extra) {
  return { msg_id: 'a-0001', channel: 'ch', thread_id: 't1', sender: 'a', seq: 1, lamport: 1, kind: 'note',
    in_reply_to: baton && baton.op === 'offer' ? null : 'a-0000', requires_ack: false, subject: 'x',
    created_at: '2026-01-01T00:00:00Z', trust: 'self', baton, ...extra };
}

const validOffer = { op: 'offer', session: 's1', stamped_at: '2026-01-01T00:00:00Z', eligible: ['a', 'b'], max_lease_seconds: 14400, skew_tolerance_seconds: 120 };
const validClaim = { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:00:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:30:00Z' };
const validRelease = { op: 'release', session: 's1', stamped_at: '2026-01-01T00:00:00Z' };

const cases = [
  ['offer valida', mk(validOffer), true],
  ['claim valida', mk(validClaim), true],
  ['release valida', mk(validRelease), true],
  ['op fora do conjunto fechado', mk({ ...validOffer, op: 'transfer' }), false],
  ['session ausente', mk({ ...validClaim, session: undefined }), false],
  ['session fora do padrao', mk({ ...validClaim, session: '!!!' }), false],
  ['stamped_at ausente', mk({ ...validClaim, stamped_at: undefined }), false],
  ['stamped_at sem Z', mk({ ...validClaim, stamped_at: '2026-01-01T00:00:00' }), false],
  ['offer sem eligible', mk({ op: 'offer', session: 's1', stamped_at: '2026-01-01T00:00:00Z', max_lease_seconds: 14400, skew_tolerance_seconds: 120 }), false],
  ['claim com eligible (proibido fora de offer)', mk({ ...validClaim, eligible: ['a'] }), false],
  ['eligible vazio', mk({ ...validOffer, eligible: [] }), false],
  ['eligible com 65 itens', mk({ ...validOffer, eligible: Array.from({length:65}, (_,i)=>'r'+i) }), false],
  ['eligible com id repetido', mk({ ...validOffer, eligible: ['a', 'a'] }), false],
  ['eligible com id fora do padrao', mk({ ...validOffer, eligible: ['A!'] }), false],
  ['max_lease_seconds abaixo do minimo', mk({ ...validOffer, max_lease_seconds: 10 }), false],
  ['max_lease_seconds acima do maximo', mk({ ...validOffer, max_lease_seconds: 999999 }), false],
  ['skew_tolerance_seconds negativo', mk({ ...validOffer, skew_tolerance_seconds: -1 }), false],
  ['skew_tolerance_seconds acima do maximo', mk({ ...validOffer, skew_tolerance_seconds: 99999 }), false],
  ['renew sem lease_seconds', mk({ op: 'renew', session: 's1', stamped_at: '2026-01-01T00:00:00Z', lease_until: '2026-01-01T00:30:00Z' }), false],
  ['offer com lease_seconds (proibido)', mk({ ...validOffer, lease_seconds: 1800 }), false],
  ['lease_seconds abaixo do minimo', mk({ ...validClaim, lease_seconds: 10, lease_until: '2026-01-01T00:00:10Z' }), false],
  ['lease_seconds acima do maximo', mk({ ...validClaim, lease_seconds: 999999, lease_until: '2026-01-02T05:46:39Z' }), false],
  ['lease_until nao bate com stamped_at + lease_seconds', mk({ ...validClaim, lease_until: '2026-01-01T09:99:99Z' }), false],
  ['lease_until aritmetica errada (1s a mais)', mk({ ...validClaim, lease_until: '2026-01-01T00:30:01Z' }), false],
  ['in_reply_to null fora de offer', mk({ ...validClaim }, { in_reply_to: null }), false],
  ['in_reply_to presente em offer', mk({ ...validOffer }, { in_reply_to: 'a-0000' }), false],
  ['baton ausente', { msg_id: 'a-0001', channel: 'ch', thread_id: 't1', sender: 'a', seq: 1, lamport: 1, kind: 'note', in_reply_to: null, requires_ack: false, subject: 'x', created_at: '2026-01-01T00:00:00Z', trust: 'self' }, false],
];

let bad = [];
for (const [label, msg, expectValid] of cases) {
  const errs = validateBaton(msg);
  const isValid = errs.length === 0;
  if (isValid !== expectValid) bad.push(label + ' (esperado valido=' + expectValid + ', achou errors=' + JSON.stringify(errs) + ')');
}
console.log(bad.length ? 'FAIL [validate-baton]: ' + bad.join(' | ') : 'OK validateBaton em ' + cases.length + ' casos');
" 2>&1)"; rc=$?
judge "validate-baton" "$out" "$rc"

# === [compat] import deste harness aceita op desconhecido, sem conflito; dobra dá malformed ===
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
LG() { local root="$1"; shift; FORGE_ROOT="$root" bash "$root/.forge/scripts/liaison-ops.sh" "$@"; }

mk_repo recv
LG "$T/recv" open ch1 --self repo-a --participants repo-a,repo-b >/dev/null
LG "$T/recv" thread open ch1 t1 --subject gate --participants repo-a,repo-b --body open >/dev/null

mkdir -p "$T/bundle-future/log"
node --input-type=module -e "
import { computeContentSha } from '$LIB/liaison-merge.mjs';
import { writeFileSync } from 'node:fs';
const msg = { msg_id: 'repo-b-0001', channel: 'ch1', thread_id: 't1', sender: 'repo-b', seq: 1, lamport: 2, kind: 'note',
  in_reply_to: 'repo-a-0001', requires_ack: false, subject: 'baton transfer: x',
  created_at: '2026-01-01T00:00:00Z', trust: 'self', baton: { op: 'transfer', session: 's9', stamped_at: '2026-01-01T00:00:00Z' } };
msg.content_sha = computeContentSha(msg);
writeFileSync('$T/bundle-future/log/repo-b.jsonl', JSON.stringify(msg) + '\n');
"
import_out="$(LG "$T/recv" import ch1 --from "$T/bundle-future" 2>&1)"; import_rc=$?
if [ "$import_rc" -ne 0 ]; then
  echo "FAIL [compat]: import de mensagem com op desconhecido foi recusado (esperava aceitar sem conflito): $import_out"
  fail=1
else
  conflicts_dir="$T/recv/.forge/liaison/ch1/conflicts"
  conflict_count=0
  [ -d "$conflicts_dir" ] && conflict_count="$(find "$conflicts_dir" -type f | wc -l | tr -d ' ')"
  if [ "${conflict_count:-0}" != "0" ]; then
    echo "FAIL [compat]: import de op desconhecido gerou conflito/quarentena (esperava aceitar)"
    fail=1
  else
    fold_out="$(node --input-type=module -e "
      import { readFileSync, readdirSync } from 'node:fs';
      import { join } from 'node:path';
      import { foldBatons } from '$LIB/liaison-baton.mjs';
      const logDir = '$T/recv/.forge/liaison/ch1/log';
      const all = [];
      for (const f of readdirSync(logDir)) for (const line of readFileSync(join(logDir, f), 'utf8').split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
      const { orphans } = foldBatons(all);
      const op = all.find((m) => m.baton && m.baton.op === 'transfer');
      console.log(op ? 'present' : 'absent');
    " 2>&1)"
    echo "$fold_out" | grep -q "^present\$" && echo "OK [compat]: import aceitou op desconhecido sem conflito (verificado também que a mensagem está no log)" || { echo "FAIL [compat]: $fold_out"; fail=1; }
  fi
fi

# === [compat] a última tag publicada sem `baton` no schema aceita as seis operações ===
LAST_TAG=""
while IFS= read -r tag; do
  cnt="$(git -C "$WS" show "$tag:template/.forge/schemas/liaison-message.schema.json" 2>/dev/null | grep -c '"baton"' || true)"
  if [ "${cnt:-0}" = "0" ]; then LAST_TAG="$tag"; break; fi
done < <(git -C "$WS" tag --sort=-v:refname 2>/dev/null)

if [ -z "$LAST_TAG" ]; then
  echo "FAIL [compat]: nenhuma tag publicada sem 'baton' no schema foi encontrada — gate não pode provar compatibilidade"
  fail=1
else
  OLD_IMPORT="$T/old-import.mjs"
  git -C "$WS" show "$LAST_TAG:template/.forge/scripts/lib/liaison-import.mjs" > "$OLD_IMPORT" 2>/dev/null
  # liaison-import.mjs importa './liaison-merge.mjs' por caminho relativo — precisa estar ao
  # lado, na mesma versão da tag (é a dupla que o import realmente usa, não a atual).
  git -C "$WS" show "$LAST_TAG:template/.forge/scripts/lib/liaison-merge.mjs" > "$T/liaison-merge.mjs" 2>/dev/null
  mk_repo oldtag
  LG "$T/oldtag" open ch1 --self repo-a --participants repo-a,repo-b >/dev/null
  LG "$T/oldtag" thread open ch1 t1 --subject gate --participants repo-a,repo-b --body open >/dev/null

  mkdir -p "$T/bundle-sixops/log"
  node --input-type=module -e "
    import { computeContentSha } from '$LIB/liaison-merge.mjs';
    import { writeFileSync } from 'node:fs';
    const ops = ['offer', 'claim', 'renew', 'release', 'complete', 'withdraw'];
    const lines = [];
    let seq = 1;
    for (const op of ops) {
      const msg = {
        msg_id: 'repo-b-' + String(seq).padStart(4, '0'), channel: 'ch1', thread_id: 't1', sender: 'repo-b', seq, lamport: seq + 1,
        kind: 'note', in_reply_to: op === 'offer' ? null : 'repo-a-0001', requires_ack: false,
        subject: op === 'offer' ? 'oferta de teste' : ('baton ' + op + ': oferta de teste'),
        created_at: '2026-01-01T00:0' + seq + ':00Z', trust: 'self',
        baton: { op, session: 's9', stamped_at: '2026-01-01T00:0' + seq + ':00Z',
          ...(op === 'offer' ? { eligible: ['repo-a', 'repo-b'], max_lease_seconds: 14400, skew_tolerance_seconds: 120 } : {}),
          ...(op === 'claim' || op === 'renew' ? { lease_seconds: 1800, lease_until: '2026-01-01T00:3' + seq + ':00Z' } : {}),
        },
      };
      msg.content_sha = computeContentSha(msg);
      lines.push(JSON.stringify(msg));
      seq++;
    }
    writeFileSync('$T/bundle-sixops/log/repo-b.jsonl', lines.join('\n') + '\n');
  "

  old_import_out="$(node --input-type=module -e "
    const mod = await import('file://$OLD_IMPORT');
    const res = mod.applyBundle({ chDir: '$T/oldtag/.forge/liaison/ch1', fromDir: '$T/bundle-sixops', self: 'repo-a' });
    console.log(JSON.stringify(res));
  " 2>&1)"
  # checa os CONTADORES numéricos do resultado (conflicts/quarantined), nunca a presença textual
  # da palavra — o próprio JSON de sucesso tem as chaves 'conflicts'/'quarantined' com valor 0,
  # e um grep textual acharia a palavra mesmo no caminho feliz (achado real, não hipotético).
  bad_counts="$(node -e "
    try {
      const res = JSON.parse(process.argv[1].trim().split('\n').pop());
      console.log((Number(res.conflicts) > 0 || Number(res.quarantined) > 0) ? 'bad' : 'ok');
    } catch (e) { console.log('parse-error'); }
  " "$old_import_out" 2>/dev/null)"
  if [ "$bad_counts" != "ok" ]; then
    echo "FAIL [compat]: a última tag sem 'baton' ($LAST_TAG) tratou alguma operação como conflito/quarentena (ou saída ilegível): $old_import_out"
    fail=1
  else
    landed="$(node -e "
      const fs = require('fs');
      const f = '$T/oldtag/.forge/liaison/ch1/log/repo-b.jsonl';
      if (!fs.existsSync(f)) { console.log(0); process.exit(0); }
      console.log(fs.readFileSync(f, 'utf8').trim().split('\n').filter(Boolean).length);
    ")"
    [ "$landed" = "6" ] && echo "OK [compat]: a última tag sem baton ($LAST_TAG) aceitou as seis operações sem conflito" || { echo "FAIL [compat]: esperava 6 mensagens aceitas pela tag $LAST_TAG, achei $landed ($old_import_out)"; fail=1; }
  fi
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — forma do bastao em duas camadas: paridade, validateBaton, content_sha, fonte unica, compat"
exit 0
