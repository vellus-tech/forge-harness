#!/usr/bin/env bash
# Gate W135 — o pre-push precisa dizer aos gates de `runtime.gates` O QUE está sendo publicado.
# O git entrega ao hook, por stdin, uma linha "<local ref> <local sha> <remote ref> <remote sha>"
# por ref empurrada. O hook consome esse stdin uma única vez (`INPUT="$(cat)"`), de modo que um
# gate invocado depois não tem como relê-lo: sem re-exportação, o gate só enxerga o que está em
# checkout. Os dois divergem em `git push origin outra-branch:main` e em push de múltiplas refs —
# um gate que resolve o alvo por `git rev-parse HEAD` valida o commit errado, e um gate que
# precisa cobrir TODAS as refs publicadas só vê uma.
#
# A re-exportação é por ARQUIVO, não por variável de ambiente com o payload dentro. O payload é
# ilimitado (`git push --all` num repositório com milhares de refs) e o kernel limita UMA string
# de ambiente a 128 KB no Linux (MAX_ARG_STRLEN). Acima disso todo exec dentro do hook falha com
# E2BIG — inclusive o awk que lê o FORGE.md — e o hook imprime "pre-push OK" sem ter rodado
# NADA. Um caminho tem algumas dezenas de bytes e nunca encosta no teto. Os cenários [3] e [4]
# existem para que essa escolha não regrida.
#   [1] FORGE_PUSH_REFS_FILE aponta para um arquivo com as linhas cruas do stdin, íntegras
#   [2] push de branch alheia — o gate vê o sha publicado, e o de HEAD não está lá
#   [3] push grande (2000 refs, ~236 KB) — typecheck, test e gates continuam rodando
#   [4] o arquivo temporário não sobrevive ao hook
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$WS/template/.forge/hooks"

T="$(mktemp -d /tmp/forge-w135.XXXXXX)"
trap 'rm -rf "$T"' EXIT

mkdir -p "$T/.forge/hooks/git" "$T/.forge/scripts"
cp "$HOOKS/git/pre-push" "$T/.forge/hooks/git/pre-push"
git -C "$T" init -q -b main

# typecheck e test declarados com echo: servem de sonda para o cenário [3], onde o modo de falha
# é justamente o awk que lê estes campos deixar de rodar.
cat > "$T/.forge/FORGE.md" <<'EOF'
runtime:
  typecheck: echo TYPECHECK-RAN
  test: echo TEST-RAN
  gates: check-pushrefs
EOF

# Alvos de delegação que o pre-push declara. A fixture instala um `.forge/scripts/` — e desde a
# issue #49 um diretório de scripts do harness presente com alvo declarado AUSENTE é erro, não
# no-op. Stubs neutros mantêm este gate medindo o que ele diz medir (a re-exportação do stdin do
# git), sem transformá-lo num teste de integridade da instalação (isso é o w147).
for _stub in check-ai-attribution.sh check-liaison-acks.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.forge/scripts/$_stub"
done

# O gate espia o que o hook lhe passou. Escreve em arquivo porque run_check desvia a saída
# do gate para um log temporário — o arquivo é o único canal observável pelo teste.
cat > "$T/.forge/scripts/check-pushrefs.sh" <<'EOF'
#!/usr/bin/env bash
root="$(git rev-parse --show-toplevel)"
if [ -z "${FORGE_PUSH_REFS_FILE-}" ]; then
  printf '<unset>' > "$root/seen-refs.txt"
elif [ ! -f "$FORGE_PUSH_REFS_FILE" ]; then
  printf '<inexistente:%s>' "$FORGE_PUSH_REFS_FILE" > "$root/seen-refs.txt"
else
  cp "$FORGE_PUSH_REFS_FILE" "$root/seen-refs.txt"
  printf '%s' "$FORGE_PUSH_REFS_FILE" > "$root/seen-path.txt"
fi
exit 0
EOF

run_hook() {  # run_hook <arquivo-de-feed> — ecoa a saída, devolve o rc do hook
  rm -f "$T/seen-refs.txt" "$T/seen-path.txt"
  (cd "$T" && bash .forge/hooks/git/pre-push origin "file://$T" < "$1" 2>&1)
}

echo "[1] FORGE_PUSH_REFS_FILE aponta para as linhas cruas do stdin"
printf 'refs/heads/main %s refs/heads/main %s\nrefs/heads/topic %s refs/heads/topic %s\n' \
  "$(printf 'a%.0s' $(seq 40))" "$(printf '1%.0s' $(seq 40))" \
  "$(printf 'b%.0s' $(seq 40))" "$(printf '0%.0s' $(seq 40))" > "$T/feed1"
out="$(run_hook "$T/feed1")"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL [1]: pre-push bloqueou (rc=$rc) — o cenário é um push legítimo"; echo "$out"; exit 1
fi
if [ ! -f "$T/seen-refs.txt" ]; then
  echo "FAIL [1]: o gate declarado em runtime.gates não chegou a rodar"; echo "$out"; exit 1
fi
seen="$(cat "$T/seen-refs.txt")"
case "$seen" in
  '<unset>')        echo "FAIL [1]: FORGE_PUSH_REFS_FILE não foi exportado — o gate não sabe o que está sendo publicado"; exit 1 ;;
  '<inexistente:'*) echo "FAIL [1]: FORGE_PUSH_REFS_FILE aponta para arquivo que não existe ($seen)"; exit 1 ;;
esac
if ! diff -q "$T/feed1" "$T/seen-refs.txt" >/dev/null 2>&1; then
  echo "FAIL [1]: o conteúdo visto pelo gate difere do stdin do git"
  echo "--- esperado ---"; cat "$T/feed1"
  echo "--- visto ---";    cat "$T/seen-refs.txt"
  exit 1
fi
echo "OK [1]"

echo "[2] push de branch alheia — o gate vê o sha publicado, não o de HEAD"
git -C "$T" -c user.email=w135@t -c user.name=w135 commit -q --allow-empty -m "base"
head_sha="$(git -C "$T" rev-parse HEAD)"
other_sha="$(printf 'c%.0s' $(seq 40))"
printf 'refs/heads/outra %s refs/heads/main %s\n' "$other_sha" "$(printf '1%.0s' $(seq 40))" > "$T/feed2"
out2="$(run_hook "$T/feed2")"; rc2=$?
if [ "$rc2" -ne 0 ]; then echo "FAIL [2]: pre-push bloqueou (rc=$rc2)"; echo "$out2"; exit 1; fi
seen2="$(cat "$T/seen-refs.txt" 2>/dev/null || echo '<ausente>')"
case "$seen2" in
  *"$other_sha"*) : ;;
  *) echo "FAIL [2]: o gate não recebeu o sha publicado ($other_sha); recebeu: $seen2"; exit 1 ;;
esac
case "$seen2" in
  *"$head_sha"*) echo "FAIL [2]: o gate recebeu o sha de HEAD ($head_sha) — resolveu o alvo pelo checkout, não pelo push"; exit 1 ;;
esac
echo "OK [2]"

echo "[3] push grande (12000 refs) — typecheck, test e gates continuam rodando"
# Regressão do E2BIG: com o payload no ambiente, TODO exec dentro do hook falha acima do teto do
# kernel — inclusive o awk do fm_field. O hook então não acha typecheck/test/gates, anuncia
# "pre-push OK" e sai 0 sem ter verificado nada. O tamanho precisa passar dos DOIS tetos, porque
# eles são muito diferentes: ~128 KB por string de ambiente no Linux (MAX_ARG_STRLEN) e ~1 MB de
# argv+envp somados no macOS. Um feed de 128 KB deixaria o cenário verde por vacuidade no macOS,
# que é onde o hook roda todo dia.
awk 'BEGIN { a = sprintf("%040d", 0); gsub(/0/, "a", a); z = sprintf("%040d", 0); gsub(/0/, "1", z);
             for (i = 0; i < 12000; i++) printf "refs/heads/b%05d %s refs/heads/b%05d %s\n", i, a, i, z }' > "$T/feed3"
bytes="$(wc -c < "$T/feed3" | tr -d ' ')"
if [ "$bytes" -lt 1200000 ]; then
  echo "FAIL [3]: o feed grande tem só $bytes bytes — abaixo do teto do macOS (~1 MB), o cenário passaria por vacuidade"; exit 1
fi
out3="$(run_hook "$T/feed3")"; rc3=$?
if [ "$rc3" -ne 0 ]; then echo "FAIL [3]: pre-push bloqueou num push grande legítimo (rc=$rc3)"; echo "$out3"; exit 1; fi
case "$out3" in
  *"Argument list too long"*) echo "FAIL [3]: E2BIG — o payload está sendo passado pelo ambiente ($bytes bytes)"; echo "$out3"; exit 1 ;;
esac
grep -q 'typecheck OK' <<<"$out3" || { echo "FAIL [3]: o typecheck não rodou num push de $bytes bytes"; echo "$out3"; exit 1; }
grep -q 'test OK'      <<<"$out3" || { echo "FAIL [3]: o test não rodou num push de $bytes bytes"; echo "$out3"; exit 1; }
if [ ! -f "$T/seen-refs.txt" ]; then
  echo "FAIL [3]: o gate de runtime.gates não rodou num push de $bytes bytes — o hook passou sem verificar nada"
  echo "$out3"; exit 1
fi
if ! diff -q "$T/feed3" "$T/seen-refs.txt" >/dev/null 2>&1; then
  echo "FAIL [3]: o conteúdo de $bytes bytes chegou truncado ou alterado ao gate"; exit 1
fi
echo "OK [3] ($bytes bytes)"

echo "[4] o arquivo temporário não sobrevive ao hook"
leaked="$(cat "$T/seen-path.txt" 2>/dev/null || true)"
[ -n "$leaked" ] || { echo "FAIL [4]: o gate não registrou o caminho recebido — cenário [1]/[3] não chegou a rodar"; exit 1; }
if [ -e "$leaked" ]; then
  echo "FAIL [4]: '$leaked' continua no disco depois do hook — vazamento de temporário a cada push"
  rm -f "$leaked"
  exit 1
fi
echo "OK [4]"

echo "PASS w135-push-refs-export-gate"
