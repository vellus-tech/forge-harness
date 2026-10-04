#!/usr/bin/env bash
# Gate W283 — issue #191: exceção de setup de fixture xUnit (IAsyncLifetime.InitializeAsync,
# construtor) ficava classificada como 'unknown' por lib/red-classify.mjs — não produz
# `Xunit.Sdk.` nem `Assert.X() Failure` — e o `/forge:red replay` nunca chegava a `observed`
# num bugfix cujo defeito É o setup falhar (imagem de Testcontainers que não pode ser puxada).
#
# A correção cria a classe própria 'setup-exception' (nem 'behavioral', nem 'build-error') e a
# política única `countsAsRed` em red-classify.mjs: exceção de setup só conta como Red quando
# `failure_pattern` está declarado e casa com a saída — sem âncora, uma exceção de ambiente
# (Docker parado, porta ocupada, credencial ausente) passaria por Red observado.
#
#   [1] classify(saída VSTest en-US de exceção de setup) = 'setup-exception', não 'unknown'
#   [2] classify(saída VSTest pt-BR — "Com falha"/"Mensagem de erro:") = 'setup-exception'
#   [3] contrafactuais: asserção xUnit continua 'behavioral'; erro de build .NET continua
#       'build-error'; prosa solta com "Error Message:" sem [FAIL]/Failed continua 'unknown'
#   [4] countsAsRed: setup-exception + failure_pattern que casa = true; sem failure_pattern = false;
#       failure_pattern que não casa = false; build-error/unknown nunca contam
#   [5] replay real (red-evidence.sh record + replay) de exceção de setup com failure_pattern
#       "pull access denied" -> status observed, classification 'setup-exception' gravada
#   [6] replay() com exceção de setup SEM failure_pattern -> não observed (item 3)
#   [7] replay() com exceção de setup e failure_pattern que não casa -> não observed (item 3)
#   [8] check-red-first estático: excerpt de exceção de setup com failure_pattern casando não gera
#       achado de item 3; sem casar, gera
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo
# obedecerem ao repositório de quem invocou o gate, e não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w283.XXXXXX)"
trap 'rm -rf "$T"' EXIT

LIB="$WS/template/.forge/scripts/lib"
CASES=0
ok() { CASES=$((CASES + 1)); echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }

# Saída real do `dotnet test` (VSTest, logger console) quando o InitializeAsync de uma fixture com
# Testcontainers.Minio lança porque a imagem saiu do Docker Hub — o caso da issue.
cat > "$T/xunit-setup-en.txt" <<'TXT'
  Determining projects to restore...
  All projects are up-to-date for restore.
  Azim.Tests -> /src/Azim.Tests/bin/Debug/net8.0/Azim.Tests.dll
Test run for /src/Azim.Tests/bin/Debug/net8.0/Azim.Tests.dll (.NETCoreApp,Version=v8.0)
VSTest version 17.11.1 (arm64)

Starting test execution, please wait...
A total of 1 test files matched the specified pattern.
[xUnit.net 00:00:02.41]     Azim.Tests.Storage.MinioStorageTests.Upload_Works [FAIL]
  Failed Azim.Tests.Storage.MinioStorageTests.Upload_Works [1 ms]
  Error Message:
   Docker.DotNet.DockerApiException : Docker API responded with status code=NotFound, response={"message":"pull access denied for minio/minio, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
  Stack Trace:
     at Docker.DotNet.DockerClient.HandleIfErrorResponseAsync(HttpStatusCode statusCode, HttpResponseMessage response)
     at DotNet.Testcontainers.Clients.DockerImageOperations.CreateAsync(IImage image, IDockerRegistryAuthenticationConfiguration dockerRegistryAuthConfig, CancellationToken ct)
     at Azim.Tests.Storage.MinioFixture.InitializeAsync() in /src/Azim.Tests/Storage/MinioFixture.cs:line 18

Failed!  - Failed:     1, Passed:     0, Skipped:     0, Total:     1, Duration: < 1 ms - Azim.Tests.dll (net8.0)
TXT

cat > "$T/xunit-setup-pt.txt" <<'TXT'
Iniciando execução de teste, espere...
[xUnit.net 00:00:02.41]     Azim.Tests.Storage.MinioStorageTests.Upload_Works [FAIL]
  Com falha Azim.Tests.Storage.MinioStorageTests.Upload_Works [1 ms]
  Mensagem de erro:
   System.AggregateException : One or more errors occurred. (Docker API responded with status code=NotFound, response={"message":"pull access denied for minio/minio"})
  Rastreamento de pilha:
     at Azim.Tests.Storage.MinioFixture.InitializeAsync() in /src/Azim.Tests/Storage/MinioFixture.cs:line 18
Com falha!  – Com falha:     1, Aprovado:     0, Ignorado:     0, Total:     1
TXT

cat > "$T/xunit-assert.txt" <<'TXT'
[xUnit.net 00:00:00.51]     Azim.Tests.SumTests.Adds [FAIL]
  Failed Azim.Tests.SumTests.Adds [3 ms]
  Error Message:
   Assert.Equal() Failure: Values differ
Expected: 5
Actual:   -1
  Stack Trace:
     at Azim.Tests.SumTests.Adds() in /src/Azim.Tests/SumTests.cs:line 9
TXT

cat > "$T/dotnet-build.txt" <<'TXT'
  Determining projects to restore...
/src/Azim/Storage.cs(12,5): error CS0246: The type or namespace name 'MinioClient' could not be found [/src/Azim/Azim.csproj]
Build FAILED.
TXT

cat > "$T/prose.txt" <<'TXT'
Notas da reunião: o campo Error Message: InvalidOperationException aparece no log do servidor.
TXT

cls() { node --input-type=module -e "import { classify } from '$LIB/red-classify.mjs'; import { readFileSync } from 'node:fs'; console.log(classify(readFileSync(process.argv[1], 'utf8')));" "$1"; }

echo "[1] exceção de setup xUnit (VSTest en-US) -> setup-exception"
got="$(cls "$T/xunit-setup-en.txt")"
[ "$got" = "setup-exception" ] || fail 1 "esperava 'setup-exception', obtido '$got'"
ok 1

echo "[2] exceção de setup xUnit (VSTest pt-BR) -> setup-exception"
got="$(cls "$T/xunit-setup-pt.txt")"
[ "$got" = "setup-exception" ] || fail 2 "esperava 'setup-exception', obtido '$got'"
ok 2

echo "[3] contrafactuais: asserção, build e prosa não mudam de classe"
got="$(cls "$T/xunit-assert.txt")"; [ "$got" = "behavioral" ] || fail 3 "asserção xUnit: esperava 'behavioral', obtido '$got'"
got="$(cls "$T/dotnet-build.txt")"; [ "$got" = "build-error" ] || fail 3 "erro de build .NET: esperava 'build-error', obtido '$got'"
got="$(cls "$T/prose.txt")"; [ "$got" = "unknown" ] || fail 3 "prosa solta: esperava 'unknown', obtido '$got'"
ok 3

echo "[4] countsAsRed: setup-exception só conta com failure_pattern declarado que casa"
out="$(node --input-type=module -e "
import { classify, countsAsRed } from '$LIB/red-classify.mjs';
import { readFileSync } from 'node:fs';
const setup = readFileSync('$T/xunit-setup-en.txt', 'utf8');
const assertion = readFileSync('$T/xunit-assert.txt', 'utf8');
const build = readFileSync('$T/dotnet-build.txt', 'utf8');
const c = classify(setup);
const r = [
  countsAsRed(c, setup, 'pull access denied') === true,
  countsAsRed(c, setup, null) === false,
  countsAsRed(c, setup, '') === false,
  countsAsRed(c, setup, 'Connection refused') === false,
  countsAsRed(classify(assertion), assertion, 'Values differ') === true,
  countsAsRed(classify(build), build, 'error CS0246') === false,
  countsAsRed('unknown', 'qualquer coisa', 'qualquer') === false,
];
console.log(r.join(','));
" 2>&1)" || fail 4 "node falhou: $out"
[ "$out" = "true,true,true,true,true,true,true" ] || fail 4 "esperava todos true, obtido '$out'"
ok 4

# ── fixture de replay: um "teste" que imprime a saída xUnit real quando a imagem é a quebrada ──
cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q -b main
git -C "$T" config user.email t@t
git -C "$T" config user.name t
git -C "$T" config commit.gpgsign false
git -C "$T" add .forge
git -C "$T" commit -qm "chore: init harness" >/dev/null
# Mesma topologia do w107 [1] (estratégia ancestry): defeito, teste e correção em commits separados.
mkdir -p "$T/src" "$T/tests"
echo "minio/minio" > "$T/src/minio-image.txt"
git -C "$T" add src/minio-image.txt
git -C "$T" commit -qm "feat: fixture minio com imagem minio/minio (defeito)" >/dev/null
cp "$T/xunit-setup-en.txt" "$T/tests/setup-failure.txt"
cat > "$T/tests/minio.test.sh" <<'SH'
#!/usr/bin/env bash
# Azim.Tests.Storage.MinioStorageTests.Upload_Works
cd "$(dirname "$0")/.."
if grep -q '^minio/minio$' src/minio-image.txt; then
  cat tests/setup-failure.txt
  exit 1
fi
echo "Passed!  - Failed:     0, Passed:     1, Skipped:     0, Total:     1"
SH
git -C "$T" add tests
git -C "$T" commit -qm "test: regressão minio (setup da fixture lança)" >/dev/null
echo "quay.io/minio/minio" > "$T/src/minio-image.txt"
git -C "$T" add src/minio-image.txt
git -C "$T" commit -qm "fix: minio — imagem fora do Docker Hub" >/dev/null

SN="$T/.forge/scripts/spec-new.sh"
RE="$T/.forge/scripts/red-evidence.sh"
TID="Azim.Tests.Storage.MinioStorageTests.Upload_Works"

echo "[5] replay real de exceção de setup com failure_pattern -> observed"
FORGE_ROOT="$T" bash "$SN" fix-minio --type bugfix --scale 1 >/dev/null
EV="$T/.forge/specs/active/fix-minio/evidence/red/red-evidence.json"
out="$(FORGE_ROOT="$T" bash "$RE" record fix-minio --test-path tests/minio.test.sh --test-id "$TID" --command "bash tests/minio.test.sh" --fix-files src/minio-image.txt --failure-pattern "pull access denied" 2>&1)" || fail 5 "record falhou: $out"
set +e
out="$(FORGE_ROOT="$T" bash "$RE" replay fix-minio 2>&1)"; rc=$?
set -e
st="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).status)" "$EV")"
[ "$rc" -eq 0 ] && [ "$st" = "observed" ] || fail 5 "replay esperava observed com rc 0, obtido status '$st' rc $rc — saída: $out"
grep -q '"classification": "setup-exception"' "$EV" || fail 5 "classification 'setup-exception' não gravada em $EV"
ok 5

replay_js() { # replay_js <failure_pattern|__none__>
  node --input-type=module -e "
import { replay } from '$LIB/red-replay.mjs';
const fp = process.argv[1] === '__none__' ? undefined : process.argv[1];
const ev = { test_path: 'tests/minio.test.sh', test_id: '$TID', command: 'bash tests/minio.test.sh', fix_files: ['src/minio-image.txt'] };
if (fp !== undefined) ev.failure_pattern = fp;
const r = await replay({ root: '$T', evidence: ev });
console.log(r.verdict + '|' + (r.ruleItem || '') + '|' + (r.base && r.base.classification || ''));
" "$1"
}

echo "[6] replay() de exceção de setup SEM failure_pattern -> não observed"
got="$(replay_js __none__)"
[ "${got%%|*}" != "observed" ] || fail 6 "exceção de setup sem âncora virou observed ($got)"
[ "$got" = "fail|3|setup-exception" ] || fail 6 "esperava 'fail|3|setup-exception', obtido '$got'"
ok 6

echo "[7] replay() de exceção de setup com failure_pattern que não casa -> não observed"
got="$(replay_js 'Connection refused')"
[ "$got" = "fail|3|setup-exception" ] || fail 7 "esperava 'fail|3|setup-exception', obtido '$got'"
ok 7

echo "[8] check-red-first estático aceita setup-exception só com failure_pattern casando"
set +e
chk="$(cd "$T" && FORGE_ROOT="$T" bash .forge/scripts/check-red-first.sh check fix-minio 2>&1)"; crc=$?
set -e
# Controle positivo: o check precisa ter EXAMINADO a evidência (rc 0, sem usage) — um check que não
# rodou também não acusa item 3, e a ausência de achado não provaria nada.
[ "$crc" -eq 0 ] || fail 8 "check-red-first reprovou evidência observada com âncora casando (rc $crc): $chk"
grep -q "item 3" <<<"$chk" && fail 8 "check-red-first acusou item 3 numa evidência observada com âncora casando: $chk"
node -e "
const fs = require('fs'); const p = process.argv[1];
const j = JSON.parse(fs.readFileSync(p, 'utf8')); j.failure_pattern = 'Connection refused';
for (const e of j.entries || []) e.failure_pattern = 'Connection refused';
fs.writeFileSync(p, JSON.stringify(j, null, 2) + '\n');
" "$EV"
set +e
chk="$(cd "$T" && FORGE_ROOT="$T" bash .forge/scripts/check-red-first.sh check fix-minio 2>&1)"; crc=$?
set -e
[ "$crc" -ne 0 ] || fail 8 "check-red-first aprovou (rc 0) exceção de setup com failure_pattern que não casa: $chk"
grep -q "setup-exception.*item 3" <<<"$chk" || fail 8 "check-red-first não acusou item 3 com failure_pattern que não casa: $chk"
ok 8

[ "$CASES" -eq 8 ] || { echo "FAIL w283/contador — $CASES caso(s) executado(s), esperava 8"; exit 1; }
echo "OK w283/red-xunit-setup-exception — $CASES caso(s) examinado(s)"
