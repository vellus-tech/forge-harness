#!/usr/bin/env bash
# Gate — SEC-001 (round 1 do PR #254): link simbólico plantado por um peer no ponto de encontro
# nunca leva a escrita fora do hub, e o import só instala blob no formato content-addressed que o
# próprio harness produz, com sha conferido e modo 0644.
#
# A cadeia reproduzida na revisão: (a) um participante com push na branch do canal troca
# `<canal>/blobs` por um symlink para `../../../../../.git/hooks`; o `t_push` do transporte git
# fazia checkout com `core.symlinks` padrão e copiava os blobs locais para lá; (b) o import
# aceitava `body_ref: blobs/post-commit` com o bit de execução do arquivo do peer. Juntas, viravam
# um hook executável no repositório de quem sincroniza.
#
#   [git-push]     branch com `<canal>/blobs` em modo 120000: o push recusa, nomeia o caminho, e
#                  nada é escrito em `.git/hooks`
#   [git-pull]     a mesma branch: o pull recusa nomeando o caminho
#   [fs-log]       hub fs com `<canal>/log` como symlink: o push recusa e nada vai para o alvo
#   [fs-blobs]     hub fs com `<canal>/blobs` como symlink: idem
#   [fs-hub]       hub fs com o próprio `<canal>` como symlink: idem (inclusive o probe)
#   [import-nome]  body_ref de peer fora do formato `blobs/<sha256>-<nome>` vira conflito e nada é
#                  instalado
#   [import-sha]   body_ref content-addressed com conteúdo que não confere vira conflito
#   [import-modo]  blob legítimo de peer com 0755 é instalado com 0644
#   [recontrole]   com as guardas neutralizadas por mutação numa cópia dos scripts, os cenários
#                  [git-push], [fs-log], [fs-blobs] e [import-nome] PRECISAM ver a escrita escapar
#                  — prova de que a fixture está armada e de que é a guarda que segura
set -uo pipefail
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-liaison-symlink.XXXXXX)"
trap 'rm -rf "$T"' EXIT
CH=symlink-gate
fail=0

# ── cópias dos scripts: a real e a mutante (guardas neutralizadas) ───────────────────────────────
REAL_SCRIPTS="$WS/template/.forge/scripts"
MUT_SCRIPTS="$T/mutant-scripts"
cp -R "$REAL_SCRIPTS" "$MUT_SCRIPTS"
# Cada substituição precisa acontecer: um marcador ausente faria a "mutante" igual à real, e o
# recontrole aprovaria por não ter mutado nada.
mutate() { # mutate <arquivo> <expressão perl> <rótulo>
  local f="$1" expr="$2" label="$3" before after
  before="$(shasum -a 256 "$f" | cut -d' ' -f1)"
  perl -0pi -e "$expr" "$f"
  after="$(shasum -a 256 "$f" | cut -d' ' -f1)"
  if [ "$before" = "$after" ]; then
    echo "FAIL [recontrole]: a mutação '$label' não casou nenhum marcador em $f — recontrole sem mutação não prova nada"
    fail=1
  fi
}
mutate "$MUT_SCRIPTS/lib/transports/git.sh" 's/(_git_refuse_special_entries\(\) \{\n)/$1  return 0\n/' "git: recusa de entrada especial"
mutate "$MUT_SCRIPTS/lib/transports/git.sh" 's/git -C "\$dir" config core\.symlinks false/:/' "git: core.symlinks false"
mutate "$MUT_SCRIPTS/lib/transports/_common.sh" 's/(_dir_refuse_link\(\) \{\n)/$1  return 0\n/' "_common: recusa de link"
mutate "$MUT_SCRIPTS/lib/liaison-import.mjs" 's/(function blobRefRejection\([^)]*\) \{\n)/$1  return null;\n/' "import: formato content-addressed"

mk_repo() { # mk_repo <nome> <scripts>
  local dir="$T/$1" scripts="$2"
  mkdir -p "$dir/.forge"
  cp -R "$scripts" "$dir/.forge/scripts"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -q -m init >/dev/null
}
LG() { local root="$1"; shift; FORGE_ROOT="$root" bash "$root/.forge/scripts/liaison-ops.sh" "$@"; }
listing() { (cd "$1" 2>/dev/null && find . -mindepth 1 | LC_ALL=C sort); }

# ── [git-push] / [git-pull] ──────────────────────────────────────────────────────────────────────
# scen_git <tag> <scripts> — rc 0 = guarda segurou (push recusado nomeando o caminho, nada em
# .git/hooks); rc 1 = escapou ou não recusou. Mensagens em stdout.
scen_git() {
  local tag="$1" scripts="$2" a="git-$1" b="git-$1-b" hub="$T/hub-$1.git"
  git init -q --bare "$hub"
  mk_repo "$a" "$scripts"
  LG "$T/$a" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
  LG "$T/$a" transport set "$CH" --kind git --remote "$hub" --branch "liaison/$CH" >/dev/null
  LG "$T/$a" thread open "$CH" t1 --subject gate --participants repo-a,repo-b --body open >/dev/null
  printf 'corpo grande\n' > "$T/corpo-$tag.md"
  LG "$T/$a" send "$CH" --thread t1 --kind note --subject m1 --body-file "$T/corpo-$tag.md" >/dev/null
  LG "$T/$a" sync "$CH" --push-only >/dev/null 2>&1 || { echo "FAIL [$tag]: fixture — primeiro push legítimo falhou"; return 1; }
  # o atacante troca <canal>/blobs por symlink para ../../../../../.git/hooks (relativo ao
  # diretório do canal dentro de .forge/cache/liaison-git-run/<canal>@pid@x/)
  local atk="$T/atk-$tag"
  git clone -q --branch "liaison/$CH" "$hub" "$atk" 2>/dev/null
  git -C "$atk" config user.email atk@test; git -C "$atk" config user.name atk; git -C "$atk" config commit.gpgsign false
  git -C "$atk" rm -q -r "$CH/blobs"
  ln -s ../../../../../.git/hooks "$atk/$CH/blobs"
  git -C "$atk" add "$CH/blobs"
  git -C "$atk" commit -q -m "hostil"
  git -C "$atk" push -q origin "HEAD:refs/heads/liaison/$CH" 2>/dev/null || { echo "FAIL [$tag]: fixture — push do atacante falhou"; return 1; }
  grep -q "^120000" <<<"$(git -C "$hub" ls-tree -r "liaison/$CH" -- "$CH")" || { echo "FAIL [$tag]: fixture — symlink não chegou ao remoto"; return 1; }

  local hooks_before; hooks_before="$(listing "$T/$a/.git/hooks")"
  printf 'outro corpo\n' > "$T/corpo2-$tag.md"
  LG "$T/$a" send "$CH" --thread t1 --kind note --subject m2 --body-file "$T/corpo2-$tag.md" >/dev/null
  local out rc=0
  out="$(LG "$T/$a" sync "$CH" --push-only 2>&1)" || rc=$?
  local hooks_after; hooks_after="$(listing "$T/$a/.git/hooks")"
  local res=0
  if [ "$hooks_before" != "$hooks_after" ]; then
    echo "FAIL [$tag/push]: escrita escapou para .git/hooks: $(diff <(echo "$hooks_before") <(echo "$hooks_after") | grep '^>' | tr '\n' ' ')"
    res=1
  fi
  if [ "$rc" -eq 0 ]; then
    echo "FAIL [$tag/push]: push contra branch com symlink em $CH/blobs terminou com rc 0"
    res=1
  elif ! grep -q "$CH/blobs" <<<"$out"; then
    echo "FAIL [$tag/push]: recusa não nomeia o caminho $CH/blobs: $out"
    res=1
  fi

  # pull de outro participante contra a mesma branch hostil
  mk_repo "$b" "$scripts"
  LG "$T/$b" open "$CH" --self repo-b --participants repo-a,repo-b >/dev/null
  LG "$T/$b" transport set "$CH" --kind git --remote "$hub" --branch "liaison/$CH" >/dev/null
  local outp rcp=0
  outp="$(LG "$T/$b" sync "$CH" --pull-only 2>&1)" || rcp=$?
  if [ "$rcp" -eq 0 ]; then
    echo "FAIL [$tag/pull]: pull contra branch com symlink em $CH/blobs terminou com rc 0"
    res=1
  elif ! grep -q "$CH/blobs" <<<"$outp"; then
    echo "FAIL [$tag/pull]: recusa do pull não nomeia o caminho $CH/blobs: $outp"
    res=1
  fi
  return "$res"
}

# ── [fs-log] / [fs-blobs] / [fs-hub] ────────────────────────────────────────────────────────────
# scen_fs <tag> <scripts> <alvo: log|blobs|hub> — rc 0 = guarda segurou; rc 1 = escapou.
scen_fs() {
  local tag="$1" scripts="$2" which="$3" r="fs-$1-$3" fshub="$T/fshub-$1-$3" outside="$T/outside-$1-$3"
  mk_repo "$r" "$scripts"
  LG "$T/$r" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
  LG "$T/$r" transport set "$CH" --kind fs --path "$fshub" >/dev/null
  LG "$T/$r" thread open "$CH" t1 --subject gate --participants repo-a,repo-b --body open >/dev/null
  LG "$T/$r" sync "$CH" --push-only >/dev/null 2>&1 || { echo "FAIL [$tag/$which]: fixture — primeiro push legítimo falhou"; return 1; }
  mkdir -p "$outside"
  case "$which" in
    log)   rm -rf "$fshub/$CH/log";   ln -s "$outside" "$fshub/$CH/log" ;;
    blobs) rm -rf "$fshub/$CH/blobs"; ln -s "$outside" "$fshub/$CH/blobs" ;;
    hub)   rm -rf "${fshub:?}/$CH";   ln -s "$outside" "$fshub/$CH" ;;
  esac
  printf 'corpo %s\n' "$which" > "$T/corpo-$r.md"
  LG "$T/$r" send "$CH" --thread t1 --kind note --subject m2 --body-file "$T/corpo-$r.md" >/dev/null
  local out rc=0
  out="$(LG "$T/$r" sync "$CH" --push-only 2>&1)" || rc=$?
  local res=0 escaped
  escaped="$(listing "$outside")"
  if [ -n "$escaped" ]; then
    echo "FAIL [$tag/fs-$which]: escrita escapou do hub para $outside: $(echo "$escaped" | tr '\n' ' ')"
    res=1
  fi
  if [ "$rc" -eq 0 ]; then
    echo "FAIL [$tag/fs-$which]: push com $which como symlink terminou com rc 0"
    res=1
  elif ! grep -qi "link simbólico" <<<"$out"; then
    echo "FAIL [$tag/fs-$which]: recusa não diz que encontrou link simbólico: $out"
    res=1
  fi
  return "$res"
}

# ── [import-*] ───────────────────────────────────────────────────────────────────────────────────
craft() { # craft <lib> <json> — calcula content_sha
  node - "$1" "$2" <<'NODEEOF'
const { pathToFileURL } = require('url');
const { join } = require('path');
(async () => {
  const [, , lib, json] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const msg = JSON.parse(json);
  msg.content_sha = M.computeContentSha(msg);
  process.stdout.write(JSON.stringify(msg));
})();
NODEEOF
}
peer_msg() { # peer_msg <lib> <seq> <body_ref>
  craft "$1" "{\"msg_id\":\"repo-p-$(printf '%04d' "$2")\",\"channel\":\"$CH\",\"thread_id\":\"t1\",\"sender\":\"repo-p\",\"seq\":$2,\"lamport\":$2,\"kind\":\"note\",\"in_reply_to\":null,\"requires_ack\":false,\"subject\":\"anexo\",\"body_ref\":\"$3\",\"refs\":{\"change_id\":null,\"contract_files\":[],\"commit\":null},\"created_at\":\"2026-01-01T00:00:00Z\",\"trust\":\"self\"}"
}
file_mode() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null; }

# scen_import_nome <tag> <scripts> — rc 0 = guarda segurou; rc 1 = blob fora do formato instalado.
scen_import_nome() {
  local tag="$1" scripts="$2" r="imp-$1" bundle="$T/bundle-nome-$1"
  mk_repo "$r" "$scripts"
  LG "$T/$r" open "$CH" --self repo-i --participants repo-i,repo-p >/dev/null
  mkdir -p "$bundle/log" "$bundle/blobs"
  printf '#!/bin/sh\necho pwned > "%s/pwned"\n' "$T" > "$bundle/blobs/post-commit"
  chmod 0755 "$bundle/blobs/post-commit"
  peer_msg "$T/$r/.forge/scripts/lib" 1 "blobs/post-commit" > "$bundle/log/repo-p.jsonl"
  echo >> "$bundle/log/repo-p.jsonl"
  LG "$T/$r" import "$CH" --from "$bundle" >/dev/null 2>&1 || true
  local res=0
  if [ -e "$T/$r/.forge/liaison/$CH/blobs/post-commit" ]; then
    echo "FAIL [$tag/import-nome]: blob de peer com nome fora do formato content-addressed foi instalado (modo $(file_mode "$T/$r/.forge/liaison/$CH/blobs/post-commit"))"
    res=1
  fi
  if grep -q '"repo-p-0001"' "$T/$r/.forge/liaison/$CH/log/repo-p.jsonl" 2>/dev/null; then
    echo "FAIL [$tag/import-nome]: mensagem com body_ref fora do formato entrou no log local"
    res=1
  fi
  if [ ! -f "$T/$r/.forge/liaison/$CH/conflicts/repo-p-0001.json" ]; then
    echo "FAIL [$tag/import-nome]: nenhum conflito registrado para o body_ref fora do formato"
    res=1
  fi
  return "$res"
}

echo "[git-push]/[git-pull] branch com <canal>/blobs em modo 120000"
scen_git real "$REAL_SCRIPTS" && echo "OK [git-push]/[git-pull]: recusados nomeando $CH/blobs, nada em .git/hooks" || fail=1

for which in log blobs hub; do
  echo "[fs-$which] hub fs com $which como link simbólico"
  scen_fs real "$REAL_SCRIPTS" "$which" && echo "OK [fs-$which]: push recusado, nada escrito fora do hub" || fail=1
done

echo "[import-nome] body_ref de peer fora do formato content-addressed"
scen_import_nome real "$REAL_SCRIPTS" && echo "OK [import-nome]: conflito registrado, nada instalado" || fail=1

echo "[import-sha] body_ref content-addressed com conteúdo que não confere"
r=imp-sha; bundle="$T/bundle-sha"
mk_repo "$r" "$REAL_SCRIPTS"
LG "$T/$r" open "$CH" --self repo-i --participants repo-i,repo-p >/dev/null
mkdir -p "$bundle/log" "$bundle/blobs"
fake="0000000000000000000000000000000000000000000000000000000000000000-corpo.md"
printf 'conteúdo que não é o do nome\n' > "$bundle/blobs/$fake"
peer_msg "$T/$r/.forge/scripts/lib" 1 "blobs/$fake" > "$bundle/log/repo-p.jsonl"; echo >> "$bundle/log/repo-p.jsonl"
LG "$T/$r" import "$CH" --from "$bundle" >/dev/null 2>&1 || true
if [ -e "$T/$r/.forge/liaison/$CH/blobs/$fake" ]; then
  echo "FAIL [import-sha]: blob com sha que não confere com o nome foi instalado"; fail=1
elif [ ! -f "$T/$r/.forge/liaison/$CH/conflicts/repo-p-0001.json" ]; then
  echo "FAIL [import-sha]: nenhum conflito registrado para o blob adulterado"; fail=1
else
  echo "OK [import-sha]: blob adulterado recusado como conflito"
fi

echo "[import-modo] blob legítimo de peer com 0755 é instalado com 0644"
r=imp-modo; bundle="$T/bundle-modo"
mk_repo "$r" "$REAL_SCRIPTS"
LG "$T/$r" open "$CH" --self repo-i --participants repo-i,repo-p >/dev/null
mkdir -p "$bundle/log" "$bundle/blobs"
printf 'corpo legítimo\n' > "$T/legit.md"
legit="$(shasum -a 256 "$T/legit.md" | cut -d' ' -f1)-legit.md"
cp "$T/legit.md" "$bundle/blobs/$legit"; chmod 0755 "$bundle/blobs/$legit"
peer_msg "$T/$r/.forge/scripts/lib" 1 "blobs/$legit" > "$bundle/log/repo-p.jsonl"; echo >> "$bundle/log/repo-p.jsonl"
LG "$T/$r" import "$CH" --from "$bundle" >/dev/null 2>&1 || true
inst="$T/$r/.forge/liaison/$CH/blobs/$legit"
if [ ! -f "$inst" ]; then
  echo "FAIL [import-modo]: blob legítimo não foi instalado (controle positivo)"; fail=1
elif [ "$(file_mode "$inst")" != "644" ]; then
  echo "FAIL [import-modo]: blob instalado com modo $(file_mode "$inst"), esperado 644"; fail=1
else
  echo "OK [import-modo]: blob legítimo instalado com 0644"
fi

# ── [recontrole] guardas neutralizadas: a escrita PRECISA escapar ───────────────────────────────
echo "[recontrole] mesmas fixtures contra a cópia mutante dos scripts"
if scen_git mut "$MUT_SCRIPTS" >/dev/null; then
  echo "FAIL [recontrole/git]: sem as guardas o cenário git continuou seguro — a fixture não está armada"; fail=1
else
  echo "OK [recontrole/git]: sem as guardas, o cenário git reprova"
fi
for which in log blobs; do
  if scen_fs mut "$MUT_SCRIPTS" "$which" >/dev/null; then
    echo "FAIL [recontrole/fs-$which]: sem a guarda o cenário fs-$which continuou seguro"; fail=1
  else
    echo "OK [recontrole/fs-$which]: sem a guarda, o cenário reprova"
  fi
done
if scen_import_nome mut "$MUT_SCRIPTS" >/dev/null; then
  echo "FAIL [recontrole/import-nome]: sem a guarda o import continuou recusando"; fail=1
else
  echo "OK [recontrole/import-nome]: sem a guarda, o blob fora do formato é instalado"
fi

[ "$fail" -eq 0 ] || exit 1
echo "PASS — link simbólico no ponto de encontro nunca leva escrita para fora do hub; import só instala blob content-addressed conferido, com 0644"
exit 0
