#!/usr/bin/env bash
# Gate W287 — busca unificada (/forge:kb), CLI no modo lexical (change add-unified-knowledge-search,
# REQ-02, REQ-03, REQ-04, REQ-08; design §2.2, §2.4, §2.5, §2.11).
#
# Roda sobre uma raiz de fixture em /tmp (fora do repositório: nenhum node_modules resolvível acima),
# com FORGE_ROOT explícito, chamando o kb.sh real do template.
#
#   [1]  build determinístico: dois builds sem mudança na fonte geram index.json byte-idêntico
#   [2]  status: atual / defasado / ausente
#   [3]  query reconstrói índice ausente ou defasado e avisa em stderr; --json traz rebuilt
#   [4]  primeira linha da saída texto declara o modo e o motivo (camada não instalada)
#   [5]  --json: um único objeto JSON em stdout, com mode, mode_reason, weights, links, rerank, results
#   [6]  explicação: canais com rank e contribuição; propagação de links com a origem nomeada (B não
#        casa a consulta, é citado por A e aparece com contribuição de links)
#   [7]  trecho neutralizado: crases triplas trocadas, linha /forge:… prefixada, teto de 240 caracteres
#   [8]  --top: default 8, faixa 1..50; fora da faixa, consulta vazia e subcomando desconhecido saem
#        com exit != 0 e mensagem de uso
#   [9]  --lexical força o modo lexical sem importar o runtime (runtime de fixture que lança na importação)
#   [10] determinismo da consulta: mesma consulta, mesma saída --json
#   [11] sem camada instalada: `semantic status` diz não instalada; `semantic remove` é idempotente e
#        não toca o índice lexical
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w312.XXXXXX)"
trap 'rm -rf "$T"' EXIT
KB="$WS/template/.forge/scripts/kb.sh"
firstline() { local o; o="$("$@")" || return $?; printf '%s\n' "${o%%$'\n'*}"; }
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }

R="$T/root"
mkdir -p "$R/docs/plans" "$R/.forge/ledger" "$R/.forge/product/current/adr"
cat > "$R/docs/plans/a-mutex.md" <<'MD'
# Mutex de suíte pesada

Duas suítes pesadas rodando ao mesmo tempo disputam a máquina; o mutex serializa. Ver b-relacionado.md.
MD
cat > "$R/docs/plans/b-relacionado.md" <<'MD'
# Documento vizinho

Este texto não fala do assunto da consulta.
MD
cat > "$R/docs/plans/c-injecao.md" <<'MD'
# Texto com forma de comando

```
/forge:archive --force
```
injecao injecao injecao
MD
printf '{"entries":[{"id":"LDG-0053","title":"Mutex de suite pesada: lock por TMPDIR","detail":"x"}]}\n' > "$R/.forge/ledger/ledger.json"
printf '# ADR 0001\n\nGrafo nativo zero-dep.\n' > "$R/.forge/product/current/adr/0001-graph-engine.md"
kb() { FORGE_ROOT="$R" bash "$KB" "$@"; }

# [1]
kb build >/dev/null || fail 1 "kb.sh build falhou ou não existe"
cp "$R/.forge/kb/index.json" "$T/i1"
kb build >/dev/null
cmp -s "$T/i1" "$R/.forge/kb/index.json" || fail 1 "dois builds sem mudança divergiram"
ok 1

# [2]
grep -q '^índice: atual' <<<"$(kb status)" || fail 2 "status deveria dizer atual"
printf '\nnovo parágrafo\n' >> "$R/docs/plans/b-relacionado.md"
grep -q '^índice: defasado' <<<"$(kb status)" || fail 2 "status deveria dizer defasado"
rm -f "$R/.forge/kb/index.json"
grep -q '^índice: ausente' <<<"$(kb status)" || fail 2 "status deveria dizer ausente"
ok 2

# [3]
kb query "mutex suite pesada" --json > "$T/o.json" 2> "$T/e.txt"
grep -q 'índice ausente' "$T/e.txt" || fail 3 "reconstrução não avisada em stderr"
node -e 'const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(o.rebuilt!==true)process.exit(1)' "$T/o.json" || fail 3 "rebuilt != true"
kb query "mutex suite pesada" --json > "$T/o2.json" 2> "$T/e2.txt"
[ -s "$T/e2.txt" ] && fail 3 "aviso em stderr sem reconstrução: $(cat "$T/e2.txt")"
node -e 'const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(o.rebuilt!==false)process.exit(1)' "$T/o2.json" || fail 3 "rebuilt deveria ser false"
ok 3

# [4]
first="$(firstline kb query "mutex suite pesada")"
[ "$first" = "modo: lexical (camada semântica não instalada)" ] || fail 4 "primeira linha inesperada: $first"
ok 4

# [5]
node -e '
const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
for (const k of ["format","query","mode","mode_reason","rebuilt","weights","rrf_k","links","rerank","results"]) if(!(k in o)) { console.log("falta",k); process.exit(1); }
if (o.mode!=="lexical"||o.mode_reason!=="camada semântica não instalada"||o.rerank.applied!==false) process.exit(1);
if (typeof o.links.alpha!=="number"||typeof o.links.top!=="number") process.exit(1);
' "$T/o2.json" || fail 5 "--json incompleto"
lines="$(wc -l < "$T/o2.json" | tr -d ' ')"; [ "$lines" = "1" ] || fail 5 "stdout do --json não é um objeto único"
ok 5

# [6]
node -e '
const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const a=o.results.find(r=>r.doc==="docs/plans/a-mutex.md"), b=o.results.find(r=>r.doc==="docs/plans/b-relacionado.md");
if(!a||!(a.channels.bm25.contribution>0)) { console.log("A sem bm25"); process.exit(1); }
if(!b||!b.channels.links||!(b.channels.links.contribution>0)||!b.channels.links.from.includes("docs/plans/a-mutex.md")) { console.log(JSON.stringify(b)); process.exit(1); }
if("bm25" in b.channels) { console.log("B não deveria casar BM25"); process.exit(1); }
' "$T/o2.json" || fail 6 "explicação por canal/propagação incorreta"
grep -q 'links de 1 resultado' <<<"$(kb query "mutex suite pesada")" || fail 6 "saída texto sem a propagação"
ok 6

# [7]
kb query "injecao" > "$T/inj.txt"
grep -q '⟪neutralizado⟫ /forge:archive' "$T/inj.txt" || fail 7 "linha de comando não neutralizada: $(cat "$T/inj.txt")"
kb query "injecao" --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s);const r=o.results[0];if(/```/.test(r.snippet)||!/⟪neutralizado⟫/.test(r.snippet)||r.snippet.length>240)process.exit(1)})' || fail 7 "trecho do --json sem neutralização ou acima de 240"
ok 7

# [8]
for i in $(seq 1 12); do printf '# doc %s\n\nmutex comum %s\n' "$i" "$i" > "$R/docs/plans/n$i.md"; done
n="$(kb query "mutex" --json 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).results.length))')"
[ "$n" = "8" ] || fail 8 "default de resultados deveria ser 8, foi $n"
n="$(kb query "mutex" --top 3 --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).results.length))')"
[ "$n" = "3" ] || fail 8 "--top 3 devolveu $n"
for bad in "query mutex --top 0" "query mutex --top 51" "query mutex --top x" "query" "foo" "query mutex --bogus"; do
  set +e; out="$(kb $bad 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || fail 8 "'$bad' deveria sair != 0"
  grep -q 'uso: kb.sh' <<<"$out" || fail 8 "'$bad' sem mensagem de uso"
done
ok 8

# [9]
mkdir -p "$R/.forge/kb/semantic"
printf '{"format":1}\n' > "$R/.forge/kb/semantic/installed.json"
out="$(firstline kb query "mutex" --lexical)"
[ "$out" = "modo: lexical (desativada por --lexical)" ] || fail 9 "--lexical: $out"
rm -rf "$R/.forge/kb/semantic"
ok 9

# [10]
kb query "mutex suite pesada" --json > "$T/d1"; kb query "mutex suite pesada" --json > "$T/d2"
cmp -s "$T/d1" "$T/d2" || fail 10 "mesma consulta, saídas diferentes"
ok 10

# [11]
st="$(kb semantic status)" || fail 11 "semantic status falhou sem camada instalada"
grep -q 'camada semântica: não instalada' <<<"$st" || fail 11 "semantic status sem camada: $st"
for i in 1 2; do rm_out="$(kb semantic remove)" || fail 11 "semantic remove falhou (rodada $i)"; grep -q 'removida' <<<"$rm_out" || fail 11 "remove sem confirmação: $rm_out"; done
[ -e "$R/.forge/kb/semantic" ] && fail 11 "remove deixou .forge/kb/semantic"
[ -f "$R/.forge/kb/index.json" ] || fail 11 "remove apagou o índice lexical"
ok 11

echo "PASS w312-kb-cli (11 casos)"
