#!/usr/bin/env bash
# Gate W10.2 — capability packs são distribuídos, opt-in e compatíveis com adapters/update:
# [1] catálogo e dispatcher existem; [2] frontmatter e regras transversais válidos;
# [3] agents-skills projeta a contagem real de skills, sem número fixo; [4] doctor sugere .NET.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w102.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] catálogo"
for p in backend-dotnet-relational backend-node-postgres backend-java-relational backend-python-relational; do
  [ -f "$WS/template/.forge/capabilities/$p/PROFILE.md" ]
  grep -q "id: $p" "$WS/template/.forge/capabilities/$p/PROFILE.md"
done
[ -f "$WS/template/.forge/skills/capability-dispatcher/SKILL.md" ]
[ -f "$WS/template/.forge/commands/harness/capabilities.md" ]
echo "OK [1]"

echo "[2] regras e frontmatter"
bash "$WS/template/.forge/scripts/validate-frontmatter.sh" \
  "$WS/template/.forge/skills/capability-dispatcher" \
  "$WS/template/.forge/rules/data/schema-evolution.md" \
  "$WS/template/.forge/rules/testing/change-test-contract.md" | tail -1 | grep -q '^OK'
echo "OK [2]"

echo "[3] adapter agents-skills usa inventário dinâmico"
"$WS/installer/install.sh" --target "$T" --slug fixture --name Fixture --desc fixture --adapters agents-skills >/dev/null
(cd "$T" && bash .forge/scripts/smoke-adapters.sh) | tail -1 | grep -q '^OK$'
projected="$(find "$T/.agents/skills" -name SKILL.md | wc -l | tr -d ' ')"
canonical="$(find "$T/.forge/skills" -name SKILL.md | wc -l | tr -d ' ')"
[ "$projected" = "$canonical" ] && [ "$canonical" -gt 10 ]
echo "OK [3] ($canonical skills)"

echo "[4] doctor sugere .NET sem ativar"
mkdir -p "$T/src"
printf '<Project Sdk="Microsoft.NET.Sdk"></Project>\n' > "$T/src/Fixture.csproj"
set +e
out="$(cd "$T" && bash .forge/scripts/doctor.sh --report 2>&1)"
status=$?
set -e
grep -q 'capability pack sugerido: backend-dotnet-relational' <<<"$out"
grep -q 'active: \[\]' "$T/.forge/forge.yaml"
[ "$status" -eq 0 ] || [ "$status" -eq 1 ]
echo "OK [4]"

echo "PASS w102-capability-packs-gate"
