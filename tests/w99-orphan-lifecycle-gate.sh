#!/usr/bin/env bash
# Gate W99 — reconciliação de lifecycle: detecção de changes órfãos (FIX-1) + surface
# no doctor (FIX-2) + avanço de status no caminho module-based (FIX-4).
#   [1] detector: change verified em active/ → merged_unarchived
#   [2] detector: TASKs 100% mas status tasks-ready → done_not_advanced
#   [3] detector: implemented + branch mergeada → merged_unarchived (branch-merged);
#       implemented SEM branch mergeada → NÃO é órfão (fluxo normal)
#   [4] detector: sem git → ainda classifica verified (tolerante), sem crash
#   [5] detector: sem specs/active → objeto vazio (no-op)
#   [6] spec-advance-module: tasks-ready → implementing → implemented, idempotente;
#       módulo sem change mapeável → SKIP (nunca quebra)
#   [7] doctor: sem órfão imprime linha ok; com órfão imprime `·` e NÃO altera o exit
#       (advisory non-load-bearing)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w99.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
OC="$T/.forge/scripts/lib/orphan-changes.mjs"
SN="$T/.forge/scripts/spec-new.sh"; ST="$T/.forge/scripts/spec-transition.sh"
AV="$T/.forge/scripts/spec-advance-module.sh"; DR="$T/.forge/scripts/doctor.sh"
git -C "$T" init -q
git -C "$T" -c user.email=t@t -c user.name=t add -A >/dev/null
git -C "$T" -c user.email=t@t -c user.name=t commit -qm init >/dev/null
INT="$(git -C "$T" rev-parse --abbrev-ref HEAD)"

buckets() { node "$OC" "$T" --integration "$INT" --lines 2>/dev/null; }
has() { buckets | grep -qE "^$1"$'\t'"$2"$'\t'; }

mk() { # mk <id> <scale> "<status chain via spec-transition>"
  FORGE_ROOT="$T" bash "$SN" "$1" --type feature --scale "$2" >/dev/null
  for s in $3; do FORGE_ROOT="$T" bash "$ST" "$1" "$s" >/dev/null; done
}
# set_status: força o status no manifest (o detector só lê `status:` — sem depender do
# verification.yaml que a transição a `verified` exigiria; é o mesmo campo que produção lê).
set_status() { perl -pi -e "s/^status: .*/status: $2/" "$T/.forge/specs/active/$1/manifest.yaml"; }

echo "[1] verified → merged_unarchived"
FORGE_ROOT="$T" bash "$SN" chg-ver --type feature --scale 0 >/dev/null
set_status chg-ver verified
has merged_unarchived chg-ver || { echo "FAIL: chg-ver não é merged_unarchived"; buckets; exit 1; }
echo "OK [1]"

echo "[2] TASKs 100% + tasks-ready → done_not_advanced"
mk chg-done 0 "tasks-ready"
# reescreve tasks.md com todas as TASKs [X]
cat > "$T/.forge/specs/active/chg-done/tasks.md" <<'EOF'
# Tasks
> legenda: `[ ]` todo · `[X]` done
- [X] TASK-01 — algo (paths: x)
- [X] TASK-02 — outro (paths: y)
EOF
has done_not_advanced chg-done || { echo "FAIL: chg-done não é done_not_advanced"; buckets; exit 1; }
# não deve estar em merged_unarchived (precedência)
buckets | grep -qE "^merged_unarchived"$'\t'"chg-done"$'\t' && { echo "FAIL: chg-done duplicado em merged_unarchived"; exit 1; }
echo "OK [2]"

echo "[3] implemented: só é órfão se a branch estiver mergeada"
mk chg-impl 0 "tasks-ready implementing implemented"
# sem branch → NÃO órfão
buckets | grep -qE $'\t'"chg-impl"$'\t' && { echo "FAIL: chg-impl (implemented, sem branch) não deveria ser órfão"; buckets; exit 1; }
# cria branch mapeável e merge na integração
git -C "$T" checkout -q -b feature/chg-impl
echo x > "$T/impl-marker.txt"; git -C "$T" add -A >/dev/null
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: chg-impl work" >/dev/null
git -C "$T" checkout -q "$INT"
git -C "$T" -c user.email=t@t -c user.name=t merge --no-ff -q feature/chg-impl -m "merge chg-impl" >/dev/null
has merged_unarchived chg-impl || { echo "FAIL: chg-impl mergeado não virou merged_unarchived"; buckets; exit 1; }
echo "OK [3]"

echo "[4] sem git → ainda classifica verified, sem crash"
N="$(mktemp -d /tmp/forge-w99-nogit.XXXXXX)"
mkdir -p "$N/.forge/specs/active/z"
printf 'status: verified\n' > "$N/.forge/specs/active/z/manifest.yaml"
if ! out="$(node "$OC" "$N" 2>&1)"; then echo "FAIL: detector crashou sem git"; echo "$out"; rm -rf "$N"; exit 1; fi
printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);if(!j.merged_unarchived.some(e=>e.id==="z"))process.exit(1)})' || { echo "FAIL: verified não detectado sem git"; rm -rf "$N"; exit 1; }
rm -rf "$N"
echo "OK [4]"

echo "[5] sem specs/active → objeto vazio"
E="$(mktemp -d /tmp/forge-w99-empty.XXXXXX)"
node "$OC" "$E" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);if(j.merged_unarchived.length||j.done_not_advanced.length)process.exit(1)})' || { echo "FAIL: dir sem specs não deu vazio"; rm -rf "$E"; exit 1; }
rm -rf "$E"
echo "OK [5]"

echo "[6] spec-advance-module avança e é idempotente; módulo sem change → SKIP"
mk paymod 0 "tasks-ready"
FORGE_ROOT="$T" bash "$AV" paymod implementing >/dev/null
[ "$(awk -F': ' '$1=="status"{print $2}' "$T/.forge/specs/active/paymod/manifest.yaml")" = "implementing" ] || { echo "FAIL: paymod não avançou p/ implementing"; exit 1; }
# idempotente
FORGE_ROOT="$T" bash "$AV" paymod implementing | grep -q NOOP || { echo "FAIL: 2ª chamada implementing não foi NOOP"; exit 1; }
# implemented (dois passos a partir de tasks-ready seria coberto; aqui só falta 1)
FORGE_ROOT="$T" bash "$AV" paymod implemented >/dev/null
[ "$(awk -F': ' '$1=="status"{print $2}' "$T/.forge/specs/active/paymod/manifest.yaml")" = "implemented" ] || { echo "FAIL: paymod não avançou p/ implemented"; exit 1; }
# módulo inexistente → SKIP, exit 0
FORGE_ROOT="$T" bash "$AV" modulo-fantasma implemented | grep -q SKIP || { echo "FAIL: módulo sem change não deu SKIP"; exit 1; }
echo "OK [6]"

echo "[7] doctor: orfao vira marcador informativo sem mudar o exit (non-load-bearing)"
# baseline exit ANTES de introduzir órfão adicional (T já tem órfãos dos passos acima; medimos
# apenas que o check NÃO é load-bearing — remover/adicionar órfão não altera o exit do doctor).
CLEAN="$(mktemp -d /tmp/forge-w99-doc.XXXXXX)"
cp -R "$WS/template/.forge" "$CLEAN/.forge"
git -C "$CLEAN" init -q
git -C "$CLEAN" -c user.email=t@t -c user.name=t add -A >/dev/null
git -C "$CLEAN" -c user.email=t@t -c user.name=t commit -qm init >/dev/null
# doctor.sh deriva ROOT do próprio local (ignora FORGE_ROOT) → invoque o doctor do CLEAN.
DRC="$CLEAN/.forge/scripts/doctor.sh"
set +e
out_clean="$(bash "$DRC" 2>&1)"; rc_clean=$?
set -e
printf '%s' "$out_clean" | grep -q "sem changes órfãos" || { echo "FAIL: doctor sem órfão não imprimiu linha ok"; echo "$out_clean" | grep -i orf; rm -rf "$CLEAN"; exit 1; }
# introduz um órfão verified (status setado direto — detector lê só `status:`)
FORGE_ROOT="$CLEAN" bash "$CLEAN/.forge/scripts/spec-new.sh" orf --type feature --scale 0 >/dev/null
perl -pi -e 's/^status: .*/status: verified/' "$CLEAN/.forge/specs/active/orf/manifest.yaml"
set +e
out_orph="$(bash "$DRC" 2>&1)"; rc_orph=$?
set -e
printf '%s' "$out_orph" | grep -qE "· .*orf.*mergeado/verificado|orf.*sem baixa" || { echo "FAIL: doctor não sinalizou o órfão 'orf'"; echo "$out_orph" | grep -i orf; rm -rf "$CLEAN"; exit 1; }
[ "$rc_orph" = "$rc_clean" ] || { echo "FAIL: check de órfão mudou o exit do doctor ($rc_clean -> $rc_orph) — deveria ser non-load-bearing"; rm -rf "$CLEAN"; exit 1; }
rm -rf "$CLEAN"
echo "OK [7]"

echo "[8] detector NÃO casa branch por substring (auth vs feature/oauth2-support)"
mk chg-auth 0 "tasks-ready implementing implemented"
git -C "$T" checkout -q -b feature/oauth2-support
echo oauth > "$T/oauth.txt"; git -C "$T" add -A >/dev/null
git -C "$T" -c user.email=t@t -c user.name=t commit -qm "feat: oauth2" >/dev/null
git -C "$T" checkout -q "$INT"
git -C "$T" -c user.email=t@t -c user.name=t merge --no-ff -q feature/oauth2-support -m "merge oauth2" >/dev/null
buckets | grep -qE $'\t'"chg-auth"$'\t' && { echo "FAIL: 'chg-auth' virou órfão por substring de 'oauth2'"; buckets; exit 1; }
echo "OK [8]"

echo "PASS w99-orphan-lifecycle-gate"
