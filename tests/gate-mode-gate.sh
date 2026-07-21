#!/usr/bin/env bash
# Gate — lib/gate-mode.mjs (TASK-13, REQ-16, design.md §2.2 "Contrato comum dos gates").
# Zero-dependência. Prova o contrato warn|enforce + inegociabilidade que os três gates
# da Wave 4 (check-authz/check-observability/check-data-governance) vão consumir:
#   [1] mode:warn + finding rebaixável (enforceable:false) → não bloqueia (exit 0, warning)
#   [2] mode:warn + finding inegociável (enforceable:true)  → bloqueia (exit≠0), mesmo em warn
#   [3] mode:enforce + qualquer finding (rebaixável e inegociável) → bloqueia (exit≠0)
#   [4] sem findings → exit 0
#   [5] default seguro (bloco ausente / mode inválido → 'warn') + governanceFor/readAllowlist
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-gate-mode.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
LIB="$T/.forge/scripts/lib/gate-mode.mjs"
[ -f "$LIB" ]

echo "[1] mode:warn + finding rebaixável → exit 0, vira warning"
cat > "$T/case1.mjs" <<EOF
import { applyMode } from '${LIB}';
const findings = [{ file: 'a.go', enforceable: false, why: 'decisao imperativa fora do PEP' }];
const r = applyMode(findings, { mode: 'warn' });
if (r.exitCode !== 0) { console.error('FAIL exitCode', r.exitCode); process.exit(1); }
if (r.blocking.length !== 0) { console.error('FAIL blocking', JSON.stringify(r.blocking)); process.exit(1); }
if (r.warnings.length !== 1) { console.error('FAIL warnings', JSON.stringify(r.warnings)); process.exit(1); }
console.log('OK [1]');
EOF
node "$T/case1.mjs"

echo "[2] mode:warn + finding inegociavel (deny-by-default / PAN em log) → bloqueia mesmo em warn"
cat > "$T/case2.mjs" <<EOF
import { applyMode } from '${LIB}';
const findings = [{ file: 'policy.rego', enforceable: true, why: 'default allow := true' }];
const r = applyMode(findings, { mode: 'warn' });
if (r.exitCode === 0) { console.error('FAIL: inegociavel nao bloqueou em warn'); process.exit(1); }
if (r.blocking.length !== 1) { console.error('FAIL blocking', JSON.stringify(r.blocking)); process.exit(1); }
if (r.warnings.length !== 0) { console.error('FAIL warnings', JSON.stringify(r.warnings)); process.exit(1); }
console.log('OK [2]');
EOF
node "$T/case2.mjs"

echo "[3] mode:enforce + qualquer finding (rebaixável e inegociável) → bloqueia"
cat > "$T/case3.mjs" <<EOF
import { applyMode } from '${LIB}';
const findings = [
  { file: 'b.ts', enforceable: false, why: 'boundary sem wrapper de instrumentacao' },
  { file: 'policy.rego', enforceable: true, why: 'default allow := true' },
];
const r = applyMode(findings, { mode: 'enforce' });
if (r.exitCode === 0) { console.error('FAIL: enforce nao bloqueou'); process.exit(1); }
if (r.blocking.length !== 2) { console.error('FAIL blocking', JSON.stringify(r.blocking)); process.exit(1); }
if (r.warnings.length !== 0) { console.error('FAIL warnings', JSON.stringify(r.warnings)); process.exit(1); }
console.log('OK [3]');
EOF
node "$T/case3.mjs"

echo "[4] sem findings → exit 0 (warn e enforce; array vazio e undefined)"
cat > "$T/case4.mjs" <<EOF
import { applyMode } from '${LIB}';
const r1 = applyMode([], { mode: 'enforce' });
if (r1.exitCode !== 0) { console.error('FAIL exitCode (empty, enforce)', r1.exitCode); process.exit(1); }
const r2 = applyMode(undefined, { mode: 'warn' });
if (r2.exitCode !== 0) { console.error('FAIL exitCode (undefined, warn)', r2.exitCode); process.exit(1); }
console.log('OK [4]');
EOF
node "$T/case4.mjs"

echo "[5] default seguro (bloco ausente/mode invalido -> warn) + governanceFor/readAllowlist"
cat > "$T/case5.mjs" <<EOF
import { readMode, readAllowlist, governanceFor, applyMode } from '${LIB}';
if (readMode(undefined) !== 'warn') { console.error('FAIL default mode (undefined)'); process.exit(1); }
if (readMode({ mode: 'bogus' }) !== 'warn') { console.error('FAIL default mode (invalid)'); process.exit(1); }
if (readAllowlist(undefined).length !== 0) { console.error('FAIL default allowlist'); process.exit(1); }
if (governanceFor({}, 'authz') !== undefined) { console.error('FAIL governanceFor sem governance'); process.exit(1); }

const graph = { governance: { authz: { mode: 'enforce', allowlist: ['services/health'] } } };
const block = governanceFor(graph, 'authz');
if (!block || block.mode !== 'enforce') { console.error('FAIL governanceFor'); process.exit(1); }
if (readAllowlist(block).length !== 1 || readAllowlist(block)[0] !== 'services/health') {
  console.error('FAIL readAllowlist(block)'); process.exit(1);
}
// applyMode aceita o bloco de governance cru diretamente (tem .mode) — sem passo extra.
const r = applyMode([{ enforceable: false }], block);
if (r.exitCode === 0) { console.error('FAIL: bloco authz enforce nao bloqueou rebaixavel'); process.exit(1); }
console.log('OK [5]');
EOF
node "$T/case5.mjs"

echo "OK"
