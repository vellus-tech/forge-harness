#!/usr/bin/env bash
# Gate W323 — fila de priorização entre sessões do squad (pedido do Milton, 02/11). Estende o
# ledger.json existente (ledger-ops.sh), nunca cria arquivo novo: prioridade EMERGENCIAL (acima
# de P0-P3, reservada a pedido direto do dono, sempre vence qualquer P0-P3 em andamento) e
# preempção por checkpoint (assign/pause/resume), ortogonal a `status` — pause/resume nunca tocam
# `status`/`resolved_at` (mesma disciplina de ledger-consultation.md contra status virar veículo
# de progresso informal).
#
#   [1] 'assign <id> --to <sessão>' grava assigned_to/assigned_at; sem '--to' reprova
#   [2] 'add --priority EMERGENCIAL' é aceito pelo schema (antes só P0-P3)
#   [3] 'pause <id> --by <emergencial> --checkpoint "<txt>"' grava paused_by/paused_at/checkpoint
#       SEM tocar status; sem '--by' e sem '--checkpoint' reprovam, cada um isolado
#   [4] 'pause --by <não-EMERGENCIAL>' reprova — só EMERGENCIAL preempta
#   [5] 'resume <id>' limpa paused_by/paused_at/checkpoint, sem tocar status; em item não-pausado
#       reprova
#   [6] 'list --assigned' mostra só entradas com assigned_to, com o peso (priority) visível
#   [7] 'pause' em item já pausado reprova (não empilha pausa sobre pausa)
#   [8] MUTAÇÃO (sandbox) — remover a checagem de priority EMERGENCIAL em 'pause' faz [4] passar
#       quando deveria reprovar (qualquer entrada preemptaria qualquer outra)
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem
# ao repositório de quem invocou o gate, e não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v node >/dev/null 2>&1 || { echo "NÃO VERIFICADO: 'node' ausente"; exit 3; }
command -v git  >/dev/null 2>&1 || { echo "NÃO VERIFICADO: 'git' ausente — a fixture precisa de um commit para a data determinística"; exit 3; }

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w323.XXXXXX")"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q
git -C "$T" add -A >/dev/null
git -C "$T" -c user.email=t@t -c user.name=t commit -qm init >/dev/null

LG="$T/.forge/scripts/ledger-ops.sh"
LF="$T/.forge/ledger/ledger.json"
_lg() { FORGE_ROOT="$T" bash "$LG" "$@"; }
_field_of() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);const v=e&&e[process.argv[3]];process.stdout.write(v==null?"":String(v))' "$LF" "$1" "$2"; }

# ── fixture: um item comum (LDG-0001) e, depois de [2], um EMERGENCIAL (LDG-0002) ──────────────
out_add1="$(_lg add --type tech-debt --title "item comum do w323" --priority P1)"
id1="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).entries[0].id)' "$LF")"

echo "[1] assign grava assigned_to/assigned_at; sem --to reprova"
_lg assign "$id1" --to CODER >/dev/null
[ "$(_field_of "$id1" assigned_to)" = "CODER" ] || { echo "FAIL [1]: assigned_to não gravado"; exit 1; }
[ -n "$(_field_of "$id1" assigned_at)" ] || { echo "FAIL [1]: assigned_at não gravado"; exit 1; }
if _lg assign "$id1" 2>/tmp/w323-err1; then echo "FAIL [1]: assign sem --to deveria reprovar"; exit 1; fi
grep -qi -- "--to" /tmp/w323-err1 || { echo "FAIL [1]: mensagem não cita --to"; exit 1; }
echo "OK [1]"

echo "[2] add --priority EMERGENCIAL é aceito"
_lg add --type follow-up --title "pedido emergencial do Milton (w323)" --priority EMERGENCIAL >/dev/null
id2="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$LF")"
[ "$(_field_of "$id2" priority)" = "EMERGENCIAL" ] || { echo "FAIL [2]: priority EMERGENCIAL não gravada"; exit 1; }
echo "OK [2]"

echo "[3] pause grava paused_by/paused_at/checkpoint sem tocar status; sem --by/--checkpoint reprova"
status_before="$(_field_of "$id1" status)"
_lg pause "$id1" --by "$id2" --checkpoint "parei no passo 3 do teste X" >/dev/null
[ "$(_field_of "$id1" paused_by)" = "$id2" ] || { echo "FAIL [3]: paused_by não gravado"; exit 1; }
[ -n "$(_field_of "$id1" paused_at)" ] || { echo "FAIL [3]: paused_at não gravado"; exit 1; }
[ "$(_field_of "$id1" checkpoint)" = "parei no passo 3 do teste X" ] || { echo "FAIL [3]: checkpoint não gravado"; exit 1; }
[ "$(_field_of "$id1" status)" = "$status_before" ] || { echo "FAIL [3]: status mudou (deveria ser ortogonal)"; exit 1; }
if _lg pause "$id1" --checkpoint "x" 2>/tmp/w323-err3a; then echo "FAIL [3]: pause sem --by deveria reprovar"; exit 1; fi
grep -qi -- "--by" /tmp/w323-err3a || { echo "FAIL [3]: mensagem não cita --by"; exit 1; }
_lg resume "$id1" >/dev/null
if _lg pause "$id1" --by "$id2" 2>/tmp/w323-err3b; then echo "FAIL [3]: pause sem --checkpoint deveria reprovar"; exit 1; fi
grep -qi -- "--checkpoint" /tmp/w323-err3b || { echo "FAIL [3]: mensagem não cita --checkpoint"; exit 1; }
echo "OK [3]"

echo "[4] pause --by <não-EMERGENCIAL> reprova"
out_add3="$(_lg add --type known-bug --title "item comum 2 do w323" --priority P2)"
id3="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$LF")"
if _lg pause "$id3" --by "$id1" --checkpoint "x" 2>/tmp/w323-err4; then echo "FAIL [4]: pause --by de entrada não-EMERGENCIAL deveria reprovar"; exit 1; fi
grep -qi "EMERGENCIAL" /tmp/w323-err4 || { echo "FAIL [4]: mensagem não cita EMERGENCIAL ($(cat /tmp/w323-err4))"; exit 1; }
[ -z "$(_field_of "$id3" paused_by)" ] || { echo "FAIL [4]: paused_by foi gravado mesmo com a recusa"; exit 1; }
echo "OK [4]"

echo "[5] resume limpa paused_by/paused_at/checkpoint sem tocar status; em item não-pausado reprova"
_lg pause "$id1" --by "$id2" --checkpoint "parei de novo" >/dev/null
status_before2="$(_field_of "$id1" status)"
_lg resume "$id1" >/dev/null
[ -z "$(_field_of "$id1" paused_by)" ] || { echo "FAIL [5]: paused_by não limpo"; exit 1; }
[ -z "$(_field_of "$id1" paused_at)" ] || { echo "FAIL [5]: paused_at não limpo"; exit 1; }
[ -z "$(_field_of "$id1" checkpoint)" ] || { echo "FAIL [5]: checkpoint não limpo"; exit 1; }
[ "$(_field_of "$id1" status)" = "$status_before2" ] || { echo "FAIL [5]: status mudou no resume"; exit 1; }
if _lg resume "$id3" 2>/tmp/w323-err5; then echo "FAIL [5]: resume em item não-pausado deveria reprovar"; exit 1; fi
echo "OK [5]"

echo "[6] list --assigned mostra só entradas com assigned_to"
out6="$(_lg list --assigned)"
echo "$out6" | grep -q "^$id1 " || { echo "FAIL [6]: $id1 (assigned) ausente de 'list --assigned' ($out6)"; exit 1; }
echo "$out6" | grep -q "^$id3 " && { echo "FAIL [6]: $id3 (não atribuída) apareceu em 'list --assigned'"; exit 1; }
echo "$out6" | grep -q "atribuído a CODER" || { echo "FAIL [6]: linha não mostra 'atribuído a CODER' ($out6)"; exit 1; }
echo "OK [6]"

echo "[7] pause em item já pausado reprova"
_lg pause "$id3" --by "$id2" --checkpoint "primeira pausa" >/dev/null
if _lg pause "$id3" --by "$id2" --checkpoint "segunda pausa" 2>/tmp/w323-err7; then echo "FAIL [7]: pause duplo deveria reprovar"; exit 1; fi
[ "$(_field_of "$id3" checkpoint)" = "primeira pausa" ] || { echo "FAIL [7]: checkpoint foi sobrescrito pelo pause duplo"; exit 1; }
echo "OK [7]"

echo "[8] MUTAÇÃO (sandbox) — remover a checagem de priority EMERGENCIAL em pause faz [4] passar quando deveria reprovar"
MT="$(mktemp -d "${TMPDIR:-/tmp}/forge-w323-mut.XXXXXX")"
cp -R "$WS/template/.forge" "$MT/.forge"
LGM="$MT/.forge/ledger-ops-mut.sh"
node -e '
const fs = require("fs");
const path = process.argv[1];
let content = fs.readFileSync(path, "utf8");
const marker = "if (emergencia.priority !== \x27EMERGENCIAL\x27)";
const idx = content.indexOf(marker);
if (idx === -1) { console.error("marcador não encontrado"); process.exit(1); }
const end = content.indexOf("process.exit(1); }", idx) + "process.exit(1); }".length;
content = content.slice(0, idx) + content.slice(end);
fs.writeFileSync(path, content);
' "$MT/.forge/scripts/ledger-ops.sh"
git -C "$MT" init -q
git -C "$MT" add -A >/dev/null
git -C "$MT" -c user.email=t@t -c user.name=t commit -qm init >/dev/null
_lgm() { FORGE_ROOT="$MT" bash "$MT/.forge/scripts/ledger-ops.sh" "$@"; }
LFM="$MT/.forge/ledger/ledger.json"
_lgm add --type tech-debt --title "comum-mut" --priority P1 >/dev/null
idm1="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).entries[0].id)' "$LFM")"
_lgm add --type tech-debt --title "comum-mut-2" --priority P2 >/dev/null
idm2="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$LFM")"
if _lgm pause "$idm1" --by "$idm2" --checkpoint "x" 2>/tmp/w323-mut.log; then
  echo "OK [8] — mutação removeu a checagem EMERGENCIAL, pause --by de item comum passou sem reprovar, como [4] previa"
else
  echo "FAIL [8]: a mutação deveria fazer o pause passar sem checagem, mas ele reprovou mesmo assim ($(cat /tmp/w323-mut.log))"; rm -rf "$MT"; exit 1
fi
rm -rf "$MT"
echo "OK [8]"

echo "OK"
