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
# divergem — ou quando a resolução falha de qualquer lado (nunca silêncio). A resolução é feita
# pela PRÓPRIA lib (`heavy-mutex.sh`, funções `_fhm_resource`/`forge_heavy_mutex_path` sourceadas
# por subprocesso bash) — nunca uma reimplementação paralela em JS da precedência
# env > forge.yaml > default, que é exatamente o tipo de gêmeo-mentiroso que causou a partição
# original (duas cópias da mesma regra, uma delas defasada). O `resource` nomeado vem DIRETO da
# lib, nunca de `basename(path)` — um recurso com caractere de path (`/`) produziria um `path` com
# subdiretório, e `basename` devolveria só o último segmento, um nome diferente do que a lib
# realmente resolve.
#
#   [1] positiva: bloco ausente, sem env, template real (default do template == default hardcoded
#       da lib) — linha nominal aparece, SEM `WARN:`, e nomeia o lock sob o root isolado do caso.
#   [2] WARN: bloco ausente, template com `resource:` diferente do default hardcoded da lib —
#       linha nominal com `WARN:`, nomeando os dois nomes (antes = default da lib; depois = valor
#       que o template escreveu).
#   [3] env vence dos dois lados: bloco ausente, `FORGE_HEAVY_MUTEX_RESOURCE` declarado, MESMO
#       template do cenário [2] (que sozinho geraria WARN) — sem `WARN:`, porque a env tem
#       precedência sobre o forge.yaml nos dois momentos (antes E depois do merge).
#   [4] bloco JÁ declarado (`resource` customizado, SEM `root`) nunca é tocado: byte-idêntico
#       depois do update, e NENHUMA linha `heavy_mutex: recurso resolvido` aparece — o merge
#       inteiro é barrado pela chave já presente, então a rota que imprimiria a linha nem executa.
#   [5] bloco JÁ declarado COM `root` real (fixture do axis-fare-validator: `root:
#       "${TMPDIR:-/tmp}"`, token literal entre aspas) nunca é tocado — mesma garantia de [4], mas
#       exercitando a dimensão `root` que a issue original mede em campo, e que [4] sozinho nunca
#       cobria (achado MEDIUM do review: a suíte alegava cobertura de `root` sem nenhum cenário
#       declarando um).
#   [6] doctor.sh: a linha `HEAVY-MUTEX` já existente nomeia o recurso resolvido (`recurso .....
#       <res>`) e o caminho do lock (`lock ........ <root>/<recurso>.lock`) — regressão estrutural,
#       não nova (a função já existe desde a #52); travada aqui para que um refactor futuro do
#       doctor não a perca em silêncio.
#   [6b]/[6c] `--dry-run` sobre bloco ausente, sem e com `FORGE_HEAVY_MUTEX_RESOURCE` — a prévia
#       nomeia o recurso previsto e, com `FORGE_HEAVY_MUTEX_ROOT` apontando para um diretório
#       inexistente, a raiz continua inexistente depois do dry-run (achado MEDIUM do review:
#       `resolveHeavyMutexPath` na prévia chamava a mesma `_fhm_resolve_root` que faz `mkdir` na
#       raiz declarada ausente — efeito colateral que uma prévia não pode ter).
#   [7] resolução falha (root isolado é um ARQUIVO comum, não um diretório — `_fhm_resolve_root`
#       recusa com rc 69): o update segue rc 0 (a linha é best-effort, nunca derruba a aplicação),
#       mas imprime `WARN: heavy_mutex: recurso resolvido não determinado (<motivo>) — bloco
#       mesclado com resource: <valor do template>` — NUNCA fica em silêncio (achado MEDIUM do
#       review: a versão anterior só imprimia a linha quando as duas resoluções tinham sucesso, e
#       uma falha de qualquer lado apagava a linha inteira, reproduzindo o sintoma original da
#       issue pela própria correção).
#   [8] mutação A, sobre CÓPIA ISOLADA (nunca a árvore rastreada real — ver ISOLAMENTO abaixo):
#       apagar o bloco que imprime a linha nominal reprova [1] (linha ausente); o binário REAL
#       (nunca mutado) roda o mesmo cenário em paralelo como recontrole e continua OK.
#   [9] mutação B, sobre CÓPIA ISOLADA: fazer `newForgeKeys` deixar de checar `dstKeys.has(key)`
#       reprova [4] (o bloco já declarado deixa de ficar byte-idêntico); o binário REAL roda o
#       mesmo cenário como recontrole e continua OK.
#   [10] PBT (seed fixa, >= 50 casos): para bloco ausente/presente × resource do template
#        gerado aleatoriamente (charset seguro) × env com resource gerado aleatoriamente ou não
#        declarada, a invariante do plano vale sempre: quando o bloco já existe, fica
#        byte-idêntico (incluindo uma linha de `root` real) e nenhuma linha nominal aparece; quando
#        é mesclado, a linha nominal nomeia exatamente o par (antes, depois) previsto pela
#        precedência env > forge.yaml > default, com `WARN:` see os dois nomes divergirem, e o
#        `(lock …)` aponta para `<root>/<depois>.lock`.
#
# ISOLAMENTO (regra transversal desta rodada). Todo caso que resolve o heavy-mutex roda com
# `FORGE_HEAVY_MUTEX_ROOT` apontado para um diretório temporário PRÓPRIO — nunca o lock real da
# máquina. `forge_heavy_mutex_path` só RESOLVE (nunca adquire: não cria diretório de lock), mesma
# garantia estrutural do gate w154 sobre `_fhm_resolve_root` — mas a raiz ainda é isolada, porque
# outras frentes rodam gates em paralelo na mesma máquina e um `root:` declarado inexistente faz a
# lib criar o diretório (`mkdir`), efeito que este gate não quer produzir fora do seu próprio `T`.
#
# ISOLAMENTO DAS MUTAÇÕES (achado BLOCKER do review, LDG-0179/w213). As duas mutações ([8] e [9])
# NUNCA escrevem em `$WS/bin/forge.mjs` — o arquivo rastreado da árvore real. Cada mutação roda
# sobre uma CÓPIA completa de `bin/`, `template/` e `package.json` dentro de `$T` (função
# `ws_copia`, abaixo), criada e destruída dentro do próprio cenário. Um `perl -pi` que rodasse
# sobre o arquivo real, restaurado só por um `cp` de volta, deixaria a árvore rastreada mutada se o
# processo morresse (SIGKILL, OOM — o modo de morte real que motivou o LDG-0175/0179) entre a
# mutação e a restauração; o gate w213 (sentinela de escrita em arquivo rastreado da árvore real)
# reprovaria a suíte inteira. Sobre uma cópia em `$T`, esse risco não existe: `$T` é descartável e
# o `trap` do topo do arquivo já cobre sua remoção, mutada ou não.
set -uo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo
# obedecerem ao repositório de quem invocou o gate, e não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$WS/bin/forge.mjs"
TPL="$WS/template/.forge"
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

# ws_copia <nome> -> ecoa <dir> — cópia INDEPENDENTE de bin/, template/, installer/ e
# package.json em $T, para as mutações rodarem por cima sem NUNCA tocar o arquivo rastreado real
# ($WS/bin/forge.mjs). `installer/` entra porque `bin/forge.mjs` resolve `GITIGNORE_PATCH`,
# `GITATTRIBUTES_PATCH` e `REMOVED_MANIFEST` como `PKG_ROOT/installer/*` (`PKG_ROOT =
# dirname(bin)/..`) — sem ele o `update` da cópia falha com ENOENT no primeiro `update` real
# (medido: `open '<ws>/installer/gitignore.patch'`). Cada chamada cria uma cópia nova (o custo é
# ~450 arquivos, poucos MB — trivial frente ao orçamento do gate) para que duas mutações no mesmo
# run nunca compartilhem estado mutado.
ws_copia() {
  local out="$T/ws-$1"
  mkdir -p "$out"
  cp -R "$WS/bin" "$out/bin"
  cp -R "$WS/template" "$out/template"
  cp -R "$WS/installer" "$out/installer"
  cp "$WS/package.json" "$out/package.json"
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

scenario "[4] bloco JÁ declarado (sem root) nunca é tocado — byte-idêntico, nenhuma linha nominal"
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

scenario "[5] bloco JÁ declarado COM root real (fixture axis-fare-validator) nunca é tocado"
# achado MEDIUM do review: [4] sozinho nunca declarava `root`, e o plano (D8/PBT) exige que
# `resource`, `root` E `enabled` declarados fiquem byte-idênticos. A fixture abaixo é o valor
# medido em campo (axis-fare-validator e Axis.PadSimulator): o TOKEN literal `${TMPDIR:-/tmp}`
# entre aspas, nunca o valor já expandido — é o que os dois consumidores reais têm versionado.
C5="$(consumidor c5)"
set_heavy_mutex "$C5/.forge/forge.yaml" "axis-heavy-suite" '"${TMPDIR:-/tmp}"' "true"
BLOCO5_ANTES="$(bloco_de "$C5/.forge/forge.yaml")"
grep -qF 'root: "${TMPDIR:-/tmp}"' <<<"$BLOCO5_ANTES" \
  || { echo "FAIL [5] (setup): a fixture não escreveu a linha de root esperada"; echo "$BLOCO5_ANTES"; exit 1; }
out5="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c5" node "$FORGE" update --target "$C5" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc5=$?
[ "$rc5" -eq 0 ] || { echo "FAIL [5]: update saiu rc=$rc5"; echo "$out5"; exit 1; }
BLOCO5_DEPOIS="$(bloco_de "$C5/.forge/forge.yaml")"
[ "$BLOCO5_ANTES" = "$BLOCO5_DEPOIS" ] \
  || { echo "FAIL [5]: bloco heavy_mutex (incluindo a linha de root) mudou.
ANTES:
$BLOCO5_ANTES
DEPOIS:
$BLOCO5_DEPOIS"; exit 1; }
[ "$(n_blocos "$C5/.forge/forge.yaml")" -eq 1 ] \
  || { echo "FAIL [5]: forge.yaml ficou com $(n_blocos "$C5/.forge/forge.yaml") chave(s) 'heavy_mutex:'"; exit 1; }
grep -q 'heavy_mutex: recurso resolvido' <<<"$out5" \
  && { echo "FAIL [5]: linha nominal apareceu para um bloco que já existia com root próprio"; echo "$out5"; exit 1; }
echo "OK [5]"

scenario "[6] doctor.sh nomeia o recurso resolvido na linha HEAVY-MUTEX (regressão)"
C6D="$(consumidor c6d)"
out6d="$(FORGE_ROOT="$C6D" env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c6d" bash "$C6D/.forge/scripts/doctor.sh" 2>&1)"
grep -q 'HEAVY-MUTEX:.*recurso ..... forge-heavy-suite' <<<"$out6d" \
  || { echo "FAIL [6]: doctor.sh não nomeia o recurso resolvido na linha HEAVY-MUTEX"; echo "$out6d" | grep -i heavy; exit 1; }
grep -qF "lock ........ $ROOT_ISO/c6d/forge-heavy-suite.lock" <<<"$out6d" \
  || { echo "FAIL [6]: doctor.sh não nomeia o caminho do lock (<root>/<recurso>.lock) na linha HEAVY-MUTEX"; echo "$out6d" | grep -i heavy; exit 1; }
echo "OK [6]"

scenario "[6b] --dry-run: bloco heavy_mutex ausente, SEM FORGE_HEAVY_MUTEX_RESOURCE — prévia nomeia o recurso e NUNCA cria a raiz declarada"
C6B="$(consumidor c6b)"
strip_heavy_mutex "$C6B/.forge/forge.yaml"
ROOT_6B="$ROOT_ISO/c6b-inexistente"
[ -d "$ROOT_6B" ] && { echo "FAIL [6b] (setup): a raiz já existia antes do dry-run"; exit 1; }
out6b="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_6B" node "$FORGE" update --target "$C6B" --dry-run --no-plugin --source "$TPL" 2>&1)"; rc6b=$?
[ "$rc6b" -eq 0 ] || { echo "FAIL [6b]: dry-run saiu rc=$rc6b"; echo "$out6b"; exit 1; }
linha6b="$(grep 'heavy_mutex: recurso previsto' <<<"$out6b")"
[ -n "$linha6b" ] || { echo "FAIL [6b]: linha de prévia ausente"; echo "$out6b"; exit 1; }
grep -qF 'recurso previsto forge-heavy-suite' <<<"$linha6b" \
  || { echo "FAIL [6b]: prévia não nomeia o recurso default ('$linha6b')"; exit 1; }
[ -d "$ROOT_6B" ] && { echo "FAIL [6b]: dry-run criou a raiz declarada ($ROOT_6B), que deveria continuar inexistente"; exit 1; }
echo "OK [6b]"

scenario "[6c] --dry-run: bloco heavy_mutex ausente, COM FORGE_HEAVY_MUTEX_RESOURCE — prévia nomeia o recurso da env e NUNCA cria a raiz declarada"
C6C="$(consumidor c6c)"
strip_heavy_mutex "$C6C/.forge/forge.yaml"
ROOT_6C="$ROOT_ISO/c6c-inexistente"
[ -d "$ROOT_6C" ] && { echo "FAIL [6c] (setup): a raiz já existia antes do dry-run"; exit 1; }
out6c="$(env FORGE_HEAVY_MUTEX_RESOURCE=env-6c FORGE_HEAVY_MUTEX_ROOT="$ROOT_6C" node "$FORGE" update --target "$C6C" --dry-run --no-plugin --source "$TPL" 2>&1)"; rc6c=$?
[ "$rc6c" -eq 0 ] || { echo "FAIL [6c]: dry-run saiu rc=$rc6c"; echo "$out6c"; exit 1; }
linha6c="$(grep 'heavy_mutex: recurso previsto' <<<"$out6c")"
[ -n "$linha6c" ] || { echo "FAIL [6c]: linha de prévia ausente"; echo "$out6c"; exit 1; }
grep -qF 'recurso previsto env-6c' <<<"$linha6c" \
  || { echo "FAIL [6c]: prévia não nomeia o recurso vindo da env ('$linha6c')"; exit 1; }
[ -d "$ROOT_6C" ] && { echo "FAIL [6c]: dry-run criou a raiz declarada ($ROOT_6C), que deveria continuar inexistente"; exit 1; }
echo "OK [6c]"

scenario "[7] resolução falha (root isolado é um arquivo comum) — WARN nominal, NUNCA silêncio"
# achado MEDIUM do review: antes desta correção, `resolveHeavyMutexPath` devolvia null em
# qualquer falha e `updateHarness` só imprimia a linha quando as DUAS resoluções tinham sucesso
# (`if (hmBefore && hmAfter)`) — uma falha de qualquer lado apagava a linha inteira, reproduzindo
# o sintoma original da issue (bloco mesclado sem UMA linha sobre identidade de lock) pela própria
# correção. `FORGE_HEAVY_MUTEX_ROOT` apontado para um ARQUIVO comum (não diretório) faz
# `_fhm_resolve_root` recusar com rc 69 (`heavy-mutex.sh`: "não consegui criar ... — já existe e
# não é diretório"), sem tocar nada fora de `$T`.
C7F="$(consumidor c7f)"
strip_heavy_mutex "$C7F/.forge/forge.yaml"
ROOT_INUTILIZAVEL="$ROOT_ISO/c7f-arquivo-nao-diretorio"
: > "$ROOT_INUTILIZAVEL"
out7f="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_INUTILIZAVEL" node "$FORGE" update --target "$C7F" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc7f=$?
[ "$rc7f" -eq 0 ] \
  || { echo "FAIL [7]: update deveria seguir rc 0 mesmo com a resolução do heavy-mutex falhando (best-effort) — saiu rc=$rc7f"; echo "$out7f"; exit 1; }
linha7f="$(grep 'heavy_mutex:' <<<"$out7f")"
[ -n "$linha7f" ] || { echo "FAIL [7]: NENHUMA linha heavy_mutex apareceu — a falha de resolução voltou a ficar em silêncio"; echo "$out7f"; exit 1; }
grep -q '^WARN: heavy_mutex: recurso resolvido não determinado' <<<"$linha7f" \
  || { echo "FAIL [7]: linha presente mas sem o prefixo WARN esperado para resolução indeterminada ('$linha7f')"; exit 1; }
grep -qF 'bloco mesclado com resource: forge-heavy-suite' <<<"$linha7f" \
  || { echo "FAIL [7]: WARN não nomeia o resource que o bloco do template escreveu ('$linha7f')"; exit 1; }
echo "OK [7]"

scenario "[8] mutação A (linha nominal), sobre CÓPIA ISOLADA — NUNCA a árvore rastreada real"
WS8="$(ws_copia mut-a)"
WS8_ORIG="$T/forge.mjs.orig8"
cp "$WS8/bin/forge.mjs" "$WS8_ORIG"
perl -pi -e "s/if \(added\.includes\('heavy_mutex'\)\) \{/if (false \&\& added.includes('heavy_mutex')) {/" "$WS8/bin/forge.mjs"
cmp -s "$WS8_ORIG" "$WS8/bin/forge.mjs" && { echo "FAIL [8] (setup): a mutação não alterou a cópia — o teste não provaria nada"; exit 1; }
C8="$(consumidor c8)"
strip_heavy_mutex "$C8/.forge/forge.yaml"
out8="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c8" node "$WS8/bin/forge.mjs" update --target "$C8" --no-plugin --no-backup --source "$WS8/template/.forge" 2>&1)"; rc8m=$?
mut8_ok=1
if [ "$rc8m" -ne 0 ]; then mut8_ok=0
elif grep -q 'heavy_mutex: recurso resolvido' <<<"$out8"; then mut8_ok=0; fi
[ "$mut8_ok" -eq 1 ] || { echo "FAIL [8]: mutação deveria fazer a linha nominal desaparecer em [1], e não desapareceu"; echo "$out8"; exit 1; }
# recontrole: MESMO cenário, com o binário REAL (nunca tocado) — prova que o defeito observado é
# da mutação na cópia, não de algum efeito colateral do isolamento do teste.
C8R="$(consumidor c8r)"
strip_heavy_mutex "$C8R/.forge/forge.yaml"
out8r="$(env -u FORGE_HEAVY_MUTEX_RESOURCE FORGE_HEAVY_MUTEX_ROOT="$ROOT_ISO/c8r" node "$FORGE" update --target "$C8R" --no-plugin --no-backup --source "$TPL" 2>&1)"; rc8r=$?
[ "$rc8r" -eq 0 ] && grep -q 'heavy_mutex: recurso resolvido' <<<"$out8r" \
  || { echo "FAIL [8] (recontrole): com o binário real (não mutado), [1] deveria continuar passando"; echo "$out8r"; exit 1; }
rm -rf "$WS8"
echo "OK [8]"

scenario "[9] mutação B (guarda de chave já declarada), sobre CÓPIA ISOLADA — NUNCA a árvore rastreada real"
WS9="$(ws_copia mut-b)"
WS9_ORIG="$T/forge.mjs.orig9"
cp "$WS9/bin/forge.mjs" "$WS9_ORIG"
perl -pi -e "s/if \(dstKeys\.has\(key\)\) continue;/if (false) continue;/" "$WS9/bin/forge.mjs"
cmp -s "$WS9_ORIG" "$WS9/bin/forge.mjs" && { echo "FAIL [9] (setup): a mutação não alterou a cópia"; exit 1; }
C9="$(consumidor c9)"
set_heavy_mutex "$C9/.forge/forge.yaml" "axis-heavy-suite" "__SEM__" "true"
node "$WS9/bin/forge.mjs" update --target "$C9" --no-plugin --no-backup --source "$WS9/template/.forge" >/dev/null 2>&1
N9_DEPOIS="$(n_blocos "$C9/.forge/forge.yaml")"
mut9_ok=1
[ "$N9_DEPOIS" -eq 1 ] && mut9_ok=0
[ "$mut9_ok" -eq 1 ] || { echo "FAIL [9]: mutação deveria fazer o bloco já declarado se DUPLICAR (2a chave 'heavy_mutex:' acrescentada), e ficou com $N9_DEPOIS — a mutação não exercita a guarda medida"; exit 1; }
# recontrole: MESMO cenário, com o binário REAL — o bloco continua byte-idêntico e único.
C9R="$(consumidor c9r)"
set_heavy_mutex "$C9R/.forge/forge.yaml" "axis-heavy-suite" "__SEM__" "true"
BLOCO9R_ANTES="$(bloco_de "$C9R/.forge/forge.yaml")"
node "$FORGE" update --target "$C9R" --no-plugin --no-backup --source "$TPL" >/dev/null 2>&1
BLOCO9R_DEPOIS="$(bloco_de "$C9R/.forge/forge.yaml")"
[ "$BLOCO9R_ANTES" = "$BLOCO9R_DEPOIS" ] && [ "$(n_blocos "$C9R/.forge/forge.yaml")" -eq 1 ] \
  || { echo "FAIL [9] (recontrole): com o binário real, [4] deveria continuar passando (bloco byte-idêntico, chave única)"; exit 1; }
rm -rf "$WS9"
echo "OK [9]"

scenario "[10] PBT: bloco ausente/presente × resource gerado aleatoriamente (template e env) (seed fixa, >= 50 casos)"
node --input-type=module - "$WS" "$T" "$ROOT_ISO" <<'NODE_EOF'
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { mkdtempSync, rmSync, cpSync, writeFileSync, readFileSync, mkdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const [WS, T, ROOT_ISO] = process.argv.slice(2);
const P = await import(pathToFileURL(join(WS, 'template/.forge/scripts/lib/pbt.mjs')).href);
const FORGE = join(WS, 'bin/forge.mjs');
const TPL = join(WS, 'template/.forge');

// Charset seguro para um valor `resource:` de YAML plano: letras minúsculas, dígitos, '-', '_',
// '.' — nunca espaço (o regex de leitura da linha nominal usa `\S+`, que não aceita espaço) nem
// caractere de sintaxe YAML (':', '#', aspas). Achado MEDIUM do review: a versão anterior gerava
// só `gen.bool()` — 8 combinações fixas repetidas 56 vezes — em vez de strings, apesar de
// `pbt.mjs` já expor `gen.array`/`gen.oneOf` (usadas por outro gate desta mesma rodada, o w214).
const SAFE_CHARS = [...'abcdefghijklmnopqrstuvwxyz0123456789', '-', '_', '.'];

// Fixture real (root fixo, não gerado): o mesmo token literal do axis-fare-validator/
// Axis.PadSimulator, usado no ramo "bloco presente" para provar que o `root` declarado — não só
// `resource` — sobrevive byte a byte (achado MEDIUM do review: o ramo presente usava só o bloco
// default do template, sem nunca declarar `root`).
const ROOT_FIXTURE_LINE = '  root: "${TMPDIR:-/tmp}"\n';

function tplComResourceDinamico(resource, tag) {
  const out = join(T, `pbt-tpl-${tag}`);
  cpSync(TPL, out, { recursive: true });
  const p = join(out, 'forge.yaml');
  writeFileSync(p, readFileSync(p, 'utf8').replace('resource: forge-heavy-suite', `resource: ${resource}`));
  return out;
}
const TPL_DEFAULT = TPL; // resource: forge-heavy-suite (== default hardcoded da lib), sem gerar cópia

function pristine(withBlock) {
  const dir = mkdtempSync(join(T, `pbt-pristine-${withBlock ? 'com' : 'sem'}-`));
  execFileSync('git', ['init', '-q', dir]);
  execFileSync('git', ['-C', dir, 'config', 'user.email', 't@t']);
  execFileSync('git', ['-C', dir, 'config', 'user.name', 't']);
  execFileSync('node', [FORGE, 'init', '--target', dir, '--slug', 'demo', '--name', 'Demo', '--desc', 't', '--yes', '--no-plugin']);
  const p = join(dir, '.forge', 'forge.yaml');
  if (!withBlock) {
    writeFileSync(p, readFileSync(p, 'utf8').replace(/^heavy_mutex:\n(?:[ \t].*\n?)*\n?/m, ''));
  } else {
    // bloco presente: `resource` customizado (não o default do template) + `root` real da
    // fixture, para que a invariante "byte-idêntico" da propriedade cubra as três chaves que o
    // plano (D8) exige — não só a ausência de linha nominal.
    let t = readFileSync(p, 'utf8');
    t = t.replace(
      /^heavy_mutex:\n(?:[ \t].*\n?)*\n?/m,
      `heavy_mutex:\n  enabled: true\n  resource: axis-heavy-suite\n${ROOT_FIXTURE_LINE}  timeout_s: 1800\n`,
    );
    writeFileSync(p, t);
  }
  return dir;
}
const PRISTINE_SEM = pristine(false);
const PRISTINE_COM = pristine(true);

const gBlockPresent = P.gen.bool();
const gDivergentFlag = P.gen.bool();
const gDivergentChars = P.gen.array(P.gen.oneOf(SAFE_CHARS), 1, 24);
const gEnvFlag = P.gen.bool();
const gEnvChars = P.gen.array(P.gen.oneOf(SAFE_CHARS), 1, 24);

let casesRun = 0;
const prop = (blockPresent, divergentFlag, divergentChars, envFlag, envChars) => {
  casesRun++;
  const base = blockPresent ? PRISTINE_COM : PRISTINE_SEM;
  const dir = mkdtempSync(join(T, 'pbt-case-'));
  rmSync(dir, { recursive: true, force: true });
  cpSync(base, dir, { recursive: true });

  const divergentResource = divergentChars.join('');
  const envResource = envChars.join('');
  const src = divergentFlag ? tplComResourceDinamico(divergentResource, `c${casesRun}`) : TPL_DEFAULT;
  const srcResource = divergentFlag ? divergentResource : 'forge-heavy-suite';
  const rootIso = join(ROOT_ISO, `pbt-${casesRun}`);
  mkdirSync(rootIso, { recursive: true });
  const env = { ...process.env, FORGE_HEAVY_MUTEX_ROOT: rootIso };
  delete env.FORGE_HEAVY_MUTEX_RESOURCE;
  if (envFlag) env.FORGE_HEAVY_MUTEX_RESOURCE = envResource;

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
    // chave já declarada (resource custom + root real): nunca tocada, e a rota da linha nominal
    // nem deveria executar. A contagem de ocorrências de `^heavy_mutex:` prova que o merge foi
    // barrado por inteiro, não só que o PRIMEIRO trecho ficou intacto (um merge que esqueça a
    // guarda ACRESCENTA uma segunda chave no fim do arquivo, sem tocar a primeira).
    const yamlAfter = readFileSync(join(dir, '.forge', 'forge.yaml'), 'utf8');
    const blockAfter = (yamlAfter.match(blockPathRe) || [''])[0];
    const nOcorrencias = (yamlAfter.match(/^heavy_mutex:/gm) || []).length;
    if (blockAfter !== blockBefore) ok = false;
    if (!blockAfter.includes(ROOT_FIXTURE_LINE.trim())) ok = false; // a linha de root sobrevive byte a byte
    if (nOcorrencias !== 1) ok = false;
    if (nominal) ok = false;
  } else if (ok) {
    // bloco ausente: mesclado — a linha nominal tem de existir e nomear exatamente o par previsto
    // pela precedência env > forge.yaml > default (env vale para os dois lados, quando declarada).
    const antesEsperado = envFlag ? envResource : 'forge-heavy-suite';
    const depoisEsperado = envFlag ? envResource : srcResource;
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

const r = P.forAll([gBlockPresent, gDivergentFlag, gDivergentChars, gEnvFlag, gEnvChars], prop, { runs: 56, seed: 142217 });
rmSync(PRISTINE_SEM, { recursive: true, force: true });
rmSync(PRISTINE_COM, { recursive: true, force: true });
if (!r.ok) {
  console.error(`FAIL [10]: propriedade falhou após ${r.runs} caso(s) (seed ${r.seed})`);
  console.error('  contraexemplo minimizado: ' + JSON.stringify(r.counterexample));
  if (r.error) console.error('  erro: ' + r.error);
  process.exit(1);
}
if (casesRun < 50) { console.error(`FAIL [10]: rodou só ${casesRun} caso(s), esperado >= 50`); process.exit(1); }
console.log(`OK [10] (${r.runs} casos, seed ${r.seed})`);
NODE_EOF
rc10=$?
[ "$rc10" -eq 0 ] || { echo "FAIL [10]: PBT reprovou (ver saída acima)"; exit 1; }

[ "$SCENARIOS_RUN" -gt 0 ] \
  || { echo "FAIL [contador]: nenhum cenário executado — um gate que não roda nada não cobre nada"; exit 1; }
GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: a suíte levou ${GATE_ELAPSED}s, acima do teto declarado de ${GATE_BUDGET_S}s"; exit 1; }
echo "PASS w217-heavy-mutex-partition ($SCENARIOS_RUN cenário(s) + PBT, ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
