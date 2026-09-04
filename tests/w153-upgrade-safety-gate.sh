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
# `.forge/templates/AGENTS.md` não é um template qualquer: sync-adapters o lê e gera o AGENTS.md da
# RAIZ a partir dele. Como o update roda sync-adapters no fim, um comando apagava a customização e
# regenerava o arquivo sem ela — sem conflito, sem aviso, e aparecendo no output como um `~` igual
# a qualquer atualização de maquinaria. Perder em silêncio o arquivo que governa os agentes é a
# classe de defeito mais cara: o repositório segue funcionando e as regras deixam de ser lidas.
grep -qE "^const ENRICHABLE_DIRS = \[[^]]*'templates'" "$FORGE" \
  || { echo "FAIL [71]: 'templates' não está em ENRICHABLE_DIRS — o AGENTS.md customizado do consumidor é sobrescrito e regenerado sem a customização"; exit 1; }
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
echo "OK [73]"

scenario "[74] doctor verifica encadeamento em hooksPath customizado e nomeia gates órfãos"
# Três estados que ANTES eram um só `info`. A régua já existia: a issue #41 fez o hooksPath
# relativo virar defeito porque hook que não executa é indistinguível de hook ausente — e uma
# árvore customizada sem encadeamento produz exatamente o mesmo estado.
DOC="$WS/template/.forge/scripts/doctor.sh"
lab74() {  # lab74 <conteúdo-do-hook-customizado> -> ecoa <dir>
  local d; d="$(mktemp -d "$T/dr.XXXXXX")"
  git init -q "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  mkdir -p "$d/.forge/scripts" "$d/.forge/hooks/git" "$d/.githooks"
  cp "$WS/template/.forge/scripts/doctor.sh" "$d/.forge/scripts/"
  cp "$WS/template/.forge/scripts/check-secrets.sh" "$d/.forge/scripts/" 2>/dev/null || true
  cp "$WS/template/.forge/scripts/check-ai-attribution.sh" "$d/.forge/scripts/" 2>/dev/null || true
  printf '#!/bin/sh\n%s\n' "$1" > "$d/.githooks/pre-push"; chmod +x "$d/.githooks/pre-push"
  git -C "$d" config core.hooksPath "$d/.githooks"
  printf '%s\n' "$d"
}
roda74() { ( cd "$1" && bash .forge/scripts/doctor.sh 2>&1 ); }
# (a) NENHUMA referência: é defeito, não informação.
D74="$(lab74 'echo nada a ver')"
o74="$(roda74 "$D74")"
grep -qiE '✗|miss' <<<"$(grep -i 'hookspath' <<<"$o74")" \
  || { echo "FAIL [74]: árvore customizada SEM nenhuma referência aos gates saiu como informação — 'instalei o harness, ele está inerte, e o doctor diz que está tudo bem' fica indistinguível de 'instalei e encadeei tudo': $(grep -i hookspath <<<"$o74")"; exit 1; }
# (b) PARCIAL: avisa E NOMEIA o que ninguém invoca. É o caso mais provável e o mais valioso —
# quem tem hooks próprios encadeia o que precisava no dia em que precisou, e cada upgrade
# acrescenta gates que ninguém liga.
D74b="$(lab74 'bash .forge/scripts/check-secrets.sh')"
o74b="$(roda74 "$D74b")"
grep -qi 'check-ai-attribution' <<<"$o74b" \
  || { echo "FAIL [74]: encadeamento PARCIAL não nomeou o gate órfão (check-ai-attribution.sh) — a lista do que ninguém invoca é a única informação acionável aqui, e sem ela todo update amplia em silêncio a distância entre o que o harness entrega e o que o repositório executa: $(grep -i hookspath <<<"$o74b")"; exit 1; }
# (c) COMPLETO: não pode virar ruído permanente, senão quem encadeou tudo aprende a ignorar.
D74c="$(lab74 'bash .forge/scripts/check-secrets.sh; bash .forge/scripts/check-ai-attribution.sh')"
o74c="$(roda74 "$D74c")"
grep -qi 'check-ai-attribution' <<<"$(grep -i 'hookspath\|órfão\|orfao\|parcial' <<<"$o74c")" \
  && { echo "FAIL [74]: com TUDO encadeado o doctor ainda reclama — aviso que não some quando o problema some é ruído, e ruído é o que ensina a ignorar aviso: $o74c"; exit 1; }
echo "OK [74]"

scenario "[75] heavy_mutex.root existe, com precedência env > forge.yaml > /tmp"
LIB="$WS/template/.forge/scripts/lib/heavy-mutex.sh"
grep -qE '_fhm_yaml_root|yaml.*root' "$LIB" \
  || { echo "FAIL [75]: a raiz do lock não é lida do forge.yaml — um ecossistema com protocolo legado não consegue migrar UM repositório sem partir a exclusão dos outros, e lock particionado é pior que nenhum porque parece um lock"; exit 1; }
python3 - "$WS/template/.forge/schemas/forge.schema.json" <<'PY' || exit 1
import json,sys
d=json.load(open(sys.argv[1]))
hm=d['$defs']['forgeManifest']['properties'].get('heavy_mutex',{})
if 'root' not in hm.get('properties',{}):
    print("FAIL [75]: heavy_mutex.root não está declarado no schema — chave que o código lê e o schema recusa é config que reprova o próprio template"); sys.exit(1)
PY
echo "OK [75]"

scenario "[76] a varredura de gates exclui .forge.bak-*"
SCAN="$(grep -rln 'forge.bak' "$WS/template/.forge/scripts/lib/" 2>/dev/null | head -1)"
[ -n "$SCAN" ] \
  || { echo "FAIL [76]: nenhuma biblioteca de varredura exclui .forge.bak-* — o backup que o próprio update cria é varrido pelos gates, e o primeiro push após o upgrade é bloqueado por conteúdo que é cópia do repositório"; exit 1; }
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
