#!/usr/bin/env bash
# Gate W157 — integridade do ledger durável (issue #78): a invariante "todo status 'resolved'
# carrega 'resolved_at'" tem que valer sempre, nas três portas que levam uma entrada a esse estado
# (add --status resolved / update --status resolved / resolve) e no ledger.json real do próprio
# repositório, que carregava 11 entradas violando essa invariante antes desta onda.
#
#   [1] ledger real do projeto (.forge/ledger/ledger.json) — 0 violações (regressão do backfill)
#   [2] entrada 'resolved' sem 'resolved_at' reprova e a mensagem nomeia o id
#   [3] entrada com 'status' nulo reprova
#   [4] 'add --status resolved' é recusado, sem produzir entrada corrompida
#   [5] 'update --status resolved' é recusado, sem produzir entrada corrompida
#   [6] 'resolve <id> --note ...' é a porta correta — carimba resolved_at
#   [7] controle e recontrole: mutar reintroduz o defeito (reprova), restaurar volta a passar
#       (restauração verificada byte-a-byte com cmp)
#   [8] guarda de vacuidade: ledger vazio declara "0 examinadas" (não passa em silêncio); ledger
#       ausente reprova (nunca passa por omissão)
#   [9] propriedade: "resolved implica resolved_at" vale para uma matriz gerada de combinações de
#       status x resolved_at x campos irrelevantes (type/severity/priority) — não só o caso feliz
#   [10] diretório fora de um repositório git: add/update/resolve/promote recusam, ledger intocado
#   [11] repositório git sem nenhum commit ainda: idem — _git_date devolve vazio nos dois casos, e
#        as quatro portas que a chamam (inclusive 'resolve', a porta CERTA) tinham rc=0 carimbando
#        a string vazia em created_at/updated_at/resolved_at antes desta correção
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w157.XXXXXX)"
# [10]/[11] precisam de raízes INDEPENDENTES de qualquer repositório git — uma subpasta de $T
# herdaria o `git init` feito abaixo para a fixture das portas (git -C sobe até achar o .git mais
# próximo), e "fora de git" deixaria de ser verdade. Alocadas fora de $T, com limpeza própria.
T10="$(mktemp -d /tmp/forge-w157-nogit.XXXXXX)"
T11="$(mktemp -d /tmp/forge-w157-nocommit.XXXXXX)"
trap 'rm -rf "$T" "$T10" "$T11"' EXIT

# Todo comando externo roda sob teto de tempo — idioma já usado em check-push-ahead.sh /
# pentest-ops.sh (perl -e 'alarm ...') porque macOS não tem `timeout` de coreutils por padrão.
_run_to() { # _run_to <segundos> -- <cmd...>
  local secs="$1"; shift
  [ "${1:-}" = "--" ] && shift
  perl -e "alarm $secs; exec @ARGV" -- "$@"
}

# Checker isolado: única fonte da invariante, para não duplicar a lógica em cada cenário.
CHECKER="$T/check-ledger-integrity.mjs"
cat > "$CHECKER" <<'EOF'
// Verifica a invariante do ledger (issue #78): todo status é não-nulo, e status 'resolved'
// implica resolved_at não-nulo. Uso: node check-ledger-integrity.mjs <ledger.json>
import { readFileSync } from 'node:fs';
const path = process.argv[2];
let data;
try {
  data = JSON.parse(readFileSync(path, 'utf8'));
} catch (e) {
  console.error(`FAIL: ledger ilegível ou ausente (${path}): ${e.message}`);
  process.exit(1);
}
const entries = Array.isArray(data.entries) ? data.entries : null;
if (!entries) {
  console.error('FAIL: ledger sem array "entries" válido');
  process.exit(1);
}
const bad = [];
for (const e of entries) {
  const id = e && e.id ? e.id : '(sem id)';
  if (e.status === null || e.status === undefined || e.status === '') {
    bad.push(`${id}: status nulo`);
    continue;
  }
  if (e.status === 'resolved' && !e.resolved_at) {
    bad.push(`${id}: status resolved sem resolved_at`);
  }
}
if (bad.length) {
  console.error(`FAIL: ${bad.length} violação(ões) de ${entries.length} entrada(s) examinada(s) — ${bad.join('; ')}`);
  process.exit(1);
}
console.log(`OK ${entries.length} entrada(s) examinada(s), 0 violação(ões)`);
EOF
_check() { _run_to 10 -- node "$CHECKER" "$1"; }

echo "[1] ledger real do projeto — 0 violações da invariante (backfill da onda 0b)"
_check "$WS/.forge/ledger/ledger.json"
echo "OK [1]"

echo "[2] entrada 'resolved' sem 'resolved_at' reprova, mensagem nomeia o id"
FIX2="$T/fixture-2.json"
node -e '
  const fs = require("fs");
  fs.writeFileSync(process.argv[1], JSON.stringify({ entries: [
    { id: "LDG-9002", type: "known-bug", title: "resolved sem carimbo", status: "resolved",
      resolved_at: null, source: { origin: "manual" }, created_at: "2026-01-01T00:00:00Z",
      dedup_key: "manual:LDG-9002" },
  ] }, null, 2));
' "$FIX2"
set +e
out2="$(_check "$FIX2" 2>&1)"; rc2=$?
set -e
[ "$rc2" -ne 0 ] || { echo "FAIL: checker deveria reprovar 'resolved' sem 'resolved_at' — saiu rc=0: $out2"; exit 1; }
grep -q "LDG-9002" <<<"$out2" || { echo "FAIL: mensagem não nomeia o id LDG-9002 — got: $out2"; exit 1; }
echo "OK [2] — $out2"

echo "[3] entrada com 'status' nulo reprova"
FIX3="$T/fixture-3.json"
node -e '
  const fs = require("fs");
  fs.writeFileSync(process.argv[1], JSON.stringify({ entries: [
    { id: "LDG-9003", type: "known-bug", title: "status nulo", status: null,
      resolved_at: null, source: { origin: "manual" }, created_at: "2026-01-01T00:00:00Z",
      dedup_key: "manual:LDG-9003" },
  ] }, null, 2));
' "$FIX3"
set +e
out3="$(_check "$FIX3" 2>&1)"; rc3=$?
set -e
[ "$rc3" -ne 0 ] || { echo "FAIL: checker deveria reprovar status nulo — saiu rc=0: $out3"; exit 1; }
grep -q "LDG-9003" <<<"$out3" || { echo "FAIL: mensagem não nomeia o id LDG-9003 — got: $out3"; exit 1; }
echo "OK [3] — $out3"

# ── fixture viva (git + template completo) para os cenários das três portas ────────────────────
cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q
_run_to 10 -- git -C "$T" add -A
_run_to 10 -- git -C "$T" -c user.email=t@t -c user.name=t commit -qm init >/dev/null
LG="$T/.forge/scripts/ledger-ops.sh"
LF="$T/.forge/ledger/ledger.json"

_entry_count() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((d.entries||[]).length)' "$1"; }
_field_of() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);process.stdout.write(e?String(e[process.argv[3]]):"MISSING")' "$1" "$2" "$3"; }

_run_to 10 -- env FORGE_ROOT="$T" bash "$LG" add --type known-bug --title "baseline" >/dev/null   # LDG-0001, status open

echo "[4] 'add --status resolved' é recusado, sem produzir entrada corrompida"
before4="$(_entry_count "$LF")"
set +e
out4="$(_run_to 10 -- env FORGE_ROOT="$T" bash "$LG" add --type known-bug --title "x" --status resolved 2>&1)"; rc4=$?
set -e
[ "$rc4" -ne 0 ] || { echo "FAIL: 'add --status resolved' deveria ser recusado (rc=0) — got: $out4"; exit 1; }
grep -qi "resolve" <<<"$out4" || { echo "FAIL: mensagem de recusa do 'add' não aponta para 'resolve' — got: $out4"; exit 1; }
after4="$(_entry_count "$LF")"
[ "$before4" = "$after4" ] || { echo "FAIL: 'add' recusado mas alterou o ledger ($before4 -> $after4 entradas)"; exit 1; }
echo "OK [4] — $out4"

echo "[5] 'update --status resolved' é recusado, sem produzir entrada corrompida"
set +e
out5="$(_run_to 10 -- env FORGE_ROOT="$T" bash "$LG" update LDG-0001 --status resolved 2>&1)"; rc5=$?
set -e
[ "$rc5" -ne 0 ] || { echo "FAIL: 'update --status resolved' deveria ser recusado (rc=0) — got: $out5"; exit 1; }
grep -qi "resolve" <<<"$out5" || { echo "FAIL: mensagem de recusa do 'update' não aponta para 'resolve' — got: $out5"; exit 1; }
status5="$(_field_of "$LF" LDG-0001 status)"
[ "$status5" = "open" ] || { echo "FAIL: 'update' recusado mas o status mudou (got '$status5', esperado 'open')"; exit 1; }
echo "OK [5] — $out5"

echo "[6] 'resolve <id> --note ...' é a porta correta — carimba resolved_at"
_run_to 10 -- env FORGE_ROOT="$T" bash "$LG" resolve LDG-0001 --note "corrigido no gate" >/dev/null
status6="$(_field_of "$LF" LDG-0001 status)"
resolved6="$(_field_of "$LF" LDG-0001 resolved_at)"
[ "$status6" = "resolved" ] || { echo "FAIL: resolve não marcou status=resolved (got '$status6')"; exit 1; }
[ -n "$resolved6" ] && [ "$resolved6" != "null" ] && [ "$resolved6" != "MISSING" ] || { echo "FAIL: resolve não carimbou resolved_at (got '$resolved6')"; exit 1; }
_check "$LF" >/dev/null || { echo "FAIL: ledger da fixture inconsistente depois de 'resolve'"; exit 1; }
echo "OK [6] — resolved_at=$resolved6"

echo "[7] controle e recontrole — mutar reintroduz o defeito, restaurar volta a passar (cmp verificado)"
CTRL="$T/ledger-control.json"
cp "$WS/.forge/ledger/ledger.json" "$CTRL"
cp "$CTRL" "$CTRL.orig"
_check "$CTRL" >/dev/null || { echo "FAIL: controle inicial (cópia do ledger real) já reprova — backfill incompleto"; exit 1; }
mutated_id="$(node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const d = JSON.parse(fs.readFileSync(p, "utf8"));
  const e = (d.entries || []).find((x) => x.status === "resolved" && x.resolved_at);
  if (!e) { console.error("nenhuma entrada resolved com resolved_at para mutar"); process.exit(1); }
  e.resolved_at = null;
  fs.writeFileSync(p, JSON.stringify(d, null, 2));
  console.log(e.id);
' "$CTRL")"
set +e
out7="$(_check "$CTRL" 2>&1)"; rc7=$?
set -e
[ "$rc7" -ne 0 ] || { echo "FAIL: mutação (zerar resolved_at de $mutated_id) não fez o checker reprovar"; exit 1; }
grep -q "$mutated_id" <<<"$out7" || { echo "FAIL: mensagem da mutação não nomeia $mutated_id — got: $out7"; exit 1; }
cp "$CTRL.orig" "$CTRL"
cmp -s "$CTRL" "$CTRL.orig" || { echo "FAIL: restauração não bateu byte-a-byte (cmp) — o próprio controle está quebrado"; exit 1; }
_check "$CTRL" >/dev/null || { echo "FAIL: checker deveria voltar a passar depois da restauração verificada"; exit 1; }
echo "OK [7] — mutou $mutated_id, reprovou, restaurou (cmp ok), voltou a passar"

echo "[8] guarda de vacuidade — vazio declara contagem, ausente reprova (nunca passa em silêncio)"
EMPTY="$T/empty-ledger.json"
printf '{"entries":[]}\n' > "$EMPTY"
set +e
out8a="$(_check "$EMPTY" 2>&1)"; rc8a=$?
set -e
[ "$rc8a" -eq 0 ] || { echo "FAIL: ledger vazio não deveria reprovar (vacuamente íntegro) — got rc=$rc8a: $out8a"; exit 1; }
grep -q "^OK 0 entrada" <<<"$out8a" || { echo "FAIL: ledger vazio não declarou '0 entrada(s) examinada(s)' — got: $out8a"; exit 1; }

ABSENT="$T/absent-ledger.json"
rm -f "$ABSENT"
set +e
out8b="$(_check "$ABSENT" 2>&1)"; rc8b=$?
set -e
[ "$rc8b" -ne 0 ] || { echo "FAIL: ledger ausente não pode passar por omissão — got rc=0: $out8b"; exit 1; }
echo "OK [8] — vazio: '$out8a' · ausente: rc=$rc8b '$out8b'"

echo "[9] propriedade — 'resolved implica resolved_at' numa matriz gerada de combinações"
PROP="$T/ledger-prop.json"
EXPECTED="$T/prop-expected.json"
node -e '
  const fs = require("fs");
  const STATUSES = ["open", "planned", "in-progress", "resolved", "wont-fix", "promoted"];
  const RESOLVED_AT = [null, "2026-01-01T00:00:00-03:00"];
  const TYPES = ["roadmap", "tech-debt", "known-bug", "follow-up", "feature-idea"];
  const SEVERITIES = ["BLOCKER", "HIGH", "MEDIUM", "LOW", null];
  const PRIORITIES = ["P0", "P1", "P2", "P3", null];
  const entries = [];
  const failIds = [];
  let n = 0;
  for (const status of STATUSES) {
    for (const resolvedAt of RESOLVED_AT) {
      n += 1;
      const id = "LDG-" + String(9100 + n).padStart(4, "0");
      const violates = status === "resolved" && !resolvedAt;
      if (violates) failIds.push(id);
      entries.push({
        id, type: TYPES[n % TYPES.length], title: "prop " + id, status,
        resolved_at: resolvedAt, severity: SEVERITIES[n % SEVERITIES.length],
        priority: PRIORITIES[(n * 3) % PRIORITIES.length],
        source: { origin: "manual" }, created_at: "2026-01-01T00:00:00Z",
        dedup_key: "manual:" + id,
      });
    }
  }
  fs.writeFileSync(process.argv[1], JSON.stringify({ entries }, null, 2));
  fs.writeFileSync(process.argv[2], JSON.stringify({ n: entries.length, failIds }));
' "$PROP" "$EXPECTED"

expected_n="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).n)' "$EXPECTED")"
fail_ids="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).failIds.join(" "))' "$EXPECTED")"
set +e
out9="$(_check "$PROP" 2>&1)"; rc9=$?
set -e
if [ -n "$fail_ids" ]; then
  [ "$rc9" -ne 0 ] || { echo "FAIL: propriedade deveria reprovar (matriz gerada tem resolved sem resolved_at) — got rc=0: $out9"; exit 1; }
  for fid in $fail_ids; do
    grep -q "$fid" <<<"$out9" || { echo "FAIL: violação $fid da matriz gerada não foi nomeada na saída — got: $out9"; exit 1; }
  done
  echo "OK [9] — $expected_n entradas geradas, violações esperadas ($fail_ids) todas nomeadas"
else
  [ "$rc9" -eq 0 ] || { echo "FAIL: propriedade não deveria reprovar — got: $out9"; exit 1; }
  echo "OK [9] — $expected_n entradas geradas, 0 violações, checker concordou"
fi

# ── [10]/[11] _git_date degradado: fora de git, e git sem nenhum commit ────────────────────────
# Achado do coordenador: a porta CERTA ('resolve') também passava por _git_date, e fora de um
# repositório git (ou com repositório git sem nenhum commit) essa função devolve string vazia via
# 'git log -1 ... || echo ""' — as quatro portas que a chamam (add/update/resolve/promote)
# carimbavam "" com rc=0, a mesma classe de falha que a onda inteira existe para eliminar.
_assert_git_date_guard() { # _assert_git_date_guard <rótulo> <root-dir>
  local label="$1" root="$2"
  mkdir -p "$root/.forge/ledger"
  node -e '
    const fs = require("fs");
    fs.writeFileSync(process.argv[1], JSON.stringify({ entries: [
      { id: "LDG-0001", type: "known-bug", title: "baseline", status: "open",
        severity: null, priority: null, source: { origin: "manual" },
        links: { adr: [], capability: [], change: [], promoted_to: null },
        created_at: "2026-01-01T00:00:00Z", updated_at: null, resolved_at: null,
        dedup_key: "manual:LDG-0001" },
    ] }, null, 2));
  ' "$root/.forge/ledger/ledger.json"
  cp "$root/.forge/ledger/ledger.json" "$root/.forge/ledger/ledger.json.orig"

  set +e
  out_add="$(_run_to 10 -- env FORGE_ROOT="$root" bash "$LG" add --type known-bug --title "x" 2>&1)"; rc_add=$?
  set -e
  [ "$rc_add" -ne 0 ] || { echo "FAIL: [$label] 'add' deveria recusar sem data de commit HEAD — got rc=0: $out_add"; exit 1; }
  echo "  add     -> rc=$rc_add: $out_add"

  set +e
  out_upd="$(_run_to 10 -- env FORGE_ROOT="$root" bash "$LG" update LDG-0001 --priority P1 2>&1)"; rc_upd=$?
  set -e
  [ "$rc_upd" -ne 0 ] || { echo "FAIL: [$label] 'update' deveria recusar sem data de commit HEAD — got rc=0: $out_upd"; exit 1; }
  echo "  update  -> rc=$rc_upd: $out_upd"

  set +e
  out_res="$(_run_to 10 -- env FORGE_ROOT="$root" bash "$LG" resolve LDG-0001 --note "x" 2>&1)"; rc_res=$?
  set -e
  [ "$rc_res" -ne 0 ] || { echo "FAIL: [$label] 'resolve' deveria recusar sem data de commit HEAD — got rc=0: $out_res"; exit 1; }
  echo "  resolve -> rc=$rc_res: $out_res"

  set +e
  out_pro="$(_run_to 10 -- env FORGE_ROOT="$root" bash "$LG" promote LDG-0001 --to change-x 2>&1)"; rc_pro=$?
  set -e
  [ "$rc_pro" -ne 0 ] || { echo "FAIL: [$label] 'promote' deveria recusar sem data de commit HEAD — got rc=0: $out_pro"; exit 1; }
  echo "  promote -> rc=$rc_pro: $out_pro"

  cmp -s "$root/.forge/ledger/ledger.json" "$root/.forge/ledger/ledger.json.orig"     || { echo "FAIL: [$label] ledger foi alterado apesar das recusas (cmp)"; exit 1; }

  for out in "$out_add" "$out_upd" "$out_res" "$out_pro"; do
    grep -qi "commit" <<<"$out" || { echo "FAIL: [$label] mensagem de recusa não menciona a causa (commit HEAD) — got: $out"; exit 1; }
  done
}

echo "[10] diretório fora de um repositório git — as quatro portas recusam, ledger intocado"
_assert_git_date_guard "10-fora-de-git" "$T10"
echo "OK [10]"

echo "[11] repositório git sem nenhum commit ainda — as quatro portas recusam, ledger intocado"
git -C "$T11" init -q
_assert_git_date_guard "11-git-sem-commit" "$T11"
echo "OK [11]"

echo "PASS w157-ledger-integrity-gate"
