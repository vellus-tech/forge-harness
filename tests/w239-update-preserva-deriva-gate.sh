#!/usr/bin/env bash
# Gate W239 — o `forge update` preserva a deriva local de maquinaria própria em vez de sobrescrevê-la (revisão da DH-1 pelo dono em 2026-09-26, depois do ensaio de campo da 0.16.0).
#
# POR QUE ESTE GATE EXISTE. Fora de ENRICHABLE_DIRS (`scripts/`, `hooks/`, `commands/`, `schemas/`, ...), a 0.16.0 sobrescrevia todo arquivo que divergia do template novo e não tinha exceção declarada em `.forge/machinery-exceptions.txt`, nomeando-o como `SOBRESCRITO (não declarado)`. O ensaio de campo da 0.16.0 mediu o custo: cerca de 40 consertos deliberados sobrescritos em cinco consumidores que nunca tinham declarado exceção (azim-crm 7, com a suíte do próprio consumidor reprovando; Axis.PadSimulator 11; axis-device-platform cerca de 20; axis-go-cloud 3; lionclaw 1). O dono revisou a DH-1: quando o `machinery.lock` não prova que o consumidor deixou o arquivo intocado, o update preserva o arquivo, grava a versão nova do template em `.forge/cache/template-pendente/<rel>` e pede reconciliação; `--overwrite-drift` restaura a sobrescrita com backup para quem quer aceitar o template.
#
#   [1]  deriva com lock (sha local != sha do lock): preserva byte a byte, imprime `PRESERVADO (deriva local)`, grava a versão pendente idêntica ao template novo, NÃO avança o lock daquele caminho e imprime o WARN agregado com a contagem e as duas saídas
#   [1b] segundo update sobre o mesmo estado: a deriva continua reconhecida (prova de que o lock não avançou) e o arquivo continua intacto
#   [2]  arquivo intocado (sha local == lock) cujo template evoluiu: `ATUALIZADO`, conteúdo novo, sem versão pendente, lock avança
#   [2b] SEM machinery.lock, arquivo byte-idêntico a uma versão PUBLICADA do template (fixture: o `prevent-secrets-leak.sh` da v0.15.0): o histórico de versões publicadas (`template/machinery-history.json`) prova que está intocado — `ATUALIZADO`, sem pendente, lock avança, e o gancho entregue bloqueia (rc 2) o payload do PreToolUse com chave AWS que o gancho da v0.15.0 deixava passar (rc 0). É o caso de todo consumidor que só rodou `init`, de clone novo e de outra máquina (`.forge/cache/` é ignorado pelo .gitignore gerenciado)
#   [3]  sem machinery.lock e conteúdo local fora de toda versão publicada (não dá para provar que o consumidor não tocou): preserva com a linha própria `PRESERVADO (sem lock para provar)` — distinta de `PRESERVADO (deriva local)`, que exige lock —, pendente gravado, e o lock novo não ganha o sha do template para esse caminho
#   [4]  --overwrite-drift: sobrescreve com backup real e linha `SOBRESCRITO (não declarado)`, sem versão pendente, lock avança
#   [5]  exceção declarada viva sobre arquivo em deriva: comportamento da #131 inalterado (`PRESERVADO (exceção declarada)`), sem linha de deriva e sem pendente — inclusive com --overwrite-drift, que não passa por cima de decisão declarada
#   [6]  --dry-run antecipa exatamente os caminhos preservados por deriva (e a contagem do WARN), sem escrever nada; com --overwrite-drift, antecipa a sobrescrita
#   [7]  doctor lista, numa linha nominal, os arquivos com versão pendente (contagem + caminho) e deixa de listá-los depois da reconciliação; rc do doctor inalterado
#   [8]  fixture REAL: o conserto LDG-0109 do `scripts/lib/yaml-lite.mjs` do azim-crm, com a linha real do `machinery.lock` dele (sha do template rc24) — preservado, pendente gravado, lock mantém o sha anterior
#   [9]  `.md` de maquinaria preservado por deriva (sem lock) com placeholder `<PROJECT_*>` local: o orphan-check de placeholders isenta o caminho preservado (conteúdo do consumidor) — rc 0
#   [10] PBT: para estados gerados (lock ausente/igual/diferente/sem entrada, histórico de versões publicadas ausente/contendo o sha local/sem ele, local editado ou não, template igual ou evoluído, exceção nenhuma/viva/expirada, flag sim/não), o desfecho é função pura do estado: intocado sse (há entrada no lock e ela == sha local) ou (não há entrada e o histórico contém o sha local); o arquivo local fica byte-idêntico sse (local == template novo) ou exceção declarada ou (deriva e não --overwrite-drift); a versão pendente existe sse preservado por deriva; a linha é `deriva local` com entrada no lock e `sem lock para provar` sem ela; o lock daquele caminho só avança quando o arquivo não foi preservado por deriva; e o --dry-run anuncia a deriva sse a aplicação real a preserva
#   [11] reconciliação por exceção declarada: com o sha da versão pendente declarado em machinery-exceptions.txt, o doctor para de cobrar o caminho na hora (sem esperar outro update), e o update seguinte preserva por exceção e REMOVE a versão pendente (o diretório é reconstruído a cada aplicação real)
#   [12] o histórico versionado (`template/machinery-history.json`) cobre toda tag v* alcançável de HEAD — o gerador em modo --check sai rc 0
#
# Isolamento git (LDG-0201 e o incidente de 2026-09-26): nenhum GIT_* herdado chega aos `git init` dos consumidores temporários, e o gate nunca roda `git config`.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$WS/bin/forge.mjs"
TPL="$WS/template/.forge"
FIX="$WS/tests/fixtures/w239"
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w239.XXXXXX")"
trap 'rm -rf "$T"' EXIT

PEND=".forge/cache/template-pendente"
REL="scripts/handoff-gen.sh"

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
lock_sha() {  # lock_sha <consumidor> <rel> -> sha registrado no lock para o caminho, ou vazio
  local f="$1/.forge/cache/machinery.lock"
  [ -f "$f" ] || return 0
  awk -v r="$2" '!/^#/ && $2 == r { print $1; exit }' "$f"
}

consumidor() {  # consumidor <nome> -> ecoa <dir>, com .forge instalado do template real (sem lock)
  local d="$T/$1"
  mkdir -p "$d"
  git -C "$d" init -q || { echo "FAIL (setup): git init falhou para $1"; exit 1; }
  node "$FORGE" init --target "$d" --slug demo --name Demo --desc t --yes --no-plugin >"$d.init.log" 2>&1 \
    || { echo "FAIL (setup): init falhou para $1"; cat "$d.init.log"; exit 1; }
  printf '%s\n' "$d"
}

upd() {  # upd <consumidor> <source> [flags...] -> saída combinada; rc em $UPD_RC
  local c="$1" s="$2"; shift 2
  UPD_OUT="$(node "$FORGE" update --target "$c" --no-plugin --source "$s" "$@" 2>&1)"; UPD_RC=$?
}

# Template "evoluído": cópia do template real com uma mudança em $REL (a versão nova do harness).
TPLN="$T/tpl-novo"
cp -R "$TPL" "$TPLN"
printf '\n# MUDANCA-DO-TEMPLATE-w239\n' >> "$TPLN/$REL"
cmp -s "$TPL/$REL" "$TPLN/$REL" && { echo "FAIL (setup): o template evoluído não difere do real"; exit 1; }
SHA_TPL="$(sha "$TPL/$REL")"
SHA_TPLN="$(sha "$TPLN/$REL")"

# Consumidor com lock gravado (update de preparo contra o template real) e conserto local em $REL.
com_lock_e_deriva() {  # com_lock_e_deriva <nome> -> ecoa <dir>
  local d; d="$(consumidor "$1")"
  node "$FORGE" update --target "$d" --no-plugin --no-backup --source "$TPL" >"$d.prep.log" 2>&1 \
    || { echo "FAIL (setup): update de preparo falhou para $1"; cat "$d.prep.log"; exit 1; }
  [ "$(lock_sha "$d" "$REL")" = "$SHA_TPL" ] || { echo "FAIL (setup): lock de preparo não registra o sha do template para $REL"; exit 1; }
  printf '\n# CONSERTO-LOCAL-w239-%s\n' "$1" >> "$d/.forge/$REL"
  printf '%s\n' "$d"
}

echo "[1] deriva com lock: preserva, grava pendente, não avança o lock, WARN agregado"
C1="$(com_lock_e_deriva c1)"
cp "$C1/.forge/$REL" "$T/c1-antes"
upd "$C1" "$TPLN" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [1]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C1/.forge/$REL" "$T/c1-antes" || { echo "FAIL [1]: conserto local em deriva foi sobrescrito — deveria ter sido preservado byte a byte"; echo "$UPD_OUT"; exit 1; }
grep -qxF "PRESERVADO (deriva local): $REL — versão nova do template em $PEND/$REL" <<<"$UPD_OUT" \
  || { echo "FAIL [1]: linha 'PRESERVADO (deriva local)' ausente para $REL"; echo "$UPD_OUT"; exit 1; }
[ -f "$C1/$PEND/$REL" ] || { echo "FAIL [1]: versão pendente não foi gravada em $PEND/$REL"; exit 1; }
cmp -s "$C1/$PEND/$REL" "$TPLN/$REL" || { echo "FAIL [1]: versão pendente difere do template novo"; exit 1; }
[ "$(lock_sha "$C1" "$REL")" = "$SHA_TPL" ] || { echo "FAIL [1]: o lock avançou para $REL (esperado o sha anterior $SHA_TPL, achei '$(lock_sha "$C1" "$REL")')"; exit 1; }
grep -q "SOBRESCRITO (não declarado): $REL" <<<"$UPD_OUT" && { echo "FAIL [1]: $REL relatado como SOBRESCRITO sem --overwrite-drift"; echo "$UPD_OUT"; exit 1; }
warn1="$(grep '^WARN: 1 arquivo(s) de maquinaria preservado(s) por deriva local' <<<"$UPD_OUT")"
[ -n "$warn1" ] || { echo "FAIL [1]: WARN agregado com a contagem ausente"; echo "$UPD_OUT"; exit 1; }
grep -q 'machinery-exceptions.txt' <<<"$warn1" && grep -q -- '--overwrite-drift' <<<"$warn1" \
  || { echo "FAIL [1]: o WARN agregado não nomeia as duas saídas (declarar exceção / --overwrite-drift)"; echo "$warn1"; exit 1; }
echo "OK [1]"

echo "[1b] segundo update: a deriva continua reconhecida (o lock não avançou)"
upd "$C1" "$TPLN" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [1b]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C1/.forge/$REL" "$T/c1-antes" || { echo "FAIL [1b]: o segundo update sobrescreveu o conserto — a deriva deixou de ser reconhecida"; exit 1; }
grep -qxF "PRESERVADO (deriva local): $REL — versão nova do template em $PEND/$REL" <<<"$UPD_OUT" \
  || { echo "FAIL [1b]: segundo update não reconheceu a deriva"; echo "$UPD_OUT"; exit 1; }
echo "OK [1b]"

echo "[2] arquivo intocado com lock, template evoluiu: ATUALIZADO, sem pendente, lock avança"
C2="$(consumidor c2)"
node "$FORGE" update --target "$C2" --no-plugin --no-backup --source "$TPL" >/dev/null 2>&1
[ "$(lock_sha "$C2" "$REL")" = "$SHA_TPL" ] || { echo "FAIL [2] (setup): lock de preparo ausente"; exit 1; }
upd "$C2" "$TPLN" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [2]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C2/.forge/$REL" "$TPLN/$REL" || { echo "FAIL [2]: arquivo intocado não recebeu o template novo"; exit 1; }
grep -q "^ATUALIZADO: $REL" <<<"$UPD_OUT" || { echo "FAIL [2]: linha ATUALIZADO ausente"; echo "$UPD_OUT"; exit 1; }
grep -q "deriva local" <<<"$UPD_OUT" && { echo "FAIL [2]: arquivo intocado relatado como deriva local"; echo "$UPD_OUT"; exit 1; }
[ ! -e "$C2/$PEND/$REL" ] || { echo "FAIL [2]: versão pendente gravada para arquivo que foi atualizado"; exit 1; }
[ "$(lock_sha "$C2" "$REL")" = "$SHA_TPLN" ] || { echo "FAIL [2]: lock não avançou para o sha do template novo"; exit 1; }
echo "OK [2]"

echo "[2b] sem lock, arquivo idêntico a uma versão publicada (gancho de segredos da v0.15.0): ATUALIZADO pelo histórico, e o gancho novo bloqueia"
REL2B="hooks/pre-tool-use/prevent-secrets-leak.sh"
[ -f "$FIX/prevent-secrets-leak.v0.15.0.sh" ] || { echo "FAIL [2b] (setup): fixture ausente"; exit 1; }
C2B="$(consumidor c2b)"
[ ! -f "$C2B/.forge/cache/machinery.lock" ] || { echo "FAIL [2b] (setup): o consumidor já tem machinery.lock"; exit 1; }
cp "$FIX/prevent-secrets-leak.v0.15.0.sh" "$C2B/.forge/$REL2B"; chmod +x "$C2B/.forge/$REL2B"
cmp -s "$C2B/.forge/$REL2B" "$TPL/$REL2B" && { echo "FAIL [2b] (setup): a fixture da v0.15.0 é idêntica ao template atual"; exit 1; }
# Payload do PreToolUse (contrato stdin-json da #125) com uma chave no formato AWS montada em tempo de execução — nenhum literal de segredo no gate.
k2b="AKIA"; k2b="${k2b}Q7XZ4N2P8LMR6TVW"
payload2b="$(printf '{"tool_name":"Write","tool_input":{"file_path":"src/config.txt","content":"chave=%s"}}' "$k2b")"
printf '%s' "$payload2b" | bash "$C2B/.forge/$REL2B" >/dev/null 2>&1; rc2b_antes=$?
[ "$rc2b_antes" -eq 0 ] || { echo "FAIL [2b] (setup): o gancho da v0.15.0 já bloqueava o payload (rc=$rc2b_antes) — o cenário não prova a entrega"; exit 1; }
upd "$C2B" "$TPL" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [2b]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C2B/.forge/$REL2B" "$TPL/$REL2B" || { echo "FAIL [2b]: arquivo intocado (idêntico à v0.15.0 publicada) foi retido sem lock — a correção do template não chegou"; echo "$UPD_OUT" | grep -E "PRESERVADO|ATUALIZADO|WARN" | head -20; exit 1; }
grep -q "^ATUALIZADO: $REL2B — " <<<"$UPD_OUT" || { echo "FAIL [2b]: linha ATUALIZADO ausente para $REL2B"; echo "$UPD_OUT"; exit 1; }
grep -q "PRESERVADO ([^)]*): $REL2B" <<<"$UPD_OUT" && { echo "FAIL [2b]: $REL2B relatado como preservado"; echo "$UPD_OUT"; exit 1; }
[ ! -e "$C2B/$PEND/$REL2B" ] || { echo "FAIL [2b]: versão pendente gravada para arquivo que foi atualizado"; exit 1; }
[ "$(lock_sha "$C2B" "$REL2B")" = "$(sha "$TPL/$REL2B")" ] || { echo "FAIL [2b]: lock não registrou o sha do template entregue"; exit 1; }
printf '%s' "$payload2b" | bash "$C2B/.forge/$REL2B" >/dev/null 2>&1; rc2b=$?
[ "$rc2b" -eq 2 ] || { echo "FAIL [2b]: o gancho entregue não bloqueou o payload com chave AWS (rc=$rc2b, esperado 2)"; exit 1; }
echo "OK [2b]"

echo "[3] sem lock: preserva, pendente gravado, lock novo sem o sha do template para o caminho"
C3="$(consumidor c3)"
[ ! -f "$C3/.forge/cache/machinery.lock" ] || { echo "FAIL [3] (setup): o consumidor já tem machinery.lock"; exit 1; }
printf '\n# CONSERTO-LOCAL-w239-c3\n' >> "$C3/.forge/$REL"
cp "$C3/.forge/$REL" "$T/c3-antes"
upd "$C3" "$TPL" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [3]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C3/.forge/$REL" "$T/c3-antes" || { echo "FAIL [3]: sem lock, o conserto local foi sobrescrito"; echo "$UPD_OUT"; exit 1; }
grep -qxF "PRESERVADO (sem lock para provar): $REL — o conteúdo local não é nenhuma versão publicada do template; versão nova do template em $PEND/$REL" <<<"$UPD_OUT" \
  || { echo "FAIL [3]: linha 'PRESERVADO (sem lock para provar)' ausente sem lock"; echo "$UPD_OUT"; exit 1; }
grep -q "PRESERVADO (deriva local): $REL" <<<"$UPD_OUT" && { echo "FAIL [3]: sem lock, o caminho foi rotulado como deriva local provada"; echo "$UPD_OUT"; exit 1; }
grep -q '^WARN: 1 arquivo(s) de maquinaria preservado(s) por deriva local (1 sem lock para provar' <<<"$UPD_OUT" \
  || { echo "FAIL [3]: o WARN agregado não separa a contagem sem lock"; echo "$UPD_OUT" | grep '^WARN'; exit 1; }
cmp -s "$C3/$PEND/$REL" "$TPL/$REL" || { echo "FAIL [3]: versão pendente ausente ou diferente do template"; exit 1; }
[ -f "$C3/.forge/cache/machinery.lock" ] || { echo "FAIL [3]: o update não gravou o lock dos demais caminhos"; exit 1; }
[ -z "$(lock_sha "$C3" "$REL")" ] || { echo "FAIL [3]: o lock ganhou entrada para $REL preservado por deriva ($(lock_sha "$C3" "$REL"))"; exit 1; }
[ -n "$(lock_sha "$C3" scripts/doctor.sh)" ] || { echo "FAIL [3]: lock sem entrada para caminho não preservado (controle)"; exit 1; }
echo "OK [3]"

echo "[4] --overwrite-drift: sobrescreve com backup e SOBRESCRITO, sem pendente, lock avança"
C4="$(com_lock_e_deriva c4)"
upd "$C4" "$TPLN" --overwrite-drift
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [4]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C4/.forge/$REL" "$TPLN/$REL" || { echo "FAIL [4]: --overwrite-drift não aplicou o template"; echo "$UPD_OUT"; exit 1; }
linha4="$(grep "^SOBRESCRITO (não declarado): $REL — conteúdo anterior em " <<<"$UPD_OUT")"
[ -n "$linha4" ] || { echo "FAIL [4]: linha SOBRESCRITO ausente"; echo "$UPD_OUT"; exit 1; }
bak4="$(sed -E 's/.*conteúdo anterior em //' <<<"$linha4")"
grep -q 'CONSERTO-LOCAL-w239-c4' "$C4/$bak4" 2>/dev/null || { echo "FAIL [4]: backup nomeado ($bak4) ausente ou sem o conteúdo anterior"; exit 1; }
grep -q 'deriva local' <<<"$UPD_OUT" && { echo "FAIL [4]: --overwrite-drift ainda relatou deriva local"; echo "$UPD_OUT"; exit 1; }
[ ! -e "$C4/$PEND/$REL" ] || { echo "FAIL [4]: versão pendente gravada com --overwrite-drift"; exit 1; }
[ "$(lock_sha "$C4" "$REL")" = "$SHA_TPLN" ] || { echo "FAIL [4]: lock não avançou com --overwrite-drift"; exit 1; }
echo "OK [4]"

echo "[5] exceção declarada sobre arquivo em deriva: comportamento da #131 inalterado, com e sem a flag"
for modo in sem-flag com-flag; do
  C5="$(com_lock_e_deriva "c5-$modo")"
  cp "$C5/.forge/$REL" "$T/c5-antes"
  printf '%s  %s  # conserto deliberado\n' "$SHA_TPLN" "$REL" > "$C5/.forge/machinery-exceptions.txt"
  if [ "$modo" = com-flag ]; then upd "$C5" "$TPLN" --no-backup --overwrite-drift; else upd "$C5" "$TPLN" --no-backup; fi
  [ "$UPD_RC" -eq 0 ] || { echo "FAIL [5] ($modo): update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
  cmp -s "$C5/.forge/$REL" "$T/c5-antes" || { echo "FAIL [5] ($modo): arquivo com exceção viva foi sobrescrito"; exit 1; }
  grep -q "PRESERVADO (exceção declarada): $REL" <<<"$UPD_OUT" || { echo "FAIL [5] ($modo): linha PRESERVADO (exceção declarada) ausente"; echo "$UPD_OUT"; exit 1; }
  grep -q "deriva local" <<<"$UPD_OUT" && { echo "FAIL [5] ($modo): exceção declarada relatada também como deriva local"; echo "$UPD_OUT"; exit 1; }
  [ ! -e "$C5/$PEND/$REL" ] || { echo "FAIL [5] ($modo): versão pendente gravada para caminho com exceção declarada"; exit 1; }
done
echo "OK [5]"

echo "[6] --dry-run antecipa a deriva sem escrever; com --overwrite-drift antecipa a sobrescrita"
C6="$(com_lock_e_deriva c6)"
cp "$C6/.forge/$REL" "$T/c6-antes"; cp "$C6/.forge/cache/machinery.lock" "$T/c6-lock-antes"
upd "$C6" "$TPLN" --dry-run
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [6]: dry-run saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
dry6="$UPD_OUT"
grep -qxF "= $REL (PRESERVADO (deriva local) — versão nova do template iria para $PEND/$REL)" <<<"$dry6" \
  || { echo "FAIL [6]: dry-run não antecipa a preservação por deriva"; echo "$dry6"; exit 1; }
grep -q "^~ $REL" <<<"$dry6" && { echo "FAIL [6]: dry-run anuncia sobrescrita de arquivo que a aplicação preserva"; echo "$dry6"; exit 1; }
cmp -s "$C6/.forge/$REL" "$T/c6-antes" && cmp -s "$C6/.forge/cache/machinery.lock" "$T/c6-lock-antes" && [ ! -e "$C6/$PEND" ] \
  || { echo "FAIL [6]: dry-run escreveu no disco (arquivo, lock ou pendente)"; exit 1; }
upd "$C6" "$TPLN" --dry-run --overwrite-drift
grep -qxF "~ $REL (sobrescrita não declarada — --overwrite-drift)" <<<"$UPD_OUT" \
  || { echo "FAIL [6]: dry-run com --overwrite-drift não antecipa a sobrescrita"; echo "$UPD_OUT"; exit 1; }
upd "$C6" "$TPLN" --no-backup
real6="$UPD_OUT"
pd="$(sed -nE 's/^= (.+) \(PRESERVADO \(deriva local\) — .*$/\1/p' <<<"$dry6" | sort)"
pr="$(sed -nE 's/^PRESERVADO \(deriva local\): (.+) — versão nova do template em .*$/\1/p' <<<"$real6" | sort)"
[ -n "$pr" ] && [ "$pd" = "$pr" ] || { echo "FAIL [6]: caminhos antecipados pelo dry-run ('$pd') diferem dos preservados pela aplicação ('$pr')"; exit 1; }
wd="$(grep -oE '^WARN: [0-9]+ arquivo\(s\) de maquinaria' <<<"$dry6")"; wr="$(grep -oE '^WARN: [0-9]+ arquivo\(s\) de maquinaria' <<<"$real6")"
[ -n "$wd" ] && [ "$wd" = "$wr" ] || { echo "FAIL [6]: contagem do WARN agregado difere entre dry-run ('$wd') e aplicação ('$wr')"; exit 1; }
echo "OK [6]"

echo "[7] doctor lista os pendentes numa linha nominal e para de listar depois da reconciliação"
d7="$(bash "$C1/.forge/scripts/doctor.sh" --report 2>&1)"; rcd7=$?
l7="$(grep 'TEMPLATE-PENDENTE' <<<"$d7")"
grep -q "TEMPLATE-PENDENTE: 1 arquivo(s) com versão nova do template aguardando reconciliação em $PEND/: $REL" <<<"$l7" \
  || { echo "FAIL [7]: doctor não nomeia o pendente com contagem e caminho"; echo "$d7" | tail -40; exit 1; }
cp "$C1/$PEND/$REL" "$C1/.forge/$REL"   # reconciliação: o consumidor aceita a versão pendente
d7b="$(bash "$C1/.forge/scripts/doctor.sh" --report 2>&1)"; rcd7b=$?
grep -q 'TEMPLATE-PENDENTE' <<<"$d7b" && { echo "FAIL [7]: doctor continua listando pendente já reconciliado"; grep 'TEMPLATE-PENDENTE' <<<"$d7b"; exit 1; }
[ "$rcd7" -eq "$rcd7b" ] || { echo "FAIL [7]: a linha de pendentes mudou o rc do doctor ($rcd7 com pendente, $rcd7b sem)"; exit 1; }
echo "OK [7]"

echo "[8] fixture real do azim-crm (conserto LDG-0109 em scripts/lib/yaml-lite.mjs) com a linha real do lock"
[ -f "$FIX/yaml-lite.mjs" ] && [ -f "$FIX/machinery.lock" ] || { echo "FAIL [8] (setup): fixtures ausentes em $FIX"; exit 1; }
REL8="scripts/lib/yaml-lite.mjs"
C8="$(consumidor c8)"
mkdir -p "$C8/.forge/cache"
cp "$FIX/machinery.lock" "$C8/.forge/cache/machinery.lock"
cp "$FIX/yaml-lite.mjs" "$C8/.forge/$REL8"
LOCK8="$(lock_sha "$C8" "$REL8")"
[ -n "$LOCK8" ] && [ "$LOCK8" != "$(sha "$FIX/yaml-lite.mjs")" ] && [ "$LOCK8" != "$(sha "$TPL/$REL8")" ] \
  || { echo "FAIL [8] (setup): a fixture não representa deriva (lock=$LOCK8)"; exit 1; }
upd "$C8" "$TPL" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [8]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C8/.forge/$REL8" "$FIX/yaml-lite.mjs" || { echo "FAIL [8]: o conserto real do azim-crm foi sobrescrito"; echo "$UPD_OUT"; exit 1; }
grep -qxF "PRESERVADO (deriva local): $REL8 — versão nova do template em $PEND/$REL8" <<<"$UPD_OUT" \
  || { echo "FAIL [8]: linha 'PRESERVADO (deriva local)' ausente para a fixture real"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C8/$PEND/$REL8" "$TPL/$REL8" || { echo "FAIL [8]: versão pendente ausente ou diferente do template"; exit 1; }
[ "$(lock_sha "$C8" "$REL8")" = "$LOCK8" ] || { echo "FAIL [8]: o lock avançou para a fixture real"; exit 1; }
echo "OK [8]"

echo "[9] .md de maquinaria em deriva com <PROJECT_*> local: orphan-check isenta, rc 0"
C9="$(consumidor c9)"
REL9="commands/harness/upgrade.md"
printf '\n<PROJECT_SLUG> — nota local com placeholder não substituído de propósito\n' >> "$C9/.forge/$REL9"
cp "$C9/.forge/$REL9" "$T/c9-antes"
upd "$C9" "$TPL" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [9]: update saiu rc=$UPD_RC (o orphan-check contou conteúdo preservado do consumidor)"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C9/.forge/$REL9" "$T/c9-antes" || { echo "FAIL [9]: .md em deriva foi sobrescrito"; exit 1; }
grep -qxF "PRESERVADO (sem lock para provar): $REL9 — o conteúdo local não é nenhuma versão publicada do template; versão nova do template em $PEND/$REL9" <<<"$UPD_OUT" \
  || { echo "FAIL [9]: linha de deriva ausente"; echo "$UPD_OUT"; exit 1; }
echo "OK [9]"

# [11] e [12] rodam antes da propriedade [10], que é a parte cara do gate: uma regressão nos cenários determinísticos reprova em segundos, sem esperar os 50 casos.
echo "[11] reconciliação por exceção: o doctor para de cobrar na hora e o update seguinte remove o pendente"
C11="$(com_lock_e_deriva c11)"
cp "$C11/.forge/$REL" "$T/c11-antes"
upd "$C11" "$TPLN" --no-backup
[ "$UPD_RC" -eq 0 ] && [ -f "$C11/$PEND/$REL" ] || { echo "FAIL [11] (setup): o update de preparo não gravou o pendente (rc=$UPD_RC)"; echo "$UPD_OUT"; exit 1; }
# A saída (1) recomendada: declarar a exceção com o sha da versão pendente, com o prefixo .forge/ que o parser normaliza.
printf '%s  .forge/%s  # conserto deliberado do consumidor\n' "$(sha "$C11/$PEND/$REL")" "$REL" > "$C11/.forge/machinery-exceptions.txt"
d11="$(bash "$C11/.forge/scripts/doctor.sh" --report 2>&1)"
grep -q 'TEMPLATE-PENDENTE' <<<"$d11" && { echo "FAIL [11]: doctor ainda cobra caminho com exceção declarada (antes do próximo update)"; grep 'TEMPLATE-PENDENTE' <<<"$d11"; exit 1; }
upd "$C11" "$TPLN" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [11]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
cmp -s "$C11/.forge/$REL" "$T/c11-antes" || { echo "FAIL [11]: o conserto com exceção declarada foi sobrescrito"; exit 1; }
grep -q "PRESERVADO (exceção declarada): $REL" <<<"$UPD_OUT" || { echo "FAIL [11]: linha PRESERVADO (exceção declarada) ausente"; echo "$UPD_OUT"; exit 1; }
[ ! -e "$C11/$PEND/$REL" ] || { echo "FAIL [11]: a versão pendente de caminho reconciliado continua em $PEND/$REL depois do update — o diretório não foi reconstruído"; exit 1; }
d11b="$(bash "$C11/.forge/scripts/doctor.sh" --report 2>&1)"
grep -q 'TEMPLATE-PENDENTE' <<<"$d11b" && { echo "FAIL [11]: doctor ainda cobra pendente depois do update"; exit 1; }
echo "OK [11]"

echo "[12] o histórico versionado cobre toda tag v* alcançável de HEAD"
[ -f "$WS/template/machinery-history.json" ] || { echo "FAIL [12]: template/machinery-history.json ausente"; exit 1; }
out12="$(cd "$WS" && node tools/build-machinery-history.mjs --check 2>&1)"; rc12=$?
[ "$rc12" -eq 0 ] || { echo "FAIL [12]: histórico defasado (rc=$rc12)"; echo "$out12"; exit 1; }
echo "OK [12]"

echo "[10] PBT: o desfecho é função pura do estado gerado"
node --input-type=module - "$WS" "$T" <<'NODE_EOF'
import { join, dirname } from 'node:path';
import { pathToFileURL } from 'node:url';
import { mkdtempSync, rmSync, cpSync, writeFileSync, readFileSync, existsSync, mkdirSync, appendFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const [WS, T] = process.argv.slice(2);
const P = await import(pathToFileURL(join(WS, 'template/.forge/scripts/lib/pbt.mjs')).href);
const FORGE = join(WS, 'bin/forge.mjs');
const TPL = join(WS, 'template/.forge');
const REL = 'scripts/handoff-gen.sh';
const PEND_REL = join('.forge/cache/template-pendente', REL);
const sha = (buf) => createHash('sha256').update(buf).digest('hex');
const shaF = (p) => sha(readFileSync(p));
const env = { ...process.env };
for (const k of ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY']) delete env[k];

// Dois templates preparados uma vez, ambos cópias fora do repositório (para que o histórico de versões publicadas ao lado de cada um, `<src>/../machinery-history.json`, seja controlado pelo gerador de estados): o real e um evoluído só em REL.
const TPLA = join(T, 'pbt-src-a', '.forge');
const TPLE = join(T, 'pbt-src-e', '.forge');
cpSync(TPL, TPLA, { recursive: true });
cpSync(TPL, TPLE, { recursive: true });
appendFileSync(join(TPLE, REL), '\n# MUDANCA-DO-TEMPLATE-PBT-w239\n');

// Consumidor pristine (init real, sem lock); cada caso parte de uma cópia.
const pristine = join(T, 'pbt-pristine');
mkdirSync(pristine, { recursive: true });
execFileSync('git', ['init', '-q', pristine], { env });
execFileSync('node', [FORGE, 'init', '--target', pristine, '--slug', 'demo', '--name', 'Demo', '--desc', 't', '--yes', '--no-plugin'], { env, stdio: 'ignore' });
const base = readFileSync(join(pristine, '.forge', REL));

const gen = P.gen.record({
  lock: P.gen.oneOf(['ausente', 'igual', 'diferente', 'sem-entrada']),
  hist: P.gen.oneOf(['ausente', 'contem-local', 'sem-local']),
  localEdit: P.gen.bool(),
  tplEvolve: P.gen.bool(),
  exc: P.gen.oneOf(['nenhuma', 'viva', 'expirada']),
  flag: P.gen.bool(),
});

const run = (args) => {
  try { return { rc: 0, out: execFileSync('node', [FORGE, ...args], { env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }) }; }
  catch (e) { return { rc: e.status ?? 1, out: (e.stdout || '') + (e.stderr || '') }; }
};
const lockEntry = (dir) => {
  const p = join(dir, '.forge/cache/machinery.lock');
  if (!existsSync(p)) return null;
  for (const l of readFileSync(p, 'utf8').split('\n')) { const m = /^([0-9a-f]{64})  (.+)$/.exec(l); if (m && m[2] === REL) return m[1]; }
  return null;
};

let casos = 0;
const prop = (s) => {
  casos++;
  const dir = mkdtempSync(join(T, 'pbt-caso-'));
  rmSync(dir, { recursive: true, force: true });
  cpSync(pristine, dir, { recursive: true });
  const src = s.tplEvolve ? TPLE : TPLA;
  const tplBuf = readFileSync(join(src, REL));
  const localBuf = s.localEdit ? Buffer.concat([base, Buffer.from(`\n# CONSERTO-PBT-${casos}\n`)]) : base;
  writeFileSync(join(dir, '.forge', REL), localBuf);
  const localSha = sha(localBuf), tplSha = sha(tplBuf);
  // Lock: ausente; igual ao sha local; diferente do local (outro sha qualquer, 64 hex); ou o
  // arquivo existe sem entrada para REL (só outra linha).
  mkdirSync(join(dir, '.forge/cache'), { recursive: true });
  const outra = `${'b'.repeat(64)}  scripts/doctor.sh`;
  const diffSha = (localSha[0] === 'c' ? 'd' : 'c') + localSha.slice(1);
  if (s.lock === 'igual') writeFileSync(join(dir, '.forge/cache/machinery.lock'), `# lock\n${localSha}  ${REL}\n`);
  if (s.lock === 'diferente') writeFileSync(join(dir, '.forge/cache/machinery.lock'), `# lock\n${diffSha}  ${REL}\n`);
  if (s.lock === 'sem-entrada') writeFileSync(join(dir, '.forge/cache/machinery.lock'), `# lock\n${outra}\n`);
  const lockAntes = lockEntry(dir);
  // Histórico de versões publicadas ao lado do template usado neste caso: ausente; contendo o sha local (o arquivo é uma versão publicada); ou só com outro sha.
  const histPath = join(dirname(src), 'machinery-history.json');
  rmSync(histPath, { force: true });
  const outroSha = 'f'.repeat(64);
  if (s.hist !== 'ausente') {
    const shas = s.hist === 'contem-local' ? [localSha, outroSha].sort() : [outroSha];
    writeFileSync(histPath, JSON.stringify({ schema: 'forge-machinery-history/v1', versions: ['v0.0.1'], paths: { [REL]: shas } }) + '\n');
  }
  if (s.exc !== 'nenhuma') {
    const declared = s.exc === 'viva' ? tplSha : (tplSha[0] === '0' ? '1' : '0') + tplSha.slice(1);
    writeFileSync(join(dir, '.forge/machinery-exceptions.txt'), `${declared}  ${REL}  # pbt\n`);
  }
  const flags = s.flag ? ['--overwrite-drift'] : [];

  // Oráculo, escrito a partir do desenho e não do código.
  const differs = localSha !== tplSha;
  const excCobre = differs && s.exc !== 'nenhuma';
  const temEntrada = s.lock === 'igual' || s.lock === 'diferente';
  const intocado = temEntrada ? s.lock === 'igual' : s.hist === 'contem-local';
  const deriva = differs && !excCobre && !intocado;
  const esperaIntacto = !differs || excCobre || (deriva && !s.flag);
  const esperaPendente = deriva && !s.flag;

  const dry = run(['update', '--target', dir, '--no-plugin', '--source', src, '--dry-run', ...flags]);
  const real = run(['update', '--target', dir, '--no-plugin', '--no-backup', '--source', src, ...flags]);
  const agora = readFileSync(join(dir, '.forge', REL));
  const intacto = sha(agora) === localSha;
  const pendente = existsSync(join(dir, PEND_REL));
  const lockDepois = lockEntry(dir);
  const rotulo = temEntrada ? 'deriva local' : 'sem lock para provar';
  const outroRotulo = temEntrada ? 'sem lock para provar' : 'deriva local';
  const dryDeriva = dry.out.includes(`= ${REL} (PRESERVADO (${rotulo}) — versão nova do template iria para ${PEND_REL})`);
  const realDeriva = real.out.split('\n').some((l) => l.startsWith(`PRESERVADO (${rotulo}): ${REL} — `) && l.endsWith(`versão nova do template em ${PEND_REL}`));
  if (dry.out.includes(`(PRESERVADO (${outroRotulo})`) || real.out.includes(`PRESERVADO (${outroRotulo}): ${REL}`)) { rmSync(dir, { recursive: true, force: true }); console.error(`  caso ${casos} ${JSON.stringify(s)}: rótulo trocado (esperado '${rotulo}')`); return false; }

  const falhas = [];
  if (dry.rc !== 0 || real.rc !== 0) falhas.push(`rc dry=${dry.rc} real=${real.rc}`);
  if (intacto !== esperaIntacto) falhas.push(`intacto=${intacto} esperado=${esperaIntacto}`);
  if (!intacto && sha(agora) !== tplSha) falhas.push('sobrescrito com conteúdo que não é o template');
  if (pendente !== esperaPendente) falhas.push(`pendente=${pendente} esperado=${esperaPendente}`);
  if (pendente && shaF(join(dir, PEND_REL)) !== tplSha) falhas.push('pendente difere do template');
  if (realDeriva !== esperaPendente) falhas.push(`linha de deriva=${realDeriva} esperado=${esperaPendente}`);
  if (dryDeriva !== esperaPendente) falhas.push(`dry-run anunciou deriva=${dryDeriva} esperado=${esperaPendente}`);
  const lockEsperado = esperaPendente ? lockAntes : tplSha;
  if (lockDepois !== lockEsperado) falhas.push(`lock=${lockDepois} esperado=${lockEsperado}`);
  rmSync(dir, { recursive: true, force: true });
  if (falhas.length) { console.error(`  caso ${casos} ${JSON.stringify(s)}: ${falhas.join('; ')}`); return false; }
  return true;
};

const SEED = 239260926;
const r = P.forAll([gen], prop, { runs: 50, seed: SEED });
if (!r.ok) {
  console.error(`FAIL [10]: propriedade falhou após ${r.runs} caso(s) (seed ${r.seed})`);
  console.error('  contraexemplo minimizado: ' + JSON.stringify(r.counterexample));
  if (r.error) console.error('  erro: ' + r.error);
  process.exit(1);
}
if (casos < 50) { console.error(`FAIL [10]: rodou só ${casos} caso(s), esperado >= 50`); process.exit(1); }
console.log(`OK [10] (${r.runs} casos, seed ${r.seed})`);
NODE_EOF
rc10=$?
[ "$rc10" -eq 0 ] || { echo "FAIL [10]: PBT reprovou (ver saída acima)"; exit 1; }

echo "PASS w239-update-preserva-deriva-gate"
