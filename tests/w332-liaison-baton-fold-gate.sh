#!/usr/bin/env bash
# Gate — TASK-15/TASK-16 de add-liaison-handoff-baton (REQ-04, REQ-05, REQ-06, NFR-02):
#   [veredito-*] um caso de teste por linha da tabela fechada do REQ-04 (21 vereditos)
#   [permutacao] 200 permutações aleatórias da mesma entrada dão estado e vereditos idênticos
#   [replicas] duas réplicas que importaram o mesmo conjunto em ordens diferentes convergem
#   [stable] provisório/estável com três repositórios elegíveis, buraco de seq, eligible restrito
#   [clock-skew] detectClockSkew ignora mensagens com baton
#   [perf-dobra] a dobra sobre uma thread de 2.000 mensagens de bastão completa em <= 500ms p95
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"

fail=0

judge() {
  local tag="$1" out="$2" rc="$3"
  if echo "$out" | grep -q '^FAIL \['; then
    echo "$out"
    fail=1
  elif [ "$rc" -ne 0 ]; then
    echo "FAIL [$tag]: comando falhou inesperadamente (rc=$rc): $(echo "$out" | tr '\n' ' ' | cut -c1-300)"
    fail=1
  else
    echo "$out"
  fi
}

# Todo o corpo pesado roda num único processo node (mais rápido que 21 processos separados) —
# um script JS completo, com um helper de fixture compartilhado.
out="$(node --input-type=module -e "
import { foldBatons, stability } from '$LIB/liaison-baton.mjs';
import { computeContentSha, detectClockSkew } from '$LIB/liaison-merge.mjs';

let seqCounters = {};
function nextSeq(sender) { seqCounters[sender] = (seqCounters[sender] || 0) + 1; return seqCounters[sender]; }

function mk(sender, threadId, lamport, batonFields, opts) {
  opts = opts || {};
  const seq = opts.seq !== undefined ? opts.seq : nextSeq(sender);
  const op = batonFields ? batonFields.op : null;
  const inReplyTo = opts.in_reply_to !== undefined ? opts.in_reply_to : (op === 'offer' || !op ? null : 'OFFER');
  const msg = {
    msg_id: sender + '-' + String(seq).padStart(4, '0'), channel: 'ch', thread_id: threadId,
    sender, seq, lamport, kind: 'note', in_reply_to: inReplyTo, requires_ack: false,
    subject: op === 'offer' ? 'work' : ('baton ' + op + ': work'),
    created_at: '2026-01-01T00:00:00Z', trust: 'self',
    ...(batonFields ? { baton: batonFields } : {}),
    ...(opts.extra || {}),
  };
  if (opts.rawContentSha !== undefined) msg.content_sha = opts.rawContentSha;
  else msg.content_sha = computeContentSha(msg);
  return msg;
}

const results = [];
function check(tag, cond, detail) {
  results.push(cond ? null : ('FAIL [' + tag + ']: ' + detail));
}

// --- fixture base compartilhada: offer de repo-a (msg_id repo-a-0001), eligible [repo-a,repo-b], max_lease=14400, skew=120
const OFFER_ID = 'repo-a-0001';
function offer(threadId, extra, seqOverride) {
  return mk('repo-a', threadId, 1, { op: 'offer', session: 'sO', stamped_at: '2026-01-01T00:00:00Z', eligible: ['repo-a', 'repo-b'], max_lease_seconds: 14400, skew_tolerance_seconds: 120, ...(extra || {}) }, { seq: seqOverride || 1 });
}

// 1. forked — mesmo sender/seq, content_sha diferente, em threads DIFERENTES.
{
  const o = offer('t1');
  const claimA = mk('repo-b', 't1', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: OFFER_ID });
  const claimAFork = { ...claimA, subject: 'DIFERENTE', content_sha: 'f'.repeat(64) }; // mesma sender/seq, sha diferente, outra thread
  const o2 = offer('t2', { stamped_at: '2026-01-01T00:00:00Z' }, 2); // seq diferente de 'o' — nao e o fork em teste aqui
  const claimAForkInT2 = { ...claimAFork, thread_id: 't2', in_reply_to: o2.msg_id };
  const { batons, orphans } = foldBatons([o, claimA, o2, claimAForkInT2]);
  const histT1 = (batons.get(o.msg_id) || { history: [] }).history;
  const histT2 = (batons.get(o2.msg_id) || { history: [] }).history;
  const vT1 = histT1.find((h) => h.msgId === claimA.msg_id);
  const vT2 = (histT2.find((h) => h.msgId === claimAForkInT2.msg_id)) || orphans.find((h) => h.msgId === claimAForkInT2.msg_id);
  check('veredito-forked', vT1 && vT1.verdict === 'forked' && vT2 && vT2.verdict === 'forked', 'esperava forked nas duas threads, achou ' + JSON.stringify([vT1, vT2]));
}

// 2. malformed — op desconhecido.
{
  const o = offer('t2b');
  const bad = mk('repo-b', 't2b', 2, { op: 'transfer', session: 's1', stamped_at: '2026-01-01T00:01:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, bad]);
  const v = batons.get(o.msg_id).history.find((h) => h.msgId === bad.msg_id);
  check('veredito-malformed', v && v.verdict === 'malformed', 'esperava malformed, achou ' + JSON.stringify(v));
}

// 3. offered.
{
  const o = offer('t3');
  const { batons } = foldBatons([o]);
  const b = batons.get(o.msg_id);
  check('veredito-offered', b && b.state === 'available' && b.history[0].verdict === 'offered', 'esperava available/offered, achou ' + JSON.stringify(b));
}

// 4. pending-offer — oferta referida ausente da réplica.
{
  const claim = mk('repo-b', 't4', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: 'repo-a-9999' });
  const { orphans } = foldBatons([claim]);
  const v = orphans.find((h) => h.msgId === claim.msg_id);
  check('veredito-pending-offer', v && v.verdict === 'pending-offer', 'esperava pending-offer, achou ' + JSON.stringify(v));
}

// 5. wrong-thread — oferta existe mas em outra thread.
{
  const o = offer('t5a');
  const claimWrong = mk('repo-b', 't5b', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const { orphans, batons } = foldBatons([o, claimWrong]);
  const v = orphans.find((h) => h.msgId === claimWrong.msg_id) || (batons.get(o.msg_id) && batons.get(o.msg_id).history.find((h) => h.msgId === claimWrong.msg_id));
  check('veredito-wrong-thread', v && v.verdict === 'wrong-thread', 'esperava wrong-thread, achou ' + JSON.stringify(v));
}

// 6. not-an-offer — in_reply_to aponta para mensagem presente que não é oferta aplicável.
{
  const o = offer('t6');
  const note = mk('repo-b', 't6', 2, null, { seq: 1, in_reply_to: null });
  const claimToNote = mk('repo-b', 't6', 3, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 2, in_reply_to: note.msg_id });
  const { orphans, batons } = foldBatons([o, note, claimToNote]);
  const v = orphans.find((h) => h.msgId === claimToNote.msg_id) || (batons.get(o.msg_id) && batons.get(o.msg_id).history.find((h) => h.msgId === claimToNote.msg_id));
  check('veredito-not-an-offer', v && v.verdict === 'not-an-offer', 'esperava not-an-offer, achou ' + JSON.stringify(v));
}

// 7. before-offer — oferta na mesma thread mas depois na ordem (carimbo de ordem forjado: lamport da claim MENOR que o da oferta).
{
  const claimEarly = mk('repo-b', 't7', 1, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: 'repo-a-0001' });
  const o = mk('repo-a', 't7', 2, { op: 'offer', session: 'sO', stamped_at: '2026-01-01T00:00:00Z', eligible: ['repo-a', 'repo-b'], max_lease_seconds: 14400, skew_tolerance_seconds: 120 }, { seq: 1 });
  const { batons, orphans } = foldBatons([claimEarly, o]);
  // No instante em que claimEarly é processada (antes de 'o' na ordem da thread), o bastão
  // ainda não existe — por isso o veredito vai para orphans, não para o history do bastão (que
  // só passa a existir quando 'o' é processada, mais tarde na mesma passada).
  const v = orphans.find((h) => h.msgId === claimEarly.msg_id) || (batons.get(o.msg_id) && batons.get(o.msg_id).history.find((h) => h.msgId === claimEarly.msg_id));
  check('veredito-before-offer', v && v.verdict === 'before-offer', 'esperava before-offer, achou ' + JSON.stringify(v));
}

// 8. closed — bastão já completed/withdrawn.
{
  const o = offer('t8');
  const claim = mk('repo-b', 't8', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const complete = mk('repo-b', 't8', 3, { op: 'complete', session: 's1', stamped_at: '2026-01-01T00:02:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const afterward = mk('repo-b', 't8', 4, { op: 'release', session: 's1', stamped_at: '2026-01-01T00:03:00Z' }, { seq: 3, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claim, complete, afterward]);
  const v = batons.get(o.msg_id).history.find((h) => h.msgId === afterward.msg_id);
  check('veredito-closed', v && v.verdict === 'closed', 'esperava closed, achou ' + JSON.stringify(v));
}

// 9. lease-over-max.
{
  const o = offer('t9');
  const claimOver = mk('repo-b', 't9', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 20000, lease_until: '2026-01-01T05:34:20Z' }, { seq: 1, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claimOver]);
  const v = batons.get(o.msg_id).history.find((h) => h.msgId === claimOver.msg_id);
  check('veredito-lease-over-max', v && v.verdict === 'lease-over-max', 'esperava lease-over-max, achou ' + JSON.stringify(v));
}

// 10. not-eligible.
{
  const o = offer('t10');
  const claimOutsider = mk('repo-c', 't10', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claimOutsider]);
  const v = batons.get(o.msg_id).history.find((h) => h.msgId === claimOutsider.msg_id);
  check('veredito-not-eligible', v && v.verdict === 'not-eligible', 'esperava not-eligible, achou ' + JSON.stringify(v));
}

// 11. won (bastão available).
{
  const o = offer('t11');
  const claim = mk('repo-b', 't11', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claim]);
  const b = batons.get(o.msg_id);
  check('veredito-won', b.state === 'held' && b.history[1].verdict === 'won', 'esperava held/won, achou ' + JSON.stringify(b));
}

// 12. duplicate-claim — titular corrente reclama de novo com carimbo <= T.
{
  const o = offer('t12');
  const claim = mk('repo-b', 't12', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const dup = mk('repo-b', 't12', 3, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:05:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:35:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claim, dup]);
  const v = batons.get(o.msg_id).history.find((h) => h.msgId === dup.msg_id);
  check('veredito-duplicate-claim', v && v.verdict === 'duplicate-claim', 'esperava duplicate-claim, achou ' + JSON.stringify(v));
}

// 13. lost-held — outra sessão reclama dentro do lease ou da folga.
{
  const o = offer('t13');
  const claim = mk('repo-b', 't13', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const rival = mk('repo-a', 't13', 3, { op: 'claim', session: 's2', stamped_at: '2026-01-01T00:10:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:40:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claim, rival]);
  const v = batons.get(o.msg_id).history.find((h) => h.msgId === rival.msg_id);
  check('veredito-lost-held', v && v.verdict === 'lost-held', 'esperava lost-held, achou ' + JSON.stringify(v));
}

// 14. won (tomada após vencimento + folga) — outra sessão reclama com carimbo >= T+S.
{
  const o = offer('t14');
  const claim = mk('repo-b', 't14', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const takeover = mk('repo-a', 't14', 3, { op: 'claim', session: 's2', stamped_at: '2026-01-01T00:33:00Z', lease_seconds: 1800, lease_until: '2026-01-01T01:03:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claim, takeover]);
  const b = batons.get(o.msg_id);
  const v = b.history.find((h) => h.msgId === takeover.msg_id);
  check('veredito-won-apos-vencimento', v && v.verdict === 'won' && b.holder.sender === 'repo-a', 'esperava won/tomada, achou ' + JSON.stringify(b.history));
}

// 15. renewed.
{
  const o = offer('t15');
  const claim = mk('repo-b', 't15', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const renew = mk('repo-b', 't15', 3, { op: 'renew', session: 's1', stamped_at: '2026-01-01T00:10:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:40:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claim, renew]);
  const b = batons.get(o.msg_id);
  const v = b.history.find((h) => h.msgId === renew.msg_id);
  check('veredito-renewed', v && v.verdict === 'renewed' && b.leaseUntil === '2026-01-01T00:40:00Z', 'esperava renewed com novo lease_until, achou ' + JSON.stringify(b));
}

// 16. late-renew.
{
  const o = offer('t16');
  const claim = mk('repo-b', 't16', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const lateRenew = mk('repo-b', 't16', 3, { op: 'renew', session: 's1', stamped_at: '2026-01-01T00:40:00Z', lease_seconds: 1800, lease_until: '2026-01-01T01:10:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claim, lateRenew]);
  const b = batons.get(o.msg_id);
  const v = b.history.find((h) => h.msgId === lateRenew.msg_id);
  check('veredito-late-renew', v && v.verdict === 'late-renew' && b.leaseUntil === '2026-01-01T00:31:00Z', 'esperava late-renew sem efeito, achou ' + JSON.stringify(b));
}

// 17. not-holder (renew/release/complete de quem não é titular, ou sem titular).
{
  const o = offer('t17');
  const renewNoHolder = mk('repo-b', 't17', 2, { op: 'renew', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, renewNoHolder]);
  const v = batons.get(o.msg_id).history.find((h) => h.msgId === renewNoHolder.msg_id);
  check('veredito-not-holder', v && v.verdict === 'not-holder', 'esperava not-holder, achou ' + JSON.stringify(v));
}

// 18. released.
{
  const o = offer('t18');
  const claim = mk('repo-b', 't18', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const release = mk('repo-b', 't18', 3, { op: 'release', session: 's1', stamped_at: '2026-01-01T00:05:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claim, release]);
  const b = batons.get(o.msg_id);
  check('veredito-released', b.state === 'available' && b.holder === null && b.history[2].verdict === 'released', 'esperava available/released, achou ' + JSON.stringify(b));
}

// 19. not-offerer (withdraw de quem não ofertou).
{
  const o = offer('t19');
  const withdrawWrong = mk('repo-b', 't19', 2, { op: 'withdraw', session: 's1', stamped_at: '2026-01-01T00:01:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, withdrawWrong]);
  const v = batons.get(o.msg_id).history.find((h) => h.msgId === withdrawWrong.msg_id);
  check('veredito-not-offerer', v && v.verdict === 'not-offerer', 'esperava not-offerer, achou ' + JSON.stringify(v));
}

// 20. withdrawn (available, pelo ofertante).
{
  const o = offer('t20');
  const withdraw = mk('repo-a', 't20', 2, { op: 'withdraw', session: 'sO', stamped_at: '2026-01-01T00:01:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, withdraw]);
  const b = batons.get(o.msg_id);
  check('veredito-withdrawn', b.state === 'withdrawn' && b.history[1].verdict === 'withdrawn', 'esperava withdrawn, achou ' + JSON.stringify(b));
}

// 21. withdraw-while-held.
{
  const o = offer('t21');
  const claim = mk('repo-b', 't21', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const withdraw = mk('repo-a', 't21', 3, { op: 'withdraw', session: 'sO', stamped_at: '2026-01-01T00:05:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const { batons } = foldBatons([o, claim, withdraw]);
  const v = batons.get(o.msg_id).history.find((h) => h.msgId === withdraw.msg_id);
  check('veredito-withdraw-while-held', v && v.verdict === 'withdraw-while-held', 'esperava withdraw-while-held, achou ' + JSON.stringify(v));
}

// --- [permutacao] 200 permutações aleatórias dão o mesmo resultado ---
{
  const o = offer('tp');
  const claim = mk('repo-b', 'tp', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const rival = mk('repo-a', 'tp', 3, { op: 'claim', session: 's2', stamped_at: '2026-01-01T00:10:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:40:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const renew = mk('repo-b', 'tp', 4, { op: 'renew', session: 's1', stamped_at: '2026-01-01T00:10:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:40:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  const base = [o, claim, rival, renew];
  function shuffle(arr) { const a = arr.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }
  function snapshot(batons) { return JSON.stringify([...batons.entries()].map(([k, v]) => [k, v.state, v.holder, v.history.map((h) => h.verdict)])); }
  const expected = snapshot(foldBatons(base).batons);
  let bad = false;
  for (let i = 0; i < 200; i++) {
    const got = snapshot(foldBatons(shuffle(base)).batons);
    if (got !== expected) { bad = true; break; }
  }
  check('permutacao', !bad, '200 permutações deveriam dar o mesmo resultado');
}

// --- [replicas] duas réplicas convergem independente da ordem de import ---
{
  const o = offer('tr');
  const claim = mk('repo-b', 'tr', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const renew = mk('repo-b', 'tr', 3, { op: 'renew', session: 's1', stamped_at: '2026-01-01T00:10:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:40:00Z' }, { seq: 2, in_reply_to: o.msg_id });
  function snapshot(batons) { return JSON.stringify([...batons.entries()].map(([k, v]) => [k, v.state, v.holder])); }
  const replicaA = foldBatons([o, claim, renew]);
  const replicaB = foldBatons([renew, o, claim]);
  check('replicas', snapshot(replicaA.batons) === snapshot(replicaB.batons), 'réplicas divergiram: ' + snapshot(replicaA.batons) + ' vs ' + snapshot(replicaB.batons));
}

// --- [stable] três repositórios elegíveis: provisional antes, stable depois; buraco de seq; eligible restrito ---
{
  const o = mk('repo-a', 'ts', 1, { op: 'offer', session: 'sO', stamped_at: '2026-01-01T00:00:00Z', eligible: ['repo-a', 'repo-b', 'repo-c'], max_lease_seconds: 14400, skew_tolerance_seconds: 120 }, { seq: 1 });
  const claim = mk('repo-b', 'ts', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id });
  const beforeImport = foldBatons([o, claim]);
  const stBefore = stability(beforeImport.batons.get(o.msg_id), [o, claim]);
  check('stable-provisional-inicial', !stBefore.stable && stBefore.missing.includes('repo-a') && stBefore.missing.includes('repo-c'), 'esperava provisional nomeando repo-a e repo-c, achou ' + JSON.stringify(stBefore));

  // repo-a e repo-c escrevem depois (lamport maior) — agora stable.
  const noteA = mk('repo-a', 'ts', 3, null, { seq: 2, in_reply_to: null });
  const noteC = mk('repo-c', 'ts', 4, null, { seq: 1, in_reply_to: null });
  const afterImport = foldBatons([o, claim, noteA, noteC]);
  const stAfter = stability(afterImport.batons.get(o.msg_id), [o, claim, noteA, noteC]);
  check('stable-apos-importar', stAfter.stable, 'esperava stable, achou ' + JSON.stringify(stAfter));

  // buraco de seq em repo-c antes da mensagem posterior — continua provisional.
  const noteCGap = { ...noteC, seq: 3 }; // seq 1,2 faltando — buraco
  noteCGap.content_sha = computeContentSha(noteCGap);
  const withGap = foldBatons([o, claim, noteA, noteCGap]);
  const stGap = stability(withGap.batons.get(o.msg_id), [o, claim, noteA, noteCGap]);
  check('stable-buraco-de-seq', !stGap.stable && stGap.missing.includes('repo-c'), 'esperava provisional por buraco em repo-c, achou ' + JSON.stringify(stGap));

  // eligible == sender da claim + ofertante já observado -> stable sem esperar não-elegível.
  const o2 = mk('repo-a', 'ts2', 1, { op: 'offer', session: 'sO', stamped_at: '2026-01-01T00:00:00Z', eligible: ['repo-b'], max_lease_seconds: 14400, skew_tolerance_seconds: 120 }, { seq: 1 });
  const claim2 = mk('repo-b', 'ts2', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o2.msg_id });
  const noteA2 = mk('repo-a', 'ts2', 3, null, { seq: 2, in_reply_to: null });
  const restricted = foldBatons([o2, claim2, noteA2]);
  const stRestricted = stability(restricted.batons.get(o2.msg_id), [o2, claim2, noteA2]);
  check('stable-eligible-restrito', stRestricted.stable, 'esperava stable com eligible restrito (so precisa do ofertante), achou ' + JSON.stringify(stRestricted));
}

// --- [clock-skew] detectClockSkew ignora mensagens com baton ---
{
  const o = offer('tc');
  const claimFuturoAtrasado = mk('repo-b', 'tc', 2, { op: 'claim', session: 's1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' }, { seq: 1, in_reply_to: o.msg_id, extra: { created_at: '2025-01-01T00:00:00Z' } });
  const skews = detectClockSkew([o, claimFuturoAtrasado]);
  check('clock-skew', skews.length === 0, 'detectClockSkew deveria ignorar mensagem com baton, achou ' + JSON.stringify(skews));
  // contrafactual: mensagem SEM baton com o mesmo problema de created_at continua detectada.
  const noteRef = mk('repo-a', 'tc2', 1, null, { seq: 10, in_reply_to: null, extra: { created_at: '2026-01-01T00:10:00Z' } });
  const noteLate = mk('repo-b', 'tc2', 2, null, { seq: 10, in_reply_to: noteRef.msg_id, extra: { created_at: '2025-01-01T00:00:00Z' } });
  const skews2 = detectClockSkew([noteRef, noteLate]);
  check('clock-skew-contrafactual', skews2.length === 1, 'contrafactual sem baton deveria continuar detectando, achou ' + JSON.stringify(skews2));
}

// --- [perf-dobra] 2000 mensagens de bastão numa thread, dobra <= 500ms p95 ---
{
  const { performance } = await import('node:perf_hooks');
  const msgs = [];
  const o = mk('repo-a', 'tperf', 1, { op: 'offer', session: 'sO', stamped_at: '2026-01-01T00:00:00Z', eligible: ['repo-a', 'repo-b'], max_lease_seconds: 14400, skew_tolerance_seconds: 120 }, { seq: 1 });
  msgs.push(o);
  let lamport = 2;
  let holderSession = null;
  for (let i = 0; i < 1999; i++) {
    const sender = i % 2 === 0 ? 'repo-b' : 'repo-a';
    const isClaim = holderSession === null;
    const session = isClaim ? 's' + i : holderSession;
    const op = isClaim ? 'claim' : 'renew';
    const stamped = new Date(60000 * (i + 1)).toISOString().replace(/\.\d{3}Z\$/, 'Z');
    const until = new Date(60000 * (i + 1) + 1800000).toISOString().replace(/\.\d{3}Z\$/, 'Z');
    const m = mk(sender === 'repo-b' && isClaim ? 'repo-b' : (holderSession ? sender : 'repo-b'), 'tperf', lamport++, { op, session: isClaim ? ('s' + i) : (holderSession || 's0'), stamped_at: stamped, lease_seconds: 1800, lease_until: until }, { in_reply_to: o.msg_id });
    if (isClaim) holderSession = m.baton.session;
    msgs.push(m);
  }
  const samples = [];
  for (let i = 0; i < 20; i++) {
    const t0 = performance.now();
    foldBatons(msgs);
    samples.push(performance.now() - t0);
  }
  samples.sort((a, b) => a - b);
  const p95 = samples[Math.floor(samples.length * 0.95)] ?? samples[samples.length - 1];
  check('perf-dobra', p95 <= 500, 'p95 da dobra com 2000 mensagens: ' + p95.toFixed(1) + 'ms (limite 500ms)');
}

const bad = results.filter(Boolean);
console.log(bad.length ? bad.join('\n') : 'OK todas as verificações da dobra/estabilidade/performance passaram');
" 2>&1)"; rc=$?
judge "veredito" "$out" "$rc"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — dobra do bastão: 21 vereditos, permutação, réplicas, estabilidade, clock-skew, performance"
exit 0
