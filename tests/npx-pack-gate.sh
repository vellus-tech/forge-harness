#!/usr/bin/env bash
# Gate — pacote npm / `npx forge-harness init`: garante que a instalação zero-install continua
# funcionando e que o tarball publicado leva tudo o que o bootstrap precisa.
#   [1] npm pack inclui o template completo + bin + gitignore.patch + staging.yml; exclui .DS_Store;
#       package.json declara bin/files/engines e license MIT (metadados de publicação)
#   [2] bin/forge.mjs init --yes materializa .forge sem placeholders órfãos + AGENTS.md +
#       CLAUDE.md (symlink) + adapter claude; doctor sai 0 (harness íntegro, lockfile sem drift)
#   [3] paridade: o .forge gerado pelo bin é idêntico ao do installer/install.sh (porta fiel)
#   [4] --version casa com package.json; guard de sobrescrita (.forge existente sem --force → exit 3)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS"
BIN="$WS/bin/forge.mjs"
[ -f "$BIN" ]
command -v node >/dev/null 2>&1 || { echo "FAIL (node necessário)"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "FAIL (npm necessário)"; exit 1; }

T="$(mktemp -d /tmp/forge-npx.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] npm pack leva o essencial + metadados de publicação"
npm pack --dry-run --json >"$T/pack.json" 2>/dev/null
cat > "$T/check.mjs" <<'EOF'
import { readFileSync } from 'node:fs';
const pack = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const pkg = JSON.parse(readFileSync(process.argv[3], 'utf8'));
const files = pack[0].files.map((f) => f.path);
const need = [
  'package.json', 'bin/forge.mjs', 'installer/gitignore.patch',
  'template/.forge/FORGE.md', 'template/.forge/scripts/lib/sync-adapters.mjs',
  'template/github/workflows/staging.yml',
];
for (const n of need) if (!files.includes(n)) { console.error('faltando no tarball: ' + n); process.exit(1); }
if (files.some((f) => f.endsWith('.DS_Store'))) { console.error('.DS_Store vazou pro tarball'); process.exit(1); }
const forgeCount = files.filter((f) => f.startsWith('template/.forge/')).length;
if (forgeCount < 200) { console.error('template/.forge incompleto no tarball: ' + forgeCount); process.exit(1); }
if (!pkg.bin || pkg.bin['forge-harness'] !== 'bin/forge.mjs') { console.error('package.json: bin forge-harness ausente/errado'); process.exit(1); }
if (!Array.isArray(pkg.files) || pkg.files.length === 0) { console.error('package.json: files ausente'); process.exit(1); }
if (!pkg.engines || !pkg.engines.node) { console.error('package.json: engines.node ausente'); process.exit(1); }
if (pkg.license !== 'MIT') { console.error('package.json: license != MIT'); process.exit(1); }
console.log('  tarball: ' + files.length + ' arquivos; template/.forge: ' + forgeCount);
EOF
node "$T/check.mjs" "$T/pack.json" "$WS/package.json"
echo "OK [1]"

echo "[2] init materializa .forge + adapters; doctor verde"
mkdir -p "$T/proj"; ( cd "$T/proj" && git init -q )
node "$BIN" init --target "$T/proj" --name "Gate Proj" --slug gate-proj --desc "gate e2e" --adapters claude --yes >"$T/init.log" 2>&1
[ -f "$T/proj/.forge/FORGE.md" ] || { echo "FAIL (.forge/FORGE.md não criado)"; cat "$T/init.log"; exit 1; }
orphans="$(grep -rl '<PROJECT_[A-Z_]*>' "$T/proj/.forge" 2>/dev/null | grep -v '/templates/' | wc -l | tr -d ' ' || true)"
[ "$orphans" -eq 0 ] || { echo "FAIL ($orphans placeholders <PROJECT_*> órfãos)"; exit 1; }
[ -f "$T/proj/AGENTS.md" ] || { echo "FAIL (AGENTS.md ausente)"; exit 1; }
[ -L "$T/proj/CLAUDE.md" ] || { echo "FAIL (CLAUDE.md não é symlink)"; exit 1; }
[ -d "$T/proj/.claude/commands/forge" ] || { echo "FAIL (adapter claude não materializado)"; exit 1; }
grep -q 'forge (managed)' "$T/proj/.gitignore" || { echo "FAIL (bloco forge ausente no .gitignore)"; exit 1; }
if ! bash "$T/proj/.forge/scripts/doctor.sh" >"$T/doctor.log" 2>&1; then
  echo "FAIL (doctor reportou problema no harness)"; sed 's/^/    /' "$T/doctor.log"; exit 1
fi
grep -q 'sem drift' "$T/doctor.log" || { echo "FAIL (doctor não validou o lockfile do adapter)"; exit 1; }
echo "OK [2]"

echo "[3] paridade bin (npx) vs install.sh (bash)"
mkdir -p "$T/proj-sh"; ( cd "$T/proj-sh" && git init -q )
bash "$WS/installer/install.sh" --target "$T/proj-sh" --name "Gate Proj" --slug gate-proj --desc "gate e2e" --adapters claude >"$T/sh.log" 2>&1
diff -rq "$T/proj/.forge" "$T/proj-sh/.forge" >/dev/null || { echo "FAIL (.forge difere entre bin e install.sh)"; diff -rq "$T/proj/.forge" "$T/proj-sh/.forge" | head; exit 1; }
diff -q "$T/proj/AGENTS.md" "$T/proj-sh/AGENTS.md" >/dev/null || { echo "FAIL (AGENTS.md difere)"; exit 1; }
echo "OK [3]"

echo "[4] --version casa com package.json + guard de sobrescrita"
pv="$(node -e "process.stdout.write(JSON.parse(require('node:fs').readFileSync(process.argv[1],'utf8')).version)" "$WS/package.json")"
bv="$(node "$BIN" --version)"
[ "$pv" = "$bv" ] || { echo "FAIL (--version=$bv != package.json=$pv)"; exit 1; }
set +e
node "$BIN" init --target "$T/proj" --yes >"$T/guard.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 3 ] || { echo "FAIL (overwrite guard: esperado exit 3, veio $rc)"; cat "$T/guard.log"; exit 1; }
echo "OK [4]"

echo "[5] --force protege trabalho de produto (specs/ADRs) e --force-content libera"
# template fresh: --force re-instala sem bloquear
node "$BIN" init --target "$T/proj" --slug gate-proj --name "Gate Proj" --desc x --force --yes >"$T/f1.log" 2>&1 \
  || { echo "FAIL (--force bloqueou um .forge SEM conteúdo de produto)"; cat "$T/f1.log"; exit 1; }
# adiciona um ADR → vira conteúdo de produto
mkdir -p "$T/proj/.forge/product/current/adr"
printf '# ADR 0001\nteste\n' > "$T/proj/.forge/product/current/adr/0001-x.md"
set +e
node "$BIN" init --target "$T/proj" --slug gate-proj --name "Gate Proj" --desc x --force --yes >"$T/f2.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 3 ] || { echo "FAIL (--force devia BLOQUEAR com conteúdo de produto, veio exit $rc)"; cat "$T/f2.log"; exit 1; }
[ -f "$T/proj/.forge/product/current/adr/0001-x.md" ] || { echo "FAIL (ADR foi sobrescrito apesar do bloqueio)"; exit 1; }
grep -qi 'trabalho de produto' "$T/f2.log" || { echo "FAIL (sem aviso de trabalho de produto)"; exit 1; }
# --force-content libera (e faz backup)
node "$BIN" init --target "$T/proj" --slug gate-proj --name "Gate Proj" --desc x --force-content --yes >"$T/f3.log" 2>&1 \
  || { echo "FAIL (--force-content devia sobrescrever)"; cat "$T/f3.log"; exit 1; }
ls -d "$T/proj"/.forge.bak-* >/dev/null 2>&1 || { echo "FAIL (--force-content não criou backup)"; exit 1; }
echo "OK [5]"

echo "OK"
