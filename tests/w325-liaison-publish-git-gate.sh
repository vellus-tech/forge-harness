#!/usr/bin/env bash
# Gate — TASK-08/TASK-09 de add-liaison-handoff-baton (REQ-09, REQ-15, design §2.4, transporte
# `git` com remoto bare local):
#   [git-repo-temporario] cada push/pull usa um repositório git descartável por execução, nunca
#     um clone compartilhado (sem resíduo em .forge/cache/liaison/<canal> nem em
#     .forge/cache/liaison-git-run/ depois de terminar)
#   [git-ausente] ls-remote decide branch ausente (rc 2) — primeira publicação cria a branch
#   [git-rede] falha de rede NUNCA é tratada como "branch ausente"
#   [git-commit-vazio] primeira publicação começa de um commit inicial vazio (árvore vazia)
#   [git-add-explicito] nenhum `git add -A` no transporte — só caminhos explícitos
#   [git-sem-force] push nunca usa --force/-f
#   [git-observacao] a marca de publicação observada bate com o que o remoto realmente tem
#     (git show do commit enviado, nunca um ref compartilhado)
#   [git-pull-sem-checkout] pull por `git archive`, sem deixar checkout compartilhado
#   [git-sync-duplo] dois sync concorrentes (push-only e completo) não corrompem a branch
#   [git-orfao] limpeza de diretório de execução morta só por idade (>1h), preservando um
#     recente e o de outro canal
#   [git-clone-antigo] apagar o clone antigo (fonte opcional de objetos) durante uma execução
#     não corrompe nem falha a publicação
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITSH="$WS/template/.forge/scripts/lib/transports/git.sh"
T="$(mktemp -d /tmp/forge-liaison-git.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=publish-git-gate

mk_repo() {
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -q -m init >/dev/null
}

LG() { local root="$1"; shift; FORGE_ROOT="$root" bash "$root/.forge/scripts/liaison-ops.sh" "$@"; }

# === [git-add-explicito]/[git-sem-force] estática: o transporte nunca usa add -A nem --force ===
# grep só em CÓDIGO (exclui comentário/prosa explicativa, que cita os padrões proibidos por
# nome para documentar que eles NÃO aparecem — "nunca `git add -A`" no comentário não é o uso).
code_lines="$(grep -vE '^\s*#' "$GITSH")"
if echo "$code_lines" | grep -Eq 'git[[:space:]].*add[[:space:]]+-A|add[[:space:]]+--all'; then
  echo "FAIL [git-add-explicito]: git.sh usa 'git add -A' em algum ponto de código"
  fail=1
else
  echo "OK [git-add-explicito]: nenhum 'git add -A' no transporte"
fi
if echo "$code_lines" | grep -Eq 'push[^|&;]*(--force|[[:space:]]-f([[:space:]]|$))'; then
  echo "FAIL [git-sem-force]: git.sh usa --force/-f no push"
  fail=1
else
  echo "OK [git-sem-force]: nenhum push --force/-f"
fi

# === fixtures de repo + remoto bare ===
git init -q --bare "$T/hub.git"
mk_repo a
LG "$T/a" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG "$T/a" transport set "$CH" --kind git --remote "$T/hub.git" --branch "liaison/$CH" >/dev/null
LG "$T/a" thread open "$CH" t1 --subject gate --participants repo-a,repo-b --body open >/dev/null

# === [git-ausente] branch ainda não existe: ls-remote --exit-code dá 2, primeira publicação cria ===
before_refs="$(git -C "$T/hub.git" for-each-ref --format='%(refname)' 2>/dev/null)"
echo "$before_refs" | grep -q "liaison/$CH" && { echo "FAIL [git-ausente]: branch já existia antes do primeiro push — fixture inválida"; fail=1; }
LG "$T/a" send "$CH" --thread t1 --kind note --subject m1 --body x >/dev/null
out_first="$(LG "$T/a" sync "$CH" --push-only 2>&1)"; rc_first=$?
if [ "$rc_first" -ne 0 ]; then
  echo "FAIL [git-ausente]: primeiro push (branch ausente) falhou: $out_first"
  fail=1
else
  git -C "$T/hub.git" for-each-ref --format='%(refname)' | grep -q "liaison/$CH" \
    && echo "OK [git-ausente]: primeira publicação criou a branch" \
    || { echo "FAIL [git-ausente]: branch não foi criada no remoto após o primeiro push"; fail=1; }
fi

# === [git-commit-vazio] a raiz do histórico da branch é um commit com árvore vazia ===
root_commit="$(git -C "$T/hub.git" log "liaison/$CH" --format=%H | tail -1)"
tree_entries="$(git -C "$T/hub.git" ls-tree "$root_commit" | wc -l | tr -d ' ')"
[ "$tree_entries" = "0" ] && echo "OK [git-commit-vazio]: commit raiz tem árvore vazia" || { echo "FAIL [git-commit-vazio]: commit raiz não tem árvore vazia (entradas=$tree_entries)"; fail=1; }

# === [git-repo-temporario] nenhum resíduo depois do push ===
old_cache="$T/a/.forge/cache/liaison"
run_cache="$T/a/.forge/cache/liaison-git-run"
if [ -d "$old_cache/$CH" ]; then
  echo "FAIL [git-repo-temporario]: clone compartilhado antigo foi criado em $old_cache/$CH"
  fail=1
fi
leftover="$(find "$run_cache" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
[ "${leftover:-0}" = "0" ] && echo "OK [git-repo-temporario]: nenhum diretório de execução sobrou após o push" || { echo "FAIL [git-repo-temporario]: sobrou $leftover diretório(s) em $run_cache"; fail=1; }

# === [git-observacao] a marca publicada bate com o que o remoto realmente tem ===
published="$(node -e "console.log(JSON.parse(require('fs').readFileSync('$T/a/.forge/liaison/$CH/state.json','utf8')).published['repo-a'])")"
remote_last_msgid="$(git -C "$T/hub.git" show "liaison/$CH:$CH/log/repo-a.jsonl" 2>/dev/null | tail -1 | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).msg_id)}catch(e){console.log('')}})")"
[ "$published" = "$remote_last_msgid" ] && echo "OK [git-observacao]: marca ($published) bate com o remoto ($remote_last_msgid)" || { echo "FAIL [git-observacao]: marca='$published' remoto='$remote_last_msgid'"; fail=1; }

# === [git-rede] falha de rede nunca é "ausente" ===
mk_repo badnet
LG "$T/badnet" open "$CH" --self repo-c --participants repo-a,repo-c >/dev/null
LG "$T/badnet" transport set "$CH" --kind git --remote "$T/does-not-exist.git" --branch "liaison/$CH" >/dev/null
LG "$T/badnet" thread open "$CH" t1 --subject x --participants repo-a,repo-c --body y >/dev/null
LG "$T/badnet" send "$CH" --thread t1 --kind note --subject m1 --body z >/dev/null
out_net="$(LG "$T/badnet" sync "$CH" --push-only 2>&1)"; rc_net=$?
if [ "$rc_net" -eq 0 ]; then
  echo "FAIL [git-rede]: push com remoto inexistente deveria falhar, mas passou"
  fail=1
else
  echo "$out_net" | grep -qi "ausente\|não existe" && echo "$out_net" | grep -qiv "rede" \
    && { echo "FAIL [git-rede]: falha de rede foi relatada como 'ausente' em vez de problema de rede: $out_net"; fail=1; } \
    || echo "OK [git-rede]: falha de rede recusada sem ser confundida com 'branch ausente'"
fi

# === [git-pull-sem-checkout] pull não deixa checkout compartilhado ===
mk_repo b
LG "$T/b" open "$CH" --self repo-b --participants repo-a,repo-b >/dev/null
LG "$T/b" transport set "$CH" --kind git --remote "$T/hub.git" --branch "liaison/$CH" >/dev/null
LG "$T/b" sync "$CH" --pull-only >/dev/null 2>&1
if [ -d "$T/b/.forge/cache/liaison/$CH/.git" ]; then
  echo "FAIL [git-pull-sem-checkout]: pull deixou um clone/checkout compartilhado em .forge/cache/liaison/$CH"
  fail=1
else
  order_b="$(cat "$T/b/.forge/liaison/$CH/log/repo-a.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
  [ "$order_b" = "2" ] && echo "OK [git-pull-sem-checkout]: pull materializou o log alheio sem checkout compartilhado" || { echo "FAIL [git-pull-sem-checkout]: pull não trouxe o log de repo-a (linhas=$order_b)"; fail=1; }
fi

# === [git-sync-duplo] dois sync concorrentes (push-only e completo) não corrompem a branch ===
mk_repo c
LG "$T/c" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
# repo-c é outra ÁRVORE do mesmo self (simula duas worktrees/processos do mesmo remetente)
cp -R "$T/a/.forge/liaison" "$T/c/.forge/liaison" 2>/dev/null || true
LG "$T/c" transport set "$CH" --kind git --remote "$T/hub.git" --branch "liaison/$CH" >/dev/null
LG "$T/a" send "$CH" --thread t1 --kind note --subject dup1 --body x >/dev/null
( LG "$T/a" sync "$CH" --push-only >"$T/dup-a.out" 2>&1 ) &
PID_A=$!
( LG "$T/c" sync "$CH" >"$T/dup-c.out" 2>&1 ) &
PID_C=$!
wait "$PID_A"; rc_dup_a=$?
wait "$PID_C"; rc_dup_c=$?
if git -C "$T/hub.git" fsck --no-progress >/tmp/fsck-git.out 2>&1; then
  echo "OK [git-sync-duplo]: dois sync concorrentes terminaram (rc_a=$rc_dup_a rc_c=$rc_dup_c) e a branch remota está íntegra (fsck limpo)"
else
  echo "FAIL [git-sync-duplo]: fsck do remoto reportou problema após sync duplo concorrente: $(cat /tmp/fsck-git.out)"
  fail=1
fi

# === [git-orfao] limpeza só por idade, preservando execução viva e o de outro canal ===
mkdir -p "$run_cache"
old_run="$run_cache/$CH@11111@zzzzzz"
recent_run="$run_cache/$CH@22222@yyyyyy"
other_channel_run="$run_cache/other-channel@33333@xxxxxx"
mkdir -p "$old_run" "$recent_run" "$other_channel_run"
touch -t "$(date -v-2H +%Y%m%d%H%M 2>/dev/null || date -d '2 hours ago' +%Y%m%d%H%M)" "$old_run" 2>/dev/null || true
LG "$T/a" send "$CH" --thread t1 --kind note --subject m2 --body x >/dev/null
LG "$T/a" sync "$CH" --push-only >/dev/null 2>&1
if [ -d "$old_run" ]; then
  echo "FAIL [git-orfao]: diretório de execução morta com mais de 1h não foi removido"
  fail=1
fi
if [ ! -d "$recent_run" ]; then
  echo "FAIL [git-orfao]: diretório recente (execução potencialmente viva) foi removido indevidamente"
  fail=1
fi
if [ ! -d "$other_channel_run" ]; then
  echo "FAIL [git-orfao]: diretório de OUTRO canal foi removido (glob deveria ser só deste canal)"
  fail=1
fi
[ -d "$old_run" ] || [ ! -d "$recent_run" ] || [ ! -d "$other_channel_run" ] || echo "OK [git-orfao]: limpeza seletiva correta (velho removido, recente e de outro canal preservados)"
rm -rf "$recent_run" "$other_channel_run"

# === [git-clone-antigo] apagar o clone antigo (alternates) durante uma execução não corrompe ===
mkdir -p "$old_cache/$CH/.git/objects"
LG "$T/a" send "$CH" --thread t1 --kind note --subject m3 --body x >/dev/null
rm -rf "$old_cache"
out_oldclone="$(LG "$T/a" sync "$CH" --push-only 2>&1)"; rc_oldclone=$?
[ "$rc_oldclone" -eq 0 ] && echo "OK [git-clone-antigo]: push funcionou mesmo com o clone antigo ausente/removido" || { echo "FAIL [git-clone-antigo]: push falhou com o clone antigo ausente: $out_oldclone"; fail=1; }

# === [git-reparo-proprio] LGC-003: `sync --push-only --repair-own-log` com a branch divergindo
# do log próprio (terceiro reescreveu a última linha no remoto) repara: o remoto passa a ter
# exatamente o log desta árvore, sem force (o laço de recusa não-ff continua valendo) ===
git init -q --bare "$T/hub-repair.git"
mk_repo rp
LG "$T/rp" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG "$T/rp" transport set "$CH" --kind git --remote "$T/hub-repair.git" --branch "liaison/$CH" >/dev/null
LG "$T/rp" thread open "$CH" t1 --subject gate --participants repo-a,repo-b --body open >/dev/null
LG "$T/rp" send "$CH" --thread t1 --kind note --subject original --body x >/dev/null
LG "$T/rp" sync "$CH" --push-only >/dev/null 2>&1 || { echo "FAIL [git-reparo-proprio]: fixture — primeiro push falhou"; fail=1; }
atk="$T/rp-atk"
git clone -q --branch "liaison/$CH" "$T/hub-repair.git" "$atk" 2>/dev/null
git -C "$atk" config user.email atk@test; git -C "$atk" config user.name atk; git -C "$atk" config commit.gpgsign false
node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const fs = require("fs");
  const [, path, lib] = process.argv;
  const { computeContentSha } = await import(pathToFileURL(join(lib, "liaison-merge.mjs")).href);
  const lines = fs.readFileSync(path, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const last = lines[lines.length - 1];
  last.subject = "reescrito por terceiro";
  last.content_sha = computeContentSha(last);
  fs.writeFileSync(path, lines.map((m) => JSON.stringify(m)).join("\n") + "\n");
})();
' "$atk/$CH/log/repo-a.jsonl" "$WS/template/.forge/scripts/lib"
git -C "$atk" commit -q -am "reescrita" && git -C "$atk" push -q origin "HEAD:refs/heads/liaison/$CH" 2>/dev/null
out_rp="$(LG "$T/rp" sync "$CH" --push-only --repair-own-log 2>&1)"; rc_rp=$?
remote_rp="$(git -C "$T/hub-repair.git" show "liaison/$CH:$CH/log/repo-a.jsonl" 2>/dev/null)"
local_rp="$(cat "$T/rp/.forge/liaison/$CH/log/repo-a.jsonl")"
if [ "$rc_rp" -ne 0 ]; then
  echo "FAIL [git-reparo-proprio]: sync --push-only --repair-own-log reprovou (rc $rc_rp): $(tr '\n' ' ' <<<"$out_rp" | cut -c1-300)"
  fail=1
elif [ "$remote_rp" != "$local_rp" ]; then
  echo "FAIL [git-reparo-proprio]: rc 0, mas o remoto não ficou com o log desta árvore"
  fail=1
elif grep -q "reescrito por terceiro" <<<"$remote_rp"; then
  echo "FAIL [git-reparo-proprio]: a versão reescrita pelo terceiro sobreviveu no remoto"
  fail=1
else
  echo "OK [git-reparo-proprio]: --repair-own-log republicou o log desta árvore sobre a reescrita do terceiro"
fi
# controle: sem --repair-own-log, a mesma divergência continua recusada
git -C "$atk" pull -q --rebase origin "liaison/$CH" 2>/dev/null
node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const fs = require("fs");
  const [, path, lib] = process.argv;
  const { computeContentSha } = await import(pathToFileURL(join(lib, "liaison-merge.mjs")).href);
  const lines = fs.readFileSync(path, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const last = lines[lines.length - 1];
  last.subject = "reescrito de novo";
  last.content_sha = computeContentSha(last);
  fs.writeFileSync(path, lines.map((m) => JSON.stringify(m)).join("\n") + "\n");
})();
' "$atk/$CH/log/repo-a.jsonl" "$WS/template/.forge/scripts/lib"
git -C "$atk" commit -q -am "reescrita 2" && git -C "$atk" push -q origin "HEAD:refs/heads/liaison/$CH" 2>/dev/null
out_rp2="$(LG "$T/rp" sync "$CH" --push-only 2>&1)"; rc_rp2=$?
if [ "$rc_rp2" -ne 0 ] && grep -q "DIVERGÊNCIA" <<<"$out_rp2"; then
  echo "OK [git-reparo-controle]: sem --repair-own-log a divergência continua recusada"
else
  echo "FAIL [git-reparo-controle]: sem --repair-own-log esperava recusa por DIVERGÊNCIA, achou rc=$rc_rp2: $(tr '\n' ' ' <<<"$out_rp2" | cut -c1-200)"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — transporte git: repositório temporário por execução, ausência vs rede, commit inicial vazio, add explícito, sem force, observação, pull sem checkout, sync duplo, limpeza por idade, clone antigo removido"
exit 0
