#!/usr/bin/env bash
# Gate W248 — isolamento de GIT_DIR/GIT_WORK_TREE/GIT_CONFIG/etc. herdados em gates que criam
# repositório git temporário OU escrevem estado git num alvo sintético (LDG-0201, incidente P1 de
# 2026-09-26, corrigido em três rodadas — a 3ª amplia o preâmbulo e a sentinela).
#
# O DEFEITO. Gates que criam um repositório git sintético em /tmp para testar a própria fixture
# (via `git init` ou `git -C <dir> init`, seguido de `git config user.email`/`user.name` sem
# `--global`) contavam com o diretório de trabalho corrente, ou com `-C`, para resolver QUAL
# repositório os comandos git afetam. Nenhum dos dois protege: o git honra um conjunto de variáveis
# de ambiente com precedência ABSOLUTA sobre `-C` e sobre o diretório corrente. A 1ª/2ª rodada
# isolaram GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE, GIT_COMMON_DIR e GIT_OBJECT_DIRECTORY. Medido
# nesta 3ª rodada (remedição dos achados do orquestrador): GIT_CONFIG, GIT_CONFIG_PARAMETERS e
# GIT_CONFIG_COUNT herdados reproduzem a MESMA classe de incidente — `git -C "$D" config
# user.email t@t` com GIT_CONFIG apontando para a vítima grava a identidade sintética no arquivo
# de config da vítima, não no de "$D" (cenários [12]/[13]). GIT_INDEX_FILE e GIT_COMMON_DIR
# ISOLADOS (sem GIT_DIR) também contaminam sozinhos: `git init` num diretório novo seguido de `git
# add`/`git config` com um desses exportado grava no arquivo apontado pela variável, não no
# repositório recém-criado (cenários [14]-[17]). GIT_WORK_TREE ISOLADO (sem GIT_DIR) foi medido e
# NÃO é explorável sozinho — o git recusa com "fatal: GIT_WORK_TREE ... not allowed without ...
# GIT_DIR" e não toca em nada; por isso não ganhou cenário próprio de "isolado", só continua
# coberto pelos cenários que isolam GIT_DIR (que já o unsetam junto). O preâmbulo agora unseta oito
# variáveis: GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE, GIT_COMMON_DIR, GIT_OBJECT_DIRECTORY,
# GIT_CONFIG, GIT_CONFIG_PARAMETERS e GIT_CONFIG_COUNT.
#
# O mesmo vale para `git -C "$D" config <chave> <valor>` sob GIT_DIR herdado: medido que ele GRAVA
# no repositório de GIT_DIR, não em "$D" — por isso o vetor alcança também gates que nunca chamam
# `git init` diretamente, mas rodam `installer/install.sh` ou `bin/forge.mjs init/update` sobre um
# diretório sintético: essas ferramentas escrevem `core.hooksPath` via `git -C <alvo> config ...`
# (`wireHooksPath` em `bin/forge.mjs`, o mesmo padrão em `installer/install.sh`). Medido nesta 3ª
# rodada: o MESMO vetor alcança `tests/validators.bats` (§19.1, `installer/install.sh --target
# "$H"`), que ficou fora do universo da sentinela porque ela só varria `tests/*.sh` — arquivos
# `.bats` não entravam (cenários [10]/[18]/[19]).
#
# REPRODUÇÃO DO INCIDENTE, medida fora deste gate: com um repositório "vítima" de identidade
# própria e GIT_DIR exportado para ele, `GIT_DIR=<vítima>/.git bash tests/changelog-merge-gate.sh`
# grava `user.email=t@t`/`user.name=t` na vítima, embora o gate nomeie um caminho de /tmp
# totalmente diferente em todas as suas variáveis internas.
#
#   [1] `tests/changelog-merge-gate.sh` REAL com GIT_DIR exportado para uma vítima: o `.git/config`
#       da vítima sai byte-idêntico antes e depois (cmp -s), e o gate continua passando (rc 0)
#   [2] MUTAÇÃO de [1] — cópia de `changelog-merge-gate.sh` sem a linha do preâmbulo contamina a
#       vítima. RECONTROLE: cópia íntegra roda com rc 0 exigido e deixa a vítima intacta
#   [3] `tests/run-all.sh` REAL despachando um gate SINTÉTICO vulnerável, com GIT_DIR exportado:
#       a vítima sai intacta — prova de que o preâmbulo do RUNNER INTERNO protege até um
#       gate-filho sem preâmbulo próprio
#   [4] MUTAÇÃO de [3] — cópia de `tests/run-all.sh` sem o preâmbulo permite a bancada contaminar a
#       vítima. RECONTROLE: cópia pristina protege
#   [5] `template/.forge/scripts/tests/run-all.sh` REAL (runner distribuído a todo consumidor)
#       despachando via `--path` um teste sintético vulnerável, com GIT_DIR exportado: vítima
#       intacta
#   [6] MUTAÇÃO de [5] — cópia do runner do template sem o preâmbulo contamina. RECONTROLE:
#       cópia pristina protege
#   [7] `tests/w102-capability-packs-gate.sh` REAL (amostra do vetor `installer/install.sh` — não
#       chama `git init`) com GIT_DIR herdado: vítima intacta
#   [8] SENTINELA ESTRUTURAL — todo `tests/*.sh` e `tests/*.bats`/`tests/*/*.bats` que casa o
#       padrão léxico do incidente (init/config/clone de git, ou instalador/forge.mjs), ESTE
#       PRÓPRIO GATE incluído, contém a linha do preâmbulo ANTES do primeiro uso não comentado.
#       Universo ampliado na 3ª rodada: (a) inclui `.bats`, não só `.sh`; (b) `git config` sem
#       exigir "user." no mesmo comando (pega `git -C <alvo> config core.hooksPath`); (c) `git
#       clone` (que também honra GIT_DIR). Isentos documentados: `w130-tasks-graph-gate.sh` (o
#       padrão casa dentro de uma STRING de dado de teste, nunca como comando executado) e
#       `w80-suite-gate.sh` (usa `GIT_CONFIG_COUNT=1 ... git config --get gc.auto` como override
#       ad-hoc de UM comando de LEITURA sobre o próprio repositório de desenvolvimento — não cria
#       vítima sintética, não escreve nada, não é instância do incidente)
#   [9] MUTAÇÃO de [8] — cópia de um gate `.sh` real do universo sem o preâmbulo faz a sentinela
#       reprovar nomeando o arquivo, sem recorrer à suíte inteira
#   [10] MUTAÇÃO de [8], variante `.bats` — cópia de `tests/validators.bats` sem o preâmbulo faz a
#       sentinela AMPLIADA reprovar nomeando o arquivo (prova de que o universo agora enxerga
#       arquivos `.bats`, não só o cenário funcional [18]/[19])
#   [11] SENTINELA — POSIÇÃO: uma cópia sintética com a linha do preâmbulo presente mas DESLOCADA
#       para depois de um `git init` é reprovada citando a linha do preâmbulo e a linha do
#       primeiro uso (prova de que a sentinela não aceita mais a linha em qualquer ponto do
#       arquivo, só antes do primeiro uso não comentado)
#   [12] GIT_CONFIG ISOLADO (sem os outros sete) — `changelog-merge-gate.sh` REAL: vítima intacta
#   [13] MUTAÇÃO de [12] — cópia com só "GIT_CONFIG" removido da linha do preâmbulo (as outras sete
#       variáveis continuam unsetadas) contamina a vítima quando só GIT_CONFIG está exportado.
#       RECONTROLE: cópia íntegra protege
#   [14] GIT_INDEX_FILE ISOLADO — `changelog-merge-gate.sh` REAL: o ÍNDICE da vítima (não o
#       config) sai byte-idêntico (cmp -s)
#   [15] MUTAÇÃO de [14] — cópia com só "GIT_INDEX_FILE" removido contamina o índice da vítima.
#       RECONTROLE: cópia íntegra protege
#   [16] GIT_COMMON_DIR ISOLADO — `changelog-merge-gate.sh` REAL: vítima intacta
#   [17] MUTAÇÃO de [16] — cópia com só "GIT_COMMON_DIR" removido contamina a vítima. RECONTROLE:
#       cópia íntegra protege
#   [18] `tests/validators.bats` REAL — `bats -f "19.1"` com GIT_DIR exportado para uma vítima:
#       vítima intacta e o teste continua "ok" (o preâmbulo funcional que cobre o achado HIGH-1)
#   [19] MUTAÇÃO de [18] — cópia de `validators.bats` sem a linha do preâmbulo, rodada com `bats -f
#       "19.1"` e GIT_DIR exportado: contamina a vítima. RECONTROLE: cópia íntegra (mesmo sha256
#       do original) protege
#   [20] SENTINELA — o gate examinou exatamente o número de cenários declarado
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DECLARADO=20
EXAMINADOS=0
cen() { EXAMINADOS=$((EXAMINADOS + 1)); }
PREAMBULO='unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT'

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

# mutar_removendo_linha <arquivo> -> remove a linha INTEIRA do preâmbulo; FALHA o gate se o
# sha256 do arquivo não mudar (prova de que a mutação de fato alterou algo, em vez de confiar num
# grep léxico que uma reformulação equivalente do preâmbulo quebraria em silêncio).
mutar_removendo_linha() {
  local f="$1" antes; antes="$(sha_de "$f")"
  perl -pi -e 's/^\Qunset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT\E\n$//' "$f"
  [ "$(sha_de "$f")" != "$antes" ] || { echo "FAIL: mutar_removendo_linha não alterou $f (sha256 idêntico) — o cenário não testaria nada"; exit 1; }
}

# mutar_removendo_var <arquivo> <VARNAME> -> remove só o token <VARNAME> da linha do preâmbulo
# (as demais variáveis continuam unsetadas). Usa \b\Q...\E\b para não casar substring (ex.:
# remover "GIT_CONFIG" não pode afetar "GIT_CONFIG_PARAMETERS"/"GIT_CONFIG_COUNT" — confirmado por
# medição: "_" é caractere de palavra, então não há fronteira \b entre "GIT_CONFIG" e "_PARAMETERS").
# Passa o nome pela env do PERL (nunca por interpolação do lado direito do shell), para respeitar a
# regra de mutação por perl com aspas simples.
mutar_removendo_var() {
  local f="$1" var="$2" antes; antes="$(sha_de "$f")"
  VARNAME="$var" perl -pi -e 's/\b\Q$ENV{VARNAME}\E\b //' "$f"
  [ "$(sha_de "$f")" != "$antes" ] || { echo "FAIL: mutar_removendo_var não alterou $f removendo $var (sha256 idêntico) — o cenário não testaria nada"; exit 1; }
  grep -qxF "$PREAMBULO" "$f" && { echo "FAIL: mutar_removendo_var($var) não removeu nada de $f — a linha continua idêntica ao preâmbulo íntegro"; exit 1; }
}

# sentinela_universo <basedir> -> lista os *.sh e *.bats (até um nível de subdiretório, cobre
# tests/*.sh, tests/*.bats e tests/snapshot/*.bats) de <basedir> que casam o padrão léxico do
# incidente: criam repositório git (init/clone) OU gravam config (com ou sem "-C", com ou sem
# "user.") OU escrevem estado git num alvo sintético via instalador/forge.mjs.
sentinela_universo() {
  find "$1" -maxdepth 2 \( -name '*.sh' -o -name '*.bats' \) -type f 2>/dev/null | sort -u | while IFS= read -r f; do
    grep -lE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+(init|config|clone)([[:space:]]|$)|forge\.mjs[[:space:]]+(init|update)|installer/install\.sh|bin/forge\.mjs' "$f" 2>/dev/null
  done
}

# primeiro_uso_git <arquivo> -> ecoa o número da primeira linha NÃO comentada que casa o padrão do
# incidente, ou vazio se nenhuma casar. Usado para exigir que a linha do preâmbulo venha ANTES do
# primeiro uso real, não em qualquer ponto do arquivo. (awk do macOS/BSD não suporta \b — o padrão
# evita a extensão GNU e usa fronteira de espaço/fim-de-linha em seu lugar.)
primeiro_uso_git() {
  awk '
    /^[[:space:]]*#/ { next }
    /git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+(init|config|clone)([[:space:]]|$)/ { print NR; exit }
    /forge\.mjs[[:space:]]+(init|update)/ { print NR; exit }
    /installer\/install\.sh/ { print NR; exit }
    /bin\/forge\.mjs/ { print NR; exit }
  ' "$1"
}

# sentinela_confere <basedir> <isentos-por-basename, separados por espaço> -> lista (uma linha por
# arquivo) os arquivos do universo de <basedir> que NÃO têm a linha do preâmbulo, ou que a têm
# DEPOIS do primeiro uso não comentado.
sentinela_confere() {
  local base="$1" isentos="$2" f rel pl ul
  for f in $(sentinela_universo "$base"); do
    rel="$(basename "$f")"
    case " $isentos " in *" $rel "*) continue ;; esac
    # -x: LINHA INTEIRA, nunca substring — o próprio texto do preâmbulo aparece dentro do
    # comentário deste gate e dentro dos comandos perl que o mutam; um match por substring
    # aprovaria um arquivo que só CITA a linha, sem executá-la.
    if ! grep -qxF "$PREAMBULO" "$f"; then
      echo "$f"
      continue
    fi
    pl="$(grep -nxF "$PREAMBULO" "$f" | head -1 | cut -d: -f1)"
    ul="$(primeiro_uso_git "$f")"
    if [ -n "$ul" ] && [ -n "$pl" ] && [ "$pl" -gt "$ul" ]; then
      echo "$f (preâmbulo na linha $pl, depois do primeiro uso git na linha $ul)"
    fi
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
# porque o gate resolve WS por BASH_SOURCE e lê a lib nesse caminho relativo.
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
mutar_removendo_linha "$MUTADA"

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
# DUBLÊ NEUTRO da sentinela de árvore rastreada (LDG-0179): o que esta bancada mede é o isolamento
# de GIT_DIR, não a sentinela, que tem gate próprio (w213).
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

mutar_removendo_linha "$B4/tests/run-all.sh"

V4="$(vitima v4)"
CFG4_ANTES="$T/v4-config-antes"
cp "$V4/.git/config" "$CFG4_ANTES"
( cd "$B4" && export GIT_DIR="$V4/.git" && bash "$B4/tests/run-all.sh" ) >"$T/out4.log" 2>&1 || true
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
printf '%s\n' '#!/usr/bin/env bash' \
  'arvore_retrato() { echo dublê; return 0; }' \
  'arvore_confere() { return 0; }' \
  > "$B5/runner/template/.forge/scripts/lib/arvore-rastreada.sh"

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

mutar_removendo_linha "$B6/runner/template/.forge/scripts/tests/run-all.sh"

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

echo "[8] sentinela estrutural — todo tests/*.sh e tests/*.bats do universo do incidente tem o preâmbulo, antes do primeiro uso, este próprio gate incluído"
cen
ISENTOS_W248="w130-tasks-graph-gate.sh w80-suite-gate.sh"
FALTANTES="$(sentinela_confere "$WS/tests" "$ISENTOS_W248")"
[ -z "$FALTANTES" ] || { echo "FAIL [8]: sem o preâmbulo (ou fora de posição):"; echo "$FALTANTES"; exit 1; }
echo "OK [8]"

echo "[9] mutação — cópia de um gate .sh real do universo do cenário [8] sem o preâmbulo faz a sentinela reprovar nomeando o arquivo"
cen
B9="$T/bancada9/tests"
mkdir -p "$B9"
cp "$WS/tests/w102-capability-packs-gate.sh" "$B9/w102-capability-packs-gate.sh"
mutar_removendo_linha "$B9/w102-capability-packs-gate.sh"
FALTANTES9="$(sentinela_confere "$B9" "")"
case "$FALTANTES9" in
  *w102-capability-packs-gate.sh*) ;;
  *) echo "FAIL [9]: a sentinela mutada não nomeou o arquivo .sh sem preâmbulo — saída: $FALTANTES9"; exit 1 ;;
esac
echo "OK [9]"

echo "[10] mutação — cópia de tests/validators.bats sem o preâmbulo faz a sentinela AMPLIADA (agora enxerga .bats) reprovar nomeando o arquivo"
cen
B10="$T/bancada10/tests"
mkdir -p "$B10"
cp "$WS/tests/validators.bats" "$B10/validators.bats"
mutar_removendo_linha "$B10/validators.bats"
FALTANTES10="$(sentinela_confere "$B10" "")"
case "$FALTANTES10" in
  *validators.bats*) ;;
  *) echo "FAIL [10]: a sentinela ampliada não nomeou validators.bats sem preâmbulo — saída: $FALTANTES10"; exit 1 ;;
esac
echo "OK [10]"

echo "[11] sentinela — posição: preâmbulo presente mas DESLOCADO para depois de um git init é reprovado citando as duas linhas"
cen
B11="$T/bancada11/tests"
mkdir -p "$B11"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '# comentário citando git init, não deve contar como uso' \
  'set -uo pipefail' \
  'D="$(mktemp -d)"' \
  'git -C "$D" init -q' \
  "$PREAMBULO" \
  'echo fim' \
  > "$B11/fora-de-posicao-gate.sh"
FALTANTES11="$(sentinela_confere "$B11" "")"
case "$FALTANTES11" in
  *"fora-de-posicao-gate.sh (preâmbulo na linha"*"depois do primeiro uso git na linha"*) ;;
  *) echo "FAIL [11]: a sentinela não reprovou o preâmbulo fora de posição, ou a mensagem não citou as duas linhas — saída: $FALTANTES11"; exit 1 ;;
esac
echo "OK [11]"

echo "[12] GIT_CONFIG isolado (sem os outros sete) — changelog-merge-gate.sh REAL deixa a vítima intacta"
cen
V12="$(vitima v12)"
CFG12_ANTES="$T/v12-config-antes"
cp "$V12/.git/config" "$CFG12_ANTES"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  export GIT_CONFIG="$V12/.git/config"
  bash "$WS/tests/changelog-merge-gate.sh" ) >"$T/out12.log" 2>&1
RC12=$?
cmp -s "$CFG12_ANTES" "$V12/.git/config" || { echo "FAIL [12]: vítima contaminada com GIT_CONFIG isolado exportado"; diff "$CFG12_ANTES" "$V12/.git/config" 2>&1 || true; exit 1; }
[ "$RC12" -eq 0 ] || { echo "FAIL [12]: changelog-merge-gate.sh saiu rc=$RC12 com GIT_CONFIG isolado"; tail -10 "$T/out12.log"; exit 1; }
echo "OK [12]"

echo "[13] mutação — cópia com só GIT_CONFIG removido do preâmbulo contamina a vítima quando só GIT_CONFIG está exportado; cópia íntegra protege (recontrole)"
cen
COPIA13="$(mkbancada bancada13-pristina)"
MUTADA13="$(mkbancada bancada13-mutada)"
mutar_removendo_var "$MUTADA13" GIT_CONFIG

V13="$(vitima v13)"
CFG13_ANTES="$T/v13-config-antes"
cp "$V13/.git/config" "$CFG13_ANTES"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  export GIT_CONFIG="$V13/.git/config"
  bash "$MUTADA13" ) >/dev/null 2>&1 || true
cmp -s "$CFG13_ANTES" "$V13/.git/config" && { echo "FAIL [13]: a cópia sem GIT_CONFIG no preâmbulo deveria contaminar a vítima e não contaminou"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V13B="$(vitima v13b)"
CFG13B_ANTES="$T/v13b-config-antes"
cp "$V13B/.git/config" "$CFG13B_ANTES"
OUT13B="$T/out13b.log"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  export GIT_CONFIG="$V13B/.git/config"
  bash "$COPIA13" ) >"$OUT13B" 2>&1
RC13B=$?
[ "$RC13B" -eq 0 ] || { echo "FAIL [13]: RECONTROLE — a cópia íntegra saiu rc=$RC13B em vez de 0"; tail -10 "$OUT13B"; exit 1; }
cmp -s "$CFG13B_ANTES" "$V13B/.git/config" || { echo "FAIL [13]: RECONTROLE — a cópia íntegra contaminou a vítima com GIT_CONFIG isolado"; exit 1; }
echo "OK [13]"

echo "[14] GIT_INDEX_FILE isolado — changelog-merge-gate.sh REAL deixa o ÍNDICE da vítima intacto"
cen
V14="$(vitima v14)"
echo conteudo > "$V14/f.txt"
git -C "$V14" add f.txt
git -C "$V14" -c user.email=vitima-v14@vitima.example -c user.name=vitima-v14 commit -qm init >/dev/null
IDX14_ANTES="$T/v14-index-antes"
cp "$V14/.git/index" "$IDX14_ANTES"
( unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
  export GIT_INDEX_FILE="$V14/.git/index"
  bash "$WS/tests/changelog-merge-gate.sh" ) >"$T/out14.log" 2>&1
RC14=$?
cmp -s "$IDX14_ANTES" "$V14/.git/index" || { echo "FAIL [14]: índice da vítima contaminado com GIT_INDEX_FILE isolado exportado"; exit 1; }
[ "$RC14" -eq 0 ] || { echo "FAIL [14]: changelog-merge-gate.sh saiu rc=$RC14 com GIT_INDEX_FILE isolado"; tail -10 "$T/out14.log"; exit 1; }
echo "OK [14]"

echo "[15] mutação — cópia com só GIT_INDEX_FILE removido do preâmbulo contamina o índice da vítima; cópia íntegra protege (recontrole)"
cen
COPIA15="$(mkbancada bancada15-pristina)"
MUTADA15="$(mkbancada bancada15-mutada)"
mutar_removendo_var "$MUTADA15" GIT_INDEX_FILE

V15="$(vitima v15)"
echo conteudo > "$V15/f.txt"
git -C "$V15" add f.txt
git -C "$V15" -c user.email=vitima-v15@vitima.example -c user.name=vitima-v15 commit -qm init >/dev/null
IDX15_ANTES="$T/v15-index-antes"
cp "$V15/.git/index" "$IDX15_ANTES"
( unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
  export GIT_INDEX_FILE="$V15/.git/index"
  bash "$MUTADA15" ) >/dev/null 2>&1 || true
cmp -s "$IDX15_ANTES" "$V15/.git/index" && { echo "FAIL [15]: a cópia sem GIT_INDEX_FILE no preâmbulo deveria contaminar o índice e não contaminou"; exit 1; }
echo "  OK — mutação contamina o índice da vítima, como esperado"

V15B="$(vitima v15b)"
echo conteudo > "$V15B/f.txt"
git -C "$V15B" add f.txt
git -C "$V15B" -c user.email=vitima-v15b@vitima.example -c user.name=vitima-v15b commit -qm init >/dev/null
IDX15B_ANTES="$T/v15b-index-antes"
cp "$V15B/.git/index" "$IDX15B_ANTES"
OUT15B="$T/out15b.log"
( unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
  export GIT_INDEX_FILE="$V15B/.git/index"
  bash "$COPIA15" ) >"$OUT15B" 2>&1
RC15B=$?
[ "$RC15B" -eq 0 ] || { echo "FAIL [15]: RECONTROLE — a cópia íntegra saiu rc=$RC15B em vez de 0"; tail -10 "$OUT15B"; exit 1; }
cmp -s "$IDX15B_ANTES" "$V15B/.git/index" || { echo "FAIL [15]: RECONTROLE — a cópia íntegra contaminou o índice da vítima com GIT_INDEX_FILE isolado"; exit 1; }
echo "OK [15]"

echo "[16] GIT_COMMON_DIR isolado — changelog-merge-gate.sh REAL deixa a vítima intacta"
cen
V16="$(vitima v16)"
CFG16_ANTES="$T/v16-config-antes"
cp "$V16/.git/config" "$CFG16_ANTES"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
  export GIT_COMMON_DIR="$V16/.git"
  bash "$WS/tests/changelog-merge-gate.sh" ) >"$T/out16.log" 2>&1
RC16=$?
cmp -s "$CFG16_ANTES" "$V16/.git/config" || { echo "FAIL [16]: vítima contaminada com GIT_COMMON_DIR isolado exportado"; diff "$CFG16_ANTES" "$V16/.git/config" 2>&1 || true; exit 1; }
[ "$RC16" -eq 0 ] || { echo "FAIL [16]: changelog-merge-gate.sh saiu rc=$RC16 com GIT_COMMON_DIR isolado"; tail -10 "$T/out16.log"; exit 1; }
echo "OK [16]"

echo "[17] mutação — cópia com só GIT_COMMON_DIR removido do preâmbulo contamina a vítima; cópia íntegra protege (recontrole)"
cen
COPIA17="$(mkbancada bancada17-pristina)"
MUTADA17="$(mkbancada bancada17-mutada)"
mutar_removendo_var "$MUTADA17" GIT_COMMON_DIR

V17="$(vitima v17)"
CFG17_ANTES="$T/v17-config-antes"
cp "$V17/.git/config" "$CFG17_ANTES"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
  export GIT_COMMON_DIR="$V17/.git"
  bash "$MUTADA17" ) >/dev/null 2>&1 || true
cmp -s "$CFG17_ANTES" "$V17/.git/config" && { echo "FAIL [17]: a cópia sem GIT_COMMON_DIR no preâmbulo deveria contaminar a vítima e não contaminou"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V17B="$(vitima v17b)"
CFG17B_ANTES="$T/v17b-config-antes"
cp "$V17B/.git/config" "$CFG17B_ANTES"
OUT17B="$T/out17b.log"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
  export GIT_COMMON_DIR="$V17B/.git"
  bash "$COPIA17" ) >"$OUT17B" 2>&1
RC17B=$?
[ "$RC17B" -eq 0 ] || { echo "FAIL [17]: RECONTROLE — a cópia íntegra saiu rc=$RC17B em vez de 0"; tail -10 "$OUT17B"; exit 1; }
cmp -s "$CFG17B_ANTES" "$V17B/.git/config" || { echo "FAIL [17]: RECONTROLE — a cópia íntegra contaminou a vítima com GIT_COMMON_DIR isolado"; exit 1; }
echo "OK [17]"

echo "[18] tests/validators.bats REAL — bats -f '19.1' com GIT_DIR herdado deixa a vítima intacta"
cen
if ! command -v bats >/dev/null 2>&1; then
  echo "FAIL [18]: bats não está instalado neste ambiente — não há como exercitar o cenário funcional do achado HIGH-1"
  exit 1
fi
V18="$(vitima v18)"
CFG18_ANTES="$T/v18-config-antes"
cp "$V18/.git/config" "$CFG18_ANTES"
OUT18="$T/out18.log"
( export GIT_DIR="$V18/.git"; bats -f "19.1" "$WS/tests/validators.bats" ) >"$OUT18" 2>&1
RC18=$?
cmp -s "$CFG18_ANTES" "$V18/.git/config" || {
  echo "FAIL [18]: vítima contaminada depois de bats -f '19.1' tests/validators.bats com GIT_DIR herdado"
  diff "$CFG18_ANTES" "$V18/.git/config" 2>&1 || true
  exit 1
}
[ "$RC18" -eq 0 ] || { echo "FAIL [18]: bats -f '19.1' validators.bats saiu rc=$RC18 com GIT_DIR herdado (deveria continuar passando)"; tail -20 "$OUT18"; exit 1; }
grep -q "^ok 1 " "$OUT18" || { echo "FAIL [18]: a saída do bats não confirma \"ok 1\" — pode ter passado por motivo errado"; tail -20 "$OUT18"; exit 1; }
echo "OK [18]"

echo "[19] mutação — cópia de validators.bats sem o preâmbulo, rodada com bats -f '19.1' e GIT_DIR herdado, contamina a vítima; cópia íntegra protege (recontrole)"
cen
if ! command -v bats >/dev/null 2>&1; then
  echo "FAIL [19]: bats não está instalado neste ambiente"
  exit 1
fi
BATS_ORIG="$WS/tests/validators.bats"
SHA_BATS_ORIG="$(sha_de "$BATS_ORIG")"
# §19.1 resolve `$WS/installer/install.sh` a partir de BATS_TEST_DIRNAME/.. — a cópia precisa da
# MESMA estrutura relativa (installer/ e template/ ao lado de tests/), senão o teste erraria por
# "installer/install.sh: no such file" antes de chegar perto de gravar qualquer coisa, e o cenário
# não provaria nada (mesma lição de mkbancada() para changelog-merge-gate.sh, aplicada ao vetor
# install.sh).
mkbancada_bats() { # mkbancada_bats <nome> -> ecoa o caminho da cópia de validators.bats na bancada
  local b="$T/$1"
  mkdir -p "$b/tests"
  cp -R "$WS/installer" "$b/installer"
  cp -R "$WS/template" "$b/template"
  cp "$BATS_ORIG" "$b/tests/validators.bats"
  echo "$b/tests/validators.bats"
}

COPIA19="$(mkbancada_bats bancada19-pristina)"
[ "$(sha_de "$COPIA19")" = "$SHA_BATS_ORIG" ] || { echo "FAIL [19]: a cópia pristina de validators.bats não é idêntica ao original"; exit 1; }
MUTADA19="$(mkbancada_bats bancada19-mutada)"
mutar_removendo_linha "$MUTADA19"

V19="$(vitima v19)"
CFG19_ANTES="$T/v19-config-antes"
cp "$V19/.git/config" "$CFG19_ANTES"
( export GIT_DIR="$V19/.git"; bats -f "19.1" "$MUTADA19" ) >/dev/null 2>&1 || true
cmp -s "$CFG19_ANTES" "$V19/.git/config" && { echo "FAIL [19]: a cópia MUTADA (sem o preâmbulo) de validators.bats deveria contaminar a vítima e não contaminou — o cenário [18] não pegaria a ausência da correção"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V19B="$(vitima v19b)"
CFG19B_ANTES="$T/v19b-config-antes"
cp "$V19B/.git/config" "$CFG19B_ANTES"
OUT19B="$T/out19b.log"
( export GIT_DIR="$V19B/.git"; bats -f "19.1" "$COPIA19" ) >"$OUT19B" 2>&1
RC19B=$?
[ "$RC19B" -eq 0 ] || { echo "FAIL [19]: RECONTROLE — a cópia íntegra de validators.bats saiu rc=$RC19B em vez de 0"; tail -20 "$OUT19B"; exit 1; }
cmp -s "$CFG19B_ANTES" "$V19B/.git/config" || { echo "FAIL [19]: RECONTROLE — a cópia íntegra (mesmo sha256 do original) contaminou a vítima; a mutação não foi limpa"; exit 1; }
echo "OK [19]"

echo "[20] sentinela — contagem de cenários examinados"
cen
[ "$EXAMINADOS" -eq "$DECLARADO" ] || { echo "FAIL [20]: examinados=$EXAMINADOS declarado=$DECLARADO"; exit 1; }
echo "OK [20]"
