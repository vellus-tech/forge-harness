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
#
# Issue #153 — cópia de `.forge` de outro consumidor é upgrade parcial disfarçado. Estende este
# MESMO gate (não cria um novo) com dois checks novos do doctor: lib órfã em scripts/lib/ e
# divergência entre forge.yaml:template_version e o cabeçalho do machinery.lock.
#
#   [9] consumidor recém-criado por `init` (cópia integral de template/.forge/scripts): ZERO
#       linhas de lib órfã — controle contra falso-positivo em api-surface.mjs/pbt.mjs/transports
#   [10] lib sem invocador (positiva): o doctor nomeia o arquivo
#   [11] contrafactual: lib sourceada por um script legítimo NÃO é nomeada, e o script que a
#        sourceia entra na contagem de "examinados" só pelo lado do universo, não como invocador
#        de si mesmo
#   [12] versão divergente entre forge.yaml e machinery.lock: o doctor nomeia as DUAS versões
#   [13] versão idêntica: sem linha de divergência (contrafactual do 12)
#
# LDG-0153 — o doctor não informa divergência do `_common.sh` (e demais transportes) contra o
# template. `.forge/cache/machinery.lock` já grava o sha256 por caminho da última aplicação
# (`bin/forge.mjs:361`), e `bin/forge.mjs:617-643` já faz essa comparação para o WARN de drift do
# `update` — o doctor não fazia o equivalente, e o consumidor só descobria o `_common.sh`
# divergente quando um push já tinha destruído o hub de liaison. Estende este MESMO gate.
#
#   [14] divergência de _common.sh contra o machinery.lock (positiva): o doctor nomeia o arquivo
#        e os DOIS shas (local e do lock)
#   [15] contrafactual do 14, na MESMA fixture: fs.sh, que não mudou e tem entrada no lock, não
#        gera linha nenhuma — prova que o check distingue arquivo a arquivo, não avisa em bloco
#   [16] sem machinery.lock: "não medido: sem machinery.lock", nunca ✓ (não medido != medido e
#        igual)
#   [17] exceção viva declarada em machinery-exceptions.txt: a linha nomeia a exceção e a razão
#        registrada, e o aviso '!' de divergência crua desaparece
#   [18] mutação: neutralizar a consulta ao machinery.lock faz [14] deixar de acusar a divergência
#        (dar zero); restaurar volta a passar, com cmp verificado
set -uo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo
# obedecerem ao repositório de quem invocou o gate, e não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

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

# ── issue #153 — mkfull: cópia INTEGRAL de template/.forge/scripts (+ hooks), como um `init` de
# verdade entregaria a um consumidor novo. mkfix acima copia só 3 libs (as que o cruzamento de
# gate precisa) — insuficiente para o controle [9], que precisa do UNIVERSO real de scripts/lib
# (as 79+ libs do template, incluindo api-surface.mjs/pbt.mjs/transports) para provar que a
# isenção declarada no doctor não deixa passar falso-positivo em produção.
mkfull() { # mkfull <nome>
  local name="$1"
  local d="$T/$name"
  mkdir -p "$d"
  cp -R "$WS/template/.forge" "$d/.forge"
  git init -q "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  printf '# %s\n' "$name" > "$d/AGENTS.md"
  ( cd "$d" && ln -sf AGENTS.md CLAUDE.md )
  git -C "$d" config core.hooksPath "$d/.forge/hooks/git"
  printf '%s\n' "$d"
}

echo "[9] consumidor recém-criado por init (cópia integral de scripts/lib): zero linhas de lib órfã"
D9="$(mkfull init-limpo)"
out9="$(roda "$D9")"
grep -qE "harness: libs: [0-9]+ arquivo\(s\) em scripts/lib/ examinado\(s\), 0 órfã" <<<"$out9" \
  || { echo "FAIL [9]: consumidor recém-criado por init acusou lib órfã — falso-positivo em api-surface.mjs/pbt.mjs/transports não foi resolvido. Saída:"; grep "harness: libs" <<<"$out9"; exit 1; }
grep -qE '^\s*!\s*harness: libs:' <<<"$out9" \
  && { echo "FAIL [9]: linha de lib órfã (marcador '!') presente num consumidor recém-criado. Saída:"; grep "harness: libs" <<<"$out9"; exit 1; }
echo "OK [9] — $(grep -E 'harness: libs:' <<<"$out9")"

echo "[10] lib sem invocador (positiva): o doctor nomeia o arquivo"
D10="$(mkfix libs-orfas "$GB_VAZIO")"
printf '#!/usr/bin/env bash\necho zz\n' > "$D10/.forge/scripts/lib/zz-orfa.sh"
out10="$(roda "$D10")"
grep -qE '^\s*!\s*harness: libs:.*zz-orfa\.sh' <<<"$out10" \
  || { echo "FAIL [10]: o doctor não nomeou 'zz-orfa.sh' como lib órfã. Saída:"; grep "harness: libs" <<<"$out10"; exit 1; }
echo "OK [10] — $(grep -E 'harness: libs:' <<<"$out10")"

echo "[11] contrafactual: lib sourceada por um script legítimo não é nomeada"
D11="$(mkfix libs-usadas "$GB_VAZIO")"
printf '#!/usr/bin/env bash\n. "$(dirname "$0")/lib/zz-usada.sh"\n' > "$D11/.forge/scripts/zz-user.sh"
printf '#!/usr/bin/env bash\necho usada\n' > "$D11/.forge/scripts/lib/zz-usada.sh"
out11="$(roda "$D11")"
grep -qE 'harness: libs:.*zz-usada\.sh' <<<"$out11" \
  && { echo "FAIL [11]: lib SOURCEADA por script legítimo foi nomeada como órfã ('zz-usada.sh'). Saída:"; grep "harness: libs" <<<"$out11"; exit 1; }
grep -qE "harness: libs: [0-9]+ arquivo\(s\)" <<<"$out11" \
  || { echo "FAIL [11]: sem o contador — asserção negativa sem sinal positivo não prova nada. Saída:"; echo "$out11"; exit 1; }
echo "OK [11] — $(grep -E 'harness: libs:' <<<"$out11")"

echo "[12] versão divergente entre forge.yaml e machinery.lock: o doctor nomeia as duas"
D12="$(mkfix versao-divergente "$GB_VAZIO")"
mkdir -p "$D12/.forge/cache"
printf '# forge machinery.lock — sha256 dos arquivos do template v0.9.0 (última aplicação).\n' \
  > "$D12/.forge/cache/machinery.lock"
out12="$(roda "$D12")"
tv_yaml_v="$(grep -m1 -E '^\s*template_version:' "$D12/.forge/forge.yaml" | sed -E 's/^[^:]*:[[:space:]]*"?([^"[:space:]]*)"?.*/\1/')"
[ -n "$tv_yaml_v" ] || { echo "FAIL [12]: fixture sem template_version em forge.yaml — precondição quebrada"; exit 1; }
grep -qE "harness: versão:.*$tv_yaml_v.*0\.9\.0|harness: versão:.*0\.9\.0.*$tv_yaml_v" <<<"$out12" \
  || { echo "FAIL [12]: o doctor não nomeou as duas versões (forge.yaml=$tv_yaml_v, lock=0.9.0). Saída:"; grep "harness: versão" <<<"$out12"; exit 1; }
grep -qE '^\s*!\s*harness: versão:' <<<"$out12" \
  || { echo "FAIL [12]: divergência de versão não gerou linha de aviso ('!'). Saída:"; grep "harness: versão" <<<"$out12"; exit 1; }
echo "OK [12] — $(grep -E 'harness: versão:' <<<"$out12")"

echo "[13] versão idêntica: sem linha de divergência (contrafactual do 12)"
D13="$(mkfix versao-igual "$GB_VAZIO")"
mkdir -p "$D13/.forge/cache"
printf '# forge machinery.lock — sha256 dos arquivos do template v%s (última aplicação).\n' "$tv_yaml_v" \
  > "$D13/.forge/cache/machinery.lock"
out13="$(roda "$D13")"
grep -qE '^\s*!\s*harness: versão:' <<<"$out13" \
  && { echo "FAIL [13]: versão idêntica entre forge.yaml e machinery.lock gerou aviso de divergência indevido. Saída:"; grep "harness: versão" <<<"$out13"; exit 1; }
grep -qE '^\s*✓\s*harness: versão:' <<<"$out13" \
  || { echo "FAIL [13]: sem o contrafactual positivo (✓) confirmando que o cruzamento rodou e concluiu igualdade. Saída:"; grep "harness: versão" <<<"$out13"; exit 1; }
echo "OK [13] — $(grep -E 'harness: versão:' <<<"$out13")"

sha_of() { # sha_of <arquivo> — portável, mesmo helper que o doctor usa
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | awk '{print $1}'
  fi
}

echo "[14] divergência de _common.sh contra o machinery.lock: o doctor nomeia o arquivo e os dois shas"
D14="$(mkfull transports-divergente)"
sha_common_lock="$(sha_of "$D14/.forge/scripts/lib/transports/_common.sh")"
sha_fs_lock="$(sha_of "$D14/.forge/scripts/lib/transports/fs.sh")"
[ -n "$sha_common_lock" ] && [ -n "$sha_fs_lock" ] || { echo "FAIL [14]: precondição — não consegui calcular sha256 (nem shasum nem sha256sum disponível)"; exit 1; }
mkdir -p "$D14/.forge/cache"
printf '# forge machinery.lock — sha256 dos arquivos do template v0.15.0 (última aplicação).\n%s  scripts/lib/transports/_common.sh\n%s  scripts/lib/transports/fs.sh\n' \
  "$sha_common_lock" "$sha_fs_lock" > "$D14/.forge/cache/machinery.lock"
printf '\n# deriva local, deliberada\n' >> "$D14/.forge/scripts/lib/transports/_common.sh"
sha_common_local="$(sha_of "$D14/.forge/scripts/lib/transports/_common.sh")"
out14="$(roda "$D14")"
grep -qE '^\s*!\s*harness: transports:.*_common\.sh.*diverge' <<<"$out14" \
  || { echo "FAIL [14]: o doctor não nomeou _common.sh como divergente do machinery.lock. Saída:"; grep -i transports <<<"$out14"; exit 1; }
grep -qF "$sha_common_local" <<<"$out14" \
  || { echo "FAIL [14]: o sha LOCAL não apareceu na linha de divergência. Saída:"; grep -i transports <<<"$out14"; exit 1; }
grep -qF "$sha_common_lock" <<<"$out14" \
  || { echo "FAIL [14]: o sha do LOCK não apareceu na linha de divergência. Saída:"; grep -i transports <<<"$out14"; exit 1; }
echo "OK [14] — $(grep -E 'harness: transports:.*_common' <<<"$out14")"

echo "[15] contrafactual do 14 (mesma fixture): fs.sh idêntico ao lock não gera linha"
grep -qi 'fs\.sh' <<<"$(grep -i transports <<<"$out14")" \
  && { echo "FAIL [15]: fs.sh, idêntico ao lock, apareceu numa linha do check de transports. Saída:"; grep -i transports <<<"$out14"; exit 1; }
echo "OK [15] — fs.sh idêntico ao lock, sem linha (só _common.sh divergente apareceu)"

echo "[16] sem machinery.lock: 'não medido', nunca ✓ (não medido != medido e igual)"
D16="$(mkfull transports-sem-lock)"
rm -f "$D16/.forge/cache/machinery.lock"
out16="$(roda "$D16")"
grep -qE '^\s*·\s*harness: transports: não medido: sem machinery\.lock' <<<"$out16" \
  || { echo "FAIL [16]: sem machinery.lock o doctor não declarou 'não medido'. Saída:"; grep -i transports <<<"$out16"; exit 1; }
grep -qE '^\s*✓\s*harness: transports:' <<<"$out16" \
  && { echo "FAIL [16]: sem machinery.lock o doctor imprimiu ✓ — nunca deveria (não medido é um terceiro estado, não 'igual')"; exit 1; }
echo "OK [16] — $(grep -E 'harness: transports:' <<<"$out16")"

echo "[17] exceção viva declarada: a linha nomeia a exceção e a razão, e o '!' de divergência crua some"
D17="$(mkfull transports-excecao)"
sha_common17="$(sha_of "$D17/.forge/scripts/lib/transports/_common.sh")"
mkdir -p "$D17/.forge/cache"
printf '# forge machinery.lock — sha256 dos arquivos do template v0.15.0 (última aplicação).\n%s  scripts/lib/transports/_common.sh\n' \
  "$sha_common17" > "$D17/.forge/cache/machinery.lock"
printf '\n# correcao local\n' >> "$D17/.forge/scripts/lib/transports/_common.sh"
printf '%s  scripts/lib/transports/_common.sh  # correcao local deliberada, aguardando upstream\n' \
  "$sha_common17" > "$D17/.forge/machinery-exceptions.txt"
out17="$(roda "$D17")"
grep -qE '^\s*!\s*harness: transports:.*_common\.sh.*diverge' <<<"$out17" \
  && { echo "FAIL [17]: exceção declarada, mas o doctor ainda emitiu o '!' cru de divergência. Saída:"; grep -i transports <<<"$out17"; exit 1; }
grep -qF "correcao local deliberada, aguardando upstream" <<<"$out17" \
  || { echo "FAIL [17]: a linha não nomeou a razão declarada em machinery-exceptions.txt. Saída:"; grep -i transports <<<"$out17"; exit 1; }
grep -qE 'harness: transports:.*_common\.sh' <<<"$out17" \
  || { echo "FAIL [17]: nenhuma linha nomeou _common.sh com a exceção declarada. Saída:"; echo "$out17"; exit 1; }
echo "OK [17] — $(grep -E 'harness: transports:' <<<"$out17")"

echo "[18] mutação — neutralizar a consulta ao machinery.lock faz [14] reprovar (dar zero divergências)"
NEEDLE_TP='${tp_rel}\$" "$tp_lock" 2>/dev/null'
cp "$D14/.forge/scripts/doctor.sh" "$T/doctor.orig.tp"
_mut_ok_tp() { grep -qE '^\s*!\s*harness: transports:.*_common\.sh.*diverge' <<<"$(roda "$D14")"; }
_mut_ok_tp || { echo "FAIL [18]: pré-condição — [14] não passa antes da mutação"; exit 1; }
python3 - "$D14/.forge/scripts/doctor.sh" "$NEEDLE_TP" <<'PY'
import sys, pathlib
p, needle = pathlib.Path(sys.argv[1]), sys.argv[2]
s = p.read_text()
n = s.count(needle)
if n != 1:
    print(f"FAIL [18]: needle apareceu {n} vez(es), esperado exatamente 1 — ponto de mutação mudou de forma")
    sys.exit(1)
p.write_text(s.replace(needle, 'MUTADO_NUNCA_CASA' + needle, 1))
PY
cmp -s "$D14/.forge/scripts/doctor.sh" "$T/doctor.orig.tp" && { echo "FAIL [18]: a mutação não alterou o doctor — o ponto de mutação mudou de nome"; exit 1; }
if _mut_ok_tp; then
  echo "FAIL [18]: com a consulta ao machinery.lock neutralizada, [14] continuou acusando a divergência — a consulta não é o que decide"
  exit 1
fi
out18_mut="$(roda "$D14")"
grep -qE '^\s*!\s*harness: transports:' <<<"$out18_mut" \
  && { echo "FAIL [18]: mutação neutralizou a consulta mas ainda assim alguma linha '!' de transports apareceu"; exit 1; }
cp "$T/doctor.orig.tp" "$D14/.forge/scripts/doctor.sh"
cmp -s "$D14/.forge/scripts/doctor.sh" "$T/doctor.orig.tp" || { echo "FAIL [18]: restauração não bateu byte a byte (cmp)"; exit 1; }
_mut_ok_tp || { echo "FAIL [18]: recontrole — depois da restauração [14] não voltou a passar"; exit 1; }
echo "OK [18] — mutou, reprovou (zero divergências), restaurou (cmp ok), voltou a passar"

echo "PASS w191-doctor-orphan-gate"
