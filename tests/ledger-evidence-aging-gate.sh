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
ALL_GROUPS="schema stale verify supersede show specnew closed wiring docs mutation"
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
  grep -q "limiar 50 de forge.yaml" <<<"$(head -1 <<<"$out")" || _fail stale-4 "forge.yaml não lido: $(head -1 <<<"$out")"
  grep -q "^LDG-0002 —" <<<"$out" && _fail stale-4 "41d com limiar 50 não deveria envelhecer"
  out="$(_lg "$F" stale --as-of "$ASOF" --days 20 2>&1 || true)"
  grep -q "limiar 20 de --days" <<<"$(head -1 <<<"$out")" || _fail stale-4 "--days não venceu: $(head -1 <<<"$out")"
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
  grep -q "(referência 2019-04-11," <<<"$(head -1 <<<"$out")" || _fail stale-8 "as_of não veio do HEAD: $(head -1 <<<"$out")"
  N="$T/stale-nohead"; mkdir -p "$N"; cp -R "$WS/template/.forge" "$N/.forge"; git -C "$N" init -q
  printf '{"entries":[]}\n' > "$N/.forge/ledger/ledger.json"
  set +e; o="$(_lg "$N" stale 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 2 ] && grep -q -- "--as-of" <<<"$o" || _fail stale-8 "sem HEAD deveria sair 2 apontando --as-of — rc=$rc: $o"
  o="$(_lg "$N" stale --as-of "$ASOF" 2>&1)" || _fail stale-8 "sem HEAD mas com --as-of deveria rodar: $o"
  grep -q "^LEDGER stale: 0 de 0 ativo(s)" <<<"$(head -1 <<<"$o")" || _fail stale-8 "ledger vazio sem '0 de 0': $o"
  echo "OK [stale-8] — HEAD como relógio; sem HEAD exige --as-of; vazio = 0 de 0"
fi

# ───────────────────────────── verify (REQ-02, REQ-03) ─────────────────────────────
if _want verify; then
  F="$T/verify"; _fixture "$F"
  LFV="$F/.forge/ledger/ledger.json"
  mkdir -p "$F/src" "$F/tests"
  printf 'linha um\nlinha dois\nlinha tres\nlinha quatro\nlinha cinco\n' > "$F/src/alvo.txt"
  printf '#!/bin/sh\n# caso_alvo verifica o alvo\n' > "$F/tests/alvo-test.sh"
  mkdir -p "$T/fora"; printf 'segredo\n' > "$T/fora/x.txt"; ln -s "$T/fora/x.txt" "$F/src/link-fora.txt"
  _run_to 30 -- git -C "$F" add -A
  _commit_at "$F" "2019-03-05T10:00:00+00:00" alvos
  H1="$(_head_date "$F")"
  SHA="$(git -C "$F" rev-parse HEAD)"
  _lg "$F" add --type known-bug --title "alvo do verify" --detail "MEDIÇÃO ORIGINAL: o defeito mora na linha dois." >/dev/null   # LDG-0001
  _lg "$F" add --type tech-debt --title "item a resolver" --detail "x" >/dev/null                                         # LDG-0002
  _lg "$F" resolve LDG-0002 --note "feito" >/dev/null
  _lg "$F" add --type tech-debt --title "item a promover" --detail "x" >/dev/null                                         # LDG-0003
  _lg "$F" promote LDG-0003 --to um-change >/dev/null
  OBS="o defeito continua exatamente na linha dois do alvo"

  _scn "[verify-1] evidência file válida grava registro, last_verified e updated_at = HEAD; detail intacto (confirmed)"
  cp "$LFV" "$T/v1-antes.json"
  out="$(_lg "$F" verify LDG-0001 --kind file --ref "src/alvo.txt:2" --observed "$OBS" --verdict confirmed 2>&1)" || _fail verify-1 "verify válido reprovou: $out"
  [ "$(_jget "$LFV" LDG-0001 'e.evidence.length')" = "1" ] || _fail verify-1 "evidence não tem 1 registro"
  [ "$(_jget "$LFV" LDG-0001 'e.evidence[0].at')" = "$H1" ] || _fail verify-1 "evidence.at diferente do HEAD ($H1)"
  [ "$(_jget "$LFV" LDG-0001 'e.last_verified')" = "$H1" ] || _fail verify-1 "last_verified diferente do HEAD"
  [ "$(_jget "$LFV" LDG-0001 'e.updated_at')" = "$H1" ] || _fail verify-1 "updated_at diferente do HEAD"
  [ "$(_jget "$LFV" LDG-0001 'e.evidence[0].kind+"|"+e.evidence[0].ref+"|"+e.evidence[0].verdict')" = "file|src/alvo.txt:2|confirmed" ] || _fail verify-1 "registro com campos errados"
  [ "$(_jget "$LFV" LDG-0001 'e.detail')" = "$(_jget "$T/v1-antes.json" LDG-0001 'e.detail')" ] || _fail verify-1 "confirmed alterou o detail"
  for k in status resolved_at priority severity title; do
    [ "$(_jget "$LFV" LDG-0001 "e.$k")" = "$(_jget "$T/v1-antes.json" LDG-0001 "e.$k")" ] || _fail verify-1 "verify alterou $k"
  done
  echo "OK [verify-1] — $out"

  _scn "[verify-2] cada violação de conteúdo mínimo reprova nomeando kind/regra, ledger byte-a-byte intacto"
  _refuse() { # _refuse <rótulo> <fragmento esperado> <args...>
    local label="$1" frag="$2"; shift 2
    cp "$LFV" "$T/ref-antes.json"
    set +e; local o; o="$(_lg "$F" "$@" 2>&1)"; local rc=$?; set -e
    [ "$rc" -ne 0 ] || _fail verify-2 "$label: deveria reprovar e saiu 0 — $o"
    grep -q -- "$frag" <<<"$o" || _fail verify-2 "$label: mensagem sem '$frag' — $o"
    cmp -s "$LFV" "$T/ref-antes.json" || _fail verify-2 "$label: ledger.json mudou numa recusa"
  }
  V=(verify LDG-0001 --observed "$OBS" --verdict confirmed)
  _refuse "file sem linha"        "--kind file" "${V[@]}" --kind file --ref "src/alvo.txt"
  _refuse "file linha zero"       "--kind file" "${V[@]}" --kind file --ref "src/alvo.txt:0"
  _refuse "file além do fim"      "--kind file" "${V[@]}" --kind file --ref "src/alvo.txt:6"
  _refuse "file intervalo inverso" "--kind file" "${V[@]}" --kind file --ref "src/alvo.txt:4-2"
  _refuse "file inexistente"      "--kind file" "${V[@]}" --kind file --ref "src/nada.txt:1"
  _refuse "file absoluto"         "--kind file" "${V[@]}" --kind file --ref "$F/src/alvo.txt:1"
  _refuse "file com .."           "--kind file" "${V[@]}" --kind file --ref "../fora/x.txt:1"
  _refuse "file symlink p/ fora"  "--kind file" "${V[@]}" --kind file --ref "src/link-fora.txt:1"
  _refuse "commit inexistente"    "--kind commit" "${V[@]}" --kind commit --ref "deadbeefdeadbeef"
  _refuse "test inexistente"      "--kind test" "${V[@]}" --kind test --ref "tests/nada.sh"
  _refuse "test nome ausente"     "--kind test" "${V[@]}" --kind test --ref "tests/alvo-test.sh::caso_inexistente"
  _refuse "command só espaços"    "--kind command" "${V[@]}" --kind command --ref "   "
  _refuse "kind fora do enum"     "file|commit|test|command" "${V[@]}" --kind palpite --ref "x"
  _refuse "observed curto"        "20" verify LDG-0001 --kind command --ref "rg x" --observed "ainda existe" --verdict confirmed
  _refuse "observed = ref"        "observed" verify LDG-0001 --kind command --ref "rg defeito no alvo agora" --observed "rg defeito no alvo agora" --verdict confirmed
  _refuse "observed = title"      "observed" verify LDG-0001 --kind command --ref "rg x" --observed "alvo do verify" --verdict confirmed
  _refuse "verdict fora do enum"  "confirmed|changed" verify LDG-0001 --kind command --ref "rg x" --observed "$OBS" --verdict talvez
  echo "OK [verify-2] — 17 violações recusadas sem tocar o ledger"

  _scn "[verify-3] flags obrigatórias, flag desconhecida, entrada inexistente e status encerrado"
  _refuse "sem --kind"     "--kind"     verify LDG-0001 --ref "rg x" --observed "$OBS" --verdict confirmed
  _refuse "sem --ref"      "--ref"      verify LDG-0001 --kind command --observed "$OBS" --verdict confirmed
  _refuse "sem --observed" "--observed" verify LDG-0001 --kind command --ref "rg x" --verdict confirmed
  _refuse "sem --verdict"  "--verdict"  verify LDG-0001 --kind command --ref "rg x" --observed "$OBS"
  _refuse "flag desconhecida" "--nota" verify LDG-0001 --kind command --ref "rg x" --observed "$OBS" --verdict confirmed --nota y
  _refuse "inexistente"    "LDG-0099"   verify LDG-0099 --kind command --ref "rg x" --observed "$OBS" --verdict confirmed
  _refuse "resolved"       "resolved"   verify LDG-0002 --kind command --ref "rg x" --observed "$OBS" --verdict confirmed
  _refuse "promoted"       "promoted"   verify LDG-0003 --kind command --ref "rg x" --observed "$OBS" --verdict confirmed
  echo "OK [verify-3] — 8 recusas de uso"

  _scn "[verify-4] commit curto grava SHA completo; test::nome e range de linhas aceitos; command nunca executado"
  _lg "$F" verify LDG-0001 --kind commit --ref "${SHA:0:8}" --observed "$OBS" --verdict confirmed >/dev/null || _fail verify-4 "commit curto válido reprovou"
  [ "$(_jget "$LFV" LDG-0001 'e.evidence[e.evidence.length-1].ref')" = "$SHA" ] || _fail verify-4 "ref do commit não é o SHA completo"
  _lg "$F" verify LDG-0001 --kind test --ref "tests/alvo-test.sh::caso_alvo" --observed "$OBS" --verdict confirmed >/dev/null || _fail verify-4 "test::nome válido reprovou"
  _lg "$F" verify LDG-0001 --kind file --ref "src/alvo.txt:2-5" --observed "$OBS" --verdict confirmed >/dev/null || _fail verify-4 "range válido reprovou"
  _lg "$F" verify LDG-0001 --kind command --ref "touch $T/executou" --observed "$OBS" --verdict confirmed >/dev/null || _fail verify-4 "command válido reprovou"
  [ ! -e "$T/executou" ] || _fail verify-4 "o ref de command foi EXECUTADO"
  echo "OK [verify-4] — commit completo, test::nome, range, command não executado"

  _scn "[verify-5] verdict changed acrescenta CORREÇÃO DE REGISTRO preservando o detail; ordem e last_verified do último"
  _commit_at "$F" "2019-03-20T10:00:00+00:00" depois
  H2="$(_head_date "$F")"
  node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(d.entries.find(e=>e.id==="LDG-0001").detail)' "$LFV" > "$T/v5-antes.txt"
  NOVO="o defeito mudou: agora mora na linha quatro"
  _lg "$F" verify LDG-0001 --kind file --ref "src/alvo.txt:4" --observed "$NOVO" --verdict changed >/dev/null || _fail verify-5 "verify changed reprovou"
  node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(d.entries.find(e=>e.id==="LDG-0001").detail)' "$LFV" > "$T/v5-depois.txt"
  head -c "$(wc -c < "$T/v5-antes.txt" | tr -d ' ')" "$T/v5-depois.txt" | cmp -s - "$T/v5-antes.txt" || _fail verify-5 "detail anterior não é prefixo do novo"
  esperado="$(cat "$T/v5-antes.txt")"$'\n\n'"CORREÇÃO DE REGISTRO (${H2:0:10}): $NOVO [evidência: file src/alvo.txt:4]"
  [ "$(cat "$T/v5-depois.txt")" = "$esperado" ] || _fail verify-5 "bloco de correção fora do formato: $(tail -c 200 "$T/v5-depois.txt")"
  grep -qF "$NOVO" "$F/.forge/ledger/LEDGER.md" || _fail verify-5 "LEDGER.md não foi re-renderizado depois do verify"
  [ "$(_jget "$LFV" LDG-0001 'e.evidence.length')" = "6" ] || _fail verify-5 "esperado 6 registros acumulados"
  [ "$(_jget "$LFV" LDG-0001 'e.evidence.map(x=>x.kind).join(",")')" = "file,commit,test,file,command,file" ] || _fail verify-5 "ordem dos registros alterada"
  [ "$(_jget "$LFV" LDG-0001 'e.last_verified')" = "$H2" ] || _fail verify-5 "last_verified não é o at do último registro"
  [ "$(_jget "$LFV" LDG-0001 'e.evidence[0].at')" = "$H1" ] || _fail verify-5 "registro antigo reescrito"
  echo "OK [verify-5] — correção acumulada, 6 registros em ordem, last_verified = último"

  _scn "[verify-6] note --kind measurement avisa que não é reverificação; progress não avisa; nenhum dos dois grava last_verified"
  _lg "$F" add --type tech-debt --title "alvo do note" --detail "x" >/dev/null; IDN="$(_last_id "$LFV")"
  o="$(_lg "$F" note "$IDN" --kind measurement --text "medi de novo" 2>&1)"
  grep -q "verify" <<<"$o" || _fail verify-6 "note measurement não apontou verify: $o"
  o="$(_lg "$F" note "$IDN" --kind progress --text "andou" 2>&1)"
  grep -q "verify" <<<"$o" && _fail verify-6 "note progress não deveria falar de verify: $o"
  [ "$(_jget "$LFV" "$IDN" '"last_verified" in e')" = "false" ] || _fail verify-6 "note gravou last_verified"
  echo "OK [verify-6]"

  _scn "[verify-7] reverificação muda a referência de idade do stale (last_verified, não created_at)"
  o="$(_lg "$F" stale --as-of "2019-04-15T10:00:00+00:00" --days 20 2>&1 || true)"
  grep -q "^LDG-0001 — 26d — reverificado em 2019-03-20" <<<"$o" || _fail verify-7 "idade não partiu do last_verified (esperado 26d): $o"
  echo "OK [verify-7]"
fi

# ───────────────────────────── supersede (REQ-04) ─────────────────────────────
if _want supersede; then
  F="$T/sup"; _fixture "$F"
  LFP="$F/.forge/ledger/ledger.json"
  HS="$(_head_date "$F")"
  _lg "$F" add --type tech-debt --title "A" --detail "detalhe de A" >/dev/null   # LDG-0001
  _lg "$F" add --type tech-debt --title "B" --detail "detalhe de B" >/dev/null   # LDG-0002
  _lg "$F" add --type tech-debt --title "P" --detail "x" >/dev/null              # LDG-0003
  _lg "$F" promote LDG-0003 --to um-change >/dev/null
  _lg "$F" add --type tech-debt --title "R" --detail "x" >/dev/null              # LDG-0004
  _lg "$F" resolve LDG-0004 --note "feito" >/dev/null

  _scn "[supersede-1] add --supersedes cria o sucessor e encerra o anterior numa escrita, com elo bidirecional"
  out="$(_lg "$F" add --type tech-debt --title "B revisto" --detail "B medido de novo" --supersedes LDG-0002 2>&1)" || _fail supersede-1 "add --supersedes reprovou: $out"
  [ "$(_jget "$LFP" LDG-0005 'e.supersedes')" = "LDG-0002" ] || _fail supersede-1 "sucessor sem supersedes"
  [ "$(_jget "$LFP" LDG-0002 'e.status')" = "superseded" ] || _fail supersede-1 "anterior não ficou superseded"
  [ "$(_jget "$LFP" LDG-0002 'e.links.superseded_by')" = "LDG-0005" ] || _fail supersede-1 "anterior sem links.superseded_by"
  [ "$(_jget "$LFP" LDG-0002 'e.resolved_at')" = "$HS" ] || _fail supersede-1 "resolved_at do anterior != HEAD"
  [ "$(_jget "$LFP" LDG-0002 'e.updated_at')" = "$HS" ] || _fail supersede-1 "updated_at do anterior != HEAD"
  [ "$(_jget "$LFP" LDG-0002 'e.detail')" = "detalhe de B"$'\n\n'"SUBSTITUÍDO (${HS:0:10}): por LDG-0005" ] || _fail supersede-1 "bloco SUBSTITUÍDO fora do formato: $(_jget "$LFP" LDG-0002 'e.detail')"
  echo "OK [supersede-1] — $out"

  _scn "[supersede-2] recusas de --supersedes sem tocar o ledger"
  _sref() { local label="$1" frag="$2"; shift 2
    cp "$LFP" "$T/sref.json"; set +e; local o; o="$(_lg "$F" "$@" 2>&1)"; local rc=$?; set -e
    [ "$rc" -ne 0 ] || _fail supersede-2 "$label: deveria reprovar — $o"
    grep -q -- "$frag" <<<"$o" || _fail supersede-2 "$label: mensagem sem '$frag' — $o"
    cmp -s "$LFP" "$T/sref.json" || _fail supersede-2 "$label: ledger mudou numa recusa"; }
  _sref "alvo inexistente"  "LDG-0099"   add --type tech-debt --title "n" --detail "d" --supersedes LDG-0099
  _sref "alvo superseded"   "superseded" add --type tech-debt --title "n" --detail "d" --supersedes LDG-0002
  _sref "alvo promoted"     "promoted"   add --type tech-debt --title "n" --detail "d" --supersedes LDG-0003
  _sref "alvo resolved"     "resolved"   add --type tech-debt --title "n" --detail "d" --supersedes LDG-0004
  _sref "padrão inválido"   "LDG-12"     add --type tech-debt --title "n" --detail "d" --supersedes LDG-12
  _sref "update --supersedes" "--supersedes" update LDG-0001 --supersedes LDG-0002
  _sref "add --status superseded" "--supersedes" add --type tech-debt --title "n" --status superseded
  _sref "update --status superseded" "--supersedes" update LDG-0001 --status superseded
  _sref "update --status em superseded" "LDG-0005" update LDG-0002 --status open
  _sref "promote em superseded" "LDG-0005" promote LDG-0002 --to outro-change
  _sref "resolve em superseded" "superseded" resolve LDG-0002 --note "x"
  _lg "$F" update LDG-0002 --title "B (histórico)" >/dev/null || _fail supersede-2 "update de título em superseded deveria ser permitido"
  [ "$(_jget "$LFP" LDG-0002 'e.status')" = "superseded" ] || _fail supersede-2 "update de título reabriu o item"
  echo "OK [supersede-2] — 11 recusas; correção de título permitida sem reabrir"

  _scn "[supersede-3] list mostra o elo e a reverificação"
  mkdir -p "$F/src"; printf 'um\ndois\n' > "$F/src/a.txt"
  _lg "$F" verify LDG-0001 --kind file --ref "src/a.txt:1" --observed "o defeito segue presente na linha um" --verdict confirmed >/dev/null
  o="$(_lg "$F" list --status open 2>&1)"
  grep -q "(substitui LDG-0002)" <<<"$(grep "^LDG-0005 " <<<"$o")" || _fail supersede-3 "list sem '(substitui LDG-0002)': $o"
  grep -q "· reverificado em ${HS:0:10}" <<<"$(grep "^LDG-0001 " <<<"$o")" || _fail supersede-3 "list sem '· reverificado em': $o"
  echo "OK [supersede-3]"

fi


# ───────────────────────────── show (REQ-04) ─────────────────────────────
_sup_fixture() {
  F="$T/$1"; _fixture "$F"
  LFP="$F/.forge/ledger/ledger.json"
  HS="$(_head_date "$F")"
  _lg "$F" add --type tech-debt --title "A" --detail "detalhe de A" >/dev/null   # LDG-0001
  _lg "$F" add --type tech-debt --title "B" --detail "detalhe de B" >/dev/null   # LDG-0002
  _lg "$F" add --type tech-debt --title "B revisto" --detail "B medido de novo" --supersedes LDG-0002 >/dev/null   # LDG-0003
}
if _want show; then
  _sup_fixture show
  _scn "[show-1] show: cadeia nas duas direções a partir de qualquer elo"
  _lg "$F" add --type tech-debt --title "B terceira versão" --detail "x" --supersedes LDG-0003 >/dev/null   # LDG-0004
  for id in LDG-0002 LDG-0003 LDG-0004; do
    o="$(_lg "$F" show "$id" 2>&1)" || _fail show-1 "show $id reprovou: $o"
    esperado="$(sed "s/$id/[$id]/" <<<"LDG-0002 → LDG-0003 → LDG-0004")"
    grep -qF "cadeia de supersessão: $esperado" <<<"$o" || _fail show-1 "show $id sem a cadeia '$esperado': $o"
  done
  o="$(_lg "$F" show LDG-0001 2>&1)"
  grep -qF "cadeia de supersessão: —" <<<"$o" || _fail show-1 "item sem cadeia deveria mostrar '—': $o"
  grep -q "nunca reverificado" <<<"$o" || _fail show-1 "show sem 'nunca reverificado': $o"
  grep -q "detalhe de A" <<<"$o" || _fail show-1 "show sem detail: $o"
  set +e; o="$(_lg "$F" show LDG-0099 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || _fail show-1 "show de id inexistente deveria reprovar"
  echo "OK [show-1] — cadeia LDG-0002 → LDG-0003 → LDG-0004 vista dos três elos"

  _scn "[show-2] show termina e nomeia defeito com ciclo e elo quebrado (dado corrompido à mão)"
  C="$T/sup-corrompido"; _fixture "$C"
  node -e '
    const mk=(id,extra)=>Object.assign({id,type:"tech-debt",title:"c "+id,detail:"",severity:null,priority:null,status:"open",source:{change_id:null,origin:"manual",ref:null},links:{adr:[],capability:[],change:[],promoted_to:null},created_at:"2019-03-04T10:00:00+00:00",updated_at:null,resolved_at:null,dedup_key:"manual:"+id},extra);
    const entries=[mk("LDG-0001",{supersedes:"LDG-0002"}),mk("LDG-0002",{supersedes:"LDG-0001"}),mk("LDG-0003",{supersedes:"LDG-0999"})];
    require("fs").writeFileSync(process.argv[1],JSON.stringify({entries}));' "$C/.forge/ledger/ledger.json"
  o="$(_run_to 10 -- env FORGE_ROOT="$C" bash "$C/.forge/scripts/ledger-ops.sh" show LDG-0001 2>&1)" || _fail show-2 "show com ciclo não terminou/reprovou: $o"
  grep -q "ciclo" <<<"$o" || _fail show-2 "ciclo não nomeado: $o"
  o="$(_run_to 10 -- env FORGE_ROOT="$C" bash "$C/.forge/scripts/ledger-ops.sh" show LDG-0003 2>&1)" || _fail show-2 "show com elo quebrado reprovou: $o"
  grep -q "elo quebrado" <<<"$o" || _fail show-2 "elo quebrado não nomeado: $o"
  echo "OK [show-2]"

fi

# ───────────────────────────── specnew (REQ-04) ─────────────────────────────
if _want specnew; then
  _sup_fixture specnew
  _scn "[specnew-1] spec-new --from-ledger com item superseded: change criado sem elo, WARN com o sucessor"
  o="$(_run_to 60 -- env FORGE_ROOT="$F" bash "$F/.forge/scripts/spec-new.sh" from-velho --type feature --scale 1 --from-ledger LDG-0002 2>&1)" || _fail specnew-1 "spec-new reprovou: $o"
  M="$F/.forge/specs/active/from-velho/manifest.yaml"
  [ -f "$M" ] || _fail specnew-1 "change não foi criado: $o"
  grep -q "^ledger_origin:" "$M" && _fail specnew-1 "manifest ganhou ledger_origin para item superseded"
  grep -q "WARN" <<<"$o" && grep -q "LDG-0003" <<<"$o" || _fail specnew-1 "WARN sem o sucessor: $o"
  [ "$(_jget "$LFP" LDG-0002 'e.status')" = "superseded" ] || _fail specnew-1 "spec-new mexeu no status do superseded"
  o="$(_run_to 60 -- env FORGE_ROOT="$F" bash "$F/.forge/scripts/spec-new.sh" from-vivo --type feature --scale 1 --from-ledger LDG-0001 2>&1)" || _fail specnew-1 "controle: spec-new reprovou: $o"
  grep -q "^ledger_origin: LDG-0001" "$F/.forge/specs/active/from-vivo/manifest.yaml" || _fail specnew-1 "controle: item ativo deveria gravar ledger_origin"
  echo "OK [specnew-1] — superseded sem elo + WARN; controle ativo com elo"
fi

# ───────────────────────────── closed (REQ-07, REQ-06 render) ─────────────────────────────
if _want closed; then
  _scn "[closed-1] 'superseded' presente em cada conjunto encerrado inventariado (guarda: padrão encontrado)"
  RENDER_SRC="$WS/template/.forge/scripts/lib/ledger-render.mjs"
  OPS_SRC="$WS/template/.forge/scripts/ledger-ops.sh"
  n_r="$(grep -c "^const CLOSED = new Set(\[" "$RENDER_SRC" || true)"
  [ "$n_r" = "1" ] || _fail closed-1 "padrão CLOSED do renderizador não encontrado ($n_r) — o sítio mudou de forma"
  grep -q "'superseded'" <<<"$(grep "^const CLOSED = new Set(\[" "$RENDER_SRC")" || _fail closed-1 "renderizador sem 'superseded' no CLOSED"
  n_o="$(grep -cE "^const CLOSED = (new Set\()?\[" "$OPS_SRC" || true)"
  [ "$n_o" = "2" ] || _fail closed-1 "esperados 2 conjuntos CLOSED em ledger-ops.sh (note, status), achados $n_o"
  n_os="$(grep -E "^const CLOSED = (new Set\()?\[" "$OPS_SRC" | grep -c "'superseded'" || true)"
  [ "$n_os" = "2" ] || _fail closed-1 "só $n_os de 2 conjuntos de ledger-ops.sh têm 'superseded'"
  grep -q "'superseded'" <<<"$(grep "^const RECLASSIFIED = new Set(\[" "$WS/tools/plan-progress.mjs")" || _fail closed-1 "tools/plan-progress.mjs sem 'superseded' no balde RECLASSIFIED"
  echo "OK [closed-1] — renderizador 1/1, ledger-ops 2/2, plan-progress 1/1"

  _scn "[closed-2] contagem ativa do LEDGER.md e do status excluem superseded; note avisa item encerrado"
  F="$T/closed"; _fixture "$F"; LFC="$F/.forge/ledger/ledger.json"
  _lg "$F" add --type tech-debt --title "A" --detail "a" >/dev/null
  _lg "$F" add --type tech-debt --title "B" --detail "b" >/dev/null
  _lg "$F" add --type tech-debt --title "B2" --detail "b2" --supersedes LDG-0002 >/dev/null
  grep -q "^\*\*2 itens ativos\*\*" "$F/.forge/ledger/LEDGER.md" || _fail closed-2 "LEDGER.md não conta 2 ativos: $(grep 'ativo' "$F/.forge/ledger/LEDGER.md" | head -1)"
  grep -q "superseded 1" "$F/.forge/ledger/LEDGER.md" || _fail closed-2 "LEDGER.md não lista superseded entre encerrados"
  grep -q "^LEDGER: 2 ativo(s)" <<<"$(_lg "$F" status)" || _fail closed-2 "status não conta 2 ativos: $(_lg "$F" status)"
  o="$(_lg "$F" note LDG-0002 --kind correction --text "nota tardia" 2>&1)"
  grep -q "está em 'superseded'" <<<"$o" || _fail closed-2 "note não avisou item superseded: $o"
  echo "OK [closed-2]"

  _scn "[closed-3] render: 'reverificado em' e '↳ substitui' só nas entradas com os campos novos"
  mkdir -p "$F/src"; printf 'um\n' > "$F/src/a.txt"
  _lg "$F" verify LDG-0001 --kind file --ref "src/a.txt:1" --observed "o defeito segue presente na linha um" --verdict confirmed >/dev/null
  MDC="$F/.forge/ledger/LEDGER.md"
  grep -q "· reverificado em " <<<"$(grep "^- \*\*LDG-0001\*\*" "$MDC")" || _fail closed-3 "entrada verificada sem 'reverificado em'"
  grep -qF '↳ substitui `LDG-0002`' <<<"$(grep -A3 "^- \*\*LDG-0003\*\*" "$MDC")" || _fail closed-3 "entrada sucessora sem '↳ substitui'"
  # Entradas legadas renderizam sem nenhum dos marcadores novos: o ledger real não tem campo novo.
  R="$T/closed-real"; mkdir -p "$R"
  LEDGER_ROOT="$R" LEDGER_JSON="$REAL_LEDGER" LEDGER_TPL="$WS/template/.forge/templates/ledger/LEDGER.md" LEDGER_OUT="$R/LEDGER.md" \
    _run_to 20 -- node "$WS/template/.forge/scripts/lib/ledger-render.mjs"
  if grep -q "reverificado em\|↳ substitui" "$R/LEDGER.md"; then _fail closed-3 "ledger legado ganhou marcador novo no render"; fi
  ativos="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries.filter(e=>!["resolved","wont-fix","promoted","superseded"].includes(e.status)).length)' "$REAL_LEDGER")"
  linhas="$(grep -c "^- \*\*LDG-" "$R/LEDGER.md" || true)"
  [ "$ativos" = "$linhas" ] || _fail closed-3 "ledger real: $ativos ativos no JSON, $linhas linhas de item no render"
  echo "OK [closed-3] — marcadores só onde há campo novo; ledger legado com $linhas linha(s) de item, nenhuma marcada"
fi

# ───────────────────────────── wiring (REQ-06) ─────────────────────────────
if _want wiring; then
  F="$T/wiring"; _fixture "$F"; LFW="$F/.forge/ledger/ledger.json"
  _lg "$F" add --type tech-debt --title "velho A" --detail "a" >/dev/null   # 2019-03-04
  _lg "$F" add --type tech-debt --title "velho B" --detail "b" >/dev/null
  _lg "$F" add --type tech-debt --title "planejado" --detail "c" >/dev/null
  _lg "$F" update LDG-0003 --status planned >/dev/null
  _commit_at "$F" "2019-06-01T10:00:00+00:00" depois       # HEAD: 89 dias depois
  mkdir -p "$F/src"; printf 'um\n' > "$F/src/a.txt"
  _lg "$F" verify LDG-0002 --kind file --ref "src/a.txt:1" --observed "o defeito segue presente na linha um" --verdict confirmed >/dev/null

  _scn "[wiring-1] status: sufixo com a contagem; sem sufixo abaixo do limiar; degrada com limiar inválido"
  o="$(_lg "$F" status)"
  grep -q " · 2 sem reverificação há mais de 30d" <<<"$o" || _fail wiring-1 "status sem sufixo de 2 envelhecidos: $o"
  _set_stale_days "$F" 100
  o="$(_lg "$F" status)"; grep -q "sem reverificação" <<<"$o" && _fail wiring-1 "status com limiar 100 não deveria ter sufixo: $o"
  _set_stale_days "$F" 0
  set +e; o="$(_lg "$F" status 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 0 ] && grep -q "limiar ledger.stale_days inválido" <<<"$o" || _fail wiring-1 "status com limiar inválido: rc=$rc $o"
  _set_stale_days "$F" 30
  echo "OK [wiring-1]"

  _scn "[wiring-2] list marca o item ativo envelhecido (o que /forge:resume e SessionStart leem)"
  o="$(_lg "$F" list --status open --by-priority --top 5 2>&1)"
  grep -q " · sem reverificação há 89d" <<<"$(grep "^LDG-0001 " <<<"$o")" || _fail wiring-2 "LDG-0001 sem marca: $o"
  grep -q "sem reverificação" <<<"$(grep "^LDG-0002 " <<<"$o")" && _fail wiring-2 "LDG-0002 reverificado no HEAD não deveria ser marcado: $o"
  o="$(_lg "$F" list 2>&1)"
  grep -q "sem reverificação há 89d" <<<"$(grep "^LDG-0003 " <<<"$o")" || _fail wiring-2 "item planned envelhecido sem marca no list sem filtro: $o"
  _set_stale_days "$F" 0
  set +e; o="$(_lg "$F" list --status open 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 0 ] || _fail wiring-2 "list com limiar inválido mudou o rc: $rc"
  grep -q "sem reverificação há" <<<"$o" && _fail wiring-2 "list com limiar inválido não deveria marcar"
  grep -q "WARN" <<<"$o" || _fail wiring-2 "list com limiar inválido sem WARN: $o"
  _set_stale_days "$F" 30
  echo "OK [wiring-2]"

  _scn "[wiring-3] sem commit HEAD: status e list seguem funcionando, sem contagem e com aviso"
  N="$T/wiring-nohead"; mkdir -p "$N"; cp -R "$WS/template/.forge" "$N/.forge"; git -C "$N" init -q
  cp "$LFW" "$N/.forge/ledger/ledger.json"
  set +e; o="$(_lg "$N" status 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 0 ] && grep -q "idade não medida (sem commit HEAD)" <<<"$o" || _fail wiring-3 "status sem HEAD: rc=$rc $o"
  set +e; o="$(_lg "$N" list 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 0 ] && grep -q "WARN" <<<"$o" && grep -q "^LDG-0001 " <<<"$o" || _fail wiring-3 "list sem HEAD: rc=$rc $o"
  echo "OK [wiring-3]"

  _scn "[wiring-4] doctor: info com a contagem, ok sem envelhecidos, info com limiar inválido; rc do doctor inalterado"
  _doc() { set +e; DOC_OUT="$(_run_to 120 -- env FORGE_ROOT="$F" bash "$F/.forge/scripts/doctor.sh" --report 2>&1)"; DOC_RC=$?; set -e; }
  _set_stale_days "$F" 100000; _doc; rc_ok="$DOC_RC"
  grep -q "ledger sem itens ativos envelhecidos\|ledger: 0 item" <<<"$DOC_OUT" || _fail wiring-4 "doctor sem linha ok de idade: $(grep -i ledger <<<"$DOC_OUT")"
  _set_stale_days "$F" 30; _doc
  grep -q "harness: ledger — 2 item(ns) ativo(s) sem reverificação há mais de 30 dia(s)" <<<"$DOC_OUT" || _fail wiring-4 "doctor sem info de envelhecidos: $(grep -i ledger <<<"$DOC_OUT")"
  [ "$DOC_RC" = "$rc_ok" ] || _fail wiring-4 "envelhecimento alterou o rc do doctor ($rc_ok → $DOC_RC)"
  _set_stale_days "$F" 0; _doc
  grep -q "stale_days" <<<"$DOC_OUT" || _fail wiring-4 "doctor com limiar inválido sem info nomeando a chave"
  [ "$DOC_RC" = "$rc_ok" ] || _fail wiring-4 "limiar inválido alterou o rc do doctor ($rc_ok → $DOC_RC)"
  _set_stale_days "$F" 30
  echo "OK [wiring-4] — rc do doctor $rc_ok nas três condições"

  _scn "[wiring-5] doctor sem ledger.json não cria o arquivo (o stale fica dentro do guard)"
  D="$T/wiring-noledger"; _fixture "$D"
  rm -f "$D/.forge/ledger/ledger.json"
  set +e; _run_to 120 -- env FORGE_ROOT="$D" bash "$D/.forge/scripts/doctor.sh" --report >/dev/null 2>&1; set -e
  [ ! -e "$D/.forge/ledger/ledger.json" ] || _fail wiring-5 "o doctor criou ledger.json num projeto sem ledger"
  echo "OK [wiring-5]"
fi

# ───────────────────────────── docs (REQ-08) ─────────────────────────────
if _want docs; then
  _scn "[docs-1] comando, rule, resume, forge.yaml, forge.schema.json e help documentam o mecanismo"
  CMD="$WS/template/.forge/commands/harness/ledger.md"
  for agulha in "ledger-ops.sh verify" "ledger-ops.sh show" "ledger-ops.sh stale" "--supersedes" "--strict" "nunca execut" "commit HEAD" "/forge:close" "stale_days"; do
    grep -qF -- "$agulha" "$CMD" || _fail docs-1 "ledger.md sem '$agulha'"
  done
  grep -qF "sem reverificação" "$WS/template/.forge/commands/harness/resume.md" || _fail docs-1 "resume.md sem a instrução sobre item marcado"
  RULE="$WS/template/.forge/rules/conventions/ledger-consultation.md"
  grep -qF "verify" "$RULE" && grep -qF -- "--supersedes" "$RULE" || _fail docs-1 "rule sem verify/--supersedes"
  grep -q y <<<"$(awk '/^ledger:/{f=1;next} f&&/^[a-z]/{f=0} f&&/^[[:space:]]*stale_days:[[:space:]]*30/{print "y"}' "$WS/template/.forge/forge.yaml")" || _fail docs-1 "forge.yaml sem ledger.stale_days: 30"
  node -e '
    const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
    let ok=false; const walk=(o)=>{ if(!o||typeof o!=="object") return; if(o.ledger&&o.ledger.properties&&o.ledger.properties.stale_days){const d=o.ledger.properties.stale_days; if(d.type==="integer"&&d.minimum===1) ok=true;} for(const k of Object.keys(o)) walk(o[k]); };
    walk(s); process.exit(ok?0:1);' "$WS/template/.forge/schemas/forge.schema.json" || _fail docs-1 "forge.schema.json sem ledger.stale_days inteiro >= 1"
  h="$(bash "$WS/template/.forge/scripts/ledger-ops.sh" --help)"
  for c in verify show stale; do grep -q "$c" <<<"$h" || _fail docs-1 "help sem '$c'"; done
  for c in ledger resume; do
    cmp -s "$WS/template/.forge/commands/harness/$c.md" "$WS/plugin/forge/commands/$c.md" || _fail docs-1 "plugin/forge/commands/$c.md dessincronizado (rode npm run build:plugin)"
  done
  echo "OK [docs-1]"

  _scn "[docs-2] NFR-02 — nenhuma leitura de relógio de parede no módulo de idade nem no ledger-ops.sh (recorte: os dois arquivos inteiros, superconjunto das portas novas)"
  _nfr02() { # _nfr02 <ledger-ops.sh> <ledger-aging.mjs> — rc 0 se limpo; imprime as ocorrências
    [ -f "$1" ] && [ -f "$2" ] || { echo "arquivo do recorte ausente"; return 2; }
    ! grep -nE 'Date\.now|new Date\(\)|\$\(date' "$1" "$2"
  }
  _nfr02 "$WS/template/.forge/scripts/ledger-ops.sh" "$WS/template/.forge/scripts/lib/ledger-aging.mjs" || _fail docs-2 "leitura de relógio de parede encontrada no recorte"
  echo "OK [docs-2] — ledger-ops.sh e ledger-aging.mjs sem relógio de parede"

  _scn "[docs-3] mutação da medição do NFR-02: inserir new Date() no recorte faz reprovar; restaurar volta a passar"
  cp "$WS/template/.forge/scripts/ledger-ops.sh" "$T/nfr-ops.sh"; cp "$WS/template/.forge/scripts/lib/ledger-aging.mjs" "$T/nfr-aging.mjs"
  cp "$T/nfr-aging.mjs" "$T/nfr-aging.orig"
  _nfr02 "$T/nfr-ops.sh" "$T/nfr-aging.mjs" >/dev/null || _fail docs-3 "controle: cópia limpa reprovou"
  printf '\nconst relogio = new Date();\n' >> "$T/nfr-aging.mjs"
  if _nfr02 "$T/nfr-ops.sh" "$T/nfr-aging.mjs" >/dev/null; then _fail docs-3 "mutação: new Date() no recorte não reprovou"; fi
  cp "$T/nfr-aging.orig" "$T/nfr-aging.mjs"; cmp -s "$T/nfr-aging.mjs" "$T/nfr-aging.orig" || _fail docs-3 "restauração não bateu (cmp)"
  _nfr02 "$T/nfr-ops.sh" "$T/nfr-aging.mjs" >/dev/null || _fail docs-3 "recontrole: cópia restaurada reprovou"
  echo "OK [docs-3]"
fi

# ───────────────────────────── mutation (REQ-09) ─────────────────────────────
if _want mutation; then
  F="$T/mut"; _fixture "$F"; LFM="$F/.forge/ledger/ledger.json"
  OPSF="$F/.forge/scripts/ledger-ops.sh"; RENF="$F/.forge/scripts/lib/ledger-render.mjs"
  cp "$OPSF" "$T/ops.orig"; cp "$RENF" "$T/render.orig"
  _lg "$F" add --type tech-debt --title "M" --detail "m" >/dev/null       # LDG-0001, 2019-03-04 (alvo do mutation-1)
  _lg "$F" add --type tech-debt --title "M2" --detail "m2" >/dev/null     # LDG-0002, 2019-03-04 (alvo do mutation-2)
  _commit_at "$F" "2019-06-01T10:00:00+00:00" depois
  mkdir -p "$F/src"; printf 'um\n' > "$F/src/a.txt"
  BAD=(verify LDG-0001 --kind file --ref "src/nada.txt:1" --observed "o defeito segue presente na linha um" --verdict confirmed)
  GOOD=(verify LDG-0002 --kind file --ref "src/a.txt:1" --observed "o defeito segue presente na linha um" --verdict confirmed)
  _evn() { _jget "$LFM" LDG-0001 '(e.evidence||[]).length'; }

  _scn "[mutation-1] validação de conteúdo mínimo: controle recusa, mutação grava, recontrole recusa"
  n0="$(_evn)"; _lg "$F" "${BAD[@]}" >/dev/null 2>&1 && _fail mutation-1 "controle: evidência inválida gravou"
  [ "$(_evn)" = "$n0" ] || _fail mutation-1 "controle: evidence cresceu"
  perl -pi -e 's/const evErr = checkEvidence\(/const evErr = null \&\& checkEvidence(/' "$OPSF"
  cmp -s "$OPSF" "$T/ops.orig" && _fail mutation-1 "a mutação não alterou o script — o ponto de mutação mudou"
  _lg "$F" "${BAD[@]}" >/dev/null 2>&1 || _fail mutation-1 "mutação: sem a validação a evidência inválida deveria gravar"
  [ "$(_evn)" -gt "$n0" ] || _fail mutation-1 "mutação: evidence não cresceu"
  cp "$T/ops.orig" "$OPSF"; cmp -s "$OPSF" "$T/ops.orig" || _fail mutation-1 "restauração não bateu (cmp)"
  n1="$(_evn)"; _lg "$F" "${BAD[@]}" >/dev/null 2>&1 && _fail mutation-1 "recontrole: evidência inválida gravou"
  [ "$(_evn)" = "$n1" ] || _fail mutation-1 "recontrole: evidence cresceu"
  echo "OK [mutation-1]"

  _scn "[mutation-2] carimbo de last_verified: sem ele o item continua envelhecido"
  perl -pi -e 's/^\s*e\.last_verified = now;\s*$/\n/' "$OPSF"
  cmp -s "$OPSF" "$T/ops.orig" && _fail mutation-2 "a mutação não alterou o script"
  _lg "$F" "${GOOD[@]}" >/dev/null
  grep -q "^LDG-0002 —" <<<"$(_lg "$F" stale 2>&1)" || _fail mutation-2 "mutação: sem carimbo o item deveria seguir envelhecido"
  cp "$T/ops.orig" "$OPSF"; cmp -s "$OPSF" "$T/ops.orig" || _fail mutation-2 "restauração não bateu (cmp)"
  _lg "$F" "${GOOD[@]}" >/dev/null
  grep -q "^LDG-0002 —" <<<"$(_lg "$F" stale 2>&1)" && _fail mutation-2 "recontrole: reverificado no HEAD não deveria envelhecer"
  echo "OK [mutation-2]"

  _scn "[mutation-3] 'superseded' no CLOSED do renderizador, contra oráculo fixo da fixture (3 ativos)"
  _lg "$F" add --type tech-debt --title "N" --detail "n" >/dev/null
  _lg "$F" add --type tech-debt --title "N2" --detail "n2" --supersedes LDG-0003 >/dev/null
  ESPERADO=3   # LDG-0001, LDG-0002 e LDG-0004; LDG-0003 está superseded — conhecido por construção
  _ativos_md() { grep -oE '^\*\*[0-9]+ ite(m|ns) ativos?\*\*' "$F/.forge/ledger/LEDGER.md" | grep -oE '[0-9]+'; }
  _lg "$F" render >/dev/null; [ "$(_ativos_md)" = "$ESPERADO" ] || _fail mutation-3 "controle: $(_ativos_md) != $ESPERADO"
  perl -pi -e "s/, 'superseded'\]\)/])/ if /^const CLOSED = new Set/" "$RENF"
  cmp -s "$RENF" "$T/render.orig" && _fail mutation-3 "a mutação não alterou o renderizador"
  _lg "$F" render >/dev/null; [ "$(_ativos_md)" != "$ESPERADO" ] || _fail mutation-3 "mutação: contagem não divergiu do oráculo"
  cp "$T/render.orig" "$RENF"; cmp -s "$RENF" "$T/render.orig" || _fail mutation-3 "restauração não bateu (cmp)"
  _lg "$F" render >/dev/null; [ "$(_ativos_md)" = "$ESPERADO" ] || _fail mutation-3 "recontrole: $(_ativos_md) != $ESPERADO"
  echo "OK [mutation-3]"
fi

# ───────────────────────────── fechamento ─────────────────────────────
[ "$(_sha "$REAL_LEDGER")" = "$REAL_SHA_BEFORE" ] || _fail final "o gate ESCREVEU no ledger.json rastreado"
if [ "$GROUP" = all ]; then sel="$ALL_GROUPS"; else sel="$GROUP"; fi
DECL=0; for g in $sel; do DECL=$((DECL + $(declare_scn "$g"))); done
[ "$SCN" -gt 0 ] || _fail final "nenhum cenário executado para '$GROUP'"
[ "$SCN" -eq "$DECL" ] || _fail final "$SCN cenário(s) executado(s), $DECL declarado(s) para '$GROUP' — cenário perdido ou não declarado"
echo "PASS ledger-evidence-aging ($GROUP: $SCN cenário(s))"
