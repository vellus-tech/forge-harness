#!/usr/bin/env bash
# Gate W281 — /forge:red replay aceita test_id na forma real do teste (issue #190).
#
# Por que existe: o motor do replay (template/.forge/scripts/lib/red-replay.mjs) exigia que o
# test_id declarado fosse SUBSTRING LITERAL do arquivo de teste. A forma natural de nomear um caso
# xUnit/.NET — `Classe.Metodo`, ou o nome totalmente qualificado que `dotnet test --filter
# FullyQualifiedName~` e o relatório do xUnit usam — nunca aparece assim num .cs (classe e método
# ficam em linhas diferentes). O replay respondia NOT-POSSIBLE ("test_id declarado não aparece em
# <arquivo> nem em HEAD") sobre um caso que existe, veredito que a rule trata como válido e que
# empurra para waiver indevido. Medido em campo (change account-360-scope-decoupling): o mesmo
# teste dava NOT-POSSIBLE com `Classe.Metodo` e OK com só o nome do método.
#
# Fixture: repositório temporário com o harness, um arquivo xUnit fictício e um "runner" bash que
# imprime a saída real do `dotnet test` (linha `Failed Ns.Classe.Metodo [12 ms]` e
# `Assert.Equal() Failure`). Histórico em três commits (código com bug → teste → correção), então
# a base deriva por ancestry. Tudo via CLI (`red-evidence.sh record` + `replay`), como o operador.
#
#   [1] CONTROLE — test_id = só o nome do método → observado (prova que o fixture reproduz o Red)
#   [2] test_id = Classe.Metodo → observado (antes: NOT-POSSIBLE falso — o defeito da issue)
#   [3] test_id = Namespace.Classe.Metodo (totalmente qualificado) → observado
#   [4] NEGATIVO — Classe.MetodoInexistente → NOT-POSSIBLE, e a mensagem diz o que foi procurado
#   [5] NEGATIVO — OutraClasse.Metodo (classe ausente do arquivo) → NOT-POSSIBLE
#   [6] NEGATIVO — Classe.Metodo, mas a linha de falha da saída é OUTRO caso da mesma classe e o
#       declarado aparece como Passed → FAIL test-id (a forma qualificada não afrouxa a verificação
#       (5): classe e método precisam estar na MESMA linha de falha, não espalhados pela saída)
#   [7] NEGATIVO — Classe.Metodo é prefixo de outro método (Metodo_Extra) e só ele existe → NOT-POSSIBLE
#       (classe e método casam como palavras inteiras, não como substring)
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w281.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q -b main
git -C "$T" config user.email t@t
git -C "$T" config user.name t
git -C "$T" config commit.gpgsign false
git -C "$T" add -A
git -C "$T" commit -qm "chore: init harness" >/dev/null

SN="$T/.forge/scripts/spec-new.sh"
RE="$T/.forge/scripts/red-evidence.sh"
status_of() { node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).status)" "$1"; }

CLS="PermissionResolverCeilingTests"
MTH="BuManager_ActivityView_ResolvesUnit"
NS="Azim.Crm.Tests"

mkdir -p "$T/src" "$T/tests/Azim.Crm.Tests"
printf 'scope=bu\n' > "$T/src/PermissionResolver.txt"
git -C "$T" add src/PermissionResolver.txt
git -C "$T" commit -qm "feat: resolver (com bug)" >/dev/null

# O arquivo de teste tem a forma real de um .cs: classe e método em linhas diferentes. Contém
# também um segundo caso (OutroCaso) e um método cujo nome começa com outro prefixo de propósito.
cat > "$T/tests/Azim.Crm.Tests/$CLS.cs" <<CS
namespace $NS;

public class $CLS
{
    [Fact]
    public void $MTH()
    {
        Assert.Equal("unit", Resolve());
    }

    [Fact]
    public void OutroCaso() { }

    [Fact]
    public void Prefixo_Extra() { }
}
CS
# Runner que imita `dotnet test --filter`: lê o "código" e imprime a saída do xUnit. Falhando,
# cita o caso cujo nome recebe como 1º argumento (default: o caso declarado); um 2º argumento
# opcional é impresso como caso que PASSOU, antes da falha — como o xUnit faz com casos vizinhos.
cat > "$T/tests/run-xunit.sh" <<'SH'
#!/usr/bin/env bash
caso="${1:-Azim.Crm.Tests.PermissionResolverCeilingTests.BuManager_ActivityView_ResolvesUnit}"
if grep -q 'scope=unit' src/PermissionResolver.txt; then
  echo "  Passed $caso [3 ms]"; echo "Passed!  - Failed: 0, Passed: 1"; exit 0
fi
[ -n "${2:-}" ] && echo "  Passed $2 [1 ms]"
echo "  Failed $caso [12 ms]"
echo "  Error Message:"
echo "   Assert.Equal() Failure: Strings differ"
echo "Failed!  - Failed: 1, Passed: 0"
exit 1
SH
chmod +x "$T/tests/run-xunit.sh"
git -C "$T" add tests
git -C "$T" commit -qm "test: regressão do teto de permissão" >/dev/null

printf 'scope=unit\n' > "$T/src/PermissionResolver.txt"
git -C "$T" add src/PermissionResolver.txt
git -C "$T" commit -qm "fix: resolver respeita o teto da unidade" >/dev/null

TEST_PATH="tests/Azim.Crm.Tests/$CLS.cs"

# replay_with <change> <test_id> [command] — grava e roda o replay; devolve rc e saída em OUT/RC.
replay_with() {
  local change="$1" tid="$2" cmd="${3:-bash tests/run-xunit.sh}"
  FORGE_ROOT="$T" bash "$SN" "$change" --type bugfix --scale 1 >/dev/null
  local rec
  rec="$(FORGE_ROOT="$T" bash "$RE" record "$change" --test-path "$TEST_PATH" --test-id "$tid" \
    --command "$cmd" --fix-files src/PermissionResolver.txt --failure-pattern 'Assert\.Equal\(\) Failure' 2>&1)"
  grep -q "OK record" <<<"$rec" || { echo "FAIL: record de $change não confirmou ($rec)"; exit 1; }
  set +e
  OUT="$(FORGE_ROOT="$T" bash "$RE" replay "$change" 2>&1)"; RC=$?
  set -e
}
ev_of() { echo "$T/.forge/specs/active/$1/evidence/red/red-evidence.json"; }

echo "[1] CONTROLE — test_id = só o método → observado"
replay_with c1 "$MTH"
[ "$RC" -eq 0 ] || { echo "FAIL [1]: rc=$RC — o fixture não reproduz o Red ($OUT)"; exit 1; }
[ "$(status_of "$(ev_of c1)")" = "observed" ] || { echo "FAIL [1]: status != observed"; exit 1; }
echo "OK [1]"

echo "[2] test_id = Classe.Metodo → observado"
replay_with c2 "$CLS.$MTH"
[ "$RC" -eq 0 ] || { echo "FAIL [2]: rc=$RC — Classe.Metodo recusado sobre caso existente ($OUT)"; exit 1; }
[ "$(status_of "$(ev_of c2)")" = "observed" ] || { echo "FAIL [2]: status != observed"; exit 1; }
echo "OK [2]"

echo "[3] test_id = Namespace.Classe.Metodo → observado"
replay_with c3 "$NS.$CLS.$MTH"
[ "$RC" -eq 0 ] || { echo "FAIL [3]: rc=$RC — nome totalmente qualificado recusado ($OUT)"; exit 1; }
[ "$(status_of "$(ev_of c3)")" = "observed" ] || { echo "FAIL [3]: status != observed"; exit 1; }
echo "OK [3]"

echo "[4] NEGATIVO — Classe.MetodoInexistente → NOT-POSSIBLE nomeando o que foi procurado"
replay_with c4 "$CLS.MetodoInexistente"
[ "$RC" -ne 0 ] || { echo "FAIL [4]: método inexistente aceito ($OUT)"; exit 1; }
grep -qi "not-possible\|NOT-POSSIBLE" <<<"$OUT" || { echo "FAIL [4]: esperava NOT-POSSIBLE ($OUT)"; exit 1; }
grep -q "MetodoInexistente" <<<"$OUT" || { echo "FAIL [4]: mensagem não diz o que foi procurado ($OUT)"; exit 1; }
grep -q "palavras inteiras" <<<"$OUT" || { echo "FAIL [4]: mensagem não explica a forma qualificada procurada ($OUT)"; exit 1; }
echo "OK [4]"

echo "[5] NEGATIVO — OutraClasse.Metodo → NOT-POSSIBLE"
replay_with c5 "OutraClasse.$MTH"
[ "$RC" -ne 0 ] || { echo "FAIL [5]: classe ausente do arquivo aceita ($OUT)"; exit 1; }
grep -qi "not-possible" <<<"$OUT" || { echo "FAIL [5]: esperava NOT-POSSIBLE ($OUT)"; exit 1; }
echo "OK [5]"

echo "[6] NEGATIVO — saída falha em OUTRO caso da mesma classe (o declarado aparece como Passed) → FAIL test-id"
replay_with c6 "$CLS.$MTH" "bash tests/run-xunit.sh $NS.$CLS.OutroCaso $NS.$CLS.$MTH"
[ "$RC" -ne 0 ] || { echo "FAIL [6]: falha de outro caso aceita como a declarada ($OUT)"; exit 1; }
grep -q "não menciona o caso declarado" <<<"$OUT" || { echo "FAIL [6]: esperava recusa do item test-id ($OUT)"; exit 1; }
echo "OK [6]"

echo "[7] NEGATIVO — Classe.Prefixo só casa como prefixo de Prefixo_Extra → NOT-POSSIBLE"
replay_with c7 "$CLS.Prefixo"
[ "$RC" -ne 0 ] || { echo "FAIL [7]: prefixo de método aceito como método ($OUT)"; exit 1; }
grep -qi "not-possible" <<<"$OUT" || { echo "FAIL [7]: esperava NOT-POSSIBLE ($OUT)"; exit 1; }
echo "OK [7]"

echo "PASS w281 — red-replay-test-id-qualificado"
