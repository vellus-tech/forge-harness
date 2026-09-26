#!/usr/bin/env bash
# Gate W214 — o `forge update` lê `.forge/machinery-exceptions.txt` antes de sobrescrever
# maquinaria própria (issues #101 e #131, um PR só — mesma causa raiz em bin/forge.mjs:618-733).
#
# POR QUE ESTE GATE EXISTE. `scripts/`, `hooks/` e `commands/` estão fora de ENRICHABLE_DIRS —
# são maquinaria que precisa poder ser corrigida pelo template — e por isso o overlay do update
# os sobrescreve incondicionalmente. Até aqui nenhuma linha do updater lia
# `.forge/machinery-exceptions.txt` (grep vazio em bin/): a divergência DELIBERADA que um
# consumidor declara ali — a mesma gramática que o `check-machinery-drift.sh` do
# axis-fare-validator já opera em produção — era invisível para o `update`, que revertia o
# conserto local com `rc=0` e, sem `machinery.lock` prévio (primeiro update depois do fix), sem
# aviso nenhum.
#
#   [1] exceção VIVA (sha declarado == sha do template novo): preserva o arquivo local e nomeia
#       com `PRESERVADO (exceção declarada)` — mesmo sem machinery.lock (primeiro update)
#   [2] NÃO declarada: sobrescreve e nomeia com `SOBRESCRITO (não declarado)`, apontando para o
#       backup real onde o conteúdo anterior sobrevive
#   [3] EXPIRADA (sha declarado != sha do template novo): preserva mesmo assim (DH-1) e nomeia
#       com `EXCEÇÃO EXPIRADA`, os dois shas, rc 0 — não bloqueia a fronteira publicada do update
#   [4] malformada (sha inválido) e duplicada (mesmo caminho duas vezes): param o update ANTES de
#       escrever qualquer arquivo, a recusa nomeia o número da linha, rc != 0
#   [5] ausência de `.forge/machinery-exceptions.txt`: comportamento igual ao de antes desta
#       entrega, mais as linhas `SOBRESCRITO` novas — nada além disso aparece
#   [6] fixture real: cópia literal do `.forge/machinery-exceptions.txt` do axis-fare-validator
#       (34 linhas vivas, só leitura em disco, sanitizada por grep prévio — sem PII/segredo) —
#       o parser aceita com rc 0 e nomeia as 34 linhas
#   [8] --dry-run HONRA exceções declaradas: exceção viva aparece como `= rel (preservado —
#       exceção declarada)`, nunca como `~ rel` (sobrescrita) — a prévia mostrada ao humano antes
#       de confirmar não pode contradizer o que a aplicação real faz
#   [8b] --dry-run HONRA exceção EXPIRADA (mesma garantia de [8], para a classe que o review
#        adversarial achou descoberta: [8] só cobria a classe viva)
#   [9] arquivo intocado localmente (hash bate com machinery.lock) cujo template evoluiu: nomeado
#       como `ATUALIZADO`, nunca como `SOBRESCRITO (não declarado)` — o rótulo de sobrescrita não
#       declarada fica reservado para divergência de verdade
#   [10] tombstone (path que o template removeu) com exceção declarada: a exceção barra a poda de
#        órfãos, o arquivo sobrevive e aparece exatamente uma vez no relatório
#   [10b] --dry-run do mesmo tombstone com exceção: pulado na prévia também, nunca listado como
#         `- rel (órfão ...)` — [10] só cobria a aplicação real
#   [11]/[11b]/[11c] caminho declarado com prefixo `./` ou `.forge/` é NORMALIZADO (aceito e
#        nomeado com a grafia original) em vez de cair em `fora-do-template`/OCIOSA — perda
#        silenciosa de conserto local por erro de grafia; duas declarações que normalizam para o
#        mesmo caminho contam como duplicata
#   [7] PBT: para arquivos de exceção gerados sobre caminhos REAIS do template, o update para
#       sse existe linha malformada/duplicada; quando não para, cada arquivo fica byte-idêntico
#       sse tem exceção viva ou expirada, e todo caminho declarado aparece exatamente uma vez
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$WS/bin/forge.mjs"
TPL="$WS/template/.forge"
T="$(mktemp -d /tmp/forge-w214.XXXXXX)"
trap 'rm -rf "$T"' EXIT

consumidor() {  # consumidor <nome> -> ecoa <dir>, com .forge instalado a partir do template real
  local d="$T/$1"
  mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  node "$FORGE" init --target "$d" --slug demo --name Demo --desc t --yes --no-plugin >"$d/init.log" 2>&1 \
    || { echo "FAIL (setup): init falhou para $1"; cat "$d/init.log"; exit 1; }
  printf '%s\n' "$d"
}

sha_tpl() { shasum -a 256 "$TPL/$1" | cut -d' ' -f1; }  # sha_tpl <rel-a-.forge>

echo "[1] exceção viva preserva e nomeia, mesmo sem machinery.lock prévio"
C1="$(consumidor c1)"
printf '\n# CONSERTO-LOCAL (issue #101, medido em axis-go-cloud)\n' >> "$C1/.forge/scripts/lib/transports/_common.sh"
SHA_CONSERTO="$(shasum -a 256 "$C1/.forge/scripts/lib/transports/_common.sh" | cut -d' ' -f1)"
printf '%s  scripts/lib/transports/_common.sh  # une o hub sem destruir escrita concorrente\n' "$(sha_tpl scripts/lib/transports/_common.sh)" \
  > "$C1/.forge/machinery-exceptions.txt"
[ ! -f "$C1/.forge/cache/machinery.lock" ] || { echo "FAIL [1] (setup): consumidor já tem machinery.lock — o cenário exige ausência dele)"; exit 1; }
out1="$(node "$FORGE" update --target "$C1" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc1=$?
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: update com exceção viva saiu rc=$rc1"; echo "$out1"; exit 1; }
[ "$(shasum -a 256 "$C1/.forge/scripts/lib/transports/_common.sh" | cut -d' ' -f1)" = "$SHA_CONSERTO" ] \
  || { echo "FAIL [1]: conserto local foi sobrescrito — exceção viva não preservou"; exit 1; }
grep -q 'PRESERVADO (exceção declarada): scripts/lib/transports/_common.sh' <<<"$out1" \
  || { echo "FAIL [1]: linha PRESERVADO (exceção declarada) ausente"; echo "$out1"; exit 1; }
echo "OK [1]"

echo "[2] NÃO declarada: sobrescreve e nomeia com o backup real"
C2="$(consumidor c2)"
printf '\n# fix-local-sem-declarar\n' >> "$C2/.forge/scripts/handoff-gen.sh"
out2="$(node "$FORGE" update --target "$C2" --no-plugin --source "$TPL" 2>&1)"; rc2=$?
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: update saiu rc=$rc2"; echo "$out2"; exit 1; }
grep -q 'fix-local-sem-declarar' "$C2/.forge/scripts/handoff-gen.sh" \
  && { echo "FAIL [2]: fix local sobreviveu — deveria ter sido sobrescrito (sem exceção declarada)"; exit 1; }
linha2="$(grep 'SOBRESCRITO (não declarado): scripts/handoff-gen.sh' <<<"$out2")"
[ -n "$linha2" ] || { echo "FAIL [2]: linha SOBRESCRITO (não declarado) ausente"; echo "$out2"; exit 1; }
bak_rel="$(sed -E 's/.*conteúdo anterior em //' <<<"$linha2")"
[ -f "$C2/$bak_rel" ] || { echo "FAIL [2]: backup nomeado não existe em disco ($bak_rel)"; exit 1; }
grep -q 'fix-local-sem-declarar' "$C2/$bak_rel" \
  || { echo "FAIL [2]: backup nomeado não contém o conteúdo anterior"; exit 1; }
echo "OK [2]"

echo "[3] EXPIRADA: preserva mesmo assim, nomeia os dois shas, rc 0"
C3="$(consumidor c3)"
printf '\n# CONSERTO-EXPIRADO\n' >> "$C3/.forge/scripts/doctor.sh"
SHA_LOCAL3="$(shasum -a 256 "$C3/.forge/scripts/doctor.sh" | cut -d' ' -f1)"
SHA_ERRADO="$(printf '0%.0s' $(seq 1 63))a"   # 64 chars hex — sha propositalmente errado
[ "${#SHA_ERRADO}" -eq 64 ] || { echo "FAIL [3] (setup): SHA_ERRADO malformado (len=${#SHA_ERRADO})"; exit 1; }
printf '%s  scripts/doctor.sh  # exceção contra versão anterior do template\n' "$SHA_ERRADO" > "$C3/.forge/machinery-exceptions.txt"
SHA_TPL_DOCTOR="$(sha_tpl scripts/doctor.sh)"
out3="$(node "$FORGE" update --target "$C3" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc3=$?
[ "$rc3" -eq 0 ] || { echo "FAIL [3]: exceção expirada não pode bloquear o update (DH-1) — saiu rc=$rc3"; echo "$out3"; exit 1; }
[ "$(shasum -a 256 "$C3/.forge/scripts/doctor.sh" | cut -d' ' -f1)" = "$SHA_LOCAL3" ] \
  || { echo "FAIL [3]: arquivo com exceção expirada foi sobrescrito — deveria ser preservado (DH-1)"; exit 1; }
grep -q "EXCEÇÃO EXPIRADA: scripts/doctor.sh — sha declarado $SHA_ERRADO, sha do template novo $SHA_TPL_DOCTOR" <<<"$out3" \
  || { echo "FAIL [3]: linha EXCEÇÃO EXPIRADA ausente ou sem os dois shas"; echo "$out3"; exit 1; }
echo "OK [3]"

echo "[4a] malformada: para ANTES de escrever, nomeia a linha"
C4A="$(consumidor c4a)"
printf 'shaInvalida  scripts/doctor.sh  # sha nao e hex\n' > "$C4A/.forge/machinery-exceptions.txt"
SHA_DOCTOR_ANTES="$(shasum -a 256 "$C4A/.forge/forge.yaml" | cut -d' ' -f1)"
set +e
out4a="$(node "$FORGE" update --target "$C4A" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc4a=$?
set +e  # permanece +e — nunca ligar errexit de volta (LOW achado: falha inesperada silenciava sem FAIL [n])
[ "$rc4a" -ne 0 ] || { echo "FAIL [4a]: exceção malformada não bloqueou o update"; echo "$out4a"; exit 1; }
grep -q 'linha 1' <<<"$out4a" || { echo "FAIL [4a]: recusa não nomeia o número da linha"; echo "$out4a"; exit 1; }
[ "$(shasum -a 256 "$C4A/.forge/forge.yaml" | cut -d' ' -f1)" = "$SHA_DOCTOR_ANTES" ] \
  || { echo "FAIL [4a]: forge.yaml foi escrito mesmo com exceção malformada — nada deveria ter sido tocado"; exit 1; }
[ ! -f "$C4A/.forge/cache/machinery.lock" ] \
  || { echo "FAIL [4a]: machinery.lock foi escrito mesmo com exceção malformada"; exit 1; }
# achado do review adversarial (LOW): os dois cenários acima rodam com --no-backup, então nada
# prova que o aborto acontece ANTES do backup também — repete SEM --no-backup e confere que
# nenhum backup foi criado (o aborto tem de vir antes de qualquer escrita, backup incluso).
out4a2="$(node "$FORGE" update --target "$C4A" --no-plugin --source "$TPL" 2>&1)"; rc4a2=$?
[ "$rc4a2" -ne 0 ] || { echo "FAIL [4a]: exceção malformada não bloqueou o update (execução sem --no-backup)"; echo "$out4a2"; exit 1; }
[ ! -d "$C4A/.git/forge-backups" ] || { echo "FAIL [4a]: backup foi criado mesmo com exceção malformada — o aborto deveria vir ANTES do backup"; exit 1; }
echo "OK [4a]"

echo "[4b] duplicada: para ANTES de escrever, nomeia as duas linhas"
C4B="$(consumidor c4b)"
SHA_DOCTOR="$(sha_tpl scripts/doctor.sh)"
{
  printf '%s  scripts/doctor.sh  # primeira declaração\n' "$SHA_DOCTOR"
  printf '%s  scripts/doctor.sh  # segunda declaração do mesmo caminho\n' "$SHA_DOCTOR"
} > "$C4B/.forge/machinery-exceptions.txt"
set +e
out4b="$(node "$FORGE" update --target "$C4B" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc4b=$?
set +e  # idem
[ "$rc4b" -ne 0 ] || { echo "FAIL [4b]: exceção duplicada não bloqueou o update"; echo "$out4b"; exit 1; }
grep -q 'linhas 1 e 2' <<<"$out4b" || { echo "FAIL [4b]: recusa não nomeia as duas linhas duplicadas"; echo "$out4b"; exit 1; }
[ ! -f "$C4B/.forge/cache/machinery.lock" ] \
  || { echo "FAIL [4b]: machinery.lock foi escrito mesmo com exceção duplicada"; exit 1; }
echo "OK [4b]"

echo "[5] ausência de machinery-exceptions.txt: só as linhas SOBRESCRITO são novas"
C5="$(consumidor c5)"
[ ! -f "$C5/.forge/machinery-exceptions.txt" ] || rm -f "$C5/.forge/machinery-exceptions.txt"
printf '\n# fix-sem-arquivo-de-excecoes\n' >> "$C5/.forge/scripts/handoff-gen.sh"
out5="$(node "$FORGE" update --target "$C5" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc5=$?
[ "$rc5" -eq 0 ] || { echo "FAIL [5]: update sem arquivo de exceções saiu rc=$rc5"; echo "$out5"; exit 1; }
grep -q 'fix-sem-arquivo-de-excecoes' "$C5/.forge/scripts/handoff-gen.sh" \
  && { echo "FAIL [5]: fix local sobreviveu sem exceção declarada"; exit 1; }
grep -q 'SOBRESCRITO (não declarado): scripts/handoff-gen.sh' <<<"$out5" \
  || { echo "FAIL [5]: SOBRESCRITO ausente mesmo sem arquivo de exceções"; echo "$out5"; exit 1; }
grep -qi 'exceç' <<<"$out5" && { echo "FAIL [5]: sem arquivo de exceções, o relatório não deveria mencionar exceção nenhuma"; echo "$out5"; exit 1; }
echo "OK [5]"

echo "[6] fixture real (axis-fare-validator, 34 exceções): rc 0, as 34 linhas nomeadas"
FIXTURE="$WS/tests/fixtures/w214/machinery-exceptions-axis-fare-validator.txt"
[ -f "$FIXTURE" ] || { echo "FAIL [6] (setup): fixture ausente em $FIXTURE"; exit 1; }
N_DECLARADAS="$(grep -cE '^[0-9a-f]{32,}[[:space:]]' "$FIXTURE")"
[ "$N_DECLARADAS" -eq 34 ] || { echo "FAIL [6] (setup): fixture não tem 34 linhas vivas de dados (achei $N_DECLARADAS)"; exit 1; }
C6="$(consumidor c6)"
cp "$FIXTURE" "$C6/.forge/machinery-exceptions.txt"
out6="$(node "$FORGE" update --target "$C6" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc6=$?
[ "$rc6" -eq 0 ] || { echo "FAIL [6]: fixture real de 34 exceções não deveria bloquear o update"; echo "$out6"; exit 1; }
n_nomeadas=0
while IFS= read -r rel; do
  grep -qF "$rel" <<<"$out6" || { echo "FAIL [6]: caminho '$rel' da fixture não foi nomeado no relatório"; exit 1; }
  n_nomeadas=$((n_nomeadas + 1))
done < <(grep -E '^[0-9a-f]{32,}[[:space:]]' "$FIXTURE" | awk '{print $2}')
[ "$n_nomeadas" -eq 34 ] || { echo "FAIL [6]: nomeadas $n_nomeadas de 34"; exit 1; }
echo "OK [6] (34/34 nomeadas, rc 0)"

echo "[8] --dry-run honra exceção viva: '= rel (preservado — exceção declarada)', nunca '~ rel'"
C8="$(consumidor c8)"
printf '\n# CONSERTO-LOCAL-DRYRUN\n' >> "$C8/.forge/scripts/lib/transports/_common.sh"
printf '%s  scripts/lib/transports/_common.sh  # preservar no dry-run também\n' "$(sha_tpl scripts/lib/transports/_common.sh)" \
  > "$C8/.forge/machinery-exceptions.txt"
out8="$(node "$FORGE" update --target "$C8" --no-plugin --source "$TPL" --dry-run 2>&1)"; rc8=$?
[ "$rc8" -eq 0 ] || { echo "FAIL [8]: dry-run saiu rc=$rc8"; echo "$out8"; exit 1; }
grep -q '^= scripts/lib/transports/_common.sh (preservado — exceção declarada)$' <<<"$out8" \
  || { echo "FAIL [8]: dry-run não anuncia a preservação por exceção viva"; echo "$out8"; exit 1; }
grep -q '^~ scripts/lib/transports/_common.sh' <<<"$out8" \
  && { echo "FAIL [8]: dry-run anuncia sobrescrita de arquivo que a exceção viva preserva"; echo "$out8"; exit 1; }
[ "$(shasum -a 256 "$C8/.forge/scripts/lib/transports/_common.sh" | cut -d' ' -f1)" != "$(sha_tpl scripts/lib/transports/_common.sh)" ] \
  || { echo "FAIL [8] (setup): conserto local não sobreviveu ao setup do cenário"; exit 1; }
echo "OK [8]"

echo "[8b] --dry-run honra exceção EXPIRADA: '= rel (preservado — EXCEÇÃO EXPIRADA...)', nunca '~ rel'"
C8B="$(consumidor c8b)"
printf '\n# CONSERTO-EXPIRADO-DRYRUN\n' >> "$C8B/.forge/scripts/doctor.sh"
SHA_ERRADO_8B="$(printf '0%.0s' $(seq 1 63))a"
printf '%s  scripts/doctor.sh  # exceção expirada no dry-run\n' "$SHA_ERRADO_8B" > "$C8B/.forge/machinery-exceptions.txt"
SHA_TPL_DOCTOR_8B="$(sha_tpl scripts/doctor.sh)"
out8b="$(node "$FORGE" update --target "$C8B" --no-plugin --source "$TPL" --dry-run 2>&1)"; rc8b=$?
[ "$rc8b" -eq 0 ] || { echo "FAIL [8b]: dry-run saiu rc=$rc8b"; echo "$out8b"; exit 1; }
grep -q "^= scripts/doctor.sh (preservado — EXCEÇÃO EXPIRADA: declarado $SHA_ERRADO_8B, template $SHA_TPL_DOCTOR_8B)\$" <<<"$out8b" \
  || { echo "FAIL [8b]: dry-run não anuncia a preservação por exceção expirada"; echo "$out8b"; exit 1; }
grep -q '^~ scripts/doctor.sh' <<<"$out8b" \
  && { echo "FAIL [8b]: dry-run anuncia sobrescrita de arquivo que a exceção expirada preserva (DH-1)"; echo "$out8b"; exit 1; }
echo "OK [8b]"

echo "[9] arquivo intocado com lock, template evoluiu: 'ATUALIZADO', nunca 'SOBRESCRITO (não declarado)'"
C9="$(consumidor c9)"
node "$FORGE" update --target "$C9" --no-plugin --no-backup --source "$TPL" >/dev/null 2>&1
[ -f "$C9/.forge/cache/machinery.lock" ] || { echo "FAIL [9] (setup): machinery.lock não foi gravado no update de preparo"; exit 1; }
TPL9="$T/tpl9"; rm -rf "$TPL9"; cp -R "$TPL" "$TPL9"
printf '\n# MUDANCA-DO-TEMPLATE-NOVA-VERSAO-w214-9\n' >> "$TPL9/scripts/handoff-gen.sh"
out9="$(node "$FORGE" update --target "$C9" --no-plugin --no-backup --source "$TPL9" 2>&1)"; rc9=$?
[ "$rc9" -eq 0 ] || { echo "FAIL [9]: update saiu rc=$rc9"; echo "$out9"; exit 1; }
grep -q 'MUDANCA-DO-TEMPLATE-NOVA-VERSAO-w214-9' "$C9/.forge/scripts/handoff-gen.sh" \
  || { echo "FAIL [9]: o template não aplicou a mudança nova (overlay não sobrescreveu)"; exit 1; }
grep -q 'SOBRESCRITO (não declarado): scripts/handoff-gen.sh' <<<"$out9" \
  && { echo "FAIL [9]: arquivo intocado localmente (lock bate) foi relatado como SOBRESCRITO (não declarado)"; echo "$out9"; exit 1; }
grep -q '^ATUALIZADO: scripts/handoff-gen.sh' <<<"$out9" \
  || { echo "FAIL [9]: linha ATUALIZADO ausente para arquivo intocado que o template atualizou"; echo "$out9"; exit 1; }
echo "OK [9]"

echo "[10] tombstone com exceção declarada: preservado, não apagado, aparece exatamente uma vez"
C10="$(consumidor c10)"
TOMB_REL="commands/graph/build.md"
mkdir -p "$(dirname "$C10/.forge/$TOMB_REL")"
printf '# customizacao local do consumidor sobre um comando removido do template\n' > "$C10/.forge/$TOMB_REL"
MANIFEST10="$T/removed-manifest-w214-10.txt"
printf '%s\n' "$TOMB_REL" > "$MANIFEST10"
SHA10="$(shasum -a 256 "$C10/.forge/$TOMB_REL" | cut -d' ' -f1)"
printf '%s  %s  # tombstone preservado por decisão local\n' "$SHA10" "$TOMB_REL" > "$C10/.forge/machinery-exceptions.txt"
out10="$(FORGE_REMOVED_MANIFEST="$MANIFEST10" node "$FORGE" update --target "$C10" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc10=$?
[ "$rc10" -eq 0 ] || { echo "FAIL [10]: update saiu rc=$rc10"; echo "$out10"; exit 1; }
[ -f "$C10/.forge/$TOMB_REL" ] || { echo "FAIL [10]: tombstone com exceção declarada foi apagado pela poda de órfãos"; exit 1; }
n10="$(grep -c "$TOMB_REL" <<<"$out10" || true)"
[ "$n10" -eq 1 ] || { echo "FAIL [10]: caminho '$TOMB_REL' apareceu $n10 vez(es) no relatório, esperado exatamente 1"; echo "$out10"; exit 1; }
grep -q 'tombstone pulado — exceção declarada' <<<"$out10" \
  || { echo "FAIL [10]: linha de tombstone pulado por exceção declarada ausente"; echo "$out10"; exit 1; }
echo "OK [10]"

echo "[10b] --dry-run honra o mesmo tombstone com exceção declarada: pulado na prévia, nunca listado como órfão"
C10B="$(consumidor c10b)"
TOMB_REL_B="commands/graph/build.md"
mkdir -p "$(dirname "$C10B/.forge/$TOMB_REL_B")"
printf '# customizacao local do consumidor sobre um comando removido do template (dry-run)\n' > "$C10B/.forge/$TOMB_REL_B"
MANIFEST10B="$T/removed-manifest-w214-10b.txt"
printf '%s\n' "$TOMB_REL_B" > "$MANIFEST10B"
SHA10B="$(shasum -a 256 "$C10B/.forge/$TOMB_REL_B" | cut -d' ' -f1)"
printf '%s  %s  # tombstone preservado por decisão local (dry-run)\n' "$SHA10B" "$TOMB_REL_B" > "$C10B/.forge/machinery-exceptions.txt"
out10b="$(FORGE_REMOVED_MANIFEST="$MANIFEST10B" node "$FORGE" update --target "$C10B" --no-plugin --source "$TPL" --dry-run 2>&1)"; rc10b=$?
[ "$rc10b" -eq 0 ] || { echo "FAIL [10b]: dry-run saiu rc=$rc10b"; echo "$out10b"; exit 1; }
grep -q "^= $TOMB_REL_B (tombstone pulado — exceção declarada)" <<<"$out10b" \
  || { echo "FAIL [10b]: dry-run não anuncia o tombstone pulado por exceção declarada"; echo "$out10b"; exit 1; }
grep -q "^- $TOMB_REL_B" <<<"$out10b" \
  && { echo "FAIL [10b]: dry-run anuncia remoção do órfão que a exceção deveria barrar"; echo "$out10b"; exit 1; }
[ -f "$C10B/.forge/$TOMB_REL_B" ] || { echo "FAIL [10b]: dry-run alterou o disco (não deveria escrever nada)"; exit 1; }
echo "OK [10b]"

echo "[11] caminho declarado com prefixo './' é normalizado (aceito), nomeando a grafia original declarada"
C11="$(consumidor c11)"
printf '\n# CONSERTO-LOCAL-PREFIXO\n' >> "$C11/.forge/scripts/doctor.sh"
SHA_DOCTOR11="$(sha_tpl scripts/doctor.sh)"
printf '%s  ./scripts/doctor.sh  # declarado com prefixo ./\n' "$SHA_DOCTOR11" > "$C11/.forge/machinery-exceptions.txt"
out11="$(node "$FORGE" update --target "$C11" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc11=$?
[ "$rc11" -eq 0 ] || { echo "FAIL [11]: update saiu rc=$rc11"; echo "$out11"; exit 1; }
grep -q 'CONSERTO-LOCAL-PREFIXO' "$C11/.forge/scripts/doctor.sh" \
  || { echo "FAIL [11]: conserto local sobrescrito — prefixo './' não foi normalizado para casar com scripts/doctor.sh"; exit 1; }
grep -qF "PRESERVADO (exceção declarada): scripts/doctor.sh — razão: declarado com prefixo ./ (declarado como './scripts/doctor.sh')" <<<"$out11" \
  || { echo "FAIL [11]: relatório não nomeia a grafia original declarada"; echo "$out11"; exit 1; }
echo "OK [11]"

echo "[11b] prefixo '.forge/' também normaliza"
C11B="$(consumidor c11b)"
printf '\n# CONSERTO-LOCAL-PREFIXO-FORGE\n' >> "$C11B/.forge/scripts/handoff-gen.sh"
SHA_HANDOFF11B="$(sha_tpl scripts/handoff-gen.sh)"
printf '%s  .forge/scripts/handoff-gen.sh  # declarado com prefixo .forge/\n' "$SHA_HANDOFF11B" > "$C11B/.forge/machinery-exceptions.txt"
out11b="$(node "$FORGE" update --target "$C11B" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc11b=$?
[ "$rc11b" -eq 0 ] || { echo "FAIL [11b]: update saiu rc=$rc11b"; echo "$out11b"; exit 1; }
grep -q 'CONSERTO-LOCAL-PREFIXO-FORGE' "$C11B/.forge/scripts/handoff-gen.sh" \
  || { echo "FAIL [11b]: conserto local sobrescrito — prefixo '.forge/' não foi normalizado"; exit 1; }
echo "OK [11b]"

echo "[11c] mesmo caminho declarado com e sem prefixo normaliza para o mesmo rel — é duplicata"
C11C="$(consumidor c11c)"
SHA_DOCTOR11C="$(sha_tpl scripts/doctor.sh)"
{
  printf '%s  scripts/doctor.sh  # sem prefixo\n' "$SHA_DOCTOR11C"
  printf '%s  ./scripts/doctor.sh  # com prefixo, mesmo caminho apos normalizar\n' "$SHA_DOCTOR11C"
} > "$C11C/.forge/machinery-exceptions.txt"
set +e
out11c="$(node "$FORGE" update --target "$C11C" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc11c=$?
set +e  # idem
[ "$rc11c" -ne 0 ] || { echo "FAIL [11c]: declarações que normalizam para o mesmo caminho não foram tratadas como duplicata"; echo "$out11c"; exit 1; }
grep -q 'caminho declarado duas vezes' <<<"$out11c" \
  || { echo "FAIL [11c]: recusa não nomeia duplicata por normalização de prefixo"; echo "$out11c"; exit 1; }
echo "OK [11c]"

echo "[7] PBT: para exceções geradas sobre caminhos reais do template, o desfecho é função pura do conjunto declarado"
node --input-type=module - "$WS" <<'NODE_EOF'
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { mkdtempSync, rmSync, cpSync, writeFileSync, readFileSync, existsSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const WS = process.argv[2];
const P = await import(pathToFileURL(join(WS, 'template/.forge/scripts/lib/pbt.mjs')).href);
const FORGE = join(WS, 'bin/forge.mjs');
const TPL = join(WS, 'template/.forge');
const sha256 = (p) => createHash('sha256').update(readFileSync(p)).digest('hex');

// Universo FIXO de caminhos reais e não-enriquecíveis do template — pequeno de propósito, para
// que 50+ execuções de `update` real (subprocesso; bin/forge.mjs roda main() incondicionalmente
// na importação, então testar em processo exigiria duplicar o parser — o que a #158 desta
// rodada proíbe) caibam no orçamento do gate.
const REAL_PATHS = [
  'scripts/handoff-gen.sh',
  'scripts/doctor.sh',
  'hooks/git/pre-push',
  'hooks/git/post-merge',
];

// Consumidor PRISTINE, preparado uma vez por `init` real; cada caso do PBT parte de uma cópia dele.
const pristine = mkdtempSync(join(tmpdir(), 'forge-w214-pbt-pristine-'));
execFileSync('git', ['init', '-q', pristine]);
execFileSync('git', ['-C', pristine, 'config', 'user.email', 't@t']);
execFileSync('git', ['-C', pristine, 'config', 'user.name', 't']);
execFileSync('node', [FORGE, 'init', '--target', pristine, '--slug', 'demo', '--name', 'Demo', '--desc', 't', '--yes', '--no-plugin']);

const templateHash = {};
for (const rel of REAL_PATHS) templateHash[rel] = sha256(join(TPL, rel));
const GHOST_REL = 'scripts/caminho-fantasma-fixo-w214.sh';

// Gerador: um estado por caminho real ('viva'|'expirada'|'identica'|'divergente'|'none') + flags
// de perturbação (fantasma fora do template, duplicata, malformada) — cobre as 6 categorias que a
// propriedade enumera (vivas, expiradas, ociosas, divergente-não-declarado, malformadas e
// duplicadas). 'divergente' é o estado que faltava no gerador original (achado do review
// adversarial, MEDIUM): local editado SEM declaração nenhuma — é o único jeito de exercitar o
// lado "sse" de "byte-idêntico sse viva/expirada" (sem ele, nenhum caso do PBT testa a sobrescrita
// de verdade, só a preservação).
const gState = P.gen.array(P.gen.oneOf(['viva', 'expirada', 'identica', 'divergente', 'none']), REAL_PATHS.length, REAL_PATHS.length);
const gFlags = P.gen.record({ ghost: P.gen.bool(), duplicate: P.gen.bool(), malformed: P.gen.bool() });

let casesRun = 0;
const prop = (states, flags) => {
  casesRun++;
  const dir = mkdtempSync(join(tmpdir(), 'forge-w214-pbt-case-'));
  rmSync(dir, { recursive: true, force: true });
  cpSync(pristine, dir, { recursive: true });

  const lines = [];
  const declared = []; // { rel, category } — caminhos DECLARADOS em machinery-exceptions.txt
  const undeclaredDivergent = []; // caminhos editados localmente SEM declaração nenhuma
  states.forEach((state, i) => {
    const rel = REAL_PATHS[i];
    const dst = join(dir, '.forge', rel);
    if (state === 'none') return;
    if (state === 'identica') {
      // dst já é igual ao template (init acabou de copiar) — não mexe no arquivo.
      lines.push(`${templateHash[rel]}  ${rel}  # ociosa: identica ao template`);
      declared.push({ rel, category: 'identica' });
      return;
    }
    if (state === 'divergente') {
      // editado localmente, NUNCA declarado — deve ser sobrescrito e nomeado SOBRESCRITO.
      writeFileSync(dst, readFileSync(dst, 'utf8') + `\n# mutação pbt divergente ${rel}\n`);
      undeclaredDivergent.push(rel);
      return;
    }
    // viva/expirada precisam de divergência local real para a classificação fazer sentido.
    writeFileSync(dst, readFileSync(dst, 'utf8') + `\n# mutação pbt ${state} ${rel}\n`);
    if (state === 'viva') {
      lines.push(`${templateHash[rel]}  ${rel}  # viva`);
      declared.push({ rel, category: 'viva' });
    } else {
      // Sha "errado" de propósito para expirada: troca só o primeiro dígito hex, preservando o
      // comprimento. Bug do gerador original (achado do review, MEDIUM): comparava uma FATIA de
      // 63 caracteres com o caractere único '0' (`slice(0, 63) === '0'`), que nunca é verdadeiro —
      // então, sempre que o sha do template começasse com '0', o "wrong" saía IDÊNTICO ao sha
      // certo e a categoria "expirada" virava "viva" em silêncio, sem que a seed fixa 214101131
      // jamais expusesse isso (nenhum dos hashes reais usados começa com '0').
      const wrong = (templateHash[rel][0] === '0' ? '1' : '0') + templateHash[rel].slice(1);
      lines.push(`${wrong}  ${rel}  # expirada`);
      declared.push({ rel, category: 'expirada', wrongSha: wrong });
    }
  });
  if (flags.ghost) lines.push(`${'a'.repeat(64)}  ${GHOST_REL}  # fora do template`);
  if (flags.duplicate && declared.length) {
    const d = declared[0];
    lines.push(`${templateHash[d.rel] || 'a'.repeat(64)}  ${d.rel}  # segunda declaração do mesmo caminho`);
  }
  if (flags.malformed) lines.push('nao-e-hex-valido  scripts/doctor.sh  # malformada de propósito');

  mkdirSync(join(dir, '.forge'), { recursive: true });
  writeFileSync(join(dir, '.forge', 'machinery-exceptions.txt'), lines.join('\n') + '\n');

  // Bug do gerador original (achado do review, MEDIUM): `flags.duplicate` com `declared` vazio
  // não escreve NENHUMA duplicata de verdade no arquivo (o `if (flags.duplicate && declared.length)`
  // acima pula), mas `shouldAbort` continuava `true` mesmo assim — falso FAIL emboscado, que a
  // seed fixa nunca disparou. Duplicata só existe, e só deve abortar, quando há algo para duplicar.
  const shouldAbort = flags.malformed || (flags.duplicate && declared.length > 0);

  // Estado ANTES de rodar — necessário para o ramo de abortar provar que NADA foi escrito (achado
  // do review, MEDIUM: o teste conferia só `rc !== 0`, nunca a ausência de escrita).
  const preHashes = Object.fromEntries(REAL_PATHS.map((rel) => [rel, sha256(join(dir, '.forge', rel))]));
  const lockPathBefore = join(dir, '.forge', 'cache', 'machinery.lock');
  const lockExistedBefore = existsSync(lockPathBefore);

  let out = '', rc = 0;
  try {
    out = execFileSync('node', [FORGE, 'update', '--target', dir, '--no-plugin', '--no-backup', '--source', TPL], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) {
    rc = e.status ?? 1;
    out = (e.stdout || '') + (e.stderr || '');
  }

  let ok = true;
  if (shouldAbort) {
    ok = rc !== 0;
    if (ok) {
      // nenhum arquivo de REAL_PATHS foi tocado, e o lock não foi criado do zero.
      for (const rel of REAL_PATHS) {
        if (sha256(join(dir, '.forge', rel)) !== preHashes[rel]) ok = false;
      }
      if (!lockExistedBefore && existsSync(lockPathBefore)) ok = false;
    }
  } else {
    ok = rc === 0;
    if (ok) {
      for (const d of declared) {
        const dst = join(dir, '.forge', d.rel);
        const nowHash = sha256(dst);
        const shouldBeUnchanged = d.category === 'viva' || d.category === 'expirada';
        // achado do review adversarial (LOW): "!== templateHash" só prova que o overlay não
        // aplicou o template — um conteúdo corrompido para um TERCEIRO valor qualquer também
        // passaria nessa checagem. "byte-idêntico" exige comparar contra o hash ANTES do update
        // (preHashes), nunca só "diferente do template novo".
        const wasUnchanged = nowHash === preHashes[d.rel];
        if (d.category === 'identica') {
          if (nowHash !== templateHash[d.rel]) ok = false;
        } else if (shouldBeUnchanged !== wasUnchanged) {
          ok = false;
        }
        // todo caminho declarado aparece EXATAMENTE uma vez no relatório — "< 1" (pelo menos uma)
        // era o bug do teste original (achado do review, MEDIUM); a propriedade da seção exige
        // "exatamente uma vez".
        const occurrences = out.split(d.rel).length - 1;
        if (occurrences !== 1) ok = false;
        // a categoria relatada tem de bater com a rotulagem que o update usa — não basta o
        // caminho aparecer, o RÓTULO tem de ser o certo (achado do review, MEDIUM: uma expirada
        // relatada como PRESERVADO passaria no teste antigo).
        if (d.category === 'viva' && !out.includes(`PRESERVADO (exceção declarada): ${d.rel}`)) ok = false;
        if (d.category === 'expirada' && !out.includes(`EXCEÇÃO EXPIRADA: ${d.rel}`)) ok = false;
        if (d.category === 'identica' && !out.includes(`EXCEÇÃO OCIOSA: ${d.rel}`)) ok = false;
      }
      // caminho divergente e NÃO declarado: sobrescrito (byte-idêntico ao template novo) e
      // nomeado SOBRESCRITO (não declarado) exatamente uma vez.
      for (const rel of undeclaredDivergent) {
        const dst = join(dir, '.forge', rel);
        if (sha256(dst) !== templateHash[rel]) ok = false;
        const occurrences = out.split(rel).length - 1;
        if (occurrences !== 1) ok = false;
        if (!out.includes(`SOBRESCRITO (não declarado): ${rel}`)) ok = false;
      }
      // o caminho FANTASMA (fora do template) nunca é conferido no relatório original (achado do
      // review, MEDIUM) — tem de aparecer exatamente uma vez, como OCIOSA.
      if (flags.ghost) {
        const occurrences = out.split(GHOST_REL).length - 1;
        if (occurrences !== 1) ok = false;
        if (!out.includes(`EXCEÇÃO OCIOSA: ${GHOST_REL}`)) ok = false;
      }
    }
  }
  rmSync(dir, { recursive: true, force: true });
  return ok;
};

const r = P.forAll([gState, gFlags], prop, { runs: 50, seed: 214101131 });
rmSync(pristine, { recursive: true, force: true });
if (!r.ok) {
  console.error(`FAIL [7]: propriedade falhou após ${r.runs} caso(s) (seed ${r.seed})`);
  console.error('  contraexemplo minimizado: ' + JSON.stringify(r.counterexample));
  if (r.error) console.error('  erro: ' + r.error);
  process.exit(1);
}
if (casesRun < 50) { console.error(`FAIL [7]: rodou só ${casesRun} caso(s), esperado >= 50`); process.exit(1); }
console.log(`OK [7] (${r.runs} casos, seed ${r.seed})`);
NODE_EOF
rc7=$?
[ "$rc7" -eq 0 ] || { echo "FAIL [7]: PBT reprovou (ver saída acima)"; exit 1; }

echo "PASS w214-update-exceptions-gate"
