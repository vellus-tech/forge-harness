#!/usr/bin/env bash
# Gate W202 — conformidade do ledger.json com o próprio schema (LDG-0169).
#
# POR QUE ESTE GATE EXISTE. .forge/ledger/ledger.json é a fonte durável do ledger; LEDGER.md é
# renderizado dela e é o que /forge:resume e rules/conventions/ledger-consultation.md mandam
# consultar antes de escolher o próximo trabalho. Medido com ajv contra
# template/.forge/schemas/ledger.schema.json (properties.entries.items): entradas antigas
# carregavam severity em minúsculo, type fora do enum (debt/bug em vez de tech-debt/known-bug),
# source como string solta, source.origin em prosa livre e links como array de URLs — nenhuma
# delas rejeitada por gate nenhum, porque ledger-ops.sh não valida contra o schema na escrita.
# O efeito visível: template/.forge/scripts/lib/ledger-render.mjs descarta em silêncio toda
# entrada cujo "type" não bate com um dos cinco valores do enum (SECTIONS fixo), então uma
# entrada open/in-progress de type inválido nunca aparece na contagem "N itens ativos" nem na
# seção nenhuma de LEDGER.md — dois leitores do mesmo arquivo (o JSON e a view humana) discordando
# em silêncio, a mesma classe do LDG-0014.
#
#   [1] conformidade com contador — valida cada entrada de .forge/ledger/ledger.json contra
#       properties.entries.items via ajv (allErrors), imprime
#       "-- universo: N entrada(s) examinada(s); M reprovando contra o schema" e reprova
#       nomeando os ids reprovados e a classe (instancePath) de cada erro.
#   [2] guarda de piso anti-vacuidade — reprova com mensagem própria quando N < 50; sem ela,
#       apagar ou truncar ledger.json aprovaria por não ter olhado nada.
#   [3] acordo entre os dois leitores — compara o "N itens ativos" da linha de resumo de
#       LEDGER.md com a contagem de entradas ativas do JSON. O conjunto de status considerado
#       "ativo" é LIDO da constante CLOSED de ledger-render.mjs (a definição que o renderizador
#       de fato usa) via regex sobre o próprio arquivo-fonte — nunca redigitado aqui —, e o
#       conjunto lido é impresso no cabeçalho da checagem: duas implementações do mesmo contrato
#       divergindo em silêncio é exatamente o LDG-0014, e este gate existe para combatê-lo, não
#       para reinstalá-lo.
#   [4] prova de mutação, os três passos, sobre CÓPIA (nunca sobre o ledger.json rastreado, que é
#       dado durável e nenhum gate pode escrever): (a) controle — cópia do ledger.json real, "0
#       reprovando"; (b) mutação — na cópia, o type de uma entrada tech-debt vira "debt" (fora do
#       enum), "1 reprovando" nomeando o id; (c) recontrole — NOVA cópia a partir do original, que
#       nunca foi escrito, "0 reprovando" de novo. A restauração é uma nova cópia de uma fonte
#       jamais escrita, não uma edição inversa do arquivo mutado — equivalente em segurança a
#       `git checkout --`, porque não existe estado intermediário sujo para desfazer: o original
#       nunca saiu do disco. Sem este passo, uma restauração quebrada produziria mutação fantasma
#       (LDG-0164, com o w200 antes da correção do commit anterior nesta branch).
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }

SCHEMA="$WS/template/.forge/schemas/ledger.schema.json"
LEDGER="$WS/.forge/ledger/ledger.json"
LEDGER_MD="$WS/.forge/ledger/LEDGER.md"
RENDERER="$WS/template/.forge/scripts/lib/ledger-render.mjs"
for f in "$SCHEMA" "$LEDGER" "$LEDGER_MD" "$RENDERER"; do
  [ -f "$f" ] || { echo "FAIL: arquivo esperado ausente: $f"; exit 1; }
done

T="$(mktemp -d /tmp/forge-w202.XXXXXX)"
trap 'rm -rf "$T"' EXIT

_run_to() { # _run_to <segundos> -- <cmd...>
  local secs="$1"; shift
  [ "${1:-}" = "--" ] && shift
  perl -e "alarm $secs; exec @ARGV" -- "$@"
}

# _check_schema <ledger.json> — roda a conformidade de [1] contra $SCHEMA (constante), sob teto de
# tempo. Combina stdout/stderr por design de chamada (o chamador redireciona 2>&1).
_check_schema() {
  local ledger="$1"
  _run_to 20 -- node -e '
    const fs = require("fs");
    const Ajv2020 = require("ajv/dist/2020").default || require("ajv/dist/2020");
    const ledgerPath = process.argv[1];
    const schemaPath = process.argv[2];
    let data;
    try {
      data = JSON.parse(fs.readFileSync(ledgerPath, "utf8"));
    } catch (e) {
      console.error(`FAIL: ledger ilegível ou ausente (${ledgerPath}): ${e.message}`);
      process.exit(1);
    }
    const schema = JSON.parse(fs.readFileSync(schemaPath, "utf8"));
    const itemSchema = schema.properties.entries.items;
    const ajv = new Ajv2020({ strict: false, allErrors: true });
    const validate = ajv.compile(itemSchema);
    const entries = Array.isArray(data.entries) ? data.entries : [];
    const n = entries.length;
    const bad = [];
    for (const e of entries) {
      if (!validate(e)) {
        const id = e && e.id ? e.id : "(sem id)";
        const classes = [...new Set((validate.errors || []).map((er) => er.instancePath || er.schemaPath))].sort();
        bad.push(`${id}: ${classes.join(", ")}`);
      }
    }
    console.log(`-- universo: ${n} entrada(s) examinada(s); ${bad.length} reprovando contra o schema`);
    if (n < 50) {
      console.error(`FAIL: universo raso — ${n} entrada(s) examinada(s), menor que o piso de 50; ledger.json truncado ou vazio não pode aprovar por vacuidade`);
      process.exit(1);
    }
    if (bad.length) {
      console.error(`FAIL: ${bad.length} entrada(s) reprovando contra o schema:`);
      for (const line of bad) console.error(`  ${line}`);
      process.exit(1);
    }
    console.log(`OK ${n} entrada(s) conformam com o schema`);
  ' "$ledger" "$SCHEMA"
}

# _check_agreement <ledger.json> <ledger-render.mjs> <LEDGER.md> — cenário [3], sob teto de tempo.
_check_agreement() {
  local ledger="$1" renderer="$2" md="$3"
  _run_to 20 -- node -e '
    const fs = require("fs");
    const ledgerPath = process.argv[1];
    const rendererPath = process.argv[2];
    const mdPath = process.argv[3];
    const rendererSrc = fs.readFileSync(rendererPath, "utf8");
    const m = rendererSrc.match(/CLOSED = new Set\(\[([^\]]*)\]\)/);
    if (!m) {
      console.error("FAIL: não encontrei CLOSED = new Set([...]) em ledger-render.mjs — o contrato lido mudou de forma, ajuste o gate");
      process.exit(1);
    }
    const closed = m[1]
      .split(",")
      .map((s) => s.trim().replace(/^[\x27"]|[\x27"]$/g, ""))
      .filter(Boolean);
    if (!closed.length) {
      console.error("FAIL: CLOSED lido de ledger-render.mjs veio vazio — extração quebrada, não um estado real do renderizador");
      process.exit(1);
    }
    console.log(`-- estados fechados (lidos de ledger-render.mjs): ${closed.join(", ")} — uma entrada é ativa quando seu status não está neste conjunto`);
    const data = JSON.parse(fs.readFileSync(ledgerPath, "utf8"));
    const entries = Array.isArray(data.entries) ? data.entries : [];
    const jsonActive = entries.filter((e) => !closed.includes(e.status)).length;
    const md = fs.readFileSync(mdPath, "utf8");
    const mm = md.match(/\*\*([0-9]+) (?:item ativo|itens ativos)\*\*/);
    if (!mm) {
      console.error("FAIL: não encontrei a linha de resumo \"**N itens ativos**\" em LEDGER.md");
      process.exit(1);
    }
    const mdActive = parseInt(mm[1], 10);
    if (mdActive !== jsonActive) {
      console.error(`FAIL: LEDGER.md declara ${mdActive} ativo(s) e ledger.json tem ${jsonActive}`);
      process.exit(1);
    }
    console.log(`OK LEDGER.md e ledger.json concordam em ${jsonActive} ativo(s)`);
  ' "$ledger" "$renderer" "$md"
}

echo "[1] conformidade com o schema — ledger real do projeto (universo declarado, nunca percentual sem ele)"
set +e
out1="$(_check_schema "$LEDGER" 2>&1)"; rc1=$?
set -e
echo "$out1"
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: o ledger real reprova contra o schema"; exit 1; }
echo "OK [1]"

echo "[2] guarda de piso anti-vacuidade — universo < 50 reprova com mensagem própria (não com a do schema)"
FIX2="$T/fixture-piso.json"
node -e '
  const fs = require("fs");
  const entries = [];
  for (let i = 1; i <= 10; i++) {
    const id = `LDG-${String(i).padStart(4, "0")}`;
    entries.push({
      id, type: "known-bug", title: "fixture de piso", status: "open",
      source: { origin: "manual", ref: null },
      created_at: "2026-01-01T00:00:00-03:00", dedup_key: `manual:${id}`,
    });
  }
  fs.writeFileSync(process.argv[1], JSON.stringify({ entries }, null, 2));
' "$FIX2"
set +e
out2="$(_check_schema "$FIX2" 2>&1)"; rc2=$?
set -e
[ "$rc2" -ne 0 ] || { echo "FAIL [2]: fixture com 10 entradas (< piso de 50), todas conformes, deveria reprovar pelo piso — got rc=0: $out2"; exit 1; }
grep -qi "piso" <<<"$out2" || { echo "FAIL [2]: mensagem não menciona o piso — got: $out2"; exit 1; }
grep -q -- "-- universo: 10 entrada(s) examinada(s); 0 reprovando" <<<"$out2" || { echo "FAIL [2]: esperava 0 reprovando contra o schema no fixture (o piso é o único motivo da reprovação) — got: $out2"; exit 1; }
echo "OK [2] — $(grep -i piso <<<"$out2")"

echo "[3] acordo entre os dois leitores — LEDGER.md vs ledger.json (estados ativos lidos do renderizador)"
set +e
out3="$(_check_agreement "$LEDGER" "$RENDERER" "$LEDGER_MD" 2>&1)"; rc3=$?
set -e
echo "$out3"
grep -q -- "-- estados fechados (lidos de ledger-render.mjs):" <<<"$out3" || { echo "FAIL [3]: cabeçalho não imprimiu o conjunto lido de ledger-render.mjs"; exit 1; }
[ "$rc3" -eq 0 ] || { echo "FAIL [3]: LEDGER.md e ledger.json divergem na contagem de itens ativos"; exit 1; }
echo "OK [3]"

echo "[4] prova de mutação — controle, mutação, restauração por nova cópia (não edição inversa), recontrole"
CTRL="$T/ledger-copia.json"
cp "$LEDGER" "$CTRL"
set +e
out4a="$(_check_schema "$CTRL" 2>&1)"; rc4a=$?
set -e
[ "$rc4a" -eq 0 ] || { echo "FAIL [4] controle: cópia do ledger real já reprova antes de qualquer mutação — $out4a"; exit 1; }
grep -q "; 0 reprovando" <<<"$out4a" || { echo "FAIL [4] controle: esperava '0 reprovando' — got: $out4a"; exit 1; }
echo "OK [4] controle — $(grep -- "-- universo" <<<"$out4a")"

mutated_id="$(node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const d = JSON.parse(fs.readFileSync(p, "utf8"));
  const e = d.entries.find((x) => x.type === "tech-debt");
  if (!e) { console.error("nenhuma entrada tech-debt disponível para mutar"); process.exit(1); }
  e.type = "debt";
  fs.writeFileSync(p, JSON.stringify(d, null, 2));
  console.log(e.id);
' "$CTRL")"
set +e
out4b="$(_check_schema "$CTRL" 2>&1)"; rc4b=$?
set -e
[ "$rc4b" -ne 0 ] || { echo "FAIL [4] mutação: type='debt' em $mutated_id não fez a checagem reprovar"; exit 1; }
grep -q "; 1 reprovando" <<<"$out4b" || { echo "FAIL [4] mutação: esperava '1 reprovando' — got: $out4b"; exit 1; }
grep -q "$mutated_id" <<<"$out4b" || { echo "FAIL [4] mutação: mensagem não nomeia $mutated_id — got: $out4b"; exit 1; }
echo "OK [4] mutação — reprovou nomeando $mutated_id (1 reprovando)"

# Restauração: NOVA cópia a partir do $LEDGER original, que em NENHUM momento deste gate foi
# aberto para escrita — só $CTRL (a cópia) foi mutado. Descartar $CTRL e copiar de novo é
# equivalente em segurança a `git checkout -- <arquivo>` sobre a cópia: não há edição inversa
# porque não há dano a desfazer na fonte, que nunca saiu do disco intocada.
cp "$LEDGER" "$CTRL"
set +e
out4c="$(_check_schema "$CTRL" 2>&1)"; rc4c=$?
set -e
[ "$rc4c" -eq 0 ] || { echo "FAIL [4] recontrole: nova cópia do original deveria voltar a passar — $out4c"; exit 1; }
grep -q "; 0 reprovando" <<<"$out4c" || { echo "FAIL [4] recontrole: esperava '0 reprovando' — got: $out4c"; exit 1; }
echo "OK [4] recontrole — nova cópia do original (nunca escrito) volta a 0 reprovando"

echo "TODOS OS CENÁRIOS OK — w202-ledger-schema-conformance-gate"
