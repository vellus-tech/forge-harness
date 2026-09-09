#!/usr/bin/env bash
# Gate W205 — `quick_plan` passa a ter efeito sobre a fase de design (LDG-0172).
#
# POR QUE ESTE GATE EXISTE. Quatro superfícies entregues ao adotante davam três respostas
# incompatíveis sobre se declarar `quick_plan.skipped_phases: [design]` no manifest dispensa a
# fase de design a partir de `tasks-ready`: (i) `lib/validate-spec.mjs` reprovava com "design.md
# missing" sem consultar `quick_plan` em momento algum; (ii) `spec-transition.sh` concedia a rota
# lateral requirements-ready -> tasks-ready só para `type: bugfix`, com o próprio comentário do
# arquivo dizendo por escrito que NÃO generalizava para `quick_plan` porque o validador ainda não
# honrava; (iii) `commands/specs/design.md` dizia ao adotante que o mecanismo não existe, citando
# `LDG-0035` — referência ERRADA (esse item é sobre outro assunto, fechado pelo gate w173); (iv)
# o CHANGELOG publicado da 0.7.0 afirmava o contrário do item (i). Este gate confere que as quatro
# concordam agora, com o mesmo idioma que já honra `quick_plan` para story-sharding
# (`skipsStorySharding` em validate-spec.mjs) — nenhum segundo dialeto para a mesma pergunta.
#
# O QUE ESTE GATE NÃO COBRA, deliberado: não estende a dispensa a nenhuma outra fase declarável em
# `skipped_phases` (requirements/analyze/story-sharding seguem exatamente como estavam — cobertos
# por outros gates); não toca o gate HITL `design_reviewed` nem o manifesto de gates.
#
#   [1] CONTROLE POSITIVO: feature scale 2, tasks-ready, SEM design.md e SEM quick_plan — REPROVA
#       com "design.md missing". Sem este controle, os cenários [2]/[3] seriam satisfeitos por
#       vacuidade (a fixture poderia estar quebrada de um jeito que sempre passa).
#   [2] o mesmo change com quick_plan declarando "design" em block style (`- design`) e
#       justification de 8+ caracteres — PASSA.
#   [3] o mesmo em flow style (`[design]`) — PASSA (regressão aqui é do fechamento do LDG-0033 em
#       yaml-lite.mjs, não desta tarefa — o gate para e reporta em vez de contornar).
#   [4] quick_plan.enabled: true com "design" em skipped_phases mas SEM justification — REPROVA,
#       pelo bloco já existente de validate-spec.mjs (linhas 95-99), independente do guard de
#       design.md.
#   [5] a rota lateral executável: type feature, scale 2, requirements-ready -> tasks-ready via
#       spec-transition.sh com quick_plan declarando "design" — AUTORIZADA, manifest fica em
#       tasks-ready.
#   [6] PROVA DE MUTAÇÃO sobre o arquivo RASTREADO real: (a) controle — roda [2] e vê passar;
#       (b) mutação — remove o `&& !skipsDesign` da condição do guard e vê [2] reprovar com
#       "design.md missing"; (c) recontrole — restauração por CÓPIA, NUNCA edição inversa, e vê [2]
#       passar de novo.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S_REAL="$WS/template/.forge/scripts"
VALIDATE_REAL="$S_REAL/lib/validate-spec.mjs"
[ -f "$VALIDATE_REAL" ] || { echo "FAIL: arquivo esperado ausente: $VALIDATE_REAL"; exit 1; }

T="$(mktemp -d /tmp/forge-w205.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/arvore-rastreada.sh"
ARVORE_ANTES="$(arvore_retrato "$WS")"

# Conversão do LDG-0179: as fixtures rodavam contra os scripts RASTREADOS, e o cenário [6] mutava o
# `validate-spec.mjs` real, restaurando com `git checkout --` sob a guarda `MUTATED` — que sob
# `SIGKILL` não roda, e que apaga trabalho não commitado do operador quando roda. Agora `template/
# .forge` inteiro é copiado para `$T` e `$S` aponta para a cópia: copiar só `scripts/` NÃO basta,
# porque o `spec-new.sh` falha com "Can't open .../tpl/templates/spec/proposal.md" — a árvore em
# volta é parte do sistema sob teste. É o que `w194`, `w201` e `w211` já fazem.
#
# A prova de mutação continua valendo: o `validate-spec.mjs` da cópia é conferido byte a byte com o
# rastreado antes do uso, e o que se mede é a propriedade do CÓDIGO, não a do inode.
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"
VALIDATE_MJS="$S/lib/validate-spec.mjs"
VALIDATE_PRISTINE="$T/validate-spec.pristine.mjs"
cmp -s "$VALIDATE_REAL" "$VALIDATE_MJS" \
  || { echo "NÃO VERIFICADO: a cópia de validate-spec.mjs em \$T não bate byte a byte com o original"; exit 3; }
copia_conferida "$VALIDATE_REAL" "$VALIDATE_PRISTINE" \
  || { echo "NÃO VERIFICADO: a cópia de referência de validate-spec.mjs em \$T não bate byte a byte com o original"; exit 3; }

# _mk_change <id> — spec-new.sh feature/scale 2 real, sob FORGE_ROOT="$T". Devolve o path do change.
_mk_change() {
  local id="$1" out
  out="$(FORGE_ROOT="$T" bash "$S/spec-new.sh" "$id" --type feature --scale 2 2>&1)"
  if [ "$?" -ne 0 ] || ! grep -q "^OK " <<<"$out"; then
    echo "FAIL: spec-new.sh não conseguiu criar a fixture '$id': $out" >&2
    return 1
  fi
  echo "$T/.forge/specs/active/$id"
}

# _set_status <dir> <status>
_set_status() { perl -pi -e "s/^status: .*/status: $2/" "$1/manifest.yaml"; }

# _set_quick_plan <dir> <style> <justification-or-empty> — style: block | flow
_set_quick_plan() {
  local dir="$1" style="$2" just="$3" sp_lines
  case "$style" in
    block) sp_lines='skipped_phases:\n    - design' ;;
    flow)  sp_lines='skipped_phases: [design]' ;;
    *) echo "FAIL: estilo de quick_plan desconhecido: $style" >&2; return 1 ;;
  esac
  perl -0777 -pi -e "s/quick_plan:\n  enabled: false\n  skipped_phases: \[\]\n  justification:\n/quick_plan:\n  enabled: true\n  $sp_lines\n  justification: \"$just\"\n/" "$dir/manifest.yaml"
}

_validate() { FORGE_ROOT="$T" bash "$S/validate-spec.sh" --path "$1" 2>&1; }

echo "[1] controle positivo — feature scale 2, tasks-ready, sem design.md e sem quick_plan REPROVA"
D1="$(_mk_change c1-controle)" || exit 1
rm -f "$D1/design.md"
_set_status "$D1" tasks-ready
OUT1="$(_validate "$D1")"
if grep -q '^OK ' <<<"$OUT1"; then
  echo "FAIL [1]: esperava REPROVAR (fixture inválida — sem controle positivo, [2]/[3] não provariam nada). Saída: $OUT1"
  exit 1
fi
if ! grep -q 'design.md missing' <<<"$OUT1"; then
  echo "FAIL [1]: reprovou mas sem 'design.md missing' na mensagem: $OUT1"
  exit 1
fi
echo "OK [1] — $OUT1"

echo "[2] quick_plan em block style ('- design') com justification de 8+ chars PASSA"
D2="$(_mk_change c2-block)" || exit 1
rm -f "$D2/design.md"
_set_quick_plan "$D2" block "pulo intencional de design para exercitar o gate w205"
_set_status "$D2" tasks-ready
OUT2="$(_validate "$D2")"
if ! grep -q '^OK ' <<<"$OUT2"; then
  echo "FAIL [2]: com quick_plan declarando design em block style, o validador ainda reprovou — $OUT2"
  exit 1
fi
echo "OK [2] — $OUT2"

echo "[3] quick_plan em flow style ('[design]') com justification de 8+ chars PASSA"
D3="$(_mk_change c3-flow)" || exit 1
rm -f "$D3/design.md"
_set_quick_plan "$D3" flow "pulo intencional de design para exercitar o gate w205"
_set_status "$D3" tasks-ready
OUT3="$(_validate "$D3")"
if ! grep -q '^OK ' <<<"$OUT3"; then
  echo "FAIL [3]: com quick_plan declarando design em flow style, o validador ainda reprovou (se yaml-lite.mjs não parseia flow style de array, é regressão do LDG-0033 — pare e reporte, não contorne) — $OUT3"
  exit 1
fi
echo "OK [3] — $OUT3"

echo "[4] quick_plan.enabled com design em skipped_phases mas SEM justification REPROVA"
D4="$(_mk_change c4-sem-justification)" || exit 1
rm -f "$D4/design.md"
_set_quick_plan "$D4" block ""
_set_status "$D4" tasks-ready
OUT4="$(_validate "$D4")"
if grep -q '^OK ' <<<"$OUT4"; then
  echo "FAIL [4]: esperava REPROVAR por justification ausente — $OUT4"
  exit 1
fi
if ! grep -q 'justification' <<<"$OUT4"; then
  echo "FAIL [4]: reprovou mas sem menção a 'justification' na mensagem: $OUT4"
  exit 1
fi
echo "OK [4] — $OUT4"

echo "[5] rota lateral executável — requirements-ready -> tasks-ready via spec-transition.sh"
D5="$(_mk_change c5-rota-lateral)" || exit 1
_set_quick_plan "$D5" block "pulo intencional de design para exercitar o gate w205"
OUT5A="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" c5-rota-lateral requirements-ready 2>&1)"
if ! grep -q '^OK c5-rota-lateral: proposed -> requirements-ready$' <<<"$OUT5A"; then
  echo "FAIL [5]: transição proposed -> requirements-ready falhou: $OUT5A"
  exit 1
fi
rm -f "$D5/design.md"
OUT5B="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" c5-rota-lateral tasks-ready 2>&1)"
if ! grep -q '^OK c5-rota-lateral: requirements-ready -> tasks-ready$' <<<"$OUT5B"; then
  echo "FAIL [5]: rota lateral requirements-ready -> tasks-ready não foi autorizada para type:feature com quick_plan declarando design: $OUT5B"
  exit 1
fi
FINAL_STATUS="$(awk -F': ' '$1=="status"{print $2; exit}' "$D5/manifest.yaml")"
if [ "$FINAL_STATUS" != "tasks-ready" ]; then
  echo "FAIL [5]: manifest resultante não ficou em tasks-ready (status='$FINAL_STATUS')"
  exit 1
fi
echo "OK [5] — $OUT5B (manifest em '$FINAL_STATUS')"

echo "[6] prova de mutação — controle, mutação da CÓPIA, restauração por cópia, recontrole"
D6="$(_mk_change c6-mutacao)" || exit 1
rm -f "$D6/design.md"
_set_quick_plan "$D6" block "pulo intencional de design para exercitar o gate w205"
_set_status "$D6" tasks-ready

OUT6A="$(_validate "$D6")"
if ! grep -q '^OK ' <<<"$OUT6A"; then
  echo "FAIL [6] controle: esperava PASSAR antes da mutação — $OUT6A"
  exit 1
fi
echo "OK [6] controle — $OUT6A"

perl -pi -e "s/scale >= 2 && man\.type !== 'bugfix' && !has\('design\.md'\) && !skipsDesign\)/scale >= 2 \&\& man.type !== 'bugfix' \&\& !has('design.md'))/" "$VALIDATE_MJS"
if ! grep -q "man.type !== 'bugfix' && !has('design.md'))" "$VALIDATE_MJS"; then
  echo "FAIL [6] mutação: o perl não conseguiu remover '&& !skipsDesign' da condição do guard na CÓPIA — ajuste o padrão do gate"
  exit 1
fi
OUT6B="$(_validate "$D6")"
if grep -q '^OK ' <<<"$OUT6B"; then
  echo "FAIL [6] mutação: com '&& !skipsDesign' removido da condição, o cenário [2] continuou passando — a mutação não afetou a propriedade testada: $OUT6B"
  exit 1
fi
if ! grep -q 'design.md missing' <<<"$OUT6B"; then
  echo "FAIL [6] mutação: reprovou mas sem 'design.md missing' na mensagem: $OUT6B"
  exit 1
fi
echo "OK [6] mutação — $OUT6B"

cp "$VALIDATE_PRISTINE" "$VALIDATE_MJS"
cmp -s "$VALIDATE_MJS" "$VALIDATE_PRISTINE" \
  || { echo "FAIL [6] recontrole: a restauração por cópia não bateu byte a byte com a referência"; exit 1; }
OUT6C="$(_validate "$D6")"
if ! grep -q '^OK ' <<<"$OUT6C"; then
  echo "FAIL [6] recontrole: após a restauração por cópia o cenário [2] deveria voltar a passar — $OUT6C"
  exit 1
fi
echo "OK [6] recontrole — $OUT6C"

echo "TODOS OS CENÁRIOS OK — w205-quick-plan-design-skip-gate"

# Fecho da sentinela pelos TRÊS estados: rc 0 limpo, rc 1 acusação, rc 3 NÃO VERIFICADO. O idioma
# anterior (`arvore_confere ... || { echo "a árvore mudou"; exit 1; }`) colapsava rc 1 e rc 3 no mesmo
# `||` e imprimia, em árvore sem `.git`, a acusação FALSA de que a árvore rastreada mudou.
arvore_sentinela_fim "$WS" "$ARVORE_ANTES" "w205-quick-plan-design-skip" || exit $?
