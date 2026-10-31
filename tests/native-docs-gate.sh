#!/usr/bin/env bash
# ORDINAL: wNNN atribuído na hora do merge
# Gate vermelho/verde da documentação operacional da mensageria nativa (REQ-10, REQ-11, design §4.5, §5).
#
#   [1] `argument-hint` de /forge:liaison (template) lista os subcomandos novos (notify, native).
#   [2]..[N] para cada subcomando novo ou alterado, o CONJUNTO de flags no bloco de protocolo de
#       liaison.md é IGUAL ao conjunto de flags aceitas pelo script (liaison-ops.sh), extraído da
#       própria variável *_FLAGS que o script usa para validar/recusar flag desconhecida — nunca
#       hardcoded duas vezes.
#   [N+1] o exemplo de `send --via cross-session` na doc mostra só `--native-ref`/`--session`/
#       `--via`, sem nenhuma flag de origem (`--authored-by` ausente).
#   [N+2] docs/refer/slash-commands.md descreve os subcomandos novos.
#   [N+3] CHANGELOG.md ([Unreleased]) traz o passo de armar do design §5, literal.
#   [N+4] template/.forge/commands/harness/upgrade.md e plugin/forge/commands/upgrade.md trazem
#       o mesmo passo (os três — CHANGELOG, upgrade template, upgrade plugin — citam a MESMA
#       frase, para não divergir).
#   [N+5] o ponteiro canônico (primeira linha do corpo do SendMessage) está documentado.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIAISON_MD="$WS/template/.forge/commands/harness/liaison.md"
LIAISON_OPS="$WS/template/.forge/scripts/liaison-ops.sh"
SLASH_MD="$WS/docs/refer/slash-commands.md"
CHANGELOG="$WS/CHANGELOG.md"
UPGRADE_TPL="$WS/template/.forge/commands/harness/upgrade.md"
UPGRADE_PLUGIN="$WS/plugin/forge/commands/upgrade.md"

n=0
overall_rc=0
ok() { n=$((n + 1)); echo "OK [$n] $1"; }
fail() { n=$((n + 1)); echo "FAIL [$n]: $1"; overall_rc=1; }

for f in "$LIAISON_MD" "$LIAISON_OPS" "$SLASH_MD" "$CHANGELOG" "$UPGRADE_TPL" "$UPGRADE_PLUGIN"; do
  [ -f "$f" ] || { fail "arquivo ausente: $f (argument-hint|flags|CHANGELOG|slash-commands|upgrade)"; }
done
[ "$overall_rc" -eq 0 ] || exit 1

# [1] argument-hint lista os subcomandos novos
hint="$(sed -n 's/^argument-hint: "\(.*\)"$/\1/p' "$LIAISON_MD" | head -1)"
if printf '%s' "$hint" | grep -q 'notify' && printf '%s' "$hint" | grep -q 'native'; then
  ok "argument-hint lista notify e native"
else
  fail "argument-hint não lista notify/native: '$hint' (argument-hint)"
fi

# _script_flags <VARNAME> — extrai o conjunto (um por linha, ordenado) de VARNAME="--a, --b, ..."
_script_flags() {
  local var="$1" raw
  raw="$(grep -oE "${var}=\"[^\"]*\"" "$LIAISON_OPS" | head -1 | sed -E "s/^${var}=\"//; s/\"\$//")"
  if [ -z "$raw" ]; then
    echo ""
    return
  fi
  printf '%s' "$raw" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | sort | tr '\n' ' ' | sed 's/ $//'
}

# _doc_flags <linha-de-comando> — extrai tokens --xxx da linha, ordenado
_doc_flags() {
  printf '%s' "$1" | grep -oE -- '--[a-z-]+' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

# _linha_do_subcomando <marcador> — a linha "bash .forge/scripts/liaison-ops.sh <marcador> ..."
_linha_do_subcomando() {
  grep -F "liaison-ops.sh $1" "$LIAISON_MD" | head -1
}

_confere_subcomando() {
  local rotulo="$1" var="$2"
  local linha esperado obtido
  linha="$(_linha_do_subcomando "$rotulo")"
  if [ -z "$linha" ]; then
    fail "doc não tem exemplo de '$rotulo' em liaison.md (flags)"
    return
  fi
  esperado="$(_script_flags "$var")"
  obtido="$(_doc_flags "$linha")"
  if [ "$esperado" = "$obtido" ]; then
    ok "flags de '$rotulo' na doc == flags aceitas pelo script ('$obtido')"
  else
    fail "flags de '$rotulo' divergem — doc='$obtido' script(\$$var)='$esperado' (flags)"
  fi
}

_confere_subcomando "notify" "NOTIFY_FLAGS"
_confere_subcomando "native check" "NATIVE_CHECK_FLAGS"
_confere_subcomando "native dispose" "NATIVE_DISPOSE_FLAGS"
_confere_subcomando "native allow" "NATIVE_ALLOW_FLAGS"
_confere_subcomando "native revoke" "NATIVE_REVOKE_FLAGS"
_confere_subcomando "native pin" "NATIVE_PIN_FLAGS"
_confere_subcomando "native containment" "NATIVE_CONTAINMENT_FLAGS"

# send --via cross-session: só --native-ref/--session/--via, sem flag de origem
linha_cs="$(grep -F "liaison-ops.sh send" "$LIAISON_MD" | grep -F "cross-session" | head -1)"
if [ -z "$linha_cs" ]; then
  fail "doc não tem exemplo de 'send --via cross-session' em liaison.md (flags)"
else
  flags_cs="$(_doc_flags "$linha_cs")"
  if printf '%s' "$flags_cs" | grep -q -- '--authored-by'; then
    fail "'send --via cross-session' na doc mostra flag de origem (--authored-by) — esperado só --native-ref/--session/--via (flags)"
  elif printf '%s' "$flags_cs" | grep -q -- '--native-ref' && printf '%s' "$flags_cs" | grep -q -- '--session' && printf '%s' "$flags_cs" | grep -q -- '--via'; then
    ok "'send --via cross-session' na doc mostra só --native-ref/--session/--via ('$flags_cs')"
  else
    fail "'send --via cross-session' na doc não mostra --native-ref/--session/--via — obtido '$flags_cs' (flags)"
  fi
fi

# docs/refer/slash-commands.md descreve os subcomandos novos
linha_slash="$(grep -F '/forge:liaison' "$SLASH_MD" | head -1)"
if [ -z "$linha_slash" ]; then
  fail "docs/refer/slash-commands.md não tem linha de /forge:liaison (slash-commands)"
elif printf '%s' "$linha_slash" | grep -qi 'notify' && printf '%s' "$linha_slash" | grep -qi 'native'; then
  ok "docs/refer/slash-commands.md descreve notify/native"
else
  fail "docs/refer/slash-commands.md não descreve os subcomandos novos (notify/native) (slash-commands)"
fi

# CHANGELOG.md [Unreleased] traz o passo de armar (design §5), literal
PASSO_ARMAR_MARCA="(1) rode \`/forge:doctor\`"
PASSO_ARMAR_MARCA5="(5) commite \`hooks.manifest\`"
if grep -qF "$PASSO_ARMAR_MARCA" "$CHANGELOG" && grep -qF "$PASSO_ARMAR_MARCA5" "$CHANGELOG"; then
  ok "CHANGELOG.md [Unreleased] traz o passo de armar do design §5"
else
  fail "CHANGELOG.md não traz o passo de armar literal (procurado: '$PASSO_ARMAR_MARCA' ... '$PASSO_ARMAR_MARCA5') (CHANGELOG)"
fi

for arq_up in "$UPGRADE_TPL" "$UPGRADE_PLUGIN"; do
  if grep -qF "$PASSO_ARMAR_MARCA" "$arq_up" && grep -qF "$PASSO_ARMAR_MARCA5" "$arq_up"; then
    ok "$(basename "$(dirname "$arq_up")")/$(basename "$arq_up") traz o passo de armar"
  else
    fail "$(basename "$(dirname "$arq_up")")/$(basename "$arq_up") não traz o passo de armar literal (upgrade)"
  fi
done

# ponteiro canônico na primeira linha do corpo do SendMessage — documentado
if grep -qF "primeira linha" "$LIAISON_MD" && grep -qF "liaison:<channel>/<msg_id>" "$LIAISON_MD"; then
  ok "ponteiro canônico na primeira linha do SendMessage está documentado"
else
  fail "ponteiro canônico na primeira linha do SendMessage NÃO documentado em liaison.md (argument-hint|flags)"
fi

exit "$overall_rc"
