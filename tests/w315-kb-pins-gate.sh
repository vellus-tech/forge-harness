#!/usr/bin/env bash
# Gate W290 — busca unificada (/forge:kb), pins da camada semântica (change add-unified-knowledge-search,
# REQ-05; design §2.2, §2.6, §2.10).
#
#   [1] pins do template: devDependencies do workspace nas versões exatas dos pins; sem bloco
#       `dependencies` no package.json do harness; lockfile com integrity sha512 por pacote;
#       models.json de produção com URL https fixada por revisão (commit), sha256 e tamanho
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }

# [1]
node -e '
const fs=require("fs"); const ws=process.argv[1]; const pins=ws+"/template/.forge/scripts/lib/kb-pins";
const pkg=JSON.parse(fs.readFileSync(ws+"/package.json","utf8")); const pp=JSON.parse(fs.readFileSync(pins+"/package.json","utf8"));
if (pkg.dependencies) { console.log("package.json do harness tem dependencies"); process.exit(1); }
for (const [k,v] of Object.entries(pp.dependencies)) if (pkg.devDependencies[k]!==v) { console.log("devDependency",k,pkg.devDependencies[k],"!= pin",v); process.exit(1); }
const lock=JSON.parse(fs.readFileSync(pins+"/package-lock.json","utf8"));
for (const [k,m] of Object.entries(lock.packages)) { if(!k) continue; if(!/^sha512-/.test(m.integrity||"")) { console.log("sem integrity",k); process.exit(1); } }
const m=JSON.parse(fs.readFileSync(pins+"/models.json","utf8"));
for (const r of ["embedder","reranker"]) for (const f of m[r].files) { if(!/^https:\/\/huggingface\.co\/[^/]+\/[^/]+\/resolve\/[0-9a-f]{40}\//.test(f.url)||!/^[0-9a-f]{64}$/.test(f.sha256)||!(f.size>0)) { console.log("pin de modelo inválido",JSON.stringify(f)); process.exit(1); } }
' "$WS" || fail 1 "pins/devDependencies incoerentes"
ok 1

echo "PASS w315-kb-pins (1 caso)"
