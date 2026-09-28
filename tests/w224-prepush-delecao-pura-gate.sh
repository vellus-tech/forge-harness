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
#   [3] contrafactual — misto (1 deleção + 1 publicação, deleção ANTES): marker com os quatro
#       sinais, sem a linha nominal — uma única ref com conteúdo no push basta para não pular nada
#   [3b] contrafactual — misto com a ORDEM INVERTIDA (1 publicação + 1 deleção, publicação ANTES):
#       mesmo resultado de [3] — a classificação não pode depender de qual linha vem primeiro
#   [3c] HIGH mutação — a classificação soma linha a linha, mas um mutante que RESETA o contador de
#       conteúdo a cada linha (em vez de só incrementar) faz o resultado refletir só a ÚLTIMA linha
#       do push; com deleção antes de publicação ([3]) esse mutante sobrevive por acidente (a
#       última linha É publicação) — só [3b] (publicação antes de deleção) expõe o fail-open: o
#       mutante classifica um push com conteúdo real como deleção pura e PULA a suíte; recontrole
#       com `cmp -s` restaura
#   [3d] contrafactual — misto com duas deleções ADJACENTES depois da publicação (publicação, deleção, deleção): tudo roda — a classificação não pode depender de duas linhas vizinhas serem do mesmo tipo
#   [3e] mutação — adjacência: um mutante que zera o contador de conteúdo quando duas deleções chegam seguidas sobrevive a todo feed estritamente alternado ([3], [3b] e um gerador degenerado em alternância) e só morre com deleções adjacentes depois da publicação — [3d] o mata aqui, e o PBT [4] o mata de forma independente pelos padrões não alternados do estrato misto; recontrole com `cmp -s` restaura
#   [3f] contrafactual — misto (1 deleção + 1 atualização de branch EXISTENTE, remote_sha != 0):
#       tudo roda — o classificador olha só `local_sha`, nunca `remote_sha`; uma publicação que
#       atualiza um branch já existente no remoto não pode contar como "menos conteúdo" do que uma
#       publicação que cria um branch novo
#   [3g] mutação — ignorar remote_sha != 0: um mutante que pula (`continue`) qualquer linha cujo
#       `remote_sha` não seja zero classifica [3f] como deleção pura, porque a única linha de
#       conteúdo do push é justamente a atualização de branch existente (remote_sha real) — o
#       fail-open que o classificador teria se passasse a olhar `remote_sha` para decidir o que
#       conta como conteúdo; recontrole com `cmp -s` restaura
#   [4] PBT (semente fixa, LCG próprio — reproduz em qualquer bash, ver nota abaixo — 50 casos estratificados, com estrato próprio para a classe mista): para listas geradas de 0 a 6 linhas de ref, cada uma deleção ou publicação em ordem aleatória — publicação sorteando também o `remote_sha` (zero, branch novo, ou um sha real, atualização de branch existente), pelos bits altos do mesmo LCG —, a suíte roda se e somente se a lista é vazia ou contém ao menos uma linha com `local_sha` não zero; nos casos de só-deleção, a contagem N da linha nominal bate com o número de linhas; o histograma por classe, os n distintos do estrato só-deleção (exigido cobrir 1 a 6) e do estrato livre, e a contagem de padrões não alternados do estrato misto aparecem no `OK [4]`, e o estrato misto precisa conter ao menos um padrão com dois tipos iguais adjacentes e ao menos um com publicação seguida de >=2 deleções até o fim da lista — as duas degenerações medidas (estado que não avança e bit baixo alternante) reprovam o gate em vez de passarem em silêncio
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
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

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
OLDSHA="$(git -C "$R" rev-parse HEAD)"   # tip "antigo" — só para simular remote_sha real de uma
# atualização de branch existente ([3f]/[3g]/PBT [4]); usar o mesmo $SHA como local_sha E
# remote_sha faz `rsha..lsha` (no gate no-ai-attribution) virar um range vazio (`SHA..SHA`) e
# dispara o próprio fail-safe de universo vazio do gate — sintoma alheio ao que este teste mede.
printf '# w224fixture v2\n' >> "$R/README.md"
git -C "$R" commit -q --no-verify -am "fixture w224 v2"
SHA="$(git -C "$R" rev-parse HEAD)"

push_out() {  # push_out <stdin-feed> — invoca o pre-push pelo canal real (stdin de refs)
  printf '%s' "$1" | (cd "$R" && bash "$R/.forge/hooks/git/pre-push" origin "file://$R" 2>&1)
}

marker_tokens() {  # marker_tokens -> lista os sinais gravados no marker (ordenados, sem duplicar)
  [ -f "$MARK" ] || { printf ''; return 0; }
  sort -u "$MARK" | tr '\n' ' '
}

FHOOK="$R/.forge/hooks/git/pre-push"   # caminho do hook DENTRO da fixture — usado por toda mutação

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

# ── [3b] ─────────────────────────────────────────────────────────────────────────────────────
echo "[3b] contrafactual — misto, ordem invertida (1 publicação + 1 deleção): tudo roda"
: > "$MARK"
feed3b="$(printf 'refs/heads/main %s refs/heads/main %s\n(delete) %s refs/heads/velha %s\n' "$SHA" "$ZERO" "$ZERO" "$SHA")"
out3b="$(push_out "$feed3b")"; rc3b=$?
[ "$rc3b" -eq 0 ] || { echo "FAIL [3b]: pre-push reprovou push misto invertido (rc=$rc3b) — saída:"; echo "$out3b"; exit 1; }
case "$out3b" in *"deleção pura"*) echo "FAIL [3b]: push misto invertido não pode pular como deleção pura — saída:"; echo "$out3b"; exit 1 ;; esac
tok3b="$(marker_tokens)"
for want in RODOU-TYPECHECK RODOU-TEST RODOU-GATE RODOU-HARNESS; do
  case " $tok3b " in *" $want "*) : ;; *) echo "FAIL [3b]: '$want' ausente do marker em push misto invertido — gravou: '$tok3b'"; exit 1 ;; esac
done
SCEN=$((SCEN + 1))
echo "OK [3b] — os quatro sinais gravados com a publicação ANTES da deleção"

# ── [3c] HIGH mutação — a ÚLTIMA linha decide sozinha se há conteúdo ────────────────────────────
# O classificador soma linha a linha; um mutante que RESETA `_pp_refs_com_conteudo` a
# cada linha do laço (em vez de só incrementar) faz o valor final refletir só a última linha do
# push. Com deleção antes de publicação ([3]) esse mutante sobrevive por acidente — a última linha
# É publicação, então o reset não muda o resultado. Só um feed com publicação ANTES da deleção
# ([3b]) expõe o mutante: ele classificaria um push com conteúdo real como deleção pura e PULARIA
# typecheck/test/gates/harness-tests — o fail-open que a revisão mediu.
echo "[3c] mutação — 'a última linha decide' faz [3b] virar (errado) deleção pura, suíte pulada"
cp "$FHOOK" "$T/hook.orig3c"
# aspas simples do lado esquerdo E direito — nunca \$ interpolado do lado direito (LDG-0164)
perl -pi -e 's/_pp_refs_vistas=\$\(\(_pp_refs_vistas \+ 1\)\)/_pp_refs_vistas=\$((_pp_refs_vistas + 1)); _pp_refs_com_conteudo=0/' "$FHOOK"
if cmp -s "$FHOOK" "$T/hook.orig3c"; then
  echo "FAIL [3c]: mutação não alterou o hook da fixture — o padrão de busca não casou"; exit 1
fi
: > "$MARK"
outm3c="$(push_out "$feed3b")"; rcm3c=$?
if [ "$rcm3c" -eq 0 ]; then
  tokm3c="$(marker_tokens)"
  case "$outm3c" in
    *"deleção pura"*)
      [ -z "$tokm3c" ] || { echo "FAIL [3c]: mutante classificou como deleção pura mas ainda gravou marker ('$tokm3c')"; cp "$T/hook.orig3c" "$FHOOK"; exit 1; }
      ;;
    *) echo "FAIL [3c]: mutante sobreviveu — [3b] continuou rodando a suíte por inteiro ('$tokm3c')"; cp "$T/hook.orig3c" "$FHOOK"; exit 1 ;;
  esac
else
  echo "FAIL [3c]: mutante quebrou o hook em vez de classificar errado (rc=$rcm3c) — saída:"; echo "$outm3c"; cp "$T/hook.orig3c" "$FHOOK"; exit 1
fi
echo "  mutante morto — [3b] passou a ser classificado (errado) como deleção pura, suíte pulada"
cp "$T/hook.orig3c" "$FHOOK"
cmp -s "$FHOOK" "$T/hook.orig3c" || { echo "FAIL [3c]: recontrole — restauração do hook da fixture não bate byte a byte"; exit 1; }
: > "$MARK"
outr3c="$(push_out "$feed3b")"; rcr3c=$?
[ "$rcr3c" -eq 0 ] || { echo "FAIL [3c]: recontrole — [3b] reprovou depois de restaurar o hook (rc=$rcr3c)"; exit 1; }
tokr3c="$(marker_tokens)"
for want in RODOU-TYPECHECK RODOU-TEST RODOU-GATE RODOU-HARNESS; do
  case " $tokr3c " in *" $want "*) : ;; *) echo "FAIL [3c]: recontrole — '$want' ausente do marker ('$tokr3c')"; exit 1 ;; esac
done
SCEN=$((SCEN + 1))
echo "OK [3c] — mutante morto, recontrole restaurado bate byte a byte"

# ── [3d] ─────────────────────────────────────────────────────────────────────────────────────
echo "[3d] contrafactual — misto, publicação seguida de duas deleções adjacentes: tudo roda"
: > "$MARK"
feed3d="$(printf 'refs/heads/main %s refs/heads/main %s\n(delete) %s refs/heads/velha1 %s\n(delete) %s refs/heads/velha2 %s\n' "$SHA" "$ZERO" "$ZERO" "$SHA" "$ZERO" "$SHA")"
out3d="$(push_out "$feed3d")"; rc3d=$?
[ "$rc3d" -eq 0 ] || { echo "FAIL [3d]: pre-push reprovou push misto com deleções adjacentes (rc=$rc3d) — saída:"; echo "$out3d"; exit 1; }
case "$out3d" in *"deleção pura"*) echo "FAIL [3d]: push misto com deleções adjacentes não pode pular como deleção pura (so_delecao tem de ser 0) — saída:"; echo "$out3d"; exit 1 ;; esac
tok3d="$(marker_tokens)"
for want in RODOU-TYPECHECK RODOU-TEST RODOU-GATE RODOU-HARNESS; do
  case " $tok3d " in *" $want "*) : ;; *) echo "FAIL [3d]: '$want' ausente do marker em push misto com deleções adjacentes — gravou: '$tok3d'"; exit 1 ;; esac
done
SCEN=$((SCEN + 1))
echo "OK [3d] — os quatro sinais gravados com publicação, deleção, deleção"

# ── [3e] mutação — duas deleções adjacentes zeram o contador de conteúdo ───────────────────────
# O mutante lembra o tipo da linha anterior e zera `_pp_refs_com_conteudo` quando uma deleção chega logo depois de outra deleção. Todo feed estritamente alternado — [3], [3b] e qualquer PBT cujo sorteio de tipo saia do bit baixo do LCG, que alterna 1,0,1,0 — nunca tem duas deleções vizinhas, então o mutante sobrevive a todos eles; só deleções adjacentes DEPOIS da última publicação o expõem, classificando como deleção pura um push que publica conteúdo (fail-open).
echo "[3e] mutação — 'duas deleções adjacentes zeram o conteúdo' faz [3d] virar (errado) deleção pura"
cp "$FHOOK" "$T/hook.orig3e"
# aspas simples do lado esquerdo E direito — nunca \$ interpolado do lado direito (LDG-0164)
perl -pi -e 's/case "\$_pp_lsha" in \*\[!0\]\*\) : ;; \*\) continue ;; esac/case "\$_pp_lsha" in *[!0]*) _pp_prev=pub ;; *) [ "\${_pp_prev:-}" = del ] && _pp_refs_com_conteudo=0; _pp_prev=del; continue ;; esac/' "$FHOOK"
if cmp -s "$FHOOK" "$T/hook.orig3e"; then
  echo "FAIL [3e]: mutação não alterou o hook da fixture — o padrão de busca não casou"; exit 1
fi
: > "$MARK"
outm3e="$(push_out "$feed3d")"; rcm3e=$?
if [ "$rcm3e" -eq 0 ]; then
  tokm3e="$(marker_tokens)"
  case "$outm3e" in
    *"push de deleção pura (3 ref(s))"*)
      [ -z "$tokm3e" ] || { echo "FAIL [3e]: mutante classificou como deleção pura mas ainda gravou marker ('$tokm3e')"; cp "$T/hook.orig3e" "$FHOOK"; exit 1; }
      ;;
    *) echo "FAIL [3e]: mutante sobreviveu — [3d] continuou rodando a suíte por inteiro ('$tokm3e')"; cp "$T/hook.orig3e" "$FHOOK"; exit 1 ;;
  esac
else
  echo "FAIL [3e]: mutante quebrou o hook em vez de classificar errado (rc=$rcm3e) — saída:"; echo "$outm3e"; cp "$T/hook.orig3e" "$FHOOK"; exit 1
fi
echo "  mutante morto — [3d] passou a ser classificado (errado) como deleção pura, suíte pulada"
cp "$T/hook.orig3e" "$FHOOK"
cmp -s "$FHOOK" "$T/hook.orig3e" || { echo "FAIL [3e]: recontrole — restauração do hook da fixture não bate byte a byte"; exit 1; }
: > "$MARK"
outr3e="$(push_out "$feed3d")"; rcr3e=$?
[ "$rcr3e" -eq 0 ] || { echo "FAIL [3e]: recontrole — [3d] reprovou depois de restaurar o hook (rc=$rcr3e)"; exit 1; }
case "$outr3e" in *"deleção pura"*) echo "FAIL [3e]: recontrole — [3d] continuou classificado como deleção pura depois de restaurar"; exit 1 ;; esac
tokr3e="$(marker_tokens)"
for want in RODOU-TYPECHECK RODOU-TEST RODOU-GATE RODOU-HARNESS; do
  case " $tokr3e " in *" $want "*) : ;; *) echo "FAIL [3e]: recontrole — '$want' ausente do marker ('$tokr3e')"; exit 1 ;; esac
done
SCEN=$((SCEN + 1))
echo "OK [3e] — mutante morto, recontrole restaurado bate byte a byte"

# ── [3f] ─────────────────────────────────────────────────────────────────────────────────────
# O classificador olha só `local_sha` (linha 240 em diante) — nunca `remote_sha`. Todos os feeds
# de publicação até aqui ([2], [3], [3b], [3d], [3e]) criam branch NOVA (`remote_sha` zero); nenhum
# exercita o outro formato real de push, a atualização de um branch EXISTENTE (`remote_sha` != 0,
# o sha antigo da ponta). [3f] fecha essa lacuna com um feed manual antes do PBT [4] sortear o
# mesmo campo.
echo "[3f] contrafactual — misto (deleção + atualização de branch existente, remote_sha != 0): tudo roda"
: > "$MARK"
feed3f="$(printf '(delete) %s refs/heads/velha %s\nrefs/heads/main %s refs/heads/main %s\n' "$ZERO" "$SHA" "$SHA" "$OLDSHA")"
out3f="$(push_out "$feed3f")"; rc3f=$?
[ "$rc3f" -eq 0 ] || { echo "FAIL [3f]: pre-push reprovou push com atualização de branch existente (rc=$rc3f) — saída:"; echo "$out3f"; exit 1; }
case "$out3f" in *"deleção pura"*) echo "FAIL [3f]: atualização de branch existente não pode ser classificada como deleção pura — saída:"; echo "$out3f"; exit 1 ;; esac
tok3f="$(marker_tokens)"
for want in RODOU-TYPECHECK RODOU-TEST RODOU-GATE RODOU-HARNESS; do
  case " $tok3f " in *" $want "*) : ;; *) echo "FAIL [3f]: '$want' ausente do marker em push com atualização de branch existente — gravou: '$tok3f'"; exit 1 ;; esac
done
SCEN=$((SCEN + 1))
echo "OK [3f] — os quatro sinais gravados com deleção + atualização de branch existente"

# ── [3g] mutação — ignorar linhas com remote_sha != 0 ──────────────────────────────────────────
# Feed PRÓPRIO, diferente de [3f]: precisa que a linha de DELEÇÃO sobreviva ao mutante (remote_sha
# zero, ao contrário de [1]/[3]/[3f], que usam o sha antigo real — aqui é sintético de propósito,
# só para isolar a variável sob teste) enquanto a linha de PUBLICAÇÃO (atualização de branch
# existente, remote_sha real) é a única a ser descartada. Se o classificador passasse a olhar
# `remote_sha` e pulasse (`continue`) qualquer linha em que ele não é zero, a linha de publicação
# deixaria de ser contada e só a deleção sobraria: o mutante vê `_pp_refs_vistas` > 0 e
# `_pp_refs_com_conteudo` == 0 e classifica o push (errado) como deleção pura, pulando a suíte por
# inteiro num push que publica conteúdo de verdade.
echo "[3g] mutação — ignorar remote_sha != 0 faz um push com conteúdo virar (errado) deleção pura"
feed3g="$(printf '(delete) %s refs/heads/velha %s\nrefs/heads/main %s refs/heads/main %s\n' "$ZERO" "$ZERO" "$SHA" "$OLDSHA")"
: > "$MARK"
out3g="$(push_out "$feed3g")"; rc3g=$?
[ "$rc3g" -eq 0 ] || { echo "FAIL [3g]: setup — pre-push reprovou o feed antes de mutar (rc=$rc3g) — saída:"; echo "$out3g"; exit 1; }
case "$out3g" in *"deleção pura"*) echo "FAIL [3g]: setup — feed já nasce classificado como deleção pura, sem mutação — saída:"; echo "$out3g"; exit 1 ;; esac
cp "$FHOOK" "$T/hook.orig3g"
# aspas simples do lado esquerdo E direito — nunca \$ interpolado do lado direito (LDG-0164)
perl -pi -e 's/\[ -n "\$\{_pp_lsha:-\}" \] \|\| continue/[ -n "\${_pp_lsha:-}" ] || continue; case "\$_pp_rsha" in *[!0]*) continue ;; esac/' "$FHOOK"
if cmp -s "$FHOOK" "$T/hook.orig3g"; then
  echo "FAIL [3g]: mutação não alterou o hook da fixture — o padrão de busca não casou"; exit 1
fi
: > "$MARK"
outm3g="$(push_out "$feed3g")"; rcm3g=$?
if [ "$rcm3g" -eq 0 ]; then
  tokm3g="$(marker_tokens)"
  case "$outm3g" in
    *"deleção pura"*)
      [ -z "$tokm3g" ] || { echo "FAIL [3g]: mutante classificou como deleção pura mas ainda gravou marker ('$tokm3g')"; cp "$T/hook.orig3g" "$FHOOK"; exit 1; }
      ;;
    *) echo "FAIL [3g]: mutante sobreviveu — o feed continuou rodando a suíte por inteiro ('$tokm3g')"; cp "$T/hook.orig3g" "$FHOOK"; exit 1 ;;
  esac
else
  echo "FAIL [3g]: mutante quebrou o hook em vez de classificar errado (rc=$rcm3g) — saída:"; echo "$outm3g"; cp "$T/hook.orig3g" "$FHOOK"; exit 1
fi
echo "  mutante morto — o push com conteúdo passou a ser classificado (errado) como deleção pura, suíte pulada"
cp "$T/hook.orig3g" "$FHOOK"
cmp -s "$FHOOK" "$T/hook.orig3g" || { echo "FAIL [3g]: recontrole — restauração do hook da fixture não bate byte a byte"; exit 1; }
: > "$MARK"
outr3g="$(push_out "$feed3g")"; rcr3g=$?
[ "$rcr3g" -eq 0 ] || { echo "FAIL [3g]: recontrole — o feed reprovou depois de restaurar o hook (rc=$rcr3g)"; exit 1; }
case "$outr3g" in *"deleção pura"*) echo "FAIL [3g]: recontrole — o feed continuou classificado como deleção pura depois de restaurar"; exit 1 ;; esac
tokr3g="$(marker_tokens)"
for want in RODOU-TYPECHECK RODOU-TEST RODOU-GATE RODOU-HARNESS; do
  case " $tokr3g " in *" $want "*) : ;; *) echo "FAIL [3g]: recontrole — '$want' ausente do marker ('$tokr3g')"; exit 1 ;; esac
done
SCEN=$((SCEN + 1))
echo "OK [3g] — mutante morto, recontrole restaurado bate byte a byte"

# ── [4] PBT ──────────────────────────────────────────────────────────────────────────────────
# Propriedade: para uma lista de 0 a 6 linhas de ref, cada uma deleção (local_sha zero) ou publicação (local_sha != zero), em ordem aleatória, a suíte roda (marker não vazio) SE E SOMENTE SE a lista é vazia OU contém ao menos uma linha de publicação; nos casos de só-deleção, a contagem N na linha nominal bate com o número de linhas do caso.
#
# LCG PRÓPRIO, nunca `$RANDOM`: `$RANDOM` muda de gerador entre versões do bash (medido: bash 3.2 local e bash 5.1+ do CI produzem sequências DIFERENTES para a mesma semente), o que torna a "semente fixa" reprodutível só na máquina que a mediu. Um LCG (Numerical Recipes: a=1103515245, c=12345, m=2^31) em aritmética inteira do próprio shell reproduz IDÊNTICO em qualquer bash.
#
# NUNCA chamar `lcg_next` via `$(...)`: command substitution roda em SUBSHELL, e a atribuição a `_lcg_state` dentro dele se perde ao voltar para o shell pai — o estado nunca avança e os 50 casos colapsam em 3 valores de `n`, sem caso misto de verdade (medido com `bash -x tests/w224-*.sh | grep -E '^\+ (n=|tipo=|_lcg_state=)' | sort | uniq -c`). A função é chamada DIRETO, no shell corrente, e o chamador lê `$_lcg_state` na linha seguinte.
#
# Cada sorteio sai dos BITS ALTOS do estado, `(_lcg_state >> 16) % k`, nunca de `_lcg_state % k`: com `a` e `c` ímpares e `m` potência de 2, o bit menos significativo de um LCG tem período 2 e alterna 1,0,1,0 a cada chamada, e todo módulo par (`% 2`, `% 6`) herda essa alternância. Sorteado do bit baixo, o tipo de cada linha saía estritamente alternado em todos os casos — nunca duas deleções vizinhas —, e um mutante que zera o contador de conteúdo em deleções adjacentes (ver [3e]) sobrevivia ao PBT inteiro. As asserções depois do laço exigem padrões não alternados no estrato misto, para que essa degeneração reprove o gate em vez de passar em silêncio.
# Semente 20260928: a 20260926 original cobria só 5 dos 6 valores de N possíveis no estrato
# só-deleção (1-6) — faltava n=5 — o que [4] passou a exigir (ver `n_so_delecao_distintos`
# abaixo). Trocada por busca exaustiva das primeiras 12 tiradas de `lcg_draw 6` (as únicas que o
# estrato consome, sempre as 12 primeiras do LCG, antes de qualquer draw dos estratos seguintes).
SEED=20260928
LCG_A=1103515245
LCG_C=12345
LCG_M=2147483648  # 2^31
_lcg_state=$SEED
lcg_next() {  # atualiza _lcg_state no shell CHAMADOR — nunca `$(lcg_next)` (ver nota acima)
  _lcg_state=$(( (LCG_A * _lcg_state + LCG_C) % LCG_M ))
}
lcg_draw() {  # lcg_draw <k> -> avança o estado e grava em _lcg_draw um valor em [0, k) tirado dos bits altos
  lcg_next
  _lcg_draw=$(( (_lcg_state >> 16) % $1 ))
}

# Estratificação: o espaço uniforme deixa "só-deleção" rara e a classe MISTA (deleção E publicação no mesmo push — a classe que #132/#134 introduz de verdade) ainda mais rara, então quatro estratos, sempre 50 casos: 1-12 forçam n=0 (vazio); 13-24 forçam "só-deleção" com 1-6 linhas; 25-36 forçam "mista" com 2-6 linhas — o LCG sorteia o tipo e a ORDEM de cada linha e, se o sorteio sair uniforme (tudo deleção ou tudo publicação), a lista inteira é sorteada de novo, sem corrigir linha nenhuma à mão, o que mantém a distribuição uniforme sobre os padrões mistos; 37-50 ficam livres (LCG puro, qualquer classe). Garante >=12 casos de cada classe crítica sem abrir mão da aleatoriedade do resto. O resorteio tem teto: um gerador cujo estado não avança sorteia sempre o mesmo tipo e esgota o teto, reprovando o gate.
echo "[4] PBT — 50 casos gerados (semente $SEED, LCG próprio, bits altos, estratificado), lista de 0-6 linhas deleção/publicação"
pbt_n=50
pbt_falhas=0
cnt_vazio=0
cnt_so_delecao=0
cnt_mista=0
cnt_resorteios=0
PBT_RESORTEIO_TETO=16
hist_n_livre=""
hist_n_so_delecao=""
hist_mista_padroes=""
for case_i in $(seq 1 "$pbt_n"); do
  forcar_mista=0
  if [ "$case_i" -le 12 ]; then
    n=0; forcar_so_delecao=0
  elif [ "$case_i" -le 24 ]; then
    lcg_draw 6; n=$(( 1 + _lcg_draw )); forcar_so_delecao=1
    hist_n_so_delecao="$hist_n_so_delecao $n"
  elif [ "$case_i" -le 36 ]; then
    lcg_draw 5; n=$(( 2 + _lcg_draw )); forcar_so_delecao=0; forcar_mista=1
  else
    lcg_draw 7; n=$_lcg_draw; forcar_so_delecao=0
    hist_n_livre="$hist_n_livre $n"
  fi

  # Tipo de cada linha em parâmetros posicionais (`set --`), nunca array bash: portátil em bash 3.2 (macOS) e sem o bug de `"${arr[@]}"` vazio sob `set -u` que arrays têm em bash < 4.4.
  _tentativas=0
  while :; do
    _tipos_str=""
    # `seq 1 "$n"` com n=0 no BSD/macOS conta PARA BAIXO ("1", "0") em vez de devolver vazio (GNU) — loop C-style, sem `seq`, para não reintroduzir o footgun de portabilidade do w97.
    line_i=1
    while [ "$line_i" -le "$n" ]; do
      if [ "$forcar_so_delecao" -eq 1 ]; then
        tipo=0
      else
        lcg_draw 2; tipo=$_lcg_draw     # 0=deleção 1=publicação
      fi
      _tipos_str="$_tipos_str $tipo"
      line_i=$((line_i + 1))
    done
    [ "$forcar_mista" -eq 1 ] || break
    case " $_tipos_str " in *" 0 "*) case " $_tipos_str " in *" 1 "*) break ;; esac ;; esac
    _tentativas=$((_tentativas + 1))
    cnt_resorteios=$((cnt_resorteios + 1))
    if [ "$_tentativas" -ge "$PBT_RESORTEIO_TETO" ]; then
      echo "FAIL [4]: gerador degenerado — caso $case_i do estrato misto saiu uniforme em $PBT_RESORTEIO_TETO sorteios seguidos ('$_tipos_str')"; exit 1
    fi
  done
  # shellcheck disable=SC2086
  set -- $_tipos_str
  [ "$forcar_mista" -eq 1 ] && hist_mista_padroes="$hist_mista_padroes|$*"

  feed=""
  publica=0
  line_i=1
  for tipo in "$@"; do
    if [ "$tipo" -eq 0 ]; then
      feed="${feed}(delete) $ZERO refs/heads/r${case_i}_${line_i} $SHA
"
    else
      # remote_sha da publicação sorteado dos bits altos do LCG (issues #132/#134, [3f]/[3g]):
      # 0 = branch nova (remote_sha zero, único formato testado antes desta rodada), 1 = branch
      # já existente (remote_sha real) — o classificador (linha ~240) olha só `local_sha`, e o
      # PBT precisa exercitar os dois formatos de publicação, não só o de branch nova.
      # $OLDSHA, nunca $SHA, para "branch existente": remote_sha == local_sha faria o gate
      # no-ai-attribution calcular `rsha..lsha` como um range VAZIO (mesmo commit dos dois lados)
      # e disparar o próprio fail-safe de universo vazio dele — sintoma alheio ao classificador
      # sob teste aqui.
      lcg_draw 2; _pbt_rsha_existente=$_lcg_draw
      if [ "$_pbt_rsha_existente" -eq 1 ]; then rsha_pub="$OLDSHA"; else rsha_pub="$ZERO"; fi
      feed="${feed}refs/heads/r${case_i}_${line_i} $SHA refs/heads/r${case_i}_${line_i} $rsha_pub
"
      publica=1
    fi
    line_i=$((line_i + 1))
  done
  esperado_roda=1
  [ "$n" -gt 0 ] && [ "$publica" -eq 0 ] && esperado_roda=0
  if [ "$n" -eq 0 ]; then cnt_vazio=$((cnt_vazio + 1))
  elif [ "$publica" -eq 0 ]; then cnt_so_delecao=$((cnt_so_delecao + 1))
  else cnt_mista=$((cnt_mista + 1))
  fi
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
n_livre_distintos="$(printf '%s\n' $hist_n_livre | sort -u | tr '\n' ' ')"
n_livre_distintos="${n_livre_distintos% }"
n_so_delecao_distintos="$(printf '%s\n' $hist_n_so_delecao | sort -u | tr '\n' ' ')"
n_so_delecao_distintos="${n_so_delecao_distintos% }"
mista_lista="$(printf '%s' "$hist_mista_padroes" | tr '|' '\n' | grep -v '^$')"
mista_padroes_distintos="$(printf '%s\n' "$mista_lista" | sort -u | wc -l | tr -d ' ')"
# Não alternado = ao menos dois tipos iguais vizinhos ("0 0" ou "1 1"). Publicação seguida de >=2 deleções até o fim da lista = a forma que mata o mutante de adjacência [3e]: as deleções vizinhas vêm DEPOIS da última publicação, e nenhuma publicação posterior restaura o contador.
mista_nao_alternados="$(printf '%s\n' "$mista_lista" | grep -cE '(^|[[:space:]])(0 0|1 1)([[:space:]]|$)')"
mista_pub_del_del="$(printf '%s\n' "$mista_lista" | grep -cE '(^|[[:space:]])1( 0){2,}$')"
[ "$cnt_vazio" -ge 12 ] || { echo "FAIL [4]: histograma degenerado — vazio=$cnt_vazio (esperado >=12)"; exit 1; }
[ "$cnt_so_delecao" -ge 12 ] || { echo "FAIL [4]: histograma degenerado — só-deleção=$cnt_so_delecao (esperado >=12)"; exit 1; }
[ "$cnt_mista" -ge 12 ] || { echo "FAIL [4]: histograma degenerado — mista=$cnt_mista (esperado >=12)"; exit 1; }
[ "$mista_nao_alternados" -ge 1 ] || { echo "FAIL [4]: gerador degenerado — nenhum padrão do estrato misto tem dois tipos iguais adjacentes (sequência estritamente alternada, bit baixo do LCG); padrões: $(printf '%s' "$hist_mista_padroes" | tr '|' ';')"; exit 1; }
[ "$mista_pub_del_del" -ge 1 ] || { echo "FAIL [4]: gerador degenerado — nenhum padrão do estrato misto tem publicação seguida de >=2 deleções até o fim da lista; padrões: $(printf '%s' "$hist_mista_padroes" | tr '|' ';')"; exit 1; }
for want_n in 1 2 3 4 5 6; do
  case " $n_so_delecao_distintos " in *" $want_n "*) : ;; *)
    echo "FAIL [4]: estrato só-deleção não cobriu n=$want_n — distintos: ${n_so_delecao_distintos:-nenhum} (troque SEED)"; exit 1 ;;
  esac
done
SCEN=$((SCEN + 1))
echo "OK [4] — propriedade sobrevive a $pbt_n casos (semente $SEED, LCG próprio, bits altos); histograma: vazio=$cnt_vazio só-deleção=$cnt_so_delecao mista=$cnt_mista; n distintos no estrato só-deleção (1-6 exigidos): $n_so_delecao_distintos; n distintos no estrato livre: ${n_livre_distintos:-nenhum}; estrato misto: $mista_padroes_distintos padrões distintos, $mista_nao_alternados não alternados, $mista_pub_del_del com publicação seguida de >=2 deleções no fim, $cnt_resorteios resorteio(s)"

# ── [5] mutação — remover o curto-circuito ──────────────────────────────────────────────────────
# Muta a CÓPIA do hook dentro da fixture (nunca o arquivo de produção real do template — "uma
# árvore, um escritor": este gate só mede a própria fixture, isolada em $T).
echo "[5] mutação — remover o curto-circuito faz [1] gravar o marker"
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
