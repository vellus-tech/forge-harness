#!/usr/bin/env bash
# Funções comuns às fixtures do eval design-system-creator.
# Uso: source lib.sh; forge_consumer "$ALVO" rotaviva
set -euo pipefail
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Monta um consumidor do harness em $1 e fixa a identidade do projeto como $2.
forge_consumer() {
  local alvo="$1" nome="$2" atual f
  mkdir -p "$alvo"
  node "$FORGE_BIN" init --target "$alvo" -y --no-plugin >/dev/null
  atual="$(sed -n 's/^project_name: *//p' "$alvo/AGENTS.md" | head -1)"
  for f in "$alvo/AGENTS.md" "$alvo/CLAUDE.md" "$alvo/.forge/FORGE.md" "$alvo/.forge/context.md"; do
    [ -f "$f" ] && [ ! -L "$f" ] && [ -n "$atual" ] && perl -pi -e "s/\Q$atual\E/$nome/g" "$f"
  done
  return 0
}

# Copia o bundle de handoff já extraído e gera os PNGs de logo/mark (1x1, a partir de base64).
handoff_bundle() {
  local alvo="$1" png d n
  mkdir -p "$alvo/design-handoff"
  cp -R "$SHARED_DIR/design-handoff/." "$alvo/design-handoff/"
  png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
  d="$alvo/design-handoff/rotaviva-design-system/project/assets"
  mkdir -p "$d/logos" "$d/brand"
  for n in color black white; do printf '%s' "$png" | base64 -D > "$d/logos/rotaviva-logo-$n.png" 2>/dev/null || printf '%s' "$png" | base64 -d > "$d/logos/rotaviva-logo-$n.png"; done
  for n in teal black white; do printf '%s' "$png" | base64 -D > "$d/brand/rotaviva-mark-$n.png" 2>/dev/null || printf '%s' "$png" | base64 -d > "$d/brand/rotaviva-mark-$n.png"; done
}

# Monorepo JS mínimo (sem node_modules).
monorepo_root() {
  local alvo="$1"
  cat > "$alvo/package.json" <<'JSON'
{
  "name": "rotaviva",
  "private": true,
  "type": "module",
  "packageManager": "pnpm@9.12.0",
  "engines": { "node": ">=22" },
  "workspaces": ["packages/*"],
  "scripts": {}
}
JSON
  printf 'packages:\n  - "packages/*"\n' > "$alvo/pnpm-workspace.yaml"
  printf '22\n' > "$alvo/.nvmrc"
  printf 'node_modules/\ndist/\nstorybook-static/\ncoverage/\n' >> "$alvo/.gitignore"
}

# Remove as superfícies do harness que contaminariam o baseline, faz o commit inicial em main (árvore limpa) e repete a remoção no fim, como exige o protocolo.
finalize() {
  local alvo="$1"
  rm -rf "$alvo/.forge/skills" "$alvo/.forge/agents" "$alvo/.claude/skills" "$alvo/.claude/agents" "$alvo/plugin"
  git -C "$alvo" init -q -b main
  git -C "$alvo" add -A
  git -C "$alvo" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "chore: estado inicial do projeto"
  rm -rf "$alvo/.forge/skills" "$alvo/.forge/agents" "$alvo/.claude/skills" "$alvo/.claude/agents" "$alvo/plugin"
}
