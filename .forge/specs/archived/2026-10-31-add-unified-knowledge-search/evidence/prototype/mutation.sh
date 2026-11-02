#!/usr/bin/env bash
# Prova de mutação das guardas do /forge:kb (verify, item 5): para cada mutação, uma cópia limpa do
# HEAD da worktree (git archive) recebe a mutação; o gate que guarda aquele ponto tem de reprovar
# (controle) e voltar a passar na cópia sem mutação (recontrole).
set -uo pipefail
W=/Users/milton/Documents/projects/forge-harness/.forge/worktrees/unified-knowledge-search
BASE="$(mktemp -d /tmp/kb-mut.XXXXXX)"
trap 'rm -rf "$BASE"' EXIT
fresh() { rm -rf "$BASE/ws"; mkdir -p "$BASE/ws"; git -C "$W" archive HEAD | tar -x -C "$BASE/ws"; ln -s "$W/node_modules" "$BASE/ws/node_modules"; }
L=template/.forge/scripts/lib
run() { (cd "$BASE/ws" && bash "tests/$1" 2>&1 | grep -E '^(FAIL|PASS)' | head -1); }
mutate() { # <rótulo> <gate> <comando de mutação>
  local label="$1" gate="$2" cmd="$3"
  fresh; (cd "$BASE/ws" && eval "$cmd")
  local ctl; ctl="$(run "$gate")"
  fresh
  local rec; rec="$(run "$gate")"
  local verdict=REPROVADO; [[ "$ctl" == FAIL* && "$rec" == PASS* ]] && verdict=OK
  printf '%-34s %-30s controle: %-70.70s | recontrole: %-40.40s => %s\n' "$label" "$gate" "$ctl" "$rec" "$verdict"
}
mutate "fetch( num módulo da busca"       w288-kb-offline-lexical-gate.sh "printf '\nexport const x = () => fetch(\"https://exemplo.invalid\");\n' >> $L/kb-lexical.mjs"
mutate "host de LLM no CLI"                w288-kb-offline-lexical-gate.sh "printf '\n// usa api.openai.com\n' >> $L/kb-cli.mjs"
mutate "curl no kb.sh"                     w288-kb-offline-lexical-gate.sh "sed -i '' 's/^exec node/curl -s https:\\/\\/exemplo.invalid >\\/dev\\/null; exec node/' template/.forge/scripts/kb.sh"
mutate "interceptador inerte (canário)"   w288-kb-offline-lexical-gate.sh "printf \"'use strict';\\n\" > tests/fixtures/kb/no-network.cjs"
mutate "corpus aceita untrusted-peer"     w284-kb-corpus-gate.sh "sed -i '' \"s/m.trust !== 'self' || expectedTrust(m, self, self) !== 'self'/false/\" $L/kb-corpus.mjs"
mutate "varredura nativa desligada"        w291-kb-install-gate.sh "sed -i '' 's/^export function findNative(dir) {/export function findNative(dir) { return [];/' $L/kb-integrity.mjs"
mutate "sha256 de modelo não conferido"    w292-kb-semantic-gate.sh "sed -i '' 's/if (sha256File(p) !== f.sha256)/if (false)/' $L/kb-integrity.mjs"
mutate "carga fora do confinamento"        w292-kb-semantic-gate.sh "sed -i '' 's/if (!p.startsWith(root))/if (false)/' $L/kb-semantic.mjs"
mutate "re-rank ignora o cross-encoder"    w286-kb-fuse-gate.sh "sed -i '' 's/const score = RERANK_WEIGHTS.cross_encoder \\/ (RERANK_RRF_K + cr)/const score = 0 \\/ (RERANK_RRF_K + cr)/' $L/kb-fuse.mjs"
