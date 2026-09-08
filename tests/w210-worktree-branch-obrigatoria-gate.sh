#!/usr/bin/env bash
# Gate W210 — toda worktree nasce com branch, e o que a branch não salva.
#
# Pedido do dono, 2026-09-08: "sempre que se abrir uma worktree, já se cria uma branch, mesmo que
# depois ela seja renomeada, para garantir rastreabilidade do trabalho e garantir que o trabalho não
# se perca". A especificação é docs/plans/spikes/worktree-branch-obrigatoria.md e este gate é a
# prova executável dela.
#
# O mecanismo é o hook `post-checkout`, medido disparando DENTRO da worktree recém-criada em
# `git worktree add`, com `$1` igual a quarenta zeros e `git symbolic-ref -q HEAD` vazio quando o
# destino é destacado — e é o único ponto que alcança quem digitou o comando fora do Claude Code.
#
# Toda fixture vive sob $TMPDIR e nenhuma worktree é criada dentro do repositório real (LDG-0175).
#
#   [0]  controle de instrumento: a fixture é repositório git utilizável e o caminho canônico do
#        hook sob teste é o esperado — sem isto um caminho digitado errado produziria o mesmo
#        vermelho que a ausência real da funcionalidade
#   [1]  `worktree add <dir> HEAD` sob .forge/worktrees/ termina com HEAD ATACADO
#   [2]  `worktree add --detach <dir>` sob .forge/worktrees/ termina com HEAD ATACADO
#   [3]  `worktree add <dir> -b <nome>` mantém <nome> e nenhuma branch wt/* nasce
#   [4]  fora do território: dentro da árvore do tronco recebe AVISO e segue destacada; fora da
#        árvore do tronco (o caso do red-replay) segue destacada EM SILÊNCIO
#   [5]  o discriminador de destacado é `symbolic-ref`, nunca `$3` — que vale 1 nos dois caminhos
#   [6]  nome derivado inválido (`x.lock`) é saneado e o HEAD termina atacado
#   [7]  colisão diretório/arquivo no namespace de refs resolve pela cascata
#   [8]  branch wt/<slug> já existente NÃO é reaproveitada, e a existente não se move
#   [9]  cascata esgotada: rc próprio, stderr nomeia o estado E diz que a worktree EXISTE em disco
#   [10] a reentrância é contida: o hook reentra e nasce EXATAMENTE UMA branch por worktree
#   [11] `git branch -m` mantém o vínculo e a triagem classifica a worktree sob o nome NOVO
#   [12] --triage separa "mergeada com ignorados presentes" de "mergeada e totalmente limpa"
#   [13] --triage devolve o terceiro estado quando as duas refs de integração discordam
#   [14] --triage NÃO executa nada: worktrees, branches e arquivos idênticos antes e depois
#   [15] a lib de classificação concorda com o post-merge sobre "limpa" e sobre "ignorado presente"
#   [16] o doctor chama a triagem barata, publica contagem por classe e não varre universo vazio
#   [17] não-interferência: checkout comum no tronco e `--detach` deliberado dentro do território
#        continuam intocados
#   [18] PBT do saneador: para basename gerado, ou nasce branch válida, ou o hook reporta o
#        terceiro estado — nunca HEAD destacado com rc 0
#   [19] sem ref de integração no repositório, NADA vira "mergeada": a triagem responde o terceiro
#        estado e não propõe remoção de árvore viva
#   [20] o conserto NÃO amplia a população que o post-merge remove: controle sem o hook e efeito
#        com ele, com o opt-in de remoção LIGADO
#   [21] --triage --barato explica o terceiro estado pela CAUSA, e nunca afirma "mergeada e de
#        índice limpo" sobre estado indeterminado
#   [22] worktree DESTACADA com trabalho não commitado torna a perda visível, com o resgate
#   [23] contador de controle: N cenários declarados, N executados
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_SRC="$WS/template/.forge/hooks/git"
HOOK_CANONICO="$HOOKS_SRC/post-checkout"
RECONCILE="$WS/template/.forge/scripts/worktree-reconcile.sh"
CLASSIFY="$WS/template/.forge/scripts/lib/worktree-classify.sh"
POST_MERGE="$HOOKS_SRC/post-merge"
DOCTOR="$WS/template/.forge/scripts/doctor.sh"
ZERO=0000000000000000000000000000000000000000

# Canonizado por `pwd -P`: no macOS $TMPDIR mora sob /var, que é symlink para /private/var, e o hook
# resolve os caminhos que compara com `pwd -P`. Sem canonizar aqui, uma asserção sobre o caminho
# impresso pelo hook compararia duas grafias do mesmo diretório e falharia por instrumento.
T="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/forge-w210.XXXXXX")" && pwd -P)"
trap 'rm -rf "$T"' EXIT

# Denominador FIXO por construção: é o número de cenários que este gate declara, e a única exceção
# legítima da invariante 14 — divergência aqui é justamente o achado.
SCENARIOS_DECLARED=24
SCENARIOS_RUN=0
scenario() { SCENARIOS_RUN=$((SCENARIOS_RUN + 1)); echo "$1"; }

# ── fixture: tronco git com harness instalado e hooks encadeados por caminho ABSOLUTO ───────────
# `core.hooksPath` absoluto é o que faz o hook do tronco alcançar toda worktree, inclusive a criada
# a partir de uma branch antiga — a única peça desta onda que atravessa a fronteira da issue #123.
mkfx() {  # mkfx <nome> -> ecoa <dir do tronco>
  local d="$T/$1"
  mkdir -p "$d/.forge/worktrees" "$d/hooks"
  git init -q -b main "$d"
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  git -C "$d" config commit.gpgsign false
  # Só o hook sob teste é instalado. Instalar a pasta inteira faria o `pre-commit` do template
  # bloquear os commits da própria fixture por delegação ausente, e o gate mediria o instrumento em
  # vez do alvo — o `post-merge` do cenário [15] é invocado diretamente, como o w153 já faz.
  cp "$HOOK_CANONICO" "$d/hooks/post-checkout" 2>/dev/null || true
  git -C "$d" config core.hooksPath "$d/hooks"
  printf '.forge/worktrees/\nbuild/\nlocal.properties\n' > "$d/.gitignore"
  printf 'x\n' > "$d/a.txt"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -qm base >/dev/null 2>&1
  printf '%s\n' "$d"
}

head_de() {  # head_de <worktree> -> ecoa a branch, ou DESTACADO
  local s; s="$(git -C "$1" symbolic-ref -q HEAD 2>/dev/null || true)"
  [ -n "$s" ] && printf '%s\n' "${s#refs/heads/}" || printf 'DESTACADO\n'
}
conta_wt_branches() {  # conta_wt_branches <repo> -> quantas branches começam com wt/
  git -C "$1" for-each-ref --format='%(refname:short)' refs/heads/wt 2>/dev/null | grep -c . || true
}
# A classe de uma worktree é lida da LINHA que termina naquele caminho, nunca de um casamento solto
# na saída inteira: 'destacada' aparecendo em qualquer outro bloco tornaria a asserção não
# discriminante. O laço é shell puro, sem varredura de texto por ferramenta externa — o `grep` desta
# máquina é ugrep, que sobre arquivo com byte de controle devolve saída vazia com rc 1, e vazio não
# prova ausência.
classe_de() {  # classe_de <saída da triagem> <caminho> -> ecoa a classe, ou nada
  local saida="$1" alvo="$2" linha
  while IFS= read -r linha; do
    case "$linha" in
      *"  $alvo") printf '%s\n' "${linha%%  *}"; return 0 ;;
    esac
  done <<EOF_CLASSE
$saida
EOF_CLASSE
  return 1
}

# ── [0] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[0] controle de instrumento: a fixture é repositório git utilizável e o caminho canônico é o esperado"
F0="$(mkfx f0)"
[ -d "$F0/.git" ] || { echo "FAIL [0]: a fixture não é repositório git — nada abaixo mediria a funcionalidade"; exit 1; }
# `git rev-parse HEAD` num repositório SEM commit ecoa a string literal 'HEAD' no stdout e sai 128,
# de modo que `[ -n ... ]` a aprova: medido aqui, e é por isso que o controle usa `--verify -q`.
git -C "$F0" rev-parse --verify -q HEAD >/dev/null \
  || { echo "FAIL [0]: a fixture não tem commit — 'worktree add HEAD' não teria alvo, e o vermelho abaixo viria da fixture e não da ausência da funcionalidade"; exit 1; }
[ -d "$F0/.forge/worktrees" ] || { echo "FAIL [0]: a fixture não tem .forge/worktrees/ — o território do conserto não existiria"; exit 1; }
# O controle roda com `core.hooksPath` apontando para um diretório VAZIO, e é essa a diferença que
# o torna controle. Com o hook sob teste ativo, qualquer defeito que fizesse o `post-checkout`
# devolver rc não zero num `worktree add` derrubaria este cenário — e a mensagem impressa afirmaria
# o oposto do que aconteceu ("o instrumento está quebrado, não o alvo"). Um controle que exercita o
# alvo não separa "não consegui verificar" de "encontrei", que é justamente a razão de ele existir.
mkdir -p "$T/hooks-vazio"
git -C "$F0" config core.hooksPath "$T/hooks-vazio"
git -C "$F0" worktree add -q "$F0/.forge/worktrees/ctl" -b ctl >/dev/null 2>&1 \
  || { echo "FAIL [0]: 'git worktree add -b' não funciona nesta fixture NEM COM O HOOK DESLIGADO — o instrumento está quebrado, não o alvo"; exit 1; }
git -C "$F0" config core.hooksPath "$F0/hooks"
# E o alvo precisa estar instalável e EXECUTÁVEL: um `post-checkout` sem bit de execução é
# silenciosamente ignorado pelo git, e a onda inteira ficaria inerte no consumidor com todos os
# cenários abaixo medindo um arquivo que nunca roda.
[ -x "$HOOK_CANONICO" ] \
  || { echo "FAIL [0]: o hook canônico não está executável ($HOOK_CANONICO) — o git ignora em silêncio um hook sem +x, e a funcionalidade nasceria inerte no consumidor"; exit 1; }
case "$HOOK_CANONICO" in
  "$WS/template/.forge/hooks/git/post-checkout") : ;;
  *) echo "FAIL [0]: o caminho canônico do hook sob teste não é o esperado ($HOOK_CANONICO)"; exit 1 ;;
esac
echo "OK [0] — instrumento verificado; alvo sob teste: $HOOK_CANONICO"

# ── [1] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[1] worktree add <dir> HEAD sob .forge/worktrees/ termina com HEAD ATACADO"
F1="$(mkfx f1)"
git -C "$F1" worktree add -q "$F1/.forge/worktrees/r1" HEAD >/dev/null 2>&1
h1="$(head_de "$F1/.forge/worktrees/r1")"
[ "$h1" != "DESTACADO" ] \
  || { echo "FAIL [1]: a worktree nasceu com HEAD destacado — sem branch não há o que empurrar, não há PR possível, e o rastro morre na máquina quando a worktree é removida"; exit 1; }
echo "OK [1] — branch: $h1"

# ── [2] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[2] worktree add --detach <dir> sob .forge/worktrees/ termina com HEAD ATACADO"
F2="$(mkfx f2)"
git -C "$F2" worktree add -q --detach "$F2/.forge/worktrees/r2" HEAD >/dev/null 2>&1
h2="$(head_de "$F2/.forge/worktrees/r2")"
[ "$h2" != "DESTACADO" ] \
  || { echo "FAIL [2]: '--detach' explícito no território do harness continuou sem branch — é o caminho que um agente digita para 'a árvore como está agora', e é o perfil das worktrees destacadas medidas em campo"; exit 1; }
echo "OK [2] — branch: $h2"

# ── [3] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[3] worktree add <dir> -b <nome> mantém <nome> e nenhuma branch wt/* nasce"
F3="$(mkfx f3)"
git -C "$F3" worktree add -q "$F3/.forge/worktrees/r3" -b feat/escolhida >/dev/null 2>&1
h3="$(head_de "$F3/.forge/worktrees/r3")"
[ "$h3" = "feat/escolhida" ] \
  || { echo "FAIL [3]: o hook mexeu numa worktree que JÁ tinha branch (HEAD=$h3) — quem nomeou a branch decidiu, e sobrescrever a decisão é pior que não agir"; exit 1; }
n3="$(conta_wt_branches "$F3")"
[ "$n3" -eq 0 ] \
  || { echo "FAIL [3]: nasceram $n3 branch(es) wt/* numa criação que já vinha com nome — branch a mais é entulho que ninguém vai remover"; exit 1; }
echo "OK [3]"

# ── [4] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[4] fora do território: dentro da árvore do tronco AVISA e segue destacada; fora dela, silêncio"
F4="$(mkfx f4)"
mkdir -p "$F4/fora"
err4="$(git -C "$F4" worktree add -q --detach "$F4/fora/dentro-da-arvore" HEAD 2>&1 >/dev/null || true)"
h4="$(head_de "$F4/fora/dentro-da-arvore")"
[ "$h4" = "DESTACADO" ] \
  || { echo "FAIL [4]: o conserto agiu FORA de .forge/worktrees/ (HEAD=$h4) — o escopo é o território declarado do harness, e um conserto de escopo largo atacharia branch em cada worktree efêmera do red-replay"; exit 1; }
case "$err4" in
  *worktrees*|*território*|*branch*) : ;;
  *) echo "FAIL [4]: worktree destacada dentro da árvore do tronco e fora do território não recebeu aviso nenhum (stderr: '$err4') — silêncio aqui é o falso-verde que a invariante 2 proíbe"; exit 1 ;;
esac
D4="$T/f4-externa"; mkdir -p "$D4"
err4b="$(git -C "$F4" worktree add -q --detach "$D4/efemera" HEAD 2>&1 >/dev/null || true)"
[ -z "$err4b" ] \
  || { echo "FAIL [4]: worktree destacada FORA da árvore do tronco produziu ruído em stderr ('$err4b') — é exatamente o que o red-replay.mjs cria em tmpdir(), e o ruído reaparece dentro de qualquer mensagem de erro do replay"; exit 1; }
echo "OK [4]"

# ── [5] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[5] o discriminador de destacado é symbolic-ref, nunca \$3 — que vale 1 nos dois caminhos"
F5="$(mkfx f5)"
git -C "$F5" worktree add -q "$F5/.forge/worktrees/com-b" -b feat/tem-nome >/dev/null 2>&1
n5b="$(conta_wt_branches "$F5")"
git -C "$F5" worktree add -q "$F5/.forge/worktrees/sem-b" HEAD >/dev/null 2>&1
n5d="$(conta_wt_branches "$F5")"
[ "$n5b" -eq 0 ] \
  || { echo "FAIL [5]: o caminho com '-b' produziu branch wt/* — o hook está discriminando por \$3, que vale 1 tanto na criação destacada quanto na criação com branch, e por isso nasce morto como discriminador"; exit 1; }
[ "$n5d" -eq 1 ] \
  || { echo "FAIL [5]: o caminho destacado produziu $n5d branch(es) wt/* onde deveria produzir exatamente 1 — os dois caminhos precisam de desfechos diferentes, e é 'symbolic-ref' que os separa"; exit 1; }
echo "OK [5]"

# ── [6] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[6] nome derivado inválido (x.lock) é saneado e o HEAD termina atacado"
F6="$(mkfx f6)"
git -C "$F6" worktree add -q "$F6/.forge/worktrees/x.lock" HEAD >/dev/null 2>&1
h6="$(head_de "$F6/.forge/worktrees/x.lock")"
[ "$h6" != "DESTACADO" ] \
  || { echo "FAIL [6]: o nome derivado inválido deixou a worktree destacada — 'wt/x.lock' é recusado pelo git e o conserto tem de sanear em vez de desistir em silêncio"; exit 1; }
git -C "$F6" check-ref-format --branch "$h6" >/dev/null 2>&1 \
  || { echo "FAIL [6]: o nome produzido ('$h6') não passa em check-ref-format — o saneador entregou algo que o próprio git recusa"; exit 1; }
# E ele resolve por SANEAMENTO, não pela cascata. As duas asserções acima são satisfeitas pela
# cascata sozinha — o segundo candidato é `wt/<slug>-<sha7>`, e ali `.lock` deixa de ser sufixo do
# componente —, de modo que apagar o saneador manteria este cenário verde afirmando o contrário do
# que o enunciado dele promete. O discriminador é o sufixo de commit: se ele aparece, quem resolveu
# foi a cascata, e o saneamento específico não existe mais.
sha6="$(git -C "$F6" rev-parse --short=7 HEAD)"
case "$h6" in
  *"-$sha6"|*"-$sha6-"*)
    echo "FAIL [6]: o nome inválido foi resolvido pela CASCATA ('$h6' carrega o sufixo de commit '$sha6') e não pelo saneamento — o cenário se anuncia como prova do saneador, e sem esta asserção apagar o saneador deixa o gate inteiro verde"; exit 1 ;;
esac
echo "OK [6] — branch: $h6 (saneada, sem recorrer à cascata)"

# ── [7] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[7] colisão diretório/arquivo no namespace de refs resolve pela cascata"
F7="$(mkfx f7)"
git -C "$F7" branch "wt/col/ocupado" >/dev/null 2>&1
git -C "$F7" worktree add -q "$F7/.forge/worktrees/col" HEAD >/dev/null 2>&1
h7="$(head_de "$F7/.forge/worktrees/col")"
[ "$h7" != "DESTACADO" ] \
  || { echo "FAIL [7]: a colisão diretório/arquivo ('wt/col' contra 'wt/col/ocupado') deixou a worktree destacada — o git recusa a ref e a cascata existe justamente para isso"; exit 1; }
echo "OK [7] — branch: $h7"

# ── [8] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[8] branch wt/<slug> já existente NÃO é reaproveitada, e a existente não se move"
F8="$(mkfx f8)"
git -C "$F8" branch "wt/dup" >/dev/null 2>&1
antes8="$(git -C "$F8" rev-parse "wt/dup")"
printf 'y\n' > "$F8/b.txt"; git -C "$F8" add -A >/dev/null 2>&1; git -C "$F8" commit -qm segundo >/dev/null 2>&1
git -C "$F8" worktree add -q "$F8/.forge/worktrees/dup" HEAD >/dev/null 2>&1
h8="$(head_de "$F8/.forge/worktrees/dup")"
[ "$h8" != "DESTACADO" ] \
  || { echo "FAIL [8]: a worktree ficou destacada porque o nome preferido já existia — a cascata tem de avançar"; exit 1; }
[ "$h8" != "wt/dup" ] \
  || { echo "FAIL [8]: o conserto REAPROVEITOU a branch existente — uma branch a mais é entulho, uma branch compartilhada por engano é histórico misturado, e o custo do erro é assimétrico"; exit 1; }
depois8="$(git -C "$F8" rev-parse "wt/dup")"
[ "$antes8" = "$depois8" ] \
  || { echo "FAIL [8]: a branch preexistente 'wt/dup' foi MOVIDA ($antes8 -> $depois8) — o conserto reescreveu o ponteiro de trabalho alheio"; exit 1; }
echo "OK [8] — branch: $h8"

# ── [9] ─────────────────────────────────────────────────────────────────────────────────────────
scenario "[9] cascata esgotada: rc próprio, stderr nomeia o estado E diz que a worktree EXISTE em disco"
F9="$(mkfx f9)"
sha9="$(git -C "$F9" rev-parse --short=7 HEAD)"
# Ocupa todos os candidatos possíveis para o slug 'esg' a partir deste commit, inclusive os
# numerados, forçando o esgotamento sem depender do teto exato escolhido pela implementação.
git -C "$F9" branch "wt/esg" >/dev/null 2>&1
git -C "$F9" branch "wt/esg-$sha9" >/dev/null 2>&1
i=2; while [ "$i" -le 24 ]; do
  git -C "$F9" branch "wt/esg-$sha9-$i" >/dev/null 2>&1
  git -C "$F9" branch "wt/esg-$i" >/dev/null 2>&1
  i=$((i + 1))
done
# O rc é capturado sem `|| true`, que zeraria justamente o que está sob prova: o terceiro estado
# não é a mensagem, é o desfecho. Um hook que imprimisse o aviso e saísse 0 colapsaria "não
# consegui dar nome" em "dei nome", e a mensagem sozinha não distingue os dois para quem automatiza.
err9="$T/err9.txt"
git -C "$F9" worktree add -q "$F9/.forge/worktrees/esg" HEAD >/dev/null 2>"$err9"
rc9=$?
out9="$(cat "$err9")"
h9="$(head_de "$F9/.forge/worktrees/esg")"
[ "$rc9" -ne 0 ] \
  || { echo "FAIL [9]: a cascata esgotou e o 'git worktree add' devolveu rc 0 — 'consegui dar nome', 'já tinha nome' e 'NÃO consegui dar nome' são três desfechos, e quem automatiza lê o código de saída, não a prosa em stderr"; exit 1; }
[ "$h9" = "DESTACADO" ] \
  || { echo "FAIL [9]: o laboratório não esgotou a cascata (HEAD=$h9) — sem esgotamento o cenário não mede o terceiro estado"; exit 1; }
case "$out9" in
  "") echo "FAIL [9]: a cascata esgotou EM SILÊNCIO — 'consegui dar nome', 'já tinha nome' e 'não consegui dar nome' são três desfechos, e colapsar o terceiro no primeiro é o falso-verde da invariante 2"; exit 1 ;;
  *) : ;;
esac
case "$out9" in
  *EXISTE*|*existe*) : ;;
  *) echo "FAIL [9]: a mensagem de esgotamento não diz que a worktree EXISTE em disco (stderr: '$out9') — o rc não desfaz o 'worktree add', e todo chamador com 'set -e' vai ler o rc como 'o add falhou'"; exit 1 ;;
esac
case "$out9" in
  *"$F9/.forge/worktrees/esg"*) : ;;
  *) echo "FAIL [9]: a mensagem de esgotamento não diz ONDE a worktree ficou (stderr: '$out9')"; exit 1 ;;
esac
echo "OK [9]"

# ── [10] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[10] a reentrância é contida: o hook reentra e nasce EXATAMENTE UMA branch por worktree"
# O 'git switch -c' do próprio conserto dispara post-checkout de novo — medido. O que o desenho
# precisa garantir não é ausência de reentrada, é que ela termine: a segunda invocação chega com
# '\$1' igual a um sha REAL e com symbolic-ref JÁ preenchido, e qualquer uma das duas condições a
# encerra. Remover as duas ao mesmo tempo produz a cascata inteira em uma criação só, e é isso que
# este contador acusa.
F10="$(mkfx f10)"
git -C "$F10" worktree add -q "$F10/.forge/worktrees/rec" HEAD >/dev/null 2>&1
n10="$(conta_wt_branches "$F10")"
[ "$n10" -eq 1 ] \
  || { echo "FAIL [10]: uma única criação de worktree produziu $n10 branch(es) wt/* — a reentrada do conserto não está contida e cada nível da cascata deixa entulho"; exit 1; }
h10="$(head_de "$F10/.forge/worktrees/rec")"
[ "$h10" != "DESTACADO" ] \
  || { echo "FAIL [10]: a worktree ficou destacada — sem conserto o contador de branches é vacuamente 0 e este cenário não mediria nada"; exit 1; }
echo "OK [10] — 1 branch: $h10"

# ── [11] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[11] git branch -m mantém o vínculo e a triagem classifica a worktree sob o nome NOVO"
F11="$(mkfx f11)"
git -C "$F11" worktree add -q "$F11/.forge/worktrees/ren" HEAD >/dev/null 2>&1
h11a="$(head_de "$F11/.forge/worktrees/ren")"
[ "$h11a" != "DESTACADO" ] || { echo "FAIL [11]: a worktree nasceu sem branch — não há o que renomear"; exit 1; }
git -C "$F11" branch -m "$h11a" feat/renomeada >/dev/null 2>&1
h11b="$(head_de "$F11/.forge/worktrees/ren")"
[ "$h11b" = "feat/renomeada" ] \
  || { echo "FAIL [11]: a worktree não acompanhou o rename (HEAD=$h11b) — o dono pediu explicitamente 'mesmo que depois ela seja renomeada'"; exit 1; }
tri11="$(bash "$RECONCILE" --root "$F11" --triage 2>&1 || true)"
c11="$(classe_de "$tri11" "$F11/.forge/worktrees/ren" || true)"
[ -n "$c11" ] \
  || { echo "FAIL [11]: a triagem perdeu a worktree depois do rename (saída: '$tri11') — nenhuma peça pode guardar o nome da branch como chave, porque o rename quebraria o vínculo no instante seguinte"; exit 1; }
[ "$c11" != "destacada" ] \
  || { echo "FAIL [11]: a triagem classificou como 'destacada' uma worktree atacada em feat/renomeada — a classificação está lendo um nome guardado em vez do estado do git"; exit 1; }
case "$tri11" in
  *feat/renomeada*) : ;;
  *) echo "FAIL [11]: a triagem não reporta a branch sob o nome NOVO (saída: '$tri11')"; exit 1 ;;
esac
echo "OK [11] — classe: $c11"

# ── laboratório da triagem ──────────────────────────────────────────────────────────────────────
# Tronco com origin real (bare), uma worktree mergeada e limpa, uma mergeada com ignorado presente,
# uma mergeada e suja, e uma viva. Nada aqui usa número da árvore real: a fixture cria o que conta.
lab_triagem() {  # lab_triagem <nome> -> ecoa <dir>
  local d="$T/$1" bare="$T/$1.git"
  d="$(mkfx "$1")"
  git init -q --bare "$bare"
  git -C "$d" remote add origin "$bare"
  git -C "$d" checkout -q -b develop
  for b in limpa ignorados suja; do
    git -C "$d" checkout -q -b "feat/$b" develop
    printf '%s\n' "$b" > "$d/$b.txt"
    git -C "$d" add -A >/dev/null 2>&1; git -C "$d" commit -qm "feat $b" >/dev/null 2>&1
    git -C "$d" checkout -q develop
    git -C "$d" merge -q --no-ff "feat/$b" -m "merge $b" >/dev/null 2>&1
  done
  git -C "$d" checkout -q -b feat/viva develop
  printf 'viva\n' > "$d/viva.txt"
  git -C "$d" add -A >/dev/null 2>&1; git -C "$d" commit -qm "feat viva" >/dev/null 2>&1
  git -C "$d" checkout -q develop
  git -C "$d" push -q origin develop >/dev/null 2>&1
  git -C "$d" fetch -q origin >/dev/null 2>&1
  for b in limpa ignorados suja viva; do
    git -C "$d" worktree add -q "$d/.forge/worktrees/$b" "feat/$b" >/dev/null 2>&1
  done
  printf 'sdk.dir=/opt\n' > "$d/.forge/worktrees/ignorados/local.properties"
  printf 'nao-commitado\n' > "$d/.forge/worktrees/suja/pendente.txt"
  git -C "$d/.forge/worktrees/suja" add -A >/dev/null 2>&1
  printf '%s\n' "$d"
}

# ── [12] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[12] --triage separa 'mergeada com ignorados presentes' de 'mergeada e totalmente limpa'"
F12="$(lab_triagem f12)"
tri12="$(bash "$RECONCILE" --root "$F12" --triage 2>&1 || true)"
c_ign="$(classe_de "$tri12" "$F12/.forge/worktrees/ignorados" || true)"
c_lim="$(classe_de "$tri12" "$F12/.forge/worktrees/limpa" || true)"
c_suja="$(classe_de "$tri12" "$F12/.forge/worktrees/suja" || true)"
c_viva="$(classe_de "$tri12" "$F12/.forge/worktrees/viva" || true)"
[ -n "$c_ign" ] && [ -n "$c_lim" ] && [ -n "$c_suja" ] && [ -n "$c_viva" ] \
  || { echo "FAIL [12]: a triagem não classificou as quatro worktrees do laboratório (ignorados='$c_ign' limpa='$c_lim' suja='$c_suja' viva='$c_viva')"; exit 1; }
[ "$c_ign" = "mergeada-com-ignorados" ] \
  || { echo "FAIL [12]: worktree mergeada com arquivo IGNORADO presente recebeu a classe '$c_ign' — 'git status --porcelain' não vê ignorado, e é exatamente esse colapso que apagou local.properties e build/ na issue #72"; exit 1; }
[ "$c_lim" = "mergeada-limpa" ] \
  || { echo "FAIL [12]: worktree mergeada e totalmente limpa recebeu a classe '$c_lim'"; exit 1; }
[ "$c_suja" = "mergeada-suja" ] \
  || { echo "FAIL [12]: worktree mergeada com arquivo rastreado modificado recebeu a classe '$c_suja'"; exit 1; }
[ "$c_viva" = "viva" ] \
  || { echo "FAIL [12]: worktree que não é ancestral de ref de integração nenhuma recebeu a classe '$c_viva'"; exit 1; }
# A proposta da classe com ignorados tem de ser explícita sobre o --force, e a da classe limpa não
# pode carregar o --force: é a diferença entre "removível sem perda" e "você vai perder isto aqui".
bloco_ign=0; bloco_lim=0; atual=""
while IFS= read -r l; do
  case "$l" in
    "mergeada-com-ignorados  "*) atual=ign ;;
    "mergeada-limpa  "*) atual=lim ;;
    "") atual="" ;;
    *"worktree remove --force"*) [ "$atual" = ign ] && bloco_ign=1; [ "$atual" = lim ] && bloco_lim=1 ;;
  esac
done <<EOF_PROP
$tri12
EOF_PROP
[ "$bloco_ign" -eq 1 ] \
  || { echo "FAIL [12]: a triagem propôs remoção SIMPLES para a worktree com ignorados — a proposta ali tem de ser explícita sobre o --force e sobre o que se perde"; exit 1; }
[ "$bloco_lim" -eq 0 ] \
  || { echo "FAIL [12]: a triagem ofereceu '--force' para a worktree TOTALMENTE limpa — normalizar o --force é ensinar o operador a usá-lo onde ele destrói"; exit 1; }
echo "OK [12]"

# ── [13] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[13] --triage devolve o terceiro estado quando as duas refs de integração discordam"
F13="$(lab_triagem f13)"
# origin/develop segue à frente; o develop LOCAL recua para antes do merge de feat/suja, de modo
# que a mesma worktree é ancestral de uma ref e não da outra — medido em campo nos dois sentidos,
# em azim-crm (5 worktrees) e em axis-go-cloud (1, no sentido oposto).
git -C "$F13" checkout -q develop
git -C "$F13" reset -q --hard "HEAD~1"
tri13="$(bash "$RECONCILE" --root "$F13" --triage 2>&1 || true)"
c13="$(classe_de "$tri13" "$F13/.forge/worktrees/suja" || true)"
[ -n "$c13" ] || { echo "FAIL [13]: a triagem não classificou a worktree em disputa (saída: '$tri13')"; exit 1; }
[ "$c13" = "nao-verificado" ] \
  || { echo "FAIL [13]: a triagem deu o VEREDITO '$c13' onde as duas refs de integração discordam — 'não consegui verificar' é um desfecho próprio, e responder 'não mergeada' com rc 0 é mentir com código zero"; exit 1; }
case "$tri13" in
  *develop*) : ;;
  *) echo "FAIL [13]: o terceiro estado não nomeia a divergência que o produziu (saída: '$tri13')"; exit 1 ;;
esac
echo "OK [13]"

# ── [14] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[14] --triage NÃO executa nada: worktrees, branches e arquivos idênticos antes e depois"
F14="$(lab_triagem f14)"
wt_antes="$(git -C "$F14" worktree list --porcelain | grep -c '^worktree ' || true)"
br_antes="$(git -C "$F14" for-each-ref --format='%(refname)' refs/heads | grep -c . || true)"
arq_antes="$(find "$F14/.forge/worktrees" -type f | wc -l | tr -d ' ')"
bash "$RECONCILE" --root "$F14" --triage >/dev/null 2>&1 || true
wt_depois="$(git -C "$F14" worktree list --porcelain | grep -c '^worktree ' || true)"
br_depois="$(git -C "$F14" for-each-ref --format='%(refname)' refs/heads | grep -c . || true)"
arq_depois="$(find "$F14/.forge/worktrees" -type f | wc -l | tr -d ' ')"
[ "$wt_antes" = "$wt_depois" ] \
  || { echo "FAIL [14]: a triagem removeu worktree ($wt_antes -> $wt_depois) — ela classifica e propõe, e nunca age; 23 das 36 mergeadas medidas em campo satisfazem 'limpa' e carregam estado irrecuperável"; exit 1; }
[ "$br_antes" = "$br_depois" ] \
  || { echo "FAIL [14]: a triagem mexeu em branches ($br_antes -> $br_depois)"; exit 1; }
[ "$arq_antes" = "$arq_depois" ] \
  || { echo "FAIL [14]: a triagem mexeu em arquivos das worktrees ($arq_antes -> $arq_depois)"; exit 1; }
[ "$wt_antes" -gt 1 ] \
  || { echo "FAIL [14]/universo-vazio — o laboratório não tinha worktree linkada nenhuma, e 'nada mudou' seria verdade por vacuidade"; exit 1; }
echo "OK [14] — $wt_antes entrada(s) de worktree, $br_antes branch(es), $arq_antes arquivo(s) intactos"

# ── [15] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[15] a lib de classificação concorda com o post-merge sobre 'limpa' e sobre 'ignorado presente'"
# O post-merge NÃO é refatorado nesta onda (ver 'Correções da implementação' na especificação): o
# risco de acrescentar delegação nova a um hook instalado em cinco consumidores é maior que o ganho
# de fonte única. O que fecha a preocupação de 'duas definições de limpa' é esta equivalência
# medida: a lib e o hook precisam classificar o MESMO laboratório do mesmo jeito.
[ -f "$CLASSIFY" ] \
  || { echo "FAIL [15]: template/.forge/scripts/lib/worktree-classify.sh não existe — sem fonte declarada dos predicados, cada peça inventa a sua definição de 'limpa'"; exit 1; }
# shellcheck source=/dev/null
. "$CLASSIFY"
F15="$(lab_triagem f15)"
forge_wt_ignored_present "$F15/.forge/worktrees/ignorados" >/dev/null 2>&1 \
  || { echo "FAIL [15]: a lib não vê o arquivo ignorado presente que o post-merge vê — é a divergência que reintroduz o incidente da issue #72"; exit 1; }
forge_wt_ignored_present "$F15/.forge/worktrees/limpa" >/dev/null 2>&1 \
  && { echo "FAIL [15]: a lib acusou arquivo ignorado numa worktree totalmente limpa — falso positivo aqui congela toda proposta de remoção"; exit 1; }
forge_wt_tracked_dirty "$F15/.forge/worktrees/suja" >/dev/null 2>&1 \
  || { echo "FAIL [15]: a lib não vê como suja a worktree com arquivo rastreado modificado"; exit 1; }
forge_wt_tracked_dirty "$F15/.forge/worktrees/ignorados" >/dev/null 2>&1 \
  && { echo "FAIL [15]: a lib chamou de suja uma worktree que só tem arquivo IGNORADO — a distinção entre os dois predicados é o cerne da guarda"; exit 1; }
# E o post-merge continua propondo, com a guarda de ignorados, sobre este mesmo laboratório.
out15="$(cd "$F15" && bash "$POST_MERGE" 2>&1 || true)"
[ -d "$F15/.forge/worktrees/ignorados" ] \
  || { echo "FAIL [15]: o post-merge removeu a worktree com arquivo ignorado (saída: '$out15')"; exit 1; }
echo "OK [15]"

# ── [16] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[16] o doctor chama a triagem barata, publica contagem por classe e não varre universo vazio"
F16="$(lab_triagem f16)"
out16="$(cd "$F16" && FORGE_ROOT="$F16" bash "$DOCTOR" --report 2>&1 || true)"
linha16=""
while IFS= read -r l; do
  case "$l" in *"triagem de worktrees"*) linha16="$l"; break ;; esac
done <<EOF_DOC
$out16
EOF_DOC
[ -n "$linha16" ] \
  || { echo "FAIL [16]: o doctor não publica a triagem de worktrees — triagem que ninguém chama é LDG-0160 de novo, e o defeito desta onda é de fiação por natureza"; exit 1; }
# O laboratório tem quatro worktrees linkadas, criadas por esta fixture e contadas por ela.
esperadas16="$(git -C "$F16" worktree list --porcelain | grep -c '^worktree ' || true)"
esperadas16=$((esperadas16 - 1))
[ "$esperadas16" -gt 0 ] \
  || { echo "FAIL [16]/universo-vazio — o laboratório não tem worktree linkada nenhuma, e qualquer contagem do doctor seria verdadeira por vacuidade"; exit 1; }
case "$linha16" in
  *" de $esperadas16 examinada"*) : ;;
  *) echo "FAIL [16]: o doctor publicou '$linha16' sobre um laboratório de $esperadas16 worktree(s) linkada(s) — a contagem publicada tem de ser a do universo que ele varreu"; exit 1 ;;
esac
case "$linha16" in
  *destacada=*|*"nao-verificado="*) : ;;
  *) echo "FAIL [16]: o doctor não publica contagem POR CLASSE (linha: '$linha16')"; exit 1 ;;
esac
case "$out16" in
  *"--triage"*) : ;;
  *) echo "FAIL [16]: o doctor não convida para a triagem completa — a forma barata omite o predicado de arquivo ignorado por custo medido, e quem lê precisa saber onde está o veredito completo"; exit 1 ;;
esac
echo "OK [16] — $linha16"

# ── [17] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[17] não-interferência: checkout comum no tronco e --detach deliberado dentro do território seguem intocados"
# 'core.hooksPath' é absoluto e comum, então este hook passa a rodar em TODO checkout de TODO
# worktree dos consumidores. O teste de '\$1 == quarenta zeros' é a peça que separa 'criação de
# worktree' de 'checkout comum', e sem um cenário que a exercite a mutação mais consequente da onda
# ficaria sem acusador.
F17="$(mkfx f17)"
git -C "$F17" checkout -q -b outra
git -C "$F17" checkout -q main
h17="$(head_de "$F17")"
[ "$h17" = "main" ] \
  || { echo "FAIL [17]: um checkout comum no tronco terminou em '$h17' — o hook está agindo fora da criação de worktree"; exit 1; }
n17="$(conta_wt_branches "$F17")"
[ "$n17" -eq 0 ] \
  || { echo "FAIL [17]: checkout comum no tronco fez nascer $n17 branch(es) wt/* — o hook roda em TODO checkout de TODO worktree do consumidor, e agir aqui polui o repositório inteiro"; exit 1; }
git -C "$F17" worktree add -q "$F17/.forge/worktrees/deliberada" -b feat/deliberada >/dev/null 2>&1
git -C "$F17/.forge/worktrees/deliberada" checkout -q --detach HEAD
h17b="$(head_de "$F17/.forge/worktrees/deliberada")"
[ "$h17b" = "DESTACADO" ] \
  || { echo "FAIL [17]: um '--detach' DELIBERADO dentro do território foi desfeito pelo hook (HEAD=$h17b) — o conserto é para a CRIAÇÃO da worktree, e reverter uma escolha explícita do operador depois é outra coisa"; exit 1; }
echo "OK [17]"

# ── [18] PBT do saneador ────────────────────────────────────────────────────────────────────────
scenario "[18] PBT do saneador: para basename gerado, ou nasce branch válida, ou o hook reporta o terceiro estado"
# O saneador mais a cascata formam um normalizador sobre espaço de entrada, que é onde a invariante 5
# manda gerar em vez de escolher três exemplos a dedo. A propriedade sob teste é a que importa para
# quem opera: o desfecho NUNCA é "HEAD destacado com rc 0" — ou o hook deu um nome que o próprio git
# aceita, ou ele disse em stderr que não conseguiu e saiu não-zero. As entradas misturam o que é
# legal em nome de diretório e ilegal em nome de ref: ponto e hífen iniciais, sufixo .lock, dois
# pontos consecutivos, til, circunflexo, dois-pontos, espaço e cadeias só de pontuação.
F18="$(mkfx f18)"
alfabeto='. - _ ~ ^ : @ { } a b 9 lock'
n18=0; ok18=0
i=1
while [ "$i" -le 14 ]; do
  # Gerador determinístico e reprodutível: o índice varre combinações do alfabeto problemático, de
  # modo que uma regressão dá sempre o mesmo caso, e o caso aparece na mensagem de falha.
  nome=""
  j=0
  for tok in $alfabeto; do
    j=$((j + 1))
    [ $(( (i * 7 + j * 3) % 4 )) -eq 0 ] && nome="$nome$tok"
  done
  case "$i" in
    1) nome=".$nome" ;;
    2) nome="-$nome" ;;
    3) nome="$nome.lock" ;;
    4) nome="..$nome" ;;
    5) nome="$nome com espaco" ;;
    6) nome="....." ;;
    7) nome="---" ;;
  esac
  [ -n "$nome" ] || nome="vazio$i"
  dir="$F18/.forge/worktrees/$nome"
  errpbt="$T/pbt-$i.err"
  git -C "$F18" worktree add -q "$dir" HEAD >/dev/null 2>"$errpbt"
  rcpbt=$?
  [ -d "$dir" ] || { i=$((i + 1)); continue; }
  n18=$((n18 + 1))
  hpbt="$(head_de "$dir")"
  if [ "$hpbt" != "DESTACADO" ]; then
    git -C "$F18" check-ref-format --branch "$hpbt" >/dev/null 2>&1 \
      || { echo "FAIL [18]: para o basename '$nome' o hook produziu a branch '$hpbt', que o próprio git recusa — o saneador entregou um nome inválido em vez de avançar a cascata"; exit 1; }
    ok18=$((ok18 + 1))
  else
    [ "$rcpbt" -ne 0 ] && [ -s "$errpbt" ] \
      || { echo "FAIL [18]: para o basename '$nome' a worktree ficou DESTACADA com rc $rcpbt e stderr $( [ -s "$errpbt" ] && echo 'presente' || echo 'VAZIO') — 'não consegui dar nome' precisa ser um desfecho visível, nunca um silêncio com código zero"; exit 1; }
    ok18=$((ok18 + 1))
  fi
  i=$((i + 1))
done
[ "$n18" -ge 10 ] \
  || { echo "FAIL [18]/universo-vazio — só $n18 entrada(s) gerada(s) chegaram a criar worktree; a propriedade não foi exercida sobre espaço de entrada nenhum"; exit 1; }
echo "OK [18] — $ok18/$n18 entrada(s) gerada(s) com desfecho legítimo"

# ── [19] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[19] sem ref de integração no repositório, NADA vira 'mergeada'"
# A saída fácil para "não achei develop, main nem master" é cair em HEAD, e ela é a pior possível:
# toda worktree é ancestral de si mesma, toda worktree vira mergeada, e a triagem passa a PROPOR
# remoção de árvore viva com rc 0. É o mesmo falso-verde que a classe 'nao-verificado' existe para
# impedir, entrando por uma porta que ninguém olha.
F19="$(mkfx f19)"
git -C "$F19" branch -m main trabalho
git -C "$F19" worktree add -q "$F19/.forge/worktrees/sem-ref" -b feat/sem-ref >/dev/null 2>&1
tri19="$(bash "$RECONCILE" --root "$F19" --triage 2>&1 || true)"
c19="$(classe_de "$tri19" "$F19/.forge/worktrees/sem-ref" || true)"
[ -n "$c19" ] || { echo "FAIL [19]: a triagem não classificou a worktree do repositório sem ref de integração (saída: '$tri19')"; exit 1; }
[ "$c19" = "nao-verificado" ] \
  || { echo "FAIL [19]: sem develop, main ou master no repositório a triagem respondeu '$c19' — sem ref de integração não existe veredito de 'mergeada', e propor remoção aqui destruiria árvore viva"; exit 1; }
case "$tri19" in
  *"worktree remove"*) echo "FAIL [19]: a triagem propôs remoção num repositório onde ela não consegue decidir o que está mergeado (saída: '$tri19')"; exit 1 ;;
  *) : ;;
esac
echo "OK [19] — classe: $c19"

# ── laboratório da população do post-merge ──────────────────────────────────────────────────────
# Duas fixtures IDÊNTICAS que diferem apenas pela presença do hook sob teste: é o controle e o
# efeito no mesmo cenário. Cada uma recebe duas worktrees mergeadas e limpas — uma que NASCERIA
# destacada (o perfil de diagnóstico, `--detach`) e uma que o operador nomeou.
lab_pop() {  # lab_pop <nome> <com-hook|sem-hook> -> ecoa <dir>
  local d="$T/$1"
  mkdir -p "$d/.forge/worktrees" "$d/hooks"
  git init -q -b main "$d"
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  git -C "$d" config commit.gpgsign false
  [ "$2" = com-hook ] && cp "$HOOK_CANONICO" "$d/hooks/post-checkout"
  git -C "$d" config core.hooksPath "$d/hooks"
  printf '.forge/worktrees/\n' > "$d/.gitignore"
  printf 'x\n' > "$d/a.txt"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -qm base >/dev/null 2>&1
  git -C "$d" worktree add -q --detach "$d/.forge/worktrees/diag" HEAD >/dev/null 2>&1
  git -C "$d" checkout -q -b feat/nomeada
  printf 'y\n' > "$d/b.txt"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -qm feat >/dev/null 2>&1
  git -C "$d" checkout -q main
  git -C "$d" merge -q --no-ff feat/nomeada -m merge >/dev/null 2>&1
  git -C "$d" worktree add -q "$d/.forge/worktrees/nomeada" feat/nomeada >/dev/null 2>&1
  printf '%s\n' "$d"
}
conta_linkadas() {  # conta_linkadas <repo> -> worktrees linkadas (sem o checkout principal)
  local n
  n="$(git -C "$1" worktree list --porcelain 2>/dev/null | awk '/^worktree /{c++} END{print c+0}')"
  printf '%s\n' "$((n - 1))"
}

# ── [20] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[20] o conserto NÃO amplia a população que o post-merge remove: mesma remoção, ou menor"
# O achado mais grave desta onda não está no código novo, está no efeito dele sobre um hook que ela
# não escreveu. O `post-merge` nunca tocou worktree destacada porque `rev-parse --abbrev-ref HEAD`
# devolvia literalmente `HEAD` e ela caía fora do laço — as worktrees de diagnóstico eram imunes por
# ESTRUTURA. Dar branch a todas elas desarmaria esse filtro, e uma onda cujo propósito declarado é
# não perder trabalho passaria a alargar o alcance da única peça do harness que destrói. Este
# cenário mede controle e efeito lado a lado, com o opt-in de remoção LIGADO, que é o pior caso.
POP_SEM="$(lab_pop pop-sem sem-hook)"
POP_COM="$(lab_pop pop-com com-hook)"
h20="$(head_de "$POP_COM/.forge/worktrees/diag")"
[ "$h20" != "DESTACADO" ] \
  || { echo "FAIL [20]: na fixture COM hook a worktree de diagnóstico continuou destacada — sem o conserto não há ampliação a medir, e este cenário aprovaria por vacuidade"; exit 1; }
[ "$(head_de "$POP_SEM/.forge/worktrees/diag")" = "DESTACADO" ] \
  || { echo "FAIL [20]: na fixture SEM hook a worktree de diagnóstico NÃO ficou destacada — o controle não reproduz o estado de antes da onda"; exit 1; }
sem_antes="$(conta_linkadas "$POP_SEM")"; com_antes="$(conta_linkadas "$POP_COM")"
( cd "$POP_SEM" && FORGE_WORKTREE_AUTOCLEAN=1 bash "$POST_MERGE" >/dev/null 2>&1 )
( cd "$POP_COM" && FORGE_WORKTREE_AUTOCLEAN=1 bash "$POST_MERGE" >/dev/null 2>&1 )
sem_depois="$(conta_linkadas "$POP_SEM")"; com_depois="$(conta_linkadas "$POP_COM")"
rem_sem=$((sem_antes - sem_depois)); rem_com=$((com_antes - com_depois))
[ "$rem_sem" -ge 1 ] \
  || { echo "FAIL [20]/universo-vazio — o controle não removeu worktree nenhuma ($sem_antes -> $sem_depois), e 'a remoção não cresceu' seria verdade por o post-merge não remover nada nesta fixture"; exit 1; }
[ "$rem_com" -le "$rem_sem" ] \
  || { echo "FAIL [20]: com o hook o post-merge removeu $rem_com worktree(s) contra $rem_sem sem ele — a onda que existe para não perder trabalho ampliou a população da única peça do harness que destrói"; exit 1; }
[ -d "$POP_COM/.forge/worktrees/diag" ] \
  || { echo "FAIL [20]: a worktree de diagnóstico foi REMOVIDA pelo post-merge porque esta onda deu nome a ela — destacada, ela era imune por estrutura; nomeada, ela virou candidata, e ninguém pediu isso naquele merge"; exit 1; }
[ -d "$POP_SEM/.forge/worktrees/diag" ] \
  || { echo "FAIL [20]: o controle removeu a worktree destacada — o filtro de HEAD destacado do post-merge não está no estado que este cenário assume"; exit 1; }
[ ! -d "$POP_COM/.forge/worktrees/nomeada" ] \
  || { echo "FAIL [20]: a worktree mergeada, limpa e NOMEADA pelo operador deixou de ser removida com o opt-in ligado — a correção não pode desligar a limpeza que já existia, só impedir que ela cresça"; exit 1; }
echo "OK [20] — removidas sem o hook: $rem_sem; com o hook: $rem_com (a de diagnóstico sobreviveu nas duas)"

# ── [21] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[21] --triage --barato não afirma 'mergeada e de índice limpo' sobre estado indeterminado"
# O modo barato tem DUAS causas para `nao-verificado`: as refs de integração discordarem, e o
# predicado caro não ter sido executado. Explicá-las pelo MODO em vez de pela CAUSA faz a triagem
# afirmar que a worktree está mergeada e de índice limpo justamente onde ela não concluiu nem uma
# coisa nem outra — a invariante 2 dentro do terceiro estado que esta triagem existe para proteger.
F21="$(lab_triagem f21)"
git -C "$F21" checkout -q develop
git -C "$F21" reset -q --hard "HEAD~1"
tri21="$(bash "$RECONCILE" --root "$F21" --triage --barato 2>&1 || true)"
c21="$(classe_de "$tri21" "$F21/.forge/worktrees/suja" || true)"
[ "$c21" = "nao-verificado" ] \
  || { echo "FAIL [21]: no modo barato a worktree em disputa recebeu a classe '$c21' — o laboratório não reproduz a divergência de refs e o cenário não mede nada"; exit 1; }
# A explicação daquele bloco, e só dele: a leitura é por bloco porque o modo barato produz várias
# worktrees `nao-verificado` por causas diferentes, e casar na saída inteira não discriminaria.
bloco21=""; atual21=""
while IFS= read -r l; do
  case "$l" in
    *"  $F21/.forge/worktrees/suja") atual21=1 ;;
    "") atual21="" ;;
    *) [ -n "$atual21" ] && bloco21="$bloco21
$l" ;;
  esac
done <<EOF_B21
$tri21
EOF_B21
case "$bloco21" in
  *"índice limpo"*) echo "FAIL [21]: a triagem afirmou 'de índice limpo' sobre uma worktree cujo estado de merge é indeterminado e cujo 'git status' nunca chegou a rodar neste caminho (bloco: '$bloco21')"; exit 1 ;;
esac
case "$bloco21" in
  *"NÃO CONSEGUI VERIFICAR"*) : ;;
  *) echo "FAIL [21]: a triagem não nomeou a causa real do terceiro estado no modo barato (bloco: '$bloco21')"; exit 1 ;;
esac
# E a outra causa continua explicada pela explicação dela: a worktree mergeada e de índice limpo,
# no modo barato, é justamente o caso em que o predicado caro foi omitido.
c21b="$(classe_de "$tri21" "$F21/.forge/worktrees/limpa" || true)"
[ "$c21b" = "nao-verificado" ] \
  || { echo "FAIL [21]: a worktree mergeada e limpa recebeu '$c21b' no modo barato — sem o predicado caro não existe veredito de remoção segura, e a classe tem de ser o terceiro estado"; exit 1; }
case "$tri21" in
  *"o predicado de arquivo ignorado não foi executado neste modo"*) : ;;
  *) echo "FAIL [21]: a causa 'predicado omitido' deixou de ser explicada — as duas causas do terceiro estado precisam de explicações diferentes, não de uma só"; exit 1 ;;
esac
echo "OK [21]"

# ── [22] ────────────────────────────────────────────────────────────────────────────────────────
scenario "[22] worktree DESTACADA com trabalho não commitado torna a perda visível, e não só a falta de nome"
# A face 2 é a única que perde dado, e ela cai inteira nesta população: a classe `destacada` é
# decidida antes de qualquer predicado de sujeira, de modo que ela absorve `mergeada-suja` em
# silêncio. Dizer "sem branch" e calar sobre o arquivo que a remoção apaga é informar a metade
# barata do problema exatamente onde a metade cara importa.
F22="$(mkfx f22)"
git -C "$F22" worktree add -q --detach "$F22/.forge/worktrees/dsuja" HEAD >/dev/null 2>&1
git -C "$F22/.forge/worktrees/dsuja" checkout -q --detach HEAD 2>/dev/null || true
printf 'trabalho-nao-commitado\n' > "$F22/.forge/worktrees/dsuja/segredo.txt"
h22="$(head_de "$F22/.forge/worktrees/dsuja")"
[ "$h22" = "DESTACADO" ] \
  || { echo "FAIL [22]: o laboratório não produziu worktree destacada (HEAD=$h22) — sem ela o cenário não mede a população onde a perda acontece"; exit 1; }
[ -n "$(git -C "$F22/.forge/worktrees/dsuja" status --porcelain)" ] \
  || { echo "FAIL [22]: o laboratório não produziu trabalho não commitado — 'a triagem não mostra a sujeira' seria verdade por vacuidade"; exit 1; }
tri22="$(bash "$RECONCILE" --root "$F22" --triage 2>&1 || true)"
c22="$(classe_de "$tri22" "$F22/.forge/worktrees/dsuja" || true)"
[ "$c22" = "destacada" ] \
  || { echo "FAIL [22]: a classe da worktree destacada e suja mudou para '$c22' — o vocabulário de seis nomes é contrato publicado e não cresce aqui"; exit 1; }
case "$tri22" in
  *segredo.txt*) : ;;
  *) echo "FAIL [22]: a triagem não nomeou o arquivo não commitado da worktree destacada (saída: '$tri22') — 'git worktree remove --force' e 'rm -rf' apagam esse arquivo, e ele é a face do problema que branch nenhuma resolve"; exit 1 ;;
esac
case "$tri22" in
  *"NÃO COMMITADO"*) : ;;
  *) echo "FAIL [22]: a triagem não diz que há trabalho não commitado na worktree destacada (saída: '$tri22')"; exit 1 ;;
esac
case "$tri22" in
  *"resgatar ANTES de remover"*) : ;;
  *) echo "FAIL [22]: a triagem não oferece o resgate para a worktree destacada e suja (saída: '$tri22') — a D5 promete o resgate a um comando copiável de distância, e é aqui que ele falta"; exit 1 ;;
esac
echo "OK [22] — classe: $c22, com a sujeira nomeada"

# ── [23] contador de controle ───────────────────────────────────────────────────────────────────
scenario "[23] contador de controle: N cenários declarados, N executados"
[ "$SCENARIOS_RUN" -eq "$SCENARIOS_DECLARED" ] \
  || { echo "FAIL [23]: $SCENARIOS_RUN cenário(s) executado(s) contra $SCENARIOS_DECLARED declarado(s) — um gate que não sabe quantas condições examinou aprova por não ter olhado"; exit 1; }
echo "OK [23] — $SCENARIOS_RUN/$SCENARIOS_DECLARED cenário(s)"

echo "PASS w210-worktree-branch-obrigatoria ($SCENARIOS_RUN/$SCENARIOS_DECLARED)"
