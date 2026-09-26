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
# publicando conteúdo no mesmo push exige os checks por inteiro. Política de ref PROTEGIDA fica
# fora deste curto-circuito, de propósito (DA-10 — roadmap na Onda 8).
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
#   [4] PBT (semente fixa, 50 casos): para listas geradas de 0 a 6 linhas de ref, cada uma deleção
#       ou publicação, em ordem aleatória, a suíte roda se e somente se a lista é vazia ou contém
#       ao menos uma linha com `local_sha` não zero
#   [5] mutação — remover o curto-circuito: o cenário [1] passa a gravar o marker (a suíte volta a
#       rodar em push de deleção pura); recontrole com `cmp -s` restaura e [1] volta a passar
#   [6] mutação — tratar entrada vazia como deleção: o cenário [2] passa a pular a suíte (marker
#       vazio); recontrole com `cmp -s` restaura e [2] volta a passar
#   [7] contador de controle: zero cenário executado reprova
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$WS/template/.forge/hooks/git/pre-push"
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
# SE a lista é vazia OU contém ao menos uma linha de publicação. Semente fixa para reprodutibilidade.
echo "[4] PBT — 50 casos gerados (semente 20260926), lista de 0-6 linhas deleção/publicação"
SEED=20260926
RANDOM=$SEED
pbt_n=50
pbt_falhas=0
for case_i in $(seq 1 "$pbt_n"); do
  n=$((RANDOM % 7))          # 0..6 linhas
  feed=""
  publica=0
  for line_i in $(seq 1 "$n"); do
    tipo=$((RANDOM % 2))     # 0=deleção 1=publicação
    if [ "$tipo" -eq 0 ]; then
      feed="${feed}(delete) $ZERO refs/heads/r${case_i}_${line_i} $SHA
"
    else
      feed="${feed}refs/heads/r${case_i}_${line_i} $SHA refs/heads/r${case_i}_${line_i} $ZERO
"
      publica=1
    fi
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
  fi
done
[ "$pbt_falhas" -eq 0 ] || { echo "FAIL [4]: $pbt_falhas/$pbt_n casos violaram a propriedade"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [4] — propriedade sobrevive a $pbt_n casos (semente $SEED)"

# ── [5] mutação — remover o curto-circuito ──────────────────────────────────────────────────────
echo "[5] mutação — remover o curto-circuito faz [1] gravar o marker"
cp "$HOOK" "$T/hook.orig"
# aspas simples do lado esquerdo E direito — nunca `$` interpolado do lado direito (LDG-0164)
perl -pi -e 's/if \[ "\$_pp_refs_vistas" -gt 0 \] && \[ "\$_pp_refs_com_conteudo" -eq 0 \]; then/if false; then/' "$HOOK"
if cmp -s "$HOOK" "$T/hook.orig"; then
  echo "FAIL [5]: mutação não alterou o hook — o padrão de busca não casou"; exit 1
fi
: > "$MARK"
outm1="$(push_out "$feed1")"; rcm1=$?
if [ "$rcm1" -eq 0 ]; then
  tokm1="$(marker_tokens)"
  case " $tokm1 " in *" RODOU-TYPECHECK "*) : ;; *) echo "FAIL [5]: mutante sobreviveu — [1] continuou pulando a suíte mesmo sem o curto-circuito ('$tokm1')"; cp "$T/hook.orig" "$HOOK"; exit 1 ;; esac
else
  echo "FAIL [5]: mutante quebrou o hook em vez de só religar a suíte (rc=$rcm1) — saída:"; echo "$outm1"; cp "$T/hook.orig" "$HOOK"; exit 1
fi
echo "  mutante morto — [1] passou a gravar '$tokm1'"
cp "$T/hook.orig" "$HOOK"
cmp -s "$HOOK" "$T/hook.orig" || { echo "FAIL [5]: recontrole — restauração do hook não bate byte a byte"; exit 1; }
: > "$MARK"
outr1="$(push_out "$feed1")"; rcr1=$?
[ "$rcr1" -eq 0 ] || { echo "FAIL [5]: recontrole — [1] reprovou depois de restaurar o hook (rc=$rcr1)"; exit 1; }
tokr1="$(marker_tokens)"
[ -z "$tokr1" ] || { echo "FAIL [5]: recontrole — [1] voltou a gravar marker depois de restaurar ('$tokr1')"; exit 1; }
SCEN=$((SCEN + 1))
echo "OK [5] — mutante morto, recontrole restaurado bate byte a byte"

# ── [6] mutação — tratar entrada vazia como deleção ─────────────────────────────────────────────
echo "[6] mutação — tratar vazio como deleção faz [2] parar de gravar o marker"
cp "$HOOK" "$T/hook.orig2"
perl -pi -e 's/if \[ "\$_pp_refs_vistas" -gt 0 \] && \[ "\$_pp_refs_com_conteudo" -eq 0 \]; then/if [ "\$_pp_refs_com_conteudo" -eq 0 ]; then/' "$HOOK"
if cmp -s "$HOOK" "$T/hook.orig2"; then
  echo "FAIL [6]: mutação não alterou o hook — o padrão de busca não casou"; exit 1
fi
: > "$MARK"
outm2="$(push_out "")"; rcm2=$?
if [ "$rcm2" -eq 0 ]; then
  tokm2="$(marker_tokens)"
  if [ -n "$tokm2" ]; then
    echo "FAIL [6]: mutante sobreviveu — [2] continuou rodando a suíte com stdin vazio ('$tokm2')"; cp "$T/hook.orig2" "$HOOK"; exit 1
  fi
else
  echo "FAIL [6]: mutante quebrou o hook (rc=$rcm2) — saída:"; echo "$outm2"; cp "$T/hook.orig2" "$HOOK"; exit 1
fi
echo "  mutante morto — [2] parou de rodar a suíte com entrada vazia"
cp "$T/hook.orig2" "$HOOK"
cmp -s "$HOOK" "$T/hook.orig2" || { echo "FAIL [6]: recontrole — restauração do hook não bate byte a byte"; exit 1; }
: > "$MARK"
outr2="$(push_out "")"; rcr2=$?
[ "$rcr2" -eq 0 ] || { echo "FAIL [6]: recontrole — [2] reprovou depois de restaurar o hook (rc=$rcr2)"; exit 1; }
tokr2="$(marker_tokens)"
case " $tokr2 " in *" RODOU-TYPECHECK "*) : ;; *) echo "FAIL [6]: recontrole — [2] não voltou a gravar marker depois de restaurar ('$tokr2')"; exit 1 ;; esac
SCEN=$((SCEN + 1))
echo "OK [6] — mutante morto, recontrole restaurado bate byte a byte"

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
[ "$SCEN" -gt 0 ] || { echo "FAIL [7]: contador de controle — zero cenário executado"; exit 1; }
echo "OK [7] — $SCEN cenário(s) executado(s)"

echo "PASS w224-prepush-delecao-pura"
