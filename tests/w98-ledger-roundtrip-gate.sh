#!/usr/bin/env bash
# Gate W98 — controle do ciclo item-do-ledger -> change -> baixa (A+B+C):
#   [1] spec new --from-ledger promove a entrada (status: promoted) + grava ledger_origin no manifest
#   [2] close abandoned de um change from-ledger REABRE a entrada (status: open — volta ao roadmap)
#   [3] close delivered-externally de um change from-ledger RESOLVE a entrada
#   [4] --from-ledger com id inexistente: change criado mesmo assim, com WARN (não-bloqueante)
#   [5] doctor sinaliza item promoted cujo change de destino sumiu (órfão), non-blocking
# (o caminho archive -> resolved é coberto no w32-archive-gate passo [1].)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w98.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
SN="$T/.forge/scripts/spec-new.sh"; CL="$T/.forge/scripts/spec-close.sh"
LG="$T/.forge/scripts/ledger-ops.sh"; DR="$T/.forge/scripts/doctor.sh"
git -C "$T" init -q && git -C "$T" add -A && git -C "$T" -c user.email=t@t -c user.name=t commit -qm init >/dev/null

status_of() { node -e 'const d=require(process.argv[1]);const e=(d.entries||[]).find(x=>x.id===process.argv[2]);process.stdout.write(e?e.status:"MISSING")' "$T/.forge/ledger/ledger.json" "$1"; }

echo "[1] spec new --from-ledger promove + grava ledger_origin"
FORGE_ROOT="$T" bash "$LG" add --type roadmap --title "módulo X" >/dev/null   # LDG-0001
FORGE_ROOT="$T" bash "$SN" chg-a --type feature --scale 1 --from-ledger LDG-0001 >/dev/null
grep -q '^ledger_origin: LDG-0001$' "$T/.forge/specs/active/chg-a/manifest.yaml" || { echo "FAIL: manifest sem ledger_origin"; exit 1; }
[ "$(status_of LDG-0001)" = "promoted" ] || { echo "FAIL: LDG-0001 não ficou promoted (got $(status_of LDG-0001))"; exit 1; }
echo "OK [1]"

echo "[2] close abandoned reabre a entrada de origem"
FORGE_ROOT="$T" bash "$CL" chg-a --reason abandoned --note "adiado" >/dev/null
[ "$(status_of LDG-0001)" = "open" ] || { echo "FAIL: LDG-0001 não reaberto (got $(status_of LDG-0001))"; exit 1; }
echo "OK [2]"

echo "[3] close delivered-externally resolve a entrada de origem"
FORGE_ROOT="$T" bash "$LG" add --type feature-idea --title "módulo Y" >/dev/null   # LDG-0002
FORGE_ROOT="$T" bash "$SN" chg-b --type feature --scale 1 --from-ledger LDG-0002 >/dev/null
FORGE_ROOT="$T" bash "$CL" chg-b --reason delivered-externally --note "PR #123" >/dev/null
[ "$(status_of LDG-0002)" = "resolved" ] || { echo "FAIL: LDG-0002 não resolved (got $(status_of LDG-0002))"; exit 1; }
echo "OK [3]"

echo "[4] --from-ledger inexistente: change criado, WARN, sem abortar"
out="$(FORGE_ROOT="$T" bash "$SN" chg-c --type feature --scale 1 --from-ledger LDG-9999 2>&1)"; rc=$?
[ $rc -eq 0 ] || { echo "FAIL: spec-new abortou com ledger id inexistente"; exit 1; }
[ -d "$T/.forge/specs/active/chg-c" ] || { echo "FAIL: change chg-c não criado"; exit 1; }
printf '%s' "$out" | grep -q "WARN" || { echo "FAIL: sem WARN para ledger id inexistente"; exit 1; }
echo "OK [4]"

echo "[5] doctor sinaliza promoted órfão (change ausente) — advisory non-load-bearing"
# baseline: rc do doctor ANTES do órfão (num fixture bare o doctor pode sair !=0 por diagnósticos
# não relacionados — o que importa é que o check do ledger NÃO altera esse rc). set +e: o doctor
# sai !=0 legitimamente aqui e não deve derrubar o gate.
set +e
FORGE_ROOT="$T" bash "$DR" >/dev/null 2>&1; rc_base=$?
set -e
FORGE_ROOT="$T" bash "$LG" add --type roadmap --title "órfão" >/dev/null   # LDG-0003
FORGE_ROOT="$T" bash "$LG" promote LDG-0003 --to change-que-nao-existe >/dev/null
set +e
out="$(FORGE_ROOT="$T" bash "$DR" 2>&1)"; rc_orphan=$?
set -e
printf '%s' "$out" | grep -q "LDG-0003" || { echo "FAIL: doctor não sinalizou LDG-0003 órfão"; exit 1; }
[ "$rc_orphan" = "$rc_base" ] || { echo "FAIL: check do ledger mudou o exit do doctor ($rc_base -> $rc_orphan) — deveria ser non-load-bearing"; exit 1; }
echo "OK [5]"

echo "PASS w98-ledger-roundtrip-gate"
