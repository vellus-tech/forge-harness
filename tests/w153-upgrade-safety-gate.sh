#!/usr/bin/env bash
# Gate W153 — segurança do caminho de UPGRADE (issues #71 a #77).
#
# Sete defeitos de uma classe só: o `update` é a única operação do harness que roda numa árvore que
# alguém já customizou, e cinco destes sete causam dano no PRIMEIRO uso depois dele. A classe é
# perigosa porque maquinaria não é revisada — ninguém lê diff de hook depois de um upgrade — e
# porque o dano aparece longe da causa: um push bloqueado, um AGENTS.md que deixou de ser lido, uma
# worktree que sumiu.
#
#  [71] templates/ é enriquecível: o AGENTS.md customizado do consumidor sobrevive ao update
#  [72] post-merge PROPÕE remoção em vez de executar; e nunca remove worktree com arquivo ignorado
#  [73] o template ENTREGA scripts/tests/run-all.sh — o pre-push bloqueia por sua ausência
#  [74] doctor VERIFICA encadeamento em hooksPath customizado, e nomeia os gates órfãos
#  [75] heavy_mutex.root existe no forge.yaml e no schema, com precedência env > yaml > /tmp
#  [76] a varredura de gates exclui .forge.bak-*, que o próprio update cria
#  [77] update acrescentando `secrets` a forge.yaml EXISTENTE escreve warn, não block
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$WS/bin/forge.mjs"
T="$(mktemp -d /tmp/forge-w153.XXXXXX)"
trap 'rm -rf "$T"' EXIT
GATE_START="$(date +%s)"; GATE_BUDGET_S="${W153_BUDGET_S:-240}"
SCENARIOS_RUN=0
scenario() { SCENARIOS_RUN=$((SCENARIOS_RUN + 1)); echo "$1"; }

# Consumidor sintético: repo git com .forge instalado a partir do template, como o update encontra.
consumidor() {  # consumidor [versão-lock] -> ecoa <dir>
  local d; d="$(mktemp -d "$T/cons.XXXXXX")"
  git init -q "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/.forge"
  cp -R "$WS/template/.forge/." "$d/.forge/" 2>/dev/null || true
  ( cd "$d" && git add -A >/dev/null 2>&1 && git commit -qm base >/dev/null 2>&1 )
  printf '%s\n' "$d"
}

scenario "[71] templates/ é enriquecível: o AGENTS.md customizado sobrevive ao update"
# COMPORTAMENTAL: a versão textual sobrevivia a `isEnrichable => false`, que mata o mecanismo
# inteiro mantendo a string na lista. Testar a lista é testar a grafia; o que importa é o arquivo
# sobreviver ao update — e `.forge/templates/AGENTS.md` é a FONTE do AGENTS.md da raiz, que o
# sync-adapters regenera no fim do próprio update.
D71="$(mktemp -d "$T/e71.XXXXXX")"
git init -q "$D71"; git -C "$D71" config user.email t@t; git -C "$D71" config user.name t
node "$FORGE" init --target "$D71" --no-plugin >/dev/null 2>&1
printf 'MARCA-LOCAL-TEMPLATES\n' >> "$D71/.forge/templates/AGENTS.md"
printf 'MARCA-LOCAL-RULES\n' >> "$D71/.forge/rules/README.md"
printf 'MARCA-LOCAL-RUNNER\n' >> "$D71/.forge/scripts/tests/run-all.sh"
( cd "$D71" && git add -A >/dev/null 2>&1 && git commit -qm base >/dev/null 2>&1 )
node "$FORGE" update --target "$D71" --no-plugin --source "$WS/template/.forge" >/dev/null 2>&1
grep -q 'MARCA-LOCAL-TEMPLATES' "$D71/.forge/templates/AGENTS.md" \
  || { echo "FAIL [71]: a customização de templates/AGENTS.md foi apagada pelo update — e é dela que o AGENTS.md da raiz é gerado, então as regras que alguém escreveu deixam de ser lidas sem uma linha de aviso"; exit 1; }
grep -q 'MARCA-LOCAL-RUNNER' "$D71/.forge/scripts/tests/run-all.sh" \
  || { echo "FAIL [71]: o runner customizado do consumidor foi sobrescrito — é a perda silenciosa desta issue cometida pela correção da #73, e o alvo é real: um consumidor tem um run-all.sh próprio que cobre suítes que o padrão do template não casa"; exit 1; }
grep -q 'MARCA-LOCAL-RULES' "$D71/.forge/rules/README.md" \
  || { echo "FAIL [71]: o CONTROLE falhou — rules/ já era preservado antes desta issue; se ele quebrou, o defeito é outro"; exit 1; }
echo "OK [71]"

scenario "[72] post-merge PROPÕE em vez de remover, e nunca toca worktree com arquivo ignorado"
# COMPORTAMENTAL, não textual. A primeira versão deste cenário fazia `grep` por
# FORGE_WORKTREE_AUTOCLEAN e por `clean -ndX`, e sobrevivia a QUALQUER mutação — porque casava o
# COMENTÁRIO que explica a correção, não a correção. Um teste que lê a documentação do próprio
# código não testa o código.
PM="$WS/template/.forge/hooks/git/post-merge"
lab72() {  # lab72 -> ecoa <dir>: tronco com uma worktree JÁ MERGEADA
  local d; d="$(mktemp -d "$T/pm.XXXXXX")"
  git init -q "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  git -C "$d" config commit.gpgsign false
  printf 'x\n' > "$d/a.txt"; git -C "$d" add -A; git -C "$d" commit -qm base
  printf 'build/\nlocal.properties\n' > "$d/.gitignore"; git -C "$d" add -A; git -C "$d" commit -qm ign
  git -C "$d" checkout -q -b feat-mergeada
  printf 'y\n' > "$d/b.txt"; git -C "$d" add -A; git -C "$d" commit -qm feat
  git -C "$d" checkout -q master 2>/dev/null || git -C "$d" checkout -q main
  git -C "$d" merge -q --no-ff feat-mergeada -m merge
  mkdir -p "$d/.forge/worktrees"
  git -C "$d" worktree add -q "$d/.forge/worktrees/wt" feat-mergeada 2>/dev/null
  printf '%s\n' "$d"
}
# (a) DEFAULT: propõe, não remove.
L72="$(lab72)"
( cd "$L72" && bash "$PM" >/dev/null 2>&1 )
[ -d "$L72/.forge/worktrees/wt" ] \
  || { echo "FAIL [72]: o post-merge REMOVEU a worktree no default — o default tem de propor. Reverter em silêncio a decisão de quem desligou é o que o overlay do update fazia, e ninguém revisa diff de maquinaria depois de um upgrade"; exit 1; }
out72="$( cd "$L72" && bash "$PM" 2>&1 )"
grep -qiE 'propo|proponho' <<<"$out72" \
  || { echo "FAIL [72]: não propôs nada — silêncio faz a worktree mergeada acumular sem ninguém saber: $out72"; exit 1; }
# (b) OPT-IN liga a remoção (senão o default seria inércia, não escolha).
L72b="$(lab72)"
( cd "$L72b" && FORGE_WORKTREE_AUTOCLEAN=1 bash "$PM" >/dev/null 2>&1 )
[ ! -d "$L72b/.forge/worktrees/wt" ] \
  || { echo "FAIL [72]: com FORGE_WORKTREE_AUTOCLEAN=1 a worktree NÃO foi removida — o opt-in é inerte, e um default que não se pode desligar do outro lado não é default, é imposição"; exit 1; }
# (c) A GUARDA: com arquivo IGNORADO presente, nem o opt-in remove. É o cerne do incidente —
# `git status --porcelain` não vê ignorado, então a worktree parece limpa e leva junto o que
# ninguém consegue recuperar.
L72c="$(lab72)"
printf 'sdk.dir=/opt/android\n' > "$L72c/.forge/worktrees/wt/local.properties"
mkdir -p "$L72c/.forge/worktrees/wt/build" && printf 'bin\n' > "$L72c/.forge/worktrees/wt/build/out.o"
[ -z "$(git -C "$L72c/.forge/worktrees/wt" status --porcelain)" ] \
  || { echo "FAIL [72]: o laboratório não reproduziu 'limpa para o git, suja no disco' — sem isso o cenário não mede a guarda"; exit 1; }
out72c="$( cd "$L72c" && FORGE_WORKTREE_AUTOCLEAN=1 bash "$PM" 2>&1 )"
[ -d "$L72c/.forge/worktrees/wt" ] && [ -f "$L72c/.forge/worktrees/wt/local.properties" ] \
  || { echo "FAIL [72]: worktree com arquivo IGNORADO foi removida mesmo com a guarda — é exatamente o incidente medido em campo, onde sumiram local.properties e build/ de uma worktree que o git considerava limpa: $out72c"; exit 1; }
grep -qi 'ignorado' <<<"$out72c" \
  || { echo "FAIL [72]: a guarda impediu a remoção mas não DISSE por quê — o operador precisa saber que o motivo é arquivo ignorado, senão parece que o hook falhou: $out72c"; exit 1; }
echo "OK [72]"

scenario "[73] o template entrega scripts/tests/run-all.sh"
RUNNER="$WS/template/.forge/scripts/tests/run-all.sh"
[ -f "$RUNNER" ] \
  || { echo "FAIL [73]: o template NÃO entrega scripts/tests/run-all.sh, e o pre-push que ele instala BLOQUEIA quando o diretório existe sem o runner — o upgrade instala o hook e não instala o arquivo que o desbloquearia"; exit 1; }
# E o runner não pode ser um falso verde: sem nenhum teste, tem de DIZER que examinou zero.
out73="$(cd "$T" && mkdir -p vazio && bash "$RUNNER" --path "$T/vazio" 2>&1)"; rc73=$?
[ "$rc73" -eq 0 ] \
  || { echo "FAIL [73]: o runner reprova num diretório sem testes (rc $rc73) — isso reintroduz o bloqueio que a issue relata: $out73"; exit 1; }
grep -qE '0 ' <<<"$out73" \
  || { echo "FAIL [73]: o runner não diz QUANTOS arquivos examinou — 'não rodou' e 'rodou e passou' terminando iguais é o defeito canônico deste repositório: $out73"; exit 1; }
# A capacidade de REPROVAR não estava coberta: um runner que conte PASS sempre, ou que saia 0
# sempre, passava por "existe o arquivo" e "diretório vazio sai zero". Runner que nunca reprova é a
# guarda-que-ninguém-roda da issue #49 com outro nome.
DT="$(mktemp -d "$T/rn.XXXXXX")"
printf 'process.exit(0)\n' > "$DT/ok.test.mjs"; printf 'process.exit(1)\n' > "$DT/mau.test.mjs"
bash "$RUNNER" --path "$DT" >/dev/null 2>&1 \
  && { echo "FAIL [73]: o runner PASSOU com um teste que falha — nunca reprovar é o mesmo que não rodar"; exit 1; }
o73b="$(bash "$RUNNER" --path "$DT" 2>&1)"
grep -q 'PASS=1' <<<"$o73b" && grep -q 'FAIL=1' <<<"$o73b" \
  || { echo "FAIL [73]: o runner não contou 1 que passou e 1 que falhou: $o73b"; exit 1; }
# Varredura que FALHA não pode sair verde: "não consegui ler" e "não há testes" no mesmo lugar é a
# vacuidade contra a qual este arquivo se anuncia como antídoto.
DE="$(mktemp -d "$T/rerr.XXXXXX")"; mkdir -p "$DE/sub"; printf 'process.exit(0)\n' > "$DE/sub/a.test.mjs"
chmod 000 "$DE/sub"
bash "$RUNNER" --path "$DE" >/dev/null 2>&1 \
  && { chmod 755 "$DE/sub"; echo "FAIL [73]: varredura ILEGÍVEL saiu verde — o resultado seria sobre universo incompleto e ninguém saberia"; exit 1; }
chmod 755 "$DE/sub"
echo "OK [73]"

scenario "[74] doctor verifica encadeamento em hooksPath customizado e nomeia gates órfãos"
# Fixture com `init` COMPLETO, de propósito. A versão anterior copiava dois `check-*.sh` para o
# consumidor, fabricando um universo de gates artificialmente reduzido no qual o estado `ok` era
# fácil — a mesma classe do fixture do w146 que este PR corrige, só que na direção oposta: em vez
# de testar o estado bom, construía um mundo onde o estado bom existe.
lab74() {  # lab74 <corpo-do-hook> [readme] -> ecoa <dir>
  local d; d="$(mktemp -d "$T/dr.XXXXXX")"
  git init -q "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  node "$FORGE" init --target "$d" --no-plugin >/dev/null 2>&1
  mkdir -p "$d/.githooks"; printf '#!/bin/sh\n%s\n' "$1" > "$d/.githooks/pre-push"; chmod +x "$d/.githooks/pre-push"
  [ -n "${2:-}" ] && printf '%s\n' "$2" > "$d/.githooks/README.md"
  git -C "$d" config core.hooksPath "$d/.githooks"
  printf '%s\n' "$d"
}
roda74() { ( cd "$1" && bash .forge/scripts/doctor.sh 2>&1 | grep -i 'hookspath' | head -1 ); }
# (a) DELEGAÇÃO é cobertura completa. É o que a própria hint manda fazer, e exigir cada gate
# nominalmente tornava o estado `ok` inalcançável pelo caminho recomendado — aviso que não some
# quando o problema some é ruído, e ruído é o que ensina a ignorar aviso.
o74a="$(roda74 "$(lab74 'exec .forge/hooks/git/pre-push "$@"')")"
grep -q '✓' <<<"$o74a" \
  || { echo "FAIL [74]: delegação canônica para .forge/hooks/git/ não foi reconhecida como cobertura — é exatamente o que a hint do doctor manda fazer: $o74a"; exit 1; }
grep -qi 'delega' <<<"$o74a" \
  || { echo "FAIL [74]: a linha não diz que a cobertura vem da DELEGAÇÃO — um ✓ genérico não distingue delegação de encadeamento nominal, e o operador não sabe o que precisa preservar ao mexer no hook: $o74a"; exit 1; }
# (b) NENHUMA referência é DEFEITO, e um README citando o caminho não pode promover árvore inerte.
o74b="$(roda74 "$(lab74 'echo nada' 'Veja .forge/hooks/git/ e o check-secrets.sh')")"
grep -q '✗' <<<"$o74b" \
  || { echo "FAIL [74]: árvore 100% inerte com um README citando o caminho saiu como algo melhor que defeito — documentação não executa hook: $o74b"; exit 1; }
# (c) PARCIAL nomeia os órfãos. É o caso mais provável e o único com informação acionável.
o74c="$(roda74 "$(lab74 'bash .forge/scripts/check-secrets.sh')")"
grep -q '!' <<<"$o74c" && grep -qE 'check-[a-z-]+\.sh' <<<"$o74c" \
  || { echo "FAIL [74]: encadeamento PARCIAL não foi reportado com a lista de gates que ninguém invoca: $o74c"; exit 1; }
grep -q 'check-secrets.sh' <<<"$o74c" \
  && { echo "FAIL [74]: o gate que ESTÁ encadeado apareceu na lista de órfãos: $o74c"; exit 1; }
echo "OK [74]"

scenario "[75] heavy_mutex.root existe, com precedência env > forge.yaml > /tmp"
# COMPORTAMENTAL: a versão textual (`grep '_fhm_yaml_root'`) sobrevivia à função virar no-op.
LIB="$WS/template/.forge/scripts/lib/heavy-mutex.sh"
r75() {  # r75 <valor-de-root> -> ecoa "<rc>|<root-resolvida>|<proveniência>"
  local B; B="$(mktemp -d "$T/hm.XXXXXX")"; mkdir -p "$B/.forge"
  if [ -n "$1" ]; then printf 'heavy_mutex:\n  enabled: true\n  root: %s\n' "$1" > "$B/.forge/forge.yaml"
  else printf 'heavy_mutex:\n  enabled: true\n' > "$B/.forge/forge.yaml"; fi
  local o rc; o="$(FORGE_ROOT="$B" bash -c '. "$0"; _fhm_resolve_root' "$LIB" 2>&1)"; rc=$?
  printf '%s|%s\n' "$rc" "$(printf '%s' "$o" | tr '\t' '|' | head -1)"
}
CONV="$T/conv75"; mkdir -p "$CONV"
out75="$(r75 "$CONV")"
grep -q "$CONV" <<<"$out75" \
  || { echo "FAIL [75]: a raiz declarada em heavy_mutex.root NÃO foi usada — sem ela um host com N repositórios já serializados não migra UM de cada vez, porque o primeiro a migrar parte a exclusão de todos os outros e cada lado adquire o próprio lock ACREDITANDO estar protegido: $out75"; exit 1; }
grep -qi 'convergência\|convergencia' <<<"$out75" \
  || { echo "FAIL [75]: a proveniência não distingue a raiz do YAML da variável de ambiente — a env significa ISOLAMENTO e a chave significa CONVERGÊNCIA, e reportar as duas igual faz o recibo mentir sobre o que está acontecendo: $out75"; exit 1; }
# `/tmp` é o default DOCUMENTADO e é symlink no macOS: recusá-lo seria recusar o próprio default.
out75b="$(r75 "/tmp")"
grep -q '^0|' <<<"$out75b" \
  || { echo "FAIL [75]: declarar root: /tmp — o valor que a documentação chama de default — foi RECUSADO: $out75b"; exit 1; }
# Valor inválido não pode ser descartado em silêncio: seria a partição silenciosa que esta issue
# existe para impedir, produzida pelo mecanismo dela.
out75c="$(r75 "relativo/x")"
grep -qi 'inválido\|invalido' <<<"$out75c" \
  || { echo "FAIL [75]: root relativo foi descartado SEM aviso — o operador declara a raiz de convergência, o recibo diz outra coisa, e ninguém sabe: $out75c"; exit 1; }
# CONTROLE: sem a chave, o default continua valendo.
out75d="$(r75 "")"
grep -q '/tmp' <<<"$out75d" \
  || { echo "FAIL [75]: sem a chave o default /tmp deixou de valer: $out75d"; exit 1; }
echo "OK [75]"

scenario "[76] a varredura de gates exclui .forge.bak-*"
# COMPORTAMENTAL, com controle na mesma execução. A versão textual (`grep -rln 'forge.bak' lib/`)
# aprovava com os COMENTÁRIOS e sobrevivia a remover o padrão da lista de exclusão — o que é o
# mesmo defeito que este PR corrige em outros três cenários.
D76="$(mktemp -d "$T/e76.XXXXXX")"
git init -q "$D76"; git -C "$D76" config user.email t@t; git -C "$D76" config user.name t
node "$FORGE" init --target "$D76" --no-plugin >/dev/null 2>&1
( cd "$D76" && bash .forge/scripts/check-data-governance.sh --path . >/dev/null 2>&1 ) \
  || { echo "FAIL [76]: o CONTROLE falhou — consumidor recém-instalado já reprova SEM backup nenhum, então o cenário não distinguiria a presença do backup de qualquer outra causa"; exit 1; }
cp -R "$D76/.forge" "$D76/.forge.bak-1"
( cd "$D76" && bash .forge/scripts/check-data-governance.sh --path . >/dev/null 2>&1 ) \
  || { echo "FAIL [76]: com .forge.bak-1 presente o gate REPROVA — é o falso positivo self-referencial medido em campo, e a instrução do próprio update é manter o backup até validar, então o caminho RECOMENDADO é o que produz o bloqueio"; exit 1; }
echo "OK [76]"

scenario "[77] update acrescentando 'secrets' a forge.yaml existente escreve warn, não block"
# O comentário do bloco no template já documentava a regra: `block` é o modo de repositório novo
# ou já saneado, e um repositório existente "HERDA warn ao atualizar". O mecanismo que deveria
# produzir esse warn pela AUSÊNCIA do bloco era justamente o que criava o bloco, com block dentro.
D77="$(mktemp -d "$T/sec.XXXXXX")"
git init -q "$D77"; git -C "$D77" config user.email t@t; git -C "$D77" config user.name t
mkdir -p "$D77/.forge"; cp -R "$WS/template/.forge/." "$D77/.forge/" 2>/dev/null || true
python3 - "$D77/.forge/forge.yaml" <<'PY'
import io,sys
p=sys.argv[1]; s=io.open(p,encoding='utf-8').read()
i=s.index('\nsecrets:'); j=s.index('\nautonomy:')
io.open(p,'w',encoding='utf-8').write(s[:i]+s[j:])
PY
[ "$(grep -c '^secrets:' "$D77/.forge/forge.yaml")" -eq 0 ] \
  || { echo "FAIL [77]: o laboratório não removeu o bloco secrets — sem um repositório SEM o bloco não há o que medir"; exit 1; }
( cd "$D77" && git add -A >/dev/null 2>&1 && git commit -qm base >/dev/null 2>&1 )
out77="$( cd "$D77" && node "$FORGE" update 2>&1 )"
enf77="$(grep -A25 '^secrets:' "$D77/.forge/forge.yaml" | grep -m1 -E '^[[:space:]]*enforce:' | tr -d ' ')"
[ "$enf77" = "enforce:warn" ] \
  || { echo "FAIL [77]: repositório EXISTENTE recebeu '$enf77' — um repo com passivo passa a reprovar no pre-commit assim que qualquer arquivo antigo for tocado, e o autor não fez nada errado nem sabe que a política mudou, porque veio embutida num upgrade de maquinaria"; exit 1; }
grep -qiE 'warn' <<<"$out77" \
  || { echo "FAIL [77]: a mudança de política entrou EM SILÊNCIO — é preciso ler o YAML gerado para descobrir que um bloco passou a bloquear algo que antes não bloqueava"; exit 1; }
# CONTROLE: o template continua entregando `block`, que é o certo para repositório NOVO (init).
tpl77="$(grep -A25 '^secrets:' "$WS/template/.forge/forge.yaml" | grep -m1 -E '^[[:space:]]*enforce:' | tr -d ' ')"
[ "$tpl77" = "enforce:block" ] \
  || { echo "FAIL [77]: o template deixou de entregar block ('$tpl77') — amaciar o APPEND não pode amaciar o init: projeto que nasce com o harness nasce sem passivo"; exit 1; }
echo "OK [77]"

GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: ${GATE_ELAPSED}s acima do teto de ${GATE_BUDGET_S}s"; exit 1; }
echo "PASS w153-upgrade-safety ($SCENARIOS_RUN cenário(s), ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
