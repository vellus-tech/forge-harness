#!/usr/bin/env bash
# ledger-ops.sh — operações deterministas no ledger durável de projeto (.forge/ledger/ledger.json).
# Store NÃO-BLOQUEANTE de trabalho conhecido que sobrevive entre changes (roadmap, dívida técnica,
# bugs conhecidos, follow-ups, ideias). Toda mutação re-renderiza LEDGER.md. Ver schema em
# .forge/schemas/ledger.schema.json e rule ledger-consultation.md.
#
# Uso:
#   ledger-ops.sh add     --type <t> --title "<txt>" [--detail "<txt>"] [--severity S] [--priority P]
#                         [--status ST] [--origin O] [--change <id>] [--ref R] [--adr A] [--capability C]
#   ledger-ops.sh update  <LDG-NNNN> [--status ST] [--priority P] [--severity S] [--title "<txt>"] [--detail "<txt>"]
#   ledger-ops.sh resolve <LDG-NNNN> --note "<txt>"
#   ledger-ops.sh promote <LDG-NNNN> --to <change-id>
#   ledger-ops.sh harvest <change-id> --origin close|archive   # colhe deferrals/findings antes do mv
#   ledger-ops.sh render                                        # regenera LEDGER.md
#   ledger-ops.sh status                                        # one-line (para /forge:status)
#   ledger-ops.sh list    [--status S] [--type T] [--top N] [--by-priority]
#
# Determinístico: created_at = data do commit HEAD (não wall clock); harvest é idempotente (dedup_key)
# e best-effort (NUNCA falha o caller). Ver deferral-ops.sh / handoff-gen.sh para os idiomas.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd)}"
LEDGER_DIR="$ROOT/.forge/ledger"
LF="$LEDGER_DIR/ledger.json"
TPL="$(cd "$SCRIPT_DIR/.." && pwd)/templates/ledger/LEDGER.md"
OUT="$LEDGER_DIR/LEDGER.md"

cmd="${1:-}"; shift || true
[ -n "$cmd" ] || { echo "Usage: ledger-ops.sh add|update|resolve|promote|harvest|render|status|list [args...]" >&2; exit 1; }

_git_date() { git -C "$ROOT" log -1 --format=%cI 2>/dev/null || echo ""; }
_write_json() { local f="$1"; local tmp; tmp="$(mktemp "${f}.XXXXXX")"; printf '%s\n' "$2" > "$tmp"; mv "$tmp" "$f"; }
_init_ledger() { mkdir -p "$LEDGER_DIR"; [ -f "$LF" ] || _write_json "$LF" '{"entries":[]}'; }
_render() {
  [ -f "$TPL" ] || { echo "WARN: template ausente ($TPL) — LEDGER.md não regenerado" >&2; return 0; }
  LEDGER_ROOT="$ROOT" LEDGER_JSON="$LF" LEDGER_TPL="$TPL" LEDGER_OUT="$OUT" \
    node "$SCRIPT_DIR/lib/ledger-render.mjs"
}

case "$cmd" in

add)
  type=""; title=""; detail=""; severity=""; priority=""; status="open"; origin="manual"; change=""; ref=""; adr=""; capability=""
  while [ $# -gt 0 ]; do case "$1" in
    --type) type="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    --detail) detail="$2"; shift 2 ;;
    --severity) severity="$2"; shift 2 ;;
    --priority) priority="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --origin) origin="$2"; shift 2 ;;
    --change) change="$2"; shift 2 ;;
    --ref) ref="$2"; shift 2 ;;
    --adr) adr="$2"; shift 2 ;;
    --capability) capability="$2"; shift 2 ;;
    *) shift ;;
  esac; done
  [ -n "$type" ] || { echo "FAIL: --type obrigatório (roadmap|tech-debt|known-bug|follow-up|feature-idea)" >&2; exit 1; }
  [ -n "$title" ] || { echo "FAIL: --title obrigatório" >&2; exit 1; }
  _init_ledger
  result="$(node - "$LF" "$type" "$title" "$detail" "$severity" "$priority" "$status" "$origin" "$change" "$ref" "$adr" "$capability" "$(_git_date)" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, type, title, detail, severity, priority, status, origin, change, ref, adr, capability, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
if (!Array.isArray(data.entries)) data.entries = [];
const max = data.entries.reduce((m, e) => { const n = parseInt((e.id || '').replace('LDG-', ''), 10); return Number.isFinite(n) && n > m ? n : m; }, 0);
const id = 'LDG-' + String(max + 1).padStart(4, '0');
const dedup = (change && ref) ? `${change}:${ref}` : `manual:${id}`;
data.entries.push({
  id, type, title,
  detail: detail || '',
  severity: severity || null,
  priority: priority || null,
  status,
  source: { change_id: change || null, origin, ref: ref || null },
  links: { adr: adr ? [adr] : [], capability: capability ? [capability] : [], change: change ? [change] : [], promoted_to: null },
  created_at: now, updated_at: null, resolved_at: null,
  dedup_key: dedup,
});
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"
  _write_json "$LF" "$result"
  _render
  new_id="$(node -e "const d=JSON.parse(require('fs').readFileSync('$LF','utf8'));console.log(d.entries[d.entries.length-1].id)")"
  echo "OK add — $new_id registrado ($type)"
  ;;

update)
  id="${1:-}"; shift || true
  [ -n "$id" ] || { echo "FAIL: LDG-id obrigatório" >&2; exit 1; }
  n_status=""; n_priority=""; n_severity=""; n_title=""; n_detail=""
  while [ $# -gt 0 ]; do case "$1" in
    --status) n_status="$2"; shift 2 ;;
    --priority) n_priority="$2"; shift 2 ;;
    --severity) n_severity="$2"; shift 2 ;;
    --title) n_title="$2"; shift 2 ;;
    --detail) n_detail="$2"; shift 2 ;;
    *) shift ;;
  esac; done
  _init_ledger
  result="$(node - "$LF" "$id" "$n_status" "$n_priority" "$n_severity" "$n_title" "$n_detail" "$(_git_date)" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, id, st, pr, sv, ti, de, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
const e = (data.entries || []).find((x) => x.id === id);
if (!e) { console.error('entrada ' + id + ' não encontrada'); process.exit(1); }
if (st) e.status = st;
if (pr) e.priority = pr;
if (sv) e.severity = sv;
if (ti) e.title = ti;
if (de) e.detail = de;
e.updated_at = now;
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"
  _write_json "$LF" "$result"
  _render
  echo "OK update — $id atualizado"
  ;;

resolve)
  id="${1:-}"; shift || true
  [ -n "$id" ] || { echo "FAIL: LDG-id obrigatório" >&2; exit 1; }
  note=""
  while [ $# -gt 0 ]; do case "$1" in --note) note="$2"; shift 2 ;; *) shift ;; esac; done
  [ -n "$note" ] || { echo "FAIL: --note obrigatório" >&2; exit 1; }
  _init_ledger
  result="$(node - "$LF" "$id" "$note" "$(_git_date)" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, id, note, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
const e = (data.entries || []).find((x) => x.id === id);
if (!e) { console.error('entrada ' + id + ' não encontrada'); process.exit(1); }
e.status = 'resolved';
e.resolved_at = now;
e.updated_at = now;
e.detail = (e.detail ? e.detail + ' — ' : '') + 'Resolvido: ' + note;
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"
  _write_json "$LF" "$result"
  _render
  echo "OK resolve — $id marcado como resolved"
  ;;

promote)
  id="${1:-}"; shift || true
  [ -n "$id" ] || { echo "FAIL: LDG-id obrigatório" >&2; exit 1; }
  to=""
  while [ $# -gt 0 ]; do case "$1" in --to) to="$2"; shift 2 ;; *) shift ;; esac; done
  [ -n "$to" ] || { echo "FAIL: --to <change-id> obrigatório" >&2; exit 1; }
  _init_ledger
  result="$(node - "$LF" "$id" "$to" "$(_git_date)" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, id, to, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
const e = (data.entries || []).find((x) => x.id === id);
if (!e) { console.error('entrada ' + id + ' não encontrada'); process.exit(1); }
e.status = 'promoted';
e.updated_at = now;
if (!e.links) e.links = { adr: [], capability: [], change: [], promoted_to: null };
e.links.promoted_to = to;
if (!Array.isArray(e.links.change)) e.links.change = [];
if (!e.links.change.includes(to)) e.links.change.push(to);
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"
  _write_json "$LF" "$result"
  _render
  echo "OK promote — $id -> $to (status: promoted)"
  ;;

harvest)
  change_id="${1:-}"; shift || true
  [ -n "$change_id" ] || { echo "WARN: harvest sem change-id — nada colhido" >&2; exit 0; }
  origin="close"
  while [ $# -gt 0 ]; do case "$1" in --origin) origin="$2"; shift 2 ;; *) shift ;; esac; done
  spec_dir="$ROOT/.forge/specs/active/$change_id"
  # best-effort: sem pasta do change, não há o que colher — nunca falha o caller (close/archive).
  [ -d "$spec_dir" ] || { echo "OK harvest $change_id — 0 nova(s) (change não encontrado)"; exit 0; }
  _init_ledger
  before="$(node -e "const d=JSON.parse(require('fs').readFileSync('$LF','utf8'));console.log((d.entries||[]).length)")"
  result="$(node - "$LF" "$change_id" "$origin" "$spec_dir" "$(_git_date)" <<'NODEEOF'
const { readFileSync, existsSync } = require('fs');
const { join } = require('path');
const [, , lf, changeId, origin, specDir, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
if (!Array.isArray(data.entries)) data.entries = [];
const seen = new Set(data.entries.map((e) => e.dedup_key).filter(Boolean));
let max = data.entries.reduce((m, e) => { const n = parseInt((e.id || '').replace('LDG-', ''), 10); return Number.isFinite(n) && n > m ? n : m; }, 0);

const readText = (p) => { try { return readFileSync(p, 'utf8'); } catch { return ''; } };
const candidates = [];

// (1) Deferrals — JSON estruturado, o caminho mais confiável.
try {
  const dj = JSON.parse(readText(join(specDir, 'deferrals.json')) || '{}');
  for (const d of (dj.deferrals || [])) {
    if (d.status === 'open') candidates.push({ type: 'follow-up', title: d.description || d.reason || d.id, detail: d.reason || '', severity: null, ref: d.id });
    else if (d.status === 'wont-fix') candidates.push({ type: 'tech-debt', title: d.description || d.reason || d.id, detail: d.reason || '', severity: null, ref: d.id });
    // resolved/tested: tratados dentro do change — não colhe.
  }
} catch { /* best-effort */ }

// (2) analysis.md — findings MEDIUM/LOW da tabela pipe (BLOCKER/HIGH são gate-resolvidos antes).
const analysis = readText(join(specDir, 'analysis.md'));
if (analysis) {
  for (const line of analysis.split('\n')) {
    if (!line.trim().startsWith('|')) continue;
    const cells = line.split('|').map((c) => c.trim());
    const sevIdx = cells.findIndex((c) => /^(MEDIUM|LOW)$/.test(c));
    if (sevIdx < 0) continue;
    const severity = cells[sevIdx];
    const idCell = cells.slice(1, sevIdx).find((c) => c && !/^-+$/.test(c)) || '';
    const rest = cells.slice(sevIdx + 1).filter((c) => c && !/^-+$/.test(c));
    const title = (rest.join(' — ') || idCell || 'finding').slice(0, 200);
    const ref = idCell || `analysis-L${analysis.split('\n').indexOf(line) + 1}`;
    candidates.push({ type: 'tech-debt', title, detail: '', severity, ref });
  }
}

// (3) verification.md — bullets sob "Desvios e observações" / "RESSALVAS" -> follow-up.
const verification = readText(join(specDir, 'verification.md'));
if (verification) {
  const lines = verification.split('\n');
  let capturing = false, n = 0;
  for (const line of lines) {
    if (/^#{1,6}\s/.test(line)) capturing = /desvios|ressalvas|observa/i.test(line);
    else if (capturing && /^\s*[-*]\s+/.test(line)) {
      const title = line.replace(/^\s*[-*]\s+/, '').trim().slice(0, 200);
      if (title) candidates.push({ type: 'follow-up', title, detail: '', severity: null, ref: `verify-${++n}` });
    }
  }
}

for (const c of candidates) {
  const dedup = `${changeId}:${c.ref}`;
  if (seen.has(dedup)) continue;
  seen.add(dedup);
  max += 1;
  const id = 'LDG-' + String(max).padStart(4, '0');
  data.entries.push({
    id, type: c.type, title: c.title, detail: c.detail || '',
    severity: c.severity || null, priority: null, status: 'open',
    source: { change_id: changeId, origin, ref: c.ref },
    links: { adr: [], capability: [], change: [changeId], promoted_to: null },
    created_at: now, updated_at: null, resolved_at: null, dedup_key: dedup,
  });
}
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"
  _write_json "$LF" "$result"
  _render
  after="$(node -e "const d=JSON.parse(require('fs').readFileSync('$LF','utf8'));console.log((d.entries||[]).length)")"
  echo "OK harvest $change_id ($origin) — $((after - before)) nova(s) entrada(s) no ledger"
  ;;

render)
  _init_ledger; _render; echo "OK $OUT"
  ;;

status)
  _init_ledger
  node - "$LF" <<'NODEEOF'
const { readFileSync } = require('fs');
const data = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const CLOSED = new Set(['resolved', 'wont-fix', 'promoted']);
const active = (data.entries || []).filter((e) => !CLOSED.has(e.status));
if (!active.length) { console.log('LEDGER: vazio'); process.exit(0); }
const by = {};
for (const e of active) by[e.type] = (by[e.type] || 0) + 1;
const hi = active.filter((e) => e.severity === 'BLOCKER' || e.severity === 'HIGH' || e.priority === 'P0' || e.priority === 'P1').length;
const parts = Object.keys(by).sort().map((t) => `${t} ${by[t]}`).join(' · ');
console.log(`LEDGER: ${active.length} ativo(s)${hi ? ` (${hi} alta prioridade)` : ''} · ${parts}`);
NODEEOF
  ;;

list)
  f_status=""; f_type=""; top=""; by_priority=""
  while [ $# -gt 0 ]; do case "$1" in
    --status) f_status="$2"; shift 2 ;;
    --type) f_type="$2"; shift 2 ;;
    --top) top="$2"; shift 2 ;;
    --by-priority) by_priority="1"; shift ;;
    *) shift ;;
  esac; done
  _init_ledger
  node - "$LF" "$f_status" "$f_type" "$top" "$by_priority" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, fStatus, fType, topRaw, byPriority] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
let items = data.entries || [];
if (fStatus) items = items.filter((e) => e.status === fStatus);
if (fType) items = items.filter((e) => e.type === fType);
const PR = { P0: 0, P1: 1, P2: 2, P3: 3 };
const SV = { BLOCKER: 0, HIGH: 1, MEDIUM: 2, LOW: 3 };
const rank = (m, v) => (v != null && m[v] != null ? m[v] : 99);
if (byPriority) items = items.slice().sort((a, b) => (rank(PR, a.priority) - rank(PR, b.priority)) || (rank(SV, a.severity) - rank(SV, b.severity)) || a.id.localeCompare(b.id));
const top = parseInt(topRaw, 10);
if (Number.isFinite(top) && top > 0) items = items.slice(0, top);
if (!items.length) { console.log('(nenhuma entrada)'); process.exit(0); }
for (const e of items) {
  const tag = [e.priority, e.severity].filter(Boolean).join('/');
  console.log(`${e.id} [${e.type}/${e.status}]${tag ? ' (' + tag + ')' : ''} — ${e.title}`);
}
NODEEOF
  ;;

*)
  echo "FAIL: comando desconhecido '$cmd'" >&2; exit 1
  ;;
esac
