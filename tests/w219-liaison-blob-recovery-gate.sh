#!/usr/bin/env bash
# Gate W219 — o corpo perdido de uma mensagem já conhecida nunca voltava por sync (issue #107).
#
# Causa raiz: em `lib/liaison-import.mjs`, a cópia do blob referenciado por `body_ref` mora DENTRO
# do laço de mensagens NOVAS (`perSenderNew` -> `toAdd`). Mensagem já conhecida sai por `dup++;
# continue` na passada anterior e nunca alcança a cópia — uma réplica que perde um `body_ref` já
# aceito não o recupera por nenhum número de syncs seguintes, e o comando termina em `rc 0`.
#
# Fixture: hub e réplicas SINTÉTICOS num diretório temporário, nunca o hub real do projeto nem
# `.forge/liaison` deste repositório — cada réplica é `FORGE_ROOT` apontado para dentro de `$T`.
#
#   [1] positiva: blob apagado localmente de mensagem já conhecida volta depois de um `sync`,
#       byte-idêntico ao do hub, com a linha "recuperado" impressa
#   [2] controle: sem perda nenhuma, o `sync` NÃO imprime a linha de recuperação
#   [3] blob ausente nos DOIS lados (local e hub) gera WARN nomeando quantidade e msg_id, com
#       rc 0 (é aviso, não recusa — o import como um todo continua íntegro)
#   [4] PBT: para 50 subconjuntos gerados (semente fixa) de blobs apagados localmente sobre um
#       conjunto de 12 mensagens com corpo, depois de um `sync` TODO body_ref local cujo blob
#       existe no hub está de volta, byte-idêntico
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w219.XXXXXX")"
trap 'rm -rf "$T"' EXIT

HUB="$T/hub"

mk_repo() { # mk_repo <dir-name> — réplica sintética própria, nunca o repositório real
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/" || return 1
  cp -R "$WS/template/.forge/templates" "$dir/.forge/" || return 1
  git -C "$dir" init -q || return 1
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null || return 1
}

LG() { # LG <repo> <args...>
  local repo="$1"; shift
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"
}

QQ_BLOBS="$T/qq/.forge/liaison/ch/blobs"
HUB_BLOBS="$HUB/ch/blobs"

# blob_of <msg-id-no-log-de-pp> -> nome do arquivo de blob referenciado por essa mensagem, lido do
# log de pp já sincronizado em qq (fonte única, evita adivinhar o sha do conteúdo).
blob_name_for() { # blob_name_for <índice 0-based na ordem de publicação>
  node -e '
const fs = require("fs");
const [file, idxRaw] = process.argv.slice(1);
const idx = Number(idxRaw);
const lines = fs.readFileSync(file, "utf8").split("\n").filter((l) => l.trim());
const withBody = lines.map((l) => JSON.parse(l)).filter((m) => m.body_ref);
const m = withBody[idx];
if (!m) { process.exit(1); }
process.stdout.write(m.body_ref.slice("blobs/".length));
' "$T/qq/.forge/liaison/ch/log/pp.jsonl" "$1"
}

msg_id_for_blob() { # msg_id_for_blob <blob-name> — nomeia a mensagem dona de um blob (para o WARN)
  node -e '
const fs = require("fs");
const [file, blobName] = process.argv.slice(1);
const lines = fs.readFileSync(file, "utf8").split("\n").filter((l) => l.trim());
for (const l of lines) { const m = JSON.parse(l); if (m.body_ref === "blobs/" + blobName) { process.stdout.write(m.msg_id); process.exit(0); } }
process.exit(1);
' "$1" "$2"
}

# --- montagem: pp publica 12 mensagens com corpo, qq sincroniza e conhece todas -------------------
mk_repo pp || { echo "FAIL [setup]: não foi possível montar pp"; exit 1; }
mk_repo qq || { echo "FAIL [setup]: não foi possível montar qq"; exit 1; }

LG pp open ch --self pp --participants qq,pp >/dev/null || { echo "FAIL [setup]: open pp"; exit 1; }
LG pp transport set ch --kind fs --path "$HUB" >/dev/null || { echo "FAIL [setup]: transport pp"; exit 1; }
LG pp thread open ch t1 --subject "assunto" --participants qq,pp --body "abertura" >/dev/null \
  || { echo "FAIL [setup]: thread open"; exit 1; }

N_MSGS=12
for i in $(seq 1 "$N_MSGS"); do
  printf 'corpo de teste %d — conteúdo irrelevante, só precisa ser distinto\n' "$i" > "$T/corpo-$i.md"
  LG pp send ch --thread t1 --kind note --subject "corpo $i" --body-file "$T/corpo-$i.md" >/dev/null \
    || { echo "FAIL [setup]: send $i"; exit 1; }
done
LG pp sync ch >/dev/null || { echo "FAIL [setup]: sync pp"; exit 1; }

LG qq open ch --self qq --participants qq,pp >/dev/null || { echo "FAIL [setup]: open qq"; exit 1; }
LG qq transport set ch --kind fs --path "$HUB" >/dev/null || { echo "FAIL [setup]: transport qq"; exit 1; }
LG qq sync ch >/dev/null || { echo "FAIL [setup]: sync inicial qq"; exit 1; }

n_local0="$(ls "$QQ_BLOBS" 2>/dev/null | wc -l | tr -d ' ')"
[ "${n_local0:-0}" -eq "$N_MSGS" ] \
  || { echo "FAIL [setup]: qq deveria ter $N_MSGS blob(s) depois do sync inicial, tem ${n_local0:-0} — o cenário não reproduz a issue"; exit 1; }

echo "[1] blob apagado de mensagem já conhecida volta por sync, byte-idêntico ao hub, com a linha de recuperação"
B1="$(blob_name_for 0)" || { echo "FAIL [1]: não foi possível nomear o blob da mensagem 0"; exit 1; }
[ -f "$QQ_BLOBS/$B1" ] || { echo "FAIL [1]: pré-condição — blob $B1 deveria existir antes do apagamento"; exit 1; }
rm -f "$QQ_BLOBS/$B1"
out1="$(LG qq sync ch 2>&1)"; rc1=$?
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: sync de recuperação reprovou (rc $rc1): $out1"; exit 1; }
[ -f "$QQ_BLOBS/$B1" ] \
  || { echo "FAIL [1]: blob $B1 continua ausente depois do sync — mensagem já conhecida nunca recupera o corpo. Saída: $out1"; exit 1; }
cmp -s "$QQ_BLOBS/$B1" "$HUB_BLOBS/$B1" \
  || { echo "FAIL [1]: blob $B1 recuperado não é byte-idêntico ao do hub"; exit 1; }
grep -qi "recuperad" <<<"$out1" \
  || { echo "FAIL [1]: sync recuperou o blob mas não imprimiu nenhuma linha de recuperação. Saída: $out1"; exit 1; }
echo "OK [1]"

echo "[2] sem perda nenhuma, o sync não imprime linha de recuperação (controle)"
out2="$(LG qq sync ch 2>&1)"; rc2=$?
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: sync sem perda reprovou (rc $rc2): $out2"; exit 1; }
if grep -qi "recuperad" <<<"$out2"; then
  echo "FAIL [2]: sync sem blob perdido imprimiu linha de recuperação mesmo assim: $out2"; exit 1
fi
n_local2="$(ls "$QQ_BLOBS" 2>/dev/null | wc -l | tr -d ' ')"
[ "${n_local2:-0}" -eq "$N_MSGS" ] \
  || { echo "FAIL [2]: contagem de blobs mudou sem perda nenhuma: ${n_local2:-0}, esperado $N_MSGS"; exit 1; }
echo "OK [2]"

echo "[3] blob ausente nos DOIS lados vira WARN nomeando quantidade e msg_id, sem reprovar o sync"
B3="$(blob_name_for 1)" || { echo "FAIL [3]: não foi possível nomear o blob da mensagem 1"; exit 1; }
MSG3="$(msg_id_for_blob "$T/qq/.forge/liaison/ch/log/pp.jsonl" "$B3")" \
  || { echo "FAIL [3]: não foi possível nomear a mensagem dona do blob $B3"; exit 1; }
rm -f "$QQ_BLOBS/$B3" "$HUB_BLOBS/$B3"
out3="$(LG qq sync ch 2>&1)"; rc3=$?
[ "$rc3" -eq 0 ] \
  || { echo "FAIL [3]: blob ausente nos dois lados fez o sync reprovar (rc $rc3) — deveria ser aviso, não recusa: $out3"; exit 1; }
grep -q "WARN" <<<"$out3" \
  || { echo "FAIL [3]: nenhum WARN impresso com o blob ausente nos dois lados: $out3"; exit 1; }
grep -q "sem blob" <<<"$out3" \
  || { echo "FAIL [3]: o WARN não nomeia a ausência de blob: $out3"; exit 1; }
grep -q "$MSG3" <<<"$out3" \
  || { echo "FAIL [3]: o WARN não nomeia o msg_id sem blob ($MSG3): $out3"; exit 1; }
grep -qE "WARN:? 1 " <<<"$out3" \
  || { echo "FAIL [3]: o WARN não conta exatamente 1 body_ref sem blob: $out3"; exit 1; }
# republica o corpo para não contaminar os cenários seguintes (o hub perdeu o conteúdo de fato)
LG pp send ch --thread t1 --kind note --subject "corpo $B3 republicado" --body-file "$T/corpo-2.md" >/dev/null \
  || { echo "FAIL [3]: não foi possível republicar o corpo perdido"; exit 1; }
LG pp sync ch >/dev/null || { echo "FAIL [3]: sync de republicação (pp) reprovou"; exit 1; }
LG qq sync ch >/dev/null || { echo "FAIL [3]: sync de republicação (qq) reprovou"; exit 1; }
echo "OK [3]"

echo "[4] PBT — 50 subconjuntos gerados (semente 20260915) de blobs apagados localmente voltam por sync, byte-idênticos ao hub"
# Gerador determinístico: LCG numérico (semente fixa), sem dependência de RANDOM do bash. Reexecutar
# este trecho com a mesma semente produz exatamente os mesmos 50 subconjuntos — é o que torna o
# caso reproduzível fora desta sessão.
SEED=20260915
CASES="$(node -e '
let s = Number(process.argv[1]);
const n = Number(process.argv[2]);
const trials = Number(process.argv[3]);
function next() { s = (s * 1103515245 + 12345) & 0x7fffffff; return s; }
const lines = [];
for (let t = 0; t < trials; t++) {
  const idxs = [];
  for (let i = 0; i < n; i++) { if (next() % 3 === 0) idxs.push(i); } // ~1/3 apagado por rodada
  if (idxs.length === 0) idxs.push(next() % n); // rodada nunca vazia — senão não testaria nada
  lines.push(idxs.join(","));
}
process.stdout.write(lines.join("\n"));
' "$SEED" "$N_MSGS" 50)"

trial_no=0
while IFS= read -r idxs; do
  [ -n "$idxs" ] || continue
  trial_no=$((trial_no + 1))
  deleted_blobs=()
  IFS=',' read -ra idx_arr <<< "$idxs"
  for idx in "${idx_arr[@]}"; do
    bn="$(blob_name_for "$idx")" || { echo "FAIL [4]: trial $trial_no — não foi possível nomear o blob do índice $idx"; exit 1; }
    # só apaga se ainda existir localmente (uma mensagem pode ter sido escolhida antes e já
    # restaurada; apagar de novo é o caso normal do próximo trial)
    [ -f "$QQ_BLOBS/$bn" ] && rm -f "$QQ_BLOBS/$bn"
    deleted_blobs+=("$bn")
  done
  out4="$(LG qq sync ch 2>&1)"; rc4=$?
  [ "$rc4" -eq 0 ] || { echo "FAIL [4]: trial $trial_no (índices $idxs) — sync reprovou (rc $rc4): $out4"; exit 1; }
  for bn in "${deleted_blobs[@]}"; do
    [ -f "$QQ_BLOBS/$bn" ] \
      || { echo "FAIL [4]: trial $trial_no (índices $idxs) — blob $bn não voltou depois do sync"; exit 1; }
    cmp -s "$QQ_BLOBS/$bn" "$HUB_BLOBS/$bn" \
      || { echo "FAIL [4]: trial $trial_no (índices $idxs) — blob $bn voltou mas não é byte-idêntico ao hub"; exit 1; }
  done
done <<<"$CASES"
n_trials="$(printf '%s\n' "$CASES" | grep -c .)"
[ "${n_trials:-0}" -ge 50 ] \
  || { echo "FAIL [4]: só ${n_trials:-0} trial(s) executado(s) — a PBT exige ao menos 50 casos"; exit 1; }
n_final="$(ls "$QQ_BLOBS" 2>/dev/null | wc -l | tr -d ' ')"
[ "${n_final:-0}" -eq "$N_MSGS" ] \
  || { echo "FAIL [4]: ao final dos $n_trials trials, qq tem ${n_final:-0} blob(s), esperado $N_MSGS — algum não recuperou"; exit 1; }
echo "OK [4] ($n_trials trials, semente $SEED)"

echo "PASS w219-liaison-blob-recovery"
