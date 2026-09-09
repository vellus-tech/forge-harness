#!/usr/bin/env bash
# Gate W204 — o alocador de ordinais para de devolver 'w1' no layout de dogfood (LDG-0171).
#
# POR QUE ESTE GATE EXISTE. `gate-ordinal.sh:34` resolvia `ROOT="${FORGE_ROOT:-$(cd
# "$SCRIPT_DIR/../.." && pwd)}"`. No layout de dogfood o script mora em
# `template/.forge/scripts/`, e a subida de dois níveis para em `<repo>/template` — não a raiz do
# repositório. `$ROOT/tests` não existe ali, `TESTS_DIR` cai em
# `<repo>/template/.forge/scripts/tests` (também ausente) e `rel` vira `.forge/scripts/tests`, que
# não existe no tronco remoto: a cegueira local e a cegueira remota têm a MESMA causa. Medido:
# `env -u FORGE_ROOT bash template/.forge/scripts/gate-ordinal.sh next` devolvia `w1` com rc 0.
# Como a regra de operação deste repositório proíbe exportar `FORGE_ROOT`, o modo de invocação
# documentado e seguro era justamente o que devolvia lixo.
#
# A CORREÇÃO. `forge_worktree_root` (nova, em lib/forge-root.sh) resolve, nesta ordem: (1)
# $FORGE_ROOT explícito; (2) `git -C "$SCRIPT_DIR" rev-parse --show-toplevel`, ancorado em onde o
# SCRIPT mora — não no cwd de quem chama, e não `forge_main_root` (que resolveria para o TRONCO via
# --git-common-dir, examinando o `tests/` de outra branch, errado por construção para uma decisão
# que é POR BRANCH); (3) fallback para a subida `$SCRIPT_DIR/../..` de hoje, para instalação fora
# de git — preserva o comportamento correto no layout do adotante (cenário [3]).
#
# O QUE ESTE GATE NÃO COBRA, deliberado: o modo degradado sem tronco remoto continua devolvendo
# número com rc 0 (não vira rc 3) — mudar isso quebraria o repositório greenfield sem `origin` e
# forçaria reescrever o cenário [5] de w193-tree-derived-state-gate.sh, hoje verde. Este gate não
# toca w193; o contador de retrocompatibilidade dele é conferido à parte, fora deste arquivo.
#
#   [1] A PROPRIEDADE, sobre o repositório real: sem FORGE_ROOT e com FORGE_ROOT="$WS" devolvem a
#       MESMA primeira linha de stdout. Não fixa o valor esperado — cravar 'w206' envelheceria a
#       cada gate novo, a mesma classe de defeito que a tarefa do README corrige.
#   [2] CONTADOR DE CONTROLE POSITIVO: a primeira linha casa ^w[0-9]+$ e o ordinal é estritamente
#       maior que o máximo local medido em tests/w*-gate.sh (impresso). Sem isto, 'w1' e 'w1'
#       satisfariam [1] igualmente errados.
#   [3] LAYOUT INSTALADO NÃO REGRIDE, hermético: fixture com <fixture>/.forge/scripts/ (cópias de
#       gate-ordinal.sh, lib/forge-root.sh, lib/gate-universe.sh) e <fixture>/tests/ com w010 e
#       w011; git init + commit; `next` de dentro dela sem FORGE_ROOT devolve 'w12' (sem
#       zero-padding — `printf 'w%s\n' 12`, o mesmo formato de sempre) — a raiz resolvida foi a
#       fixture, não o repositório real que a hospeda.
#   [4] PROVA DE MUTAÇÃO sobre o arquivo RASTREADO real (o mesmo padrão de w203): (a) controle —
#       roda [1] e vê passar; (b) mutação — reverte a linha 34 de gate-ordinal.sh para a forma
#       antiga e vê [1] reprovar (as duas saídas divergem); (c) recontrole — `git checkout --`,
#       NUNCA edição inversa, e vê [1] passar de novo. A mutação cai sobre CÓPIA em $T, num
#       repositório-fixture com layout de dogfood — o rastreado nunca é tocado (LDG-0179).
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }

GATEORD="$WS/template/.forge/scripts/gate-ordinal.sh"
FORGEROOT_LIB="$WS/template/.forge/scripts/lib/forge-root.sh"
UNIVERSE_LIB="$WS/template/.forge/scripts/lib/gate-universe.sh"
for f in "$GATEORD" "$FORGEROOT_LIB" "$UNIVERSE_LIB"; do
  [ -f "$f" ] || { echo "FAIL: arquivo esperado ausente: $f"; exit 1; }
done

T="$(mktemp -d /tmp/forge-w204.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/arvore-rastreada.sh"
ARVORE_ANTES="$(arvore_retrato "$WS")"

# Conversão do LDG-0179: o cenário [4] mutava o `gate-ordinal.sh` RASTREADO e restaurava com
# `git checkout --` sob a guarda `MUTATED`. Sob `SIGKILL` nenhum trap roda e o alocador ficava
# mutado na árvore; e o `git checkout --` apaga trabalho não commitado do operador com o gate saindo
# verde. Agora a mutação cai sobre uma CÓPIA, num repositório-fixture em `$T` que reproduz o LAYOUT
# DE DOGFOOD (`template/.forge/scripts/…` + `tests/`) — e o layout importa: o que este gate mede é a
# RESOLUÇÃO DE RAIZ, então copiar só o arquivo não bastaria, a árvore em volta é parte do sistema
# sob teste. Medido, a prova sobre a cópia é mais nítida que a anterior: íntegro devolve w12 dos dois
# lados, mutado devolve w1 sem FORGE_ROOT contra w12 com FORGE_ROOT — e o w1 é literalmente o defeito
# que o LDG-0171 descreve no cabeçalho do alocador.

# _next_no_root — 'next' sem FORGE_ROOT, invocado do repositório real. Primeira linha de stdout.
_next_no_root() {
  ( cd "$WS" && env -u FORGE_ROOT bash "$GATEORD" next 2>/dev/null | head -1 )
}

# _next_with_root — 'next' com FORGE_ROOT="$WS" explícito.
_next_with_root() {
  ( cd "$WS" && FORGE_ROOT="$WS" bash "$GATEORD" next 2>/dev/null | head -1 )
}

# _measured_local_max — o mesmo critério que gate-ordinal.sh usa (número antes do primeiro '-' no
# nome do arquivo), aplicado a tests/w*-gate.sh da árvore real — nunca redigitado, recalculado.
_measured_local_max() {
  local max=0 f base ord n
  for f in "$WS"/tests/w[0-9]*-gate.sh; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    ord="${base#w}"; ord="${ord%%-*}"
    case "$ord" in ''|*[!0-9]*) continue ;; esac
    n=$((10#$ord))
    [ "$n" -gt "$max" ] && max="$n"
  done
  echo "$max"
}

echo "[1] a propriedade — sem FORGE_ROOT e com FORGE_ROOT devolvem o mesmo ordinal"
out_no="$(_next_no_root)"
out_yes="$(_next_with_root)"
if [ "$out_no" != "$out_yes" ]; then
  echo "FAIL [1]: sem FORGE_ROOT o alocador devolveu '$out_no' e com FORGE_ROOT devolveu '$out_yes' — a mesma pergunta, duas respostas, e a resposta do modo de invocação documentado é lixo"
  exit 1
fi
echo "OK [1] — ambos devolveram '$out_no'"

echo "[2] contador de controle positivo — ordinal casa \\^w[0-9]+\\\$ e é maior que o máximo local medido"
local_max="$(_measured_local_max)"
echo "-- universo: máximo ordinal local medido em tests/w*-gate.sh = w$local_max"
if [[ ! "$out_no" =~ ^w[0-9]+$ ]]; then
  echo "FAIL [2]: a primeira linha devolvida ('$out_no') não casa com ^w[0-9]+\$"
  exit 1
fi
ord_no="${out_no#w}"; ord_no=$((10#$ord_no))
if [ "$ord_no" -le "$local_max" ]; then
  echo "FAIL [2]: o ordinal devolvido ('$out_no') não é maior que o máximo local medido (w$local_max)"
  exit 1
fi
echo "OK [2] — '$out_no' > w$local_max"

echo "[3] layout instalado não regride — fixture hermética fora deste repositório"
FX="$T/fixture"
mkdir -p "$FX/.forge/scripts/lib" "$FX/tests"
cp "$GATEORD" "$FX/.forge/scripts/gate-ordinal.sh"
cp "$FORGEROOT_LIB" "$FX/.forge/scripts/lib/forge-root.sh"
cp "$UNIVERSE_LIB" "$FX/.forge/scripts/lib/gate-universe.sh"
chmod +x "$FX/.forge/scripts/gate-ordinal.sh"
cat > "$FX/tests/w010-alfa-gate.sh" <<'EOF'
#!/usr/bin/env bash
echo "OK fixture w010-alfa"
EOF
cat > "$FX/tests/w011-beta-gate.sh" <<'EOF'
#!/usr/bin/env bash
echo "OK fixture w011-beta"
EOF
chmod +x "$FX"/tests/*.sh
git -C "$FX" init -q
git -C "$FX" config user.email t@t
git -C "$FX" config user.name t
git -C "$FX" config commit.gpgsign false
( cd "$FX" && git add -A >/dev/null 2>&1 && git commit -qm fixture >/dev/null 2>&1 )
out_fx="$(cd "$FX" && env -u FORGE_ROOT bash .forge/scripts/gate-ordinal.sh next 2>/dev/null | head -1)"
if [ "$out_fx" != "w12" ]; then
  echo "FAIL [3]: fixture com w010/w011 deveria devolver 'w12' (raiz resolvida = a própria fixture, layout do adotante) — got '$out_fx'"
  exit 1
fi
echo "OK [3] — fixture devolveu '$out_fx'"

echo "[4] prova de mutação — controle, mutação da CÓPIA, restauração por cópia, recontrole"
DF="$T/dogfood"
mkdir -p "$DF/template/.forge/scripts/lib" "$DF/tests"
GATEORD_FX="$DF/template/.forge/scripts/gate-ordinal.sh"
GATEORD_PRISTINE="$T/gate-ordinal.pristine.sh"
copia_conferida "$GATEORD" "$GATEORD_FX" \
  || { echo "NÃO VERIFICADO: a cópia do alocador em \$T não bate byte a byte com o original"; exit 3; }
copia_conferida "$GATEORD" "$GATEORD_PRISTINE" \
  || { echo "NÃO VERIFICADO: a cópia de referência do alocador em \$T não bate byte a byte com o original"; exit 3; }
copia_conferida "$FORGEROOT_LIB" "$DF/template/.forge/scripts/lib/forge-root.sh" \
  || { echo "NÃO VERIFICADO: a cópia de forge-root.sh em \$T não bate byte a byte com o original"; exit 3; }
copia_conferida "$UNIVERSE_LIB" "$DF/template/.forge/scripts/lib/gate-universe.sh" \
  || { echo "NÃO VERIFICADO: a cópia de gate-universe.sh em \$T não bate byte a byte com o original"; exit 3; }
chmod +x "$GATEORD_FX"
cat > "$DF/tests/w010-alfa-gate.sh" <<'EOF'
#!/usr/bin/env bash
echo "OK fixture w010-alfa"
EOF
cat > "$DF/tests/w011-beta-gate.sh" <<'EOF'
#!/usr/bin/env bash
echo "OK fixture w011-beta"
EOF
chmod +x "$DF"/tests/*.sh
git -C "$DF" init -q
git -C "$DF" config user.email t@t
git -C "$DF" config user.name t
git -C "$DF" config commit.gpgsign false
( cd "$DF" && git add -A >/dev/null 2>&1 && git commit -qm dogfood >/dev/null 2>&1 )

# A invocação NÃO pode passar `--path`: `--path` é relativo ao cwd e curto-circuita justamente o
# ROOT que se quer medir — com `--path tests` os dois lados devolvem o mesmo ordinal e a mutação
# fica invisível. Isso foi medido, e é a armadilha deste sítio.
_fx_no_root()   { ( cd "$DF" && env -u FORGE_ROOT bash "$GATEORD_FX" next 2>/dev/null | head -1 ); }
_fx_with_root() { ( cd "$DF" && FORGE_ROOT="$DF" bash "$GATEORD_FX" next 2>/dev/null | head -1 ); }

out4a_no="$(_fx_no_root)"
out4a_yes="$(_fx_with_root)"
if [[ ! "$out4a_no" =~ ^w[0-9]+$ ]]; then
  echo "FAIL [4] controle: a cópia íntegra devolveu '$out4a_no', que não casa com ^w[0-9]+\$ — duas respostas vazias seriam 'iguais' por vacuidade"
  exit 1
fi
[ "$out4a_no" = "$out4a_yes" ] || { echo "FAIL [4] controle: '$out4a_no' != '$out4a_yes' antes de qualquer mutação"; exit 1; }
echo "OK [4] controle — cópia íntegra: '$out4a_no' == '$out4a_yes'"

sed -i.bak 's|ROOT="\${FORGE_ROOT:-\$(forge_worktree_root "\$SCRIPT_DIR")}"|ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." \&\& pwd)}"|' "$GATEORD_FX"
rm -f "$GATEORD_FX.bak"
if ! grep -q 'cd "\$SCRIPT_DIR/\.\./\.\." && pwd' "$GATEORD_FX"; then
  echo "FAIL [4] mutação: o sed não conseguiu reverter a resolução de raiz para a forma antiga na cópia — ajuste o padrão do gate"
  exit 1
fi
if cmp -s "$GATEORD_FX" "$GATEORD_PRISTINE"; then
  echo "FAIL [4] mutação: a mutação não alterou a cópia — a prova mediria o próprio engano"
  exit 1
fi
out4b_no="$(_fx_no_root)"
out4b_yes="$(_fx_with_root)"
if [ "$out4b_no" = "$out4b_yes" ]; then
  echo "FAIL [4] mutação: com a resolução de raiz revertida para a forma antiga, sem FORGE_ROOT e com FORGE_ROOT continuaram iguais ('$out4b_no') — a mutação não afetou a propriedade que [1] verifica"
  exit 1
fi
echo "OK [4] mutação — sem FORGE_ROOT ('$out4b_no') diverge de com FORGE_ROOT ('$out4b_yes'), como esperado da forma antiga"

cp "$GATEORD_PRISTINE" "$GATEORD_FX"
cmp -s "$GATEORD_FX" "$GATEORD_PRISTINE" \
  || { echo "FAIL [4] recontrole: a restauração por cópia não bateu byte a byte com a referência"; exit 1; }
out4c_no="$(_fx_no_root)"
out4c_yes="$(_fx_with_root)"
[ "$out4c_no" = "$out4c_yes" ] || { echo "FAIL [4] recontrole: após a restauração por cópia '$out4c_no' != '$out4c_yes'"; exit 1; }
echo "OK [4] recontrole — a restauração por cópia devolveu a igualdade ('$out4c_no' == '$out4c_yes')"

echo "TODOS OS CENÁRIOS OK — w204-ordinal-root-resolution-gate"

# Fecho da sentinela pelos TRÊS estados: rc 0 limpo, rc 1 acusação, rc 3 NÃO VERIFICADO. O idioma
# anterior (`arvore_confere ... || { echo "a árvore mudou"; exit 1; }`) colapsava rc 1 e rc 3 no mesmo
# `||` e imprimia, em árvore sem `.git`, a acusação FALSA de que a árvore rastreada mudou.
arvore_sentinela_fim "$WS" "$ARVORE_ANTES" "w204-ordinal-root-resolution" || exit $?
