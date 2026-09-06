# Especificação — ataque ao backlog aberto (quatro issues, dezesseis itens de ledger)

> Estágio 1 de cinco. Este documento é o contrato que o implementador segue e que o revisor cobra. Nada foi implementado ao produzi-lo; toda correção que apareceu no caminho está registrada aqui, não aplicada.
>
> Base medida: worktree `.forge/worktrees/backlog-attack`, branch `feat/backlog-attack`, em 2026-09-05. Toda afirmação de número neste documento foi medida nesta sessão, salvo onde o texto diz explicitamente que a medição é de terceiro e de quando.

---

## Sumário executivo

Vinte achados abertos. Depois de ler cada um na fonte e medir contra o código, **nove registros descrevem o defeito diferente do que ele é** — dois deles prescrevendo solução ou instrumento que a medição prova errado — e **um defeito novo apareceu, mais grave que a maioria dos vinte**: o `pre-push` é cego à forma mapeada de `runtime.gates` que a 0.11.0 publicou, de modo que um consumidor que adote `phase:` perde silenciosamente toda a execução de gate no push. Isso está confirmado por experimento, não por leitura, e é exatamente o modo de falha que a issue `#82` existe para acabar.

Os vinte não se resolvem como vinte. Agrupam-se em sete famílias por causa, e o agrupamento é o que economiza: em quatro delas os itens compartilham arquivo, leitor e prova, e resolver um sozinho reinstala o defeito no outro. Quinze dos vinte entram nesta leva — mais o `LDG-0150`, novo, que fecha aqui: dezesseis itens de trabalho —; **cinco** dos vinte ficam de fora (`LDG-0010`, `LDG-0021`, `LDG-0065`, `LDG-0100`, `LDG-0131`), com o motivo medido em cada caso — a §4 tem oito linhas porque três delas recortam escopo dentro de itens que entram, e não são itens dos vinte — e dois deles ficam de fora porque **não são implementação**: `LDG-0021` pede change SDD próprio e `LDG-0131` é uma decisão, cuja instrução de medição, aliás, aponta para o comando errado.

A ordem não é preferência. Cinco dependências têm mecanismo declarado, e três delas invertem a intuição: corrigir `ledger-ops update` precede escrever o `detail` dos itens vazios, porque escrevê-lo com o `update` atual reproduz o defeito; estender o reconhecedor do lint precede fiá-lo no `pre-push`, porque fiar antes bloqueia o primeiro push no próprio harness; e o leitor único de `runtime.gates` precede o `doctor` de gate órfão, porque senão o `doctor` vira o terceiro leitor do mesmo contrato.

---

## 1. Achados de medição que contradizem o registro

Esta seção vem antes de tudo porque é a de maior valor e porque muda o escopo de sete dos vinte itens. Cada achado traz o comando ou o experimento que o produziu.

### A1 — O `pre-push` é cego à forma mapeada de `runtime.gates` (defeito novo, não registrado)

A 0.11.0 entregou o eixo de fase da issue `#82`: `runtime.gates` passa a aceitar block-sequence YAML com `phase:`, lida pelo leitor canônico `lib/forge-runtime.sh::forge_runtime_gate_entries`, que trata as duas formas — CSV escalar em bash puro, forma mapeada delegada a `lib/gate-phase.mjs`. `run-gates.sh:58` e `spec-verify.sh:92` usam esse leitor. **O `pre-push` não.** Ele tem um leitor próprio, `fm_field()` em `template/.forge/hooks/git/pre-push:184-190`, um `awk` que extrai o valor escalar da linha `  gates:` dentro do bloco `runtime:`.

Experimento executado nesta sessão, com o `awk` literal do hook aplicado a dois `FORGE.md` sintéticos:

```
FORMA MAPEADA (0.11.0)  -> fm_field gates = []
FORMA CSV (antiga)      -> fm_field gates = [check-red-first,check-authz]
```

A consequência é integral e silenciosa: com a forma mapeada, `GATES_CSV` fica vazio, o `if [ -n "$GATES_CSV" ]` da linha 258 não entra, o laço não roda, e o hook não imprime uma linha sobre isso. Um consumidor que adote `phase:` — inclusive declarando tudo como `phase: source`, que é a fase que o push executa — deixa de rodar **todos** os gates no push, e o push segue verde. Pior que não ter fase: adotar a fase desliga a cobrança que existia antes. É a forma exata do "silêncio que parece sucesso" que a `#82` denuncia, produzida pela entrega que fechou o núcleo da própria `#82`.

Nota de causa raiz, que importa para a correção: `fm_field` é o **terceiro** clone do mesmo leitor. Existe em `pre-push:184`, em `handoff-gen.sh:42` e como idioma declarado em `hooks/session/on-session-start.sh:11`. É a classe de `LDG-0014` (duas implementações do mesmo contrato divergindo em silêncio) já materializada três vezes.

Registrar como `LDG-0150`, P2, e corrigir nesta leva — é o item de maior severidade do conjunto.

### A2 — `LDG-0008` fala em dois interruptores inertes; são três, e o terceiro é o pior

`template/.forge/forge.yaml:26-29` publica **três** chaves sob `quality:`, não duas:

| chave | leitor em `scripts/`, `hooks/`, `bin/` | leitor em `commands/`, `agents/`, `rules/` |
|---|---|---|
| `require_tests_before_archive` | nenhum | nenhum |
| `require_traceability_before_archive` | nenhum | nenhum |
| `require_human_approval_before_archive` | nenhum | nenhum |

As únicas ocorrências das três em todo o repositório, fora de `plugin/` gerado e `node_modules`, são `template/.forge/forge.yaml`, `template/.forge/schemas/forge.schema.json` e `docs/refer/forge-project-harness.md`.

O terceiro é o pior dos três, e por um motivo que o item não registra: **a capacidade que ele promete já existe e funciona, sob outro nome.** A aprovação humana antes do archive é o gate de manifesto `human_archive_approval`, declarado em `schemas/spec-manifest.schema.json:53-59`, exigido por `lib/validate-archive.mjs:13` e escrito por `approval-log.sh:41`. A chave do `forge.yaml` é, portanto, uma segunda verdade não lida sobre um enforcement que já é real — e um adotante que a puser em `false` esperando pular o gate vai encontrá-lo mesmo assim, sem que nada explique por quê. A saída honesta para essa é remoção, não fiação: fiar criaria duas chaves para o mesmo fato, que é o defeito que `check-push-ahead.sh:166` já registra ter recusado a cometer.

A superfície é ainda maior do que as três, e a spec precisa ser honesta sobre isso sem inflar o escopo. Varredura das 61 chaves-folha de `$defs/forgeManifest` e `$defs/forgeFrontmatter` do `forge.schema.json` contra `scripts/`, `hooks/` e `bin/`: 16 sem leitor. Dessas, `sdd.default_mode`, `sdd.default_rigor`, `sdd.default_scale`, `sdd.archive_policy`, `sdd.human_gate_required` e `quality.evals_root` também não aparecem em `commands/`, `agents/` nem `rules/` — zero ocorrências literais em qualquer lugar além de schema, template e doc de referência. Mas a ofensa delas é de outra natureza: prometem um **default**, cuja ausência é inofensiva, e não um **enforcement**, cuja ausência é uma afirmação falsa sobre o que o harness cobra. Só as três `require_*` prometem enforcement. Esta leva decide as três; as demais viram registro novo (`LDG-0151`), não trabalho.

### A3 — `LDG-0069` está registrado maior do que é: os dois lints rodam, e contra o corpus real

O item diz que `check-shell-pipeline.sh` e `check-heredoc-hash.sh` "existem e nenhum hook os invoca", e conclui que são "o gate que ninguém invoca" e "um lint que só roda quando alguém lembra". A primeira metade é literalmente verdadeira: nenhum hook de git os chama. A conclusão não é.

Medido:

| lint | gate próprio | cenário que varre a árvore real | passo dedicado no CI |
|---|---|---|---|
| `check-shell-pipeline.sh` | `tests/w145-shell-pipeline-lint-gate.sh` | `[8]`, linha 110: `--path "$WS/template" --path "$WS/tests"`, exige `rc = 0` | sim — `.github/workflows/ci.yml:67-68` |
| `check-heredoc-hash.sh` | `tests/w159-heredoc-hash-lint-gate.sh` | `[8]`, linha 147: `--path "$WS/template" --path "$WS/tests" --path "$WS/bin"`, exige `rc = 0` e contador de controle | não, mas `ci.yml:49` roda `tests/run-all.sh`, que executa o gate |

`tests/run-all.sh:48` varre `tests/*-gate.sh`, e os dois arquivos casam. Ou seja: os dois lints rodam contra o corpus real do harness em toda execução de CI, deterministicamente, com veredito bloqueante. O que falta não é execução — é **latência**: o autor descobre a violação depois de empurrar, não antes de commitar. Isso rebaixa o item de "gate órfão" para "realimentação tardia", muda a urgência e muda a correção (fiar no `pre-push` passa a ser conveniência com risco próprio, não o remédio de uma lacuna de cobertura).

Vale registrar a ironia útil: foi precisamente `w145[8]` que varreu `tests/w20-spec-gate.sh` e **passou**, com o `ls -1 … | sort` lá dentro — o que prova, no mesmo movimento, que o lint roda e que o reconhecedor dele é cego para a classe de `LDG-0141`. O defeito verdadeiro é o reconhecedor, não a fiação.

### A4 — A issue `#102` foi medida numa árvore que não é o template, e o remédio que ela prescreve não tem de onde ser copiado

A issue afirma que quatro caminhos escrevem o cursor (`thread open`, `thread join`, `send`, `read`) e que `ack)` é o único que não escreve, e sugere que a correção "é o mesmo one-liner dos outros três sítios". Censo do arquivo em todas as árvores do ecossistema mais o template:

| árvore | linhas | sítios que escrevem `state.cursors[…] = ` |
|---|---|---|
| `axis-go-cloud` | 1137 | **4** (361, 429, 649, 839) |
| `Axis.PadSimulator` | 1424 | 2 |
| `axis-fare-validator` | 1227 | 1 |
| `axis-device-platform` | 1111 | 1 |
| `azim-crm` / `collatra` | 865 | 1 |
| **`forge-harness/template`** | **1250** | **1** (818, dentro de `read)`) |

A issue foi escrita sobre o `axis-go-cloud`, que é um fork local divergente. No **template** — a fonte que esta spec contrata — `thread open)`, `thread join)` e `send)` nunca escreveram cursor, em nenhum commit do histórico do arquivo (`git log` de nove commits, verificado). As únicas referências a `cursors` no template estão nas linhas 311, 753-760, 810-818, 851-855 e 904-910, e só a de 818 escreve.

Duas consequências para o implementador. Primeira: não existem "outros três sítios" de onde copiar o one-liner; existe um, `read)`, e é dele que sai a regra de não-regressão (linhas 813-817). Segunda, e é a que muda o argumento: a distinção que a issue diz que a correção "preserva" — `send` avançar o cursor para a própria mensagem, provando participação — **não existe upstream**. Isso torna o defeito pior no template, não mais brando: `read --upto` é hoje o único caminho pelo qual um cursor avança, então toda mensagem ackada permanece não lida a menos que alguém rode um segundo comando. O número de 148 mensagens simultaneamente ackadas e não lidas foi medido nas réplicas; a causa, no template, é ainda mais concentrada do que a issue supõe.

### A5 — A issue `#103` invoca um precedente que não existe, e por isso subdimensiona o próprio escopo

A issue pede recusar valor vazio "a mesma disciplina que o `update` já aplica a flag desconhecida". Medido: `update` não aplica disciplina nenhuma a flag desconhecida. Todos os seis subcomandos de `template/.forge/scripts/ledger-ops.sh` terminam o `case` de parsing em `*) shift ;;` — `add` (112), `update` (163), `resolve` (201), `promote` (233), `harvest` (261) e `list` (376). Não existe helper de flag desconhecida em `ledger-ops.sh`. Ele existe em `liaison-ops.sh` — chama-se **`_reject_unknown`** (linha 111, 22 usos, inclusive dentro do próprio `ack)`), e **não** `_unknown_flag`, nome que não ocorre em lugar nenhum do repositório —, e é de onde a memória do precedente provavelmente vem.

O efeito é maior que o descrito na issue e provavelmente já se materializou. `*) shift ;;` engole a flag **e**, na iteração seguinte, o valor dela. Um `--details "texto longo"` (typo) ou um `--detai "…"` desaparece por completo, a entrada nasce com `detail: ''` e o comando imprime `OK`. O ledger tem hoje **três entradas abertas com `detail` vazio** — `LDG-0100`, `LDG-0101` e `LDG-0102`, as três criadas no mesmo instante (`2026-09-04T18:44:45-03:00`), as três `origin: manual`. Não há como provar retroativamente qual porta as produziu, mas as duas portas silenciosas estão ambas abertas, e `add` sequer exige `--detail` (só `--type` e `--title` são obrigatórios, linhas 17-18 do bloco). O escopo correto de `#103` é, portanto, de três partes, não duas.

### A6 — `LDG-0131` prescreve o comando errado, e a dúvida central dele já é decidível

O item manda decidir "com o diff na mão: `git diff origin/develop..origin/wip/upgrade-safety-ldg-0131`". Esse comando devolve **154 arquivos, 873 inserções e 13.303 remoções**, porque a branch está 20 commits atrás de `develop`: quase tudo o que ele mostra como remoção é trabalho posterior de `develop` (`w168` a `w186`, `tools/plan-progress.mjs`) que a branch simplesmente não tem. É o instrumento errado, e quem o rodar vai concluir que há 13 mil linhas a avaliar.

Os números corretos, todos medidos nesta sessão:

| pergunta | comando | resultado |
|---|---|---|
| o que a branch propõe | `git diff $(git merge-base origin/develop origin/wip/…)..origin/wip/…` | 15 arquivos, 911 inserções, 29 remoções, 10 commits |
| o que ainda não foi avaliado | `git show ff4578a` | 9 arquivos, 202 inserções, 112 remoções |

Os nove commits anteriores a `ff4578a` correspondem ao material do PR #79, cujo conteúdo já está em `develop` (os gates `w153` e `w154` estão lá; `git cherry` não os reconhece porque o merge foi por squash). **O único material genuinamente não avaliado é o commit `ff4578a`.**

E a dúvida que o item levanta como o ponto mais delicado — a remoção de `lib/scan-exclude.sh`, "que develop tem e este working tree apaga" — já é decidível sem revisar linha nenhuma. Em `develop`, `grep -rn "scan-exclude"` no repositório inteiro devolve **duas ocorrências, ambas dentro do próprio arquivo** (o cabeçalho na linha 2 e o exemplo de uso na linha 14). O arquivo não tem um único chamador; e o substituto (`SKIP_PATTERNS` mais `skipDir()` em `lib/source-scan.mjs`) está no mesmo commit `ff4578a`. É código morto cuja remoção não órfã ninguém.

Isso não muda a decisão de escopo — `LDG-0131` continua fora desta leva, porque continua sendo decisão e não implementação. Muda o custo da decisão, de "avaliar 380 linhas com uma incógnita estrutural" para "revisar um commit de 202 linhas cuja única incógnita já foi respondida".

### A7 — `LDG-0100` tem zero exposição em campo

O item registra que `check-liaison-acks.sh` só lê o hub para os transportes `fs` e `manual`, caindo na réplica local para `git`/`gh` — o que está correto e é decisão deliberada, documentada no cabeçalho do próprio script (linhas 38-42). Censo dos cinco `liaison.yaml` do ecossistema: **todo canal declarado, em todas as árvores, usa `kind: "fs"`.** Nenhum usa `git` nem `gh`. A lacuna é real no código e não alcança ninguém hoje.

### A8 — `LDG-0067` não fecha pela mesma decisão do id de ledger

O item conclui que colisão de ordinal de gate é "mesma familia do item de numeracao de ledger; a saida provavelmente e a mesma decisao". Os dois mecanismos não são paralelos, e a diferença é estrutural. O ledger tem **um** arquivo físico, que vive no tronco por desenho: `_forge_main_root()` resolve por `--git-common-dir`, e `add` calcula `max + 1` sobre esse arquivo único — a serialização é por construção, e a rule `conventions/machinery-propagation.md` a declara norma ("estado de projeto mora no tronco, não na branch"). Ordinais de gate são **N** arquivos que vivem por branch em `tests/`, sem autoridade compartilhada onde escrever. Não há para onde transferir a decisão. A saída tem de ser outra: derivar o próximo ordinal do tronco remoto em vez da árvore local, e detectar a colisão deterministicamente quando ela ainda assim ocorrer.

### A9 — `LDG-0101` captura metade da divergência, e a metade que falta é a que tem consequência

O item diz que o schema "descreve body/body_ref como mutuamente obrigatório, mas validateEnvelope aceita os dois ausentes". Medido em `template/.forge/schemas/liaison-message.schema.json` e em `lib/liaison-merge.mjs:273-292`, há duas divergências e só uma está registrada:

1. A **descrição** de `body` afirma "Mutuamente exclusivo com body_ref — exatamente um dos dois é obrigatório". A **estrutura** do schema não afirma nada disso: `body` e `body_ref` não estão em `required`, e o `allOf` tem apenas duas cláusulas `if/then` sobre `kind`. `validateEnvelope` implementa "ambos opcionais, mutuamente exclusivos quando presentes", com justificativa escrita na linha 284. Aqui quem mente é a descrição, e o código está certo.
2. A exclusão mútua que o validador **de fato** cobra (linha 287, `mensagem com body E body_ref`) não está codificada no schema de forma alguma. Uma mensagem com os dois campos **passa no schema e reprova no validador** — a divergência de direção oposta, com consequência real para quem valide por `ajv` antes de enviar.

O item registra só a primeira, e registra-a invertida (fala em "mutuamente obrigatório" como se o schema exigisse ambos). A correção tem de fechar as duas.

---

## 2. Os grupos, e por que cada um é um grupo

O critério de formação é sempre o mesmo: **itens que compartilham a causa, o arquivo a tocar e a forma da prova**. Onde dois itens só compartilham o assunto, ficam separados.

| Grupo | Itens | Causa comum | O que se economiza ao resolver junto |
|---|---|---|---|
| **G1 — Gate declarado que ninguém executa** | `LDG-0150` (novo), `#82` (peça executável), `LDG-0110`, `LDG-0069` | Os quatro respondem à mesma pergunta a partir das mesmas duas fontes: os `check-*.sh` presentes em disco e os nomes declarados em `runtime.gates`. | Um leitor único de `runtime.gates`. Resolvidos em separado, cada um escreve o seu — que é literalmente o defeito `LDG-0014`, hoje já materializado três vezes como `fm_field`. |
| **G2 — Interruptor publicado que nenhum código lê** | `LDG-0008` (primeira fatia), `LDG-0003` | Chave entregue ao adotante — em `forge.yaml` + schema, ou no frontmatter de rule — sem leitor em lugar algum. | A mesma decisão binária por chave (tornar real ou remover) e a mesma prova: um gate que reprova quando um interruptor declarado como load-bearing não tem leitor. Uma prova serve às duas famílias de chave e às futuras. |
| **G3 — Estado derivado da própria árvore numa operação de visão global** | `LDG-0067`, `LDG-0068`, `LDG-0141` | Uma decisão tomada a partir do que esta árvore de trabalho por acaso contém, quando a resposta correta depende do que outras árvores, branches ou clones contêm. | O remédio é o mesmo nos três — **dizer em voz alta** o que foi derivado e de onde —, e a prova é a mesma: uma segunda árvore que discorda da primeira. |
| **G4 — Monotonicidade violada no liaison** | `#101`, `#102` | Estrutura append-only operada por um caminho de escrita que pode regredi-la (o push substitui o log do hub) ou deixar de avançá-la (o ack não move o cursor). | A fixture: duas réplicas mais um hub. Os dois itens exigem exatamente esse arranjo, e as duas propriedades (fast-forward-ou-recusa; cursor não regride) provam-se no mesmo cenário. |
| **G5 — O instrumento de registro aceita o vazio** | `#103`, `LDG-0140` | Três portas do mesmo arquivo (`ledger-ops.sh`) por onde entra registro sem conteúdo enquanto o comando responde `OK`. | Uma disciplina de parsing e uma de veredito, aplicadas de uma vez aos seis subcomandos, com um gate só. |
| **G6 — Texto normativo que o código contradiz** | `LDG-0101`, `LDG-0102`, `#82` (peça documental) | Prosa normativa sem verificação mecânica que a mantenha alinhada ao código. | O padrão de correção é idêntico: corrigir o texto **e** fiar o check que impede a próxima deriva. Corrigir só o texto é entregar o mesmo item de novo daqui a três meses. |
| **G7 — Cegueira do route-scan** | `LDG-0029` | Família de um nesta leva. | — |

Observação sobre `#82`: a issue se parte em duas peças que caem em grupos diferentes, e isso é proposital. A peça executável (o `doctor` que denuncia o gate órfão) é G1, porque lê as mesmas fontes que os outros três. A peça documental (dizer que a fase existe e o que a fase `source` não cobre) é G6, porque a correção dela tem a forma de G6 e não a de G1. A issue só fecha quando as duas entrarem.

---

## 3. Ordem e dependências

Cinco dependências têm mecanismo, não preferência. Estas são de cumprimento obrigatório; o resto da ordem é folga.

| Precede | Depende | Mecanismo |
|---|---|---|
| `#103` (recusar vazio, flag desconhecida e no-op) | escrita do `detail` de `LDG-0100`, `LDG-0101`, `LDG-0102` | Escrever o `detail` com o `update` atual reproduz o defeito que se está corrigindo: valor vazio devolve `OK` sem gravar, e flag com typo é engolida com o valor junto. Escrever antes é assinar o próprio laudo. |
| `LDG-0150` (leitor único no `pre-push`) | `LDG-0110` (`doctor` de gate órfão) | O `doctor` precisa cruzar `runtime.gates` de **todas** as fases. Se o `pre-push` mantiver o `fm_field` próprio, o `doctor` vira o terceiro leitor do mesmo contrato, com três respostas possíveis para a mesma pergunta. |
| `LDG-0141` (estender o reconhecedor do lint) | `LDG-0069` (fiar os lints no `pre-push`) | Fiar antes de estender e corrigir os sítios medidos faz o primeiro push depois da entrega reprovar no próprio harness. A ordem inversa entrega um hook que bloqueia quem o instalou. |
| `LDG-0029` (índice de constante literal) | `LDG-0010` (promover SRF-01) — **fora desta leva** | `lib/api-surface.mjs:479`: enquanto `cegueira.length > 0`, `surContractToCode` devolve `inconclusive` e move os achados para `abstained`. `NAO_SUPRIME` está vazio (linha 476), então qualquer categoria de irresolúvel derruba o veredito inteiro. |
| `LDG-0003` (chave de ativação de rule-pack) | duas rules de prioridade Alta terem porta de entrada | `rules/README.md:17` e `capabilities/README.md:11` declaram, por escrito, que `pack:` é sinalização documental **até** a chave existir, e apontam para `LDG-0003` como a razão. Enquanto não existir, `architecture/authz-pdp-pep.md` e `architecture/pii-pci-classification.md` não têm como ser contratadas por projeto nenhum. |

Sequência sugerida, respeitando o acima:

1. **G5** — `#103` e `LDG-0140`. Destrava a escrita honesta de tudo o que vier depois, inclusive dos registros novos desta spec.
2. **G1, primeira metade** — `LDG-0150`: o `pre-push` passa a usar `forge_runtime_gate_entries`. É o item de maior severidade e o mais barato dos grandes.
3. **G3, `LDG-0141`** — estender o reconhecedor e corrigir os sítios medidos.
4. **G1, segunda metade** — `LDG-0110` (o `doctor`) e `LDG-0069` (a fiação, agora segura).
5. **G3, resto** — `LDG-0067` e `LDG-0068`.
6. **G2** — `LDG-0008` (primeira fatia) e `LDG-0003`.
7. **G4** — `#101` e `#102`.
8. **G6** — `LDG-0101`, `LDG-0102` e a documentação da fase de `#82`.
9. **G7** — `LDG-0029`. Independente de tudo acima; pode correr em paralelo desde o início, e é o único item cuja fatia é grande o bastante para justificar isso.

---

## 4. O que NÃO entra nesta leva, e por quê

| Item | Motivo | O que fica registrado no lugar |
|---|---|---|
| `LDG-0021` — prova de mutação mede a regra, não a superfície de entrada | Muda a régua de prova de **116 unidades**, e vale precisar a composição porque a glosa do próprio item a descreve mal: `tests/run-all.sh` executa 114 arquivos `tests/*-gate.sh` (dos quais 93 casam `w*`) mais 2 suítes `bats` (`validators.bats` e `snapshot/claude-contract.bats`), e não "115 `.sh` no diretório". O total de 116 que o item registra está certo; o que o compõe, não. Além disso exige decidir o eixo de fuzzing guiado por gramática e a estratégia de corpus real dos repositórios adotantes, o que o próprio item já registra como pedido de change SDD com `design.md`. | Nada a fazer aqui. O item permanece `open`, P3, com o escopo de change SDD já escrito nele; o `detail` ganha a composição correta do 116. |
| `LDG-0131` — trabalho não commitado de `feat/upgrade-safety` | É **decisão**, não implementação: alguém tem de julgar se o commit entra, entra em partes, ou é descartado. | Atualizar o `detail` com A6: o instrumento correto é `git show ff4578a` (9 arquivos, 202+/112−), não o `git diff origin/develop..origin/wip/…` (154 arquivos, 13.303−) que o item prescreve; e a dúvida central — a remoção de `lib/scan-exclude.sh` — está respondida: zero chamadores em `develop`. |
| `LDG-0010` — promover SRF-01 a bloqueante | Bloqueado por `LDG-0029` pelo mecanismo da tabela anterior, e a segunda pré-condição do próprio item (reprocessar os 35 changes da amostra de 2026-08-04 com o scanner novo e mostrar que o oráculo decide a maioria, contra os 36% de agosto) é trabalho de medição que não cabe junto com a implementação do índice. | Nada. O item já diz "é DEPENDÊNCIA, não prioridade baixa"; a spec confirma e não o toca. |
| `LDG-0065` — enforcement em Java e Python | O próprio item declara o critério de subida: "a prioridade sobe no dia em que houver adotante Java ou Python exercitando o pack". Medido: `template/.forge/capabilities/backend-java-relational/` e `backend-python-relational/` têm **um** arquivo cada (`PROFILE.md`), contra 4 e 6 dos packs .NET e Node. Escrever enforcement sem repositório onde rodá-lo **fabrica um gate órfão** — que é precisamente o defeito de G1. Implementá-lo agora contradiz a leva. | Nada. O critério de subida já está no item e é auditável. |
| `LDG-0100` — `check-liaison-acks.sh` não lê o hub em `git`/`gh` | Zero exposição em campo (A7): os cinco `liaison.yaml` do ecossistema declaram `kind: "fs"`. | Escrever o `detail` (hoje vazio) com o censo de transportes e com a condição que reabre o item: o primeiro canal declarado como `git` ou `gh`. |
| A generalização de `LDG-0008` para as demais chaves sem leitor | `sdd.default_mode`, `sdd.default_rigor`, `sdd.default_scale`, `sdd.archive_policy`, `sdd.human_gate_required` e `quality.evals_root` não têm leitor em lugar nenhum, mas prometem **default**, não enforcement. Varrê-las junto transformaria uma correção de honestidade em uma limpeza de schema com risco de retrocompatibilidade desproporcional. | Registro novo `LDG-0151`, P3, com a lista medida e a distinção entre "chave que promete default" e "chave que promete cobrança". |
| A triplicação de `fm_field` | A correção de `LDG-0150` elimina o clone do `pre-push`. Os outros dois (`handoff-gen.sh:42`, `hooks/session/on-session-start.sh`) leem chaves escalares onde a forma mapeada não se aplica, e consolidá-los agora amplia o diff do item mais crítico da leva sem fechar risco nenhum. | Registro novo `LDG-0152`, P3. |
| O "gate de paridade de transporte" proposto na `#101` | A proposta é reprovar quando duas árvores que escrevem no mesmo hub têm `_dir_push` divergentes. O harness não enxerga a árvore do consumidor: o censo que a issue exibe foi rodado por um humano sobre `~/Documents/projects`. Um gate assim, dentro do harness, não tem universo para varrer — e um gate sem universo é o que a guarda de vacuidade existe para reprovar. | A peça viável entra na `#101` (ver §5.4): o **consumidor** ganha um check de deriva da própria cópia contra o template. A peça cross-repositório fica registrada como fora do alcance do harness. |

---

## 5. Especificação por item

Convenções para toda esta seção. O teste é escrito **antes** da correção e observado vermelho, conforme `rules/testing/regression-red-first.md`, item 3. Onde a prova depende do caminho pelo qual o gate roda em produção, ela usa o canal real, conforme `rules/testing/gate-delivery-channel.md` — hook exercitado por `git push` de verdade, gate invocado como o `run-gates.sh` o invoca. Todo gate novo carrega contador de controle: universo vazio reprova, nunca aprova em silêncio.

**Asserção negativa não é vermelho (correção obrigatória da revisão adversarial, §9).** Um cenário da forma "o `doctor` **não** acusa X", "o cursor **não** regride", "a rule **não** reprova" é satisfeito trivialmente por um harness em que o mecanismo inteiro não existe — ele passa **antes** da correção e não prova nada. Sete cenários desta spec foram escritos assim e estão marcados como vermelhos sendo verdes hoje: `w191[2]`, `w191[3]`, `w192[9]`, `w193[7]`, `w195[6]`, `w195[8]`, `w195[9]` — mais `w198[3]`, que a própria §5.7 já reconhece ("hoje já se abstém, mas por não tentar"). A regra que vale para todos: **toda asserção negativa é pareada com uma asserção positiva observável que só existe depois da correção** — a linha de contador ("examinei N `check-*.sh`, 0 órfãos"), o valor do cursor lido do `state.json` e comparado com o índice esperado, o veredito nomeado do validador. Sem o par, o cenário entra na tabela rotulado `verde hoje — controle`, nunca `vermelho`, e não conta como prova de correção.

Ordinais novos a partir de `w190`; ids de ledger novos a partir de `LDG-0150`, editados à mão depois do `add`.

### 5.1 — G1: gate declarado que ninguém executa

#### `LDG-0150` (novo, P2) — o `pre-push` é cego à forma mapeada de `runtime.gates`

**Defeito.** O `pre-push` lê `runtime.gates` com um `awk` próprio que só entende CSV escalar numa linha, de modo que um consumidor que adote a forma mapeada com `phase:` — a forma que a 0.11.0 publicou — deixa de rodar todos os gates no push, sem uma linha de aviso.

**Mecanismo da correção.** `template/.forge/hooks/git/pre-push` passa a dar source em `$ROOT/.forge/scripts/lib/forge-runtime.sh` e a obter os gates da fase `source` por `forge_runtime_gates_phase source "$ROOT"`, substituindo o bloco das linhas 257-275. Três exigências que não são opcionais:

- **Delegação em alvo ausente é erro, não silêncio.** O hook já aplica essa disciplina a `check-ai-attribution.sh` (linhas 71-74) e a `check-liaison-acks.sh` (111-114): diretório presente e script ausente reprova. `lib/forge-runtime.sh` ausente com `.forge/scripts/lib/` presente segue a mesma regra.
- **Ausência de `node` não pode virar zero gates.** `forge_runtime_gate_entries` delega a forma mapeada a `node lib/gate-phase.mjs` e devolve vazio, calado, quando `node` não existe. O hook tem de distinguir "nenhum gate declarado" de "há gate declarado em forma que eu não consegui ler": a distinção tem de ser feita pela **capacidade de ler**, não pela forma do frontmatter. `  gates:` sem valor inline com zero entradas devolvidas **não** pode bloquear por si: é exatamente o estado default de todo projeto novo — `template/.forge/templates/FORGE.md:24` entrega `gates:` como chave vazia, e `gate-phase.mjs` documenta esse mesmo formato como a assinatura da forma mapeada. Bloquear nesse predicado quebraria o primeiro push de todo adotante. O predicado correto é: `  gates:` sem valor inline **e** o leitor da forma mapeada indisponível (`node` ausente ou `lib/gate-phase.mjs` ausente) ⇒ `BLOQUEADO`, nomeando que a declaração não pôde ser lida; com o leitor disponível e zero entradas, é `NO-GATES` e o push segue. É a mesma distinção `NO-GATES` × `MISSING` que `run-gates.sh` já pratica.

  Duas decisões que esta exigência força e que a spec assume: (a) ela **contraria por desenho** o contrato escrito de `lib/forge-runtime.sh:71-72` ("Ausência de node ⇒ a forma mapeada simplesmente não é lida … nunca trava o script") — a severidade passa a ser do chamador, e o hook é o chamador que bloqueia; (b) `run-gates.sh` e `spec-verify.sh` continuam silenciosos no mesmo estado, o que deixa duas severidades para o mesmo fato. Isso é aceitável **declarado**; o que não é aceitável é ficar implícito. O CHANGELOG diz qual caminho bloqueia e qual não.
- **O comentário de exemplo das linhas 253-256 é atualizado**, porque hoje ele documenta como contrato a forma que o hook implementa e que a spec vai substituir.

**Teste que prova — `tests/w190-pre-push-gate-reader-gate.sh`.** Prova pelo canal real: cada cenário monta um repositório de fixture com `git init`, instala os hooks do template via `core.hooksPath` absoluto, escreve um gate sintético que grava um arquivo-marcador quando executado, e faz um `git push` de verdade contra um remoto local `--bare`.

| # | Cenário | Vermelho esperado antes da correção |
|---|---|---|
| `[1]` | forma CSV escalar declarando um gate: o push executa o gate (marcador escrito) | verde já hoje — é o controle de retrocompatibilidade, e tem de continuar verde depois |
| `[2]` | forma mapeada, um item escalar (`- check-x`): o push executa o gate | **vermelho**: marcador ausente, push aceito, hook silencioso |
| `[3]` | forma mapeada, item com `name:` e `phase: source`: o push executa o gate | **vermelho**, mesma assinatura |
| `[4]` | forma mapeada com `phase: pre-deploy` apenas: o push **não** executa o gate e diz que não há gate de fase `source` | vermelho por motivo diferente — hoje o hook não diz nada em caso nenhum |
| `[5]` | gate declarado (em qualquer forma) cujo script não existe: push **BLOQUEADO** | verde na forma CSV, **vermelho** na mapeada (hoje o hook nem chega a olhar) |
| `[6]` | `node` indisponível no `PATH` com forma mapeada declarada: push **BLOQUEADO** nomeando que a declaração não pôde ser lida | **vermelho**: hoje passa em silêncio |
| `[7]` | mutação de canal (`rules/testing/gate-delivery-channel.md`): aponta `core.hooksPath` para um diretório sem o hook e verifica que `[2]` volta a falhar — prova que o cenário mede o canal, não o script | — |
| `[8]` | contador de controle: zero cenário executado reprova | — |

**Critério de pronto.** `w190` verde com os oito cenários; `tests/w146-suite-invocation-gate.sh` continua verde; `grep -n "fm_field gates" template/.forge/hooks/git/pre-push` devolve vazio; o CHANGELOG registra que a 0.11.0 embarcou o defeito e a versão desta leva o corrige, com a frase que um consumidor precisa ler para saber se foi afetado.

#### `LDG-0110` (P2) + peça executável de `#82` — `doctor` que denuncia o gate órfão

**Defeito.** Um `check-*.sh` presente em `.forge/scripts/`, não invocado por nenhum hook e não declarado em `runtime.gates` de fase alguma, é um gate que ninguém roda, e o `doctor` não o denuncia: o único check existente (`hp_orfaos`, `doctor.sh:357-365`) só roda no ramo `else` da cascata de `core.hooksPath` (linhas 317-376), isto é, **apenas quando o `hooksPath` é customizado e diferente do canônico** — no caso comum, o do `hooksPath` default instalado pelo harness, o bloco nunca executa.

**Mecanismo da correção.** Um check novo dentro de `check_harness()` (`doctor.sh:68-425`), informativo por construção — usa `info()`/`warn()` e **nunca** toca `MISSING_DIAG`, de modo que o exit code não muda. Ele cruza três fontes:

1. o universo `$ROOT/.forge/scripts/check-*.sh`;
2. as referências por nome-base em `$ROOT/.forge/hooks/git/**` (incluindo `hooks/git/lib/`, porque `check-red-first.sh` é invocado por wrapper) e no `hooksPath` resolvido, qualquer que seja ele;
3. `runtime.gates` de **todas** as fases, por `forge_runtime_gate_entries "$ROOT"` — sem filtro de fase, e pelo leitor único, nunca por um `awk` novo.

Herda também, por decisão já registrada no adendo de `LDG-0110`, o aviso de projeto com `runtime.gates` vazio em todas as fases — como informação e jamais como bloqueio, porque `LDG-0013` foi encerrado como `wont-fix` justamente por retrocompatibilidade.

Duas decisões de desenho que o implementador tem de tomar explicitamente, e a spec toma posição:

- **`doctor.sh` não dá source em `lib/forge-runtime.sh` hoje.** Passará a dar, sob a mesma disciplina de delegação em alvo ausente do resto do arquivo.
- **Isenção para o órfão legítimo.** Existem gates que legitimamente só rodam sob condição — `check-heavy-mutex.sh` só faz sentido com `heavy_mutex.enabled: true`. A spec recusa criar uma allowlist textual nova: `empty-universe-allowlist.txt` resolve outro problema (universo vazio de um gate que itera) e reusá-la confundiria dois contratos. Com 14 `check-*.sh` no template, a exceção cabe em condição no próprio check, justificada em código. Se o universo crescer além do que cabe em condição legível, a allowlist volta a ser a resposta — e aí é item próprio.

**Medição que o check reproduz.** Estado atual dos 14 `check-*.sh` do template:

| `check-*.sh` | invocado por hook | citado no CI do harness | tem gate próprio |
|---|---|---|---|
| `check-ai-attribution` | sim (`commit-msg`, `pre-push`) | não | sim |
| `check-liaison-acks` | sim (`pre-push`, sessão) | não | sim |
| `check-liaison-log-integrity` | sim (`post-merge`, `pre-push`) | não | sim |
| `check-push-ahead` | sim (`pre-push`) | não | sim |
| `check-red-first` | sim (indireto, via wrapper) | não | sim |
| `check-secrets` | sim (`pre-commit`) | sim | sim |
| `check-worktree-prereqs` | sim (`pre-push`) | não | sim |
| `check-authz` | **não** (só string de exemplo em `pre-push:253`) | não | sim |
| `check-data-governance` | **não** (idem) | não | sim |
| `check-observability` | **não** (idem) | não | sim |
| `check-heavy-mutex` | **não** | não | sim |
| `check-heredoc-hash` | **não** | não | sim |
| `check-shell-pipeline` | **não** | sim | sim |
| `check-suite-wiring` | **não** | sim | sim |

Sete dos catorze não têm ponto de entrada de produção que os invoque por padrão. Três deles (`check-authz`, `check-data-governance`, `check-observability`) só rodam se o consumidor declarar `runtime.gates` — e é exatamente o que o `doctor` passará a dizer.

**Teste que prova — `tests/w191-doctor-orphan-gate-gate.sh`.** A fixture segue o padrão já estabelecido em `tests/w153-upgrade-safety-gate.sh` cenário `[74]` (`lab74()`, linhas 113-123): `mktemp -d`, `git init`, `.forge/scripts` e `.forge/hooks/git` populados a partir do template, `core.hooksPath` configurado.

| # | Cenário | Vermelho esperado |
|---|---|---|
| `[1]` | `hooksPath` **default**, três `check-*.sh` sem hook e sem `runtime.gates`: o `doctor` nomeia os três | **vermelho**: hoje o bloco de órfãos não roda no ramo default |
| `[2]` | o mesmo, mas com os três declarados em `runtime.gates` (CSV): o `doctor` não os acusa | vermelho por ausência do check |
| `[3]` | o mesmo, declarados na forma **mapeada** com `phase: pre-deploy`: também não são acusados — declarado com fase é declarado | vermelho, e é o cenário que prova que o cruzamento usa o leitor único |
| `[4]` | `runtime.gates` vazio em todas as fases: o `doctor` **informa**, e o exit code continua `0` | vermelho |
| `[5]` | invariante de severidade: em nenhum dos cenários acima o exit code do `doctor` muda em relação à mesma fixture sem gate órfão nenhum | vermelho se alguém marcar `MISSING_DIAG` por engano |
| `[6]` | `hooksPath` customizado: o comportamento de `hp_orfaos` (`w153[74]`) continua idêntico — nenhuma duplicidade de aviso | — |
| `[7]` | contador de controle: universo de `check-*.sh` vazio reprova o cenário, não aprova | — |
| `[8]` | mutação: apagar a consulta a `runtime.gates` faz `[2]` e `[3]` reprovarem; restaurar volta a passar, com `cmp` verificado | — |

**Critério de pronto.** `w191` verde; `w153[74]` verde e inalterado; `bash template/.forge/scripts/doctor.sh` na raiz do próprio harness continua com o mesmo exit code de antes (o `.forge/FORGE.md` do dogfood **não tem bloco `runtime:`**, então cai no cenário `[4]` e tem de sair informativo); `#82` avança, mas não fecha, porque falta a peça documental de §5.6.

#### `LDG-0069` (P3, rebaixado por A3) — os dois lints não rodam localmente

**Defeito.** `check-shell-pipeline.sh` e `check-heredoc-hash.sh` rodam no CI contra o corpus real, mas nenhum hook local os invoca, de modo que a violação só aparece depois do push.

**Mecanismo da correção.** O `pre-push` passa a invocá-los quando o diff a ser empurrado toca arquivo `.sh`, sob a mesma disciplina dos demais: alvo ausente com diretório presente reprova. **Não** entra no `pre-commit`: o custo de varrer o corpus a cada commit não se justifica para uma classe que o CI já pega, e um hook lento é um hook desativado.

**Pré-condição inegociável.** Só depois de `LDG-0141` (§5.3) e da correção dos sítios que a extensão do reconhecedor acusa. Fiar antes entrega um hook que bloqueia o próprio harness no primeiro push.

**Teste que prova.** Cenários adicionais em `w190` — é o mesmo canal (`pre-push` exercitado por `git push` real) e o mesmo gate. `[9]`: push cujo diff toca um `.sh` com a forma proibida é **BLOQUEADO** (vermelho hoje: passa). `[10]`: push cujo diff não toca `.sh` nenhum não paga o custo do lint (verificado por ausência do marcador de execução, não por tempo). `[11]`: `check-heredoc-hash.sh` ausente com `.forge/scripts/` presente **BLOQUEIA** o push.

**Critério de pronto.** `w190` verde com os onze cenários; `w145[8]` e `w159[8]` verdes; um push real no próprio repositório não fica mais lento de forma perceptível quando o diff não toca `.sh`.

### 5.2 — G2: interruptor publicado que nenhum código lê

#### `LDG-0008`, primeira fatia (P2) — os três interruptores de `quality`

**Defeito.** `template/.forge/forge.yaml` e `schemas/forge.schema.json` publicam `quality.require_tests_before_archive`, `quality.require_traceability_before_archive` e `quality.require_human_approval_before_archive`, e nenhum código no repositório lê qualquer um dos três — de modo que todo adotante instala um harness que afirma exigir testes antes do archive e não exige.

**Mecanismo da correção.** Decisão por chave, não uma decisão só. A spec toma posição e o implementador executa:

| chave | decisão | razão |
|---|---|---|
| `require_human_approval_before_archive` | **remover** de `forge.yaml` e do schema | A capacidade existe e é real sob outro nome (`gates.human_archive_approval` no manifesto do change, cobrado por `lib/validate-archive.mjs`). Fiar criaria duas chaves para o mesmo fato. A remoção vem acompanhada de um comentário no `forge.yaml` apontando onde a aprovação de fato mora. |
| `require_tests_before_archive` | **tornar real** no pré-flight de `archive-spec.sh` | É a chave que o item chama de a que "fere consumidor hoje". O ponto de ancoragem é o pré-flight §13.1 do archive, que é onde o harness já recusa incorporar um change incompleto. Default `true` no template preserva a promessa; um projeto que precise de escape declara `false` explicitamente, e essa declaração fica visível no `forge.yaml`. |
| `require_traceability_before_archive` | **tornar real** no mesmo ponto | Mesma família, mesmo ponto de ancoragem, e separá-las produziria duas passagens sobre o mesmo pré-flight. |

O que "tornar real" significa precisa ser decidido com medição, e a spec exige que a medição preceda a implementação: qual sinal já existente no change prova que há teste (`evidence/`, o contrato de teste de `rules/testing/change-test-contract.md`, o `verification.yaml`) e qual prova rastreabilidade (REQ referenciado por TASK). **Não** inventar artefato novo para satisfazer a chave — se nenhum sinal existente serve, a chave vira `LDG` própria e a decisão desta fatia passa a ser remoção também, o que é honesto e barato.

**Teste que prova — `tests/w192-declared-switch-has-reader-gate.sh`.** O gate é a propriedade, não o caso: **toda chave declarada como load-bearing tem leitor**.

| # | Cenário | Vermelho esperado |
|---|---|---|
| `[1]` | propriedade: para cada chave da lista de interruptores load-bearing, existe ao menos um arquivo em `scripts/`, `hooks/` ou `bin/` que a menciona | **vermelho** hoje para as três `require_*` |
| `[2]` | contrapositiva: uma chave sintética inventada na lista, sem leitor, reprova o gate — a lista não é decoração |  — |
| `[3]` | `require_human_approval_before_archive` **não** aparece em `forge.yaml` nem no schema (foi removida) | vermelho |
| `[4]` | change sem sinal de teste com `require_tests_before_archive: true` reprova no pré-flight do archive, nomeando a chave | vermelho |
| `[5]` | o mesmo change com a chave em `false` passa, e o `archive` **diz** que passou por dispensa declarada | vermelho |
| `[6]` | contador de controle: lista de interruptores vazia reprova o gate | — |
| `[7]` | mutação: remover a consulta à chave no pré-flight faz `[4]` reprovar; restaurar volta a passar, com `cmp` | — |

O cenário `[5]` é o que impede a correção de virar a sua própria doença: uma chave que só bloqueia e nunca reporta a dispensa é indistinguível de uma chave que não existe, do ponto de vista de quem audita depois.

**Critério de pronto.** `w192` verde; `bash tests/w30-schemas-gate.sh` e `tests/w32-archive-gate.sh` verdes; o `detail` de `LDG-0008` atualizado com a decisão tomada por chave, e o item permanece `open` com as fatias (a) TDD-em-feature e (b) cobertura de propriedades intocadas — a primeira fatia fecha, o item não.

#### `LDG-0003` (P3) — a chave de ativação de rule-pack de domínio

**Defeito.** `pack: <nome>` e `opt_in: true` no frontmatter de rule não são lidos por ninguém — nem por `lib/validate-rules.mjs`, nem por `lib/sync-adapters.mjs`, nem por schema algum —, e as duas rules de prioridade Alta que os declaram (`architecture/authz-pdp-pep.md`, `architecture/pii-pci-classification.md`) ficam sem porta de entrada.

**Mecanismo da correção.** Uma chave `rules.packs` no `forge.yaml`, por simetria explícita com `capabilities.active` que já existe e funciona. Três peças: o campo no `$defs/forgeManifest` do schema; a leitura em `validate-rules.mjs`, que passa a validar que todo `pack:` declarado no frontmatter é conhecido e que todo pack ativado tem ao menos uma rule; e o comportamento default para rule de pack inativo, que a spec fixa como **exatamente o que a documentação já promete** — referência disponível, nunca gate imposto. O trabalho é tornar mecânica uma afirmação que hoje é só prosa, e `rules/README.md:17` mais `capabilities/README.md:11` perdem a ressalva que apontam para este item.

Registrado como recusa consciente, herdada do próprio `detail` do item e confirmada aqui: **não** materializar apenas os capability packs ativos no installer. `bin/forge.mjs:307` inclui `capabilities` em `MACHINERY_DIRS`, e `suggest_pack` do `doctor` só sugere um pack cujo `PROFILE.md` existe em disco; materializar só os ativos silenciaria a sugestão de todo pack ainda não adotado, quebrando o caminho de descoberta que faz alguém adotar um.

**Teste que prova — cenários novos em `tests/w192`**, porque a propriedade é a mesma de `LDG-0008` (chave declarada tem leitor) aplicada a outro eixo. `[8]`: `rules.packs` declarado com um pack ativa a rule correspondente como contrato, e o validador o afirma (vermelho hoje: nada lê a chave). `[9]`: rule com `pack:` de pack **não** ativado continua válida e permanece disponível como referência — não reprova nada (vermelho: hoje é indistinguível, porque nada lê). `[10]`: `pack:` no frontmatter referenciando pack desconhecido reprova o `validate-rules` nomeando a rule. `[11]`: mutação — apagar a leitura de `rules.packs` faz `[8]` reprovar.

**Critério de pronto.** `w192` verde com os onze cenários; `validate-rules.sh` e `doctor --report` verdes no próprio harness; as duas ocorrências de "a chave de ativação de rule-packs ainda não existe" em `rules/README.md` e `capabilities/README.md` substituídas pelo que passa a ser verdade.

### 5.3 — G3: estado derivado da própria árvore numa operação de visão global

#### `LDG-0141` (P3) — o reconhecedor do lint não pega `$(ls … | sort)` sob `pipefail`

**Defeito.** `lib/shell-pipeline-lint.mjs` só reconhece `<produtor> | grep -q … ||/&&`, e não reconhece a atribuição por substituição de comando cujo pipeline tem produtor que pode falhar sob `pipefail` — a forma que matou o `w20-spec-gate` sem saída no CI três execuções seguidas.

**Mecanismo da correção, e é aqui que a medição muda o desenho.** A extensão ingênua descrita no item ("atribuição via `$( )` cujo pipeline tem produtor que pode falhar") é grande demais. Protótipo descartável rodado nesta sessão sobre `template/`, `tests/` e `bin/` (198 arquivos `.sh`, dos quais 139 declaram `set -e` **e** `pipefail`):

| predicado | ocorrências em arquivo com `set -e` + `pipefail` |
|---|---|
| qualquer atribuição via `$( )` contendo pipeline, produtor falível, sem escape | **46** |
| o mesmo, restrito a produtor com `2>/dev/null` | 6 |
| o mesmo, restrito a produtor da família falível (`ls`, `find`, `grep`, `git`, `rg`, `jq`, `comm`, `diff`) | 27 |
| **interseção dos dois** | **6** — 5 quando o reconhecedor trata qualquer `||` da linha como escape |

Extensão ingênua torna o cenário `[8]` de `w145` (o que varre o corpus real e exige `rc = 0`) vermelho em 46 linhas do próprio harness. O predicado correto é a interseção, e ele não é arbitrário: o `2>/dev/null` é a assinatura do defeito, porque é o autor declarando que espera falha ali e, no mesmo gesto, escondendo a única pista que restaria quando `pipefail` mais `set -e` transformarem essa falha em morte silenciosa. Foi exatamente a forma do `w20`.

Os seis sítios que o predicado acusa, todos no próprio harness (censo corrigido na revisão adversarial, §9 — a lista original trazia `w113:207`, que **não é da classe**, e omitia `impact.sh:21`, que **é**):

```
template/.forge/scripts/impact.sh:20        git … 2>/dev/null | paste
template/.forge/scripts/impact.sh:21        [ -n "$files" ] || files="$(git … 2>/dev/null | sed | paste)"
template/.forge/scripts/liaison-ops.sh:938  find … 2>/dev/null | wc -l | tr
template/.forge/scripts/ingest-legacy.sh:18 find … 2>/dev/null | head -1
tests/w50-story-shard-gate.sh:208           grep -rl … 2>/dev/null | wc -l | tr
tests/w90-run-manifest-gate.sh:66           find … 2>/dev/null | head -1
```

`tests/w113-liaison-enforce-gate.sh:207` **sai do censo**: `git … 2>/dev/null || git …` não tem pipeline nenhum — o `||` é OR lógico, não pipe —, então nenhum reconhecedor que exija pipeline chega a olhá-lo, e o requisito de reconhecedor que a versão anterior desta spec derivava dele não tem de onde ser derivado.

O requisito de escape, então, não é "qualquer `||` seguido de comando". Tem de ser **um `||` que governe a própria substituição**, e não um `||` qualquer na linha: `impact.sh:21` é exatamente a contrapositiva. Ali o `||` é a guarda do teste anterior (`[ -n "$files" ] || files="$( … )"`), a atribuição é o **último** comando da lista OR, e sob `set -euo pipefail` a falha do produtor mata o script. Medido nesta base:

```
$ cat probe.sh
set -euo pipefail
files=""
[ -n "$files" ] || files="$(false 2>/dev/null | sed 's/^...//' | paste -sd, -)"
echo "SOBREVIVEU"
$ bash probe.sh; echo "rc=$?"
rc=1                      # "SOBREVIVEU" nunca é impresso
```

Um reconhecedor que aceite qualquer `||` como escape deixa `impact.sh:21` passar — e, pior, o conserto de `impact.sh:20` **transfere** a morte silenciosa para a linha 21, porque hoje a 20 morre antes. São **seis** sítios a corrigir, no mesmo change, e `impact.sh` recebe dois.

Dois recortes de contexto que o predicado precisa fazer, e que o implementador descobriria da pior maneira. Primeiro, **só vale em arquivo que declara `set -e` junto com `pipefail`** — 139 dos 198 `.sh` do harness declaram os dois, 40 declaram `pipefail` sem `-e` (19 não declaram nenhum dos dois), e nesses últimos a classe simplesmente não morde; ignorar essa condição adiciona 53 falsos positivos de uma vez, entre eles o próprio `check-shell-pipeline.sh` (linhas 71 e 78). Segundo, **substituição de processo não é substituição de comando**: `while … done < <(ls … | sort)` não mata o pai sob `set -e`, e há 14 ocorrências de `< <(` no repositório, 6 delas em arquivo que declara `set -e` junto com `pipefail` — incluindo `tests/run-all.sh:48`, o arquivo que executa a suíte inteira. Marcar essa forma faria o lint reprovar o próprio runner.

**Teste que prova — cenários novos em `tests/w145-shell-pipeline-lint-gate.sh`**, que é o gate do próprio lint e já tem a disciplina de montar fixture por concatenação para não se autodetectar. `[9]`: fixture com `X="$(ls -1 "$D" 2>/dev/null | sort)"` num arquivo que declara `set -euo pipefail` reprova (**vermelho**: hoje passa). `[10]`: o mesmo com `|| true` no fim passa. `[11]`: o mesmo com `|| git rev-parse HEAD` **no fim da substituição** (escape que governa o próprio `$( )`) passa. `[11b]`: `[ -n "$x" ] || X="$(ls -1 "$D" 2>/dev/null | sort)"` — `||` na linha, mas governando o teste anterior e não a substituição — **reprova** (é `impact.sh:21`; **vermelho**, e é o cenário que impede o escape de virar "qualquer `||`"). `[12]`: o mesmo idioma num arquivo **sem** `set -e` passa, porque ali a classe não morde. `[13]`: `shasum … | cut` e `grep … | wc -l` sem `2>/dev/null` passam — a contrapositiva que impede o predicado de virar os 46. `[14]`: o corpus real (`template/` + `tests/` + `bin/`) passa depois dos **seis** sítios corrigidos, com contador de controle. Este cenário só é prova se `[11b]` estiver verde — sem ele, `[14]` fica verde por o reconhecedor ser cego a `impact.sh:21`, não por o corpus estar limpo. `[15]`: mutação — remover a condição de `2>/dev/null` do reconhecedor faz `[13]` reprovar, provando que a restrição é a regra e não acaso.

**Critério de pronto.** `w145` verde com os dezesseis cenários (`[9]`–`[15]` mais `[11b]`); os seis sítios corrigidos; `w159` verde; e — a prova que fecha o círculo — `w20-spec-gate.sh` continua verde num clone limpo sem `specs/active/`.

#### `LDG-0067` (P3) — ordinal de gate colide entre branches paralelas

**Defeito.** Quem escolhe o próximo ordinal `wNNN` olha `ls tests/*-gate.sh` da própria árvore, de modo que duas branches paralelas escolhem o mesmo número e um dos dois arquivos perde a identidade no merge — o que aconteceu duas vezes na rodada de 2026-09-04.

**Mecanismo da correção, e a spec recusa a saída que o item sugere.** O item conclui que "a saida provavelmente e a mesma decisao" do id de ledger. Por A8, não é: o ledger tem um arquivo único no tronco e serializa por construção; ordinais são N arquivos por branch, sem autoridade compartilhada. Duas peças, ambas necessárias e nenhuma delas replicando o mecanismo do ledger:

- **Derivar do tronco remoto, não da árvore local.** Um helper determinista que calcula o próximo ordinal a partir de `git ls-tree origin/develop tests/` — o que já contempla o que outra branch mergeou — e degrada com elegância quando não há remoto, dizendo que degradou.
- **Detectar a colisão quando ela ainda assim ocorrer.** Dois arquivos com o mesmo ordinal em `tests/` reprovam. É barato, é determinista, e é a única peça que funciona sem rede.

Ambas registram a limitação por escrito: nada disto **impede** duas branches que nunca se viram de escolher o mesmo número; o que se ganha é que a colisão para de ser descoberta no merge, e o autor da segunda branch descobre no próprio push.

**Teste que prova e critério de pronto:** compartilhados com `LDG-0068` em `tests/w193`, logo abaixo — cenários `[1]` a `[5]`. O compartilhamento é consequência do agrupamento, não economia: a fixture de "duas árvores que discordam" é a mesma nos dois itens, e montá-la duas vezes produziria duas definições do que conta como discordância.

#### `LDG-0068` (P3) — `ledger-ops` escreve no tronco em silêncio

**Defeito.** `ledger-ops.sh` resolve `ROOT` por `--git-common-dir`, de modo que uma resolução feita de dentro de uma worktree grava no ledger do tronco, que pode estar noutra branch — e nada avisa, nem obriga.

**Mecanismo da correção.** Apenas visibilidade. O comportamento **não** muda: `rules/conventions/machinery-propagation.md` o declara norma explícita ("estado de projeto mora no tronco, não na branch"), e alterá-lo faria toda branch que toca o ledger colidir no merge por construção. A correção é a saída mínima que o próprio item propõe — quando o `ROOT` resolvido difere do repositório de trabalho do invocador, dizer isso na saída, com o caminho absoluto, em toda porta que **escreve** (`add`, `update`, `resolve`, `promote`, `harvest`) e não nas que só leem.

Um detalhe que o implementador precisa saber e que o item não registra: `_forge_main_root()` está **copiado em quatro scripts** — `ledger-ops.sh:52`, `liaison-ops.sh:80`, `check-liaison-acks.sh:50` e `check-liaison-log-integrity.sh:37` —, corpo idêntico. O aviso vai para um lugar só, em `lib/`, consumido pelos quatro; escrevê-lo quatro vezes é reinstalar `LDG-0014` no mesmo change que existe para combater essa classe.

**Teste que prova — `tests/w193-tree-derived-state-gate.sh`.** Um gate para os dois itens de G3 que restam, porque a causa é a mesma e a fixture também: duas árvores que discordam.

| # | Cenário | Vermelho esperado |
|---|---|---|
| `[1]` | dois arquivos `tests/w200-a-gate.sh` e `tests/w200-b-gate.sh` na mesma árvore: o detector de colisão reprova nomeando o ordinal | **vermelho**: não existe detector |
| `[2]` | árvore sem colisão passa, com contador de controle de quantos ordinais examinou | vermelho |
| `[3]` | o próprio `tests/` do harness passa (93 arquivos `w*.sh`, ordinal máximo 186, nenhuma colisão hoje) | vermelho |
| `[4]` | o helper de próximo ordinal, com um remoto que já tem `w200`, devolve `w201` mesmo que a árvore local não tenha `w200` | **vermelho** |
| `[5]` | sem remoto acessível, o helper devolve um número **e diz** que o derivou só da árvore local | vermelho |
| `[6]` | `ledger-ops add` invocado de dentro de uma worktree, sem `FORGE_ROOT`, escreve no tronco **e o anuncia** com o caminho absoluto | **vermelho**: hoje é silencioso |
| `[7]` | `ledger-ops add` com `FORGE_ROOT` apontando para a worktree não emite o aviso — o aviso é sobre divergência, não sobre worktree | vermelho |
| `[8]` | `ledger-ops list` (porta de leitura) não emite aviso nenhum | — |
| `[9]` | propriedade: para as cinco portas de escrita, `ROOT ≠ repositório do invocador` implica aviso na saída; `ROOT = repositório do invocador` implica ausência de aviso | vermelho |
| `[10]` | mutação: remover o aviso do lib faz `[6]` e `[9]` reprovarem nas cinco portas de uma vez — prova que há um sítio, não quatro | — |

**Critério de pronto.** `w193` verde; `w157-ledger-integrity-gate.sh` verde; `grep -c "_forge_main_root()" template/.forge/scripts/**/*.sh` cai de 4 para 1 **ou** — se a consolidação for julgada fora do escopo — o aviso vive num único lib consumido pelos quatro, e o cenário `[10]` prova isso.

### 5.4 — G4: monotonicidade violada no liaison

#### `#101` — `_dir_push` sobrescreve o log do hub

**Defeito.** `template/.forge/scripts/lib/transports/_common.sh::_dir_push` publica o log próprio no hub com `cp` mais `mv` incondicional, sem união, de modo que uma réplica atrasada substitui o log do hub pelo seu, com `rc 0` e sem aviso, apagando mensagens que só existiam lá — num log append-only, de onde não há como restaurar.

**Mecanismo da correção.** O push passa a ser **fast-forward ou recusa**, que é a formulação exata do comportamento que a issue chama de certo. Antes de escrever, lê `$hub/log/$LIAISON_SELF.jsonl`, compara com o log local por `(msg_id, content_sha)` preservando a ordem append-only, e:

- se o log do hub é prefixo (ou subconjunto) do local, escreve o local — é avanço, e é o caso normal;
- se o hub tem linha que o local não tem, **não toca o hub** e devolve `1`, nomeando quantas linhas divergem e onde. Não é o push que resolve isso: `liaison-import.mjs` já é o caminho que trata log append-only como história que não se reescreve, e o push não pode ser mais frouxo que ele.

Peça de propagação, que é metade da issue e a mais fácil de esquecer: `scripts/` **não** está em `ENRICHABLE_DIRS` (`bin/forge.mjs:352` — `['agents','rules','skills','templates']`), então é sobrescrita a cada `forge update`. Isso é o desenho correto para maquinaria e a spec não o altera; a consequência a registrar é que os três consumidores que consertaram o defeito por conta própria (três implementações diferentes, medidas na issue) terão o conserto substituído pela versão do template — que, depois desta entrega, é a versão correta. O CHANGELOG tem de dizer isso com todas as letras, porque um consumidor que veja `_common.sh` mudar precisa saber que a mudança é convergência, não regressão.

A segunda proposta da issue — gate de paridade de transporte entre árvores — não entra, pelo motivo da tabela de §4. O que entra no lugar é a peça que cabe no alcance do harness: o `doctor` do consumidor informa quando o `_common.sh` local diverge do que o template entrega, que é a informação que o censo da issue produziu à mão.

**Teste que prova e critério de pronto:** compartilhados com `#102` em `tests/w195`, logo abaixo — cenários `[1]` a `[4]` e `[11]`. A fixture de hub mais duas réplicas é a mesma para os dois itens, e é o que torna o par um grupo.

#### `#102` — `ack` não avança o cursor da thread

**Defeito.** `ack)` (`liaison-ops.sh:623-721`) lê `cursors[id]` para exibir e não escreve cursor nenhum, de modo que o ato mais forte de leitura que o protocolo tem não marca a thread como lida — e 148 mensagens ficam simultaneamente ackadas e não lidas nas quatro árvores medidas.

**Mecanismo da correção.** `ack)` passa a avançar o cursor da thread até a mensagem ackada, com a mesma regra de não-regressão de `read)` (linhas 813-817: cursor não pode voltar). Por A4, **não** há três sítios de onde copiar o one-liner: há um, e a correção extrai a lógica dele para um helper compartilhado em `lib/`, consumido pelos dois. Duplicá-la é criar a segunda implementação de "avançar cursor sem regredir" no mesmo arquivo em que se está corrigindo um defeito de leitura.

O texto da issue sobre a distinção entre "participação" e "leitura de terceiro" descreve o `axis-go-cloud`, não o template, e o CHANGELOG desta entrega deve dizer isso — porque um consumidor que rode a versão com quatro sítios vai receber esta correção sobre uma base diferente da que ela pressupõe.

**Teste que prova — `tests/w195-liaison-monotonicity-gate.sh`.** Uma fixture serve aos dois itens: um hub de diretório e duas réplicas, `A` e `B`, com identidades distintas.

| # | Cenário | Vermelho esperado |
|---|---|---|
| `[1]` | `A` publica, `B` publica, `A` publica de novo: o hub contém as mensagens das duas | verde hoje (identidades distintas escrevem arquivos distintos) — é o controle |
| `[2]` | duas árvores com a **mesma** identidade `A`, uma atrasada: o push da atrasada é **recusado** com `rc ≠ 0` e o hub fica byte a byte idêntico | **vermelho**: hoje sobrescreve com `rc 0` |
| `[3]` | a mesma árvore atrasada, depois de um `sync` que a põe em dia: o push é aceito e o hub avança | vermelho |
| `[4]` | propriedade (fast-forward): para pares de logs gerados, o push tem êxito **se e somente se** o log do hub é subconjunto do local; em êxito o hub passa a ser o local; em recusa o hub é idêntico ao anterior | **vermelho** |
| `[5]` | `ack` de uma mensagem de terceiro avança o cursor da thread até ela | **vermelho**: `ack)` não escreve cursor |
| `[6]` | `ack` de mensagem **anterior** ao cursor atual não faz o cursor regredir, e a operação não falha | vermelho |
| `[7]` | depois de `[5]`, `liaison-ops.sh list` conta zero não-lidas naquela thread | vermelho — é a prova do efeito que a issue mede |
| `[8]` | propriedade (monotonicidade do cursor): para qualquer sequência de `ack` e `read --upto`, o índice do cursor é não-decrescente | vermelho |
| `[9]` | `ack` da própria mensagem não avança cursor de leitura de terceiro — a invariante que separa participação de leitura | vermelho por ausência da distinção |
| `[10]` | contador de controle: fixture com zero mensagem reprova o cenário | — |
| `[11]` | mutação: remover a guarda de não-regressão faz `[6]` e `[8]` reprovarem; remover a união faz `[2]` reprovar; restaurar volta a passar, com `cmp` do lib | — |

**Critério de pronto.** `w195` verde; `w110-liaison-core-gate.sh`, `w113`, `w150`, `w168` e `w169` verdes; o `check-liaison-log-integrity.sh` continua verde contra o hub real do ecossistema; CHANGELOG com o parágrafo de convergência para os três consumidores que haviam corrigido `_dir_push` por conta própria.

### 5.5 — G5: o instrumento de registro aceita o vazio

#### `#103` — `ledger-ops update` devolve `OK` sem gravar

**Defeito.** `update <id> --detail ""` imprime `OK update — <id> atualizado`, grava o arquivo, avança `updated_at` e não altera o campo, porque `if (de) e.detail = de;` (`ledger-ops.sh:184`) trata string vazia como falsa — e o commit acaba anunciando um conteúdo que o ledger não carrega.

**Mecanismo da correção — três partes, não duas.** A terceira vem de A5 e é a que provavelmente já produziu dano:

1. **Recusar valor vazio.** Flag de campo passada com string vazia é erro de uso: sai com código diferente de zero, nomeando qual flag veio vazia. Vale para `--title`, `--detail`, `--status`, `--priority` e `--severity`.
2. **Recusar `update` que não muda nada.** Se nenhum campo foi efetivamente alterado, não imprimir `OK`. Hoje o único efeito garantido de um `update` é mexer no `updated_at`, o que faz a entrada parecer recente sem carregar informação nova.
3. **Recusar flag desconhecida, nos seis subcomandos.** `add` (112), `update` (163), `resolve` (201), `promote` (233), `harvest` (261) e `list` (376) terminam o `case` em `*) shift ;;`, que engole a flag e, na iteração seguinte, o valor dela. Um `--details` por typo desaparece inteiro e a entrada nasce vazia com `OK` na saída. O idioma a replicar é o `_reject_unknown` que `liaison-ops.sh` já tem (linha 111) — o precedente que a issue julga existir em `ledger-ops.sh` e que não existe.

Peça adicional, não bloqueante e proporcional: `add` sem `--detail` **avisa** (não reprova) que a entrada nasce sem conteúdo, nomeando o id criado. Reprovar quebraria retrocompatibilidade para todo consumidor com script que chame `add`; avisar é o remédio que o próprio `detail` de `LDG-0008` justifica — "título sem conteúdo, que é a forma de item que envelhece pior".

**Teste que prova e critério de pronto:** compartilhados com `LDG-0140` em `tests/w194`, logo abaixo — cenários `[1]` a `[8]` e `[13]` cobrem este item; `[9]` a `[12]` cobrem o `harvest`. É o mesmo arquivo, a mesma disciplina de parsing e o mesmo veredito; separar os gates faria duas definições de "escrita honesta no ledger".

#### `LDG-0140` (P3) — o `harvest` captura narrativa histórica como follow-up novo

**Defeito.** A etapa (3) do `harvest` (`ledger-ops.sh:312-322`) casa **qualquer** bullet sob um heading que combine `/desvios|ressalvas|observa/i`, sem distinguir uma ressalva aberta de uma linha que apenas narra algo já concluído — e produziu quatro entradas (`LDG-0111` a `LDG-0114`) 100% duplicadas de itens já resolvidos, todas a serem desfeitas à mão pelo operador do `close`, que é o oposto do "não-bloqueante" que o `harvest` promete.

**Mecanismo da correção.** Exigir marcador explícito em vez de casar a seção inteira: só bullet prefixado por `PENDENTE:` (ou sob um heading dedicado `Follow-ups abertos`) vira candidato. É a mesma classe de `LDG-0062` — heurística de texto sem entender semântica — e a saída é a mesma que aquele item tomou: pedir que o autor marque, em vez de adivinhar. Complemento barato e independente: bullet que cita um `LDG-00NN` entre crases é descartado por dedupe, porque a maioria dos quatro casos reais o fazia.

Nota de escopo que o implementador precisa ver: `harvest` cria entradas com `detail: ''` e `priority: null` (linhas 333-334). Isso é a mesma porta de entrada de item sem conteúdo do item anterior, por um terceiro caminho. Corrigir a heurística reduz o volume; não fecha a porta. Fechá-la é decisão de produto que esta leva **não** toma — fica registrada em `LDG-0140` como a segunda metade.

**Teste que prova — `tests/w194-ledger-write-discipline-gate.sh`.**

| # | Cenário | Vermelho esperado |
|---|---|---|
| `[1]` | `update <id> --detail ""` sai com `rc ≠ 0`, nomeia a flag, e o `ledger.json` fica byte a byte idêntico | **vermelho**: hoje `rc 0`, `OK`, e `updated_at` avança |
| `[2]` | `update <id> --title ""` idem | vermelho |
| `[3]` | `update <id>` sem flag alguma sai com `rc ≠ 0` e não imprime `OK` | vermelho |
| `[4]` | `update <id> --detail "texto"` grava e imprime `OK` — o caminho feliz não regride | verde hoje, controle |
| `[5]` | propriedade (`OK` implica gravação): para toda combinação de flags, `rc = 0` implica que ao menos um campo mudou entre o `ledger.json` de antes e o de depois | **vermelho** |
| `[6]` | flag desconhecida em `add` sai com `rc ≠ 0` nomeando a flag, sem criar entrada | **vermelho**: hoje engole |
| `[7]` | o mesmo para os outros cinco subcomandos, parametrizado | vermelho |
| `[8]` | `add` sem `--detail` cria a entrada, imprime o id **e avisa** que ela nasce sem conteúdo | vermelho |
| `[9]` | `harvest` sobre um `verification.md` com bullet narrativo sob "Desvios e observações", sem marcador: zero entradas | **vermelho**: hoje cria uma por bullet |
| `[10]` | o mesmo `verification.md` com um bullet `PENDENTE:`: exatamente uma entrada | vermelho |
| `[11]` | bullet citando `` `LDG-0030` `` é descartado mesmo com marcador | vermelho |
| `[12]` | contador de controle: `harvest` sobre change inexistente declara zero e não falha o chamador (o `close` depende disso) | verde hoje, recontrole |
| `[12b]` | contador de controle **do próprio gate**: a lista de subcomandos que `[7]` parametriza é contada e declarada na saída; lista vazia **reprova** o gate. Sem isto, `[7]` com a lista vazia aprova em silêncio — é a vacuidade que `lib/gate-universe.sh` existe para recusar | — |
| `[13]` | mutação: restaurar `if (de) e.detail = de;` faz `[1]` e `[5]` reprovarem; restaurar o `*) shift ;;` faz `[6]` e `[7]` reprovarem | — |

**Critério de pronto.** `w194` verde; `w157-ledger-integrity-gate.sh` verde; o `detail` de `LDG-0100`, `LDG-0101` e `LDG-0102` escrito **por este `update` já corrigido**, o que é a prova de campo da correção; `LDG-0140` atualizado com a segunda metade explicitada.

### 5.6 — G6: texto normativo que o código contradiz

Os três itens deste grupo compartilham o padrão de correção: **corrigir o texto e fiar o check que impede a próxima deriva**. Corrigir só o texto entrega o mesmo item de novo em três meses, e é o que o histórico deste repositório mostra ter acontecido com `LDG-0102`.

#### `LDG-0101` — schema × `validateEnvelope`

Por A9, são duas divergências. A correção: (a) a descrição de `body` em `schemas/liaison-message.schema.json` passa a dizer o que o validador faz — ambos opcionais, no máximo um presente —, e (b) o schema passa a **codificar** a exclusão mútua, com `not: { required: ["body", "body_ref"] }`, que é a forma que `ajv` cobra e que hoje falta.

#### `LDG-0102` — a tabela de topo do contrato do adapter

`contracts/claude-adapter-contract.md` tem `| **Versão** | 1.2 |` e `| **Data** | 2026-06-10 |` na tabela de topo, enquanto o "Controle de versão do documento" no rodapé chega a **1.5**, datada de 2026-09-04 — quatro entradas de changelog depois. Corrigir os dois campos é trivial; o que impede a repetição é o check.

#### `#82`, peça documental — a fase não existe para quem consome o harness

Medido: `phase`, `pre-deploy` e `post-deploy` não aparecem em rule nenhuma, comando nenhum, nem em `template/.forge/templates/FORGE.md` — onde `gates:` segue como chave vazia sem exemplo, na linha 24. As únicas ocorrências no repositório são comentários de código em `run-gates.sh`, `gate-phase.mjs` e `spec-verify.sh`, mais o CHANGELOG e o plano de 2026-09-04. `commands/waves/wave.md:50` ainda descreve `runtime.gates` como lista plana. Quatro peças: o exemplo comentado no `FORGE.md` do template mostrando as duas formas; a correção de `commands/waves/wave.md`; uma rule ou seção de rule que diga o que a fase `source` **não** cobre — que é o pedido literal da issue, e que tem o mesmo espírito de `testing/regression-red-first.md` ao dizer que suíte verde não é evidência; e o registro de que gate de fase `pre-deploy`/`post-deploy` pode ser **inconclusivo** por falta de credencial, estado que não pode virar verde nem bloquear quem não tem credencial na máquina.

**Teste que prova — `tests/w197-normative-text-parity-gate.sh`.**

| # | Cenário | Vermelho esperado |
|---|---|---|
| `[1]` | a `Versão` da tabela de topo de `contracts/claude-adapter-contract.md` casa a última entrada do changelog do próprio documento | **vermelho**: 1.2 contra 1.5 |
| `[2]` | a `Data` idem — comparada com a data da **última entrada de versão** (`Versão N.M`), não com a última linha da seção | **vermelho** (1.5 é de 2026-09-04) — mas **verde** se implementado como "última linha do changelog": a última linha de `contracts/claude-adapter-contract.md` é a decisão de gate W0.3, datada `2026-06-10`, idêntica à tabela de topo. O `[9]` de mutação tem de cobrir esta leitura errada. |
| `[3]` | propriedade, para todo `.md` em `contracts/` que tenha tabela de topo com `Versão` e seção de changelog: as duas casam | vermelho |
| `[4]` | envelope com `body` **e** `body_ref` reprova no schema por `ajv`, como já reprova em `validateEnvelope` | **vermelho**: hoje passa no schema |
| `[5]` | envelope sem `body` e sem `body_ref` passa nos dois — e a descrição do schema diz isso | vermelho na descrição |
| `[6]` | `phase`, `pre-deploy` e `post-deploy` aparecem em ao menos um arquivo de `template/.forge/rules/` **e** em `template/.forge/templates/FORGE.md` | **vermelho**: zero ocorrências em ambos |
| `[7]` | `commands/waves/wave.md` não descreve `runtime.gates` como lista plana | vermelho |
| `[8]` | contador de controle: zero documento examinado reprova | — |
| `[9]` | mutação: alterar a `Versão` do contrato para um valor arbitrário faz `[1]` reprovar | — |

**Critério de pronto.** `w197` verde; `tests/w30-schemas-gate.sh` verde com o schema alterado; `npm run build:plugin` executado, porque `commands/waves/wave.md` mudou, e `tests/plugin-sync-gate.sh` verde nos cinco cenários; a issue `#82` fecha, com as duas peças entregues.

### 5.7 — G7: cegueira do route-scan

#### `LDG-0029` (P2) — índice de constante literal com abstenção por chave não-única

**Defeito.** O `route-scan` deixa 75 sítios irresolúveis no repositório de referência, e como `NAO_SUPRIME` está vazio em `lib/api-surface.mjs:476`, qualquer irresolúvel derruba o SUR-01 inteiro para `inconclusive` (linha 479) — o que mantém o oráculo mudo e bloqueia `LDG-0010`.

**O número, e sua procedência.** 370 rotas resolvidas e 75 irresolúveis no `axis-go-cloud`, particionados em `group-path-not-literal` 32, `route-path-not-literal` 22, `producer-never-invoked` 11, `mapgroup-unindexed` 5 e `route-site-unindexed` 5. **Esta medição é de 2026-09-05 e foi feita pelo dono do repositório, não por esta sessão** — a varredura completa custa cerca de 185 segundos contra um repositório externo, e a spec não a reproduziu. O implementador deve remedi-la antes de começar e depois de terminar; o número de antes é a linha de base, e sem ele o de depois não significa nada.

**Mecanismo da correção.** Um índice de literais de `const string` em C#, chaveado `Classe.Membro`, mais interpolação simples da forma `$"{X.Y}/sufixo"`. A projeção do protótipo do dono do repositório é 51 dos 75 sítios, 68%, com colisão medida em zero das 34 referências efetivamente usadas pelos irresolúveis (e 2,8% no índice inteiro — 95 chaves em 3.432). O desenho seguro é o idioma que o `route-scan` já pratica: resolver só quando a chave é única e **abster-se**, mantendo `unresolved`, quando não é — nunca emitir path parcial.

Onde a peça encaixa, medido na estrutura do arquivo: `scanRoutes` (`lib/route-scan.mjs:1217`) já é de duas fases — lê arquivo a arquivo num laço (linha 1222) povoando o acumulador `idx`, e só depois chama `compose(idx)` (linha 1253), que faz toda a resolução cross-arquivo sem reler disco. O índice de constantes é populado dentro do laço, enquanto `text`/`struct` de cada `.cs` já estão em memória, a custo marginal zero; e é consultado em `compose()`, quando o índice de todos os arquivos já está completo. **Não há segunda varredura de disco**, e o precedente de resolução cross-arquivo com abstenção já existe no mesmo arquivo: `candidatasVisiveis` (linhas 988-996) desambigua produtores homônimos por `using`/namespace, e `resolveSpec` (964-981) resolve mounts do Express contra `idx.files`.

Uma diferença de forma que o implementador tem de respeitar: `KNOWN_NON_PRODUCER_CALLS` (linhas 55-61) é um `Set`, porque a decisão lá é binária. O índice de constantes é um `Map` `Classe.Membro → literal`, porque a decisão aqui é ternária — resolver, abster por ambiguidade, ou não conhecer a chave —, e os três estados têm de ser distinguíveis na saída.

**Teste que prova — `tests/w198-route-const-index-gate.sh`.**

| # | Cenário | Vermelho esperado |
|---|---|---|
| `[1]` | `const string Roles = "/roles"` numa classe e `MapGroup(AdminRoutes.Roles)` noutro arquivo: a rota resolve com o prefixo certo | **vermelho**: hoje sai `group-path-not-literal` |
| `[2]` | `$"{AdminRoutes.Roles}/{id}"`: resolve com o sufixo composto | vermelho |
| `[3]` | **abstenção**: duas classes distintas com `Roles` e a referência nua `Roles`: permanece `unresolved`, e nenhum path parcial é emitido | vermelho por motivo oposto — hoje já se abstém, mas por não tentar; o cenário tem de provar que se abstém **depois** de tentar e achar ambiguidade |
| `[4]` | chave única mas em arquivo fora do universo varrido: permanece `unresolved`, nunca resolve por adivinhação | — |
| `[5]` | contrapositiva: constante que **não** é de rota (`const string ConnectionString = "..."`) não vira rota | — |
| `[6]` | propriedade (conservação): `resolvidas_depois + irresolúveis_depois ≥ resolvidas_antes + irresolúveis_antes` sobre o mesmo corpus — o índice **converte** irresolúvel em resolvido, nunca faz sítio desaparecer | **vermelho** se a implementação perder sítio |
| `[7]` | propriedade (invariância de path): toda rota que já resolvia antes do índice resolve depois, para o mesmo path, byte a byte | **vermelho** se o índice alterar resolução existente |
| `[8]` | SUR-01 com `cegueira.length = 0` numa fixture completa devolve `conclusive` — a integração que é o ponto do item | — |
| `[9]` | contador de controle: corpus vazio reprova | — |
| `[10]` | mutação: remover a checagem de unicidade da chave faz `[3]` reprovar; remover o índice faz `[1]` e `[2]` reprovarem; recontrole com `cmp` do lib | — |

O cenário `[7]` é o mais importante e o mais fácil de omitir: um índice que resolve 51 novos sítios e muda um path que já estava certo é uma regressão, e nenhum dos outros nove a pegaria.

**Critério de pronto.** `w198` verde; `w132-route-surface-gate.sh` verde nos 59 cenários, incluindo a prova de mutação `[29]` com o checksum do lib intacto; remedição no `axis-go-cloud` registrada no `detail` de `LDG-0029` com o número de antes e o de depois na mesma linha; e — explicitamente — `LDG-0010` **não** é promovido, porque a segunda pré-condição dele (reprocessar os 35 changes) continua fora de escopo.

---

## 6. Riscos de regressão, nomeados por onde mordem

Esta base tem armadilhas recorrentes. A tabela diz onde cada uma pode morder **nesta leva**, não em abstrato.

| Armadilha | Onde morde aqui | Mitigação exigida |
|---|---|---|
| `sed -i` sem sufixo (GNU × BSD) | Todo gate novo que edite fixture: `w190` (flipar a forma de `runtime.gates`), `w191` (montar `FORGE.md` da fixture), `w192` (flipar `require_tests_before_archive`), `w197` (mutar a versão do contrato no cenário `[9]`). | O idioma do repositório é `sed -i.bak`, documentado em `tests/req13-affects-surfaces-gate.sh:22` — `sed -i ''` quebra no runner Linux do CI. Nenhum gate novo usa outra forma. |
| `env -i … command -v` | Só em `w190[6]`, que precisa simular `node` ausente. | `env -i PATH=… command -v <x>` só funciona onde `command` é builtin do shell invocado, e a nota está em `tests/w180-node-enforcement-gate.sh:217`. Simular ausência de `node` por `PATH` restrito a um diretório temporário, com `command -v` direto, sem `env -i`. |
| `ls \| sort` sob `pipefail` matando o script em silêncio | Em `w193[1..3]`, que precisa enumerar `tests/*.sh`; e em `w191[1]`, que enumera `.forge/scripts/check-*.sh` numa fixture onde o diretório pode não existir. É a classe que `LDG-0141` corrige, e escrevê-la nos gates da própria leva seria a auto-ironia mais provável desta entrega. | Capturar antes do pipe, com `|| true` explícito, e — depois de `LDG-0141` — os próprios gates novos passam a ser varridos por `w145[14]`. |
| Comando editado sem `npm run build:plugin` | `commands/waves/wave.md` muda em §5.6. O `plugin/forge/commands/` espelha 56 comandos hoje. | `npm run build:plugin` no mesmo commit, e `tests/plugin-sync-gate.sh` cenários `[1]` a `[4]` verdes. Vale também para qualquer outro comando que a leva toque. |
| `\b` em regex de `grep` (BSD × GNU) | Todo predicado novo que case nome de gate, nome de chave ou identificador: o reconhecedor de `LDG-0141`, o cruzamento de nomes-base do `doctor` em §5.1, a lista de interruptores de `w192`, a varredura de `phase`/`pre-deploy` de `w197`. | O `grep` BSD do macOS **não** reconhece `\b`: o padrão acha menos na máquina de quem revisa e mais no runner Linux, e a diferença é falso verde silencioso. O repositório já registra a proibição em quatro lugares (`skills/dotnet-quality-scan/scripts/scan.sh:41`, `skills/node-quality-scan/scripts/scan.sh:48` e as duas `references/detection-commands.md`). Use `[[:space:]]` e `([^A-Za-z0-9_]|$)`, nunca `\b`, nunca `grep -P`. Vale também para `\s` e para ranges como `[a-z-]` mal ordenados (`sprint-orchestrator.md:242`). |
| Chave de teste que o gate de segredos acha | `w195` precisa de fixtures de mensagem liaison; `w190`/`w191` precisam de `FORGE.md` de fixture. Se alguma carregar valor com forma de segredo, `check-secrets.sh` (fiado no `pre-commit` e no CI) reprova. | O contrato de `secrets-allowlist.txt` exige motivo de ao menos 12 caracteres por linha, e isentar tudo reprova por vacuidade. Preferir fixture sem forma de segredo; onde for inevitável, entrada na allowlist com motivo auditável, no padrão das duas que já existem. |
| Gate novo fiado no `pre-push` que bloqueia fixture parcial | `LDG-0069` fia dois lints no `pre-push`, e ambos varrem `.sh`. Os gates `w145` e `w159` montam fixtures que **contêm de propósito** a forma proibida — construída por concatenação, exatamente para não se autodetectarem. Um `pre-push` que varra tudo indiscriminadamente bloqueia o push da própria entrega. | Fiar por **diff**, não por árvore: só varrer os `.sh` que o push carrega. E a ordem de §3 (estender antes de fiar) existe para que o corpus já esteja limpo quando o hook entrar. |
| `ledger-ops` escrevendo no checkout principal | Toda vez que esta leva registrar ou atualizar item de ledger a partir da worktree. É `LDG-0068`, ainda aberto quando o trabalho começar. | `FORGE_ROOT` apontando para a worktree, em toda invocação, até `LDG-0068` entregar o aviso. E o aviso, quando existir, é a prova de que a disciplina passou a ser observável. |
| Gate novo que não é invocado | Nove ordinais novos. Um gate entregue e nunca chamado conta como cobertura em todo relatório e não cobre nada — é a issue `#49`, instância 2, e é a própria doença que G1 trata. | `tests/run-all.sh:48` varre `tests/*-gate.sh`; o sufixo `-gate.sh` é obrigatório. `tests/w146-suite-invocation-gate.sh` cenário `[7]` verifica que gates de uma faixa estão dentro da rede — estendê-lo para `w190`–`w198`. |
| Retrocompatibilidade do consumidor | `LDG-0150` muda como o `pre-push` lê gates; `LDG-0008` remove uma chave do schema; `#101` muda `_common.sh`, que `forge update` sobrescreve. | Golden byte a byte do comportamento anterior para a forma CSV (é o método que a própria 0.11.0 usou para `run-gates.sh`), e um parágrafo de CHANGELOG por mudança que um consumidor perceba. |

---

## 7. Numeração e registros novos

**Gates.** `w190` (leitor de gates no `pre-push`, mais a fiação dos lints), `w191` (`doctor` de gate órfão), `w192` (interruptor declarado tem leitor, mais ativação de rule-pack), `w193` (estado derivado da árvore: ordinal e `ROOT` do ledger), `w194` (disciplina de escrita do ledger), `w195` (monotonicidade do liaison), `w197` (paridade de texto normativo), `w198` (índice de constante do route-scan). `w196` fica **não usado** de propósito, como folga entre `w195` e `w197` para a eventualidade de o grupo G4 precisar de um segundo gate. Extensões, sem ordinal novo: `w145` cenários `[9]` a `[15]`; `w146` cenário `[7]` estendido.

**Ledger.** Três entradas novas, a criar com `ledger-ops.sh add` e id editado à mão para a faixa reservada:

| id | tipo | prioridade | conteúdo |
|---|---|---|---|
| `LDG-0150` | `known-bug` | **P2** | O `pre-push` é cego à forma mapeada de `runtime.gates` (A1). Inclui o experimento reproduzível e a consequência: adotar `phase:` desliga a execução de gate no push. Fecha nesta leva. |
| `LDG-0151` | `tech-debt` | P3 | As demais chaves de schema sem leitor (`sdd.default_mode`, `default_rigor`, `default_scale`, `archive_policy`, `human_gate_required`, `quality.evals_root`), com a distinção entre chave que promete default e chave que promete cobrança. Não fecha nesta leva. |
| `LDG-0152` | `tech-debt` | P3 | `fm_field` triplicado (`pre-push:184`, `handoff-gen.sh:42`, `hooks/session/on-session-start.sh`), com a nota de que a correção de `LDG-0150` elimina um dos três. |

**Atualizações de `detail` em itens existentes**, todas com o `update` já corrigido por §5.5, e é essa a prova de campo da correção: `LDG-0008` (são três interruptores, e o terceiro se fecha por remoção); `LDG-0069` (os dois lints rodam no CI contra o corpus real — o defeito é latência, não ausência); `LDG-0067` (a decisão do ledger não transfere, e por qual mecanismo); `LDG-0100` (censo de transportes; zero exposição; condição que reabre); `LDG-0101` (são duas divergências, e a registrada está invertida); `LDG-0102` (o número medido); `LDG-0131` (o comando correto e a resposta sobre `scan-exclude.sh`); `LDG-0021` (116 gates, não 94 — já registrado, confirmado aqui); `LDG-0140` (a segunda metade explicitada).

---

## 8. Verificação desta especificação

O que foi executado ao produzi-la, e que o revisor pode repetir: o experimento do `awk` do `pre-push` contra as duas formas de `runtime.gates` (A1); o censo de `state.cursors[…] = ` nas seis árvores mais o template (A4); o censo de `_dir_push` e de `liaison.yaml` no ecossistema (A7 e `#101`); dois protótipos descartáveis de predicado para `LDG-0141`, com as quatro contagens da tabela de §5.3 (nenhuma linha entrou no lint); a varredura das 61 chaves-folha do `forge.schema.json` contra `scripts/`, `hooks/` e `bin/` (A2); os três diffs de `LDG-0131` e o `grep` de chamadores de `scan-exclude.sh` (A6); e a leitura direta dos cenários `[8]` de `w145` e `w159` (A3).

O que **não** foi executado, e é preciso dizer: `bash tests/run-all.sh` não rodou (116 gates, cerca de quinze minutos, e a instrução desta sessão o proíbe); e a varredura completa do `route-scan` contra o `axis-go-cloud` não foi reproduzida — o número de 370 resolvidas e 75 irresolúveis é do dono do repositório, de 2026-09-05, e está marcado como tal em §5.7. Nenhum outro número deste documento é de terceiro.

---

## 9. Veredito da revisão adversarial

> Revisão executada em 2026-09-05 sobre o commit `091c325`, na mesma worktree `backlog-attack`. `tests/run-all.sh` **não** foi executado (proibido nesta sessão); gates individuais também não foram executados — a revisão é medição sobre o código, não execução da suíte. As correções textuais listadas em §9.3 já estão aplicadas ao corpo desta spec.

### 9.1 Decisão

**APROVADA COM CORREÇÕES OBRIGATÓRIAS.**

O núcleo da spec sobrevive: A1, A3, A4, A5, A7, A8 e A9 conferem na fonte, o agrupamento por causa se sustenta, a lista de itens fora da leva é honesta e cada exclusão tem medição própria. O que não sobrevive é a régua de vermelho: sete cenários marcados como vermelhos passam **antes** da correção, e o censo de `LDG-0141` acusa um sítio que não é da classe enquanto omite um que é — e que mata o script. Nenhuma das cinco objeções bloqueantes exige rediscutir o desenho; todas são de asserção e de censo, e todas estão corrigidas no texto acima. O implementador pode começar pela §3 sem esperar por nova rodada, desde que trate a §9.2 como parte do contrato.

### 9.2 Objeções bloqueantes

**B1 — Sete cenários descritos como vermelhos ficariam verdes antes da correção.** Toda asserção da forma "o mecanismo **não** produz X" é satisfeita por um harness em que o mecanismo não existe. `w191[2]` ("o `doctor` não os acusa") e `w191[3]` passam hoje porque o `doctor` não acusa ninguém — o bloco de órfãos só roda no ramo `else` da cascata de `core.hooksPath` (`doctor.sh:376` para trás), como a própria §5.1 mede. `w195[6]` ("`ack` de mensagem anterior não faz o cursor regredir"), `w195[8]` ("para qualquer sequência de `ack` e `read --upto` o índice é não-decrescente") e `w195[9]` passam hoje porque `ack)` não escreve cursor nenhum: medido, `template/.forge/scripts/liaison-ops.sh` tem **uma** escrita de cursor, na linha 818, dentro de `read)`, e a guarda de não-regressão em 813-817 já recusa retrocesso. `w192[9]` ("rule com `pack:` de pack não ativado não reprova nada") passa hoje porque nada lê `pack:` — a spec chega a escrever "hoje é indistinguível" e ainda assim marca vermelho. `w193[7]` ("`add` com `FORGE_ROOT` na worktree não emite o aviso") passa hoje porque aviso nenhum é emitido. `w198[3]` a própria §5.7 reconhece. Comando que demonstra o caso mais barato de todos:

```
$ grep -n 'state\.cursors\[[^]]*\] *=' template/.forge/scripts/liaison-ops.sh
818:  state.cursors[threadId] = { msg_id: upto, read_at: nowWall };
$ for c in $(git log --format=%h -- template/.forge/scripts/liaison-ops.sh); do
    echo "$c $(git show $c:template/.forge/scripts/liaison-ops.sh | grep -c 'state\.cursors\[[^]]*\] *=')"; done
8c13186 1 / 25e5907 1 / ba396ee 1 / 836232f 1 / b5e0909 1 / 035fb07 1 / 798ff17 1 / 47a914e 1 / af56931 1
```

Nove commits, sempre uma escrita: não há caminho pelo qual o cursor avance por `ack`, logo "o cursor não regride sob `ack`" é verdadeiro hoje e continuará verdadeiro se a correção nunca for escrita. **Correção obrigatória, já aplicada à §5:** parear toda asserção negativa com uma positiva observável que só existe depois da correção — o valor do cursor lido de `state.json` e comparado com o índice esperado, a linha de contador do `doctor` nomeando quantos `check-*.sh` examinou, o veredito nomeado do `validate-rules`. Sem o par, o cenário é rotulado `verde hoje — controle` e não conta como prova.

**B2 — O censo de `LDG-0141` acusa um sítio que não é da classe e omite um que é.** `tests/w113-liaison-enforce-gate.sh:207` é `parent="$(git … 2>/dev/null || git …)"` — não há pipeline nenhum ali, o `||` é OR lógico. Nenhum reconhecedor que exija pipeline o alcança, e o requisito de desenho que a spec derivava dele ("o escape aceito é **qualquer** `||` seguido de comando") fica sem base. Pior: aplicado, esse requisito deixa passar `template/.forge/scripts/impact.sh:21`, que é da classe e é letal. Medido:

```
$ cat probe.sh
set -euo pipefail
files=""
[ -n "$files" ] || files="$(false 2>/dev/null | sed 's/^...//' | paste -sd, -)"
echo "SOBREVIVEU (files='$files')"
$ bash probe.sh; echo "rc=$?"
rc=1
```

"SOBREVIVEU" não é impresso: a atribuição é o último comando da lista OR, o `pipefail` promove a falha do produtor, e o `set -e` mata. `impact.sh:21` é literalmente essa forma, com `git -C "$ROOT" status --porcelain 2>/dev/null | sed | paste`, num arquivo que declara `set -euo pipefail` na linha 8. E a consequência de ordem é a que fecha o argumento: hoje a linha 20 morre primeiro; corrigi-la sem corrigir a 21 **transfere** a morte silenciosa uma linha adiante, dentro do mesmo arquivo, no mesmo change que existe para eliminar a classe. Isso torna o critério `w145[14]` ("o corpus real passa depois dos cinco sítios corrigidos") ou falso-verde — se o escape for "qualquer `||`" — ou vermelho, porque falta o sexto sítio. **Correção obrigatória, já aplicada à §5.3:** censo de seis sítios com `impact.sh:21` dentro e `w113:207` fora; escape definido como o `||` que governa a própria substituição; cenário `[11b]` novo, que reprova a forma de `impact.sh:21` e impede o reconhecedor de aceitar qualquer `||`.

**B3 — A guarda de `node` ausente, como escrita, bloqueia o push default de todo adotante.** A §5.1 exigia: "se o frontmatter tem uma linha `  gates:` sem valor inline (a assinatura da forma mapeada) e o leitor devolveu zero entradas, isso é `BLOQUEADO`". Medido, esse predicado é o estado de fábrica: `template/.forge/templates/FORGE.md:24` entrega `gates:` como chave vazia, sem CSV e sem block-sequence, e `lib/gate-phase.mjs` documenta esse formato — "block-sequence YAML (NOVO), quando o valor inline de `gates:` está vazio" — como a assinatura da forma mapeada. Todo projeto recém-inicializado casaria a guarda e teria o primeiro push recusado. **Correção obrigatória, já aplicada à §5.1:** o gatilho do bloqueio é a **indisponibilidade do leitor** (`node` ou `lib/gate-phase.mjs` ausentes), não a forma do frontmatter; com o leitor disponível e zero entradas, é `NO-GATES`. A mesma edição registra o que a exigência custa: ela contraria por desenho o contrato escrito de `lib/forge-runtime.sh:71-72` ("nunca trava o script") e deixa `run-gates.sh` e `spec-verify.sh` silenciosos no mesmo estado — duas severidades para o mesmo fato, aceitável declarada, inaceitável implícita.

**B4 — `w197[2]` é verde hoje.** O cenário compara a `Data` da tabela de topo com "a última entrada do changelog do próprio documento". Medido em `contracts/claude-adapter-contract.md`: a tabela de topo diz `2026-06-10`, e a última **linha** da seção "Controle de versão do documento" (linha 98) é `Milton Silva - 2026-06-10 - Gate W0.3 decidido: Approve` — mesma data. O vermelho só aparece contra a última entrada **de versão** (linha 97, `Versão 1.5`, `2026-09-04`). Implementado ao pé da letra, `[2]` aprova antes e depois da correção. **Correção obrigatória, já aplicada à §5.6.**

**B5 — Aritmética de escopo do sumário.** "Doze itens entram nesta leva; oito ficam de fora" não fecha com nada medível. Os vinte achados são 16 itens de ledger abertos (`LDG-0003, 0008, 0010, 0021, 0029, 0065, 0067, 0068, 0069, 0100, 0101, 0102, 0110, 0131, 0140, 0141`, conferidos no `ledger.json`) mais as quatro issues. Entram quinze; ficam de fora cinco (`LDG-0010`, `LDG-0021`, `LDG-0065`, `LDG-0100`, `LDG-0131`). A §4 tem oito linhas porque três delas recortam escopo **dentro** de itens que entram, e não são itens dos vinte. Com o `LDG-0150` novo, a leva tem dezesseis itens de trabalho. **Correção obrigatória, já aplicada ao sumário.** Não é o número que importa; é que a spec inteira se apoia em "eu medi", e este número não foi medido.

### 9.3 O que mudou nesta spec

Sumário executivo: contagem de escopo corrigida para quinze dentro / cinco fora, com a explicação da §4 de oito linhas. A5 e §5.5: `_unknown_flag` → `_reject_unknown` (`liaison-ops.sh:111`, 22 usos) — o nome antigo não existe em lugar nenhum do repositório, e o `ack)` já usa o helper. §5.3: tabela de predicados anotada (interseção 6, ou 5 sob a regra de escape ingênua; `2>/dev/null` 6, não 7), censo dos sítios refeito com `impact.sh:21` dentro e `w113:207` fora e a justificativa medida, contagem de `pipefail` sem `-e` de 41 para 40, contagem de substituição de processo de 8 para 14 (6 em arquivo com `set -e` + `pipefail`), cenário `[11b]` acrescentado a `w145` e critério de pronto passado para dezesseis cenários e seis sítios. §5 (convenções): parágrafo normativo novo proibindo asserção negativa desacompanhada, com os oito cenários nomeados. §5.1: predicado da guarda de leitor indisponível reescrito, com as duas decisões que ele força declaradas. §5.6: `w197[2]` reescrito contra a última entrada de versão. §5.5: cenário `[12b]` acrescentado a `w194`, contador de controle da própria parametrização dos seis subcomandos. §6: linha nova para `\b` em `grep` BSD.

### 9.4 Objeções não bloqueantes

`w192[1]` é frouxo: "existe ao menos um arquivo em `scripts/`, `hooks/` ou `bin/` que a menciona" é satisfeito por um comentário. Menção não é leitura, e a correção de `LDG-0008` inclui escrever comentários sobre as chaves — há caminho para o gate ficar verde sem que nenhuma chave seja lida. A asserção tem de ser sobre uso, não sobre ocorrência: a chave aparece num sítio que decide alguma coisa, e a prova de mutação `[7]` tem de reprovar quando a decisão sai e o comentário fica.

`LDG-0008` adia para o implementador a decisão de qual sinal prova que há teste, e os cenários `[4]` e `[5]` dependem dessa decisão. Não são escrevíveis hoje — o que é legítimo, mas significa que o "vermelho esperado" das duas linhas é uma promessa, não uma medição, e a spec devia dizê-lo. O caminho que a própria §5.2 abre (se nenhum sinal existente servir, a chave vira remoção também) é o certo, e deve ser exercido cedo, não no fim.

`LDG-0029` está sub-dimensionado para a leva. Ele carrega decisões de desenho próprias (Map ternário contra Set binário, gramática de interpolação aceita, política de abstenção por chave não-única), um gate de dez cenários, e um critério de pronto que depende de remedir um repositório **externo** — `axis-go-cloud`, cerca de 185 segundos, fora do alcance do CI do harness. Nenhum gate do harness pode provar o "depois". É o perfil de um change SDD com `design.md`, e o argumento de que ele "pode correr em paralelo desde o início" é justamente o argumento de que ele é outro trabalho. Recomendação: extrair para change próprio, mantendo a §5.7 como o insumo dele. Não bloqueia porque não contamina os outros seis grupos.

A fixture de `w190` tem de sobreviver a nove caminhos `BLOQUEADO` do `pre-push` antes de chegar ao bloco de gates da linha 257 — delegação em alvo ausente do `hooks/git/lib`, `check-ai-attribution` (existência e conteúdo), `check-liaison-acks`, `check-liaison-log-integrity`, `check-worktree-prereqs`, `heavy-mutex`, mais os `run_check` de `typecheck`/`test`/`lint`. A §6 nomeia o risco inverso (gate novo bloqueando a fixture parcial dos lints) e não este. Vale uma linha na §6 do implementador: a fixture ou copia `.forge/scripts/` inteiro, ou não cria `.forge/scripts/` de todo — os meios-termos são exatamente o que essas guardas existem para reprovar.

`w197[6]` afirma "zero ocorrências" de `phase` em `template/.forge/templates/FORGE.md`. Medido, há duas: linhas 58 e 61, dentro da palavra `phases`, em prosa sobre scale-adaptive levels. O cenário continua vermelho porque exige os três termos e `pre-deploy` de fato não ocorre, mas um `grep -q phase` produz falso verde nesse terço. O predicado tem de casar `phase:` como chave, não `phase` como substring.

`w197[3]` chama de propriedade o que é o caso: o universo de `.md` com tabela de topo em `contracts/` é **um** arquivo. `contracts/` mora na raiz do repositório do harness, não em `template/` — `template/.forge/contracts/` contém apenas `stages/*.yaml`. A spec deve dizer qual dos dois o gate varre, porque varrendo o segundo o contador de controle `[8]` reprova por universo vazio, corretamente.

`w193[3]` fixa "93 arquivos `w*.sh`, ordinal máximo 186". Medido e correto hoje; depois desta leva serão 101 e 198. Se esses números entrarem como constante no gate, ele reprova no commit seguinte ao próprio.

Três números decorativos não foram reproduzíveis e devem sair ou ganhar o predicado que os produziu: as "46 ocorrências" do predicado ingênuo (a spec não declara o que conta como "produtor falível"; com a família explícita da própria tabela dá 27, que **confere**), os "53 falsos positivos" que a condição de `set -e` evita, e as "61 chaves-folha" de `forgeManifest` mais `forgeFrontmatter` (minha travessia devolve 72 — a definição de folha não está declarada). O mesmo vale para "os cinco `liaison.yaml` do ecossistema": medi quatro vivos (`axis-go-cloud`, `axis-device-platform`, `Axis.PadSimulator`, `axis-fare-validator`) e sete contando os `.bak`. A conclusão de A7 — nenhum canal declara `git` ou `gh` — se sustenta em todos os sete.

Duas imprecisões menores de citação, sem consequência: A2 diz que as únicas ocorrências das três chaves `require_*` fora de `plugin/` e `node_modules` são `forge.yaml`, o schema e `docs/refer/` — faltam `.forge/ledger/ledger.json`, `.forge/ledger/LEDGER.md` e `docs/plans/2026-09-04-…`, que são registro sobre o item e não leitor. E `hp_orfaos` vai de 357 a 374, não a 365 (o `warn` do encadeamento parcial está em 371).

Uma dependência não declarada, benigna mas que vale registrar: `LDG-0008`, `LDG-0003` e `LDG-0029` tocam três arquivos distintos, mas `#103` e `LDG-0068` tocam **o mesmo** `ledger-ops.sh` em direções compatíveis e são provados em gates diferentes (`w194` e `w193`). Se `#103` entrar primeiro, o aviso de `add` sem `--detail` que ele acrescenta muda a saída que `w193[6]`/`[7]` inspecionam. Não é conflito, é ordem de escrita de asserção: `w193` deve casar a linha do aviso de `ROOT`, nunca a saída inteira. E a boa notícia, medida: `archive-spec.sh:103` e `spec-close.sh:73` invocam `harvest` só com `--origin`, flag conhecida — a disciplina estrita de `#103` não quebra nenhum chamador existente.

### 9.5 O que foi medido e bateu

Confirmados na fonte, com o valor da spec igual ao medido: as três chaves `quality.require_*` sem leitor em `scripts/`, `hooks/` e `bin/`, e as seis chaves `sdd.*` mais `quality.evals_root` com zero ocorrência também em `commands/`, `agents/` e `rules/`; `human_archive_approval` exigido de fato — `spec-manifest.schema.json:53-59`, `validate-archive.mjs:80-81` (a linha 13 citada pela spec é o comentário do contrato, e o enforcement está em 80-81), `approval-log.sh:41`. A3 inteira: `w145[8]` na linha 110 com `--path template --path tests`, `w159[8]` na linha 147 com os três `--path`, `ci.yml:49` rodando `run-all.sh`, `ci.yml:67-68` com o passo dedicado do `check-shell-pipeline` e nenhum passo dedicado para o `check-heredoc-hash`, `run-all.sh:48` varrendo `tests/*-gate.sh`. A4 inteira, incluindo as sete linhas do censo de árvores (`axis-go-cloud` 1137/4, `Axis.PadSimulator` 1424/2, `axis-fare-validator` 1227/1, `axis-device-platform` 1111/1, `azim-crm` e `collatra` 865/1, `template` 1250/1) e a afirmação mais forte dela: nos nove commits do histórico do arquivo no template há sempre exatamente uma escrita de cursor. A5 no que toca ao ledger: `LDG-0100`, `LDG-0101` e `LDG-0102` abertas com `detail` vazio, as três criadas em `2026-09-04T18:44:45-03:00`, as três `origin: manual`, e são as únicas três abertas sem `detail` entre as dezesseis. A7: todos os `liaison.yaml` do ecossistema declaram `kind: "fs"`. A9: a descrição de `body` no schema promete "exatamente um dos dois é obrigatório" enquanto `required` não os lista e o `allOf` tem só as duas cláusulas sobre `kind`; `validateEnvelope` (`liaison-merge.mjs:273`) implementa "ambos opcionais, mutuamente exclusivos quando presentes", com a justificativa em 286-287 e a checagem em 288 — a divergência de direção oposta é real.

Das dependências declaradas na §3, as duas que a revisão foi mandada conferir batem: `lib/api-surface.mjs:476` tem `const NAO_SUPRIME = new Set([])` e a linha 479 é o `if (cegueira.length === 0)` que decide `conclusive` contra `inconclusive`; `rules/README.md:17` e `capabilities/README.md:11` declaram por escrito que `pack:` é sinalização documental até a chave existir, apontando `LDG-0003` como razão. Também conferem as citações estruturais que o implementador vai usar: `pre-push` com `fm_field` em 184-190, comentário de exemplo em 253-256, bloco a substituir em 257-275, disciplina de delegação em 71-74 e 111-114; `doctor.sh` com `check_harness()` de 68 a 425 (a chave em 135 fecha a função aninhada `_generated_header`, não a externa) e o bloco de órfãos só no ramo `else` da cascata; os catorze `check-*.sh` do template, com `check-red-first` invocado indiretamente pelo wrapper de `pre-push:57` e `check-heavy-mutex` sem hook nenhum; `_forge_main_root()` copiado exatamente nos quatro arquivos e linhas citados; `bin/forge.mjs:307` com `capabilities` em `MACHINERY_DIRS` e `:352` com `ENRICHABLE_DIRS` sem `scripts`; `route-scan.mjs` com `scanRoutes` em 1217, a leitura de disco em 1222 e o `compose(idx)` em 1253, e `KNOWN_NON_PRODUCER_CALLS` como `Set` em 55-61; `ledger-ops.sh:184` com o `if (de) e.detail = de;`, a etapa (3) do `harvest` em 312-322 e o `detail: ''` mais `priority: null` em 333-334.

Os contadores da §4 e da §6 também batem: 114 arquivos `tests/*-gate.sh` mais duas suítes `bats` fazem os 116 do `LDG-0021`, dos quais 93 casam `w*`, com ordinal máximo 186 e zero colisões hoje; 56 comandos espelhados no `plugin/forge/commands/`; `w132` com 59 cenários; os packs de capability com 4, 6, 1 e 1 arquivos, que é o que justifica manter `LDG-0065` fora; `req13-affects-surfaces-gate.sh:22` com o idioma `sed -i.bak` documentado, `w180-node-enforcement-gate.sh:217` com a nota sobre `env -i … command -v`, `w153` com `lab74()` em 113-123 e `check-push-ahead.sh:166` com o precedente de recusa a criar uma segunda chave para o mesmo fato; `w146[7]` cobrindo hoje a faixa `w144`–`w147`, que é o cenário a estender. `LDG-0102` confere: `Versão 1.2` e `2026-06-10` na tabela de topo contra `Versão 1.5` de `2026-09-04` na última entrada de versão do rodapé. E `139` dos `198` `.sh` declaram `set -e` junto com `pipefail`, com `check-shell-pipeline.sh` de fato entre os que declaram `pipefail` sem `-e` e com as ocorrências nas linhas 71 e 78 exatamente onde a spec diz.

Um achado que corrige a narrativa sem mudar a conclusão: a spec afirma, em A5, que o precedente de recusa a flag desconhecida "existe em `liaison-ops.sh`". Existe, e mais forte do que a spec supõe — `_reject_unknown` é chamado 22 vezes naquele arquivo, inclusive dentro do próprio `ack)` que `#102` vai alterar. O que não existe é o nome `_unknown_flag`, que a spec usa duas vezes e que o implementador iria procurar.

### 9.6 O que não consegui verificar

A medição de `LDG-0029` — 370 rotas resolvidas e 75 irresolúveis no `axis-go-cloud`, particionadas em cinco categorias, com projeção de 51 sítios recuperados — não foi reproduzida. É medição de terceiro, a spec a declara como tal em §5.7 e §8, e reproduzi-la exigiria rodar o `route-scan` completo contra um repositório externo por cerca de 185 segundos. A declaração de procedência está correta e a exigência de remedir antes e depois é a mitigação certa; a objeção que resta sobre esse item é de escopo (§9.4), não de número. Também não executei gate nenhum: a proibição de rodar `tests/run-all.sh` vale nesta sessão e gates individuais não foram necessários para nenhuma das objeções acima — todas se demonstram por leitura da fonte, por censo, ou pelo probe de doze linhas de `bash` da B2. Por fim, o predicado "ingênuo" de 46 ocorrências e os 53 falsos positivos evitados pela condição de `set -e` não são reproduzíveis a partir do texto: a spec não declara o que conta como produtor falível fora da família explícita, e a família explícita reproduz exatamente os 27 da terceira linha da tabela.
