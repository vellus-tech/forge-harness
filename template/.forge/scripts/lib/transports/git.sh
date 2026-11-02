#!/usr/bin/env bash
# Transporte `git` — hub numa BRANCH DEDICADA de um repositório remoto.
#
# Por que branch dedicada e não um diretório no default branch: o canal do liaison muda em ritmo
# próprio (várias mensagens por dia) e não deve poluir o histórico do código, disparar CI, nem
# entrar em PR de feature. A branch é órfã — sem ancestral comum com o código — então nunca é
# candidata a merge por engano.
#
# REPOSITÓRIO TEMPORÁRIO POR EXECUÇÃO (design §2.4, opção C — "nenhum recurso compartilhado por
# execução"). O antigo clone compartilhado em `.forge/cache/liaison/<channel>` usava
# `checkout -B`/`reset --hard`, e o `reset` de um processo apagava a união recém-escrita por
# outro. Em vez de travar esse recurso compartilhado (trazendo de volta o problema de vivacidade
# que a opção C abandonou para os transportes de diretório), CADA EXECUÇÃO de `t_push`/`t_pull`
# trabalha num repositório `git init` próprio e descartável em
# `.forge/cache/liaison-git-run/<channel>@<pid>@<aleatório>/`; se o clone antigo existir, seus
# objetos entram como `alternates` (só leitura, para economizar download) — nenhum ref nem
# objeto é escrito no repositório compartilhado, que deixa de ser escrito e fica como fonte
# opcional de objetos. O próprio REMOTO é o compare-and-swap: só aceita fast-forward, então a
# recusa de um push por não-fast-forward É a conferência — não há conferência pós-mv separada
# como nos transportes de diretório.
#
# Como todo transporte, este move ARQUIVOS OPACOS: não parseia mensagem, não sabe o que é thread,
# e não decide merge. Conflito de conteúdo é resolvido pela política de import (liaison-import.mjs),
# nunca pelo git.

# shellcheck source=./_common.sh
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_git_branch() { printf '%s' "${LIAISON_T_BRANCH:-liaison/$LIAISON_CHANNEL}"; }
# Clone antigo, só leitura (alternates): nunca mais escrito por este transporte.
_git_old_cache() { printf '%s/.forge/cache/liaison/%s' "$LIAISON_ROOT" "$LIAISON_CHANNEL"; }
_git_run_base() { printf '%s/.forge/cache/liaison-git-run' "$LIAISON_ROOT"; }
_git_run_dir() { printf '%s/%s@%s@%s' "$(_git_run_base)" "$LIAISON_CHANNEL" "$$" "$(_liaison_unique_suffix)"; }

# _git_cleanup_orphans — remove diretório de execução morta SÓ POR IDADE (> 1 h pelo mtime),
# nunca por pid (um pid pode ter sido reaproveitado). O glob `<channel>@*` não casa com outro
# canal porque `@` não pertence a `[a-z0-9._-]`.
_git_cleanup_orphans() {
  local base; base="$(_git_run_base)"
  [ -d "$base" ] || return 0
  local d mtime now cutoff
  now="$(date +%s)"; cutoff=$(( now - 3600 ))
  for d in "$base/$LIAISON_CHANNEL"@*; do
    [ -d "$d" ] || continue
    mtime="$(stat -c %Y "$d" 2>/dev/null || stat -f %m "$d" 2>/dev/null || echo "$now")"
    [ "$mtime" -lt "$cutoff" ] && rm -rf "$d" 2>/dev/null || true
  done
}

# _git_branch_check <remote> <branch> — rc 0 existe, 2 ausente (ls-remote --exit-code), 1 falha
# de rede/qualquer outra causa. NUNCA trata falha de rede como "ausente".
_git_branch_check() {
  local remote="$1" branch="$2"
  git ls-remote --exit-code "$remote" "refs/heads/$branch" >/dev/null 2>&1
  local rc=$?
  case "$rc" in
    0) return 0 ;;
    2) return 2 ;;
    *) return 1 ;;
  esac
}

# _git_init_run <dir> — git init do repositório descartável desta execução, com o clone antigo
# (se existir) como fonte opcional de objetos.
_git_init_run() {
  local dir="$1"
  mkdir -p "$dir" || return 1
  git init -q "$dir" || return 1
  git -C "$dir" config user.email "liaison@forge.local"
  git -C "$dir" config user.name "forge-liaison"
  git -C "$dir" config commit.gpgsign false
  # SEC-001: a branch do canal é escrita por peers. Com `core.symlinks` padrão (true no macOS), um
  # link simbólico commitado ali vira link de verdade no checkout, e o `mkdir -p`/`cp` seguintes o
  # seguem para fora do repositório descartável. Desligar é a segunda camada; a primeira é a recusa
  # de `_git_refuse_special_entries`, que nem deixa o checkout acontecer.
  git -C "$dir" config core.symlinks false
  local old; old="$(_git_old_cache)"
  if [ -d "$old/.git/objects" ]; then
    mkdir -p "$dir/.git/objects/info"
    printf '%s\n' "$old/.git/objects" > "$dir/.git/objects/info/alternates"
  fi
  return 0
}

# _git_refuse_special_entries <run_dir> <rev> — rc 1 (FAIL nomeando cada caminho) se a árvore do
# canal em <rev> tiver qualquer entrada de modo 120000 (link simbólico) ou 160000 (gitlink). SEC-001:
# o transporte só move arquivos opacos, e nenhum participante legítimo publica link ou submódulo no
# canal — um deles ali é, por construção, conteúdo plantado. Falha do próprio `ls-tree` também
# recusa: não saber ler a árvore é motivo de rigor, não de checkout.
_git_refuse_special_entries() {
  local dir="$1" rev="$2" listing bad
  if ! listing="$(git -C "$dir" ls-tree -r "$rev" -- "$LIAISON_CHANNEL" 2>/dev/null)"; then
    echo "FAIL: RECUSADO — não foi possível listar a árvore do canal $LIAISON_CHANNEL na branch $(_git_branch)." >&2
    return 1
  fi
  bad="$(awk -F '\t' '{ split($1, meta, " "); if (meta[1] == "120000" || meta[1] == "160000") print meta[1] " " $2 }' <<<"$listing")"
  [ -z "$bad" ] && return 0
  echo "FAIL: RECUSADO — a branch $(_git_branch) tem entrada que não é arquivo comum no canal (link simbólico ou submódulo):" >&2
  while IFS= read -r line; do
    echo "      ${line#* } (modo ${line%% *})" >&2
  done <<<"$bad"
  echo "      Nenhum participante legítimo publica isso; seguir o link gravaria fora do repositório descartável. Remova a entrada na branch (e investigue quem a plantou) antes de sincronizar de novo." >&2
  return 1
}

t_probe() {
  [ -n "${LIAISON_T_REMOTE:-}" ] || { echo "FAIL: transporte git exige 'remote' no liaison.yaml" >&2; return 1; }
  command -v git >/dev/null 2>&1 || { echo "FAIL: git não encontrado no PATH" >&2; return 1; }
  git ls-remote "$LIAISON_T_REMOTE" >/dev/null 2>&1 \
    || { echo "FAIL: remote inacessível: $LIAISON_T_REMOTE (credencial? URL?)" >&2; return 1; }
  return 0
}

# t_push — publica log/<self>.jsonl e blobs novos na branch do canal, sem trava de rede (design
# §2.4). Cada tentativa: repositório temporário novo, `ls-remote` decide se a branch existe,
# fetch+checkout (ou commit inicial vazio), sequência igual à dos transportes de diretório
# (instantâneo, blobs, união), `git add` explícito só de `<channel>/log/<self>.jsonl` e blobs
# novos (nunca `git add -A`), commit, `push ... HEAD:refs/heads/<branch>` sem force. Recusa por
# não-fast-forward volta ao início da tentativa (novo fetch) — é o próprio laço de recusa que
# confere, sem conferência pós-mv separada.
t_push() {
  _git_cleanup_orphans
  local remote branch
  remote="$LIAISON_T_REMOTE"; branch="$(_git_branch)"
  local deadline; deadline=$(( $(date +%s) + $(_liaison_push_deadline_s) ))
  local attempts=0 repairs=0 rc=1
  LIAISON_OBSERVED_FILE=""

  local src="$LIAISON_CHANNEL_DIR"
  local own="$src/log/$LIAISON_SELF.jsonl"

  while :; do
    attempts=$((attempts + 1))
    local run_dir; run_dir="$(_git_run_dir)"
    if ! _git_init_run "$run_dir"; then
      echo "FAIL: não foi possível preparar repositório temporário git em $run_dir" >&2
      rm -rf "$run_dir" 2>/dev/null
      return 1
    fi

    local branch_rc=0
    _git_branch_check "$remote" "$branch" || branch_rc=$?
    local base_commit=""
    case "$branch_rc" in
      0)
        if ! git -C "$run_dir" fetch -q --depth 1 "$remote" "$branch" 2>/dev/null; then
          echo "FAIL: push RECUSADO — fetch da branch $branch falhou (rede?)" >&2
          rm -rf "$run_dir"; return 1
        fi
        _git_refuse_special_entries "$run_dir" FETCH_HEAD || { rm -rf "$run_dir"; return 1; }
        git -C "$run_dir" checkout -q -B "$branch" FETCH_HEAD || { rm -rf "$run_dir"; return 1; }
        base_commit="$(git -C "$run_dir" rev-parse HEAD)"
        ;;
      2)
        local empty_tree initial_commit
        empty_tree="$(git -C "$run_dir" hash-object -t tree /dev/null)"
        initial_commit="$(git -C "$run_dir" commit-tree "$empty_tree" -m "liaison: canal $LIAISON_CHANNEL (inicial)")"
        git -C "$run_dir" checkout -q -B "$branch" "$initial_commit" || { rm -rf "$run_dir"; return 1; }
        base_commit="$initial_commit"
        ;;
      *)
        echo "FAIL: push RECUSADO — não foi possível saber se a branch $branch existe no remoto (falha de rede, não ausência)" >&2
        rm -rf "$run_dir"; return 1
        ;;
    esac

    local hub="$run_dir/$LIAISON_CHANNEL"
    _dir_hub_guard "$hub" || { rm -rf "$run_dir"; return 1; }
    mkdir -p "$hub/log" "$hub/blobs"

    if [ ! -f "$own" ]; then
      # nada próprio a publicar nesta execução.
      rm -rf "$run_dir"
      export LIAISON_PUSH_ATTEMPTS="$attempts" LIAISON_PUSH_REPAIRS="$repairs"
      return 0
    fi

    local snap; snap="$(mktemp "${TMPDIR:-/tmp}/liaison-git-push-snap.XXXXXX")"
    cp "$own" "$snap"
    if ! _dir_push_blobs "$hub" "$src"; then
      rm -f "$snap"; rm -rf "$run_dir"
      return 1
    fi
    _liaison_test_barrier after-blobs

    local verdict cls_rc=0
    verdict="$(_dir_push_classify "$hub" "$snap")" || cls_rc=$?
    case "$cls_rc" in
      0) : ;;
      1) repairs=$((repairs + 1)) ;;
      2)
        if [ "${LIAISON_PUSH_REPAIR:-0}" = "1" ]; then
          echo "WARN: reparo do log próprio (--repair-own-log) — a branch diverge desta árvore em posição(ões) que ela também tem:" >&2
          echo "     ${verdict#diverged}" >&2
        else
          echo "FAIL: push RECUSADO — DIVERGÊNCIA entre a branch $branch e esta árvore em posição(ões) que ela também tem: ${verdict#diverged}" >&2
          rm -f "$snap"; rm -rf "$run_dir"
          return 1
        fi
        ;;
      *)
        echo "FAIL: push RECUSADO — não foi possível classificar o conteúdo da branch (rc $cls_rc)." >&2
        rm -f "$snap"; rm -rf "$run_dir"
        return 1
        ;;
    esac

    local libdir; libdir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local unionmod="$libdir/liaison-push-union.mjs"
    local hubf="$hub/log/$LIAISON_SELF.jsonl"
    if ! node "$unionmod" "$snap" "$hubf" "$hubf.tmp" "$LIAISON_SELF"; then
      rm -f "$snap" "$hubf.tmp"; rm -rf "$run_dir"
      return 1
    fi
    mv "$hubf.tmp" "$hubf"
    _liaison_test_barrier after-union
    rm -f "$snap"

    # `git add` explícito (nunca `-A`): só o log do self e blobs novos.
    git -C "$run_dir" add -- "$LIAISON_CHANNEL/log/$LIAISON_SELF.jsonl" >/dev/null 2>&1
    if [ -d "$hub/blobs" ]; then
      local b
      while IFS= read -r b; do
        [ -n "$b" ] || continue
        git -C "$run_dir" add -- "$LIAISON_CHANNEL/blobs/$(basename "$b")" >/dev/null 2>&1
      done < <(find "$hub/blobs" -type f 2>/dev/null)
    fi

    if git -C "$run_dir" diff --cached --quiet; then
      # nada novo sobre o que já está na branch — a observação é o que acabou de ser buscado.
      LIAISON_OBSERVED_FILE="$(mktemp "${TMPDIR:-/tmp}/liaison-git-observed.XXXXXX")"
      git -C "$run_dir" show "$base_commit:$LIAISON_CHANNEL/log/$LIAISON_SELF.jsonl" > "$LIAISON_OBSERVED_FILE" 2>/dev/null || : > "$LIAISON_OBSERVED_FILE"
      export LIAISON_OBSERVED_FILE
      _liaison_test_barrier after-mv
      rc=0
      rm -rf "$run_dir"
      break
    fi

    git -C "$run_dir" commit -q -m "liaison($LIAISON_CHANNEL): $LIAISON_SELF" || { rm -rf "$run_dir"; return 1; }
    _liaison_test_barrier after-mv

    if git -C "$run_dir" push -q "$remote" "HEAD:refs/heads/$branch" 2>/dev/null; then
      # Push aceito pelo remoto = a própria conferência (fast-forward-only). Observação: o
      # log próprio tal como FOI ENVIADO (o commit HEAD, que por ser fast-forward é exatamente
      # o que o remoto passou a ter) — nenhum ref compartilhado (origin/<branch>) é consultado.
      LIAISON_OBSERVED_FILE="$(mktemp "${TMPDIR:-/tmp}/liaison-git-observed.XXXXXX")"
      git -C "$run_dir" show "HEAD:$LIAISON_CHANNEL/log/$LIAISON_SELF.jsonl" > "$LIAISON_OBSERVED_FILE" 2>/dev/null || : > "$LIAISON_OBSERVED_FILE"
      export LIAISON_OBSERVED_FILE
      # sincroniza o log próprio local de volta, sob a trava, com o que foi de fato enviado —
      # mesma disciplina de escritor único que os transportes de diretório (design §2.4).
      local append_mod="$libdir/liaison-append.mjs"
      node "$append_mod" union-own "$src" "$LIAISON_SELF" "$LIAISON_OBSERVED_FILE" >/dev/null || true
      rc=0
      rm -rf "$run_dir"
      break
    fi

    # Recusado por não-fast-forward (ou qualquer outra causa) — o laço de recusa É a
    # conferência: volta ao início com um fetch novo. O prazo é o mesmo dos transportes de
    # diretório.
    rm -rf "$run_dir"
    if [ "$(date +%s)" -ge "$deadline" ]; then
      rc=1
      echo "FAIL: push esgotou o prazo ($(_liaison_push_deadline_s)s) sem conseguir publicar na branch $branch" >&2
      break
    fi
  done

  export LIAISON_PUSH_ATTEMPTS="$attempts" LIAISON_PUSH_REPAIRS="$repairs"
  echo "publicação: $attempts tentativa(s), $repairs reparo(s)" >&2
  return "$rc"
}

# t_pull <staging> — materializa os logs alheios e blobs da branch do canal, por `git archive`
# (sem checkout compartilhado), num repositório temporário descartável desta execução.
t_pull() {
  local staging="$1"
  _git_cleanup_orphans
  local remote branch
  remote="$LIAISON_T_REMOTE"; branch="$(_git_branch)"
  local run_dir; run_dir="$(_git_run_dir)"
  _git_init_run "$run_dir" || { echo "FAIL: não foi possível preparar repositório temporário git" >&2; rm -rf "$run_dir"; return 1; }

  local branch_rc=0
  _git_branch_check "$remote" "$branch" || branch_rc=$?
  case "$branch_rc" in
    0)
      if ! git -C "$run_dir" fetch -q --depth 1 "$remote" "$branch" 2>/dev/null; then
        echo "FAIL: pull — fetch da branch $branch falhou (rede?)" >&2
        rm -rf "$run_dir"; return 1
      fi
      # SEC-001: `git archive | tar -x` materializa link simbólico como link, independente de
      # `core.symlinks` — a recusa vem antes de qualquer extração.
      _git_refuse_special_entries "$run_dir" FETCH_HEAD || { rm -rf "$run_dir"; return 1; }
      mkdir -p "$staging"
      git -C "$run_dir" archive FETCH_HEAD -- "$LIAISON_CHANNEL" 2>/dev/null | tar -x -C "$staging" 2>/dev/null || true
      ;;
    2)
      mkdir -p "$staging" # branch ainda não existe no remoto — nada a puxar, não é erro
      ;;
    *)
      echo "FAIL: pull — não foi possível saber se a branch $branch existe no remoto (falha de rede, não ausência)" >&2
      rm -rf "$run_dir"; return 1
      ;;
  esac
  rm -rf "$run_dir"

  # _dir_pull espera <hub>/log e <hub>/blobs; o archive materializou <staging>/<channel>/{log,blobs}
  # diretamente no diretório de staging que o chamador já passa — então normaliza um nível.
  if [ -d "$staging/$LIAISON_CHANNEL" ]; then
    mkdir -p "$staging/.git-pull-tmp"
    mv "$staging/$LIAISON_CHANNEL"/* "$staging/.git-pull-tmp/" 2>/dev/null || true
    rm -rf "$staging/$LIAISON_CHANNEL"
    _dir_pull "$staging/.git-pull-tmp" "$staging"
    rm -rf "$staging/.git-pull-tmp"
  else
    mkdir -p "$staging/log" "$staging/blobs"
  fi
  return 0
}
