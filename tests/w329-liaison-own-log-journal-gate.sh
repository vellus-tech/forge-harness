#!/usr/bin/env bash
# Gate — TASK-10/TASK-11 de add-liaison-handoff-baton (REQ-09, design §2.4, "escritor de versão
# antiga", limite declarado com detecção):
#   [diario] appendOwn registra seq/content_sha no diário SÓ depois do renameSync bem-sucedido
#     (gravação abortada por stillOwned()==false nunca gera entrada falsa); diário detecta
#     reescrita por escritor sem trava (sender sem a trava sobrescrevendo uma posição conhecida)
#   [status-reescrito] `status <channel>` avisa "log próprio reescrito por escritor sem trava"
#     quando o diário diverge do log atual, e fica calado quando não diverge
#   [doctor-worktree] doctor.sh nomeia a worktree sem a sentinela e fica calado para a que tem
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
T="$(mktemp -d /tmp/forge-liaison-journal.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=journal-gate

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

mk_repo a
LG "$T/a" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG "$T/a" thread open "$CH" t1 --subject gate --participants repo-a,repo-b --body open >/dev/null
LG "$T/a" send "$CH" --thread t1 --kind note --subject m1 --body x >/dev/null

journal_file="$T/a/.forge/cache/liaison-baton/$CH/append-journal.json"

# [1] diário tem entrada para as duas mensagens gravadas (thread-open + m1)
if [ ! -f "$journal_file" ]; then
  echo "FAIL [diario]: $journal_file não existe após duas gravações"
  fail=1
else
  count="$(node -e "console.log(JSON.parse(require('fs').readFileSync('$journal_file','utf8')).length)")"
  [ "$count" = "2" ] && echo "OK [1] diário com 2 entradas" || { echo "FAIL [diario]: diário deveria ter 2 entradas, tem $count"; fail=1; }
fi

# [2] gravação abortada por stillOwned()==false NÃO entra no diário
out="$(node --input-type=module -e "
  import { appendOwn, LockLostError } from '$LIB/liaison-append.mjs';
  import { acquireLock } from '$LIB/liaison-lock.mjs';
  const root = '$T/a'; const channel = '$CH'; const self = 'repo-a';
  const chDir = root + '/.forge/liaison/' + channel;
  // simula uma trava recuperada por outro processo: adquire e libera sob outro nonce ANTES do
  // appendOwn tentar — appendOwn adquire sua PRÓPRIA trava normalmente (não há contenção aqui);
  // para forçar LockLostError de verdade, o teste abaixo chama appendOwn e, se não lançar,
  // confere que o diário cresceu normalmente (caminho feliz) — o caminho de aborto já é
  // coberto pelo gate da trava (w326-liaison-own-log-lock-gate.sh, stillOwned recusa nonce velho);
  // aqui confirmamos que o diário só cresce quando a gravação REALMENTE aconteceu.
  const before = (await import('fs')).existsSync('$journal_file') ? JSON.parse((await import('fs')).readFileSync('$journal_file','utf8')).length : 0;
  await appendOwn({ root, chDir, channel, self, build: (all) => {
    const threadMsgs = all.filter((m) => m.thread_id === 't1');
    return { channel, thread_id: 't1', kind: 'note', in_reply_to: null, requires_ack: false, subject: 'm2', body: 'y', refs: { change_id: null, contract_files: [], commit: null }, created_at: new Date().toISOString(), trust: 'self' };
  } });
  const after = JSON.parse((await import('fs')).readFileSync('$journal_file','utf8')).length;
  console.log(after === before + 1 ? 'OK diário cresceu exatamente 1 após gravação real' : 'FAIL [diario]: diário não cresceu corretamente (antes=' + before + ' depois=' + after + ')');
" 2>&1)"
echo "$out" | grep -q '^FAIL ' && { echo "$out"; fail=1; } || echo "[2] $out"

# [3] diário detecta reescrita por escritor sem trava (posição conhecida sobrescrita fora da trava)
# Simula um escritor ANTIGO (sem trava) sobrescrevendo o log próprio inteiro com conteúdo
# diferente na mesma posição (seq) que o diário já registrou — exatamente o dano que o diário
# existe para detectar.
own_log="$T/a/.forge/liaison/$CH/log/repo-a.jsonl"
node -e "
  const fs = require('fs');
  const lines = fs.readFileSync('$own_log','utf8').trim().split('\n').map((l)=>JSON.parse(l));
  // reescreve a ÚLTIMA mensagem (a que o diário também conhece) com subject/body diferentes,
  // recalculando content_sha para simular um escritor antigo que faz tudo à mão.
  const last = lines[lines.length - 1];
  last.subject = 'REESCRITO-SEM-TRAVA';
  last.body = 'conteudo-trocado';
  const crypto = require('crypto');
  const { content_sha, trust, ...rest } = last;
  const canon = JSON.stringify(rest, Object.keys(rest).sort());
  last.content_sha = crypto.createHash('sha256').update(canon).digest('hex');
  fs.writeFileSync('$own_log', lines.map((l)=>JSON.stringify(l)).join('\n') + '\n');
"
detect_out="$(node --input-type=module -e "
  import { checkJournalIntegrity } from '$LIB/liaison-append.mjs';
  const bad = checkJournalIntegrity({ root: '$T/a', channel: '$CH', chDir: '$T/a/.forge/liaison/$CH', self: 'repo-a' });
  console.log(JSON.stringify(bad));
")"
echo "$detect_out" | grep -q '"msg_id"' && echo "OK [3] checkJournalIntegrity detectou a reescrita: $detect_out" || { echo "FAIL [diario]: checkJournalIntegrity não detectou a reescrita: $detect_out"; fail=1; }

# [4] status avisa 'log próprio reescrito por escritor sem trava'
status_out="$(LG "$T/a" status "$CH" 2>&1)"
echo "$status_out" | grep -q "log próprio reescrito por escritor sem trava" \
  && echo "OK [4] status avisou" || { echo "FAIL [status-reescrito]: status não avisou: $status_out"; fail=1; }

# [5] contrafactual: sem reescrita, status fica calado sobre o diário
mk_repo clean
LG "$T/clean" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG "$T/clean" thread open "$CH" t1 --subject gate --participants repo-a,repo-b --body open >/dev/null
LG "$T/clean" send "$CH" --thread t1 --kind note --subject m1 --body x >/dev/null
status_clean="$(LG "$T/clean" status "$CH" 2>&1)"
echo "$status_clean" | grep -q "log próprio reescrito" \
  && { echo "FAIL [status-reescrito]: status avisou sem reescrita real: $status_clean"; fail=1; } \
  || echo "OK [5] status calado quando não há reescrita"

# [6] doctor.sh nomeia worktree sem a sentinela e fica calado para a que tem
# Fabrica um "repositório" com duas worktrees git de verdade: a principal tem a sentinela
# (cópia atual de liaison-ops.sh); a segunda é fabricada SEM a sentinela (versão "antiga").
mk_repo main_repo
cd "$T/main_repo" || exit 1
git branch old-branch >/dev/null 2>&1
git worktree add -q "$T/wt-old" old-branch >/dev/null 2>&1
cd "$WS" || exit 1
sed '/^# forge-liaison: own-log-lock v1$/d' "$T/wt-old/.forge/scripts/liaison-ops.sh" > "$T/wt-old/.forge/scripts/liaison-ops.sh.aged"
mv "$T/wt-old/.forge/scripts/liaison-ops.sh.aged" "$T/wt-old/.forge/scripts/liaison-ops.sh"
mkdir -p "$T/main_repo/.forge/liaison"
doctor_out="$(FORGE_ROOT="$T/main_repo" bash "$T/main_repo/.forge/scripts/doctor.sh" 2>&1 || true)"
echo "$doctor_out" | grep -q "wt-old" && echo "$doctor_out" | grep -q "sem a trava do log" \
  && echo "OK [6a] doctor nomeou a worktree sem a sentinela" \
  || { echo "FAIL [doctor-worktree]: doctor não nomeou a worktree antiga: $(echo "$doctor_out" | grep -i 'trava do log' || echo '(nada)')"; fail=1; }
echo "$doctor_out" | grep -q "main_repo.*sem a trava do log\|main_repo .*sentinela" \
  && { echo "FAIL [doctor-worktree]: doctor reclamou da worktree PRINCIPAL (que tem a sentinela)"; fail=1; } \
  || echo "OK [6b] doctor calado sobre a worktree principal (tem a sentinela)"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — diário de appendOwn, aviso em status, doctor nomeando worktree sem a trava"
exit 0
