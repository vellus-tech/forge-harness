#!/usr/bin/env bash
# Gate W213 — nenhum teste da suíte usa arquivo RASTREADO da árvore real como fixture (LDG-0179).
#
# O defeito da classe: seis arquivos de `tests/` mutavam um arquivo rastreado da árvore de trabalho,
# mediam o efeito e restauravam no trap. A restauração depende de o processo sobreviver até o fim, e
# nenhuma sobrevive a `SIGKILL` — que é o modo de morte real desta máquina (LDG-0180, a suíte foi
# perdida quatro vezes num dia por pressão de memória, e o OOM killer entrega `SIGKILL`). Pior: três
# desses gates restauravam com `git checkout -- <arquivo>`, o que APAGA trabalho não commitado com o
# gate saindo verde — medido, e já custou uma implementação inteira nesta sessão.
#
# Este gate guarda DUAS propriedades distintas, por dois instrumentos que não se substituem:
#
#   FORMA  — cenários [1] a [4]: detector estático sobre `git ls-files tests/`, que resolve o alvo de
#            cada porta de escrita por cadeia de atribuição e reprova quando ele cai na árvore
#            rastreada real. LIMITE ESTRUTURAL DECLARADO: o detector NÃO enxerga alvo montado em
#            tempo de execução (`eval`, indireção de nome de variável, caminho lido de arquivo), e
#            NÃO lê corpo de heredoc, que é texto emitido e não código deste arquivo. Ele é TRAVA DE
#            REGRESSÃO DE FORMA, jamais a rede da classe. O sítio histórico do LDG-0175 (`w146`
#            sobrescrevendo o runner do adotante) foi pego por um `git status` sujo na hora do
#            commit, não por varredura — e é essa a evidência de que a cegueira é real.
#
#            A máscara de heredoc não é conveniência: sem ela o detector é orientado a LINHA e acusa
#            este próprio arquivo duas vezes — as iscas de teste contêm, como TEXTO, linhas que
#            parecem escrita em rastreado — no instante em que o w213 entra no índice. O verde antes
#            da correção só existia porque o arquivo ainda não estava lá: um gate que passa por não
#            se olhar. Medido, e travado pelo par [3]/[4] mais a mutação (c) do [8], que confirma que
#            sem a máscara a isca de heredoc VOLTA a ser acusada.
#
#   EFEITO — cenários [6] e [7]: a sentinela dinâmica de `lib/arvore-rastreada.sh`, chamada pelos
#            dois runners antes e depois de cada gate. Ela é infalsificável quanto ao efeito (compara
#            o estado real da árvore rastreada, seja qual for o primitivo que o gate use) e é cega
#            quanto à forma: um gate que muta e restaura no fluxo feliz passa por ela — e é
#            exatamente esse gate que o `SIGKILL` corrompe. Por isso as duas peças, e não uma.
#
#            O [6] não para na biblioteca: ele mede se os TRÊS estados atravessam o sítio de adoção,
#            com controle (o idioma que morre mudo sob `set -e`) e tratamento (o que sai rc 3
#            nomeado). O [7] não para no caminho feliz: mede também o runner do adotante SEM
#            repositório git, que é onde ele prometia aviso em comentário e entregava verde
#            silencioso. Nenhum dos dois depende de premissa de ambiente — em particular, o
#            runner-fixture do [7] ganha uma suíte bats trivial em vez de esconder o `bats` num PATH
#            restrito, porque o CI instala o bats em `/usr/bin`, dentro daquele PATH, e a premissa
#            quebraria SEMPRE no caminho feliz do CI.
#
# O cenário [5] é o que prova que a conversão fecha a janela, e ele carrega TRÊS iscas, não duas: a
# defeituosa (muta o rastreado e restaura no trap), a corrigida (muta uma cópia) e a VAZIA. A isca
# vazia existe porque `rc 8 — janela nunca alcançada` é asserção negativa e é satisfeita por
# vacuidade: um alvo que não executa nada devolve o mesmo `rc 8` com a árvore limpa que o alvo
# corrigido. O verde do [5] exige o trio — `rc 8`, árvore limpa E o marcador de execução gravado
# pela isca corrigida — e reprova se o critério aceitar a isca vazia.
#
# O cenário [8] é a prova de mutação, sobre CÓPIAS em `$T` da biblioteca e do detector: este gate não
# pode reintroduzir a classe que ele existe para fechar.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w213.XXXXXX")"
trap 'rm -rf "$T"' EXIT

LIB="$WS/template/.forge/scripts/lib/arvore-rastreada.sh"
RUNNER_SUITE="$WS/tests/run-all.sh"
RUNNER_ADOTANTE="$WS/template/.forge/scripts/tests/run-all.sh"

CENARIOS_DECLARADOS=8
executados=0
falhou=0

_sha() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  else
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
  fi
}
_falha() { echo "FAIL $*"; falhou=1; }
_git_fx() { git -c user.email=w213@forge.local -c user.name=w213 -C "$1" "${@:2}"; }

# ── o detector estático, emitido em $T ────────────────────────────────────────────────────────────
DET="$T/detector.pl"
cat > "$DET" <<'PERL'
#!/usr/bin/perl
# Detector estático de escrita em arquivo RASTREADO da árvore real, a partir do texto de um script.
# LIMITE ESTRUTURAL: resolve variáveis por cadeia de atribuição literal; não enxerga alvo montado em
# tempo de execução. Não é a rede da classe — a rede é a sentinela dinâmica nos runners.
#
# CORPO DE HEREDOC NÃO É CÓDIGO DESTE ARQUIVO. Um gate que emite uma isca com `cat > "$T/x" <<'EOF'`
# grava TEXTO em $T; as linhas do corpo só executam se e quando a isca rodar, e o alvo delas resolve
# na árvore da isca, não na deste arquivo. Sem essa distinção o detector é orientado a linha e acusa
# o próprio w213 duas vezes — medido: linha 221 (`cp "$T/copia" "$ALVO"` dentro da isca positiva) e
# linha 432 (`printf ... >> "$WS/alvo.txt"` dentro do gate-isca do cenário [7]) — no instante em que
# o w213 entra no índice, isto é, no primeiro commit da onda. A máscara vale para as DUAS passagens:
# a que colhe atribuições e a que procura portas de escrita, porque `ALVO=...` dentro de um heredoc
# também não é atribuição deste arquivo. A LINHA DE ABERTURA continua sendo código e continua sendo
# examinada: `cat > "$ALVO" <<'EOF'` é uma escrita real em $ALVO e tem de ser acusada.
use strict;
use warnings;

# heredoc_mask(\@linhas) -> lista de 0/1, 1 = a linha é CORPO de heredoc (nem código, nem atribuição)
sub heredoc_mask {
  my ($lines) = @_;
  my @mask = (0) x scalar(@$lines);
  my @pend;
  my $cur;
  for my $i (0 .. $#$lines) {
    my $l = $lines->[$i];
    if (defined $cur) {
      my $d = $cur->{delim};
      my $fim = $cur->{dash} ? qr/^\s*\Q$d\E\s*$/ : qr/^\Q$d\E\s*$/;
      if ($l =~ $fim) { $cur = @pend ? shift(@pend) : undef; }
      else { $mask[$i] = 1; }
      next;
    }
    my $c = $l;
    $c =~ s/^\s*#.*$//;                      # comentário de linha inteira não abre heredoc
    while ($c =~ /<<(-?)\s*(?!<)(["']?)([A-Za-z_][A-Za-z0-9_]*)\2/g) {
      push @pend, { delim => $3, dash => ($1 eq '-') };
    }
    $cur = shift(@pend) if @pend;
  }
  return @mask;
}

sub classify {
  my ($s) = @_;
  return 'SANDBOX' if $s =~ /mktemp|TMPDIR|\/tmp\//;
  return 'REAL'    if $s =~ /BASH_SOURCE/;
  return 'DESCONHECIDO';
}

sub varname {
  my ($tok) = @_;
  return undef unless defined $tok;
  return $1 if $tok =~ /\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?/;
  return undef;
}

sub tokenize {
  my ($tail) = @_;
  my @out;
  while ($tail =~ /\G\s*("(?:[^"\\]|\\.)*"|'[^']*'|[^\s;|&)]+)/gc) {
    my $t = $1;
    $t =~ s/^["']//;
    $t =~ s/["']$//;
    push @out, $t;
  }
  return @out;
}

my $hits = 0;
my $arquivos = 0;
for my $file (@ARGV) {
  open(my $fh, '<', $file) or next;
  my @lines = <$fh>;
  close $fh;
  $arquivos++;

  my @mask = heredoc_mask(\@lines);

  my %assign;
  for my $i (0 .. $#lines) {
    next if $mask[$i];
    my $l = $lines[$i];
    next if $l =~ /^\s*#/;
    if ($l =~ /^\s*(?:local\s+|export\s+|readonly\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$/) {
      my ($n, $v) = ($1, $2);
      $assign{$n} = $v unless exists $assign{$n};
    }
  }

  my $resolve = sub {
    my ($name) = @_;
    my $cur = exists $assign{$name} ? $assign{$name} : "\$$name";
    for (1 .. 8) {
      my $before = $cur;
      $cur =~ s/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/exists $assign{$1} ? $assign{$1} : "\$\{$1\}"/ge;
      $cur =~ s/\$([A-Za-z_][A-Za-z0-9_]*)/exists $assign{$1} ? $assign{$1} : "\$$1"/ge;
      last if $cur eq $before;
    }
    return $cur;
  };

  for my $i (0 .. $#lines) {
    next if $mask[$i];
    my $l = $lines[$i];
    next if $l =~ /^\s*#/;
    chomp(my $raw = $l);
    my @alvos;

    while ($raw =~ /(?<![0-9&<>\-])>>?\s*("?)(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?[^\s"'`;)&|]*)\1/g) {
      push @alvos, [$2, 'redirecionamento'];
    }
    if ($raw =~ /(?:^|[;&|`]|\$\(|\bthen\b|\bdo\b|\{)\s*(cp|mv|install|ln)\b(.*)$/) {
      my ($verbo, $tail) = ($1, $2);
      my @t = grep { !/^-/ } tokenize($tail);
      push @alvos, [$t[-1], $verbo] if @t;
    }
    if ($raw =~ /(?:^|[;&|`]|\$\(|\bthen\b|\bdo\b|\{)\s*(rm|touch|tee)\b(.*)$/) {
      my ($verbo, $tail) = ($1, $2);
      for my $t (grep { !/^-/ } tokenize($tail)) { push @alvos, [$t, $verbo]; }
    }
    if ($raw =~ /(?:^|[;&|`]|\$\(|\bthen\b|\bdo\b|\{)\s*(sed|perl)\s+(?:[^|;']*\s)?-i\b(.*)$/) {
      my ($verbo, $tail) = ($1, $2);
      for my $t (grep { !/^-/ } tokenize($tail)) { push @alvos, [$t, "$verbo -i"]; }
    }
    if ($raw =~ /\bgit\b[^|;]*\bcheckout\b\s+--\s+(.*)$/) {
      my $tail = $1;
      for my $t (tokenize($tail)) { push @alvos, [$t, 'git checkout --']; }
    }

    for my $a (@alvos) {
      my ($tok, $porta) = @$a;
      next unless defined $tok;
      next if $tok =~ m{^/dev/};
      my $v = varname($tok);
      next unless defined $v;
      my $res = $resolve->($v);
      my $cls = classify($res);
      next unless $cls eq 'REAL';
      $hits++;
      printf("HIT %s:%d: \$%s (%s) resolve para a árvore rastreada real\n", $file, $i + 1, $v, $porta);
    }
  }
}
printf("EXAMINADOS %d\n", $arquivos);
printf("ACUSADOS %d\n", $hits);
exit(0);
PERL
cp "$DET" "$T/detector.pristine.pl"

_detectar() { # _detectar <saida> <arquivo...>
  local saida="$1"; shift
  perl "$DET" "$@" > "$saida" 2>&1
}

# ══ [1] nenhum arquivo de tests/ escreve em arquivo rastreado da árvore real ══════════════════════
echo "[1] nenhum arquivo de tests/ escreve em arquivo rastreado da árvore real"
executados=$((executados + 1))
UNIV=()
while IFS= read -r _f; do
  [ -n "$_f" ] && UNIV+=("$WS/$_f")
done < <(git -C "$WS" ls-files tests/ 2>/dev/null)
PISO="${#UNIV[@]}"
if [ "$PISO" -eq 0 ]; then
  _falha "[1] universo-vazio: 'git ls-files tests/' devolveu zero arquivo — o denominador não pode ser derivado"
else
  _detectar "$T/hits1.txt" "${UNIV[@]}"
  n_hits1="$(grep -c '^HIT ' "$T/hits1.txt")"
  if [ "${n_hits1:-0}" -ne 0 ]; then
    _falha "[1] $n_hits1 porta(s) de escrita em arquivo rastreado da árvore real:"
    grep '^HIT ' "$T/hits1.txt" | sed 's/^/      /'
  else
    echo "OK [1] — nenhuma porta de escrita em arquivo rastreado nos $PISO arquivos de tests/"
  fi
fi

# ══ [2] contador de controle do universo ═════════════════════════════════════════════════════════
echo "[2] contador de controle — o detector leu o universo inteiro"
executados=$((executados + 1))
if [ "$PISO" -eq 0 ]; then
  _falha "[2] universo-vazio: sem piso derivado, o [1] seria satisfeito por vacuidade"
else
  exam1="$(sed -n 's/^EXAMINADOS //p' "$T/hits1.txt" | tail -1)"
  if [ "${exam1:-0}" -ne "$PISO" ]; then
    _falha "[2] o detector examinou ${exam1:-0} arquivo(s) e o universo derivado tem $PISO — o [1] leria menos do que afirma"
  else
    echo "OK [2] — $exam1 arquivo(s) examinado(s), igual ao piso derivado de 'git ls-files tests/' ($PISO)"
  fi
fi

# ══ [3] isca positiva — o detector ACUSA quem muta rastreado ═════════════════════════════════════
echo "[3] isca positiva — um arquivo que muta caminho rastreado é acusado"
executados=$((executados + 1))
cat > "$T/isca-positiva.sh" <<'ISCA'
#!/usr/bin/env bash
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
ALVO="$WS/template/.forge/scripts/lib/ledger-render.mjs"
cp "$ALVO" "$T/copia"
cp "$T/copia" "$ALVO"
ISCA
_detectar "$T/hits3.txt" "$T/isca-positiva.sh"
n_hits3="$(grep -c '^HIT ' "$T/hits3.txt")"
if [ "${n_hits3:-0}" -lt 1 ]; then
  _falha "[3] a isca positiva NÃO foi acusada — o [1] é asserção negativa satisfeita por vacuidade"
else
  echo "OK [3] — isca positiva acusada em $n_hits3 porta(s)"
fi

# ══ [4] isca negativa — o detector NÃO acusa quem só muta em $T ══════════════════════════════════
echo "[4] isca negativa — um arquivo que só muta sob \$T não é acusado"
executados=$((executados + 1))
cat > "$T/isca-negativa.sh" <<'ISCA'
#!/usr/bin/env bash
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
ALVO="$WS/template/.forge/scripts/lib/ledger-render.mjs"
COPIA="$T/ledger-render.mjs"
cp "$ALVO" "$COPIA"
printf 'lixo\n' >> "$COPIA"
sed -i.bak 's/x/y/' "$COPIA"
rm -f "$COPIA.bak"
ISCA
_detectar "$T/hits4.txt" "$T/isca-negativa.sh"
n_hits4="$(grep -c '^HIT ' "$T/hits4.txt")"
if [ "${n_hits4:-0}" -ne 0 ]; then
  _falha "[4] a isca negativa foi acusada em $n_hits4 porta(s) — um detector que acusa tudo satisfaria o [3] e seria inútil:"
  grep '^HIT ' "$T/hits4.txt" | sed 's/^/      /'
else
  echo "OK [4] — isca negativa não acusada"
fi

# Isca de HEREDOC: um arquivo cujas ÚNICAS linhas que parecem escrita em rastreado estão dentro do
# corpo de um heredoc. Elas são texto que o arquivo grava em $T, não código que ele executa, e um
# detector orientado a linha as acusa — foi assim que o próprio w213 se acusou duas vezes no instante
# em que entrou no índice. O par com o [3] é o que impede a correção de virar cegueira: o [3] exige
# que a escrita REAL continue acusada, esta exige que o TEXTO não seja.
cat > "$T/isca-heredoc.sh" <<'ISCA'
#!/usr/bin/env bash
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
cat > "$T/emitida.sh" <<'DENTRO'
ALVO="$WS/template/.forge/scripts/lib/ledger-render.mjs"
cp "$T/copia" "$ALVO"
printf 'sujeira
' >> "$WS/alvo.txt"
DENTRO
bash "$T/emitida.sh"
ISCA
_detectar "$T/hits4h.txt" "$T/isca-heredoc.sh"
n_hits4h="$(grep -c '^HIT ' "$T/hits4h.txt")"
if [ "${n_hits4h:-0}" -ne 0 ]; then
  _falha "[4] a isca de heredoc foi acusada em $n_hits4h porta(s) — o detector lê corpo de heredoc como código e acusa o próprio w213 no primeiro commit:"
  grep '^HIT ' "$T/hits4h.txt" | sed 's/^/      /'
else
  echo "OK [4] — isca de heredoc não acusada: corpo de heredoc é texto, não código deste arquivo"
fi

# ══ [5] sobrevivência a sinal — controle, recontrole e controle de vacuidade ═════════════════════
echo "[5] sobrevivência a sinal — isca defeituosa, isca corrigida e isca VAZIA"
executados=$((executados + 1))
FXR="$T/repo-sinal"
mkdir -p "$FXR"
git init -q "$FXR" >/dev/null 2>&1
printf 'linha original\n' > "$FXR/alvo.txt"
_git_fx "$FXR" add -A >/dev/null 2>&1
_git_fx "$FXR" commit -qm "fixture" >/dev/null 2>&1

cat > "$T/isca-defeituosa.sh" <<'ISCA'
#!/usr/bin/env bash
R="$1"; MARC="$2"
trap 'git -C "$R" checkout -- alvo.txt' EXIT
printf 'MUTADO PELO GATE\n' > "$R/alvo.txt"
sleep 3
printf 'defeituosa-terminou\n' > "$MARC"
ISCA

cat > "$T/isca-corrigida.sh" <<'ISCA'
#!/usr/bin/env bash
R="$1"; MARC="$2"
B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT
cp "$R/alvo.txt" "$B/alvo.txt"
cmp -s "$R/alvo.txt" "$B/alvo.txt" || exit 3
printf 'MUTADO PELO GATE\n' > "$B/alvo.txt"
cmp -s "$R/alvo.txt" "$B/alvo.txt" && exit 4
printf 'corrigida-executou\n' > "$MARC"
ISCA

cat > "$T/isca-vazia.sh" <<'ISCA'
#!/usr/bin/env bash
exit 0
ISCA

_atacar() { # _atacar <isca> <repo> <sinal> <marcador> -> ecoa "<DESFECHO> rc=<n> sujo=<0|1>"
  local isca="$1" repo="$2" sinal="$3" marc="$4"
  local sha0 shan i pid rc janela sujo
  rm -f "$marc"
  _git_fx "$repo" checkout -- . >/dev/null 2>&1
  sha0="$(_sha "$repo/alvo.txt")"
  bash "$isca" "$repo" "$marc" >/dev/null 2>&1 &
  pid=$!
  janela=0
  i=0
  while [ "$i" -lt 60 ]; do
    shan="$(_sha "$repo/alvo.txt")"
    if [ "$shan" != "$sha0" ]; then janela=1; break; fi
    kill -0 "$pid" 2>/dev/null || break
    i=$((i + 1))
    sleep 0.1
  done
  if [ "$janela" -eq 1 ]; then
    kill -"$sinal" "$pid" >/dev/null 2>&1
  fi
  wait "$pid" >/dev/null 2>&1
  rc=$?
  sujo=0
  [ -n "$(git -C "$repo" status --porcelain -uno 2>/dev/null)" ] && sujo=1
  if [ "$janela" -eq 0 ]; then
    echo "RC8 rc=$rc sujo=$sujo"
  elif [ "$sujo" -eq 1 ]; then
    echo "CORROMPIDO rc=$rc sujo=$sujo"
  else
    echo "RESTAURADO rc=$rc sujo=$sujo"
  fi
}

d_kill="$(_atacar "$T/isca-defeituosa.sh" "$FXR" KILL "$T/marc-def-kill")"
d_term="$(_atacar "$T/isca-defeituosa.sh" "$FXR" TERM "$T/marc-def-term")"
c_kill="$(_atacar "$T/isca-corrigida.sh" "$FXR" KILL "$T/marc-cor-kill")"
v_kill="$(_atacar "$T/isca-vazia.sh" "$FXR" KILL "$T/marc-vazia")"
_git_fx "$FXR" checkout -- . >/dev/null 2>&1

echo "    defeituosa/KILL : $d_kill"
echo "    defeituosa/TERM : $d_term"
echo "    corrigida/KILL  : $c_kill"
echo "    vazia/KILL      : $v_kill"

case "$d_kill" in
  CORROMPIDO*) echo "OK [5] controle — a isca defeituosa sob SIGKILL deixa o rastreado da fixture sujo" ;;
  *) _falha "[5] controle: a isca defeituosa sob SIGKILL deveria CORROMPER — got '$d_kill'; sem ela o verde não distingue proteção de ataque que não aconteceu" ;;
esac
case "$d_term" in
  RESTAURADO*) echo "OK [5] recontrole — a mesma isca sob SIGTERM restaura, então a janela existe e o harness a alcança" ;;
  *) _falha "[5] recontrole: a isca defeituosa sob SIGTERM deveria RESTAURAR — got '$d_term'" ;;
esac

# O verde exige o TRIO: rc 8, árvore limpa e o marcador de execução da isca corrigida.
cor_ok=0
case "$c_kill" in
  "RC8 rc=0 sujo=0") [ -s "$T/marc-cor-kill" ] && cor_ok=1 ;;
esac
if [ "$cor_ok" -eq 1 ]; then
  echo "OK [5] corrigida — rc 8 (janela nunca alcançada) + árvore limpa + marcador de execução presente"
else
  _falha "[5] corrigida: esperava 'RC8 rc=0 sujo=0' COM marcador de execução — got '$c_kill', marcador '$( [ -s "$T/marc-cor-kill" ] && echo presente || echo ausente)'"
fi

# Controle de vacuidade: a isca VAZIA produz o mesmo rc 8 com árvore limpa, e tem de ser REJEITADA.
vazia_ok=0
case "$v_kill" in
  "RC8 rc=0 sujo=0") [ -s "$T/marc-vazia" ] && vazia_ok=1 ;;
esac
if [ "$vazia_ok" -eq 1 ]; then
  _falha "[5] vacuidade: a isca VAZIA satisfez o critério do verde — 'rc 8' sozinho não distingue 'não existe janela' de 'não executou nada'"
else
  case "$v_kill" in
    RC8*) echo "OK [5] vacuidade — a isca vazia devolve o mesmo '$v_kill' e é rejeitada por não ter marcador de execução" ;;
    *) _falha "[5] vacuidade: a isca vazia deveria devolver RC8 — got '$v_kill'" ;;
  esac
fi

# ══ [6] a sentinela discrimina — três estados, nunca dois ════════════════════════════════════════
echo "[6] a sentinela discrimina — rc 0 sem mudança, rc 1 com mudança, rc 3 sem poder medir"
executados=$((executados + 1))
if [ ! -f "$LIB" ]; then
  _falha "[6] a biblioteca '$LIB' não existe — a sentinela não pode ser conferida"
else
  cp "$LIB" "$T/arvore-rastreada.sh"
  cp "$LIB" "$T/arvore-rastreada.pristine.sh"
  _rodar_sentinela() { # _rodar_sentinela <lib> <repo> <snapshot> -> ecoa rc
    local lib="$1" repo="$2" snap="$3" rc
    bash -c '. "$1" && arvore_confere "$2" "$3" "w213" >/dev/null 2>&1' _ "$lib" "$repo" "$snap"
    rc=$?
    echo "$rc"
  }
  _snapshot() { # _snapshot <lib> <repo> [modo]
    bash -c '. "$1" && arvore_snapshot "$2" "${3:-rastreados}" 2>/dev/null' _ "$1" "$2" "${3:-rastreados}"
  }
  mkdir -p "$T/nao-e-repo"
  SNAP0="$(_snapshot "$T/arvore-rastreada.sh" "$FXR")"
  rc6a="$(_rodar_sentinela "$T/arvore-rastreada.sh" "$FXR" "$SNAP0")"
  printf 'sujeira do cenario 6\n' >> "$FXR/alvo.txt"
  rc6b="$(_rodar_sentinela "$T/arvore-rastreada.sh" "$FXR" "$SNAP0")"
  _git_fx "$FXR" checkout -- . >/dev/null 2>&1
  rc6c="$(_rodar_sentinela "$T/arvore-rastreada.sh" "$T/nao-e-repo" "$SNAP0")"
  snap_nao_repo="$(_snapshot "$T/arvore-rastreada.sh" "$T/nao-e-repo")"
  echo "    rc sem mudança=$rc6a  rc com mudança=$rc6b  rc fora de repositório=$rc6c"
  [ "$rc6a" = "0" ] || _falha "[6] sem mudança na árvore rastreada a sentinela deveria devolver rc 0 — got $rc6a"
  [ "$rc6b" = "1" ] || _falha "[6] com mudança na árvore rastreada a sentinela deveria devolver rc 1 — got $rc6b"
  [ "$rc6c" = "3" ] || _falha "[6] fora de repositório git a sentinela deveria devolver rc 3 ('não consegui verificar' nunca colapsa em 'não encontrei violação') — got $rc6c"
  [ "$snap_nao_repo" = "__ARVORE_NAO_MEDIDA__" ] || _falha "[6] o snapshot não medido deveria valer a marca __ARVORE_NAO_MEDIDA__ e não string vazia — got '${snap_nao_repo}'"
  [ "$rc6a" = "0" ] && [ "$rc6b" = "1" ] && [ "$rc6c" = "3" ] && echo "OK [6] — três estados distintos"

  # Os três estados TÊM DE ATRAVESSAR O SÍTIO DE ADOÇÃO. A biblioteca os implementa com cuidado e o
  # gate adotante os desfazia de duas maneiras, as duas medidas em árvore sem `.git`:
  #   (a) `X="$(arvore_snapshot "$WS")"` sob `set -e` herda o rc 3 e MATA o gate ali, antes de
  #       qualquer echo — rc 3 com log de ZERO byte, sem nome e sem motivo. Cinco gates adotantes
  #       morreram assim, e dois deles (w199 e gate-assert-visibility) saíam rc 0 antes da adoção.
  #   (b) `arvore_confere ... || { echo "a árvore mudou"; exit 1; }` colapsa rc 1 e rc 3 no mesmo
  #       `||` e imprime a acusação FALSA de que a árvore mudou quando o que houve foi não medir.
  # O par abaixo é controle (idioma defeituoso) e tratamento (idioma corrigido) sobre a MESMA bancada
  # fora de repositório: sem o controle, o verde do tratamento não distinguiria correção de ataque
  # que não aconteceu.
  _sitio() { # _sitio <arquivo> <idioma>  -> escreve um gate adotante mínimo, sob `set -euo pipefail`
    if [ "$2" = "defeituoso" ]; then
      cat > "$1" <<'SITIO'
#!/usr/bin/env bash
set -euo pipefail
. "$1"
ANTES="$(arvore_snapshot "$2")"
echo "corpo do gate rodou"
arvore_confere "$2" "$ANTES" "sitio" || { echo "FAIL sentinela: a árvore rastreada do repositório mudou durante o gate"; exit 1; }
SITIO
    else
      cat > "$1" <<'SITIO'
#!/usr/bin/env bash
set -euo pipefail
. "$1"
ANTES="$(arvore_retrato "$2")"
echo "corpo do gate rodou"
arvore_sentinela_fim "$2" "$ANTES" "sitio" || exit $?
SITIO
    fi
  }
  _sitio "$T/sitio-defeituoso.sh" defeituoso
  _sitio "$T/sitio-corrigido.sh" corrigido
  out6d="$(bash "$T/sitio-defeituoso.sh" "$T/arvore-rastreada.sh" "$T/nao-e-repo" 2>&1)"; rc6d=$?
  out6e="$(bash "$T/sitio-corrigido.sh" "$T/arvore-rastreada.sh" "$T/nao-e-repo" 2>&1)"; rc6e=$?
  echo "    sítio defeituoso: rc=$rc6d bytes=${#out6d} | sítio corrigido: rc=$rc6e bytes=${#out6e}"
  if [ "${#out6d}" -ne 0 ]; then
    _falha "[6] controle: o idioma defeituoso deveria morrer MUDO fora de repositório (é o defeito medido) — saiu com ${#out6d} byte(s); sem esse controle o verde do sítio corrigido não prova nada"
  else
    echo "OK [6] controle — o idioma defeituoso morre mudo (rc=$rc6d, zero byte), que é a regressão que o corrigido fecha"
  fi
  if [ "$rc6e" -ne 3 ]; then
    _falha "[6] o sítio corrigido deveria sair rc 3 (NÃO VERIFICADO) fora de repositório — got rc=$rc6e"
  elif [ "${#out6e}" -eq 0 ]; then
    _falha "[6] o sítio corrigido saiu rc 3 com log de ZERO byte — é a mesma morte muda com outro número"
  elif ! printf '%s\n' "$out6e" | grep -q 'NÃO VERIFICADO'; then
    _falha "[6] o sítio corrigido não nomeou 'NÃO VERIFICADO': $(printf '%s' "$out6e" | tail -1)"
  elif printf '%s\n' "$out6e" | grep -q 'MUDOU'; then
    _falha "[6] o sítio corrigido acusou a árvore de ter MUDADO quando o que houve foi não conseguir medir — acusação falsa: $(printf '%s' "$out6e" | tail -1)"
  else
    echo "OK [6] tratamento — o sítio corrigido sai rc 3 nomeando NÃO VERIFICADO, sem acusar mudança que não houve"
  fi

  # Trava estática do idioma: nenhum arquivo de tests/ pode voltar a ATRIBUIR de `arvore_snapshot`
  # sem capturar o rc. É a regressão exata do achado, e ela reentra por cópia-e-cola. O próprio w213
  # sai do universo desta trava porque ele CARREGA o idioma defeituoso de propósito, como texto: é o
  # controle do par acima, e sem ele o verde do tratamento não distinguiria correção de ataque que
  # não aconteceu. O w213 não tem sítio de adoção, então a exclusão não esconde nada.
  maus="$(grep -lF '="$(arvore_snapshot ' "$WS"/tests/*.sh 2>/dev/null | grep -v 'w213-arvore-rastreada-gate.sh' || true)"
  if [ -n "$maus" ]; then
    _falha "[6] atribuição direta de 'arvore_snapshot' (que herda o rc 3 e mata o gate mudo sob \`set -e\`); use 'arvore_retrato':"
    printf '%s\n' "$maus" | sed 's/^/      /'
  else
    echo "OK [6] — nenhum sítio de tests/ atribui direto de arvore_snapshot"
  fi
fi

# ══ [7] prova de INVOCAÇÃO nos dois runners, não de existência ═══════════════════════════════════
echo "[7] os dois runners chamam a sentinela — prova comportamental, não textual"
executados=$((executados + 1))
if [ ! -f "$LIB" ]; then
  _falha "[7] a biblioteca '$LIB' não existe — nenhum runner pode invocá-la"
else
  RFX="$T/runner-fx"
  mkdir -p "$RFX/tests" "$RFX/template/.forge/scripts/lib" "$RFX/template/.forge/scripts/tests"
  cp "$RUNNER_SUITE" "$RFX/tests/run-all.sh"
  cp "$LIB" "$RFX/template/.forge/scripts/lib/arvore-rastreada.sh"
  printf 'conteudo rastreado\n' > "$RFX/alvo.txt"
  cat > "$RFX/tests/aa-limpo-gate.sh" <<'GATEFX'
#!/usr/bin/env bash
D="$(mktemp -d)"
printf 'so no sandbox\n' > "$D/x"
rm -rf "$D"
echo "OK isca limpa"
GATEFX
  # Suíte bats trivial na fixture, e NÃO um PATH restrito.
  #
  # O runner copiado expande `"${BATS_SUITES[@]}"`, e um array vazio sob `set -u` no bash 3.2 aborta
  # o fixture inteiro. A primeira redação contornava isso escondendo o `bats` num
  # `PATH=/usr/bin:/bin:/usr/sbin:/sbin` e AFIRMAVA a premissa "bats é inalcançável aqui". A premissa
  # é falsa exatamente onde mais importa: o `ci.yml` instala o bats por `apt`, que o põe em
  # `/usr/bin/bats` — o primeiro diretório daquele PATH. O cenário reprovaria SEMPRE no caminho feliz
  # do CI e passaria no caminho degradado (fallback por npm, que instala fora de /usr/bin), que é a
  # inversão exata do que se quer. Medido com um `bats` postiço no PATH restrito: `FAIL [7] premissa
  # quebrada`, com todo o resto do gate verde.
  #
  # Dar à fixture uma suíte bats de um teste trivial resolve pelos DOIS lados e sem premissa nenhuma:
  # com bats instalado o array tem um elemento e a suíte roda; sem bats o runner entra no ramo
  # "bats indisponível" e nem expande o array. O cenário deixa de depender do ambiente.
  cat > "$RFX/tests/validators.bats" <<'BATSFX'
#!/usr/bin/env bats

@test "isca bats trivial (nome em ASCII puro: o bats 1.x quebra com acento no nome do teste)" {
  true
}
BATSFX
  git init -q "$RFX" >/dev/null 2>&1
  _git_fx "$RFX" add -A >/dev/null 2>&1
  _git_fx "$RFX" commit -qm "fixture do runner" >/dev/null 2>&1

  cat > "$RFX/tests/ab-sujo-gate.sh" <<'GATEFX'
#!/usr/bin/env bash
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf 'sujeira plantada pela isca\n' >> "$WS/alvo.txt"
echo "OK isca suja (o gate em si passa)"
GATEFX
  out7a="$(bash "$RFX/tests/run-all.sh" 2>&1)"
  rc7a=$?
  _git_fx "$RFX" checkout -- . >/dev/null 2>&1
  rm -f "$RFX/tests/ab-sujo-gate.sh"
  out7b="$(bash "$RFX/tests/run-all.sh" 2>&1)"
  rc7b=$?
  _git_fx "$RFX" checkout -- . >/dev/null 2>&1
  echo "    runner com gate que suja: rc=$rc7a | runner só com gate limpo: rc=$rc7b"
  if [ "$rc7a" -eq 0 ]; then
    _falha "[7] o runner da suíte APROVOU um gate que sujou a árvore rastreada — a sentinela não é invocada por gate:"
    printf '%s\n' "$out7a" | tail -8 | sed 's/^/      /'
  elif ! printf '%s\n' "$out7a" | grep -q 'sujou a árvore rastreada'; then
    _falha "[7] o runner reprovou, mas sem distinguir 'o gate reprovou' de 'o gate sujou a árvore rastreada':"
    printf '%s\n' "$out7a" | tail -8 | sed 's/^/      /'
  elif [ "$rc7b" -ne 0 ]; then
    _falha "[7] recontrole: sem o gate que suja, o runner deveria aprovar — rc=$rc7b:"
    printf '%s\n' "$out7b" | tail -8 | sed 's/^/      /'
  else
    echo "OK [7] runner da suíte — reprova o gate que suja nomeando a violação, aprova quando ele sai"
  fi

  # O runner do ADOTANTE: mesma prova, com a suíte de teste que ele enumera.
  AFX="$T/adotante-fx"
  mkdir -p "$AFX/.forge/scripts/tests" "$AFX/.forge/scripts/lib"
  cp "$RUNNER_ADOTANTE" "$AFX/.forge/scripts/tests/run-all.sh"
  cp "$LIB" "$AFX/.forge/scripts/lib/arvore-rastreada.sh"
  printf 'conteudo rastreado\n' > "$AFX/alvo.txt"
  cat > "$AFX/.forge/scripts/tests/limpo.test.sh" <<'GATEFX'
#!/usr/bin/env bash
D="$(mktemp -d)"
printf 'so no sandbox\n' > "$D/x"
rm -rf "$D"
GATEFX
  git init -q "$AFX" >/dev/null 2>&1
  _git_fx "$AFX" add -A >/dev/null 2>&1
  _git_fx "$AFX" commit -qm "fixture do adotante" >/dev/null 2>&1
  cat > "$AFX/.forge/scripts/tests/sujo.test.sh" <<'GATEFX'
#!/usr/bin/env bash
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
printf 'sujeira plantada pela isca\n' >> "$R/alvo.txt"
GATEFX
  out7c="$(bash "$AFX/.forge/scripts/tests/run-all.sh" 2>&1)"
  rc7c=$?
  _git_fx "$AFX" checkout -- . >/dev/null 2>&1
  rm -f "$AFX/.forge/scripts/tests/sujo.test.sh"
  out7d="$(bash "$AFX/.forge/scripts/tests/run-all.sh" 2>&1)"
  rc7d=$?
  _git_fx "$AFX" checkout -- . >/dev/null 2>&1
  echo "    runner do adotante com teste que suja: rc=$rc7c | só com teste limpo: rc=$rc7d"
  if [ "$rc7c" -eq 0 ]; then
    _falha "[7] o runner do ADOTANTE aprovou um teste que sujou a árvore rastreada:"
    printf '%s\n' "$out7c" | tail -8 | sed 's/^/      /'
  elif ! printf '%s\n' "$out7c" | grep -q 'sujou a árvore rastreada'; then
    _falha "[7] o runner do ADOTANTE reprovou sem distinguir 'o teste reprovou' de 'o teste sujou a árvore rastreada':"
    printf '%s\n' "$out7c" | tail -8 | sed 's/^/      /'
  elif [ "$rc7d" -ne 0 ]; then
    _falha "[7] recontrole no adotante: sem o teste que suja, o runner deveria aprovar — rc=$rc7d:"
    printf '%s\n' "$out7d" | tail -8 | sed 's/^/      /'
  else
    echo "OK [7] runner do adotante — reprova o teste que suja nomeando a violação, aprova quando ele sai"
  fi

  # O runner do adotante SEM repositório git: o caso que o cabeçalho dele promete tratar em letra
  # ("repositório ausente ou `git` ausente NÃO viram verde silencioso") e que a primeira redação não
  # tratava — todo o bloco da sentinela ficava guardado por `if [ -n "$REPO" ]`, o ramo do aviso era
  # inalcançável e um teste que sujava a árvore saía com `✓` e o runner com rc 0. É o cenário MAIS
  # provável de um adotante: projeto ainda sem `git init`, ou árvore exportada sem `.git`.
  SFX="$T/adotante-sem-git"
  mkdir -p "$SFX/.forge/scripts/tests" "$SFX/.forge/scripts/lib"
  cp "$RUNNER_ADOTANTE" "$SFX/.forge/scripts/tests/run-all.sh"
  cp "$LIB" "$SFX/.forge/scripts/lib/arvore-rastreada.sh"
  printf 'conteudo\n' > "$SFX/alvo.txt"
  cat > "$SFX/.forge/scripts/tests/sujo.test.sh" <<'GATEFX'
#!/usr/bin/env bash
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
printf 'sujeira plantada pela isca\n' >> "$R/alvo.txt"
GATEFX
  out7e="$(bash "$SFX/.forge/scripts/tests/run-all.sh" 2>&1)"
  rc7e=$?
  echo "    runner do adotante sem repositório git: rc=$rc7e"
  if [ "$rc7e" -eq 0 ]; then
    _falha "[7] o runner do ADOTANTE saiu VERDE (rc 0) sem repositório git — 'não pude medir' colapsou em 'nada sujou', que é o falso-verde que a guarda existe para eliminar:"
    printf '%s\n' "$out7e" | tail -8 | sed 's/^/      /'
  elif ! printf '%s\n' "$out7e" | grep -q 'NÃO MEDIDA'; then
    _falha "[7] o runner do ADOTANTE não saiu verde, mas também não nomeou 'árvore rastreada NÃO MEDIDA' — o operador não fica sabendo por que:"
    printf '%s\n' "$out7e" | tail -8 | sed 's/^/      /'
  elif [ "$rc7e" -ne 3 ]; then
    _falha "[7] o runner do ADOTANTE devolveu rc=$rc7e sem poder medir; o contrato do terceiro estado é rc 3, o MESMO do runner da suíte — dois runners divergindo no mesmo rc é o LDG-0014"
  else
    echo "OK [7] runner do adotante sem git — rc 3 nomeado, e não o verde silencioso"
  fi
fi

# ══ [8] prova de mutação, sobre CÓPIAS em $T ═════════════════════════════════════════════════════
echo "[8] prova de mutação — controle, mutação e recontrole, sempre sobre cópias em \$T"
executados=$((executados + 1))
if [ ! -f "$LIB" ]; then
  _falha "[8] a biblioteca '$LIB' não existe — não há o que mutar"
else
  # (a) a sentinela: `arvore_confere` mutada para devolver sempre rc 0 tem de derrubar o [6].
  cp "$T/arvore-rastreada.pristine.sh" "$T/arvore-rastreada.sh"
  SNAP8="$(_snapshot "$T/arvore-rastreada.sh" "$FXR")"
  printf 'sujeira do cenario 8\n' >> "$FXR/alvo.txt"
  rc8a="$(_rodar_sentinela "$T/arvore-rastreada.sh" "$FXR" "$SNAP8")"
  perl -0pi -e 's/^arvore_confere\(\) \{/arvore_confere() {\n  return 0/m' "$T/arvore-rastreada.sh"
  if cmp -s "$T/arvore-rastreada.sh" "$T/arvore-rastreada.pristine.sh"; then
    _falha "[8] a mutação da sentinela não alterou a cópia — a prova mediria o próprio engano"
  fi
  rc8b="$(_rodar_sentinela "$T/arvore-rastreada.sh" "$FXR" "$SNAP8")"
  cp "$T/arvore-rastreada.pristine.sh" "$T/arvore-rastreada.sh"
  rc8c="$(_rodar_sentinela "$T/arvore-rastreada.sh" "$FXR" "$SNAP8")"
  _git_fx "$FXR" checkout -- . >/dev/null 2>&1
  echo "    sentinela: controle=$rc8a mutada=$rc8b recontrole=$rc8c"
  if [ "$rc8a" = "1" ] && [ "$rc8b" = "0" ] && [ "$rc8c" = "1" ]; then
    echo "OK [8] sentinela — a mutação apaga a detecção (1 -> 0) e o recontrole a traz de volta (0 -> 1)"
  else
    _falha "[8] sentinela: esperava controle=1 mutada=0 recontrole=1 — got $rc8a/$rc8b/$rc8c"
  fi

  # (b) o detector: com a classificação REAL neutralizada, o [3] tem de reprovar.
  cp "$T/detector.pristine.pl" "$DET"
  _detectar "$T/hits8a.txt" "$T/isca-positiva.sh"
  n8a="$(grep -c '^HIT ' "$T/hits8a.txt")"
  perl -pi -e "s/^\\s*next unless \\\$cls eq 'REAL';/      next;/" "$DET"
  if cmp -s "$DET" "$T/detector.pristine.pl"; then
    _falha "[8] a mutação do detector não alterou a cópia — a prova mediria o próprio engano"
  fi
  _detectar "$T/hits8b.txt" "$T/isca-positiva.sh"
  n8b="$(grep -c '^HIT ' "$T/hits8b.txt")"
  cp "$T/detector.pristine.pl" "$DET"
  _detectar "$T/hits8c.txt" "$T/isca-positiva.sh"
  n8c="$(grep -c '^HIT ' "$T/hits8c.txt")"
  echo "    detector: controle=$n8a mutado=$n8b recontrole=$n8c"
  if [ "${n8a:-0}" -ge 1 ] && [ "${n8b:-0}" -eq 0 ] && [ "${n8c:-0}" -ge 1 ]; then
    echo "OK [8] detector — a mutação apaga a acusação da isca positiva e o recontrole a traz de volta"
  else
    _falha "[8] detector: esperava controle>=1 mutado=0 recontrole>=1 — got $n8a/$n8b/$n8c"
  fi

  # (c) a máscara de heredoc: neutralizada, a isca de heredoc do [4] volta a ser acusada, e é isso
  # que prova que a máscara não é código morto. Sem esta mutação, "a isca de heredoc não foi acusada"
  # seria satisfeito por qualquer detector que não acuse nada — inclusive por um quebrado.
  cp "$T/detector.pristine.pl" "$DET"
  _detectar "$T/hits8d.txt" "$T/isca-heredoc.sh"
  n8d="$(grep -c '^HIT ' "$T/hits8d.txt")"
  perl -0pi -e 's/^  my \@mask = heredoc_mask\(\\\@lines\);$/  my \@mask = (0) x scalar(\@lines);/m' "$DET"
  if cmp -s "$DET" "$T/detector.pristine.pl"; then
    _falha "[8] a mutação da máscara de heredoc não alterou a cópia — a prova mediria o próprio engano"
  fi
  _detectar "$T/hits8e.txt" "$T/isca-heredoc.sh"
  n8e="$(grep -c '^HIT ' "$T/hits8e.txt")"
  cp "$T/detector.pristine.pl" "$DET"
  _detectar "$T/hits8f.txt" "$T/isca-heredoc.sh"
  n8f="$(grep -c '^HIT ' "$T/hits8f.txt")"
  echo "    máscara de heredoc: controle=$n8d sem-máscara=$n8e recontrole=$n8f"
  if [ "${n8d:-0}" -eq 0 ] && [ "${n8e:-0}" -ge 1 ] && [ "${n8f:-0}" -eq 0 ]; then
    echo "OK [8] máscara de heredoc — sem ela a isca de heredoc é acusada ($n8e porta(s)); com ela, não"
  else
    _falha "[8] máscara de heredoc: esperava controle=0 sem-máscara>=1 recontrole=0 — got $n8d/$n8e/$n8f; se a mutação não faz a acusação aparecer, a máscara não está sendo exercitada e o [4] passa por vacuidade"
  fi
fi

# ══ fecho: denominador de cenários declarado igual ao executado ══════════════════════════════════
echo
if [ "$executados" -ne "$CENARIOS_DECLARADOS" ]; then
  echo "FAIL denominador: declarei $CENARIOS_DECLARADOS cenário(s) e executei $executados"
  exit 1
fi
if [ "$falhou" -ne 0 ]; then
  echo "REPROVADO — w213-arvore-rastreada ($executados/$CENARIOS_DECLARADOS cenários executados)"
  exit 1
fi
echo "TODOS OS CENÁRIOS OK — w213-arvore-rastreada ($executados/$CENARIOS_DECLARADOS cenários; universo de $PISO arquivo(s) em tests/)"
