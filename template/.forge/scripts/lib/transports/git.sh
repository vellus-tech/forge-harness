#!/usr/bin/env bash
# Transporte `git` — hub numa BRANCH DEDICADA de um repositório remoto.
#
# Por que branch dedicada e não um diretório no default branch: o canal do liaison muda em ritmo
# próprio (várias mensagens por dia) e não deve poluir o histórico do código, disparar CI, nem
# entrar em PR de feature. A branch é órfã — sem ancestral comum com o código — então nunca é
# candidata a merge por engano.
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

# Garante um clone de trabalho posicionado na branch do canal, sincronizado com o remoto. Se a
# branch ainda não existe lá, prepara uma órfã vazia — o primeiro push a cria.
_git_sync_clone() {
  local cache branch
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
  if git -C "$cache" fetch -q origin "$branch" 2>/dev/null; then
    git -C "$cache" checkout -q -B "$branch" FETCH_HEAD || return 1
    git -C "$cache" reset -q --hard FETCH_HEAD || return 1
  else
    git -C "$cache" checkout -q --orphan "$branch" 2>/dev/null \
      || git -C "$cache" symbolic-ref HEAD "refs/heads/$branch" || return 1
    git -C "$cache" rm -rq --cached . 2>/dev/null || true
    find "$cache" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
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
  _dir_push "$hub"
  git -C "$cache" add -A "$LIAISON_CHANNEL" || return 1
  if git -C "$cache" diff --cached --quiet; then return 0; fi   # nada novo a publicar
  git -C "$cache" commit -qm "liaison($LIAISON_CHANNEL): $LIAISON_SELF" || return 1
  if ! git -C "$cache" push -q origin "$branch" 2>/dev/null; then
    # corrida com outro participante: rebaseia sobre o remoto e reescreve só o próprio arquivo
    _git_sync_clone || return 1
    _dir_push "$hub"
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
