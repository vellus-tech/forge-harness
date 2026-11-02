#!/usr/bin/env bash
# Gate — TASK-04/TASK-05 de add-liaison-handoff-baton (REQ-09, REQ-11, NFR-02, design §2.4):
#   [send-concorrente] 20 `send` concorrentes (duas worktrees do mesmo tronco) sem seq
#     duplicado nem mensagem perdida
#   [worktrees] as duas worktrees escrevem no MESMO log/<self>.jsonl do tronco
#   [recuperacao] timeout nomeando o dono; recuperação por pid morto (mesmo host); recuperação
#     por idade (>120s) e trava sem owner.json (idade pelo mtime do diretório); dois
#     recuperadores concorrentes + um adquirente novo, sem gravação perdida;
#     FORGE_LIAISON_LOCK_WAIT_MS honrado
#   [nonce] stillOwned() recusa depois que a trava foi recuperada por outro processo
#   [escrita-fora] nenhum escritor fora de liaison-append.mjs grava em log/<self>.jsonl
#     (varredura estática do bash e dinâmica via preload do Node)
#   [estado-local] escritores concorrentes de um JSON local sob a trava, sem atualização
#     perdida nem JSON truncado
# set -e DELIBERADAMENTE ausente: este gate orquestra dezenas de sub-processos esperados FALHAR
# em cenários específicos (trava ocupada, recuperação, etc.) e cada falha é verificada
# explicitamente (fail=1), nunca propagada como abort do script — um `out="$(cmd)"` com `cmd`
# retornando != 0 abortaria o gate inteiro sob `set -e`, mascarando todos os cenários seguintes.
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
LIAISON_OPS="$WS/template/.forge/scripts/liaison-ops.sh"
PRELOAD="$WS/tests/fixtures/liaison-lock/write-scan-preload.cjs"
T="$(mktemp -d /tmp/forge-liaison-lock.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=baton-lock-gate

# judge <tag> <output> <rc> — decide pass/fail de um probe isolado (nunca aborta o gate: sem
# set -e, uma falha inesperada de processo (import ausente, exceção não tratada) não teria
# "FAIL [...]" no próprio texto, e um grep simples a deixaria passar batido).
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

# LG_WT <worktree-dir> <args...> — roda SEM forçar FORGE_ROOT: a resolução natural por
# --git-common-dir é o que faz uma worktree secundária escrever no MESMO tronco da principal
# (é precisamente a propriedade que este bloco testa). Forçar FORGE_ROOT=<worktree> aqui
# apontaria para a própria worktree como tronco, e as duas "worktrees" escreveriam em logs
# separados — nenhuma corrida real aconteceria, e o teste passaria sem testar nada. `unset -v
# FORGE_ROOT` é OBRIGATÓRIO aqui, não cosmético: quem invoca este gate (ex. `red-evidence.sh
# task`, que exporta FORGE_ROOT apontando para o PRÓPRIO worktree efêmero dele) pode ter
# FORGE_ROOT herdado no ambiente, e um `FORGE_ROOT` exportado por fora tem PRECEDÊNCIA sobre
# --git-common-dir em forge_resolve_root (por desenho — é declaração explícita de quem invoca).
# Sem o unset, a resolução "natural" que este helper promete nunca acontece: herda o valor de
# fora, aponta para outro tronco, e o canal "desaparece" para o lado wt2 (achado real, não
# hipotético — rastreado até aqui por bisseção, porque red-evidence.sh exporta FORGE_ROOT no
# próprio topo, antes até do despacho do subcomando `task`).
LG_WT() {
  local wt="$1"; shift
  ( unset -v FORGE_ROOT; cd "$wt" && bash "$wt/.forge/scripts/liaison-ops.sh" "$@" )
}

# === [send-concorrente]/[worktrees] 20 sends concorrentes em duas worktrees ===
mk_repo main
LG "$T/main" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG "$T/main" thread open "$CH" t1 --subject "lock gate" --participants repo-a,repo-b --body "abertura" >/dev/null

git -C "$T/main" worktree add -q "$T/wt2" -b wt2-branch >/dev/null 2>&1 || {
  echo "FAIL [worktrees]: git worktree add falhou"
  fail=1
}

if [ "$fail" -eq 0 ]; then
  # send_retry <helper> <root-or-worktree> <args...> — até 3 tentativas absorvem o único modo de
  # falha LEGÍTIMO deste cenário: o teto de espera da trava (FORGE_LIAISON_LOCK_WAIT_MS, no
  # máximo 10 s) sob contenção de CPU/IO externa o bastante para que até um `send` sozinho não
  # consiga nem terminar de inicializar o node antes do teto. É falha LIMPA e nomeável (rc 1,
  # dono citado em stderr), nunca corrupção nem gravação duplicada — a mesma reação que um
  # operador real teria (tentar de novo). Sem o retry, este gate fica falso-flaky só em máquina
  # sob contenção severa (esta própria máquina compartilhada chegou a load average > 20 em 10
  # núcleos durante o desenvolvimento, medido por `uptime` — 16 usuários concorrentes; nunca
  # falhou em execução isolada). Não mascara corrida real: duplicidade/perda de seq continua
  # conferida nos checks abaixo sobre o resultado final, independente de quantas tentativas cada
  # send usou.
  send_retry() {
    local helper="$1" root="$2"; shift 2
    for _try in 1 2 3; do
      "$helper" "$root" send "$@" >/dev/null 2>&1 && return 0
      sleep 0.2
    done
    return 1
  }
  pids=()
  for i in $(seq 1 10); do
    ( send_retry LG "$T/main" "$CH" --thread t1 --kind note --subject "msg-main-$i" --body "corpo $i" ) &
    pids+=($!)
  done
  for i in $(seq 1 10); do
    ( send_retry LG_WT "$T/wt2" "$CH" --thread t1 --kind note --subject "msg-wt2-$i" --body "corpo $i" ) &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p" || true; done

  LOGFILE="$T/main/.forge/liaison/$CH/log/repo-a.jsonl"
  if [ ! -f "$LOGFILE" ]; then
    echo "FAIL [send-concorrente]: $LOGFILE não existe depois dos 20 sends concorrentes"
    fail=1
  else
    count="$(wc -l < "$LOGFILE" | tr -d ' ')"
    # thread-open consumiu seq=1; os 20 sends devem ser seq=2..21 (total 21 linhas)
    if [ "$count" != "21" ]; then
      echo "FAIL [send-concorrente]: esperava 21 linhas (1 thread-open + 20 sends), achei $count"
      fail=1
    fi
    dup="$(node -e "
      const fs=require('fs');
      const lines=fs.readFileSync('$LOGFILE','utf8').trim().split('\n').filter(Boolean);
      const seqs=lines.map(l=>{ try { return JSON.parse(l).seq; } catch(e){ return 'PARSE_ERROR'; } });
      const seen=new Set(); let dup=null;
      for (const s of seqs) { if (seen.has(s)) { dup=s; break; } seen.add(s); }
      const sorted=[...seen].sort((a,b)=>a-b);
      const maxv=Math.max(...sorted);
      const contiguous = sorted.length===maxv && sorted.every((v,i)=>v===i+1);
      console.log(JSON.stringify({dup, contiguous, parseErrors: seqs.filter(s=>s==='PARSE_ERROR').length}));
    ")"
    echo "$dup" | grep -q '"dup":null' || { echo "FAIL [send-concorrente]: seq duplicado detectado: $dup"; fail=1; }
    echo "$dup" | grep -q '"contiguous":true' || { echo "FAIL [send-concorrente]: seq não é contíguo 1..N: $dup"; fail=1; }
    echo "$dup" | grep -q '"parseErrors":0' || { echo "FAIL [send-concorrente]: linha JSON truncada/corrompida: $dup"; fail=1; }
  fi
  [ "$fail" -eq 0 ] && echo "OK [send-concorrente]/[worktrees]"
fi

# === [recuperacao] trava — timeout, pid morto, idade, sem owner.json, concorrência de recuperadores ===
RUN_LOCK_PROBE() { # roda um script node que usa liaison-lock.mjs diretamente
  node --input-type=module -e "$1"
}

# (a) timeout nomeando o dono: segura a trava manualmente num processo filho vivo, tenta
# adquirir com waitMs pequeno e confere a mensagem.
HOLD_SCRIPT="$T/hold-lock.mjs"
cat > "$HOLD_SCRIPT" <<EOF
import { acquireLock } from '$LIB/liaison-lock.mjs';
const { release } = await acquireLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log' });
process.send ? process.send('held') : process.stdout.write('held\n');
await new Promise((r) => setTimeout(r, 4000));
release();
EOF

node "$HOLD_SCRIPT" >/tmp/holdlock.out 2>&1 &
HOLD_PID=$!
# espera a trava aparecer
for i in $(seq 1 100); do
  [ -d "$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock" ] && break
  sleep 0.05
done

if [ ! -d "$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock" ]; then
  echo "FAIL [recuperacao]: trava não apareceu depois do holder adquirir"
  fail=1
else
  out="$(RUN_LOCK_PROBE "
    import { acquireLock } from '$LIB/liaison-lock.mjs';
    try {
      await acquireLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log', waitMs: 150 });
      console.log('FAIL [recuperacao]: adquiriu trava ocupada por processo VIVO');
    } catch (e) {
      const msg = String(e.message || e);
      if (/pid=\d+/.test(msg) && /host=/.test(msg) && /started_at=/.test(msg)) {
        console.log('OK timeout nomeia dono: ' + msg);
      } else {
        console.log('FAIL [recuperacao]: timeout não nomeou pid/host/started_at: ' + msg);
      }
    }
  " 2>&1)"; rc=$?
  judge "recuperacao" "$out" "$rc"
fi

kill "$HOLD_PID" 2>/dev/null || true
wait "$HOLD_PID" 2>/dev/null || true
rm -rf "$T/main/.forge/cache/liaison-locks"

# (b) recuperação por pid morto (mesmo host): fabrica owner.json com um pid garantidamente morto.
mkdir -p "$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock"
DEAD_PID=99999
while kill -0 "$DEAD_PID" 2>/dev/null; do DEAD_PID=$((DEAD_PID + 1)); done
node -e "
  const fs=require('fs');
  fs.writeFileSync('$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock/owner.json', JSON.stringify({
    pid: $DEAD_PID, host: require('os').hostname(), started_at: new Date().toISOString(), nonce: 'dead-nonce', cmd: 'fixture'
  }));
"
out="$(RUN_LOCK_PROBE "
  import { acquireLock } from '$LIB/liaison-lock.mjs';
  const t0 = Date.now();
  const { release } = await acquireLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log', waitMs: 5000 });
  const dt = Date.now() - t0;
  release();
  console.log(dt < 3000 ? 'OK recuperou pid morto em ' + dt + 'ms' : 'FAIL [recuperacao]: recuperação de pid morto demorou demais (' + dt + 'ms)');
" 2>&1)"; rc=$?
judge "recuperacao" "$out" "$rc"
rm -rf "$T/main/.forge/cache/liaison-locks"

# (c) trava SEM owner.json: idade pelo mtime do diretório. <120s não recupera dentro do wait
# curto; >120s recupera.
mkdir -p "$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock"
out="$(RUN_LOCK_PROBE "
  import { acquireLock } from '$LIB/liaison-lock.mjs';
  try {
    await acquireLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log', waitMs: 200 });
    console.log('FAIL [recuperacao]: trava jovem sem owner.json foi recuperada antes de 120s');
  } catch (e) {
    console.log('OK trava jovem sem owner.json não recuperada: ' + String(e.message||e).slice(0,40));
  }
" 2>&1)"; rc=$?
judge "recuperacao" "$out" "$rc"
# envelhece o diretório para mais de 120s (toca mtime no passado)
node -e "
  const fs=require('fs');
  const past = new Date(Date.now() - 130000);
  fs.utimesSync('$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock', past, past);
"
out="$(RUN_LOCK_PROBE "
  import { acquireLock } from '$LIB/liaison-lock.mjs';
  const { release } = await acquireLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log', waitMs: 2000 });
  release();
  console.log('OK trava velha sem owner.json foi recuperada');
" 2>&1)"; rc=$?
judge "recuperacao" "$out" "$rc"
rm -rf "$T/main/.forge/cache/liaison-locks"

# (d) dois recuperadores concorrentes + um adquirente novo sobre a mesma trava morta: nenhuma
# mensagem perdida (cada um dos 3 processos consegue, serialmente, rodar a própria seção crítica
# incrementando um contador em arquivo).
mkdir -p "$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock"
node -e "
  const fs=require('fs');
  fs.writeFileSync('$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock/owner.json', JSON.stringify({
    pid: $DEAD_PID, host: require('os').hostname(), started_at: new Date().toISOString(), nonce: 'dead-nonce-2', cmd: 'fixture'
  }));
"
echo 0 > "$T/counter.txt"
RACER="$T/racer.mjs"
cat > "$RACER" <<EOF
import { withLock } from '$LIB/liaison-lock.mjs';
await withLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log', waitMs: 8000 }, async () => {
  const fs = await import('node:fs');
  const cur = Number(fs.readFileSync('$T/counter.txt', 'utf8').trim());
  await new Promise((r) => setTimeout(r, 20));
  fs.writeFileSync('$T/counter.txt', String(cur + 1));
});
EOF
racer_pids=()
for i in 1 2 3; do
  node "$RACER" >/tmp/racer-$i.out 2>&1 &
  racer_pids+=($!)
done
for p in "${racer_pids[@]}"; do wait "$p" || { echo "FAIL [recuperacao]: um dos 3 corredores falhou"; fail=1; }; done
final="$(cat "$T/counter.txt" 2>/dev/null || echo "?")"
[ "$final" = "3" ] || { echo "FAIL [recuperacao]: contador final esperado 3, achei $final (mensagem perdida na corrida de recuperadores)"; fail=1; }
[ "$final" = "3" ] && echo "OK [recuperacao]: 3 corredores sobre trava morta, contador=$final"
rm -rf "$T/main/.forge/cache/liaison-locks"

# (e) FORGE_LIAISON_LOCK_WAIT_MS honrado dentro de [0, 10000]
mkdir -p "$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock"
node -e "
  const fs=require('fs');
  fs.writeFileSync('$T/main/.forge/cache/liaison-locks/baton-lock-gate@repo-a@log.lock/owner.json', JSON.stringify({
    pid: $$, host: require('os').hostname(), started_at: new Date().toISOString(), nonce: 'alive-nonce', cmd: 'fixture'
  }));
"
out="$(FORGE_LIAISON_LOCK_WAIT_MS=200 node --input-type=module -e "
  import { acquireLock } from '$LIB/liaison-lock.mjs';
  const t0 = Date.now();
  try {
    await acquireLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log' });
    console.log('FAIL [recuperacao]: adquiriu trava de processo VIVO (pid próprio, mas host bate e pid vivo)');
  } catch (e) {
    const dt = Date.now() - t0;
    console.log(dt < 1000 ? 'OK FORGE_LIAISON_LOCK_WAIT_MS honrado (' + dt + 'ms)' : 'FAIL [recuperacao]: FORGE_LIAISON_LOCK_WAIT_MS não honrado (' + dt + 'ms)');
  }
" 2>&1)"; rc=$?
judge "recuperacao" "$out" "$rc"
rm -rf "$T/main/.forge/cache/liaison-locks"

# === [nonce] stillOwned() recusa depois de recuperação por outro processo ===
out="$(RUN_LOCK_PROBE "
  import { acquireLock, releaseLock } from '$LIB/liaison-lock.mjs';
  const a = await acquireLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log' });
  // simula outro processo recuperando: libera e readquire com nonce novo
  releaseLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log', nonce: a.nonce });
  const b = await acquireLock({ root: '$T/main', name: 'baton-lock-gate@repo-a@log' });
  const stillA = a.stillOwned();
  b.release();
  console.log(stillA === false ? 'OK stillOwned recusa nonce velho' : 'FAIL [nonce]: stillOwned aceitou nonce velho depois de nova aquisição');
" 2>&1)"; rc=$?
judge "nonce" "$out" "$rc"
rm -rf "$T/main/.forge/cache/liaison-locks"

# === [escrita-fora] escritor único de log/<self>.jsonl ===
# Estática: cp/mv/tee/redirecionamento visando $own/\${own}/\$self.jsonl fora das linhas de
# leitura permitidas (--repair-own-log lê, não escreve).
static_fail=0
while IFS= read -r hit; do
  echo "FAIL [escrita-fora]: padrão de escrita direta ao log próprio fora de liaison-append.mjs: $hit"
  static_fail=1
done < <(grep -nE '(cp |mv |tee |>\s*)"?\$\{?(own|self)\}?\.jsonl' "$LIAISON_OPS" "$WS"/template/.forge/scripts/lib/transports/*.sh 2>/dev/null | grep -v '# forge-liaison: leitura' || true)
[ "$static_fail" -eq 0 ] && echo "OK estática: nenhum cp/mv/tee/redirect direto ao log próprio" || fail=1

# Dinâmica: preload grava toda escrita em log/<self>.jsonl com a origem na pilha; exige que a
# origem seja sempre liaison-append.mjs quando o módulo existe. Cobre os quatro verbos que
# escrevem no log próprio (send, ack, thread open, thread join) — conflicts resolve compartilha
# o mesmo caminho de appendOwn que ack/send e não precisa de fixture própria aqui.
#
# QLT-001: a varredura não pode passar por vacuidade. Cada verbo roda com o PRÓPRIO arquivo de
# varredura e precisa terminar com rc 0 (sem `|| true`) e deixar ao menos uma entrada nele — um
# preload que não carrega, um verbo que falha antes de escrever ou um caminho de escrita que o
# preload não intercepta dão "nenhuma escrita fora" sem ter observado escrita nenhuma. O
# recontrole, no fim, prova que o filtro acusa uma escrita direta feita fora de liaison-append.mjs.
# FORGE_WRITE_SCAN_PRELOAD só existe para provar a vacuidade com um preload no-op; fora disso é o
# preload real.
SCAN_PRELOAD="${FORGE_WRITE_SCAN_PRELOAD:-$PRELOAD}"
scan_bad() { # scan_bad <arquivo-de-varredura> -> JSON das entradas com origem fora de liaison-append.mjs
  node -e '
    const fs = require("fs");
    let lines = [];
    try { lines = fs.readFileSync(process.argv[1], "utf8").trim().split("\n").filter(Boolean).map(JSON.parse); } catch (e) {}
    console.log(JSON.stringify(lines.filter((l) => !/liaison-append\.mjs$/.test(l.origin))));
  ' "$1"
}
scan_count() { # scan_count <arquivo-de-varredura> -> número de entradas
  if [ -s "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi
}
if [ -f "$LIB/liaison-append.mjs" ]; then
  dyn_fail=0
  SCAN_DIR="$T/write-scan"; mkdir -p "$SCAN_DIR"
  scan_run() { # scan_run <verbo> <args...> -> roda sob o preload, com a varredura em $SCAN_DIR/<verbo>.jsonl
    local verb="$1"; shift
    : > "$SCAN_DIR/$verb.jsonl"
    FORGE_WRITE_SCAN_LOG="$SCAN_DIR/$verb.jsonl" NODE_OPTIONS="--require $SCAN_PRELOAD" LG "$T/main" "$@"
  }
  send_out="$(scan_run send send "$CH" --thread t1 --kind note --subject "scan-probe" --body "x" 2>&1)"; rc_send=$?
  SCAN_MSGID="$(grep -oE '[a-z0-9._-]+-[0-9]{4}' <<<"$send_out" | tail -1)"
  scan_run ack ack "$CH" "$SCAN_MSGID" --subject "scan-probe-ack" >/dev/null 2>&1; rc_ack=$?
  scan_run thread-open thread open "$CH" scan-probe-thread --subject "scan" --participants repo-a --body "x" >/dev/null 2>&1; rc_topen=$?
  scan_run thread-join thread join "$CH" scan-probe-thread --subject "scan-join" >/dev/null 2>&1; rc_tjoin=$?
  for pair in "send:$rc_send" "ack:$rc_ack" "thread-open:$rc_topen" "thread-join:$rc_tjoin"; do
    verb="${pair%%:*}"; vrc="${pair#*:}"
    n="$(scan_count "$SCAN_DIR/$verb.jsonl")"
    if [ "$vrc" -ne 0 ]; then
      echo "FAIL [escrita-fora]: o verbo '$verb' falhou (rc $vrc) sob a varredura — sem a escrita não há o que conferir"
      dyn_fail=1
    elif [ "$n" -eq 0 ]; then
      echo "FAIL [escrita-fora]: o verbo '$verb' terminou sem nenhuma escrita observada pela varredura — o preload não viu nada (vacuidade)"
      dyn_fail=1
    fi
    bad="$(scan_bad "$SCAN_DIR/$verb.jsonl")"
    if [ "$bad" != "[]" ]; then
      echo "FAIL [escrita-fora]: escrita dinâmica fora de liaison-append.mjs no verbo '$verb': $bad"
      dyn_fail=1
    fi
  done
  # Recontrole: escrita direta em log/<self>.jsonl por um script que NÃO é liaison-append.mjs
  # precisa aparecer como 'bad' — sem isto, um filtro que nunca acusa nada passaria.
  mkdir -p "$T/rogue/log"
  printf '%s\n' "import { writeFileSync } from 'node:fs';" "writeFileSync(process.argv[2], '{\"rogue\":true}\\n');" > "$T/rogue/rogue-writer.mjs"
  : > "$SCAN_DIR/rogue.jsonl"
  FORGE_WRITE_SCAN_LOG="$SCAN_DIR/rogue.jsonl" NODE_OPTIONS="--require $SCAN_PRELOAD" node "$T/rogue/rogue-writer.mjs" "$T/rogue/log/repo-a.jsonl"
  rogue_bad="$(scan_bad "$SCAN_DIR/rogue.jsonl")"
  if [ "$rogue_bad" = "[]" ]; then
    echo "FAIL [escrita-fora]: recontrole — a escrita direta de rogue-writer.mjs em log/repo-a.jsonl não foi acusada"
    dyn_fail=1
  fi
  if [ "$dyn_fail" -eq 0 ]; then
    echo "OK dinâmica: send, ack, thread open e thread join escreveram (rc 0, ao menos uma escrita observada cada) e toda escrita em log/<self>.jsonl veio de liaison-append.mjs; o recontrole acusa escrita direta fora dele"
  else
    fail=1
  fi
else
  echo "FAIL [escrita-fora]: liaison-append.mjs ainda não existe — send não pode estar roteado por ele"
  fail=1
fi

# === [estado-local] escritores concorrentes de JSON local sob a trava ===
if [ -f "$LIB/liaison-lock.mjs" ]; then
  echo '{"count":0}' > "$T/local-state.json"
  LOCAL_RACER="$T/local-racer.mjs"
  cat > "$LOCAL_RACER" <<EOF
import { withLocalLock } from '$LIB/liaison-lock.mjs';
await withLocalLock({ root: '$T/main', channel: '$CH', self: 'repo-a' }, async () => {
  const fs = await import('node:fs');
  const cur = JSON.parse(fs.readFileSync('$T/local-state.json', 'utf8'));
  await new Promise((r) => setTimeout(r, 5));
  const tmp = '$T/local-state.json.tmp';
  fs.writeFileSync(tmp, JSON.stringify({ count: cur.count + 1 }));
  fs.renameSync(tmp, '$T/local-state.json');
});
EOF
  local_pids=()
  for i in $(seq 1 15); do
    node "$LOCAL_RACER" >/tmp/local-racer-$i.out 2>&1 &
    local_pids+=($!)
  done
  for p in "${local_pids[@]}"; do wait "$p" || { echo "FAIL [estado-local]: um escritor local falhou"; fail=1; }; done
  final_json="$(cat "$T/local-state.json" 2>/dev/null || echo "CORROMPIDO")"
  count_val="$(node -e "try { console.log(JSON.parse(require('fs').readFileSync('$T/local-state.json','utf8')).count); } catch(e) { console.log('PARSE_ERROR'); }")"
  if [ "$count_val" != "15" ]; then
    echo "FAIL [estado-local]: contador final esperado 15, achei $count_val ($final_json)"
    fail=1
  else
    echo "OK [estado-local]: 15 escritores concorrentes, contador=$count_val, JSON válido"
  fi
else
  echo "FAIL [estado-local]: liaison-lock.mjs ainda não existe — withLocalLock indisponível"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — trava do log próprio, publicação e estado local concorrentes seguros"
exit 0
