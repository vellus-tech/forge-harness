#!/usr/bin/env bash
# Gate W209 — arquivo rastreado invisível à varredura de texto, e varredura recursiva que extrai conteúdo sem `-a` (LDG-0177).
#
# POR QUE ESTE GATE EXISTE. `template/.forge/scripts/lib/secret-scan.mjs` nasceu, em `71b3689`, com quatro bytes de controle
# literais dentro de um literal de regex na linha 149 (`NUL`, `0x08`, `0x0e`, `0x1f`, o NUL no offset 8521). O arquivo é UTF-8
# válido e o `node` o executa sem reclamar; o que se perde é a AUDITABILIDADE. Para o `file` ele é `data`; para uma varredura
# recursiva de texto ele deixa de entregar a linha casada, e o `-I` de alguns wrappers o faz sumir sem uma linha de aviso.
# Uma auditoria por varredura passa a confirmar ausências falsas — que é o falso-verde da invariante 2 na forma mais cara:
# a ferramenta de medição mente e o operador não tem como saber.
#
# O dano tem duas metades e este gate fecha as duas, porque corrigir só o arquivo deixa o instrumento cego para o próximo.
#
#   BLOCO A — nenhum arquivo rastreado que o harness distribui como texto carrega byte de controle fora de `\t`, `\n` e `\r`.
#   A isenção é por EXTENSÃO DECLARADA, nunca por lista de caminhos: allowlist por caminho envelheceria no primeiro asset
#   binário novo e treinaria a equipe a editar a allowlist em vez de olhar para o achado.
#
#   BLOCO B — toda varredura recursiva que EXTRAI CONTEÚDO na maquinaria do harness passa `-a` (ou `--text`). "Extrai
#   conteúdo" é a saída que carrega a linha casada, isto é, tudo que não seja `-l`, `-q` ou `-c` — os três foram medidos e
#   NÃO degradam sobre arquivo binário, e exigir `-a` neles seria ruído, que é como gates morrem.
#
# O DETECTOR SE PROTEGE DO PRÓPRIO DEFEITO. A leitura dos arquivos é feita byte a byte em `perl`, com `:raw`, sem delegar a
# decisão de "isto é binário" a nenhuma heurística de varredura — nem à do `grep` BSD, que olha o arquivo inteiro, nem à do
# GNU, que olha só o primeiro buffer. Um gate que procura varreduras cegas usando uma varredura cega aprovaria por não ter
# conseguido ler o arquivo que contém a violação, e este programa já pagou por essa forma exata.
#
# A FIXTURE DO BLOCO A ENUMERA A CLASSE INTEIRA, NUNCA UM REPRESENTANTE. A primeira versão deste gate plantava um único
# canário, com `\x00`, e afirmava sobre ele a propriedade "nenhum byte de controle fora de `\t`, `\n` e `\r`" — um caso
# medido e uma classe afirmada, que é a invariante 3 violada pelo próprio gate. O custo era literal: encolher o detector de
# `[\x00-\x08\x0b\x0c\x0e-\x1f]` para `[\x00]` mantinha os cinco cenários verdes, e três dos quatro bytes do defeito que
# originou a onda (`0x08`, `0x0e`, `0x1f`) ficavam sem controle positivo nenhum. Agora o cenário [2] planta UM canário por
# byte de `0x00` a `0x1f`, e planta `\t`, `\n` e `\r` como controle NEGATIVO — o detector tem de acusar os vinte e nove e
# silenciar sobre os três, e tanto encolher quanto alargar a classe derruba o cenário.
#
# O DETECTOR DO BLOCO B CASA TODAS AS OCORRÊNCIAS DA LINHA, não a última. A primeira versão escrita durante a especificação
# usava `sed 's/.*grep \(-[A-Za-z-]*\).*/\1/p'`, que casa o ÚLTIMO comando da linha, e por isso PERDIA justamente o sítio de
# `tests/w97-hook-portability-gate.sh:15` — o único falso-verde funcional do conjunto, porque a linha dele tem duas varreduras
# e a segunda não é recursiva. Um detector que erra para menos é um gate que aprova por não ter olhado.
#
# E O DETECTOR DO BLOCO B RECONHECE A INVOCAÇÃO, NÃO UM PREFIXO DELA. A segunda versão exigia que os flags viessem GRUDADOS
# logo depois do token, e por isso três formas plausíveis passavam inteiras — um arquivo novo com as três era aprovado com
# `sem-a=0`, e o contador de controle `arquivos-varridos` até subia, o que faz o operador ler "leu mais e não achou nada"
# quando o certo era "leu mais e ficou cego". As três, todas agora exercitadas no cenário [5]:
#
#   1. opção longa ANTES dos flags curtos (`--include='*.cs' -rnE`) — que é o resultado de UMA reordenação nos dois `scan.sh`
#      que esta própria onda corrigiu, porque os dois carregam `--include` e flags curtos na mesma linha;
#   2. variante do nome do comando (`egrep`, `fgrep`, `rgrep`), onde a fronteira de palavra do token não casa;
#   3. invocação por variável (`GREP=grep; "$GREP" -rn …`), resolvida por rastreio de atribuição DENTRO do mesmo arquivo.
#
# Junto com elas entraram os flags depois do operando (`grep "padrao" -rn dir/`, que o GNU aceita) e o reconhecimento das
# opções longas equivalentes (`--recursive`, `--text`, `--binary-files=text`, `--quiet`, `--count`). O rastreio de variável é
# POR ARQUIVO e não pela árvore: alias definido em outro arquivo e usado aqui continua fora do alcance, e é por isso que
# existe o estado abaixo.
#
# TOKEN DE OPÇÃO ILEGÍVEL NÃO É "SEM OPÇÃO" — É "NÃO CONSEGUI LER". Um token que começa com `-`, cuja primeira corrida de
# letras carrega `r`, `R` ou `a`, e que não tem a forma de cluster curto nem de opção longa (por exemplo `-rn"$x"`) pode
# esconder tanto o `-r` que tornaria a varredura recursiva quanto o `-a` que a isentaria. Contá-lo como ausência seria
# exatamente o erro-para-menos de D6, então ele vai para `indeterminados` e o cenário encerra em 99.
#
#   [1] BLOCO A: nenhum arquivo rastreado de texto carrega byte de controle. Publica `universo`, `nao-regulares`, `vazios`,
#       `isentos-por-extensao` e `violacoes`.
#   [2] BLOCO A, discriminação hermética por byte: o detector ACUSA um canário para CADA byte de controle da classe, SILENCIA
#       sobre `\t`, `\n` e `\r`, e SILENCIA sobre o mesmo canário com extensão isenta. Sem [2] a cláusula de isenção seria
#       código que ninguém sabe se funciona, e a classe de bytes seria uma afirmação sem controle positivo.
#   [3] BLOCO B: toda varredura recursiva extratora do universo declarado passa `-a`. Publica `arquivos-varridos`,
#       `linhas-de-comentario-ignoradas`, `sitios`, `com-a`, `sem-a` e `indeterminados`.
#   [4] BLOCO B, piso nominal: os caminhos que a onda corrigiu continuam entre os sítios encontrados. Caminho nominal ausente
#       NÃO aprova e NÃO reprova — encerra em 99, porque a causa pode ser tanto remoção legítima quanto detector cego.
#   [5] BLOCO B, discriminação hermética: o detector ACUSA a forma sem `-a` em CADA uma das formas de invocação que ele diz
#       reconhecer, SILENCIA sobre a forma com `-a` (curta e longa), SILENCIA sobre `-l`/`-q`/`-c`, IGNORA linha de
#       comentário e declara INDETERMINADO o token de opção que não sabe ler.
#
# TRÊS ESTADOS, NUNCA DOIS (invariante 2). `0` não encontrei violação; `1` encontrei violação; `99` não consegui verificar.
# Quando as duas coisas acontecem na mesma execução o código é `1`, porque violação encontrada é evidência positiva e não
# depende de a varredura ter sido completa — mas a linha de inconclusivo continua impressa, nunca engolida.
#
# CONTADOR DE CONTROLE COM DENOMINADOR FIXO (invariante 3). Os cinco cenários acima são o único literal numérico legítimo
# deste arquivo, pela exceção explícita da invariante 14. Todo o resto é PROPRIEDADE mais PISO: `violacoes == 0`,
# `sem-a == 0`, `indeterminados == 0`, `universo >= PISO_UNIVERSO` e `arquivos-varridos >= PISO_VARRIDOS`, com os pisos
# abaixo da metade do medido em 2026-09-08 (1179 rastreados e 506 arquivos de maquinaria) para envelhecerem com folga. O
# piso existe para pegar o caso em que o `git ls-files` falha ou a raiz está errada, não para conferir o tamanho do
# repositório. Os números esperados das duas fixtures são DERIVADOS da fixture no mesmo instante em que ela é construída —
# nenhum deles é digitado à mão.
set -u

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CENARIOS=5
PISO_UNIVERSO=500
PISO_VARRIDOS=200

# Extensões cujo conteúdo binário é legítimo. Declaradas, não deduzidas de caminho.
EXT_ISENTAS="png jpg jpeg gif ico pdf zip gz tar woff woff2 ttf otf mp4 mov webp"

# Universo do bloco B, declarado como conjunto nomeado: arquivo RASTREADO sob um dos prefixos de maquinaria, com uma das
# extensões que carregam comando executável ou comando prescrito a um agente. Fica de fora `docs/` (prosa de medição, onde
# uma varredura citada é o objeto do texto e não uma instrução), `snapshot/` (artefato congelado e travado por
# `snapshot/MANIFEST.sha256`, cuja edição quebraria o manifesto) e `plugin/` (espelho gerado de `template/.forge/commands`,
# medido hoje com zero sítios, e onde a correção pertence à fonte).
PREFIXOS_B='^(template|tests|installer|bin|tools)/'
EXTS_B='\.(sh|bats|bash|mjs|js|cjs|md)$'

# Piso nominal do bloco B: os caminhos que carregavam varredura recursiva extratora quando esta onda mediu a árvore. É piso,
# não igualdade — sítio NOVO com `-a` é bem-vindo e não move esta lista. A âncora é o CAMINHO e nunca `caminho:linha`, porque
# número de linha em asserção envelhece na primeira edição acima dele e reprovaria a árvore correta.
PISO_NOMINAL="template/.forge/agents/review/arch-reviewer.md
template/.forge/agents/review/code-evaluator.md
template/.forge/agents/review/platform-reviewer.md
template/.forge/agents/review/security-reviewer.md
template/.forge/skills/dotnet-quality-scan/references/detection-commands.md
template/.forge/skills/dotnet-quality-scan/scripts/scan.sh
template/.forge/skills/frontend-ui-review/SKILL.md
template/.forge/skills/gate-runner/SKILL.md
template/.forge/skills/node-quality-scan/references/detection-commands.md
template/.forge/skills/node-quality-scan/scripts/scan.sh
template/.forge/skills/verify-diff-claims/SKILL.md
tests/snapshot/claude-contract.bats
tests/w131-surface-declaration-gate.sh
tests/w97-hook-portability-gate.sh"

overall_rc=0
inconclusivo=0
executados=0

falha() { echo "FAIL $1"; overall_rc=1; }
nao_verifiquei() { echo "INCONCLUSIVO $1"; inconclusivo=1; }

command -v perl >/dev/null 2>&1 || { echo "INCONCLUSIVO: perl ausente na bancada — o detector byte a byte não roda e nada foi medido"; exit 99; }
command -v git  >/dev/null 2>&1 || { echo "INCONCLUSIVO: git ausente na bancada — o universo não pode ser enumerado"; exit 99; }

T="$(mktemp -d "${TMPDIR:-/tmp}/w209.XXXXXX")" || { echo "INCONCLUSIVO: mktemp falhou"; exit 99; }
trap 'rm -rf "$T"' EXIT

# ── detector do bloco A ────────────────────────────────────────────────────────────────────────
# Recebe a raiz e a lista de caminhos rastreados; imprime a linha de contadores e, depois dela, um caminho violador por linha.
detector_a() {
  perl -e '
    use strict; use warnings;
    my ($raiz, $lista, $exts) = @ARGV;
    my %isenta = map { lc($_) => 1 } split /\s+/, $exts;
    my ($universo, $nao_reg, $vazios, $isentos) = (0,0,0,0);
    my @violadores;
    open(my $lh, "<", $lista) or die "lista ilegivel\n";
    while (my $rel = <$lh>) {
      chomp $rel;
      next if $rel eq "";
      $universo++;
      my $abs = "$raiz/$rel";
      if (-l $abs || ! -f $abs) { $nao_reg++; next; }
      if (-z $abs) { $vazios++; next; }
      my $ext = ($rel =~ /\.([A-Za-z0-9]+)$/) ? lc($1) : "";
      if ($ext ne "" && $isenta{$ext}) { $isentos++; next; }
      open(my $fh, "<:raw", $abs) or next;
      my $sujo = 0;
      while (read($fh, my $buf, 65536)) {
        if ($buf =~ /[\x00-\x08\x0b\x0c\x0e-\x1f]/) { $sujo = 1; last; }
      }
      close $fh;
      push @violadores, $rel if $sujo;
    }
    close $lh;
    printf("universo=%d nao-regulares=%d vazios=%d isentos-por-extensao=%d violacoes=%d\n", $universo, $nao_reg, $vazios, $isentos, scalar @violadores);
    print "$_\n" for sort @violadores;
  ' "$1" "$2" "$EXT_ISENTAS"
}

# ── detector do bloco B ────────────────────────────────────────────────────────────────────────
# Casa TODAS as ocorrências de cada linha, não a última, e reconhece a invocação inteira em vez de um prefixo dela: o token do
# comando (`grep` e as variantes `egrep`/`fgrep`/`rgrep`, com ou sem caminho, ou a variável a que este mesmo arquivo atribuiu
# um deles), depois a lista de argumentos tokenizada com respeito a aspas até o primeiro separador de comando não citado. O
# token procurado é montado por concatenação e as aspas simples entram por `chr(39)`/`\x27`, para que este próprio arquivo
# não vire um sítio fantasma do seu próprio detector — o gate está dentro do universo que ele varre, e tem de estar.
detector_b() {
  perl -e '
    use strict; use warnings;
    my ($raiz, $lista) = @ARGV;
    my $tok = "gr" . "ep";
    my $ASPA_S = chr(39);
    my $ASPA_D = chr(34);
    my ($arqs, $coment, $com_a, $sem_a, $indet) = (0,0,0,0,0);
    my (@ok, @ruins, @duvida);

    # Argumentos do comando, do fim do token até o primeiro separador NÃO citado. Respeitar aspas é o que impede que um
    # padrao com "|" dentro corte a linha antes dos flags, que seria erro-para-menos.
    sub argumentos_do_comando {
      my ($resto) = @_;
      my @toks; my $cur = ""; my $q = "";
      my $i = 0; my $n = length($resto);
      while ($i < $n) {
        my $c = substr($resto, $i, 1);
        if ($q ne "") { $cur .= $c; $q = "" if $c eq $q; $i++; next; }
        if ($c eq $ASPA_S || $c eq $ASPA_D) { $q = $c; $cur .= $c; $i++; next; }
        if ($c eq "\\" && $i + 1 < $n) { $cur .= substr($resto, $i, 2); $i += 2; next; }
        if ($c =~ /\s/) { push @toks, $cur if $cur ne ""; $cur = ""; $i++; next; }
        if ($c =~ /[|;&`)><]/) { push @toks, $cur if $cur ne ""; return @toks; }
        $cur .= $c; $i++;
      }
      push @toks, $cur if $cur ne "";
      return @toks;
    }

    open(my $lh, "<", $lista) or die "lista ilegivel\n";
    while (my $rel = <$lh>) {
      chomp $rel;
      next if $rel eq "";
      my $abs = "$raiz/$rel";
      next unless -f $abs;
      open(my $fh, "<:raw", $abs) or next;
      $arqs++;
      my @linhas = <$fh>;
      close $fh;

      # Passe 1: variáveis a que ESTE arquivo atribuiu o comando. Alias vindo de outro arquivo continua fora do alcance, e é
      # por isso que o token de opção ilegível encerra em 99 em vez de ser lido como ausência.
      my %alias;
      for my $l (@linhas) {
        next if $l =~ /^\s*#/;
        while ($l =~ /(?:^|[\s;&|])(?:local\s+|export\s+|readonly\s+|typeset\s+)?([A-Za-z_][A-Za-z0-9_]*)=["\x27]?(?:[\w.\/-]*\/)?[efr]?\Q$tok\E["\x27]?(?=[\s;&|"\x27]|$)/g) {
          $alias{$1} = 1;
        }
      }

      my $n = 0;
      for my $linha (@linhas) {
        $n++;
        $linha =~ s/[\r\n]+$//;
        if ($linha =~ /^\s*#/) { $coment++ if $linha =~ /(?<![\w])[efr]?\Q$tok\E(?![\w])/; next; }
        my @pos;
        while ($linha =~ /(?<![\w])[efr]?\Q$tok\E(?![\w])/g) { push @pos, pos($linha); }
        for my $av (sort keys %alias) {
          while ($linha =~ /\$\{?\Q$av\E\}?(?![\w])/g) { push @pos, pos($linha); }
        }
        for my $p (sort { $a <=> $b } @pos) {
          my $resto = substr($linha, $p);
          $resto =~ s/^["\x27]//;
          next unless $resto eq "" || $resto =~ /^\s/;
          my @toks = argumentos_do_comando($resto);
          my (@curtos, @longos);
          my $opaco = 0;
          for my $t (@toks) {
            last if $t eq "--";
            my $u = $t; $u =~ s/^(["\x27])(.*)\1$/$2/;
            next unless $u =~ /^-/;
            next if $u eq "-";
            if    ($u =~ /^--[A-Za-z0-9][-A-Za-z0-9]*(?:=.*)?$/) { push @longos, $u; }
            elsif ($u =~ /^-([A-Za-z0-9]+)$/) { push @curtos, $1; }
            elsif ($u =~ /^-([A-Za-z0-9]+)/ && $1 =~ /[rRa]/) { $opaco = 1; }
          }
          my $curtos = join("", @curtos);
          my $longos = join(" ", @longos);
          my $desc = join(" ", (map { "-$_" } @curtos), @longos);
          if ($opaco) { $indet++; push @duvida, sprintf("%s:%d  (token de opcao ilegivel; lido ate aqui: %s)", $rel, $n, $desc); next; }
          next if $curtos eq "" && $longos eq "";
          next unless ($curtos =~ /[rR]/ || $longos =~ /--recursive|--dereference-recursive|--directories=recurse/);
          next if ($curtos =~ /[lqc]/ || $longos =~ /--files-with-matches|--files-without-match|--quiet|--silent|--count/);
          my $tem_a = ($curtos =~ /a/ || $longos =~ /--text|--binary-files=text/) ? 1 : 0;
          my $sitio = sprintf("%s:%d  (%s)", $rel, $n, $desc);
          if ($tem_a) { $com_a++; push @ok, $sitio } else { $sem_a++; push @ruins, $sitio }
        }
      }
    }
    close $lh;
    printf("arquivos-varridos=%d linhas-de-comentario-ignoradas=%d sitios=%d com-a=%d sem-a=%d indeterminados=%d\n", $arqs, $coment, $com_a + $sem_a, $com_a, $sem_a, $indet);
    print "SEM-A\t$_\n" for @ruins;
    print "INDET\t$_\n" for @duvida;
    print "COM-A\t$_\n" for @ok;
  ' "$1" "$2"
}

# ── [1] bloco A: nenhum arquivo rastreado de texto carrega byte de controle ────────────────────
executados=$((executados + 1))
echo "[1] nenhum arquivo rastreado de texto carrega byte de controle fora de \\t, \\n e \\r"
if ! git -C "$WS" ls-files >"$T/rastreados.txt" 2>"$T/lserr.txt"; then
  nao_verifiquei "[1]: 'git ls-files' falhou em $WS — o universo não foi enumerado e nada foi medido"
else
  saida_a="$(detector_a "$WS" "$T/rastreados.txt")" || saida_a=""
  contadores_a="$(printf '%s\n' "$saida_a" | head -1)"
  echo "    $contadores_a"
  universo_a="$(printf '%s\n' "$contadores_a" | sed -n 's/^universo=\([0-9]*\).*/\1/p')"
  violacoes_a="$(printf '%s\n' "$contadores_a" | sed -n 's/.* violacoes=\([0-9]*\).*/\1/p')"
  if [ -z "${universo_a:-}" ] || [ -z "${violacoes_a:-}" ]; then
    nao_verifiquei "[1]: o detector não devolveu contadores — nada foi medido"
  elif [ "$universo_a" -lt "$PISO_UNIVERSO" ]; then
    nao_verifiquei "[1]: universo=$universo_a abaixo do piso $PISO_UNIVERSO — a varredura não leu a árvore, e aprovar aqui seria aprovar por não ter olhado"
  elif [ "$violacoes_a" -gt 0 ]; then
    falha "[1]: $violacoes_a arquivo(s) rastreado(s) de texto carrega(m) byte de controle — auditoria por varredura devolve silêncio, não erro:"
    printf '%s\n' "$saida_a" | tail -n +2 | sed 's/^/      - /'
  else
    echo "OK [1] — universo lido inteiro e nenhum arquivo de texto é invisível à varredura"
  fi
fi

# ── [2] bloco A, discriminação hermética POR BYTE ──────────────────────────────────────────────
# Roda sobre uma fixture em $T, nunca sobre a árvore rastreada. A fixture enumera a CLASSE DA PROPRIEDADE — todo byte de
# `0x00` a `0x1f` menos `\t`, `\n` e `\r` — e não um representante dela: com um canário só, encolher o detector para
# `[\x00]` deixava trinta dos trinta e um bytes sem controle positivo e mantinha os cinco cenários verdes. Os três bytes
# permitidos entram como controle NEGATIVO, de modo que alargar a classe também derruba o cenário. Os contadores esperados
# saem da própria construção da fixture, nunca digitados.
executados=$((executados + 1))
echo "[2] o detector do bloco A acusa um canário por byte de controle, silencia sobre \\t, \\n, \\r e sobre extensão isenta"
mkdir -p "$T/fixA"
: > "$T/fixA/lista.txt"
esperados_viol=""
n_canarios=0
n_negativos=0
for i in $(perl -e 'print join(" ", 0..31), "\n"'); do
  hex="$(perl -e 'printf("%02x", $ARGV[0])' "$i")"
  if [ "$i" -eq 9 ] || [ "$i" -eq 10 ] || [ "$i" -eq 13 ]; then
    nome="negativo-$hex.md"
    n_negativos=$((n_negativos + 1))
  else
    nome="canario-$hex.md"
    n_canarios=$((n_canarios + 1))
    esperados_viol="${esperados_viol}${nome}
"
  fi
  perl -e 'print "antes", chr($ARGV[0]), "depois\n"' "$i" > "$T/fixA/$nome"
  echo "$nome" >> "$T/fixA/lista.txt"
done
printf 'texto limpo\n' > "$T/fixA/limpo.md"
perl -e 'print "antes\x00depois\n"' > "$T/fixA/canario.png"
: > "$T/fixA/vazio.gitkeep"
printf 'limpo.md\ncanario.png\nvazio.gitkeep\n' >> "$T/fixA/lista.txt"
fix_a="$(detector_a "$T/fixA" "$T/fixA/lista.txt")"
fix_head="$(printf '%s\n' "$fix_a" | head -1)"
fix_viol="$(printf '%s\n' "$fix_a" | tail -n +2)"
esperado_a="universo=$((n_canarios + n_negativos + 3)) nao-regulares=0 vazios=1 isentos-por-extensao=1 violacoes=$n_canarios"
esperado_viol="$(printf '%s' "$esperados_viol" | sort)"
if [ "$fix_head" != "$esperado_a" ]; then
  falha "[2]: contadores da fixture divergem — esperado '$esperado_a', obtido '$fix_head'"
elif [ "$fix_viol" != "$esperado_viol" ]; then
  falha "[2]: o conjunto de violadores não é a classe inteira — a fixture tem um canário por byte de controle e o detector precisa acusar todos e só eles. Esperado:"
  printf '%s\n' "$esperado_viol" | sed 's/^/      + /'
  echo "    obtido:"
  printf '%s\n' "$fix_viol" | sed 's/^/      - /'
else
  echo "OK [2] — $fix_head; acusou os $n_canarios canário(s) de byte de controle, silenciou sobre os $n_negativos de \\t/\\n/\\r e contou o canário .png como isento em vez de reportado"
fi

# ── [3] bloco B: toda varredura recursiva extratora passa -a ───────────────────────────────────
executados=$((executados + 1))
echo "[3] toda varredura recursiva que extrai conteúdo na maquinaria do harness passa -a"
sitios_b=""
if [ ! -s "$T/rastreados.txt" ]; then
  nao_verifiquei "[3]: sem lista de rastreados — o universo não foi enumerado"
else
  perl -ne 'chomp; next unless m{'"$PREFIXOS_B"'}; next unless m{'"$EXTS_B"'}; print "$_\n"' "$T/rastreados.txt" > "$T/universo-b.txt"
  saida_b="$(detector_b "$WS" "$T/universo-b.txt")" || saida_b=""
  contadores_b="$(printf '%s\n' "$saida_b" | head -1)"
  echo "    $contadores_b"
  varridos_b="$(printf '%s\n' "$contadores_b" | sed -n 's/^arquivos-varridos=\([0-9]*\).*/\1/p')"
  sitios_n="$(printf '%s\n' "$contadores_b" | sed -n 's/.* sitios=\([0-9]*\).*/\1/p')"
  sem_a="$(printf '%s\n' "$contadores_b" | sed -n 's/.* sem-a=\([0-9]*\).*/\1/p')"
  indet_b="$(printf '%s\n' "$contadores_b" | sed -n 's/.* indeterminados=\([0-9]*\).*/\1/p')"
  sitios_b="$(printf '%s\n' "$saida_b" | tail -n +2)"
  if [ -z "${varridos_b:-}" ] || [ -z "${sem_a:-}" ] || [ -z "${sitios_n:-}" ] || [ -z "${indet_b:-}" ]; then
    nao_verifiquei "[3]: o detector não devolveu contadores — nada foi medido"
  elif [ "$varridos_b" -lt "$PISO_VARRIDOS" ]; then
    nao_verifiquei "[3]: arquivos-varridos=$varridos_b abaixo do piso $PISO_VARRIDOS — o detector não leu a maquinaria"
  elif [ "$sitios_n" -eq 0 ]; then
    nao_verifiquei "[3]: sitios=0 — nenhuma varredura recursiva extratora foi encontrada em lugar nenhum, o que é indício de detector cego e não de árvore limpa"
  elif [ "$sem_a" -gt 0 ]; then
    falha "[3]: $sem_a varredura(s) recursiva(s) extraem conteúdo sem -a — sobre arquivo binário elas perdem a linha casada e o silêncio vira verde:"
    printf '%s\n' "$sitios_b" | awk -F'\t' '$1=="SEM-A"{print "      - " $2}'
    if [ "$indet_b" -gt 0 ]; then
      echo "    e $indet_b sítio(s) que o detector não conseguiu ler:"
      printf '%s\n' "$sitios_b" | awk -F'\t' '$1=="INDET"{print "      ? " $2}'
    fi
  elif [ "$indet_b" -gt 0 ]; then
    nao_verifiquei "[3]: $indet_b sítio(s) com token de opção que este detector não sabe ler — ele pode carregar o -r que torna a varredura recursiva e pode carregar o -a que a isentaria, e contá-lo como ausência seria aprovar por não ter entendido:"
    printf '%s\n' "$sitios_b" | awk -F'\t' '$1=="INDET"{print "      ? " $2}'
  else
    echo "OK [3] — $sitios_n sítio(s) recursivo(s) extrator(es), todos com -a"
  fi
fi

# ── [4] bloco B, piso nominal por CAMINHO ──────────────────────────────────────────────────────
# Piso, não igualdade. Caminho nominal ausente encerra em 99 e nunca em 1: a causa pode ser remoção legítima do sítio ou
# cegueira do detector, e um gate que não sabe distinguir as duas não tem o direito de dizer nem "ok" nem "violação".
# Sítio indeterminado NÃO conta como presença aqui: o detector não sabe se aquilo é uma varredura recursiva.
executados=$((executados + 1))
echo "[4] os caminhos nominais que esta onda corrigiu continuam entre os sítios encontrados"
if [ -z "$sitios_b" ]; then
  nao_verifiquei "[4]: o bloco B não produziu lista de sítios — o piso nominal não pôde ser conferido"
else
  printf '%s\n' "$sitios_b" | awk -F'\t' '$1=="SEM-A" || $1=="COM-A"{print $2}' | cut -d: -f1 | sort -u > "$T/caminhos.txt"
  faltantes=""
  n_nominais=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n_nominais=$((n_nominais + 1))
    grep -qxF "$p" "$T/caminhos.txt" || faltantes="$faltantes $p"
  done <<EOF
$PISO_NOMINAL
EOF
  if [ -n "$faltantes" ]; then
    nao_verifiquei "[4]: caminho(s) nominal(is) fora da lista de sítios —$faltantes. Ou o sítio foi removido de verdade (e o piso desta onda precisa ser reescrito no mesmo commit) ou o detector ficou cego; das duas hipóteses este gate não sabe escolher, e por isso não aprova."
  else
    echo "OK [4] — os $n_nominais caminho(s) nominal(is) continuam presentes"
  fi
fi

# ── [5] bloco B, discriminação hermética por FORMA DE INVOCAÇÃO ────────────────────────────────
# A fixture é escrita com o token montado em variável, para que a criação da fixture não plante um sítio real dentro deste
# arquivo — o gate pertence ao universo que varre, e a fixture não pode contaminá-lo. Cada linha exercita uma forma que o
# cabeçalho afirma reconhecer, e as três que a segunda versão do detector deixava passar inteiras estão entre elas.
executados=$((executados + 1))
echo "[5] o detector do bloco B acusa cada forma de invocação sem -a, silencia sobre -a, sobre -l/-q/-c e sobre comentário, e declara indeterminado o token que não sabe ler"
mkdir -p "$T/fixB"
G="grep"
{
  printf '%s -rn "padrao" dir/\n' "$G"
  printf '%s -arn "padrao" dir/\n' "$G"
  printf '%s -rl "padrao" dir/\n' "$G"
  printf '%s -rq "padrao" dir/\n' "$G"
  printf '%s -rc "padrao" dir/\n' "$G"
  printf '# %s -rn "padrao" dir/  (linha de comentario, nao conta)\n' "$G"
  printf '%s -rn "a" x/ | %s -E "b"\n' "$G" "$G"
  printf '%s --include=%s -rnE -e "$pattern" dir/\n' "$G" "'*.cs'"
  printf 'e%s -rn "outro" dir/\n' "$G"
  printf 'MYG=%s; "$MYG" -rn "terceiro" dir/\n' "$G"
  printf '%s "padrao" -rn dir/\n' "$G"
  printf '%s --include=%s -arnE -e "$p" dir/\n' "$G" "'*.cs'"
  printf '%s -rn --text "x" dir/\n' "$G"
  printf 'f%s -rl "x" dir/\n' "$G"
  printf '%s --recursive --text "x" dir/\n' "$G"
  printf '%s -rn%s dir/\n' "$G" '"$x"'
} > "$T/fixB/alvo.sh"
printf 'alvo.sh\n' > "$T/fixB/lista.txt"
fix_b="$(detector_b "$T/fixB" "$T/fixB/lista.txt")"
fix_b_head="$(printf '%s\n' "$fix_b" | head -1)"
esperado_b='arquivos-varridos=1 linhas-de-comentario-ignoradas=1 sitios=10 com-a=4 sem-a=6 indeterminados=1'
linhas_sem_a="$(printf '%s\n' "$fix_b" | awk -F'\t' '$1=="SEM-A"{print $2}' | sed 's/^[^:]*:\([0-9]*\).*/\1/' | sort -n | tr '\n' ',')"
linhas_indet="$(printf '%s\n' "$fix_b" | awk -F'\t' '$1=="INDET"{print $2}' | sed 's/^[^:]*:\([0-9]*\).*/\1/' | sort -n | tr '\n' ',')"
if [ "$fix_b_head" != "$esperado_b" ]; then
  falha "[5]: contadores da fixture divergem — esperado '$esperado_b', obtido '$fix_b_head'"
elif [ "$linhas_sem_a" != "1,7,8,9,10,11," ]; then
  falha "[5]: as violações deveriam ser as linhas 1 (forma canônica), 7 (duas varreduras na linha e só a primeira é recursiva — o caso que derrubou o detector guloso), 8 (opção longa antes dos flags curtos), 9 (variante do nome do comando), 10 (invocação por variável) e 11 (flags depois do operando); vieram '$linhas_sem_a'"
elif [ "$linhas_indet" != "16," ]; then
  falha "[5]: o único sítio indeterminado deveria ser a linha 16 (token de opção sem forma de cluster nem de opção longa), vieram '$linhas_indet'"
else
  echo "OK [5] — $fix_b_head; acusou as linhas 1, 7, 8, 9, 10 e 11, declarou indeterminada a 16 e deixou -a curto e longo, -l, -q, -c e o comentário em paz"
fi

# ── desfecho ───────────────────────────────────────────────────────────────────────────────────
if [ "$executados" -ne "$CENARIOS" ]; then
  echo "INCONCLUSIVO: $executados de $CENARIOS cenários executados — o gate não percorreu o próprio denominador"
  exit 99
fi
if [ "$overall_rc" -ne 0 ]; then
  [ "$inconclusivo" -ne 0 ] && echo "AVISO: houve também cenário inconclusivo nesta execução; o código é 1 porque violação encontrada é evidência positiva e não depende de a varredura ter sido completa"
  echo "FAIL w209-varredura-cega-gate ($CENARIOS cenários)"
  exit 1
fi
if [ "$inconclusivo" -ne 0 ]; then
  echo "INCONCLUSIVO w209-varredura-cega-gate ($CENARIOS cenários) — não consegui verificar, e isto não é um verde"
  exit 99
fi
echo "PASS w209-varredura-cega-gate ($CENARIOS cenários)"
exit 0
