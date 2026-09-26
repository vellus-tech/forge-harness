#!/usr/bin/env bash
# Gate W224 — issues #132 e #134: push de deleção pura roda typecheck, test, os gates de
# runtime.gates e harness-tests por inteiro, para uma operação que não publica árvore nenhuma.
#
# Causa raiz comum, provada nas duas issues: `run_check "typecheck"`/`run_check "test"`, o bloco
# de `runtime.gates` e o bloco de `harness-tests` do `pre-push` do template rodam incondicionalmente
# — não existia curto-circuito nenhum para `local_sha` zero (deleção de ref, contrato do próprio
# git). #132 mede isso via patch de consumidor (sentinela `_viu_ref`, ausente no template) sob um
# mutex de suíte pesada compartilhado; #134 mede via 25 deleções reais, cada uma pagando a suíte
# inteira.
#
# Desenho (DA-10): três estados de stdin, nunca dois — vazio, só deleções, misto. Só em "só
# deleções" o hook pula typecheck/test/gates/harness-tests, com a linha nominal "pre-push: push de
# deleção pura (N ref(s)) — checks de árvore não se aplicam". Vazio e misto continuam rodando tudo
# — entrada vazia não pode ser lida como "todas as refs são seguras" (issue #49), e uma ref
# publicando conteúdo no mesmo push exige os checks por inteiro. Nenhum gate de `runtime.gates`
# roda num push de deleção pura, inclusive um eventual gate de consumidor que dependa de ver a
# deleção; a política de ref PROTEGIDA fica fora deste curto-circuito, de propósito, e é
# server-side (`develop` com `strict: true`) — roadmap de uma política própria no hook na Onda 8.
#
# A classificação roda ANTES do preflight de pré-condições de worktree (issue #81) e do mutex de
# carga pesada (issue #52) — não só antes de typecheck/test/gates/harness-tests. Sem isso, uma
# deleção pura continuava pagando fila do mutex e exigência de dependências instaladas, que é
# exatamente o custo que #132 e #134 medem: [7]/[8] cobrem essa regressão.
#
# Canal: stdin piped diretamente ao script do hook (mesmo padrão de w97/w135/w146/w147/w151/w160 e
# do w223, que é o predecessor imediato desta cadeia — #141 já resolve o canal de delegação entre
# árvores; aqui o que está sob teste é lógica interna do próprio script, não o canal de resolução).
#
#   [1] positiva — só deleções (2 refs): marker vazio (typecheck/test/gate/harness-tests NÃO
#       rodam) e a linha nominal, com a contagem certa, aparece
#   [2] contrafactual — stdin vazio: marker com os quatro sinais (tudo roda), sem a linha nominal
#   [3] contrafactual — misto (1 deleção + 1 publicação): marker com os quatro sinais, sem a linha
#       nominal — uma única ref com conteúdo no push basta para não pular nada
#   [4] PBT (semente fixa, LCG próprio — reproduz em qualquer bash, ver nota abaixo — 50 casos
#       estratificados): para listas geradas de 0 a 6 linhas de ref, cada uma deleção ou
#       publicação, em ordem aleatória, a suíte roda se e somente se a lista é vazia ou contém ao
#       menos uma linha com `local_sha` não zero; nos casos de só-deleção, a contagem N da linha
#       nominal bate com o número de linhas
#   [5] mutação — remover o curto-circuito: o cenário [1] passa a gravar o marker (a suíte volta a
#       rodar em push de deleção pura); recontrole com `cmp -s` restaura e [1] volta a passar
#   [6] mutação — tratar entrada vazia como deleção: o cenário [2] passa a pular a suíte (marker
#       vazio); recontrole com `cmp -s` restaura e [2] volta a passar
#   [7] HIGH regressão — mutex de carga pesada (issue #52) disputado por um dono externo: deleção
#       pura adquire e sai rc 0 sem entrar na fila (sem "AGUARDANDO"), enquanto um push misto sob o
#       mesmo dono espera e estoura o teto (rc 75, "AGUARDANDO"/"TIMEOUT") — heavy_mutex isolado por
#       FORGE_HEAVY_MUTEX_ROOT/TESTING, nunca o lock real da máquina
#   [8] mutação — reintroduzir a aquisição do mutex antes do curto-circuito: o cenário [7] passa a
#       esperar/estourar o teto também na deleção pura; recontrole com `cmp -s` restaura
#   [9] MEDIUM regressão — preflight de pré-condições de worktree (issue #81) com `package.json`
#       declarando dependências e sem `node_modules`: deleção pura sai rc 0 sem o BLOQUEADO do #81,
#       enquanto um push misto continua BLOQUEADO (mutex desligado, isola a variável sob teste)
#   [10] contador de controle: zero cenário executado reprova
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w224.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

ZERO=0000000000000000000000000000000000000000
MARK="$T/marker"
SCEN=0

# ── fixture ───────────────────────────────────────────────────────────────────────────────────
# Repositório com typecheck, test, um gate de runtime.gates e um harness-test próprio, os quatro
# instrumentados para gravar um sinal no MARKER — que mora fora do repositório, para que "rodou" e
# "não rodou" nunca dependam de `git status` da fixture. `.forge/` fica fora do controle de versão
# (mesmo padrão do w190): os hooks leem `.forge/` do disco, nunca do índice, e versioná-la só
# multiplicaria o custo do lint de shell (LDG-0069) sobre ~200 `.sh` do template sem provar nada
# sobre este gate.
R="$T/repo"
mkdir -p "$R"
cp -R "$WS/template/.forge" "$R/.forge"
cat > "$R/.forge/FORGE.md" <<EOF
---
forge_version: 1
project:
  name: w224fixture
runtime:
  typecheck: printf 'RODOU-TYPECHECK\n' >> "$MARK"
  test: printf 'RODOU-TEST\n' >> "$MARK"
  gates: w224marker
---

# FORGE.md — w224fixture
EOF
cat > "$R/.forge/scripts/w224marker.sh" <<EOF
#!/usr/bin/env bash
printf 'RODOU-GATE\n' >> "$MARK"
exit 0
EOF
chmod +x "$R/.forge/scripts/w224marker.sh"
cat > "$R/.forge/scripts/tests/w224marker-test.sh" <<EOF
#!/usr/bin/env bash
printf 'RODOU-HARNESS\n' >> "$MARK"
exit 0
EOF
chmod +x "$R/.forge/scripts/tests/w224marker-test.sh"
printf '.forge/\n' > "$R/.gitignore"
printf '# w224fixture\n' > "$R/README.md"
printf '# Changelog\n\n## [Unreleased]\n' > "$R/CHANGELOG.md"
git -C "$R" init -q -b main
git -C "$R" config user.email w224@t
git -C "$R" config user.name w224
git -C "$R" config commit.gpgsign false
git -C "$R" add -A >/dev/null
git -C "$R" commit -q --no-verify -m "fixture w224"
SHA="$(git -C "$R" rev-parse HEAD)"

push_out() {  # push_out <stdin-feed> — invoca o pre-push pelo canal real (stdin de refs)
  printf '%s' "$1" | (cd "$R" && bash "$R/.forge/hooks/git/pre-push" origin "file://$R" 2>&1)
}

marker_tokens() {  # marker_tokens -> lista os sinais gravados no marker (ordenados, sem duplicar)
  [ -f "$MARK" ] || { printf ''; return 0; }
  sort -u "$MARK" | tr '\n' ' '
}

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] positiva — só deleções (2 refs): checks de árvore NÃO rodam"
: > "$MARK"
feed1="$(printf '(delete) %s refs/heads/velha1 %s\n(delete) %s refs/heads/velha2 %s\n' "$ZERO" "$SHA" "$ZERO" "$SHA")"
out1="$(push_out "$feed1")"; rc1=$?
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: pre-push reprovou push de deleção pura (rc=$rc1) — saída:"; echo "$out1"; exit 1; }
case "$out1" in *"push de deleção pura (2 ref(s)) — checks de árvore não se aplicam"*) : ;; *)
  echo "FAIL [1]: a linha nominal com a contagem certa não apareceu — saída:"; echo "$out1"; exit 1 ;;
esac
tok1="$(marker_tokens)"
[ -z "$tok1" ] || { echo "FAIL [1]: marker não deveria ter sinal nenhum (typecheck/test/gate/harness-tests pulados) — gravou: '$tok1'"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [1] — marker vazio, linha nominal presente"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] contrafactual — stdin vazio: tudo roda"
: > "$MARK"
out2="$(push_out "")"; rc2=$?
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: pre-push reprovou com stdin vazio (rc=$rc2) — saída:"; echo "$out2"; exit 1; }
case "$out2" in *"deleção pura"*) echo "FAIL [2]: entrada vazia não pode virar 'deleção pura' (DA-10) — saída:"; echo "$out2"; exit 1 ;; esac
tok2="$(marker_tokens)"
for want in RODOU-TYPECHECK RODOU-TEST RODOU-GATE RODOU-HARNESS; do
  case " $tok2 " in *" $want "*) : ;; *) echo "FAIL [2]: '$want' ausente do marker (esperava tudo rodando) — gravou: '$tok2'"; exit 1 ;; esac
done
SCEN=$((SCEN + 1))
echo "OK [2] — os quatro sinais gravados, sem a linha de deleção pura"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] contrafactual — misto (1 deleção + 1 publicação): tudo roda"
: > "$MARK"
feed3="$(printf '(delete) %s refs/heads/velha %s\nrefs/heads/main %s refs/heads/main %s\n' "$ZERO" "$SHA" "$SHA" "$ZERO")"
out3="$(push_out "$feed3")"; rc3=$?
[ "$rc3" -eq 0 ] || { echo "FAIL [3]: pre-push reprovou push misto (rc=$rc3) — saída:"; echo "$out3"; exit 1; }
case "$out3" in *"deleção pura"*) echo "FAIL [3]: push misto não pode pular como deleção pura — saída:"; echo "$out3"; exit 1 ;; esac
tok3="$(marker_tokens)"
for want in RODOU-TYPECHECK RODOU-TEST RODOU-GATE RODOU-HARNESS; do
  case " $tok3 " in *" $want "*) : ;; *) echo "FAIL [3]: '$want' ausente do marker em push misto — gravou: '$tok3'"; exit 1 ;; esac
done
SCEN=$((SCEN + 1))
echo "OK [3] — os quatro sinais gravados em push misto"

# ── [4] PBT ──────────────────────────────────────────────────────────────────────────────────
# Propriedade: para uma lista de 0 a 6 linhas de ref, cada uma deleção (local_sha zero) ou
# publicação (local_sha != zero), em ordem aleatória, a suíte roda (marker não vazio) SE E SOMENTE
# SE a lista é vazia OU contém ao menos uma linha de publicação; nos casos de só-deleção, a
# contagem N na linha nominal bate com o número de linhas do caso.
#
# LCG PRÓPRIO, nunca `$RANDOM`: `$RANDOM` muda de gerador entre versões do bash (medido: bash 3.2
# local e bash 5.1+ do CI produzem sequências DIFERENTES para a mesma semente), o que torna a
# "semente fixa" reprodutível só na máquina que a mediu. Um LCG (Numerical Recipes: a=1103515245,
# c=12345, m=2^31) em aritmética inteira do próprio shell reproduz IDÊNTICO em qualquer bash.
SEED=20260926
LCG_A=1103515245
LCG_C=12345
LCG_M=2147483648  # 2^31
_lcg_state=$SEED
lcg_next() {  # atualiza _lcg_state e ecoa um inteiro em [0, LCG_M)
  _lcg_state=$(( (LCG_A * _lcg_state + LCG_C) % LCG_M ))
  printf '%s' "$_lcg_state"
}

# Estratificação: os 50 casos sem estratificar (achado LOW da rodada anterior) deram só 4 casos de
# "só-deleção" — a classe que a issue #132/#134 introduz — porque n=0 e n>0-com-publicação dominam
# o espaço uniforme. Os primeiros 12 casos forçam n=0 (vazio); os 12 seguintes forçam "só-deleção"
# com 1-6 linhas; os 26 restantes ficam livres (podem cair em qualquer classe, inclusive as duas
# forçadas) — garante >=12 casos de cada classe crítica sem abrir mão da aleatoriedade do resto.
echo "[4] PBT — 50 casos gerados (semente $SEED, LCG próprio, estratificado), lista de 0-6 linhas deleção/publicação"
pbt_n=50
pbt_falhas=0
for case_i in $(seq 1 "$pbt_n"); do
  if [ "$case_i" -le 12 ]; then
    n=0; forcar_so_delecao=0
  elif [ "$case_i" -le 24 ]; then
    n=$(( 1 + $(lcg_next) % 6 )); forcar_so_delecao=1
  else
    n=$(( $(lcg_next) % 7 )); forcar_so_delecao=0
  fi
  feed=""
  publica=0
  # `seq 1 "$n"` com n=0 no BSD/macOS conta PARA BAIXO ("1", "0") em vez de devolver vazio (GNU) —
  # loop C-style, sem `seq`, para não reintroduzir o footgun de portabilidade do w97.
  line_i=1
  while [ "$line_i" -le "$n" ]; do
    if [ "$forcar_so_delecao" -eq 1 ]; then
      tipo=0
    else
      tipo=$(( $(lcg_next) % 2 ))     # 0=deleção 1=publicação
    fi
    if [ "$tipo" -eq 0 ]; then
      feed="${feed}(delete) $ZERO refs/heads/r${case_i}_${line_i} $SHA
"
    else
      feed="${feed}refs/heads/r${case_i}_${line_i} $SHA refs/heads/r${case_i}_${line_i} $ZERO
"
      publica=1
    fi
    line_i=$((line_i + 1))
  done
  esperado_roda=1
  [ "$n" -gt 0 ] && [ "$publica" -eq 0 ] && esperado_roda=0
  : > "$MARK"
  outp="$(push_out "$feed")"; rcp=$?
  if [ "$rcp" -ne 0 ]; then
    echo "FAIL [4]: caso $case_i (n=$n, publica=$publica) reprovou (rc=$rcp) — saída:"; echo "$outp"
    pbt_falhas=$((pbt_falhas + 1)); continue
  fi
  tokp="$(marker_tokens)"
  if [ "$esperado_roda" -eq 1 ]; then
    case " $tokp " in *" RODOU-TYPECHECK "*) : ;; *)
      echo "FAIL [4]: caso $case_i (n=$n, publica=$publica) deveria rodar a suíte e não rodou — feed:"; printf '%s' "$feed"
      pbt_falhas=$((pbt_falhas + 1)) ;;
    esac
  else
    case " $tokp " in *"RODOU"*) echo "FAIL [4]: caso $case_i (n=$n, só deleção) deveria pular a suíte e rodou ('$tokp') — feed:"; printf '%s' "$feed"
      pbt_falhas=$((pbt_falhas + 1)) ;;
    esac
    case "$outp" in *"push de deleção pura ($n ref(s))"*) : ;; *)
      echo "FAIL [4]: caso $case_i (n=$n, só deleção) — linha nominal não tem a contagem certa — saída:"; echo "$outp"
      pbt_falhas=$((pbt_falhas + 1)) ;;
    esac
  fi
done
[ "$pbt_falhas" -eq 0 ] || { echo "FAIL [4]: $pbt_falhas/$pbt_n casos violaram a propriedade"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [4] — propriedade sobrevive a $pbt_n casos (semente $SEED, LCG próprio, >=12 casos de vazio e >=12 de só-deleção)"

# ── [5] mutação — remover o curto-circuito ──────────────────────────────────────────────────────
# Muta a CÓPIA do hook dentro da fixture (nunca o arquivo de produção real do template — "uma
# árvore, um escritor": este gate só mede a própria fixture, isolada em $T).
echo "[5] mutação — remover o curto-circuito faz [1] gravar o marker"
FHOOK="$R/.forge/hooks/git/pre-push"
cp "$FHOOK" "$T/hook.orig"
# aspas simples do lado esquerdo E direito — nunca `$` interpolado do lado direito (LDG-0164)
perl -pi -e 's/if \[ "\$_pp_refs_vistas" -gt 0 \] && \[ "\$_pp_refs_com_conteudo" -eq 0 \]; then/if false; then/' "$FHOOK"
if cmp -s "$FHOOK" "$T/hook.orig"; then
  echo "FAIL [5]: mutação não alterou o hook da fixture — o padrão de busca não casou"; exit 1
fi
: > "$MARK"
outm1="$(push_out "$feed1")"; rcm1=$?
if [ "$rcm1" -eq 0 ]; then
  tokm1="$(marker_tokens)"
  case " $tokm1 " in *" RODOU-TYPECHECK "*) : ;; *) echo "FAIL [5]: mutante sobreviveu — [1] continuou pulando a suíte mesmo sem o curto-circuito ('$tokm1')"; cp "$T/hook.orig" "$FHOOK"; exit 1 ;; esac
else
  echo "FAIL [5]: mutante quebrou o hook em vez de só religar a suíte (rc=$rcm1) — saída:"; echo "$outm1"; cp "$T/hook.orig" "$FHOOK"; exit 1
fi
echo "  mutante morto — [1] passou a gravar '$tokm1'"
cp "$T/hook.orig" "$FHOOK"
cmp -s "$FHOOK" "$T/hook.orig" || { echo "FAIL [5]: recontrole — restauração do hook da fixture não bate byte a byte"; exit 1; }
: > "$MARK"
outr1="$(push_out "$feed1")"; rcr1=$?
[ "$rcr1" -eq 0 ] || { echo "FAIL [5]: recontrole — [1] reprovou depois de restaurar o hook (rc=$rcr1)"; exit 1; }
tokr1="$(marker_tokens)"
[ -z "$tokr1" ] || { echo "FAIL [5]: recontrole — [1] voltou a gravar marker depois de restaurar ('$tokr1')"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [5] — mutante morto, recontrole restaurado bate byte a byte"

# ── [6] mutação — tratar entrada vazia como deleção ─────────────────────────────────────────────
echo "[6] mutação — tratar vazio como deleção faz [2] parar de gravar o marker"
cp "$FHOOK" "$T/hook.orig2"
perl -pi -e 's/if \[ "\$_pp_refs_vistas" -gt 0 \] && \[ "\$_pp_refs_com_conteudo" -eq 0 \]; then/if [ "\$_pp_refs_com_conteudo" -eq 0 ]; then/' "$FHOOK"
if cmp -s "$FHOOK" "$T/hook.orig2"; then
  echo "FAIL [6]: mutação não alterou o hook da fixture — o padrão de busca não casou"; exit 1
fi
: > "$MARK"
outm2="$(push_out "")"; rcm2=$?
if [ "$rcm2" -eq 0 ]; then
  tokm2="$(marker_tokens)"
  if [ -n "$tokm2" ]; then
    echo "FAIL [6]: mutante sobreviveu — [2] continuou rodando a suíte com stdin vazio ('$tokm2')"; cp "$T/hook.orig2" "$FHOOK"; exit 1
  fi
else
  echo "FAIL [6]: mutante quebrou o hook (rc=$rcm2) — saída:"; echo "$outm2"; cp "$T/hook.orig2" "$FHOOK"; exit 1
fi
echo "  mutante morto — [2] parou de rodar a suíte com entrada vazia"
cp "$T/hook.orig2" "$FHOOK"
cmp -s "$FHOOK" "$T/hook.orig2" || { echo "FAIL [6]: recontrole — restauração do hook da fixture não bate byte a byte"; exit 1; }
: > "$MARK"
outr2="$(push_out "")"; rcr2=$?
[ "$rcr2" -eq 0 ] || { echo "FAIL [6]: recontrole — [2] reprovou depois de restaurar o hook (rc=$rcr2)"; exit 1; }
tokr2="$(marker_tokens)"
case " $tokr2 " in *" RODOU-TYPECHECK "*) : ;; *) echo "FAIL [6]: recontrole — [2] não voltou a gravar marker depois de restaurar ('$tokr2')"; exit 1 ;; esac
SCEN=$((SCEN + 1))
echo "OK [6] — mutante morto, recontrole restaurado bate byte a byte"

# ── [7]/[8] HIGH regressão + mutação — mutex de carga pesada (issue #52) ───────────────────────
# Achado da rodada anterior: o curto-circuito só pulava typecheck/test/gates/harness-tests, mas o
# mutex (bloco entre o preflight #81 e os checks) era adquirido ANTES dele — uma deleção pura
# continuava entrando na fila e podia estourar o teto (rc 75) atrás de um dono vivo, o mesmo custo
# que a #132 mede. Isolado por FORGE_HEAVY_MUTEX_ROOT + FORGE_HEAVY_MUTEX_TESTING=1 — nunca toca o
# lock real da máquina (a trava em heavy-mutex.sh recusa TESTING=1 sem ROOT).
HBOX="$T/heavymutex"
mkdir -p "$HBOX"
HEAVY_LIB_PATH="$WS/template/.forge/scripts/lib/heavy-mutex.sh"
FORGE_YAML="$R/.forge/forge.yaml"
cp "$FORGE_YAML" "$T/forge.yaml.orig"
# -0777 (slurp o arquivo inteiro): o bloco `heavy_mutex:` e o `enabled: false` que ele governa
# ficam em LINHAS diferentes, e `perl -p` sozinho processa uma linha por vez — não casaria as
# duas. Âncorado em `heavy_mutex:` para não tocar os outros `enabled: false` do arquivo (capability
# packs, LDG-0150 etc.).
perl -0777 -pi -e 's/(heavy_mutex:\n\s*enabled:\s*)false/${1}true/' "$FORGE_YAML"
grep -A1 '^heavy_mutex:' "$FORGE_YAML" | grep -q 'enabled: true' \
  || { echo "FAIL [7]: setup — heavy_mutex.enabled não ficou 'true' na fixture"; exit 1; }

push_out_heavy() {  # push_out_heavy <stdin-feed> <timeout_s> — como push_out, com heavy-mutex
  # isolado (ROOT/TESTING/RESOURCE) e teto e intervalo de poll explícitos (POLL_S curto: o gate não
  # espera minutos para provar um comportamento de segundos).
  printf '%s' "$1" | (cd "$R" && FORGE_HEAVY_MUTEX_TESTING=1 FORGE_HEAVY_MUTEX_ROOT="$HBOX" \
    FORGE_HEAVY_MUTEX_RESOURCE=w224heavy FORGE_HEAVY_MUTEX_TIMEOUT_S="$2" FORGE_HEAVY_MUTEX_POLL_S=1 \
    bash "$R/.forge/hooks/git/pre-push" origin "file://$R" 2>&1)
}

start_holder() {  # start_holder <segundos-de-posse> — adquire o mutex isolado num processo à
  # parte e o segura pelo tempo dado; ecoa o PID em stdout. A saída do holder vai para um LOG, nunca
  # herda o stdout da função: `"$(start_holder N)"` é command substitution, e substituição só
  # retorna quando TODOS os processos com o fd de escrita aberto terminam — inclusive um neto em
  # segundo plano que herdasse esse mesmo stdout. Sem o redirecionamento, `HOLDER1="$(start_holder
  # 6)"` bloqueava pelos 6s inteiros do `sleep`, e por quando a atribuição finalmente retornava o
  # holder já tinha liberado o lock — o "setup não adquiriu a tempo" medido ao escrever este cenário.
  _holder_n=$(( ${_holder_n:-0} + 1 ))
  local log="$T/holder-$_holder_n.log"
  ( FORGE_HEAVY_MUTEX_TESTING=1 FORGE_HEAVY_MUTEX_ROOT="$HBOX" FORGE_HEAVY_MUTEX_RESOURCE=w224heavy \
    bash -c '. "$0"; forge_heavy_mutex_acquire --label holder --timeout 5 || exit $?; forge_heavy_mutex_arm_trap; sleep "$1"' \
    "$HEAVY_LIB_PATH" "$1" >"$log" 2>&1 ) &
  echo $!
}

wait_lock_file() {  # wait_lock_file — poll até o lock do holder aparecer (até 5s). A âncora é um
  # DIRETÓRIO (`mkdir`), não um arquivo — heavy-mutex.sh:853 — daí o `-d`, nunca `-f`.
  local i=0
  while [ ! -d "$HBOX/w224heavy.lock" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  [ -d "$HBOX/w224heavy.lock" ]
}

echo "[7] HIGH — mutex disputado por dono externo: deleção pura não entra na fila, push misto entra"
HOLDER1="$(start_holder 6)"
wait_lock_file || { echo "FAIL [7]: setup — holder externo não adquiriu o lock a tempo"; kill "$HOLDER1" 2>/dev/null; wait "$HOLDER1" 2>/dev/null; exit 1; }

out7a="$(push_out_heavy "$feed1" 3)"; rc7a=$?
[ "$rc7a" -eq 0 ] || { echo "FAIL [7]: deleção pura sob dono externo reprovou (rc=$rc7a) — saída:"; echo "$out7a"; kill "$HOLDER1" 2>/dev/null; wait "$HOLDER1" 2>/dev/null; exit 1; }
case "$out7a" in
  *"AGUARDANDO"*|*"TIMEOUT"*) echo "FAIL [7]: deleção pura entrou na fila do mutex — saída:"; echo "$out7a"; kill "$HOLDER1" 2>/dev/null; wait "$HOLDER1" 2>/dev/null; exit 1 ;;
esac
case "$out7a" in *"push de deleção pura (2 ref(s))"*) : ;; *) echo "FAIL [7]: linha nominal ausente na deleção pura sob mutex — saída:"; echo "$out7a"; kill "$HOLDER1" 2>/dev/null; wait "$HOLDER1" 2>/dev/null; exit 1 ;; esac

out7b="$(push_out_heavy "$feed3" 2)"; rc7b=$?
[ "$rc7b" -eq 75 ] || { echo "FAIL [7]: push misto sob dono externo não estourou o teto do mutex (rc=$rc7b, esperado 75) — saída:"; echo "$out7b"; kill "$HOLDER1" 2>/dev/null; wait "$HOLDER1" 2>/dev/null; exit 1; }
case "$out7b" in *"AGUARDANDO"*) : ;; *) echo "FAIL [7]: push misto não mostrou 'AGUARDANDO' esperando o mutex — saída:"; echo "$out7b"; kill "$HOLDER1" 2>/dev/null; wait "$HOLDER1" 2>/dev/null; exit 1 ;; esac

kill "$HOLDER1" 2>/dev/null; wait "$HOLDER1" 2>/dev/null
rm -rf "$HBOX/w224heavy.lock"
SCEN=$((SCEN + 1))
echo "OK [7] — deleção pura ignora o mutex disputado (rc 0, sem fila); push misto entra na fila e estoura o teto (rc 75)"

echo "[8] mutação — reintroduzir a aquisição do mutex antes do curto-circuito faz [7] voltar a esperar"
cp "$FHOOK" "$T/hook.orig3"
# aspas simples do lado esquerdo E direito — nunca `$` interpolado do lado direito (LDG-0164)
perl -pi -e 's/if \[ "\$_pp_so_delecao" != 1 \] && \[ -n "\$HEAVY_LIB" \] && _heavy_enabled; then/if [ -n "\$HEAVY_LIB" ] && _heavy_enabled; then/' "$FHOOK"
if cmp -s "$FHOOK" "$T/hook.orig3"; then
  echo "FAIL [8]: mutação não alterou o hook da fixture — o padrão de busca não casou"; exit 1
fi
HOLDER2="$(start_holder 6)"
wait_lock_file || { echo "FAIL [8]: setup — holder externo não adquiriu o lock a tempo"; kill "$HOLDER2" 2>/dev/null; wait "$HOLDER2" 2>/dev/null; cp "$T/hook.orig3" "$FHOOK"; exit 1; }
outm3="$(push_out_heavy "$feed1" 2)"; rcm3=$?
case "$outm3" in
  *"AGUARDANDO"*) : ;;
  *)
    echo "FAIL [8]: mutante sobreviveu — [7] continuou ignorando o mutex mesmo sem a guarda (rc=$rcm3) — saída:"; echo "$outm3"
    kill "$HOLDER2" 2>/dev/null; wait "$HOLDER2" 2>/dev/null; cp "$T/hook.orig3" "$FHOOK"; exit 1 ;;
esac
echo "  mutante morto — [7] voltou a esperar o mutex numa deleção pura"
kill "$HOLDER2" 2>/dev/null; wait "$HOLDER2" 2>/dev/null
rm -rf "$HBOX/w224heavy.lock"
cp "$T/hook.orig3" "$FHOOK"
cmp -s "$FHOOK" "$T/hook.orig3" || { echo "FAIL [8]: recontrole — restauração do hook da fixture não bate byte a byte"; exit 1; }
out8r="$(push_out_heavy "$feed1" 3)"; rc8r=$?
[ "$rc8r" -eq 0 ] || { echo "FAIL [8]: recontrole — deleção pura reprovou depois de restaurar o hook (rc=$rc8r)"; exit 1; }
case "$out8r" in *"AGUARDANDO"*) echo "FAIL [8]: recontrole — deleção pura voltou a entrar na fila do mutex"; exit 1 ;; esac
SCEN=$((SCEN + 1))
echo "OK [8] — mutante morto, recontrole restaurado bate byte a byte"

# forge.yaml restaurado ANTES do cenário [9]: ele mede com o mutex DESLIGADO, isolando a variável
# sob teste (o preflight #81), exatamente como a medição do achado original.
cp "$T/forge.yaml.orig" "$FORGE_YAML"
cmp -s "$FORGE_YAML" "$T/forge.yaml.orig" || { echo "FAIL [7]/[8]: restauração de forge.yaml não bate byte a byte"; exit 1; }

# ── [9] MEDIUM regressão — preflight de pré-condições de worktree (issue #81) ──────────────────
# Mesmo achado: o preflight só antecipa o que typecheck/test/gates/harness-tests exigiriam, e
# nenhum deles roda numa deleção — mas rodava (e bloqueava) ANTES do curto-circuito de deleção
# pura, exigindo `pnpm install` para apagar uma branch.
echo "[9] MEDIUM — preflight #81 sem node_modules: deleção pura não é bloqueada, push misto continua"
cat > "$R/package.json" <<'EOF'
{"name": "w224fixture", "version": "1.0.0", "dependencies": {"left-pad": "^1.0.0"}}
EOF
[ ! -d "$R/node_modules" ] || { echo "FAIL [9]: setup — node_modules não deveria existir na fixture"; exit 1; }

out9a="$(push_out "$feed1")"; rc9a=$?
[ "$rc9a" -eq 0 ] || { echo "FAIL [9]: deleção pura sem node_modules reprovou (rc=$rc9a) — saída:"; echo "$out9a"; exit 1; }
case "$out9a" in *"BLOQUEADO: pré-condições de worktree"*) echo "FAIL [9]: deleção pura foi bloqueada pelo preflight #81 — saída:"; echo "$out9a"; exit 1 ;; esac
case "$out9a" in *"push de deleção pura (2 ref(s))"*) : ;; *) echo "FAIL [9]: linha nominal ausente — saída:"; echo "$out9a"; exit 1 ;; esac

out9b="$(push_out "$feed3")"; rc9b=$?
[ "$rc9b" -ne 0 ] || { echo "FAIL [9]: push misto sem node_modules deveria ser bloqueado pelo #81 e não foi — saída:"; echo "$out9b"; exit 1; }
case "$out9b" in *"BLOQUEADO: pré-condições de worktree"*) : ;; *) echo "FAIL [9]: push misto não mostrou o bloqueio do #81 — saída:"; echo "$out9b"; exit 1 ;; esac

rm -f "$R/package.json"
SCEN=$((SCEN + 1))
echo "OK [9] — deleção pura ignora o preflight #81; push misto continua bloqueado por dependência ausente"

# ── [10] ─────────────────────────────────────────────────────────────────────────────────────
[ "$SCEN" -gt 0 ] || { echo "FAIL [10]: contador de controle — zero cenário executado"; exit 1; }
echo "OK [10] — $SCEN cenário(s) executado(s)"

echo "PASS w224-prepush-delecao-pura"
