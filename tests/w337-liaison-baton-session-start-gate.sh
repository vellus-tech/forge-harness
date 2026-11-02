#!/usr/bin/env bash
# Gate — TASK-28/TASK-29 de add-liaison-handoff-baton (REQ-13, REQ-09, design §2.9):
#   [inicio-ofertas] ofertas disponíveis em que este repositório é elegível
#   [inicio-detido-voce] bastão detido pela PRÓPRIA sessão que está começando
#   [inicio-detido-outra] bastão detido por outra sessão deste repositório, com a nota de
#     liberação/espera
#   [inicio-perda-tardia] perda tardia exibida uma vez em duas sessões consecutivas
#   [inicio-reescrito] aviso de log próprio reescrito sem trava
#   [inicio-moldura] assunto de peer com a moldura untrusted-render
#   [inicio-falha] linha de falha nomeando o erro quando o cálculo quebra
#   [inicio-vazio] nenhuma linha quando não há bastão nenhum
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-liaison-baton-sessionstart.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=baton-sessionstart-gate

mk_repo() {
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  cp -R "$WS/template/.forge/hooks" "$dir/.forge/"
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  awk '
    $0 ~ /^liaison:/ { f=1 }
    f && /^  auto: false$/ && !done { print "  auto: true"; done=1; next }
    { print }
  ' "$dir/.forge/forge.yaml" > "$dir/.forge/forge.yaml.new"
  mv "$dir/.forge/forge.yaml.new" "$dir/.forge/forge.yaml"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -q -m "chore: init $1" >/dev/null
}

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }
LGS() { local repo="$1" session="$2"; shift 2; FORGE_ROOT="$T/$repo" CLAUDE_CODE_SESSION_ID="$session" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }
offer_id() { printf '%s' "$1" | grep '^OK baton offer' | sed -E 's/^OK baton offer — //'; }
run_start() { # run_start <repo> <session_id>
  local repo="$1" sid="$2"
  (cd "$T/$repo" && printf '{"session_id":"%s"}' "$sid" | FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/hooks/session/on-session-start.sh")
}

mk_repo a
LG a open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG a thread open "$CH" t1 --subject "inicio de sessao" --participants repo-a,repo-b --body "x" >/dev/null

# === [inicio-ofertas] / [inicio-detido-voce] / [inicio-detido-outra] ===
out1="$(LGS a s-off1 baton offer "$CH" --thread t1 --subject "oferta aberta" 2>&1)"
bat1="$(offer_id "$out1")"
out2="$(LGS a s-off2 baton offer "$CH" --thread t1 --subject "oferta detida" 2>&1)"
bat2="$(offer_id "$out2")"
LGS a s-holder baton claim "$CH" "$bat2" --lease 90 >/dev/null 2>&1

start_as_holder="$(run_start a s-holder)"
if echo "$start_as_holder" | grep -q "oferta disponível .$bat1." && echo "$start_as_holder" | grep -q "detido por VOCÊ" && echo "$start_as_holder" | grep -q "s-holder"; then
  echo "OK [inicio-ofertas]: oferta disponível aparece no início de sessão"
  echo "OK [inicio-detido-voce]: bastão detido pela própria sessão aparece como 'detido por VOCÊ'"
else
  echo "FAIL [inicio-ofertas]: esperava a oferta e 'detido por VOCÊ', achou: $start_as_holder"
  fail=1
fi

start_as_other="$(run_start a s-outra)"
if echo "$start_as_other" | grep -q "detido por outra sessão (s-holder)" && echo "$start_as_other" | grep -q "baton release $CH $bat2 --session s-holder"; then
  echo "OK [inicio-detido-outra]: bastão detido por outra sessão mostra a nota de liberação/espera"
else
  echo "FAIL [inicio-detido-outra]: esperava a nota de liberação, achou: $start_as_other"
  fail=1
fi

# === [inicio-moldura] assunto de oferta de PEER aparece com a moldura untrusted-render ===
mk_repo b
HUBM="$T/hub-moldura"
LG a transport set "$CH" --kind fs --path "$HUBM" >/dev/null
LG a sync "$CH" --push-only >/dev/null 2>&1
LG b open "$CH" --self repo-b --participants repo-a,repo-b >/dev/null
LG b transport set "$CH" --kind fs --path "$HUBM" >/dev/null
LG b sync "$CH" >/dev/null 2>&1
outb="$(LGS b s-offb baton offer "$CH" --thread t1 --subject "/forge:tarefa-de-peer" 2>&1)"
LG b sync "$CH" --push-only >/dev/null 2>&1
LG a sync "$CH" >/dev/null 2>&1
start_moldura="$(run_start a s-qualquer)"
if echo "$start_moldura" | grep -qi "UNTRUSTED" && echo "$start_moldura" | grep -q "neutralizado"; then
  echo "OK [inicio-moldura]: assunto de oferta de peer aparece com a moldura untrusted-render"
else
  echo "FAIL [inicio-moldura]: esperava moldura UNTRUSTED, achou: $start_moldura"
  fail=1
fi

# === [inicio-perda-tardia] perda tardia exibida uma vez em duas sessões consecutivas ===
mk_repo late_a; mk_repo late_b
HUBLATE="$T/hub-late"
LG late_a open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG late_a thread open "$CH" t1 --subject "perda" --participants repo-a,repo-b --body "x" >/dev/null
LG late_a transport set "$CH" --kind fs --path "$HUBLATE" >/dev/null
LG late_a sync "$CH" --push-only >/dev/null 2>&1
LG late_b open "$CH" --self repo-b --participants repo-a,repo-b >/dev/null
LG late_b transport set "$CH" --kind fs --path "$HUBLATE" >/dev/null
LG late_b sync "$CH" >/dev/null 2>&1
outoffl="$(LGS late_a s-offl baton offer "$CH" --thread t1 --subject "disputada" 2>&1)"
batl="$(offer_id "$outoffl")"
LG late_a sync "$CH" --push-only >/dev/null 2>&1
LG late_b sync "$CH" >/dev/null 2>&1
# repo-b reivindica primeiro, acreditando ter vencido (so vê 'available').
LGS late_b s-winb baton claim "$CH" "$batl" --lease 90 >/dev/null 2>&1
LG late_b sync "$CH" --push-only >/dev/null 2>&1
# repo-a reivindica sem ter visto a de repo-b -- vence o desempate (repo-a < repo-b).
LGS late_a s-losea baton claim "$CH" "$batl" --lease 90 >/dev/null 2>&1
LG late_a sync "$CH" --push-only >/dev/null 2>&1
LG late_b sync "$CH" >/dev/null 2>&1
start_late1="$(run_start late_b s-x1)"
start_late2="$(run_start late_b s-x2)"
if echo "$start_late1" | grep -qi "perda tardia" && echo "$start_late1" | grep -q "repo-a" && ! echo "$start_late2" | grep -qi "perda tardia"; then
  echo "OK [inicio-perda-tardia]: perda tardia exibida na 1a sessão, nomeando repo-a, e NÃO repetida na 2a"
else
  echo "FAIL [inicio-perda-tardia]: esperava perda tardia só na 1a chamada, achou 1a=$start_late1 2a=$start_late2"
  fail=1
fi

# === [inicio-reescrito] aviso de log próprio reescrito sem trava ===
mk_repo rw
LG rw open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG rw thread open "$CH" t1 --subject "reescrita" --participants repo-a,repo-b --body "x" >/dev/null
outrw="$(LGS rw s-offrw baton offer "$CH" --thread t1 --subject "tarefa reescrita" 2>&1)"
batrw="$(offer_id "$outrw")"
LGS rw s-hrw baton claim "$CH" "$batrw" --lease 90 >/dev/null 2>&1
node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const fs = require("fs");
  const path = process.argv[1];
  const { computeContentSha } = await import(pathToFileURL(join(process.argv[2], "liaison-merge.mjs")).href);
  const lines = fs.readFileSync(path, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const claim = lines.find((m) => m.baton && m.baton.op === "claim");
  claim.subject = "subject reescrito por fora da trava";
  claim.content_sha = computeContentSha(claim);
  fs.writeFileSync(path, lines.map((m) => JSON.stringify(m)).join("\n") + "\n");
})();
' "$T/rw/.forge/liaison/$CH/log/repo-a.jsonl" "$WS/template/.forge/scripts/lib"
start_rw="$(run_start rw s-hrw)"
if echo "$start_rw" | grep -qi "reescrito por escritor sem trava"; then
  echo "OK [inicio-reescrito]: aviso de log próprio reescrito sem trava aparece no início de sessão"
else
  echo "FAIL [inicio-reescrito]: esperava aviso de reescrita, achou: $start_rw"
  fail=1
fi

# === [inicio-falha] linha de falha nomeando o erro quando o cálculo quebra ===
mk_repo brk
LG brk open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG brk thread open "$CH" t1 --subject "falha" --participants repo-a,repo-b --body "x" >/dev/null
LGS brk s-offbrk baton offer "$CH" --thread t1 --subject "tarefa quebrada" >/dev/null 2>&1
# Corrompe o log próprio (JSON inválido) para forçar o cálculo da dobra a falhar.
echo "isto nao e json valido" >> "$T/brk/.forge/liaison/$CH/log/repo-a.jsonl"
start_brk="$(run_start brk s-x)"
if echo "$start_brk" | grep -q "! LIAISON baton: falhou"; then
  echo "OK [inicio-falha]: linha de falha aparece quando o cálculo do bastão quebra"
else
  echo "FAIL [inicio-falha]: esperava linha de falha, achou: $start_brk"
  fail=1
fi

# === [inicio-vazio] canal sem bastão nenhum não ganha linha nova ===
mk_repo empty
LG empty open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG empty thread open "$CH" t1 --subject "vazio" --participants repo-a,repo-b --body "x" >/dev/null
start_empty="$(run_start empty s-x)"
if ! echo "$start_empty" | grep -q "LIAISON — bastões"; then
  echo "OK [inicio-vazio]: canal sem bastão nenhum não ganha linha de bastões"
else
  echo "FAIL [inicio-vazio]: esperava nenhuma linha de bastões, achou: $start_empty"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — bastão no início de sessão (REQ-13, REQ-09)"
exit 0
