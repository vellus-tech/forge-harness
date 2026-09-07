# Prompt da próxima rodada — forge-harness, depois do merge do PR #105

> Emitido em 2026-09-06, depois da rodada que mergeou o PR #105 e de uma análise de quinze agentes (cinco varreduras, três propostas com viés declarado, seis refutações adversariais, um crítico de completude).
> Formato: `~/Documents/projects/axis-go-cloud/plans/templates/prompt-de-sessao.md`. O mandato do §4 foi adaptado ao forge-harness — as peças do axis-go-cloud que não existem aqui saíram, e as que existem (`approval-log.sh`, `heavy-run.sh`, `gate-ordinal.sh`) ficaram.

========================= prompt =========================

```
rodada: R01 · prompt_id: R01-FH-canal-antes-da-release · emitido_em: 2026-09-06 · expira_em: 2026-09-13

=== QUEM VOCÊ É ===

Você é a sessão do forge-harness, em /Users/milton/Documents/projects/forge-harness, branch develop — que É a branch default deste repositório no GitHub (vellus-tech/forge-harness). Confirme sempre com `git ls-remote --symref origin HEAD` antes de confiar nisso: toda a lógica de closing keyword depende dele, e uma rodada inteira já foi conduzida sob a crença errada de que develop não era a default.

Armadilhas estruturais deste repositório, que custaram tempo e você precisa saber antes de tocar em qualquer coisa:

O checkout principal NÃO tem `.forge/scripts/`. O dogfood roda pelos scripts do template: `template/.forge/scripts/<script>.sh`. O ledger real, porém, vive em `.forge/ledger/ledger.json` na raiz — o script resolve o ROOT pelo `--git-common-dir`, então rodar de qualquer lugar do repositório escreve no lugar certo. NUNCA exporte `FORGE_ROOT`: exportar e rodar script do harness escreve estado durável no repositório real. Use `env -u FORGE_ROOT bash ...` sempre.

Existem dois worktrees montados: `.forge/worktrees/backlog-attack` (branch feat/backlog-attack, já mergeada por squash, resíduo) e `.forge/worktrees/upgrade-safety` (branch feat/upgrade-safety, ff4578a, é o objeto do LDG-0131 e NÃO é resíduo — tem trabalho não avaliado dentro). Use `git -C <path absoluto>` sempre; nunca dependa do cwd do shell.

Você é participante declarado de um canal de liaison que nunca leu. Isto é o centro desta rodada e está detalhado abaixo.

=== BOOTSTRAP ===

cd /Users/milton/Documents/projects/forge-harness
git ls-remote --symref origin HEAD
git log --oneline origin/main..origin/develop
git status --porcelain && git worktree list
gh issue list --state open --limit 20 --json number,title,createdAt --jq '.[] | "#\(.number) [\(.createdAt[0:16])] \(.title)"'
node -e 'const j=require("./.forge/ledger/ledger.json");const a=j.entries.filter(e=>!["resolved","wont-fix"].includes(e.status));console.log(j.entries.length,"entradas,",a.length,"abertas");a.forEach(e=>console.log(e.id,`[${e.type}/${e.priority}]`,e.title.slice(0,95)))'
ls -d /Users/milton/Documents/projects/.forge-liaison-hub/forge-harness
cat /Users/milton/Documents/projects/.forge-liaison-hub/forge-harness/log/*.jsonl | wc -l
ls -d .forge/liaison 2>&1

O último comando falha, e a falha É o achado: 340 mensagens endereçadas a este repositório e nenhuma réplica local para recebê-las.

=== AUTONOMIA ESTENDIDA ===

Trabalhe até fechar a lista, sem retornos parciais. A única exceção é a TAREFA 2, que é decisão minha e não sua: chegue nela com o material medido e PARE ali, no meio da rodada, para eu decidir. Depois que eu decidir, siga para a 3 sem me perguntar de novo. Se travar em dependência de terceiro em qualquer outra tarefa, siga para a próxima e reporte no fim — nunca pare esperando ack.

=== O QUE VOCÊ ENTREGOU, E O QUE EU CONFIRMEI ===

A rodada do PR #105 acertou o essencial, e eu confirmei medindo, não pelo relatório.

O achado central resiste: o `pre-push` era cego à forma mapeada de `runtime.gates` que a própria 0.11.0 publicou. `git show v0.11.0:template/.forge/hooks/git/pre-push | grep -c forge_runtime_gate_entries` devolve 0 e o mesmo comando sobre develop devolve 2 (com `grep -cE 'forge_runtime_gate_entries|gate-phase'` são 7 — declare qual expressão você usou, porque eu já troquei os dois números uma vez). Um consumidor que adotasse `phase:` desligava todos os gates no push, com push verde. Está corrigido e coberto por gate que prova pelo canal real — `w190` monta repositório de fixture, instala hooks por `core.hooksPath` absoluto e faz `git push` de verdade contra um remoto `--bare`. Não é gate invocado como função.

A edição do corpo do PR antes do merge funcionou exatamente como desenhada, e era a única janela dura da rodada: `gh issue view` confirma #82 `CLOSED` às 15:15:57Z, dois segundos depois do merge, e #101 e #103 `OPEN`. A #102 também está `CLOSED`, mas às 15:18:08Z, por ato meu e não pelo merge (`commit_id: null`) — ao dizer o que fechou, diga sempre pelo que fechou. Sem aquela edição, três issues com metade do título não entregue teriam fechado sozinhas.

Crédito nominal pelas formulações que eu quero ver se espalhando: **"prova produzida por quem é verificado, no ambiente que ela controla, não prova nada"** e **"asserção negativa é satisfeita trivialmente por um harness em que o mecanismo não existe"** — essa segunda derrubou sete cenários que passariam antes da correção. E a disciplina de reproduzir em fixture própria com controle E recontrole, que foi o que provou a terceira porta do #103 (`ledger-ops.sh update LDG-0001 --detail --title` devolve `OK update`, rc=0, e grava `detail = "--title"`).

O que a minha medição contraria, e você precisa saber antes de repetir:

A contagem de itens de ledger da rodada não fecha com ela mesma. São quatro números em circulação, não dois: o corpo do PR #105 diz "dezesseis itens de ledger" no primeiro parágrafo E "os doze itens de ledger" no parágrafo do aviso operacional, listando 12 ids como resolvidos; o CHANGELOG que o MESMO commit escreve diz "treze itens de ledger". O diff diz outra coisa: `git diff 5ff7f6b..d7d4ad4 -- .forge/ledger/ledger.json` toca 23 entradas (9 novas, 14 alteradas). Nenhum dos dois textos declara o método de contagem. Não invente um terceiro número: declare o método junto do número, ou não escreva número nenhum.

O título do commit de squash em develop é falso. `git log -1 --format=%s d7d4ad4` afirma "fecha #82, #101, #102, #103" e só a #82 fechou. Não é closing keyword (está em português), então não causou dano mecânico — mas é registro permanente que mente, na branch default, no commit da leva que existiu para eliminar registro que mente. Não dá para corrigir sem reescrever histórico publicado, e eu não autorizo reescrever. Fica como está, e como lição: o título do PR entra na revisão junto com o corpo.

LDG-0010 ficou com título contradizendo o próprio detail — o título diz "BLOQUEADO por LDG-0029" e o detail reescrito na mesma rodada diz que o bloqueador real são as `MapGroup()` não ancoradas. Note que o detail do LDG-0010 NÃO cita o id `LDG-0162`: diz apenas "item próprio". Quem nomeia a ligação é o detail do LDG-0162, na direção contrária. É a mesma contradição título-contra-detail que a rodada acabou de criticar no LDG-0029.

=== ONDE EU ERREI ===

Quatro retratações minhas, e a terceira é a que mais importa.

**Eu afirmei a rodada inteira que merge para `develop` não dispara closing keywords.** É falso. `develop` É a branch default desde 2026-06-16 e a minha própria memória de projeto já registrava isso. A afirmação errada foi escrita em negrito no corpo do PR #105.

**Eu sugeri que o dono republicando sobre divergência em posição conhecida deveria ser aceito por default.** Estava errado: reescrita-por-terceiro e colisão de sequência produzem logs idênticos, nada nos dados os distingue, e aceitar por default apagaria mensagem alheia em silêncio. A solução certa, que ficou, é reparo atrás de flag explícita `--repair-own-log`.

**Eu afirmei, hoje, que "a 0.11.0 publicou o eixo de fase com o pre-push cego, então toda instalação nova leva o recurso e o defeito juntos", e usei isso para chamar a release de urgente.** A refutação adversarial derrubou a segunda metade, medindo: a 0.11.0 publicou a MAQUINARIA (`gate-phase.mjs`, `run-gates.sh --phase`) e ZERO documentação da forma mapeada. `git show v0.11.0:template/.forge/FORGE.md | sed -n '/^runtime:/,/^codegraph:/p'` mostra `gates:` nu, sem comentário; `git show v0.11.0:template/.forge/rules/testing/gate-delivery-channel.md | grep -c pre-deploy` devolve 0. Um adotante da 0.11.0 não tem como aprender, de nada que recebeu, a forma que dispara o defeito. A exposição não cresce com instalações novas; cresce com quem descobrir a forma por conta própria — e cresce de verdade no dia em que sair a release que ENSINA a forma. Isso rebaixa a urgência do corte e eleva a exigência sobre o que a próxima release contém.

**E a primeira versão deste prompt saiu com sete números errados, que um verificador adversarial derrubou antes de você recebê-lo.** Eu escrevi que o `grep` do `pre-push` em develop devolve 7 quando devolve 2 — o 7 era de uma expressão combinada que eu usei numa medição anterior e transcrevi para o comando errado. Escrevi que o merge da release tem três pais quando tem dois, porque li a saída de `git rev-list --parents -n 1` como pais em vez de commit-mais-pais. Escrevi "só a #82 fechou" quando a #102 também está fechada, por ato meu. Escrevi que o detail do LDG-0010 nomeia LDG-0162 quando ele diz apenas "item próprio". Dei 48 arquivos no PR quando são 49, quatro entradas em `Added` quando são três, e um DoD para a TAREFA 1 que era inalcançável pelo comando que ele próprio prescrevia. Registro isto por dois motivos: para você não herdar os números errados, e porque é a demonstração do que o MANDATO cobra de você — vermelho declarado se verifica antes de virar DoD, e número sem o comando ao lado é chute com aparência de medição.

**E eu conduzi a rodada do PR #105 inteira sem ler o canal de liaison deste repositório.** Mergei a correção da #101 — o `_dir_push` fail-closed — sem saber que o dono de outro repositório havia medido aquele desenho no mesmo dia e pedido explicitamente para não distribuí-lo. É a falha de processo mais cara da rodada, e é o motivo de a TAREFA 1 desta ser ler o canal.

=== O QUE VOCÊ NÃO PODE DERIVAR DO DISCO ===

**Existe um hub de liaison com um canal endereçado a este repositório, e este repositório nunca falou nele.** O hub é `/Users/milton/Documents/projects/.forge-liaison-hub` e o canal é `forge-harness`. Medido às 16h de 2026-09-06: 348 mensagens, de quatro remetentes (axis-device-platform 96, axis-fare-validator 94, axis-go-cloud 88, axis-pad-simulator 70), 58 exigindo ack, zero do `forge-harness`. ESTE NÚMERO ENVELHECE ENQUANTO VOCÊ LÊ: entre a primeira medição desta análise e a verificação adversarial, o canal andou oito mensagens em cerca de três horas, e quatro delas eram sobre o arquivo em disputa. Remeça no bootstrap e trabalhe com o seu número, nunca com o meu. E `ls -d .forge/liaison` neste repositório não devolve nada — não há réplica. O doctor reporta isso como benignidade (`LIAISON: self=? · 0 canal(is)`), o que é a terceira polaridade do item 3 da #108: não o `state.json` inválido, e sim a réplica ausente lida como zero canal.

**A mensagem `axis-go-cloud-0086`, de hoje às 11:51, pede literalmente para não distribuir o que acabamos de mergear.** O corpo está em `blobs/6a666e42db9557d649190b7f28e65b9fb55f5f5bf8adada77eea83ac020068d5-msg-quarta-versao.md` e diz: *"Não distribuam essa versão ainda. Se ela descer para os consumidores, cada worktree nova nasce recusando push enquanto a réplica dela estiver atrás — e 79% já estão."* Ela identifica o arquivo por sha: `6a96021062be787b…`. Eu conferi — `shasum -a256 template/.forge/scripts/lib/transports/_common.sh` em develop devolve exatamente esse sha. A "quarta versão" que o campo pede para não distribuir É o que o PR #105 mergeou.

O argumento dela é de desenho, não de bug: o fail-closed novo não destrói mais o hub (e ela dá o crédito por escrito), mas troca perda de dados por push travado — recusa em vez de unir. E o `_dir_pull` não traz de volta o próprio log por desenho, então "sincronize primeiro" não é operação que o participante consiga executar sozinho para o log dele.

**Mas o número que ela usa para dimensionar o problema está inflado por vício de universo, e isso é meu achado de hoje, ainda não comunicado a ela.** Ela mede 782 de 984 réplicas atrasadas (79%). Eu medi as réplicas de participante real — profundidade 1 sob `~/Documents/projects/*/.forge/liaison/` — e obtive 30 réplicas, 24 com par no hub, 3 atrasadas (13%) na primeira passada e 0 atrasadas (0%) na verificação três horas depois, porque o campo sincronizou no intervalo. A diferença é o universo: `find` com `maxdepth 7` acha 44 réplicas e com `maxdepth 9` acha 830, das quais 688 vêm de `axis-go-cloud` e 128 de `Axis.PadSimulator`, todas dentro de `.forge/worktrees/*` — inclusive dentro do `axis-device-platform` aninhado, o mesmo repositório git-excluído que o LDG-0029 acabou de identificar como contaminante da varredura do route-scan. Réplica dentro de worktree efêmero não é participante do canal: é cópia de trabalho que nunca vai publicar. Isto não anula o argumento de desenho dela, que é legítimo e independente do número. Anula a magnitude, e é exatamente o que eu quero devolver ao canal.

**Há três consumidores com conserto local no arquivo em disputa, e o `forge update` os apaga.** Comparei o `_common.sh` do template com a cópia de cada consumidor: `axis-fare-validator` (53bcdc9d), `axis-go-cloud` (cff3162f) e `Axis.PadSimulator` (68e4bb64) têm três shas distintos, nenhum igual ao do template; `azim-crm` e `collatra` ainda estão em `28a01adc`, a versão que o campo nomeia como destrutiva. Esse arquivo mora em `template/.forge/scripts/`, que está em `MACHINERY_DIRS` (`bin/forge.mjs:307`) e fora de `ENRICHABLE_DIRS` (`bin/forge.mjs:352`) — é literalmente o caminho que a issue #101 descreve. Publicar e mandar rodar `forge update` sobrescreve os três consertos sem uma linha de aviso nas árvores sem `machinery.lock`.

**As issues #106, #107 e #109 foram abertas hoje, fora da rodada do #105, e a #109 nasceu depois da análise que gerou este prompt.** O universo não é mais "cinco issues abertas": são seis. A #107, além disso, já foi superada pelo campo antes de qualquer um de nós orçá-la — as mensagens `axis-pad-simulator-0066` e `axis-device-platform-0095` descrevem defeito estritamente maior do que o mecanismo que a issue registra, e o número do título dela ("145 ponteiros mortos em 29 réplicas") já não é o número do campo.

**O que já foi rejeitado e não volta:** gate de paridade cross-repositório para a #101 (o harness não enxerga a árvore do consumidor, e gate sem universo é o que a guarda de vacuidade existe para reprovar — mas essa recusa NÃO cobre o check LOCAL de deriva, que é viável e continua em aberto); change SDD para o LDG-0029 como está escrito (o índice de constante literal tem alvo zero no repositório de referência); e carimbar `resolved_at` em `add`/`update` do ledger (manteria duas fontes de verdade para o mesmo carimbo).

=== DECISÕES DO DONO ===

**Nada é publicado antes de o canal ser lido e respondido.** A razão não é cortesia: o campo mediu o nosso artefato e registrou uma objeção de desenho antes de nós o mergearmos, e nós não vimos porque não lemos. Publicar agora repete o erro com o custo multiplicado por cada consumidor. O critério que quero que você generalize: quando existe canal aberto sobre um artefato, o canal é insumo de release, não cortesia pós-release.

**A próxima release é 0.12.0, nunca 0.11.1.** O bloco `## [Unreleased]` inteiro é a leva do #105 — não existe "resto do Unreleased" para separar — e ele contém `### Added` (três entradas), `### Changed` com uma chave REMOVIDA do schema (`require_human_approval_before_archive`), e uma marcação literal de BREAKING dentro de `### Fixed`. O CHANGELOG declara SemVer na linha 5. Numerar isso como patch é publicar remoção de chave de schema sob patch, e o adotante que lê a versão decide se lê o changelog. Critério a generalizar: a numeração é lida por quem não vai ler a prosa.

**Correção de registro não vira release própria.** Se você achar contagem errada ou título contraditório, corrija no mesmo PR do trabalho que já vai a develop, nunca num PR de registro que precisa entrar antes do corte — senão a release muda de conteúdo entre a decisão e a execução.

**Não puxe correção nova para dentro de uma leva que já está fechada.** A rodada do #105 tinha 49 arquivos e 20 commits; cada mecanismo a mais é superfície de risco numa entrega que o CI já validou. O lugar do achado tardio é o ledger, e depois um change próprio.

**Sobre o desenho do push do liaison, eu ainda não decidi, e não quero que você decida por mim.** Traga a comparação medida e pare. O que eu já sei: recusar não é errado, e unir não é obviamente certo — a união tem o caso ambíguo da bifurcação real (mesma `(sender, seq)` com `content_sha` divergente), que é onde a recusa é a resposta correta.

=== DoR ===

Antes de escrever qualquer linha, confira que não está refazendo trabalho:

node -e 'const j=require("./.forge/ledger/ledger.json");const t=process.argv[1].toLowerCase();j.entries.filter(e=>(e.title+" "+(e.detail||"")).toLowerCase().includes(t)).forEach(e=>console.log(e.id,e.status,e.title.slice(0,90)))' <palavra-chave>
gh issue list --state all --search "<palavra-chave>" --limit 10 --json number,state,title
grep -rn "<simbolo>" template/.forge/scripts/ tests/ | head
bash template/.forge/scripts/gate-ordinal.sh next --path .

Sobre o ordinal, o DoR e a TAREFA 4 divergiam e eu resolvo aqui: `w196` está LIVRE (a leva anterior pulou de w195 para w197), mas `gate-ordinal.sh next` devolve `w198`, porque ele deriva do máximo remoto e não procura buracos. Vale o script: use `w198`. Reserve sempre pelo script, nunca por inspeção visual: `gate-ordinal.sh next` resolve o remoto pelo CWD e não pelo repositório de `--path` (LDG-0158, aberto) — então rode-o com o CWD dentro deste repositório.

=== TAREFAS ===

A ordem importa e é dura entre 1, 2 e 3: você não pode responder sem ler, não pode publicar sem eu decidir, e o que sair publicado depende da decisão. De 4 em diante a ordem é conveniência.

**1. Abrir a réplica de liaison deste repositório e ler o canal inteiro.**

O forge-harness é participante declarado do canal `forge-harness` e nunca teve `.forge/liaison/`. Inicialize a réplica, sincronize contra `/Users/milton/Documents/projects/.forge-liaison-hub`, e leia — de verdade, com `read`, que avança o cursor — o canal inteiro, priorizando as que têm `requires_ack`. Não trate o número deste prompt como universo fechado: recontagem primeiro, leitura depois. Use `template/.forge/scripts/liaison-ops.sh`; leia `template/.forge/commands/harness/liaison.md` antes.

Armadilhas: o `sync` puxa mas o `_dir_pull` NÃO traz o próprio log de volta, por desenho — não conclua que perdeu mensagem por causa disso. O `ack` só passou a avançar o cursor no PR #105, então nada anterior deixou marca; o reparo documentado é `read <canal> --upto <msg_id>`. E NÃO publique nada do canal por subagente: publicação é serial na sessão principal, senão dois subagentes reservam a mesma sequência.

Delegue a LEITURA a subagentes (é volume: 340 mensagens e blobs), mas eles devolvem ficha, não material bruto — quem lê o canal inteiro é o subagente, quem decide é você.

DoD: `env -u FORGE_ROOT bash template/.forge/scripts/liaison-ops.sh status` deixa de dizer `LIAISON: não inicializado` e passa a mostrar o canal com contagem — esse script resolve o ROOT por `--git-common-dir` e mede a raiz. NÃO use o doctor como DoD aqui: `doctor.sh:44` resolve `ROOT` como `dirname $0/../..`, que é `template/`, então sem `FORGE_ROOT` ele mede `template/.forge/liaison/` (que tem só um `.gitkeep`) e vai continuar dizendo `self=? · 0 canal(is)` depois de você criar a réplica na raiz. Isso não é falha sua: é a terceira polaridade do item 3 da #108, e o lugar dela é o ledger, nesta rodada. Você me entrega uma ficha de no máximo trinta linhas com o que as mensagens de ack pedem, agrupado por assunto, nomeando quais contradizem trabalho que já mergeamos — e a contagem que VOCÊ mediu, com o comando.

**2. Responder a `axis-go-cloud-0086` na thread, com o achado do universo — e PARAR para eu decidir.**

Responda dizendo: qual é o repositório e o commit da quarta versão (é `vellus-tech/forge-harness`, commit `d7d4ad4`, mergeado hoje às 15:15Z — ela pediu a procedência explicitamente e merece a resposta); que o crédito que ela deu ao fail-closed está correto; e que o número de 79% está inflado por universo de varredura, com a medição que VOCÊ acabou de fazer, não com a minha (a minha oscilou de 3 atrasadas para 0 em três horas — o percentual é volátil e o que sustenta o argumento é a partição do universo, não ele) — cerca de 30 réplicas de participante real contra 830 achadas em `maxdepth 9`, das quais 688 vêm de worktrees do `axis-go-cloud` e 128 de worktrees do `Axis.PadSimulator`, incluindo o `axis-device-platform` aninhado e git-excluído.

Diga que o número não anula o argumento de desenho dela, e que a decisão de recusar-contra-unir é minha e está pendente. Não prometa prazo.

Resultado negativo medido é resultado válido: se você remedir e a partição não se confirmar — se as réplicas de participante real também estiverem majoritariamente atrasadas —, diga isso na resposta e me diga a mim, porque nesse caso quem está errado sou eu.

Depois de publicar a resposta, PARE e me traga: a comparação recusar-contra-unir com o caso ambíguo nomeado, o custo de cada caminho em gates a reescrever (o `w195` afirma hoje, como linha vermelha, que push de réplica atrasada é RECUSADO — trocar recusa por união custa reescrever esse gate), e a assimetria que ninguém tinha visto: `tests/w168-liaison-log-merge-union-gate.sh` torna normativo o `merge=union` do driver git para o MESMO log que o transporte fs agora recusa unir. Duas semânticas opostas de reconciliação para o mesmo arquivo, cada uma com gate próprio verde.

DoD: a mensagem publicada e visível em `liaison-ops.sh inbox` do canal, e a ficha de comparação na minha mão. Você não segue para a 3 sem a minha resposta.

**3. Depois da minha decisão: cortar a 0.12.0 pelo fluxo da casa.**

Branch `release/0.12.0` a partir de develop, PR mirando `main` (é a única exceção da org à regra "todo PR mira develop", e é o padrão medido: `761b31e` foi o merge da release/0.11.0 em main, com dois pais (`git cat-file -p 761b31e | grep -c '^parent '` → 2); os PRs de trabalho `#104` e `#105` foram squash em develop, com um pai). Feche `## [Unreleased]` como `## [0.12.0]`, bump em `package.json`, tag em main, back-merge para develop.

Armadilhas medidas: o range do back-merge é `origin/develop..origin/main`, NÃO o inverso — `origin/main..origin/develop` lista só o que develop tem e nunca vê um bump feito em main, então um DoD escrito nessa direção fica verde mesmo com o back-merge pulado. E a contagem de itens de ledger no bloco do CHANGELOG está errada: corrija declarando o método junto do número, ou remova o número.

DoD: `npm view forge-harness version` devolve 0.12.0, `git log --oneline origin/develop..origin/main` vazio depois do back-merge, e `git tag --contains d7d4ad4 | grep v0.12.0` casa.

**4. Um change SDD, red-first, para LDG-0159 e LDG-0160 — que são a mesma classe de defeito, nascida na entrega que prometia acabar com ela.**

LDG-0159: `forge.schema.json` declara `runtime.gates` como `$ref: nullableString`, então o schema ACEITA a forma CSV e REJEITA tanto a forma mapeada quanto a block-sequence de escalares puros — e a documentação que a 0.12.0 vai publicar ENSINA a forma mapeada. Reproduzido com ajv: as duas falham com `/runtime/gates must be string,null`. Alargar para aceitar array é puramente aditivo.

LDG-0160: declarar `phase: pre-deploy`/`post-deploy` tira o gate da contagem de órfãos do doctor, e nada executa esses gates — `wave-ops.sh:161`, o único chamador de produção de `run-gates.sh`, invoca sem `--phase`, e o grep por `--phase` em `template/`, `bin/`, `installer/`, `.github/` não acha chamador nenhum.

Três correções de premissa que a refutação adversarial já pagou por você, e que mudam o desenho:

A chave canônica da forma mapeada é `name:`, NÃO `id:` — `gate-phase.mjs:69` exige `item.name` e descarta em silêncio o item mapeado sem ela. Escrever o schema para aceitar `id:` publicaria um schema que aceita uma declaração que o harness ignora: LDG-0159 invertido, dentro do change que existe para fechá-lo.

O doctor NÃO mente sobre gate de fase. Ele já emite linha própria e dedicada — `· harness: gates: rodam SÓ por runtime.gates (nenhum hook os invoca): check-image-digest check-rollout-health`, em `doctor.sh:472-473`, incondicional para essa classe. E numa instalação stock ele imprime `4 gate(s) órfão(s)`, nunca `0`. Um gate escrito contra a redação "o doctor passa a nomear os dois" nasceria VERDE sobre o defeito. O vermelho verdadeiro tem de ser sobre a ausência de executor, não sobre a ausência de aviso.

Cinco dos treze `FORGE.md` instalados neste Mac JÁ reprovam contra o `forgeFrontmatter` hoje, e nenhum por `gates`: quatro por `/runtime must NOT have additional properties` (`gate_phases` em axis-fare-validator, `dev` em axis-go-cloud, `frontend_*` em Axis.AcqSimulator, `local_only_tests` em Axis.PadSimulator) e o quinto é o dogfood deste repositório, que é deliberadamente mínimo. Qualquer DoD do tipo "estes casos passam a validar" é falso hoje pela raiz e continuaria falso depois de um alargamento correto de `gates` — e uma sessão perseguindo esse verde é empurrada a afrouxar o `required` do schema que vai para todo adotante. Escreva o DoD contra o erro específico de `/runtime/gates`, nunca contra "valid: true".

Ordinal reservado: `w198`, pelo script — não `w196`, ainda que ele esteja livre.

DoD: o vermelho de cada peça colado no PR com a mensagem literal do gate, o verde depois, prova de mutação para cada propriedade nova, e `env -u FORGE_ROOT bash tests/w196-*.sh` verde.

**5. Decidir e encerrar LDG-0131.**

`ff4578a` em `.forge/worktrees/upgrade-safety` tem 9 arquivos e 202 inserções, e toca gate: `tests/w153-upgrade-safety-gate.sh`, com 147 linhas alteradas, além de `bin/forge.mjs`, `doctor.sh`, `source-scan.mjs`. Cuidado com a leitura fácil disso: o `w153` JÁ existe em develop e o commit o REESCREVE (100 inserções, 47 remoções) — não é cobertura nova chegando junto com o código, é um gate preexistente sendo reescrito pelo mesmo commit que muda o comportamento que ele mede, o que é risco maior e não menor. Há ainda 112 remoções no commit, entre elas a deleção de `lib/scan-exclude.sh`, que a própria mensagem sinaliza como não verificada. Pela regra de corte da casa ("o que não tiver gate que o exercite não entra"), ele ENTRA — o que significa que isto é um change sobre o caminho de upgrade, não uma leitura de dez minutos. Decida com esse tamanho na mão: ou vira change SDD próprio nesta rodada ou vira `wont-fix` com o motivo escrito. Não deixe em aberto.

DoD: `LDG-0131` com `status` em `{resolved, wont-fix}` e o motivo no detail nomeando o que foi descartado e por quê — e se for `wont-fix`, o worktree removido no fechamento.

**6. Faxina, e só depois do merge da release.**

Remover o worktree `.forge/worktrees/backlog-attack` e as branches `feat/backlog-attack` (local e remota) — `44f8b44` está integralmente contido no squash `d7d4ad4`, confirmado. Remover `origin/release/0.11.0`, já mergeada. Há ainda `git stash list` com `stash@{0}: On feat/forge-update`, de uma branch que não existe mais, e uma branch local `chore/ledger-decisions` cujo upstream está `gone` — inspecione antes de descartar, e NUNCA use `git stash pop` (a pilha é compartilhada entre worktrees): use `git stash apply <sha>` depois de capturar o sha por `git stash list --format='%H %gs'`.

Corrigir o título do LDG-0010 para nomear LDG-0162. Atenção: o detail do LDG-0010 NÃO cita esse id — diz "item próprio" — então corrija os dois lados, ou o item continua sem elo navegável. `node -e 'require("./.forge/ledger/ledger.json").entries.filter(e=>(e.title+e.detail).includes("0162"))'` devolve hoje só o próprio LDG-0162.

DoD: `git worktree list` com dois itens ou menos, `git branch -r --merged origin/develop` sem resíduo, `git stash list` vazio ou com o conteúdo justificado no relatório.

=== NÃO FAÇA NESTA RODADA ===

Não publique a 0.12.0 antes da TAREFA 2 estar respondida e da minha decisão registrada. É o hard-stop desta rodada.

Não rode `tests/run-all.sh`. São 121 gates sem concorrência, e gate manual durante a suíte gera falha fantasma em gate alheio, com log vazio. Rode gates individuais com `env -u FORGE_ROOT bash tests/<gate>.sh`.

Não exporte `FORGE_ROOT`, nunca.

Não abra change SDD para LDG-0029. A fatia decidida continua sendo corrigir o universo da varredura e remedir — e o achado de hoje sobre as réplicas de liaison é a segunda ocorrência da mesma classe, o que reforça a decisão em vez de mudá-la.

Não entre nas issues #106, #107 e #109 nesta rodada. A #107 já está superada pelo campo e o número do título dela está velho; orçá-la antes de ler o canal seria repetir o erro que esta rodada existe para corrigir.

Não tente o gate de paridade cross-repositório da #101. A recusa se sustenta: o harness não tem universo para varrer.

Não reescreva histórico publicado em `develop` nem em `main`, por nenhum motivo, inclusive para corrigir o título falso do `d7d4ad4`.

Nenhuma linha de coautoria ou geração por IA em commit, PR, issue ou comentário.

E o que a rodada anterior fez certo em NÃO fazer, que eu quero reforçado: não puxou para dentro do PR #105 nem a correção de schema, nem a guarda de flag-como-valor, nem peça alguma da #101 ou da #102, mesmo com o argumento de custo disponível. Mantenha essa recusa.

=== FECHAMENTO DA RODADA ===

Nesta ordem, porque a próxima sessão começa com `/clear` e o que não estiver no disco deixa de existir: ledger primeiro (registre o que achou e o que decidiu, com o método de contagem junto de todo número); liaison depois (publique o que o canal precisa saber, serialmente, na sessão principal); `/forge:handoff`; commit; push.

=== MANDATO ===

Opere em modo yolo até o fim da task list; só retorne no relatório final ou em hard-stop. O hard-stop desta rodada é a TAREFA 2.
GATES: gate não-hard-stop → subagente adversarial (tentar REPROVAR), decisão registrada EXCLUSIVAMENTE por `template/.forge/scripts/approval-log.sh --autonomous --reason "<análise>"`. NUNCA edite approvals.yaml à mão — é artefato de execução. O script recusa por construção qualquer gate em human_hard_stops: se ele recusar, é hard-stop — PARE e reporte, não contorne.
TDD SEM EXCEÇÃO, inclusive em script de shell, hook e infraestrutura de gate: o teste vem antes do código, o vermelho é observado e falha pela razão certa (cole a mensagem), só então o verde, só então a refatoração. PBT para invariante: propriedade sobre entradas variadas, nunca tabela de casos. Regressão anti-mutante para todo defeito E para toda propriedade nova, provada removendo a linha que a sustenta e vendo o teste falhar pela razão certa; reverta por `git checkout`, nunca por edição inversa, e commite ANTES de mutar. Guarda textual não prova comportamento.
ASSERÇÃO NEGATIVA NÃO PROVA NADA SOZINHA: toda asserção da forma "o mecanismo não produz X" é satisfeita trivialmente por um harness em que o mecanismo não existe. Pareie sempre com uma positiva observável que só existe depois da correção (`fh#LDG-0150`).
VERMELHO DECLARADO É VERIFICADO ANTES DE VIRAR DoD: rode o comando do vermelho ANTES de escrever o gate. Três DoD desta análise foram derrubados por já estarem verdes no estado defeituoso.
EVIDÊNCIA: SHA carimbado ANTES da suíte; contagem com o comando que a produziu, e o método de contagem declarado junto do número; artefato de execução é imutável — corrigir = reexecutar.
UNIVERSO ANTES DE PERCENTUAL: nenhum número que dimensione problema vale sem o universo da varredura declarado. Duas vezes neste programa o número estava dominado por subárvore que não devia estar lá — `fh#LDG-0029` (69 de 77 sítios vindos de repositório aninhado git-excluído) e a medição de réplicas de liaison de hoje (830 contra 30, a diferença toda em worktrees).
MÁQUINA: nunca `--no-verify` e nunca `-c core.hooksPath=/dev/null` ou equivalente — desviar o caminho dos hooks é burlá-los. Nada de `sleep`/polling em foreground. TODA suíte pesada roda por `template/.forge/scripts/heavy-run.sh`; EXCEÇÃO MEDIDA: script que já adquire o mutex por conta própria NÃO se envolve em `heavy-run.sh` — mesmo `LOCK_PATH`, o filho encontra vivo o PID do pai e trava por deadlock estrutural.
GIT: `git -C <path absoluto>` sempre; `git add` só com paths explícitos; commit antes de mutar. NUNCA `git stash pop` — a pilha é compartilhada entre worktrees e outra sessão pode estar usando; use `git stash push -u -m "<tag>"`, capture o sha e restaure com `git stash apply <sha>`.
SUBAGENTES — DELEGUE POR DEFAULT: sua janela serve para DECIDIR, não para armazenar material. Todo trabalho de volume — ler as 340 mensagens do canal, varrer histórico, triar o ledger — vai para subagente, que devolve a conclusão mais a evidência mínima que a sustenta, nunca o material bruto. Model explícito SEMPRE, nunca herdado: `haiku` para bite-sized com instrução pequena e clara; `sonnet` para módulo, integração e debugging; `opus` effort high para gate, revisão crítica e prova adversarial. Cada subagente recebe DoR e DoD próprios e autoverifica com teste real antes de retornar. Subagente nunca publica no liaison — publicação é serial na sessão principal, senão dois reservam a mesma sequência. Relatório de subagente NÃO é verdade: valide com teste real e confira o commit no `git log` antes de dar a task por feita.
IDENTIFICADORES: reserve antes de usar (`gate-ordinal.sh next`, com o CWD dentro deste repositório por causa do `fh#LDG-0158`) e releia na fonte antes de citar; ao citar LDG de outro repositório, escreva `<repo>#LDG-NNNN`.
RETORNO: relatório único no fim.

=== RETORNO ESPERADO ===

Um relatório só, no fim, na ordem das tarefas:

1. A ficha do canal: o que as mensagens de ack pedem (com a sua contagem, não a minha), agrupado por assunto, e quais contradizem trabalho já mergeado.
2. A mensagem publicada em resposta à `axis-go-cloud-0086`, e a comparação recusar-contra-unir com o caso ambíguo nomeado e o custo em gates a reescrever. (Você terá parado aqui uma vez.)
3. A 0.12.0: versão no npm, tag, back-merge provado na direção certa.
4. O change de LDG-0159 e LDG-0160: vermelho de cada peça com a mensagem literal, verde, prova de mutação.
5. LDG-0131: decisão e motivo.
6. Faxina: o que saiu e o que ficou, com justificativa para o que ficou.

E, no fim, o que a sua medição contrariou do que eu escrevi aqui. Se alguma medição minha estiver errada, diga com o comando que prova — a rodada anterior me corrigiu três vezes com medição (o `develop` default, o `machinery.lock` que existe e eu disse não existir, e a forma certa de fechar o LDG-0154), e as três vezes o certo era você.
```

========================= prompt =========================
