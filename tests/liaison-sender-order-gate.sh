#!/usr/bin/env bash
# Gate — TASK-02/03 de add-liaison-handoff-baton (REQ-04, design §2.6.1):
#   [ordem-sender] compareSender (exportado por liaison-merge.mjs) ordena por code point, sob
#     LANG/LC_ALL variados, nunca por localeCompare; threadOrder usa compareSender no tie-break de
#     sender; mergeLogs escolhe o thread-open vencedor (entre dois com o mesmo lamport) também por
#     compareSender.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MERGE_MJS="$WS/template/.forge/scripts/lib/liaison-merge.mjs"

fail=0

run_node() {
  local lang="$1" lc_all="$2"
  LANG="$lang" LC_ALL="$lc_all" node --input-type=module -e "
    import { compareSender, threadOrder, mergeLogs } from '$MERGE_MJS';

    const ids = ['a_b','a-b','a-c','a.b','a0','ab'];
    const expectedCodePoint = ['a-b','a-c','a.b','a0','a_b','ab'];

    // compareSender existe e ordena por code point, não por localeCompare.
    if (typeof compareSender !== 'function') {
      console.log('FAIL [ordem-sender] compareSender não exportado (LANG=$lang LC_ALL=$lc_all)');
      process.exit(1);
    }
    const sorted = ids.slice().sort(compareSender);
    if (JSON.stringify(sorted) !== JSON.stringify(expectedCodePoint)) {
      console.log('FAIL [ordem-sender] compareSender não deu ordem de code point (LANG=$lang LC_ALL=$lc_all): ' + JSON.stringify(sorted));
      process.exit(1);
    }

    // threadOrder usa compareSender no tie-break de sender (mesmo lamport).
    const msgs = ids.map((sender, i) => ({ sender, seq: 1, lamport: 5, msg_id: sender + ':1' }));
    const order = threadOrder(msgs.slice().reverse()).map((m) => m.sender);
    if (JSON.stringify(order) !== JSON.stringify(expectedCodePoint)) {
      console.log('FAIL [ordem-sender] threadOrder não deu ordem de code point (LANG=$lang LC_ALL=$lc_all): ' + JSON.stringify(order));
      process.exit(1);
    }

    // mergeLogs escolhe o thread-open vencedor por compareSender quando o lamport empata.
    const opens = ids.map((sender) => ({
      kind: 'thread-open', thread_id: 't1', sender, seq: 1, lamport: 1,
      msg_id: sender + ':open', participants: [sender], subject: 'x', created_at: '2026-01-01T00:00:00Z',
    }));
    const merged = mergeLogs(opens.slice().reverse());
    if (merged.threads.t1.opened_by !== expectedCodePoint[0]) {
      console.log('FAIL [ordem-sender] mergeLogs escolheu opener errado (LANG=$lang LC_ALL=$lc_all): ' + merged.threads.t1.opened_by + ' esperado ' + expectedCodePoint[0]);
      process.exit(1);
    }

    console.log('OK (LANG=$lang LC_ALL=$lc_all)');
  "
}

for combo in "C:C" "en_US.UTF-8:en_US.UTF-8" "pt_BR.UTF-8:pt_BR.UTF-8" "tr_TR.UTF-8:tr_TR.UTF-8"; do
  lang="${combo%%:*}"
  lc_all="${combo##*:}"
  if ! out="$(run_node "$lang" "$lc_all" 2>&1)"; then
    echo "FAIL [ordem-sender] execução falhou sob LANG=$lang LC_ALL=$lc_all (import/export ausente ou erro de runtime): $(echo "$out" | head -1)"
    fail=1
    continue
  fi
  if echo "$out" | grep -q '^FAIL '; then
    echo "$out"
    fail=1
    continue
  fi
  echo "$out"
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — compareSender/threadOrder/mergeLogs ordenam por code point sob LANG/LC_ALL variados"
exit 0
