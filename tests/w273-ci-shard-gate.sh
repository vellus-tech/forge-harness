#!/usr/bin/env bash
# Gate W273 — `tests/run-all.sh --shard K/N` fatia a suíte de forma determinista, e o CI roda as fatias em paralelo sem perder o nome do check obrigatório `gates`.
#
# POR QUE ESTE GATE EXISTE. O job `gates` do CI rodava os ~170 gates em série num runner só (~27 min medidos), com o teto de tempo sendo subido a cada leva de gates novos. A suíte passou a ser fatiada em N shards, cada um no seu runner; o que pode dar errado numa fatia é silencioso por natureza — um gate que cai em NENHUMA fatia some do CI sem reprovar nada, e um gate em DUAS fatias só custa minutos. Por isso o que se cobra aqui é a partição, não a velocidade.
#
#   [1]  partição: para N em 1..5, a união de `--list --shard K/N` (K = 1..N) é exatamente a lista de `--list` sem shard, sem repetição, na mesma ordem relativa; e o índice de cada gate na lista completa satisfaz índice mod N == K-1
#   [2]  as suítes bats ficam fixas no shard 1 — aparecem em `--shard 1/N` e em nenhum outro
#   [3]  K/N inválido sai rc 2 (0/3, 4/3, 1/0, a/b, 3, 1/3/2, -1/3, 01/3, vazio, --shard sem valor, --shard repetido)
#   [4]  execução real numa bancada isolada: os alvos que `--shard K/3` EXECUTA são exatamente os que `--list --shard K/3` lista (o filtro da listagem e o da execução são o mesmo)
#   [5]  ci.yml: o job da suíte é uma matrix de shards 1..N com `--shard ${{ matrix.shard }}/N` (o mesmo N), `fail-fast: false`; existe um job chamado exatamente `gates` com `needs:` que inclui a matrix e o job dos lints estáticos, com `if: always()` e que só passa quando todos os `needs` saíram `success` (job pulado conta como aprovado em branch protection — sem always() o check obrigatório passaria com um shard vermelho)
#   [6]  nenhum passo de segurança virou opcional: check-secrets, check-shell-pipeline, check-suite-wiring e red-evidence.sh ci continuam no ci.yml, num job que alimenta o `gates` final, e nenhum deles tem `continue-on-error`
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$WS/tests/run-all.sh"
CI="$WS/.github/workflows/ci.yml"
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w273.XXXXXX")"
trap 'rm -rf "$T"' EXIT

itens() { grep '^  ' | sed 's/^  //'; }   # as linhas de item do --list (indentadas com dois espaços)

echo "[1] partição: a união dos shards é a lista completa, sem repetição, por índice mod N"
FULL="$T/full.txt"
bash "$RUNNER" --list | itens > "$FULL" || { echo "FAIL [1]: --list sem shard falhou"; exit 1; }
FULL_GATES="$T/full-gates.txt"
grep -- '-gate\.sh$' "$FULL" > "$FULL_GATES"
n_full="$(wc -l < "$FULL" | tr -d ' ')"
n_gates="$(wc -l < "$FULL_GATES" | tr -d ' ')"
# contador de controle independente do parse do --list: o glob em disco
n_disco="$(ls "$WS"/tests/*-gate.sh | wc -l | tr -d ' ')"
[ "$n_gates" -gt 0 ] && [ "$n_gates" -eq "$n_disco" ] || { echo "FAIL [1]: --list trouxe $n_gates gates, o disco tem $n_disco — o parse do gate não mede o que pensa"; exit 1; }
casos=0
for N in 1 2 3 4 5; do
  : > "$T/uniao.txt"
  for K in $(seq 1 "$N"); do
    out="$(bash "$RUNNER" --list --shard "$K/$N")"; rc=$?
    [ "$rc" -eq 0 ] || { echo "FAIL [1]: --list --shard $K/$N saiu rc=$rc"; echo "$out"; exit 1; }
    printf '%s\n' "$out" | itens >> "$T/uniao.txt"
    # índice mod N == K-1, contra a lista completa
    while IFS= read -r g; do
      idx="$(grep -nxF "$g" "$FULL_GATES" | cut -d: -f1)"
      [ -n "$idx" ] || { echo "FAIL [1]: $g listado em $K/$N não existe na lista completa"; exit 1; }
      [ $(( (idx - 1) % N )) -eq $(( K - 1 )) ] || { echo "FAIL [1]: $g (índice $((idx - 1))) caiu no shard $K/$N, esperado $(( (idx - 1) % N + 1 ))/$N"; exit 1; }
      casos=$((casos + 1))
    done < <(printf '%s\n' "$out" | itens | grep -- '-gate\.sh$')
  done
  n_uniao="$(wc -l < "$T/uniao.txt" | tr -d ' ')"
  [ "$n_uniao" -eq "$n_full" ] || { echo "FAIL [1]: N=$N — a união dos shards tem $n_uniao itens, a lista completa $n_full (repetição ou perda)"; exit 1; }
  dup="$(sort "$T/uniao.txt" | uniq -d)"
  [ -z "$dup" ] || { echo "FAIL [1]: N=$N — itens em mais de um shard: $dup"; exit 1; }
  diff <(sort "$T/uniao.txt") <(sort "$FULL") >/dev/null || { echo "FAIL [1]: N=$N — a união dos shards difere da lista completa"; diff <(sort "$T/uniao.txt") <(sort "$FULL"); exit 1; }
done
[ "$casos" -eq $((n_gates * 5)) ] || { echo "FAIL [1]: contador de controle — $casos verificações de índice, esperado $((n_gates * 5))"; exit 1; }
echo "OK [1] ($casos verificações de índice sobre $n_gates gates)"

echo "[2] bats fixos no shard 1"
n_bats="$(grep -c '\.bats$' "$FULL")"
[ "$n_bats" -ge 1 ] || { echo "FAIL [2]: a lista completa não tem suíte bats — o cenário não mediria nada"; exit 1; }
for N in 2 3 4; do
  b1="$(bash "$RUNNER" --list --shard "1/$N" | itens | grep -c '\.bats$')"
  [ "$b1" -eq "$n_bats" ] || { echo "FAIL [2]: --shard 1/$N tem $b1 suíte(s) bats, esperado $n_bats"; exit 1; }
  for K in $(seq 2 "$N"); do
    bk="$(bash "$RUNNER" --list --shard "$K/$N" | itens | grep -c '\.bats$')"
    [ "$bk" -eq 0 ] || { echo "FAIL [2]: --shard $K/$N tem $bk suíte(s) bats — deveriam estar só no shard 1"; exit 1; }
  done
done
echo "OK [2]"

echo "[3] K/N inválido sai rc 2"
invalidos=0
for arg in "0/3" "4/3" "1/0" "a/b" "3" "1/3/2" "-1/3" "01/3" "1/03" ""; do
  bash "$RUNNER" --list --shard "$arg" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 2 ] || { echo "FAIL [3]: --shard '$arg' saiu rc=$rc, esperado 2"; exit 1; }
  invalidos=$((invalidos + 1))
done
bash "$RUNNER" --list --shard >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL [3]: --shard sem valor saiu rc=$rc, esperado 2"; exit 1; }
bash "$RUNNER" --list --shard 1/3 --shard 2/3 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL [3]: --shard repetido saiu rc=$rc, esperado 2"; exit 1; }
# controle: os válidos saem rc 0 (sem isso, um runner que recusa TUDO passaria acima)
bash "$RUNNER" --list --shard 3/3 >/dev/null 2>&1 || { echo "FAIL [3] (controle): --shard 3/3 válido foi recusado"; exit 1; }
bash "$RUNNER" --list --shard 1/1 >/dev/null 2>&1 || { echo "FAIL [3] (controle): --shard 1/1 válido foi recusado"; exit 1; }
echo "OK [3] ($invalidos formas inválidas + vazio + repetido)"

echo "[4] bancada isolada: o que --shard K/3 executa é o que --list --shard K/3 lista"
B="$T/bancada"
mkdir -p "$B/tests/snapshot" "$B/bin" "$B/template/.forge/scripts/lib"
cp "$RUNNER" "$B/tests/run-all.sh"
printf '%s\n' '#!/usr/bin/env bash' 'arvore_retrato() { echo dublê; }' 'arvore_snapshot() { echo dublê; }' 'arvore_confere() { return 0; }' \
  > "$B/template/.forge/scripts/lib/arvore-rastreada.sh"
MARCA="$T/executados.txt"
cat > "$B/bin/bats" <<SHIM
#!/usr/bin/env bash
echo "\$(basename "\${!#}")" >> "$MARCA"
echo "1..1"; echo "ok 1 dublê"; exit 0
SHIM
chmod +x "$B/bin/bats"
: > "$B/tests/validators.bats"
: > "$B/tests/snapshot/claude-contract.bats"
for i in 01 02 03 04 05 06 07; do
  printf '#!/usr/bin/env bash\necho "$(basename "$0")" >> "%s"\nexit 0\n' "$MARCA" > "$B/tests/w9$i-dubl-gate.sh"
done
for K in 1 2 3; do
  : > "$MARCA"
  lista="$(cd "$B" && PATH="$B/bin:$PATH" bash "$B/tests/run-all.sh" --list --shard "$K/3" | itens | xargs -n1 basename | LC_ALL=C sort)"
  ( cd "$B" && PATH="$B/bin:$PATH" bash "$B/tests/run-all.sh" --shard "$K/3" ) > "$T/run-$K.log" 2>&1; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL [4]: execução --shard $K/3 na bancada saiu rc=$rc"; cat "$T/run-$K.log"; exit 1; }
  exec_="$(LC_ALL=C sort "$MARCA")"
  [ -n "$exec_" ] || { echo "FAIL [4]: --shard $K/3 não executou nada"; exit 1; }
  [ "$lista" = "$exec_" ] || { echo "FAIL [4]: --shard $K/3 executou algo diferente do que lista"; echo "lista: $lista"; echo "executados: $exec_"; exit 1; }
done
echo "OK [4]"

echo "[5] ci.yml: matrix de shards + job final 'gates' com needs e if: always()"
[ -f "$CI" ] || { echo "FAIL [5]: $CI ausente"; exit 1; }
node --input-type=module - "$CI" <<'NODE_EOF' || exit 1
import { readFileSync } from 'node:fs';
const src = readFileSync(process.argv[2], 'utf8').split('\n');
// Parse por indentação, sem dependência: blocos de job = linhas `  <id>:` sob `jobs:`.
const jobs = {}; let inJobs = false; let cur = null;
for (const l of src) {
  if (/^jobs:\s*$/.test(l)) { inJobs = true; continue; }
  if (inJobs && /^\S/.test(l)) { inJobs = false; cur = null; continue; }
  if (!inJobs) continue;
  const m = l.match(/^  ([A-Za-z_][\w-]*):\s*$/);
  if (m) { cur = m[1]; jobs[cur] = []; continue; }
  if (cur) jobs[cur].push(l);
}
const fail = (msg) => { console.log(`FAIL [5]: ${msg}`); process.exit(1); };
const ids = Object.keys(jobs);
if (!ids.length) fail('nenhum job encontrado sob jobs: — o parse não mede o que pensa');
const body = (id) => jobs[id].filter((l) => !/^\s*#/.test(l)).join('\n');
const matrixJobs = ids.filter((id) => /^\s+matrix:\s*$/m.test(body(id)) && /run-all\.sh --shard/.test(body(id)));
if (matrixJobs.length !== 1) fail(`esperado exatamente 1 job com matrix que roda run-all.sh --shard, achei ${matrixJobs.length} (${matrixJobs.join(', ')})`);
const mj = matrixJobs[0];
const shardList = body(mj).match(/^\s+shard:\s*\[([^\]]*)\]\s*$/m);
if (!shardList) fail(`o job ${mj} não declara 'shard: [..]' na matrix`);
const shards = shardList[1].split(',').map((s) => Number(s.trim()));
const N = shards.length;
if (N < 2 || shards.some((v, i) => v !== i + 1)) fail(`matrix.shard deve ser 1..N contíguo, achei [${shards.join(', ')}]`);
const inv = body(mj).match(/run-all\.sh --shard \$\{\{ *matrix\.shard *\}\}\/(\d+)/);
if (!inv) fail(`o job ${mj} não invoca 'run-all.sh --shard \${{ matrix.shard }}/N'`);
if (Number(inv[1]) !== N) fail(`o N da invocação (${inv[1]}) difere do tamanho da matrix (${N}) — shards ficariam sem rodar ou repetidos`);
if (!/^\s+fail-fast:\s*false\s*$/m.test(body(mj))) fail(`o job ${mj} não declara 'fail-fast: false' — um shard vermelho cancelaria os outros e esconderia reprovações`);
if (!jobs.gates) fail("não existe job chamado exatamente 'gates' — o nome do check obrigatório da branch protection se perderia");
if (/run-all\.sh/.test(body('gates'))) fail("o job 'gates' final ainda roda a suíte — ele deve só agregar os shards");
const needsM = body('gates').match(/^\s+needs:\s*\[([^\]]*)\]\s*$/m);
if (!needsM) fail("o job 'gates' não declara 'needs: [...]'");
const needs = needsM[1].split(',').map((s) => s.trim()).filter(Boolean);
if (!needs.includes(mj)) fail(`o job 'gates' não depende da matrix (${mj}); needs = [${needs.join(', ')}]`);
if (!/^\s+if:\s*\$\{\{\s*always\(\)\s*\}\}\s*$/m.test(body('gates')) && !/^\s+if:\s*always\(\)\s*$/m.test(body('gates'))) fail("o job 'gates' não tem 'if: always()' — com um shard vermelho ele seria PULADO, e job pulado conta como aprovado na branch protection");
for (const n of needs) {
  if (!jobs[n]) fail(`needs cita job inexistente: ${n}`);
  if (!new RegExp(`needs\\.${n}\\.result`).test(body('gates'))) fail(`o job 'gates' não confere needs.${n}.result`);
}
if (!/!= *["']?success/.test(body('gates')) && !/== *["']?success/.test(body('gates'))) fail("o job 'gates' não compara o resultado dos needs com 'success'");
// [6] passos de segurança: presentes, num job que alimenta 'gates', sem continue-on-error
const seg = ['check-secrets.sh', 'check-shell-pipeline.sh', 'check-suite-wiring.sh', 'red-evidence.sh ci'];
for (const s of seg) {
  const donos = ids.filter((id) => body(id).includes(s));
  if (!donos.length) { console.log(`FAIL [6]: passo de segurança '${s}' sumiu do ci.yml`); process.exit(1); }
  if (!donos.some((d) => needs.includes(d))) { console.log(`FAIL [6]: '${s}' roda em job (${donos.join(', ')}) que não alimenta o 'gates' final`); process.exit(1); }
  for (const d of donos) if (/continue-on-error:\s*true/.test(body(d))) { console.log(`FAIL [6]: o job ${d} (que roda '${s}') tem continue-on-error: true`); process.exit(1); }
}
console.log(`OK [5] (matrix ${mj} com ${N} shards; gates needs = [${needs.join(', ')}])`);
console.log('OK [6]');
NODE_EOF

echo "PASS w273-ci-shard-gate"
