#!/usr/bin/env bash
# Gate W200 — flag engolida como valor de outra flag (issue #103).
#
# Todo parser de flags de `ledger-ops.sh`, `deferral-ops.sh` e `liaison-ops.sh` lia o valor como
# "$2" sem perguntar o que "$2" era. Quando o operador esquecia o valor, a flag SEGUINTE ocupava o
# lugar dele: o comando devolvia rc=0, imprimia `OK`, e gravava no registro durável o NOME de uma
# flag no lugar do conteúdo.
#
#   [1]  ledger-ops update  --detail --title              (flag consome nome de outra flag)
#   [2]  ledger-ops add     --title --detail               (idem, subcomando diferente)
#   [3]  os 6 subcomandos de ledger-ops, parametrizado (universo contado — contrapositiva)
#   [4]  deferral-ops raise --reason --blocks               (mesma família)
#   [5]  deferral-ops raise --blockss (flag DESCONHECIDA — guarda DIFERENTE da de [4])
#   [6]  liaison send        --subject --requires-ack
#   [7]  liaison thread open --subject --requires-ack
#   [8]  liaison thread join --subject --requires-ack
#   [9]  liaison ack         --subject --reason
#   [10] contador de universo dos sítios liaison exercitados por ESTE gate (não grep de script)
#   [P1] list --top -3 sobrevive (prefixo de hífen é valor legítimo, não flag)
#   [P2] add --detail '---frontmatter' sobrevive literal
#   [P3] caminho feliz de cada subcomando fiado continua rc=0 e grava o conteúdo certo — é o único
#        cenário que pega o aborto MUDO da restrição (i): primitiva sem `return 0` explícito
#        aborta o chamador sob `set -euo pipefail` (liaison-ops.sh) mesmo no caminho aceito.
#   [11] mutação: (a) remover o teste de pertencimento em lib/arg-guards.sh faz [1],[2],[4],[6],
#        [7],[8],[9] voltarem a rc=0 COM o campo corrompido; (b) restaurar `*) shift ;;` no
#        `raise` do deferral-ops faz SÓ [5] voltar. Restauração por cmp byte a byte + recontrole.
#
# Critério: PERTENCIMENTO ao conjunto de flags DECLARADAS do subcomando — nunca "começa com
# hífen" (a alternativa por prefixo reprovaria [P1]/[P2], que são controle obrigatório aqui).
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── sentinela do repositório real: nenhuma escrita fora do sandbox ─────────────────────────────
REPO_SNAPSHOT_BEFORE="$(git -C "$WS" status --porcelain)"

T="$(mktemp -d /tmp/forge-w200.XXXXXX)"
trap 'rm -rf "$T"' EXIT

_run_to() { # _run_to <segundos> -- <cmd...>  — teto de tempo (macOS não tem `timeout` por padrão)
  local secs="$1"; shift
  [ "${1:-}" = "--" ] && shift
  perl -e "alarm $secs; exec @ARGV" -- "$@"
}

# ── fixture viva: template completo sob git ─────────────────────────────────────────────────────
cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q
_run_to 20 -- git -C "$T" add -A
_run_to 20 -- git -C "$T" -c user.email=t@t -c user.name=t commit -qm init >/dev/null

LG="$T/.forge/scripts/ledger-ops.sh"
DFO="$T/.forge/scripts/deferral-ops.sh"
LO="$T/.forge/scripts/liaison-ops.sh"
LF="$T/.forge/ledger/ledger.json"
CH="ch-w200"
DFJ="$T/.forge/specs/active/$CH/deferrals.json"
CHAN="canal-w200"
SELFLOG="$T/.forge/liaison/$CHAN/log/repo-a.jsonl"

_lg()  { _run_to 20 -- env FORGE_ROOT="$T" bash "$LG" "$@"; }
_dfo() { _run_to 20 -- env FORGE_ROOT="$T" bash "$DFO" "$@"; }
_lo()  { _run_to 20 -- env FORGE_ROOT="$T" bash "$LO" "$@"; }

_entries() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((d.entries||[]).length)' "$1"; }
_field_of() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);process.stdout.write(e&&e[process.argv[3]]!=null?String(e[process.argv[3]]):"")' "$1" "$2" "$3"; }
_new_id() { grep -oE 'LDG-[0-9]+' <<<"$1" | head -1; }

mkdir -p "$T/.forge/specs/active/$CH"

# ── seeds ────────────────────────────────────────────────────────────────────────────────────
_lg add --type roadmap --title "titulo real" --detail "detalhe real" >/dev/null   # LDG-0001

out_seed3u="$(_lg add --type roadmap --title "alvo update cenario 3" --detail "x")"; U3ID="$(_new_id "$out_seed3u")"
out_seed3r="$(_lg add --type follow-up --title "alvo resolve cenario 3" --detail "y")"; R3ID="$(_new_id "$out_seed3r")"
out_seed3p="$(_lg add --type known-bug --title "alvo promote cenario 3" --detail "z")"; PR3ID="$(_new_id "$out_seed3p")"

_lo open "$CHAN" --self repo-a --participants repo-a,repo-b >/dev/null
_lo thread open "$CHAN" th-base --subject "assunto base" --participants repo-a,repo-b --body "corpo base" >/dev/null
ack_target="$(_lo send "$CHAN" --thread th-base --kind note --subject "mensagem alvo do ack" --body "corpo alvo" | grep -oE '[a-z0-9-]+-[0-9]{4}')"

# =================================================================================================
# CENÁRIOS NEGATIVOS — asserção TRIPLA: rc≠0 E mensagem nomeia a flag ofensora E registro intacto.
# =================================================================================================

echo "[1] ledger-ops update --detail --title (flag consome nome de outra flag)"
cp "$LF" "$T/snap1.json"
set +e
out1="$(_lg update LDG-0001 --detail --title 2>&1)"; rc1=$?
set -e
[ "$rc1" -ne 0 ] || { echo "FAIL [1]: 'update --detail --title' devolveu rc=0 — got: $out1"; exit 1; }
grep -q -- "--detail" <<<"$out1" || { echo "FAIL [1]: mensagem não nomeia '--detail' — got: $out1"; exit 1; }
grep -q -- "--title" <<<"$out1" || { echo "FAIL [1]: mensagem não nomeia '--title' — got: $out1"; exit 1; }
cmp -s "$LF" "$T/snap1.json" || { echo "FAIL [1]: ledger.json foi alterado por um update recusado"; exit 1; }
echo "OK [1] — $out1"

echo "[2] ledger-ops add --title --detail (idem, subcomando diferente)"
cp "$LF" "$T/snap2.json"
set +e
out2="$(_lg add --type roadmap --title --detail 2>&1)"; rc2=$?
set -e
[ "$rc2" -ne 0 ] || { echo "FAIL [2]: 'add --title --detail' devolveu rc=0 — got: $out2"; exit 1; }
grep -q -- "--title" <<<"$out2" || { echo "FAIL [2]: mensagem não nomeia '--title' — got: $out2"; exit 1; }
grep -q -- "--detail" <<<"$out2" || { echo "FAIL [2]: mensagem não nomeia '--detail' — got: $out2"; exit 1; }
cmp -s "$LF" "$T/snap2.json" || { echo "FAIL [2]: ledger.json ganhou entrada apesar da recusa"; exit 1; }
echo "OK [2] — $out2"

echo "[3] pertencimento parametrizado sobre os 6 subcomandos de ledger-ops"
# promote e harvest declaram UMA flag cada (--to / --origin): o único caso de pertencimento
# possível neles é a flag repetindo a si mesma (degenerado, mas válido — não falta caso nenhum).
SUB3_CASES=(
  "update|update $U3ID --detail --title|--detail|--title"
  "add|add --type roadmap --title --detail|--title|--detail"
  "resolve|resolve $R3ID --note --status|--note|--status"
  "promote|promote $PR3ID --to --to|--to|--to"
  "harvest|harvest ch-fake-w200 --origin --origin|--origin|--origin"
  "list|list --status --type|--status|--type"
)
sub3_n=0; sub3_bad=0
for spec in "${SUB3_CASES[@]}"; do
  IFS='|' read -r label cmdline flag1 flag2 <<<"$spec"
  # shellcheck disable=SC2206
  cmdargs=($cmdline)
  cp "$LF" "$T/snap3-$label.json"
  set +e
  out3="$(_lg "${cmdargs[@]}" 2>&1)"; rc3=$?
  set -e
  sub3_n=$((sub3_n + 1))
  if [ "$rc3" -eq 0 ]; then
    echo "FAIL [3]: subcomando '$label' aceitou flag como valor (rc=0) — got: $out3"; sub3_bad=$((sub3_bad + 1)); continue
  fi
  if ! grep -q -- "$flag1" <<<"$out3"; then
    echo "FAIL [3]: subcomando '$label' não nomeia '$flag1' — got: $out3"; sub3_bad=$((sub3_bad + 1)); continue
  fi
  if ! grep -q -- "$flag2" <<<"$out3"; then
    echo "FAIL [3]: subcomando '$label' não nomeia '$flag2' — got: $out3"; sub3_bad=$((sub3_bad + 1)); continue
  fi
  cmp -s "$LF" "$T/snap3-$label.json" || { echo "FAIL [3]: subcomando '$label' recusado mas alterou ledger.json"; sub3_bad=$((sub3_bad + 1)); }
done
[ "$sub3_bad" -eq 0 ] || { echo "FAIL [3]: $sub3_bad de $sub3_n subcomandos aceitaram flag como valor"; exit 1; }
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w201/ledger-subcomandos" "$sub3_n" "subcomando(s) de ledger-ops" "cenário [3]" "$T" \
  || { echo "FAIL [3]: universo de subcomandos vazio aprovaria em silêncio"; exit 1; }
set +e
out3u="$(forge_universe_check "w201/ledger-subcomandos" 0 "subcomando(s) de ledger-ops" "contrapositiva" "$T" 2>&1)"; rc3u=$?
set -e
[ "$rc3u" -ne 0 ] || { echo "FAIL [3]: universo vazio aprovou — got: $out3u"; exit 1; }
echo "OK [3] — $sub3_n subcomandos de ledger-ops examinados, todos recusam flag como valor"

_dfj_snapshot() { [ -f "$DFJ" ] && cp "$DFJ" "$1" || rm -f "$1"; }
_dfj_unchanged() { # _dfj_unchanged <snapshot> — true quando deferrals.json não mudou (existência + conteúdo)
  if [ -f "$1" ]; then [ -f "$DFJ" ] && cmp -s "$DFJ" "$1"; else [ ! -f "$DFJ" ]; fi
}

echo "[4] deferral-ops raise --reason --blocks (mesma família)"
_dfj_snapshot "$T/snap4.json"
set +e
out4="$(_dfo raise "$CH" --reason --blocks 2>&1)"; rc4=$?
set -e
[ "$rc4" -ne 0 ] || { echo "FAIL [4]: 'raise --reason --blocks' devolveu rc=0 — got: $out4"; exit 1; }
grep -q -- "--reason" <<<"$out4" || { echo "FAIL [4]: mensagem não nomeia '--reason' — got: $out4"; exit 1; }
grep -q -- "--blocks" <<<"$out4" || { echo "FAIL [4]: mensagem não nomeia '--blocks' — got: $out4"; exit 1; }
_dfj_unchanged "$T/snap4.json" || { echo "FAIL [4]: deferrals.json ganhou entrada apesar da recusa"; exit 1; }
echo "OK [4] — $out4"

echo "[5] deferral-ops raise --blockss (flag DESCONHECIDA — guarda diferente da de [4])"
_dfj_snapshot "$T/snap5.json"
set +e
out5="$(_dfo raise "$CH" --reason "trava o archive" --blockss archive 2>&1)"; rc5=$?
set -e
[ "$rc5" -ne 0 ] || { echo "FAIL [5]: 'raise --blockss' (flag desconhecida) devolveu rc=0 — got: $out5"; exit 1; }
grep -q -- "--blockss" <<<"$out5" || { echo "FAIL [5]: mensagem não nomeia a flag desconhecida '--blockss' — got: $out5"; exit 1; }
_dfj_unchanged "$T/snap5.json" || { echo "FAIL [5]: deferrals.json ganhou entrada apesar da recusa"; exit 1; }
echo "OK [5] — $out5"

echo "[6] liaison send --subject --requires-ack"
cp "$SELFLOG" "$T/snap6.jsonl"
set +e
out6="$(_lo send "$CHAN" --thread th-base --kind note --body "corpo real da mensagem" --subject --requires-ack 2>&1)"; rc6=$?
set -e
[ "$rc6" -ne 0 ] || { echo "FAIL [6]: 'send --subject --requires-ack' devolveu rc=0 — got: $out6"; exit 1; }
grep -q -- "--subject" <<<"$out6" || { echo "FAIL [6]: mensagem não nomeia '--subject' — got: $out6"; exit 1; }
grep -q -- "--requires-ack" <<<"$out6" || { echo "FAIL [6]: mensagem não nomeia '--requires-ack' — got: $out6"; exit 1; }
cmp -s "$SELFLOG" "$T/snap6.jsonl" || { echo "FAIL [6]: log JSONL ganhou linha apesar da recusa"; exit 1; }
echo "OK [6] — $out6"

echo "[7] liaison thread open --subject --requires-ack"
cp "$SELFLOG" "$T/snap7.jsonl"
set +e
out7="$(_lo thread open "$CHAN" th-negativo-open --participants repo-a,repo-b --body "corpo real" --subject --requires-ack 2>&1)"; rc7=$?
set -e
[ "$rc7" -ne 0 ] || { echo "FAIL [7]: 'thread open --subject --requires-ack' devolveu rc=0 — got: $out7"; exit 1; }
grep -q -- "--subject" <<<"$out7" || { echo "FAIL [7]: mensagem não nomeia '--subject' — got: $out7"; exit 1; }
grep -q -- "--requires-ack" <<<"$out7" || { echo "FAIL [7]: mensagem não nomeia '--requires-ack' — got: $out7"; exit 1; }
cmp -s "$SELFLOG" "$T/snap7.jsonl" || { echo "FAIL [7]: log JSONL ganhou linha apesar da recusa"; exit 1; }
echo "OK [7] — $out7"

echo "[8] liaison thread join --subject --requires-ack"
cp "$SELFLOG" "$T/snap8.jsonl"
set +e
out8="$(_lo thread join "$CHAN" th-base --body "corpo real" --subject --requires-ack 2>&1)"; rc8=$?
set -e
[ "$rc8" -ne 0 ] || { echo "FAIL [8]: 'thread join --subject --requires-ack' devolveu rc=0 — got: $out8"; exit 1; }
grep -q -- "--subject" <<<"$out8" || { echo "FAIL [8]: mensagem não nomeia '--subject' — got: $out8"; exit 1; }
grep -q -- "--requires-ack" <<<"$out8" || { echo "FAIL [8]: mensagem não nomeia '--requires-ack' — got: $out8"; exit 1; }
cmp -s "$SELFLOG" "$T/snap8.jsonl" || { echo "FAIL [8]: log JSONL ganhou linha apesar da recusa"; exit 1; }
echo "OK [8] — $out8"

echo "[9] liaison ack --subject --reason"
cp "$SELFLOG" "$T/snap9.jsonl"
set +e
out9="$(_lo ack "$CHAN" "$ack_target" --body "corpo do ack" --subject --reason 2>&1)"; rc9=$?
set -e
[ "$rc9" -ne 0 ] || { echo "FAIL [9]: 'ack --subject --reason' devolveu rc=0 — got: $out9"; exit 1; }
grep -q -- "--subject" <<<"$out9" || { echo "FAIL [9]: mensagem não nomeia '--subject' — got: $out9"; exit 1; }
grep -q -- "--reason" <<<"$out9" || { echo "FAIL [9]: mensagem não nomeia '--reason' — got: $out9"; exit 1; }
cmp -s "$SELFLOG" "$T/snap9.jsonl" || { echo "FAIL [9]: log JSONL ganhou linha apesar da recusa"; exit 1; }
echo "OK [9] — $out9"

echo "[10] contador de universo dos sítios liaison exercitados por este gate (casos, não grep)"
LIAISON_CASES_RUN=4   # [6] send, [7] thread open, [8] thread join, [9] ack — contagem de EXECUÇÃO
forge_universe_check "w201/liaison-sitios" "$LIAISON_CASES_RUN" "sítio(s) de liaison-ops guardado(s)" "cenários [6]-[9]" "$T" \
  || { echo "FAIL [10]: universo de sítios liaison vazio aprovaria em silêncio"; exit 1; }
set +e
out10u="$(forge_universe_check "w201/liaison-sitios" 0 "sítio(s) de liaison-ops guardado(s)" "contrapositiva" "$T" 2>&1)"; rc10u=$?
set -e
[ "$rc10u" -ne 0 ] || { echo "FAIL [10]: universo vazio aprovou — got: $out10u"; exit 1; }
echo "OK [10] — $LIAISON_CASES_RUN sítios de liaison-ops examinados neste gate"

# =================================================================================================
# CONTROLES POSITIVOS — obrigatórios: sem eles, uma implementação por PREFIXO (que reprova tudo
# que começa com hífen) passaria em todo cenário negativo acima e não seria pega.
# =================================================================================================

echo "[P1] list --top -3 sobrevive (prefixo de hífen é valor legítimo, não flag)"
set +e
outp1="$(_lg list --top -3 2>&1)"; rcp1=$?
set -e
[ "$rcp1" -eq 0 ] || { echo "FAIL [P1]: 'list --top -3' reprovou — got rc=$rcp1: $outp1"; exit 1; }
echo "OK [P1] — $outp1" | head -1

echo "[P2] add --detail '---frontmatter' sobrevive literal"
set +e
outp2="$(_lg add --type roadmap --title "controle P2" --detail "---frontmatter" 2>&1)"; rcp2=$?
set -e
[ "$rcp2" -eq 0 ] || { echo "FAIL [P2]: 'add --detail ---frontmatter' reprovou — got rc=$rcp2: $outp2"; exit 1; }
p2id="$(_new_id "$outp2")"
p2detail="$(_field_of "$LF" "$p2id" detail)"
[ "$p2detail" = "---frontmatter" ] || { echo "FAIL [P2]: detail gravado != '---frontmatter' (got '$p2detail')"; exit 1; }
echo "OK [P2] — $p2id detail='$p2detail'"

echo "[P3] caminho feliz de cada subcomando fiado continua rc=0 e grava certo (pega o aborto MUDO)"
p3_fail=0

set +e
outp3u="$(_lg update "$U3ID" --detail "detalhe legítimo do P3" 2>&1)"; rcp3u=$?
set -e
if [ "$rcp3u" -ne 0 ] || [ "$(_field_of "$LF" "$U3ID" detail)" != "detalhe legítimo do P3" ]; then
  echo "FAIL [P3]: update caminho feliz quebrou — got rc=$rcp3u: $outp3u"; p3_fail=1
fi

set +e
outp3a="$(_lg add --type roadmap --title "P3 add" --detail "P3 add detail" 2>&1)"; rcp3a=$?
set -e
p3a_id="$(_new_id "$outp3a")"
if [ "$rcp3a" -ne 0 ] || [ "$(_field_of "$LF" "$p3a_id" detail)" != "P3 add detail" ]; then
  echo "FAIL [P3]: add caminho feliz quebrou — got rc=$rcp3a: $outp3a"; p3_fail=1
fi

set +e
outp3raise="$(_dfo raise "$CH" --reason "texto real de P3" --blocks archive 2>&1)"; rcp3raise=$?
set -e
p3_defer_id="$(grep -oE 'DEFER-[0-9]+' <<<"$outp3raise" | head -1)"
p3_blocks="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const x=d.deferrals.find(y=>y.id===process.argv[2]);console.log(JSON.stringify(x&&x.blocks))' "$DFJ" "$p3_defer_id" 2>/dev/null)"
if [ "$rcp3raise" -ne 0 ] || [ "$p3_blocks" != '["archive"]' ]; then
  echo "FAIL [P3]: deferral raise caminho feliz quebrou — got rc=$rcp3raise: $outp3raise (blocks=$p3_blocks)"; p3_fail=1
fi

# É este que pega a restrição (i): uma primitiva sem `return 0` explícito aborta MUDO aqui, sob
# `set -euo pipefail` de liaison-ops.sh — rc≠0 e ZERO saída, sem nomear flag nenhuma.
set +e
outp3send="$(_lo send "$CHAN" --thread th-base --kind note --subject "assunto legitimo p3" --body "corpo legitimo p3" 2>&1)"; rcp3send=$?
set -e
if [ "$rcp3send" -ne 0 ] || ! grep -q "^OK send" <<<"$outp3send"; then
  echo "FAIL [P3]: send caminho feliz quebrou (possível aborto mudo da restrição (i)) — got rc=$rcp3send: $outp3send"; p3_fail=1
fi

set +e
outp3open="$(_lo thread open "$CHAN" th-p3-open --participants repo-a,repo-b --subject "assunto p3 open" --body "corpo p3 open" 2>&1)"; rcp3open=$?
set -e
if [ "$rcp3open" -ne 0 ] || ! grep -q "^OK thread open" <<<"$outp3open"; then
  echo "FAIL [P3]: thread open caminho feliz quebrou — got rc=$rcp3open: $outp3open"; p3_fail=1
fi

set +e
outp3join="$(_lo thread join "$CHAN" th-p3-open --subject "assunto p3 join" --body "corpo p3 join" 2>&1)"; rcp3join=$?
set -e
if [ "$rcp3join" -ne 0 ] || ! grep -q "^OK thread join" <<<"$outp3join"; then
  echo "FAIL [P3]: thread join caminho feliz quebrou — got rc=$rcp3join: $outp3join"; p3_fail=1
fi

set +e
outp3ack="$(_lo ack "$CHAN" "$ack_target" --subject "assunto p3 ack" --body "corpo p3 ack" 2>&1)"; rcp3ack=$?
set -e
if [ "$rcp3ack" -ne 0 ] || ! grep -q "^OK ack" <<<"$outp3ack"; then
  echo "FAIL [P3]: ack caminho feliz quebrou — got rc=$rcp3ack: $outp3ack"; p3_fail=1
fi

[ "$p3_fail" -eq 0 ] || { echo "FAIL [P3]: pelo menos um caminho feliz quebrou (ver acima)"; exit 1; }
echo "OK [P3] — 7 caminhos felizes (update, add, raise, send, thread open, thread join, ack) intactos"

# =================================================================================================
# [11] MUTAÇÃO — prova de que a propriedade é sustentada pela linha certa, com controle E
# recontrole. Commit ANTES de mutar é responsabilidade de quem roda o passo 7 do plano; aqui só a
# prova em si.
# =================================================================================================

echo "[11] mutação — pré-condição, mutação (a) e (b), restauração byte a byte, recontrole"

AG="$T/.forge/scripts/lib/arg-guards.sh"
cp "$AG" "$T/arg-guards.orig"
DFOORIG="$T/deferral-ops.orig"
cp "$DFO" "$DFOORIG"

_scn1_rejects() { set +e; local o r; o="$(_lg update LDG-0001 --detail --title 2>&1)"; r=$?; set -e; [ "$r" -ne 0 ] && grep -q -- "--title" <<<"$o"; }
_scn2_rejects() { set +e; local o r; o="$(_lg add --type roadmap --title --detail 2>&1)"; r=$?; set -e; [ "$r" -ne 0 ] && grep -q -- "--detail" <<<"$o"; }
_scn4_rejects() { set +e; local o r; o="$(_dfo raise "$CH" --reason --blocks 2>&1)"; r=$?; set -e; [ "$r" -ne 0 ] && grep -q -- "--blocks" <<<"$o"; }
_scn5_rejects() { set +e; local o r; o="$(_dfo raise "$CH" --reason "x" --blockss archive 2>&1)"; r=$?; set -e; [ "$r" -ne 0 ] && grep -q -- "--blockss" <<<"$o"; }
_scn6_rejects() { set +e; local o r; o="$(_lo send "$CHAN" --thread th-base --kind note --body "b" --subject --requires-ack 2>&1)"; r=$?; set -e; [ "$r" -ne 0 ] && grep -q -- "--requires-ack" <<<"$o"; }
_scn9_rejects() { set +e; local o r; o="$(_lo ack "$CHAN" "$ack_target" --body "b" --subject --reason 2>&1)"; r=$?; set -e; [ "$r" -ne 0 ] && grep -q -- "--reason" <<<"$o"; }

for scn in _scn1_rejects _scn2_rejects _scn4_rejects _scn5_rejects _scn6_rejects _scn9_rejects; do
  "$scn" || { echo "FAIL [11]: pré-condição — $scn não reprova antes da mutação"; exit 1; }
done

# (a) remover a linha de PERTENCIMENTO em lib/arg-guards.sh — o único sítio que decide.
# ARMADILHA MEDIDA NESTE PROGRAMA: os `$` são interpolados pelo PERL tanto no lado de BUSCA quanto
# no de SUBSTITUIÇÃO de um `s///` — sem escapar `\$tok`/`\$value` na busca, o Perl interpola as
# duas variáveis (indefinidas no seu escopo) como string vazia, o padrão vira
# `if [ "" = "" ]; then` e NUNCA casa a linha real do arquivo. `\[` e `\]` também precisam de
# escape (classe de caractere em regex).
perl -0pi -e 's/    if \[ "\$tok" = "\$value" \]; then/    if false; then/' "$AG"
cmp -s "$AG" "$T/arg-guards.orig" && { echo "FAIL [11a]: perl não alterou arg-guards.sh — regex não casou"; exit 1; }

mut_a_bad=0
for scn in _scn1_rejects _scn2_rejects _scn4_rejects _scn6_rejects _scn9_rejects; do
  if "$scn"; then
    echo "FAIL [11a]: $scn AINDA reprova depois de remover o pertencimento — mutação não muta nada"
    mut_a_bad=1
  fi
done
[ "$mut_a_bad" -eq 0 ] || exit 1
# [5] usa uma guarda DIFERENTE (flag desconhecida) — TEM de continuar reprovando com a mutação (a).
_scn5_rejects || { echo "FAIL [11a]: mutação do pertencimento derrubou [5], que é de OUTRA guarda"; exit 1; }

cp "$T/arg-guards.orig" "$AG"
cmp -s "$AG" "$T/arg-guards.orig" || { echo "FAIL [11]: restauração de arg-guards.sh não bateu byte a byte"; exit 1; }
for scn in _scn1_rejects _scn2_rejects _scn4_rejects _scn6_rejects _scn9_rejects; do
  "$scn" || { echo "FAIL [11a]: recontrole — $scn não voltou a reprovar depois da restauração"; exit 1; }
done

# (b) restaurar `*) shift ;;` no `raise` do deferral-ops.sh — só [5] deve voltar (guarda DIFERENTE).
perl -0pi -e 's/\*\)\s*forge_reject_unknown\s+raise[^\n]*\n/*) shift ;;\n/' "$DFO"
cmp -s "$DFO" "$DFOORIG" && { echo "FAIL [11b]: perl não alterou deferral-ops.sh — regex não casou"; exit 1; }

_scn5_rejects && { echo "FAIL [11b]: [5] AINDA reprova depois de restaurar '*) shift ;;' — mutação não muta nada"; exit 1; }
# [4] usa a guarda de PERTENCIMENTO (intacta) — TEM de continuar reprovando com a mutação (b).
_scn4_rejects || { echo "FAIL [11b]: mutação do '*) shift ;;' derrubou [4], que é de OUTRA guarda"; exit 1; }

cp "$DFOORIG" "$DFO"
cmp -s "$DFO" "$DFOORIG" || { echo "FAIL [11]: restauração de deferral-ops.sh não bateu byte a byte"; exit 1; }
_scn5_rejects || { echo "FAIL [11b]: recontrole — [5] não voltou a reprovar depois da restauração"; exit 1; }

echo "OK [11] — duas mutações reintroduziram os defeitos isoladamente; restauração e recontrole OK"

# ── sentinela do repositório real: nada vazou do sandbox ───────────────────────────────────────
REPO_SNAPSHOT_AFTER="$(git -C "$WS" status --porcelain)"
[ "$REPO_SNAPSHOT_BEFORE" = "$REPO_SNAPSHOT_AFTER" ] || {
  echo "FAIL sentinela — a árvore do repositório real mudou durante o gate (o gate só pode escrever em \$T)"
  diff <(echo "$REPO_SNAPSHOT_BEFORE") <(echo "$REPO_SNAPSHOT_AFTER") >&2 || true
  exit 1
}

echo "PASS w201-flag-como-valor"
