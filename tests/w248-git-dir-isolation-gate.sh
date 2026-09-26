#!/usr/bin/env bash
# Gate W248 — isolamento de GIT_DIR/GIT_WORK_TREE herdados em gates que criam repositório git
# temporário OU escrevem estado git num alvo sintético (LDG-0201, incidente P1 de 2026-09-26).
#
# O DEFEITO. Gates que criam um repositório git sintético em /tmp para testar a própria fixture
# (via `git init` ou `git -C <dir> init`, seguido de `git config user.email`/`user.name` sem
# `--global`) contavam com o diretório de trabalho corrente, ou com `-C`, para resolver QUAL
# repositório os comandos git afetam. Nenhum dos dois protege: o git honra as variáveis de ambiente
# GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE, GIT_COMMON_DIR e GIT_OBJECT_DIRECTORY com precedência
# ABSOLUTA sobre `-C` e sobre o diretório corrente — `git -C "$D" init` com GIT_DIR exportado
# reinicializa o repositório de GIT_DIR, não `$D`, e `$D/.git` nunca chega a existir. O mesmo vale
# para `git -C "$D" config <chave> <valor>`: medido que ele GRAVA no repositório de GIT_DIR, não em
# `$D` — por isso o vetor alcança também gates que nunca chamam `git init` diretamente, mas rodam
# `installer/install.sh` ou `bin/forge.mjs init/update` sobre um diretório sintético: essas
# ferramentas escrevem `core.hooksPath` via `git -C <alvo> config ...` (`wireHooksPath` em
# `bin/forge.mjs`, o mesmo padrão em `installer/install.sh`), e com GIT_DIR herdado gravariam um
# `core.hooksPath` alheio no repositório real, desligando os hooks dele em silêncio. Quando uma
# sessão paralela mal isolada exporta GIT_DIR apontando para um repositório real, um gate que roda
# ISOLADO (fora do `run-all.sh`, que agora dá `unset` nessas variáveis antes de despachar cada alvo)
# grava a identidade sintética (`user.name=t`, `user.email=t@t`) no `.git/config` do repositório
# real. Incidente medido nesta rodada: 16 commits em 5 branches gravados com autor `t`, um deles já
# mergeado em `develop` (`0c2ab4f`, não reescrito — reescrever histórico publicado exige o dono).
#
# REPRODUÇÃO DO INCIDENTE, medida fora deste gate: com um repositório "vítima" de identidade
# própria e GIT_DIR exportado para ele, `GIT_DIR=<vítima>/.git bash tests/changelog-merge-gate.sh`
# grava `user.email=t@t`/`user.name=t` na vítima, embora o gate nomeie um caminho de /tmp
# totalmente diferente em todas as suas variáveis internas. A mesma reprodução, isolando
# `tests/w248-git-dir-isolation-gate.sh` (este próprio arquivo, ANTES da correção que o cenário
# [8] agora trava) com GIT_DIR herdado, contaminava a vítima na função `vitima()` — o gate do
# incidente era, ele mesmo, uma instância do incidente.
#
#   [1] `tests/changelog-merge-gate.sh` REAL (amostra do defeito — é o próprio gate do incidente),
#       com GIT_DIR exportado para uma vítima: o `.git/config` da vítima sai byte-idêntico antes e
#       depois (cmp -s), e o gate continua passando (rc 0) — a correção não muda o comportamento
#       funcional do gate, só a superfície que ele toca
#   [2] MUTAÇÃO de [1] — numa CÓPIA de `changelog-merge-gate.sh` (sha256 conferido contra o
#       original antes de mutar), remove-se a linha `unset GIT_DIR ...`; rodada com o mesmo padrão
#       de GIT_DIR herdado, a vítima sai CONTAMINADA — prova de que [1] de fato pegaria a ausência
#       da correção. RECONTROLE: uma segunda cópia, íntegra (mesmo sha256 do original), roda com
#       rc 0 EXIGIDO (nunca só "não contaminou" — um recontrole que aborta antes de tocar git
#       aprovaria sem medir nada) e volta a deixar a vítima intacta
#   [3] `tests/run-all.sh` REAL (cópia byte-idêntica por sha256 — "sem recursão sobre a suíte
#       real", o mesmo padrão do w212), despachando um gate SINTÉTICO que reproduz o padrão
#       vulnerável (`cd $T; git init -q; git config user.email/name`, sem `-C` e sem `unset`): com
#       GIT_DIR exportado para uma vítima, ela sai intacta depois de rodar a cópia do runner —
#       prova de que o preâmbulo do RUNNER INTERNO protege até um gate-filho sem preâmbulo próprio
#   [4] MUTAÇÃO de [3] — remove-se a linha `unset GIT_DIR ...` de uma SEGUNDA cópia de
#       `tests/run-all.sh`; rodada a mesma bancada sintética, a vítima sai CONTAMINADA. RECONTROLE:
#       a bancada com a cópia pristina (sha256 idêntico ao runner real) volta a proteger a vítima
#   [5] `template/.forge/scripts/tests/run-all.sh` REAL — o runner que o template DISTRIBUI a todo
#       consumidor (cópia byte-idêntica por sha256) — despachando, via `--path`, um teste sintético
#       vulnerável (`*-test.sh`, o padrão que este runner reconhece): com GIT_DIR exportado para
#       uma vítima, ela sai intacta — sem este cenário, o runner que chega a CADA CONSUMIDOR não
#       tinha nenhum gate medindo sua própria resistência à mutação (medido: [3]/[4] cobrem só o
#       runner interno deste repositório, nunca o do template)
#   [6] MUTAÇÃO de [5] — remove-se a linha `unset GIT_DIR ...` de uma cópia do runner do TEMPLATE;
#       a mesma bancada sintética contamina a vítima. RECONTROLE: a bancada com a cópia pristina de
#       [5], reexecutada, protege a vítima
#   [7] `tests/w102-capability-packs-gate.sh` REAL (amostra do vetor `installer/install.sh` — o
#       gate não chama `git init` nenhuma vez, só instala o harness num diretório sintético via
#       `install.sh`, que grava `core.hooksPath` por `git -C <alvo> config`) com GIT_DIR herdado
#       deixa a vítima intacta — prova de que a proteção alcança também quem nunca inicializa um
#       repositório diretamente
#   [8] SENTINELA ESTRUTURAL — todo `tests/*.sh` que casa o padrão léxico do incidente (`git init`,
#       `git config user.`, `forge.mjs init|update`, `installer/install.sh`, `bin/forge.mjs`),
#       ESTE PRÓPRIO GATE incluído, contém a linha do preâmbulo. Única exceção declarada:
#       `w130-tasks-graph-gate.sh`, em que o padrão casa dentro de uma STRING de dado de teste
#       (título de TASK numa fixture de `parseTasks`), nunca como comando `git` executado
#   [9] MUTAÇÃO de [8] — numa CÓPIA de um gate real do universo do cenário [8]
#       (`w102-capability-packs-gate.sh`), remove-se a linha do preâmbulo; a sentinela reprovada
#       nomeia o arquivo sem recorrer à suíte inteira
#   [10] SENTINELA — o gate examinou exatamente o número de cenários declarado
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DECLARADO=10
EXAMINADOS=0
cen() { EXAMINADOS=$((EXAMINADOS + 1)); }
PREAMBULO='unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY'

T="$(mktemp -d /tmp/forge-w248.XXXXXX)" || { echo "FAIL [0]: mktemp -d falhou"; exit 1; }
trap 'rm -rf "$T"' EXIT

sha_de() { shasum -a 256 "$1" | awk '{print $1}'; }

# vitima <nome> -> ecoa o caminho de um repositório git recém-criado com identidade própria,
# distinta em cada chamada, para nunca reutilizar estado entre cenários.
vitima() {
  local v="$T/$1"
  mkdir -p "$v"
  git -C "$v" init -q -b main >/dev/null
  git -C "$v" config user.email "vitima-$1@vitima.example"
  git -C "$v" config user.name "vitima-$1"
  git -C "$v" config commit.gpgsign false
  echo "$v"
}

# sentinela_universo <basedir> -> lista os *.sh de <basedir> que casam o padrão léxico do
# incidente: criam repositório git temporário OU escrevem estado git num alvo sintético via
# instalador/forge.mjs.
sentinela_universo() {
  grep -lE 'git( -C [^ ]+)? init|git config user\.|forge\.mjs (init|update)|installer/install\.sh|bin/forge\.mjs' "$1"/*.sh 2>/dev/null || true
}

# sentinela_confere <basedir> <isentos-por-basename, separados por espaço> -> lista (uma linha por
# arquivo) os arquivos do universo de <basedir> que NÃO têm a linha do preâmbulo no topo.
sentinela_confere() {
  local base="$1" isentos="$2" f rel
  for f in $(sentinela_universo "$base"); do
    rel="$(basename "$f")"
    case " $isentos " in *" $rel "*) continue ;; esac
    # -x: LINHA INTEIRA, nunca substring — o próprio texto do preâmbulo aparece dentro do
    # comentário deste gate e dentro do comando perl que o muta em [2]/[4]/[6]/[9]; um match por
    # substring aprovaria um arquivo que só CITA a linha, sem executá-la (o defeito original do
    # cenário [8], medido: com a linha real removida deste próprio arquivo, a citação em prosa e
    # no `perl -pi -e 's/^unset .../` bastava para o grep por substring aprovar).
    grep -qxF "$PREAMBULO" "$f" || echo "$f"
  done
}

echo "[1] changelog-merge-gate.sh REAL com GIT_DIR herdado deixa a vítima intacta"
cen
V1="$(vitima v1)"
CFG1_ANTES="$T/v1-config-antes"
cp "$V1/.git/config" "$CFG1_ANTES"
( export GIT_DIR="$V1/.git"; bash "$WS/tests/changelog-merge-gate.sh" ) >"$T/out1.log" 2>&1
RC1=$?
cmp -s "$CFG1_ANTES" "$V1/.git/config" || {
  echo "FAIL [1]: vítima contaminada — .git/config mudou depois de rodar changelog-merge-gate.sh com GIT_DIR herdado"
  diff "$CFG1_ANTES" "$V1/.git/config" 2>&1 || true
  exit 1
}
[ "$RC1" -eq 0 ] || { echo "FAIL [1]: changelog-merge-gate.sh saiu rc=$RC1 com GIT_DIR herdado (deveria continuar passando)"; tail -10 "$T/out1.log"; exit 1; }
echo "OK [1]"

echo "[2] mutação — cópia de changelog-merge-gate.sh sem o preâmbulo contamina; cópia íntegra não contamina (recontrole)"
cen
ORIG="$WS/tests/changelog-merge-gate.sh"
SHA_ORIG="$(sha_de "$ORIG")"
LIBORIG="$WS/template/.forge/scripts/lib/changelog-from-merge.mjs"
[ -f "$LIBORIG" ] || { echo "FAIL [2]: $LIBORIG não existe — não há como montar a bancada"; exit 1; }

# a cópia precisa preservar a MESMA estrutura relativa (tests/ ao lado de template/.forge/…),
# porque o gate resolve WS por BASH_SOURCE e lê a lib nesse caminho relativo — mesmo padrão do
# w212 ("sem recursão sobre a suíte real", cópia byte-idêntica, nunca invocação do arquivo real
# fora do lugar).
mkbancada() { # mkbancada <nome> -> ecoa o caminho da cópia de changelog-merge-gate.sh na bancada
  local b="$T/$1"
  mkdir -p "$b/tests" "$b/template/.forge/scripts/lib"
  cp "$ORIG" "$b/tests/changelog-merge-gate.sh"
  cp "$LIBORIG" "$b/template/.forge/scripts/lib/changelog-from-merge.mjs"
  echo "$b/tests/changelog-merge-gate.sh"
}

COPIA="$(mkbancada bancada2-pristina)"
[ "$(sha_de "$COPIA")" = "$SHA_ORIG" ] || { echo "FAIL [2]: a cópia de changelog-merge-gate.sh não é idêntica ao original"; exit 1; }
MUTADA="$(mkbancada bancada2-mutada)"
perl -pi -e 's/^unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY\n$//' "$MUTADA"
grep -q "unset GIT_DIR" "$MUTADA" && { echo "FAIL [2]: a mutação não removeu a linha do preâmbulo de $MUTADA — o cenário não testaria nada"; exit 1; }

V2="$(vitima v2)"
CFG2_ANTES="$T/v2-config-antes"
cp "$V2/.git/config" "$CFG2_ANTES"
( export GIT_DIR="$V2/.git"; bash "$MUTADA" ) >/dev/null 2>&1 || true
cmp -s "$CFG2_ANTES" "$V2/.git/config" && { echo "FAIL [2]: a cópia MUTADA (sem o preâmbulo) deveria contaminar a vítima e não contaminou — o cenário [1] não pegaria a ausência da correção"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V2B="$(vitima v2b)"
CFG2B_ANTES="$T/v2b-config-antes"
cp "$V2B/.git/config" "$CFG2B_ANTES"
OUT2B="$T/out2b.log"
( export GIT_DIR="$V2B/.git"; bash "$COPIA" ) >"$OUT2B" 2>&1
RC2B=$?
[ "$RC2B" -eq 0 ] || { echo "FAIL [2]: RECONTROLE — a cópia ÍNTEGRA saiu rc=$RC2B em vez de 0 (um recontrole que aborta antes de tocar git aprovaria sem ter exercitado nada)"; tail -10 "$OUT2B"; exit 1; }
cmp -s "$CFG2B_ANTES" "$V2B/.git/config" || { echo "FAIL [2]: RECONTROLE — a cópia ÍNTEGRA (mesmo sha256 do original) contaminou a vítima; a mutação não foi limpa"; exit 1; }
echo "OK [2]"

echo "[3] tests/run-all.sh REAL despachando um gate sintético vulnerável deixa a vítima intacta"
cen
B3="$T/bancada3"
mkdir -p "$B3/tests" "$B3/template/.forge/scripts/lib"
cp "$WS/tests/run-all.sh" "$B3/tests/run-all.sh"
[ "$(sha_de "$WS/tests/run-all.sh")" = "$(sha_de "$B3/tests/run-all.sh")" ] || { echo "FAIL [3]: a cópia de tests/run-all.sh na bancada não é idêntica ao original"; exit 1; }
chmod +x "$B3/tests/run-all.sh"
# DUBLÊ NEUTRO da sentinela de árvore rastreada (LDG-0179) — mesmo padrão do w212: o que esta
# bancada mede é o isolamento de GIT_DIR, não a sentinela, que tem gate próprio (w213).
printf '%s\n' '#!/usr/bin/env bash' \
  'arvore_retrato() { echo dublê; return 0; }' \
  'arvore_confere() { return 0; }' \
  > "$B3/template/.forge/scripts/lib/arvore-rastreada.sh"

# gate sintético: reproduz o padrão vulnerável de changelog-merge-gate.sh ANTES da correção —
# `cd`, `git init`, `git config user.*` sem `-C` e sem `unset`.
{
  echo '#!/usr/bin/env bash'
  echo 'set -euo pipefail'
  echo 'T="$(mktemp -d /tmp/forge-w248-sint.XXXXXX)"'
  echo 'trap '\''rm -rf "$T"'\'' EXIT'
  echo 'cd "$T"'
  echo 'git init -q'
  echo 'git config user.email "t@t"; git config user.name "t"'
  echo 'echo "OK sintético"'
} > "$B3/tests/synthetic-vuln-gate.sh"
chmod +x "$B3/tests/synthetic-vuln-gate.sh"

V3="$(vitima v3)"
CFG3_ANTES="$T/v3-config-antes"
cp "$V3/.git/config" "$CFG3_ANTES"
( cd "$B3" && export GIT_DIR="$V3/.git" && bash "$B3/tests/run-all.sh" ) >"$T/out3.log" 2>&1
cmp -s "$CFG3_ANTES" "$V3/.git/config" || {
  echo "FAIL [3]: vítima contaminada depois de rodar a cópia REAL de tests/run-all.sh despachando um gate sintético vulnerável"
  tail -20 "$T/out3.log"
  exit 1
}
echo "OK [3]"

echo "[4] mutação — cópia de tests/run-all.sh sem o preâmbulo permite a bancada contaminar a vítima; cópia pristina protege (recontrole)"
cen
B4="$T/bancada4"
mkdir -p "$B4/tests" "$B4/template/.forge/scripts/lib"
cp "$WS/tests/run-all.sh" "$B4/tests/run-all.sh"
[ "$(sha_de "$WS/tests/run-all.sh")" = "$(sha_de "$B4/tests/run-all.sh")" ] || { echo "FAIL [4]: a cópia pristina de tests/run-all.sh na bancada 4 não é idêntica ao original"; exit 1; }
cp "$B3/template/.forge/scripts/lib/arvore-rastreada.sh" "$B4/template/.forge/scripts/lib/arvore-rastreada.sh"
cp "$B3/tests/synthetic-vuln-gate.sh" "$B4/tests/synthetic-vuln-gate.sh"
chmod +x "$B4/tests/run-all.sh" "$B4/tests/synthetic-vuln-gate.sh"

perl -pi -e 's/^unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY\n$//' "$B4/tests/run-all.sh"
grep -q "unset GIT_DIR" "$B4/tests/run-all.sh" && { echo "FAIL [4]: a mutação não removeu a linha do preâmbulo de tests/run-all.sh na bancada 4"; exit 1; }

V4="$(vitima v4)"
CFG4_ANTES="$T/v4-config-antes"
cp "$V4/.git/config" "$CFG4_ANTES"
( cd "$B4" && export GIT_DIR="$V4/.git" && bash "$B4/tests/run-all.sh" ) >"$T/out4.log" 2>&1
cmp -s "$CFG4_ANTES" "$V4/.git/config" && { echo "FAIL [4]: a cópia MUTADA (sem o preâmbulo) deveria contaminar a vítima e não contaminou — o cenário [3] não pegaria a ausência da correção no runner"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V4B="$(vitima v4b)"
CFG4B_ANTES="$T/v4b-config-antes"
cp "$V4B/.git/config" "$CFG4B_ANTES"
( cd "$B3" && export GIT_DIR="$V4B/.git" && bash "$B3/tests/run-all.sh" ) >"$T/out4b.log" 2>&1
cmp -s "$CFG4B_ANTES" "$V4B/.git/config" || { echo "FAIL [4]: RECONTROLE — a bancada com a cópia pristina contaminou a vítima; a mutação não foi limpa"; exit 1; }
echo "OK [4]"

echo "[5] template/.forge/scripts/tests/run-all.sh REAL (o runner distribuído a todo consumidor) despachando via --path um teste sintético vulnerável deixa a vítima intacta"
cen
B5="$T/bancada5"
mkdir -p "$B5/runner/template/.forge/scripts/tests" "$B5/runner/template/.forge/scripts/lib" "$B5/alvo"
TPL_ORIG="$WS/template/.forge/scripts/tests/run-all.sh"
cp "$TPL_ORIG" "$B5/runner/template/.forge/scripts/tests/run-all.sh"
[ "$(sha_de "$TPL_ORIG")" = "$(sha_de "$B5/runner/template/.forge/scripts/tests/run-all.sh")" ] || { echo "FAIL [5]: a cópia do runner do template não é idêntica ao original"; exit 1; }
chmod +x "$B5/runner/template/.forge/scripts/tests/run-all.sh"
# mesmo dublê neutro de [3]/[4] — o runner do template usa a MESMA lib (../lib/arvore-rastreada.sh
# relativo ao próprio script), e o que esta bancada mede é o isolamento de GIT_DIR, não a sentinela.
printf '%s\n' '#!/usr/bin/env bash' \
  'arvore_retrato() { echo dublê; return 0; }' \
  'arvore_confere() { return 0; }' \
  > "$B5/runner/template/.forge/scripts/lib/arvore-rastreada.sh"

# teste sintético no padrão que ESTE runner reconhece (*-test.sh, não *-gate.sh): reproduz o mesmo
# padrão vulnerável de [3], `git init` + `git config user.*` sem `-C` e sem `unset`.
{
  echo '#!/usr/bin/env bash'
  echo 'set -euo pipefail'
  echo 'T="$(mktemp -d /tmp/forge-w248-sint.XXXXXX)"'
  echo 'trap '\''rm -rf "$T"'\'' EXIT'
  echo 'cd "$T"'
  echo 'git init -q'
  echo 'git config user.email "t@t"; git config user.name "t"'
  echo 'echo "OK sintético"'
} > "$B5/alvo/synthetic-vuln-test.sh"
chmod +x "$B5/alvo/synthetic-vuln-test.sh"

V5="$(vitima v5)"
CFG5_ANTES="$T/v5-config-antes"
cp "$V5/.git/config" "$CFG5_ANTES"
( export GIT_DIR="$V5/.git"; bash "$B5/runner/template/.forge/scripts/tests/run-all.sh" --path "$B5/alvo" ) >"$T/out5.log" 2>&1
cmp -s "$CFG5_ANTES" "$V5/.git/config" || {
  echo "FAIL [5]: vítima contaminada depois de rodar a cópia REAL de template/.forge/scripts/tests/run-all.sh despachando um teste sintético vulnerável via --path"
  tail -20 "$T/out5.log"
  exit 1
}
echo "OK [5]"

echo "[6] mutação — cópia do runner do template sem o preâmbulo permite a bancada contaminar a vítima; cópia pristina protege (recontrole)"
cen
B6="$T/bancada6"
mkdir -p "$B6/runner/template/.forge/scripts/tests" "$B6/runner/template/.forge/scripts/lib"
cp "$TPL_ORIG" "$B6/runner/template/.forge/scripts/tests/run-all.sh"
[ "$(sha_de "$TPL_ORIG")" = "$(sha_de "$B6/runner/template/.forge/scripts/tests/run-all.sh")" ] || { echo "FAIL [6]: a cópia pristina do runner do template não é idêntica ao original"; exit 1; }
cp "$B5/runner/template/.forge/scripts/lib/arvore-rastreada.sh" "$B6/runner/template/.forge/scripts/lib/arvore-rastreada.sh"
chmod +x "$B6/runner/template/.forge/scripts/tests/run-all.sh"

perl -pi -e 's/^unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY\n$//' "$B6/runner/template/.forge/scripts/tests/run-all.sh"
grep -q "unset GIT_DIR" "$B6/runner/template/.forge/scripts/tests/run-all.sh" && { echo "FAIL [6]: a mutação não removeu a linha do preâmbulo do runner do template na bancada 6"; exit 1; }

V6="$(vitima v6)"
CFG6_ANTES="$T/v6-config-antes"
cp "$V6/.git/config" "$CFG6_ANTES"
( export GIT_DIR="$V6/.git"; bash "$B6/runner/template/.forge/scripts/tests/run-all.sh" --path "$B5/alvo" ) >"$T/out6.log" 2>&1 || true
cmp -s "$CFG6_ANTES" "$V6/.git/config" && { echo "FAIL [6]: a cópia MUTADA (sem o preâmbulo) do runner do template deveria contaminar a vítima e não contaminou — o cenário [5] não pegaria a ausência da correção no runner distribuído"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V6B="$(vitima v6b)"
CFG6B_ANTES="$T/v6b-config-antes"
cp "$V6B/.git/config" "$CFG6B_ANTES"
( export GIT_DIR="$V6B/.git"; bash "$B5/runner/template/.forge/scripts/tests/run-all.sh" --path "$B5/alvo" ) >"$T/out6b.log" 2>&1
cmp -s "$CFG6B_ANTES" "$V6B/.git/config" || { echo "FAIL [6]: RECONTROLE — a bancada com a cópia pristina do runner do template contaminou a vítima; a mutação não foi limpa"; exit 1; }
echo "OK [6]"

echo "[7] w102-capability-packs-gate.sh REAL (amostra do vetor installer/install.sh — não chama git init nenhuma vez) com GIT_DIR herdado deixa a vítima intacta"
cen
V7="$(vitima v7)"
CFG7_ANTES="$T/v7-config-antes"
cp "$V7/.git/config" "$CFG7_ANTES"
( export GIT_DIR="$V7/.git"; bash "$WS/tests/w102-capability-packs-gate.sh" ) >"$T/out7.log" 2>&1
RC7=$?
cmp -s "$CFG7_ANTES" "$V7/.git/config" || {
  echo "FAIL [7]: vítima contaminada — .git/config mudou depois de rodar w102-capability-packs-gate.sh com GIT_DIR herdado"
  diff "$CFG7_ANTES" "$V7/.git/config" 2>&1 || true
  exit 1
}
[ "$RC7" -eq 0 ] || { echo "FAIL [7]: w102-capability-packs-gate.sh saiu rc=$RC7 com GIT_DIR herdado (deveria continuar passando)"; tail -10 "$T/out7.log"; exit 1; }
echo "OK [7]"

echo "[8] sentinela estrutural — todo tests/*.sh do universo do incidente tem o preâmbulo, este próprio gate incluído"
cen
ISENTOS_W248="w130-tasks-graph-gate.sh"
FALTANTES="$(sentinela_confere "$WS/tests" "$ISENTOS_W248")"
[ -z "$FALTANTES" ] || { echo "FAIL [8]: sem o preâmbulo de isolamento:"; echo "$FALTANTES"; exit 1; }
echo "OK [8]"

echo "[9] mutação — cópia de um gate real do universo do cenário [8] sem o preâmbulo faz a sentinela reprovar nomeando o arquivo"
cen
B9="$T/bancada9/tests"
mkdir -p "$B9"
cp "$WS/tests/w102-capability-packs-gate.sh" "$B9/w102-capability-packs-gate.sh"
perl -pi -e 's/^unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY\n$//' "$B9/w102-capability-packs-gate.sh"
grep -q "^unset GIT_DIR" "$B9/w102-capability-packs-gate.sh" && { echo "FAIL [9]: a mutação não removeu o preâmbulo da cópia"; exit 1; }
FALTANTES9="$(sentinela_confere "$B9" "")"
case "$FALTANTES9" in
  *w102-capability-packs-gate.sh*) ;;
  *) echo "FAIL [9]: a sentinela mutada não nomeou o arquivo sem preâmbulo — saída: $FALTANTES9"; exit 1 ;;
esac
echo "OK [9]"

echo "[10] sentinela — contagem de cenários examinados"
cen
[ "$EXAMINADOS" -eq "$DECLARADO" ] || { echo "FAIL [10]: examinados=$EXAMINADOS declarado=$DECLARADO"; exit 1; }
echo "OK [10]"
