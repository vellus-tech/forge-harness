#!/usr/bin/env bash
# Gate W191 — o `doctor` denuncia o gate órfão (LDG-0110 + peça executável da issue #82).
#
# Um `check-*.sh` presente em `.forge/scripts/`, não invocado por hook nenhum e não declarado em
# `runtime.gates` de fase alguma, é um gate que ninguém roda — e ele conta como cobertura em todo
# relatório. O único check que existia (`hp_orfaos`) só roda no ramo `else` da cascata de
# `core.hooksPath`, isto é, APENAS quando o hooksPath é customizado e diferente do canônico. No
# caso comum — o hooksPath default instalado pelo próprio harness — o bloco nunca executava.
#
# Sete dos catorze `check-*.sh` do template não têm ponto de entrada de produção que os invoque
# por padrão, e três deles (`check-authz`, `check-data-governance`, `check-observability`) só
# rodam se o consumidor declarar `runtime.gates`. É exatamente isso que o doctor passa a dizer.
#
# ASSERÇÃO NEGATIVA NUNCA SOZINHA. "o doctor não os acusa" é satisfeito por um harness em que o
# mecanismo inteiro não existe — passa ANTES da correção e não prova nada. Todo cenário abaixo que
# afirma uma ausência vem pareado com o SINAL POSITIVO de que o mecanismo rodou: a linha de
# contador do doctor, que nomeia quantos `check-*.sh` examinou e quantos ficaram órfãos.
#
#   [1] hooksPath DEFAULT, três check-*.sh sem hook e sem runtime.gates: o doctor nomeia os três
#   [2] os mesmos três declarados em runtime.gates (CSV): não são acusados — e o contador prova
#       que o doctor examinou e concluiu, em vez de não ter olhado
#   [3] o mesmo na forma MAPEADA com phase: pre-deploy — declarado com fase é declarado; é o
#       cenário que prova que o cruzamento usa o leitor único, não um awk novo
#   [4] runtime.gates vazio em todas as fases: o doctor INFORMA e o exit code continua 0
#   [5] invariante de severidade: o exit code não muda em relação à mesma fixture sem órfão algum
#   [6] hooksPath customizado: o comportamento de hp_orfaos (w153[74]) continua idêntico
#   [7] contador de controle: universo de check-*.sh vazio REPROVA o cenário, não aprova
#   [8] mutação: apagar a consulta a runtime.gates faz [2] e [3] reprovarem; restaurar volta a
#       passar, com cmp verificado
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC_SRC="$WS/template/.forge/scripts/doctor.sh"
T="$(mktemp -d /tmp/forge-w191.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

[ -f "$DOC_SRC" ] || { echo "FAIL [0]: doctor.sh não existe"; exit 1; }

# Fixture mínima: repositório git com .forge/scripts + .forge/hooks/git e hooksPath DEFAULT
# (apontando para .forge/hooks/git do próprio checkout), que é o caso comum e o que o bloco
# antigo de órfãos nunca alcançava.
mkfix() { # mkfix <nome> <bloco gates do FORGE.md, já indentado> [--custom-hookspath]
  local name="$1" gates_block="$2" custom="${3:-default}"
  local d="$T/$name"
  mkdir -p "$d/.forge/scripts/lib" "$d/.forge/hooks/git"
  git init -q "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  cp "$DOC_SRC" "$d/.forge/scripts/doctor.sh"
  cp "$WS/template/.forge/scripts/lib/forge-runtime.sh" "$d/.forge/scripts/lib/"
  cp "$WS/template/.forge/scripts/lib/gate-phase.mjs" "$d/.forge/scripts/lib/"
  cp "$WS/template/.forge/scripts/lib/yaml-lite.mjs" "$d/.forge/scripts/lib/"
  # Hook real do template: é dele que sai o universo de "gate invocado por hook".
  cp "$WS/template/.forge/hooks/git/pre-push" "$d/.forge/hooks/git/pre-push"
  cp "$WS/template/.forge/hooks/git/pre-commit" "$d/.forge/hooks/git/pre-commit" 2>/dev/null || true
  # Os que o hook invoca: presentes e NÃO órfãos.
  for g in check-ai-attribution check-liaison-acks check-secrets; do
    cp "$WS/template/.forge/scripts/$g.sh" "$d/.forge/scripts/$g.sh" 2>/dev/null \
      || printf '#!/usr/bin/env bash\nexit 0\n' > "$d/.forge/scripts/$g.sh"
  done
  # Os três ÓRFÃOS deste gate: presentes em disco, invocados por ninguém.
  for g in check-orfao-um check-orfao-dois check-orfao-tres; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$d/.forge/scripts/$g.sh"
  done
  {
    printf -- '---\n'
    printf 'forge_version: 1\n'
    printf 'project:\n  name: %s\n' "$name"
    printf 'runtime:\n  primary_stack:\n  run:\n  test:\n  typecheck:\n  lint:\n'
    printf '%s' "$gates_block"
    printf -- '---\n\n# FORGE.md — %s\n' "$name"
  } > "$d/.forge/FORGE.md"
  printf '# %s\n' "$name" > "$d/AGENTS.md"
  # forge.yaml: sem ele o doctor já sai com rc 1 por outro motivo, e o cenário [4] (invariante de
  # severidade) mediria o defeito errado.
  cp "$WS/template/.forge/forge.yaml" "$d/.forge/forge.yaml" 2>/dev/null || true
  ( cd "$d" && ln -sf AGENTS.md CLAUDE.md )
  if [ "$custom" = "default" ]; then
    git -C "$d" config core.hooksPath "$d/.forge/hooks/git"
  else
    mkdir -p "$d/.githooks"
    printf '#!/bin/sh\n%s\n' "$custom" > "$d/.githooks/pre-push"
    chmod +x "$d/.githooks/pre-push"
    git -C "$d" config core.hooksPath "$d/.githooks"
  fi
  printf '%s\n' "$d"
}

roda() { ( cd "$1" && FORGE_ROOT="$1" bash "$1/.forge/scripts/doctor.sh" 2>&1 ); }
roda_rc() { ( cd "$1" && FORGE_ROOT="$1" bash "$1/.forge/scripts/doctor.sh" >/dev/null 2>&1 ); echo $?; }

GB_VAZIO='  gates:
'
GB_CSV='  gates: check-orfao-um,check-orfao-dois,check-orfao-tres
'
GB_MAPEADA='  gates:
    - name: check-orfao-um
      phase: pre-deploy
    - name: check-orfao-dois
      phase: pre-deploy
    - name: check-orfao-tres
      phase: post-deploy
'

echo "[1] hooksPath default, três check-*.sh sem hook e sem runtime.gates: o doctor nomeia os três"
D1="$(mkfix orfaos "$GB_VAZIO")"
out1="$(roda "$D1")"
for g in check-orfao-um check-orfao-dois check-orfao-tres; do
  grep -q "$g" <<<"$out1" || { echo "FAIL [1]: o doctor não nomeou o gate órfão '$g' no caso do hooksPath DEFAULT — o bloco de órfãos só rodava no ramo customizado. Saída:"; echo "$out1"; exit 1; }
done
grep -qE "harness: gates: [0-9]+ check-\*\.sh examinado\(s\), [1-9][0-9]* gate\(s\) órfão" <<<"$out1" \
  || { echo "FAIL [1]: o doctor nomeou nomes mas não declarou o veredito contado de gate órfão. Saída:"; echo "$out1"; exit 1; }
echo "OK [1] — $(grep -E 'harness: gates: [0-9]+ check' <<<"$out1" | head -1)"

echo "[2] os três declarados em runtime.gates (CSV): não são acusados, e o contador prova a leitura"
D2="$(mkfix declarados "$GB_CSV")"
out2="$(roda "$D2")"
# SINAL POSITIVO obrigatório: sem a linha de contador, "não acusou" seria satisfeito por um
# doctor que não olhou.
grep -qE "harness: gates: [0-9]+ check-\*\.sh examinado" <<<"$out2" \
  || { echo "FAIL [2]: o doctor não declarou quantos check-*.sh examinou — asserção negativa sem sinal positivo não prova nada. Saída:"; echo "$out2"; exit 1; }
for g in check-orfao-um check-orfao-dois check-orfao-tres; do
  grep -qE "órfão.*$g|$g.*órfão" <<<"$out2" && { echo "FAIL [2]: gate DECLARADO em runtime.gates foi acusado de órfão ('$g'). Saída:"; echo "$out2"; exit 1; }
done
grep -q "0 órfão" <<<"$out2" || { echo "FAIL [2]: o doctor não declarou zero órfãos com todos os gates declarados. Saída:"; echo "$out2"; exit 1; }
echo "OK [2] — $(grep -E 'harness: gates: [0-9]+ check' <<<"$out2" | head -1)"

echo "[3] os três na forma MAPEADA com phase: pre-deploy/post-deploy também não são acusados"
D3="$(mkfix mapeada "$GB_MAPEADA")"
out3="$(roda "$D3")"
grep -qE "harness: gates: [0-9]+ check-\*\.sh examinado" <<<"$out3" \
  || { echo "FAIL [3]: sem contador — o cruzamento não rodou. Saída:"; echo "$out3"; exit 1; }
for g in check-orfao-um check-orfao-dois check-orfao-tres; do
  grep -qE "órfão.*$g|$g.*órfão" <<<"$out3" && { echo "FAIL [3]: gate declarado na forma MAPEADA foi acusado de órfão ('$g') — o cruzamento não está usando o leitor único (lib/forge-runtime.sh), que é o que enxerga phase:. Saída:"; echo "$out3"; exit 1; }
done
grep -q "0 órfão" <<<"$out3" || { echo "FAIL [3]: o doctor não declarou zero órfãos com os gates declarados por fase. Saída:"; echo "$out3"; exit 1; }
echo "OK [3] — $(grep -E 'harness: gates: [0-9]+ check' <<<"$out3" | head -1)"

echo "[4] runtime.gates vazio em todas as fases: o doctor INFORMA e o exit code continua 0"
grep -qi "runtime.gates.*vazi\|nenhum gate declarado" <<<"$out1" \
  || { echo "FAIL [4]: com runtime.gates vazio o doctor não informou nada. Saída:"; echo "$out1"; exit 1; }
rc4="$(roda_rc "$D1")"
[ "$rc4" -eq 0 ] || { echo "FAIL [4]: gate órfão mudou o exit code do doctor (rc=$rc4) — o check é informativo por construção (LDG-0013 foi encerrado como wont-fix por retrocompatibilidade)"; exit 1; }
echo "OK [4] — rc=0 com aviso informativo"

echo "[5] invariante de severidade — exit code idêntico com e sem órfão"
D5="$(mkfix semorfao "$GB_CSV")"
rm -f "$D5"/.forge/scripts/check-orfao-*.sh
python3 - "$D5/.forge/FORGE.md" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(s.replace("  gates: check-orfao-um,check-orfao-dois,check-orfao-tres\n", "  gates:\n"))
PY
rc5a="$(roda_rc "$D5")"
rc5b="$(roda_rc "$D1")"
[ "$rc5a" = "$rc5b" ] || { echo "FAIL [5]: exit code diverge entre fixture sem órfão ($rc5a) e com três órfãos ($rc5b) — o check deixou de ser informativo"; exit 1; }
echo "OK [5] — rc=$rc5a nos dois"

echo "[6] hooksPath customizado — o comportamento de hp_orfaos continua idêntico, sem duplicidade"
D6="$(mkfix custom "$GB_VAZIO" 'echo hook-proprio')"
out6="$(roda "$D6")"
grep -qi "core.hooksPath customizado" <<<"$out6" \
  || { echo "FAIL [6]: a cascata de hooksPath customizado deixou de reportar. Saída:"; echo "$out6"; exit 1; }
n6="$(grep -c "check-orfao-um" <<<"$out6")"
[ "$n6" -le 2 ] || { echo "FAIL [6]: 'check-orfao-um' aparece $n6 vezes — duplicidade entre hp_orfaos e o check novo. Saída:"; echo "$out6"; exit 1; }
echo "OK [6] — hp_orfaos preservado, $n6 menção(ões) ao órfão"

echo "[7] contador de controle — universo de check-*.sh VAZIO reprova o cenário, não aprova"
D7="$(mkfix semgates "$GB_VAZIO")"
rm -f "$D7"/.forge/scripts/check-*.sh
out7="$(roda "$D7")"
grep -qE "harness: gates: 0 check-\*\.sh" <<<"$out7" \
  || { echo "FAIL [7]: com ZERO check-*.sh o doctor não declarou o universo vazio — 'não examinei' e 'examinei e estava limpo' colapsam. Saída:"; echo "$out7"; exit 1; }
# E o cenário do gate reprova o VAZIO: se a fixture perdesse os check-*.sh por acidente, [1]-[3]
# aprovariam vacuamente. Aqui a contagem da fixture viva é conferida.
n_univ="$(ls "$D1"/.forge/scripts/check-*.sh 2>/dev/null | wc -l | tr -d ' ')" || n_univ=0
[ "${n_univ:-0}" -gt 0 ] || { echo "FAIL [7]: a fixture de [1] tem ZERO check-*.sh — os cenários acima aprovariam por vacuidade"; exit 1; }
echo "OK [7] — universo declarado; fixture de [1] com $n_univ check-*.sh"

echo "[8] mutação — apagar a consulta a runtime.gates faz [2] e [3] reprovarem"
MUT="$T/mut-doctor.sh"
cp "$D2/.forge/scripts/doctor.sh" "$T/doctor.orig"
_mut_ok() { # 0 quando [2] e [3] passam com o doctor instalado nas fixtures
  local o2 o3
  o2="$(roda "$D2")"; o3="$(roda "$D3")"
  grep -q "0 órfão" <<<"$o2" && grep -q "0 órfão" <<<"$o3"
}
_mut_ok || { echo "FAIL [8]: pré-condição — [2]/[3] não passam antes da mutação"; exit 1; }
for d in "$D2" "$D3"; do
  perl -0pi -e 's/forge_runtime_gate_entries "\$ROOT"/printf ""/' "$d/.forge/scripts/doctor.sh"
done
cmp -s "$D2/.forge/scripts/doctor.sh" "$T/doctor.orig" && { echo "FAIL [8]: a mutação não alterou o doctor — o ponto de mutação mudou de nome"; exit 1; }
if _mut_ok; then
  echo "FAIL [8]: sem a consulta a runtime.gates, [2] e [3] continuaram passando — o cruzamento não é o que decide"
  exit 1
fi
for d in "$D2" "$D3"; do cp "$T/doctor.orig" "$d/.forge/scripts/doctor.sh"; done
cmp -s "$D2/.forge/scripts/doctor.sh" "$T/doctor.orig" || { echo "FAIL [8]: restauração não bateu byte a byte (cmp)"; exit 1; }
_mut_ok || { echo "FAIL [8]: recontrole — depois da restauração [2]/[3] não voltaram a passar"; exit 1; }
rm -f "$MUT"
echo "OK [8] — mutou, reprovou, restaurou (cmp ok), voltou a passar"

echo "PASS w191-doctor-orphan-gate"
