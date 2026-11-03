#!/usr/bin/env bash
# Gate — TASK-20 de add-liaison-handoff-baton (design §2.4/§2.8, liaison-baton-local.mjs):
#   [claim-cache-local] claim vencedora grava baton-local.json (claims + holders, com
#     next_renew_at e tamanho/mtime do log próprio no momento), sob a trava local
#     (<channel>@<self>@local.lock), para o gancho de renovação (TASK-26) e baton
#     status/início de sessão (TASK-23/24) — ainda não implementados, apenas consumidores
#     futuros do que esta task grava
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-liaison-baton-cache.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=baton-cache-gate

mk_repo() {
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -q -m "chore: init $1" >/dev/null
}

LG() { # LG <nome-repo> <args...>
  local repo="$1"; shift
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"
}

LGS() { # LGS <nome-repo> <session> <args...>
  local repo="$1" session="$2"; shift 2
  FORGE_ROOT="$T/$repo" CLAUDE_CODE_SESSION_ID="$session" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"
}

offer_id() { printf '%s' "$1" | grep '^OK baton offer' | sed -E 's/^OK baton offer — //'; }

mk_repo cache
LG cache open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG cache thread open "$CH" t1 --subject "cache" --participants repo-a,repo-b --body "x" >/dev/null
outcache="$(LGS cache s-offcache baton offer "$CH" --thread t1 --subject "cache tarefa" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL [claim-cache-local]: oferta falhou inesperadamente (rc=$rc): $outcache"
  exit 1
fi
batidcache="$(offer_id "$outcache")"
if [ -z "$batidcache" ]; then
  echo "FAIL [claim-cache-local]: não consegui extrair baton_id de: $outcache"
  exit 1
fi

claimout="$(LGS cache s-claimcache baton claim "$CH" "$batidcache" 2>&1)"; claimrc=$?
cachefile="$T/cache/.forge/cache/liaison-baton/$CH/baton-local.json"
cache_ok="$(node -e '
const fs = require("fs");
const path = process.argv[1];
const batonId = process.argv[2];
if (!fs.existsSync(path)) { process.stdout.write("0:ausente"); process.exit(0); }
let state;
try { state = JSON.parse(fs.readFileSync(path, "utf8")); } catch (e) { process.stdout.write("0:json-invalido:" + e.message); process.exit(0); }
const c = state.claims && state.claims[batonId];
const h = state.holders && state.holders[batonId];
const ok = c && c.session === "s-claimcache" && h && h.session === "s-claimcache"
  && typeof h.nextRenewAt === "string" && typeof h.ownLogSize === "number" && h.ownLogSize > 0
  && typeof h.ownLogMtimeMs === "number" && h.ownLogMtimeMs > 0;
process.stdout.write(ok ? "1:ok" : "0:" + JSON.stringify({ c, h }));
' "$cachefile" "$batidcache" 2>&1)"

case "$cache_ok" in
  1:*)
    echo "OK [claim-cache-local]: baton-local.json gravado com claims+holders+nextRenewAt+ownLogSize/mtimeMs (claim rc=$claimrc)"
    ;;
  *)
    echo "FAIL [claim-cache-local]: baton-local.json ausente ou incompleto depois da claim (rc=$claimrc, cache_ok=$cache_ok, out=$claimout)"
    fail=1
    ;;
esac

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — baton-local.json (liaison-baton-local.mjs) gravado por claim vencedora"
exit 0
