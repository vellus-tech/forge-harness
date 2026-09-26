#!/usr/bin/env bash
# Gate W248 — isolamento de GIT_DIR/GIT_WORK_TREE/GIT_CONFIG/etc. herdados em gates que criam
# repositório git temporário OU escrevem estado git num alvo sintético (LDG-0201, incidente P1 de
# 2026-09-26, corrigido em quatro rodadas).
#
# O DEFEITO. Gates que criam um repositório git sintético em /tmp para testar a própria fixture
# (via `git init` ou `git -C <dir> init`, seguido de `git config user.email`/`user.name` sem
# `--global`) contavam com o diretório de trabalho corrente, ou com `-C`, para resolver QUAL
# repositório os comandos git afetam. Nenhum dos dois protege: o git honra um conjunto de variáveis
# de ambiente com precedência ABSOLUTA sobre `-C` e sobre o diretório corrente. Vetores MEDIDOS de
# redirecionamento de ESCRITA: GIT_DIR (config, índice, objetos, refs), GIT_CONFIG (`git -C "$D"
# config user.email t@t` grava no arquivo apontado, cenários [12]/[13]), GIT_INDEX_FILE e
# GIT_COMMON_DIR isolados, sem GIT_DIR (cenários [14]-[17]), e GIT_OBJECT_DIRECTORY isolado (um
# `git add`/`git commit` num repositório recém-criado grava os objetos no diretório apontado —
# medido na bancada da 4ª rodada, visível só porque o oráculo passou a fotografar a `.git` inteira).
# GIT_WORK_TREE ISOLADO (sem GIT_DIR) foi medido e NÃO é explorável sozinho — o git recusa com
# "fatal: GIT_WORK_TREE ... not allowed without ... GIT_DIR" e não toca em nada; continua no
# preâmbulo porque acompanha GIT_DIR. O preâmbulo unseta SEIS variáveis: GIT_DIR, GIT_WORK_TREE,
# GIT_INDEX_FILE, GIT_COMMON_DIR, GIT_OBJECT_DIRECTORY e GIT_CONFIG.
#
# O QUE O PREÂMBULO NÃO UNSETA, E POR QUÊ (4ª rodada). GIT_CONFIG_COUNT e GIT_CONFIG_PARAMETERS
# NÃO redirecionam escrita — medido: com cada uma exportada, `git init` + `git config user.email` +
# `git commit` num diretório novo gravam no repositório novo, e a vítima sai byte-idêntica. E as
# duas têm uso LEGÍTIMO que o unset destruía: `tests/run-all.sh` desliga `gc.auto`,
# `maintenance.auto` e `gc.autoDetach` em todo fixture via GIT_CONFIG_COUNT=3 (motivo em w80 [7]:
# o gc em background reprovava o w106 no CI Linux com todas as asserções verdes), e o unset de
# GIT_CONFIG_COUNT em cada gate anulava essa proteção silenciosamente (cenário [20]); e todo
# `git -c chave=valor` do usuário chega aos processos-filhos via GIT_CONFIG_PARAMETERS, que o
# runner do template descartava (cenário [21]).
#
# O mesmo vale para `git -C "$D" config <chave> <valor>` sob GIT_DIR herdado: medido que ele GRAVA
# no repositório de GIT_DIR, não em "$D" — por isso o vetor alcança também gates que nunca chamam
# `git init` diretamente, mas rodam `installer/install.sh` ou `bin/forge.mjs init/update` sobre um
# diretório sintético: essas ferramentas escrevem `core.hooksPath` via `git -C <alvo> config ...`
# (`wireHooksPath` em `bin/forge.mjs`, o mesmo padrão em `installer/install.sh`). O mesmo vetor
# alcança `tests/validators.bats` (§19.1, `installer/install.sh --target "$H"`), por isso a
# sentinela varre `.bats` além de `.sh` (cenários [10]/[18]/[19]).
#
# O ORÁCULO. Toda comparação de vítima é uma FOTOGRAFIA da `.git` inteira — sha256 de todo arquivo
# sob `.git`, ordenado —, nunca de um arquivo só: comparar só `.git/config` (ou só `.git/index`)
# deixava passar uma contaminação por objetos, refs ou HEAD. A fotografia confere que o número de
# linhas é igual ao número de arquivos contado por outro meio, para que uma foto vazia não seja
# lida como "vítima intacta".
#
#   [1] `tests/changelog-merge-gate.sh` REAL com GIT_DIR exportado para uma vítima: a vítima sai
#       byte-idêntica antes e depois (fotografia da `.git`), e o gate continua passando (rc 0)
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
#       padrão léxico do incidente (init/config/clone de git, com QUALQUER sequência de opções
#       globais entre `git` e o subcomando — `-C`, `-c`, `--git-dir=`, `--bare` etc. —, ou
#       instalador/forge.mjs), ESTE PRÓPRIO GATE incluído, contém a linha do preâmbulo ANTES do
#       primeiro uso não comentado. Isentos documentados: `w130-tasks-graph-gate.sh` (o padrão
#       casa dentro de uma STRING de dado de teste, nunca como comando executado) e
#       `w80-suite-gate.sh` (usa `GIT_CONFIG_COUNT=1 ... git config --get gc.auto` como override
#       ad-hoc de UM comando de LEITURA sobre o próprio repositório de desenvolvimento — não cria
#       vítima sintética, não escreve nada, não é instância do incidente)
#   [9] MUTAÇÃO de [8] — cópia de um gate `.sh` real do universo sem o preâmbulo faz a sentinela
#       reprovar nomeando o arquivo, sem recorrer à suíte inteira
#   [10] MUTAÇÃO de [8], variante `.bats` — cópia de `tests/validators.bats` sem o preâmbulo faz a
#       sentinela reprovar nomeando o arquivo
#   [11] SENTINELA — POSIÇÃO: uma cópia sintética com a linha do preâmbulo presente mas DESLOCADA
#       para depois de um `git init` é reprovada citando a linha do preâmbulo e a linha do
#       primeiro uso
#   [12] GIT_CONFIG ISOLADO (sem os outros cinco) — `changelog-merge-gate.sh` REAL: vítima intacta
#   [13] MUTAÇÃO de [12] — cópia com só "GIT_CONFIG" removido da linha do preâmbulo (as outras cinco
#       variáveis continuam unsetadas) contamina a vítima quando só GIT_CONFIG está exportado.
#       RECONTROLE: cópia íntegra protege
#   [14] GIT_INDEX_FILE ISOLADO — `changelog-merge-gate.sh` REAL: vítima intacta
#   [15] MUTAÇÃO de [14] — cópia com só "GIT_INDEX_FILE" removido contamina a vítima (o índice).
#       RECONTROLE: cópia íntegra protege
#   [16] GIT_COMMON_DIR ISOLADO — `changelog-merge-gate.sh` REAL: vítima intacta
#   [17] MUTAÇÃO de [16] — cópia com só "GIT_COMMON_DIR" removido contamina a vítima. RECONTROLE:
#       cópia íntegra protege
#   [18] `tests/validators.bats` REAL — `bats -f "19.1"` com GIT_DIR exportado para uma vítima:
#       vítima intacta e o teste continua "ok"
#   [19] MUTAÇÃO de [18] — cópia de `validators.bats` sem a linha do preâmbulo, rodada com `bats -f
#       "19.1"` e GIT_DIR exportado: contamina a vítima. RECONTROLE: cópia íntegra (mesmo sha256
#       do original) protege
#   [20] PROTEÇÃO CONTRA GC PRESERVADA — um gate COM o preâmbulo exato, despachado por uma cópia
#       sha256-idêntica de `tests/run-all.sh`, lê `git config --get gc.auto` = 0. MUTAÇÃO: o mesmo
#       gate com GIT_CONFIG_COUNT reintroduzido no unset do preâmbulo NÃO lê 0. RECONTROLE: o gate
#       pristino volta a ler 0
#   [21] `git -c` DO USUÁRIO CHEGA AO TESTE — `git -c forge.sondaw248=chegou` invocando, por alias
#       de shell do próprio git, uma cópia sha256-idêntica do runner do template com um teste que
#       tem o preâmbulo: o teste lê "chegou". MUTAÇÃO: cópia do runner com GIT_CONFIG_PARAMETERS
#       reintroduzido no unset — o teste NÃO lê "chegou". RECONTROLE: runner pristino entrega
#   [22] SENTINELA COM ESPAÇO NO CAMINHO — bancada em "…/bancada com espaço/tests": cópia íntegra
#       de um gate real não é reprovada (controle); cópia mutada com espaço no próprio nome é
#       reprovada com o CAMINHO COMPLETO numa linha só; removida a mutada, a saída volta a vazia
#       (recontrole)
#   [23] SENTINELA COM OPÇÕES GLOBAIS — `git -c k=v init` com o preâmbulo no topo não é reprovado
#       (controle); a MUTAÇÃO do mesmo arquivo sem o preâmbulo é reprovada; `git --git-dir=… init` e
#       `git -C a -c b=c config` sem preâmbulo também são reprovados; `git -c k=v init` ANTES do
#       preâmbulo é reprovado por posição; um arquivo sem uso git não entra no universo; o
#       pristino continua aprovado depois de tudo (recontrole)
#   [24] SENTINELA — o gate examinou exatamente o número de cenários declarado
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DECLARADO=24
EXAMINADOS=0
cen() { EXAMINADOS=$((EXAMINADOS + 1)); }
PREAMBULO='unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG'

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

# foto <repo> <saída> -> sha256 de TODO arquivo sob <repo>/.git (config, HEAD, índice, refs,
# objetos, hooks), ordenado. Guarda de instrumento: o número de linhas da foto tem de bater com o
# número de arquivos contado por outro meio (`find | wc -l`), e nenhum dos dois pode ser zero —
# uma foto vazia compararia igual a outra foto vazia e aprovaria qualquer contaminação.
foto() {
  local r="$1" out="$2" n linhas
  ( cd "$r/.git" && find . -type f -exec shasum -a 256 {} + | LC_ALL=C sort ) >"$out"
  n="$(find "$r/.git" -type f | wc -l | tr -d ' ')"
  linhas="$(wc -l <"$out" | tr -d ' ')"
  if [ "$n" -eq 0 ] || [ "$linhas" != "$n" ]; then
    echo "FAIL: instrumento quebrado — foto de $r tem $linhas linha(s) para $n arquivo(s)"
    exit 1
  fi
}
foto_antes() { foto "$1" "$1.foto-antes"; }
# vitima_intacta <repo> -> rc 0 se a .git inteira é byte-idêntica à foto_antes
vitima_intacta() { foto "$1" "$1.foto-depois"; cmp -s "$1.foto-antes" "$1.foto-depois"; }
difere() { diff "$1.foto-antes" "$1.foto-depois" 2>&1 | head -20 || true; }

# mutar_removendo_linha <arquivo> -> remove a linha INTEIRA do preâmbulo; FALHA o gate se o
# sha256 do arquivo não mudar (prova de que a mutação de fato alterou algo, em vez de confiar num
# grep léxico que uma reformulação equivalente do preâmbulo quebraria em silêncio).
mutar_removendo_linha() {
  local f="$1" antes; antes="$(sha_de "$f")"
  LINHA="$PREAMBULO" perl -pi -e 's/^\Q$ENV{LINHA}\E\n$//' "$f"
  [ "$(sha_de "$f")" != "$antes" ] || { echo "FAIL: mutar_removendo_linha não alterou $f (sha256 idêntico) — o cenário não testaria nada"; exit 1; }
}

# mutar_removendo_var <arquivo> <VARNAME> -> remove só o token <VARNAME> da linha do preâmbulo
# (as demais variáveis continuam unsetadas). Ancora no início da linha do preâmbulo e usa
# (?=\s|$) depois do nome, para não casar prefixo de outro nome.
mutar_removendo_var() {
  local f="$1" var="$2" antes; antes="$(sha_de "$f")"
  VARNAME="$var" perl -pi -e 's/^(unset GIT_DIR.*?) \Q$ENV{VARNAME}\E(?=\s|$)/$1/' "$f"
  [ "$(sha_de "$f")" != "$antes" ] || { echo "FAIL: mutar_removendo_var não alterou $f removendo $var (sha256 idêntico) — o cenário não testaria nada"; exit 1; }
  grep -qxF "$PREAMBULO" "$f" && { echo "FAIL: mutar_removendo_var($var) não removeu nada de $f — a linha continua idêntica ao preâmbulo íntegro"; exit 1; }
}

# mutar_acrescentando_var <arquivo> <VARNAME> -> REINTRODUZ <VARNAME> no fim da linha do preâmbulo
# (a regressão que a 4ª rodada desfez). Confere sha256 e a linha resultante exata.
mutar_acrescentando_var() {
  local f="$1" var="$2" antes; antes="$(sha_de "$f")"
  LINHA="$PREAMBULO" VARNAME="$var" perl -pi -e 's/^\Q$ENV{LINHA}\E$/$ENV{LINHA} $ENV{VARNAME}/' "$f"
  [ "$(sha_de "$f")" != "$antes" ] || { echo "FAIL: mutar_acrescentando_var não alterou $f acrescentando $var (sha256 idêntico) — o cenário não testaria nada"; exit 1; }
  grep -qxF "$PREAMBULO $var" "$f" || { echo "FAIL: mutar_acrescentando_var($var) não produziu a linha esperada em $f"; exit 1; }
}

# Padrão léxico do incidente, UMA definição para o grep (universo) e para o awk (posição). Entre
# `git` e o subcomando aceita qualquer sequência de opções globais: `-C <dir>`, `-c <k=v>`,
# `--git-dir <x>`/`--work-tree <x>` (e as demais que tomam argumento separado), `--opcao[=valor]`
# e opção curta isolada. Sem barra invertida — `[.]` no lugar de `\.` — porque `awk -v` processa
# escapes da string e o padrão chegaria alterado.
PADRAO='git([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace|exec-path|super-prefix|config-env)[[:space:]]+[^[:space:]]+|--[a-z][a-z-]*(=[^[:space:]]+)?|-[a-zA-Z]))*[[:space:]]+(init|config|clone)([[:space:]]|$)|forge[.]mjs[[:space:]]+(init|update)|installer/install[.]sh|bin/forge[.]mjs'

# sentinela_universo <basedir> -> lista os *.sh e *.bats (até um nível de subdiretório, cobre
# tests/*.sh, tests/*.bats e tests/snapshot/*.bats) de <basedir> que casam o padrão do incidente.
sentinela_universo() {
  find "$1" -maxdepth 2 \( -name '*.sh' -o -name '*.bats' \) -type f 2>/dev/null | LC_ALL=C sort -u | while IFS= read -r f; do
    grep -qE "$PADRAO" "$f" 2>/dev/null && printf '%s\n' "$f"
  done
}

# primeiro_uso_git <arquivo> -> ecoa o número da primeira linha NÃO comentada que casa o padrão do
# incidente, ou vazio se nenhuma casar. Exige que a linha do preâmbulo venha ANTES do primeiro uso
# real, não em qualquer ponto do arquivo.
primeiro_uso_git() {
  awk -v re="$PADRAO" '
    /^[[:space:]]*#/ { next }
    $0 ~ re { print NR; exit }
  ' "$1"
}

# sentinela_confere <basedir> <isentos-por-basename, separados por espaço> -> lista (uma linha por
# arquivo) os arquivos do universo de <basedir> que NÃO têm a linha do preâmbulo, ou que a têm
# DEPOIS do primeiro uso não comentado. Laço por `while read` sobre substituição de processo, e
# NÃO `for f in $(...)`: a divisão por palavra quebraria um caminho com espaço em fragmentos, cada
# um reportado como "sem preâmbulo" (cenário [22]).
sentinela_confere() {
  local base="$1" isentos="$2" f rel pl ul
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="$(basename "$f")"
    case " $isentos " in *" $rel "*) continue ;; esac
    # -x: LINHA INTEIRA, nunca substring — o próprio texto do preâmbulo aparece dentro do
    # comentário deste gate; um match por substring aprovaria um arquivo que só CITA a linha.
    if ! grep -qxF "$PREAMBULO" "$f"; then
      printf '%s\n' "$f"
      continue
    fi
    pl="$(grep -nxF "$PREAMBULO" "$f" | head -1 | cut -d: -f1)"
    ul="$(primeiro_uso_git "$f")"
    if [ -n "$ul" ] && [ -n "$pl" ] && [ "$pl" -gt "$ul" ]; then
      printf '%s\n' "$f (preâmbulo na linha $pl, depois do primeiro uso git na linha $ul)"
    fi
  done < <(sentinela_universo "$base")
}

# dublê neutro da sentinela de árvore rastreada (LDG-0179) para as bancadas de runner: o que elas
# medem é o isolamento git, não a sentinela, que tem gate próprio (w213).
duble_arvore() {
  printf '%s\n' '#!/usr/bin/env bash' \
    'arvore_retrato() { echo dublê; return 0; }' \
    'arvore_confere() { return 0; }' \
    > "$1"
}

echo "[1] changelog-merge-gate.sh REAL com GIT_DIR herdado deixa a vítima intacta"
cen
V1="$(vitima v1)"
foto_antes "$V1"
( export GIT_DIR="$V1/.git"; bash "$WS/tests/changelog-merge-gate.sh" ) >"$T/out1.log" 2>&1
RC1=$?
vitima_intacta "$V1" || {
  echo "FAIL [1]: vítima contaminada — a .git mudou depois de rodar changelog-merge-gate.sh com GIT_DIR herdado"
  difere "$V1"
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
foto_antes "$V2"
( export GIT_DIR="$V2/.git"; bash "$MUTADA" ) >/dev/null 2>&1 || true
vitima_intacta "$V2" && { echo "FAIL [2]: a cópia MUTADA (sem o preâmbulo) deveria contaminar a vítima e não contaminou — o cenário [1] não pegaria a ausência da correção"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V2B="$(vitima v2b)"
foto_antes "$V2B"
OUT2B="$T/out2b.log"
( export GIT_DIR="$V2B/.git"; bash "$COPIA" ) >"$OUT2B" 2>&1
RC2B=$?
[ "$RC2B" -eq 0 ] || { echo "FAIL [2]: RECONTROLE — a cópia ÍNTEGRA saiu rc=$RC2B em vez de 0 (um recontrole que aborta antes de tocar git aprovaria sem ter exercitado nada)"; tail -10 "$OUT2B"; exit 1; }
vitima_intacta "$V2B" || { echo "FAIL [2]: RECONTROLE — a cópia ÍNTEGRA (mesmo sha256 do original) contaminou a vítima; a mutação não foi limpa"; difere "$V2B"; exit 1; }
echo "OK [2]"

echo "[3] tests/run-all.sh REAL despachando um gate sintético vulnerável deixa a vítima intacta"
cen
B3="$T/bancada3"
mkdir -p "$B3/tests" "$B3/template/.forge/scripts/lib"
cp "$WS/tests/run-all.sh" "$B3/tests/run-all.sh"
[ "$(sha_de "$WS/tests/run-all.sh")" = "$(sha_de "$B3/tests/run-all.sh")" ] || { echo "FAIL [3]: a cópia de tests/run-all.sh na bancada não é idêntica ao original"; exit 1; }
chmod +x "$B3/tests/run-all.sh"
duble_arvore "$B3/template/.forge/scripts/lib/arvore-rastreada.sh"

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
foto_antes "$V3"
( cd "$B3" && export GIT_DIR="$V3/.git" && bash "$B3/tests/run-all.sh" ) >"$T/out3.log" 2>&1
vitima_intacta "$V3" || {
  echo "FAIL [3]: vítima contaminada depois de rodar a cópia REAL de tests/run-all.sh despachando um gate sintético vulnerável"
  difere "$V3"
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
foto_antes "$V4"
( cd "$B4" && export GIT_DIR="$V4/.git" && bash "$B4/tests/run-all.sh" ) >"$T/out4.log" 2>&1 || true
vitima_intacta "$V4" && { echo "FAIL [4]: a cópia MUTADA (sem o preâmbulo) deveria contaminar a vítima e não contaminou — o cenário [3] não pegaria a ausência da correção no runner"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V4B="$(vitima v4b)"
foto_antes "$V4B"
( cd "$B3" && export GIT_DIR="$V4B/.git" && bash "$B3/tests/run-all.sh" ) >"$T/out4b.log" 2>&1
vitima_intacta "$V4B" || { echo "FAIL [4]: RECONTROLE — a bancada com a cópia pristina contaminou a vítima; a mutação não foi limpa"; difere "$V4B"; exit 1; }
echo "OK [4]"

echo "[5] template/.forge/scripts/tests/run-all.sh REAL (o runner distribuído a todo consumidor) despachando via --path um teste sintético vulnerável deixa a vítima intacta"
cen
B5="$T/bancada5"
mkdir -p "$B5/runner/template/.forge/scripts/tests" "$B5/runner/template/.forge/scripts/lib" "$B5/alvo"
TPL_ORIG="$WS/template/.forge/scripts/tests/run-all.sh"
cp "$TPL_ORIG" "$B5/runner/template/.forge/scripts/tests/run-all.sh"
[ "$(sha_de "$TPL_ORIG")" = "$(sha_de "$B5/runner/template/.forge/scripts/tests/run-all.sh")" ] || { echo "FAIL [5]: a cópia do runner do template não é idêntica ao original"; exit 1; }
chmod +x "$B5/runner/template/.forge/scripts/tests/run-all.sh"
duble_arvore "$B5/runner/template/.forge/scripts/lib/arvore-rastreada.sh"

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
foto_antes "$V5"
( export GIT_DIR="$V5/.git"; bash "$B5/runner/template/.forge/scripts/tests/run-all.sh" --path "$B5/alvo" ) >"$T/out5.log" 2>&1
vitima_intacta "$V5" || {
  echo "FAIL [5]: vítima contaminada depois de rodar a cópia REAL de template/.forge/scripts/tests/run-all.sh despachando um teste sintético vulnerável via --path"
  difere "$V5"
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
foto_antes "$V6"
( export GIT_DIR="$V6/.git"; bash "$B6/runner/template/.forge/scripts/tests/run-all.sh" --path "$B5/alvo" ) >"$T/out6.log" 2>&1 || true
vitima_intacta "$V6" && { echo "FAIL [6]: a cópia MUTADA (sem o preâmbulo) do runner do template deveria contaminar a vítima e não contaminou — o cenário [5] não pegaria a ausência da correção no runner distribuído"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V6B="$(vitima v6b)"
foto_antes "$V6B"
( export GIT_DIR="$V6B/.git"; bash "$B5/runner/template/.forge/scripts/tests/run-all.sh" --path "$B5/alvo" ) >"$T/out6b.log" 2>&1
vitima_intacta "$V6B" || { echo "FAIL [6]: RECONTROLE — a bancada com a cópia pristina do runner do template contaminou a vítima; a mutação não foi limpa"; difere "$V6B"; exit 1; }
echo "OK [6]"

echo "[7] w102-capability-packs-gate.sh REAL (amostra do vetor installer/install.sh — não chama git init nenhuma vez) com GIT_DIR herdado deixa a vítima intacta"
cen
V7="$(vitima v7)"
foto_antes "$V7"
( export GIT_DIR="$V7/.git"; bash "$WS/tests/w102-capability-packs-gate.sh" ) >"$T/out7.log" 2>&1
RC7=$?
vitima_intacta "$V7" || {
  echo "FAIL [7]: vítima contaminada — a .git mudou depois de rodar w102-capability-packs-gate.sh com GIT_DIR herdado"
  difere "$V7"
  exit 1
}
[ "$RC7" -eq 0 ] || { echo "FAIL [7]: w102-capability-packs-gate.sh saiu rc=$RC7 com GIT_DIR herdado (deveria continuar passando)"; tail -10 "$T/out7.log"; exit 1; }
echo "OK [7]"

echo "[8] sentinela estrutural — todo tests/*.sh e tests/*.bats do universo do incidente tem o preâmbulo, antes do primeiro uso, este próprio gate incluído"
cen
ISENTOS_W248="w130-tasks-graph-gate.sh w80-suite-gate.sh"
# guarda de instrumento: um universo vazio aprovaria tudo; ele tem de conter pelo menos este gate
# e o validators.bats, que sabidamente casam o padrão.
UNIVERSO8="$(sentinela_universo "$WS/tests")"
case "$UNIVERSO8" in
  *w248-git-dir-isolation-gate.sh*) ;;
  *) echo "FAIL [8]: instrumento quebrado — o universo da sentinela não contém o próprio w248"; exit 1 ;;
esac
case "$UNIVERSO8" in
  *validators.bats*) ;;
  *) echo "FAIL [8]: instrumento quebrado — o universo da sentinela não contém tests/validators.bats"; exit 1 ;;
esac
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

echo "[10] mutação — cópia de tests/validators.bats sem o preâmbulo faz a sentinela (que enxerga .bats) reprovar nomeando o arquivo"
cen
B10="$T/bancada10/tests"
mkdir -p "$B10"
cp "$WS/tests/validators.bats" "$B10/validators.bats"
mutar_removendo_linha "$B10/validators.bats"
FALTANTES10="$(sentinela_confere "$B10" "")"
case "$FALTANTES10" in
  *validators.bats*) ;;
  *) echo "FAIL [10]: a sentinela não nomeou validators.bats sem preâmbulo — saída: $FALTANTES10"; exit 1 ;;
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
  *"fora-de-posicao-gate.sh (preâmbulo na linha 6, depois do primeiro uso git na linha 5)"*) ;;
  *) echo "FAIL [11]: a sentinela não reprovou o preâmbulo fora de posição, ou a mensagem não citou as duas linhas — saída: $FALTANTES11"; exit 1 ;;
esac
echo "OK [11]"

echo "[12] GIT_CONFIG isolado (sem os outros cinco) — changelog-merge-gate.sh REAL deixa a vítima intacta"
cen
V12="$(vitima v12)"
foto_antes "$V12"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  export GIT_CONFIG="$V12/.git/config"
  bash "$WS/tests/changelog-merge-gate.sh" ) >"$T/out12.log" 2>&1
RC12=$?
vitima_intacta "$V12" || { echo "FAIL [12]: vítima contaminada com GIT_CONFIG isolado exportado"; difere "$V12"; exit 1; }
[ "$RC12" -eq 0 ] || { echo "FAIL [12]: changelog-merge-gate.sh saiu rc=$RC12 com GIT_CONFIG isolado"; tail -10 "$T/out12.log"; exit 1; }
echo "OK [12]"

echo "[13] mutação — cópia com só GIT_CONFIG removido do preâmbulo contamina a vítima quando só GIT_CONFIG está exportado; cópia íntegra protege (recontrole)"
cen
COPIA13="$(mkbancada bancada13-pristina)"
MUTADA13="$(mkbancada bancada13-mutada)"
mutar_removendo_var "$MUTADA13" GIT_CONFIG

V13="$(vitima v13)"
foto_antes "$V13"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  export GIT_CONFIG="$V13/.git/config"
  bash "$MUTADA13" ) >/dev/null 2>&1 || true
vitima_intacta "$V13" && { echo "FAIL [13]: a cópia sem GIT_CONFIG no preâmbulo deveria contaminar a vítima e não contaminou"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V13B="$(vitima v13b)"
foto_antes "$V13B"
OUT13B="$T/out13b.log"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  export GIT_CONFIG="$V13B/.git/config"
  bash "$COPIA13" ) >"$OUT13B" 2>&1
RC13B=$?
[ "$RC13B" -eq 0 ] || { echo "FAIL [13]: RECONTROLE — a cópia íntegra saiu rc=$RC13B em vez de 0"; tail -10 "$OUT13B"; exit 1; }
vitima_intacta "$V13B" || { echo "FAIL [13]: RECONTROLE — a cópia íntegra contaminou a vítima com GIT_CONFIG isolado"; difere "$V13B"; exit 1; }
echo "OK [13]"

# vitima_com_commit <nome> -> vítima com um commit, para que o índice exista e tenha conteúdo
vitima_com_commit() {
  local v; v="$(vitima "$1")"
  echo conteudo > "$v/f.txt"
  git -C "$v" add f.txt
  git -C "$v" -c user.email="vitima-$1@vitima.example" -c user.name="vitima-$1" commit -qm init >/dev/null
  echo "$v"
}

echo "[14] GIT_INDEX_FILE isolado — changelog-merge-gate.sh REAL deixa a vítima (índice incluído) intacta"
cen
V14="$(vitima_com_commit v14)"
foto_antes "$V14"
( unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG
  export GIT_INDEX_FILE="$V14/.git/index"
  bash "$WS/tests/changelog-merge-gate.sh" ) >"$T/out14.log" 2>&1
RC14=$?
vitima_intacta "$V14" || { echo "FAIL [14]: vítima contaminada com GIT_INDEX_FILE isolado exportado"; difere "$V14"; exit 1; }
[ "$RC14" -eq 0 ] || { echo "FAIL [14]: changelog-merge-gate.sh saiu rc=$RC14 com GIT_INDEX_FILE isolado"; tail -10 "$T/out14.log"; exit 1; }
echo "OK [14]"

echo "[15] mutação — cópia com só GIT_INDEX_FILE removido do preâmbulo contamina a vítima; cópia íntegra protege (recontrole)"
cen
COPIA15="$(mkbancada bancada15-pristina)"
MUTADA15="$(mkbancada bancada15-mutada)"
mutar_removendo_var "$MUTADA15" GIT_INDEX_FILE

V15="$(vitima_com_commit v15)"
foto_antes "$V15"
( unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG
  export GIT_INDEX_FILE="$V15/.git/index"
  bash "$MUTADA15" ) >/dev/null 2>&1 || true
vitima_intacta "$V15" && { echo "FAIL [15]: a cópia sem GIT_INDEX_FILE no preâmbulo deveria contaminar a vítima e não contaminou"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V15B="$(vitima_com_commit v15b)"
foto_antes "$V15B"
OUT15B="$T/out15b.log"
( unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG
  export GIT_INDEX_FILE="$V15B/.git/index"
  bash "$COPIA15" ) >"$OUT15B" 2>&1
RC15B=$?
[ "$RC15B" -eq 0 ] || { echo "FAIL [15]: RECONTROLE — a cópia íntegra saiu rc=$RC15B em vez de 0"; tail -10 "$OUT15B"; exit 1; }
vitima_intacta "$V15B" || { echo "FAIL [15]: RECONTROLE — a cópia íntegra contaminou a vítima com GIT_INDEX_FILE isolado"; difere "$V15B"; exit 1; }
echo "OK [15]"

echo "[16] GIT_COMMON_DIR isolado — changelog-merge-gate.sh REAL deixa a vítima intacta"
cen
V16="$(vitima v16)"
foto_antes "$V16"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_CONFIG
  export GIT_COMMON_DIR="$V16/.git"
  bash "$WS/tests/changelog-merge-gate.sh" ) >"$T/out16.log" 2>&1
RC16=$?
vitima_intacta "$V16" || { echo "FAIL [16]: vítima contaminada com GIT_COMMON_DIR isolado exportado"; difere "$V16"; exit 1; }
[ "$RC16" -eq 0 ] || { echo "FAIL [16]: changelog-merge-gate.sh saiu rc=$RC16 com GIT_COMMON_DIR isolado"; tail -10 "$T/out16.log"; exit 1; }
echo "OK [16]"

echo "[17] mutação — cópia com só GIT_COMMON_DIR removido do preâmbulo contamina a vítima; cópia íntegra protege (recontrole)"
cen
COPIA17="$(mkbancada bancada17-pristina)"
MUTADA17="$(mkbancada bancada17-mutada)"
mutar_removendo_var "$MUTADA17" GIT_COMMON_DIR

V17="$(vitima v17)"
foto_antes "$V17"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_CONFIG
  export GIT_COMMON_DIR="$V17/.git"
  bash "$MUTADA17" ) >/dev/null 2>&1 || true
vitima_intacta "$V17" && { echo "FAIL [17]: a cópia sem GIT_COMMON_DIR no preâmbulo deveria contaminar a vítima e não contaminou"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V17B="$(vitima v17b)"
foto_antes "$V17B"
OUT17B="$T/out17b.log"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_CONFIG
  export GIT_COMMON_DIR="$V17B/.git"
  bash "$COPIA17" ) >"$OUT17B" 2>&1
RC17B=$?
[ "$RC17B" -eq 0 ] || { echo "FAIL [17]: RECONTROLE — a cópia íntegra saiu rc=$RC17B em vez de 0"; tail -10 "$OUT17B"; exit 1; }
vitima_intacta "$V17B" || { echo "FAIL [17]: RECONTROLE — a cópia íntegra contaminou a vítima com GIT_COMMON_DIR isolado"; difere "$V17B"; exit 1; }
echo "OK [17]"

echo "[18] tests/validators.bats REAL — bats -f '19.1' com GIT_DIR herdado deixa a vítima intacta"
cen
if ! command -v bats >/dev/null 2>&1; then
  echo "FAIL [18]: bats não está instalado neste ambiente — não há como exercitar o cenário funcional do vetor install.sh em .bats"
  exit 1
fi
V18="$(vitima v18)"
foto_antes "$V18"
OUT18="$T/out18.log"
( export GIT_DIR="$V18/.git"; bats -f "19.1" "$WS/tests/validators.bats" ) >"$OUT18" 2>&1
RC18=$?
vitima_intacta "$V18" || {
  echo "FAIL [18]: vítima contaminada depois de bats -f '19.1' tests/validators.bats com GIT_DIR herdado"
  difere "$V18"
  exit 1
}
[ "$RC18" -eq 0 ] || { echo "FAIL [18]: bats -f '19.1' validators.bats saiu rc=$RC18 com GIT_DIR herdado (deveria continuar passando)"; tail -20 "$OUT18"; exit 1; }
grep -q "^ok 1 " "$OUT18" || { echo "FAIL [18]: a saída do bats não confirma \"ok 1\" — pode ter passado por motivo errado"; tail -20 "$OUT18"; exit 1; }
echo "OK [18]"

echo "[19] mutação — cópia de validators.bats sem o preâmbulo, rodada com bats -f '19.1' e GIT_DIR herdado, contamina a vítima; cópia íntegra protege (recontrole)"
cen
BATS_ORIG="$WS/tests/validators.bats"
SHA_BATS_ORIG="$(sha_de "$BATS_ORIG")"
# §19.1 resolve `$WS/installer/install.sh` a partir de BATS_TEST_DIRNAME/.. — a cópia precisa da
# MESMA estrutura relativa (installer/ e template/ ao lado de tests/), senão o teste erraria por
# "installer/install.sh: no such file" antes de chegar perto de gravar qualquer coisa.
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
foto_antes "$V19"
( export GIT_DIR="$V19/.git"; bats -f "19.1" "$MUTADA19" ) >/dev/null 2>&1 || true
vitima_intacta "$V19" && { echo "FAIL [19]: a cópia MUTADA (sem o preâmbulo) de validators.bats deveria contaminar a vítima e não contaminou — o cenário [18] não pegaria a ausência da correção"; exit 1; }
echo "  OK — mutação contamina a vítima, como esperado"

V19B="$(vitima v19b)"
foto_antes "$V19B"
OUT19B="$T/out19b.log"
( export GIT_DIR="$V19B/.git"; bats -f "19.1" "$COPIA19" ) >"$OUT19B" 2>&1
RC19B=$?
[ "$RC19B" -eq 0 ] || { echo "FAIL [19]: RECONTROLE — a cópia íntegra de validators.bats saiu rc=$RC19B em vez de 0"; tail -20 "$OUT19B"; exit 1; }
vitima_intacta "$V19B" || { echo "FAIL [19]: RECONTROLE — a cópia íntegra (mesmo sha256 do original) contaminou a vítima; a mutação não foi limpa"; difere "$V19B"; exit 1; }
echo "OK [19]"

echo "[20] proteção contra gc preservada — gate COM o preâmbulo, despachado por cópia de tests/run-all.sh, lê gc.auto=0; com GIT_CONFIG_COUNT reintroduzido no unset, não lê (mutação); pristino volta a ler (recontrole)"
cen
B20="$T/bancada20"
mkdir -p "$B20/tests" "$B20/template/.forge/scripts/lib"
cp "$WS/tests/run-all.sh" "$B20/tests/run-all.sh"
[ "$(sha_de "$WS/tests/run-all.sh")" = "$(sha_de "$B20/tests/run-all.sh")" ] || { echo "FAIL [20]: a cópia de tests/run-all.sh na bancada 20 não é idêntica ao original"; exit 1; }
duble_arvore "$B20/template/.forge/scripts/lib/arvore-rastreada.sh"
# config global e de sistema neutralizadas na invocação: um gc.auto=0 do ~/.gitconfig de quem roda
# faria a mutação "passar" lendo o valor global, e o cenário não distinguiria nada.
: > "$T/gitconfig-vazio"
LIDO20="$T/lido20"
{
  echo '#!/usr/bin/env bash'
  echo "$PREAMBULO"
  echo "git config --get gc.auto > '$LIDO20' 2>/dev/null || echo VAZIO > '$LIDO20'"
} > "$T/sonda-gc-pristina.sh"
grep -qxF "$PREAMBULO" "$T/sonda-gc-pristina.sh" || { echo "FAIL [20]: a sonda pristina não carrega a linha exata do preâmbulo"; exit 1; }
roda20() { # roda20 <sonda> -> instala a sonda como único gate da bancada, roda o runner; lido em L20, rc em RC20 (chamada direta, nunca em $(...), para o rc e o exit valerem no gate)
  rm -f "$LIDO20" "$B20/tests/sonda-gc-gate.sh"
  cp "$1" "$B20/tests/sonda-gc-gate.sh"; chmod +x "$B20/tests/sonda-gc-gate.sh"
  ( cd "$B20" && GIT_CONFIG_GLOBAL="$T/gitconfig-vazio" GIT_CONFIG_NOSYSTEM=1 bash "$B20/tests/run-all.sh" ) >"$T/out20.log" 2>&1
  RC20=$?
  [ -f "$LIDO20" ] || { echo "FAIL [20]: a sonda não rodou (sem arquivo de leitura) — runner rc=$RC20"; tail -20 "$T/out20.log"; exit 1; }
  L20="$(cat "$LIDO20")"
}
roda20 "$T/sonda-gc-pristina.sh"
[ "$L20" = "0" ] || { echo "FAIL [20]: gate COM o preâmbulo, despachado por tests/run-all.sh, leu gc.auto='$L20' em vez de 0 — o preâmbulo anula a proteção contra gc do runner"; exit 1; }
[ "$RC20" -eq 0 ] || { echo "FAIL [20]: a cópia de tests/run-all.sh saiu rc=$RC20 com a sonda pristina"; tail -20 "$T/out20.log"; exit 1; }
cp "$T/sonda-gc-pristina.sh" "$T/sonda-gc-mutada.sh"
mutar_acrescentando_var "$T/sonda-gc-mutada.sh" GIT_CONFIG_COUNT
roda20 "$T/sonda-gc-mutada.sh"; L20M="$L20"
[ "$L20M" != "0" ] || { echo "FAIL [20]: MUTAÇÃO — com GIT_CONFIG_COUNT no unset o gate ainda leu gc.auto=0; a asserção não distingue a regressão"; exit 1; }
echo "  OK — mutação leu gc.auto='$L20M', como esperado"
roda20 "$T/sonda-gc-pristina.sh"; L20R="$L20"
[ "$L20R" = "0" ] && [ "$RC20" -eq 0 ] || { echo "FAIL [20]: RECONTROLE — a sonda pristina leu '$L20R' (rc=$RC20) em vez de 0"; exit 1; }
echo "OK [20]"

echo "[21] git -c do usuário chega ao teste pelo runner do template; com GIT_CONFIG_PARAMETERS reintroduzido no unset, não chega (mutação); runner pristino entrega (recontrole)"
cen
B21="$T/bancada21"
mkdir -p "$B21/pristino/template/.forge/scripts/tests" "$B21/pristino/template/.forge/scripts/lib" \
         "$B21/mutado/template/.forge/scripts/tests" "$B21/mutado/template/.forge/scripts/lib" "$B21/alvo"
RUN21P="$B21/pristino/template/.forge/scripts/tests/run-all.sh"
RUN21M="$B21/mutado/template/.forge/scripts/tests/run-all.sh"
cp "$TPL_ORIG" "$RUN21P"; cp "$TPL_ORIG" "$RUN21M"
[ "$(sha_de "$TPL_ORIG")" = "$(sha_de "$RUN21P")" ] || { echo "FAIL [21]: a cópia do runner do template não é idêntica ao original"; exit 1; }
duble_arvore "$B21/pristino/template/.forge/scripts/lib/arvore-rastreada.sh"
duble_arvore "$B21/mutado/template/.forge/scripts/lib/arvore-rastreada.sh"
mutar_acrescentando_var "$RUN21M" GIT_CONFIG_PARAMETERS
LIDO21="$T/lido21"
{
  echo '#!/usr/bin/env bash'
  echo "$PREAMBULO"
  echo "git config --get forge.sondaw248 > '$LIDO21' 2>/dev/null || echo VAZIO > '$LIDO21'"
} > "$B21/alvo/sonda-c-test.sh"
chmod +x "$B21/alvo/sonda-c-test.sh"
roda21() { # roda21 <runner> -> invoca o runner como alias de shell do git, sob `git -c`; lido em L21 (chamada direta)
  rm -f "$LIDO21"
  ( cd "$T" && GIT_CONFIG_GLOBAL="$T/gitconfig-vazio" GIT_CONFIG_NOSYSTEM=1 \
      git -c forge.sondaw248=chegou -c alias.rodarw248="!bash '$1' --path '$B21/alvo'" rodarw248 ) >"$T/out21.log" 2>&1
  [ -f "$LIDO21" ] || { echo "FAIL [21]: o teste-sonda não rodou (sem arquivo de leitura)"; tail -20 "$T/out21.log"; exit 1; }
  L21="$(cat "$LIDO21")"
}
roda21 "$RUN21P"
[ "$L21" = "chegou" ] || { echo "FAIL [21]: o 'git -c forge.sondaw248=chegou' do usuário não chegou ao teste pelo runner do template (leu '$L21')"; exit 1; }
roda21 "$RUN21M"; L21M="$L21"
[ "$L21M" != "chegou" ] || { echo "FAIL [21]: MUTAÇÃO — com GIT_CONFIG_PARAMETERS no unset do runner o 'git -c' ainda chegou; a asserção não distingue a regressão"; exit 1; }
echo "  OK — mutação leu '$L21M', como esperado"
roda21 "$RUN21P"; L21R="$L21"
[ "$L21R" = "chegou" ] || { echo "FAIL [21]: RECONTROLE — o runner pristino leu '$L21R' em vez de 'chegou'"; exit 1; }
echo "OK [21]"

echo "[22] sentinela com espaço no caminho — íntegro aprovado, mutado reprovado com o caminho completo, recontrole volta a vazio"
cen
B22="$T/bancada com espaço/tests"
mkdir -p "$B22"
cp "$WS/tests/w102-capability-packs-gate.sh" "$B22/w102 integro-gate.sh"
S22="$(sentinela_confere "$B22" "")"
[ -z "$S22" ] || { echo "FAIL [22]: CONTROLE — a cópia íntegra num caminho com espaço foi reprovada (divisão por palavra?) — saída: $S22"; exit 1; }
# guarda de instrumento: o controle vazio só vale se o arquivo ENTROU no universo
[ "$(sentinela_universo "$B22")" = "$B22/w102 integro-gate.sh" ] || { echo "FAIL [22]: instrumento quebrado — o universo não devolveu o caminho com espaço íntegro"; exit 1; }
cp "$B22/w102 integro-gate.sh" "$B22/w102 mutado-gate.sh"
mutar_removendo_linha "$B22/w102 mutado-gate.sh"
S22M="$(sentinela_confere "$B22" "")"
[ "$S22M" = "$B22/w102 mutado-gate.sh" ] || { echo "FAIL [22]: MUTAÇÃO — a sentinela deveria devolver exatamente uma linha com o caminho completo do mutado — saída: $S22M"; exit 1; }
rm -f "$B22/w102 mutado-gate.sh"
S22R="$(sentinela_confere "$B22" "")"
[ -z "$S22R" ] || { echo "FAIL [22]: RECONTROLE — removido o mutado, a saída deveria voltar a vazia — saída: $S22R"; exit 1; }
echo "OK [22]"

echo "[23] sentinela com opções globais entre git e o subcomando (-c, --git-dir=, -C a -c b)"
cen
B23="$T/bancada23/tests"
mkdir -p "$B23"
printf '%s\n' '#!/usr/bin/env bash' "$PREAMBULO" 'D="$(mktemp -d)"' 'git -c init.defaultBranch=main init -q "$D"' \
  > "$B23/com-c-gate.sh"
S23="$(sentinela_confere "$B23" "")"
[ -z "$S23" ] || { echo "FAIL [23]: CONTROLE — 'git -c k=v init' com o preâmbulo no topo foi reprovado — saída: $S23"; exit 1; }
[ "$(sentinela_universo "$B23")" = "$B23/com-c-gate.sh" ] || { echo "FAIL [23]: instrumento quebrado — 'git -c k=v init' não entrou no universo da sentinela"; exit 1; }
cp "$B23/com-c-gate.sh" "$B23/com-c-mutado-gate.sh"
mutar_removendo_linha "$B23/com-c-mutado-gate.sh"
printf '%s\n' '#!/usr/bin/env bash' 'git --git-dir="$D/.git" init -q' > "$B23/git-dir-gate.sh"
printf '%s\n' '#!/usr/bin/env bash' 'git -C "$D" -c core.x=y config user.email t@t' > "$B23/c-maiusculo-c-gate.sh"
printf '%s\n' '#!/usr/bin/env bash' 'git -c k=v init -q "$D"' "$PREAMBULO" > "$B23/c-deslocado-gate.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo sem git aqui' > "$B23/neutro-gate.sh"
S23M="$(sentinela_confere "$B23" "")"
ESPERADO23="$(printf '%s\n' \
  "$B23/c-deslocado-gate.sh (preâmbulo na linha 3, depois do primeiro uso git na linha 2)" \
  "$B23/c-maiusculo-c-gate.sh" \
  "$B23/com-c-mutado-gate.sh" \
  "$B23/git-dir-gate.sh")"
[ "$S23M" = "$ESPERADO23" ] || { echo "FAIL [23]: MUTAÇÃO — a sentinela deveria reprovar exatamente os quatro arquivos esperados, e só eles"; echo "--- obtido:"; echo "$S23M"; echo "--- esperado:"; echo "$ESPERADO23"; exit 1; }
echo "  OK — mutação e as três formas sem preâmbulo reprovadas; íntegro e neutro aprovados"
rm -f "$B23/com-c-mutado-gate.sh" "$B23/git-dir-gate.sh" "$B23/c-maiusculo-c-gate.sh" "$B23/c-deslocado-gate.sh"
S23R="$(sentinela_confere "$B23" "")"
[ -z "$S23R" ] || { echo "FAIL [23]: RECONTROLE — só com o íntegro e o neutro a saída deveria ser vazia — saída: $S23R"; exit 1; }
echo "OK [23]"

echo "[24] sentinela — contagem de cenários examinados"
cen
[ "$EXAMINADOS" -eq "$DECLARADO" ] || { echo "FAIL [24]: examinados=$EXAMINADOS declarado=$DECLARADO"; exit 1; }
echo "OK [24]"
