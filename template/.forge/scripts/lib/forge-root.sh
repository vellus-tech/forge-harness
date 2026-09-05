#!/usr/bin/env bash
# lib/forge-root.sh — resolução do CHECKOUT PRINCIPAL e visibilidade da divergência (LDG-0068).
#
# Estado durável de PROJETO (ledger, liaison) mora no tronco, nunca na branch. `--git-common-dir`
# devolve o `.git` compartilhado por TODOS os worktrees; o diretório que o contém é o tronco.
# `--path-format=absolute` é necessário porque, no próprio checkout principal, `--git-common-dir`
# devolveria `.git` relativo — e `dirname .git` daria `.`, que é justamente o worktree corrente
# que se quer evitar.
#
# Isto é NORMA, escrita em `rules/conventions/machinery-propagation.md`, e não muda: um registro
# feito de dentro de um worktree que nascesse no `ledger.json` daquela branch faria toda branch
# que toca o ledger colidir por construção no merge. Medido em `axis-go-cloud` (cinco
# reconciliações num único dia) e em `axis-fare-validator` (dez entradas presas numa branch de
# feature, duas delas normas de processo, invisíveis para o resto do repositório até o PR mergear).
#
# O que ESTE arquivo acrescenta é a metade que faltava: **dizer em voz alta**. Quem opera de dentro
# de uma worktree escrevia no ledger do tronco — que pode estar noutra branch — e nada avisava,
# nem obrigava. O comportamento continua o mesmo; a diferença é que ele passa a ser observável.
#
# Um lugar só, consumido pelos quatro scripts que copiavam `_forge_main_root()` corpo idêntico
# (`ledger-ops.sh`, `liaison-ops.sh`, `check-liaison-acks.sh`, `check-liaison-log-integrity.sh`).
# Escrever o aviso quatro vezes reinstalaria `LDG-0014` — duas implementações do mesmo contrato
# divergindo em silêncio — dentro do change que existe para combater essa classe.

# forge_main_root — ecoa o caminho absoluto do checkout principal; rc 1 quando não dá para saber.
forge_main_root() {
  local common
  common="$(git -C "$(pwd)" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ -n "$common" ] || return 1
  case "$common" in /*) : ;; *) return 1 ;; esac
  dirname "$common"
}

# forge_resolve_root — a resolução completa, com os mesmos fallbacks de sempre.
forge_resolve_root() {
  if [ -n "${FORGE_ROOT:-}" ]; then printf '%s\n' "$FORGE_ROOT"; return 0; fi
  forge_main_root || git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd
}

# forge_warn_root_divergence <root> <rótulo do artefato> [porta]
#
# Emite UMA linha em stderr quando o ROOT resolvido difere do repositório de trabalho de quem
# invocou. Só nas portas que ESCREVEM: quem apenas lê não está gravando nada em lugar nenhum, e um
# aviso ali seria ruído que treina o operador a ignorar a linha quando ela importa.
#
# Silencioso quando os dois coincidem: o aviso é sobre DIVERGÊNCIA, não sobre worktree. Um projeto
# que rode tudo do tronco nunca o vê.
forge_warn_root_divergence() {
  local root="$1" artefato="${2:-estado durável}" porta="${3:-}"
  # FORGE_ROOT explícito é DECLARAÇÃO, não acidente: quem o exportou já disse onde quer gravar, e
  # avisá-lo seria ruído em todo fixture, todo CI e toda invocação deliberada — ruído que treina o
  # operador a ignorar a linha justamente quando ela importa. O aviso existe para a resolução
  # AUTOMÁTICA que cai no tronco sem ninguém ter pedido.
  [ -n "${FORGE_ROOT:-}" ] && return 0
  local here
  here="$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -n "$here" ] || return 0
  [ -n "$root" ] || return 0
  # Comparação por caminho REAL: em macOS `/tmp` é symlink para `/private/tmp`, e comparar o
  # caminho lógico produziria divergência falsa em toda fixture montada sob `/tmp`.
  local rroot rhere
  rroot="$(cd "$root" 2>/dev/null && pwd -P)" || return 0
  rhere="$(cd "$here" 2>/dev/null && pwd -P)" || return 0
  [ "$rroot" = "$rhere" ] && return 0
  echo "WARN: ${porta:+$porta: }escrevendo no ledger do TRONCO, não nesta árvore de trabalho." >&2
  echo "      $artefato: $rroot" >&2
  echo "      invocado de: $rhere" >&2
  echo "      É o desenho (estado de projeto mora no tronco, não na branch — rules/conventions/machinery-propagation.md)," >&2
  echo "      e o tronco pode estar noutra branch. Para gravar NESTA árvore, exporte FORGE_ROOT=$rhere." >&2
  return 0
}
