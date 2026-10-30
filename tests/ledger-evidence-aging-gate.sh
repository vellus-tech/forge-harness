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
ALL_GROUPS="schema stale"
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

# ───────────────────────────── stale (REQ-05) ─────────────────────────────
if _want stale; then
  F="$T/stale"; _fixture "$F"
  LFS="$F/.forge/ledger/ledger.json"
  # Ledger montado à mão (é fixture): idades e inconsistências conhecidas por construção.
  node -e '
    const ev=(at)=>({at,kind:"command",ref:"rg x",observed:"o defeito segue igual ao registro",verdict:"confirmed"});
    const mk=(id,status,created,extra)=>Object.assign({id,type:"tech-debt",title:"item "+id,detail:"",severity:null,priority:null,status,source:{change_id:null,origin:"manual",ref:null},links:{adr:[],capability:[],change:[],promoted_to:null},created_at:created,updated_at:null,resolved_at:null,dedup_key:"manual:"+id},extra||{});
    const entries=[
      mk("LDG-0001","open","2019-01-01T10:00:00+00:00"),                                   // 100d
      mk("LDG-0002","planned","2019-03-01T10:00:00+00:00"),                                // 41d
      mk("LDG-0003","in-progress","2019-01-01T10:00:00+00:00",{last_verified:"2019-04-01T10:00:00+00:00",evidence:[ev("2019-04-01T10:00:00+00:00")]}), // 10d
      mk("LDG-0004","resolved","2018-01-01T10:00:00+00:00",{resolved_at:"2018-02-01T10:00:00+00:00"}),
      mk("LDG-0005","promoted","2018-01-01T10:00:00+00:00"),
      mk("LDG-0006","superseded","2018-01-01T10:00:00+00:00"),
      mk("LDG-0007","open","2019-03-01T10:00:00+00:00"),                                   // 41d (empate com 0002)
      mk("LDG-0008","open","2019-01-01T10:00:00+00:00",{last_verified:"2019-04-05T10:00:00+00:00"}),                        // sem evidence
      mk("LDG-0009","open","2019-01-01T10:00:00+00:00",{last_verified:"2019-04-05T10:00:00+00:00",evidence:[ev("2019-04-01T10:00:00+00:00")]}), // diverge
      mk("LDG-0010","open","ontem"),                                                        // ilegível
      mk("LDG-0011","open","2019-05-01T10:00:00+00:00"),                                   // futuro
    ];
    require("fs").writeFileSync(process.argv[1],JSON.stringify({entries},null,2));
  ' "$LFS"
  ASOF="2019-04-11T10:00:00+00:00"

  _scn "[stale-1] universo, limiar default, ordem por idade e id, encerrados fora"
  set +e; out="$(_lg "$F" stale --as-of "$ASOF" 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 0 ] || _fail stale-1 "sem --strict deveria sair 0 — rc=$rc: $out"
  head -1 <<<"$out" | grep -q "^LEDGER stale: 3 de 8 ativo(s) sem reverificação há mais de 30 dia(s) (referência 2019-04-11, limiar 30 de default)" \
    || _fail stale-1 "cabeçalho inesperado: $(head -1 <<<"$out")"
  ids="$(grep -oE '^LDG-[0-9]{4} — [0-9]+d' <<<"$out" | tr '\n' '|')"
  [ "$ids" = "LDG-0001 — 100d|LDG-0002 — 41d|LDG-0007 — 41d|" ] || _fail stale-1 "lista/ordem inesperada: $ids"
  grep -q "^LDG-0001 — 100d — nunca reverificado (registrado em 2019-01-01) — item LDG-0001" <<<"$out" || _fail stale-1 "formato da linha de item: $out"
  for id in LDG-0003 LDG-0004 LDG-0005 LDG-0006; do grep -q "^$id —" <<<"$out" && _fail stale-1 "$id não deveria ser listado"; done
  echo "OK [stale-1] — 3 de 8, ordem idade desc/id, encerrados e reverificado recente fora"

  _scn "[stale-2] inconsistências listadas e contadas, nunca tratadas como recentes"
  for pair in "LDG-0008:sem evidence" "LDG-0009:last_verified" "LDG-0010:não interpretável" "LDG-0011:posterior"; do
    id="${pair%%:*}"; frag="${pair#*:}"
    grep -E "^  $id .*$frag" <<<"$out" >/dev/null || _fail stale-2 "$id ($frag) ausente da seção de inconsistências: $out"
  done
  grep -q "inconsistente(s): 4" <<<"$out" || _fail stale-2 "contagem de inconsistências ausente: $out"
  echo "OK [stale-2] — 4 inconsistências nomeadas"

  _scn "[stale-3] fronteira: idade igual ao limiar não envelhece, limiar+1 envelhece"
  out="$(_lg "$F" stale --as-of "2019-03-31T10:00:00+00:00" --days 30 2>&1 || true)"
  grep -q "^LDG-0002 —" <<<"$out" && _fail stale-3 "30d com limiar 30 não deveria envelhecer"
  out="$(_lg "$F" stale --as-of "2019-04-01T10:00:00+00:00" --days 30 2>&1 || true)"
  grep -q "^LDG-0002 — 31d" <<<"$out" || _fail stale-3 "31d com limiar 30 deveria envelhecer: $out"
  echo "OK [stale-3] — 30d fica, 31d envelhece"

  _scn "[stale-4] precedência do limiar: --days > forge.yaml > 30"
  _set_stale_days "$F" 50
  out="$(_lg "$F" stale --as-of "$ASOF" 2>&1 || true)"
  head -1 <<<"$out" | grep -q "limiar 50 de forge.yaml" || _fail stale-4 "forge.yaml não lido: $(head -1 <<<"$out")"
  grep -q "^LDG-0002 —" <<<"$out" && _fail stale-4 "41d com limiar 50 não deveria envelhecer"
  out="$(_lg "$F" stale --as-of "$ASOF" --days 20 2>&1 || true)"
  head -1 <<<"$out" | grep -q "limiar 20 de --days" || _fail stale-4 "--days não venceu: $(head -1 <<<"$out")"
  echo "OK [stale-4] — --days vence forge.yaml, que vence o default"

  _scn "[stale-5] limiar/as-of inválidos reprovam com rc 2 nomeando a fonte"
  for bad in 0 -3 abc 1.5; do
    set +e; o="$(_lg "$F" stale --as-of "$ASOF" --days "$bad" 2>&1)"; rc=$?; set -e
    [ "$rc" -eq 2 ] || _fail stale-5 "--days $bad deveria sair 2 — rc=$rc: $o"
    grep -q -- "--days" <<<"$o" || _fail stale-5 "mensagem não nomeia --days: $o"
  done
  _set_stale_days "$F" 0
  set +e; o="$(_lg "$F" stale --as-of "$ASOF" 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 2 ] && grep -q "stale_days" <<<"$o" || _fail stale-5 "forge.yaml inválido não reprovou com rc 2 nomeando a chave — rc=$rc: $o"
  _set_stale_days "$F" 30
  set +e; o="$(_lg "$F" stale --as-of "semana-passada" 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 2 ] || _fail stale-5 "--as-of inválido deveria sair 2 — rc=$rc: $o"
  echo "OK [stale-5] — --days 0/-3/abc/1.5, forge.yaml 0 e --as-of ilegível: rc 2"

  _scn "[stale-6] --strict: 1 com envelhecido ou inconsistência, 0 sem nenhum"
  set +e; _lg "$F" stale --as-of "$ASOF" --strict >/dev/null 2>&1; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail stale-6 "--strict com envelhecidos deveria sair 1 — rc=$rc"
  set +e; _lg "$F" stale --as-of "$ASOF" --days 100000 --strict >/dev/null 2>&1; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail stale-6 "--strict só com inconsistências deveria sair 1 — rc=$rc"
  cp "$LFS" "$T/stale-full.json"
  node -e 'const f=process.argv[1];const d=JSON.parse(require("fs").readFileSync(f,"utf8"));d.entries=d.entries.filter(e=>["LDG-0001","LDG-0002","LDG-0003","LDG-0004"].includes(e.id));require("fs").writeFileSync(f,JSON.stringify(d))' "$LFS"
  set +e; _lg "$F" stale --as-of "$ASOF" --days 100000 --strict >/dev/null 2>&1; rc=$?; set -e
  [ "$rc" -eq 0 ] || _fail stale-6 "--strict limpo deveria sair 0 — rc=$rc"
  cp "$T/stale-full.json" "$LFS"
  echo "OK [stale-6] — 1/1/0"

  _scn "[stale-7] determinismo: mesma entrada, mesmo as_of, mesmo limiar → saída byte-idêntica"
  _lg "$F" stale --as-of "$ASOF" > "$T/s7a.txt" 2>&1 || true
  _lg "$F" stale --as-of "$ASOF" > "$T/s7b.txt" 2>&1 || true
  cmp -s "$T/s7a.txt" "$T/s7b.txt" || _fail stale-7 "duas execuções divergiram"
  echo "OK [stale-7] — byte-idêntico"

  _scn "[stale-8] as_of padrão é o commit HEAD; sem HEAD e sem --as-of reprova rc 2; ledger vazio declara 0 de 0"
  _commit_at "$F" "2019-04-11T10:00:00+00:00" segundo
  out="$(_lg "$F" stale 2>&1 || true)"
  head -1 <<<"$out" | grep -q "(referência 2019-04-11," || _fail stale-8 "as_of não veio do HEAD: $(head -1 <<<"$out")"
  N="$T/stale-nohead"; mkdir -p "$N"; cp -R "$WS/template/.forge" "$N/.forge"; git -C "$N" init -q
  printf '{"entries":[]}\n' > "$N/.forge/ledger/ledger.json"
  set +e; o="$(_lg "$N" stale 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 2 ] && grep -q -- "--as-of" <<<"$o" || _fail stale-8 "sem HEAD deveria sair 2 apontando --as-of — rc=$rc: $o"
  o="$(_lg "$N" stale --as-of "$ASOF" 2>&1)" || _fail stale-8 "sem HEAD mas com --as-of deveria rodar: $o"
  head -1 <<<"$o" | grep -q "^LEDGER stale: 0 de 0 ativo(s)" || _fail stale-8 "ledger vazio sem '0 de 0': $o"
  echo "OK [stale-8] — HEAD como relógio; sem HEAD exige --as-of; vazio = 0 de 0"
fi

# ───────────────────────────── fechamento ─────────────────────────────
[ "$(_sha "$REAL_LEDGER")" = "$REAL_SHA_BEFORE" ] || _fail final "o gate ESCREVEU no ledger.json rastreado"
if [ "$GROUP" = all ]; then sel="$ALL_GROUPS"; else sel="$GROUP"; fi
DECL=0; for g in $sel; do DECL=$((DECL + $(declare_scn "$g"))); done
[ "$SCN" -gt 0 ] || _fail final "nenhum cenário executado para '$GROUP'"
[ "$SCN" -eq "$DECL" ] || _fail final "$SCN cenário(s) executado(s), $DECL declarado(s) para '$GROUP' — cenário perdido ou não declarado"
echo "PASS ledger-evidence-aging ($GROUP: $SCN cenário(s))"
