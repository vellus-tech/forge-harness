#!/usr/bin/env bash
# Gate — TASK-26/27 de add-liaison-handoff-baton (design §2.4/§2.8): o gancho de renovação
# consolida publish-result-<pid>.json (do processo destacado ou de um sync manual) sob a trava
# local, apaga os arquivos consumidos e avisa (uma vez por falha distinta) quando o resultado
# consolidado tem rc != 0.
#   [aviso-publish-falho] resultado com rc!=0 -> additionalContext + arquivos apagados
#   [aviso-publish-falho-sem-repetir] mesma falha não repete o aviso numa segunda chamada
#   [aviso-publish-sucesso] resultado com rc=0 -> arquivos apagados, sem aviso
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-liaison-baton-pubresult.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=baton-pubresult-gate

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
run_hook() { # run_hook <repo> <session_id>
  local repo="$1" sid="$2"
  (cd "$T/$repo" && printf '{"session_id":"%s"}' "$sid" | FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/hooks/session/on-post-tool-use.sh")
}
write_result() { # write_result <repo> <pid> <rc> <at>
  local repo="$1" pid="$2" rc="$3" at="$4"
  local dir="$T/$repo/.forge/cache/liaison-baton/$CH"
  mkdir -p "$dir"
  node -e 'require("fs").writeFileSync(process.argv[1], JSON.stringify({rc: Number(process.argv[2]), at: process.argv[3], attempts: 1, repairs: 0}))' \
    "$dir/publish-result-$pid.json" "$rc" "$at"
}
result_files_count() { ls "$T/$1/.forge/cache/liaison-baton/$CH"/publish-result-*.json 2>/dev/null | wc -l | tr -d ' '; }

# === [aviso-publish-falho] rc!=0 -> additionalContext, arquivos consumidos ===
mk_repo a
LG a open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
write_result a 1001 1 "2026-01-01T00:00:00Z"
out1="$(run_hook a sess-1)"; rc1=$?
after1="$(result_files_count a)"
if [ "$rc1" -eq 0 ] && echo "$out1" | grep -q "additionalContext" && echo "$out1" | grep -qi "falhou" && [ "$after1" = "0" ]; then
  echo "OK [aviso-publish-falho]: resultado com rc!=0 emite additionalContext e consome o arquivo"
else
  echo "FAIL [aviso-publish-falho]: esperava additionalContext + 0 arquivos restantes, achou rc=$rc1 out=$out1 restantes=$after1"
  fail=1
fi

# === [aviso-publish-falho-sem-repetir] mesma falha (mesmo 'at') não repete na 2a chamada ===
out2="$(run_hook a sess-1)"
if [ -z "$out2" ]; then
  echo "OK [aviso-publish-falho-sem-repetir]: segunda chamada não repete o aviso (já consumido)"
else
  echo "FAIL [aviso-publish-falho-sem-repetir]: esperava saída vazia, achou: $out2"
  fail=1
fi

# === [aviso-publish-falho] (continuação) uma NOVA falha, com 'at' diferente, avisa de novo ===
write_result a 1002 1 "2026-01-01T00:05:00Z"
out3="$(run_hook a sess-1)"
if echo "$out3" | grep -q "additionalContext"; then
  echo "OK [aviso-publish-falho]: uma NOVA falha (instante diferente) avisa de novo, mesmo já tendo avisado antes"
else
  echo "FAIL [aviso-publish-falho]: esperava aviso para a nova falha, achou: $out3"
  fail=1
fi

# === [aviso-publish-sucesso] rc=0 -> consumido, sem aviso; e múltiplos arquivos consolidam só o
# mais recente (mtime), apagando todos ===
mk_repo b
LG b open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
write_result b 2001 1 "2026-01-01T00:00:00Z"
sleep 1
write_result b 2002 0 "2026-01-01T00:01:00Z" # o MAIS RECENTE (mtime) venceu, e teve sucesso
out4="$(run_hook b sess-1)"
after4="$(result_files_count b)"
if [ -z "$out4" ] && [ "$after4" = "0" ]; then
  echo "OK [aviso-publish-sucesso]: resultado mais recente com rc=0 -- sem aviso, todos os arquivos consumidos"
else
  echo "FAIL [aviso-publish-sucesso]: esperava silêncio + 0 arquivos, achou out=$out4 restantes=$after4"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — consolidação de publish-result-*.json pelo gancho de renovação"
exit 0
