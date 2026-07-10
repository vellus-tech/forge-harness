#!/usr/bin/env bash
# Gate W-yolo — modo autônomo / YOLO (§12.2). O mecanismo determinista que sustenta o --yolo:
#   [1] approval-log --autonomous grava decisão auditável (autonomous:true + decided_by do decisor
#       autônomo) e exige --reason MESMO em approve (a máquina sempre registra a análise)
#   [2] approve autônomo SEM --reason → recusado (a honestidade de auditoria é obrigatória)
#   [3] a entrada autônoma valida contra approvals.schema.json (ajv) E validate-spec (zero-dep)
#   [4] decisão HUMANA não marca autonomous — as duas são distinguíveis numa auditoria
#   [5] config + agent + rule presentes: forge.yaml bloco autonomy (mode: hitl default + hard-stop),
#       agent review/yolo-gate.md (opus), rule autonomy-yolo.md indexada
#   [6] hard-stop DETERMINISTA: --autonomous num gate de human_hard_stops é recusado (exit 2) —
#       a fronteira de segurança é mecânica, não confiável ao juízo do agente (§13.1)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-yolo.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
SN="$T/.forge/scripts/spec-new.sh"; AL="$T/.forge/scripts/approval-log.sh"; VS="$T/.forge/scripts/validate-spec.sh"

echo "[1] approval-log --autonomous grava decisão auditável (approve carrega reason)"
(cd "$T" && bash "$SN" chg-y --type feature --scale 2 >/dev/null)
(cd "$T" && bash "$AL" chg-y --gate design_reviewed --decision approve \
  --reason "design cobre INV-01..05, PBTs mapeados, sem NEEDS CLARIFICATION" --autonomous >/dev/null)
AP="$T/.forge/specs/active/chg-y/approvals.yaml"
grep -q '^    autonomous: true$' "$AP" || { echo "FAIL [1] (autonomous:true ausente)"; exit 1; }
grep -q 'decided_by: "forge-yolo (opus, high)"' "$AP" || { echo "FAIL [1] (decided_by não é o decisor autônomo)"; exit 1; }
grep -q 'decision: approve' "$AP" || { echo "FAIL [1] (decisão ausente)"; exit 1; }
grep -q '    reason: "design cobre' "$AP" || { echo "FAIL [1] (approve autônomo sem reason gravado)"; exit 1; }
echo "OK [1]"

echo "[2] approve autônomo sem --reason → recusado"
set +e
(cd "$T" && bash "$AL" chg-y --gate tasks_reviewed --decision approve --autonomous) >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [2] (aceitou approve autônomo sem reason)"; exit 1; }
echo "OK [2]"

echo "[3] entrada autônoma valida (ajv + zero-dep)"
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/approvals.schema.json" "$AP" >/dev/null \
  || { echo "FAIL [3] (ajv recusou a entrada autônoma)"; exit 1; }
(cd "$T" && bash "$VS" chg-y >/dev/null) || { echo "FAIL [3] (validate-spec recusou)"; exit 1; }
echo "OK [3]"

echo "[4] decisão humana NÃO marca autonomous (distinguível)"
(cd "$T" && bash "$SN" chg-h --type feature --scale 1 >/dev/null)
(cd "$T" && bash "$AL" chg-h --gate requirements_reviewed --decision approve >/dev/null)
APH="$T/.forge/specs/active/chg-h/approvals.yaml"
grep -q 'autonomous:' "$APH" && { echo "FAIL [4] (decisão humana marcou autonomous)"; exit 1; }
grep -q 'decided_by: "forge-yolo' "$APH" && { echo "FAIL [4] (humano gravado como decisor autônomo)"; exit 1; }
echo "OK [4]"

echo "[5] config + agent + rule presentes"
grep -q '^autonomy:' "$T/.forge/forge.yaml" || { echo "FAIL [5] (bloco autonomy ausente)"; exit 1; }
grep -qE '^  mode: hitl$' "$T/.forge/forge.yaml" || { echo "FAIL [5] (default não é hitl)"; exit 1; }
grep -q 'human_archive_approval' "$T/.forge/forge.yaml" || { echo "FAIL [5] (hard-stop default ausente)"; exit 1; }
[ -f "$T/.forge/agents/review/yolo-gate.md" ] || { echo "FAIL [5] (agent yolo-gate ausente)"; exit 1; }
grep -qE '^model: opus$' "$T/.forge/agents/review/yolo-gate.md" || { echo "FAIL [5] (yolo-gate não é opus)"; exit 1; }
[ -f "$T/.forge/rules/conventions/autonomy-yolo.md" ] || { echo "FAIL [5] (rule autonomy-yolo ausente)"; exit 1; }
grep -q 'autonomy-yolo.md' "$T/.forge/rules/README.md" || { echo "FAIL [5] (rule não indexada no README)"; exit 1; }
echo "OK [5]"

echo "[6] hard-stop determinista: --autonomous em human_archive_approval → recusado (exit 2)"
set +e
(cd "$T" && bash "$AL" chg-y --gate human_archive_approval --decision approve \
  --reason "tentativa de auto-aprovar mutação de baseline" --autonomous) >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || { echo "FAIL [6] (autônomo aprovou gate hard-stop — exit $rc, esperado 2)"; exit 1; }
# e o gate NÃO foi flipado no manifest (a decisão foi barrada antes de qualquer escrita)
grep -qE '^  human_archive_approval: false$' "$T/.forge/specs/active/chg-y/manifest.yaml" \
  || { echo "FAIL [6] (gate hard-stop foi flipado apesar da recusa)"; exit 1; }
echo "OK [6]"

echo "PASS w95-yolo-gate"
