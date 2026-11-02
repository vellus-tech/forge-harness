#!/usr/bin/env bash
# Gate — TASK-30/TASK-31 de add-liaison-handoff-baton (REQ-14, design §2.10): `baton offer
# --from-handoff` usa o HANDOFF.md da worktree corrente como corpo, pelo MESMO caminho de
# --body-file (teto de 64 KB + varredura de segredo), gerando-o na hora se ausente, tudo antes
# de qualquer gravação.
#   [from-handoff-exclusivo] --from-handoff junto de --body/--body-file → rc 1
#   [from-handoff-gerado] HANDOFF.md ausente, change ativo presente → gerado na hora, oferta ok
#   [from-handoff-existente] HANDOFF.md já presente → reaproveitado sem regenerar (sem change
#     ativo nenhum, então uma tentativa de regeneração falharia — o sucesso aqui prova o reuso)
#   [from-handoff-teto] HANDOFF.md > 64 KB → rc 1, nada gravado no log próprio
#   [from-handoff-segredo] HANDOFF.md com achado de segredo → rc 1, nada gravado no log próprio
#   [from-handoff-falha-geracao] HANDOFF.md ausente e nenhum change ativo → geração falha, rc 1,
#     nada gravado
#   [from-handoff-gate-existente] gate pré-existente do handoff-gen continua verde
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-liaison-baton-handoff.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=baton-handoff-gate

mk_repo() {
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -q -m "chore: init $1" >/dev/null
}

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }
own_log_count() { local repo="$1"; wc -l < "$T/$repo/.forge/liaison/$CH/log/repo-a.jsonl" 2>/dev/null | tr -d ' '; }

mk_repo a
LG a open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG a thread open "$CH" t1 --subject "handoff" --participants repo-a,repo-b --body "x" >/dev/null

# === [from-handoff-gerado] (primeiro cenário: precisa da implementação real para passar — os
# dois cenários de recusa pura abaixo já recusavam mesmo com o antigo stub "ainda não
# implementado", então sozinhos não provariam vermelho real) ===
DIR="$T/a/.forge/specs/active/demo-change"
mkdir -p "$DIR"
cat > "$DIR/manifest.yaml" <<'YAML'
id: demo-change
type: feature
scale: 2
status: implementing
YAML
cat > "$DIR/progress.json" <<'JSON'
{ "current_wave": 1, "done_stories": 0, "total_stories": 1, "done_tasks": 0, "total_tasks": 1 }
JSON
cat > "$DIR/deferrals.json" <<'JSON'
[]
JSON
out_gen="$(LG a baton offer "$CH" --thread t1 --subject "gerado-na-hora" --from-handoff 2>&1)"
rc_gen=$?
bat_gen="$(printf '%s' "$out_gen" | grep '^OK baton offer' | sed -E 's/^OK baton offer — //')"
if [ "$rc_gen" -eq 0 ] && [ -f "$T/a/.forge/HANDOFF.md" ] && [ -n "$bat_gen" ] && grep -q "demo-change" "$T/a/.forge/HANDOFF.md"; then
  echo "OK [from-handoff-gerado]: HANDOFF.md ausente foi gerado na hora, oferta criada"
else
  echo "FAIL [from-handoff-gerado]: esperava rc 0, HANDOFF.md gerado e baton_id, achou rc=$rc_gen out=$out_gen"
  fail=1
fi
rm -f "$T/a/.forge/HANDOFF.md"
rm -rf "$DIR"

# === [from-handoff-exclusivo] ===
out_excl="$(LG a baton offer "$CH" --thread t1 --subject "exclusivo" --body "x" --from-handoff 2>&1)"
rc_excl=$?
if [ "$rc_excl" -ne 0 ] && echo "$out_excl" | grep -qi "exclusivo"; then
  echo "OK [from-handoff-exclusivo]: --from-handoff com --body recusa com rc != 0"
else
  echo "FAIL [from-handoff-exclusivo]: esperava rc != 0 e 'exclusivo', achou rc=$rc_excl out=$out_excl"
  fail=1
fi

# === [from-handoff-falha-geracao] ===
before_fg="$(own_log_count a)"
out_fg="$(LG a baton offer "$CH" --thread t1 --subject "falha-geracao" --from-handoff 2>&1)"
rc_fg=$?
after_fg="$(own_log_count a)"
if [ "$rc_fg" -ne 0 ] && [ "$before_fg" = "$after_fg" ]; then
  echo "OK [from-handoff-falha-geracao]: sem change ativo e sem HANDOFF.md, geração falha, rc != 0, nada gravado"
else
  echo "FAIL [from-handoff-falha-geracao]: esperava rc != 0 e log inalterado, achou rc=$rc_fg antes=$before_fg depois=$after_fg out=$out_fg"
  fail=1
fi

# === [from-handoff-existente] ===
mkdir -p "$T/a/.forge"
printf '# HANDOFF\nMARCA-HANDOFF-EXISTENTE-%s\n' "$CH" > "$T/a/.forge/HANDOFF.md"
out_ex="$(LG a baton offer "$CH" --thread t1 --subject "existente" --from-handoff 2>&1)"
rc_ex=$?
bat_ex="$(printf '%s' "$out_ex" | grep '^OK baton offer' | sed -E 's/^OK baton offer — //')"
blob_hit=""
if [ "$rc_ex" -eq 0 ] && [ -n "$bat_ex" ]; then
  blob_hit="$(grep -rl "MARCA-HANDOFF-EXISTENTE" "$T/a/.forge/liaison/$CH/blobs" 2>/dev/null | head -1)"
fi
if [ "$rc_ex" -eq 0 ] && [ -n "$blob_hit" ]; then
  echo "OK [from-handoff-existente]: HANDOFF.md pré-existente reaproveitado sem regenerar (sem change ativo, teria falhado se tentasse)"
else
  echo "FAIL [from-handoff-existente]: esperava rc 0 e o conteúdo pré-existente no blob, achou rc=$rc_ex out=$out_ex blob_hit=$blob_hit"
  fail=1
fi

# === [from-handoff-teto] ===
rm -f "$T/a/.forge/HANDOFF.md"
head -c 70000 /dev/zero | tr '\0' 'x' > "$T/a/.forge/HANDOFF.md"
before_cap="$(own_log_count a)"
out_cap="$(LG a baton offer "$CH" --thread t1 --subject "acima-do-teto" --from-handoff 2>&1)"
rc_cap=$?
after_cap="$(own_log_count a)"
if [ "$rc_cap" -ne 0 ] && [ "$before_cap" = "$after_cap" ]; then
  echo "OK [from-handoff-teto]: HANDOFF.md acima de 64 KB recusa com rc != 0, nada gravado"
else
  echo "FAIL [from-handoff-teto]: esperava rc != 0 e log inalterado, achou rc=$rc_cap antes=$before_cap depois=$after_cap out=$out_cap"
  fail=1
fi

# === [from-handoff-segredo] ===
rm -f "$T/a/.forge/HANDOFF.md"
printf '# HANDOFF\nAKIAABCDEFGHIJKLMNOP\n' > "$T/a/.forge/HANDOFF.md"
before_sec="$(own_log_count a)"
out_sec="$(LG a baton offer "$CH" --thread t1 --subject "com-segredo" --from-handoff 2>&1)"
rc_sec=$?
after_sec="$(own_log_count a)"
if [ "$rc_sec" -ne 0 ] && [ "$before_sec" = "$after_sec" ] && echo "$out_sec" | grep -qi "segredo"; then
  echo "OK [from-handoff-segredo]: HANDOFF.md com achado de segredo recusa com rc != 0, nada gravado"
else
  echo "FAIL [from-handoff-segredo]: esperava rc != 0, log inalterado e menção a segredo, achou rc=$rc_sec antes=$before_sec depois=$after_sec out=$out_sec"
  fail=1
fi
rm -f "$T/a/.forge/HANDOFF.md"

# === [from-handoff-gate-existente] ===
if bash "$WS/tests/w60-handoff-gen-gate.sh" > /tmp/w60-from-handoff-sanity.log 2>&1; then
  echo "OK [from-handoff-gate-existente]: gate pré-existente do handoff-gen continua verde"
else
  echo "FAIL [from-handoff-gate-existente]: w60-handoff-gen-gate.sh quebrou — $(tail -5 /tmp/w60-from-handoff-sanity.log)"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — baton offer --from-handoff (REQ-14)"
exit 0
