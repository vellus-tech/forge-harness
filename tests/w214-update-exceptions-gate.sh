#!/usr/bin/env bash
# Gate W214 — o `forge update` lê `.forge/machinery-exceptions.txt` antes de sobrescrever
# maquinaria própria (issues #101 e #131, um PR só — mesma causa raiz em bin/forge.mjs:618-733).
#
# POR QUE ESTE GATE EXISTE. `scripts/`, `hooks/` e `commands/` estão fora de ENRICHABLE_DIRS —
# são maquinaria que precisa poder ser corrigida pelo template — e por isso o overlay do update
# os sobrescreve incondicionalmente. Até aqui nenhuma linha do updater lia
# `.forge/machinery-exceptions.txt` (grep vazio em bin/): a divergência DELIBERADA que um
# consumidor declara ali — a mesma gramática que o `check-machinery-drift.sh` do
# axis-fare-validator já opera em produção — era invisível para o `update`, que revertia o
# conserto local com `rc=0` e, sem `machinery.lock` prévio (primeiro update depois do fix), sem
# aviso nenhum.
#
#   [1] exceção VIVA (sha declarado == sha do template novo): preserva o arquivo local e nomeia
#       com `PRESERVADO (exceção declarada)` — mesmo sem machinery.lock (primeiro update)
#   [2] NÃO declarada: sobrescreve e nomeia com `SOBRESCRITO (não declarado)`, apontando para o
#       backup real onde o conteúdo anterior sobrevive
#   [3] EXPIRADA (sha declarado != sha do template novo): preserva mesmo assim (DH-1) e nomeia
#       com `EXCEÇÃO EXPIRADA`, os dois shas, rc 0 — não bloqueia a fronteira publicada do update
#   [4] malformada (sha inválido) e duplicada (mesmo caminho duas vezes): param o update ANTES de
#       escrever qualquer arquivo, a recusa nomeia o número da linha, rc != 0
#   [5] ausência de `.forge/machinery-exceptions.txt`: comportamento igual ao de antes desta
#       entrega, mais as linhas `SOBRESCRITO` novas — nada além disso aparece
#   [6] fixture real: cópia literal do `.forge/machinery-exceptions.txt` do axis-fare-validator
#       (34 linhas vivas, só leitura em disco, sanitizada por grep prévio — sem PII/segredo) —
#       o parser aceita com rc 0 e nomeia as 34 linhas
#   [7] PBT: para arquivos de exceção gerados sobre caminhos REAIS do template, o update para
#       sse existe linha malformada/duplicada; quando não para, cada arquivo fica byte-idêntico
#       sse tem exceção viva ou expirada, e todo caminho declarado aparece exatamente uma vez
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$WS/bin/forge.mjs"
TPL="$WS/template/.forge"
T="$(mktemp -d /tmp/forge-w214.XXXXXX)"
trap 'rm -rf "$T"' EXIT

consumidor() {  # consumidor <nome> -> ecoa <dir>, com .forge instalado a partir do template real
  local d="$T/$1"
  mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  node "$FORGE" init --target "$d" --slug demo --name Demo --desc t --yes --no-plugin >"$d/init.log" 2>&1 \
    || { echo "FAIL (setup): init falhou para $1"; cat "$d/init.log"; exit 1; }
  printf '%s\n' "$d"
}

sha_tpl() { shasum -a 256 "$TPL/$1" | cut -d' ' -f1; }  # sha_tpl <rel-a-.forge>

echo "[1] exceção viva preserva e nomeia, mesmo sem machinery.lock prévio"
C1="$(consumidor c1)"
printf '\n# CONSERTO-LOCAL (issue #101, medido em axis-go-cloud)\n' >> "$C1/.forge/scripts/lib/transports/_common.sh"
SHA_CONSERTO="$(shasum -a 256 "$C1/.forge/scripts/lib/transports/_common.sh" | cut -d' ' -f1)"
printf '%s  scripts/lib/transports/_common.sh  # une o hub sem destruir escrita concorrente\n' "$(sha_tpl scripts/lib/transports/_common.sh)" \
  > "$C1/.forge/machinery-exceptions.txt"
[ ! -f "$C1/.forge/cache/machinery.lock" ] || { echo "FAIL [1] (setup): consumidor já tem machinery.lock — o cenário exige ausência dele)"; exit 1; }
out1="$(node "$FORGE" update --target "$C1" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc1=$?
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: update com exceção viva saiu rc=$rc1"; echo "$out1"; exit 1; }
[ "$(shasum -a 256 "$C1/.forge/scripts/lib/transports/_common.sh" | cut -d' ' -f1)" = "$SHA_CONSERTO" ] \
  || { echo "FAIL [1]: conserto local foi sobrescrito — exceção viva não preservou"; exit 1; }
grep -q 'PRESERVADO (exceção declarada): scripts/lib/transports/_common.sh' <<<"$out1" \
  || { echo "FAIL [1]: linha PRESERVADO (exceção declarada) ausente"; echo "$out1"; exit 1; }
echo "OK [1]"

echo "[2] NÃO declarada: sobrescreve e nomeia com o backup real"
C2="$(consumidor c2)"
printf '\n# fix-local-sem-declarar\n' >> "$C2/.forge/scripts/handoff-gen.sh"
out2="$(node "$FORGE" update --target "$C2" --no-plugin --source "$TPL" 2>&1)"; rc2=$?
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: update saiu rc=$rc2"; echo "$out2"; exit 1; }
grep -q 'fix-local-sem-declarar' "$C2/.forge/scripts/handoff-gen.sh" \
  && { echo "FAIL [2]: fix local sobreviveu — deveria ter sido sobrescrito (sem exceção declarada)"; exit 1; }
linha2="$(grep 'SOBRESCRITO (não declarado): scripts/handoff-gen.sh' <<<"$out2")"
[ -n "$linha2" ] || { echo "FAIL [2]: linha SOBRESCRITO (não declarado) ausente"; echo "$out2"; exit 1; }
bak_rel="$(sed -E 's/.*conteúdo anterior em //' <<<"$linha2")"
[ -f "$C2/$bak_rel" ] || { echo "FAIL [2]: backup nomeado não existe em disco ($bak_rel)"; exit 1; }
grep -q 'fix-local-sem-declarar' "$C2/$bak_rel" \
  || { echo "FAIL [2]: backup nomeado não contém o conteúdo anterior"; exit 1; }
echo "OK [2]"

echo "[3] EXPIRADA: preserva mesmo assim, nomeia os dois shas, rc 0"
C3="$(consumidor c3)"
printf '\n# CONSERTO-EXPIRADO\n' >> "$C3/.forge/scripts/doctor.sh"
SHA_LOCAL3="$(shasum -a 256 "$C3/.forge/scripts/doctor.sh" | cut -d' ' -f1)"
SHA_ERRADO="0000000000000000000000000000000000000000000000000000000000000a"
SHA_ERRADO="${SHA_ERRADO: -64}"
printf '%s  scripts/doctor.sh  # exceção contra versão anterior do template\n' "$SHA_ERRADO" > "$C3/.forge/machinery-exceptions.txt"
SHA_TPL_DOCTOR="$(sha_tpl scripts/doctor.sh)"
out3="$(node "$FORGE" update --target "$C3" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc3=$?
[ "$rc3" -eq 0 ] || { echo "FAIL [3]: exceção expirada não pode bloquear o update (DH-1) — saiu rc=$rc3"; echo "$out3"; exit 1; }
[ "$(shasum -a 256 "$C3/.forge/scripts/doctor.sh" | cut -d' ' -f1)" = "$SHA_LOCAL3" ] \
  || { echo "FAIL [3]: arquivo com exceção expirada foi sobrescrito — deveria ser preservado (DH-1)"; exit 1; }
grep -q "EXCEÇÃO EXPIRADA: scripts/doctor.sh — sha declarado $SHA_ERRADO, sha do template novo $SHA_TPL_DOCTOR" <<<"$out3" \
  || { echo "FAIL [3]: linha EXCEÇÃO EXPIRADA ausente ou sem os dois shas"; echo "$out3"; exit 1; }
echo "OK [3]"

echo "[4a] malformada: para ANTES de escrever, nomeia a linha"
C4A="$(consumidor c4a)"
printf 'shaInvalida  scripts/doctor.sh  # sha nao e hex\n' > "$C4A/.forge/machinery-exceptions.txt"
SHA_DOCTOR_ANTES="$(shasum -a 256 "$C4A/.forge/forge.yaml" | cut -d' ' -f1)"
set +e
out4a="$(node "$FORGE" update --target "$C4A" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc4a=$?
set -e
[ "$rc4a" -ne 0 ] || { echo "FAIL [4a]: exceção malformada não bloqueou o update"; echo "$out4a"; exit 1; }
grep -q 'linha 1' <<<"$out4a" || { echo "FAIL [4a]: recusa não nomeia o número da linha"; echo "$out4a"; exit 1; }
[ "$(shasum -a 256 "$C4A/.forge/forge.yaml" | cut -d' ' -f1)" = "$SHA_DOCTOR_ANTES" ] \
  || { echo "FAIL [4a]: forge.yaml foi escrito mesmo com exceção malformada — nada deveria ter sido tocado"; exit 1; }
[ ! -f "$C4A/.forge/cache/machinery.lock" ] \
  || { echo "FAIL [4a]: machinery.lock foi escrito mesmo com exceção malformada"; exit 1; }
echo "OK [4a]"

echo "[4b] duplicada: para ANTES de escrever, nomeia as duas linhas"
C4B="$(consumidor c4b)"
SHA_DOCTOR="$(sha_tpl scripts/doctor.sh)"
{
  printf '%s  scripts/doctor.sh  # primeira declaração\n' "$SHA_DOCTOR"
  printf '%s  scripts/doctor.sh  # segunda declaração do mesmo caminho\n' "$SHA_DOCTOR"
} > "$C4B/.forge/machinery-exceptions.txt"
set +e
out4b="$(node "$FORGE" update --target "$C4B" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc4b=$?
set -e
[ "$rc4b" -ne 0 ] || { echo "FAIL [4b]: exceção duplicada não bloqueou o update"; echo "$out4b"; exit 1; }
grep -q 'linhas 1 e 2' <<<"$out4b" || { echo "FAIL [4b]: recusa não nomeia as duas linhas duplicadas"; echo "$out4b"; exit 1; }
[ ! -f "$C4B/.forge/cache/machinery.lock" ] \
  || { echo "FAIL [4b]: machinery.lock foi escrito mesmo com exceção duplicada"; exit 1; }
echo "OK [4b]"

echo "[5] ausência de machinery-exceptions.txt: só as linhas SOBRESCRITO são novas"
C5="$(consumidor c5)"
[ ! -f "$C5/.forge/machinery-exceptions.txt" ] || rm -f "$C5/.forge/machinery-exceptions.txt"
printf '\n# fix-sem-arquivo-de-excecoes\n' >> "$C5/.forge/scripts/handoff-gen.sh"
out5="$(node "$FORGE" update --target "$C5" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc5=$?
[ "$rc5" -eq 0 ] || { echo "FAIL [5]: update sem arquivo de exceções saiu rc=$rc5"; echo "$out5"; exit 1; }
grep -q 'fix-sem-arquivo-de-excecoes' "$C5/.forge/scripts/handoff-gen.sh" \
  && { echo "FAIL [5]: fix local sobreviveu sem exceção declarada"; exit 1; }
grep -q 'SOBRESCRITO (não declarado): scripts/handoff-gen.sh' <<<"$out5" \
  || { echo "FAIL [5]: SOBRESCRITO ausente mesmo sem arquivo de exceções"; echo "$out5"; exit 1; }
grep -qi 'exceç' <<<"$out5" && { echo "FAIL [5]: sem arquivo de exceções, o relatório não deveria mencionar exceção nenhuma"; echo "$out5"; exit 1; }
echo "OK [5]"

echo "[6] fixture real (axis-fare-validator, 34 exceções): rc 0, as 34 linhas nomeadas"
FIXTURE="$WS/tests/fixtures/w214/machinery-exceptions-axis-fare-validator.txt"
[ -f "$FIXTURE" ] || { echo "FAIL [6] (setup): fixture ausente em $FIXTURE"; exit 1; }
N_DECLARADAS="$(grep -cE '^[0-9a-f]{32,}[[:space:]]' "$FIXTURE")"
[ "$N_DECLARADAS" -eq 34 ] || { echo "FAIL [6] (setup): fixture não tem 34 linhas vivas de dados (achei $N_DECLARADAS)"; exit 1; }
C6="$(consumidor c6)"
cp "$FIXTURE" "$C6/.forge/machinery-exceptions.txt"
out6="$(node "$FORGE" update --target "$C6" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc6=$?
[ "$rc6" -eq 0 ] || { echo "FAIL [6]: fixture real de 34 exceções não deveria bloquear o update"; echo "$out6"; exit 1; }
n_nomeadas=0
while IFS= read -r rel; do
  grep -qF "$rel" <<<"$out6" || { echo "FAIL [6]: caminho '$rel' da fixture não foi nomeado no relatório"; exit 1; }
  n_nomeadas=$((n_nomeadas + 1))
done < <(grep -E '^[0-9a-f]{32,}[[:space:]]' "$FIXTURE" | awk '{print $2}')
[ "$n_nomeadas" -eq 34 ] || { echo "FAIL [6]: nomeadas $n_nomeadas de 34"; exit 1; }
echo "OK [6] (34/34 nomeadas, rc 0)"

echo "[7] PBT: para exceções geradas sobre caminhos reais do template, o desfecho é função pura do conjunto declarado"
node --input-type=module - "$WS" <<'NODE_EOF'
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { mkdtempSync, rmSync, cpSync, writeFileSync, readFileSync, existsSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const WS = process.argv[2];
const P = await import(pathToFileURL(join(WS, 'template/.forge/scripts/lib/pbt.mjs')).href);
const FORGE = join(WS, 'bin/forge.mjs');
const TPL = join(WS, 'template/.forge');
const sha256 = (p) => createHash('sha256').update(readFileSync(p)).digest('hex');

// Universo FIXO de caminhos reais e não-enriquecíveis do template — pequeno de propósito, para
// que 50+ execuções de `update` real (subprocesso; bin/forge.mjs roda main() incondicionalmente
// na importação, então testar em processo exigiria duplicar o parser — o que a #158 desta
// rodada proíbe) caibam no orçamento do gate.
const REAL_PATHS = [
  'scripts/handoff-gen.sh',
  'scripts/doctor.sh',
  'hooks/git/pre-push',
  'hooks/git/post-merge',
];

// Consumidor PRISTINE, preparado uma vez por `init` real; cada caso do PBT parte de uma cópia dele.
const pristine = mkdtempSync(join(tmpdir(), 'forge-w214-pbt-pristine-'));
execFileSync('git', ['init', '-q', pristine]);
execFileSync('git', ['-C', pristine, 'config', 'user.email', 't@t']);
execFileSync('git', ['-C', pristine, 'config', 'user.name', 't']);
execFileSync('node', [FORGE, 'init', '--target', pristine, '--slug', 'demo', '--name', 'Demo', '--desc', 't', '--yes', '--no-plugin']);

const templateHash = {};
for (const rel of REAL_PATHS) templateHash[rel] = sha256(join(TPL, rel));

// Gerador: um estado por caminho real ('viva'|'expirada'|'identica'|'none') + flags de
// perturbação (fantasma fora do template, duplicata, malformada) — cobre as 5 categorias que a
// propriedade enumera (vivas, expiradas, ociosas, malformadas e duplicadas).
const gState = P.gen.array(P.gen.oneOf(['viva', 'expirada', 'identica', 'none']), REAL_PATHS.length, REAL_PATHS.length);
const gFlags = P.gen.record({ ghost: P.gen.bool(), duplicate: P.gen.bool(), malformed: P.gen.bool() });

let casesRun = 0;
const prop = (states, flags) => {
  casesRun++;
  const dir = mkdtempSync(join(tmpdir(), 'forge-w214-pbt-case-'));
  rmSync(dir, { recursive: true, force: true });
  cpSync(pristine, dir, { recursive: true });

  const lines = [];
  const declared = []; // { rel, expectPreserved, isGhost, isDuplicate, isMalformed }
  states.forEach((state, i) => {
    const rel = REAL_PATHS[i];
    const dst = join(dir, '.forge', rel);
    if (state === 'none') return;
    if (state === 'identica') {
      // dst já é igual ao template (init acabou de copiar) — não mexe no arquivo.
      lines.push(`${templateHash[rel]}  ${rel}  # ociosa: identica ao template`);
      declared.push({ rel, category: 'identica' });
      return;
    }
    // viva/expirada precisam de divergência local real para a classificação fazer sentido.
    writeFileSync(dst, readFileSync(dst, 'utf8') + `\n# mutação pbt ${state} ${rel}\n`);
    if (state === 'viva') {
      lines.push(`${templateHash[rel]}  ${rel}  # viva`);
      declared.push({ rel, category: 'viva' });
    } else {
      const wrong = (templateHash[rel].slice(0, 63) === '0' ? '1' : '0') + templateHash[rel].slice(1);
      lines.push(`${wrong}  ${rel}  # expirada`);
      declared.push({ rel, category: 'expirada', wrongSha: wrong });
    }
  });
  if (flags.ghost) lines.push(`${'a'.repeat(64)}  scripts/caminho-fantasma-fixo-w214.sh  # fora do template`);
  if (flags.duplicate && declared.length) {
    const d = declared[0];
    lines.push(`${templateHash[d.rel] || 'a'.repeat(64)}  ${d.rel}  # segunda declaração do mesmo caminho`);
  }
  if (flags.malformed) lines.push('nao-e-hex-valido  scripts/doctor.sh  # malformada de propósito');

  mkdirSync(join(dir, '.forge'), { recursive: true });
  writeFileSync(join(dir, '.forge', 'machinery-exceptions.txt'), lines.join('\n') + '\n');

  const shouldAbort = flags.malformed || flags.duplicate;
  let out = '', rc = 0;
  try {
    out = execFileSync('node', [FORGE, 'update', '--target', dir, '--no-plugin', '--no-backup', '--source', TPL], { encoding: 'utf8' });
  } catch (e) {
    rc = e.status ?? 1;
    out = (e.stdout || '') + (e.stderr || '');
  }

  let ok = true;
  if (shouldAbort) {
    ok = rc !== 0;
  } else {
    ok = rc === 0;
    if (ok) {
      for (const d of declared) {
        const dst = join(dir, '.forge', d.rel);
        const nowHash = sha256(dst);
        const shouldBeUnchanged = d.category === 'viva' || d.category === 'expirada';
        const wasUnchanged = nowHash !== templateHash[d.rel]; // preservado != conteúdo do template novo
        if (d.category === 'identica') {
          if (nowHash !== templateHash[d.rel]) ok = false;
        } else if (shouldBeUnchanged !== wasUnchanged) {
          ok = false;
        }
        // todo caminho declarado aparece exatamente uma vez no relatório (exceto ghost/duplicate/malformed sintéticos)
        const occurrences = out.split(d.rel).length - 1;
        if (occurrences < 1) ok = false;
      }
    }
  }
  rmSync(dir, { recursive: true, force: true });
  return ok;
};

const r = P.forAll([gState, gFlags], prop, { runs: 50, seed: 214101131 });
rmSync(pristine, { recursive: true, force: true });
if (!r.ok) {
  console.error(`FAIL [7]: propriedade falhou após ${r.runs} caso(s) (seed ${r.seed})`);
  console.error('  contraexemplo minimizado: ' + JSON.stringify(r.counterexample));
  if (r.error) console.error('  erro: ' + r.error);
  process.exit(1);
}
if (casesRun < 50) { console.error(`FAIL [7]: rodou só ${casesRun} caso(s), esperado >= 50`); process.exit(1); }
console.log(`OK [7] (${r.runs} casos, seed ${r.seed})`);
NODE_EOF
rc7=$?
[ "$rc7" -eq 0 ] || { echo "FAIL [7]: PBT reprovou (ver saída acima)"; exit 1; }

echo "PASS w214-update-exceptions-gate"
