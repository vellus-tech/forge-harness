#!/usr/bin/env bash
# Gate W190 — o `pre-push` lê `runtime.gates` pelo leitor CANÔNICO (LDG-0150, issue #82).
#
# A 0.11.0 entregou o eixo de fase: `runtime.gates` passa a aceitar block-sequence YAML com
# `phase:`, lida por `lib/forge-runtime.sh::forge_runtime_gate_entries` (CSV escalar em bash puro,
# forma mapeada delegada a `lib/gate-phase.mjs`). `run-gates.sh:58` e `spec-verify.sh:92` usam
# esse leitor. O `pre-push` NÃO: tinha um `awk` próprio (`fm_field`) que só extraía o valor escalar
# da linha `  gates:`. Medido pelo canal real, com `git push` de verdade:
#
#   forma CSV     -> o gate roda (marcador escrito)
#   forma mapeada -> GATES_CSV vazio, o laço não roda, o hook não imprime uma linha, push verde
#
# Um consumidor que adotasse `phase:` — inclusive declarando tudo como `phase: source`, a fase que
# o push executa — deixava de rodar TODOS os gates no push. Pior que não ter fase: adotar a fase
# desligava a cobrança que existia antes.
#
# Prova pelo CANAL REAL (rule testing/gate-delivery-channel.md): cada cenário monta um repositório
# com `git init`, instala os hooks do template por `core.hooksPath` ABSOLUTO, escreve um gate
# sintético que grava um marcador quando executado, e faz `git push` contra um remoto `--bare`.
#
#   [1] forma CSV escalar: o push executa o gate (controle de retrocompatibilidade)
#   [2] forma mapeada, item escalar (`- check-x`): o push executa o gate
#   [3] forma mapeada, item com `name:` + `phase: source`: o push executa o gate
#   [4] forma mapeada só com `phase: pre-deploy`: o gate NÃO roda e o hook DIZ que não há gate de
#       fase 'source' — asserção negativa pareada com sinal positivo, nunca sozinha
#   [5] gate declarado cujo script não existe: push BLOQUEADO, nas duas formas
#   [6] leitor da forma mapeada indisponível: push BLOQUEADO nomeando que a declaração não pôde
#       ser lida. [6a] (gate-phase.mjs ausente, node presente) é o cenário que ISOLA a guarda;
#       [6b] (node fora do PATH) cobra só o fecho — sem o leitor o push nunca segue verde — e
#       vira SKIP declarado quando outro check se antecipa, porque um `rc != 0` com `BLOQUEADO`
#       qualquer também acontece no pre-push de origin/develop, que não tem guarda nenhuma
#   [7] mutação de canal: com `core.hooksPath` apontando para um diretório sem o hook, [2] volta a
#       falhar — prova que o cenário mede o CANAL, não o script
#   [8] contador de controle: zero cenário executado reprova
#
# Fiação dos dois lints de shell no push (LDG-0069). Eles rodam no CI contra o corpus real desde
# sempre — `w145[8]`/`w159[8]` mais `ci.yml` —, mas nenhum hook local os invocava: o defeito não é
# ausência de cobertura, é LATÊNCIA, e o autor descobria a violação depois de empurrar.
#
#   [9]  push cujo diff toca um .sh com a forma proibida é BLOQUEADO
#   [10] push cujo diff não toca .sh nenhum não paga o custo do lint — verificado pela linha que o
#        hook imprime, não por tempo
#   [11] check-heredoc-hash.sh ausente com .forge/scripts/ presente BLOQUEIA o push
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w190.XXXXXX)"
T="$(cd "$T" && pwd -P)"   # macOS: /tmp é symlink para /private/tmp; git devolve o caminho real
trap 'rm -rf "$T"' EXIT

SCEN=0   # contador de controle: cenários efetivamente executados

_run_to() { local secs="$1"; shift; [ "${1:-}" = "--" ] && shift; perl -e "alarm $secs; exec @ARGV" -- "$@"; }

# _fixture <nome> <bloco gates (multilinha, já indentado)> [--no-gate-script]
# Devolve o caminho do repositório em stdout. O marcador de execução do gate mora FORA do
# repositório, para que `git status` da fixture não mude quando o gate roda.
_fixture() {
  local name="$1" gates_block="$2" mk_script="${3:-yes}"
  local r="$T/$name"
  mkdir -p "$r"
  cp -R "$WS/template/.forge" "$r/.forge"
  {
    printf -- '---\n'
    printf 'forge_version: 1\n'
    printf 'project:\n  name: %s\n' "$name"
    printf 'runtime:\n  primary_stack:\n  run:\n  test:\n  typecheck:\n  lint:\n'
    printf '%s' "$gates_block"
    printf -- '---\n\n# FORGE.md — %s\n' "$name"
  } > "$r/.forge/FORGE.md"

  if [ "$mk_script" = "yes" ]; then
    {
      printf '#!/usr/bin/env bash\n'
      printf 'set -eu\n'
      printf 'printf %s > "%s"\n' "'executado\\n'" "$T/marker-$name"
      printf 'echo "OK check-w190marker"\n'
    } > "$r/.forge/scripts/check-w190marker.sh"
    chmod +x "$r/.forge/scripts/check-w190marker.sh"
  fi

  printf '# %s\n' "$name" > "$r/README.md"
  printf '# Changelog\n\n## [Unreleased]\n' > "$r/CHANGELOG.md"
  # `.forge/` fora do controle de versão da FIXTURE, de propósito. Os hooks leem `.forge` do
  # DISCO, nunca do índice do git — versioná-la só faria cada push carregar ~200 `.sh` do template
  # para os lints de `LDG-0069` varrerem, o que multiplica o custo do gate por dez sem mudar uma
  # asserção. O que cada cenário publica é escrito explicitamente por ele.
  printf '.forge/\n' > "$r/.gitignore"
  git -C "$r" init -q -b main
  git -C "$r" config user.email w190@t
  git -C "$r" config user.name w190
  git -C "$r" add -A >/dev/null
  # --no-verify no COMMIT: o que está sob teste é o pre-push, e o pre-commit da fixture só
  # adicionaria ruído (varredura de segredos sobre o template inteiro) ao caminho medido.
  git -C "$r" commit -q --no-verify -m "fixture $name"
  git init -q --bare "$T/$name.git"
  git -C "$r" remote add origin "$T/$name.git"
  # ABSOLUTO: core.hooksPath vive no .git/config, e um valor relativo é resolvido por cada
  # worktree na própria árvore (w137[2]).
  git -C "$r" config core.hooksPath "$r/.forge/hooks/git"
  printf '%s\n' "$r"
}

# _push <repo> -> escreve saída em $T/out.txt, devolve rc do push
# NB: nunca mexer em `set -e` aqui dentro. Uma função que faz `set +e … set -e` restaura a opção
# GLOBALMENTE e, chamada de dentro de um bloco que a havia desligado, religa o `errexit` do
# chamador — o `return 1` seguinte mata a suíte inteira sem imprimir cenário nenhum. `|| rc=$?`
# captura o código sem tocar na opção.
_push() {
  local r="$1" rc=0
  _run_to 180 -- git -C "$r" push origin main > "$T/out.txt" 2>&1 || rc=$?
  return $rc
}

# O `pre-push` do harness também cobra documentação revisada em todo push que toque código. Os
# cenários abaixo empurram commits novos, então cada um leva README.md e CHANGELOG.md junto — do
# contrário o push é bloqueado por um gate que não é o que está sob teste.
_commit_docs() { # _commit_docs <repo> <mensagem>
  printf 'nota: %s\n' "$2" >> "$1/README.md"
  printf -- '- %s\n' "$2" >> "$1/CHANGELOG.md"
  git -C "$1" add -A >/dev/null
  git -C "$1" commit -q --no-verify -m "$2"
}

GB_CSV='  gates: check-w190marker
'
GB_SEQ_SCALAR='  gates:
    - check-w190marker
'
GB_SEQ_NAMED='  gates:
    - name: check-w190marker
      phase: source
'
GB_SEQ_DEPLOY='  gates:
    - name: check-w190marker
      phase: pre-deploy
'

echo "[1] forma CSV escalar — o push executa o gate (controle de retrocompatibilidade)"
R1="$(_fixture csv "$GB_CSV")"
_push "$R1" || { echo "FAIL [1]: push reprovou na forma CSV — saída:"; cat "$T/out.txt"; exit 1; }
[ -f "$T/marker-csv" ] || { echo "FAIL [1]: o gate não rodou na forma CSV — saída:"; cat "$T/out.txt"; exit 1; }
grep -q "check-w190marker OK" "$T/out.txt" || { echo "FAIL [1]: o hook não reportou o gate — saída:"; cat "$T/out.txt"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [1] — gate executado pelo canal real (marcador escrito)"

echo "[2] forma mapeada, item escalar — o push executa o gate"
R2="$(_fixture seqscalar "$GB_SEQ_SCALAR")"
_push "$R2" || { echo "FAIL [2]: push reprovou — saída:"; cat "$T/out.txt"; exit 1; }
[ -f "$T/marker-seqscalar" ] || { echo "FAIL [2]: o gate NÃO rodou na forma mapeada (item escalar) — o hook é cego à forma que a 0.11.0 publicou. Saída:"; cat "$T/out.txt"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [2] — gate executado"

echo "[3] forma mapeada com name: + phase: source — o push executa o gate"
R3="$(_fixture seqnamed "$GB_SEQ_NAMED")"
_push "$R3" || { echo "FAIL [3]: push reprovou — saída:"; cat "$T/out.txt"; exit 1; }
[ -f "$T/marker-seqnamed" ] || { echo "FAIL [3]: o gate NÃO rodou com 'name:'/'phase: source' — saída:"; cat "$T/out.txt"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [3] — gate executado"

echo "[4] forma mapeada só com phase: pre-deploy — gate não roda E o hook diz por quê"
R4="$(_fixture seqdeploy "$GB_SEQ_DEPLOY")"
_push "$R4" || { echo "FAIL [4]: push reprovou — saída:"; cat "$T/out.txt"; exit 1; }
[ ! -f "$T/marker-seqdeploy" ] || { echo "FAIL [4]: gate de fase 'pre-deploy' foi executado no push"; exit 1; }
# Asserção negativa NUNCA sozinha: o sinal positivo é o hook NOMEANDO a fase e a contagem. Sem
# isto, um harness em que o mecanismo inteiro não existe satisfaz o cenário.
grep -qi "fase 'source'" "$T/out.txt" || { echo "FAIL [4]: o hook não declarou que nenhum gate é de fase 'source' — silêncio não é veredito. Saída:"; cat "$T/out.txt"; exit 1; }
grep -qi "pre-deploy" "$T/out.txt" || { echo "FAIL [4]: o hook não nomeou a(s) fase(s) que declarou e não executou — saída:"; cat "$T/out.txt"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [4] — $(grep -i "fase 'source'" "$T/out.txt" | head -1)"

echo "[5] gate declarado cujo script não existe — push BLOQUEADO nas duas formas"
for form in csv seq; do
  case "$form" in
    csv) blk="$GB_CSV" ;;
    seq) blk="$GB_SEQ_NAMED" ;;
  esac
  R5="$(_fixture "missing-$form" "$blk" no-gate-script)"
  set +e
  _push "$R5"; rc5=$?
  set -e
  [ "$rc5" -ne 0 ] || { echo "FAIL [5/$form]: gate declarado e ausente NÃO bloqueou o push — saída:"; cat "$T/out.txt"; exit 1; }
  grep -q "check-w190marker" "$T/out.txt" || { echo "FAIL [5/$form]: o bloqueio não nomeia o gate ausente — saída:"; cat "$T/out.txt"; exit 1; }
  SCEN=$((SCEN + 1))
done
echo "OK [5] — bloqueio nas duas formas, nomeando o gate ausente"

echo "[6] leitor da forma mapeada indisponível — push BLOQUEADO nomeando a declaração ilegível"
# (a) gate-phase.mjs ausente
R6a="$(_fixture noreader "$GB_SEQ_NAMED")"
rm -f "$R6a/.forge/scripts/lib/gate-phase.mjs"
_commit_docs "$R6a" "sem gate-phase.mjs"
set +e
_push "$R6a"; rc6a=$?
set -e
[ "$rc6a" -ne 0 ] || { echo "FAIL [6a]: sem gate-phase.mjs o push passou em silêncio — saída:"; cat "$T/out.txt"; exit 1; }
grep -qi "não pôde ser lida\|nao pode ser lida" "$T/out.txt" || { echo "FAIL [6a]: o bloqueio não diz que a declaração não pôde ser lida — saída:"; cat "$T/out.txt"; exit 1; }
SCEN=$((SCEN + 1))

# (b) `node` fora do PATH. Sem `env -i … command -v` (funciona no macOS por causa de
# /usr/bin/command e NÃO existe em Debian — o CI é Linux; nota em w180:217). Em vez disso, um
# diretório de symlinks para tudo que está no PATH MENOS os executáveis de Node.
NB="$T/nonode-bin"; mkdir -p "$NB"
IFS=':' read -ra _pathdirs <<< "$PATH"
for d in "${_pathdirs[@]}"; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do
    [ -x "$f" ] && [ ! -d "$f" ] || continue
    b="${f##*/}"   # expansão do próprio bash: `basename` aqui seriam milhares de forks
    case "$b" in node|nodejs|npm|npx|corepack|yarn|pnpm) continue ;; esac
    [ -e "$NB/$b" ] || ln -s "$f" "$NB/$b" 2>/dev/null || true
  done
done
if PATH="$NB" bash -c 'command -v node >/dev/null 2>&1'; then
  echo "SKIP [6b]: não consegui montar um PATH sem 'node' — [6a] já cobre o predicado (leitor indisponível)"
else
  R6b="$(_fixture nonode "$GB_SEQ_NAMED")"
  rc6b=0
  _run_to 180 -- env PATH="$NB" git -C "$R6b" push origin main > "$T/out.txt" 2>&1 || rc6b=$?
  # `rc != 0` mais um `BLOQUEADO` qualquer NÃO prova esta guarda, e a medição o mostra: com o
  # `pre-push` de `origin/develop` — que NÃO tem guarda de leitor alguma — este mesmo cenário
  # termina `rc=1` com `BLOQUEADO` na saída. Num harness COMPLETO sem `node`, quem bloqueia
  # primeiro é `check-ai-attribution.sh`, que invoca `node`, falha fechado e ainda reporta
  # "assinatura de IA detectada" — um diagnóstico falso, sobre um commit limpo. Uma asserção
  # satisfeita por um harness em que o mecanismo não existe é verde vacuoso, que é exatamente o
  # que a §5 desta leva proíbe.
  #
  # Então: a propriedade de fecho (o push NUNCA segue verde sem o leitor) continua cobrada; mas o
  # cenário só CONTA como prova da guarda quando a razão do bloqueio é a guarda. Quando outro
  # check se antecipa, isto é um SKIP declarado — [6a] prova a guarda pelo mesmo canal real, com
  # `node` presente e `gate-phase.mjs` ausente, e ali a mensagem é isolável.
  [ "$rc6b" -ne 0 ] || { echo "FAIL [6b]: com 'node' fora do PATH o push passou — zero gates e verde é o pior desfecho possível. Saída:"; cat "$T/out.txt"; exit 1; }
  grep -q "BLOQUEADO" "$T/out.txt" || { echo "FAIL [6b]: o push falhou sem uma linha 'BLOQUEADO' nomeando a causa — saída:"; cat "$T/out.txt"; exit 1; }
  if grep -qi "não pôde ser lida\|nao pode ser lida" "$T/out.txt"; then
    SCEN=$((SCEN + 1))
    echo "OK [6b] — sem node o bloqueio é o da guarda do leitor: $(grep -m1 'BLOQUEADO' "$T/out.txt")"
  else
    echo "SKIP [6b]: o push foi bloqueado ANTES do bloco de gates ($(grep -m1 'BLOQUEADO' "$T/out.txt")) — o cenário não isola a guarda do leitor e NÃO conta como prova dela; [6a] a prova pelo mesmo canal real."
  fi
fi
echo "OK [6] — leitor indisponível bloqueia e nomeia a causa"

echo "[7] mutação de canal — sem o hook no hooksPath, [2] volta a falhar"
R7="$(_fixture canal "$GB_SEQ_SCALAR")"
EMPTY_HOOKS="$T/hooks-vazio"; mkdir -p "$EMPTY_HOOKS"
git -C "$R7" config core.hooksPath "$EMPTY_HOOKS"
_push "$R7" || { echo "FAIL [7]: push reprovou sem hook algum — saída:"; cat "$T/out.txt"; exit 1; }
[ ! -f "$T/marker-canal" ] || { echo "FAIL [7]: o marcador apareceu SEM o hook instalado — o cenário [2] não mede o canal"; exit 1; }
# Recontrole: devolver o hooksPath faz o gate voltar a rodar. Sem isto, [7] seria satisfeito por
# um gate que nunca roda em canal nenhum.
git -C "$R7" config core.hooksPath "$R7/.forge/hooks/git"
_commit_docs "$R7" "recontrole de canal"
_push "$R7" || { echo "FAIL [7]: push reprovou no recontrole — saída:"; cat "$T/out.txt"; exit 1; }
[ -f "$T/marker-canal" ] || { echo "FAIL [7]: recontrole — com o hook de volta o gate não rodou. Saída:"; cat "$T/out.txt"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [7] — sem hook o marcador não aparece; com o hook de volta, aparece"

# ── fiação dos lints de shell no push (LDG-0069) ─────────────────────────────────────────────
# A forma proibida entra na fixture por CONCATENAÇÃO: escrita literal aqui, o cenário [14] de
# w145 (que varre tests/) acusaria este próprio arquivo.
PIPE='|'

echo "[9] push cujo diff toca um .sh com a forma proibida é BLOQUEADO"
R9="$(_fixture lints "$GB_CSV")"
printf '#!/usr/bin/env bash\nset -euo pipefail\nsed -n 1,200p "$f" %s grep -q pat || continue\n' "$PIPE" > "$R9/sujo.sh"
_commit_docs "$R9" "acrescenta script com a forma proibida"
rc9=0
_push "$R9" || rc9=$?
[ "$rc9" -ne 0 ] || { echo "FAIL [9]: push com .sh violando o lint de pipeline NÃO foi bloqueado — saída:"; cat "$T/out.txt"; exit 1; }
grep -qi "shell-pipeline" "$T/out.txt" || { echo "FAIL [9]: o bloqueio não nomeia o lint que reprovou — saída:"; cat "$T/out.txt"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [9] — $(grep -m1 -i 'BLOQUEADO' "$T/out.txt")"

echo "[10] push cujo diff não toca .sh nenhum não paga o custo do lint"
git -C "$R9" rm -q "$R9/sujo.sh"
_commit_docs "$R9" "remove o script sujo"
_push "$R9" || { echo "FAIL [10]: push de limpeza reprovou — saída:"; cat "$T/out.txt"; exit 1; }
_commit_docs "$R9" "so documentacao"
_push "$R9" || { echo "FAIL [10]: push só de .md reprovou — saída:"; cat "$T/out.txt"; exit 1; }
# Sinal POSITIVO, nunca a mera ausência: o hook declara que examinou zero .sh e por isso pulou.
grep -qi "shell-lints" "$T/out.txt" || { echo "FAIL [10]: o hook não disse nada sobre os lints de shell — 'não rodei' e 'rodei e passou' colapsam. Saída:"; cat "$T/out.txt"; exit 1; }
grep -qi "0 arquivo(s) .sh\|nenhum .sh" "$T/out.txt" || { echo "FAIL [10]: o hook não declarou que o diff não trouxe .sh — saída:"; cat "$T/out.txt"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [10] — $(grep -m1 -i 'shell-lints' "$T/out.txt")"

echo "[11] check-heredoc-hash.sh ausente com .forge/scripts/ presente BLOQUEIA o push"
R11="$(_fixture lintausente "$GB_CSV")"
rm -f "$R11/.forge/scripts/check-heredoc-hash.sh"
printf '#!/usr/bin/env bash\nset -euo pipefail\necho limpo\n' > "$R11/limpo.sh"
_commit_docs "$R11" "publica um .sh com o lint de heredoc ausente"
rc11=0
_push "$R11" || rc11=$?
[ "$rc11" -ne 0 ] || { echo "FAIL [11]: lint declarado e ausente não bloqueou — delegação em alvo ausente virou no-op. Saída:"; cat "$T/out.txt"; exit 1; }
grep -q "check-heredoc-hash" "$T/out.txt" || { echo "FAIL [11]: o bloqueio não nomeia o alvo ausente — saída:"; cat "$T/out.txt"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [11] — $(grep -m1 'BLOQUEADO' "$T/out.txt")"

echo "[8] contador de controle — zero cenário executado reprova"
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w190/cenarios" "$SCEN" "cenário(s) de push" "canal real (git push)" "$WS" \
  || { echo "FAIL [8]: nenhum cenário executado"; exit 1; }
set +e
out8="$(forge_universe_check "w190/cenarios" 0 "cenário(s) de push" "contrapositiva" "$WS" 2>&1)"; rc8=$?
set -e
[ "$rc8" -ne 0 ] || { echo "FAIL [8]: universo vazio aprovou — got: $out8"; exit 1; }
echo "OK [8]"

echo "PASS w190-pre-push-gate-reader"
