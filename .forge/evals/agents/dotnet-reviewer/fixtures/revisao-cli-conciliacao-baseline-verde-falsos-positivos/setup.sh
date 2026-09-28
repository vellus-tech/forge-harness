#!/usr/bin/env bash
# Monta a fixture em $1: consumidor do forge-harness com a solução Conciliacao em main (baseline de build materializado e verde) e a branch feature/conciliacao-cli com o diff sob revisão.
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
# Baseline de build verde em main: o próprio script do harness materializa Directory.Build.props, .editorconfig e Directory.Packages.props.
bash "$TARGET/.forge/scripts/dotnet-baseline.sh" --root "$TARGET" --apply >/dev/null
# Versões centrais dos pacotes que a branch vai referenciar (CPM exige PackageVersion para cada PackageReference sem Version).
python3 - "$TARGET/Directory.Packages.props" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
itens = '''    <PackageVersion Include="Npgsql" Version="8.0.4" />
    <PackageVersion Include="xunit" Version="2.9.0" />
    <PackageVersion Include="xunit.runner.visualstudio" Version="2.8.2" />
    <PackageVersion Include="Microsoft.NET.Test.Sdk" Version="17.11.1" />
'''
vazio = "<ItemGroup>\n  </ItemGroup>"
if vazio in s:
    i = s.rfind(vazio)
    s = s[:i] + "<ItemGroup>\n" + itens + "  </ItemGroup>" + s[i + len(vazio):]
else:
    s = s.replace("</Project>", "  <ItemGroup>\n" + itens + "  </ItemGroup>\n</Project>", 1)
open(p, "w", encoding="utf-8").write(s)
PY
git -C "$TARGET" init -q -b main
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "chore: domínio de conciliação e baseline de build"
"${GIT[@]}" checkout -q -b feature/conciliacao-cli
cp -R "$HERE/overlay/branch/." "$TARGET/"
"${GIT[@]}" add -A
"${GIT[@]}" commit -q -m "feat(conciliacao): CLI noturna que concilia lotes da validadora com o extrato do adquirente"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
