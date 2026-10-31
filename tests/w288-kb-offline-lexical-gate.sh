#!/usr/bin/env bash
# Gate W288 — busca unificada (/forge:kb): nenhum dado sai da máquina e o caminho lexical é zero-dep
# (change add-unified-knowledge-search, REQ-04, REQ-09, NFR-03; design §2.8, §2.12).
#
#   [1] estático: lib/kb-*.mjs (fora kb-install.mjs) não importam http, https, http2, net, tls, dgram,
#       dns, child_process, worker_threads nem usam fetch(
#   [2] estático: nenhuma referência a host/SDK de provedor de LLM em kb.sh e lib/kb-*.mjs
#   [3] estático: kb.sh e o que ele inclui por source não chamam curl, wget, nc, ssh, npm, npx nem
#       subcomando de rede do git
#   [4] estático, zero-dep: kb-cli/kb-corpus/kb-lexical/kb-fuse só importam node:* e módulos do
#       harness, e a camada semântica só entra por import() dinâmico
#   [5] dinâmico: git substituto no PATH — sem FORGE_ROOT, numa árvore git, só `rev-parse` é chamado
#   [6] dinâmico, lexical: build, query, status, eval, semantic status e semantic remove sob bloqueio
#       de rede (permissões do Node quando há --allow-net, e interceptador --require em qualquer Node)
#   [7] controle positivo: um canário tenta fetch, net.connect (import ESM nomeado), socket cru e
#       processo filho, na thread principal e num Worker, contra um servidor local (outro processo);
#       sob cada mecanismo, as 8 tentativas são bloqueadas; sem bloqueio (recontrole), as 8 passam
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w288.XXXXXX)"
# shellcheck source=fixtures/kb/semantic-env.sh
. "$WS/tests/fixtures/kb/semantic-env.sh"
trap 'semantic_env_teardown; rm -rf "$T"' EXIT
LIB="$WS/template/.forge/scripts/lib"
firstline() { local o; o="$("$@")" || return $?; printf '%s\n' "${o%%$'\n'*}"; }
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }

# [1]
for f in "$LIB"/kb-*.mjs; do
  [ "$(basename "$f")" = kb-install.mjs ] && continue
  bad="$(grep -nE "from '(node:)?(http|https|http2|net|tls|dgram|dns|child_process|worker_threads)'|import\('(node:)?(http|https|http2|net|tls|dgram|dns|child_process|worker_threads)'|require\('(node:)?(http|https|http2|net|tls|dgram|dns|child_process|worker_threads)'|\bfetch\(" "$f" || true)"
  [ -z "$bad" ] || fail 1 "$(basename "$f") toca rede/processo: $bad"
done
ok 1

# [2]
bad="$(grep -niE '(api\.anthropic\.com|@anthropic-ai|api\.openai\.com|\bopenai\b|generativelanguage\.googleapis\.com|@google/generative-ai|api\.voyageai\.com|api\.cohere\.ai|api\.mistral\.ai|bedrock-runtime|\bollama\b)' "$WS/template/.forge/scripts/kb.sh" "$LIB"/kb-*.mjs || true)"
[ -z "$bad" ] || fail 2 "referência a provedor de LLM: $bad"
ok 2

# [3]
srcs="$WS/template/.forge/scripts/kb.sh"
for inc in $(grep -oE '^\s*(\.|source)\s+"\$SCRIPT_DIR/[^"]+"' "$srcs" | sed -E 's/.*"\$SCRIPT_DIR\/([^"]+)"/\1/'); do srcs="$srcs $WS/template/.forge/scripts/$inc"; done
grep -q 'forge-root.sh' <<<"$srcs" || fail 3 "kb.sh deveria incluir lib/forge-root.sh"
bad="$(grep -nvE '^\s*#' $srcs | grep -E '(^|[^a-zA-Z_-])(curl|wget|nc|ssh|npm|npx)([[:space:]]|$)|git([[:space:]]+-C[[:space:]]+[^ ]+)?[[:space:]]+(fetch|pull|push|clone|ls-remote|remote)\b' || true)"
[ -z "$bad" ] || fail 3 "programa de rede no kb.sh ou incluídos: $bad"
ok 3

# [4]
for m in kb-cli kb-corpus kb-lexical kb-fuse; do
  bad="$(grep -E "^\s*import .* from '" "$LIB/$m.mjs" | grep -vE "from '(node:[a-z_/]+|\./(kb-[a-z]+|yaml-lite|liaison-trust|untrusted-render)\.mjs)'" || true)"
  [ -z "$bad" ] || fail 4 "$m.mjs importa fora de node:* e do harness: $bad"
  grep -qE "^\s*import .*kb-(semantic|install)" "$LIB/$m.mjs" && fail 4 "$m.mjs importa estaticamente a camada semântica"
done
ok 4

# fixture comum: raiz com cópia da maquinaria (kb.sh real) e servidor local para o canário
kb_env_setup
mkdir -p "$R/docs/plans" "$R/.forge/ledger"
printf '# Grafo\n\ngrafo codigo python\n' > "$R/docs/plans/grafo.md"
printf '{"entries":[{"id":"LDG-0001","title":"grafo"}]}\n' > "$R/.forge/ledger/ledger.json"
printf '[{"q":"grafo python","gold":["grafo.md"]}]\n' > "$T/q.json"

# [5]
G="$T/gitrepo"; mkdir -p "$G"; cp -R "$R/.forge" "$G/.forge"; cp -R "$R/docs" "$G/docs"
git -C "$G" init -q && git -C "$G" -c user.email=t@t -c user.name=t add -A >/dev/null && git -C "$G" -c user.email=t@t -c user.name=t commit -qm init
mkdir -p "$T/gitbin"; cp "$WS/tests/fixtures/kb/fake-git.sh" "$T/gitbin/git"; chmod +x "$T/gitbin/git"
export REAL_GIT="$(command -v git)" FAKE_GIT_LOG="$T/git.log"
# sem FORGE_ROOT de verdade: quem invoca o gate (red-evidence, run-all) pode tê-lo exportado
( cd "$G" && unset FORGE_ROOT && PATH="$T/gitbin:$PATH" bash .forge/scripts/kb.sh build >/dev/null 2>&1 && PATH="$T/gitbin:$PATH" bash .forge/scripts/kb.sh query "grafo" >/dev/null 2>&1 && PATH="$T/gitbin:$PATH" bash .forge/scripts/kb.sh status >/dev/null 2>&1 ) || fail 5 "kb.sh falhou sem FORGE_ROOT numa árvore git"
[ -s "$T/git.log" ] || fail 5 "git substituto não registrou nada (o teste não exercitou a resolução de raiz)"
other="$(grep -vx 'rev-parse' "$T/git.log" || true)"
[ -z "$other" ] || fail 5 "subcomandos de git além de rev-parse: $other"
ok 5

# bloqueio: modos disponíveis neste Node
MECHS="interceptador"
nh="$(node --help 2>/dev/null || true)"; grep -q -- '--allow-net' <<<"$nh" && MECHS="permissoes $MECHS"
echo "INFO mecanismos de bloqueio de rede neste Node ($(node --version)): $MECHS"
blocked() { # <mecanismo> <args do kb...>
  local mech="$1"; shift
  : > "$T/net.log"
  case "$mech" in
    permissoes) NODE_OPTIONS="--permission --allow-fs-read=* --allow-fs-write=$T --allow-worker" kb "$@" ;;
    interceptador) NO_NETWORK_LOG="$T/net.log" NODE_OPTIONS="--require=$WS/tests/fixtures/kb/no-network.cjs" kb "$@" ;;
  esac
}
assert_clean() { [ -s "$T/net.log" ] && fail "$1" "tentativa de rede/processo registrada: $(sort -u "$T/net.log" | tr '\n' ' ')"; return 0; }

# [6]
for mech in $MECHS; do
  for args in "build" "query grafo" "status" "eval $T/q.json" "semantic status" "semantic remove"; do
    # shellcheck disable=SC2086
    blocked "$mech" $args > "$T/o" 2> "$T/e" || fail 6 "[$mech] '$args' falhou sob bloqueio: $(tail -3 "$T/e")"
    assert_clean 6
  done
  o="$(blocked "$mech" query grafo 2>/dev/null)"; grep -q '^modo: lexical' <<<"${o%%$'\n'*}" || fail 6 "[$mech] modo inesperado"
done
ok 6

# [7]
canary() { # <mecanismo|nenhum>
  case "$1" in
    permissoes) NODE_OPTIONS="--permission --allow-fs-read=* --allow-worker" node "$WS/tests/fixtures/kb/net-canary.mjs" "http://127.0.0.1:$PORT/ping" 2>/dev/null ;;
    interceptador) NODE_OPTIONS="--require=$WS/tests/fixtures/kb/no-network.cjs" node "$WS/tests/fixtures/kb/net-canary.mjs" "http://127.0.0.1:$PORT/ping" ;;
    nenhum) node "$WS/tests/fixtures/kb/net-canary.mjs" "http://127.0.0.1:$PORT/ping" ;;
  esac
}
c="$(canary nenhum)"
[ "$(grep -c ':ok$' <<<"$c")" = "8" ] || fail 7 "recontrole sem bloqueio não alcançou o servidor local (o canário não prova nada): $c"
for mech in $MECHS; do
  c="$(canary "$mech")"
  [ "$(grep -c ':bloqueado$' <<<"$c")" = "8" ] || fail 7 "[$mech] o bloqueio deixou passar: $c"
done
ok 7

echo "PASS w288-kb-offline-lexical (7 casos; bloqueio: $MECHS)"
