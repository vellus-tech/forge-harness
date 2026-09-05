# Plano de resolução — issues e ledger do forge-harness

> Data: 2026-09-04 · Base: `develop` @ 0.10.0 · Escopo: as issues abertas e as entradas não encerradas do ledger.
> Progresso medido por `node tools/plan-progress.mjs` — nunca por marcação manual neste documento. O placar reconcilia nos dois sentidos: item aberto fora do plano reprova, e o total não é declarado aqui para não envelhecer.
> Revisão adversarial de 2026-09-04 reprovou a v1 com sete bloqueantes; esta é a v2, com as correções aplicadas e o gate `w156` cobrindo o instrumento.

## Sumário executivo

Rode `node tools/plan-progress.mjs` para o número corrente — ele é medido, e uma contagem escrita aqui envelheceria na primeira issue nova (foi o que aconteceu: a v1 deste plano declarou 11 issues abertas e duas foram criadas no mesmo dia, ficando fora do escopo sem que nada acusasse). Os itens não são problemas independentes. Sete das issues nasceram da mesma auditoria de upgrade em consumidor real (22/08) e compartilham uma causa: **o `update` decide sobre a árvore do consumidor sem verificar o estado dela**. Outro bloco de oito itens é resíduo conhecido da própria 0.10.0. Um terceiro bloco é dívida da suíte que só existe porque o instrumento que registra dívida tem dívida.

Por isso a primeira onda não corrige defeito nenhum de produto: ela conserta o instrumento de medição. Hoje o ledger informa um único item P1 que já foi entregue, esconde cinco itens em status nulo do comando de consulta canônico, e carrega onze entradas encerradas sem data de encerramento — o defeito exato da issue #78, comprovado onze vezes dentro do próprio harness. Planejar sobre esse dado é planejar sobre ficção.

A ordenação das ondas seguintes é por **dano a terceiros**, não por esforço: primeiro o que destrói trabalho de quem já instalou o harness, depois o que trava o trabalho dele, depois o que passa verde sem medir, e só então a dívida interna e o roadmap.

## O que foi medido (2026-09-04)

| Fonte | Estado na abertura do plano |
|---|---|
| Issues abertas | #71–#78 (22/08), #80–#81 (23/08), #82 (01/09), #83–#84 (04/09) |
| Ledger — entradas | 29 `open`, 25 `resolved`, **5 `null`**, 1 `wont-fix`, 1 `promoted` |
| Ledger — não encerrados | 1 P1, 5 P2, o resto P3 ou sem prioridade |
| Suíte | 100% verde em 738s (2026-09-03), antes dos gates `w155`/`w156` |

Os números acima são um retrato datado, não a fonte de verdade — o placar mede o corrente.

Três defeitos de integridade no ledger, todos verificados:

**LDG-0053 é o único P1 e é falso pendente.** A issue #52 está fechada, os cinco artefatos da entrega existem (`lib/heavy-mutex.sh`, `heavy-run.sh`, `check-heavy-mutex.sh`, a rule `heavy-resource-serialization.md`, o gate `w151`), o `w151` passa na suíte e o CHANGELOG 0.10.0 documenta a entrega inteira. Como é o único P1, ele distorce a resposta à pergunta "o que fazer a seguir" — que é precisamente a pergunta que o ledger existe para responder.

**LDG-0016 descreve o próprio conserto.** O detalhe da entrada começa com "Corrigido no run-all.sh via GIT_CONFIG_COUNT (…) com asserção no w80, mas a causa raiz merece nota". É uma nota técnica registrada como dívida aberta P2.

**LDG-0056 a LDG-0060 têm `status: null`.** Renderizam literalmente `[null]` no `LEDGER.md` e **não** aparecem em `ledger-ops list --status open`. Quem consulta pela porta canônica — que é o que a rule `conventions/ledger-consultation.md` manda fazer — não os vê.

## O PR #79 já implementa sete itens — leia antes de executar qualquer onda

A v1 e a v2 deste plano foram escritas sem consultar os PRs abertos, e planejaram como trabalho a fazer sete itens que já estão escritos. **PR #79 (`feat/upgrade-safety`), aberto em 23/08, `MERGEABLE`, +551/-20 em 11 arquivos, fecha #71 a #77.** O gate `w153-upgrade-safety` da branch passa em 26s com sete cenários comportamentais — e o corpo do PR registra que a primeira versão daquele gate fazia `grep` no código-fonte e sobrevivia a quatro de cinco mutações, por isso foi refeita.

Revisão feita em 2026-09-04, lendo o diff:

| # | o que o PR faz | julgamento |
|---|---|---|
| #71 | `templates` entra em `ENRICHABLE_DIRS` | Correto, e **dispensa o ADR** que a v1 exigia: a preservação ali é por lock de hash — preserva só o que divergiu do template anterior —, então quem não customizou continua recebendo atualização. A política não mudou; o conjunto a que ela se aplica é que cresceu, com o mesmo trade-off já aceito para `agents`, `rules` e `skills`. |
| #72 | limpeza **propõe** em vez de remover; opt-in `FORGE_WORKTREE_AUTOCLEAN=1` | Correto, e a decisão certa é a guarda de `git clean -ndX` valer **mesmo com o opt-in ligado** — é exatamente onde o dano ocorreu, e ele não é detectável depois. |
| #73 | entrega `template/.forge/scripts/tests/run-all.sh` | Fecha o gate insatisfazível na origem. |
| #74 | `doctor` verifica encadeamento; três estados | O estado **parcial** (`warn` novo) é o mais valioso e o mais provável: quem tem hooks próprios encadeia o que precisou no dia em que precisou, e cada upgrade acrescenta gate que ninguém liga. |
| #75 | `heavy_mutex.root`, precedência env > forge.yaml > /tmp | Correto. |
| #76 | backup vai para `.git/forge-backups/`, fora da árvore | **A melhor decisão do PR.** Resolve a classe na origem em vez de remendar gate por gate, e de quebra sai do `git status` e do universo de qualquer varredura. `lib/scan-exclude.sh` cobre o resíduo de quem já tem `.forge.bak-N` — com um comentário registrando que a primeira versão fatiava o caminho com `IFS='/'` e nunca excluía nada. |
| #77 | `APPEND_SOFTEN` amacia `secrets` para `warn` e **reporta** | Correto nas duas metades: o valor certo e o aviso em voz alta. Bloco que muda política não pode entrar calado num upgrade de maquinaria. |

**Três coisas a resolver antes do merge:**

1. **Conflito certo no `CHANGELOG.md`.** O PR insere nas linhas 6–32 e o trabalho de 03–04/09 (gates `w155`/`w156`, camada .NET) insere nas 9–27 — ambos logo abaixo de `## [Unreleased]`. O `doctor.sh` **não** conflita: o PR toca as linhas 41 e 327, o trabalho novo toca a 452.
2. **Dois commits locais não empurrados** na worktree `.forge/worktrees/upgrade-safety`: `feat(heavy-mutex): aceitar root /tmp declarado no forge.yaml` e `fix(heavy-mutex): barrar symlink antes de convergir e corrigir o recibo`. O segundo corrige o primeiro. Mergear o PR como está deixa os dois de fora, e o segundo é uma correção de segurança (symlink).
3. **Colisão de numeração de gate — já resolvida.** O PR traz `w153-upgrade-safety` e `w154-heavy-mutex-yaml-root`; os gates escritos em `develop` foram renomeados para `w155-dotnet-enforcement` e `w156-plan-progress`.

**Consequência para as ondas:** as Ondas 1, 2 e 4 deixam de ser implementação. A primeira ação do plano é **revisar e mergear #79**; o que sobra nelas é `#81` e `LDG-0028` (Onda 1/2) — nada da Onda 4, cujo #75 está coberto. As decisões que a v1 mandava deliberar em ADR já foram tomadas no PR, e a leitura acima é o parecer sobre elas.

## Princípios de ordenação

1. **Instrumento antes de medida, na dose certa.** Um backlog que mente produz plano que mente — mas só a parte do conserto que outra onda espera é bloqueante. A Onda 0a (edição de dado, minutos) antecede a Onda 4; a Onda 0b (código, gate, backfill) corre em paralelo à Onda 1, porque prender correção que fere consumidor atrás de carimbo interno contradiria o Princípio 2.
2. **Dano a terceiros vence esforço.** Defeito que apaga customização de consumidor tem precedência sobre defeito que só nos custa tempo.
3. **Gate insatisfazível é pior que gate ausente.** Um gate que ninguém consegue satisfazer vira `--no-verify` de hábito, e o hábito desliga os outros gates junto.
4. **Correção da causa antes do saneamento do passivo.** Sanear passivo com o vetor aberto produz passivo novo na rodada seguinte — medido na própria #78, cujo passivo cresceu de 39 para 45 entre medições.
5. **Toda onda fecha com gate.** Item resolvido sem asserção executável não conta como resolvido, pela norma que este repositório aplica a terceiros.

## Onda 0a — Veracidade do backlog (minutos, destrava a Onda 4)

**Por que primeiro, e só esta parte:** as cinco entradas com `status: null` são **todas** itens da Onda 4 e são invisíveis em `ledger-ops list --status open`, que é a porta que `conventions/ledger-consultation.md` manda usar — a Onda 4 é literalmente inexecutável a partir da consulta canônica até que sejam corrigidas. E `LDG-0053` encabeça `--by-priority` como único P1, distorcendo a resposta à pergunta que o ledger existe para responder. Isso é edição de dado, não trabalho de código, e não deve segurar nada.

| Item | O que fazer |
|---|---|
| **LDG-0053** | Reconciliar para `resolved`, com nota apontando 0.10.0, PR #68 e o gate `w151`. |
| **LDG-0016** | Reconciliar para `resolved`; o conteúdo é nota técnica sobre `git gc --auto`, já mitigada no `run-all.sh` e asseverada no `w80`. |

Mais, sem ID próprio: dar `open` explícito às cinco entradas de status nulo (LDG-0056 a LDG-0060 — defeitos reais, corrigidos na Onda 4).

**DoD:** `node tools/plan-progress.mjs` reporta zero entradas de status nulo, com o contador de controle de entradas examinadas visível na saída. Nada aqui depende de código novo.

## Onda 0b — O instrumento de registro (em paralelo à Onda 1)

**Por que não bloqueia:** as Ondas 1, 2 e 3 são dirigidas por issues do GitHub, e o ledger não as governa. Prender correção que fere consumidor a cada upgrade atrás de um backfill de carimbo interno contradiria o Princípio 2 deste mesmo plano.

| Item | O que fazer |
|---|---|
| **#78** | `ledger-ops.sh` deve recusar `add --status resolved` e `update --status resolved` sem carimbo, ou gravar `resolved_at` nos dois caminhos. A escolha de desenho importa: as duas portas erradas são as que a pessoa procura, e a que funciona tem outro nome. Corrigir a causa antes do backfill — o passivo cresceu de 39 para 45 entre medições sucessivas com o vetor aberto. |

**DoD:** as onze entradas `resolved` sem `resolved_at` recebem carimbo **depois** que #78 fechar a porta, e um gate novo reprova entrada com status nulo ou `resolved` sem carimbo, para que o passivo não volte. O `plan-progress.mjs` mede os dois números; o gate é peça própria, com controle e recontrole.

## Onda 1 — O upgrade destrói ou reverte decisão do consumidor

**Causa raiz comum:** o `update` decide sobre a árvore do consumidor sem verificar o estado dela. `ENRICHABLE_DIRS` (`bin/forge.mjs:329`) é a forma dessa causa em #71 e na metade de reversão de #72 — `['agents','rules','skills']`, e tudo fora da allowlist é sobrescrita incondicional. **Os outros três itens têm mecanismos distintos e não dependem dessa decisão:** #76 é o backup criado dentro da árvore (`bin/forge.mjs:519-523`) somado a walkers que não o excluem; #77 é `newForgeKeys()` (`bin/forge.mjs:424-437`) acrescentando bloco de topo ausente; LDG-0028 é a mensagem em `bin/forge.mjs:426-427`. Isso importa para a execução: **#76, #77 e LDG-0028 não esperam o ADR** citado em Riscos — são os três mais baratos, e #76 é provavelmente a correção de maior retorno do plano inteiro, porque desbloqueia o primeiro push de todo consumidor após qualquer upgrade.

| Item | Dano concreto medido |
|---|---|
| **#71** | `templates/` fora da allowlist, e `.forge/templates/AGENTS.md` é a fonte do `AGENTS.md` da raiz. Um `update` apaga a customização e o `sync` regenera sem ela. Medido: nove linhas próprias com quatro regras de disciplina, perdidas em silêncio. É o arquivo que governa o comportamento dos agentes — perdê-lo sem aviso é a classe de defeito mais cara que existe, porque o repositório continua funcionando. |
| **#72** | `post-merge` remove worktree e branch sem opt-out, e `hooks/` também está fora da allowlist: quem desligou por ter perdido trabalho tem o comportamento reativado no upgrade. `git status --porcelain` não vê arquivo ignorado, então "worktree limpa" é afirmação sobre o que o git rastreia, e a remoção destrói o que ele não rastreia. Já houve incidente com perda de `local.properties` e `build/`. |
| **#76** | O `.forge.bak-N` que o próprio `update` cria fica dentro da árvore, e os gates com `--path` o varrem. O primeiro push após o upgrade é bloqueado por conteúdo que é cópia do repositório — e a instrução do `update` é manter o backup até validar, ou seja, o caminho recomendado é o que produz o falso positivo. **Ressalva de execução:** não existe walk compartilhada para consertar num ponto só — `lib/discover-lite.mjs:26` já exclui `.forge.bak*` e `lib/check-data-governance.mjs` não exclui nada; `check-secrets.sh` opera sobre `git ls-files` e só é atingido se alguém commitar o backup, para o que o remédio é o bloco gerenciado do `.gitignore`. |
| **#77** | `newForgeKeys()` acrescenta o bloco `secrets` ausente com `enforce: block`, exatamente contradizendo o comentário do bloco, que promete `warn` para repositório existente. A ausência que produziria `warn` deixa de existir no ato do upgrade. Medido: quatro consumidores sem o bloco, um deles com seis achados pré-existentes que passariam a bloquear. |
| **LDG-0028** | `update` diz `.forge não encontrado` quando o ausente é o `forge.yaml`. Mensagem errada no mesmo comando; barato de corrigir junto. |

**Ordem interna:** #76 e #77 primeiro (bloqueiam o primeiro push após qualquer upgrade e afetam todo consumidor), depois #71 e #72 (destrutivos, mas exigem decisão de desenho sobre a allowlist), depois LDG-0028.

**DoD da onda:** gate que instala o harness num fixture com customização em `templates/` e `hooks/`, roda `update` e prova que a customização sobreviveu; gate que prova que o `.forge.bak-N` não é varrido; gate que prova que `secrets` ausente permanece `warn` em repositório existente e `block` em repositório novo.

## Onda 2 — Gate insatisfazível e gate que passa sem medir

| Item | Problema |
|---|---|
| **#73** | O `pre-push` bloqueia por ausência de `.forge/scripts/tests/run-all.sh` e **o pacote não entrega esse runner**. Consumidor que escreveu gates próprios ali — que é o que o harness incentiva — recebe um hook que bloqueia e nenhum arquivo que o desbloqueie. Medido: cinco checkouts com push bloqueado simultaneamente num único repositório. |
| **#81** | O `pre-push` exige quatro artefatos de worktree que não produz e **revela um por vez**, porque para no primeiro gate que reprova. Medido: nove tentativas de push, zero bloqueadas por defeito de código, cada descoberta custando um ciclo de ~70 minutos. Quem estima a partir do primeiro bloqueio subestima por construção. |
| **#74** | `doctor` classifica `hooksPath` customizado como `info` sem verificar se os gates do Forge foram encadeados. É o único ramo em que a árvore fica inerte e o único classificado como informação — "instalei e está inerte" fica indistinguível de "instalei e encadeei". Foi assim que o gate de acks do liaison passou meses sem rodar, inclusive durante a campanha dedicada a corrigi-lo. |

**A metade barata de #82 é implementada aqui, não na Onda 3.** A issue #82 propõe que o `doctor` nomeie os gates que ninguém invoca — um `check-*.sh` presente em `.forge/scripts/`, ausente dos hooks e ausente de `runtime.gates`. É a **mesma** capacidade do `doctor` que #74 pede, e a própria #82 diz que essa metade "teria evitado o incidente sozinha" e "é barato e não depende de o consumidor adotar fases": teria apontado dez gates órfãos meses antes de uma migration quase ir para produção sem ser aplicada. Implementar as duas metades em ondas diferentes recriaria por construção o defeito de LDG-0014 — duas implementações do mesmo contrato. A issue #82 (sem negrito aqui: ela é rastreada na Onda 3, e um identificador em negrito em duas ondas faz o placar reprovar) permanece na Onda 3 porque só fecha quando o eixo de fase existir; o que sobe para cá é a capacidade, escrita uma vez só.

**Desenho a decidir na onda:** #73 e #81 são o mesmo defeito em duas formas — pré-condição exigida e não provida. As saídas possíveis são o gate produzir o que exige, degradar para aviso quando a pré-condição não é dele, ou revelar **todas** as pendências de uma vez. A terceira é a que corta o custo medido; as três merecem ser comparadas explicitamente antes de escolher.

**DoD da onda:** nenhum gate do template bloqueia por artefato que o harness não entrega nem produz; o `pre-push` reporta o conjunto completo de pendências numa passada; o `doctor` distingue `hooksPath` customizado **com** encadeamento de `hooksPath` customizado **sem**; e o `doctor` **nomeia os gates que ninguém invoca** — um `check-*.sh` presente em `.forge/scripts/`, ausente dos hooks e ausente de `runtime.gates` —, com cenário que reprova quando um gate órfão é plantado na fixture. Sem esta última cláusula a Onda 2 poderia ser declarada completa com a capacidade não construída, e a Onda 3 a encontraria "já movida".

## Onda 3 — O contrato de gate não alcança o artefato implantável

**Item central: #82.** Todo gate do harness recebe caminho de repositório e lê arquivos; `runtime.gates` é lista plana executada no fechamento da wave; os hooks rodam no commit e no push. Os três momentos acontecem quando o artefato implantável ainda não existe — então o harness não tem como expressar a única pergunta que separa "o código está certo" de "o que vai para produção está certo". Medido no `azim-crm`: dez gates que nenhum hook invoca, **sete deles sobre o sistema implantado**, e uma migration que quase foi para produção sem ser aplicada.

| Item | Relação |
|---|---|
| **#82** | Estender o contrato de gate para fases além da árvore de fontes. É a mudança de desenho da onda. |
| **LDG-0013** | Projeto sem `runtime.gates` fecha a wave sem executar nada, registrado como `NO-GATES`. A porta legítima aberta por compatibilidade vira o default silencioso. |
| **LDG-0036** | G5 (frescor de grafo em `/forge:analyze`) é instrução, não gate executável — ninguém chama o script. |
| **LDG-0035** | Nenhum gate confronta `archive-state-machine.yaml` (definição canônica) com a cadeia executável de `spec-transition.sh`. |
| **LDG-0014** | `spec-verify.sh` mantém cópia própria de `get_runtime`/`run_check` em vez de usar `lib/forge-runtime.sh`. Duas implementações do mesmo contrato divergem por construção. |

**Ordem interna (não é indiferente):** LDG-0014 é **pré-requisito**, não sobra. Se `run-gates.sh` ganhar seletor de fase via `lib/forge-runtime.sh` enquanto o `spec-verify.sh` mantém a cópia privada de `get_runtime`/`run_check`, a cópia fica para trás em silêncio e o harness passa a ter dois contratos de fase divergentes. Depois dele: #82 (eixo de fase), então LDG-0013 e LDG-0036, que dependem do eixo existir; LDG-0035 é independente e pode ir a qualquer momento.

**DoD da onda:** um gate declarado numa fase que não é árvore de fontes é executado por alguém, e existe asserção de que é; `runtime.gates` vazio deixa de ser caminho verde silencioso na fatia que era mecânica — pedir uma fase explicitamente com universo vazio reprova, e o caso do projeto sem gate nenhum foi decidido como `wont-fix` em 2026-09-05 por quebrar retrocompatibilidade (ver Reclassificação decidida); nenhuma cópia privada de `get_runtime`/`run_check` sobrevive fora de `lib/forge-runtime.sh`.

## Onda 4 — Resíduos conhecidos da 0.10.0

Oito itens que a própria entrega da 0.10.0 registrou como pendência. Cinco deles são os que hoje estão com status nulo.

| Item | Problema |
|---|---|
| **#75** | `heavy_mutex` sem chave de raiz no `forge.yaml`: migrar um repositório de um host particiona o lock dos demais em silêncio. É o defeito nº 1 que a própria lib existe para corrigir — "um lock particionado é pior que nenhum, porque parece um lock". A remediação óbvia (`resource:` casando com o legado) resolve a metade errada. |
| **LDG-0054** | `check-heavy-mutex` regra 1 mede grafia, não intenção: quebrar a expressão em duas linhas desarma a regra sem mudar a semântica. |
| **LDG-0055** | `w151 [15]`: recuperação de ticket ocupado coberta por unidade, sem rede de integração. |
| **LDG-0056** | `worktree-reconcile.sh` mede adiantamento por `@{u}` — réplica local, que pode estar desatualizada nas duas direções. É o mesmo defeito que o `check-push-ahead` corrigiu usando `ls-remote`, sobrevivendo em outro script do harness. |
| **LDG-0057** | `check-push-ahead`: interseção reporta o máximo entre refs, não a união — o número subestima em push multi-ref. |
| **LDG-0058** | `check-push-ahead`: temporário vaza quando o script morre por sinal. |
| **LDG-0059** | `check-push-ahead`: custo linear em push multi-ref (~35ms/ref; 800 refs = 27,9s). |
| **LDG-0060** | `check-push-ahead`: falha de `rev-list` na interseção sem cobertura de teste. |

**DoD da onda:** os quatro itens de `check-push-ahead` fecham juntos, com um gate que exercita push multi-ref real; `worktree-reconcile` passa a medir pelo remoto; `heavy_mutex` ganha chave de raiz com migração documentada.

## Onda 5 — Liaison

| Item | Problema |
|---|---|
| **#80** | Logs append-only sem `merge=union`: o invariante de escritor único vale entre repositórios, mas não cobre branch paralela do mesmo remetente nem réplica versionada. Medido: 95 mensagens publicadas seriam destruídas por `--theirs`, com `rc=0`, arquivo sintaticamente perfeito e menor, e nada no diff parecendo perda. `--ours` ser inócuo naquele par é acaso. |
| **#83** | O ack não tem como anexar corpo, e 1138 de 1138 acks estão sem `body_ref`. |
| **#84** | `check-liaison-acks` decide pela réplica local e aprova com 15 e 19 acks devidos no hub. |
| **LDG-0022** | O contrato C5 não foi estendido para asserir o estado `+2 Session hooks`. |

**#84 é o exemplar mais puro do tema da Onda 2**, e está aqui por coesão de superfície, não por discordância: um gate que consulta a réplica local em vez do canal de entrega declarado aprova com acks devidos no hub — violação direta de `testing/gate-delivery-channel.md`. Vale notar a simetria com #74, que também é sobre este mesmo gate de acks: lá ele nunca rodava, aqui ele roda e pergunta à fonte errada. São dois defeitos independentes no mesmo lugar, e nenhum dos dois é reparado pelo outro.

**DoD:** driver de merge configurado **e** gate do modo de falha — o item da issue é explícito em que o driver sozinho é insuficiente; `check-liaison-acks` mede pelo hub, com asserção de que a réplica desatualizada reprova.

## Onda 6 — Grafo, route-scan e C4

| Item | Problema |
|---|---|
| **LDG-0027** | O grafo é cego no dogfood: `SKIP_DIRS` pula `bin` e `.forge`, e `.sh` não está no mapa de linguagens — o harness enxerga 19 nós e nenhum dos 107 arquivos do próprio motor. |
| **LDG-0029** | 83 irresolúveis no repositório de referência (38 producer-not-found, 23 group-path-not-literal, 12 producer-never-invoked, 5+5 unindexed). |
| **LDG-0020** | `route-scan`: travessia por caminho, custo exponencial em DAG denso antes do `MAX_DEPTH`. Robustez, não defeito de campo — a saída (memoizar por `(owner, prefixo)`) já está identificada. |
| **LDG-0031** | C4: boundary de arquivo único cross-referenciado não aparece em nenhum dos três níveis, e o C3 omite toda aresta cross-boundary. |
| **LDG-0010** | Promover SRF-01 a bloqueante — bloqueado por insumo e pela cegueira do scanner, não pelo oráculo. Depende de LDG-0029. |

**Ordem interna:** LDG-0029 antes de LDG-0010 (dependência declarada); LDG-0027 é barato e melhora todo diagnóstico posterior no próprio repositório.

**DoD da onda:** o grafo do próprio harness deixa de reportar 19 nós e passa a incluir `bin/` e `template/.forge/scripts/**`, com contagem asseverada em gate; o número de irresolúveis do `route-scan` no repositório de referência cai e o número novo é registrado (a meta é a medição, não um alvo inventado); o C4 mostra boundary de arquivo único e aresta cross-boundary, com cenário de gate que reprova a omissão; LDG-0010 só é promovido a bloqueante depois que LDG-0029 fechar, e o gate que o promove existe antes da promoção.

## Onda 7 — Higiene da suíte e do harness

| Item | Problema |
|---|---|
| **LDG-0021** | A prova de mutação mede as regras que existem, não a superfície de entrada que elas deixam passar. Limite estrutural generalizável a todo gate deste harness — o mais conceitual da lista e o de maior alcance. |
| **LDG-0032** | `w111:259` é asserção vazia (`grep … && true`, sempre verdadeira). |
| **LDG-0034** | Mensagens `FAIL` agrupam 2–3 condições sem indicar qual falhou. |
| **LDG-0052** | Sustenido dentro de `$( )` engole o resto da linha e o script morre com `bad substitution`, e o `bash -n` não vê. |
| **LDG-0033** | `yaml-lite.mjs` não parseia array em flow style; `spec-new.sh` grava no formato que o parser não entende. |
| **LDG-0038** | `red-replay.mjs` não detecta clone shallow e devolve conselho errado. |
| **LDG-0040** | `doctor`: guard de placeholders varre specs arquivadas e o baseline, e acusa `<PROJECT_*>` literal — falso positivo no próprio repositório. |
| **LDG-0037** | `gate-assert-visibility` fica `active` indefinidamente e trava `red-evidence.sh ci` a um formato de histórico. |

**Ordem interna:** LDG-0032 e LDG-0040 são de resolução imediata (uma asserção vazia e um guard que varre o diretório errado), e nenhuma onda anterior declara tocar `tests/w111` ou `doctor.sh` — então ficam aqui, na frente, e não como nota sem executor. LDG-0021 é o oposto: o plano o descreve como "limite estrutural generalizável a todo gate deste harness", e isso não é higiene. Ele fica registrado nesta onda por falta de lugar melhor, mas **não deve ser executado como item de faxina**: quando chegar a vez, abra change SDD próprio, porque mudar como se prova um gate muda a régua de todos os 116.

**DoD da onda:** cada item fecha com o gate que o expõe reprovando antes e passando depois — a asserção vazia de `w111:259` passa a reprovar quando o alvo é mutilado; `doctor` deixa de acusar `<PROJECT_*>` no próprio repositório e existe cenário com placeholder real para provar que ainda acusa quando deve; `yaml-lite.mjs` parseia flow style com caso de round-trip; `red-replay.mjs` distingue clone shallow de histórico ausente. LDG-0021 fecha com o change SDD, não com esta onda.

## Onda 8 — Roadmap de enforcement

| Item | Escopo |
|---|---|
| **LDG-0061** | Enforcement mecânico existe só para .NET; Node, Java e Python seguem em prosa. Os equivalentes existem e o padrão a replicar é o do `w155` (asset no pack, script de auditoria com check/apply, fiação em doctor/verify-build/reviewer, gate com controle e recontrole). |
| **LDG-0062** | `single-impl-interface` é heurística de grep; a saída correta é analisador Roslyn na primeira camada. |
| **LDG-0008** | Enforcement determinista de TDD-em-feature e de cobertura de propriedades (PBT). |
| **LDG-0003** | Maquinaria de capability packs (`forge.yaml packs:`, installer materializando só packs ativos). Desbloqueia a ativação de rule-packs, hoje sinalização documental. |
| **LDG-0001** | Runtime cross-repo da capability authz/observability. **Fora do harness** — pertence aos repositórios de destino. |
| **LDG-0002** | Piloto do gate authz/observability no `axis-go-cloud`. **Fora do harness** — depende de LDG-0001. |
| **LDG-0065** | Enforcement mecânico ausente em Java e Python — separado de LDG-0061 para que fechar o pack Node não feche Java e Python em silêncio. |
| **LDG-0063** | Estratégia de corte de arquivo grande: a rule para em "é smell, revise" e não oferece caminho. Adotar a coreografia do prompt 09 do `vibe-coding-toolkit` (MIT) como orientação cabeada, nunca como prompt solto. |
| **LDG-0064** | Burndown de lint sem portão de decisão. Adotar o portão A/B/C do prompt 02 (MIT) em `testing/quality-gates.md`, com a regra "afrouxar a regra é mudança de config, nunca código mais limpo". |

**DoD da onda:** LDG-0061 — cujo título foi estreitado para Node/TS — fecha quando o pack Node tiver assets, script de auditoria e `node-quality-scan` com gate espelhando o `w155`; LDG-0065 (Java e Python) fecha por conta própria e não é arrastado por ele — controle e recontrole inclusos, e o `MAX_LINES` entrando como sinal não bloqueante ou não entrando; LDG-0062 fecha quando a regra virar analisador Roslyn na primeira camada, ou `wont-fix` com a limitação documentada; LDG-0063 e LDG-0064 fecham como rule/skill com asserção de que o texto é lido por quem deve lê-lo, não como arquivo órfão. LDG-0003 e LDG-0008 são projeto e pedem change SDD próprio, e os dois tiveram o escopo reescrito em 2026-09-05 (LDG-0003 é ativação de rule-pack, não maquinaria de capability pack; LDG-0008 começa pelos dois interruptores de `quality` que ninguém lê). LDG-0001 e LDG-0002 fecharam como `wont-fix` — trabalho de outro repositório, e `promoted` neste ledger significa change local, não transferência entre repositórios (ver Reclassificação decidida).

## Reclassificação decidida (2026-09-05)

> Esta seção substitui a "Reclassificação proposta" da v2. As decisões abaixo foram tomadas com autoridade delegada pelo dono do repositório, cada uma medida contra o código atual antes de ser registrada, e estão aplicadas no `.forge/ledger/ledger.json` — o placar lê de lá, nunca daqui. As duas reclassificações que a v2 propunha e que já haviam sido executadas em ondas anteriores (LDG-0016 a `resolved`, LDG-0020 a `wont-fix`) saem daqui por estarem encerradas.

Depois das Ondas 0 a 8, dez itens seguiam abertos. Nenhum foi encerrado por edição de lista: três terminaram em `wont-fix` com a razão medida, seis continuam `open` com escopo, prioridade ou critério revistos, e a issue #82 fica aberta pelo que sobrou da própria proposta dela.

| Item | Destino | Razão medida |
|---|---|---|
| `#82` | aberta, escopo reduzido a duas peças | O eixo de fase entrou e tem gate (`w171`); sobram o `doctor` de gate órfão (já rastreado em `LDG-0110`) e a documentação da fase, que **não existe** — `phase`/`pre-deploy` não aparecem em rule, comando nem no `FORGE.md` que o consumidor recebe, só em comentário de código e no CHANGELOG. Fechar deixaria a segunda sem dono, porque o placar só rastreia issue e ledger. |
| `LDG-0013` | `wont-fix` | O que sobrava era obrigar todo adotante a declarar um gate, e isso quebra retrocompatibilidade para quem nunca declarou — inclusive este repositório, cujo `.forge/FORGE.md` não tem bloco `runtime` algum. A metade perigosa já está fechada em três lugares (`NO-GATES` em vez de `OK`, asserção do `w131` [12], guarda de vacuidade). O que resta é visibilidade, e ela nasce em `LDG-0110`, uma vez só. |
| `LDG-0001` | `wont-fix` (fora do harness) | `detail` vazio desde 2026-07-20; o destino já rastreia o trabalho melhor (`axis-go-cloud`, LDG-0538 e LDG-0497, ambos P1 open). **`promoted` seria o status errado por definição deste ledger**: `links.promoted_to` é change-id local, e o advisory do `doctor` acusa item `promoted` cujo change não existe — codificar transferência cross-repo assim instalaria falso positivo permanente. |
| `LDG-0002` | `wont-fix` (fora do harness) | Mesmo fundamento, e depende de `LDG-0001`. O que o harness deve ao piloto fica registrado: o gate (`check-authz.sh`) existe; o que falta para torná-lo obrigatório num adotante é `LDG-0003`. |
| `LDG-0029` | `open` P2, escopo revisto | Remedido: 370 rotas resolvidas, 75 irresolúveis, mesma partição — o número está correto. O **tamanho** não estava: um índice de `const string` chaveado `Classe.Membro` (3432 pares em 8336 `.cs`) mais interpolação simples resolve 51 dos 75 sites (68%), e a colisão de nome, medida, é zero entre as 34 referências em jogo (2,8% no índice inteiro). Não é "capacidade nova de symbol-resolution". |
| `LDG-0010` | `open` P3, critério revisto | Não promover — cegueira medida hoje = 75 > 0. O critério anterior era inauditável; passa a ter duas pré-condições medíveis: cegueira remedida depois do índice de `LDG-0029` (projeção 75 → 24) e reprocessamento dos 35 changes mostrando o oráculo decidindo >50% dos achados, contra os 36% de agosto. É dependência, não prioridade baixa. |
| `LDG-0021` | `open`, P2 → **P3**, vira change SDD | Nada em campo está bloqueado por ele, e quem achou os ~25 defeitos foi revisão adversarial, não mutação; a fatia barata já entrou. Correção de número: a régua vale para **116** gates, não 94. Escopo agora nomeado (fuzzing por gramática, corpus real dos adotantes, critério de cobertura de dialeto) para não ficar como nota filosófica. |
| `LDG-0008` | `open` P2, escopo escrito pela primeira vez | Tinha `detail` vazio desde julho. Achado: `quality.require_tests_before_archive` e `require_traceability_before_archive` são entregues no template e no schema e **nenhum código os lê** — todo consumidor instala um harness que afirma exigir testes antes do archive e não exige. Essa é a primeira fatia; TDD-em-feature e cobertura de PBT vêm depois. |
| `LDG-0003` | `open` P3 (era sem prioridade), escopo corrigido | O título descrevia trabalho feito e uma decisão errada. A maquinaria de **capability** pack existe (`capabilities.active`, quatro packs, sugestão do `doctor`, dois com enforcement material). "Installer materializa só packs ativos" hoje quebraria a descoberta, porque o `suggest_pack` exige o `PROFILE.md` em disco. O que falta é a ativação de **rule-pack** de domínio: `pack:`/`opt_in:` não é lido por ninguém e alcança duas rules de prioridade Alta. |
| `LDG-0065` | `open` P3, confirmado | Re-medido e correto: Java e Python têm só `PROFILE.md`, zero assets, nenhuma menção a ruff, mypy, Error Prone, SpotBugs ou Checkstyle. Com `w155` e `w180` no ar o padrão está provado duas vezes, então é replicação, não desenho. A prioridade sobe quando houver adotante Java ou Python exercitando o pack. |

Três registros descreviam o defeito **diferente** do que ele é, e os três só apareceram porque a decisão foi precedida de medição: `LDG-0003` pedia maquinaria que já existe e prescrevia, na outra metade, uma mudança que hoje quebraria o caminho de descoberta de pack; `LDG-0029` classificava como capacidade nova o que 68% dos casos resolvem com um índice de constante literal; e `LDG-0008`, que estava sem detalhe nenhum, escondia um defeito de consumidor em produção — dois interruptores de `quality` publicados no template que ninguém lê. Some-se a correção de escala de `LDG-0021` (116 gates, não 94) e o fato de que `promoted`, o destino que esta seção propunha para `LDG-0001`/`LDG-0002`, é impossível sem instalar um falso positivo permanente no `doctor`.

Seis dos dez continuam `open`, e é assim que o placar deve mostrá-los: escopo revisto não é entrega. O que muda é que agora cada um diz o próprio tamanho.

## Progress tracking

O progresso **não é marcado neste documento**. Ele é medido por:

```bash
node tools/plan-progress.mjs                 # placar por onda
node tools/plan-progress.mjs --wave 1        # detalhe de uma onda
node tools/plan-progress.mjs --json          # saída para máquina
```

O script reconcilia **nos dois sentidos**: extrai os identificadores deste arquivo, consulta o estado real de cada um (`gh issue list` para issues, `.forge/ledger/ledger.json` para o ledger) e — o que faltava na v1 — confronta o conjunto do plano com o universo do repositório. Item aberto que não esteja em nenhuma onda reprova (`orphans`); item do plano que não exista em lugar nenhum reprova (`phantoms`); identificador em duas ondas reprova. Foi assim que #83 e #84 deixaram de poder ficar fora do escopo sem que nada acusasse.

O placar tem três baldes, não dois: entregue (`✓`), **reclassificado** (`~` — `wont-fix` e `promoted` encerram o item, mas fechá-los é edição de JSON, não trabalho) e aberto (`·`). Onda sem DoD sai marcada. `--universe` fixa o universo para teste e execução offline auditável, e nesse modo o placar **nunca imprime a linha afirmativa de sucesso** — universo fornecido reconcilia, mas não atesta. O código de saída reflete o que foi medido: falha real ao consultar o `gh` sai `rc=1`, e só `--no-network`, que é cegueira declarada por quem invoca, sai `rc=0`.

**Convenção de marcação (obrigatória ao editar este plano):** dentro de uma seção `## Onda N`, um item só é rastreado se o identificador estiver em **negrito** — `**#82**`, `**LDG-0013**`. Menção em prosa a PR, issue fechada ou dependência fica sem negrito e é ignorada. A regra existe porque a primeira versão do script contou um `PR #68` citado no texto como item da Onda 0: marcar o que é rastreado é mais honesto do que adivinhar pelo contexto. Mover um item de onda é recortar a linha da tabela — não há segunda lista para dessincronizar.

Duas propriedades são deliberadas:

**Uma linha por item, inclusive os pendentes.** O mesmo princípio do `dotnet-quality-scan`: relatório que só mostra o que foi feito torna a omissão invisível.

**"Não medido" nunca conta como feito.** Se o `gh` não estiver disponível ou autenticado, o item sai como `? não medido` e a onda não pode ser declarada completa. É a lição da issue #49 — "não executei" e "executei e estava limpo" não podem terminar no mesmo lugar.

Uma onda só é considerada fechada quando todos os seus itens estão encerrados **e** a suíte está verde. O placar não substitui `bash tests/run-all.sh`.

## Riscos do plano

**A Onda 1 exige decisão de desenho, não só correção.** Ampliar `ENRICHABLE_DIRS` para `templates/` e `hooks/` muda a política de overlay do updater e pode fazer consumidor deixar de receber correção de maquinaria — que é exatamente o defeito que o bloco gerenciado do `.gitignore` já teve. A saída provavelmente não é ampliar a allowlist, e sim distinguir arquivo de maquinaria de arquivo de política; isso precisa de ADR.

**A Onda 3 é a maior, e é estrutural — mas não é a de maior alcance.** Esse título é de LDG-0021 (a prova de mutação mede as regras que existem, não a superfície que elas deixam passar), que muda a régua de todos os gates do repositório e está na Onda 7 por falta de lugar melhor, com instrução explícita de não ser executado como faxina. #82 pede um eixo novo no contrato de gate (fase de execução), com efeito sobre `FORGE.md`, `run-gates.sh`, os hooks e a documentação. Ela pode justificar um change SDD próprio em vez de uma sequência de correções.

**O passivo de `resolved_at` cresce enquanto #78 estiver aberta.** Medido em consumidor: 39 → 42 → 45 entre medições sucessivas. Backfill antes da correção é trabalho que se desfaz.

**Nenhuma onda deve rodar com a suíte concorrente.** São mais de 90 gates e ~740s; gate manual rodando junto produz falha fantasma em gate alheio.

**Reclassificar e apagar do plano escapa da reconciliação.** O universo do ledger exclui `wont-fix` e `promoted`, então relabelar um item e removê-lo deste documento mantém o placar verde. É o caminho por onde um item sai do plano sem decisão registrada, e nenhuma checagem o cobre hoje.

**O placar não distingue quem decidiu.** Cinco itens têm reclassificação proposta e nada impede uma sessão de executá-la por conta própria, fechando parte do plano por edição de JSON. Por isso o placar tem balde próprio para reclassificado (`~`) — mas a salvaguarda real é humana: **reclassificação é decisão do dono do repositório**, e nenhuma sessão deve aplicá-la sem pedido explícito.

## Disciplina de execução

Vale para toda onda, e não é negociável por pressa:

**TDD red-first.** Nenhuma correção entra sem o teste que reproduz o defeito falhando antes — `/forge:red` para bugfix, com Red observado e replicável, não declarado. Um item deste plano que chegue com teste escrito depois da correção não conta como fechado, porque o teste que nasce verde não prova que mediria o defeito.

**Property-based testing onde há propriedade.** Invariância, idempotência, round-trip e conservação pedem PBT com seed fixa e shrinking — o `yaml-lite` de LDG-0033 é round-trip; a interseção de refs de LDG-0057 é conservação (a união não pode ser menor que qualquer parcela); o merge append-only de #80 é conservação de mensagens publicadas.

**Teste de contrato.** Mudança que toca superfície acordada — `runtime.gates` (#82), o contrato do adapter, o formato do ledger (#78), o protocolo do liaison (#80, #83, #84) — precisa de asserção contra a definição canônica, não apenas contra a implementação. LDG-0035 existe exatamente porque essa asserção falta hoje entre `archive-state-machine.yaml` e `spec-transition.sh`.

**Teste de integração pelo canal de entrega.** A prova exercita o caminho real, não o alvo isolado: instalar o harness num fixture e rodar `update` de verdade (Onda 1), dirigir o `pre-push` como o git o dirige, com ref no stdin (Onda 2), executar o gate pela fase declarada (Onda 3). É a rule `testing/gate-delivery-channel.md`, e é o que separou maquinaria presente de maquinaria acionada nas duas últimas entregas.

**Controle e recontrole em toda prova de gate.** Mutar o alvo faz o gate reprovar; restaurar faz voltar a passar, e a restauração é verificada. Sem o par, um gate que sempre passa é indistinguível de um gate que funciona.

## Entrega aos consumidores

A ordenação inteira deste plano se justifica por dano a terceiros, então o plano deve dizer como a correção chega a eles — caso contrário o critério não se completa.

As Ondas 0a, 1 e 2 formam a **0.11.0** e devem sair juntas: são os defeitos que ferem quatro consumidores a cada upgrade, e #73/#76 se compõem (o primeiro push após o upgrade encontra os dois bloqueios em sequência). Corrigir um e publicar sem o outro entrega um upgrade que ainda bloqueia, com a diferença de que agora ninguém espera que bloqueie.

A Onda 0b viaja junto se estiver pronta; não segura a release. A Onda 3 é candidata natural a **0.12.0**, com change SDD próprio. As Ondas 4 a 8 se acomodam em releases seguintes conforme fecharem, sem agrupamento obrigatório.

Consumidores precisam ser avisados de que a 0.11.0 é o upgrade que conserta o upgrade — e a nota de release deve dizer explicitamente o que fazer com o `.forge.bak-N` de quem já atualizou.

## Trabalho aberto fora deste plano

Existe um change SDD residual em `.forge/specs/active/gate-assert-visibility`, `status: verified` com `archive.eligible: false`, mantido ativo por decisão registrada no manifest. Ele não está entre os itens acima porque não é issue nem entrada de ledger, mas um plano que se apresenta como varredura do trabalho aberto precisa dizer que ele existe. LDG-0037 é justamente a consequência de mantê-lo ativo indefinidamente, e está na Onda 7 — fechar LDG-0037 provavelmente decide o destino do change.
