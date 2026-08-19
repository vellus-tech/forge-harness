#!/usr/bin/env bash
# Gate W138 — story sharding obrigatória em scale >= 3 (issue #35), como SCRIPT.
#
# Por que existe: o contrato scale-adaptive já DECLARAVA que scale >= 3 soma story sharding ao
# fluxo (`commands/specs/spec.md` tabela de scale, `commands/specs/tasks.md`, e o próprio
# `spec-manifest.schema.json` já tinha `dev_loop.sharded`/`epic_context_compiled` e
# `quick_plan.skipped_phases` incluindo "story-sharding" no enum) — mas nada verificava que o
# shard de fato aconteceu antes de `/forge:implement` entrar no loop TASK a TASK.
# `dev_loop.sharded` podia ficar `false` para sempre e a implementação seguia em silêncio, sem
# `epic_context.md` nem stories auto-contidas. `validate-spec.mjs` é o ponto certo: já é chamado
# por `spec-transition.sh` ANTES de qualquer transição de status ser persistida (com rollback se
# reprovar), então o guard aqui cobre `/forge:implement` (chamada direta) e a transição
# `tasks-ready -> implementing` (via `spec-transition.sh`) com o mesmo código.
#
#   [1]  CONTROLE — scale 3, sharded + epic_context_compiled + stories válidas cobrindo todas as
#        tasks exatamente uma vez, acíclico → PASSA (sem isto nenhum vermelho abaixo prova nada)
#   [2]  scale 3, dev_loop.sharded: false → FAIL mencionando story sharding e /forge:shard
#   [3]  scale 3, sharded: true mas epic_context_compiled: false → FAIL
#   [4]  scale 3, dev_loop completo, mas stories/ não existe → FAIL explícito (não vacuidade)
#   [5]  scale 3, dev_loop completo, stories/ existe mas está vazio → FAIL explícito (vacuidade)
#   [6]  scale 3, uma TASK não aparece em nenhuma story → FAIL nomeando a TASK
#   [7]  scale 3, uma TASK aparece em duas stories → FAIL nomeando a duplicidade
#   [8]  scale 3, grafo depends_on das stories tem ciclo → FAIL nomeando o ciclo
#   [9]  scale 2, mesmo shape sem stories/ e sharded:false → continua PASSANDO (comportamento
#        atual preservado para scale < 3)
#   [10] scale 3, dispensa explícita via quick_plan.skipped_phases (block style) incluindo
#        "story-sharding" + justification → PASSA sem stories/ (dispensa não é omissão silenciosa)
#   [11] scale 3, mesma dispensa tentada em FLOW STYLE (`skipped_phases: [story-sharding]`) → FAIL
#        fechado — decisão registrada (LDG-0033): yaml-lite.mjs não parseia array flow-style não
#        vazio, então a tentativa vira string literal e reprova no formato de quick_plan já
#        existente (Array.isArray falha) em vez de conceder a dispensa em silêncio
#   [12] FIAÇÃO — spec-transition.sh reprova a transição tasks-ready -> implementing (scale 3, sem
#        shard) e faz rollback do manifest; após corrigir (sharded/epic_context_compiled + stories
#        válidas), a mesma transição passa
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
T="$(mktemp -d /tmp/forge-w138.XXXXXX)"
trap 'rm -rf "$T"' EXIT

MANIFEST_HEADER='id: change
type: feature
mode: feature-only
rigor: spec-first
status: implementing
created_at: 2026-08-19
updated_at: 2026-08-19
owner: milton
gates:
  requirements_reviewed: true
  design_reviewed: true
  tasks_reviewed: false
  implementation_verified: false
  human_archive_approval: false'

write_common_artifacts() {
  local ch="$1"
  printf '# Proposal\n\n## 1. Por quê\n\ntexto\n\n## 2. O que muda\n\ntexto\n' > "$ch/proposal.md"
  printf '# Design\n\ntexto\n' > "$ch/design.md"
  cat > "$ch/requirements.md" <<'EOF'
# Requirements

## REQ-01 — algo

Critérios de aceite: dado x, quando y, então z.

## REQ-02 — outro algo

Critérios de aceite: dado a, quando b, então c.
EOF
  cat > "$ch/tasks.md" <<'EOF'
# Tasks

## Wave 1 — base

- [ ] TASK-01 — cria o esquema (rastreia: REQ-01; paths: `src/db/schema.sql`; depende: —)
- [ ] TASK-02 — grava o registro (rastreia: REQ-01; paths: `src/store.ts`; depende: TASK-01)

## Wave 2 — superfície

- [ ] TASK-03 — processa o item (rastreia: REQ-02; paths: `src/handlers/itens.ts`; depende: TASK-02)
EOF
}

write_valid_stories() {
  local ch="$1"
  mkdir -p "$ch/stories"
  cat > "$ch/stories/STORY-01.md" <<'EOF'
---
story_id: STORY-01
epic: change
title: Esquema e registro
depends_on: []
status: todo
---

# STORY-01 — Esquema e registro

## Tasks

- [ ] TASK-01 — cria o esquema (paths: `src/db/schema.sql`)
- [ ] TASK-02 — grava o registro (paths: `src/store.ts`; depende: TASK-01)
EOF
  cat > "$ch/stories/STORY-02.md" <<'EOF'
---
story_id: STORY-02
epic: change
title: Endpoint
depends_on: [STORY-01]
status: todo
---

# STORY-02 — Endpoint

## Tasks

- [ ] TASK-03 — processa o item (paths: `src/handlers/itens.ts`; depende: TASK-02)
EOF
}

run_validate() { node "$LIB/validate-spec.mjs" "$1" 2>&1 || true; }

# ── [1] CONTROLE ──────────────────────────────────────────────────────────────────────────────
echo "[1] CONTROLE: scale 3, sharded + stories válidas cobrindo tudo → PASSA"
CH="$T/c1/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: true
  stories_path: stories/
  epic_context_compiled: true
EOF
write_common_artifacts "$CH"
write_valid_stories "$CH"
out="$(run_validate "$CH")"
grep -q '^OK change' <<< "$out" \
  || { echo "FAIL [1]: fixture íntegro reprovou — nenhum vermelho abaixo prova nada: $out"; exit 1; }
echo "OK [1]"

# ── [2] dev_loop.sharded: false ──────────────────────────────────────────────────────────────
echo "[2] scale 3, dev_loop.sharded:false → FAIL mencionando story sharding e /forge:shard"
CH="$T/c2/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: false
  stories_path: stories/
  epic_context_compiled: false
EOF
write_common_artifacts "$CH"
out="$(run_validate "$CH")"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [2]: validate-spec passou com dev_loop.sharded:false em scale 3: $out"; exit 1 ;;
esac
grep -qi 'story sharding' <<< "$out" || { echo "FAIL [2]: mensagem não menciona story sharding: $out"; exit 1; }
grep -q '/forge:shard' <<< "$out" || { echo "FAIL [2]: mensagem não indica a ação corretiva /forge:shard: $out"; exit 1; }
echo "OK [2]"

# ── [3] sharded:true mas epic_context_compiled:false ─────────────────────────────────────────
echo "[3] scale 3, sharded:true mas epic_context_compiled:false → FAIL"
CH="$T/c3/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: true
  stories_path: stories/
  epic_context_compiled: false
EOF
write_common_artifacts "$CH"
write_valid_stories "$CH"
out="$(run_validate "$CH")"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [3]: validate-spec passou com epic_context_compiled:false: $out"; exit 1 ;;
esac
grep -q 'epic_context_compiled' <<< "$out" || { echo "FAIL [3]: mensagem não cita epic_context_compiled: $out"; exit 1; }
echo "OK [3]"

# ── [4] stories/ ausente ──────────────────────────────────────────────────────────────────────
echo "[4] scale 3, dev_loop completo mas stories/ não existe → FAIL explícito"
CH="$T/c4/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: true
  stories_path: stories/
  epic_context_compiled: true
EOF
write_common_artifacts "$CH"
out="$(run_validate "$CH")"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [4]: validate-spec passou por vacuidade (stories/ ausente): $out"; exit 1 ;;
esac
echo "OK [4]"

# ── [5] stories/ vazio ────────────────────────────────────────────────────────────────────────
echo "[5] scale 3, stories/ existe mas está vazio → FAIL explícito (vacuidade)"
CH="$T/c5/change"; mkdir -p "$CH/stories"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: true
  stories_path: stories/
  epic_context_compiled: true
EOF
write_common_artifacts "$CH"
out="$(run_validate "$CH")"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [5]: validate-spec passou por vacuidade (stories/ vazio): $out"; exit 1 ;;
esac
echo "OK [5]"

# ── [6] TASK sem story ────────────────────────────────────────────────────────────────────────
echo "[6] scale 3, TASK-03 não aparece em nenhuma story → FAIL nomeando a TASK"
CH="$T/c6/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: true
  stories_path: stories/
  epic_context_compiled: true
EOF
write_common_artifacts "$CH"
mkdir -p "$CH/stories"
cat > "$CH/stories/STORY-01.md" <<'EOF'
---
story_id: STORY-01
epic: change
title: Esquema e registro
depends_on: []
status: todo
---

# STORY-01

## Tasks

- [ ] TASK-01 — cria o esquema (paths: `src/db/schema.sql`)
- [ ] TASK-02 — grava o registro (paths: `src/store.ts`; depende: TASK-01)
EOF
out="$(run_validate "$CH")"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [6]: validate-spec passou com TASK-03 sem story: $out"; exit 1 ;;
esac
grep -q 'TASK-03' <<< "$out" || { echo "FAIL [6]: mensagem não nomeia TASK-03: $out"; exit 1; }
echo "OK [6]"

# ── [7] TASK em duas stories ──────────────────────────────────────────────────────────────────
echo "[7] scale 3, TASK-02 aparece em duas stories → FAIL nomeando a duplicidade"
CH="$T/c7/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: true
  stories_path: stories/
  epic_context_compiled: true
EOF
write_common_artifacts "$CH"
mkdir -p "$CH/stories"
cat > "$CH/stories/STORY-01.md" <<'EOF'
---
story_id: STORY-01
epic: change
title: Esquema e registro
depends_on: []
status: todo
---

# STORY-01

## Tasks

- [ ] TASK-01 — cria o esquema (paths: `src/db/schema.sql`)
- [ ] TASK-02 — grava o registro (paths: `src/store.ts`; depende: TASK-01)
EOF
cat > "$CH/stories/STORY-02.md" <<'EOF'
---
story_id: STORY-02
epic: change
title: Endpoint (duplicando TASK-02 por engano)
depends_on: [STORY-01]
status: todo
---

# STORY-02

## Tasks

- [ ] TASK-02 — grava o registro (paths: `src/store.ts`)
- [ ] TASK-03 — processa o item (paths: `src/handlers/itens.ts`; depende: TASK-02)
EOF
out="$(run_validate "$CH")"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [7]: validate-spec passou com TASK-02 em duas stories: $out"; exit 1 ;;
esac
grep -q 'TASK-02' <<< "$out" || { echo "FAIL [7]: mensagem não nomeia TASK-02: $out"; exit 1; }
echo "OK [7]"

# ── [8] ciclo em depends_on ───────────────────────────────────────────────────────────────────
echo "[8] scale 3, ciclo STORY-01 <-> STORY-02 → FAIL nomeando o ciclo"
CH="$T/c8/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: true
  stories_path: stories/
  epic_context_compiled: true
EOF
write_common_artifacts "$CH"
mkdir -p "$CH/stories"
cat > "$CH/stories/STORY-01.md" <<'EOF'
---
story_id: STORY-01
epic: change
title: Esquema e registro
depends_on: [STORY-02]
status: todo
---

# STORY-01

## Tasks

- [ ] TASK-01 — cria o esquema (paths: `src/db/schema.sql`)
- [ ] TASK-02 — grava o registro (paths: `src/store.ts`; depende: TASK-01)
EOF
cat > "$CH/stories/STORY-02.md" <<'EOF'
---
story_id: STORY-02
epic: change
title: Endpoint
depends_on: [STORY-01]
status: todo
---

# STORY-02

## Tasks

- [ ] TASK-03 — processa o item (paths: `src/handlers/itens.ts`; depende: TASK-02)
EOF
out="$(run_validate "$CH")"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [8]: validate-spec passou com ciclo STORY-01 <-> STORY-02: $out"; exit 1 ;;
esac
grep -qi 'ciclo' <<< "$out" || { echo "FAIL [8]: mensagem não menciona ciclo: $out"; exit 1; }
echo "OK [8]"

# ── [9] scale 2 preserva comportamento atual ─────────────────────────────────────────────────
echo "[9] scale 2, mesmo shape sem stories/ e sharded:false → continua PASSANDO"
CH="$T/c9/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 2
dev_loop:
  sharded: false
  stories_path: stories/
  epic_context_compiled: false
EOF
write_common_artifacts "$CH"
out="$(run_validate "$CH")"
grep -q '^OK change' <<< "$out" \
  || { echo "FAIL [9]: scale 2 passou a exigir story sharding — regressão no comportamento existente: $out"; exit 1; }
echo "OK [9]"

# ── [10] dispensa explícita (block style) ────────────────────────────────────────────────────
echo "[10] scale 3, quick_plan.skipped_phases (block style) inclui story-sharding + justification → PASSA sem stories/"
CH="$T/c10/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: false
  stories_path: stories/
  epic_context_compiled: false
quick_plan:
  enabled: true
  skipped_phases:
    - story-sharding
  justification: "change trivial de config, sem valor em fatiar em stories"
EOF
write_common_artifacts "$CH"
out="$(run_validate "$CH")"
grep -q '^OK change' <<< "$out" \
  || { echo "FAIL [10]: dispensa explícita e válida não foi honrada: $out"; exit 1; }
echo "OK [10]"

# ── [11] dispensa em flow style → reprova fechado (LDG-0033) ────────────────────────────────
echo "[11] scale 3, dispensa em flow style [story-sharding] → FAIL fechado (yaml-lite não parseia flow array)"
CH="$T/c11/change"; mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
$MANIFEST_HEADER
scale: 3
dev_loop:
  sharded: false
  stories_path: stories/
  epic_context_compiled: false
quick_plan:
  enabled: true
  skipped_phases: [story-sharding]
  justification: "change trivial de config, sem valor em fatiar em stories"
EOF
write_common_artifacts "$CH"
out="$(run_validate "$CH")"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [11]: dispensa em flow style foi concedida em silêncio (LDG-0033 não fecha aqui): $out"; exit 1 ;;
esac
grep -qi 'skipped_phases' <<< "$out" || { echo "FAIL [11]: FAIL não aponta a causa (skipped_phases malformado): $out"; exit 1; }
echo "OK [11]"

# ── [12] FIAÇÃO no lifecycle ──────────────────────────────────────────────────────────────────
echo "[12] FIAÇÃO — spec-transition.sh reprova tasks-ready -> implementing sem shard, e passa depois de corrigido"
cp -R "$WS/template/.forge" "$T/.forge"
CHID="epic-w138"
CH="$T/.forge/specs/active/$CHID"
mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<EOF
id: $CHID
type: feature
mode: feature-only
rigor: spec-first
scale: 3
status: tasks-ready
created_at: 2026-08-19
updated_at: 2026-08-19
owner: milton
gates:
  requirements_reviewed: true
  design_reviewed: true
  tasks_reviewed: true
  implementation_verified: false
  human_archive_approval: false
dev_loop:
  sharded: false
  stories_path: stories/
  epic_context_compiled: false
EOF
write_common_artifacts "$CH"
before_sha="$(shasum "$CH/manifest.yaml" | awk '{print $1}')"
out="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/spec-transition.sh" "$CHID" implementing 2>&1 || true)"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [12]: spec-transition.sh permitiu implementing sem story sharding em scale 3: $out"; exit 1 ;;
esac
grep -qi 'story sharding' <<< "$out" || { echo "FAIL [12]: spec-transition.sh não mencionou story sharding: $out"; exit 1; }
after_sha="$(shasum "$CH/manifest.yaml" | awk '{print $1}')"
[ "$before_sha" = "$after_sha" ] || { echo "FAIL [12]: manifest.yaml não foi revertido após a reprovação"; exit 1; }
[ ! -f "$CH/manifest.yaml.bak" ] || { echo "FAIL [12]: .bak sobrou no disco após rollback"; exit 1; }
grep -q '^status: tasks-ready' "$CH/manifest.yaml" || { echo "FAIL [12]: status mudou apesar da reprovação"; exit 1; }

# corrige e confirma que a MESMA transição passa
sed -i.bak2 's/sharded: false/sharded: true/; s/epic_context_compiled: false/epic_context_compiled: true/' "$CH/manifest.yaml"
rm -f "$CH/manifest.yaml.bak2"
write_valid_stories "$CH"
out2="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/spec-transition.sh" "$CHID" implementing 2>&1 || true)"
grep -q "^OK $CHID: tasks-ready -> implementing" <<< "$out2" \
  || { echo "FAIL [12] CONTROLE: transição não passou após corrigir sharding: $out2"; exit 1; }
echo "OK [12]"

echo "PASS w138-story-shard-guard-gate"
