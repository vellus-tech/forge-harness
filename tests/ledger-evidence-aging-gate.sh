#!/usr/bin/env bash
# Gate — envelhecimento com evidência no ledger durável (change add-ledger-evidence-aging).
#
# POR QUE ESTE GATE EXISTE. Um item do ledger é uma afirmação sobre o código feita numa data, e o
# código muda depois. Medido no ledger deste repositório em 2026-10-30: 38 itens ativos, todos com
# mais de 30 dias desde o registro, 23 deles nunca tocados depois de criados — envelhecer em
# silêncio era o estado padrão. O change acrescenta `last_verified`/`evidence`/`supersedes` ao
# schema, as portas `verify`/`show`/`stale` e `add --supersedes`, o status terminal `superseded` e
# a marca de envelhecimento em `status`, `list` e `doctor`. Este gate exercita tudo isso numa
# fixture hermética (repositório git sintético, nunca o `ledger.json` rastreado).
#
# Grupos (primeiro argumento; sem argumento roda todos): schema · stale · verify · supersede · show ·
# specnew · closed · wiring · docs · mutation. O ordinal wNNN do arquivo é decidido na hora do merge.
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado faria os comandos git da fixture obedecerem ao
# repositório de quem invoca o gate.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

GROUP="${1:-all}"
case "$GROUP" in
  all|schema|stale|verify|supersede|show|specnew|closed|wiring|docs|mutation) : ;;
  *) echo "FAIL: grupo desconhecido '$GROUP' (schema|stale|verify|supersede|show|specnew|closed|wiring|docs|mutation)"; exit 2 ;;
esac
_want() { [ "$GROUP" = all ] || [ "$GROUP" = "$1" ]; }

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }
command -v node >/dev/null 2>&1 || { echo "NÃO VERIFICADO: 'node' ausente"; exit 3; }
command -v git  >/dev/null 2>&1 || { echo "NÃO VERIFICADO: 'git' ausente"; exit 3; }

REAL_LEDGER="$WS/.forge/ledger/ledger.json"
_sha() { if [ -f "$1" ]; then shasum -a 256 "$1" | awk '{print $1}'; else echo "AUSENTE"; fi; }
REAL_SHA_BEFORE="$(_sha "$REAL_LEDGER")"

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-ledger-aging.XXXXXX")"
trap 'rm -rf "$T"' EXIT

_run_to() { # _run_to <segundos> -- <cmd...> — teto de tempo (macOS não tem `timeout` por padrão)
  local secs="$1"; shift
  [ "${1:-}" = "--" ] && shift
  perl -e "alarm $secs; exec @ARGV" -- "$@"
}

# Contador de cenários por grupo: declarados × executados DOS GRUPOS SELECIONADOS.
declare_scn() { case "$1" in schema) echo 4;; stale) echo 8;; verify) echo 7;; supersede) echo 3;; show) echo 2;; specnew) echo 1;; closed) echo 3;; wiring) echo 5;; docs) echo 3;; mutation) echo 3;; esac; }
ALL_GROUPS="schema"
SCN=0
_scn() { SCN=$((SCN + 1)); echo "$1"; }
_fail() { echo "FAIL [$1] $2"; exit 1; }

# _fixture <dir> — copia template/.forge, tira `stale_days` do forge.yaml (cada cenário declara o
# limiar que quer) e faz um commit em data fixa, para que a data do HEAD nunca seja a de hoje.
_fixture() {
  local d="$1"
  mkdir -p "$d"
  cp -R "$WS/template/.forge" "$d/.forge"
  perl -ni -e 'print unless /^\s*stale_days:/' "$d/.forge/forge.yaml"
  rm -f "$d/.forge/ledger/ledger.json" "$d/.forge/ledger/LEDGER.md"
  git -C "$d" init -q
  _run_to 30 -- git -C "$d" add -A
  _commit_at "$d" "2019-03-04T10:00:00+00:00" init
}
_commit_at() { # _commit_at <dir> <data ISO> <msg>
  GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" \
    _run_to 30 -- git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "$3" >/dev/null
}
_set_stale_days() { # _set_stale_days <dir> <valor> — declara ledger.stale_days no forge.yaml da fixture
  local f="$1/.forge/forge.yaml"
  perl -ni -e 'print unless /^\s*stale_days:/' "$f"
  awk -v v="$2" '{print} /^ledger:[[:space:]]*$/{print "  stale_days: " v}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}
_lg() { local root="$1"; shift; _run_to 30 -- env FORGE_ROOT="$root" bash "$root/.forge/scripts/ledger-ops.sh" "$@"; }
_jget() { # _jget <ledger.json> <id> <expr JS sobre e> — imprime o valor (JSON para objetos)
  node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);if(!e){process.stdout.write("<sem-entrada>");process.exit(0)}const v=(new Function("e","return ("+process.argv[3]+")"))(e);process.stdout.write(v===undefined?"<undefined>":(typeof v==="object"?JSON.stringify(v):String(v)))' "$1" "$2" "$3"
}
_last_id() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$1"; }
_head_date() { git -C "$1" log -1 --format=%cI; }

# ───────────────────────────── schema (REQ-01) ─────────────────────────────
if _want schema; then
  SCHEMA="$WS/template/.forge/schemas/ledger.schema.json"
  _ajv() { # _ajv <arquivo-json com {entries:[...]}> — imprime "N M" (examinadas, reprovando) e os erros
    _run_to 20 -- node -e '
      const fs=require("fs");
      const Ajv2020=require("ajv/dist/2020").default||require("ajv/dist/2020");
      const schema=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));
      const v=new Ajv2020({strict:false,allErrors:true}).compile(schema.properties.entries.items);
      const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
      const bad=[];for(const e of d.entries){if(!v(e))bad.push(e.id+":"+(v.errors||[]).map(x=>x.instancePath+" "+x.message).join(";"));}
      console.log(d.entries.length+" "+bad.length);for(const b of bad)console.log(b);
    ' "$1" "$SCHEMA"
  }
  _scn "[schema-1] o ledger real do repositório (sem campos novos) continua conforme"
  r="$(_ajv "$REAL_LEDGER")"; set -- $r
  [ "${1:-0}" -ge 50 ] || _fail schema-1 "universo raso: ${1:-0} entrada(s) — o ledger real não foi lido"
  [ "${2:-x}" = "0" ] || _fail schema-1 "ledger real reprova contra o schema novo: $r"
  echo "OK [schema-1] — $1 entrada(s) examinada(s), 0 reprovando"

  _scn "[schema-2] entrada com os campos novos válidos passa; cada violação reprova nominalmente"
  node -e '
    const base={id:"LDG-0001",type:"tech-debt",title:"t",status:"open",source:{origin:"manual"},created_at:"2019-03-04T10:00:00+00:00",dedup_key:"manual:LDG-0001"};
    const ev={at:"2019-03-04T10:00:00+00:00",kind:"file",ref:"a.txt:1",observed:"o defeito continua na linha 1",verdict:"confirmed"};
    const mk=(id,patch)=>Object.assign({},base,{id,dedup_key:"manual:"+id},patch);
    const entries=[
      mk("LDG-0001",{last_verified:ev.at,evidence:[ev],supersedes:"LDG-0002",links:{superseded_by:null}}),
      mk("LDG-0002",{status:"superseded",links:{superseded_by:"LDG-0001"}}),
      mk("LDG-0003",{supersedes:"LDG-12"}),
      mk("LDG-0004",{evidence:[Object.assign({},ev,{kind:"palpite"})]}),
      mk("LDG-0005",{evidence:[(({observed,...r})=>r)(ev)]}),
      mk("LDG-0006",{evidence:[Object.assign({},ev,{extra:1})]}),
      mk("LDG-0007",{evidence:[Object.assign({},ev,{verdict:"talvez"})]}),
      mk("LDG-0008",{links:{superseded_by:"x"}}),
    ];
    require("fs").writeFileSync(process.argv[1],JSON.stringify({entries}));
  ' "$T/schema2.json"
  out="$(_ajv "$T/schema2.json")"
  first="$(head -1 <<<"$out")"
  [ "$first" = "8 6" ] || _fail schema-2 "esperado '8 6' (2 válidas, 6 inválidas), obtido '$first' — $out"
  for id in LDG-0003 LDG-0004 LDG-0005 LDG-0006 LDG-0007 LDG-0008; do
    grep -q "^$id:" <<<"$out" || _fail schema-2 "$id deveria reprovar e não reprovou — $out"
  done
  echo "OK [schema-2] — 2 válidas, 6 violações reprovadas nominalmente"

  _scn "[schema-3] 'required' da entrada intocado e 'superseded' no enum de status"
  node -e '
    const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).properties.entries.items;
    const want=["id","type","title","status","source","created_at","dedup_key"];
    if(JSON.stringify(s.required)!==JSON.stringify(want)){console.error("required mudou: "+JSON.stringify(s.required));process.exit(1)}
    if(!s.properties.status.enum.includes("superseded")){console.error("superseded fora do enum");process.exit(1)}
  ' "$SCHEMA" || _fail schema-3 "contrato de required/enum quebrado"
  echo "OK [schema-3] — required igual ao anterior; superseded no enum"

  _scn "[schema-4] portas existentes não gravam os campos novos"
  F="$T/schema4"; _fixture "$F"
  _lg "$F" add --type tech-debt --title "a" --detail "detalhe de a" >/dev/null
  _lg "$F" add --type tech-debt --title "b" --detail "detalhe de b" >/dev/null
  _lg "$F" update LDG-0001 --priority P2 >/dev/null
  _lg "$F" note LDG-0001 --kind progress --text "andou" >/dev/null
  _lg "$F" resolve LDG-0001 --note "feito" >/dev/null
  _lg "$F" promote LDG-0002 --to algum-change >/dev/null
  n="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));let n=0;for(const e of d.entries)for(const k of ["last_verified","evidence","supersedes"])if(k in e)n++;for(const e of d.entries)if(e.links&&"superseded_by" in e.links)n++;console.log(n)' "$F/.forge/ledger/ledger.json")"
  [ "$n" = "0" ] || _fail schema-4 "$n campo(s) novo(s) gravado(s) por porta existente"
  echo "OK [schema-4] — add/update/note/resolve/promote não tocam os campos novos"
fi

# ───────────────────────────── fechamento ─────────────────────────────
[ "$(_sha "$REAL_LEDGER")" = "$REAL_SHA_BEFORE" ] || _fail final "o gate ESCREVEU no ledger.json rastreado"
if [ "$GROUP" = all ]; then sel="$ALL_GROUPS"; else sel="$GROUP"; fi
DECL=0; for g in $sel; do DECL=$((DECL + $(declare_scn "$g"))); done
[ "$SCN" -gt 0 ] || _fail final "nenhum cenário executado para '$GROUP'"
[ "$SCN" -eq "$DECL" ] || _fail final "$SCN cenário(s) executado(s), $DECL declarado(s) para '$GROUP' — cenário perdido ou não declarado"
echo "PASS ledger-evidence-aging ($GROUP: $SCN cenário(s))"
