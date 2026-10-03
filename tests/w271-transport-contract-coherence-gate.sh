#!/usr/bin/env bash
# Gate W271 — a tabela de desfechos do cabeçalho de _common.sh confere com o comportamento real.
#
# POR QUE ESTE GATE EXISTE (issue #126). O cabeçalho de `_dir_push_classify`
# (template/.forge/scripts/lib/transports/_common.sh) dizia, para `behind`, que "recusar é a única
# saída — inclusive sob reparo" (entrou em `d7d4ad4`). O `case` real de `_dir_push` passou a UNIR
# em `a86fdd7` — e o comentário nunca acompanhou. Sem um gate que execute o código e confronte o
# resultado com o texto, o próximo editor lê o comentário, confia nele e reintroduz a mesma
# divergência (ou o oposto: "corrige" o código para bater com um comentário errado).
#
# O cabeçalho agora é uma TABELA com quatro desfechos exaustivos — `ff`, `equal`, `behind`,
# `diverged` — cada um com a ação que `_dir_push` de fato toma (`une` | `recusa`). Este gate:
#
#   [1] EXTRAI da tabela, em texto, a ação declarada para cada um dos quatro desfechos;
#   [2] EXECUTA o caso real (hub + log próprio sintéticos, direto contra `_dir_push`/
#       `_dir_push_classify`, sem depender de `liaison-ops.sh`) e observa o rc e o efeito no hub;
#   [3] CONFRONTA os dois — tabela e comportamento têm de bater nos quatro desfechos;
#   [4] MUTAÇÃO A — trocar "une" por "recusa" só no TEXTO da linha de `behind` (comentário,
#       código intocado) faz o confronto do desfecho `behind` reprovar;
#   [5] MUTAÇÃO B — trocar o `case 1` (behind) do CÓDIGO para `return 1` em vez de unir (texto
#       intocado) também faz o confronto reprovar — nos dois sentidos, não só quando o código
#       "parece" certo.
#
# PBT: não se aplica — quatro desfechos exaustivos e enumeráveis, não um espaço contínuo.
set -euo pipefail
# Isolamento git (LDG-0201): mesmo padrão dos demais gates de liaison/transporte.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w271.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

SELF=A

# Copia a árvore inteira de scripts (não só o arquivo) para que a resolução relativa de
# `liaison-push-union.mjs` a partir de `BASH_SOURCE[0]` dentro de `_common.sh` continue
# encontrando `lib/liaison-push-union.mjs` mesmo quando o arquivo sob teste é uma cópia mutada.
cp -R "$WS/template/.forge/scripts" "$T/scripts"
BASECOMMON="$T/scripts/lib/transports/_common.sh"
[ -f "$BASECOMMON" ] || { echo "FAIL: setup — cópia de _common.sh não existe em $BASECOMMON"; exit 1; }

# ── [1] extrai a ação declarada na tabela para <outcome> a partir do arquivo <file> ───────────
table_word() {
  local outcome="$1" file="$2"
  awk -v o="$outcome" '
    {
      line = $0
      sub(/^#[ \t]*/, "", line)
      n = split(line, cols, "|")
      if (n < 3) next
      key = cols[1]; gsub(/^[ \t]+|[ \t]+$/, "", key)
      if (key != o) next
      w = cols[n]
      gsub(/^[ \t]+|[ \t]+$/, "", w)
      gsub(/\*$/, "", w)
      sub(/[ \t]*\(.*\)$/, "", w)
      print w
      exit
    }
  ' "$file"
}

# ── [2] executa o caso real: escreve hub/own sintéticos e roda _dir_push contra <commonfile> ──
# stdout: "une" (rc 0) | "recusa" (rc != 0). Também deixa $T/scn-hub/log/$SELF.jsonl com o estado final
# do hub, para quem chama comparar conteúdo (perda/no-op) além da palavra.
run_push() {
  local commonfile="$1" hub_lines="$2" own_lines="$3"
  local hd="$T/scn-hub" od="$T/scn-own"
  rm -rf "$hd" "$od"
  mkdir -p "$hd/log" "$od/log"
  printf '%s\n' "$hub_lines" > "$hd/log/$SELF.jsonl"
  printf '%s\n' "$own_lines" > "$od/log/$SELF.jsonl"
  local rc=0
  (
    LIAISON_SELF="$SELF"
    LIAISON_CHANNEL_DIR="$od"
    export LIAISON_SELF LIAISON_CHANNEL_DIR
    # shellcheck source=/dev/null
    . "$commonfile"
    _dir_push "$hd"
  ) >"$T/push.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then echo "une"; else echo "recusa"; fi
  return 0
}

# classify puro (sem publicar), para conferir o TOKEN de stdout de _dir_push_classify em si.
classify_only() {
  local commonfile="$1" hub_lines="$2" own_lines="$3"
  local hd="$T/cls-hub" of="$T/cls-own.jsonl"
  rm -rf "$hd"; mkdir -p "$hd/log"
  printf '%s\n' "$hub_lines" > "$hd/log/$SELF.jsonl"
  printf '%s\n' "$own_lines" > "$of"
  (
    LIAISON_SELF="$SELF"
    # shellcheck source=/dev/null
    . "$commonfile"
    _dir_push_classify "$hd" "$of"
  )
}

# ── conteúdo sintético dos quatro desfechos ────────────────────────────────────────────────────
# `liaison-push-union.mjs` exige `sender == LIAISON_SELF` em toda linha (um escritor por arquivo)
# e usa `seq` para desempate/ordenação e para a chave de bifurcação `(sender, seq)` — por isso
# cada linha carrega os três campos, não só os dois que `_dir_push_classify` lê.
FF_HUB='{"msg_id":"m1","sender":"A","seq":1,"content_sha":"shaA000000000000000000000000000000000000000000000000000000"}'
FF_OWN='{"msg_id":"m1","sender":"A","seq":1,"content_sha":"shaA000000000000000000000000000000000000000000000000000000"}
{"msg_id":"m2","sender":"A","seq":2,"content_sha":"shaB000000000000000000000000000000000000000000000000000000"}'

EQ_HUB='{"msg_id":"m1","sender":"A","seq":1,"content_sha":"shaA000000000000000000000000000000000000000000000000000000"}'
EQ_OWN='{"msg_id":"m1","sender":"A","seq":1,"content_sha":"shaA000000000000000000000000000000000000000000000000000000"}'

BH_HUB='{"msg_id":"m1","sender":"A","seq":1,"content_sha":"shaA000000000000000000000000000000000000000000000000000000"}
{"msg_id":"m2","sender":"A","seq":2,"content_sha":"shaB000000000000000000000000000000000000000000000000000000"}'
BH_OWN='{"msg_id":"m1","sender":"A","seq":1,"content_sha":"shaA000000000000000000000000000000000000000000000000000000"}
{"msg_id":"m3","sender":"A","seq":3,"content_sha":"shaC000000000000000000000000000000000000000000000000000000"}'

DV_HUB='{"msg_id":"m1","sender":"A","seq":1,"content_sha":"shaA000000000000000000000000000000000000000000000000000000"}'
DV_OWN='{"msg_id":"m1","sender":"A","seq":1,"content_sha":"shaB000000000000000000000000000000000000000000000000000000"}'

n_examinados=0

# ── [ff] ────────────────────────────────────────────────────────────────────────────────────
echo "[ff] tabela declara vs. comportamento real"
tok_ff="$(classify_only "$BASECOMMON" "$FF_HUB" "$FF_OWN")" || true
[[ "$tok_ff" == ff ]] || { echo "FAIL [ff]: _dir_push_classify devolveu '$tok_ff', esperado 'ff'"; exit 1; }
cp "$T/scn-hub-baseline.jsonl" /dev/null 2>/dev/null || true
word_ff="$(run_push "$BASECOMMON" "$FF_HUB" "$FF_OWN")" || true
table_ff="$(table_word ff "$BASECOMMON")"
[ "$table_ff" = "une" ] || { echo "FAIL [ff]: tabela declara '$table_ff' para ff, esperado 'une'"; exit 1; }
[ "$word_ff" = "$table_ff" ] || { echo "FAIL [ff]: tabela diz '$table_ff', comportamento real é '$word_ff'"; exit 1; }
grep -q 'm2' "$T/scn-hub/log/$SELF.jsonl" || { echo "FAIL [ff]: hub não recebeu a mensagem exclusiva do local (união não publicou)"; exit 1; }
echo "OK [ff] — tabela='$table_ff', real='$word_ff', hub passou a conter m2"
n_examinados=$((n_examinados + 1))

# ── [equal] ─────────────────────────────────────────────────────────────────────────────────
echo "[equal] tabela declara vs. comportamento real (no-op)"
tok_eq="$(classify_only "$BASECOMMON" "$EQ_HUB" "$EQ_OWN")" || true
[[ "$tok_eq" == ff ]] || { echo "FAIL [equal]: _dir_push_classify devolveu '$tok_eq', esperado 'ff' (equal não tem token próprio)"; exit 1; }
antes_eq="$(printf '%s\n' "$EQ_HUB")"
word_eq="$(run_push "$BASECOMMON" "$EQ_HUB" "$EQ_OWN")" || true
depois_eq="$(cat "$T/scn-hub/log/$SELF.jsonl")"
table_eq="$(table_word equal "$BASECOMMON")"
[ "$table_eq" = "une" ] || { echo "FAIL [equal]: tabela declara '$table_eq' para equal, esperado 'une' (no-op)"; exit 1; }
[ "$word_eq" = "$table_eq" ] || { echo "FAIL [equal]: tabela diz '$table_eq', comportamento real é '$word_eq'"; exit 1; }
[ "$antes_eq" = "$depois_eq" ] || { echo "FAIL [equal]: hub mudou de conteúdo — não foi no-op"; exit 1; }
echo "OK [equal] — tabela='$table_eq', real='$word_eq', hub byte a byte igual (no-op)"
n_examinados=$((n_examinados + 1))

# ── [behind] ────────────────────────────────────────────────────────────────────────────────
echo "[behind] tabela declara vs. comportamento real"
tok_bh="$(classify_only "$BASECOMMON" "$BH_HUB" "$BH_OWN")" || true
[[ "$tok_bh" == behind* ]] || { echo "FAIL [behind]: _dir_push_classify devolveu '$tok_bh', esperado prefixo 'behind'"; exit 1; }
word_bh="$(run_push "$BASECOMMON" "$BH_HUB" "$BH_OWN")" || true
table_bh="$(table_word behind "$BASECOMMON")"
[ "$table_bh" = "une" ] || { echo "FAIL [behind]: tabela declara '$table_bh' para behind, esperado 'une'"; exit 1; }
[ "$word_bh" = "$table_bh" ] || { echo "FAIL [behind]: tabela diz '$table_bh', comportamento real é '$word_bh'"; exit 1; }
grep -q 'm2' "$T/scn-hub/log/$SELF.jsonl" || { echo "FAIL [behind]: mensagem que só o hub tinha (m2) foi perdida na união"; exit 1; }
grep -q 'm3' "$T/scn-hub/log/$SELF.jsonl" || { echo "FAIL [behind]: mensagem que só a réplica tinha (m3) não chegou ao hub"; exit 1; }
echo "OK [behind] — tabela='$table_bh', real='$word_bh', hub preserva m2 e ganha m3 (união, hub preservado)"
n_examinados=$((n_examinados + 1))

# ── [diverged] ──────────────────────────────────────────────────────────────────────────────
echo "[diverged] tabela declara vs. comportamento real"
tok_dv="$(classify_only "$BASECOMMON" "$DV_HUB" "$DV_OWN")" || true
[[ "$tok_dv" == diverged* ]] || { echo "FAIL [diverged]: _dir_push_classify devolveu '$tok_dv', esperado prefixo 'diverged'"; exit 1; }
word_dv="$(run_push "$BASECOMMON" "$DV_HUB" "$DV_OWN")" || true
table_dv="$(table_word diverged "$BASECOMMON")"
[ "$table_dv" = "recusa" ] || { echo "FAIL [diverged]: tabela declara '$table_dv' para diverged, esperado 'recusa'"; exit 1; }
[ "$word_dv" = "$table_dv" ] || { echo "FAIL [diverged]: tabela diz '$table_dv', comportamento real é '$word_dv'"; exit 1; }
cmp -s <(printf '%s\n' "$DV_HUB") "$T/scn-hub/log/$SELF.jsonl" || { echo "FAIL [diverged]: push recusado mas o hub foi alterado"; exit 1; }
echo "OK [diverged] — tabela='$table_dv', real='$word_dv', hub intacto"
n_examinados=$((n_examinados + 1))

# ── contador de controle de universo ────────────────────────────────────────────────────────
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w271/desfechos" "$n_examinados" "desfecho(s) confrontado(s)" "tabela x _common.sh" "$WS" \
  || { echo "FAIL: contador de controle de universo"; exit 1; }
set +e
out_vazio="$(forge_universe_check "w271/desfechos" 0 "desfecho(s)" "contrapositiva" "$WS" 2>&1)"; rc_vazio=$?
set -e
[ "$rc_vazio" -ne 0 ] || { echo "FAIL: universo vazio aprovou — $out_vazio"; exit 1; }
echo "OK — contador de controle: 0 desfecho(s) reprova, $n_examinados aprova"

# ── MUTAÇÃO A — só o TEXTO da linha de `behind` muda de "une" para "recusa" ────────────────
echo "[mutA] comentário mentiroso (behind: une -> recusa, código intocado) — confronto tem de reprovar"
cp -R "$T/scripts" "$T/scripts-mutA"
MUTA="$T/scripts-mutA/lib/transports/_common.sh"
perl -0777 -pi -e 's/(behind\s+\|[^\n]*NÃO tem\s+\|)\s*une(\s*)$/$1 recusa$2/m' "$MUTA"
grep -qE 'behind.*\|\s*recusa\s*$' "$MUTA" || { echo "FAIL [mutA]: a mutação de texto não foi aplicada — o alvo do perl não casou"; exit 1; }
cmp -s "$MUTA" "$BASECOMMON" && { echo "FAIL [mutA]: arquivo mutado é idêntico ao original"; exit 1; }
table_bh_mutA="$(table_word behind "$MUTA")"
[ "$table_bh_mutA" = "recusa" ] || { echo "FAIL [mutA]: extração da tabela não capturou a mutação (leu '$table_bh_mutA')"; exit 1; }
word_bh_mutA="$(run_push "$MUTA" "$BH_HUB" "$BH_OWN")" || true
[ "$word_bh_mutA" = "une" ] || { echo "FAIL [mutA]: o código mudou de comportamento sob a mutação de TEXTO — a mutação vazou para o comportamento"; exit 1; }
if [ "$table_bh_mutA" = "$word_bh_mutA" ]; then
  echo "FAIL [mutA]: o confronto NÃO detectou a divergência (tabela='$table_bh_mutA', real='$word_bh_mutA') — o gate está cego"
  exit 1
fi
echo "OK [mutA] — confronto reprovaria (tabela='$table_bh_mutA' x real='$word_bh_mutA'); mutação detectada"

# ── MUTAÇÃO B — o CÓDIGO do case 1 (behind) troca a união por recusa; texto intocado ────────
echo "[mutB] case 1 (behind) recusa em vez de unir, comentário intocado — confronto tem de reprovar"
cp -R "$T/scripts" "$T/scripts-mutB"
MUTB="$T/scripts-mutB/lib/transports/_common.sh"
perl -0777 -pi -e 's/      1\)\n(?:.*\n)*?        ;;\n/      1)\n        return 1\n        ;;\n/' "$MUTB"
cmp -s "$MUTB" "$BASECOMMON" && { echo "FAIL [mutB]: a mutação de código não alterou o arquivo — o alvo do perl não casou"; exit 1; }
ctx_mutb="$(grep -A1 '^      1)$' "$MUTB" || true)"
grep -q 'return 1' <<<"$ctx_mutb" || { echo "FAIL [mutB]: a mutação não produziu 'return 1' logo após o case 1"; exit 1; }
table_bh_mutB="$(table_word behind "$MUTB")"
[ "$table_bh_mutB" = "une" ] || { echo "FAIL [mutB]: o comentário mudou sob mutação de CÓDIGO — deveria estar intocado (leu '$table_bh_mutB')"; exit 1; }
word_bh_mutB="$(run_push "$MUTB" "$BH_HUB" "$BH_OWN")" || true
[ "$word_bh_mutB" = "recusa" ] || { echo "FAIL [mutB]: o case mutado ainda uniu (real='$word_bh_mutB') — a mutação não pegou o caminho certo"; exit 1; }
if [ "$table_bh_mutB" = "$word_bh_mutB" ]; then
  echo "FAIL [mutB]: o confronto NÃO detectou a divergência (tabela='$table_bh_mutB', real='$word_bh_mutB') — o gate está cego"
  exit 1
fi
echo "OK [mutB] — confronto reprovaria (tabela='$table_bh_mutB' x real='$word_bh_mutB'); mutação detectada"

# ── RECONTROLE — a cópia-base (não mutada) segue coerente depois das duas mutações acima ────
word_bh_recontrole="$(run_push "$BASECOMMON" "$BH_HUB" "$BH_OWN")" || true
table_bh_recontrole="$(table_word behind "$BASECOMMON")"
[ "$word_bh_recontrole" = "$table_bh_recontrole" ] \
  || { echo "FAIL [recontrole]: a base deixou de bater depois das mutações em cópias (contaminação entre cópias?)"; exit 1; }
echo "OK [recontrole] — base intocada segue coerente: tabela='$table_bh_recontrole', real='$word_bh_recontrole'"

echo "PASS w271-transport-contract-coherence"
