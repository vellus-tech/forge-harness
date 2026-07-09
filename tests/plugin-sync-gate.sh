#!/usr/bin/env bash
# Gate — plugin Claude Code "forge" + marketplace em sincronia com a fonte única:
#   [1] plugin/forge regenerado de template/.forge/commands é byte-idêntico ao commitado
#       (impede drift quando alguém edita comandos e esquece de rodar `npm run build:plugin`)
#   [2] versões casam: package.json == plugin/forge/.claude-plugin/plugin.json == marketplace.json
#   [3] o plugin achata sem colisão e cobre TODOS os comandos de template/.forge/commands
#   [4] (se `claude` disponível) marketplace + plugin validam em --strict
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS"
command -v node >/dev/null 2>&1 || { echo "FAIL (node necessário)"; exit 1; }

PKGV="$(node -p "require('./package.json').version")"
T="$(mktemp -d /tmp/forge-plugin-sync.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] plugin/forge em sincronia com template/.forge/commands"
node template/.forge/scripts/lib/plugin-build.mjs \
  --commands template/.forge/commands --out "$T/forge" --version "$PKGV" >/dev/null
if ! diff -r "$T/forge" plugin/forge >/dev/null 2>&1; then
  echo "FAIL: plugin/forge dessincronizado — rode: npm run build:plugin"
  diff -r "$T/forge" plugin/forge | head -20 || true
  exit 1
fi
echo "OK [1]"

echo "[2] versões casam (package == plugin == marketplace)"
PJV="$(node -p "require('./plugin/forge/.claude-plugin/plugin.json').version")"
MPV="$(node -p "require('./.claude-plugin/marketplace.json').plugins[0].version")"
[ "$PKGV" = "$PJV" ] || { echo "FAIL: plugin.json version ($PJV) != package.json ($PKGV)"; exit 1; }
[ "$PKGV" = "$MPV" ] || { echo "FAIL: marketplace version ($MPV) != package.json ($PKGV) — atualize .claude-plugin/marketplace.json"; exit 1; }
echo "OK [2]"

echo "[3] cobertura: todo comando de template vira /forge:* (sem colisão)"
SRC_N="$(find template/.forge/commands -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')"
PLG_N="$(find plugin/forge/commands -name '*.md' | wc -l | tr -d ' ')"
[ "$SRC_N" = "$PLG_N" ] || { echo "FAIL: $SRC_N comandos na fonte, $PLG_N no plugin (colisão de basename?)"; exit 1; }
echo "OK [3] ($PLG_N comandos)"

# Nome reservado pelo Claude Code: um comando 'skill' (exato) num plugin derruba o carregamento
# inteiro silenciosamente. plugin-build.mjs já aborta, mas guardamos aqui com mensagem clara.
echo "[3b] nenhum comando usa nome reservado (ex.: skill)"
if find plugin/forge/commands template/.forge/commands -name 'skill.md' | grep -q .; then
  echo "FAIL: existe um comando 'skill' — renomeie (ex.: skill-lifecycle); 'skill' colide com a infra de skills do Claude Code"; exit 1
fi
echo "OK [3b]"

echo "[4] validação de manifesto (se claude disponível)"
if command -v claude >/dev/null 2>&1; then
  claude plugin validate . --strict >/dev/null 2>&1 || { echo "FAIL: marketplace/plugin inválido (claude plugin validate . --strict)"; exit 1; }
  echo "OK [4]"
else
  echo "SKIP [4] (claude CLI não disponível neste ambiente)"
fi

echo "PASS plugin-sync-gate"
