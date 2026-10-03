#!/usr/bin/env bash
# Monta o consumidor servico-pagamentos (.NET 10 + xUnit) sem Directory.Build.props nem
# .editorconfig (baseline de enforcement ausente). Em main os testes passam; a branch
# feat/parcela-minima troca a guard de Split para InvalidOperationException (quebra
# Split_ParcelasZero_LancaDomainException) e deixa uma linha com indentação fora do padrão.
set -euo pipefail
T="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../../../.." && pwd)"
mkdir -p "$T"
node "$REPO_ROOT/bin/forge.mjs" init --target "$T" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$T/"
CLEAN=("$T/.forge/skills" "$T/.forge/agents" "$T/.claude/skills" "$T/.claude/agents" "$T/plugin")
rm -rf "${CLEAN[@]}"
printf 'bin/\nobj/\nTestResults/\n' >> "$T/.gitignore"
G=(git -C "$T" -c user.name=eval -c user.email=eval@example.invalid)
"${G[@]}" init -q -b main
"${G[@]}" add -A
"${G[@]}" commit -qm "feat: servico-pagamentos com split de parcelas"
"${G[@]}" checkout -q -b feat/parcela-minima
cp -R "$HERE/overlay/change/." "$T/"
"${G[@]}" add -A
"${G[@]}" commit -qm "feat(pagamentos): parcela mínima de R\$ 5,00 no split"
rm -rf "${CLEAN[@]}"
