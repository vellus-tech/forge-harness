#!/usr/bin/env bash
# Transporte `git` — hub numa BRANCH DEDICADA de um repositório remoto.
#
# Por que branch dedicada e não um diretório no default branch: o canal do liaison muda em ritmo
# próprio (várias mensagens por dia) e não deve poluir o histórico do código, disparar CI, nem
# entrar em PR de feature. A branch é órfã — sem ancestral comum com o código — então nunca é
# candidata a merge por engano.
#
# PLAT-204 — A BRANCH CONFIGURADA PRECISA SER DEDICADA AO LIAISON, e não só "não ser a de código":
# a varredura de SEC-001 (camada 1 em `_git_sync_clone`) olha a árvore INTEIRA da branch, sem
# pathspec, e recusa symlink (120000) ou gitlink/submódulo (160000) em QUALQUER lugar dela, não só
# abaixo de `<canal>/`. Apontar `branch` para uma branch que carregue symlink ou submódulo legítimo
# (uma branch de código, uma branch de docs com link) faz todo sync desse canal reprovar. A
# restrição é deliberada: o pathspec por canal diferencia maiúsculas e o filesystem pode não
# diferenciar, e foi por ali que `CH/blobs` escapava da varredura.
#
# O clone de trabalho vive em `.forge/cache/liaison/<channel>`, sob `cache/`, que é descartável
# por definição: apagar o cache custa um clone, nunca uma mensagem — a fonte da verdade do log
# local é `.forge/liaison/`, e a do log alheio é a branch remota.
#
# Como todo transporte, este move ARQUIVOS OPACOS: não parseia mensagem, não sabe o que é thread,
# e não decide merge. Conflito de conteúdo é resolvido pela política de import (liaison-import.mjs),
# nunca pelo git — daí o push ser sempre "reset para o remoto, reescreve o próprio arquivo,
# commita": não existe merge de branch aqui, só um diretório de arquivos por remetente.

# shellcheck source=./_common.sh
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_git_cache() { printf '%s/.forge/cache/liaison/%s' "$LIAISON_ROOT" "$LIAISON_CHANNEL"; }
_git_branch() { printf '%s' "${LIAISON_T_BRANCH:-liaison/$LIAISON_CHANNEL}"; }

# _git_descarta_arvore <cache> — apaga a árvore de trabalho do cache (tudo menos `.git`). O cache
# é descartável por desenho; descartá-lo antes do checkout garante que nenhum link materializado
# por uma versão anterior sobreviva — `checkout`/`reset --hard` não tocam arquivo não rastreado, e
# `core.symlinks=false` não reescreve uma entrada do índice que o git considera limpa.
_git_descarta_arvore() {
  find "$1" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
}

# Garante um clone de trabalho posicionado na branch do canal, sincronizado com o remoto. Se a
# branch ainda não existe lá, prepara uma órfã vazia — o primeiro push a cria.
#
# SEC-001, três camadas independentes contra symlink/submódulo publicado na branch:
#   1. varredura da árvore INTEIRA da branch dedicada (`ls-tree -r`, sem pathspec) antes do
#      checkout. Sem pathspec porque ele diferencia maiúsculas e o filesystem pode não diferenciar:
#      `CH/blobs` escapava de `-- ch` e virava `ch/blobs` no APFS/NTFS. A saída é CAPTURADA antes de
#      ser examinada, e o `awk` lê tudo: `ls-tree | awk | grep -q` dentro de `if` sob `pipefail`
#      era pulado por SIGPIPE em árvores grandes (grep sai no primeiro casamento, o produtor leva
#      SIGPIPE, o pipeline vira 141 e o `if` lê "não casou");
#   2. `core.symlinks=false`: se algo escapar da varredura, o checkout materializa o link como
#      arquivo de texto;
#   3. depois do checkout, nenhum link pode existir na árvore de trabalho — se existir, recusa e
#      descarta a árvore.
_git_sync_clone() {
  local cache branch tree links
  cache="$(_git_cache)"; branch="$(_git_branch)"
  if [ ! -d "$cache/.git" ]; then
    mkdir -p "$cache"
    git -C "$cache" init -q || return 1
    git -C "$cache" remote add origin "$LIAISON_T_REMOTE" || return 1
  fi
  git -C "$cache" remote set-url origin "$LIAISON_T_REMOTE"
  git -C "$cache" config user.email "liaison@forge.local"
  git -C "$cache" config user.name "forge-liaison"
  git -C "$cache" config commit.gpgsign false
  # Camada 2: symlink committed vira ARQUIVO DE TEXTO comum no checkout (conteúdo = destino do
  # link), nunca link real do filesystem.
  git -C "$cache" config core.symlinks false
  if git -C "$cache" fetch -q origin "$branch" 2>/dev/null; then
    _git_descarta_arvore "$cache"
    # Camada 1: falha fechada — sem conseguir listar a árvore, não há checkout.
    tree="$(git -C "$cache" ls-tree -r FETCH_HEAD)" \
      || { echo "FAIL: não foi possível listar a árvore da branch '$branch' — recusado (SEC-001: sem varredura não há checkout)." >&2; return 1; }
    if printf '%s\n' "$tree" | awk '$1=="120000"||$1=="160000"{f=1} END{exit !f}'; then
      echo "FAIL: a branch do canal '$branch' contém symlink ou submódulo — recusado (SEC-001, possível" >&2
      echo "      traversal). Não sincronize até remover o commit malicioso da branch remota e" >&2
      echo "      identificar quem o publicou." >&2
      return 1
    fi
    git -C "$cache" checkout -q -f -B "$branch" FETCH_HEAD || return 1
    git -C "$cache" reset -q --hard FETCH_HEAD || return 1
  else
    git -C "$cache" checkout -q --orphan "$branch" 2>/dev/null \
      || git -C "$cache" symbolic-ref HEAD "refs/heads/$branch" || return 1
    git -C "$cache" rm -rq --cached . 2>/dev/null || true
    _git_descarta_arvore "$cache"
  fi
  # Camada 3.
  links="$(find "$cache" -path "$cache/.git" -prune -o -type l -print)" \
    || { echo "FAIL: não foi possível varrer o cache '$cache' — recusado (SEC-001)." >&2; return 1; }
  if [ -n "$links" ]; then
    echo "FAIL: o checkout da branch '$branch' materializou link simbólico no cache — recusado (SEC-001):" >&2
    printf '      %s\n' "$links" >&2
    _git_descarta_arvore "$cache"
    return 1
  fi
  return 0
}

t_probe() {
  [ -n "${LIAISON_T_REMOTE:-}" ] || { echo "FAIL: transporte git exige 'remote' no liaison.yaml" >&2; return 1; }
  command -v git >/dev/null 2>&1 || { echo "FAIL: git não encontrado no PATH" >&2; return 1; }
  git ls-remote "$LIAISON_T_REMOTE" >/dev/null 2>&1 \
    || { echo "FAIL: remote inacessível: $LIAISON_T_REMOTE (credencial? URL?)" >&2; return 1; }
  return 0
}

t_push() {
  local cache branch hub
  _git_sync_clone || { echo "FAIL: não foi possível preparar o clone do canal" >&2; return 1; }
  cache="$(_git_cache)"; branch="$(_git_branch)"
  hub="$cache/$LIAISON_CHANNEL"
  # A recusa do `_dir_push` PROPAGA. Engolida, o `git add -A` seguinte commitava o que estivesse no
  # cache (inclusive um link recusado) e o sync gravava marca d'água de publicação para o que não
  # foi publicado (LOG-003).
  _dir_push "$hub" || return 1
  git -C "$cache" add -A "$LIAISON_CHANNEL" || return 1
  if git -C "$cache" diff --cached --quiet; then return 0; fi   # nada novo a publicar
  git -C "$cache" commit -qm "liaison($LIAISON_CHANNEL): $LIAISON_SELF" || return 1
  if ! git -C "$cache" push -q origin "$branch" 2>/dev/null; then
    # corrida com outro participante: rebaseia sobre o remoto e reescreve só o próprio arquivo
    _git_sync_clone || return 1
    _dir_push "$hub" || return 1
    git -C "$cache" add -A "$LIAISON_CHANNEL" || return 1
    if git -C "$cache" diff --cached --quiet; then return 0; fi
    git -C "$cache" commit -qm "liaison($LIAISON_CHANNEL): $LIAISON_SELF" || return 1
    git -C "$cache" push -q origin "$branch" \
      || { echo "FAIL: push da branch $branch recusado pelo remoto" >&2; return 1; }
  fi
  return 0
}

t_pull() {
  _git_sync_clone || { echo "FAIL: não foi possível preparar o clone do canal" >&2; return 1; }
  _dir_pull "$(_git_cache)/$LIAISON_CHANNEL" "$1"
}
