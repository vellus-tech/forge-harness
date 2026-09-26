#!/usr/bin/env bash
# Gate W217 — o `update` nomeia o recurso do heavy-mutex que resolve depois de mesclar um bloco
# ausente, e nunca reescreve `resource`/`root`/`enabled` já declarados (issue #142).
#
# POR QUE ESTE GATE EXISTE. `bin/forge.mjs` mescla ADITIVAMENTE chaves de topo do `forge.yaml`
# ausentes no consumidor (`newForgeKeys`/`mergeNewForgeKeys`) — e `heavy_mutex` é uma delas. Um
# consumidor que NUNCA declarou o bloco (ex.: axis-go-cloud, medido no adendo do plano) recebia o
# bloco inteiro do template, com `resource: forge-heavy-suite`, sem UMA linha sobre identidade de
# lock: o operador só descobre a serialização mudou lendo o diff do `forge.yaml`. Um consumidor
# que JÁ declarava outro caminho (`axis-heavy-suite`, o axis-fare-validator) nunca era tocado —
# `dstKeys.has('heavy_mutex')` já barra o merge inteiro — mas essa garantia nunca tinha gate
# próprio: um refactor que trocasse `continue` por outra coisa passaria despercebido até quebrar
# em campo.
#
# DECISÃO DO DONO (DH-3): o nome default do recurso é MANTIDO (não vira neutro, não reparticiona
# quem já está nele). O update só GANHA TRANSPARÊNCIA: uma linha nominal `heavy_mutex: recurso
# resolvido <antes> → <depois> (lock <caminho>)`, com prefixo `WARN: ` quando os dois nomes
# divergem. A resolução é feita pela PRÓPRIA lib (`heavy-mutex.sh`, função `forge_heavy_mutex_path`
# sourceada por subprocesso bash) — nunca uma reimplementação paralela em JS da precedência
# env > forge.yaml > default, que é exatamente o tipo de gêmeo-mentiroso que causou a partição
# original (duas cópias da mesma regra, uma delas defasada).
#
#   [1] positiva: bloco ausente, sem env, template real (default do template == default hardcoded
#       da lib) — linha nominal aparece, SEM `WARN:`, e nomeia o lock sob o root isolado do caso.
#   [2] WARN: bloco ausente, template com `resource:` diferente do default hardcoded da lib —
#       linha nominal com `WARN:`, nomeando os dois nomes (antes = default da lib; depois = valor
#       que o template escreveu).
#   [3] env vence dos dois lados: bloco ausente, `FORGE_HEAVY_MUTEX_RESOURCE` declarado, MESMO
#       template do cenário [2] (que sozinho geraria WARN) — sem `WARN:`, porque a env tem
#       precedência sobre o forge.yaml nos dois momentos (antes E depois do merge).
#   [4] bloco JÁ declarado (`resource`/`root`/`enabled` customizados) nunca é tocado: byte-idêntico
#       depois do update, e NENHUMA linha `heavy_mutex: recurso resolvido` aparece — o merge
#       inteiro é barrado pela chave já presente, então a rota que imprimiria a linha nem executa.
#   [5] doctor.sh: a linha `HEAVY-MUTEX` já existente nomeia o recurso resolvido (`recurso .....
#       <res>`) — regressão estrutural, não nova (a função já existe desde a #52); travada aqui
#       para que um refactor futuro do doctor não a perca em silêncio.
#   [6] mutação A: apagar o bloco que imprime a linha nominal em `bin/forge.mjs` reprova [1] (linha
#       ausente); restaurado byte a byte (`cmp -s`), [1] volta a passar (recontrole).
#   [7] mutação B: fazer `newForgeKeys` deixar de checar `dstKeys.has(key)` reprova [4] (o bloco já
#       declarado deixa de ficar byte-idêntico); restaurado, [4] volta a passar (recontrole).
#   [8] PBT (seed fixa, >= 50 casos): para bloco ausente/presente × resource do template
#       (default|divergente) × env declarada ou não, a invariante do plano vale sempre: quando o
#       bloco já existe, fica byte-idêntico e nenhuma linha nominal aparece; quando é mesclado, a
#       linha nominal nomeia exatamente o par (antes, depois) previsto pela precedência
#       env > forge.yaml > default, com `WARN:` see os dois nomes divergirem, e o `(lock …)`
#       aponta para `<root>/<depois>.lock`.
#
# ISOLAMENTO (regra transversal desta rodada). Todo caso que resolve o heavy-mutex roda com
# `FORGE_HEAVY_MUTEX_ROOT` apontado para um diretório temporário PRÓPRIO — nunca o lock real da
# máquina. `forge_heavy_mutex_path` só RESOLVE (nunca adquire: não cria diretório de lock), mesma
# garantia estrutural do gate w154 sobre `_fhm_resolve_root` — mas a raiz ainda é isolada, porque
# outras frentes rodam gates em paralelo na mesma máquina e um `root:` declarado inexistente faz a
# lib criar o diretório (`mkdir`), efeito que este gate não quer produzir fora do seu próprio `T`.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$WS/bin/forge.mjs"
TPL="$WS/template/.forge"
FORGE_MJS_SRC="$WS/bin/forge.mjs"
T="$(mktemp -d /tmp/forge-w217.XXXXXX)"
trap 'rm -rf "$T"' EXIT INT TERM
GATE_START="$(date +%s)"; GATE_BUDGET_S="${W217_BUDGET_S:-420}"
SCENARIOS_RUN=0
scenario() { SCENARIOS_RUN=$((SCENARIOS_RUN + 1)); echo "$1"; }

ROOT_ISO="$T/lock-root"; mkdir -p "$ROOT_ISO"   # raiz isolada — NUNCA o /tmp real da máquina

consumidor() {  # consumidor <nome> -> ecoa <dir>, .forge instalado a partir do template real
  local d="$T/$1"
  mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  node "$FORGE" init --target "$d" --slug demo --name Demo --desc t --yes --no-plugin >"$d/init.log" 2>&1 \
    || { echo "FAIL (setup): init falhou para $1"; cat "$d/init.log"; exit 1; }
  printf '%s\n' "$d"
}

strip_heavy_mutex() {  # strip_heavy_mutex <forge.yaml> — remove o bloco inteiro (ausência real)
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    let t = fs.readFileSync(p, "utf8");
    t = t.replace(/^heavy_mutex:\n(?:[ \t].*\n?)*\n?/m, "");
    fs.writeFileSync(p, t);
  ' "$1"
}

set_heavy_mutex() {  # set_heavy_mutex <forge.yaml> <resource> <root|__SEM__> <enabled>
  node -e '
    const fs = require("fs");
    const [, p, res, root, enabled] = process.argv;
    let t = fs.readFileSync(p, "utf8");
    const rootLine = root === "__SEM__" ? "" : ("  root: " + root + "\n");
    const bloco = "heavy_mutex:\n  enabled: " + enabled + "\n  resource: " + res + "\n" + rootLine + "  timeout_s: 1800\n";
    if (/^heavy_mutex:\n(?:[ \t].*\n?)*\n?/m.test(t)) t = t.replace(/^heavy_mutex:\n(?:[ \t].*\n?)*\n?/m, bloco);
    else t = t.replace(/\n$/, "") + "\n" + bloco;
    fs.writeFileSync(p, t);
  ' "$1" "$2" "$3" "$4"
}

bloco_de() { awk '/^heavy_mutex:/{f=1} f{print} f&&/^[a-z]/&&!/^heavy_mutex:/{exit}' "$1"; }  # bloco_de <forge.yaml>
n_blocos() { grep -c '^heavy_mutex:' "$1"; }  # n_blocos <forge.yaml> — 1 se a chave é única (nunca duplicada pelo merge)

tpl_com_resource() {  # tpl_com_resource <resource> -> ecoa <dir> — cópia do template com resource trocado
  local out="$T/tpl-$1"
  [ -d "$out" ] && { printf '%s\n' "$out"; return 0; }
  cp -R "$TPL" "$out"
  sed -i.bak "s/resource: forge-heavy-suite/resource: $1/" "$out/forge.yaml"
  rm -f "$out/forge.yaml.bak"
  printf '%s\n' "$out"
}

scenario "[1] bloco ausente, sem env, template real — linha nominal SEM WARN, antes == depois"
C1="$(consumidor c1)"
strip_heavy_mutex "$C1/.forge/forge.yaml"
out1="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c1" node "$FORGE" update --target "$C1" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc1=$?
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: update saiu rc=$rc1"; echo "$out1"; exit 1; }
linha1="$(grep 'heavy_mutex: recurso resolvido' <<<"$out1")"
[ -n "$linha1" ] || { echo "FAIL [1]: linha nominal ausente"; echo "$out1"; exit 1; }
grep -q '^WARN:' <<<"$linha1" && { echo "FAIL [1]: linha nominal com WARN inesperado ('$linha1') — antes e depois deveriam ser o mesmo default"; exit 1; }
grep -qF 'forge-heavy-suite → forge-heavy-suite' <<<"$linha1" \
  || { echo "FAIL [1]: linha nominal não nomeia forge-heavy-suite dos dois lados ('$linha1')"; exit 1; }
grep -qF "(lock $ROOT_ISO/c1/forge-heavy-suite.lock)" <<<"$linha1" \
  || { echo "FAIL [1]: linha nominal não nomeia o lock sob o root isolado ('$linha1')"; exit 1; }
echo "OK [1]"

scenario "[2] bloco ausente, template com resource divergente do default hardcoded da lib — WARN"
C2="$(consumidor c2)"
strip_heavy_mutex "$C2/.forge/forge.yaml"
TPL_DIVERGENTE="$(tpl_com_resource custom-heavy-suite)"
out2="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c2" node "$FORGE" update --target "$C2" --no-plugin --no-backup --source "$TPL_DIVERGENTE" 2>&1)"; rc2=$?
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: update saiu rc=$rc2"; echo "$out2"; exit 1; }
linha2="$(grep 'heavy_mutex: recurso resolvido' <<<"$out2")"
[ -n "$linha2" ] || { echo "FAIL [2]: linha nominal ausente"; echo "$out2"; exit 1; }
grep -q '^WARN: heavy_mutex: recurso resolvido' <<<"$linha2" \
  || { echo "FAIL [2]: linha nominal sem prefixo WARN ('$linha2') — os dois nomes divergem e isso não pode passar em silêncio"; exit 1; }
grep -qF 'forge-heavy-suite → custom-heavy-suite' <<<"$linha2" \
  || { echo "FAIL [2]: linha nominal não nomeia os dois lados corretos ('$linha2')"; exit 1; }
grep -qF "(lock $ROOT_ISO/c2/custom-heavy-suite.lock)" <<<"$linha2" \
  || { echo "FAIL [2]: linha nominal não nomeia o lock do recurso NOVO ('$linha2')"; exit 1; }
echo "OK [2]"

scenario "[3] env vence dos dois lados — mesmo template do [2], mas sem WARN porque a env pina antes e depois"
C3="$(consumidor c3)"
strip_heavy_mutex "$C3/.forge/forge.yaml"
out3="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c3" FORGE_HEAVY_MUTEX_RESOURCE=env-pinned node "$FORGE" update --target "$C3" --no-plugin --no-backup --source "$TPL_DIVERGENTE" 2>&1)"; rc3=$?
[ "$rc3" -eq 0 ] || { echo "FAIL [3]: update saiu rc=$rc3"; echo "$out3"; exit 1; }
linha3="$(grep 'heavy_mutex: recurso resolvido' <<<"$out3")"
[ -n "$linha3" ] || { echo "FAIL [3]: linha nominal ausente"; echo "$out3"; exit 1; }
grep -q '^WARN:' <<<"$linha3" \
  && { echo "FAIL [3]: WARN inesperado ('$linha3') — a env vale antes E depois do merge, os dois nomes têm de ser iguais"; exit 1; }
grep -qF 'env-pinned → env-pinned' <<<"$linha3" \
  || { echo "FAIL [3]: linha nominal não nomeia o valor da env dos dois lados ('$linha3')"; exit 1; }
echo "OK [3]"

scenario "[4] bloco JÁ declarado nunca é tocado — byte-idêntico, nenhuma linha nominal"
C4="$(consumidor c4)"
set_heavy_mutex "$C4/.forge/forge.yaml" "axis-heavy-suite" "__SEM__" "true"
BLOCO_ANTES="$(bloco_de "$C4/.forge/forge.yaml")"
out4="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c4" node "$FORGE" update --target "$C4" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc4=$?
[ "$rc4" -eq 0 ] || { echo "FAIL [4]: update saiu rc=$rc4"; echo "$out4"; exit 1; }
BLOCO_DEPOIS="$(bloco_de "$C4/.forge/forge.yaml")"
[ "$BLOCO_ANTES" = "$BLOCO_DEPOIS" ] \
  || { echo "FAIL [4]: bloco heavy_mutex mudou — declarado (resource/root/enabled) foi reescrito.
ANTES:
$BLOCO_ANTES
DEPOIS:
$BLOCO_DEPOIS"; exit 1; }
# byte-idêntico do PRIMEIRO trecho não basta: um merge que ESQUEÇA de barrar a chave já
# declarada não reescreve o trecho original, só ACRESCENTA um segundo `heavy_mutex:` no fim do
# arquivo — `bloco_de` (que para no primeiro fechamento de bloco) nunca veria essa duplicata.
[ "$(n_blocos "$C4/.forge/forge.yaml")" -eq 1 ] \
  || { echo "FAIL [4]: forge.yaml ficou com $(n_blocos "$C4/.forge/forge.yaml") chave(s) 'heavy_mutex:' — o merge deveria ter sido barrado por inteiro pela chave já declarada, nunca acrescentar uma segunda"; exit 1; }
grep -q 'heavy_mutex: recurso resolvido' <<<"$out4" \
  && { echo "FAIL [4]: linha nominal apareceu para um bloco que já existia — o merge não deveria nem ter rodado para esta chave"; echo "$out4"; exit 1; }
echo "OK [4]"

scenario "[5] doctor.sh nomeia o recurso resolvido na linha HEAVY-MUTEX (regressão)"
C5="$(consumidor c5)"
out5="$(FORGE_ROOT="$C5" env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c5" bash "$C5/.forge/scripts/doctor.sh" 2>&1)"
grep -q 'HEAVY-MUTEX:.*recurso ..... forge-heavy-suite' <<<"$out5" \
  || { echo "FAIL [5]: doctor.sh não nomeia o recurso resolvido na linha HEAVY-MUTEX"; echo "$out5" | grep -i heavy; exit 1; }
echo "OK [5]"

scenario "[6] mutação A: sem a impressão da linha nominal, [1] reprova; restaurado, recontrole passa"
cp "$FORGE_MJS_SRC" "$T/forge.mjs.orig"
perl -pi -e "s/if \(added\.includes\('heavy_mutex'\)\) \{/if (false \&\& added.includes('heavy_mutex')) {/" "$FORGE_MJS_SRC"
C6="$(consumidor c6)"
strip_heavy_mutex "$C6/.forge/forge.yaml"
out6="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c6" node "$FORGE" update --target "$C6" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc6=$?
mut6_ok=1
if [ "$rc6" -ne 0 ]; then mut6_ok=0
elif grep -q 'heavy_mutex: recurso resolvido' <<<"$out6"; then mut6_ok=0; fi
cmp -s "$T/forge.mjs.orig" "$FORGE_MJS_SRC" && { echo "FAIL [6] (setup): a mutação não alterou o arquivo — o teste não provaria nada"; exit 1; }
cp "$T/forge.mjs.orig" "$FORGE_MJS_SRC"
cmp -s "$T/forge.mjs.orig" "$FORGE_MJS_SRC" || { echo "FAIL [6]: restauração byte a byte falhou (cmp -s)"; exit 1; }
[ "$mut6_ok" -eq 1 ] || { echo "FAIL [6]: mutação deveria fazer a linha nominal desaparecer em [1], e não desapareceu"; echo "$out6"; exit 1; }
C6R="$(consumidor c6r)"
strip_heavy_mutex "$C6R/.forge/forge.yaml"
out6r="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c6r" node "$FORGE" update --target "$C6R" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc6r=$?
[ "$rc6r" -eq 0 ] && grep -q 'heavy_mutex: recurso resolvido' <<<"$out6r" \
  || { echo "FAIL [6] (recontrole): depois de restaurar o arquivo, [1] deveria voltar a passar"; echo "$out6r"; exit 1; }
echo "OK [6]"

scenario "[7] mutação B: newForgeKeys ignora chave já declarada, [4] reprova; restaurado, recontrole passa"
cp "$FORGE_MJS_SRC" "$T/forge.mjs.orig2"
perl -pi -e "s/if \(dstKeys\.has\(key\)\) continue;/if (false) continue;/" "$FORGE_MJS_SRC"
C7="$(consumidor c7)"
set_heavy_mutex "$C7/.forge/forge.yaml" "axis-heavy-suite" "__SEM__" "true"
out7="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c7" node "$FORGE" update --target "$C7" --no-plugin --no-backup --source "$TPL" 2>&1)"
N7_DEPOIS="$(n_blocos "$C7/.forge/forge.yaml")"
mut7_ok=1
[ "$N7_DEPOIS" -eq 1 ] && mut7_ok=0
cmp -s "$T/forge.mjs.orig2" "$FORGE_MJS_SRC" && { echo "FAIL [7] (setup): a mutação não alterou o arquivo"; exit 1; }
cp "$T/forge.mjs.orig2" "$FORGE_MJS_SRC"
cmp -s "$T/forge.mjs.orig2" "$FORGE_MJS_SRC" || { echo "FAIL [7]: restauração byte a byte falhou (cmp -s)"; exit 1; }
[ "$mut7_ok" -eq 1 ] || { echo "FAIL [7]: mutação deveria fazer o bloco já declarado se DUPLICAR em [4] (2a chave 'heavy_mutex:' acrescentada), e ficou com $N7_DEPOIS — a mutação não exercita a guarda medida"; exit 1; }
C7R="$(consumidor c7r)"
set_heavy_mutex "$C7R/.forge/forge.yaml" "axis-heavy-suite" "__SEM__" "true"
BLOCO7R_ANTES="$(bloco_de "$C7R/.forge/forge.yaml")"
node "$FORGE" update --target "$C7R" --no-plugin --no-backup --source "$TPL" >/dev/null 2>&1
BLOCO7R_DEPOIS="$(bloco_de "$C7R/.forge/forge.yaml")"
[ "$BLOCO7R_ANTES" = "$BLOCO7R_DEPOIS" ] && [ "$(n_blocos "$C7R/.forge/forge.yaml")" -eq 1 ] \
  || { echo "FAIL [7] (recontrole): depois de restaurar o arquivo, [4] deveria voltar a passar (bloco byte-idêntico, chave única)"; exit 1; }
echo "OK [7]"

scenario "[8] PBT: bloco ausente/presente × resource do template × env declarada ou não (seed fixa, >= 50 casos)"
node --input-type=module - "$WS" "$T" "$ROOT_ISO" <<'NODE_EOF'
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { mkdtempSync, rmSync, cpSync, writeFileSync, readFileSync, mkdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const [WS, T, ROOT_ISO] = process.argv.slice(2);
const P = await import(pathToFileURL(join(WS, 'template/.forge/scripts/lib/pbt.mjs')).href);
const FORGE = join(WS, 'bin/forge.mjs');
const TPL = join(WS, 'template/.forge');

// Pristine por variante de SRC (real e uma cópia com resource trocado) e por presença do bloco —
// 4 combinações fixas, cada `init` roda uma vez só; cada caso do PBT parte de uma cópia rasa.
function tplComResource(nome, resource) {
  const out = join(T, `pbt-tpl-${nome}`);
  if (existsSync(out)) return out;
  cpSync(TPL, out, { recursive: true });
  const p = join(out, 'forge.yaml');
  writeFileSync(p, readFileSync(p, 'utf8').replace('resource: forge-heavy-suite', `resource: ${resource}`));
  return out;
}
const TPL_DEFAULT = TPL;                                   // resource: forge-heavy-suite (== default hardcoded da lib)
const TPL_DIVERGENTE = tplComResource('divergente', 'pbt-divergente');

function pristine(withBlock) {
  const dir = mkdtempSync(join(T, `pbt-pristine-${withBlock ? 'com' : 'sem'}-`));
  execFileSync('git', ['init', '-q', dir]);
  execFileSync('git', ['-C', dir, 'config', 'user.email', 't@t']);
  execFileSync('git', ['-C', dir, 'config', 'user.name', 't']);
  execFileSync('node', [FORGE, 'init', '--target', dir, '--slug', 'demo', '--name', 'Demo', '--desc', 't', '--yes', '--no-plugin']);
  if (!withBlock) {
    const p = join(dir, '.forge', 'forge.yaml');
    writeFileSync(p, readFileSync(p, 'utf8').replace(/^heavy_mutex:\n(?:[ \t].*\n?)*\n?/m, ''));
  }
  return dir;
}
const PRISTINE_SEM = pristine(false);
const PRISTINE_COM = pristine(true);

const gBlockPresent = P.gen.bool();
const gSrcDivergente = P.gen.bool();
const gEnvSet = P.gen.bool();

let casesRun = 0;
const prop = (blockPresent, srcDivergente, envSet) => {
  casesRun++;
  const base = blockPresent ? PRISTINE_COM : PRISTINE_SEM;
  const dir = mkdtempSync(join(T, 'pbt-case-'));
  rmSync(dir, { recursive: true, force: true });
  cpSync(base, dir, { recursive: true });

  const src = srcDivergente ? TPL_DIVERGENTE : TPL_DEFAULT;
  const srcResource = srcDivergente ? 'pbt-divergente' : 'forge-heavy-suite';
  const rootIso = join(ROOT_ISO, `pbt-${casesRun}`);
  mkdirSync(rootIso, { recursive: true });
  const env = { ...process.env, FORGE_HEAVY_MUTEX_ROOT: rootIso };
  delete env.FORGE_HEAVY_MUTEX_RESOURCE;
  if (envSet) env.FORGE_HEAVY_MUTEX_RESOURCE = 'pbt-env-resource';

  const blockPathRe = /^heavy_mutex:\n(?:[ \t].*\n?)*\n?/m;
  const blockBefore = blockPresent ? (readFileSync(join(dir, '.forge', 'forge.yaml'), 'utf8').match(blockPathRe) || [''])[0] : null;

  let out = '', rc = 0;
  try {
    out = execFileSync('node', [FORGE, 'update', '--target', dir, '--no-plugin', '--no-backup', '--source', src], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], env });
  } catch (e) {
    rc = e.status ?? 1;
    out = (e.stdout || '') + (e.stderr || '');
  }
  let ok = rc === 0;

  const nominal = /(WARN: )?heavy_mutex: recurso resolvido (\S+) → (\S+) \(lock (\S+)\)/.exec(out);

  if (ok && blockPresent) {
    // chave já declarada: nunca tocada, e a rota da linha nominal nem deveria executar. A
    // contagem de ocorrências de `^heavy_mutex:` prova que o merge foi barrado por inteiro, não
    // só que o PRIMEIRO trecho ficou intacto (um merge que esqueça a guarda ACRESCENTA uma
    // segunda chave no fim do arquivo, sem tocar a primeira).
    const yamlAfter = readFileSync(join(dir, '.forge', 'forge.yaml'), 'utf8');
    const blockAfter = (yamlAfter.match(blockPathRe) || [''])[0];
    const nOcorrencias = (yamlAfter.match(/^heavy_mutex:/gm) || []).length;
    if (blockAfter !== blockBefore) ok = false;
    if (nOcorrencias !== 1) ok = false;
    if (nominal) ok = false;
  } else if (ok) {
    // bloco ausente: mesclado — a linha nominal tem de existir e nomear exatamente o par previsto
    // pela precedência env > forge.yaml > default (env vale para os dois lados, quando declarada).
    const antesEsperado = envSet ? 'pbt-env-resource' : 'forge-heavy-suite';
    const depoisEsperado = envSet ? 'pbt-env-resource' : srcResource;
    if (!nominal) ok = false;
    else {
      const [, warn, antes, depois, lockPath] = nominal;
      if (antes !== antesEsperado) ok = false;
      if (depois !== depoisEsperado) ok = false;
      const deveriaWarn = antesEsperado !== depoisEsperado;
      if (deveriaWarn !== Boolean(warn)) ok = false;
      if (lockPath !== join(rootIso, `${depoisEsperado}.lock`)) ok = false;
    }
  }
  rmSync(dir, { recursive: true, force: true });
  return ok;
};

const r = P.forAll([gBlockPresent, gSrcDivergente, gEnvSet], prop, { runs: 56, seed: 142217 });
rmSync(PRISTINE_SEM, { recursive: true, force: true });
rmSync(PRISTINE_COM, { recursive: true, force: true });
if (!r.ok) {
  console.error(`FAIL [8]: propriedade falhou após ${r.runs} caso(s) (seed ${r.seed})`);
  console.error('  contraexemplo minimizado: ' + JSON.stringify(r.counterexample));
  if (r.error) console.error('  erro: ' + r.error);
  process.exit(1);
}
if (casesRun < 50) { console.error(`FAIL [8]: rodou só ${casesRun} caso(s), esperado >= 50`); process.exit(1); }
console.log(`OK [8] (${r.runs} casos, seed ${r.seed})`);
NODE_EOF
rc8=$?
[ "$rc8" -eq 0 ] || { echo "FAIL [8]: PBT reprovou (ver saída acima)"; exit 1; }

[ "$SCENARIOS_RUN" -gt 0 ] \
  || { echo "FAIL [contador]: nenhum cenário executado — um gate que não roda nada não cobre nada"; exit 1; }
GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: a suíte levou ${GATE_ELAPSED}s, acima do teto declarado de ${GATE_BUDGET_S}s"; exit 1; }
echo "PASS w217-heavy-mutex-partition ($SCENARIOS_RUN cenário(s) + PBT, ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
