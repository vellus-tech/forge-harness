#!/usr/bin/env bash
# Gate W324 - LDG-1626: bats só usa o exit code da ÚLTIMA instrução do corpo de um @test pra
# decidir pass/fail. Uma asserção "[ ]"/"[[ ]]" fora de `run`, sem "||"/"return"/"exit"/"assert_",
# que falha NO MEIO do teste, não aborta nada - as linhas seguintes continuam rodando e só a
# última decide. Achado real na sessão CODER (LDG-0065, Payments.Deploy): um @test com 4
# linhas de asserção reportou "ok" mesmo com o código no estado anterior ao fix, porque só a
# última linha era de fato verificada. Medição subsequente: ~51% dos testes bats em 5 repos do
# workspace Payments têm esse defeito.
#
#   [1]  @test com 2+ asserções sem guarda é acusado por --path, com arquivo:linha
#   [2]  @test com "|| return 1" em cada asserção não é acusado
#   [3]  @test com só 1 linha de asserção (a própria "run ...; [ status ]" como última) não é
#        acusado - o idioma comum de 1 asserção já é seguro por construção
#   [4]  universo vazio (diretório sem .bats) REPROVA em --path
#   [5]  range: @test NOVO com o defeito, introduzido no diff, é acusado
#   [6]  range: @test pré-existente com o defeito, em arquivo tocado por uma linha que não entra
#        em nenhum @test, NÃO é acusado - o gate audita o que o diff muda, não o arquivo inteiro
#   [7]  range: zero arquivo .bats tocado no range é OK (não é vacuidade - nada a auditar)
#   [8]  report: nunca reprova (exit 0) mesmo com violação real, e lista cada achado
#   [9]  mutação: reduzir o limiar de "2+ assertivas sem guarda" pra "1+" faz o cenário [3]
#        (seguro) passar a ser acusado - prova que o limiar de 2 não é vácuo/decorativo
set -uo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado faria os comandos git das fixtures obedecerem ao
# repositório de quem invoca o gate.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="$WS/template/.forge/scripts/check-bats-assertion-abort.sh"
LIBDIR="$WS/template/.forge/scripts/lib"

[ -f "$LINT" ] || { echo "FAIL [0]: $LINT não existe - o gate do LDG-1626 não foi entregue"; exit 1; }

T="$(mktemp -d /tmp/forge-w324.XXXXXX)"
trap 'rm -rf "$T"' EXIT

run_lint() { # run_lint <args...> - saída em $out, rc em $rc
  out="$(FORGE_ROOT="$T/repo" bash "$LINT" "$@" 2>&1)"; rc=$?
}

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] @test com 2+ asserções sem guarda é acusado por --path, com arquivo:linha"
mkdir -p "$T/c1"
cat > "$T/c1/x.bats" << 'EOF'
#!/usr/bin/env bats
@test "vulneravel" {
  run echo x
  [ "$status" -eq 0 ]
  [[ "$output" == "nomatch" ]]
}
EOF
run_lint --path "$T/c1"
[ "$rc" -ne 0 ] || { echo "FAIL [1]: lint aprovou @test com 2 asserções sem guarda (saída: '$out')"; exit 1; }
case "$out" in
  *"x.bats:2"*) : ;;
  *) echo "FAIL [1]: lint acusou sem nomear arquivo:linha (saída: '$out')"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] @test com '|| return 1' em cada asserção não é acusado"
mkdir -p "$T/c2"
cat > "$T/c2/x.bats" << 'EOF'
#!/usr/bin/env bats
@test "guardado" {
  run echo x
  [ "$status" -eq 0 ] || return 1
  [[ "$output" == "x" ]] || return 1
}
EOF
run_lint --path "$T/c2"
[ "$rc" -eq 0 ] || { echo "FAIL [2]: lint acusou @test corretamente guardado (saída: '$out')"; exit 1; }
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] @test com só 1 linha de asserção (idioma comum) não é acusado"
mkdir -p "$T/c3"
cat > "$T/c3/x.bats" << 'EOF'
#!/usr/bin/env bats
@test "uma asserção só" {
  run echo x
  [ "$status" -eq 0 ]
}
EOF
run_lint --path "$T/c3"
[ "$rc" -eq 0 ] || { echo "FAIL [3]: lint acusou @test com 1 única asserção - falso positivo esvazia o gate (saída: '$out')"; exit 1; }
echo "OK [3]"

# ── [4] AUTO-IRONIA ──────────────────────────────────────────────────────────────────────────
echo "[4] universo vazio (diretório sem .bats) REPROVA em --path"
mkdir -p "$T/c4vazio"
printf 'nada aqui\n' > "$T/c4vazio/README.md"
run_lint --path "$T/c4vazio"
[ "$rc" -ne 0 ] || { echo "FAIL [4]: --path aprovou universo vazio - é a mesma instância que o próprio gate ataca (saída: '$out')"; exit 1; }
case "$out" in
  *universo-vazio*) : ;;
  *) echo "FAIL [4]: reprovou sem nomear o estado de universo vazio (saída: '$out')"; exit 1 ;;
esac
echo "OK [4]"

# ── setup de repo git para os cenários de range ──────────────────────────────────────────────
mkrepo() {
  rm -rf "$T/repo"
  mkdir -p "$T/repo/tests"
  (cd "$T/repo" && git init -q -b main && git config user.email a@a.com && git config user.name a)
}

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] range: @test NOVO com o defeito, introduzido no diff, é acusado"
mkrepo
cat > "$T/repo/tests/novo.bats" << 'EOF'
#!/usr/bin/env bats
@test "placeholder" {
  run true
  [ "$status" -eq 0 ]
}
EOF
(cd "$T/repo" && git add -A && git commit -q -m base)
cat > "$T/repo/tests/novo.bats" << 'EOF'
#!/usr/bin/env bats
@test "placeholder" {
  run true
  [ "$status" -eq 0 ]
}
@test "novo vulneravel" {
  run echo x
  [ "$status" -eq 0 ]
  [[ "$output" == "nomatch" ]]
}
EOF
(cd "$T/repo" && git add -A && git commit -q -m novo)
out="$(cd "$T/repo" && FORGE_ROOT="$T/repo" bash "$LINT" range HEAD~1..HEAD 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [5]: range não acusou @test novo vulnerável (saída: '$out')"; exit 1; }
case "$out" in
  *"novo vulneravel"*) : ;;
  *) echo "FAIL [5]: acusou sem nomear o @test novo (saída: '$out')"; exit 1 ;;
esac
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] range: @test pré-existente vulnerável, arquivo tocado fora de qualquer @test, NÃO é acusado"
mkrepo
cat > "$T/repo/tests/legado.bats" << 'EOF'
#!/usr/bin/env bats
@test "legado vulneravel" {
  run echo x
  [ "$status" -eq 0 ]
  [[ "$output" == "nomatch" ]]
}
EOF
(cd "$T/repo" && git add -A && git commit -q -m base)
printf '\n# comentario inofensivo, fora de qualquer @test\n' >> "$T/repo/tests/legado.bats"
(cd "$T/repo" && git add -A && git commit -q -m toque)
out="$(cd "$T/repo" && FORGE_ROOT="$T/repo" bash "$LINT" range HEAD~1..HEAD 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [6]: range acusou @test pré-existente não tocado pelo diff (saída: '$out')"; exit 1; }
echo "OK [6]"

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
echo "[7] range: zero arquivo .bats tocado no range é OK (não é vacuidade)"
mkrepo
echo "x" > "$T/repo/outro.txt"
(cd "$T/repo" && git add -A && git commit -q -m base)
echo "y" >> "$T/repo/outro.txt"
(cd "$T/repo" && git add -A && git commit -q -m toque)
out="$(cd "$T/repo" && FORGE_ROOT="$T/repo" bash "$LINT" range HEAD~1..HEAD 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [7]: range sem .bats tocado reprovou como se fosse vacuidade (saída: '$out')"; exit 1; }
echo "OK [7]"

# ── [8] ──────────────────────────────────────────────────────────────────────────────────────
echo "[8] report: nunca reprova (exit 0) mesmo com violação real, e lista o achado"
run_lint report "$T/c1"
[ "$rc" -eq 0 ] || { echo "FAIL [8]: report reprovou (deveria ser inventário, nunca gate) (saída: '$out')"; exit 1; }
case "$out" in
  *"x.bats:2"*) : ;;
  *) echo "FAIL [8]: report não listou o achado conhecido (saída: '$out')"; exit 1 ;;
esac
echo "OK [8]"

# ── [9] MUTAÇÃO ──────────────────────────────────────────────────────────────────────────────
echo "[9] mutação: baixar o limiar de 2 pra 1 asserção sem guarda faz o cenário seguro [3] reprovar"
# A mutação nunca toca a árvore rastreada (LDG-0201/w213-arvore-rastreada): copia o
# template/.forge/scripts/ inteiro pra um sandbox sob $T e muta só a cópia ali.
rm -rf "$T/scripts-mut"
cp -R "$WS/template/.forge/scripts" "$T/scripts-mut"
sed -i.bak 's/bare\.length >= 2/bare.length >= 1/' "$T/scripts-mut/lib/bats-assertion-lint.mjs"
out="$(FORGE_ROOT="$T/repo" bash "$T/scripts-mut/check-bats-assertion-abort.sh" --path "$T/c3" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [9]: mutação do limiar não mudou nada - o limiar de 2 pode ser decorativo (saída: '$out')"; exit 1; }
echo "OK [9]"

echo "W324 bats-assertion-abort-gate: todos os cenários passaram"
