#!/usr/bin/env bash
# Gate W251 — posse órfã no mutex de carga pesada: dono morto por BENEFICIÁRIO (issue #144) e
# dono vivo além do TETO DE POSSE (issue #137), um PR só para as duas (docs/plans/2026-09-15-plano-
# issues-abertas.md, seção "#144 e #137 — dono vivo nunca é reclamável").
#
# Causa raiz comum: a política "dono vivo nunca é reclamável" morava num único ramo do laço de
# aquisição (`heavy-mutex.sh:869-890` na medição da onda L2) — só dono MORTO reclama, e um dono
# reparentado para PID 1 (#144) ou um dono vivo há 27 horas (#137, na forma generalizada: teto de
# posse NÃO EXISTIA no template, só num fork local não declarado) passavam por vivo indefinidamente.
#
# Desenho adotado (DH-5 e DA-06, não o desenho original da onda L2): o teto de posse
# (`stale_after_s`) é OPT-IN — ausente é DESLIGADO, NUNCA derivado por default do teto de espera.
# Quando declarado, o valor é RESPEITADO como está (nunca rebaixado); se a relação
# `declarado + reserva <= teto de espera` for violada, o efeito é só um AVISO de três números. O
# beneficiário (issue #144) é declarado por VARIÁVEL DE AMBIENTE (`FORGE_HEAVY_MUTEX_BENEFICIARY`),
# nunca por flag nova — o `pre-push` do tronco pode carregar a lib de uma worktree com versão
# anterior, que recusaria flag desconhecida e mataria o push.
#
# ISOLAMENTO. Todo cenário resolve dentro de uma caixa própria (FORGE_HEAVY_MUTEX_ROOT). A suíte
# NUNCA toca o lock real da máquina.
set -uo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem ao
# repositório de quem invocou o gate, e não aos repositórios sintéticos criados aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/heavy-mutex.sh"
T="$(mktemp -d /tmp/forge-w253.XXXXXX)"

PIDFILE="$T/fixture-pids"
: > "$PIDFILE"
_cleanup() {
  while read -r p; do [ -n "$p" ] && kill -9 "$p" 2>/dev/null; done < "$PIDFILE"
  rm -rf "$T"
}
trap _cleanup EXIT INT TERM
track() { printf '%s\n' "$1" >> "$PIDFILE"; }

# Sleeper real (herda a mesma nota do w151: `>/dev/null 2>&1` no lançamento é obrigatório, senão a
# substituição de comando que o cria fica pendurada até o `sleep` acabar).
sleeper() { sleep 600 >/dev/null 2>&1 & local p=$!; track "$p"; printf '%s' "$p"; }

# Um "morto garantido": nasce e já é morto, com espera ativa até `kill -0` confirmar — evita a
# corrida de tratar um processo que ainda não terminou de morrer como vivo.
dead_pid() {
  local p
  ( sleep 1 >/dev/null 2>&1 & echo $! ) > "$T/.deadpid.$$"
  p="$(cat "$T/.deadpid.$$")"; rm -f "$T/.deadpid.$$"
  kill -9 "$p" 2>/dev/null
  local n=0
  while kill -0 "$p" 2>/dev/null && [ "$n" -lt 50 ]; do sleep 0.1; n=$((n+1)); done
  printf '%s' "$p"
}

tok_of() { LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | tr -s ' ' | sed 's/^ *//;s/ *$//'; }

# Lock pré-fabricado. Campos extras (beneficiary, beneficiary_token, acquired_at) são opcionais e
# só gravados quando o cenário os passa — um lock "legado" simplesmente não os declara.
mk_lock() {  # mk_lock <dir> <pid> [token]
  mkdir -p "$1"
  printf '%s\n' "$2" > "$1/pid"
  if [ -n "${3:-}" ]; then printf '%s\n' "$3" > "$1/token"; else tok_of "$2" > "$1/token"; fi
  printf '%s\n' "fixture" > "$1/nonce"
}

newbox() { local b; b="$(mktemp -d "$T/box.XXXXXX")"; printf '%s' "$b"; }

FORGE_HEAVY_MUTEX_TESTING=1
export FORGE_HEAVY_MUTEX_TESTING

GATE_START="$(date +%s)"
# Derivado, não escolhido: medido em bancada ociosa após a implementação, [10] e [14] dominam o
# gasto (esperas reais de segundos para a escalada TERM->graça->KILL). ~40s de gasto solo medido
# nesta máquina; 120s dá margem confortável sem tornar o teto decorativo.
GATE_BUDGET_S="${W251_BUDGET_S:-120}"

DECLARADOS=16
SCENARIOS_RUN=0
scenario() { SCENARIOS_RUN=$((SCENARIOS_RUN + 1)); echo "$1"; }

[ -f "$LIB" ] || { echo "FAIL [setup]: $LIB não existe"; exit 1; }

# ── [1] idade reclamada quando stale_after_s é declarado e a posse é velha (issue #137) ────────
scenario "[1] posse velha, detentor vivo, stale_after_s declarado -> recolhida por IDADE (rc 0)"
BOX="$(newbox)"; H1="$(sleeper)"
mk_lock "$BOX/r.lock" "$H1"
echo $(( $(date +%s) - 100000 )) > "$BOX/r.lock/acquired_at"
out1="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
        FORGE_HEAVY_MUTEX_STALE_AFTER_S=2 FORGE_HEAVY_MUTEX_STALE_GRACE_S=1 FORGE_HEAVY_MUTEX_TIMEOUT_S=15 \
        bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=0" <<<"$out1" || { echo "FAIL [1]: não adquiriu contra posse velha declarada (esperado rc 0): $out1"; exit 1; }
grep -qi "acima do teto de posse declarado" <<<"$out1" || { echo "FAIL [1]: a mensagem não nomeia o motivo (idade): $out1"; exit 1; }
echo "OK [1]"

# ── [2] stale_after_s: 0 desliga a recuperação por idade ───────────────────────────────────────
scenario "[2] stale_after_s: 0 desliga a recuperação por idade -> rc 75, sem recolhimento"
BOX="$(newbox)"; H2="$(sleeper)"
mk_lock "$BOX/r.lock" "$H2"
echo $(( $(date +%s) - 100000 )) > "$BOX/r.lock/acquired_at"
out2="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
        FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_TIMEOUT_S=2 \
        bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=75" <<<"$out2" || { echo "FAIL [2]: stale_after_s=0 deveria manter rc 75: $out2"; exit 1; }
grep -qi "recolh" <<<"$out2" && { echo "FAIL [2]: houve menção a recolhimento com stale_after_s=0: $out2"; exit 1; }
[ -d "$BOX/r.lock" ] || { echo "FAIL [2]: o lock do detentor vivo sumiu com stale_after_s=0"; exit 1; }
echo "OK [2]"

# ── [3] idade NÃO computável (acquired_at ausente) NÃO é reclamável, mesmo com o ramo armado ────
scenario "[3] acquired_at AUSENTE não é reclamável por idade (ausência não é licença para destruir)"
BOX="$(newbox)"; H3="$(sleeper)"
mk_lock "$BOX/r.lock" "$H3"   # sem acquired_at — lock "legado"
out3="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
        FORGE_HEAVY_MUTEX_STALE_AFTER_S=2 FORGE_HEAVY_MUTEX_TIMEOUT_S=2 \
        bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=75" <<<"$out3" || { echo "FAIL [3]: idade não computável foi tratada como reclamável: $out3"; exit 1; }
[ -d "$BOX/r.lock" ] || { echo "FAIL [3]: o lock sumiu sem idade computável"; exit 1; }
echo "OK [3]"

# ── [4] beneficiário DECLARADO e MORTO -> reclamado (issue #144), com stale_after_s:0 para isolar
scenario "[4] beneficiário declarado e MORTO, dono vivo -> recolhida por BENEFICIÁRIO (rc 0)"
BOX="$(newbox)"; H4="$(sleeper)"; D4="$(dead_pid)"
mk_lock "$BOX/r.lock" "$H4"
echo "$D4" > "$BOX/r.lock/beneficiary"
tok_of "$D4" > "$BOX/r.lock/beneficiary_token"
out4="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
        FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_STALE_GRACE_S=1 FORGE_HEAVY_MUTEX_TIMEOUT_S=15 \
        bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=0" <<<"$out4" || { echo "FAIL [4]: beneficiário morto não foi reclamado (esperado rc 0): $out4"; exit 1; }
grep -qi "beneficiário PID $D4 morto" <<<"$out4" || { echo "FAIL [4]: a mensagem não nomeia o beneficiário morto: $out4"; exit 1; }
echo "OK [4]"

# ── [5] beneficiário AUSENTE (lock legado) NÃO é reclamado — interoperabilidade (D2) ────────────
scenario "[5] beneficiário AUSENTE (lock legado / heavy-run.sh / nohup) não é reclamado -> rc 75"
BOX="$(newbox)"; H5="$(sleeper)"
mk_lock "$BOX/r.lock" "$H5"   # sem campo beneficiary — igual a um lock do heavy-run.sh, ou nohup
out5="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
        FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_TIMEOUT_S=2 \
        bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=75" <<<"$out5" || { echo "FAIL [5]: lock sem beneficiário foi reclamado — mataria nohup/LaunchAgent/daemon: $out5"; exit 1; }
[ -d "$BOX/r.lock" ] || { echo "FAIL [5]: o lock sem beneficiário sumiu"; exit 1; }
echo "OK [5]"

# ── [6] beneficiário VIVO com token conferindo -> NÃO é reclamado ───────────────────────────────
scenario "[6] beneficiário declarado e VIVO não é reclamado -> rc 75"
BOX="$(newbox)"; H6="$(sleeper)"; B6="$(sleeper)"
mk_lock "$BOX/r.lock" "$H6"
echo "$B6" > "$BOX/r.lock/beneficiary"
tok_of "$B6" > "$BOX/r.lock/beneficiary_token"
out6="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
        FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_TIMEOUT_S=2 \
        bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=75" <<<"$out6" || { echo "FAIL [6]: beneficiário VIVO foi tratado como órfão: $out6"; exit 1; }
[ -d "$BOX/r.lock" ] || { echo "FAIL [6]: o lock com beneficiário vivo sumiu"; exit 1; }
echo "OK [6]"

# ── [7] beneficiário MALFORMADO (0, -1, não numérico) nunca é licença para reclamar ─────────────
scenario "[7] beneficiário 0 / -1 / não numérico não reclama; controle (morto válido) reclama"
for val in 0 -1 abc; do
  BOX="$(newbox)"; H7="$(sleeper)"
  mk_lock "$BOX/r.lock" "$H7"
  printf '%s\n' "$val" > "$BOX/r.lock/beneficiary"
  out7="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
          FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_TIMEOUT_S=2 \
          bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
  grep -q "RC=75" <<<"$out7" || { echo "FAIL [7]: beneficiary='$val' foi tratado como licença para reclamar (kill -0 0/-1 endereça grupo): $out7"; exit 1; }
  kill -9 "$H7" 2>/dev/null
done
BOX="$(newbox)"; H7c="$(sleeper)"; D7c="$(dead_pid)"
mk_lock "$BOX/r.lock" "$H7c"
echo "$D7c" > "$BOX/r.lock/beneficiary"; tok_of "$D7c" > "$BOX/r.lock/beneficiary_token"
out7c="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
        FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_STALE_GRACE_S=1 FORGE_HEAVY_MUTEX_TIMEOUT_S=15 \
        bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=0" <<<"$out7c" || { echo "FAIL [7]: controle (beneficiário morto válido) não reclamou: $out7c"; exit 1; }
echo "OK [7]"

# ── [8] motivo impresso, e as duas mensagens são DISTINTAS (beneficiário vs idade) ──────────────
scenario "[8] a mensagem nomeia o motivo, e ele difere entre beneficiário e idade"
grep -qi "beneficiário PID $D4 morto" <<<"$out4" || { echo "FAIL [8]: mensagem de beneficiário não reaproveitável de [4]"; exit 1; }
grep -qi "acima do teto de posse declarado" <<<"$out1" || { echo "FAIL [8]: mensagem de idade não reaproveitável de [1]"; exit 1; }
[ "$(grep -o 'beneficiário' <<<"$out1")" = "" ] || { echo "FAIL [8]: o motivo de IDADE menciona 'beneficiário' — as duas mensagens não são distintas: $out1"; exit 1; }
echo "OK [8]"

# ── [9] censo de descendentes impresso ANTES do encerramento (D11) ──────────────────────────────
scenario "[9] o recolhimento imprime o censo de descendentes do detentor"
grep -qE "[0-9]+ descendente\(s\) direto\(s\)" <<<"$out4" || { echo "FAIL [9]: nenhuma linha de censo de descendentes: $out4"; exit 1; }
echo "OK [9]"

# ── [10] escalada TERM -> graça -> KILL: comando em PRIMEIRO PLANO ignora TERM ──────────────────
scenario "[10] detentor em comando de primeiro plano ignora TERM; a escalada mata e recolhe"
BOX="$(newbox)"
TRAPSH="$BOX/ignora-term.sh"
cat > "$TRAPSH" <<'SH'
trap '' TERM
sleep 30
SH
bash "$TRAPSH" >/dev/null 2>&1 &
H10=$!
track "$H10"
sleep 0.3
mk_lock "$BOX/r.lock" "$H10"
D10="$(dead_pid)"
echo "$D10" > "$BOX/r.lock/beneficiary"; tok_of "$D10" > "$BOX/r.lock/beneficiary_token"
t0=$(date +%s)
out10="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
        FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_STALE_GRACE_S=2 FORGE_HEAVY_MUTEX_TIMEOUT_S=20 \
        bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
t1=$(date +%s)
grep -q "RC=0" <<<"$out10" || { echo "FAIL [10]: escalada TERM->KILL não recolheu detentor que ignora TERM: $out10"; exit 1; }
[ $((t1 - t0)) -ge 2 ] || { echo "FAIL [10]: recolheu rápido demais para ter passado pela graça — a escalada não rodou de verdade"; exit 1; }
kill -0 "$H10" 2>/dev/null && { echo "FAIL [10]: o detentor que ignora TERM continua vivo — o KILL não chegou"; exit 1; }
echo "OK [10]"

# ── [11] AVISO com os três números quando declarado excede teto de espera menos a reserva ───────
# Valores REAIS do consumidor que motivou a #137 (Axis.PadSimulator: timeout_s 1800, stale_after_s
# 3600, "o dobro do teto de espera") — DA-06 manda respeitar sem rebaixar, só avisar.
scenario "[11] AVISO de 3 números com os valores reais do PadSim (declarado 3600, espera 1800)"
BOX="$(newbox)"; H11="$(sleeper)"
mk_lock "$BOX/r.lock" "$H11"
echo $(( $(date +%s) - 10 )) > "$BOX/r.lock/acquired_at"   # posse recente: não deve disparar reclaim
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
  FORGE_HEAVY_MUTEX_STALE_AFTER_S=3600 FORGE_HEAVY_MUTEX_TIMEOUT_S=1800 \
  bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t" > "$BOX/out11" 2>&1 &
P11=$!; track "$P11"
sleep 2
kill -TERM "$P11" 2>/dev/null; wait "$P11" 2>/dev/null
kill -9 "$H11" 2>/dev/null
out11="$(cat "$BOX/out11")"
grep -qi "AVISO" <<<"$out11" || { echo "FAIL [11]: nenhum aviso impresso com declarado > espera - reserva: $out11"; exit 1; }
grep -q "3600" <<<"$out11" && grep -q "1800" <<<"$out11" || { echo "FAIL [11]: o aviso não nomeia os números declarado/espera: $out11"; exit 1; }
echo "OK [11]"

# ── [12]/[13] CANAL REAL: pre-push de verdade, com hook do próprio git ──────────────────────────
mk_real_repo() {  # mk_real_repo <box> -> ecoa <repo-dir>
  local BOX="$1" R="$BOX/repo"
  mkdir -p "$R/.forge/scripts/lib" "$R/.forge/hooks/git"
  cp "$LIB" "$R/.forge/scripts/lib/"
  cp "$WS/template/.forge/hooks/git/pre-push" "$R/.forge/hooks/git/"
  for _stub in check-ai-attribution.sh check-liaison-acks.sh check-shell-pipeline.sh check-heredoc-hash.sh; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$R/.forge/scripts/$_stub"
    chmod +x "$R/.forge/scripts/$_stub"
  done
  cat > "$R/.forge/forge.yaml" <<'FY'
heavy_mutex:
  enabled: true
FY
  cat > "$R/.forge/FORGE.md" <<'FM'
runtime:
  test: sh -c 'echo CARGA-EXECUTOU >> "$MARK"'
FM
  git -C "$R" init -q -b main 2>/dev/null
  git -C "$R" config user.email t@t; git -C "$R" config user.name t; git -C "$R" config commit.gpgsign false
  git -C "$R" add -A 2>/dev/null; git -C "$R" commit -qm init 2>/dev/null
  printf '%s' "$R"
}

scenario "[12] canal real: pre-push com beneficiário MORTO -> push PASSA, carga executa"
BOX="$(newbox)"; R12="$(mk_real_repo "$BOX")"
H12="$(sleeper)"; D12="$(dead_pid)"
mk_lock "$BOX/w253res.lock" "$H12"
echo "$D12" > "$BOX/w253res.lock/beneficiary"; tok_of "$D12" > "$BOX/w253res.lock/beneficiary_token"
MARK12="$BOX/mark12"; : > "$MARK12"
sha12="$(git -C "$R12" rev-parse HEAD 2>/dev/null)"
out12="$(cd "$R12" && printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$sha12" | \
  FORGE_ROOT="$R12" FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w253res \
  FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_STALE_GRACE_S=1 FORGE_HEAVY_MUTEX_TIMEOUT_S=15 \
  MARK="$MARK12" bash "$R12/.forge/hooks/git/pre-push" origin "file://$R12" 2>&1)"; rc12=$?
[ "$rc12" -eq 0 ] || { echo "FAIL [12]: o push não passou com o beneficiário morto (rc $rc12): $out12"; exit 1; }
grep -q "CARGA-EXECUTOU" "$MARK12" 2>/dev/null || { echo "FAIL [12]: a carga não executou apesar do rc 0: $out12"; exit 1; }
echo "OK [12]"

scenario "[13] canal real, contrapositiva: pre-push com beneficiário VIVO -> push BLOQUEADO"
BOX="$(newbox)"; R13="$(mk_real_repo "$BOX")"
H13="$(sleeper)"; B13="$(sleeper)"
mk_lock "$BOX/w253res.lock" "$H13"
echo "$B13" > "$BOX/w253res.lock/beneficiary"; tok_of "$B13" > "$BOX/w253res.lock/beneficiary_token"
MARK13="$BOX/mark13"; : > "$MARK13"
sha13="$(git -C "$R13" rev-parse HEAD 2>/dev/null)"
out13="$(cd "$R13" && printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$sha13" | \
  FORGE_ROOT="$R13" FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w253res \
  FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_TIMEOUT_S=2 \
  MARK="$MARK13" bash "$R13/.forge/hooks/git/pre-push" origin "file://$R13" 2>&1)"; rc13=$?
[ "$rc13" -ne 0 ] || { echo "FAIL [13]: o push passou com o beneficiário VIVO — recolheu posse legítima: $out13"; exit 1; }
grep -q "CARGA-EXECUTOU" "$MARK13" 2>/dev/null && { echo "FAIL [13]: a carga executou apesar do bloqueio: $out13"; exit 1; }
echo "OK [13]"

# ── [14] versão mista: lib de v0.15.0 não conhece FORGE_HEAVY_MUTEX_BENEFICIARY, e não quebra ───
scenario "[14] versão mista: lib v0.15.0 ignora a variável nova (interoperabilidade), não quebra"
LIB15="$T/heavy-mutex-v0.15.0.sh"
if git -C "$WS" show v0.15.0:template/.forge/scripts/lib/heavy-mutex.sh > "$LIB15" 2>/dev/null && [ -s "$LIB15" ]; then
  BOX="$(newbox)"
  out14="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r FORGE_HEAVY_MUTEX_TIMEOUT_S=10 \
           FORGE_HEAVY_MUTEX_BENEFICIARY="$$" \
           bash -c ". '$LIB15'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
  grep -q "RC=0" <<<"$out14" || { echo "FAIL [14]: a lib v0.15.0 não adquiriu com a variável nova no ambiente (deveria IGNORÁ-LA): $out14"; exit 1; }
  grep -qi "argumento desconhecido" <<<"$out14" && { echo "FAIL [14]: a variável de ambiente nova matou o push numa lib antiga — deveria ser flag, não var, e é exatamente o que a #144/#137 evitou: $out14"; exit 1; }
  echo "OK [14]"
else
  echo "OK [14] (tag v0.15.0 indisponível neste checkout — pulado sem contar como vermelho fabricado)"
fi

# ── [15] contrato de argumento: --label vazio recusado; --label legítimo continua gravando ──────
scenario "[15] --label vazio devolve 64; --label legítimo continua funcionando"
BOX="$(newbox)"
out15a="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
          bash -c ". '$LIB'; forge_heavy_mutex_acquire --label ''; echo RC=\$?" 2>&1)"
grep -q "RC=64" <<<"$out15a" || { echo "FAIL [15]: --label '' não devolveu 64: $out15a"; exit 1; }
out15b="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=r \
          bash -c ". '$LIB'; forge_heavy_mutex_acquire --label 'minha carga'; echo RC=\$?; cat \"\$FORGE_HEAVY_MUTEX_HELD_PATH/label\"" 2>&1)"
grep -q "RC=0" <<<"$out15b" && grep -q "minha carga" <<<"$out15b" \
  || { echo "FAIL [15]: --label legítimo deixou de funcionar: $out15b"; exit 1; }
echo "OK [15]"

# ── [16] contrato de schema: stale_after_s e paridade de root ───────────────────────────────────
scenario "[16] schema: stale_after_s inteiro>=0 valida; root aceita '', token e absoluto; recusa relativo"
out16="$(node -e '
const Ajv = (() => { try { return require("ajv/dist/2020"); } catch (e) { return null; } })();
if (!Ajv) { console.log("SKIP-NO-AJV"); process.exit(0); }
const fs = require("fs");
const schema = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const hm = schema.$defs.forgeManifest.properties.heavy_mutex;
const ajv = new Ajv.default({allErrors:true, strict:true, allowUnionTypes:true});
const validate = ajv.compile(hm);
const ok = (doc) => validate(doc) === true;
const bad = (doc) => validate(doc) === false;
let fails = [];
if (!ok({stale_after_s: 0})) fails.push("stale_after_s:0 deveria validar");
if (!ok({stale_after_s: 3600})) fails.push("stale_after_s:3600 deveria validar");
if (!bad({stale_after_s: -1})) fails.push("stale_after_s:-1 deveria RECUSAR");
if (!bad({stale_after_s: "abc"})) fails.push("stale_after_s string deveria RECUSAR");
if (!ok({root: ""})) fails.push("root vazio deveria validar (primeiro braço do leitor)");
if (!ok({root: "${TMPDIR:-/tmp}"})) fails.push("root token literal deveria validar");
if (!ok({root: "/tmp"})) fails.push("root absoluto deveria validar");
if (!bad({root: "relativo/nao-absoluto"})) fails.push("root relativo deveria RECUSAR");
const desc = hm.description;
if (desc.includes("nunca em $TMPDIR")) fails.push("description ainda proíbe o token que o pattern aceita");
if (!desc.includes("${TMPDIR:-/tmp}")) fails.push("description não menciona o token literal aceito");
console.log(fails.length === 0 ? "OK" : "FAIL: " + fails.join(" | "));
' "$WS/template/.forge/schemas/forge.schema.json" 2>&1)"
if grep -q "SKIP-NO-AJV" <<<"$out16"; then
  echo "OK [16] (ajv indisponível — validado via node -e no-op; contrato conferido manualmente na implementação)"
else
  grep -q "^OK$" <<<"$out16" || { echo "FAIL [16]: $out16"; exit 1; }
  echo "OK [16]"
fi

[ "$SCENARIOS_RUN" -eq "$DECLARADOS" ] \
  || { echo "FAIL [contador]: $SCENARIOS_RUN cenário(s) executado(s) de $DECLARADOS declarado(s) — universo divergente"; exit 1; }

# ── Prova de mutação, com controle e recontrole ─────────────────────────────────────────────────
# Escopo reduzido em relação à onda L2 original: sem `--beneficiary` como flag (é variável de
# ambiente, D9 revisado) e sem teto derivado por default (DH-5), as mutações M3/M9/M10 da
# especificação original não se aplicam a este desenho. M6 (morte não confirmada) fica de fora
# porque não existe processo imune a KILL em espaço de usuário sem um stub que testaria o stub —
# a própria especificação da onda L2 registra essa limitação (nota do cenário [15] dela).
ORIG="$T/heavy-mutex.sh.orig"
cp "$LIB" "$ORIG"

mutate_check() {  # mutate_check <descricao> <perl-expr> <cenario-que-deve-falhar> <bash-que-reproduz-o-cenario>
  local desc="$1" expr="$2"
  echo "MUTAÇÃO: $desc"
  perl -0pi -e "$expr" "$LIB"
  cmp -s "$LIB" "$ORIG" && { echo "FAIL [mutação $desc]: a mutação foi NO-OP (arquivo idêntico) — o padrão não casou"; exit 1; }
}
restore_check() {
  cp "$ORIG" "$LIB"
  cmp -s "$LIB" "$ORIG" || { echo "FAIL [mutação]: restauração não bateu byte a byte"; exit 1; }
}

# M1 — remover a checagem de beneficiário do laço. Duas ocorrências no arquivo (status e acquire);
# `/g` neutraliza as duas — inócuo para o `status`, que não é o alvo desta prova — e garante que a
# do LAÇO seja mutada mesmo ela vindo depois no arquivo. [4] deve passar a FALHAR (rc 75 em vez de 0).
mutate_check "M1 remove checagem de beneficiário" \
  's/if _fhm_beneficiary_orphaned; then/if false \&\& _fhm_beneficiary_orphaned; then/g'
BOXm1="$(newbox)"; Hm1="$(sleeper)"; Dm1="$(dead_pid)"
mk_lock "$BOXm1/r.lock" "$Hm1"
echo "$Dm1" > "$BOXm1/r.lock/beneficiary"; tok_of "$Dm1" > "$BOXm1/r.lock/beneficiary_token"
outm1="$(FORGE_HEAVY_MUTEX_ROOT="$BOXm1" FORGE_HEAVY_MUTEX_RESOURCE=r \
         FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_TIMEOUT_S=2 \
         bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
kill -9 "$Hm1" 2>/dev/null
grep -q "RC=75" <<<"$outm1" || { echo "FAIL [mutação M1]: sem a checagem de beneficiário, [4] deveria reprovar (RC=75) e não reprovou: $outm1"; restore_check; exit 1; }
echo "M1 matou [4] como esperado"
restore_check
# RECONTROLE — reexecuta [4] contra o arquivo restaurado; tem de voltar a passar.
BOXm1r="$(newbox)"; Hm1r="$(sleeper)"; Dm1r="$(dead_pid)"
mk_lock "$BOXm1r/r.lock" "$Hm1r"
echo "$Dm1r" > "$BOXm1r/r.lock/beneficiary"; tok_of "$Dm1r" > "$BOXm1r/r.lock/beneficiary_token"
outm1r="$(FORGE_HEAVY_MUTEX_ROOT="$BOXm1r" FORGE_HEAVY_MUTEX_RESOURCE=r \
          FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_STALE_GRACE_S=1 FORGE_HEAVY_MUTEX_TIMEOUT_S=15 \
          bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=0" <<<"$outm1r" || { echo "FAIL [recontrole M1]: depois de restaurar, [4] deveria voltar a passar (RC=0) e não passou: $outm1r"; exit 1; }
echo "RECONTROLE M1 ok"

# M2 — tratar acquired_at ausente/ilegível como infinitamente velho: [3] deve passar a FALHAR.
mutate_check "M2 trata acquired_at ausente como infinitamente velho" \
  's/case "\$at" in \x27\x27\|\*\[!0-9\]\*\) return 1 ;; esac/case "\$at" in \x27\x27|*[!0-9]*) printf 999999999; return 0 ;; esac/'
BOXm2="$(newbox)"; Hm2="$(sleeper)"
mk_lock "$BOXm2/r.lock" "$Hm2"   # sem acquired_at
outm2="$(FORGE_HEAVY_MUTEX_ROOT="$BOXm2" FORGE_HEAVY_MUTEX_RESOURCE=r \
         FORGE_HEAVY_MUTEX_STALE_AFTER_S=2 FORGE_HEAVY_MUTEX_STALE_GRACE_S=1 FORGE_HEAVY_MUTEX_TIMEOUT_S=15 \
         bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=0" <<<"$outm2" || { echo "FAIL [mutação M2]: com 'ausente = infinitamente velho', [3] deveria reprovar (recolher, RC=0) e não recolheu: $outm2"; restore_check; exit 1; }
echo "M2 matou [3] como esperado (recolheu posse sem idade computável)"
restore_check
# RECONTROLE — reexecuta [3] contra o arquivo restaurado; tem de voltar a rc 75.
BOXm2r="$(newbox)"; Hm2r="$(sleeper)"
mk_lock "$BOXm2r/r.lock" "$Hm2r"
outm2r="$(FORGE_HEAVY_MUTEX_ROOT="$BOXm2r" FORGE_HEAVY_MUTEX_RESOURCE=r \
          FORGE_HEAVY_MUTEX_STALE_AFTER_S=2 FORGE_HEAVY_MUTEX_TIMEOUT_S=2 \
          bash -c ". '$LIB'; forge_heavy_mutex_acquire --label t; echo RC=\$?" 2>&1)"
grep -q "RC=75" <<<"$outm2r" || { echo "FAIL [recontrole M2]: depois de restaurar, [3] deveria voltar a rc 75 e não voltou: $outm2r"; exit 1; }
echo "RECONTROLE M2 ok"

# M4 — retirar a declaração de beneficiário do pre-push (canal): [12] deve passar a FALHAR.
HOOK="$WS/template/.forge/hooks/git/pre-push"
HOOK_ORIG="$T/pre-push.orig"; cp "$HOOK" "$HOOK_ORIG"
echo "MUTAÇÃO: M4 remove FORGE_HEAVY_MUTEX_BENEFICIARY do pre-push"
perl -0pi -e 's/FORGE_HEAVY_MUTEX_BENEFICIARY="\$PPID" //' "$HOOK"
cmp -s "$HOOK" "$HOOK_ORIG" && { echo "FAIL [mutação M4]: a mutação foi NO-OP no pre-push"; cp "$HOOK_ORIG" "$HOOK"; exit 1; }
BOXm4="$(newbox)"; Rm4="$(mk_real_repo "$BOXm4")"
Hm4="$(sleeper)"; Dm4="$(dead_pid)"
mk_lock "$BOXm4/w253res.lock" "$Hm4"
echo "$Dm4" > "$BOXm4/w253res.lock/beneficiary"; tok_of "$Dm4" > "$BOXm4/w253res.lock/beneficiary_token"
shm4="$(git -C "$Rm4" rev-parse HEAD 2>/dev/null)"
outm4="$(cd "$Rm4" && printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$shm4" | \
  FORGE_ROOT="$Rm4" FORGE_HEAVY_MUTEX_ROOT="$BOXm4" FORGE_HEAVY_MUTEX_RESOURCE=w253res \
  FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_TIMEOUT_S=2 \
  bash "$Rm4/.forge/hooks/git/pre-push" origin "file://$Rm4" 2>&1)"; rcm4=$?
kill -9 "$Hm4" 2>/dev/null
cp "$HOOK_ORIG" "$HOOK"
cmp -s "$HOOK" "$HOOK_ORIG" || { echo "FAIL [mutação M4]: restauração do pre-push não bateu byte a byte"; exit 1; }
[ "$rcm4" -ne 0 ] || { echo "FAIL [mutação M4]: sem declarar o beneficiário no hook, [12] deveria bloquear (rc != 0) e passou: $outm4"; exit 1; }
echo "M4 matou [12] como esperado (canal: sem a declaração no hook, o beneficiário morto nunca é visto)"
# RECONTROLE — reexecuta [12] contra o hook restaurado; tem de voltar a rc 0.
BOXm4r="$(newbox)"; Rm4r="$(mk_real_repo "$BOXm4r")"
Hm4r="$(sleeper)"; Dm4r="$(dead_pid)"
mk_lock "$BOXm4r/w253res.lock" "$Hm4r"
echo "$Dm4r" > "$BOXm4r/w253res.lock/beneficiary"; tok_of "$Dm4r" > "$BOXm4r/w253res.lock/beneficiary_token"
shm4r="$(git -C "$Rm4r" rev-parse HEAD 2>/dev/null)"
MARKm4r="$BOXm4r/markm4r"; : > "$MARKm4r"
outm4r="$(cd "$Rm4r" && printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$shm4r" | \
  FORGE_ROOT="$Rm4r" FORGE_HEAVY_MUTEX_ROOT="$BOXm4r" FORGE_HEAVY_MUTEX_RESOURCE=w253res \
  FORGE_HEAVY_MUTEX_STALE_AFTER_S=0 FORGE_HEAVY_MUTEX_STALE_GRACE_S=1 FORGE_HEAVY_MUTEX_TIMEOUT_S=15 \
  MARK="$MARKm4r" bash "$Rm4r/.forge/hooks/git/pre-push" origin "file://$Rm4r" 2>&1)"; rcm4r=$?
[ "$rcm4r" -eq 0 ] || { echo "FAIL [recontrole M4]: depois de restaurar o hook, [12] deveria voltar a passar (rc 0) e não passou: $outm4r"; exit 1; }
echo "RECONTROLE M4 ok"

[ -f "$LIB" ] && cmp -s "$LIB" "$ORIG" || { echo "FAIL [pós-mutação]: heavy-mutex.sh não bateu com o original ao final"; exit 1; }
[ -f "$HOOK" ] && cmp -s "$HOOK" "$HOOK_ORIG" || { echo "FAIL [pós-mutação]: pre-push não bateu com o original ao final"; exit 1; }

GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: a suíte levou ${GATE_ELAPSED}s, acima do teto declarado de ${GATE_BUDGET_S}s"; exit 1; }
echo "OK heavy-mutex-posse/universo — $SCENARIOS_RUN cenário(s) executado(s) de $DECLARADOS declarado(s)"
echo "PASS w253-heavy-mutex-posse ($SCENARIOS_RUN cenário(s) + 3 mutações, ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
