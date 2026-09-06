#!/usr/bin/env bash
# Gate W203 — o renderizador do ledger para de descartar em silêncio e passa a somar o resumo
# sobre o arquivo inteiro (LDG-0170).
#
# POR QUE ESTE GATE EXISTE. template/.forge/scripts/lib/ledger-render.mjs fixa SECTIONS nos cinco
# tipos válidos do schema e, antes desta mudança, "for (const e of entries) if (byType[e.type])
# byType[e.type].push(e)" descartava em silêncio toda entrada cujo type não batesse com um deles —
# sem contador, sem aviso, sem vestígio na saída. totalActive somava só sobre as seções conhecidas,
# então o resumo declarava menos itens ativos do que o ledger.json de fato tinha (era a mesma classe
# de defeito que o W202 persegue no par schema↔renderer, agora dentro do próprio renderer: duas
# leituras do mesmo arquivo discordando em silêncio). Este gate é hermético: nunca lê nem escreve
# .forge/ledger/ledger.json real — todas as fixtures vivem em $T.
#
#   [1] controle positivo — fixture com 3 entradas ativas, todas de type válido: o resumo declara
#       3 e os 3 ids aparecem no markdown gerado. Sem este cenário, [2] mediria o próprio engano.
#   [2] a propriedade — mesma fixture mais 2 ativas de type fora do enum (debt, bug — os mesmos
#       tipos que este repositório carregava): o resumo tem de declarar 5, e os 2 ids têm de
#       aparecer no markdown, dentro do balde "### Fora do enum do schema".
#   [3] balde vazio não aparece, com contador de controle — sobre a fixture de [1] o heading não
#       pode existir; o MESMO grep aplicado à saída de [2] tem de achar o heading (senão o
#       cenário reprova com mensagem própria, porque um grep que não enxerga nada satisfaz
#       trivialmente o "não apareceu").
#   [4] prova de mutação sobre o arquivo RASTREADO ledger-render.mjs: (a) controle — roda [2] e vê
#       passar; (b) mutação — remove o balde do renderizador e vê [2] reprovar acusando resumo 3
#       contra fixture 5; (c) recontrole — `git checkout --`, nunca edição inversa, e vê [2] passar
#       de novo.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }

RENDERER="$WS/template/.forge/scripts/lib/ledger-render.mjs"
[ -f "$RENDERER" ] || { echo "FAIL: arquivo esperado ausente: $RENDERER"; exit 1; }

T="$(mktemp -d /tmp/forge-w203.XXXXXX)"
trap 'rm -rf "$T"' EXIT

TPL="$T/LEDGER.tpl.md"
cat >"$TPL" <<'EOF'
# LEDGER — fixture

{{SUMMARY}}

## Roadmap

{{SECTION_ROADMAP}}

## Ideias de feature

{{SECTION_FEATURE_IDEA}}

## Dívida técnica

{{SECTION_TECH_DEBT}}

## Bugs conhecidos

{{SECTION_KNOWN_BUG}}

## Follow-ups

{{SECTION_FOLLOW_UP}}

## Notas

<!-- FORGE:NARRATIVE:START -->
_(fixture)_
<!-- FORGE:NARRATIVE:END -->
EOF

# _mk_fixture_3 <path> — 3 entradas ativas, todas de type válido (o controle positivo de [1]).
_mk_fixture_3() {
  local path="$1"
  node -e '
    const fs = require("fs");
    const entries = [
      { id: "LDG-9001", type: "tech-debt", title: "fixture ativa 1", status: "open",
        source: { origin: "manual", ref: null }, created_at: "2026-01-01T00:00:00-03:00", dedup_key: "manual:LDG-9001" },
      { id: "LDG-9002", type: "known-bug", title: "fixture ativa 2", status: "open",
        source: { origin: "manual", ref: null }, created_at: "2026-01-01T00:00:00-03:00", dedup_key: "manual:LDG-9002" },
      { id: "LDG-9003", type: "follow-up", title: "fixture ativa 3", status: "in-progress",
        source: { origin: "manual", ref: null }, created_at: "2026-01-01T00:00:00-03:00", dedup_key: "manual:LDG-9003" },
    ];
    fs.writeFileSync(process.argv[1], JSON.stringify({ entries }, null, 2));
  ' "$path"
}

# _mk_fixture_5 <path> — a fixture de [1] mais 2 ativas de type fora do enum (debt, bug).
_mk_fixture_5() {
  local path="$1"
  node -e '
    const fs = require("fs");
    const entries = [
      { id: "LDG-9001", type: "tech-debt", title: "fixture ativa 1", status: "open",
        source: { origin: "manual", ref: null }, created_at: "2026-01-01T00:00:00-03:00", dedup_key: "manual:LDG-9001" },
      { id: "LDG-9002", type: "known-bug", title: "fixture ativa 2", status: "open",
        source: { origin: "manual", ref: null }, created_at: "2026-01-01T00:00:00-03:00", dedup_key: "manual:LDG-9002" },
      { id: "LDG-9003", type: "follow-up", title: "fixture ativa 3", status: "in-progress",
        source: { origin: "manual", ref: null }, created_at: "2026-01-01T00:00:00-03:00", dedup_key: "manual:LDG-9003" },
      { id: "LDG-9004", type: "debt", title: "fixture fora do enum 1", status: "open",
        source: { origin: "manual", ref: null }, created_at: "2026-01-01T00:00:00-03:00", dedup_key: "manual:LDG-9004" },
      { id: "LDG-9005", type: "bug", title: "fixture fora do enum 2", status: "open",
        source: { origin: "manual", ref: null }, created_at: "2026-01-01T00:00:00-03:00", dedup_key: "manual:LDG-9005" },
    ];
    fs.writeFileSync(process.argv[1], JSON.stringify({ entries }, null, 2));
  ' "$path"
}

# _run_render <ledger.json> <out.md> — invoca o renderizador exatamente como ledger-ops.sh invoca
# (mesmas 4 env vars), sob teto de tempo, e imprime o conteúdo de out.md em caso de sucesso.
_run_render() {
  local ledger="$1" out="$2"
  perl -e 'alarm 20; exec @ARGV' -- env LEDGER_ROOT="$T" LEDGER_JSON="$ledger" LEDGER_TPL="$TPL" LEDGER_OUT="$out" \
    node "$RENDERER"
}

# _extract_n <markdown> — extrai o N da linha "**N item ativo**"/"**N itens ativos**"; vazio se a
# linha não existir.
_extract_n() {
  grep -oE '\*\*[0-9]+ (item ativo|itens ativos)\*\*' <<<"$1" | head -1 | grep -oE '[0-9]+'
}

# [1]-[3] acumulam falha em vez de sair no primeiro erro, para que uma reprovação em [2] não
# esconda a de [3] no mesmo run — vermelho observável precisa das duas linhas juntas.
FAILED=0

echo "[1] controle positivo — 3 ativas válidas, resumo declara 3, os 3 ids aparecem"
J1="$T/ledger-1.json"; OUT1="$T/LEDGER-1.md"
_mk_fixture_3 "$J1"
_run_render "$J1" "$OUT1"
md1="$(cat "$OUT1")"
n1="$(_extract_n "$md1")"
if [ "$n1" != "3" ]; then
  echo "FAIL [1]: o resumo declara ${n1:-(nenhum)} item(ns) ativo(s) e a fixture tem 3"; FAILED=1
else
  ok1=1
  for id in LDG-9001 LDG-9002 LDG-9003; do
    grep -q "$id" <<<"$md1" || { echo "FAIL [1]: id $id não apareceu no markdown"; ok1=0; FAILED=1; }
  done
  [ "$ok1" -eq 1 ] && echo "OK [1]"
fi

echo "[2] a propriedade — 3 válidas + 2 fora do enum (debt, bug), resumo declara 5, os 2 ids aparecem"
J2="$T/ledger-2.json"; OUT2="$T/LEDGER-2.md"
_mk_fixture_5 "$J2"
_run_render "$J2" "$OUT2"
md2="$(cat "$OUT2")"
n2="$(_extract_n "$md2")"
if [ "$n2" != "5" ]; then
  echo "FAIL [2]: o resumo declara ${n2:-(nenhum)} item(ns) ativo(s) e a fixture tem 5 — 2 entrada(s) de type fora do enum foram descartadas em silêncio"; FAILED=1
else
  ok2=1
  for id in LDG-9004 LDG-9005; do
    grep -q "$id" <<<"$md2" || { echo "FAIL [2]: id $id (fora do enum) não apareceu no markdown"; ok2=0; FAILED=1; }
  done
  [ "$ok2" -eq 1 ] && echo "OK [2]"
fi

echo "[3] balde vazio não aparece (com contador de controle sobre a saída de [2])"
if grep -q '### Fora do enum do schema' <<<"$md1"; then
  echo "FAIL [3]: o heading do balde apareceu em [1], que não tem entrada fora do enum"; FAILED=1
elif ! grep -q '### Fora do enum do schema' <<<"$md2"; then
  echo "FAIL [3]: o heading do balde não apareceu na saída de [2] — o contador de controle da asserção negativa deu zero"; FAILED=1
else
  echo "OK [3]"
fi

if [ "$FAILED" -eq 1 ]; then
  echo "FALHOU — [1]-[3] reprovaram antes da prova de mutação; ver mensagens acima"
  exit 1
fi

echo "[4] prova de mutação — controle, mutação, git checkout --, recontrole"
set +e
out4a="$(_run_render "$J2" "$T/LEDGER-4a.md" 2>&1)"; rc4a=$?
set -e
[ "$rc4a" -eq 0 ] || { echo "FAIL [4] controle: o render de [2] deveria rodar sem erro — $out4a"; exit 1; }
n4a="$(_extract_n "$(cat "$T/LEDGER-4a.md")")"
[ "$n4a" = "5" ] || { echo "FAIL [4] controle: esperava 5 itens ativos antes de mutar — got: ${n4a:-(nenhum)}"; exit 1; }
echo "OK [4] controle — 5 itens ativos antes de mutar"

node -e '
  const fs = require("fs");
  const p = process.argv[1];
  let src = fs.readFileSync(p, "utf8");
  const startMarker = "// BALDE:START";
  const endMarker = "// BALDE:END";
  const start = src.indexOf(startMarker);
  const endIdx = src.indexOf(endMarker);
  if (start < 0 || endIdx < 0 || endIdx <= start) {
    console.error("marcadores do balde (// BALDE:START ... // BALDE:END) não encontrados em ledger-render.mjs — ajuste o gate");
    process.exit(1);
  }
  const end = endIdx + endMarker.length;
  src = src.slice(0, start) + src.slice(end);
  fs.writeFileSync(p, src);
' "$RENDERER"
set +e
out4b="$(_run_render "$J2" "$T/LEDGER-4b.md" 2>&1)"; rc4b=$?
set -e
if [ "$rc4b" -eq 0 ]; then
  n4b="$(_extract_n "$(cat "$T/LEDGER-4b.md" 2>/dev/null || echo '')")"
  if [ "$n4b" = "3" ]; then
    echo "OK [4] mutação — resumo caiu para 3 itens ativos contra fixture de 5 (balde removido)"
  else
    git checkout -- "$RENDERER"
    echo "FAIL [4] mutação: esperava resumo com 3 itens ativos (balde removido, entradas fora do enum descartadas) — got: ${n4b:-(nenhum)}"
    exit 1
  fi
else
  echo "OK [4] mutação — remover o balde quebrou a execução do renderizador (rc=$rc4b): $out4b"
fi

git checkout -- "$RENDERER"

set +e
out4c="$(_run_render "$J2" "$T/LEDGER-4c.md" 2>&1)"; rc4c=$?
set -e
[ "$rc4c" -eq 0 ] || { echo "FAIL [4] recontrole: após git checkout -- o render de [2] voltou a falhar — $out4c"; exit 1; }
n4c="$(_extract_n "$(cat "$T/LEDGER-4c.md")")"
[ "$n4c" = "5" ] || { echo "FAIL [4] recontrole: após git checkout -- esperava 5 itens ativos de novo — got: ${n4c:-(nenhum)}"; exit 1; }
echo "OK [4] recontrole — git checkout -- restaurou 5 itens ativos"

echo "TODOS OS CENÁRIOS OK — w203-ledger-render-bucket-gate"
