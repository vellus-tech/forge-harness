#!/usr/bin/env bash
# Gate W294 — busca unificada (/forge:kb), superfície: comando, remissão, gitignore, plugin e doctor
# (change add-unified-knowledge-search, REQ-05, REQ-09, REQ-10; design §2.9, §2.12).
#
#   [1] /forge:kb existe com frontmatter e declara a política de cloud; /forge:query cita /forge:kb;
#       .forge/kb/ no gitignore.patch e no .gitignore da raiz; plugin sincronizado
#   [2] doctor informa o estado da busca unificada como info, não cria .forge/kb/semantic, e numa
#       worktree real sem FORGE_ROOT acha a instalação do checkout principal
#   [3] ADR 0004 no baseline: indexada, emenda explicitamente a 0001, registra o padrão opt-in (pins
#       na maquinaria, sem binário nativo, degradação) e a dúvida de licença dos dados de treino
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w319.XXXXXX)"
trap 'rm -rf "$T"' EXIT
KB="$WS/template/.forge/scripts/kb.sh"
firstline() { local o; o="$("$@")" || return $?; printf '%s\n' "${o%%$'\n'*}"; }
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }

# [1]
CMD="$WS/template/.forge/commands/graph/kb.md"
[ "$(sed -n 1p "$CMD")" = "---" ] && grep -q '^description:' "$CMD" || fail 1 "kb.md sem frontmatter"
grep -q '/forge:kb' "$WS/template/.forge/commands/graph/query.md" || fail 1 "query.md não cita /forge:kb"
grep -qxF '.forge/kb/' "$WS/installer/gitignore.patch" || fail 1 ".forge/kb/ fora do gitignore.patch"
grep -qxF '.forge/kb/' "$WS/.gitignore" || fail 1 ".forge/kb/ fora do .gitignore da raiz"
[ -f "$WS/plugin/forge/commands/kb.md" ] || fail 1 "plugin sem o comando kb (rode npm run build:plugin)"
grep -qi 'cloud' "$CMD" && grep -qi 'opt-in' "$CMD" || fail 1 "kb.md não declara a política de cloud"
ok 1

# [2]
D="$T/doc"; mkdir -p "$D"; cp -R "$WS/template/.forge" "$D/.forge"
set +e; out="$(cd "$D" && FORGE_ROOT="$D" bash .forge/scripts/doctor.sh 2>&1)"; set -e
line="$(printf '%s\n' "$out" | grep 'busca unificada' || true)"
[ -n "$line" ] || fail 2 "doctor não informa o estado da busca unificada"
grep -q '·' <<<"$line" || fail 2 "linha da busca unificada não é info: $line"
grep -q 'não instalada' <<<"$line" || fail 2 "linha não informa a camada semântica: $line"
[ -e "$D/.forge/kb/semantic" ] && fail 2 "doctor criou .forge/kb/semantic"
# raízes diferentes: worktree git real, sem FORGE_ROOT, camada instalada só no checkout principal
M="$T/main"; mkdir -p "$M"; cp -R "$WS/template/.forge" "$M/.forge"
git -C "$M" init -q && git -C "$M" -c user.email=t@t -c user.name=t add -A >/dev/null && git -C "$M" -c user.email=t@t -c user.name=t commit -qm init
git -C "$M" worktree add -q "$T/wt" -b feat/x >/dev/null 2>&1
mkdir -p "$M/.forge/kb/semantic"; printf '{"format":1}\n' > "$M/.forge/kb/semantic/installed.json"
set +e; out="$(cd "$T/wt" && env -u FORGE_ROOT bash .forge/scripts/doctor.sh 2>&1)"; set -e
line="$(grep 'busca unificada' <<<"$out" || true)"
grep -q 'camada semântica instalada' <<<"$line" || fail 2 "doctor na worktree não achou a instalação do checkout principal: $line"
git -C "$M" worktree remove --force "$T/wt" >/dev/null 2>&1 || true
ok 2

# [3]
ADR="$WS/.forge/product/current/adr/0004-opt-in-runtime-layer.md"
[ -f "$ADR" ] || fail 3 "ADR 0004 ausente"
grep -q '0004' "$WS/.forge/product/current/adr/README.md" || fail 3 "ADR 0004 fora do índice"
grep -q '0001' "$ADR" || fail 3 "ADR 0004 não cita a 0001 que emenda"
for want in 'opt-in' 'kb-pins' 'nativo' 'MS MARCO' 'Status:\*\* accepted'; do grep -qE "$want" "$ADR" || fail 3 "ADR 0004 sem: $want"; done
ok 3

echo "PASS w319-kb-surface (3 casos)"
