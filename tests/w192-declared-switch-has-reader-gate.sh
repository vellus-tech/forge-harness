#!/usr/bin/env bash
# Gate W192 — interruptor publicado tem leitor (LDG-0008 primeira fatia, LDG-0003).
#
# `template/.forge/forge.yaml` e `schemas/forge.schema.json` publicavam TRÊS chaves sob `quality:`
# — `require_tests_before_archive`, `require_traceability_before_archive` e
# `require_human_approval_before_archive` — e nenhum código do repositório lia qualquer uma das
# três. Todo adotante instalava um harness que AFIRMA exigir testes antes do archive e não exigia.
#
# A decisão é POR CHAVE, não uma só:
#   require_human_approval_before_archive -> REMOVER. A capacidade existe e funciona sob outro
#     nome: `gates.human_archive_approval` no manifesto do change, exigido por validate-archive.mjs
#     e escrito por approval-log.sh. Fiar criaria DUAS chaves para o mesmo fato — o defeito que
#     check-push-ahead.sh:166 já registra ter recusado a cometer. E um adotante que a pusesse em
#     `false` esperando pular o gate encontraria o gate mesmo assim, sem que nada explicasse.
#   require_tests_before_archive        -> TORNAR REAL no pré-flight §13.1.
#   require_traceability_before_archive -> TORNAR REAL no mesmo ponto.
#
# O sinal que prova cada uma foi MEDIDO antes de implementar, e nenhum artefato novo foi
# inventado: `verification.yaml` já registra os checks com nome e status (`spec-verify.sh` os
# nomeia `test`/`typecheck`/`lint`, pelas chaves do bloco runtime), e `traceability.yaml` já
# existe, tem schema próprio e é validado por `validate-spec.mjs` QUANDO PRESENTE — nunca exigido.
#
#   [1]  propriedade: toda chave declarada load-bearing tem leitor que DECIDE algo
#   [2]  contrapositiva: chave sintética sem leitor reprova o gate — a lista não é decoração
#   [3]  require_human_approval_before_archive não aparece em forge.yaml nem no schema
#   [4]  change sem sinal de teste com require_tests_before_archive: true reprova, nomeando a chave
#   [5]  o mesmo change com a chave em false passa, e o archive DIZ que passou por dispensa
#   [6]  contador de controle: lista de interruptores vazia reprova o gate
#   [4b] a chave em `true` com um check `test` que REPROVOU também reprova o archive
#   [4c] a chave em `true` com um check `test` que PASSOU aprova, e o pré-flight declara isso
#   [4d] o DEFAULT de fábrica da chave é `false`, e o motivo está escrito ao lado do da irmã —
#        `templates/FORGE.md` entrega `test:` vazio, então ligada por default ela reprovaria o
#        primeiro archive de todo projeto greenfield
#   [7]  mutação: remover a consulta à chave no pré-flight faz [4] reprovar; restaurar volta
#   [8]  rules.packs declarado ATIVA a rule do pack como contrato, e o validador o AFIRMA
#   [9]  rule com pack: NÃO ativado continua válida e disponível como referência — pareado com o
#        sinal positivo de que o validador de fato classificou a rule
#   [10] pack: no frontmatter referenciando pack DESCONHECIDO reprova, nomeando a rule
#   [11] mutação: apagar a leitura de rules.packs faz [8] reprovar
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w192.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

_run_to() { local s="$1"; shift; [ "${1:-}" = "--" ] && shift; perl -e "alarm $s; exec @ARGV" -- "$@"; }

# ── [1]/[2]/[6] a propriedade ────────────────────────────────────────────────────────────────
# Chaves publicadas como ENFORCEMENT: prometem que o harness COBRA algo. Chave que promete
# DEFAULT (sdd.default_mode e afins) tem ofensa de outra natureza e está registrada em LDG-0151.
SWITCHES=(
  "quality.require_tests_before_archive"
  "quality.require_traceability_before_archive"
)

# "Ter leitor" não é "ser mencionado": um comentário satisfaria a menção, e a própria correção
# desta fatia escreve comentários sobre as chaves. A asserção é sobre USO — a chave aparece num
# sítio que DECIDE. O predicado: ocorrência fora de linha de comentário, em scripts/, hooks/ ou
# bin/. É o que a objeção não bloqueante da revisão adversarial exige.
_reader_hits() { # _reader_hits <chave-folha>
  local leaf="${1##*.}" n=0 f
  for f in "$WS"/template/.forge/scripts/*.sh "$WS"/template/.forge/scripts/lib/*.mjs \
           "$WS"/template/.forge/hooks/git/* "$WS"/template/.forge/hooks/session/* "$WS"/bin/*.mjs; do
    [ -f "$f" ] || continue
    # Remove linhas de comentário (# em shell, // em JS) ANTES de casar: menção não é leitura.
    if sed -e 's://.*$::' -e 's:^[[:space:]]*#.*$::' "$f" | grep -q "$leaf"; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}

echo "[1] propriedade — toda chave declarada load-bearing tem leitor que decide algo"
n_sw=0; bad=0
for key in "${SWITCHES[@]}"; do
  n_sw=$((n_sw + 1))
  hits="$(_reader_hits "$key")"
  if [ "$hits" -eq 0 ]; then
    echo "  '$key' é publicada em forge.yaml/schema e NENHUM arquivo de scripts/, hooks/ ou bin/ a lê fora de comentário"
    bad=$((bad + 1))
  fi
done
[ "$bad" -eq 0 ] || { echo "FAIL [1]: $bad de $n_sw interruptor(es) declarado(s) sem leitor — o harness afirma cobrar algo que não cobra"; exit 1; }
echo "OK [1] — $n_sw interruptor(es) load-bearing, todos com leitor"

echo "[2] contrapositiva — chave sintética sem leitor reprova"
hits_fake="$(_reader_hits "quality.require_unicorn_before_archive")"
[ "$hits_fake" -eq 0 ] || { echo "FAIL [2]: o predicado casou uma chave que não existe ('$hits_fake' ocorrências) — está frouxo demais para provar coisa alguma"; exit 1; }
echo "OK [2] — chave inexistente tem 0 leitores; a lista de [1] não é decoração"

echo "[6] contador de controle — lista de interruptores vazia reprova o gate"
[ "$n_sw" -gt 0 ] || { echo "FAIL [6]: lista de interruptores VAZIA — [1] aprovaria vacuamente"; exit 1; }
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w192/interruptores" "$n_sw" "interruptor(es) load-bearing" "forge.yaml + schema" "$WS" \
  || { echo "FAIL [6]"; exit 1; }
out6="$(forge_universe_check "w192/interruptores" 0 "interruptor(es)" "contrapositiva" "$WS" 2>&1)"; rc6=$?
[ "$rc6" -ne 0 ] || { echo "FAIL [6]: universo vazio aprovou — $out6"; exit 1; }
echo "OK [6] — $n_sw declarados; universo vazio reprova"

echo "[3] require_human_approval_before_archive foi REMOVIDA de forge.yaml e do schema"
# Asserção ANCORADA na forma real da chave YAML (início de linha, dois-pontos), nunca na
# substring: o próprio comentário que explica a remoção cita o nome, e um grep solto casaria a
# explicação em vez do defeito.
grep -qE '^[[:space:]]*require_human_approval_before_archive:' "$WS/template/.forge/forge.yaml" \
  && { echo "FAIL [3]: a chave continua em forge.yaml — a capacidade já existe sob outro nome (gates.human_archive_approval), e duas chaves para o mesmo fato é o defeito"; exit 1; }
grep -qE '"require_human_approval_before_archive"[[:space:]]*:' "$WS/template/.forge/schemas/forge.schema.json" \
  && { echo "FAIL [3]: a chave continua no schema"; exit 1; }
# Sinal POSITIVO pareado: o enforcement REAL continua existindo e é nomeado onde a chave estava.
grep -q "human_archive_approval" "$WS/template/.forge/forge.yaml" \
  || { echo "FAIL [3]: a chave sumiu sem apontar onde a aprovação de fato mora — remoção sem nota deixa o adotante sem resposta"; exit 1; }
grep -q "human_archive_approval" "$WS/template/.forge/scripts/lib/validate-archive.mjs" \
  || { echo "FAIL [3]: o enforcement real (gates.human_archive_approval) sumiu junto — a remoção era de UMA chave duplicada, não da capacidade"; exit 1; }
echo "OK [3] — removida de forge.yaml e do schema; o gate real preservado e apontado"

# ── [4]/[5]/[7] fixture de archive ───────────────────────────────────────────────────────────
S="$WS/template/.forge/scripts"
mkfix() { # mkfix <nome> -> ecoa o root
  local d="$T/$1"
  mkdir -p "$d"
  cp -R "$WS/template/.forge" "$d/.forge"
  git init -q "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  git -C "$d" add -A >/dev/null
  _run_to 60 -- git -C "$d" -c user.email=t@t -c user.name=t commit -q --no-verify -m init
  printf '%s\n' "$d"
}
mk_verified() { # mk_verified <root> <id>
  local d="$1" id="$2"
  ( cd "$d" && FORGE_ROOT="$d" bash "$S/spec-new.sh" "$id" --type feature --scale 0 >/dev/null
                FORGE_ROOT="$d" bash "$S/spec-transition.sh" "$id" tasks-ready >/dev/null
                FORGE_ROOT="$d" bash "$S/spec-transition.sh" "$id" implementing >/dev/null )
  perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$d/.forge/specs/active/$id/tasks.md"
  # Refactor verificado sem delta de baseline é o escape sancionado do pré-flight: sem ele o
  # cenário mediria "spec-delta.yaml ausente", não a chave sob teste.
  perl -0pi -e 's/^archive:\n/archive:\n  baseline_delta: none\n/m' "$d/.forge/specs/active/$id/manifest.yaml"
  grep -q 'baseline_delta' "$d/.forge/specs/active/$id/manifest.yaml" \
    || printf 'archive:\n  baseline_delta: none\n' >> "$d/.forge/specs/active/$id/manifest.yaml"
  ( cd "$d" && FORGE_ROOT="$d" bash "$S/spec-transition.sh" "$id" implemented >/dev/null
                FORGE_ROOT="$d" bash "$S/spec-verify.sh" "$id" >/dev/null 2>&1
                FORGE_ROOT="$d" bash "$S/approval-log.sh" "$id" --gate implementation_verified --decision approve >/dev/null
                FORGE_ROOT="$d" bash "$S/spec-transition.sh" "$id" verified >/dev/null
                FORGE_ROOT="$d" bash "$S/approval-log.sh" "$id" --gate human_archive_approval --decision approve >/dev/null )
}
_set_switch() { # _set_switch <root> <chave> <true|false>
  perl -pi -e "s/^(\\s*)$2:.*/\${1}$2: $3/" "$1/.forge/forge.yaml"
}

echo "[4] change SEM sinal de teste com require_tests_before_archive: true reprova, nomeando a chave"
D4="$(mkfix semteste)"
mk_verified "$D4" ch-semteste
_set_switch "$D4" require_tests_before_archive true
out4="$( _run_to 120 -- env FORGE_ROOT="$D4" node "$S/lib/validate-archive.mjs" "$D4/.forge/specs/active/ch-semteste" "$D4" 2>&1 )"; rc4=$?
[ "$rc4" -ne 0 ] || { echo "FAIL [4]: pré-flight aprovou um change SEM sinal de teste com a chave em true — a chave continua sendo uma afirmação falsa. Saída: $out4"; exit 1; }
grep -q "require_tests_before_archive" <<<"$out4" \
  || { echo "FAIL [4]: reprovou sem NOMEAR a chave que decidiu — quem lê não sabe qual interruptor desligar. Saída: $out4"; exit 1; }
echo "OK [4] — $(tr '\n' ' ' <<<"$out4" | cut -c1-160)"

echo "[5] o mesmo change com a chave em false passa, e o pré-flight DIZ que foi dispensa declarada"
_set_switch "$D4" require_tests_before_archive false
out5="$( _run_to 120 -- env FORGE_ROOT="$D4" node "$S/lib/validate-archive.mjs" "$D4/.forge/specs/active/ch-semteste" "$D4" 2>&1 )"; rc5=$?
[ "$rc5" -eq 0 ] || { echo "FAIL [5]: com a chave em false o pré-flight ainda reprovou — a dispensa declarada não é honrada. Saída: $out5"; exit 1; }
grep -qi "dispensa\|require_tests_before_archive: false" <<<"$out5" \
  || { echo "FAIL [5]: passou em SILÊNCIO sobre a dispensa. Uma chave que só bloqueia e nunca reporta a dispensa é indistinguível de uma chave que não existe, do ponto de vista de quem audita depois. Saída: $out5"; exit 1; }
echo "OK [5] — $(grep -i 'dispensa' <<<"$out5" | head -1)"

# As QUATRO ramificações da chave, todas exercitadas: sem check `test` ([4]), com `test` que
# reprovou ([4b]), com `test` que passou ([4c]) e desligada ([5]). Um default `false` só é honesto
# se o enforcement estiver provado LIGADO — do contrário a chave volta a ser decoração, que é o
# defeito que LDG-0008 existe para fechar.
_set_check() { # _set_check <root> <change> <nome> <status>
  node -e '
    const fs = require("fs");
    const [f, nome, status] = process.argv.slice(1);
    let y = fs.readFileSync(f, "utf8");
    y = y.replace(/  checks:\n(?:.*\n)*?(?=  evidence:|  red_first:|$)/,
      `  checks:\n    - name: ${nome}\n      command: "cmd"\n      status: ${status}\n`);
    fs.writeFileSync(f, y);
  ' "$1/.forge/specs/active/$2/verification.yaml" "$3" "$4"
}

echo "[4b] chave em true com um check 'test' que REPROVOU: o archive reprova"
_set_switch "$D4" require_tests_before_archive true
_set_check "$D4" ch-semteste test failed
out4b="$( _run_to 120 -- env FORGE_ROOT="$D4" node "$S/lib/validate-archive.mjs" "$D4/.forge/specs/active/ch-semteste" "$D4" 2>&1 )"; rc4b=$?
[ "$rc4b" -ne 0 ] || { echo "FAIL [4b]: archive aprovado com o check 'test' em 'failed' — saída: $out4b"; exit 1; }
echo "OK [4b] — $(tr '\n' ' ' <<<"$out4b" | cut -c1-120)"

echo "[4c] chave em true com um check 'test' que PASSOU: aprova, e o pré-flight declara"
_set_check "$D4" ch-semteste test passed
out4c="$( _run_to 120 -- env FORGE_ROOT="$D4" node "$S/lib/validate-archive.mjs" "$D4/.forge/specs/active/ch-semteste" "$D4" 2>&1 )"; rc4c=$?
[ "$rc4c" -eq 0 ] || { echo "FAIL [4c]: archive reprovado com o check 'test' em 'passed' — a chave virou intransponível. Saída: $out4c"; exit 1; }
# Sinal POSITIVO: aprovar em silêncio é indistinguível de a chave não existir.
grep -q "require_tests_before_archive: true" <<<"$out4c" \
  || { echo "FAIL [4c]: aprovou sem declarar que a exigência foi satisfeita — saída: $out4c"; exit 1; }
echo "OK [4c] — $(grep 'require_tests' <<<"$out4c" | head -1)"
_set_check "$D4" ch-semteste none skipped

echo "[4d] o DEFAULT de fábrica da chave é false, pelo mesmo motivo medido da irmã"
FY="$WS/template/.forge/forge.yaml"
grep -qE '^[[:space:]]*require_tests_before_archive:[[:space:]]*false' "$FY" \
  || { echo "FAIL [4d]: o default de fábrica não é 'false'. templates/FORGE.md entrega 'test:' VAZIO, então spec-verify grava um único check 'name: none / status: skipped' e a chave ligada reprova o /forge:archive de todo projeto greenfield no primeiro change. Medido: cinco gates da suíte reprovam com ela ligada (w31, w32, w33, w42, w100), e w31 é o único montado a partir dos templates de fábrica — o único que não dá para calar editando a fixture."; exit 1; }
# Pareado com o sinal positivo de que o motivo está ESCRITO, e ao lado do da irmã: um default
# mudado sem justificativa registrada é indistinguível de um default mudado para calar a suíte.
grep -q "greenfield" "$FY" \
  || { echo "FAIL [4d]: o default é 'false' e o motivo não está escrito no forge.yaml, ao lado do da chave irmã"; exit 1; }
# E o de fábrica de templates/FORGE.md continua sendo 'test:' vazio — é a premissa da decisão.
grep -qE '^[[:space:]]*test:[[:space:]]*$' "$WS/template/.forge/templates/FORGE.md" \
  || { echo "FAIL [4d]: templates/FORGE.md deixou de entregar 'test:' vazio — a premissa medida da decisão mudou, e a decisão precisa ser remedida"; exit 1; }
echo "OK [4d] — default 'false', motivo escrito, e 'test:' de fábrica continua vazio"

echo "[7] mutação — remover a consulta à chave no pré-flight faz [4] reprovar"
VA="$D4/.forge/scripts/lib/validate-archive.mjs"
cp "$VA" "$T/va.orig"
_set_switch "$D4" require_tests_before_archive true
_rc4() { _run_to 120 -- env FORGE_ROOT="$D4" node "$VA" "$D4/.forge/specs/active/ch-semteste" "$D4" >/dev/null 2>&1; echo $?; }
[ "$(_rc4)" -ne 0 ] || { echo "FAIL [7]: pré-condição — [4] não reprova antes da mutação"; exit 1; }
perl -0pi -e 's/const QUALITY = readQuality\(\);/const QUALITY = {};/' "$VA"
cmp -s "$VA" "$T/va.orig" && { echo "FAIL [7]: a mutação não alterou o arquivo — o ponto de mutação mudou de nome"; exit 1; }
[ "$(_rc4)" -eq 0 ] || { echo "FAIL [7]: com a leitura de forge.yaml neutralizada, [4] continuou reprovando — não é a chave que decide"; exit 1; }
cp "$T/va.orig" "$VA"
cmp -s "$VA" "$T/va.orig" || { echo "FAIL [7]: restauração não bateu byte a byte (cmp)"; exit 1; }
[ "$(_rc4)" -ne 0 ] || { echo "FAIL [7]: recontrole — depois da restauração [4] não voltou a reprovar"; exit 1; }
echo "OK [7] — mutou, aprovou (defeito reintroduzido), restaurou (cmp ok), voltou a reprovar"

# ── [8]-[11] LDG-0003: chave de ativação de rule-pack ────────────────────────────────────────
VR="$WS/template/.forge/scripts/lib/validate-rules.mjs"
[ -f "$VR" ] || { echo "FAIL [8]: $VR não existe"; exit 1; }

mkrules() { # mkrules <dir> <packs-ativos-csv>
  local d="$1" packs="$2"
  mkdir -p "$d/.forge/rules/architecture"
  printf 'quality:\n  enabled: false\nrules:\n  packs: [%s]\n' "$packs" > "$d/.forge/forge.yaml"
  printf -- '---\nid: authz-pdp-pep\ntitle: Authz PDP/PEP\npriority: Alta\npack: security-authz\nopt_in: true\n---\n\n# Authz\n\nRegra.\n' \
    > "$d/.forge/rules/architecture/authz-pdp-pep.md"
  printf -- '---\nid: base\ntitle: Base\npriority: Alta\n---\n\n# Base\n\nRegra sem pack.\n' \
    > "$d/.forge/rules/architecture/base.md"
}

echo "[8] rules.packs declarado ATIVA a rule do pack como contrato, e o validador o AFIRMA"
D8="$T/packs-on"; mkrules "$D8" "security-authz"
out8="$( _run_to 60 -- node "$VR" "$D8" 2>&1 )"; rc8=$?
[ "$rc8" -eq 0 ] || { echo "FAIL [8]: validate-rules reprovou com o pack ATIVO — saída: $out8"; exit 1; }
grep -qi "pack" <<<"$out8" \
  || { echo "FAIL [8]: o validador não diz uma palavra sobre packs — nada lê rules.packs, e a rule de prioridade Alta continua sem porta de entrada. Saída: $out8"; exit 1; }
grep -qi "security-authz" <<<"$out8" \
  || { echo "FAIL [8]: o validador não nomeia o pack ATIVADO — sem isso não há como distinguir contratada de disponível. Saída: $out8"; exit 1; }
echo "OK [8] — $out8"

echo "[9] rule com pack NÃO ativado continua válida e disponível como referência"
D9="$T/packs-off"; mkrules "$D9" ""
out9="$( _run_to 60 -- node "$VR" "$D9" 2>&1 )"; rc9=$?
[ "$rc9" -eq 0 ] || { echo "FAIL [9]: rule de pack INATIVO reprovou — a documentação promete 'referência disponível, nunca gate imposto'. Saída: $out9"; exit 1; }
# Sinal POSITIVO pareado: sem ele, "não reprova" seria satisfeito por um validador que não lê nada.
grep -qi "inativo\|não ativado\|nao ativado\|disponível como referência" <<<"$out9" \
  || { echo "FAIL [9]: o validador não CLASSIFICOU a rule como de pack inativo — 'não reprovou' é satisfeito por um harness em que nada lê pack:, e era esse o estado antes. Saída: $out9"; exit 1; }
echo "OK [9] — $(grep -i 'inativ' <<<"$out9" | head -1)"

echo "[10] rules.packs ativando pack que NENHUMA rule declara reprova, nomeando o pack"
# A direção oposta que a spec propunha ("pack: no frontmatter referenciando pack desconhecido")
# NÃO é decidível sem inventar um catálogo de packs — sem catálogo, um pack que ninguém ativou é
# apenas INATIVO, que é o estado legítimo e documentado, indistinguível de um typo. Criar o
# catálogo seria uma terceira fonte de verdade para resolver um problema de duas. A direção que
# resta é a que tem conteúdo: o typo no arquivo que o humano edita produz ativação sem conteúdo.
D10="$T/packs-vazio"; mkrules "$D10" "security-authz, pack-que-nao-existe"
out10="$( _run_to 60 -- node "$VR" "$D10" 2>&1 )"; rc10=$?
[ "$rc10" -ne 0 ] || { echo "FAIL [10]: rules.packs ativando um pack sem rule alguma passou — o projeto acredita ter contratado uma política e não contratou nada. Saída: $out10"; exit 1; }
grep -q "pack-que-nao-existe" <<<"$out10" || { echo "FAIL [10]: a reprovação não nomeia o pack ativado sem conteúdo — saída: $out10"; exit 1; }
echo "OK [10] — $(head -2 <<<"$out10" | tr '\n' ' ')"

echo "[11] mutação — apagar a leitura de rules.packs faz [8] reprovar"
MUTVR="$T/validate-rules-mut.mjs"
cp "$VR" "$MUTVR"; cp "$VR" "$T/vr.orig"
# Muta o CORPO, nunca o nome: renomear definição e chamada juntas preserva o comportamento e a
# mutação passaria sem provar nada — foi o que aconteceu na primeira escrita deste cenário.
perl -0pi -e 's/  const out = new Set\(\);/  const out = new Set(); return out;/' "$MUTVR"
cmp -s "$MUTVR" "$T/vr.orig" && { echo "FAIL [11]: a mutação não alterou o arquivo — o ponto de mutação mudou de nome"; exit 1; }
# A asserção é sobre CONTRATAR, não sobre mencionar: o nome do pack segue aparecendo na linha de
# "inativo (referência)", e um grep solto pelo nome aprovaria a mutação.
out11="$( _run_to 60 -- node "$MUTVR" "$D8" 2>&1 )"; rc11=$?
if grep -q "contratada: .*security-authz" <<<"$out11"; then
  echo "FAIL [11]: com a leitura de rules.packs neutralizada o validador ainda CONTRATOU o pack — não é a chave que decide. Saída: $out11"
  exit 1
fi
out11b="$( _run_to 60 -- node "$VR" "$D8" 2>&1 )"; rc11b=$?
[ "$rc11b" -eq 0 ] && grep -q "contratada: .*security-authz" <<<"$out11b" \
  || { echo "FAIL [11]: recontrole — o original não voltou a contratar o pack. Saída: $out11b"; exit 1; }
echo "OK [11] — mutou (o validador deixou de afirmar), original intacto volta a afirmar"

echo "PASS w192-declared-switch-has-reader"
