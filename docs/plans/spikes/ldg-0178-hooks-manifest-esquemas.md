# LDG-0178 — o esquema de coluna do `hooks.manifest`, escrito duas vezes em campo antes de o produtor chegar (especificação implementável)

Autor: especificador de LDG-0178. Data: 2026-09-08. Base medida: `forge-harness` na branch `feat/fase1-dogfood-completo`, e leitura pura das árvores de consumidor em `~/Documents/projects`. Nenhum gate da suíte foi executado — `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio, e há outros agentes lendo este repositório agora. Toda medição abaixo é de leitura pura das árvores ou de bancada própria sob o scratchpad da sessão, com a saída colada.

> **LEIA §15 ANTES DO CORPO.** A revisão independente reprovou esta especificação em três defeitos de implementação, e a implementação os corrigiu por execução. A seção §15, "Correções da implementação", tem **precedência sobre o corpo** onde as duas divergirem: ela corrige o denominador de cenários, o cenário [10], a enumeração de §7.1, a lista de gates da invariante 15 e a matriz de mutação inteira, cujas linhas declaradas foram derrubadas pela medição real.

**Regra de método, invariante 19 do plano-mestre.** Esta especificação declara a **propriedade** e o **contrafactual**; quem escolhe o primitivo é o implementador, que executa. Comando exato só permanece aqui quando veio de execução minha, com a saída colada. O inventário do que executei está em §13, e o inventário do que declarei sem executar está em §14.

**Fronteira com a Onda L1, em letra e antes de tudo.** `docs/plans/spikes/backlog-onda-l1-update-desarma-consumidor.md` entrega a derivação do `PreToolUse` a partir do diretório, a ponte `stdin` → `argv`, o `hooks.manifest.default` do produtor, o semeador de ativação e quatro guardas. Ela declara explicitamente, em §14 item 9, que **não** escolhe o esquema de coluna da camada do consumidor e que **não lê** os dois manifestos já instalados. Esta especificação é o outro lado dessa fronteira: ela escolhe o esquema, define como o produtor convive com os dois arquivos que já estão lá e escreve a mensagem de canal. Ela **não** implementa a ponte de despacho, **não** altera `sync-adapters.mjs` e **não** toca o semeador. O ponto em que as duas se encostam — a guarda 4 de L1 — é tratado em §7, e a emenda que ele exige está escrita ali.

---

## 0. Resumo do que muda

| Peça | Arquivo | Natureza |
|---|---|---|
| Leitor canônico do `hooks.manifest`, como módulo puro sem efeito de import | `template/.forge/scripts/lib/hooks-manifest.mjs` (novo) | contrato novo, distribuído |
| Formato canônico v1 — união de `estado` e `universo`, marcador de formato no cabeçalho | mesmo arquivo. O `template/.forge/templates/hooks.manifest.exemplo` listado aqui na redação original **não foi entregue**, e o descarte está registrado com a razão em §15.8, item 2 — §15 tem precedência sobre o corpo | decisão de produto, fechada em §6 |
| Modo de projeção para manifesto sem marcador — campos 1 a 3 e ativação derivada da fiação observada | mesmo arquivo | retrocompatibilidade com a base instalada, §7 |
| Gate do esquema e da projeção | `tests/w<NNN>-hooks-manifest-esquema-gate.sh` (novo) | ordinal alocado pelo orquestrador, §12 |
| Corpo da mensagem de canal aos dois adotantes | §11 desta especificação — **redigido, não enviado** | fronteira declarada |

Ordinais: `gate-ordinal.sh next --path tests` devolve `w208`, derivado de `origin/develop` (máximo remoto `w207`) e da árvore local (máximo local `w207`); as duas branches remotas restantes têm máximo `80` e `154`. **O ordinal não é alocado aqui.** A Onda L1 pede quatro ordinais a partir do mesmo `w208` e há outras frentes em voo nesta rodada; a invariante 10 e LDG-0173 atribuem a alocação ao orquestrador, no momento de escrever o arquivo, conferida contra as branches em voo e não só contra `origin/develop`.

---

## 1. A régua — o que eu medi, e o que eu não consegui medir

A invariante 2 vale para o próprio instrumento de medição: "não encontrei", "encontrei" e "não consegui verificar" são desfechos diferentes. A tabela separa os três.

| Afirmação | Como foi medida | Desfecho |
|---|---|---|
| O produtor não distribui `hooks.manifest` nem leitor para ele | `grep -arl` em `template/ bin/ installer/ plugin/`, com controle positivo plantado e achado | **encontrei a ausência**, com o instrumento provado vivo |
| Dois consumidores têm o arquivo, em esquemas incompatíveis | leitura dos dois arquivos inteiros, `wc -l`, `grep -c '^[^#]'`, `awk -F'\t' '{print NF}'` | **encontrei** |
| O leitor de um interpreta mal a árvore do outro | execução cruzada dos **dois parsers de produção**, copiados literalmente dos `sync-adapters.mjs` locais | **encontrei, e o dano é assimétrico** — §5 |
| O denominador do item é 5 consumidores | censo de toda árvore com `.forge/` em `~/Documents/projects` | **derrubada: são 12 árvores de consumidor nesta máquina**, 2 com manifesto e 10 sem — §4 |
| `axis-device-platform` não tem o arquivo | a árvore **não existe** em `~/Documents/projects` sob esse nome nem sob variação de caixa | **não consegui verificar.** Ela é participante do canal de liaison e emissora de 4 mensagens no fio de fiação, mas o disco dela não está aqui. Registrar "não tem o arquivo" seria colapsar o terceiro estado no primeiro, que é o defeito que este plano combate. §11 endereça a mensagem a ela também, pedindo o dado |

A correção de denominador não é cosmética. LDG-0178 diz "dois dos cinco consumidores"; a Onda L1 diz "dois de seis". São **dois de doze** no que eu consigo ler, mais uma árvore que não consigo ler. Toda frase desta especificação sobre "a base instalada" usa doze, e §4 traz o censo nominal.

---

## 2. Os dois arquivos, campo a campo, lidos inteiros

### 2.1 `axis-fare-validator` — 63 linhas, 6 declarações, cinco campos

Cabeçalho de 57 linhas de comentário, seguido de uma linha-legenda e seis declarações. A legenda, literal: `# Colunas, separadas por TAB: hook <TAB> matcher <TAB> contrato <TAB> universo <TAB> razao`.

| Campo | Nome | Vocabulário observado | Quem consome |
|---|---|---|---|
| 1 | `hook` | os 6 nomes de `.sh` | gerador local e três gates locais |
| 2 | `matcher` | `^(Write\|Edit\|MultiEdit\|NotebookEdit)$` (3 linhas), `^Bash$` (3 linhas) — **todos ancorados** | gerador local |
| 3 | `contrato` | `argv` (3), `stdin-json` (3) | gerador local; `hook-matcher-casa-as-ferramentas.test.sh` filtra por `$3 == "argv"` |
| 4 | `universo` | `.cs,.java`, `comando` (3 linhas), `*` (2 linhas) | **não é lido pelo gerador**; é lido só por `gate-universe-not-blind.test.sh` |
| 5 | `razao` | prosa longa, com ids de ledger próprios (`LDG-0798`, `LDG-0800`, `LDG-0387` no par) e datas | ninguém, por máquina |

**O achado que muda o desenho: o campo 4 desta árvore não participa da fiação.** O parser local desestrutura três nomes — `const [hook, matcher, contrato] = t.split(/\t+/)` — e descarta o resto. O `universo` existe para um gate que reprova gancho **armado e cego**: um gancho cujo universo declarado casa zero arquivo da árvore conta como cobertura sem ser cobertura. O cabeçalho diz o que isso mediu: a árvore tem 833 `.java`, 23 `.py` e **zero** `.cs`, e dois ganchos recortavam por `.cs`. O `universo` é, portanto, uma declaração **voltada para teste**, não para fiação — e essa separação é o que torna a união possível sem disputa por uma posição.

O gate que o consome exige `len(col) >= 5` e depois lê posicionalmente `read -r hook _matcher _contrato universo _resto`. Qualquer esquema que insira um campo antes da quarta posição faz esse gate ler outra coisa como universo, em silêncio. É a consequência mais dura da §9.

### 2.2 `Axis.PadSimulator` — 38 linhas, 4 declarações, quatro campos

Cabeçalho de 33 linhas, legenda `#hook	matcher	contrato	estado` e quatro declarações.

| Campo | Nome | Vocabulário observado | Quem consome |
|---|---|---|---|
| 1 | `hook` | os 4 nomes de `.sh` | gerador local e o gate `pretooluse-fiacao.test.sh` |
| 2 | `matcher` | `^(Write\|Edit\|MultiEdit\|NotebookEdit)$`, `^Bash$` nas duas linhas **armadas**; `Write\|Edit` **sem âncora** nas duas linhas **retidas** | gerador local, e só para as armadas |
| 3 | `contrato` | `stdin-json` (2), `argv` (2) | gerador local |
| 4 | `estado` | `armado` (2), `retido:<razão-curta>` (2) | **é o campo que decide a fiação** |

As duas razões de retenção, literais e com item de ledger na própria linha: `retido:portao-invertido-le-o-disco-alcance-de-conteudo-zero-LDG-0387` e `retido:28-falsos-positivos-estruturais-em-engine-e-sai-por-exit-1-LDG-0387`. O cabeçalho registra que o censo que as sustenta foi por **execução** sobre os 2004 arquivos versionados, com controle positivo por gancho — entregar a todos os arquivos um conteúdo que o gancho **deve** reprovar.

O cabeçalho também credita o desenho: *"Crédito do desenho ao axis-fare-validator (forge-harness seq 40)"*, e diz em letra que *"A COLUNA `estado` É UMA ADIÇÃO NOSSA AO DESENHO ORIGINAL"*. A linhagem entre os dois adotantes é do campo. O produtor chega em terceiro.

Detalhe de matcher que a união precisa carregar: as duas linhas retidas têm matcher **não ancorado**, e o próprio cabeçalho do arquivo explica por que âncora é obrigatória. Não é contradição, é consequência: o gerador local nunca emite linha retida, então o matcher dela nunca foi exercitado. Qualquer esquema que passe a armar um gancho antes retido **precisa** revalidar o matcher dele, e essa obrigação entra na mensagem de canal (§11) e na guarda de §6.4.

### 2.3 O que cada esquema cobre, e o que só um deles cobre

| Propriedade | `axis-fare-validator` | `Axis.PadSimulator` |
|---|---|---|
| nome do gancho | sim, campo 1 | sim, campo 1 |
| matcher de ferramenta | sim, campo 2, sempre ancorado | sim, campo 2, ancorado só nas armadas |
| contrato de entrada | sim, campo 3 | sim, campo 3 |
| **universo julgado** — contra cegueira armada | **sim, campo 4** | **não existe** |
| **estado de ativação** — contra armar por omissão | **não existe** (toda linha declarada é fiada) | **sim, campo 4** |
| razão auditável | sim, campo 5, prosa longa | sim, embutida no token `retido:<razão>`, sem campo próprio |

**As duas propriedades são ortogonais e cada adotante acertou metade.** "Sobre que arquivos este gancho chega a opinar" e "este gancho está fiado" são perguntas independentes: um gancho pode estar armado e cego (o defeito que o `axis-fare-validator` mediu), e pode estar retido com universo largo (o `check-language-policy.sh` do `Axis.PadSimulator`, retido por ler o disco em vez do payload). A hipótese da união, que o item pedia para considerar a sério, **sobrevive à medição** e é a decisão D1.

### 2.4 A terceira divergência, que ninguém tinha nomeado — o campo 3 é fato do consumidor, não do produtor

Medido: o `prevent-secrets-leak.sh` das duas árvores **não é o arquivo do template**.

```
=== sha do template x cada consumidor ===
template=fb9fafec947c
Axis.PadSimulator      84c77147487a DIVERGENTE
axis-fare-validator    bbf653932d4f DIVERGENTE
azim-crm               fb9fafec947c IDENTICO
collatra               fb9fafec947c IDENTICO
```

O do `Axis.PadSimulator` tem 21974 bytes contra 3036 do template, e a leitura das primeiras 40 linhas mostra por quê: ele aceita **os dois** canais. Lê `$1`/`$2` quando há argv, e cai para `cat` do stdin quando argv vem vazio e o stdin não é terminal, com `exit 2` fail-closed quando o payload deveria ter chegado e não chegou. É a "tradução dentro do próprio detector" que a árvore anunciou no canal, em `axis-pad-simulator-0037`.

A consequência é forte e ela decide D5: **o `contrato` de um gancho é uma propriedade da implementação instalada naquela árvore**, e o produtor não tem como saber o valor certo para um gancho que o consumidor bifurcou. Duas árvores declaram `contrato` diferente para o mesmo nome de arquivo — `argv` no `axis-fare-validator`, `stdin-json` no `Axis.PadSimulator` — e **as duas estão certas**, porque os arquivos são diferentes. Isso torna o `hooks.manifest.default` do produtor um **piso sobreponível**, nunca uma verdade: onde o consumidor declara, o consumidor vence, sem exceção e sem aviso de drift.

---

## 3. O defeito reproduzido, com código de produção e saída colada

Não usei leitor de brinquedo. Copiei os **dois parsers de produção**, literalmente, de `.forge/scripts/lib/sync-adapters.mjs` de cada árvore, e cruzei cada um contra os dois manifestos reais.

```
=== parser do fare-validator x manifesto do fare-validator (nativo) ===
OK  fv  declaracoes=6  fiados=check-language-policy.sh,enforce-docs-on-publish.sh,enforce-worktree-location.sh,guard-machinery-drift.sh,prevent-secrets-leak.sh,validate-naming-conventions.sh
=== parser do fare-validator x manifesto do PadSimulator (CRUZADO) ===
OK  fv  declaracoes=4  fiados=prevent-secrets-leak.sh,enforce-worktree-location.sh,check-language-policy.sh,validate-naming-conventions.sh
=== parser do PadSimulator x manifesto do PadSimulator (nativo) ===
OK  ps  declaracoes=4  armados=prevent-secrets-leak.sh,enforce-worktree-location.sh
=== parser do PadSimulator x manifesto do fare-validator (CRUZADO) ===
THROW ps  estado '.cs,.java' desconhecido para 'check-language-policy.sh'
```

**O dano está na segunda linha, e ele é silencioso.** O parser do `axis-fare-validator`, aplicado ao manifesto do `Axis.PadSimulator`, fia **quatro** ganchos onde o dono fia **dois** — e os dois excedentes são exatamente os dois que ele reteve com razão medida escrita. Nenhuma mensagem, `rc` de sucesso, o `settings.json` sairia com quatro comandos e ninguém saberia. É o dano central de LDG-0178, reproduzido com o código que roda hoje em produção numa das árvores.

A fiação real de hoje, para o contrafactual:

```
### fiacao REAL hoje no settings.json do Axis.PadSimulator
"^Bash$" -> $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh
"^(Write|Edit|MultiEdit|NotebookEdit)$" -> $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh
blocos PreToolUse = 2
```

**A quarta linha é o outro desfecho, e ele é barulhento.** O parser do `Axis.PadSimulator`, aplicado ao manifesto do `axis-fare-validator`, lança nomeando o gancho e o token. A árvore ficaria sem fiação nova, mas com a anterior intacta, e com uma linha no terminal dizendo exatamente o que não entendeu.

**Essa assimetria — silencioso ao armar demais, barulhento ao recusar — é a base empírica de D4 (§8), e ela não é opinião: são as duas saídas acima.**

Um terceiro leitor, ingênuo, escrito por mim para o caso que o item descreve (quarta coluna como estado, token desconhecido caindo para ativo), sobre o `axis-fare-validator`:

```
FIA   check-language-policy.sh   (token desconhecido ".cs,.java" -> ativo por omissao)
FIA   enforce-docs-on-publish.sh   (token desconhecido "comando" -> ativo por omissao)
FIA   enforce-worktree-location.sh   (token desconhecido "comando" -> ativo por omissao)
FIA   guard-machinery-drift.sh   (token desconhecido "comando" -> ativo por omissao)
FIA   prevent-secrets-leak.sh   (token desconhecido "*" -> ativo por omissao)
FIA   validate-naming-conventions.sh   (token desconhecido "*" -> ativo por omissao)
```

Aqui o fail-open acerta o conjunto **por acidente** — o `axis-fare-validator` quer os seis fiados mesmo. Isso é importante e desconfortável: um leitor errado pode passar despercebido por muito tempo numa árvore que não retém nada, e só se revelar na árvore que retém. É argumento para o gate desta onda carregar **as duas formas de campo** como cenário, não uma.

### 3.1 O que não reproduziu, e o que isso significa

Eu **não** consegui reproduzir o defeito no produtor, porque o produtor não tem leitor nenhum:

```
-- grep -arl 'hooks.manifest' em template/ bin/ installer/ plugin/ --
<CONTROLE>
-- reais (excluindo o controle) --
0
```

O `<CONTROLE>` é um arquivo plantado por mim dentro do universo varrido, que a varredura precisava achar antes de o zero valer; ele foi removido e a remoção foi conferida. Sem ele, o zero significaria apenas silêncio.

**E o controle de texto sozinho não bastava, por um achado que entrou no ledger enquanto eu escrevia esta especificação.** LDG-0177 registra que o `grep` do `PATH` desta máquina é `ugrep 7.8.4` e que ele **silencia** sobre arquivo não-texto, devolvendo saída vazia com `rc 1` — indistinguível de "não há ocorrência". Um controle positivo plantado num arquivo de texto prova que a varredura está viva **para texto**, e não diz nada sobre o único arquivo de código não-texto da árvore. Refiz as duas varreduras com `/usr/bin/grep -a`, e provei a vida do instrumento exatamente nesse arquivo:

```
  /usr/bin/grep -ac AKIA secret-scan.mjs = 3
  grep (ugrep do PATH) -c AKIA          =  (rc=1)
```

Com o instrumento provado vivo no caso difícil, a ausência sobrevive: **zero ocorrências reais** de `hooks.manifest` e de `forge-manifest-format` em `template/ bin/ installer/ plugin/ tests/`, com o controle plantado achado nas duas. Toda afirmação de ausência desta especificação foi refeita assim.

Isso significa que **o defeito de LDG-0178 é prospectivo no produtor e presente no campo**: as duas árvores já se ferem mutuamente se qualquer maquinaria compartilhada ler o manifesto da outra, e o produtor ainda não escreveu o leitor que causaria o dano em escala. É a janela para escolher certo, e é por isso que o item existe antes de a Onda L1 ser mergeada, não depois.

O que o produtor faz hoje, para o contrafactual, é emitir um literal de **um** gancho:

```
233:    const hooks = { PreToolUse: [{ matcher: 'Bash', hooks: [{ type: 'command', command: '$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh' }] }] };
```

Quatro `.sh` no diretório do template, um fiado. Os outros três nascem inertes em toda instalação nova, e o censo de §4 mostra que é exatamente o que dez das doze árvores têm.

---

## 4. A base instalada — censo nominal das doze árvores

`~/Documents/projects`, toda árvore com `.forge/`, excluído o próprio `forge-harness`:

```
ARVORE                   forge.yaml lock  .sh  manif fiados   gerador
agent-smith              sim   nao   4    nao   1        literal
axis-fare-validator      sim   sim   7    SIM   7        le-manifesto
axis-go-cloud            sim   sim   3    nao   1        literal
Axis.AcqSimulator        sim   sim   4    nao   1        literal
Axis.PadSimulator        sim   sim   4    SIM   2        le-manifesto
azim-crm                 sim   sim   4    nao   1        literal
collatra                 sim   sim   4    nao   1        literal
cpf-cnpj-validator       sim   nao   4    nao   1        literal
docuseal                 sim   sim   4    nao   1        literal
forge-test               sim   nao   4    nao   1        literal
lionclaw                 sim   sim   4    nao   1        literal
payments                 sim   nao   4    nao   1        literal
```

A coluna `fiados` conta alvos distintos referenciados em comandos de `PreToolUse`, **incluindo a ponte** — daí o 7 do `axis-fare-validator`, que são 6 ganchos mais o `dispatch-file-hook.sh`.

Três leituras que a especificação precisa carregar:

1. **Dez de doze árvores fiam exatamente um dos três ou quatro ganchos que têm.** O desarme por omissão é o estado normal da base instalada, não a exceção. Qualquer decisão desta onda que aumente esse número em alguma árvore é mudança de comportamento observável e precisa ser anunciada — é o que §11 carrega.
2. **Duas de doze bifurcaram o gerador** para ler o manifesto. As outras dez rodam o literal do template. Um leitor novo no produtor alcança as dez imediatamente e as duas só se elas aceitarem o `update` da maquinaria.
3. **`axis-device-platform` não está nesta tabela porque a árvore não está nesta máquina.** Terceiro estado, não ausência.

---

## 5. As três interpretações possíveis do campo 4, e a que o produtor pode sustentar

Antes das decisões, a enumeração exaustiva do que um leitor do produtor pode fazer diante de um manifesto de campo, com o que cada caminho custa medido.

| Caminho | O que faz | Custo medido |
|---|---|---|
| **A. Ler o campo 4 como estado** | vocabulário fechado `armado`/`retido:` | no `axis-fare-validator`, seis tokens desconhecidos. Se fail-open, fia seis (por acaso correto hoje); se fail-closed, recusa e a árvore fica sem derivação |
| **B. Ler o campo 4 como universo** | vocabulário `*`, `comando`, lista de extensões | no `Axis.PadSimulator`, **fia quatro onde o dono fia dois** — medido em §3, silencioso |
| **C. Detectar o dialeto pela forma do campo 4** | os dois vocabulários são disjuntos hoje | funciona hoje e **fixa por código uma decisão que o item existe para tomar por conversa**. Pior: transforma um valor futuro qualquer numa mudança de dialeto silenciosa, e o campo 4 do `axis-fare-validator` é prosa-adjacente (`.cs,.java`), sem gramática publicada que impeça colisão amanhã |
| **D. Não ler o campo 4 de manifesto que não seja do próprio produtor** | campos 1 a 3, e ativação de outra fonte | é a decisão D3, e §7 mede que ela reproduz **exatamente** a fiação de hoje nas duas árvores |

A alternativa C merece o parágrafo que o item pede, porque ela é a tentadora. Ela é descartada por três razões, e a terceira é decisiva: os vocabulários são disjuntos **por medição de dois arquivos**, não por gramática acordada; o `axis-fare-validator` não publicou gramática de universo nenhuma, e a Onda L1 já registrou que ler os dois esquemas conhecidos *"é inventar o terceiro esquema com outro nome"*; e a detecção por forma é frágil ao caso que §13 mede — `split(/\t+/)` colapsa tabulações consecutivas, então uma linha com universo vazio faz a **razão** subir para o campo 4 e o detector classificar a linha inteira pelo texto de um comentário.

---

## 6. D1 — o formato canônico é a UNIÃO, com marcador de formato e campos nomeados a partir do quinto

**Decisão, fechada.** O formato canônico do produtor, versão 1, é:

```
# forge-manifest-format: 1
#hook	matcher	contrato	estado	[chave=valor …]
prevent-secrets-leak.sh	^(Write|Edit|MultiEdit|NotebookEdit)$	stdin-json	armado	universo=*	razao=AWS/JWT/PEM antes do byte tocar o disco
check-language-policy.sh	^(Write|Edit|MultiEdit|NotebookEdit)$	argv	retido:portao-invertido-le-o-disco-LDG-0387	universo=.cs,.java
```

Quatro regras, e cada uma tem a alternativa descartada colada.

### 6.1 Campos 1 a 3 são posicionais e invariantes: `hook`, `matcher`, `contrato`

**Razão medida:** é o prefixo em que os dois adotantes já concordam, campo a campo e vocabulário a vocabulário. `contrato` tem o mesmo par de valores nas duas árvores (`argv`, `stdin-json`), e o gate `hook-matcher-casa-as-ferramentas.test.sh` do `axis-fare-validator` já filtra por `$3 == "argv"`. Nenhum dos dois precisa mexer numa vírgula desses três campos, hoje ou depois de migrar.

*Alternativa descartada — tornar tudo nomeado, inclusive `hook` e `matcher`.* Descartada por retrocompatibilidade medida: o parser do `Axis.PadSimulator` desestrutura quatro posições e **lança** em linha malformada; o gate `pretooluse-fiacao.test.sh` lê `read -r h m c e`; o gate `gate-universe-not-blind.test.sh` do `axis-fare-validator` exige `len(col) >= 5` e lê posicionalmente. Um formato totalmente nomeado quebraria os cinco leitores instalados de uma vez, e o item existe justamente para não fazer isso.

### 6.2 O campo 4 é `estado`, posicional, com vocabulário FECHADO

`armado` ou `retido:<razão-curta>`. Nada mais.

**Razão medida, e ela é a única assimetria que justifica a escolha entre `estado` e `universo` para a quarta posição:** `estado` é o **único campo que a fiação consome**. Errar `estado` arma ou desarma um gancho; errar `universo` não muda a fiação em byte nenhum — o parser do `axis-fare-validator` sequer o lê, e quem o lê é um gate. O campo que decide segurança fica na posição obrigatória, onde a **omissão** é um erro de aridade detectável, e não um `chave=valor` que some se alguém digitar `estdo=armado`.

E há a consequência de migração, que é o argumento decisivo: **a árvore que já implementa ativação converge com zero movimento de campo.** O `Axis.PadSimulator` já é canônico nos campos 1 a 4; falta-lhe apenas a linha de marcador. A árvore que tem `universo` no campo 4 não tem `estado` nenhum hoje, então ela precisa escrever esse campo de qualquer maneira — mover `universo` para nomeado no mesmo gesto não acrescenta trabalho.

*Alternativa descartada — `universo` no campo 4 e `estado` nomeado.* Descartada porque põe o campo de segurança na parte aberta e desordenada da linha, onde a omissão precisa de um padrão de omissão — e qualquer padrão reabre exatamente o dilema fail-open/fail-closed num lugar invisível. E porque ela obrigaria o `Axis.PadSimulator`, o adotante que resolveu o problema difícil, a reescrever as quatro linhas dele para acomodar a árvore que não tem o conceito.

*Alternativa descartada — adotar o esquema do `axis-fare-validator` inteiro, cinco campos posicionais com `universo` no 4.* Descartada com número: esse esquema **não tem conceito de retenção**, e §3 mede o que ele faz com a outra árvore — fia quatro onde o dono fia dois. Adotá-lo seria escolher o esquema que não sabe o que é um gancho deliberadamente retido, no item cujo risco central é reativar gancho deliberadamente retido.

*Alternativa descartada — adotar o esquema do `Axis.PadSimulator` inteiro, quatro campos, sem `universo`.* Descartada porque apaga uma medição que o campo pagou: o `gate-universe-not-blind.test.sh` reprova gancho **armado e cego**, e o cabeçalho registra o que isso pegou — dois ganchos recortando por `.cs` numa árvore com 833 `.java` e zero `.cs`. Armado e cego conta como cobertura e não é. Descartar a coluna descartaria o gate.

### 6.3 Campos 5 em diante são `chave=valor`, conjunto aberto, ordem livre

`universo=` e `razao=` são as duas chaves da v1. Chave desconhecida é **ignorada e nomeada no relatório** — não é fail-closed, porque nenhuma chave desta faixa participa da fiação, e recusar por causa de metadado que o consumidor quis anotar seria o produtor legislando sobre a prosa do consumidor. Chave repetida na mesma linha é erro de forma e recusa.

**Razão medida:** as duas árvores anotam razão, e anotam de formas incompatíveis — o `axis-fare-validator` num campo 5 de prosa longa com ids de ledger, o `Axis.PadSimulator` embutida dentro do token `retido:`. A faixa nomeada acomoda as duas sem que nenhuma perca o que escreveu, e a razão de retenção continua podendo viver dentro do token, que é onde o adotante a pôs.

### 6.4 O marcador `# forge-manifest-format: 1` é o que distingue canônico de campo

Uma linha de comentário, no cabeçalho, antes de qualquer declaração. **Nenhum dos dois arquivos instalados a tem** — conferido nos dois cabeçalhos inteiros, o de 57 linhas e o de 33.

**Razão medida:** é a única marca que não pode ser inferida por forma, e §5 mede por que inferir por forma é o caminho errado. E o marcador é a peça que a Onda L1 já projetou (guarda 4), de modo que as duas ondas usam a mesma marca em vez de duas.

**Guarda obrigatória que acompanha o marcador:** um manifesto marcado que arma um gancho cuja linha tem matcher **não ancorado** é recusado, nomeando o gancho. Razão medida em §2.2 — as duas linhas retidas do `Axis.PadSimulator` têm matcher sem âncora, e passar a armá-las sem revalidar o matcher entregaria à ferramenta um regex de substring que o próprio cabeçalho da árvore documenta como perigoso, com medição própria de `TodoWrite` bloqueando a sessão.

---

## 7. D3 — a migração é por PROJEÇÃO, e ela funciona com o arquivo exatamente como ele está

**A restrição do item é literal: o caminho de migração não pode ser "o consumidor reescreve o arquivo".** Ele precisa funcionar com o arquivo que já está lá. A decisão é esta:

**Diante de um `hooks.manifest` SEM o marcador, o leitor do produtor opera em modo de projeção: consome apenas os campos 1 a 3, NUNCA lê o campo 4 ou além, e deriva a ativação da fiação já observada no `.claude/settings.json` da própria árvore.**

Eu escrevi esse leitor e rodei nas duas árvores reais:

```
=== axis-fare-validator ===
declaracoes(campos 1-3 legiveis) = 6
larguras de linha observadas     = 5
contratos                        = argv,stdin-json
ponte reconhecida no settings    = dispatch-file-hook.sh
ATIVOS   (derivados do settings) = check-language-policy.sh,enforce-docs-on-publish.sh,enforce-worktree-location.sh,guard-machinery-drift.sh,prevent-secrets-leak.sh,validate-naming-conventions.sh
INATIVOS (derivados do settings) = (nenhum)

=== Axis.PadSimulator ===
declaracoes(campos 1-3 legiveis) = 4
larguras de linha observadas     = 4
contratos                        = stdin-json,argv
ponte reconhecida no settings    = (nenhuma)
ATIVOS   (derivados do settings) = enforce-worktree-location.sh,prevent-secrets-leak.sh
INATIVOS (derivados do settings) = check-language-policy.sh,validate-naming-conventions.sh
```

**A projeção reproduz exatamente a fiação de hoje nas duas árvores, sem ler o campo em disputa, sem que ninguém edite um byte.** No `Axis.PadSimulator` os dois inativos derivados são **precisamente** os dois `retido:` — a informação que o dono escreveu no campo 4 chega ao produtor pelo efeito dela, não pelo texto dela. É essa coincidência, medida e não suposta, que torna a projeção uma migração honesta em vez de um paliativo.

*Alternativa descartada — versionamento explícito exigido do consumidor.* Pedir que os dois donos acrescentem `# forge-manifest-format: 1` é uma linha de trabalho, não uma reescrita, e continua sendo o caminho de convergência final (§11). Mas ela não pode ser **pré-requisito** para o produtor funcionar, porque isso é exatamente "o consumidor reescreve o arquivo antes de a maquinaria servir para ele" — e porque, enquanto ninguém escrever a linha, o produtor fica com um terceiro estado permanente numa árvore que está funcionando bem.

*Alternativa descartada — detecção de esquema por forma.* §5, caminho C. Fixa por código a decisão que o item existe para tomar por conversa, e quebra no caso de tabulação colapsada que §13 mede.

*Alternativa descartada — tolerância cega, lendo o campo 4 e caindo para um padrão.* É o caminho A ou B de §5, e os dois têm o dano medido em §3.

### 7.1 A enumeração exaustiva, e o caso que eu fui procurar

A invariante 17 obriga a caçar ativamente o desfecho não coberto. Sete estados, e o sétimo é o que quase escapou.

| # | Estado | Desfecho |
|---|---|---|
| 1 | manifesto ausente | fora desta onda — é o semeador de L1 |
| 2 | manifesto com marcador, tudo bem formado | leitor canônico, campo 4 é `estado` |
| 3 | manifesto com marcador, token de `estado` desconhecido | **recusa**, D4 (§8) |
| 4 | manifesto com marcador, linha com aridade < 4 | recusa, nomeando a linha |
| 5 | manifesto sem marcador, `settings.json` legível | **projeção**, D3 |
| 6 | manifesto sem marcador, `settings.json` ausente ou ilegível | **terceiro estado**: recusa, não escreve, nomeia o arquivo. Não é "tudo ativo" nem "nada ativo" |
| 7 | manifesto sem marcador, e o `settings.json` fia um `.sh` que **não tem linha no manifesto** | é o caso real do `axis-fare-validator`, e ele é a ponte |

O sétimo estado é o que a enumeração ingênua perde, e ele **existe hoje**: o `dispatch-file-hook.sh` aparece em três comandos do `settings.json` do `axis-fare-validator` e não tem declaração própria no manifesto — só uma menção em comentário, na linha 21. Um leitor que contasse todo `.sh` referenciado como gancho veria sete alvos contra seis declarações e recusaria a árvore.

A propriedade que resolve, declarada sem prescrever primitivo: **em cada comando de `PreToolUse`, o gancho é o ÚLTIMO alvo; qualquer alvo anterior no mesmo comando é despachante.** Medido:

```
axis-fare-validator  ultimos = check-language-policy.sh,enforce-docs-on-publish.sh,enforce-worktree-location.sh,guard-machinery-drift.sh,prevent-secrets-leak.sh,validate-naming-conventions.sh | anteriores = dispatch-file-hook.sh
Axis.PadSimulator    ultimos = enforce-worktree-location.sh,prevent-secrets-leak.sh | anteriores = (nenhum)
```

A regra é estrutural e **não** por nome de arquivo. Reconhecer a ponte por se chamar `dispatch-*` amarraria o produtor ao vocabulário de uma árvore, e a outra nem tem ponte separada — ela põe a tradução dentro do detector (`axis-pad-simulator-0037`).

### 7.2 A emenda que a Onda L1 precisa, e por que a ordem de entrega não fere ninguém

A Onda L1 §D4.5 decide que manifesto sem marcador é terceiro estado: o gerador **para**, deixa o `settings.json` anterior byte-idêntico e nomeia LDG-0178. D3 decide diferente: o gerador **projeta** e reproduz a fiação.

**A emenda, em letra:** onde L1 diz "para antes de escrever", passa a valer "projeta pelos campos 1 a 3 e pela fiação observada, e só para se a fiação observada não puder ser lida (estado 6)". Os cenários `[6d]` e `[7e]` de L1 mudam de asserção: em vez de "o `settings.json` anterior fica byte-idêntico", passam a afirmar "o conjunto `(matcher, alvo final)` do `settings.json` gerado é **igual ao conjunto anterior**". Igualdade de **conjunto**, nunca de bytes nem de contagem — o agrupamento por matcher é livre e a invariante 14 proíbe o literal.

**Por que a ordem de entrega não fere o campo:** sob L1 sozinha, as duas árvores conservam a fiação que têm; sob D3, as duas árvores recebem uma fiação **cujo conjunto é igual ao que têm**. O efeito observável nas duas é o mesmo — nenhum gancho armado é desarmado, nenhum gancho retido é armado. A diferença é só de alcance: L1 sozinha não entrega derivação nenhuma às duas, e com D3 elas passam a receber matcher e contrato do manifesto delas, o que é o que elas já fazem localmente. Se L1 for mergeada antes, a guarda 4 dela fica em pé e esta onda a substitui; se esta onda for antes, L1 assume a projeção já disponível. Nos dois casos o campo não vê mudança de comportamento, e é isso que autoriza as duas ondas a seguirem em paralelo.

---

## 8. D4 — token desconhecido é FAIL-CLOSED, e a razão está medida

**Decisão, fechada: dentro do formato canônico marcado, um valor do campo 4 que não seja `armado` nem `retido:<razão>` faz o leitor RECUSAR a geração inteira, nomeando o gancho e o token, sem escrever o `settings.json`.**

O item pede a razão escrita, porque os dois lados custam. Ela é esta, e é medida em §3.

**O custo do fail-open é invisível e reativa retenção deliberada.** Medido: o parser que resolve desconhecido para ativo, aplicado ao `Axis.PadSimulator`, fia quatro ganchos onde o dono fia dois, com `rc` de sucesso e nenhuma linha de saída. Os dois excedentes são o `check-language-policy.sh`, retido por ser um portão invertido que lê o disco em vez do payload, e o `validate-naming-conventions.sh`, retido por 28 falsos positivos estruturais medidos por execução sobre 2004 arquivos. O primeiro, uma vez armado, opina sobre o disco e não sobre o conteúdo que entra; o segundo reprova 28 caminhos legítimos e sai por `exit 1`. O dono descobriria no dia do upgrade, sem nada no relatório apontando para a causa.

**O custo do fail-closed é visível e limitado.** Medido: o parser fail-closed, aplicado ao manifesto alheio, lança `estado '.cs,.java' desconhecido para 'check-language-policy.sh'` — nomeia o gancho e o token. E o custo real é menor do que parece, porque **recusar a geração não desarma nada**: o `settings.json` anterior permanece, então nenhum gancho que estava armado deixa de estar. O único dano é que um gancho **novo**, cuja linha tem token errado, não entra na fiação até alguém corrigir a linha — e isso é barulhento, imediato e endereçado a quem acabou de editar o arquivo.

**A assimetria decide.** Fail-open troca segurança silenciosa por conveniência; fail-closed troca conveniência barulhenta por segurança. E há o argumento que fecha: o campo já escolheu. O `sync-adapters.mjs` do `Axis.PadSimulator` faz exatamente isto na linha 259 — `throw new Error("sync-adapters: estado '<x>' desconhecido para '<f>' (use 'armado' ou 'retido:<razão>')")` — e é o único dos dois adotantes que enfrentou a pergunta. O produtor adotar o oposto sem medição nova seria reprovar o adotante que decidiu certo.

**A recusa é o terceiro estado, e ela tem código próprio.** Ela não pode compartilhar `rc` com "não encontrei violação" nem com "encontrei violação". A alocação do número é coordenada com a Onda L1, que já acrescenta três `rc` novos ao `update` (§D3, §D4.5) e diz em letra que a tabela de `rc` é fronteira publicada; esta onda **não aloca o número**, declara que ele é distinto dos dois anteriores e delega a alocação a quem consolidar a tabela.

**Guarda contra a inversão pela borda:** `retido:` com razão **vazia** (`retido:` seco) é token malformado, não retenção válida, e recusa. Sem essa guarda, a retenção vira o caminho fácil de desarmar sem justificar, e o valor do campo — decisão auditável em vez de esquecimento — evapora.

---

## 9. Retrocompatibilidade — o que está instalado e o que quebra

Leitura das árvores, leitor a leitor. Cinco leitores instalados hoje consomem o manifesto, e nenhum deles é do produtor.

| Leitor | Árvore | Como lê | Sobrevive a D1/D3? |
|---|---|---|---|
| `sync-adapters.mjs` (fork local) | `axis-fare-validator` | `t.split(/\t+/)`, desestrutura 3, ignora 4 e 5 | **sim, sem mudança.** Não lê o campo 4; a chegada de `estado` no 4 e de `universo=` no 5 é invisível para ele |
| `hook-matcher-casa-as-ferramentas.test.sh` | `axis-fare-validator` | `awk -F'\t' '$3 == "argv"'` | **sim, sem mudança.** Campo 3 é invariante por D1 |
| `gate-universe-not-blind.test.sh` | `axis-fare-validator` | exige `len(col) >= 5`, depois `read -r hook _matcher _contrato universo _resto` | **QUEBRA se e somente se a árvore migrar.** No dia em que `estado` entrar no campo 4, este gate lê `armado` como universo, `tr ',' ' '` não acha extensão, `git ls-files "*armado"` devolve zero e ele reprova o gancho como cego. É um falso positivo, barulhento, não silencioso — mas é quebra, e é **do consumidor**, corrigível por ele numa linha |
| `sync-adapters.mjs` (fork local) | `Axis.PadSimulator` | `t.split('\t')`, exige 4 não vazios, `estado` fechado | **sim, sem mudança**, e ele já é canônico nos campos 1 a 4 |
| `pretooluse-fiacao.test.sh` (B8) | `Axis.PadSimulator` | `while IFS=$'\t' read -r h m c e` | **enfraquece em silêncio se a árvore acrescentar campo 5.** Com `read` de quatro nomes e `IFS` de tabulação, o quarto nome recebe **todo o resto** da linha: `e` vira `armado<TAB>universo=*`, a comparação `[ "$e" = "armado" ]` falha e o cenário passa a pular todas as linhas — verde por não ter olhado. É a falha clássica da invariante 3, num gate do consumidor |

**As duas quebras são do consumidor, e as duas são consequência de ele migrar, nunca de o produtor entregar.** É exatamente por isso que D3 existe: enquanto a árvore não escreve o marcador, nada nela muda. A migração é opt-in, e as duas quebras entram na mensagem de canal (§11) **nominalmente, com o arquivo e a linha**, porque descobrir isso sozinho depois de migrar é o pior desfecho possível.

Para as **dez árvores sem manifesto**, nada muda nesta onda: elas não têm o arquivo, então o leitor não é acionado, e o caminho delas é o semeador da Onda L1.

Para o `axis-device-platform`, **não sei**, e a mensagem pede o dado.

---

## 10. O gate — vermelho, mutação, contadores e o que cada camada de teste cobre

### 10.1 O vermelho, e por que ele é por ausência real

O produtor **não tem** leitor de `hooks.manifest`: `grep -arl` com controle positivo plantado devolve **0 ocorrências reais** em `template/ bin/ installer/ plugin/`, e `find template -name 'hooks.manifest*'` devolve vazio. O módulo `template/.forge/scripts/lib/hooks-manifest.mjs` não existe.

O vermelho, portanto, é este, e ele é observado **antes** de existir uma linha de implementação:

- Cada cenário do gate constrói a sua fixture e **invoca a função exportada pelo módulo canônico**. O módulo não existe, o `import` falha, e cada cenário registra a sua própria falha com a sua própria mensagem — não uma falha global de sintaxe.
- A mensagem de cada cenário nomeia a **propriedade ausente**, não o arquivo ausente. Por exemplo, `[3]` falha com `FAIL [3]: modo de projeção não existe — o produtor não sabe ler manifesto sem marcador` e não com `FAIL: módulo não encontrado`.
- **O que torna esse vermelho legítimo, e não fabricado:** a fixture de cada cenário é montada e validada **antes** da invocação, e o cenário `[0]` é um controle de instrumento que confirma que as fixtures existem, são legíveis e têm o número de linhas declaradas esperado. Se `[0]` falhar, o gate sai pelo código de "não consegui verificar" — o vermelho dos demais cenários só é aceito como vermelho legítimo quando `[0]` está verde. Isso fecha o caminho de vermelho por fixture ausente, que a invariante 1 chama pelo nome.

O implementador registra a saída do vermelho, cenário a cenário, no `verification.md` do change, antes do primeiro commit de implementação.

### 10.2 Os cenários, com propriedade e contrafactual

Denominador declarado: **doze** cenários, `[0]` a `[11]`. É o denominador do próprio gate, a única exceção legítima da invariante 14. Dois nascem verdes por construção — `[0]`, controle de instrumento, e `[11]`, sentinela. **Dez falham hoje por ausência real.**

| # | Propriedade | Contrafactual que a implementação precisa provar | Mensagem do vermelho |
|---|---|---|---|
| [0] | CONTROLE DE INSTRUMENTO — as fixtures existem, são legíveis e têm a forma declarada (uma de cinco campos com universo no 4, uma de quatro campos com estado no 4, uma canônica marcada) | remover uma fixture faz o gate sair por "não consegui verificar", nunca por verde | verde por construção |
| [1] | O leitor canônico existe e é importável **sem efeito colateral** — importá-lo não escreve, não lê a árvore e não reescreve a si mesmo | importar duas vezes não muda o disco; é a lição da retratação de L1 §4.3 e de LDG-0175 | `FAIL [1]: não há leitor canônico de hooks.manifest no produtor — LDG-0178` |
| [2] | FORMATO CANÔNICO — manifesto marcado, campos 1 a 4 posicionais e 5+ nomeados, produz o conjunto de ativos esperado | trocar `armado` por `retido:x` numa linha tira **aquele** gancho do conjunto e não mexe nos demais | `FAIL [2]: o formato canônico v1 não tem leitor` |
| [3] | PROJEÇÃO — manifesto **sem marcador**, nas **duas** formas de campo, produz conjunto de ativos **igual** ao conjunto derivado do `settings.json` da fixture | comparado como **conjunto** de nomes, nunca por contagem; na fixture de quatro campos, os dois `retido:` **não** aparecem no conjunto | `FAIL [3]: modo de projeção não existe — o produtor não sabe ler manifesto sem marcador` |
| [4] | O CAMPO 4 ALHEIO NÃO É LIDO — na fixture de cinco campos, trocar o valor do campo 4 por qualquer coisa **não muda** o conjunto de ativos | mutação do campo 4 de `.cs,.java` para `armado` e para `lixo` produz o mesmo conjunto nos três casos | `FAIL [4]: o leitor consultou o campo 4 de um manifesto que não é do produtor` |
| [5] | TOKEN DESCONHECIDO É FAIL-CLOSED — manifesto **marcado** com `estado` fora do vocabulário faz recusar | a recusa tem código próprio, distinto de "sem violação" e de "com violação", e o `settings.json` da fixture fica intocado | `FAIL [5]: token desconhecido não é recusado` |
| [6] | `retido:` SECO É MALFORMADO — retenção sem razão recusa | `retido:` recusa; `retido:x` passa | `FAIL [6]: retenção sem razão é aceita` |
| [7] | TERCEIRO ESTADO POR FIAÇÃO ILEGÍVEL — manifesto sem marcador e `settings.json` ausente ou inválido recusa, e não resolve para "tudo ativo" nem "nada ativo" | a saída nomeia o arquivo e o código é o de "não consegui verificar" | `FAIL [7]: fiação ilegível resolve para um conjunto em vez de recusar` |
| [8] | A PONTE NÃO É GANCHO — na fixture cujo comando encadeia dois alvos, só o **último** entra no conjunto | acrescentar um terceiro alvo encadeado não aumenta o conjunto; a regra é estrutural e **não** por nome de arquivo | `FAIL [8]: o alvo anterior do comando foi contado como gancho` |
| [9] | MATCHER NÃO ANCORADO EM LINHA ARMADA RECUSA — em manifesto marcado | ancorar a mesma linha faz passar; é a guarda de §6.4 | `FAIL [9]: gancho armado com matcher de substring é aceito` |
| [10] | CENSO DA BASE INSTALADA, COM TERCEIRO ESTADO — quando as árvores de consumidor estão presentes no disco, cada `hooks.manifest` encontrado é classificado (canônico, cinco campos, quatro campos, não classificável) e o **piso** de dialetos examinados é afirmado; quando não estão, o cenário sai por "não consegui verificar" e **nunca por verde** | asserte **propriedade e piso** (`>= 2` dialetos entre as fixtures), nunca o literal 12 nem o literal 2 de árvores no disco — a invariante 14 | `FAIL [10]: não há classificador de dialeto` |
| [11] | SENTINELA — o gate publica o contador e reprova se o número de cenários executados divergir do denominador declarado | verde por construção; é o que impede o gate de aprovar por não ter olhado | verde por construção |

### 10.3 Prova de mutação — com controle, contrafactual medido e recontrole

A invariante 16 exige contrafactual medido **antes** de a linha ser escrita. Duas das cinco mutações abaixo eu já medi; as três restantes estão marcadas **A MEDIR** e o implementador as mede antes de escrever a matriz final, como a invariante manda.

| # | Mutação | O que o gate deve ACUSAR | Não pode derrubar | Contrafactual |
|---|---|---|---|---|
| M1 | fazer o modo de projeção **ler o campo 4** e resolver token desconhecido para ativo | `[3]` e `[4]` | `[2]`, `[5]` | **MEDIDO.** É o cruzamento de §3: o parser que lê o campo 4 fia 4 onde o dono fia 2, e os dois excedentes são os `retido:` |
| M2 | fazer a ativação da projeção **não** vir da fiação observada, e sim de "toda linha declarada é ativa" | `[3]` | `[2]`, `[5]` | **MEDIDO** na bancada de §10.4: sob a mutação, `ATIVOS` do `Axis.PadSimulator` sobe de 2 para 4, com os dois `retido:` incluídos |
| M3 | trocar o fail-closed do token desconhecido por fail-open | `[5]` | `[3]` — se `[3]` cair junto, ele está lendo o campo 4 alheio, que é o defeito de M1 reentrando | **A MEDIR** |
| M4 | contar **todo** alvo referenciado no comando como gancho, em vez do último | `[8]`, e `[3]` na fixture com ponte | `[2]` | **A MEDIR** — a leitura de §7.1 diz que o `axis-fare-validator` passaria de 6 para 7, mas o efeito sobre o cenário precisa ser observado, não deduzido |
| M5 | aceitar `retido:` seco | `[6]` | os demais | **A MEDIR** |

**Mecânica obrigatória da prova, e ela existe porque este plano já foi mordido duas vezes.** Controle antes, mutação, **prova de que o texto mudou** — não só o `sha` —, execução sob mutação, restauração por cópia do original conferida por `sha256`, e **recontrole**. A armadilha de LDG-0164 é literal e ela derrubou quem conhecia a regra: em `perl -0pi -e 's/x/y$var/'` o `$var` do lado **direito** é variável do **perl**, vazia, e a mutação vira no-op enquanto o `cmp` confirma que o arquivo mudou. O implementador **não** interpola variável de shell no lado direito de uma substituição do perl; se precisar de um valor variável, ele o injeta por outro primitivo e prova o texto resultante com `grep` na linha mutada.

Eu rodei essa mecânica inteira na bancada, sobre o meu leitor de projeção, para provar que ela discrimina:

```
sha antes  = adf0a192265ec541eff4315c8a7190c95f3729e3c158f5e5b844b7eb3ab21526
--- CONTROLE: PadSimulator, esperado 2 ativos ---
ATIVOS   (derivados do settings) = enforce-worktree-location.sh,prevent-secrets-leak.sh
sha depois = 29c46a65fa8aef8066b5538b0bd8649c5968a388cfa9aee87cb0b93cec755294
MUTACAO APLICADA (sha mudou)
-- prova de que o TEXTO mudou, nao so o sha --
21:const ativos = [...decl.keys()].filter((h) => true).sort();
--- SOB MUTACAO: PadSimulator ---
ATIVOS   (derivados do settings) = check-language-policy.sh,enforce-worktree-location.sh,prevent-secrets-leak.sh,validate-naming-conventions.sh
--- RESTAURACAO por checksum ---
RESTAURADO (sha bate com o original)
--- RECONTROLE ---
ATIVOS   (derivados do settings) = enforce-worktree-location.sh,prevent-secrets-leak.sh
```

O `grep` da linha 21 é a peça que a invariante 4 pede e que falta na maioria das provas: ele mostra o **texto** mutado, não apenas que o `sha` mudou. `cp` do original mais conferência de `sha` fecha a restauração, e o recontrole mostra o verde de volta.

### 10.4 Contador de controle, com denominador fixo

O gate publica, em toda execução, três números:

- **cenários executados / denominador declarado**, com o denominador fixo em doze. Divergência é o achado, e é o que `[11]` afirma.
- **fixtures examinadas**, com piso `>= 3` (as três formas: canônica marcada, cinco campos, quatro campos). Piso, nunca literal.
- **dialetos classificados no censo de `[10]`**, com piso `>= 2` e a partição nominal. Quando o censo não roda por ausência das árvores, o número é publicado como **não medido**, com o código de terceiro estado, e não como zero.

**Zero em qualquer um dos três reprova.** Gate que aprova por não ter olhado para nada é a falha que a invariante 3 nomeia, e ela já apareceu neste repositório.

### 10.5 Onde entram PBT, contrato, integração e E2E

**PBT — aplica-se, e é obrigatório.** O leitor de manifesto é um parser com espaço de entrada, e a invariante 5 lista "serializador de manifesto" nominalmente. Três propriedades, sobre linhas geradas:

1. **Nenhuma entrada resolve para "ativo" sem que o campo 4 seja literalmente `armado`.** É a propriedade que M3 muta e é a única que impede o fail-open de voltar por uma borda.
2. **Idempotência de leitura:** ler o mesmo texto duas vezes dá o mesmo conjunto, e o texto não é alterado pela leitura.
3. **Robustez ao colapso de tabulação**, e esta é uma propriedade que eu medi porque as duas árvores divergem nela:

```
split(/\t+/) -> ["hook.sh","^Bash$","stdin-json","razao-com-universo-vazio"]
split("\t")  -> ["hook.sh","^Bash$","stdin-json","","razao-com-universo-vazio"]
```

O parser do `axis-fare-validator` colapsa tabulações consecutivas e o do `Axis.PadSimulator` não. Numa linha com campo vazio no meio, o primeiro promove a **razão** ao campo 4. Sob um leitor canônico que lê o campo 4 como `estado`, isso significa que **prosa de justificativa vira token de estado**, e o desfecho depende inteiramente de D4 estar certo. A PBT gera linhas com campos vazios em cada posição e afirma que nenhuma delas produz ativação; a implementação escolhe o primitivo de separação e prova que ele discrimina, porque este é exatamente o tipo de detalhe que a invariante 19 proíbe a especificação de prescrever sem ter executado.

**Teste de contrato — aplica-se, e a fronteira é publicada.** O formato do manifesto passa a ser contrato com **dois adotantes instalados** e cinco leitores em produção, nenhum deles do produtor. Os cenários `[2]`, `[3]`, `[5]` e `[9]` são o teste de contrato, e a decisão de retrocompatibilidade está escrita em §9, nominalmente por leitor.

**Integração — aplica-se, mas do outro lado da fronteira.** O caminho "manifesto → `preToolUseWiring` → `settings.json`" é da Onda L1; o cenário `[3]` desta onda afirma o **contrato** que L1 precisa satisfazer (igualdade de conjunto com a fiação anterior), sem tocar o gerador. Especificar aqui a integração seria especificar duas vezes a mesma peça, com duas ondas em voo — que é o defeito que a leitura cruzada das duas especificações existe para evitar.

**E2E — NÃO se aplica nesta onda, e a justificativa é medida.** O E2E honesto seria "o Claude Code invoca o gancho fiado e ele bloqueia", e ele exige o runtime da ferramenta, que nenhuma suíte deste repositório controla. O que existe hoje como aproximação é `tests/snapshot/claude-contract.bats` — **o único** arquivo de `tests/` que menciona `PreToolUse` ou `pre-tool-use`, conferido por `grep -rlF` —, e o cenário C5 dele afirma `wired -eq 1` sobre uma árvore gerada. Esta onda **não** altera o gerador, então C5 continua verde e não entra na lista da invariante 15. Quando L1 alterar o gerador, C5 muda por conta dela, e a Onda L1 §13 já o registra.

### 10.6 Invariante 15 — as strings que a produção imprime

Esta onda **não altera** nenhuma string existente da produção; ela só acrescenta mensagens novas. Varredura conferida com `/usr/bin/grep -arl` — e não com o `grep` do `PATH`, pela razão de LDG-0177 registrada em §3.1: `hooks.manifest` e `forge-manifest-format` devolvem **zero** ocorrências reais em `template/ bin/ installer/ plugin/ tests/`, com controle positivo plantado e achado nas duas, e com o instrumento provado vivo sobre o único arquivo de código não-texto da árvore. **Nenhum gate existente afirma qualquer string desta onda**, e a lista nominal de gates a editar junto é, portanto, **vazia**. Se durante a implementação alguma mensagem existente precisar mudar, a varredura é refeita e a lista entra na definição de pronto antes do commit.

---

## 11. O que fica para conversa com o campo — e o corpo da mensagem, redigido e NÃO enviado

Esta é a parte honesta que o item pede. A separação é esta:

**Implementável unilateralmente AGORA, sem quebrar ninguém:**

1. O formato canônico v1 e o seu leitor no produtor (D1). Nenhuma árvore instalada tem o marcador, então nenhuma é afetada.
2. O modo de projeção (D3). Medido: reproduz exatamente a fiação de hoje nas duas árvores, sem que ninguém edite um byte.
3. O fail-closed de token desconhecido dentro do formato marcado (D4). Só morde manifesto marcado, e não existe manifesto marcado no campo.
4. O gate de doze cenários, com as três fixtures e o censo de terceiro estado.
5. A documentação distribuída do formato, como exemplo comentado.

**Depende de resposta dos dois adotantes, e NÃO é decidido nesta onda:**

1. **Se e quando cada árvore escreve o marcador**, e portanto quando ela sai da projeção e entra no formato canônico. É decisão do dono da árvore, e a projeção existe para que ela nunca seja forçada.
2. **Para o `axis-fare-validator`, a quebra do `gate-universe-not-blind.test.sh`** no dia da migração (§9). Ele precisa saber, antes de migrar, que o gate dele lê o campo 4 posicionalmente e vai ler `armado` como universo.
3. **Para o `Axis.PadSimulator`, o enfraquecimento silencioso do B8** se ele acrescentar campo 5 (§9). É a pior das duas quebras, porque é silenciosa: o cenário passa a pular todas as linhas e fica verde.
4. **Para o `Axis.PadSimulator`, a revalidação do matcher das duas linhas retidas** antes de qualquer armação futura (§2.2 e §6.4).
5. **Para o `axis-device-platform`, o dado que eu não consigo ler**: existe `hooks.manifest` naquela árvore, e em que esquema.
6. **Se `universo` deve virar propriedade obrigatória** no formato canônico, ou seguir opcional. Nesta versão é opcional, e a razão é que só uma árvore tem gate que a consome; tornar obrigatório o que só um adotante mede seria o produtor legislar sobre a régua do outro.

### 11.1 Corpo da mensagem — canal `forge-harness`, fio `upgrade-desarma-o-proprio-ponto-de-entrada`, destinatários `axis-fare-validator`, `axis-pad-simulator` e `axis-device-platform`, `requires_ack: true`

> **Assunto:** o formato do `hooks.manifest` — vocês escreveram o contrato duas vezes antes de nós, e a nossa proposta é a UNIÃO dos dois, com uma migração que não pede que vocês editem o arquivo
>
> Nós medimos as duas árvores por leitura direta, e o resultado é que o produtor chega por último a um contrato que o campo já resolveu. O `axis-fare-validator` tem 63 linhas, 6 declarações e cinco campos, com **universo** no quarto e prosa de justificativa no quinto. O `axis-pad-simulator` tem 38 linhas, 4 declarações e quatro campos, com **estado** no quarto, `armado` ou `retido:<razão>`. Os dois cabeçalhos chegaram, de forma independente, à mesma conclusão sobre por que a declaração não pode viver dentro de cada gancho — o overlay do upgrade a apagaria — e o cabeçalho do `axis-pad-simulator` credita o desenho ao `axis-fare-validator`. Nada disso veio de nós.
>
> **O que medimos, e é o motivo desta mensagem.** Copiamos os **dois parsers de produção**, literalmente dos vossos `sync-adapters.mjs`, e cruzamos cada um contra o manifesto do outro. O parser do `axis-fare-validator`, aplicado ao manifesto do `axis-pad-simulator`, **fia quatro ganchos onde o dono fia dois**, com `rc` de sucesso e nenhuma linha de saída — e os dois excedentes são exatamente o `check-language-policy.sh` e o `validate-naming-conventions.sh`, que o `axis-pad-simulator` retém com razão medida escrita na linha. O parser do `axis-pad-simulator`, aplicado ao manifesto do `axis-fare-validator`, lança nomeando o gancho e o token. Um desfecho é silencioso e arma o que foi deliberadamente retido; o outro é barulhento e não desarma nada. Foi essa assimetria, e não preferência, que decidiu o resto.
>
> **A proposta, em quatro pontos.**
>
> **1. O formato canônico é a união, porque vocês acertaram metade cada um.** `universo` e `estado` são propriedades ortogonais: um gancho pode estar armado e cego, e pode estar retido com universo largo. Campos 1 a 3 ficam como estão nos dois — `hook`, `matcher`, `contrato` —, porque é onde vocês já concordam, valor a valor. O campo 4 passa a ser `estado`, posicional, vocabulário fechado `armado` ou `retido:<razão>`. Do campo 5 em diante, `chave=valor`, com `universo=` e `razao=` na v1. Uma linha de cabeçalho `# forge-manifest-format: 1` marca o formato.
>
> **Por que `estado` no campo 4 e `universo` nomeado, e não o contrário.** `estado` é o único campo que a fiação consome — errar `estado` arma ou desarma um gancho, errar `universo` não muda a fiação em byte nenhum. Notamos que o parser do `axis-fare-validator` sequer lê o campo 4; quem o lê é o `gate-universe-not-blind.test.sh`. O campo que decide segurança fica na posição obrigatória, onde a omissão é erro de aridade e não um `chave=valor` que some com um erro de digitação. E há a consequência prática: o `axis-pad-simulator` já é canônico nos campos 1 a 4 e converge **sem mover campo nenhum**; o `axis-fare-validator` precisa escrever `estado` de qualquer forma, porque hoje não tem o conceito.
>
> **2. A migração NÃO pede que vocês reescrevam o arquivo.** Diante de um manifesto sem o marcador, o nosso leitor opera em **projeção**: consome apenas os campos 1 a 3, **nunca** lê o campo 4, e deriva a ativação do `.claude/settings.json` que já está na árvore. Rodamos isso nas duas: reproduz **exatamente** a fiação de hoje — 6 de 6 no `axis-fare-validator`, 2 de 4 no `axis-pad-simulator`, e os 2 inativos derivados são precisamente os dois `retido:`. A informação que vocês escreveram no campo 4 chega até nós pelo efeito dela, não pelo texto dela. Enquanto vocês não escreverem o marcador, nada muda nas vossas árvores, e nós não lemos o campo em disputa.
>
> **3. Token desconhecido é fail-closed, e nós adotamos a vossa decisão.** Dentro do formato marcado, um `estado` fora do vocabulário faz recusar a geração inteira, nomeando o gancho e o token, sem escrever o `settings.json` — que continua como estava, então nada que estava armado é desarmado. É literalmente o que o `sync-adapters.mjs` do `axis-pad-simulator` já faz na linha 259. Fail-open reativaria em silêncio os ganchos que vocês retiveram com razão medida, e não vamos fazer isso.
>
> **4. Três avisos que vocês precisam ter ANTES de migrar, e que descobrimos lendo o vosso código.**
>
> **`axis-fare-validator`:** o vosso `gate-universe-not-blind.test.sh` exige `len(col) >= 5` e depois lê posicionalmente `read -r hook _matcher _contrato universo _resto`. No dia em que `estado` entrar no campo 4, ele vai ler `armado` como universo, `git ls-files "*armado"` devolve zero e ele reprova o gancho como cego. É falso positivo barulhento, corrigível numa linha, mas é quebra — e é vossa, não nossa.
>
> **`axis-pad-simulator`:** o cenário B8 do vosso `pretooluse-fiacao.test.sh` lê `while IFS=$'\t' read -r h m c e`. Com quatro nomes e `IFS` de tabulação, o quarto nome recebe **todo o resto da linha**. No dia em que vocês acrescentarem um campo 5, `e` vira `armado<TAB>universo=*`, a comparação `[ "$e" = "armado" ]` falha, o cenário passa a pular todas as linhas e fica **verde por não ter olhado**. Esta é a pior das duas, porque é silenciosa. E um segundo ponto: as vossas duas linhas retidas têm matcher **sem âncora** (`Write|Edit`), o que hoje é inofensivo porque o gerador nunca as emite — mas se alguma delas for armada um dia, o matcher precisa ser revalidado antes, pela razão que o vosso próprio cabeçalho documenta com a medição de `TodoWrite`.
>
> **`axis-device-platform`:** nós **não conseguimos ler** a vossa árvore desta máquina — ela não está sob `~/Documents/projects` com esse nome. Não sabemos se vocês têm `hooks.manifest` nem em que esquema. Registramos isso como "não verificado", e não como "não tem". Se vocês tiverem o arquivo, o esquema de vocês entra na decisão antes de ela fechar.
>
> **O que pedimos.** Um ack de cada um dizendo: se a união serve; se `estado` no campo 4 e `universo` nomeado é aceitável, ou se há razão medida do vosso lado para o contrário; se `universo` deve ser obrigatório no formato canônico ou seguir opcional (hoje só uma árvore tem gate que o consome, e por isso deixamos opcional); e, no caso do `axis-device-platform`, o censo do que existe aí. Nada disto bloqueia a nossa entrega, porque a projeção não toca nas vossas árvores — mas o formato canônico só fecha com a vossa resposta, e nós preferimos fechá-lo com vocês do que por cima de vocês.

**Esta mensagem NÃO é enviada por esta especificação.** O envio é operação de canal e pertence à onda de liaison, com `requires_ack: true`, e o `check-liaison-acks.sh` passa a cobrar os acks.

---

## 12. O que esta onda explicitamente NÃO faz

1. **Não implementa a ponte de despacho `stdin` → `argv`.** É da Onda L1, §D5. Esta onda só declara que o alvo anterior de um comando encadeado não é gancho (§7.1), como propriedade estrutural.
2. **Não altera `template/.forge/scripts/lib/sync-adapters.mjs`.** O leitor nasce como módulo puro com o seu próprio gate; a fiação dele no gerador é da Onda L1, e a emenda que L1 precisa está escrita em §7.2.
3. **Não escreve o `hooks.manifest.default` com conteúdo definitivo.** §2.4 mede que o `contrato` de um gancho é fato da árvore que o instalou, porque os dois adotantes bifurcaram o próprio `prevent-secrets-leak.sh`. O `default` é piso sobreponível e o seu conteúdo é da onda que o distribuir.
4. **Não escreve em consumidor nenhum.** Toda leitura das doze árvores foi pura. Nenhum arquivo fora de `forge-harness` foi tocado.
5. **Não envia mensagem de canal.** §11 redige o corpo; o envio é da onda de liaison.
6. **Não aloca ordinal de gate.** `w208` é o que o alocador devolve hoje, mas ele só lê `origin/develop` (LDG-0173) e há outras frentes em voo; a alocação é do orquestrador.
7. **Não decide se `universo` vira obrigatório.** Fica opcional na v1, com a razão em §11 item 6, e a decisão é do campo.
8. **Não toca a base de dez árvores sem manifesto.** O caminho delas é o semeador da Onda L1.
9. **Não afirma nada sobre o `axis-device-platform`.** Terceiro estado declarado, e §11 pede o dado.

---

## 13. Inventário do que eu executei, com a saída colada

Toda medição desta especificação veio de leitura pura das árvores ou de bancada própria sob o scratchpad da sessão. Nenhum gate da suíte foi executado.

- leitura integral dos dois `hooks.manifest`, com `cat -n`, incluindo os 57 e os 33 comentários de cabeçalho;
- censo de largura de campo com `awk -F'\t' '!/^#/ && NF>0 {print NF}' | sort -u`, `wc -l` e `grep -c '^[^#]'`;
- censo das **doze** árvores com `.forge/` em `~/Documents/projects`, com `forge.yaml`, `machinery.lock`, contagem de `.sh`, presença de manifesto, alvos distintos no `settings.json` e classificação do gerador local;
- **cruzamento dos dois parsers de produção** contra os dois manifestos reais, com os parsers copiados literalmente dos `sync-adapters.mjs` de cada árvore — a saída de quatro linhas de §3;
- leitor ingênuo de "campo 4 como estado, desconhecido cai para ativo" contra o `axis-fare-validator`, e leitor ingênuo de "campo 4 como universo" contra o `Axis.PadSimulator`;
- leitor de **projeção** contra as duas árvores, com o conjunto de ativos e inativos derivado do `settings.json` de cada uma;
- bancada de mutação completa sobre o leitor de projeção: controle, mutação, `grep` da linha mutada, execução sob mutação, restauração conferida por `sha256` e recontrole;
- varredura de ausência de `hooks.manifest` e `forge-manifest-format` em `template/ bin/ installer/ plugin/ tests/`, com **controle positivo plantado e achado**, removido depois, e **refeita com `/usr/bin/grep -a`** depois de LDG-0177 entrar no ledger, com prova de vida do instrumento sobre o `secret-scan.mjs` (3 ocorrências de `AKIA` pelo BSD, silêncio pelo `ugrep` do `PATH`);
- `grep -rlF "PreToolUse"` e `grep -rlF "pre-tool-use"` sobre `tests/`, que devolvem **um único** arquivo, `tests/snapshot/claude-contract.bats`, e a leitura do cenário C5 dele;
- comparação de `sha256` do `prevent-secrets-leak.sh` do template contra quatro consumidores, e leitura das 40 primeiras linhas do fork de 21974 bytes do `Axis.PadSimulator`;
- leitura dos parsers e dos cinco leitores instalados: `sync-adapters.mjs` das duas árvores, `gate-universe-not-blind.test.sh`, `hook-matcher-casa-as-ferramentas.test.sh` e `pretooluse-fiacao.test.sh`;
- propriedade do "último alvo é o gancho", medida sobre os `settings.json` das duas árvores;
- divergência de `split(/\t+/)` contra `split('\t')` numa linha com campo vazio no meio;
- inventário dos 29 fios do canal de liaison e leitura dos 22 últimos eventos dos fios `upgrade-desarma-o-proprio-ponto-de-entrada` e `o-gerador-tambem-esta-no-lock`;
- `gate-ordinal.sh next --path tests` e o máximo de ordinal de todas as branches locais e remotas.

## 14. O que eu declarei como propriedade sem executar

A invariante 19 obriga a separar. Está declarado como propriedade e contrafactual, sem prescrição de primitivo, porque eu **não** executei: o leitor canônico do formato marcado e a guarda de matcher não ancorado de §6.4; a guarda de `retido:` seco de §8; o código de saída do terceiro estado e a sua distinção dos outros dois, cuja alocação é coordenada com a Onda L1; as três propriedades de PBT de §10.5, das quais só a divergência de tabulação foi medida; o efeito das mutações M3, M4 e M5, marcadas **A MEDIR** na própria matriz; o comportamento do estado 6 de §7.1 com `settings.json` inválido; e a igualdade de conjunto de §7.2 sob o gerador real de L1, que eu não executei porque o gerador ainda não existe.

Uma retratação minha, em primeira pessoa, porque ela é evidência e não nota de rodapé: eu escrevi a primeira versão de §4 com o denominador de **cinco** consumidores, copiado do texto do item, antes de varrer o disco. O item diz cinco, a Onda L1 diz seis, e são **doze** árvores de consumidor nesta máquina mais uma que eu não consigo ler. Eu só descobri porque fui procurar o `axis-device-platform` e não o achei — se ele estivesse lá, eu teria fechado a especificação com o denominador errado e com a mesma confiança.

---

## 15. Correções da implementação

Escrito pelo implementador de LDG-0178, em 2026-09-08, depois de executar. Esta seção tem **precedência sobre o corpo** onde as duas divergirem. Cada correção nasce de um bloqueador da revisão independente ou de uma medição que a própria implementação produziu, e nenhuma delas é opinião: todas têm a saída colada abaixo ou no relatório da sessão.

### 15.1 A lista nominal de gates a editar NÃO era vazia — bloqueador 1, confirmado por execução

§10.6 afirmava em letra que "a lista nominal de gates a editar junto é, portanto, vazia". Ela estava errada, e a razão é a invariante 14 e não a 15: o `w200` não afirma nenhuma string desta onda, ele afirma dois **números** que a onda faz envelhecer. Medido com os dois arquivos novos já no disco:

```
FAIL [1]: inventário do README defasado em 'template/.forge/scripts/' — declarado (136), real (137)
FAIL [6]: o badge do README diz 131 gate(s) e a árvore tem 132 — a mesma contagem à mão que este gate existe para impedir
```

A correção entra no mesmo commit: `README.md:12` passa de `gates-131%20passing` para `gates-132%20passing`, e `README.md:235` passa de `scripts/ (136)` para `scripts/ (137)`. Reconferido depois do bump, com os dois arquivos novos existindo:

```
OK [1] — 7 de 7 contagens conferidas (0 divergente)
OK [6] — badge e árvore concordam em 132 gate(s)
```

**Nota de reconciliação, registrada porque ela é evidência do risco que a invariante 10 nomeia.** Durante esta sessão, a onda de LDG-0177 acrescentou `tests/w209-varredura-cega-gate.sh` à mesma árvore de trabalho, e o badge saltou de 132 para 133 por mão alheia. As duas ondas não colidiram em ordinal — `w208` aqui, `w209` lá —, mas as duas disputam o mesmo literal do badge, e o `w200` fica vermelho para quem chegar em segundo até que alguém some os dois deltas. O estado final medido é `OK [6] — badge e árvore concordam em 133 gate(s)` e `OK [1] — 7 de 7 contagens conferidas (0 divergente)`, com o `scripts/ (137)` desta onda preservado. **O delta desta onda é +1 gate e +1 script; se ela for commitada sozinha, o badge correto é 132 e não 133.**

**A lista nominal de gates desta onda é, portanto, exatamente esta: `tests/w200-readme-inventory-gate.sh`, cenários [1] e [6].** Conferido também o que NÃO entra: `tests/run-all.sh` e `tests/w80-suite-gate.sh` derivam a lista por glob e não têm literal; `template/.forge/templates/` não é declarado no bloco `## 📁 Estrutura` e por isso não afeta o `w200`.

### 15.2 A varredura da invariante 15 precisa de um segundo eixo, e ele encontrou um defeito real no gate novo

A invariante 15 manda varrer `tests/` **pela string** que muda. Essa varredura é necessária e não é suficiente: o `w145-shell-pipeline-lint-gate.sh` não afirma string nenhuma desta onda e mesmo assim reprovou o gate novo, porque ele varre por **forma** sobre o universo de todo `.sh` do harness. O achado, com o arquivo e a linha:

```
FAIL shell-pipeline — 1 pipeline(s) terminando em 'grep -q' com '||'/'&&' na sequência, sob pipefail:
      tests/w208-hooks-manifest-esquema-gate.sh:373: produtor "!" antes de grep -q, seguido de ||
        elif ! printf '%s\n' "$out5" | grep -qF 'enforce-worktree-location.sh' || ! printf '%s\n' "$out5" | grep -qF '.cs,.java'; then
```

`grep -q` sai no primeiro casamento, o produtor leva `SIGPIPE`, o pipeline devolve 141 e o `pipefail` promove a falha, de modo que a ação do `||` rodaria pelo motivo errado. As seis ocorrências do gate novo foram reescritas com herestring (`grep -qF -- '<alvo>' <<<"$out"`), que elimina o pipeline, e o `w145` voltou a `PASS`. **A generalização, que vale para as demais ondas desta rodada: um arquivo NOVO entra no universo de todo gate que varre por forma, e a lista da invariante 15 precisa incluir os gates de lint de universo aberto (`w145`, `w159`), não apenas os que afirmam a string.**

### 15.3 O cenário [10] foi reescrito — bloqueador 2, aceito integralmente

A redação anterior de [10] fazia a suíte sair por terceiro estado em toda máquina sem as árvores de consumidor no disco, e `run-all.sh` tem exatamente dois desfechos por gate, sem canal de skip: o resultado seria a suíte permanentemente vermelha no CI, com a implementação correta. Além disso §10.2 e §10.4 se contradiziam sobre qual régua vale. A versão implementada é esta: **[10] classifica exclusivamente as fixtures deste repositório**, com piso de dois dialetos distintos medido sobre elas, e o censo das doze árvores externas permanece como medição de §4, fora da suíte. O terceiro estado é exercido como **valor de retorno** do módulo, afirmado por [7] (a fiação ilegível resolve para `nao-verificado`, com o código nomeado e comparado contra o código de "sem violação") e por [12] (os quatro desfechos têm códigos distintos dois a dois), e os dois cenários terminam **verdes**. É o padrão do `w206`, em que o rc 4 é do produto sob teste e o cenário que o afirma passa.

### 15.4 A enumeração de §7.1 ganhou três estados e duas declarações de fronteira — bloqueador 3, aceito, mais o estado 10 de §15.9

A tabela de §7.1 perdia o caso que faz a própria decisão D3 produzir o defeito que a onda combate. A enumeração implementada é esta:

| # | Estado | Desfecho implementado |
|---|---|---|
| 1 | manifesto ausente | fora desta onda — é o semeador de L1 |
| 2 | marcado, bem formado, com pelo menos um `armado` | `ok`, código 0, campo 4 é `estado` |
| 3 | marcado, token de `estado` desconhecido | `recusa`, código 1, nomeando gancho, token e número da linha |
| 4 | marcado, aridade < 4 | `recusa`, código 1, nomeando a linha e a aridade observada |
| 5 | sem marcador, fiação legível e não vazia | `ok`, código 0, por projeção dos campos 1 a 3 |
| 6 | sem marcador, fiação ausente ou ilegível | `nao-verificado`, código 4, nomeando o arquivo |
| 7 | sem marcador, e a fiação tem `.sh` sem linha declarada | não é erro: o alvo anterior de comando encadeado vira despachante, e o resto vira **aviso nomeado** — é o caso real do `dispatch-file-hook.sh` |
| **8** | **sem marcador, fiação LEGÍVEL e VAZIA (ou que não arma nenhum gancho declarado)** | **`recusa-por-vacuidade`, código 5, nomeando o arquivo.** É a guarda que os dois adotantes escreveram por conta própria, e sem ela a projeção derivaria conjunto vazio e devolveria "nenhum gancho armado" com sucesso, que é o desarme silencioso pelo qual este item existe |
| **9** | **marcado, bem formado, e com ZERO linhas `armado`** | **`recusa-por-vacuidade`, código 5**, pela mesma razão: o efeito sobre o consumidor é idêntico, não há fiação a emitir, e devolver isso como sucesso é o mesmo desarme com outra causa |
| **10** | **sem marcador, fiação legível, e um comando de `PreToolUse` sem alvo `.sh` reconhecível** | **`nao-verificado`, código 4, nomeando o comando.** Acrescentado em §15.9 depois do review adversarial. 'não consegui reconhecer alvo neste comando' é o terceiro estado, e colapsá-lo em 'este comando não fia gancho nenhum' fazia o leitor devolver como INATIVO um gancho realmente armado na árvore, com desfecho de sucesso e avisos vazios |

**Os dois casos de reconciliação diretório-por-manifesto ficam declarados por escrito como fora do alcance deste módulo, e a razão é estrutural e não esquecimento:** o módulo é puro e **não recebe o diretório** `pre-tool-use/`, então ele não enxerga nem um `.sh` presente no diretório sem linha declarada, nem uma linha `armado` cujo `.sh` não existe no disco. Os dois são guardas do **gerador**, e pertencem à Onda L1, que recebe o diretório; a declaração está escrita no cabeçalho do próprio módulo distribuído, para que a ausência seja decisão registrada e verificável, não silêncio.

### 15.5 O denominador de cenários passa de doze para vinte e dois, e a numeração mudou duas vezes

O gate implementado declarou primeiro **quinze** cenários, `[0]` a `[14]`, e o denominador continua fixo por construção, que é a única exceção legítima da invariante 14. A primeira mudança veio dos estados novos de §15.4 e da separação do terceiro estado do seu código: `[11]` é a vacuidade, `[12]` afirma que os quatro desfechos têm códigos distintos dois a dois, `[13]` é a PBT. O antigo `[11]` sentinela virou `[14]`.

A segunda mudança veio do review adversarial, que mediu sete guardas vivas sem cenário que as observasse, e está em §15.9: os cenários `[14]` a `[20]` são novos, a sentinela passou de `[14]` para `[21]`, e o **denominador final é vinte e dois**, `[0]` a `[21]`. A sentinela ganhou um quarto piso, `canais_de_aviso >= 3`, porque o canal `avisos` era o que estava invisível.

### 15.6 A matriz de mutação declarada estava errada em duas linhas, e a medição real é esta

As linhas M1 e M2 estavam marcadas **MEDIDO**, mas o que fora medido era o efeito sobre o leitor de bancada do especificador, e não sobre os cenários — que ainda não existiam. Medidas de verdade agora, contra o gate real, com controle, prova de **texto** por `grep` na linha mutada, restauração por `sha256` e recontrole, sempre sobre uma **cópia** sob `$TMPDIR` pelo seam `HM_MOD`:

| # | Mutação | Declarado antes | **MEDIDO agora** |
|---|---|---|---|
| M1 | a projeção passa a LER o campo 4 e resolve desconhecido para ativo | `[3]` e `[4]` | **`[4]` e `[11]`. `[3]` NÃO cai** |
| M2 | a ativação da projeção deixa de vir da fiação observada: toda linha declarada é ativa | `[3]` | **`[3]` e `[11]`** |
| M3 | o fail-closed do token desconhecido vira fail-open | A MEDIR | **`[5]` e `[13]`** |
| M4 | todo alvo do comando encadeado conta como gancho, em vez de só o último | A MEDIR, supondo `[8]` e `[3]` | **só `[8]`. `[3]` NÃO cai** |
| M5 | `retido:` seco passa a ser aceito | A MEDIR | **`[6]`** |

**O achado de M1 é o mais importante da onda, e ele confirma empiricamente o que §3 já suspeitava.** O cenário `[3]`, sozinho, **não discrimina** o defeito central de LDG-0178: sob M1, a projeção que lê o campo 4 continua produzindo o conjunto certo nas duas fixtures, porque o fail-open acerta por acidente numa árvore que não retém nada e a árvore que retém usa vocabulário que a mutação entende. Quem discrimina é `[4]`, que muta o campo 4 e exige o mesmo conjunto — e é por isso que `[4]` passou a exigir que o conjunto de controle seja **não vazio**, depois que a primeira versão dele comparou dois conjuntos vazios e aprovou por vacuidade. **Uma especificação que só tivesse `[3]` teria declarado o defeito coberto e não estaria.**

O achado de M4 tem a mesma natureza: contar todo alvo encadeado como gancho não derruba `[3]`, porque os despachantes contados a mais não têm linha declarada no manifesto e por isso não entram no conjunto de ativos da projeção. Só `[8]` morde.

Saída da bancada, com o rito completo de uma das cinco linhas:

```
sha do original = 219a257ec339c9960cfc8c0c0b8850d6c2d4bb3cb50d44513af9238e816aba45
--- CONTROLE (cópia intacta): OK [14] — 15 de 15 cenários executados; pisos respeitados | quebrados: []
=== M1 — projeção lê o campo 4 e resolve desconhecido para ativo
  texto mutado, linha real: 242:  const ativos = decls.filter((d) => !String(d.campos[3] || '').startsWith('retido:')).map((d) => d.campos[0]);
  cenários que ACUSARAM: [[11] [4] ]
  RESTAURADO (sha bate com o original)
  RECONTROLE: OK [14] — 15 de 15 cenários executados; pisos respeitados | quebrados: []

arquivo RASTREADO antes  = 219a257ec339c9960cfc8c0c0b8850d6c2d4bb3cb50d44513af9238e816aba45
arquivo RASTREADO depois = 219a257ec339c9960cfc8c0c0b8850d6c2d4bb3cb50d44513af9238e816aba45
o arquivo rastreado NÃO foi tocado por nenhuma mutação
```

Nenhuma das cinco substituições interpola variável de shell no lado direito do `perl`, que é a armadilha de LDG-0164, e a prova de que o texto mudou vem do `grep` na linha real, não do `cmp`.

**Rerodada depois das correções de §15.9, contra o gate de vinte e dois cenários, sempre sobre cópia em `$TMPDIR` pelo seam `HM_MOD`.** As cinco linhas continuam válidas, e nenhuma delas passou a cair em cenário novo: M1 derruba `[4]` e `[11]`, M2 derruba `[3]` e `[11]`, M3 derruba `[5]` e `[13]`, M4 derruba só `[8]` e M5 derruba só `[6]`. O recontrole confirma o arquivo rastreado intocado, com o `sha256` `4d00cc8d2be5…` antes e depois das quatorze mutações desta rodada.

### 15.7 As ressalvas do revisor, uma a uma

- **§5 tem título de "três interpretações" e tabela com quatro caminhos.** Confirmado; são **quatro** (A, B, C, D), e o título está errado. A tabela é que vale.
- **Asserção morta em [5].** Confirmado e removida: o módulo é puro e nunca escreve, então "o `settings.json` da fixture fica intocado" não pode falhar. A asserção viva de `[5]` é o código próprio de recusa mais o fato de nenhum conjunto de ativos ser devolvido junto com a recusa, que é o que a implementação afirma hoje.
- **[3] com comparação circular.** Evitado: os conjuntos esperados são literais escritos à mão no gate, a partir da leitura das duas árvores, e o módulo sob teste nunca os rederiva.
- **[0] não provava o caminho canônico.** Corrigido: `[0]` anuncia o caminho canônico esperado e, quando ele não existe, imprime em letra que o vermelho dos demais cenários é por ausência real e não por caminho digitado errado. O vermelho observado antes da implementação confirma: `[0]` saiu **verde** com as três fixtures válidas, e `[1]` a `[13]` saíram vermelhos com `Cannot find module '.../hooks-manifest.mjs'` — instrumento vivo, funcionalidade ausente.
- **A guarda de §6.4 colide com o `matcher: 'Bash'` que o produtor emite hoje.** Confirmado e delimitado: a guarda de matcher ancorado morde **apenas manifesto MARCADO**, e não existe manifesto marcado no campo, então nada quebra hoje. Fica declarado aqui, para a Onda L1: **o `hooks.manifest.default` do produtor precisa nascer com matcher ancorado**, ou o primeiro manifesto marcado que ele semear será recusado por esta guarda. Esta onda não altera `sync-adapters.mjs` e não corrige o literal de lá.

### 15.8 Duas decisões tomadas em modo yolo, com a razão

1. **O ordinal alocado é `w208`.** `gate-ordinal.sh next --path tests` devolve `w208`, e a conferência contra **todas** as refs locais e remotas — e não só `origin/develop`, que é o defeito de LDG-0173 — dá máximo `w207` em `develop`, `main` e nesta branch, `w80` em `origin/wip/deepspec-run-manifest-ldg-0165` e `w154` em `origin/wip/upgrade-safety-ldg-0131`. A Onda L1 pede quatro ordinais a partir do mesmo `w208`, então **se as duas ondas forem para o mesmo tronco, uma delas renumera**, e o orquestrador é quem decide qual.
2. **`template/.forge/templates/hooks.manifest.exemplo` NÃO foi criado.** §0 o listava como documentação, e a documentação existe — ela vive no cabeçalho do próprio `hooks-manifest.mjs`, que é distribuído no pacote e traz o exemplo comentado com as quatro regras de formato. Um arquivo separado ampliaria o universo de gates que varrem a árvore sem acrescentar informação, e a onda já pagou esse pedágio uma vez em `w200` e outra em `w145`.

### 15.9 Os sete achados do review adversarial, e o que cada um mudou

Escrito depois de reproduzir cada achado com comando próprio e de rodar cada mutação contra o gate. Dez achados vieram; sete procederam e foram corrigidos, um é do README e pertence ao orquestrador, um foi refutado por medição, e o décimo já estava registrado.

**Dois defeitos de PRODUÇÃO, não de cobertura.**

1. **Comando de `PreToolUse` sem alvo `.sh` reconhecível era engolido em silêncio, e é o pior dos dez.** `derivarFiacao` derivava os alvos de `comando.split(/\s+/).filter((t) => t.endsWith('.sh'))` e, com a lista vazia, seguia sem registrar nada. Duas formas realistas caíam nisso: caminho entre aspas — higiene de shell perfeitamente comum, e o token termina em `.sh"` — e dois ganchos encadeados por `;`, em que o primeiro token termina em `.sh;`. Medido contra o módulo então rastreado, com os dois ganchos REALMENTE fiados: `ativos = ["enforce-worktree-location.sh"]`, `inativos = ["prevent-secrets-leak.sh"]`, `desfecho = ok`, `avisos = []`. O leitor mentia sobre o estado do consumidor, e é o mecanismo exato que desarma gancho retido deliberadamente. A correção tem duas partes: o comando é dividido em comandos SIMPLES pelos separadores de shell antes de procurar alvo — o que também acerta a semântica, porque `a.sh; b.sh` são dois ganchos independentes e não uma ponte seguida de um gancho —, cada alvo é desencapado de aspas e parênteses, e um comando simples não vazio sem alvo reconhecível sai em `naoReconhecidos`, que a projeção resolve por `nao-verificado`. É o estado 10 da enumeração de §15.4. Retrocompatibilidade reconferida em leitura das duas árvores instaladas: `axis-fare-validator` continua `projecao / ok / 6 ativos / 0 inativos`, e `Axis.PadSimulator` continua `projecao / ok / 2 ativos / 2 inativos`, byte por byte a mesma leitura de antes.

2. **O campo 3 não tinha vocabulário, e o campo 4 tinha — assimetria de rigor entre dois campos posicionais que ambos governam comportamento.** Medido contra o módulo então rastreado: `"argvv"`, `""`, `"ARGV"` e `"qualquer coisa"` no campo 3 saíam todos com `desfecho = ok` e o valor repassado verbatim, sem aviso. O campo 3 decide por qual canal o gancho recebe o payload, isto é, COMO ele é invocado, e §2.4 mede o que acontece quando o payload não chega pelo canal esperado — o detector do `Axis.PadSimulator` sai por `exit 2` fail-closed. **Decisão, e ela é assimétrica de propósito:** no formato MARCADO o vocabulário fecha em `argv` e `stdin-json`, e um token fora dele recusa nomeando o gancho e o token, porque ali o produtor é dono do formato; na PROJEÇÃO o mesmo token vira AVISO nomeado e nunca recusa, porque ali o leitor está lendo um arquivo que não escreveu, o campo 3 não participa da derivação da ativação, e recusar a árvore inteira por causa dele quebraria a retrocompatibilidade que é a premissa da onda. O custo é zero na base instalada, medido linha a linha: as dez declarações das duas árvores usam exclusivamente `argv` e `stdin-json`, e de todo modo não existe manifesto MARCADO no campo.

**Cinco guardas vivas que nenhum cenário observava.** Cada uma foi confirmada removendo-a de uma cópia sob `$TMPDIR` pelo seam `HM_MOD` e vendo os quinze cenários passarem verdes; cada uma ganhou o seu cenário, e a mutação foi rerodada contra o gate novo para provar que agora ela ACUSA.

| Guarda | Cenário novo | Sob a mutação, antes | Sob a mutação, agora |
|---|---|---|---|
| vacuidade do modo CANÔNICO (manifesto marcado, bem formado, zero linhas `armado`) | `[14]` | rc=0, PASS | `FAIL [14]: manifesto marcado com zero linhas armadas resolveu para sucesso` |
| formas de comando da fiação, e o comando irreconhecível | `[15]` | não havia cenário | `FAIL [15]` nas três mutações independentes (desencapar desligado, divisão por comando simples desligada, `naoReconhecidos` engolido) |
| o canal `avisos`, que o driver do gate nem imprimia | `[16]` | rc=0, PASS nas duas direções | `FAIL [16]` tanto ao virar recusa quanto ao ser engolido, mais o piso da sentinela |
| guarda de versão do marcador | `[17]` | rc=0, PASS | `FAIL [17]: manifesto marcado como formato 2 foi lido com a régua da v1` |
| guarda de gancho declarado duas vezes, nos dois modos | `[18]` | rc=0, PASS | `FAIL [18]` no modo mutado, mais o piso de modos |
| aridade canônica, aridade da projeção, campo nomeado fora de `chave=valor` | `[19]` | rc=0, PASS nas três | `FAIL [19]` nas três |

**Um cenário que não discriminava.** O `[9]` mutava o matcher para `Write|Edit`, que não tem âncora NENHUMA, e por isso não distinguia a guarda real — `^` e `$` nas duas pontas — de uma que exigisse só a abertura. Medido: com `ancorado()` enfraquecido para `matcher.startsWith('^')`, os quinze cenários passavam verdes, e `^Write` entraria armado — âncora só à esquerda é casamento por substring à direita, que é o perigo que o cabeçalho do `Axis.PadSimulator` documenta com medição própria de `TodoWrite` bloqueando a sessão. O `[9]` passou a varrer TRÊS formas insuficientes — sem âncora, meio-ancorada à esquerda, meio-ancorada à direita — com piso de três e contrafactual ancorado nas duas pontas na mesma posição de campo. Sob a mesma mutação, agora: `FAIL [9]: gancho armado com matcher '^Write' é aceito`.

**Um achado refutado, com a medição.** O achado 10 dizia que o descarte do `hooks.manifest.exemplo` não estava registrado em §15 — "nenhuma subseção de §15 a menciona". É falso: §15.8, item 2, registra o descarte com a razão escrita, e `grep -n 'hooks.manifest.exemplo'` no arquivo devolve exatamente duas linhas, a declaração de §0 e esse registro. O que procedia era menor e foi feito: a linha de §0 agora aponta para §15.8, para que quem lê a tabela de cima não precise chegar ao fim do documento para saber que o arquivo não existe. O arquivo continua não sendo criado, pela razão já escrita em §15.8.

**Um achado que não é desta onda.** O achado 7 é o badge `gates-N` do `README.md`, que quatro ondas desta rodada disputam ao mesmo tempo. Ele não é defeito de lógica e a correção é do orquestrador, com valor derivado no fim. Esta onda não acrescenta nem remove arquivo que mude as contagens do `w200`: nenhum arquivo novo entrou em `template/.forge/scripts/`, e o único gate desta onda é o `w208`, que já estava no disco quando o `w200` foi medido.

**Uma armadilha nova, da mesma família de LDG-0164, e ela mordeu esta sessão.** O rito de mutação foi feito por um utilitário em Node que faz `src.replace(velho, novo)`. Em JavaScript, o token `$'` no lado DIREITO de `String.prototype.replace` significa "o trecho do original que vem DEPOIS do casamento" — exatamente como `$var` do lado direito de um `perl -0pi -e 's///'` é variável do perl. Uma das substituições continha `'Write$'` como valor de laço, o `$'` foi interpretado, e o resultado duplicou quatro mil e novecentos bytes do arquivo dentro dele mesmo; o `bash -n` acusou na hora e o reparo foi determinístico. **A lição em letra: no lado direito de qualquer substituição, seja `perl`, `sed` ou `String.replace`, todo token que a linguagem interpreta é uma mutação fantasma esperando acontecer, e o antídoto é passar o replacement como FUNÇÃO (`replace(velho, () => novo)`), que não interpreta token nenhum.**
