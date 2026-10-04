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
#   [10] PBT: para estados gerados (lock ausente/igual/diferente/sem entrada, histórico de versões publicadas ausente/contendo o sha local/sem ele, local editado ou não, template igual ou evoluído, exceção nenhuma/viva/expirada, flag sim/não, e uma dimensão de sequência: reconciliar à mão copiando a versão pendente e atualizar de novo para um template evoluído), o desfecho é função pura do estado: intocado sse (há entrada no lock e ela == sha local) ou o histórico contém o sha local; o arquivo local fica byte-idêntico sse (local == template novo) ou exceção declarada ou (deriva e não --overwrite-drift); a versão pendente existe sse preservado por deriva; a linha é `deriva local` com entrada no lock e `sem lock para provar` sem ela; o lock daquele caminho só avança quando o arquivo não foi preservado por deriva; e o --dry-run anuncia a deriva sse a aplicação real a preserva; na sequência, o arquivo reconciliado à mão é `ATUALIZADO` pelo update seguinte (sem pendente, lock no sha do template novo), e o --dry-run antecipa isso (50 estados uniformes com a semente 239260926 e 25 no recorte que força a sequência, semente 239260927, com piso de 5 sequências medidas)
#   [11] reconciliação por exceção declarada: com o sha da versão pendente declarado em machinery-exceptions.txt, o doctor para de cobrar o caminho na hora (sem esperar outro update), e o update seguinte preserva por exceção e REMOVE a versão pendente (o diretório é reconstruído a cada aplicação real)
#   [12] o histórico versionado (`template/machinery-history.json`) cobre toda tag v* alcançável de HEAD — o gerador em modo --check sai rc 0. Pré-requisito de ambiente: as tags v* (o CI clona com fetch-depth: 0). Num clone raso ou feito com --no-tags o [12] não é medido: imprime `UNV [12]` e o gate termina rc 127 (dependência ausente, que o run-all classifica como não verificado) depois de rodar todos os outros cenários — nunca PASS sem medir, nunca FAIL por defeito que não existe
#   [13] reconciliação à mão (saída 2 do /forge:upgrade): o consumidor copia a versão pendente sobre o arquivo; o update seguinte, para um template que evoluiu de novo, reconhece o arquivo como uma versão que o próprio template entregou — `ATUALIZADO`, conteúdo novo, sem pendente e lock avançado —, em vez de retê-lo como `PRESERVADO (deriva local)` a cada release
#   [14] lock defasado por checkout (`.forge/cache/` é ignorado e `.forge/` é versionado: update feito em outra worktree ou por um colega chega por pull): a entrada do lock registra uma versão publicada mais antiga e o arquivo local é byte-idêntico a uma versão publicada posterior — `ATUALIZADO` pelo histórico, nunca `deriva local`
#   [15] sem lock, com e sem histórico de versões publicadas ao lado do template: a linha `PRESERVADO (sem lock para provar)` e o WARN agregado só afirmam "não é nenhuma versão publicada" quando havia histórico para consultar; sem histórico, dizem "sem histórico de versões publicadas para provar". Com mutação: uma cópia do forge.mjs cujo driftVerdict ignora a ausência do histórico reprova o caso sem histórico e continua aprovando o caso com histórico; controle e recontrole com o forge.mjs real
#
# Isolamento git (LDG-0201 e o incidente de 2026-09-26): nenhum GIT_* herdado chega aos `git init` dos consumidores temporários, e o gate nunca roda `git config`.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

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
  UPD_OUT="$(node "$FORGE" update --target "$c" --no-plugin --skip-postcheck --source "$s" "$@" 2>&1)"; UPD_RC=$?
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
  node "$FORGE" update --target "$d" --no-plugin --skip-postcheck --no-backup --source "$TPL" >"$d.prep.log" 2>&1 \
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
node "$FORGE" update --target "$C2" --no-plugin --skip-postcheck --no-backup --source "$TPL" >/dev/null 2>&1
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

# [11] a [15] rodam antes da propriedade [10], que é a parte cara do gate: uma regressão nos cenários determinísticos reprova em segundos, sem esperar os 50 casos.
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
UNV12=0
if [ -z "$(git -C "$WS" tag --merged HEAD -l 'v*' 2>/dev/null | head -1)" ]; then
  # Falta de tags é ambiente (clone raso ou --no-tags), não defeito do histórico: o gate segue para os demais cenários e termina rc 127 no fim.
  echo "UNV [12]: nenhuma tag v* alcançável de HEAD neste clone (raso ou feito com --no-tags) — rode 'git fetch --tags' para medir; o histórico versionado não foi conferido"
  UNV12=1
else
  out12="$(cd "$WS" && node tools/build-machinery-history.mjs --check 2>&1)"; rc12=$?
  [ "$rc12" -eq 0 ] || { echo "FAIL [12]: histórico defasado (rc=$rc12)"; echo "$out12"; exit 1; }
  echo "OK [12]"
fi

echo "[13] reconciliação à mão (cópia da versão pendente) e update seguinte para o template evoluído: ATUALIZADO, sem pendente, lock avança"
C13="$(com_lock_e_deriva c13)"
upd "$C13" "$TPLN" --no-backup
[ "$UPD_RC" -eq 0 ] && [ -f "$C13/$PEND/$REL" ] || { echo "FAIL [13] (setup): o update de preparo não gravou o pendente (rc=$UPD_RC)"; echo "$UPD_OUT"; exit 1; }
cp "$C13/$PEND/$REL" "$C13/.forge/$REL"   # saída (2) do /forge:upgrade: o template já cobre o conserto; o resultado é igual à versão pendente
# Template da versão seguinte: evoluiu de novo em $REL. Sem machinery-history.json ao lado ($T), para que a prova venha só da versão pendente guardada pelo update anterior.
TPLC="$T/tpl-c"
cp -R "$TPLN" "$TPLC"
printf '\n# EVOL-C-w239\n' >> "$TPLC/$REL"
[ ! -e "$T/machinery-history.json" ] || { echo "FAIL [13] (setup): há histórico ao lado do template evoluído"; exit 1; }
upd "$C13" "$TPLC" --dry-run
grep -qxF "~ $REL (o template evoluiu — arquivo intocado, idêntico à versão pendente que o update anterior guardou)" <<<"$UPD_OUT" \
  || { echo "FAIL [13]: o dry-run não antecipa a atualização do arquivo reconciliado"; echo "$UPD_OUT" | grep -F "$REL"; exit 1; }
upd "$C13" "$TPLC" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [13]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
grep -q "PRESERVADO ([^)]*): $REL" <<<"$UPD_OUT" && { echo "FAIL [13]: arquivo reconciliado à mão (igual à versão pendente) retido de novo como deriva — a correção do template não chega"; echo "$UPD_OUT" | grep -F "$REL"; exit 1; }
cmp -s "$C13/.forge/$REL" "$TPLC/$REL" || { echo "FAIL [13]: o arquivo reconciliado não recebeu o template evoluído"; exit 1; }
grep -q "^ATUALIZADO: $REL — " <<<"$UPD_OUT" || { echo "FAIL [13]: linha ATUALIZADO ausente para o arquivo reconciliado"; echo "$UPD_OUT"; exit 1; }
[ ! -e "$C13/$PEND/$REL" ] || { echo "FAIL [13]: versão pendente continua gravada depois da atualização"; exit 1; }
[ "$(lock_sha "$C13" "$REL")" = "$(sha "$TPLC/$REL")" ] || { echo "FAIL [13]: o lock não avançou para o sha do template entregue"; exit 1; }
echo "OK [13]"

echo "[14] lock defasado por checkout: entrada do lock de uma versão publicada anterior, local idêntico a uma versão publicada posterior — ATUALIZADO pelo histórico"
# Três versões publicadas de $REL: A (o template real), B (A + uma linha) e a atual C (B + outra linha). O histórico ao lado do template C registra A e B.
SRC14="$T/src14"
mkdir -p "$SRC14"
cp -R "$TPLN" "$SRC14/.forge"
printf '\n# EVOL-14-w239\n' >> "$SRC14/.forge/$REL"
printf '{"schema":"forge-machinery-history/v1","versions":["v9.0.0","v9.1.0"],"paths":{"%s":["%s","%s"]}}\n' "$REL" "$SHA_TPL" "$SHA_TPLN" > "$SRC14/machinery-history.json"
C14="$(consumidor c14)"
node "$FORGE" update --target "$C14" --no-plugin --skip-postcheck --no-backup --source "$TPL" >"$C14.prep.log" 2>&1 || { echo "FAIL [14] (setup): update de preparo falhou"; exit 1; }
[ "$(lock_sha "$C14" "$REL")" = "$SHA_TPL" ] || { echo "FAIL [14] (setup): lock de preparo não registra a versão A"; exit 1; }
cp "$TPLN/$REL" "$C14/.forge/$REL"   # o pull trouxe a versão B, entregue pelo update feito em outra worktree; o lock deste checkout ficou em A
upd "$C14" "$SRC14/.forge" --dry-run
grep -qxF "~ $REL (o template evoluiu — arquivo intocado, idêntico a uma versão publicada)" <<<"$UPD_OUT" \
  || { echo "FAIL [14]: o dry-run não antecipa a atualização do arquivo idêntico a uma versão publicada"; echo "$UPD_OUT" | grep -F "$REL"; exit 1; }
upd "$C14" "$SRC14/.forge" --no-backup
[ "$UPD_RC" -eq 0 ] || { echo "FAIL [14]: update saiu rc=$UPD_RC"; echo "$UPD_OUT"; exit 1; }
grep -q "PRESERVADO ([^)]*): $REL" <<<"$UPD_OUT" && { echo "FAIL [14]: arquivo idêntico a uma versão publicada rotulado como deriva local por causa do lock defasado"; echo "$UPD_OUT" | grep -F "$REL"; exit 1; }
cmp -s "$C14/.forge/$REL" "$SRC14/.forge/$REL" || { echo "FAIL [14]: o arquivo não recebeu a versão atual do template"; exit 1; }
grep -q "^ATUALIZADO: $REL — sem edição local (idêntico a uma versão publicada do template)" <<<"$UPD_OUT" || { echo "FAIL [14]: linha ATUALIZADO pelo histórico ausente"; echo "$UPD_OUT" | grep -F "$REL"; exit 1; }
[ ! -e "$C14/$PEND/$REL" ] || { echo "FAIL [14]: versão pendente gravada para arquivo atualizado"; exit 1; }
[ "$(lock_sha "$C14" "$REL")" = "$(sha "$SRC14/.forge/$REL")" ] || { echo "FAIL [14]: o lock não avançou"; exit 1; }
echo "OK [14]"

echo "[15] sem lock, com e sem histórico: o texto da linha 'sem lock para provar' só afirma o que pôde consultar (com mutação)"
[ -f "$WS/template/machinery-history.json" ] || { echo "FAIL [15] (setup): template/machinery-history.json ausente — o caso com histórico não seria medido"; exit 1; }
# Fonte sem histórico: cópia do template real fora do repositório, sem machinery-history.json ao lado.
SRC15="$T/src15"
mkdir -p "$SRC15"
cp -R "$TPL" "$SRC15/.forge"
[ ! -e "$SRC15/machinery-history.json" ] || { echo "FAIL [15] (setup): há histórico ao lado da fonte sem histórico"; exit 1; }
# Fonte com histórico VAZIO ({} — LOW-1): o arquivo existe, mas sem nenhum path registrado. Conta
# como ausência de histórico (mesma linha/WARN do caso "sem"), nunca como prova de nada — um Map
# vazio não é diferente de não ter consultado nada.
SRC15B="$T/src15b"
mkdir -p "$SRC15B"
cp -R "$TPL" "$SRC15B/.forge"
printf '{}\n' > "$SRC15B/machinery-history.json"
LINHA15_COM="PRESERVADO (sem lock para provar): $REL — o conteúdo local não é nenhuma versão publicada do template; versão nova do template em $PEND/$REL"
LINHA15_SEM="PRESERVADO (sem lock para provar): $REL — sem histórico de versões publicadas para provar; versão nova do template em $PEND/$REL"
WARN15_COM='(1 sem lock para provar que estava(m) intocado(s): conteúdo fora de toda versão publicada do template)'
WARN15_SEM='(1 sem lock para provar que estava(m) intocado(s): sem histórico de versões publicadas para provar)'
N15=0
confere15() {  # confere15 <forge.mjs> <com|sem|vazio> -> rc 0 se a linha e o WARN (aplicação real E --dry-run) do caso batem e os do outro caso não aparecem; motivo em $MOTIVO15
  local bin="$1" caso="$2" src linha outra warn outrowarn c out cdry outdry warnline
  N15=$((N15 + 1))
  case "$caso" in
    com)   src="$TPL";          linha="$LINHA15_COM"; outra="$LINHA15_SEM"; warn="$WARN15_COM"; outrowarn="$WARN15_SEM" ;;
    sem)   src="$SRC15/.forge";  linha="$LINHA15_SEM"; outra="$LINHA15_COM"; warn="$WARN15_SEM"; outrowarn="$WARN15_COM" ;;
    vazio) src="$SRC15B/.forge"; linha="$LINHA15_SEM"; outra="$LINHA15_COM"; warn="$WARN15_SEM"; outrowarn="$WARN15_COM" ;;
    *) MOTIVO15="caso desconhecido: $caso"; return 1 ;;
  esac
  c="$(consumidor "c15-$N15")"
  [ ! -f "$c/.forge/cache/machinery.lock" ] || { MOTIVO15="(setup) o consumidor já tem machinery.lock"; return 1; }
  printf '\n# CONSERTO-LOCAL-w239-c15-%s\n' "$N15" >> "$c/.forge/$REL"
  out="$(node "$bin" update --target "$c" --no-plugin --skip-postcheck --no-backup --source "$src" 2>&1)" || { MOTIVO15="update saiu rc≠0: $(tail -3 <<<"$out")"; return 1; }
  grep -qxF "$linha" <<<"$out" || { MOTIVO15="linha esperada ausente ($caso histórico): $linha | obtido: $(grep -F "): $REL" <<<"$out")"; return 1; }
  grep -qF "$outra" <<<"$out" && { MOTIVO15="linha do outro caso presente ($caso histórico)"; return 1; }
  warnline="$(grep '^WARN: 1 arquivo(s) de maquinaria preservado(s)' <<<"$out" || true)"
  grep -qF "$warn" <<<"$warnline" || { MOTIVO15="WARN agregado sem o texto esperado ($caso histórico): $warnline"; return 1; }
  grep -qF "$outrowarn" <<<"$out" && { MOTIVO15="WARN do outro caso presente ($caso histórico)"; return 1; }
  # LOW-2: o --dry-run agregado precisa afirmar o MESMO texto (com/sem histórico) que a aplicação
  # real — num consumidor SEPARADO (o --dry-run não escreve; reaproveitar o de cima já teria o
  # pendente e o lock da rodada real, o que não é o que este bloco mede).
  N15=$((N15 + 1))
  cdry="$(consumidor "c15-$N15")"
  [ ! -f "$cdry/.forge/cache/machinery.lock" ] || { MOTIVO15="(setup --dry-run) o consumidor já tem machinery.lock"; return 1; }
  printf '\n# CONSERTO-LOCAL-w239-c15-%s\n' "$N15" >> "$cdry/.forge/$REL"
  outdry="$(node "$bin" update --target "$cdry" --no-plugin --no-backup --source "$src" --dry-run 2>&1)" || { MOTIVO15="--dry-run saiu rc≠0: $(tail -3 <<<"$outdry")"; return 1; }
  warnline="$(grep '^WARN: 1 arquivo(s) de maquinaria seriam preservado(s)' <<<"$outdry" || true)"
  grep -qF "$warn" <<<"$warnline" \
    || { MOTIVO15="WARN do --dry-run sem o texto esperado ($caso histórico): $warnline"; return 1; }
  grep -qF "$outrowarn" <<<"$outdry" && { MOTIVO15="WARN do --dry-run do outro caso presente ($caso histórico)"; return 1; }
  return 0
}
# Controle: o forge.mjs real acerta os três casos (com, sem, e sem-por-histórico-vazio).
confere15 "$FORGE" com || { echo "FAIL [15] (controle, com histórico): $MOTIVO15"; exit 1; }
confere15 "$FORGE" sem || { echo "FAIL [15] (controle, sem histórico): $MOTIVO15"; exit 1; }
confere15 "$FORGE" vazio || { echo "FAIL [15] (controle, histórico vazio {}): $MOTIVO15"; exit 1; }
# Mutação (driftVerdict): o driftVerdict deixa de distinguir a ausência do histórico. O pacote mutante reaproveita template, installer e package.json do repositório.
MUT15="$T/mut15"
mkdir -p "$MUT15/bin"
ln -s "$WS/template" "$MUT15/template"
ln -s "$WS/installer" "$MUT15/installer"
ln -s "$WS/package.json" "$MUT15/package.json"
ALVO15="return history ? 'sem-lock' : 'sem-historico';"
[ "$(grep -cF "$ALVO15" "$FORGE")" -eq 1 ] || { echo "FAIL [15] (mutação): alvo da mutação ausente ou repetido no forge.mjs: $ALVO15"; exit 1; }
sed "s/return history ? 'sem-lock' : 'sem-historico';/return 'sem-lock';/" "$FORGE" > "$MUT15/bin/forge.mjs"
cmp -s "$FORGE" "$MUT15/bin/forge.mjs" && { echo "FAIL [15] (mutação): o sed não mudou nada"; exit 1; }
grep -qF "$ALVO15" "$MUT15/bin/forge.mjs" && { echo "FAIL [15] (mutação): o alvo continua no mutante"; exit 1; }
confere15 "$MUT15/bin/forge.mjs" sem && { echo "FAIL [15] (mutação): o mutante que ignora a ausência do histórico passou no caso sem histórico — o cenário não mede o texto"; exit 1; }
echo "  mutante reprovado no caso sem histórico, como esperado: $MOTIVO15"
confere15 "$MUT15/bin/forge.mjs" com || { echo "FAIL [15] (mutação): o mutante reprovou também o caso com histórico, então a reprovação não isola o defeito: $MOTIVO15"; exit 1; }
# Recontrole: o forge.mjs real, de novo, no caso que o mutante reprovou.
confere15 "$FORGE" sem || { echo "FAIL [15] (recontrole, sem histórico): $MOTIVO15"; exit 1; }

# Mutação (LOW-2): o WARN agregado do --dry-run passa a afirmar hasHistory=true incondicionalmente
# (`historyDry !== null` -> `true`, perto da linha 895 de bin/forge.mjs). Sem a checagem do
# --dry-run dentro de confere15 (acima), esse mutante sobrevivia ao [15] inteiro — nenhum cenário
# rodava `update --dry-run` no caso sem histórico.
MUT15B="$T/mut15b"
mkdir -p "$MUT15B/bin"
ln -s "$WS/template" "$MUT15B/template"
ln -s "$WS/installer" "$MUT15B/installer"
ln -s "$WS/package.json" "$MUT15B/package.json"
ALVO15B="historyDry !== null"
[ "$(grep -cF "$ALVO15B" "$FORGE")" -eq 1 ] || { echo "FAIL [15] (mutação LOW-2): alvo ausente ou repetido no forge.mjs: $ALVO15B"; exit 1; }
sed "s/historyDry !== null/true/" "$FORGE" > "$MUT15B/bin/forge.mjs"
cmp -s "$FORGE" "$MUT15B/bin/forge.mjs" && { echo "FAIL [15] (mutação LOW-2): o sed não mudou nada"; exit 1; }
grep -qF "$ALVO15B" "$MUT15B/bin/forge.mjs" && { echo "FAIL [15] (mutação LOW-2): o alvo continua no mutante"; exit 1; }
confere15 "$MUT15B/bin/forge.mjs" sem && { echo "FAIL [15] (mutação LOW-2): o mutante que força hasHistory=true no --dry-run passou no caso sem histórico — o WARN do --dry-run não mede o texto"; exit 1; }
echo "  mutante LOW-2 reprovado no caso sem histórico, como esperado: $MOTIVO15"
confere15 "$MUT15B/bin/forge.mjs" com || { echo "FAIL [15] (mutação LOW-2): o mutante reprovou também o caso com histórico, então a reprovação não isola o defeito: $MOTIVO15"; exit 1; }
# Recontrole (LOW-2): o forge.mjs real, de novo, no caso que o mutante LOW-2 reprovou.
confere15 "$FORGE" sem || { echo "FAIL [15] (recontrole LOW-2, sem histórico): $MOTIVO15"; exit 1; }
echo "OK [15]"

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
// Terceiro template, para a dimensão de sequência: a versão seguinte, que evoluiu de novo em REL e difere dos dois acima. Sem histórico ao lado: a prova de intocado do arquivo reconciliado à mão tem de vir da versão pendente guardada pelo update anterior.
const TPL3 = join(T, 'pbt-src-3', '.forge');
cpSync(TPLE, TPL3, { recursive: true });
appendFileSync(join(TPL3, REL), '\n# MUDANCA-SEGUINTE-PBT-w239\n');
const tpl3Sha = shaF(join(TPL3, REL));

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
  seq: P.gen.bool(),
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

let casos = 0, seqs = 0;
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
  const intocado = (temEntrada && s.lock === 'igual') || s.hist === 'contem-local';
  const deriva = differs && !excCobre && !intocado;
  const esperaIntacto = !differs || excCobre || (deriva && !s.flag);
  const esperaPendente = deriva && !s.flag;

  const dry = run(['update', '--target', dir, '--no-plugin', '--source', src, '--dry-run', ...flags]);
  const real = run(['update', '--target', dir, '--no-plugin', '--skip-postcheck', '--no-backup', '--source', src, ...flags]);
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
  // Sequência: reconciliação à mão pela saída (2) do /forge:upgrade (o resultado é igual à versão pendente) e update para a versão seguinte do template. Esperado: o arquivo é uma versão que o próprio template entregou, então recebe a versão seguinte (ATUALIZADO), sem pendente, e o lock avança.
  if (s.seq && esperaPendente && pendente && !falhas.length) {
    cpSync(join(dir, PEND_REL), join(dir, '.forge', REL));
    const dry2 = run(['update', '--target', dir, '--no-plugin', '--source', TPL3, '--dry-run']);
    const real2 = run(['update', '--target', dir, '--no-plugin', '--skip-postcheck', '--no-backup', '--source', TPL3]);
    if (dry2.rc !== 0 || real2.rc !== 0) falhas.push(`seq: rc dry=${dry2.rc} real=${real2.rc}`);
    if (!dry2.out.includes(`~ ${REL} (o template evoluiu — arquivo intocado, idêntico à versão pendente que o update anterior guardou)`)) falhas.push('seq: dry-run não antecipa a atualização do arquivo reconciliado');
    if (real2.out.split('\n').some((l) => /^PRESERVADO \([^)]*\): /.test(l) && l.includes(`: ${REL} — `))) falhas.push('seq: arquivo reconciliado retido de novo como deriva');
    if (!real2.out.split('\n').some((l) => l.startsWith(`ATUALIZADO: ${REL} — `))) falhas.push('seq: linha ATUALIZADO ausente');
    if (shaF(join(dir, '.forge', REL)) !== tpl3Sha) falhas.push('seq: o arquivo reconciliado não recebeu a versão seguinte');
    if (existsSync(join(dir, PEND_REL))) falhas.push('seq: pendente continua gravado');
    if (lockEntry(dir) !== tpl3Sha) falhas.push(`seq: lock=${lockEntry(dir)} esperado=${tpl3Sha}`);
    seqs++;
  }
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
// A sequência só acontece quando o primeiro update preserva por deriva sem a flag, cerca de 3% dos estados uniformes; uma segunda rodada, com semente própria, fixa esse recorte (local editado, sem exceção, sem flag, com sequência) e deixa livres lock, histórico e template, para que a dimensão seja medida em muitos casos e não num só.
const casosUniformes = casos;
const genSeq = P.gen.record({
  lock: P.gen.oneOf(['ausente', 'igual', 'diferente', 'sem-entrada']),
  hist: P.gen.oneOf(['ausente', 'contem-local', 'sem-local']),
  localEdit: P.gen.oneOf([true]),
  tplEvolve: P.gen.bool(),
  exc: P.gen.oneOf(['nenhuma']),
  flag: P.gen.oneOf([false]),
  seq: P.gen.oneOf([true]),
});
const SEED_SEQ = SEED + 1;
const r2 = P.forAll([genSeq], prop, { runs: 25, seed: SEED_SEQ });
if (!r2.ok) {
  console.error(`FAIL [10]: propriedade (recorte de sequência) falhou após ${r2.runs} caso(s) (seed ${r2.seed})`);
  console.error('  contraexemplo minimizado: ' + JSON.stringify(r2.counterexample));
  if (r2.error) console.error('  erro: ' + r2.error);
  process.exit(1);
}
// Guarda de vacuidade da dimensão de sequência: sem casos que reconciliam à mão e atualizam de novo, a propriedade passaria sem medir a sequência.
if (seqs < 5) { console.error(`FAIL [10]: só ${seqs} caso(s) exercitaram a sequência reconciliação à mão + update, esperado >= 5`); process.exit(1); }
console.log(`OK [10] (${casosUniformes} casos uniformes com seed ${r.seed} e ${r2.runs} no recorte de sequência com seed ${r2.seed}; ${seqs} com sequência)`);
NODE_EOF
rc10=$?
[ "$rc10" -eq 0 ] || { echo "FAIL [10]: PBT reprovou (ver saída acima)"; exit 1; }

[ "$UNV12" -eq 0 ] || { echo "UNV w239-update-preserva-deriva-gate: todos os cenários medidos passaram, mas o [12] não foi verificado (sem tags v* neste clone)"; exit 127; }
echo "PASS w239-update-preserva-deriva-gate"
