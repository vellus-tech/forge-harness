# Plano — zerar o backlog do forge-harness

Data: 2026-09-07. Estado medido no commit `49bc97d` (`v0.14.0`, publicada no npm), branch de trabalho `fix/strix-achados-medios`, suíte em 132 arquivos `tests/*.sh`.

Este documento é a fonte única da cadeia de trabalho. Cada etapa seguinte — especificação, revisão da especificação, implementação, revisão adversarial — lê daqui, não do contexto de quem a invocou. Quem receber uma onda para executar deve ler a seção da sua onda **e** as seções "Invariantes" e "Método de prova", que valem para todas.

## Definição de pronto do plano inteiro

Três contadores em zero, verificáveis por comando, não por relatório:

```
node -e '…ledger.json…' | grep -c open        → 0
gh issue list --state open                    → 0
check-liaison-acks.sh                          → 0 mensagem(ns) exigem ack
```

Um item sai de `open` por duas portas legítimas, e só por essas duas: `resolved`, com prova de que o defeito descrito não reproduz mais e um gate que morde se ele voltar; ou `wont-fix`, com decisão registrada do dono e a medição que a sustenta. Fechar por reclassificação silenciosa não conta — o harness já reprovou essa saída em LDG-0053 e LDG-0061, e reprová-la de novo aqui é o mínimo de coerência.

## Estado medido — o que está aberto

| Fonte | Aberto | Onde |
|---|---|---|
| Ledger | 22 itens (9 P2, 11 P3, 2 LOW/MEDIUM) — 21 no levantamento inicial mais o LDG-0176, achado durante a revisão das especificações | `.forge/ledger/ledger.json` |
| Issues | 10 abertas, 6 delas de liaison | `gh issue list` |
| Liaison | 37 mensagens em 22 threads, de 4 repositórios | `check-liaison-acks.sh` |
| Em voo | 3 achados médios do perfil strix, não commitados | branch `fix/strix-achados-medios` |
| Fora de registro | piloto do Strix nunca executado contra alvo real | artifact de backlog, 2026-09-07 |
| Fora de registro | mecânica de CI/CD acoplada ao GitHub Actions, sem executor de fase de deploy | medido em 2026-09-07, onda K |

O total de 107 itens do ledger tem 77 `resolved` e 8 `wont-fix`, o que dá a régua do que este plano precisa produzir: 22 transições, cada uma com evidência do mesmo padrão das 85 anteriores. O contador subiu durante o próprio planejamento, e isso é esperado: rodada que mede de verdade encontra defeito novo, e um plano que não previsse isso estaria mentindo sobre o próprio alcance.

## Invariantes — valem em toda onda, sem exceção

1. **TDD red-first de verdade.** O teste falha primeiro **pela ausência real da funcionalidade**, e o vermelho é observado e registrado antes de existir uma linha de implementação. Vermelho fabricado (assert que falha por sintaxe, por fixture ausente, por caminho errado) não conta e será tratado como achado na revisão adversarial. A regra do repositório é `rules/testing/`, e a lição que o programa já pagou está registrada em `project-red-first-limite-verificacao`: evidência produzida por quem é verificado, no ambiente que ele controla, não prova nada.
2. **Um gate distingue três estados, nunca dois.** "Não encontrei violação", "encontrei violação" e "não consegui verificar" são desfechos diferentes com códigos diferentes. Gate que colapsa o primeiro e o terceiro no mesmo verde é o defeito que mais mordeu este programa — é literalmente o assunto de #119, #106, LDG-0157 e LDG-0160, quatro dos itens que este plano fecha.
3. **Contador de controle com denominador fixo.** Todo gate publica quantas condições examinou, e reprova quando esse número é zero ou menor que o esperado. Gate que aprova por não ter olhado para nada é a falha clássica, e ela já apareceu aqui.
4. **Prova de mutação com controle e recontrole.** Quebrar a regra faz o gate acusar; restaurar por checksum faz o gate voltar ao verde. Sem o recontrole a prova não vale — `feedback-mutacao-fantasma-restore` registra o caso em que um `restore()` quebrado deixou a mutação eterna e ninguém viu. E LDG-0164 registra o caso em que a própria mutação era malformada e media o engano: `perl -0pi -e` com `$` sem escape do lado direito são variáveis do **perl**, vazias, e a mutação vira `cp "" ""`.
5. **PBT onde há espaço de entrada.** Parser, normalizador de caminho, comparador de versão, alocador de ordinal e serializador de manifesto recebem teste de propriedade sobre entrada gerada, não três exemplos escolhidos a dedo. LDG-0021 registra exatamente essa lacuna e este plano não deve ampliá-la.
6. **Teste de contrato onde há fronteira publicada.** Schema (`forge.schema.json`), formato de manifesto, formato de mensagem do liaison e assinatura de subcomando do CLI são contratos com adotante instalado; mudança neles exige teste que falhe quando o contrato quebra, e uma decisão explícita sobre retrocompatibilidade.
7. **Integração e E2E onde o defeito é de fiação.** Vários itens aqui não são bugs de função, são bugs de **ninguém chamar a função** — LDG-0160 é o caso puro. Teste unitário sobre a função nasce verde e não diz nada; o teste precisa exercer o caminho real, do gatilho ao efeito.
8. **bash 3.2.** Sem `declare -A`, `${var,,}`, `${var^^}`, `mapfile`, `readarray`. `bash -n` limpo em tudo que for tocado.
9. **A suíte não tolera concorrência.** Gate manual rodando durante `npm test` produz falha fantasma em gate alheio, com log vazio — está em `feedback-suite-sem-concorrencia`. Implementação paralela acontece em worktrees isoladas; **verificação é serializada pelo orquestrador**.
10. **Ordinal de gate é alocado pelo orquestrador, uma vez, no momento de escrever o arquivo** — e conferido contra `origin/*` **e** contra as branches em voo desta rodada. É o defeito de LDG-0167/0173 e esta rodada tem várias frentes; pagar o pedágio duas vezes na mesma noite já aconteceu.
11. **Nenhum texto de coautoria de IA** em commit, PR ou issue.
12. **PR sempre contra `develop`.** `git -C <path>` explícito. Nada de `sleep` ou polling em foreground.
13. **Uma frase é uma linha lógica contínua no fonte.** Sem quebra manual dentro de parágrafo, em nenhum arquivo gerado.
14. **Todo número literal numa asserção é dívida.** Se o literal conta arquivos rastreados, gates em `tests/`, entradas de `machinery.lock`, nodes de grafo ou fixtures, ele envelhece — muitas vezes na própria onda que o escreve, porque a onda acrescenta arquivos. Três especificações diferentes desta rodada nasceram com esse defeito, cada uma com o seu número (434, 401, 132), e em dois casos o revisor mostrou que o literal quebraria no dia da entrega. Asserte **propriedade mais piso**, ou derive o denominador no momento da execução. A única exceção legítima é o denominador de cenários do próprio gate, que é fixo por construção e cuja divergência é justamente o achado.
15. **Mudar uma string que a produção imprime quebra os gates que a afirmam.** Antes de propor qualquer mudança de mensagem, aviso ou token, varra `tests/` pela string atual e liste nominalmente todo gate que a afirma. Uma onda desta rodada quase deixou quatro gates rastreados vermelhos (`w160`, `w168`, `w135`, `w97`) por trocar vocabulário sem varrer. Se a mudança é necessária, a especificação lista os gates a editar junto, e essa lista entra na definição de pronto.
16. **Toda linha de matriz de mutação precisa de contrafactual medido antes de ser escrita.** Rode a mutação, observe o efeito real, e só então declare o que ela derruba. Duas matrizes desta rodada declararam efeito errado e uma mutação era no-op — o padrão de LDG-0164, em que o `cmp` confirma que o arquivo mudou enquanto o comportamento não muda.
17. **Enumerar desfechos exige exaustividade provada.** Uma decisão que listava cinco desfechos "exaustivos" foi derrubada por um sexto: repositório git **sem nenhum commit**, onde `git diff HEAD` sai 128 e as duas implementações plausíveis são igualmente ruins. Para cada enumeração de estados, procure ativamente o caso não coberto e escreva o que acontece nele.
18. **Guarda de vacuidade dispara no caminho feliz.** `run-gates.sh --phase` reprova com `universo-vazio` quando nenhum gate declara aquela fase, e zero de treze consumidores declaram `phase:` hoje. Antes de fiar qualquer chamada nova, meça o que ela faz num consumidor real.
19. **Uma especificação não prescreve mecanismo que ela não executou.** Foi a causa da maior parte dos defeitos da terceira rodada de revisão, e os três exemplos medidos dão a régua: `node -e '<código>' <caminho>` põe o caminho em `process.argv[1]` e não em `process.argv[2]`, então a mutação prescrita produzia `undefined`, não alterava arquivo nenhum e o `cmp` de controle acusava mutação-fantasma — no parágrafo em que a especificação **ensinava** a evitá-la; `git diff-files` não reporta um `touch` ocorrido no mesmo segundo do commit, pela regra racy-clean do git, o que torna a asserção verde por acidente; e `stat -f %m` tem granularidade de segundo no macOS, de modo que dois writes separados por 18 ms devolvem o mesmo número e a asserção de "não reescreveu" é gate morto. Nos três casos a especificação escreveu o comando sem rodar. A saída é dividir o trabalho onde ele pertence: a especificação declara a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir, e o implementador — que executa — escolhe o primitivo e prova que ele discrimina. Prescrição de comando exato só entra na especificação quando ela veio de uma execução registrada, com a saída colada.

## Fase 0 — fechar o que está em voo

A branch `fix/strix-achados-medios` tem os três achados médios do perfil strix implementados e verificados (gate `w206` em 30 blocos, prova de mutação de `exec`→`system` observada mordendo o `[28]`), mas três pendências ficaram fora do escopo autorizado do implementador e precisam entrar antes do PR:

1. **A documentação do R8 mente sobre o número de raízes.** `template/.forge/commands/waves/pentest.md:146` e o gêmeo `plugin/forge/commands/pentest.md:146` dizem "nenhuma das **quatro** raízes de skill que o pré-voo varre" enquanto o engine agora varre **seis**. O assert `[23]` do gate confere paridade de **tokens** `R<n>/<nome>`, não de conteúdo, então ele fica verde sobre a mentira — o que faz desta uma instância do próprio padrão que a onda D combate. A correção é textual e vem com regeneração do plugin por `npm run build:plugin` (nunca `build-plugin.sh`, que instala em `$HOME`).
2. **A especificação está defasada.** `docs/plans/spikes/strix-pentest-spec.md:22` fixa "**23** asserções" (são 30) e as seções §4.8 e §7 descrevem o R8 de quatro raízes e o timeout provado por leitura estática.
3. **`timeout_s` não está no manifesto.** `strix_manifest_write` grava `scan_mode`, `max_budget_usd` e `sandbox_network`, mas não o teto de tempo — que é justamente o parâmetro cuja violação silenciosa o `[28]` passou a detectar. Manifesto existe para provar sob que contenção a execução ocorreu; omitir a contenção recém-endurecida esvazia metade disso. Entra com asserção nova no `w206`, red-first.

Saída da fase: suíte verde, commit, PR contra `develop`, review adversarial, merge.

## Fase 1 — completar o dogfood do harness neste repositório

Decisão do dono, tomada em 2026-09-07: este repositório passa a **consumir** o harness que produz.

Hoje ele não consome. Medido: `node bin/forge.mjs update --dry-run` recusa com *".forge existe mas forge.yaml não — instalação parcial, arquivo apagado, ou harness sem esse arquivo (ex.: dogfood)"*. O `.forge/` da raiz tem `FORGE.md`, `HANDOFF.md`, `ledger/`, `liaison/`, `specs/`, `graph/`, duas allowlists e um symlink `contracts → ../template/.forge/contracts`; não tem `forge.yaml`, `rules/`, `scripts/`, `commands/`, `agents/`, `hooks/` nem `machinery.lock`. O próprio `.forge/FORGE.md` registra a dívida em letra: *"este repositório não é (ainda) um consumidor completo de si mesmo"*.

**O que a fase entrega:** instalação real da maquinaria 0.14.0 na raiz, com `forge.yaml` e `machinery.lock`, sem perder um byte do que já existe.

**O risco, nomeado antes de começar, porque ele é a razão de a fase existir separada:** instalar `.forge/scripts/`, `.forge/rules/` e `.forge/commands/` na raiz **duplica a maquinaria** — ela passa a existir em `template/.forge/` (código-fonte do produto) e em `.forge/` (cópia instalada). Todo gate que varre o repositório por padrão de texto passa a ver duas cópias, e todo gate que conta ocorrências muda de número. Vários gates fazem exatamente isso. Além disso o campo já mediu que `forge update` sobrescreve maquinaria local (issue #101, e o alerta `axis-fare-validator-0023` no canal), o que aqui significaria o `.forge/` da raiz divergir do `template/` e ser silenciosamente revertido no update seguinte.

**Protocolo obrigatório da fase, em ordem:**

1. Inventário byte a byte, com `sha256`, de todo arquivo hoje sob `.forge/` da raiz, gravado em artefato antes de qualquer escrita.
2. Baseline da suíte completa **verde**, com a lista nominal dos gates que passaram e o contador de cada um.
3. Instalação em **worktree descartável** primeiro, nunca na árvore de trabalho: medir o diff completo, rodar a suíte inteira lá e comparar gate a gate contra o baseline.
4. Toda divergência de contador é tratada como achado: ou o gate estava certo e a instalação precisa de ajuste (`codegraph.include_paths`, allowlists, exclusão de `.forge/scripts` do universo do gate), ou o gate estava medindo o universo errado e vira item próprio.
5. Só depois, aplicar na árvore real, reconferir os `sha256` do inventário e provar que os arquivos de instrução estão idênticos.
6. `machinery.lock` passa a existir, o que — e isso é benefício direto, não efeito colateral — dá a este repositório a mesma referência de drift que a issue #101 e LDG-0153 dizem faltar aos consumidores.

**Critério de aceite da fase:** suíte verde com os mesmos contadores do baseline, `sha256` idênticos para os arquivos preexistentes, `forge update --dry-run` respondendo sem recusa, e um gate novo que reprova se um arquivo de instrução da raiz for sobrescrito por update.

## Ondas do backlog

As ondas agrupam por **mecanismo do defeito**, não por onde o item foi registrado, porque itens com a mesma causa se corrigem juntos e se testam com a mesma bancada. Cada onda vira uma branch e um PR contra `develop`.

### Onda A — perda de dado silenciosa

O critério que junta os dois: alguma coisa destrói trabalho já feito e **sai com código zero**.

| Item | O que fecha |
|---|---|
| #120 | `lib/handoff-render.mjs:70` reescreve `.forge/HANDOFF.md` incondicionalmente; a única guarda preserva o texto entre marcadores `FORGE:NARRATIVE-DELTA` que o arquivo real nunca teve. Medido: 290.761 bytes viram 2.764, sem backup, sem aviso, `exit 0`. |
| LDG-0175 | `w146-suite-invocation-gate.sh` usa `template/.forge/scripts/tests/run-all.sh` — arquivo **rastreado e distribuído no pacote** — como fixture e não restaura. Encontrado com o arquivo de 70 linhas reduzido a um stub de 3 que sai 1, e a allowlist de 32 linhas reduzida a 1. Um commit por cima desse estado publica maquinaria quebrada para os consumidores. |

A correção de LDG-0175 tem duas metades e as duas são obrigatórias: o gate deixa de usar arquivo rastreado como fixture (copia para `$TMPDIR`), **e** nasce uma guarda que reprova quando a árvore de `template/` diverge do HEAD em arquivo rastreado ao fim de qualquer gate — porque a primeira metade conserta um sítio e a segunda fecha a classe.

### Onda B — liaison: integridade de conteúdo

| Item | O que fecha |
|---|---|
| #117 | `liaison-ops.sh:298` computa `sha256Hex(buf.toString('binary'))`, ou seja `sha256(utf8(latin1(bytes)))`, não `sha256(bytes)`. Divergem 665 de 666 blobs em produção; o único que bate não tem acentuação. Exige decisão de contrato: renomear o acervo, aceitar as duas formas na leitura, ou versionar o esquema de nome. |
| #107 | Em `lib/liaison-import.mjs` a instalação do blob mora **dentro** do laço de mensagens novas, então réplica que conhece a mensagem e perdeu o corpo nunca o recupera. Medido: 145 ponteiros mortos em 29 réplicas, hubs íntegros. |
| #109 | O `sync` publica e não deixa marca d'água: `state.json` só tem cursores de leitura. Nada distingue mensagem enviada de mensagem publicada, e o gate de acks é estruturalmente cego ao outbox por regra declarada. |
| #108 | Três resíduos: passivo de cursor pré-#105 sem reparo automático, avanço de cursor que falha em silêncio com rc 0, e `doctor.sh:231` que engole falha de `status` e remove a linha inteira do liaison quando `state.json` é inválido. |
| LDG-0153 | O doctor não informa divergência do `_common.sh` local contra o template, embora `machinery.lock` grave o sha do template por path e `bin/forge.mjs:617-643` já compute a comparação. Restrição real: sem `machinery.lock` não há referência, e é aí que a perda é totalmente muda. |
| LDG-0163 | Registro de defeito já corrigido no código (o caminho `ff` do `_dir_push` publicava log contaminado com rc 0). Fecha por prova de que o caminho atual recusa, com o cenário do `w198`. |

### Onda C — liaison: transporte e configuração

| Item | O que fecha |
|---|---|
| #123 | Proposta de `fs-union` como `kind` de primeira classe. O achado que a sustenta é negativo e vale mais que a proposta: **nenhuma correção que mora no código versionado alcança a árvore cujo defeito é carregar a versão anterior desse código** — medido em 13 worktrees armadas de 32. O ponto fixo é `liaison.yaml`, único elo lido do tronco. Vem com aviso do campo de que a 0.14.0 remove o kind e trava o push de quem o adotou, o que precisa ser conferido antes de qualquer coisa. |
| #101 | `scripts` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS`, então `forge update` sobrescreve o diretório inteiro; sem `machinery.lock` a perda é silenciosa. Aproveitar no mesmo change: três mensagens ainda mandam o operador para `.forge.bak-N` quando o backup vai para `.git/forge-backups/forge-N` desde a issue #76. |
| LDG-0100 | `check-liaison-acks.sh` não lê o hub para transporte `git`/`gh`. Censo do ecossistema: todo canal declarado usa `kind: fs`. Candidato a `wont-fix` com condição de reabertura escrita, **ou** a implementação junto de #123, que introduz kind novo e portanto mexe na mesma vizinhança. |

### Onda D — falso-verde: aprovar sem ter olhado

| Item | O que fecha |
|---|---|
| #119 | O `pre-push` declara em comentário que o gatilho do bloqueio é a **indisponibilidade do leitor**, e a linha 418 condiciona a guarda à **forma do frontmatter**. Árvore com gates em CSV escalar e lib antiga imprime "0 gate(s) declarado(s)" e sai 0, com 8 gates declarados e os 8 scripts no disco. |
| #106 | `runtime.test` é texto livre sem guarda de cobertura. Um consumidor declarou `pnpm test` num repositório com 24 solutions e ficou 19 dias com suíte vermelha invisível, 21 de 21 testes reprovando. |
| LDG-0157 | `check-ai-attribution.sh` trata qualquer rc≠0 de `node -` como violação, então sem `node` no PATH o rc 127 imprime "assinatura de IA detectada" sobre um commit limpo. Terceira classe: "NÃO VERIFICADO — node ausente". |

### Onda E — alocação de ordinal e disciplina de escrita

| Item | O que fecha |
|---|---|
| LDG-0173 | `gate-ordinal.sh next` só lê `origin/develop`, `origin/main` e `origin/master`; nenhuma branch em voo entra no universo. Medido: com o tronco em `w205` e `w206` já publicado numa branch, `next` devolveu `w206`. |
| LDG-0167 | A mesma raiz vista de cima: `next` **lê** o máximo publicado, não **aloca**. Custou duas colisões numa noite, em duas maquinarias diferentes — ordinal de gate e id de ledger. |
| LDG-0158 | Em `next`, `git rev-parse` e `git ls-tree` rodam sem `-C`, consultando o repositório do diretório corrente enquanto o máximo local vem de `--path`. |
| #103 | `forge_require_value` testa `[ -n "$value" ]`, então `--detail --title` grava a string `--title` no campo e responde `OK` com rc 0. O critério certo é recusar quando o valor é **membro do conjunto de flags declaradas**, não "começa com hífen". Levar junto: `deferral-ops.sh` tem a mesma classe em `*) shift ;;`, e lá um deferral nasce inerte. |
| LDG-0140 | `harvest` continua criando entradas com `detail` vazio e `priority` nula — a mesma porta de item sem conteúdo da #103, por um terceiro caminho. |

### Onda F — consolidação, schema e varreduras

| Item | O que fecha |
|---|---|
| LDG-0152 | `fm_field` triplicado: `hooks/git/pre-push`, `handoff-gen.sh:42` e `hooks/session/on-session-start.sh:11`. Consolidar num lib, com o cuidado de que o `FORGE.md` tem leitor canônico e a regra de extração é herdada, não reinventada — a lição que quase publicou uma allowlist envenenada. |
| LDG-0151 | Seis chaves de schema sem leitor que prometem **default**: `sdd.default_mode`, `sdd.default_rigor`, `sdd.default_scale`, `sdd.archive_policy`, `sdd.human_gate_required`, `quality.evals_root`. Decidir por chave. |
| LDG-0161 | `template/.forge/FORGE.md` e `template/.forge/templates/FORGE.md` divergem e nenhum caminho gera um do outro; documentação depositada só na segunda não chega ao arquivo que o adotante abre. |
| LDG-0171 | O padrão `SCRIPT_DIR/../..` segue em 34 sítios exatos, incluindo `doctor.sh:44`; só o sítio com dano medido foi corrigido. Exige varredura que classifique cada sítio antes de generalizar. |
| LDG-0164 | Varrer os demais gates que usam `perl -0pi` para mutação atrás do mesmo `$` sem escape que tornava a mutação tautológica. |
| LDG-0176 | O `graph.json` commitado está em `2026-09-04` com 256 nodes e `tests: 114`, enquanto a regeneração devolve 310 nodes com `tests: 150` — 36 gates fora do grafo. O que o torna dívida é que **nenhum gate compara o grafo commitado com o que a regeneração produziria**, então a defasagem não tem detector; ela só apareceu porque um revisor foi conferir um número. O gate a criar compara o conjunto de **ids**, nunca a contagem, que envelhece a cada gate novo. |

### Onda G — route-scan e cobertura de superfície

| Item | O que fecha |
|---|---|
| LDG-0029 | Corrigir o universo da varredura (pular a subárvore git-excluída) e **remedir**, antes de decidir o índice de constante literal. A partição 69/8 foi recomputada sobre saída de terceiro, não regenerada. |
| LDG-0162 | `MapGroup()` não ancorado deixa 4 chamadas fora do índice no repositório de referência. Manter `w132[16]` verde como linha vermelha. |
| LDG-0010 | Promover SRF-01 a bloqueante, o que exige `validate-spec.mjs:302` passar rota real em vez de `apiPaths()` e `enforceable:true` na chamada. Bloqueado por LDG-0162. |

Esta onda depende de repositório de referência externo e pode ser a que mais resiste a fechar nesta rodada; se resistir, o desfecho honesto é `wont-fix` com a medição, não um `resolved` fabricado.

### Onda H — enforcement de qualidade

| Item | O que fecha |
|---|---|
| LDG-0008 | As fatias de TDD-em-feature e de cobertura por propriedades, que continuam intocadas depois da primeira fatia de 2026-09-05. É o item que dá enforcement às invariantes 1 e 5 deste plano, o que o torna reflexivo: fechá-lo bem significa que a próxima rodada não depende de disciplina. |
| LDG-0065 | Packs Java e Python sem enforcement mecânico: os dois capability packs contêm apenas `PROFILE.md` e nenhum cita `ruff`, `mypy`, Error Prone, SpotBugs ou Checkstyle. Padrão a replicar: o do `w155`. |
| LDG-0021 | Fuzzing guiado por gramática sobre a superfície de entrada. Pede change SDD próprio, com `design.md`. |

### Onda I — responder os 37 acks

Vinte e duas threads, quatro repositórios. Não é trabalho de código: é passivo de conversa, e várias mensagens trazem medição de campo que **contradiz ou corrige** o que o harness publicou — a retratação `axis-go-cloud-0085` sobre o compare-and-swap, o censo por conteúdo de ref de `axis-fare-validator-0098`, a retificação `axis-go-cloud-0081` sobre a guarda de colisão. Responder exige ler o corpo, conferir a medição contra o código de hoje e dizer o que o harness vai fazer.

A ordem importa: as threads que pedem `contract-change` (`template-distribui-transporte-destrutivo`, `gates-do-template-cegos-a-java-e-dominio-ausente`, `find-sem-quit-mata-o-script-na-linha-da-recusa`, `o-gerador-tambem-esta-no-lock`, `mutex-nao-atravessa-a-fronteira-do-harness`, entre outras) são respondidas **depois** da onda que resolve o pedido, para que o ack carregue a entrega e não uma promessa. As de `note` e `question` podem ser respondidas antes.

Duas recobranças estão registradas e precisam ser reconhecidas como tais: `axis-fare-validator-0018` diz que o pedido de `.java` nos gates do template saiu sem `requires-ack` e que "o participante forge-harness nunca escreveu uma linha neste canal". Isso é verdade e o ack precisa dizer isso, não contorná-lo.

### Onda K — mecânica de CI/CD portátil, sem depender do GitHub Actions

Esta onda entrou no plano por decisão do dono em 2026-09-07, depois da pergunta direta: o harness especifica a mecânica de CI/CD sem depender do GitHub Actions? A resposta medida é **não**, e a medição vale mais que a resposta.

**O que existe hoje, medido no template:**

1. **Zero abstração de provedor.** Não há uma única menção a GitLab CI, Jenkins, CircleCI, Azure Pipelines, Buildkite ou Drone em nenhum arquivo de `template/`. GitHub Actions é o único provedor que o harness conhece, e ele é conhecido por acoplamento direto, não por adaptador.
2. **`template/github/workflows/staging.yml` é um esqueleto.** O único job imprime `echo "Pipeline de staging — preencher conforme a stack do projeto"` e lista as etapas em texto. A mecânica não está especificada em lugar nenhum: ela está delegada ao consumidor, para ser escrita dentro do YAML do Actions, uma vez por repositório.
3. **`template/github/workflows/red-first.yml` é real e sua dependência é de desenho.** Ele reexecuta o replay de evidência red num runner que o autor do PR não controla, e o cabeçalho declara que é isso que faz do veredito dali a autoridade. Essa dependência não deve ser removida por simetria — o valor dela é justamente ser *externa ao autor*. O que ela precisa é ser nomeada como a única dependência legítima, e ganhar um equivalente para quem não usa Actions.
4. **`/forge:deploy-wave` é prosa para um agente executar.** Dez gates ordenados — build multi-arch, Trivy `0C0H0M0L` por digest, Cosign keyless, SBOM CycloneDX, `helm upgrade --install --atomic`, `kubectl rollout status`, pod arm64 nativo, smoke em `/health/ready`, Kyverno admission, tag de deploy — todos descritos em markdown, nenhum em script. E o passo 1 é literalmente `gh workflow run build-image.yml` seguido de `gh run watch $RUN_ID --exit-status`. Isso contraria a norma do próprio repositório, registrada em `feedback-end-to-end-completo`: **escape hatch operado por script, nunca por memória do agente**. Um deploy de produção conduzido por dez passos de markdown é a forma mais cara possível de descobrir que o agente pulou o passo 7.
5. **O seletor de fase de deploy existe e não tem executor.** `run-gates.sh --phase pre-deploy|post-deploy` está implementado, com guarda de vacuidade própria, e o comentário do arquivo afirma que "o deploy chama `run-gates.sh <id> --phase pre-deploy`". Nenhum chamador de produção passa `--phase` — é LDG-0160, e ele vive nesta onda e não na D porque o conserto dele **é** o executor que esta onda cria. Escrever um gate que só faz o doctor nomear as fases nasceria verde sobre o defeito.

**Sobre os arquivos citados como referência:** procurei `scripts/deploy.sh` e `deploy-common.sh` em `axis-go-cloud` e `azim-crm` e eles não existem. O `axis-go-cloud` faz deploy por GitHub Actions (`api-gateway-deploy.yml`, `audit-trail-deploy.yml`, `_template-cd-helm-deploy.yml`) mais buildspecs do AWS CodeBuild em `deploy/dev-cielo-lambda/`; o `azim-crm` usa Helm charts e Cloud Scheduler, sem script de deploy próprio. O único `deploy.sh` em `~/Documents/projects` está em `payments/payments-docs/scripts/` e é de publicação de documentação. Registro isso porque muda a natureza do trabalho: **não há um padrão em produção para extrair e generalizar — esta onda cria o padrão**, e por isso precisa de piloto real num consumidor antes de virar contrato do template.

**O que a onda entrega:**

| Peça | O que é |
|---|---|
| `template/.forge/scripts/lib/deploy-common.sh` | A mecânica: resolução de ambiente, verificação de pré-condições, execução ordenada dos estágios, captura de veredito por estágio, rollback, e o vocabulário de saída de três estados (executou e passou, executou e reprovou, não conseguiu executar). Sem uma linha específica de provedor. |
| `template/.forge/scripts/deploy.sh` | A porta: `deploy.sh <modulo> <env> [--sha] [--strategy] [--dry-run]`, que valida, chama `run-gates.sh --phase pre-deploy`, executa os estágios, chama `--phase post-deploy` e grava manifesto de execução. É o executor que LDG-0160 diz não existir. |
| Adaptadores de provedor | `lib/ci/github-actions.sh` e ao menos um segundo — o segundo existe para provar que a interface é uma interface, e não o primeiro provedor com nome genérico. O workflow do Actions passa a ser um invólucro de três linhas que chama `deploy.sh`, e não o lugar onde a mecânica mora. |
| Manifesto de deploy | O mesmo princípio do manifesto do pré-voo do strix: a saída do deploy por si só não prova sob que condições ele ocorreu. Registra módulo, ambiente, sha, estratégia, digest verificado, veredito de cada estágio, quem aprovou e quando. |
| `/forge:deploy-wave` reescrito | O markdown deixa de ser a mecânica e passa a ser a interface humana sobre `deploy.sh`. Os dez gates continuam existindo — como estágios do script, onde pular um é `exit` e não esquecimento. |
| Gate novo | Prova que `deploy.sh` recusa quando uma pré-condição falha, que as fases `pre-deploy` e `post-deploy` são de fato invocadas (a asserção que fecha LDG-0160 pelo canal real), que o adaptador de provedor é substituível, e que nenhum estágio pode ser pulado em silêncio. Com contador de controle e prova de mutação. |
| LDG-0160 | Fecha aqui, por execução real da fase, não por linha de aviso do doctor. |

**O que a onda não faz, e por quê:** não remove o `red-first.yml` nem tenta reimplementar em shell a garantia que ele oferece. Rodar o replay num runner que o autor não controla é uma propriedade do *ambiente*, não do script — um `deploy.sh` executado pelo próprio autor, na máquina do próprio autor, não a reproduz. O que a onda faz é documentar essa fronteira e oferecer, para quem não usa Actions, o mesmo contrato num adaptador equivalente.

### Onda J — release

Bump, `CHANGELOG.md`, PR de release para `main`, tag, back-merge para `develop`, publicação no npm com `.npmrc` temporário a partir do item "Npmjs" do 1Password, vault Operations, sem persistir credencial em disco.

## Fora do backlog formal, e registrado aqui para não sumir

**O piloto do Strix nunca foi executado.** A maquinaria foi entregue e publicada, mas nenhum scan real rodou. Duas condições continuam dependendo de disciplina humana e o código admite isso em vez de fingir o contrário: o opt-in de bancada é contornável por variável de ambiente — o pré-voo grava a origem no manifesto, então há rastro, não contenção — e a conformidade do Strix com `STRIX_TELEMETRY=0` foi lida no código-fonte do fornecedor, nunca medida no binário. Sem números de recall, falso positivo, tempo de operador e custo por achado verificado, a decisão de continuar ou parar é fé. Isto não é item de ledger e não bloqueia a definição de pronto; é decisão de produto que o dono precisa tomar com dados.

## Cadeia de execução

| Etapa | Responsável | Entrega | Paralelismo |
|---|---|---|---|
| 1 | Especificadores | uma especificação implementável por onda, em `docs/plans/spikes/`, com decisões fechadas e o vermelho descrito antes do verde | paralelo por onda |
| 2 | Revisores de especificação | veredito aprovado/reprovado por onda, com achados; a especificação volta ao autor se reprovada | paralelo por onda |
| 3 | Implementadores | engine, gate, fiação, changelog — com suíte verde na worktree | paralelo em worktrees isoladas, **verificação serializada** |
| 4 | Revisores adversariais | achados de código, procurando o gate morto, a recusa que não recusa e o vermelho fabricado | paralelo por onda, com verificação independente de cada achado |
| 5 | Orquestrador | roda a suíte inteira, valida cada retorno com execução real, abre PR contra `develop` | serial |

O orquestrador valida cada retorno com execução real da suíte. Relatório de subagente não é prova — e `feedback-subagente-trava-esperando-monitor` registra o caso em que um retorno descrevia intenção como se fosse estado.

## Ordem de execução e por quê

Fase 0 primeiro, porque a árvore está suja e nada mais pode começar sobre trabalho não commitado. Fase 1 em seguida, porque ela muda o universo dos gates e toda onda posterior precisa medir contra o universo novo, não contra o antigo. Depois A (destrói dado), D (falso-verde, que é o mecanismo que mais nos mordeu), B e C (liaison, a maior concentração isolada), E (barato e já cobrou pedágio duas vezes), F, G, H. K entra depois de E, porque ela cria maquinaria nova em vez de consertar maquinaria existente e merece uma bancada estável embaixo; ela é também a única onda cujo produto precisa de piloto num consumidor real antes de virar contrato do template. I acompanha as ondas cujo pedido ela responde. J fecha.
