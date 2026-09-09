# LDG-0177 — o leitor canônico de segredos é invisível a `grep`, e o silêncio da varredura é falso-verde

Especificação. Data da medição: 2026-09-08. Repositório `forge-harness`, branch `feat/fase1-dogfood-completo`, `HEAD` em `1e28514`. Todas as medições deste documento foram executadas por mim nesta árvore e as saídas estão coladas; onde não executei, digo em letra que não executei e o que isso significa.

Este documento obedece às invariantes 1 a 19 de `docs/plans/2026-09-07-backlog-zero.md`. A invariante 19 governa a forma: eu declaro a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir, e prescrevo comando exato apenas onde ele veio de execução própria com a saída registrada.

## §0 — Método, e uma advertência sobre o instrumento

O assunto deste item é a confiabilidade de uma ferramenta de medição, então a primeira coisa a medir foi a minha própria bancada. Duas armadilhas apareceram e as duas mudaram números que eu já tinha na mão.

**Primeira: o `grep` desta sessão não é o `grep` do sistema.** É uma função de shell que delega a `ugrep` com `-I` e `--ignore-files`, e o `-I` é exatamente o flag que faz um arquivo binário sumir sem aviso.

```
$ type grep
grep is a shell function from /Users/milton/.claude/shell-snapshots/snapshot-zsh-....sh
...
ARGV0=ugrep "$_cc_bin" -G --ignore-files --hidden -I --exclude-dir=.git ...
```

Toda varredura deste documento usa `/usr/bin/grep` por caminho absoluto. Quem repetir as medições com o `grep` da sessão vai obter números diferentes, e os diferentes são os errados.

**Segunda: a bancada roda `zsh` e o alvo roda `bash`.** Uma medição minha foi corrompida por isso e vale registrar porque a mesma classe já apareceu na Onda L: `git show "$c:template/..."` em `zsh` aplica o modificador de história `:t` à variável, a expansão sai vazia, o `shasum` recebe stdin vazio e devolve `e3b0c44298fc...`, que é o sha256 da string vazia. A saída "parecia" um resultado. Toda medição que envolve expansão foi refeita sob `/bin/bash -c`.

## §1 — O defeito, reproduzido

### 1.1 Os bytes

```
$ /usr/bin/perl -ne 'while(/([\x00-\x08\x0b\x0c\x0e-\x1f])/g){printf("linha %d offset-na-linha %d byte 0x%02x\n",$.,pos($_),ord($1))}' template/.forge/scripts/lib/secret-scan.mjs
linha 149 offset-na-linha 9 byte 0x00
linha 149 offset-na-linha 11 byte 0x08
linha 149 offset-na-linha 12 byte 0x0e
linha 149 offset-na-linha 14 byte 0x1f
```

```
$ /usr/bin/perl -0777 -ne 'my $i=index($_,"\x00"); print "NUL offset: $i\n"; print "bytes 8515..8535: "; for my $j (8515..8535){ printf("%02x ", ord(substr($_,$j,1))) } print "\n";' template/.forge/scripts/lib/secret-scan.mjs
NUL offset: 8521
bytes 8515..8535: 69 66 20 28 2f 5b 00 2d 08 0e 2d 1f 5d 2f 2e 74 65 73 74 28 64
```

Os bytes `2f 5b 00 2d 08 0e 2d 1f 5d 2f` são `/[` NUL `-` BS SO `-` US `]/`, isto é, o literal de regex que deveria ter sido escrito `/[\x00-\x08\x0e-\x1f]/`. A linha é a 149 e a função é `decodedBasicPair(b64)`, o validador que decodifica um `Authorization: Basic <base64>` e recusa o candidato quando o resultado não é texto:

```
$ /usr/bin/sed -n '149p' template/.forge/scripts/lib/secret-scan.mjs | /bin/cat -v
  if (/[^@-^H^N-^_]/.test(decoded)) return null;  // binário: não é par de texto
```

O offset do NUL confere com o que o orquestrador mediu (8521). O arquivo tem 12587 bytes e 252 linhas, é UTF-8 válido e o `node` o executa; o que se perde é a auditabilidade.

```
$ /usr/bin/file template/.forge/scripts/lib/secret-scan.mjs
template/.forge/scripts/lib/secret-scan.mjs: data
```

### 1.2 A consequência, com controle positivo

```
$ D=$(mktemp -d); printf 'chave=AKIAIOSFODNN7EXAMPLE\n' > "$D/plantado.txt"; cp template/.forge/scripts/lib/secret-scan.mjs "$D/secret-scan.mjs"
$ /usr/bin/grep -rn AKIA "$D"
.../plantado.txt:1:chave=AKIAIOSFODNN7EXAMPLE
Binary file .../secret-scan.mjs matches
$ /usr/bin/grep -arn AKIA "$D"
.../plantado.txt:1:chave=AKIAIOSFODNN7EXAMPLE
.../secret-scan.mjs:13:  { name: 'AWS Access Key ID', re: /AKIA[0-9A-Z]{16}/ },
.../secret-scan.mjs:118:// que menciona `ghp_` ou `AKIA` ao documentar a política não casa, porque não carrega os 36 ou 16
.../secret-scan.mjs:123:  { name: 'AWS Access Key ID', re: /AKIA[0-9A-Z]{16}/ },
```

As três ocorrências são as mesmas que o item registra (linhas 13, 118 e 123). O controle positivo é o `plantado.txt`: ele aparece nas duas varreduras, o que prova que o comando funcionou e que a diferença está no arquivo, não no comando.

### 1.3 O que NÃO reproduziu, e o que isso significa

**O item diz que `grep -rn` "PULA o `secret-scan.mjs` sem uma linha de aviso". Isso é falso para o `/usr/bin/grep` do macOS, e a correção importa porque ela move o dano de lugar.** O BSD grep imprime `Binary file … matches` — em **stdout**, não em stderr, medido separando os descritores:

```
$ /usr/bin/grep -rn AKIA "$D" 2>&1 1>/dev/null
(fim stderr — nada)
```

E as demais formas não são cegas de forma alguma:

| forma | comportamento sobre o arquivo binário | cego? |
|---|---|---|
| `grep -rn` | imprime `Binary file … matches`, **sem número de linha e sem o conteúdo** | não, mas degrada |
| `grep -rl` / `grep -rln` | lista o caminho normalmente | não |
| `grep -rc` | conta certo (devolveu `3` para o `secret-scan.mjs`) | não |
| `grep -q` | rc 0 | não |
| `grep -rho` | imprime `Binary file … matches` em vez da ocorrência recortada | não, mas degrada |
| `grep` desta sessão (`ugrep -I`) | **silêncio absoluto** | **sim** |

Consequência para a especificação, e ela é a razão de este parágrafo existir: **o instrumento que produziu a conclusão errada do subgrupo L1 foi o `grep` da sessão do agente, não o `grep` de produção.** A conclusão do item — de que a auditoria por varredura pode confirmar uma ausência falsa — está certa e o dano ocorreu; o mecanismo é outro, e um gate desenhado sobre o mecanismo errado morde no lugar errado. O dano no `grep` de produção é de **três formas**, todas medidas abaixo: a linha ofensora some da saída (`-n`, `-o`), a contagem por linha subconta, e um pipeline que filtra a saída do primeiro `grep` deixa de ver a evidência.

**Subcontagem, medida:**

```
$ /usr/bin/perl -e 'print qq{x\x00\n.claude/a\n.claude/b\n.claude/c\n}' > "$D/sujo.md"; printf '.claude/z\n' > "$D/limpo.md"
$ /usr/bin/grep -r ".claude/" "$D" | wc -l
2
$ /usr/bin/grep -ar ".claude/" "$D" | wc -l
4
```

**Pipeline que perde a evidência, medido (é o padrão do gate `w97`):**

```
$ /usr/bin/perl -e 'print qq{a\x00b mktemp XXXXXX aqui\n}' > sujo.sh; printf 'mktemp /tmp/ok.XXXXXX\n' > limpo.sh
$ /usr/bin/grep -rn "mktemp" "$D" | /usr/bin/grep -E "X{3,}"
.../limpo.sh:1:mktemp /tmp/ok.XXXXXX
$ /usr/bin/grep -arn "mktemp" "$D" | /usr/bin/grep -E "X{3,}"
Binary file (standard input) matches
```

A segunda saída ainda é feia, mas ela **casa** e faz o `if` do gate disparar; a primeira não casa e o gate diz que está tudo bem. A prova funcional completa disso está em §5.2, contra o gate real.

## §2 — Censo obrigatório: quantos arquivos rastreados somem numa varredura de texto

O enunciado pede este censo antes de decidir a metade (b), porque a resposta muda a forma da decisão. Dois métodos independentes, com o mesmo resultado.

Método 1, com o próprio instrumento (`/usr/bin/grep -qI .` por arquivo, sobre `git ls-files`):

```
rastreados: 1179
vazios (0 byte): 18
binarios-para-grep (nao vazios): 2
docs/assets/banner.png
template/.forge/scripts/lib/secret-scan.mjs
```

Método 2, independente do grep, procurando byte NUL em `perl`:

```
arquivos regulares rastreados: 1178
vazios (0 byte): 18
com byte NUL: 2
docs/assets/banner.png
template/.forge/scripts/lib/secret-scan.mjs
```

A diferença de 1179 para 1178 é o `git ls-files` contar uma entrada que não é arquivo regular no diretório de trabalho; irrelevante para o censo e registrada para que ninguém a interprete como divergência entre os métodos. Os 18 arquivos de zero byte são `.gitkeep` e precisam de tratamento explícito no gate, porque `grep -qI .` também falha neles e sem essa distinção o gate nasceria com 18 falsos positivos.

**A resposta ao enunciado é: só este, entre os arquivos que deveriam ser texto.** O `banner.png` é binário por natureza, não é auditável e nem deveria ser. E a decisão muda de forma, como o enunciado antecipou: o valor da metade (b) **não** está no tamanho do passivo de hoje na árvore do produtor, que é um arquivo; está em duas outras coisas, ambas medidas neste documento — o instrumento continua degradando em cinco sítios de varredura mesmo depois de o arquivo ser corrigido (§3.2 e §5.2), e as árvores que o harness varre em produção não são esta (o `doctor` varre o `.forge/` do consumidor, que carrega blobs de liaison, `.DS_Store` e caches, e a Onda L6 mediu 14 arquivos casando numa varredura só do canal deste repositório).

**Quando o defeito entrou.** O arquivo nasceu corrompido:

```
$ git show 71b3689:template/.forge/scripts/lib/secret-scan.mjs | /usr/bin/perl -0777 -ne 'print((index($_,"\x00")>=0)?"JA NASCEU COM NUL\n":"limpo\n")'
JA NASCEU COM NUL
$ git show 798ff17:template/.forge/scripts/lib/secret-scan.mjs | /usr/bin/perl -0777 -ne 'print((index($_,"\x00")>=0)?"com NUL\n":"limpo\n")'
limpo
```

`71b3689` é `feat(gates): reprovar segredo hardcoded em arquivo versionado (#37) (#56)`, de 2026-08-19, o commit que criou a camada de gate e a função `decodedBasicPair`. O template só teve duas versões deste arquivo: `2e302067bea1` (798ff17, limpa, sem a camada de gate) e `3ea502b3831a` (71b3689, atual, corrompida).

## §3 — Decisões fechadas

### D1 — a correção é escapar os quatro bytes no literal, no lugar, sem tocar em mais nada

**Decisão.** Substituir a única ocorrência da classe de caracteres escrita com bytes literais pela forma escapada `[\x00-\x08\x0e-\x1f]`. Uma linha, um arquivo.

**Alternativa descartada, e o porquê medido: reescrever o predicado com `Buffer.includes` ou com uma função nomeada `pareceBinario()`.** Descartada porque a mudança de mecanismo destrói a única propriedade que torna esta correção barata de provar — a equivalência ponto a ponto. Medi que a forma escapada é semanticamente idêntica à literal, exaustivamente:

```
$ node equiv.mjs
codepoints comparados: 1112064
divergencias: 0
fonte A (bytes): "[\\u0000-\\b\\u000e-\\u001f]"
fonte B (bytes): "[\\x00-\\x08\\x0e-\\x1f]"
A.source === B.source ? false
```

O `A` é a regex com os bytes literais, o `B` é a escapada, e a comparação percorre todo o espaço `U+0000`–`U+10FFFF` menos os surrogates. Zero divergências sobre 1.112.064 pontos. Uma reescrita para `Buffer` exigiria provar a equivalência sobre outro domínio (bytes, não code points) e sobre a fronteira de decodificação UTF-8, que é justamente onde este tipo de detector erra.

**A ressalva que a última linha da saída obriga: `A.source !== B.source`.** Se qualquer código serializasse esta regex, a mudança não seria neutra. Medi que nada serializa: `/usr/bin/grep -an '\.source' template/.forge/scripts/lib/secret-scan.mjs` devolve rc 1, e a regex da linha 149 é interna à `decodedBasicPair`, fora de `SECRET_PATTERNS` (que é o único array exportado que um consumidor poderia inspecionar). Os dois consumidores do módulo em produção são `template/.forge/scripts/check-secrets.sh` e `template/.forge/scripts/liaison-ops.sh`, e nenhum deles lê `.source`.

**Contrafactual desta decisão**, para quem implementa: a correção é neutra sobre o comportamento observável do módulo, e a prova é diferencial (§5.1), não por leitura.

### D2 — a prova de (a) é diferencial sobre o módulo, não sobre a regex isolada

**Decisão.** A propriedade a preservar é "o comportamento observável de `scanLines` e `findSecrets` é idêntico antes e depois", e ela é provada rodando as duas versões do módulo lado a lado sobre um corpus que exercita a função tocada em toda a sua fronteira. Executei essa prova:

```
comparacoes: 269
divergencias: 0
achados scanLines(appsettings.json): 232
```

O corpus é, para cada byte de 0 a 255, um `Authorization: Basic <base64 de "adm<byte>in:senha1234">`, mais oito casos de borda (base64 sem par, lado esquerdo vazio, lado direito vazio, placeholder de interpolação, token AWS, cabeçalho PEM, senha literal em connection string, senha interpolada), cruzados com cinco caminhos de elegibilidade (`appsettings.json`, `.env`, `README.md`, `.properties`, `.yml`). A terceira linha é o **denominador de substância**: 232 achados provam que a comparação teve conteúdo, e não que duas listas vazias coincidiram.

**Alternativa descartada: confiar na equivalência da regex isolada (a prova de 1.112.064 pontos) e parar por aí.** Descartada porque ela prova a regex, não o módulo, e a linha tocada está dentro de uma função com dois `return null` anteriores e três validações posteriores. A prova exaustiva da regex continua no documento porque ela é barata e cobre um domínio que o corpus não cobre; ela é insumo, não conclusão.

### D3 — o gate de (a) assere propriedade sobre a árvore inteira, com isenção por extensão declarada

**Decisão.** O gate reprova quando **algum arquivo rastreado que o harness distribui como texto é binário para o `grep`**. O universo é `git ls-files`, os arquivos de zero byte são contados e isentados explicitamente, e a isenção de conteúdo binário é por **extensão declarada** (`png jpg jpeg gif ico pdf zip gz tar woff woff2 ttf otf mp4 mov webp`), nunca por lista de caminhos.

**Alternativa descartada: allowlist por caminho.** Descartada por medição de envelhecimento: hoje ela teria uma entrada (`docs/assets/banner.png`) e o próximo asset binário adicionado ao repositório reprovaria o gate por existir, o que treina a equipe a editar a allowlist em vez de olhar para o achado. A isenção por extensão inverte o ônus na direção certa: um binário com extensão de texto é acusado, e um binário com extensão desconhecida também é acusado, o que força uma declaração explícita em vez de um silêncio.

**Alternativa descartada: derivar a isenção do `.gitattributes`.** Medida e descartada: este repositório não tem `.gitattributes` na raiz (`git check-attr -a docs/assets/banner.png template/.forge/scripts/lib/secret-scan.mjs` não devolve nenhum atributo), e o único `gitattributes` do projeto é `installer/gitattributes.patch`, que é aplicado no consumidor. Derivar de um arquivo inexistente daria um gate que aprova por não ter olhado para nada, que é o defeito da invariante 3.

### D4 — a metade (b) corrige os cinco sítios existentes E ganha um gate que impede a regressão

**Decisão.** As varreduras recursivas do harness que **extraem conteúdo** passam a usar `-a`, e um gate novo reprova quando um sítio desses volta a existir sem `-a`. "Extrai conteúdo" é a saída que carrega a linha casada, isto é, tudo que não seja `-l`, `-q` ou `-c`.

O critério não é arbitrário: ele veio da tabela de §1.3, em que `-l`, `-q` e `-c` foram medidos e **não** degradam. Exigir `-a` neles seria ruído, e ruído em gate é como gates morrem.

O universo é de **cinco** sítios, nominalmente, e hoje **nenhum** deles passa `-a`:

```
arquivos-varridos=287 linhas-de-comentario-ignoradas=30 sitios=5 com-a=0 sem-a=5
FAIL: 5 varredura(s) recursiva(s) extraem conteúdo sem -a:
  template/.forge/skills/dotnet-quality-scan/scripts/scan.sh:49  (-rnE)
  template/.forge/skills/node-quality-scan/scripts/scan.sh:58  (-rnE)
  tests/snapshot/claude-contract.bats:142  (-r)
  tests/w131-surface-declaration-gate.sh:340  (-rhoE)
  tests/w97-hook-portability-gate.sh:15  (-rn)
```

**Alternativa descartada: só o gate, sem corrigir os sítios.** Impossível por construção — o gate nasceria vermelho sobre trabalho que a onda não faria.

**Alternativa descartada: corrigir só os dois sítios de produção e deixar os três gates em paz.** Descartada por medição: o único falso-verde **funcional** que consegui exibir está justamente num gate, o `w97` (§5.2), e ele é o pior dos cinco porque a mensagem que ele imprime afirma a ausência — `OK [1] (nenhum mktemp com sufixo após os X)`. Deixar um gate mentindo em nome do escopo é o padrão que a Onda D existe para fechar.

**A severidade real de cada um dos cinco, medida e não presumida** — este quadro existe porque a invariante 16 exige contrafactual medido antes de declarar efeito, e porque três dos cinco não são falso-verde:

| sítio | forma | o que se perde | é falso-verde hoje? |
|---|---|---|---|
| `tests/w97-hook-portability-gate.sh:15` | `grep -rn … \| grep -E` | a linha ofensora não chega ao segundo grep | **sim, exibido em §5.2** |
| `tests/w131-surface-declaration-gate.sh:340` | `grep -rhoE` alimentando `sed`/`sort -u` | o token recortado some do conjunto | sim, em potencial: um doc de wave binário deixaria de ter seus scripts conferidos |
| `template/.forge/skills/node-quality-scan/scripts/scan.sh:58` | `grep -rnE --include` | `arquivo:linha:conteúdo` vira `Binary file … matches` | não; o achado é reportado sem localização, o relatório degrada |
| `template/.forge/skills/dotnet-quality-scan/scripts/scan.sh:49` | idem | idem | não; idem |
| `tests/snapshot/claude-contract.bats:142` | `grep -r … \| wc -l` com asserção `-eq 0` | subcontagem (medi 2 onde o certo é 4) | não; com asserção contra zero, subcontar ainda acusa |

O `claude-contract.bats:142` entra na correção mesmo não sendo falso-verde hoje porque a asserção vizinha da mesma classe é `[ "$count" -eq 27 ]` (linha 138), e ali a subcontagem quebraria nas duas direções. Não mudo a asserção de 27 nesta onda — ela é dívida da invariante 14 e está registrada em §10 como fora de escopo.

### D5 — o gate se protege do próprio defeito que combate

**Decisão.** A varredura que o gate novo faz sobre os scripts para encontrar os sítios roda ela mesma com `-a`, e o gate publica quantos arquivos leu.

Não é preciosismo: um gate que procura varreduras cegas usando uma varredura cega aprovaria por não ter conseguido ler o arquivo que contém a violação, e o programa já pagou por essa forma exata (o red-first que assegurava o próprio exploit, em `project-red-first-limite-verificacao`).

### D6 — o detector de sítios precisa de controle positivo nominal, porque o primeiro que escrevi era cego

**Decisão.** A especificação **não** prescreve o regex do detector. Ela fixa a lista nominal de cinco sítios como **piso**, e exige que a implementação prove que o seu detector encontra os cinco.

Isto vem de erro próprio, e ele é instrutivo. A primeira versão do meu detector devolveu seis sítios, dos quais dois eram linhas de comentário (`template/.forge/scripts/check-suite-wiring.sh:5` e `tests/w146-suite-invocation-gate.sh:4`, que documentam um comando em prosa) e — pior — ela **perdia** o `w97:15`, que é o único falso-verde real do conjunto. A causa foi gula de regex: `sed 's/.*grep \(-[A-Za-z-]*\).*/\1/p'` casa o **último** `grep` da linha, e a linha do `w97` tem dois, de modo que o detector lia os flags do segundo (`-E`) e concluía que ali não havia varredura recursiva. Um detector que erra para menos é um gate que aprova por não ter olhado.

## §4 — O vermelho antes do verde

O red-first aqui tem uma propriedade que raramente se consegue: **o vermelho não precisa de fixture, porque a árvore real está violando a regra hoje.** Escrever o gate e rodá-lo contra `HEAD` já produz a falha, pela ausência real da funcionalidade e pela presença real do defeito.

### 4.1 Vermelho do bloco A — o arquivo

Executado contra a árvore, com o protótipo do gate:

```
$ /bin/bash proto-bloco1.sh /Users/milton/Documents/projects/forge-harness
universo=1178 vazios=18 isentos-por-extensao=1 violacoes=1
FAIL: arquivo de texto rastreado é binário para o grep (auditoria por varredura devolve silêncio, não erro):
  - template/.forge/scripts/lib/secret-scan.mjs
RC=1
```

A asserção que falha é "nenhum arquivo rastreado de texto é binário para o `grep`", a mensagem nomeia o arquivo, e ela falha porque o arquivo carrega quatro bytes de controle na linha 149 — não por fixture ausente, não por caminho errado, não por sintaxe.

### 4.2 Vermelho do bloco B — o instrumento

Executado contra a árvore, com o protótipo do detector (a saída completa está em D4): `sitios=5 com-a=0 sem-a=5`, `RC=1`. A asserção que falha é "toda varredura recursiva que extrai conteúdo passa `-a`", e ela falha porque **zero** sítios passam `-a` hoje. Ausência real da funcionalidade, com denominador não vazio.

### 4.3 O verde, medido no mesmo lugar

Para não modificar a árvore de trabalho — há outros agentes lendo este repositório agora — as provas de verde e de mutação rodaram numa cópia isolada, criada com `git archive HEAD | tar -x -C $TMPDIR/copia` seguida de `git init` e um commit base, de modo que `git ls-files` funcione na cópia com o mesmo universo. A cópia reproduz o vermelho antes de qualquer edição, o que é o controle de que ela é fiel:

```
$ /bin/bash proto-bloco1.sh "$C"
universo=1178 vazios=18 isentos-por-extensao=1 violacoes=1
FAIL: ... template/.forge/scripts/lib/secret-scan.mjs
```

Aplicando a correção de D1 na cópia (uma substituição, `cmp` confirmando que o arquivo mudou):

```
substituicoes: 1
controle: arquivo mudou
$ /bin/bash proto-bloco1.sh "$C"
universo=1178 vazios=18 isentos-por-extensao=1 violacoes=0
OK
RC=0
$ /usr/bin/sed -n '149p' "$C/template/.forge/scripts/lib/secret-scan.mjs"
  if (/[\x00-\x08\x0e-\x1f]/.test(decoded)) return null;  // binário: não é par de texto
$ /usr/bin/file "$C/template/.forge/scripts/lib/secret-scan.mjs"
...: exported SGML document text, Unicode text, UTF-8 text
```

O `file` deixa de dizer `data`, e o `diff` entre as duas versões, renderizado com `cat -v`, é de exatamente uma linha.

## §5 — Prova de mutação

Duas provas independentes, uma por metade. Ambas com controle (o arquivo mudou de verdade), efeito observado, restauração por checksum e recontrole. A armadilha de LDG-0164 foi evitada construindo o lado direito da substituição com `\\x` escapado dentro de aspas simples do shell e conferindo o `cmp` — e ela quase me pegou: a **primeira** tentativa de produzir a cópia corrigida não substituiu nada, o `sha` ficou idêntico e só não virou uma conclusão errada porque eu comparei os checksums antes de olhar o resultado.

### 5.1 Mutação da metade (a): encolher a classe de caracteres

O que mutar: a classe corrigida, de `[\x00-\x08\x0e-\x1f]` para `[\x00-\x08\x0e-\x1e]`, tirando `0x1f` do conjunto tratado como binário.

O que o teste diferencial deve acusar: divergência de comportamento entre a versão original e a mutada, porque um par `adm\x1fin:senha1234` passa a ser lido como texto e vira achado onde antes não era.

```
mutacoes aplicadas: 1
controle: arquivo MUDOU
  if (/[\x00-\x08\x0e-\x1e]/.test(decoded)) return null;  // binário: não é par de texto
=== teste diferencial COM mutacao ===
DIVERGE scanLines em README.md
DIVERGE scanLines em x.properties
DIVERGE scanLines em y.yml
comparacoes: 269
divergencias: 5
achados scanLines(appsettings.json): 232
=== restauracao por checksum ===
restaurado: checksum bate
=== RECONTROLE ===
comparacoes: 269
divergencias: 0
achados scanLines(appsettings.json): 232
```

Denominador estável nas três execuções (269 comparações), efeito de 5 divergências, restauração conferida por `shasum -a 256` e recontrole em zero. É esta prova que autoriza dizer que a correção é semanticamente neutra: o instrumento que declarou "0 divergências" é o mesmo que acusou 5 quando havia divergência de verdade.

### 5.2 Mutação da metade (b): tirar o `-a` de um sítio corrigido, com contrafactual funcional

Esta é a prova que importa mais, porque ela não mede conformidade textual — mede o comportamento do gate real sobre uma árvore envenenada.

Passo 1, plantar no `template/.forge/hooks/` da cópia um hook com um byte de controle **e** um `mktemp` com sufixo depois dos X, que é exatamente a violação que o `w97 [1]` existe para pegar. Com os cinco sítios corrigidos, o gate acusa:

```
[1] mktemp portável (template termina nos X) em todos os hooks
.../canario-hook.sh:3:t=...mktemp /tmp/x.XXXXXX.log)
FAIL [1] (mktemp com sufixo após os X — quebra no BSD/macOS; mova a extensão ou remova-a)
```

Passo 2, mutar apenas o sítio (`grep -arn` de volta para `grep -rn`), com a mesma árvore envenenada:

```
mutacoes: 1
controle: arquivo mudou
[1] mktemp portável (template termina nos X) em todos os hooks
OK [1] (nenhum mktemp com sufixo após os X)
```

**O gate afirma a ausência de uma violação que está no diretório que ele acabou de varrer.** É o falso-verde da invariante 2 na forma mais literal possível, e o custo de produzi-lo foi um byte.

Passo 3, o gate novo acusa a regressão do sítio:

```
arquivos-varridos=287 linhas-de-comentario-ignoradas=30 sitios=5 com-a=4 sem-a=1
FAIL: 1 varredura(s) recursiva(s) extraem conteúdo sem -a:
  tests/w97-hook-portability-gate.sh:15  (-rn)
```

Passo 4, restauração por checksum e recontrole:

```
restaurado: checksum bate
arquivos-varridos=287 linhas-de-comentario-ignoradas=30 sitios=5 com-a=5 sem-a=0
OK
[1] mktemp portável (template termina nos X) em todos os hooks
.../canario-hook.sh:3:t=...mktemp /tmp/x.XXXXXX.log)   ← volta a acusar
```

### 5.3 Mutação do gate de (a): o canário e o não-canário

Duas mutações complementares, na cópia, com o denominador publicado em cada uma:

```
[m1] canário binário num .md rastreado
universo=1179 vazios=18 isentos-por-extensao=1 violacoes=2
FAIL: ...
  - docs/CANARIO.md
  - template/.forge/scripts/lib/secret-scan.mjs

[m2] o mesmo canário com extensão isenta (.png)
universo=1179 vazios=18 isentos-por-extensao=2 violacoes=1
FAIL: ...
  - template/.forge/scripts/lib/secret-scan.mjs
```

A `[m1]` prova que o gate morde conteúdo novo; a `[m2]` prova que a isenção por extensão **discrimina** e não é uma cláusula morta — o contador `isentos-por-extensao` sobe de 1 para 2 e a violação não é reportada. Sem a `[m2]`, a isenção seria código que ninguém sabe se funciona.

## §6 — Três estados e contador de controle

### 6.1 Os três estados, com os códigos medidos

| desfecho | código | como foi observado |
|---|---|---|
| não encontrei violação | 0 | `universo=1178 … violacoes=0` / `OK` na cópia corrigida |
| encontrei violação | 1 | `violacoes=1` na árvore de hoje; `sem-a=5` no bloco B |
| não consegui verificar | 99 | executado num repositório git vazio: `universo=0 … INCONCLUSIVO: universo abaixo do piso — a varredura não leu a árvore`, `RC=99` |

O terceiro estado apareceu também sem eu provocar, e vale registrar porque é a melhor evidência de que ele não é decorativo: ao rodar os gates afetados contra a cópia, o `w180-node-enforcement-gate.sh` devolveu `FAIL [12]: pacote 'eslint' não resolvível a partir do worktree — rode 'npm install'`. Isso **não** é uma violação do código; é a bancada sem `node_modules`. Eu não consegui verificar o `w180` nesta rodada, e digo isso em letra em vez de contar o resultado como qualquer uma das outras duas coisas.

### 6.2 Contadores de controle, com denominador fixo

O bloco A publica quatro números por execução: `universo`, `vazios`, `isentos-por-extensao`, `violacoes`. O bloco B publica quatro: `arquivos-varridos`, `linhas-de-comentario-ignoradas`, `sitios`, `com-a`, `sem-a`.

**Nenhum deles é comparado a um literal que conte a árvore** — a invariante 14 proíbe, e três especificações desta rodada já quebraram por isso. As asserções são de **propriedade mais piso**:

- `violacoes == 0` e `sem-a == 0` são propriedades, não contagens da árvore.
- `universo >= piso` e `arquivos-varridos >= piso`, com piso escolhido bem abaixo do medido hoje (1178 e 287) para envelhecer com folga; o piso existe para pegar o caso em que o `git ls-files` falha ou o `cd` está errado, não para conferir o tamanho do repositório.
- `sitios >= 1`: se o detector não casar nenhum sítio, o desfecho é 99 e não 0. É a guarda de vacuidade da invariante 18 aplicada aqui, e ela dispara no caminho feliz — se alguém reescrever os cinco sítios de outra forma, o gate diz "não consegui verificar", não "está tudo bem".
- A **única** contagem literal legítima é o denominador de cenários do próprio gate, pela exceção explícita da invariante 14.

O piso numérico concreto é do implementador, que executa; a régua é: menor que metade do medido hoje, e nunca derivado da árvore no mesmo instante em que é conferido, porque um piso que se recalcula não é piso.

### 6.3 A lista nominal de cinco sítios é piso, não igualdade

O gate B deve exigir que os cinco caminhos de D4 estejam entre os sítios encontrados. Se um deles sumir da lista, ou o sítio foi removido (e o gate precisa dizer isso alto, não aprovar em silêncio) ou o detector ficou cego, que é o defeito de D6.

## §7 — Onde entram PBT, contrato, integração e E2E

**PBT — sim, e já executado, em dois níveis.** O primeiro é a equivalência da regex sobre todo o espaço de code points (1.112.064 pontos, 0 divergências), que é um teste de propriedade exaustivo sobre o domínio inteiro em vez de amostrado. O segundo é o corpus de `decodedBasicPair`, gerado varrendo os 256 valores de byte na posição interna do par, cruzados com cinco caminhos de elegibilidade: 269 comparações. Este é o lugar natural do PBT nesta onda e a invariante 5 é atendida sem invenção — a função tocada é um classificador com espaço de entrada enumerável.

**Teste de contrato — sim, e o contrato é o conjunto de exports.** `secret-scan.mjs` é fronteira publicada: exporta `SECRET_PATTERNS`, `findSecrets`, `isConnCredFile`, `maskSecret`, `scanLines`, `parseAllowlist` e `allowlistMatch`, é consumido por `check-secrets.sh` e `liaison-ops.sh`, e está **instalado em cinco repositórios** (§8). O teste de contrato é o diferencial de §5.1, que compara as saídas dos exports antes e depois em vez de comparar o arquivo; a decisão de retrocompatibilidade correspondente está em §8 e é "nenhuma quebra, e a propagação é automática pelo overlay".

**Integração — sim, e ela já existe e não precisa de gate novo.** O caminho `check-secrets.sh` → `secret-scan.mjs` é exercido por `tests/w139-secrets-gate.sh`, que tem 15 cenários, dos quais o `[7]` é exatamente a validação do `Authorization: Basic` com decodificação e checagem dos dois lados — isto é, a função que carrega a linha tocada. Rodei o `w139` contra a árvore de hoje e contra a cópia corrigida, e ele passa nos dois:

```
$ /bin/bash tests/w139-secrets-gate.sh
... OK [15]
PASS w139-secrets-gate
```

O segundo caminho de integração, `liaison-ops.sh send` → módulo, é exercido por `tests/w166-liaison-ack-body-gate.sh`.

**E2E — sim, e também já existe.** O cenário `[14]` do `w139` faz um `git commit` real falhar num repositório real por causa do hook de pre-commit. É o E2E do canal de commit e ele cobre a fiação inteira, do gatilho ao efeito, que é o que a invariante 7 pede. Não proponho E2E novo para a metade (a) porque o defeito de (a) **não é de comportamento** — o comportamento está correto hoje, é a auditabilidade que está quebrada, e auditabilidade não tem caminho de execução para percorrer.

**O que explicitamente não recebe PBT, com justificativa medida: os dois gates novos.** O espaço de entrada deles é a árvore rastreada e o corpo dos scripts, não uma função com domínio gerável; um "PBT" ali seria gerar árvores sintéticas, o que testaria o gerador. O que substitui o PBT nesses dois é a prova de mutação de §5.2 e §5.3, que é a técnica certa para gate estrutural: plantar a violação e observar a acusação, plantar o caso isento e observar o silêncio correto.

## §8 — Retrocompatibilidade: o que está instalado nos consumidores

Li as árvores. Treze repositórios em `~/Documents/projects` foram inspecionados; **cinco** têm `.forge/scripts/lib/secret-scan.mjs` instalado:

| repositório | versão no `machinery.lock` | arquivo tem NUL? | sha (12) | bate com o template? |
|---|---|---|---|---|
| `axis-fare-validator` | v0.14.0 | **sim** | `3ea502b3831a` | sim, idêntico |
| `azim-crm` | v0.1.0-rc24 | **sim** | `3ea502b3831a` | sim, idêntico |
| `lionclaw` | v0.14.0 | **sim** | `3ea502b3831a` | sim, idêntico |
| `Axis.PadSimulator` | v0.11.0 | **sim** | `1c0c326dd04b` | não — 269 linhas, versão divergente |
| `axis-go-cloud` | v0.14.0 | não | `9c4c86b1962e` | não — 452 linhas, versão divergente |

`axis-device-platform` não tem `.forge` nesta máquina, e a raiz do próprio `forge-harness` também não tem `.forge/scripts` (o dogfood da raiz é incompleto, o que é conhecido). Os outros sete repositórios com `.forge` não têm o arquivo.

**Quatro dos cinco carregam o defeito hoje.** O `axis-go-cloud` não carrega, mas o arquivo dele é outro — 452 linhas contra 252 do template, com uma única ocorrência de `AKIA` contra três — e o `machinery.lock` dele registra `3ea502b3831a`, isto é, o sha do template. O mesmo vale para o `Axis.PadSimulator`. Nos dois casos o disco diverge do que o lock declara, o que é **drift local não declarado** e não uma variação de versão.

**O que acontece com eles no próximo `forge update`, medido em `bin/forge.mjs`, não presumido.** A política de overlay está nas linhas 352 e 611–643:

```js
const ENRICHABLE_DIRS = ['agents', 'rules', 'skills', 'templates'];
...
if (!isEnrichable(rel) && oldLock && oldLock.has(rel) && dstHash !== oldLock.get(rel) && dstHash !== newHash)
  driftWarned.push(rel);
```

`scripts/` **não** é enriquecível. Portanto:

- Nos três repositórios idênticos ao template, a correção é aplicada silenciosamente, como qualquer atualização de maquinaria. Nada quebra: o contrato de exports não muda e o comportamento é idêntico por §5.1.
- No `Axis.PadSimulator` e no `axis-go-cloud`, o arquivo é sobrescrito **com aviso** — `WARN: drift local em … sobrescrito pelo template (fix local em maquinaria? faça upstream; backup em .forge.bak-N)` — e o backup cobre. Esse drift já existe hoje e não é criado por esta onda; a onda apenas faz o aviso aparecer, o que é ganho e não regressão. **Não medi por que essas duas árvores divergem**, e não vou especular: é achado para o ledger, separado deste item.
- O `azim-crm` está em `v0.1.0-rc24` e o `Axis.PadSimulator` em `v0.11.0`, portanto nenhum dos dois recebe a correção sem um `forge update` deliberado. A correção não é urgente para eles porque o defeito não é de comportamento.

**Nada mais depende dos bytes deste arquivo.** Medi: nenhum gate fixa o sha256 ou o tamanho do `secret-scan.mjs`, e o `snapshot/MANIFEST.sha256` (88 entradas, validado por `tests/snapshot/verify-manifest.sh`) **não** contém o arquivo — `/usr/bin/grep -a 'secret-scan' snapshot/MANIFEST.sha256` devolve rc 1.

**O que quebra: nada.** Essa é uma afirmação de ausência e ela vem com a prova de que a varredura leu o universo — todas as varreduras desta seção usaram `/usr/bin/grep -a`, e o universo foi enumerado com `git ls-files` em vez de suposto.

## §9 — Invariante 15: strings da produção e os gates que as afirmam

Duas mudanças desta onda tocam produção. Varri `tests/` por cada uma, com `-a`, e listo os gates nominalmente.

**Mudança 1, a linha 149 do `secret-scan.mjs`.** Ela não é impressa por ninguém: é um predicado interno. Os arquivos que mencionam `secret-scan` são `template/.forge/rules/conventions/liaison-untrusted-input.md`, `template/.forge/rules/conventions/no-hardcoded-secrets.md`, `template/.forge/scripts/check-secrets.sh`, `template/.forge/scripts/liaison-ops.sh`, o próprio módulo e `tests/w166-liaison-ack-body-gate.sh` (que o cita num comentário, na linha 113). **Gates a rodar: `w139-secrets-gate.sh` e `w166-liaison-ack-body-gate.sh`.** Nenhuma edição de gate é necessária.

**Mudança 2, o `-a` nos cinco sítios.** Ela não muda nenhuma string impressa, mas muda a saída de dois scripts de produção quando o alvo tem binário. Os gates que afirmam esses scripts são `tests/w155-dotnet-enforcement-gate.sh` (4 menções), `tests/w180-node-enforcement-gate.sh` (4 menções) e `tests/snapshot/claude-contract.bats` (1 menção). **Gates a rodar: `w97`, `w131`, `w155`, `w180`, `claude-contract.bats`.**

Executei quatro dos cinco na cópia, antes e depois do `-a`, e nenhum regride:

| gate | antes do `-a` | depois do `-a` |
|---|---|---|
| `w97-hook-portability-gate.sh` | PASS | PASS |
| `w131-surface-declaration-gate.sh` | PASS | PASS |
| `w155-dotnet-enforcement-gate.sh` | PASS | PASS |
| `w180-node-enforcement-gate.sh` | **não consegui verificar** (`eslint` não resolvível na cópia) | não consegui verificar |

O `w180` fica como pendência explícita da definição de pronto: ele precisa rodar numa bancada com `node_modules` instalado, e o resultado dele não pode ser inferido do resultado do `w155`.

**Espelho do plugin: não é exigido por esta onda.** A regra é que tocar `template/.forge/commands/` obriga `npm run build:plugin`. Esta onda toca `template/.forge/scripts/lib/`, `template/.forge/skills/*/scripts/` e `tests/`, e nenhum desses caminhos tem espelho em `plugin/forge`. Se a implementação acabar editando qualquer arquivo sob `template/.forge/commands/`, o `npm run build:plugin` passa a ser obrigatório — e nunca `build-plugin.sh`, que instala em `$HOME`.

## §10 — O que esta onda explicitamente NÃO faz

1. **Não muda a política de detecção de segredos.** Nenhum padrão novo, nenhum padrão removido, nenhuma mudança de severidade. A conclusão errada do subgrupo L1 — de que o canal de commit não teria detector para AWS Access Key ID — está **refutada** por §1.2: o detector existe, nas linhas 13 e 123, e a delegação está em `check-secrets.sh:162`. Refutar a premissa é serviço desta onda; reavaliar o piso de severidade da issue #125 sobre a premissa corrigida é serviço de quem cuida da issue #125, e este documento não o faz.
2. **Não normaliza `grep` no harness inteiro.** Ficam fora os oito sítios que usam `-l`, `-q` e `-c`, porque foram medidos e não degradam (§1.3), e ficam fora todas as varreduras não recursivas.
3. **Não cria uma função-biblioteca `audit_grep()`.** É a alternativa mais elegante e ela foi descartada por medição de tamanho: cinco sítios não pagam uma camada de indireção, e uma biblioteca nova é superfície nova que precisa do seu próprio gate. Se o número de sítios crescer, o item volta.
4. **Não conserta a asserção `[ "$count" -eq 27 ]` de `tests/snapshot/claude-contract.bats:138`.** É literal numérico que conta a árvore, é dívida da invariante 14 e envelhece sozinho — mas é dívida de outro item e mexer nele aqui misturaria escopos. Fica registrado para o ledger.
5. **Não investiga o drift do `axis-go-cloud` e do `Axis.PadSimulator`.** Os dois têm em disco um `secret-scan.mjs` que não corresponde a nenhuma das duas versões que o template já teve (452 e 269 linhas, contra 252). Está medido em §8 e é achado novo, para o ledger, não para esta onda.
6. **Não muda o comportamento do `doctor`.** As linhas 115 e 119 dele usam `grep -rl` e foram medidas como não cegas; a Onda L6 tem trabalho próprio ali e as duas ondas não devem colidir no mesmo arquivo.
7. **Não escreve no `.forge/` deste repositório, nem nos consumidores.** As árvores dos consumidores foram lidas, nunca escritas.

## §11 — Definição de pronto

A onda está pronta quando cada linha abaixo tiver um comando que a prove, executado pelo implementador na sua bancada e não copiado daqui.

1. `template/.forge/scripts/lib/secret-scan.mjs` não contém byte NUL nem byte de controle fora de `\t`, `\n` e `\r`, e `file` deixa de classificá-lo como `data`.
2. O teste diferencial dos exports do módulo, antes e depois, devolve zero divergências sobre um denominador publicado e não vazio — e o mesmo instrumento acusa divergência quando a classe de caracteres é mutada, com restauração por checksum e recontrole.
3. `w139-secrets-gate.sh` e `w166-liaison-ack-body-gate.sh` passam.
4. O gate novo, bloco A, reprova a árvore antes da correção (vermelho observado e registrado, com a saída colada no PR) e aprova depois, publicando `universo`, `vazios`, `isentos-por-extensao` e `violacoes`.
5. O gate novo, bloco B, reprova a árvore antes da correção dos cinco sítios e aprova depois, publicando `arquivos-varridos`, `sitios`, `com-a` e `sem-a`, e encontrando os **cinco** caminhos nominais de D4 como piso.
6. Os três estados são exibidos: `0`, `1` e o código de "não consegui verificar" em cenário de vacuidade construído.
7. A prova de mutação funcional de §5.2 é reproduzida: com `-a` o `w97` acusa o hook envenenado, sem `-a` ele imprime `OK [1]`, e a restauração por checksum devolve a acusação.
8. Os cinco gates de §9 rodam, **inclusive o `w180` numa bancada com `node_modules`**, um a um e nunca em paralelo com outra execução da suíte.
9. `bash -n` limpo em todo `.sh` tocado.
10. O ordinal do gate novo é alocado pelo orquestrador no momento de escrever o arquivo. `FORGE_ROOT=<repo> bash template/.forge/scripts/gate-ordinal.sh next --path tests` devolveu `w208` em 2026-09-08, derivado de `origin/develop` (máximo remoto `w207`) e da árvore local — **e esse número é fotografia, não reserva**: o alocador só lê `origin/develop` (LDG-0173), há duas branches remotas em voo (`wip/upgrade-safety-ldg-0131` e `wip/deepspec-run-manifest-ldg-0165`) e várias ondas desta rodada pedem gate novo na mesma noite. Duas colisões já aconteceram assim.

## §12 — Um comentário final sobre este documento

Este arquivo escreve `\x00` e `\x1f` sempre na forma escapada, inclusive nos blocos de código. Não é estilo: é a mesma regra que a onda impõe ao código, aplicada ao documento que a descreve. Um documento sobre um arquivo invisível ao `grep` que fosse ele próprio invisível ao `grep` seria a piada mais cara desta rodada, e depois do `w97` afirmando `OK [1]` sobre a violação que acabou de varrer, eu prefiro não arriscar.

## §13 — Correções da implementação

Esta seção é escrita pelo implementador, depois da revisão adversarial da especificação. Ela corrige o documento nos pontos em que ele errou e registra as decisões que ficaram em aberto — porque uma especificação reprovada que é implementada sem ser corrigida vira dívida silenciosa na primeira vez que alguém a reler como se fosse verdade. Todas as medições abaixo foram executadas por mim, nesta bancada, em 2026-09-08, e as saídas estão coladas.

### C1 — o badge `gates-N` do README entra no escopo, e ele é o gate `w200`

**O que a especificação errou.** Nem §9 nem §11 mencionam `tests/w200-readme-inventory-gate.sh`. O cenário `[6]` dele compara o badge do README com `find "$WS/tests" -maxdepth 1 -name '*-gate.sh' | wc -l`, de modo que criar um gate novo sem subir o badge deixa a árvore vermelha por construção — vermelho fabricado contra a implementação correta, que é exatamente a classe que a invariante 15 existe para impedir.

**A correção.** `tests/w200-readme-inventory-gate.sh` entra na lista de gates a rodar de §9, e o bump do badge em `README.md:12` entra na definição de pronto, no MESMO commit que cria o gate, com o valor derivado da contagem e não escrito à mão.

**A decisão que faltava, e ela muda o número: os blocos A e B são UM arquivo de gate, não dois.** `tests/w209-varredura-cega-gate.sh` carrega os cinco cenários. A razão não é economia de arquivo: os dois blocos compartilham o mesmo universo (`git ls-files` executado uma vez) e o bloco B só é interpretável à luz do bloco A, porque o sítio cego e o arquivo invisível são as duas pontas do mesmo defeito. Separar em dois gates duplicaria a enumeração da árvore e permitiria que um passasse enquanto o outro reprovasse, o que é justamente a leitura que o operador não deve ter.

**O que medi na bancada, e é um dado de campo que a especificação não tinha como ter.** Quando comecei, o badge dizia `gates-131` e a árvore rastreada tinha 131 gates, mas o disco já tinha 132 por causa de `tests/w208-hooks-manifest-esquema-gate.sh`, não rastreado, de outro agente da mesma rodada. Enquanto eu trabalhava, esse agente subiu o badge para 132. Subi de 132 para 133, derivando o valor da árvore no momento da edição:

```
$ N=$(find tests -maxdepth 1 -name '*-gate.sh' | wc -l | tr -d ' '); echo "derivado=$N"
derivado=133
$ bash tests/w200-readme-inventory-gate.sh
OK [6] — badge e árvore concordam em 133 gate(s)
```

O badge só fica coerente quando as duas ondas em voo entram juntas. Registro isto em letra porque é uma dependência entre branches que nenhum dos dois gates enxerga, e quem for reconciliar precisa saber que o número correto depende do conjunto que entra, não da onda isolada.

### C2 — o universo do bloco B é declarado como conjunto nomeado, e os `.md` prescritivos ENTRAM

**O que a especificação errou.** D4 declara "o universo é de **cinco** sítios, nominalmente" sobre um universo que ela nunca delimita, e §10.2 só exclui `-l`/`-q`/`-c` e varreduras não recursivas. Isso deixa de fora as varreduras recursivas extratoras prescritas como comando executável na prosa da maquinaria — inclusive `template/.forge/agents/review/security-reviewer.md:72`, que tem exatamente a forma `grep -rnE … | grep -iE …` que §5.2 elegeu como o falso-verde mais forte do documento.

**A decisão, e ela é minha:** os `.md` prescritivos ENTRAM. Um comando que a maquinaria manda um agente executar é produção, não documentação — o agente digita o que está escrito, e o defeito que a onda combate acontece na execução, não na leitura. Excluí-los deixaria vivo o pior exemplar da classe que a onda existe para fechar, e a alternativa (um gate que distingue prosa de prescrição) degeneraria numa allowlist mantida à mão, que é o que D3 já descartou por medição de envelhecimento no bloco A.

**O universo, declarado.** Arquivo RASTREADO (`git ls-files`) sob um dos prefixos `template/`, `tests/`, `installer/`, `bin/`, `tools/`, com uma das extensões `.sh`, `.bats`, `.bash`, `.mjs`, `.js`, `.cjs`, `.md`. Ficam fora, com a razão medida de cada um:

| fora | sítios que teria | por que fica fora |
|---|---|---|
| `docs/` | 115 | prosa de medição: a varredura citada é o OBJETO do texto, não uma instrução. Esta própria especificação seria acusada por si mesma. |
| `snapshot/` | 11 | artefato congelado, travado por `snapshot/MANIFEST.sha256` (88 entradas, validado por `tests/snapshot/verify-manifest.sh`); editá-lo quebraria o manifesto. |
| `plugin/` | 0 | espelho gerado de `template/.forge/commands`; medido com zero sítios, e a correção pertenceria à fonte. |

### C3 — o contador `arquivos-varridos=287` não reproduz, e foi substituído por definição mais piso

**O que a especificação errou.** §4.2, §5.2 e D4 publicam `arquivos-varridos=287` sem dizer quais arquivos entram na conta, e nenhum critério plausível reproduz 287 nesta árvore.

**O que medi.** Com o universo de C2, o número é **506** (507 depois que o gate novo passa a ser rastreado, porque ele pertence ao universo que varre — e tem de pertencer):

```
$ bash tests/w209-varredura-cega-gate.sh
    arquivos-varridos=506 linhas-de-comentario-ignoradas=54 sitios=21 com-a=21 sem-a=0
```

O piso derivado é `arquivos-varridos >= 200`, abaixo da metade do medido, e o piso do bloco A é `universo >= 500` contra os 1179 rastreados de hoje. Nenhum dos dois é comparado a igualdade, e nenhum é recalculado no mesmo instante em que é conferido.

### C4 — a lista nominal sobe de 5 para 14 CAMINHOS, e caminho ausente encerra em 99

**O que a especificação errou.** §6.3 manda o gate exigir os cinco caminhos como piso mas não atribui código ao caso em que um deles some, e a lista de D4 vem com número de linha, que é literal que envelhece na primeira edição acima dela.

**As decisões, fechadas com valor.** A âncora é o CAMINHO, sem número de linha. Caminho nominal ausente da lista de sítios encerra em **99** e nunca em 1: a causa pode ser remoção legítima do sítio ou cegueira do detector, e das duas hipóteses o gate não sabe escolher — dizer "ok" seria o falso-verde de D6 e dizer "violação" seria acusar sem evidência. `sem-a > 0` continua sendo a única condição que produz 1.

**A lista nominal medida, com o universo de C2 — são 21 sítios em 14 caminhos**, e não cinco:

```
template/.forge/agents/review/arch-reviewer.md            (2 sítios)
template/.forge/agents/review/code-evaluator.md           (1)
template/.forge/agents/review/platform-reviewer.md        (1)
template/.forge/agents/review/security-reviewer.md        (4)
template/.forge/skills/dotnet-quality-scan/references/detection-commands.md (2)
template/.forge/skills/dotnet-quality-scan/scripts/scan.sh (1)
template/.forge/skills/frontend-ui-review/SKILL.md        (1)
template/.forge/skills/gate-runner/SKILL.md               (1)
template/.forge/skills/node-quality-scan/references/detection-commands.md (2)
template/.forge/skills/node-quality-scan/scripts/scan.sh  (1)
template/.forge/skills/verify-diff-claims/SKILL.md        (2)
tests/snapshot/claude-contract.bats                       (1)
tests/w131-surface-declaration-gate.sh                    (1)
tests/w97-hook-portability-gate.sh                        (1)
```

### C5 — o gate mede propriedade mais forte que "binário para o `grep`", e a definição de pronto passa a bater com ele

**O que a revisão apontou.** §11.1 exige "nenhum byte NUL nem byte de controle fora de `\t`, `\n` e `\r`" enquanto o gate proposto media "binário para o `grep`" via `grep -qI`. Um arquivo com apenas `0x08` e sem NUL satisfaria o gate e violaria a definição de pronto.

**A decisão.** O detector do bloco A lê byte a byte em `perl` com `:raw` e assere a propriedade FORTE, a mesma da definição de pronto. Além de fechar a divergência, isso remove uma dependência que teria mordido em outra bancada: o `grep` BSD do macOS decide "binário" olhando o arquivo inteiro e o GNU olha só o primeiro buffer, de modo que o mesmo arquivo com um `0x00` no meio de um arquivo grande é binário no macOS e texto no Linux. Um gate que herda essa heurística é um gate que responde diferente conforme o CI.

### C6 — os contadores publicados: cinco no bloco A, cinco no bloco B

**O que a especificação errou.** §6.2 abre dizendo "o bloco B publica **quatro**" e lista cinco; §11.5 lista quatro, omitindo `linhas-de-comentario-ignoradas`. O conjunto correto, repetido igual nos dois lugares, é:

- bloco A: `universo`, `nao-regulares`, `vazios`, `isentos-por-extensao`, `violacoes` — o `nao-regulares` é acréscimo meu e existe porque `git ls-files` conta uma entrada que não é arquivo regular (o symlink `.forge/contracts`); sem o contador, a diferença de 1 entre os dois métodos de censo de §2 voltaria a ser um mistério a cada leitura.
- bloco B: `arquivos-varridos`, `linhas-de-comentario-ignoradas`, `sitios`, `com-a`, `sem-a`.

### C7 — efeito colateral do `-a` nos dois `scan.sh`, dimensionado e contido

**O que a revisão apontou.** §9 registra que o `-a` "muda a saída de dois scripts de produção quando o alvo tem binário", mas não diz o que o relatório faz com os bytes crus. O `raw` de `search()` alimenta o relatório em texto **e** o `JSON_ITEMS`, e byte de controle é inválido em JSON.

**O que medi**, com um alvo sintético contendo `src/Limpo.cs` e `src/Sujo.cs` (este com um `\x00` logo após o achado), forçando o motor `grep` (a bancada tem `rg`, que também pula binário e por isso não exercita este caminho):

```
SEM -a (contrafactual, em cópia sob $TMPDIR, com controle de checksum):
FOUND new-httpclient [HIGH] 2 ocorrência(s) — ...
     src/Limpo.cs:2:var c = new HttpClient();
     Binary file /.../alvo-cs/src/Sujo.cs matches      ← sem linha, sem conteúdo, com caminho absoluto

COM -a e com a sanitização:
FOUND new-httpclient [HIGH] 2 ocorrência(s) — ...
     src/Limpo.cs:2:var c = new HttpClient();
     src/Sujo.cs:2:var c = new HttpClient(); // byte de controle logo apos o achado
```

**A correção que acompanha o `-a`.** A última etapa do `search()` dos dois `scan.sh` passa a remover bytes de controle (`LC_ALL=C tr -d "\000-\010\013\014\016-\037"`), depois do `sed` que encurta o caminho. Preserva a localização, que é o que o relatório precisa, e mantém o JSON válido. Verificado: `perl` sobre a saída completa do scan com o alvo envenenado não encontra byte de controle nenhum.

### C8 — o `w180` foi executado numa bancada com `node_modules`

§9 deixou o `w180-node-enforcement-gate.sh` como pendência explícita ("não consegui verificar", `eslint` não resolvível na cópia). Rodei nesta bancada, que tem `node_modules` instalado, depois do `-a` e depois da sanitização de C7: `PASS w180-node-enforcement-gate`. A pendência de §11.8 está fechada.

### C9 — o ordinal foi realocado no momento de escrever o arquivo, e a advertência de §11.10 se confirmou

§11.10 registrou `w208` como fotografia. Quando fui escrever, `tests/w208-hooks-manifest-esquema-gate.sh` já existia na árvore local, não rastreado, escrito por outro agente da rodada. O alocador devolveu `w209` e conferi contra as branches remotas em voo (`origin/wip/upgrade-safety-ldg-0131` e `origin/wip/deepspec-run-manifest-ldg-0165`), cujo máximo é `w207`. O gate é `tests/w209-varredura-cega-gate.sh`.

### C10 — correções menores que a revisão apontou e que ficam registradas sem mudar a implementação

- §10.2 fala em "os **oito** sítios que usam `-l`, `-q` e `-c`". O número é descritivo, nunca virou asserção, e está errado — a varredura independente do revisor encontra cerca de vinte. Fica como está com esta ressalva: o número não deve ser citado como medida.
- §8 diz que a política de overlay está "nas linhas 352 e 611–643" de `bin/forge.mjs`. Referência por número de linha em prosa envelhece sozinha; o que identifica os dois pontos é a constante `ENRICHABLE_DIRS` e o laço que alimenta `driftWarned`.
- §5.3 apresenta `[m1]` e `[m2]` com `universo=1179` e o `secret-scan.mjs` ainda reportado como violação, enquanto §4.3 descreve a cópia já corrigida com `violacoes=0`. São cópias distintas e o documento não dizia isso. Refiz as duas mutações numa cópia isolada já corrigida: `[m1]` sobe para `violacoes=1` nomeando `docs/CANARIO.md`, `[m2]` volta a `violacoes=0` com `isentos-por-extensao` subindo de 1 para 2, e o recontrole depois da remoção volta ao estado de controle.
- §1.3, bloco "Pipeline que perde a evidência": os comandos colados gravam `sujo.sh` e `limpo.sh` sem o prefixo `$D` e só reproduzem se o `cwd` for o próprio `$D`. O fenômeno é real e eu o reproduzi contra o gate `w97` de verdade (§13, prova funcional), mas a colagem, ao pé da letra, não reproduz.

### C11 — o gate tinha buraco da classe que ele existe para fechar, nos dois blocos, e as duas fixtures foram refeitas

Esta correção é escrita depois da revisão adversarial da IMPLEMENTAÇÃO, e ela reprova a primeira versão do `tests/w209-varredura-cega-gate.sh` em dois pontos. Os dois são a mesma doença: o gate media um caso e afirmava uma classe, que é a invariante 3 aplicada ao próprio instrumento. Reproduzi os dois numa cópia isolada sob `$TMPDIR` antes de tocar em qualquer linha, e as duas reproduções deram verde onde tinham de dar vermelho.

**Buraco 1, bloco A: a fixture de [2] plantava um canário só, com `\x00`.** Encolher a classe do detector de `[\x00-\x08\x0b\x0c\x0e-\x1f]` para `[\x00]` mantinha os cinco cenários verdes — medido, com substituição byte-exata em `python3`, alvo único conferido, `RC=0`. Trinta dos trinta e um bytes ficavam sem controle positivo, inclusive `0x08`, `0x0e` e `0x1f`, que são três dos quatro bytes do defeito que originou a onda. Um detector assim mutilado continuaria pegando o `secret-scan.mjs` de hoje, porque ele tem NUL, e deixaria passar um arquivo futuro corrompido só com `0x08` e `0x1f` — que é justamente a forma que o `file` classifica como texto e a razão pela qual C5 escolheu ler byte a byte.

A correção é enumerar a CLASSE DA PROPRIEDADE em vez de um representante dela. O cenário [2] planta um canário por byte de `0x00` a `0x1f`, vinte e nove ao todo, e planta `\t`, `\n` e `\r` como controle NEGATIVO, que o detector tem de deixar em paz. Os contadores esperados são derivados da construção da fixture no mesmo instante em que ela é escrita, nunca digitados. Agora encolher a classe derruba o cenário e alargá-la também:

```
[m-A1] classe reduzida a [\x00]            -> FAIL [2]: obtido 'violacoes=1'  (era PASS, RC=0)
[m-A2] 0x08 removido da classe             -> FAIL [2]: obtido 'violacoes=28' (era PASS, RC=0)
[m-A3] classe alargada para incluir \t     -> FAIL [1] e FAIL [2]: obtido 'violacoes=30'
[m-A4] cláusula de isenção neutralizada    -> FAIL [2]: obtido 'isentos-por-extensao=34 violacoes=0'
```

Cada mutação foi restaurada por checksum (`0ff7d3c41ef8f812`) com recontrole em `RC=0` depois de cada uma.

**Buraco 2, bloco B: o detector reconhecia um PREFIXO da invocação, não a invocação.** A regra `\bgrep\b((?:[ \t]+-[-A-Za-z0-9_=]+)*)` exigia flags grudados logo depois do token, e três formas plausíveis escapavam inteiras. Medido: um arquivo NOVO em `template/.forge/scripts/`, rastreado, com as três, passava com `sitios=21 com-a=21 sem-a=0` e `PASS`, e o contador de controle `arquivos-varridos` subia de 507 para 508 — o operador lê "leu mais e não achou nada" quando o certo era "leu mais e ficou cego", que é a forma exata de D6. É o caso de regressão que o gate existe para pegar, porque árvore existente todo mundo já corrigiu.

As três formas, e as duas que entraram junto por serem da mesma família:

1. opção longa antes dos flags curtos, `--include='*.cs' -rnE` — a mais grave, porque é o resultado de UMA reordenação nos dois `scan.sh` que esta onda corrigiu, que carregam `--include` e flags curtos na mesma linha;
2. variante do nome do comando, `egrep`/`fgrep`/`rgrep`, onde a fronteira de palavra não casa;
3. invocação por variável, `GREP=grep; "$GREP" -rn …`;
4. flags depois do operando, `grep "padrao" -rn dir/`, que o GNU aceita;
5. opções longas equivalentes, `--recursive`, `--text`, `--binary-files=text`, `--quiet`, `--count`.

O detector novo acha o token do comando (as variantes do nome, com ou sem caminho, mais as variáveis a que o MESMO arquivo atribuiu um deles), tokeniza os argumentos respeitando aspas até o primeiro separador de comando não citado — respeitar aspas é o que impede que um padrão com `|` dentro corte a linha antes dos flags — e classifica os tokens de opção. O rastreio de variável é por arquivo, e não pela árvore: alias definido em outro arquivo e usado aqui continua fora do alcance, e é por isso que existe o estado do parágrafo seguinte.

**Um sexto contador, e ele corrige o C6.** Um token que começa com `-`, cuja primeira corrida de letras carrega `r`, `R` ou `a`, e que não tem forma de cluster curto nem de opção longa — `-rn"$x"`, por exemplo — pode esconder tanto o `-r` que torna a varredura recursiva quanto o `-a` que a isentaria. Contá-lo como ausência é o erro-para-menos de D6, então ele vai para `indeterminados` e o cenário [3] encerra em 99. O conjunto publicado do bloco B passa a ser SEIS: `arquivos-varridos`, `linhas-de-comentario-ignoradas`, `sitios`, `com-a`, `sem-a` e `indeterminados`. Onde C6 diz cinco, vale esta linha.

O cenário [5] passou a exercitar as cinco formas e o indeterminado, com as violações ancoradas por número de linha DENTRO da fixture, que é literal legítimo porque a fixture é escrita pelo próprio gate três linhas acima. As mutações, todas com restauração por checksum e recontrole em `RC=0`:

```
[m-B1] arquivo novo com as três formas cegas -> FAIL [3]: sem-a=3, os três sítios nomeados (era PASS, RC=0)
[m-B2] variante do nome do comando removida  -> FAIL [5]: sitios=9 sem-a=5
[m-B3] rastreio de invocação por variável removido -> FAIL [5]: sitios=9 sem-a=5
[m-B4] coleta para no primeiro não-opção     -> FAIL [5]: sitios=9 sem-a=5
[m-B5] token ilegível volta a ser ausência   -> FAIL [5]: indeterminados=0
[m-B6] leitura para na opção longa           -> FAIL [5]: sitios=8 com-a=2
```

**Paridade medida na árvore real, antes e depois da troca do detector.** O detector novo devolve exatamente os mesmos 21 sítios em 14 caminhos, `com-a=21 sem-a=0 indeterminados=0`, sobre `arquivos-varridos=506` e `linhas-de-comentario-ignoradas=55` — os mesmos números de C3 e C4. A primeira versão do detector novo, mais frouxa, subia para 23 sítios com dois falsos positivos em `tests/w106-red-first-gate.sh` (a assinatura em comentário `# check_bugx <expected-rc> <grep-pattern-or-empty>`, onde o token vem colado a um `-`), e três indeterminados em prosa dentro de `echo` (`'grep -q' com '||'`). As duas classes foram fechadas por regra e não por allowlist: o token de opção precisa vir separado do comando por espaço, e o token ilegível só conta quando a corrida de letras dele poderia carregar `r`, `R` ou `a`.

### C12 — a retrocompatibilidade da §8 vale para `scripts/` e NÃO vale para os 11 caminhos enriquecíveis

**O que a §8 errou.** Ela conclui "nenhuma quebra, e a propagação é automática pelo overlay" a partir da constatação de que `scripts/` não é enriquecível. Isso é verdade para o único arquivo que a especificação original tocava, o `secret-scan.mjs`, e deixou de ser verdade quando C2 expandiu a entrega para 14 caminhos: onze deles vivem sob `agents/` e `skills/`, os dois dentro de `ENRICHABLE_DIRS`. Para esses, o `bin/forge.mjs` só sobrescreve quando o `cache/machinery.lock` do consumidor tem entrada para o caminho E o hash bate com o disco; caso contrário o arquivo entra em `preservedFiles` e é reportado como "customização local NÃO sobrescrita" — rótulo errado quando não houve customização nenhuma, e o fix simplesmente não chega.

**A medição, feita por mim, sobre as treze árvores com `.forge` em `~/Documents/projects`, lendo e nunca escrevendo.** Para cada um dos onze caminhos presentes no disco do consumidor comparei o sha256 do arquivo instalado com a entrada correspondente do lock e apliquei a condição literal de `bin/forge.mjs`:

| consumidor | versão do lock | caminhos presentes | recebem o fix | PRESERVADOS (fix não chega) |
|---|---|---|---|---|
| `axis-fare-validator` | v0.14.0 | 11 | 11 | 0 |
| `Axis.PadSimulator` | v0.11.0 | 11 | 11 | 0 |
| `axis-go-cloud` | v0.14.0 | 11 | 10 | 1 — `agents/review/platform-reviewer.md` |
| `lionclaw` | v0.14.0 | 11 | 10 | 1 — `agents/review/code-evaluator.md` |
| `collatra` | v0.1.0-rc24 | 7 | 6 | 1 — `agents/review/code-evaluator.md` |
| `azim-crm` | v0.1.0-rc24 | 7 | 7 | 0 |
| `Axis.AcqSimulator` | v0.1.0-rc22 | 7 | 7 | 0 |
| `docuseal` | v0.1.0-rc23 | 7 | 7 | 0 |
| `agent-smith` | **sem lock** | 6 | 0 | **6** |
| `cpf-cnpj-validator` | **sem lock** | 6 | 0 | **6** |
| `payments` | **sem lock** | 6 | 0 | **6** |
| `forge-test` | **sem lock** | 5 | 0 | **5** |
| `forge-harness` | sem lock | 0 | 0 | 0 (dogfood da raiz incompleto, conhecido) |

**O efeito é maior do que a revisão estimou, e por um motivo diferente.** A revisão apontou um consumidor e dois arquivos, nomeando `azim-crm skills/{node,dotnet}-quality-scan/scripts/scan.sh` como preservados por falta de entrada no lock. Essa linha específica está **refutada por medição**: os dois caminhos não existem no disco do `azim-crm`, nem sob `.forge/skills/` nem sob `.claude/skills/`, e um `find` na árvore inteira não acha nenhum `quality-scan/scan.sh`. Caminho ausente não é caminho preservado — o overlay o CRIA, e o `azim-crm` recebe o fix nos sete caminhos que de fato tem. O que a medição mostra no lugar é uma causa mais larga: **quatro consumidores não têm `cache/machinery.lock` nenhum**, e para eles TODO arquivo enriquecível diferente do template entra em `preservedFiles` — 23 arquivos ao todo, e o fix desta onda não chega a nenhum. Somando os três casos de drift local real, são 26 dos 87 caminhos instalados.

**O que isto muda nesta onda: nada, e é deliberado.** A mecânica é pré-existente e não é criada aqui; o dano é degradação de relatório mais um fix que não propaga, nunca falso-verde de gate no consumidor; e consertar a política de overlay é superfície nova que pede o seu próprio gate. O que muda é a afirmação: onde §8 diz "a propagação é automática pelo overlay", leia-se "automática para `scripts/`, medida; para os onze caminhos sob `agents/` e `skills/` ela depende de o consumidor ter lock e de o lock bater, e em quatro consumidores ela não acontece". O rótulo "customização local NÃO sobrescrita" aplicado a arquivo que ninguém customizou é achado para o ledger, separado deste item.
