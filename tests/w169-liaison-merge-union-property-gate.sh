#!/usr/bin/env bash
# Gate W169 — teste de PROPRIEDADE do merge=union do liaison (issue #80): CONSERVAÇÃO.
#
# A propriedade: para qualquer par de conjuntos de mensagens publicados dos dois lados de um
# merge, NENHUMA mensagem publicada em qualquer lado pode desaparecer do resultado. É essa
# assimetria que torna a troca de `--theirs`/`--ours` por `merge=union` boa — o modo de falha do
# union é SEMPRE duplicação (detectável, e é o que check-liaison-log-integrity.sh mede), NUNCA
# perda (silenciosa e irrecuperável).
#
# Gerador cobre as quatro formas exigidas — disjuntos, sobrepostos, um contido no outro, vazios —
# mais o cenário 5 medido na issue (duas mensagens COMUNS com ordem relativa invertida nos dois
# lados, sobrepondo-se): esse é o único que produz duplicata, e o teste confirma que mesmo ali
# nada some. Determinístico (sem relógio de parede, sem aleatoriedade): cada trial é um conjunto
# fixo, para não trocar defeito real por contenção de máquina.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w169.XXXXXX)"
trap 'rm -rf "$T"' EXIT

TARGET_REL=".forge/liaison/contracts-fare/log/axis-go-cloud.jsonl"

TOTAL=0
DUP_TRIALS=0

# run_trial <nome> <base-linhas-separadas-por-espaco> <esquerda-final-apos-base> <direita-final-apos-base>
# As "linhas finais" são o conteúdo COMPLETO do arquivo em cada lado (base + o que cada lado
# publicou) — é como o append-only realmente funciona: cada lado reescreve o arquivo inteiro do
# próprio remetente a cada `send`.
run_trial() {
  local nome="$1" base="$2" left="$3" right="$4"
  TOTAL=$((TOTAL + 1))
  local dir="$T/trial-$TOTAL"
  mkdir -p "$dir/$(dirname "$TARGET_REL")"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@test
  git -C "$dir" config user.name t
  git -C "$dir" config commit.gpgsign false
  echo ".forge/liaison/*/log/*.jsonl merge=union" > "$dir/.gitattributes"
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -qm init >/dev/null

  # shellcheck disable=SC2086
  { for tok in $base; do printf '%s\n' "$tok"; done; } > "$dir/$TARGET_REL"
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -qm base >/dev/null 2>&1 || true   # base vazia = nada a commitar, ok

  git -C "$dir" branch feature >/dev/null

  # shellcheck disable=SC2086
  { for tok in $left; do printf '%s\n' "$tok"; done; } > "$dir/$TARGET_REL"
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -qm left >/dev/null 2>&1 || true

  git -C "$dir" checkout -q feature
  # shellcheck disable=SC2086
  { for tok in $right; do printf '%s\n' "$tok"; done; } > "$dir/$TARGET_REL"
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -qm right >/dev/null 2>&1 || true

  git -C "$dir" checkout -q main
  set +e
  merge_out="$(git -C "$dir" merge feature --no-edit 2>&1)"; merge_rc=$?
  set -e
  [ "$merge_rc" -eq 0 ] || { echo "FAIL [$nome]: merge reprovou (rc=$merge_rc) — union deveria resolver sozinho: $merge_out"; exit 1; }
  ! grep -q '^<<<<<<<' "$dir/$TARGET_REL" 2>/dev/null \
    || { echo "FAIL [$nome]: marcador de conflito sobrou no arquivo — union não resolveu"; exit 1; }

  # CONSERVAÇÃO: todo token publicado por QUALQUER lado (a versão FINAL dele, base+próprio) tem
  # de aparecer pelo menos uma vez no resultado. Comparado via node para não depender de grep -F
  # por token multi-linha nenhum (tokens aqui são de uma linha, mas o padrão é o mesmo do check
  # real, que faz o mesmo raciocínio sobre msg_id via JSON.parse).
  local missing
  missing="$(node -e '
    const fs = require("fs");
    const [file, leftRaw, rightRaw] = process.argv.slice(1);
    const merged = new Set(fs.readFileSync(file, "utf8").split("\n").filter((l) => l.trim()));
    const want = new Set([...leftRaw.split(" ").filter(Boolean), ...rightRaw.split(" ").filter(Boolean)]);
    const missing = [...want].filter((t) => !merged.has(t));
    process.stdout.write(missing.join(","));
  ' "$dir/$TARGET_REL" "$left" "$right")"
  [ -z "$missing" ] || { echo "FAIL [$nome]: CONSERVAÇÃO VIOLADA — mensagem(ns) publicada(s) desapareceram do merge: $missing"; exit 1; }

  local n_lines n_distinct
  n_lines="$(grep -c . "$dir/$TARGET_REL" || true)"
  n_distinct="$(sort -u "$dir/$TARGET_REL" | grep -c . || true)"
  if [ "$n_lines" != "$n_distinct" ]; then
    DUP_TRIALS=$((DUP_TRIALS + 1))
    echo "  [$nome] duplicata detectada como esperado: $n_lines linha(s), $n_distinct distinta(s) — e a conservação MESMO ASSIM se mantém (nada perdido)"
  fi
  echo "OK [$nome] ($n_lines linha(s), $n_distinct distinta(s))"
}

echo "== forma 1: DISJUNTOS (nenhuma mensagem em comum entre os lados) =="
run_trial "disjoint/sem-base"      ""              "L1 L2 L3"         "R1 R2"
run_trial "disjoint/com-base"      "B1 B2"         "B1 B2 L1 L2 L3"   "B1 B2 R1"
run_trial "disjoint/so-um-lado"    "B1"            "B1 L1 L2"         "B1"

echo "== forma 2: UM CONTIDO NO OUTRO (o conjunto de um lado é subconjunto do outro) =="
# Espelha o par medido na issue: o PR era subconjunto do tronco porque o sync já o alcançara.
run_trial "subset/direita-em-esquerda" "B1"        "B1 X1 X2 X3 X4"   "B1 X1 X2"
run_trial "subset/esquerda-em-direita" "B1 B2"     "B1 B2 X1"         "B1 B2 X1 X2 X3"

echo "== forma 3: SOBREPOSTOS (interseção não vazia, mas nenhum lado contém o outro) =="
run_trial "overlap/parcial"        "B1"            "B1 X1 X2 Y1"      "B1 X1 X2 Z1"
run_trial "overlap/parcial-2"      ""               "X1 Y1 Y2"         "X1 Z1"

echo "== forma 4: VAZIOS (um lado ou os dois não publicam nada de novo) =="
run_trial "empty/direita"          "B1 B2"         "B1 B2 L1"         "B1 B2"
run_trial "empty/esquerda"         "B1"            "B1"               "B1 R1 R2"
run_trial "empty/ambos"            "B1 B2 B3"      "B1 B2 B3"         "B1 B2 B3"
run_trial "empty/canal-novo"       ""               ""                 ""

echo "== forma 5 (medida na issue): DUAS COMUNS com ordem relativa invertida, SOBREPONDO-SE =="
# base de 10, um lado troca 4/5, o outro troca 5/6 — a região trocada SE SOBREPÕE (compartilham a
# posição 5). É o único caso, entre os cinco medidos na issue, que duplica.
run_trial "reorder-overlap/issue"  "B1 B2 B3 B4 B5 B6 B7 B8 B9 B10" \
                                    "B1 B2 B3 B5 B4 B6 B7 B8 B9 B10" \
                                    "B1 B2 B3 B4 B6 B5 B7 B8 B9 B10"

echo ""
echo "== controle: a MESMA reordenação, mas DISTANTE (sem sobreposição), NÃO duplica =="
# A correção que a própria issue registra: trocas distantes (100/200 de um lado, 150/250 do
# outro) o git resolve cada hunk independentemente. Aqui, em miniatura: troca 2/3 vs troca 8/9 —
# nenhuma posição compartilhada.
run_trial "reorder-distante/controle" "B1 B2 B3 B4 B5 B6 B7 B8 B9 B10" \
                                       "B1 B3 B2 B4 B5 B6 B7 B8 B9 B10" \
                                       "B1 B2 B3 B4 B5 B6 B7 B9 B8 B10"

echo ""
echo "== propriedade confirmada: $TOTAL/$TOTAL trials preservaram toda mensagem publicada =="
echo "   ($DUP_TRIALS trial(s) produziram duplicata — sempre o modo de falha esperado, nunca perda)"
[ "$DUP_TRIALS" -ge 1 ] || { echo "FAIL: nenhum trial produziu duplicata — o gerador não está exercitando o cenário 5, e o teste de propriedade fica raso"; exit 1; }
[ "$DUP_TRIALS" -lt "$TOTAL" ] || { echo "FAIL: TODO trial duplicou — o gerador não cobre os casos limpos, e o teste não distingue nada"; exit 1; }

echo "PASS w169-liaison-merge-union-property-gate"
