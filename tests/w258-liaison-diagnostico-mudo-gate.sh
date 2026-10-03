#!/usr/bin/env bash
# Gate W258 — issue #108: o `ack` engolia a falha de avanço de cursor num `catch {}` vazio e
# imprimia "OK ack" como se nada tivesse acontecido; o `doctor` emudecia a seção inteira de
# liaison quando `liaison-ops.sh status` saía rc≠0 (`2>/dev/null || true` apagava o motivo junto
# com o erro).
#
#   [1] `ack` de mensagem de terceiro com `liaison-cursor.mjs` ausente: o cursor não avança, mas
#       o `catch` agora imprime `WARN: ack publicado, mas o cursor não avançou (<motivo>)` em
#       stderr com rc 0 — e o ack fica GRAVADO no log do ackador mesmo assim (positiva: o ato de
#       protocolo, que já tinha sido publicado ANTES do bloco try/catch, não é desfeito por um
#       efeito colateral que falhou depois).
#   [2] `doctor` com `liaison-ops.sh status` saindo rc≠0 (state.json corrompido) imprime
#       `✗ harness: LIAISON: status falhou — <primeira linha do erro>` em vez de sumir com a
#       seção inteira.
#   [3] `doctor` com `status` funcionando normalmente continua imprimindo a linha de sempre
#       (contrafactual — a correção não quebra o caminho feliz).
#   [4] mutação: esvaziar o `catch` de novo (cópia isolada de liaison-ops.sh, nunca o arquivo
#       real) faz o WARN do cenário [1] desaparecer — controle e recontrole por `cmp -s`.
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem
# ao repositório de quem invocou o gate, e não aos repositórios sintéticos criados aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w258.XXXXXX)"
trap 'rm -rf "$T"' EXIT
FAIL=0

CH=contracts-fare
TH=fare-grpc-v1

mk_repo() { # mk_repo <nome> — cópia completa o bastante para o doctor não tropeçar em ausência
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  for d in scripts templates hooks schemas rules commands agents skills adapters contracts; do
    [ -d "$WS/template/.forge/$d" ] && cp -R "$WS/template/.forge/$d" "$dir/.forge/"
  done
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  cp "$WS/template/.forge/FORGE.md" "$dir/.forge/FORGE.md" 2>/dev/null || true
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null
}

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }

mk_repo gc
mk_repo fv
mk_repo a
LG gc open "$CH" --self axis-go-cloud --participants axis-go-cloud,axis-fare-validator >/dev/null
LG fv open "$CH" --self axis-fare-validator --participants axis-go-cloud,axis-fare-validator >/dev/null
LG a  open "$CH" --self axis-go-cloud --participants axis-go-cloud,axis-fare-validator >/dev/null
LG gc thread open "$CH" "$TH" --subject "abertura" --participants axis-go-cloud,axis-fare-validator --body "abertura" >/dev/null
mkdir -p "$T/bundle0"; LG gc export "$CH" --out "$T/bundle0" >/dev/null
LG fv import "$CH" --from "$T/bundle0" >/dev/null

echo "[1] catch avisa em stderr quando o cursor não avança, e o ack fica gravado mesmo assim"
MSGID1="$(LG gc send "$CH" --thread "$TH" --kind note --subject "pede confirmação" --body "confirma X" --requires-ack)"
MSGID1="${MSGID1#*— }"; MSGID1="${MSGID1%% *}"
mkdir -p "$T/bundle1"; LG gc export "$CH" --out "$T/bundle1" >/dev/null
LG fv import "$CH" --from "$T/bundle1" >/dev/null
CURSOR_MJS="$T/fv/.forge/scripts/lib/liaison-cursor.mjs"
[ -f "$CURSOR_MJS" ] || { echo "FAIL [1]: fixture não tem liaison-cursor.mjs — setup mudou, ajuste o gate"; exit 1; }
mv "$CURSOR_MJS" "$CURSOR_MJS.hidden"
set +e
ACK1_OUT="$(LG fv ack "$CH" "$MSGID1" 2>&1)"; RC1=$?
set -e
mv "$CURSOR_MJS.hidden" "$CURSOR_MJS"
if [ "$RC1" -ne 0 ]; then
  echo "FAIL [1]: ack saiu rc=$RC1 (deveria ser rc 0 — o ato de protocolo já tinha publicado): $ACK1_OUT"
  FAIL=1
elif ! grep -qi "WARN: ack publicado, mas o cursor não avançou" <<<"$ACK1_OUT"; then
  echo "FAIL [1]: WARN ausente: $ACK1_OUT"
  FAIL=1
elif ! grep -q "OK ack" <<<"$ACK1_OUT"; then
  echo "FAIL [1]: a confirmação normal do ack sumiu: $ACK1_OUT"
  FAIL=1
else
  ACK1_LINE="$(grep "OK ack" <<<"$ACK1_OUT")"
  ACK1_ID="${ACK1_LINE#*— }"; ACK1_ID="${ACK1_ID%% *}"
  if ! grep -q "\"msg_id\":\"$ACK1_ID\"" "$T/fv/.forge/liaison/$CH/log/axis-fare-validator.jsonl"; then
    echo "FAIL [1]: ack '$ACK1_ID' não ficou gravado no log — o ato deveria ter publicado apesar do WARN"
    FAIL=1
  else
    echo "OK [1]"
  fi
fi

echo "[2] doctor com 'liaison status' falhando nomeia o motivo em vez de sumir com a seção"
STATE_JSON="$T/fv/.forge/liaison/$CH/state.json"
[ -f "$STATE_JSON" ] || { echo "FAIL [2]: fixture não tem state.json — setup mudou, ajuste o gate"; exit 1; }
cp "$STATE_JSON" "$T/state.json.bak"
printf '{ isto não é json' > "$STATE_JSON"
set +e
DOUT2="$(cd "$T/fv" && FORGE_ROOT="$T/fv" bash "$T/fv/.forge/scripts/doctor.sh" 2>&1)"
set -e
cp "$T/state.json.bak" "$STATE_JSON"
if ! grep -qE '✗.*LIAISON: status falhou' <<<"$DOUT2"; then
  echo "FAIL [2]: doctor não nomeou a falha de 'liaison status': "
  grep -i liaison <<<"$DOUT2" || echo "  (nenhuma linha de liaison no relatório — a seção sumiu em silêncio)"
  FAIL=1
else
  echo "OK [2]"
fi

echo "[3] doctor com 'liaison status' normal continua imprimindo a linha de sempre (contrafactual)"
set +e
DOUT3="$(cd "$T/a" && FORGE_ROOT="$T/a" bash "$T/a/.forge/scripts/doctor.sh" 2>&1)"
set -e
if ! grep -qE '·.*harness: LIAISON' <<<"$DOUT3"; then
  echo "FAIL [3]: doctor não imprimiu a linha normal de liaison com estado saudável: "
  grep -i liaison <<<"$DOUT3" || echo "  (nenhuma linha de liaison)"
  FAIL=1
elif grep -qE '✗.*LIAISON' <<<"$DOUT3"; then
  echo "FAIL [3]: doctor marcou liaison saudável como falha: $DOUT3"
  FAIL=1
else
  echo "OK [3]"
fi

echo "[4] mutação: esvaziar o catch de novo faz o WARN do cenário [1] desaparecer"
LIAISON_SRC="$WS/template/.forge/scripts/liaison-ops.sh"
LIAISON_MUT="$T/liaison-ops-mutated.sh"
cp "$LIAISON_SRC" "$LIAISON_MUT"
# A mesma classe de defeito da issue: troca o corpo do catch por um bloco vazio, byte a byte
# equivalente ao estado ANTES desta correção. perl com aspas simples (nunca com $ interpolado do
# lado direito — LDG-0164) para não depender de como o shell expande a substituição.
perl -0pi -e 's/\} catch \(e\) \{.*?\n    \}/} catch { \/* mutado: catch vazio de novo, issue #108 *\/ }/s' "$LIAISON_MUT"
if ! grep -q 'catch { /\* mutado: catch vazio de novo, issue #108 \*/ }' "$LIAISON_MUT"; then
  echo "FAIL [4]: a mutação não pegou — ajuste o padrão do perl (o gate não pode alegar prova de mutação sem ela ter acontecido)"
  FAIL=1
else
  # O mutante precisa rodar DE DENTRO de .forge/scripts/ — a resolução de `lib/forge-root.sh` e
  # companhia é relativa ao próprio caminho do script, nunca ao cwd. Substitui o arquivo no
  # lugar (repo sintético "fv", descartável) em vez de invocar a cópia solta em $T.
  LIAISON_REAL_FV="$T/fv/.forge/scripts/liaison-ops.sh"
  cp "$LIAISON_REAL_FV" "$T/liaison-ops-fv-original.sh"
  cp "$LIAISON_MUT" "$LIAISON_REAL_FV"
  mv "$CURSOR_MJS" "$CURSOR_MJS.hidden"
  set +e
  ACK4_OUT="$(LG fv ack "$CH" "$MSGID1" --subject "reack pos-mutacao" 2>&1)"; RC4=$?
  set -e
  mv "$CURSOR_MJS.hidden" "$CURSOR_MJS"
  cp "$T/liaison-ops-fv-original.sh" "$LIAISON_REAL_FV"
  if [ "$RC4" -ne 0 ]; then
    echo "FAIL [4]: mutante saiu rc=$RC4 — o gate espera que o ack continue publicando (só o WARN some): $ACK4_OUT"
    FAIL=1
  elif grep -qi "WARN: ack publicado" <<<"$ACK4_OUT"; then
    echo "FAIL [4]: o mutante (catch vazio) ainda imprimiu o WARN — o gate não está medindo o mecanismo certo"
    FAIL=1
  else
    echo "  ok: mutante reintroduz o silêncio (WARN ausente), confirmando que o gate mede o catch certo"
  fi
  # recontrole: cópia intocada continua idêntica ao arquivo real
  if ! cmp -s "$LIAISON_SRC" "$WS/template/.forge/scripts/liaison-ops.sh"; then
    echo "FAIL [4]: recontrole — o arquivo real do template mudou durante o teste (não deveria)"
    FAIL=1
  else
    echo "OK [4]"
  fi
fi

if [ "$FAIL" -ne 0 ]; then
  echo "GATE W258: FAIL"
  exit 1
fi
echo "PASS w258-liaison-diagnostico-mudo-gate"
