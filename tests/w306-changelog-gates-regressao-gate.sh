#!/usr/bin/env bash
# Gate W294 — regressão dedicada aos gates released/preserve (TASK-13, add-unify-changelog-skill)
# com os 4 controles descritos na issue #238 item 4:
#   [1] versao publicada ALTERADA (1 byte) entre o arquivo anterior e o novo → FAIL released
#   [2] versao publicada REMOVIDA no arquivo novo → FAIL released
#   [3] bloco (### Added) do arquivo anterior removido sem substituto → FAIL preserve
#   [4] conjunto vazio comparado a um arquivo anterior vazio → passa (released e preserve)
#
# Preâmbulo de isolamento de GIT_DIR/GIT_WORK_TREE/etc. (LDG-0201) — herdado de
# tests/changelog-merge-gate.sh (vítima original do w248, removida na TASK-16 deste change):
# este arquivo nasce sendo a NOVA vítima do w248, e precisa do mesmo preâmbulo, senão os
# cenários que o w248 monta sobre ele (ex.: mutação do preâmbulo) ficam com controle vazio. Os
# gates released/preserve em si não chamam git — mas este arquivo também INICIALIZA um
# repositório sintético com comandos git SEM `-C`/`--git-dir` (igual ao padrão vulnerável do
# changelog-merge-gate.sh antigo), só para que o preâmbulo tenha algo real a proteger: sem isso,
# a mutação [2] do w248 (remover a linha do preâmbulo) não teria efeito observável nenhum.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASED="$WS/template/.forge/skills/readme-generator/scripts/gates/released.mjs"
PRESERVE="$WS/template/.forge/skills/readme-generator/scripts/gates/preserve.mjs"
[ -f "$RELEASED" ]
[ -f "$PRESERVE" ]

T="$(mktemp -d /tmp/forge-w294.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# Repositório sintético, sem relação funcional com released/preserve: existe só para exercitar
# comandos git SEM escopo (nenhum -C, nenhum --git-dir), no mesmo padrão de risco do
# changelog-merge-gate.sh original — é o que dá ao preâmbulo algo real a isolar.
(
  cd "$T"
  git init -q
  git config user.email "t@t"; git config user.name "t"
  git config commit.gpgsign false
  printf 'x\n' > "$T/sentinela-git.txt"
  git add -A
  git commit -qm "chore: sentinela de isolamento (w294)" >/dev/null
)

# ── [1] versão publicada alterada (1 byte) ──────────────────────────────────────────────────
echo "[1] versao publicada ALTERADA (1 byte) → FAIL released"
cat > "$T/old1.md" <<'EOF'
# Changelog

## [Unreleased]

### Added
- em andamento

## [1.0.0] - 2026-01-01

### Added
- primeira versao
EOF
cp "$T/old1.md" "$T/new1.md"
sed -i.bak 's/primeira versao/primeira versao!/' "$T/new1.md"; rm -f "$T/new1.md.bak"
if node "$RELEASED" "$T/old1.md" "$T/new1.md" >"$T/out1.log" 2>&1; then
  echo "FAIL [1]: released passou com 1 byte alterado numa versao publicada"; cat "$T/out1.log"; exit 1
fi
grep -q 'FAIL released' "$T/out1.log" || { echo "FAIL [1]: saida sem 'FAIL released' (saida: $(cat "$T/out1.log"))"; exit 1; }
echo "OK [1]"

# ── [2] versão publicada removida ───────────────────────────────────────────────────────────
echo "[2] versao publicada REMOVIDA no arquivo novo → FAIL released"
cat > "$T/new2.md" <<'EOF'
# Changelog

## [Unreleased]

### Added
- em andamento
EOF
if node "$RELEASED" "$T/old1.md" "$T/new2.md" >"$T/out2.log" 2>&1; then
  echo "FAIL [2]: released passou com a versao [1.0.0] removida"; cat "$T/out2.log"; exit 1
fi
grep -q 'FAIL released' "$T/out2.log" || { echo "FAIL [2]: saida sem 'FAIL released' (saida: $(cat "$T/out2.log"))"; exit 1; }
echo "OK [2]"

# ── [3] bloco removido sem substituto ───────────────────────────────────────────────────────
echo "[3] bloco (### Added) removido sem substituto → FAIL preserve"
cat > "$T/old3.md" <<'EOF'
# Changelog

## [Unreleased]

### Added
- item a preservar
EOF
cat > "$T/new3.md" <<'EOF'
# Changelog

## [Unreleased]

### Fixed
- outra coisa
EOF
if node "$PRESERVE" "$T/old3.md" "$T/new3.md" >"$T/out3.log" 2>&1; then
  echo "FAIL [3]: preserve passou com bloco removido sem substituto"; cat "$T/out3.log"; exit 1
fi
grep -q 'FAIL preserve' "$T/out3.log" || { echo "FAIL [3]: saida sem 'FAIL preserve' (saida: $(cat "$T/out3.log"))"; exit 1; }
echo "OK [3]"

# ── [4] conjunto vazio comparado a arquivo anterior vazio → passa ──────────────────────────
echo "[4] conjunto vazio comparado a arquivo anterior vazio → passa (released e preserve)"
: > "$T/old4.md"
: > "$T/new4.md"
node "$RELEASED" "$T/old4.md" "$T/new4.md" >"$T/out4r.log" 2>&1 \
  || { echo "FAIL [4]: released reprovou arquivo anterior vazio contra novo vazio"; cat "$T/out4r.log"; exit 1; }
node "$PRESERVE" "$T/old4.md" "$T/new4.md" >"$T/out4p.log" 2>&1 \
  || { echo "FAIL [4]: preserve reprovou arquivo anterior vazio contra novo vazio"; cat "$T/out4p.log"; exit 1; }
echo "OK [4]"

echo "PASS w294-changelog-gates-regressao"
