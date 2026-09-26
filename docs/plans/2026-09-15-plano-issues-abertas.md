# Plano de correção — issues abertas e ledger do forge-harness (R02 com adendo de 2026-09-25)

> R02: 2026-09-15 · Base: `origin/develop` @ `821178e` (0.15.0), que não se moveu até 2026-09-25 · Universo remedido em 2026-09-25: `gh issue list --state open` (42 issues: as 36 do R02, #101–#153, mais #155–#160) e as 29 entradas não encerradas de `.forge/ledger/ledger.json` deste ramo.
> Progresso medido por `node tools/plan-progress.mjs --plan docs/plans/2026-09-15-plano-issues-abertas.md`, nunca por marcação manual neste documento. O placar lê o ledger da árvore em que roda, então é executado no worktree do ramo.

## Sumário executivo

As 36 issues abertas do R02 reproduzem, total ou parcialmente, em `821178e`; nenhuma está inteiramente corrigida. Todos os vermelhos citados nas seções do R02 foram executados contra `821178e` nos clones `/tmp/fh-tri-A` e `/tmp/fh-tri-B` em 2026-09-15, e as linhas coladas são saída real dessas execuções. As bancadas ficaram em `/tmp/fh-R02-*.sh` e `/tmp/fh-A-*.sh` (efêmeras); o comando essencial de cada vermelho está escrito na seção da issue para ser reconstruído no PR. As seções acrescentadas pelo adendo (#155–#160, LDG-0181, LDG-0153, LDG-0182 e a dívida interna) dizem, cada uma, o que foi medido em 2026-09-25 e o que fica para o implementador medir contra a base.

A ordenação continua por dano a terceiros, decisão do dono, e desde o adendo cada onda pertence a um bloco de release. A Onda 0 (Bloco 0) conserta a régua da suíte. As Ondas 1 e 2 (Bloco A, 0.16.0) cobrem o que o `forge update`, o gerador de adapters e o hook do tronco desarmam, apagam ou bloqueiam na árvore de quem instalou o harness, e as ferramentas que destroem trabalho do consumidor com rc 0. A Onda 3 (Bloco B, 0.17.0) cobre o que trava o trabalho dele e o runner do template que não distingue morto de reprovado; a Onda 4 (Bloco C, 0.18.0), o que passa verde sem medir; as Ondas 5 e 5b (Bloco D, 0.19.0), prosa, contrato de agente e interface; a Onda 7 (Bloco E), a dívida interna. A Onda 8 (Bloco F) lista, sem implementar, o que fica fora desta rodada. Não existe Onda 6: a do R02 foi apagada e o número não foi reaproveitado, para que as referências do R02 às Ondas 1 a 5 continuem valendo.

Planos anteriores foram usados como insumo, não como base: os spikes `docs/plans/spikes/backlog-onda-l1..l6-*.md` têm decisões fechadas que reaproveito onde ainda valem, e cada seção diz o que foi reaproveitado e o que mudou. A mudança mais importante em relação a eles é o critério de decisão do dono: onde o spike escolheu o comportamento mais forte (parar o update, recuperar posse de dono vivo por padrão, recusar regeneração), este plano implementa o default conservador retrocompatível e registra a promoção como item de roadmap na Onda 8, com a decisão escrita nas seções "Decisões do dono" e "Decisões autônomas".

## Adendo de 2026-09-25

O R02 continua sendo a base, porque `origin/develop` não se moveu desde `821178e`. O adendo incorpora as correções das duas revisões adversariais do plano de execução de 2026-09-25 (achados J-01 a J-28 do juiz; sobreviveram 2 BLOCKER, 15 MAJOR e 11 MINOR) e as decisões registradas abaixo. Ele não é um apêndice: as ondas foram reescritas no lugar, e esta seção diz o que mudou e por quê.

### O que mudou em relação ao R02

Onda passou a ser bloco de release, e a seção "Onda 6" do R02 foi apagada junto com a regra de não editar o ledger: toda entrada de ledger não encerrada está agora em exatamente uma onda (0, 1, 3, 4, 7 ou 8), e as entradas já resolvidas não aparecem em negrito. A #141 saiu da Onda 3 para a Onda 1, como primeira da cadeia do `pre-push` (J-07). A #123 continua na Onda 2, como última do Bloco A, e a dependência #133 → #123 fica declarada como branda: o axis-device-platform tem `fs-union` local em `liaison-config.mjs`, divergente do lock e sem exceção declarada, com 3 canais em uso, e a sobrescrita nomeada da 0.16.0 derrubaria esses canais se o template não trouxesse o kind no mesmo release (medição na seção da #123). A issue nova #160 (o gerador apaga chaves de topo de `.claude/settings.json`, J-08) entra na Onda 1 entre a #130 e a #125, com o LDG-0189 no mesmo PR. Desvio em relação ao item 3 do Bloco A do plano v2, que diz que o gerador "só é dono dos blocos que referenciam `.forge/hooks/`": aqui a posse é por igualdade de string com o universo de emissão do gerador, porque a regra por menção apagaria os três comandos `dispatch-file-hook.sh` e os dois ganchos autorais do axis-fare-validator (seção da #160); o detail do LDG-0189, que repetia a regra por menção, foi corrigido por nota. A #157 entra na Onda 3 logo depois do LDG-0181 (J-05), e as #155, #156, #158 e #159 formam a Onda 5b com caminhos reais (J-20).

Cada "Pergunta ao dono" do R02 virou referência a uma decisão numerada (DH-n humana, DA-nn autônoma), e as decisões que mudam desenho foram aplicadas no texto da seção: #101/#131 (gramática do consumidor, J-13), #125 (três manifestos, aviso em vez de reprovação, J-11), #139 (legado, J-14), #144/#137 (beneficiário por ambiente e valor declarado respeitado, J-06, J-12), #150 e #109 (passam a `Closes`), #108 e #140 (Arquivos completos), #123 (`check-liaison-acks.sh`, J-15) e #153 (controle de consumidor recém-criado, J-25). O vermelho da #125 não traz mais o literal da chave AWS de exemplo que o gate de segredos do CI reprovou no PR #154; o payload é descrito e montado em tempo de execução.

A tabela de ordem de merge foi reconciliada com os blocos (J-04) e conferida mecanicamente; os ordinais novos vão de w238 a w246, atribuídos à mão e conferidos contra todos os refs; o censo de consumidores foi refeito (J-11); e o protocolo por PR ganhou os comandos que o plano de execução exige, inclusive o que prova que o commit do vermelho só tem teste (J-22).

| Onda | Bloco | Release | Itens (em negrito só na seção da onda) |
|---|---|---|---|
| 0 | 0 — régua | 0.16.0 | LDG-0182 |
| 1 | A — dano ao consumidor | 0.16.0 | #101, #131, #130, #160, LDG-0189, #125, #142, #141 |
| 2 | A — dano ao consumidor | 0.16.0 | #120, #139, #107, #123 |
| 3 | B — o que trava | 0.17.0 | #132, #134, #135, #144, #137, #146, #127, #129, LDG-0181, #157 |
| 4 | C — verde sem medir | 0.18.0 | #119, #106, #138, #150, #128, #133, #103, #108, #109, #117, #149, #153, LDG-0153 |
| 5 | D — prosa e contrato | 0.19.0 | #126, #136, #145, #140, #151, #152 |
| 5b | D — prosa e contrato | 0.19.0 | #155, #156, #158, #159 |
| 7 | E — dívida interna | 0.19.x ou 0.20.0 | LDG-0171, LDG-0183, LDG-0158, LDG-0167, LDG-0173, LDG-0176, LDG-0161, LDG-0152, LDG-0157, LDG-0188, LDG-0100 |
| 8 | F — fora desta rodada | — | LDG-0008, LDG-0010, LDG-0029, LDG-0162, LDG-0021, LDG-0065, LDG-0178, LDG-0160, LDG-0151, LDG-0140, LDG-0184, LDG-0185, LDG-0186, LDG-0187 |

São 42 issues e 29 entradas de ledger, cada uma em exatamente uma onda. As entradas LDG-0163, LDG-0180, LDG-0175 e LDG-0164, que o R02 listava na Onda 6, foram remedidas e resolvidas na Fase 0 e por isso não aparecem em nenhuma onda.

### Estado da Fase 0 em 2026-09-25

Itens 1 a 3 do plano de execução, feitos neste ramo (`fedf6be`..`b4505c2`): o LDG-0183 foi transferido do checkout principal (em `main`) para este worktree pelo procedimento `apply --index --check` → `apply` → `cmp` → render → commit, e só depois restaurado em `main`. Desvio declarado: o `cmp` antes do restore foi local, entre o ledger de `main` e o do worktree, e não contra `origin/docs/plan-issues-abertas`, porque o push cabe ao orquestrador; o plano v2 pede o `cmp` contra o ref remoto antes do restore, e ele é feito logo depois do push (`git -C <wt> show origin/docs/plan-issues-abertas:.forge/ledger/ledger.json | cmp - <wt>/.forge/ledger/ledger.json`, com o conteúdo do LDG-0183 igual ao transferido). Não houve perda, porque o objeto está no store compartilhado. As notas de correção do LDG-0183 registram que o resolvedor certo é `forge_worktree_root`, não `forge_resolve_root` (J-01), e que o `created_at` é a data do commit HEAD no momento do `add` (`ledger-ops.sh:20` e `:118`), feito em `main` em 2026-09-15 com HEAD em `22a3d9d`, e não um efeito da transferência. LDG-0163 (w198 rc 0, com o residual `--repair-own-log` remetido ao LDG-0188), LDG-0180 (`5a796a8`, w212 27/27), LDG-0175 e LDG-0164 foram resolvidos com a saída do gate colada na nota. A evidência do LDG-0175 foi corrigida por duas notas. A segunda substitui a primeira no ponto da prova: o `cp -R` do w146 [5] (`w146:82`) existe desde `efe99e9` (2026-08-20), antes do incidente de 2026-09-07, e não é correção; a causa exata do incidente não foi identificada; a cobertura da classe vem de `5a796a8`, com a conversão dos 6 gates que mutavam arquivo rastreado sob trap (w199, w203, w207, gate-assert-visibility, w201 e w211), a trava estática do w213 contra o idioma antigo e a sentinela `template/.forge/scripts/lib/arvore-rastreada.sh` nos dois runners (`tests/run-all.sh:80`, `template/.forge/scripts/tests/run-all.sh:46`), com o w213 em 8/8, em particular [6] e [7]; e `1c82c73`, citado na nota de resolução, é commit squashado sem ref (`git for-each-ref --contains 1c82c73` vazio), com `5a796a8` como carimbo de entrega. A primeira nota registra a DA-25 com a condição de reabertura. A do LDG-0164 também: a instância original é o w195 [11] (`w195:430`), e a tabela por arquivo das 105 ocorrências em 32 arquivos está na nota, com as 94 invocações entre aspas simples (uma com `$`, o `$ENV{CAP}` legítimo de `w100:50`) e as 11 entre aspas duplas conferidas à mão, 0 casos da classe. Foram criados LDG-0184 a LDG-0187 (lados fortes descartados, roadmap), LDG-0188 (J-27) e LDG-0189 (J-08), e aberta a issue #160. O detail de LDG-0184 a LDG-0187 foi corrigido por nota para coincidir com DH-1, DH-3 e DH-5, separar no LDG-0184 a exceção expirada da preservação por deriva e usar no LDG-0187 o censo de 181 worktrees em 7 consumidores, das quais 164 têm leitor que não aceita `fs-union`. O item 4 (decisões) está registrado nas duas seções de decisões abaixo; os itens 5 e 6 são este adendo. Pendentes: item 7 (liaison: leitura das threads sobre update, hooks e mutex; thread do LDG-0178; avisos prévios à 0.16.0) e item 8 (revisão adversarial do adendo em clone descartável e merge do PR #154 em develop). Antes do merge do PR #154, o orquestrador faz o push, roda o `cmp` do ledger contra `origin/docs/plan-issues-abertas` descrito acima e confere `gh pr checks 154` com o check `gates` verde, e registra as duas saídas no corpo do PR. O check estava vermelho no último push (`ab19600`, run 35040159153, `FAIL [15]` do w139 com `WARN secrets/provider-token — 1 ocorrência`), antes da remoção do literal feita neste adendo.

### Censo de consumidores (corrigido, J-11)

O R02 contava quatro consumidores e 176 worktrees com `_common.sh`, 146 sem a união. Remedido em 2026-09-25, somente leitura, com `find /Users/milton/Documents/projects -path '*/.forge/scripts/lib/transports/_common.sh' -path '*worktrees*'` e o predicado por nome `_dir_push_union`: são 181 worktrees com `_common.sh` em 7 consumidores, e 139 delas sem a união. O mesmo `find` casa também as 2 worktrees do próprio forge-harness (pelo caminho `template/.forge/...`), excluídas da contagem. Das 181, 17, todas do axis-device-platform, têm `liaison-config.mjs` que aceita o kind `fs-union`, e 164 não aceitam (predicado `grep -q "'fs-union'"` no `liaison-config.mjs` vizinho).

| Consumidor | Worktrees com `_common.sh` | Sem `_dir_push_union` |
|---|---|---|
| azim-crm | 84 | 84 |
| axis-device-platform (aninhado em axis-go-cloud) | 32 | 29 |
| Axis.PadSimulator | 30 | 23 |
| axis-go-cloud | 24 | 2 |
| lionclaw | 9 | 0 |
| axis-fare-validator | 1 | 1 |
| vellus-enterprise-ai-platform | 1 | 0 |
| total | 181 | 139 |

Há três `hooks.manifest` em campo, em esquemas diferentes: axis-fare-validator, Axis.PadSimulator e axis-device-platform (este criado em `cec1a73`, com o campo 3 `stdin-json:tool_input.file_path+content` fora de `CONTRATOS_V1`). O axis-device-platform tem também `transports/fs-union.sh` próprio, com `fs-union` em `TRANSPORT_KINDS` e 3 canais em uso, no mesmo caminho que a #123 cria. No disco desta máquina há 17 árvores com `.forge/forge.yaml` fora de worktrees (medido com `find ... -maxdepth 4 -path '*/.forge/forge.yaml' -not -path '*/worktrees/*'`), mas só as 7 acima têm worktrees com a maquinaria de liaison; o ensaio de campo de cada release cobre as 7 e o vellus, única árvore com chaves de topo autorais no `settings.json`.

### Regra transversal de escrita no ledger e no liaison

Toda escrita por `ledger-ops.sh` ou `liaison-ops.sh` desta rodada roda dentro do worktree do PR, com `FORGE_ROOT="<abs do worktree>"` prefixado só naquela invocação e nunca exportado. Depois de cada escrita, `git -C <worktree> diff --stat -- .forge/ledger .forge/liaison` precisa mostrar a mudança e `git -C /Users/milton/Documents/projects/forge-harness status --porcelain -- .forge/` precisa sair vazio. Só um escritor de ledger por vez: a Fase 0 e o PR de reconciliação de cada bloco. É exceção de dogfood à norma `machinery-propagation.md:19`, registrada como DA-07; a norma não muda. Todo item de ledger criado durante a rodada entra em negrito na onda correspondente no mesmo PR que o cria, senão o placar sai rc 1 com o item órfão.

## Invariantes de execução

Vermelho antes do verde: o implementador escreve o gate inteiro, executa-o contra a base do PR, cola a falha no corpo do PR e só então toca a produção. Um vermelho que já passa no estado defeituoso reprova o PR.

Asserção negativa nunca sozinha: todo "não produz X" vem pareado com uma asserção positiva observável que só existe depois da correção, no mesmo cenário.

Prova de mutação com controle e recontrole: a mutação é aplicada, o gate é observado falhando no cenário nomeado, o arquivo é restaurado byte a byte (`cmp -s`) e o gate volta a passar. Mutação por `perl` com aspas simples, nunca com `$` do lado direito interpolado (LDG-0164).

Ordinais `wNNN` são atribuídos pelo orquestrador na tabela de ordinais, à mão e conferidos contra todos os refs, nunca por `gate-ordinal.sh next` isolado (LDG-0167, LDG-0173). Todo PR que cria gate atualiza o badge `gates-N` do README na mesma mudança (w200). Todo PR que toca `template/.forge/commands/` roda `npm run build:plugin`. Um PR por issue, salvo causa raiz comum provada por arquivo:linha na seção; `Closes #N` só no PR que fecha título e corpo inteiros.

## Protocolo por PR

1. Worktree próprio a partir de `origin/develop`, conferido com `cd <abs> && pwd && git branch --show-current` antes de qualquer escrita.
2. Medir antes: `git log origin/develop -- <arquivos do item>` e o vermelho da seção contra a base atual.
3. Commit RED só com teste, com o sha declarado no corpo do PR (a lição da #156 aplicada ao próprio plano). O orquestrador, nunca o subagente, roda: `git diff --name-only $(git merge-base origin/develop $RED) $RED | grep -vE '^(tests/.+|README\.md|CHANGELOG\.md)$'`, com saída vazia (o filtro aceita arquivo novo em todo `tests/`, inclusive `tests/fixtures/`, `tests/snapshot/` e `tests/validators.bats`, porque o vermelho de #101/#131, #125 e #160 traz fixture real); `git diff --name-only $(git merge-base origin/develop $RED) $RED -- tests/run-all.sh`, com saída vazia, porque o runner é instrumento da suíte e mudança nele vai no commit verde; `git diff --diff-filter=MDR --name-only $(git merge-base origin/develop $RED) $RED -- tests/ | grep -vxF tests/wNNN-<slug>-gate.sh`, com saída vazia, ou seja, o único arquivo existente de `tests/` que o RED altera, apaga ou renomeia é o gate do próprio item, e qualquer outra linha dessa saída exige justificativa escrita por arquivo no corpo do PR (o LDG-0182, que converte os `! cmd` nus de 14 gates existentes, é o caso previsto); o gate num worktree destacado em `$RED`, com rc≠0 e `FAIL [n]` do cenário nomeado; `git diff --quiet $RED HEAD -- tests/wNNN-*.sh`, ou justificativa escrita no PR; o gate em HEAD, com rc 0; e a mutação com `cmp -s` de controle e recontrole. O squash não apaga o RED, que continua em `refs/pull/N/head`. Fixture copiada de consumidor real é sanitizada antes do commit, porque o repositório é público (`gh repo view --json visibility` → `PUBLIC`): caminho absoluto de máquina, nome de host, e-mail, token e qualquer valor de `env` saem ou viram marcador, e o PR registra o que foi trocado. Nenhum padrão de segredo entra como literal, nem em fixture nem em semente de PBT; a auto-varredura do w139 [15] reprova o repositório inteiro por qualquer achado (seção da #125).
4. Toda mudança de interface entre `hooks/git/*` (tronco) e `scripts/lib/*` (worktree ou preservado por exceção) traz cenário de versão mista (J-06). Vale para #144/#137, #138, #125, #141 e LDG-0152.
5. Suíte completa sozinha na máquina (nenhum gate manual em paralelo), e depois `git status --porcelain -- template/` vazio.
6. `npm run build:plugin` quando tocar `template/.forge/commands/`, e `bash tests/w200-readme-inventory-gate.sh` rc 0 no SHA final depois de `git merge origin/develop`. Desenvolvimento paralelo, merge serial: `develop` tem `strict: true` e o check `gates`, que já serializa o merge (J-21).
7. Revisão por subagente opus instruído por `template/.forge/agents/review/code-evaluator.md` sobre o SHA final, declarada no PR como emulação, nas condições de DA-08: só segue com APPROVED ou APPROVED_WITH_COMMENTS, sem BLOCKER ou HIGH abertos; teto de 3 iterações com escalada ao dono na 3ª; depois de rebase, re-revisão do delta via `git range-diff`.
8. `bash template/.forge/scripts/check-ai-attribution.sh range origin/develop..HEAD` e `... text <corpo-do-PR>`, com rc 0 colado no PR. Nenhum trailer de sessão ou de atribuição, inclusive os injetados pela ferramenta.
9. Merge com `gh pr merge --squash` só depois do check `gates` verde, sem `--admin`, registrado como decisão autônoma (DA-08); nunca como decisão humana e nunca por `approval-log`.
10. `Closes #N` só quando título e corpo estão inteiramente fechados; nos demais, `Refs #N` e fechamento manual com comentário que aponta o resíduo rastreado (DA-19 a DA-24).
11. Ledger só no PR de reconciliação do bloco, com `FORGE_ROOT` inline (regra transversal acima). PR de código nunca chama `ledger-ops.sh`: `add` aloca o id como máximo local mais um (LDG-0167), e dois PRs do mesmo bloco desenvolvidos em paralelo alocariam o mesmo id e conflitariam em `ledger.json`. O PR de reconciliação do bloco é o único escritor de ledger do bloco e roda depois do último PR de código dele: resolve os itens de ledger que o bloco entregou, com a saída do gate na nota; cria, em sequência e um por vez, os itens derivados das decisões autônomas cujas issues de origem fecham no bloco (lista na Onda 8); põe cada id novo em negrito na onda de destino no mesmo PR; e roda o placar com rc 0 antes do merge. Só depois do merge dele as issues com `Refs` do bloco são fechadas à mão, com comentário que cita os ids criados.
12. Checkpoint por PR: placar (`node tools/plan-progress.mjs --plan ... --wave <n>`) e memória.

O Bloco 0 não tem release própria: compartilha a 0.16.0 com o Bloco A. O PR de reconciliação do Bloco 0 roda logo depois do merge do PR do LDG-0182 e antes do primeiro PR de código do Bloco A, resolve o LDG-0182 com a saída do w80 e cria o item do lote restante de `! cmd` nus na Onda 7; o PR de reconciliação do Bloco A roda depois dele, e a sequência abaixo vale para o conjunto 0+A a partir do último PR de código do Bloco A. Release de cada bloco, nesta ordem: último PR de código do bloco; PR de reconciliação do bloco (item 11); fechamento manual das issues com `Refs` do bloco, citando os ids criados; ensaio de campo; PR develop→main, tag, `npm publish` com `.npmrc` temporário, back-merge main→develop, `git diff --quiet origin/main origin/develop` rc 0, mensagem de liaison "X.Y.Z publicada: risco por arquivo" enviada com `FORGE_ROOT` inline no worktree do release, a mesma nota no CHANGELOG e no PR de release para os consumidores fora do canal (azim-crm, lionclaw, vellus, collatra), e só então o bloco seguinte. Antes de cada release, ensaio de campo em clone descartável de cada consumidor real, com `.forge/cache/machinery.lock` copiado e `node bin/forge.mjs update --target <clone> --no-plugin` a partir do tarball de `npm pack`: zero `SOBRESCRITO` não aceito por escrito, chaves de topo do `settings.json` iguais antes e depois, e a suíte do consumidor rodada e triada (J-09). Apagar branch remota continua exigindo o dono.

## Decisões do dono

Cinco decisões humanas, tomadas antes do plano de execução e mantidas sem mudança. Cada lado forte descartado virou item de roadmap na Onda 8 com a condição mensurável de promoção.

**DH-1** · #101/#131 · exceção expirada preserva o arquivo e imprime `EXCEÇÃO EXPIRADA` com os dois shas, rc 0; `scripts/` não ganha preservação por deriva decidida por lock. Lado forte: LDG-0184.

**DH-2** · #125 e LDG-0178 · o esquema canônico da camada do consumidor para `hooks.manifest` aguarda a thread de liaison com axis-fare-validator, Axis.PadSimulator e axis-device-platform. Até lá, a fiação derivada lê só o que o w208 já lê, e o LDG-0178 fica na Onda 8.

**DH-3** · #142 · o nome default do recurso do heavy-mutex é mantido, e o update imprime a linha nominal `heavy_mutex: recurso resolvido`. Lado forte: LDG-0186.

**DH-4** · #123 · `fs-union` entra como kind opt-in, sem recomendação ativa aos consumidores. Lado forte: LDG-0187.

**DH-5** · #137 · teto de posse opt-in, sem default derivado da metade da espera. Lado forte: LDG-0185.

| Issue | Questão fechada pelo dono | Custo medido do lado forte |
|---|---|---|
| #123 | recomendar `fs-union` aos consumidores | 181 worktrees em 7 consumidores têm `_common.sh`, 139 delas sem `_dir_push_union` (censo do adendo; o R02 contava 176/146 em quatro); 164 das 181 têm `liaison-config.mjs` que não aceita `fs-union` e param de sincronizar até atualizar, se o tronco trocar o kind |
| #125 | esquema canônico da camada do consumidor (LDG-0178) | três esquemas em produção (axis-fare-validator, Axis.PadSimulator e axis-device-platform) |
| #101/#131 | parar o update em exceção expirada; preservar `scripts/` por deriva | L1 mediu 5 de 6 árvores com `pre-push` divergente do lock, que seria preservado e deixaria de receber correção |
| #137 | teto de posse ligado por padrão | com o default derivado, todo consumidor passa a ter dono vivo encerrado depois de 900 s de posse |
| #142 | nome default do recurso | axis-fare-validator declara `axis-heavy-suite` e axis-go-cloud `forge-heavy-suite`; trocar o default reparticiona quem está no default |

## Decisões autônomas (yolo-gate, Opus effort high, 2026-09-25)

Decididas pelo agente yolo-gate (Opus, effort high) por autorização do dono para o modo yolo em 2026-09-25, sempre com o default conservador. São autônomas, nunca humanas: nenhuma vai para `approval-log`, e o dono pode revertê-las. Falha de execução, BLOCKER, teste vermelho e conflito de normas continuam parando o loop.

**DA-01** · autonomous · LDG-0181, mapa de rc e piso de vacuidade. Decisão: no runner do template, 0 verde, 1 reprovação (com precedência), 3 não verificado (sinal 129–192, 126/127 dependência ausente, árvore não medida), e 64/66 continuam uso e diretório, sem renumerar; o ramo de falha deixa de reexecutar o alvo e imprime o tail do log da primeira execução; o piso de vacuidade do template continua 0 (zero arquivos dá rc 0 e a linha `nada a rodar`); no runner interno o piso passa a 1 (zero gates dá UNV e rc 3, com asserção nova no w212). Motivo: `template/.forge/scripts/tests/run-all.sh:30` sai 64, `:33` sai 66 e `:124` já sai 3 para árvore não medida, e o 3 do runner interno (`tests/run-all.sh:271`) tem a mesma semântica, então o mapa converge sem colisão; `:91` reexecuta o alvo, que é a morte dupla do detail; o template distribui o runner com zero testes e o `pre-push` o roda (`pre-push:476-478`) bloqueando em qualquer rc≠0, então piso ≥1 no template bloquearia o push de todo consumidor stock; o interno sai rc 0 com a árvore vazia (`tests/run-all.sh:272`), que é o buraco que o próprio item nomeia. Retrocompatível: nos dois runners o 3 bloqueia como o 1.

**DA-02** · autonomous · LDG-0160 vai para a Onda 8, como change próprio via `/forge:spec new`. Motivo: fechar exige decidir quem agenda as fases pre-deploy e post-deploy, em que momento e com que artefato; não há `deploy.sh`, e o doctor já nomeia os gates órfãos (`doctor.sh:472-473`), então não há mentira ativa nem correção retrocompatível barata.

**DA-03** · autonomous · LDG-0151 vai para a Onda 8, com decisão por chave num change próprio. Motivo: o detail pede exatamente isso e alerta para risco de retrocompatibilidade desproporcional; remover chave de schema quebra consumidor que a declare, e a falta de leitor de default é inofensiva, ao contrário de enforcement falso.

**DA-04** · autonomous · LDG-0140 (segunda metade: harvest com detail vazio) vai para a Onda 8. Motivo: o detail diz que fechar é decisão de produto, porque o harvest é best-effort e nunca falha o caller; a primeira metade já foi entregue (w194 [9]-[12]).

**DA-05** · autonomous · LDG-0173 entra na Onda 7 só na parte sem custo de contrato: `next` continua devolvendo o mesmo número e o mesmo rc, e passa a imprimir em stderr um WARN que nomeia os ordinais maiores ou iguais ao devolvido já presentes em outras refs `origin/*`. Mudar o universo que define o número, ou criar registro de reserva, vai para a Onda 8. Motivo: `gate-ordinal.sh:16-25` documenta a derivação pelo tronco remoto, o detail diz que mudar o universo tem custo de contrato para adotante porque o script viaja no tarball, e um WARN aditivo em stderr não altera stdout nem rc (`:28-29`) e mata a descoberta tardia medida (w206 já tomado).

**DA-06** · autonomous · #137 e #144, `stale_after_s` declarado pelo Axis.PadSimulator. Decisão: respeitar o valor declarado pelo consumidor e emitir WARN com os três números (declarado, espera, reserva), sem rebaixar; a invariante de L2 D4 vira aviso quando o valor vem declarado; o gate usa os valores reais 1800/3600 e o cenário de versões mistas sobre o mesmo lock; o aviso prévio à 0.16.0 recomenda ao PadSim declarar exceção para `scripts/lib/heavy-mutex.sh`. Motivo: o PadSim declara `timeout_s 1800` e `stale_after_s 3600` com a justificativa "o dobro do teto de espera" (J-12); rebaixar encerraria antes de 1800 s um dono vivo que o consumidor declarou poder durar 3600, mudança silenciosa de semântica em dado declarado. DH-5 (teto opt-in) não cobre o rebaixamento.

**DA-07** · autonomous · exceção de dogfood: `ledger-ops.sh` e `liaison-ops.sh` escrevem no worktree do PR com `FORGE_ROOT` inline, restrita a este repositório e a esta rodada, nas condições da regra transversal acima; a norma não muda. Motivo: `machinery-propagation.md:19` exige ledger no tronco para evitar colisão de merge entre branches, mas aqui o tronco está em `main` (`ledger-ops.sh:109` usa `forge_resolve_root`, que resolve para o tronco segundo `forge-root.sh:35-38`) e o fluxo vai por PR para `develop`; escrever no tronco deixaria as resoluções fora de qualquer PR (J-02, reproduzido; o LDG-0183 nasceu assim). Com um escritor por vez, a colisão que a norma previne não se materializa, e a exceção é reversível e não altera maquinaria distribuída.

**DA-08** · autonomous · revisão por emulação do code-evaluator no lugar do `/forge:ship` literal, com decisão autônoma no lugar do aceite do dono, nas condições do protocolo por PR (itens 7 a 9): emulação declarada no PR sobre o SHA final; só APPROVED ou APPROVED_WITH_COMMENTS sem BLOCKER ou HIGH abertos; teto de 3 iterações com escalada ao dono na 3ª; re-revisão do delta depois de rebase; `check-ai-attribution.sh range` e `text` com rc 0 colados no PR; `gh pr merge --squash` só com o check `gates` verde e sem `--admin`; registro como "forge-yolo (opus, high)", nunca como humano e sem `approval-log`; o PR registra que o code-evaluator canônico está indisponível no dogfood (`ship.md:65`). Cobre só o merge em develop; promote e publish seguem a autorização de releases do dono. Motivo: não há code-evaluator registrado nem `core.hooksPath` ativo (`git config --get core.hooksPath` → rc 1), `ship.md:65` proíbe substituir por revisão manual e manda registrar a indisponibilidade, o dono atribuiu esta decisão ao yolo-gate, `autonomy-yolo.md` declara o merge para develop yolo-able, e as condições mantêm todas as barreiras mecânicas.

**DA-09** · autonomous · #120: não recusar handoff sem marcadores; mantém o desenho do R02 (backup byte-idêntico em `<git-dir>/forge-backups`, com o git-dir resolvido por `git rev-parse --git-dir` como em `bin/forge.mjs:596`, WARN nominal, rc 0). Recusa opt-in e alinhamento do `/forge:handoff` aos marcadores viram roadmap na Onda 8. Motivo: `handoff-gen.sh` é chamado pelo `/forge:handoff` e pelo hook de sessão esperando rc 0 (w62); o backup já torna os bytes anteriores recuperáveis, e a PBT da seção prova isso.

**DA-10** · autonomous · #132/#134: sem política própria para deleção de ref protegida nesta rodada; o curto-circuito de deleção pura vale para qualquer ref, e a política vira roadmap na Onda 8. Motivo: os checks pulados (typecheck, test, gates, harness-tests; `pre-push:324-325`, `:431`, `:478`) são checks de árvore que nunca impediram deleção; proteção de ref é server-side (`develop` com `strict: true` e o check `gates`); política nova no hook seria contrato novo com o consumidor.

**DA-11** · autonomous · #135: nenhum default de teto para `FORGE_PREPUSH_CHECK_TIMEOUT_S`; ausente significa desligado. Motivo: a própria #135 mede suítes legítimas de consumidor acima de 8 minutos (4 testes, cerca de 470 s), e reusar os 300 s de `forge_run_gate` (`forge-runtime.sh:20`) mataria pushes hoje verdes.

**DA-12** · autonomous · #106: só aviso, e só para .NET; bloqueio opt-in por chave e outras stacks viram um item de roadmap na Onda 8. Motivo: o corpo da #106 diz que aviso já resolve porque a declaração pode ser deliberada; o único caso medido é .NET (axis-go-cloud: 24 `.sln`, `test: pnpm test`); a heurística por comando não vê através de script, e bloquear daria falso positivo.

**DA-13** · autonomous · #150: `positive_control` fica opcional; a obrigatoriedade vira roadmap na Onda 8. Motivo: o corpo pede o controle positivo como opcional e `failure_pattern` obrigatório sem controle, que a seção entrega por recusa no replay; tornar o campo obrigatório no schema invalidaria evidências de escritores antigos.

**DA-14** · autonomous · #133: sem camada declarativa canônica de argparse nesta rodada; ficam a guarda por sítio e o teste estrutural, e a camada vira roadmap na Onda 8. Motivo: há duas camadas incompatíveis em campo (`_ap_ctx` do axis-fare-validator e `argparse_guard_value` do Axis.PadSimulator); escolher uma é contrato novo de lib, e o teste estrutural já fecha a classe medida (11 sítios).

**DA-15** · autonomous · #109: o gate de acks distinguir "ack não publicado" vira roadmap na Onda 8. Motivo: a #109 não pede isso (pede marca d'água e linha no status), e o gate de acks evita ler o hub de propósito por staleness; mudar isso mexe na semântica de um gate que reprova.

**DA-16** · autonomous · #145: o fallback `forge-pentest:latest` fica, com WARN; a remoção vira roadmap na Onda 8, condicionada ao WARN ter circulado por ao menos uma release menor e a um censo dos 7 consumidores sem uso do fallback. O harness entrega só o contrato documentado do entrypoint, não o binário `pentest-scan`. Motivo: trocar o default declara "não buildado" toda imagem já construída pelos consumidores, e entregar o binário cria artefato de toolchain novo, fora do escopo da issue (`pentest-ops.sh:26`, `:180-281`).

**DA-17** · autonomous · #140: A4 advisory (OK/WARN) no template, com o scanner discriminante; o gate bloqueante do azim-crm não vem para o template, e um gate bloqueante opt-in vira roadmap na Onda 8. Motivo: o script bloqueante não existe no template (0 arquivos), a #140 pede "advisory nas duas ou bloqueante nas duas" e o template só tem a superfície advisory (`SKILL.md:152-158`); a issue mostra que um A4 bloqueante empurra o usuário para `--no-verify`, que desliga junto o gate de segredos.

**DA-18** · autonomous · #151: reescrever o critério de teste é prerrogativa exclusiva do dono humano da spec, com registro nominal de quem decidiu; em modo yolo, o yolo-gate não reescreve critério e escala. A regra ordena as três saídas, e a segunda (reescrever) exige esse registro. Motivo: reescrever o critério de aceite é mudar o requisito, `autonomy-yolo.md` mantém o "proibido inferir" do `/forge:clarify` para ambiguidade de requisito de alto risco, e a opção mais restrita é aditiva (hoje a regra só oferece a pendência declarada, `change-test-contract.md:19`).

**DA-19** · autonomous · #135, separar o resíduo e fechar. O PR mantém `Refs`. Depois do PR de reconciliação do Bloco B (protocolo, item 11), que vem depois do PR do LDG-0181 e cria o item, a #135 é fechada à mão com comentário que aponta: (1) o item novo de roadmap na Onda 8, "teto por teste opcional no `run-all.sh` do template, reprovando nomeando quem estourou" (item 3 "Idealmente" do corpo); (2) a classificação "morto por teto" entregue pelo LDG-0181; (3) o manifesto em status `running`, que é maquinaria do consumidor (o `pre-push` do template não carimba manifesto), comunicado por comentário e liaison. Motivo: o título fica atendido pelo teto opt-in e pelo anúncio do nome; o critério de saída da rodada exige a issue fechada ou herdada por decisão escrita, e fechar com resíduo rastreado não perde informação.

**DA-20** · autonomous · #106, separar o resíduo e fechar. O PR mantém `Refs`; depois do PR de reconciliação do Bloco C, que cria o item, a #106 é fechada à mão com comentário que aponta o item de roadmap da Onda 8 "guarda de cobertura para outras stacks e bloqueio opt-in por chave". Motivo: a seção "O que resolveria" da issue pede aviso quando uma classe inteira fica com zero, com prova vermelha contra `.sln` + `pnpm test` e verde nos três que declararam certo, e o desenho entrega exatamente isso para .NET.

**DA-21** · autonomous · #150 fecha pelo próprio PR: `Closes #150`, e os Arquivos ganham `template/.forge/rules/testing/regression-red-first.md` e `template/.forge/commands/testing/red.md` (mais o espelho do plugin) com o item 3 do corpo: âncora que não falha na base é defeito do teste, e o teste afirma o caminho, não só o resultado. Se o implementador não incluir o texto, cai para separar e fechar à mão. Motivo: os itens 1 e 2 do corpo já são entregues pela seção, e o item 3 é prosa aditiva sem custo de contrato que zera o resíduo.

**DA-22** · autonomous · #108: o PR inclui em `commands/harness/liaison.md` (e no plugin) a linha que diz que `read <canal> --upto <msg_id>` é o reparo de acks anteriores ao #105. Depois do PR de reconciliação do Bloco C, que cria os itens, separar e fechar à mão com comentário que aponta dois itens novos: "medir em campo o passivo de cursores pré-#105 e decidir reparo automático" e "dívida de leitura (ackada e não lida)", ambos na Onda 8. Motivo: os itens 2 e 3 do corpo são entregues pela seção; o item 1 não reproduz sem estado antigo e a issue diz que a dimensão em campo está por medir e que o reparo não está escrito em lugar nenhum; a documentação fecha a parte acionável.

**DA-23** · autonomous · #109 fecha pelo próprio PR: `Closes #109`, com o carimbo da hora do push na marca d'água (`published_at` por remetente, gravado depois de `t_push` rc 0), e o `status` imprime `· N própria(s) não publicada(s) (há Xmin)` medido contra esse carimbo, nunca contra `created_at`. Se não couber, cai para separar e fechar à mão. Motivo: o corpo pede literalmente "(há Xmin)" e adverte contra construí-lo sobre `created_at`, que é a data do HEAD (`liaison-ops.sh:99`); a chave é aditiva num `state.json` cujos leitores só leem `cursors`.

**DA-24** · autonomous · #140, separar o resíduo e fechar. O PR mantém `Refs` e acrescenta o README (linha Estrutura) aos Arquivos (J-21). Depois do PR de reconciliação do Bloco D, que cria o item, a #140 é fechada à mão com comentário: a superfície do template ficou discriminante e alinhada; o script bloqueante é local do azim-crm e o alinhamento dele é do consumidor; "gate A4 bloqueante opt-in" vai para roadmap na Onda 8. Motivo: a metade bloqueante mora no consumidor, fora do alcance do produtor, e o `.py` novo altera a contagem de skills que o w200 confere.

**DA-25** · autonomous · LDG-0175, segunda metade (guard de commit): não se cria item. A nota de resolução do LDG-0175 registra que a classe está coberta pela sentinela de árvore rastreada nos dois runners mais a trava de forma do w213, e que o guard de commit não é adotado por falta de sinal de intenção. Condição de reabertura: um arquivo rastreado de `template/` corrompido por gate chegar a commit ou PR apesar da sentinela. Motivo: `tests/run-all.sh:66-83` e `template/.forge/scripts/tests/run-all.sh:66-94` medem o efeito por alvo; não há `core.hooksPath` ativo neste repositório, então um guard de commit nem rodaria no dogfood; distinguir modificação intencional em `template/`, o caso normal de todo PR de maquinaria, exigiria heurística de alto falso positivo.

**DA-26** · autonomous · LDG-0100 e fs-union, os dois nesta ordem. (1) O PR da #123 inclui `check-liaison-acks.sh:179/184` tratando `fs-union` como `fs` (hub em `<path>/<canal>/log`), com cenário no gate w220, independentemente de o kind ser opt-in. (2) Só depois desse merge, na Onda 7, o LDG-0100 vira wont-fix com a condição de reabertura reescrita para "algum canal com kind diferente de fs, fs-union ou manual", verificada por um WARN aditivo e não bloqueante do doctor que nomeia canal e kind. Se a #123 entregar o kind com outro nome, por colisão com o `fs-union.sh` do axis-device-platform, a condição usa o nome entregue. Motivo: `check-liaison-acks.sh:179` só lê o hub para `fs` e `manual`, e qualquer outro kind cai em silêncio na réplica local; a premissa do LDG-0100 ("todo canal usa kind: fs") já é falsa em campo (o ADP usa `fs-union` em 3 canais); DH-4 não muda isso, porque quem optar cai no mesmo buraco.

## Onda 0 — régua da suíte (Bloco 0, entra na 0.16.0)

### LDG-0182 — o guarda anti-recursão do w80 está morto

**LDG-0182** · gate novo: não (reescreve `tests/w80-suite-gate.sh` [4] e [5] e converte os `! cmd` nus dos gates que o Bloco A manda revalidar)

Causa raiz, do detail do ledger (medida em 2026-09-08 e reproduzida com controle, mutação e recontrole): as asserções [4] e [5] do w80 têm a forma `! grep -E … >/dev/null` sob `set -euo pipefail`, e o bash, como o POSIX manda, não sai por `set -e` quando o retorno do comando é invertido por `!`; o gate imprime `OK [4]` e `OK [5]` sempre. A mesma forma aparece em 17 a 19 linhas de 13 a 15 gates com `set -e` (J-19), entre elas `w62:28-29`, que a #125 manda revalidar. Por isso a régua vem antes do Bloco A: um gate revalidado com `!` nu passa por construção.

Desenho: [4] e [5] reescritos na forma `! cmd || { echo "FAIL [n] …"; exit 1; }`; a mesma conversão, uma por gate e cada uma com mutação e recontrole, nos gates que o Bloco A revalida, na ordem w62, w12, w14, w63, w101, w153, w161, w208, w60, w106, w107, w144, w111 e w195. O restante da varredura vira item novo de ledger criado pelo PR de reconciliação deste bloco e posto em negrito na Onda 7 no mesmo PR. Alternativa descartada: `set -o errexit` com `shopt -s inherit_errexit`, que não muda a isenção do `!`.

Vermelho: aplicar ao runner a mutação que o guarda anti-recursão existe para pegar e rodar `bash tests/w80-suite-gate.sh`; esperado rc≠0 com `FAIL [4]`. Hoje, segundo o detail medido, sai `OK [4]` e `OK [5]`; o implementador reexecuta contra a base e cola a saída.

Gate que fica: o próprio w80, com [4] e [5] reprovando o runner mutado e passando no recontrole (`cmp -s`). Propriedade PBT: não se aplica. Mutação: a do vermelho, com controle e recontrole; para cada gate convertido, uma mutação que torne verdadeira a condição negada faz o gate sair rc≠0 nomeando o cenário.

Arquivos: `tests/w80-suite-gate.sh`, os 14 gates listados, CHANGELOG.

**DoD da Onda 0:** `bash tests/w80-suite-gate.sh` sai rc≠0 com o runner mutado e rc 0 no recontrole (`cmp -s`); `grep -nE '^[[:space:]]*! ' tests/w62-*.sh tests/w12-*.sh tests/w14-*.sh tests/w63-*.sh tests/w101-*.sh tests/w153-*.sh tests/w161-*.sh tests/w208-*.sh tests/w60-*.sh tests/w106-*.sh tests/w107-*.sh tests/w144-*.sh tests/w111-*.sh tests/w195-*.sh | grep -v '||'` dá 0 linhas; e `node tools/plan-progress.mjs --plan docs/plans/2026-09-15-plano-issues-abertas.md --wave 0` com tudo ✓ depois do merge do PR de reconciliação do Bloco 0 (protocolo, item 11, e regra de release do Bloco 0), que é quem grava o LDG-0182 como `resolved` e cria o item do lote na Onda 7.

## Onda 1 — o update, o gerador e o hook do tronco desarmam, apagam ou bloqueiam o que o consumidor instalou (Bloco A, 0.16.0)

### #101 e #131 — o overlay sobrescreve maquinaria local e ignora exceções declaradas (um PR)

**#101** · **#131** · Closes #101 · Closes #131 · gate novo: sim (um gate para o PR)

Causa raiz comum, provada: as duas passam pelo mesmo ramo de `bin/forge.mjs`. `:352` define `ENRICHABLE_DIRS = ['agents','rules','skills','templates']`; `:623` só preserva quando `isEnrichable(rel)`; `:630` só avisa (`driftWarned.push`) quando existe `machinery.lock`, que o `init` não cria; `:633` faz `cpSync(srcAbs, dst)` incondicional para `scripts/` e `hooks/`. Nenhuma linha do updater lê `.forge/machinery-exceptions.txt` (`grep -rn machinery-exceptions bin` vazio). A #101 é o sintoma sem declaração, a #131 é o sintoma com declaração, e as duas correções editam as mesmas linhas 620–640 — separá-las garantiria conflito.

Desenho, reaproveitando L1 D2 e D3 com um desvio: `.forge/machinery-exceptions.txt` vira contrato do template no formato que o axis-fare-validator já opera (`<sha256 do template na declaração>  <caminho relativo a .forge/>  # razão`). Exceção viva (sha declarado igual ao sha do template novo) preserva o arquivo e o nomeia com a razão. Exceção ociosa (caminho fora do template, ou arquivo local idêntico ao template) é reportada sem efeito. Arquivo ilegível, linha malformada ou duas declarações do mesmo caminho param o update antes de escrever qualquer arquivo, nomeando a linha. Toda sobrescrita de arquivo que divergia do template novo, com ou sem lock, imprime uma linha por arquivo (`SOBRESCRITO (não declarado): <rel> — conteúdo anterior em <backup real>`). O desvio em relação a L1 D3: exceção expirada (sha declarado diferente do template novo) não para o update; preserva o arquivo e imprime `EXCEÇÃO EXPIRADA: <rel>` com os dois shas, rc 0. Parar seria rc novo na fronteira publicada do `update`.

Alternativa descartada: pôr `scripts`/`hooks` em `ENRICHABLE_DIRS` ou criar `PRESERVED_ON_DRIFT_DIRS` sem declaração. L1 D1 mediu congelamento: sem lock, o fallback preserva quem só estava defasado e a correção do template nunca chega (linhas com JWT depois do update = 0 contra 2 no recontrole).

Decisão: DH-1 (exceção expirada preserva, rc 0; `scripts/` sem preservação por deriva). O lado forte descartado é o LDG-0184, na Onda 8.

Gramática do arquivo de exceções (J-13, medido): o parser segue a gramática que o consumidor já opera, não o formato literal acima. O `machinery-exceptions.txt` do axis-fare-validator tem 34 linhas, só 1 casa com `^[0-9a-f]{64}  [^ ]+  # .+$`, e as 34 estão vivas contra `821178e`; o parser dele (`check-machinery-drift.sh`, cerca de `:189-217`) usa `read -r` com espaçamento livre, corta no `#` e aceita hex com 32 ou mais dígitos. Fixture obrigatória do gate: cópia literal desse arquivo, com rc 0 e as 34 linhas nomeadas. O cenário "malformada" usa sha não hexadecimal ou caminho ausente, nunca espaçamento.

Vermelho, executado (`/tmp/fh-R02-Bupdate.sh`): `node bin/forge.mjs init --target $C -y --no-plugin`; anexar `# CONSERTO-LOCAL` a `.forge/scripts/lib/transports/_common.sh`; declarar a exceção com o sha do template; `node bin/forge.mjs update --target $C --no-backup --no-plugin`; esperado depois da correção: conserto presente e o caminho nomeado no stdout. Hoje:

```
  ANTES: hook stdin rc=2 settings=1 conserto=1
  update rc=0
  linhas do update citando _common.sh/exceptions/prevent-secrets: 0
  DEPOIS: hook stdin rc=0 settings=0 conserto=0
```

Gate que fica: `tests/w<NNN>-update-exceptions-gate.sh`, com cenários: viva preserva e nomeia (positiva: linha `PRESERVADO (exceção declarada)` presente e sha local intacto); não declarada sobrescreve e nomeia com caminho de backup existente; expirada preserva e nomeia; malformada e duplicada param com arquivo nenhum escrito (positiva: a linha da recusa nomeia o número da linha); ausência do arquivo não imprime nada novo além das linhas `SOBRESCRITO`. Revalidar w63, w101, w153 e w161, que executam o updater.

Propriedade PBT: para arquivos de exceção gerados (mistura aleatória de linhas vivas, expiradas, ociosas, malformadas e duplicadas sobre caminhos reais do template), o desfecho é uma função pura do conjunto: o update para se e somente se existe linha malformada ou duplicada; quando não para, cada arquivo local fica byte-idêntico se e somente se tem exceção viva ou expirada, e todo caminho declarado aparece exatamente uma vez no relatório.

Mutação: remover a chamada ao leitor de exceções no laço (a condição que antecede `:633`) faz o cenário "viva preserva" falhar com o sha local trocado; remover o `console.log` da linha `SOBRESCRITO` faz o cenário não declarado falhar pela contagem de linhas.

Arquivos: `bin/forge.mjs`, `template/.forge/machinery-exceptions.txt` (cabeçalho documentado, sem linhas), `template/.forge/commands/harness/upgrade.md` (+ espelho do plugin), gate novo, README, CHANGELOG.

### #130 — importar o gerador reconcilia 70 arquivos do consumidor

**#130** · Closes #130 · gate novo: sim

Causa raiz: `template/.forge/scripts/lib/sync-adapters.mjs:352-372` (bloco `// ── entry ──`) roda incondicionalmente, sem guarda de módulo principal, e o `process.exit(1)` de nível de módulo mata o importador.

Desenho, reaproveitando L1 D6: guarda de principal por identidade de arquivo (`realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1])`), `process.exit` só dentro do galho principal, e exportação nomeada da função que monta a fiação (a #125 precisa lê-la). Alternativa descartada: o idioma de `plugin-build.mjs` (`import.meta.url === \`file://${process.argv[1]}\``), medido falso nas três invocações sob `$TMPDIR` no macOS (L1 §4.4), o que desarmaria também o caminho legítimo.

Vermelho, executado: anexar `// edicao-pendente` a um arquivo de `.claude/agents/` do consumidor sintético e rodar `node --input-type=module -e "await import('<C>/.forge/scripts/lib/sync-adapters.mjs')"`; esperado: arquivo intacto e nada impresso. Hoje:

```
  antes: 1
OK reconcile complete: 1 active [claude]
  depois: 0
```

Gate que fica: `tests/w<NNN>-module-import-side-effect-gate.sh`, com o par: importar não muda o sha de nenhum arquivo sob `.claude/` e expõe pelo menos uma exportação (positiva), e `node sync-adapters.mjs` direto continua imprimindo `OK reconcile complete` e restaura o arquivo editado (positiva do caminho legítimo). Propriedade PBT: não se aplica, a entrada é binária (importado ou principal). Mutação: remover a condição da guarda faz o cenário de import falhar com o sha alterado; inverter a condição faz o cenário de invocação direta falhar sem `OK reconcile`.

Arquivos: `template/.forge/scripts/lib/sync-adapters.mjs`, gate novo, README, CHANGELOG.

### #160 — o gerador apaga chaves de topo autorais do `.claude/settings.json`

**#160** · **LDG-0189** · Closes #160 · gate novo: sim (w238) · depois do PR da #130, antes do PR da #125 (mesmo `sync-adapters.mjs`)

Causa raiz (J-08, reproduzida num clone do vellus): `template/.forge/scripts/lib/sync-adapters.mjs:246` emite `JSON.stringify({ hooks }, null, 2)`, então toda chave de topo que não é `hooks` some no próximo `sync`, com rc 0. Medido: antes `['permissions','env','hooks','includeCoAuthoredBy']`, depois `['hooks']`, com 41 regras allow/deny e 4 variáveis de env perdidas sem aviso. `template/.forge/scripts/doctor.sh:157` agrava o dano, porque manda rodar `sync-adapters.sh` para corrigir drift sem ressalva (LDG-0189, mesmo PR).

Desenho: o gerador lê o `settings.json` existente e só é dono das entradas de hook cujo `command` é, por igualdade de string, um dos comandos que ele mesmo sabe derivar (o universo de emissão do gerador em qualquer combinação dos flags do `forge.yaml`: hoje `enforce-worktree-location.sh`, `on-session-start.sh` e `on-session-end.sh`, e depois da #125 os ganchos declarados no manifesto), nunca pela simples menção a `.forge/hooks/`. Medido no axis-fare-validator: o `.claude/settings.json` tem três comandos `.forge/hooks/pre-tool-use/dispatch-file-hook.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/<gancho>.sh` (wrapper autoral fora do manifesto) e dois ganchos autorais, `enforce-docs-on-publish.sh` e `guard-machinery-drift.sh`; todos citam `.forge/hooks/`, nenhum é igual a um comando derivado, e por isso todos sobrevivem como autorais. Chaves de topo e hooks de terceiros sobrevivem, de forma idempotente (dois `sync` seguidos produzem bytes iguais). Arquivo existente com JSON ilegível não é regenerado por cima em silêncio: o gerador copia os bytes anteriores para `<git-dir>/forge-backups/`, com o git-dir resolvido por `git rev-parse --git-dir` como faz `bin/forge.mjs:596` (numa worktree ligada, `.git` é arquivo e o caminho literal `.git/forge-backups/` falharia), antes de escrever, e imprime WARN com o caminho, rc 0, a mesma política da #120 (DA-09). A mensagem de `doctor.sh:157` passa a dizer que o `sync` preserva chaves autorais e deixa de recomendar a regeneração quando o drift está só em chave que o gerador não possui. Alternativa descartada: mover as chaves autorais para `settings.local.json`, que muda onde o consumidor declara permissões e não recupera o que já foi apagado.

Vermelho, a reconstruir no PR: consumidor sintético com o `settings.json` do vellus como fixture; `node .forge/scripts/lib/sync-adapters.mjs`; `node -e 'console.log(Object.keys(JSON.parse(require("fs").readFileSync(".claude/settings.json","utf8"))))'`; esperado as quatro chaves. Hoje `['hooks']`, como no clone medido.

Gate que fica: `tests/w238-settings-json-merge-gate.sh`: chaves de topo e `permissions` byte-idênticas depois do `sync`, com a fiação de `.forge/hooks/` presente e atualizada (positiva); hook de terceiro em `PreToolUse` preservado; o `settings.json` do axis-fare-validator como segunda fixture, sanitizada, com os três wrappers `dispatch-file-hook.sh` e os dois ganchos autorais preservados byte a byte e nenhuma entrada derivada duplicando um gancho que o wrapper já chama (a #125 herda este cenário no w215); segundo `sync` sem diff (idempotência); JSON ilegível gera backup byte-idêntico e WARN com o caminho, também numa worktree ligada, em que o backup cai no git-dir da worktree; doctor com drift só em chave autoral não recomenda regenerar (LDG-0189). Revalidar w12, w14, w62 e w208, que executam o gerador, e w63 (update). Propriedade PBT: para `settings.json` gerados (subconjuntos aleatórios de chaves de topo autorais, hooks de terceiros e hooks do harness, em ordem aleatória), depois do `sync` o conjunto de chaves autorais e de hooks de terceiros é igual ao de antes, e os hooks do harness são exatamente os derivados. Mutação: voltar a `emit({ hooks })` faz o cenário do vellus falhar nomeando `permissions`; trocar a posse por igualdade pela menção a `.forge/hooks/` faz o cenário do axis-fare-validator falhar nomeando `dispatch-file-hook.sh`; remover o backup faz o cenário de JSON ilegível falhar.

Arquivos: `template/.forge/scripts/lib/sync-adapters.mjs`, `template/.forge/scripts/doctor.sh` (`:157`), gate novo, README, CHANGELOG.

### #125 — o detector de segredos nunca chega armado e o update desarma quem o armou

**#125** · Closes #125 · gate novo: sim · depende do PR de #101/#131 e dos PRs de #130 e #160

Causa raiz: três defeitos independentes. (1) `hooks/` cai no `cpSync` de `bin/forge.mjs:633` — fechado pelo PR de #101/#131, que torna a sobrescrita nominal e a exceção honrada; por isso este PR usa `Refs` para essa metade e só fecha a issue ao fim. (2) `template/.forge/scripts/lib/sync-adapters.mjs:233` monta `PreToolUse` com um único gancho literal (`enforce-worktree-location.sh`), então todo `sync` apaga a fiação armada à mão. (3) `template/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh:8-13` lê `$1`/`$2` e sai 0 com argv vazio, e o Claude Code entrega o payload por stdin: mesmo registrado, o gancho aprova.

Desenho, reaproveitando L1 D4, D4.5 e D5: a fiação `PreToolUse` passa a derivar do diretório `hooks/pre-tool-use/` (profundidade 1) com matcher e contrato vindos de `hooks.manifest.default` distribuído, lido pelo leitor canônico que já existe em `template/.forge/scripts/lib/hooks-manifest.mjs` (coberto por w208). Manifesto do consumidor em esquema não marcado resolve pelo mesmo leitor; esquema não reconhecido deixa o `settings.json` anterior byte-idêntico e nomeia LDG-0178. O semeador do `update` deriva ativação do que já está fiado: gancho hoje fiado nasce ativo, gancho não fiado nasce inativo e nomeado — nenhum consumidor ganha bloqueio novo sem saber. O gancho de segredos passa a ler o JSON de stdin quando argv vem vazio, bloqueia com exit 2 e é fail-closed com stdin vazio, como o Axis.PadSimulator mediu; os ganchos `argv` restantes recebem uma ponte em `hooks/pre-tool-use/lib/`.

Alternativa descartada: pôr a lista no `forge.yaml` (item 2 da issue). O merge do `forge.yaml` é por chave de topo ausente (`bin/forge.mjs:447-460`), então sub-chave nova nunca chega a quem já tem a chave. Descartada também a ativação de todos os ganchos no update: introduziria bloqueio não anunciado em consumidores que nunca armaram.

Decisão: DH-2 (o esquema canônico da camada do consumidor aguarda a thread de liaison com axis-fare-validator, Axis.PadSimulator e axis-device-platform; o LDG-0178 fica na Onda 8). Até lá, a ativação por sobreposição do consumidor não é lida além do que w208 já lê. O censo do adendo conta três esquemas em campo, não dois (J-11): o axis-device-platform criou o seu em `cec1a73`, com o campo 3 `stdin-json:tool_input.file_path+content` fora de `CONTRATOS_V1`, que o leitor atual projeta com aviso.

Vermelho, executado (`/tmp/fh-R02-Bupdate.sh`), em duas partes. Sem armar nada: `printf '<payload Write>' | bash .forge/hooks/pre-tool-use/prevent-secrets-leak.sh; echo rc=$?`, em que o `content` do payload carrega a chave de acesso AWS de exemplo da documentação da AWS montada em tempo de execução por concatenação (prefixo de quatro letras e sufixo em variáveis separadas), para que nenhum literal de segredo entre no repositório; e `grep -c prevent-secrets-leak .claude/settings.json`; esperado rc 2 e contagem ≥1. Armado e depois `update`: esperado rc 2 e contagem ≥1 depois. Hoje:

```
  stdin rc=0
  settings.json registra prevent-secrets-leak? 0
  DEPOIS: hook stdin rc=0 settings=0 conserto=0
```

Gate que fica: `tests/w<NNN>-hook-wiring-derived-gate.sh` (w215). Revalidar w12, w14, w62, w63, w153 e w208, que executam o gerador, e w238, que trava a fusão do `settings.json` entregue pela #160. O gate w215 monta o payload com segredo em tempo de execução, por concatenação, como o vermelho acima. O que reprovou o PR #154 pelo literal que esta seção trazia foi a auto-varredura do `tests/w139-secrets-gate.sh` [15], dentro da suíte que o check `gates` roda: ela executa `check-secrets.sh` em modo `path` sobre o repositório inteiro e exige zero achado (`w139:366`, `FAIL [15]: o gate achou segredo no próprio repositório`), independentemente do modo `warn` herdado. O passo `check-secrets.sh range` do CI (`.github/workflows/ci.yml:56-61`), em rc 0, só emite WARN neste repositório, que não declara `secrets:`. A trava do w139 [15] vale para qualquer padrão de segredo, inclusive chave privada, token de provedor e credencial em URL, e por isso alcança o w215, as fixtures desta seção e as sementes da PBT: todo segredo de teste é montado em tempo de execução, nunca gravado como literal. Depois da correção, `check-secrets.sh path` no worktree deste ramo varreu 1197 arquivos com 0 achados (`OK secrets — nenhum segredo em 1197 arquivo(s) versionado(s)`, medido em 2026-09-25). Fixtures (J-11): os três manifestos reais (axis-fare-validator, Axis.PadSimulator e axis-device-platform) com os `settings.json` correspondentes, e o `settings.json` do vellus; um `.sh` presente em `pre-tool-use/` e ausente do manifesto (caso medido: `dispatch-file-hook.sh` do axis-fare-validator) gera aviso nomeado, nunca reprovação; e cenário de versão mista entre o gerador novo e ganchos antigos preservados por exceção (protocolo, item 4).

Propriedade PBT: para diretórios `pre-tool-use/` gerados (subconjuntos aleatórios de ganchos declarados, ativos e inativos, mais um arquivo não declarado), o conjunto de comandos emitidos em `PreToolUse` é igual ao conjunto de ganchos declarados ativos; arquivo não declarado gera aviso nomeando o arquivo e não entra no conjunto emitido; e para payloads gerados contendo um dos padrões de segredo em posição aleatória do `content`, o gancho via stdin sai 2.

Mutação: trocar a derivação pelo literal de `:233` faz o cenário de igualdade de conjunto falhar nomeando `prevent-secrets-leak.sh`; remover a leitura de stdin no gancho faz o cenário de payload sair rc 0.

Arquivos: `template/.forge/scripts/lib/sync-adapters.mjs`, `template/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh`, `template/.forge/hooks/pre-tool-use/hooks.manifest.default` (novo), `template/.forge/hooks/pre-tool-use/lib/` (ponte, nova), gate novo, README, CHANGELOG.

### #142 — o update introduz o nome default do lock em quem declarava outro caminho de serialização

**#142** · Closes #142 · gate novo: sim

Causa raiz, remedida: o update não reescreve `resource` declarado (caso 1 da triagem preserva `axis-heavy-suite`). A partição vem de `bin/forge.mjs:447-460` (`newForgeKeys`), que mescla o bloco `heavy_mutex` inteiro, com `resource: forge-heavy-suite`, em quem não tinha o bloco, sem uma linha sobre identidade do lock; a lib cai no mesmo nome sem yaml (`template/.forge/scripts/lib/heavy-mutex.sh:235`). Medido nas árvores desta máquina: axis-fare-validator declara `axis-heavy-suite` e axis-go-cloud declara `forge-heavy-suite`, com a mesma lib de 932 linhas — duas famílias de lock que não se serializam.

Desenho: quando o update mescla `heavy_mutex` ausente, ele resolve o recurso antes e depois pela mesma precedência da lib (env > yaml > default) e imprime uma linha nominal `heavy_mutex: recurso resolvido <antes> → <depois> (lock <caminho>)`, com `WARN` quando os dois diferem; o `doctor` passa a imprimir o recurso resolvido na linha `HEAVY-MUTEX` que já existe, e o gate trava L1 D8 (o update nunca reescreve `resource`, `root` e `enabled` declarados). Alternativa descartada: trocar o default para um nome neutro, que reparticionaria todos os consumidores no default atual. Descartada também a leitura dos `forge.yaml` de árvores irmãs (sugestão 2 da issue): exige varrer o disco a cada push.

Decisão: DH-3 (nome default mantido, com a linha nominal; sem registro de famílias). O lado forte descartado é o LDG-0186, na Onda 8. Complemento (J-28): a linha `HEAVY-MUTEX` do doctor imprime também o `root` resolvido, e o axis-go-cloud recebe mensagem de liaison pedindo `resource` e `root` alinhados.

Vermelho, executado (`/tmp/fh-A-142.sh`, caso 2): remover o bloco `heavy_mutex` de um consumidor e rodar `update`; esperado: linha nominando o recurso resolvido. Hoje só a mescla aparece:

```
forge.yaml: 1 chave(s) de topo nova(s) do template mescladas: heavy_mutex
  bloco depois:   enabled: false   resource: forge-heavy-suite   timeout_s: 1800
```

Gate que fica: `tests/w<NNN>-heavy-mutex-partition-gate.sh`. Propriedade PBT: para `forge.yaml` gerados (bloco presente ou ausente, `resource` aleatório, `FORGE_HEAVY_MUTEX_RESOURCE` definido ou não), depois do update o recurso resolvido pela lib é igual ao de antes, ou o stdout do update contém os dois nomes numa linha `heavy_mutex:`; e `resource`, `root` e `enabled` declarados ficam byte-idênticos. Mutação: remover a impressão da linha nominal faz o caso "bloco ausente com env diferente" falhar; fazer o merge sobrescrever `resource` faz o cenário D8 falhar.

Arquivos: `bin/forge.mjs`, `template/.forge/scripts/doctor.sh`, gate novo, README, CHANGELOG.

### #141 — hook do tronco procura o script delegado na worktree

**#141** · Closes #141 · gate novo: sim · primeira da cadeia do `pre-push` (movida da Onda 3 para a Onda 1, J-07)

Causa raiz: `bin/forge.mjs:211-247` grava `core.hooksPath` absoluto do tronco por decisão registrada (#41/#54, LDG-0042), mas `template/.forge/hooks/git/pre-commit:6` resolve `ROOT` por `git rev-parse --show-toplevel` da worktree, e `:74-77` bloqueia quando `.forge/scripts/` existe sem o script delegado. Um hook novo encontra scripts velhos na worktree e bloqueia o commit. A mesma classe tem 12 sítios medidos em L3 §0 (pre-push 6, pre-commit 1, commit-msg 1, post-merge 2, `hooks/git/lib/check-red-first.sh` 2).

Desenho, reaproveitando L3 D14: precedência de resolução do alvo delegado — primeiro a árvore que executa (`$ROOT/.forge/scripts/<alvo>`); se ausente lá, a árvore do hook (`$(dirname "$0")/../../scripts/<alvo>`), com uma linha `hook: <alvo> ausente em <worktree> — usando o do tronco (<caminho>); rode forge update na worktree`; bloqueio mantido quando o alvo falta nas duas. As recusas existentes ficam literais. Alternativas descartadas: voltar ao `hooksPath` relativo (reverte #41/#54 e LDG-0042) e degradar a recusa para WARN (afrouxa a política da #49 de que delegação em alvo ausente é erro).

Vermelho, executado (`/tmp/fh-A-141.sh`): worktree com `.forge/scripts/` sem `check-secrets.sh`, hook do tronco novo; esperado rc 0 com a linha que nomeia o tronco. Hoje:

```
pre-commit BLOQUEADO: .forge/scripts/ existe mas check-secrets.sh não — a delegação aponta para um alvo ausente
  rc=1
```

Gate que fica: `tests/w<NNN>-delegacao-arvore-do-hook-gate.sh` com a matriz de L3 §4.3 ([a] worktree sem alvo e tronco com: passa e nomeia; [b] as duas sem: continua bloqueando — contrafactual; [d] worktree com alvo próprio: usa o próprio); cenário de auto-ironia sobre os 12 sítios. Revalidar w97, w137, w147 e w191. Propriedade PBT: não se aplica; o espaço são os quatro estados da matriz, exaustivos. Mutação: remover o fallback num sítio faz [a] bloquear; aplicar o fallback também quando o alvo falta nas duas faz [b] passar.

Arquivos: `template/.forge/hooks/git/pre-push`, `pre-commit`, `commit-msg`, `post-merge`, `lib/check-red-first.sh`, gate novo, README, CHANGELOG.

Por que na Onda 1 (J-07): o dano existe desde a v0.10.0 (`efe99e9`), e o cético mediu no azim-crm `core.hooksPath` absoluto para o tronco, template 0.1.0-rc24 e 87 worktrees sem `check-secrets.sh`. A 0.16.0 induz o consumidor a atualizar o tronco; sem esta correção, as worktrees seguem com commit bloqueado por um release inteiro. Nenhuma justificativa do R02 exige a #141 depois da #135, e por isso ela abre a cadeia do `pre-push`.

**DoD da Onda 1:** num consumidor sintético criado por `init`, com conserto local em `scripts/`, gancho de segredos armado, exceção declarada e bloco `heavy_mutex` removido, um `update` seguido de `sync` deixa o conserto intacto e nomeado no stdout, o gancho sai 2 para payload com segredo via stdin e está registrado no `settings.json`, o import do gerador não altera `.claude/` enquanto a invocação direta ainda reconcilia, o stdout nomeia o recurso de lock resolvido, as chaves de topo autorais do `settings.json` (fixture do vellus) sobrevivem ao `sync` byte a byte, e numa worktree com `.forge/scripts/` sem `check-secrets.sh` o commit sai rc 0 com a linha que nomeia o tronco, enquanto o contrafactual sem alvo nas duas árvores continua bloqueando. Cada negativa ("não sobrescreveu", "não alterou") é provada junto com a positiva correspondente (linha nominal presente, rc 2 observado, `OK reconcile` impresso).

## Onda 2 — ferramentas que destroem trabalho do consumidor com rc 0 (Bloco A, 0.16.0)

### #120 — handoff-gen troca o HANDOFF.md inteiro quando faltam marcadores

**#120** · Closes #120 · gate novo: não (amplia `tests/w60-handoff-gen-gate.sh`)

Causa raiz: `template/.forge/scripts/lib/handoff-render.mjs:56-60` só preserva quando o arquivo existente tem os marcadores `NARRATIVE-DELTA`; sem eles, `:70` (`writeFileSync(out, content)`) grava o template renderizado por cima, sem backup e com rc 0.

Desenho: quando o arquivo existente não tem os marcadores e difere do conteúdo novo, o renderizador copia o arquivo anterior para `<git-dir>/forge-backups/handoff-<timestamp>.md`, com o git-dir resolvido por `git rev-parse --git-dir` para funcionar também em worktree ligada (fora da árvore, mesmo destino e mesma resolução do backup do update desde a #76, `bin/forge.mjs:596`; fallback `.forge/HANDOFF.md.bak-<timestamp>` fora de repositório git) antes de escrever, e imprime `WARN: HANDOFF.md sem marcadores NARRATIVE-DELTA — conteúdo anterior (<N> bytes) salvo em <caminho>` em stderr, rc 0. Alternativa descartada como default: recusar sem `--force`, que muda o contrato do `handoff-gen.sh` para o fluxo `/forge:handoff` e para o hook de sessão que o chamam esperando rc 0 (w62). Descartada também a guarda de proporção de tamanho: um limiar é heurística e deixaria passar a perda de um arquivo pequeno.

Decisão: DA-09 (não recusar; recusa opt-in e alinhamento do `/forge:handoff` aos marcadores viram roadmap na Onda 8).

Vermelho, executado (`/tmp/fh-R02-Bupdate.sh`): `.forge/HANDOFF.md` com 3.000 seções sem marcadores e change `c1` ativo; `FORGE_ROOT=$C bash .forge/scripts/handoff-gen.sh c1`; esperado: backup com os bytes anteriores. Hoje:

```
  antes=  111786 bytes
  rc=0
  depois=    2569 bytes; backups: 0
```

Gate que fica: cenários novos no w60 — sem marcadores: o backup existe e é byte-idêntico ao arquivo anterior (positiva) e o WARN nomeia o caminho; com marcadores: nenhum backup e o delta preservado (controle); arquivo idêntico ao render: nenhum backup. Propriedade PBT: para conteúdos anteriores gerados (com e sem marcadores, com bytes aleatórios fora deles), os bytes anteriores são sempre recuperáveis depois da geração — ou no próprio arquivo (delta preservado) ou num backup byte-idêntico. Mutação: remover a cópia de backup faz o cenário sem marcadores falhar por backup ausente.

Arquivos: `template/.forge/scripts/lib/handoff-render.mjs`, `tests/w60-handoff-gen-gate.sh`, CHANGELOG.

### #139 — `/forge:red record` sobrescreve a evidência anterior

**#139** · Closes #139 · gate novo: sim

Causa raiz: `template/.forge/scripts/lib/red-evidence.mjs:9` fixa um caminho único e `template/.forge/scripts/lib/red-evidence-ops.mjs:93-127` copia os escalares do topo (`const data = { ...ev.data }`), atribui campo a campo e grava com `writeJsonAtomic`: o segundo `record` apaga o primeiro, e um `record` parcial herda campos de outro defeito.

Desenho, reaproveitando L5 D12, D13 e D19: `red-evidence.json` ganha `entries[]` com um registro por defeito e `id` estável (`record --id`); `record` sobre `id` já declarado sem `--id` explícito recusa (fail-closed contra quimera); os escalares do topo passam a ser projeção da primeira entrada e o `status` do topo é derivado (observado só se todas as entradas estão observadas ou dispensadas). Leitores antigos continuam lendo o topo. O schema `red-evidence.schema.json` ganha `entries` como propriedade opcional. Alternativa descartada: um arquivo por defeito em `evidence/red/`, que obrigaria todo leitor (pre-push, spec-verify, CI) a descobrir o universo de arquivos e deixaria arquivo extra ignorado, que é o quarto sintoma medido. Separado da #138 porque o locus é outro (`red-evidence-ops.mjs:93-127` contra os predicados `type !== 'bugfix'` em `:69`, `:219` e `check-red-first.mjs:166`, `:350`, `:539`); a #138 vem depois e itera `entries`.

Vermelho, executado (`/tmp/fh-A-139.sh`): `record` de `DefeitoA` e depois `DefeitoB` no mesmo change `type: bugfix`; `grep -r DefeitoA <change> | wc -l` esperado ≥1; `record --failure-pattern PC` sem `--test-id` num change com duas entradas esperado rc≠0. Hoje:

```
  ocorrências de DefeitoA no change: 0
  topo: DefeitoB PB ["src/b.sh"] sem entries
  topo: DefeitoB PC
```

Gate que fica: `tests/w<NNN>-red-evidence-entries-gate.sh`; revalidar w106, w107 e w144, que escrevem o artefato à mão (L5 §6.4). Cenários de legado (J-14): há `red-evidence.json` sem `entries` em voo em centenas de changes de campo (123 no axis-go-cloud, 66 no axis-device-platform, 283 no azim-crm, medidos pelo cético); `status` lê o legado como entrada observada, e o primeiro `record --id` preserva o legado como `entries[0]` em vez de criar `entries=[novo]`, que seria o próprio defeito da issue. Propriedade PBT: para estados iniciais gerados entre vazio e legado, seguidos de sequências geradas de `record --id <k>` com campos aleatórios, cada `id` aparece exatamente uma vez em `entries`, a última declaração por `id` vence, nenhum campo de um `id` aparece na entrada de outro, e o topo é igual à projeção da primeira entrada. Mutação: trocar a escrita em `entries` pela atribuição no topo faz o cenário A+B falhar com contagem 0; remover a recusa sem `--id` faz o cenário da quimera sair rc 0.

Arquivos: `template/.forge/scripts/lib/red-evidence.mjs`, `red-evidence-ops.mjs`, `check-red-first.mjs` (leitura de `entries`), `template/.forge/schemas/red-evidence.schema.json`, `template/.forge/commands/testing/red.md` (+ plugin), gate novo, README, CHANGELOG.

### #107 — o corpo perdido de uma mensagem já conhecida nunca volta por sync

**#107** · Closes #107 · gate novo: sim

Causa raiz: `template/.forge/scripts/lib/liaison-import.mjs:197-198` conta mensagem já conhecida como `dup` e faz `continue` antes da cópia de blob, que mora em `:237-243`, dentro do laço das mensagens novas. Réplica que perde um blob nunca o recupera, com rc 0.

Desenho: uma passada própria, depois do merge, que percorre todas as mensagens locais com `body_ref` cujo blob falta localmente e o copia do bundle quando existe lá, contando `N blob(s) recuperado(s)`; blob ausente nos dois lados vira `WARN: <n> body_ref sem blob (local e hub)` com os ids. Alternativa descartada: tirar o `continue` e reprocessar mensagens conhecidas no laço de escrita, que reabriria a detecção de duplicata e de divergência já coberta por w111 e w195.

Vermelho, executado (`/tmp/fh-R02-Bliaison.sh`): réplica `qq` sincroniza uma mensagem com `--body-file`, apaga o blob local e roda `liaison-ops.sh sync ch`; esperado: 1 blob local. Hoje:

```
OK sync via fs — 0 nova(s), 2 duplicata(s) (no-op), 0 conflito(s), 0 em quarentena
  sync rc=0
  blobs em qq após sync: 0  hub: 1
```

Gate que fica: `tests/w<NNN>-liaison-blob-recovery-gate.sh`, com a positiva (blob de volta e byte-idêntico ao do hub, linha `recuperado` impressa) e o controle (sem perda, a linha de recuperação não aparece). Propriedade PBT: para subconjuntos gerados de blobs apagados localmente, depois de um `sync` o conjunto de blobs locais contém todo `body_ref` local cujo blob existe no hub. Mutação: remover a passada de recuperação faz o cenário principal falhar com 0 blobs.

Arquivos: `template/.forge/scripts/lib/liaison-import.mjs`, gate novo, README, CHANGELOG.

### #123 — worktree de branch antiga publica no hub com `_common.sh` destrutivo

**#123** · Closes #123 · gate novo: sim · última do Bloco A; a dependência da #133 (Onda 4) é branda e declarada como tal na tabela de dependências

Causa raiz: `template/.forge/scripts/liaison-ops.sh:101` resolve `ROOT` pelo checkout principal, mas `:103` resolve `LIBDIR` pela cópia da árvore que invoca; o único elo lido do tronco é a configuração, e `template/.forge/scripts/lib/liaison-config.mjs:27` não tem kind capaz de travar leitor antigo. Custo remedido em 2026-09-25, somente leitura (censo do adendo): 181 worktrees em 7 consumidores têm `_common.sh`, e 139 delas não contêm `_dir_push_union` (predicado por nome; um fork com a união sob outro nome seria contado como antigo). O R02 contava 176/146 em quatro consumidores.

Desenho, a proposta da issue como opt-in por consumidor: `fs-union` entra em `TRANSPORT_KINDS` e no `liaison-config.schema.json`, com o mesmo backend de `fs` em `821178e` (push por união). A proteção vem do leitor antigo: `liaison-config.mjs:86` já recusa kind desconhecido (`kind inválido`), então uma árvore anterior ao kind que leia o `liaison.yaml` do tronco falha fechado antes de tocar o hub. Quem não troca o kind não muda nada — por isso não é quebra de contrato do produtor. Segunda camada, a do `fs-union.sh` do axis-device-platform (`transports/fs-union.sh:31-37` e `:52-61`): o backend do kind carrega o `_common.sh` do TRONCO, não o de `$LIBDIR`, e falha fechado se ele não existir ali (`FAIL fs-union: _common.sh do checkout principal ausente em <caminho>`, rc 1), sem cair para a cópia da árvore. O tronco é resolvido por `forge_main_root` executado a partir do diretório do próprio script (`template/.forge/scripts/lib/forge-root.sh:26`), com `FORGE_ROOT` ignorado nessa resolução, como faz o ADP (`FORGE_ROOT='' forge_resolve_root`): `FORGE_ROOT` declara onde mora o estado, e a âncora aqui é sobre qual código roda. Isso protege a árvore que tem o `fs-union.sh` novo e um `_common.sh` destrutivo por merge feito pela metade, que a trava por kind não pega. Alternativa descartada como default: resolver `LIBDIR` pelo tronco para todo kind, que muda qual código de reconciliação roda em toda worktree de todo consumidor; no backend do kind a objeção não vale, porque só roda para quem optou por `fs-union`. Descartado também o "campo de política" ao lado de `kind: fs`: não medi se o leitor antigo recusa campo desconhecido, e se ele ignorar, a opção não trava ninguém.

Decisão: DH-4 (`fs-union` opt-in, sem recomendação; o lado forte é o LDG-0187, na Onda 8) e DA-26 (este PR trata `fs-union` em `check-liaison-acks.sh`). Colisão de nome (J-11): o axis-device-platform já tem `transports/fs-union.sh` próprio, `TRANSPORT_KINDS` com `fs-union` e 3 canais em uso. Antes de escrever o backend, o PR compara o arquivo do ADP com o do template por cinco critérios: os desfechos ff, behind, diverged e equal do push, e a origem do `_common.sh` (tronco com falha fechada, ou `$LIBDIR`). Os quatro desfechos saem iguais nas duas versões sempre que o `_common.sh` carregado é o mesmo, e por isso não bastam para declarar equivalência: um backend que carrega o `_common.sh` de `$LIBDIR` tira do ADP a proteção por resolução no tronco sem mudar nenhum desfecho. O PR avisa o ADP por liaison; se algum dos cinco divergir, o kind do template não reaproveita o nome, e a condição do LDG-0100 usa o nome entregue.

Por que no Bloco A, medido no axis-device-platform em 2026-09-25, somente leitura: `.forge/scripts/lib/liaison-config.mjs:34` tem `TRANSPORT_KINDS = ['manual','fs','fs-union','git','gh']`, com sha `2da8ae9a…` diferente do lock (`machinery.lock:300` → `080ac83d…`, o do template); `check-liaison-acks.sh` também diverge do lock (`58ab0532…` contra `3669ae39…`), e o diff contra `821178e` é exatamente o tratamento de `fs-union` em `:179` e `:184` que a DA-26 pede; não existe `.forge/machinery-exceptions.txt`; e o `liaison.yaml` declara `kind: "fs-union"` em 3 canais (linhas 11, 19 e 31). O comentário do próprio arquivo registra que o overlay do `forge update` já removeu a entrada uma vez, em 2026-09-11 (0.6.0 → 0.15.0), e que ela foi reinserida à mão. Pela #101/#131, na 0.16.0 um arquivo divergente e não declarado é sobrescrito e nomeado: sem a #123 no mesmo release, o update da 0.16.0 troca o `liaison-config.mjs` do ADP por um sem `fs-union`, e os 3 canais passam a falhar com `kind inválido`. Com a #123 no Bloco A, o arquivo do template que chega ao ADP já aceita o kind. A dependência da #133 é branda: a #123 só usa `transport set --kind`, que funciona sem a guarda de flag-como-valor, e a #133 revalida o gate da #123 quando entrar.

Aviso prévio ao ADP (Bloco A, antes da publicação), com dois ramos decididos pela comparação acima: se o `fs-union.sh` do template for equivalente ao do ADP nos cinco critérios e reaproveitar o nome, a sobrescrita de `scripts/lib/liaison-config.mjs`, `scripts/lib/transports/fs-union.sh` e `scripts/check-liaison-acks.sh` traz conteúdo equivalente, inclusive a segunda camada, e a mensagem só nomeia os três arquivos que serão sobrescritos; se não for equivalente em qualquer um dos cinco, a mensagem instrui a declarar exceção para os três antes do update, com o texto de cada linha de `.forge/machinery-exceptions.txt` (sha do template, caminho, razão) escrito na própria mensagem. O ensaio de campo do Bloco A no clone do ADP, com o `path` do transporte apontado no clone para uma cópia descartável do hub e nunca para o hub real, confere depois do update: (1) `liaison-ops.sh sync` rc 0 em cada um dos 3 canais `fs-union`; (2) a propriedade da segunda camada, e não só o rc, renomeando no clone o `_common.sh` do tronco: o `sync`, invocado como `(cd <worktree-do-clone> && .forge/scripts/liaison-ops.sh sync <canal>)` — nunca o `liaison-ops.sh` do tronco com `cd` para a worktree, que resolveria `LIBDIR` pelo tronco (`liaison-ops.sh:103`) e deixaria o ensaio de discriminar —, sai rc≠0 com a linha de recusa, o sha da cópia do hub fica idêntico antes e depois, e o arquivo é restaurado com `cmp -s` antes de seguir. No ramo equivalente, o ensaio roda sem exceção declarada. No ramo não equivalente, o ensaio declara no clone as três exceções com exatamente o texto enviado ao ADP, e o PR de release registra que o resultado do ensaio vale para o clone com a declaração, e que a proteção real depende de o ADP declarar as mesmas linhas antes de atualizar; a release não espera a declaração do ADP, mas a mensagem "0.16.0 publicada" repete a instrução. O `liaison-ops.sh` do ADP é customizado (sha `9739bd61…` contra `5c35bf1f…` no lock); o ensaio assume essa sobrescrita aceita por escrito pelo ADP, ou coberta por exceção declarada, caso em que o `cmp -s` contra o tarball é substituído pelo `cmp -s` contra a versão do clone anterior ao update. Regra do ensaio da segunda camada no clone do ADP (revisão da Fase 0, iteração 3): o resultado do `update` a partir do tarball é commitado no clone antes do `git worktree add`, ou a worktree é criada nesse commit; e a worktree mantém o próprio `_common.sh` presente (o do template ou o `cp` cru), para que um backend que leia `$LIBDIR` saia rc 0 e seja pego — sem isso, o `fs-union.sh` próprio do ADP produz a mesma recusa e o ensaio não prova nada sobre o artefato da release. No ramo equivalente (o kind do template reaproveita o nome, e o tarball tem os dois arquivos), antes do cenário `cmp -s` do `fs-union.sh` e do `liaison-ops.sh` da worktree contra os do tarball de `npm pack` precisa sair 0. No ramo não equivalente (o kind não reaproveita o nome, o tarball não tem `fs-union.sh`, e a exceção preserva o do ADP), essa regra é impossível para o `fs-union.sh`; a prova nesse ramo é: (i) `cmp -s` dos três arquivos da worktree contra as versões do clone anteriores ao update, provando que a exceção segurou; (ii) `cmp -s` do `liaison-ops.sh` da worktree contra o tarball, que continua valendo; (iii) o PR de release registra que a segunda camada do kind renomeado é provada só pelo w220 no consumidor sintético, e que o item (2) do ensaio (a recusa com o `_common.sh` do tronco renomeado) exercita o backend do ADP, não o do template.

Vermelho, executado: `liaison-ops.sh transport set ch --kind fs-union --path <HUB>`; esperado rc 0. Hoje:

```
kind inválido: fs-union (use manual|fs|git|gh)
  rc=1
```

Gate que fica: `tests/w<NNN>-liaison-fs-union-gate.sh`: `transport set --kind fs-union` rc 0 e `sync` publica com união (positiva); uma árvore com o `liaison-config.mjs` de `821178e` (copiado como fixture) lendo esse yaml sai rc≠0 e o sha do hub fica idêntico antes e depois. Cenários da segunda camada, num repositório sintético com tronco e uma worktree ligada que tem o `fs-union.sh` novo e um `_common.sh` sem `_dir_push_union` (o `cp` cru), com a fixture: `liaison.yaml` da worktree com `kind: fs-union` e `self` configurado, e um `<self>.jsonl` atrasado na worktree, enquanto o hub já tem, nesse mesmo `<self>.jsonl`, uma mensagem publicada por outra réplica da mesma identidade (o tronco) e ausente da réplica da worktree: com o `_common.sh` bom no tronco, o `sync` da worktree preserva no hub essa mensagem (positiva: a mensagem continua lá, byte-idêntica); com o `_common.sh` do tronco ausente, o `sync` sai rc≠0 com a linha `FAIL fs-union: _common.sh do checkout principal ausente`, e o sha do hub fica idêntico antes e depois. Propriedade PBT: não se aplica, os estados são enumeráveis (kind novo ou antigo × leitor novo ou antigo). Cenário novo (DA-26, J-15): com `kind: fs-union`, `check-liaison-acks.sh` lê o hub em `<path>/<canal>/log` como faz para `fs` (hoje `:179` e `:184` só leem o hub para `fs` e `manual`). Mutação: remover `'fs-union'` de `TRANSPORT_KINDS` faz o `transport set` sair rc 1; tirar `fs-union` da condição de `:179` faz o cenário de acks ler a réplica local; trocar no backend a resolução pelo tronco por `$(dirname "${BASH_SOURCE[0]}")/_common.sh` faz o cenário da worktree com `cp` cru perder a mensagem publicada pelo tronco em `<self>.jsonl`, ausente da réplica da worktree, e o cenário do tronco sem `_common.sh` sair rc 0 sem a linha de recusa. Cenário adicional (revisão da Fase 0, iteração 3): o `sync`, invocado como `(cd <worktree> && .forge/scripts/liaison-ops.sh sync <canal>)` com `FORGE_ROOT=<worktree>` inline — nunca o `liaison-ops.sh` do tronco com `cd` para a worktree, que resolveria `LIBDIR` pelo tronco (`liaison-ops.sh:103`) e deixaria o cenário de discriminar —, e a mensagem publicada pelo tronco em `<self>.jsonl`, ausente da réplica da worktree, continua byte-idêntica no hub; mutação correspondente: resolver o tronco com `forge_resolve_root` sem `FORGE_ROOT=''` faz esse cenário perder a mensagem.

Arquivos: `template/.forge/scripts/lib/liaison-config.mjs`, `template/.forge/scripts/lib/transports/fs-union.sh` (novo — `liaison-ops.sh:195` resolve o backend por `$LIBDIR/transports/$LIAISON_T_KIND.sh`, então o kind exige arquivo próprio; define `t_probe/t_push/t_pull` com o layout de hub de `fs.sh`, mas carrega o `_common.sh` do tronco com falha fechada, em vez de carregar `fs.sh`, cujo `:18` carrega o `_common.sh` da árvore que invoca), `template/.forge/schemas/liaison-config.schema.json`, `template/.forge/scripts/check-liaison-acks.sh` (`:179` e `:184`), gate novo, README, CHANGELOG. Revalidar w136 e w167, que exercitam o gate de acks.

**DoD da Onda 2:** um HANDOFF sem marcadores regenerado deixa backup byte-idêntico e o WARN com o caminho; dois `record` no mesmo change deixam as duas entradas legíveis por `check-red-first.mjs status`, inclusive quando o primeiro grava sobre um `red-evidence.json` legado; um blob apagado volta depois de um `sync` com a linha de recuperação impressa; e `transport set --kind fs-union` sai rc 0 e o `sync` publica com união, enquanto a fixture do leitor de `821178e` recusa o mesmo yaml com o sha do hub intacto, e `check-liaison-acks.sh` lê o hub do canal `fs-union`; e o backend `fs-union` carrega o `_common.sh` do tronco, preservando no hub a mensagem publicada por outra réplica da mesma identidade (o tronco), ausente da réplica da worktree, a partir de uma worktree com `cp` cru, e recusa com a linha nominal e o sha do hub intacto quando o do tronco falta. O `sync` com `FORGE_ROOT=<worktree>` inline preserva essa mensagem. Toda asserção de "não perdeu" é provada pela presença do dado recuperado, nunca só pela ausência de erro. (Mutação: propriedade do gate, não do DoD — ver seção da #123.)

Critério de saída do Bloco A: os DoD das Ondas 1 e 2 num consumidor sintético criado a partir do pacote (`npm pack` e `node bin/forge.mjs init`), incluindo uma worktree com `.forge/scripts` sem `check-secrets.sh` em que o commit sai rc 0 com a linha que nomeia o tronco; ensaio de campo em clone descartável de cada consumidor real (protocolo, release), exigindo zero `SOBRESCRITO` não aceito por escrito, chaves de topo do `settings.json` iguais antes e depois, e, no clone do axis-device-platform, `liaison-ops.sh sync` rc 0 nos 3 canais `fs-union` contra uma cópia descartável do hub e a recusa da segunda camada com o `_common.sh` do tronco renomeado, com restauração conferida por `cmp -s` (seção da #123); `node tools/plan-progress.mjs --plan ... --wave 1` e `--wave 2` com tudo ✓; aviso prévio via liaison antes da publicação ao Axis.PadSimulator, ao axis-device-platform e ao axis-go-cloud, com a lista nominal de maquinaria divergente sem exceção declarada (medida pelo cético: axis-go-cloud 32, axis-device-platform 27, Axis.PadSimulator 11, axis-fare-validator 0, vellus 1) e a instrução de declarar exceção antes do update (ao PadSim, para `scripts/lib/heavy-mutex.sh`, DA-06; ao ADP, os três arquivos de liaison nomeados na seção da #123, no ramo que a comparação dos desfechos decidir); e mensagem "0.16.0 publicada: risco por arquivo" com as exceções que expiram por consumidor, mais a nota no CHANGELOG, recomendando reexecutar isoladamente qualquer alvo sem linha FAIL antes de classificar uma reprovação (J-05). Antes da release, o PR de reconciliação do Bloco A (protocolo, item 11), que cria o item de roadmap da DA-09 e grava as resoluções de ledger do bloco. Não publicar a 0.16.0 sem a #141, sem ensaio de campo e sem aviso prévio. Regra do ensaio da segunda camada no clone do ADP, incluindo a condição de ramo do `cmp -s` contra o tarball: ver seção da #123.

## Onda 3 — o que trava o trabalho de quem instalou, e o runner que não distingue morto de reprovado (Bloco B, 0.17.0)

### #132 e #134 — push de deleção pura roda a suíte inteira (um PR)

**#132** · **#134** · Closes #132 · Closes #134 · gate novo: sim (um gate para o PR)

Causa raiz comum, provada: no template, o único teste de `lsha` zero fica dentro dos laços de varredura (`template/.forge/hooks/git/pre-push:79` e `:272`); `run_check "typecheck"` e `run_check "test"` (`:324-325`), os gates (`:431`) e `harness-tests` (`:478`) rodam incondicionalmente. As duas issues descrevem a ausência do mesmo curto-circuito; a sentinela `_viu_ref` da #132 é patch local do Axis.DevicePlatform (0 ocorrências no template e em cinco consumidores), e o manifesto órfão da #134 não existe no template (o pre-push do template não carimba manifesto). A contribuição da #132 que vale aqui é a propriedade de três entradas.

Desenho, reaproveitando L3 D1–D6: antes de `:324`, classificar a entrada do stdin em três estados — vazia, só deleções, mista — e, em só deleções, pular typecheck, test, gates e harness-tests com a linha `pre-push: push de deleção pura (<n> ref(s)) — checks de árvore não se aplicam`. Entrada vazia e entrada mista continuam rodando tudo. Alternativa descartada: tratar entrada vazia como deleção, que é o colapso da `_viu_ref` que a #132 mede. Decisão: DA-10 (sem política própria nesta rodada; roadmap na Onda 8).

Vermelho, executado (`/tmp/fh-A-134.sh`): `runtime.test` e `runtime.typecheck` gravam num marker; stdin `(delete) 000…0 refs/heads/x <sha>`; esperado marker vazio e a linha de deleção pura. Hoje, e o controle com stdin vazio mostra o mesmo marker:

```
pre-push: typecheck OK
pre-push: test OK
  marker: RODOU-TYPECHECK RODOU-TEST
```

Gate que fica: `tests/w<NNN>-prepush-delecao-pura-gate.sh`, com a positiva (linha de deleção pura presente) e os dois contrafactuais (vazia e mista gravam o marker). Ajustar a fixture de `w97:38` para `local_sha` não zero (L3 §7.1 mediu o w97 vermelho sem isso); revalidar w135, w146, w147, w151, w152 e w160. Propriedade PBT: para listas geradas de linhas de ref (0 a 6 linhas, cada uma deleção ou publicação, em ordem aleatória), a suíte roda se e somente se a lista é vazia ou contém ao menos uma linha com `lsha` não zero. Mutação: remover o curto-circuito faz o caso só-deleções gravar o marker; tratar vazia como deleção faz o contrafactual vazio ficar sem marker.

Arquivos: `template/.forge/hooks/git/pre-push`, `tests/w97-hook-portability-gate.sh`, gate novo, README, CHANGELOG.

### #135 — `run_check` sem teto e suíte muda

**#135** · Refs #135 · gate novo: sim

Causa raiz: `template/.forge/hooks/git/pre-push:204-222` executa `eval "$cmd"` com saída redirecionada até o fim e sem teto, enquanto `forge_run_gate` (`template/.forge/scripts/lib/forge-runtime.sh:20` e `:49`) tem `perl alarm` de 300 s; `template/.forge/scripts/tests/run-all.sh:66-92` só imprime o nome do teste depois que ele termina.

Desenho, reaproveitando L3 §3.4: teto opt-in por valor (`FORGE_PREPUSH_CHECK_TIMEOUT_S`, sem default) aplicado por `perl alarm`; estourado, o hook sai rc≠0 com `pre-push BLOQUEADO: <label> excedeu o teto de <n>s (morto por teto, não reprovado)`; e `run-all.sh` do template anuncia o nome do teste antes de executá-lo. Alternativa descartada: reusar os 300 s de `forge_run_gate` como default, que mataria suítes legítimas de consumidor medidas em mais de dez minutos. Fica `Refs` porque o terceiro item do corpo (manifesto em `running`) é maquinaria do consumidor e a distinção "morto por teto" no runner é o LDG-0181, que entra na mesma onda logo depois deste PR. Decisão: DA-11 (nenhum default de teto; ausente significa desligado) e DA-19 (depois do merge do PR do LDG-0181, a #135 é fechada à mão com comentário que aponta o resíduo rastreado).

Vermelho, executado (`/tmp/fh-R02-Bprepush.sh`): `runtime.test: sleep 8` e `FORGE_PREPUSH_CHECK_TIMEOUT_S=2`; esperado rc≠0 nomeando `test` e o teto. Hoje a variável é ignorada:

```
  rc=0 elapsed=43s
pre-push: test OK
pre-push OK
```

Gate que fica: `tests/w<NNN>-prepush-teto-de-check-gate.sh`: com teto, rc≠0 e a linha "morto por teto" presente; sem teto, `sleep 3` passa (contrafactual); `run-all.sh` com teste `sleep 5` tem o nome impresso antes do término (positiva por timestamp da linha). Propriedade PBT: para pares gerados (duração d, teto t) com |d − t| ≥ 2 s e d, t ≤ 6, o desfecho é "morto por teto" se e somente se d > t. Mutação: remover o `perl alarm` faz o cenário com teto sair rc 0.

Arquivos: `template/.forge/hooks/git/pre-push`, `template/.forge/scripts/tests/run-all.sh`, gate novo, README, CHANGELOG.

### #144 e #137 — dono vivo nunca é reclamável (um PR)

**#144** · **#137** · Closes #144 · Closes #137 · gate novo: sim (um gate para o PR)

Causa raiz comum, provada: a política "dono vivo nunca é reclamável" mora num único ramo do laço de aquisição, `template/.forge/scripts/lib/heavy-mutex.sh:869-890`. Em `:877-880` o único reclaim é `if ! _fhm_alive "$holder" "$htok"; then _fhm_reclaim_orphan ...`, e `_fhm_alive` (`:274-286`) classifica como vivo qualquer processo com token coerente e estado diferente de Z — inclusive o dono reparentado para o PID 1 (#144). Em `:882-888` quem espera sai com 75 atrás de qualquer dono vivo, qualquer que seja a idade da posse, porque o template não tem teto de posse (`grep -c STALE_AFTER heavy-mutex.sh` → 0; o 3600 da #137 é do fork do Axis.PadSimulator). As duas correções inserem ramos novos entre `:880` e `:882` e compartilham o primitivo de encerramento `TERM → graça → KILL` com remoção só depois de morte confirmada (L2 D6); em PRs separados, o segundo reescreveria o primeiro.

Desenho, reaproveitando L2 D1, D2, D5, D6, D7, D8 e D9, com um desvio em D3: o lock grava `beneficiary` e `beneficiary_token` quando o chamador declara o beneficiário pela variável de ambiente `FORGE_HEAVY_MUTEX_BENEFICIARY=<pid>`, nunca por flag nova; o `pre-push` passa `FORGE_HEAVY_MUTEX_BENEFICIARY="$PPID"` só na chamada de `pre-push:245`, e o `heavy-run.sh` não declara. Por ambiente porque o `pre-push` do tronco carrega a lib da worktree (`pre-push:232`), e uma lib de v0.15.0 recusa flag desconhecida com rc 64 (`heavy-mutex.sh:745`), o que mataria o push (J-06, reproduzido); a lib antiga ignora a variável. Detentor vivo com beneficiário declarado morto é reclamado; campo ausente, vazio, não numérico ou ≤ 1 nunca é licença para reclamar. Ordem no laço: dono morto, beneficiário morto, idade acima do teto. O desvio: o teto de posse (`FORGE_HEAVY_MUTEX_STALE_AFTER_S` > `heavy_mutex.stale_after_s`) é opt-in, ausente significa desligado; quando declarado, o valor é respeitado e a invariante de L2 D4 (`efetivo + reserva ≤ teto de espera`) vira aviso de três números (declarado, espera, reserva), sem rebaixar (DA-06: o Axis.PadSimulator declara `timeout_s 1800` e `stale_after_s 3600`, e rebaixar encerraria antes de 1800 s um dono vivo que o consumidor declarou poder durar 3600). L2 D3 derivava o teto da metade da espera por padrão, o que passaria a matar dono vivo em todos os consumidores depois de 900 s.

Alternativas descartadas: reclamar quando `ppid == 1` (sugestão 1 da #144), que mata `nohup`, LaunchAgent, contêiner e runner daemonizado (L2 D1); derivar a espera do teto de posse (sugestão 1 da #137), que levaria um `git push` a esperar mais de uma hora e agrava a #144 (L2 D3).

Decisão: DH-5 (teto opt-in; o lado forte é o LDG-0185, na Onda 8) e DA-06 (valor declarado respeitado, com WARN).

Vermelho, executado (`/tmp/fh-A-mutex.sh` e bancada R02 da #137, `FORGE_HEAVY_MUTEX_ROOT` em mktemp). #144: dono vivo com ppid 1 e esperante com timeout 4 s, esperado rc 0 depois de o beneficiário morrer. #137: dono vivo por 30 s, esperante com `FORGE_HEAVY_MUTEX_STALE_AFTER_S=2 FORGE_HEAVY_MUTEX_TIMEOUT_S=10`, esperado aquisição antes de 10 s. Hoje a variável não é lida e os dois saem 75:

```
  dono pid=22479 ppid=1 label=holder-orfao
  esperante rc=75 elapsed=6s
esperante rc=75 elapsed=17s
```

Gate que fica: `tests/w<NNN>-heavy-mutex-posse-gate.sh`, com contrafactuais obrigatórios: dono em `nohup` sem beneficiário declarado não é reclamado (e o esperante sai 75 nomeando o motivo); beneficiário vivo não é reclamado; recolhimento imprime o motivo (`beneficiário morto` ou `posse acima do teto`) e o censo de descendentes (positiva). Revalidar w151 e w154, que exportam `FORGE_HEAVY_MUTEX_TESTING` de formas diferentes. Cenários de versão mista (protocolo, item 4): `pre-push` novo com a lib de v0.15.0 (fixture por `git show v0.15.0:template/.forge/scripts/lib/heavy-mutex.sh`) sai rc 0; detentor com lib antiga e esperante com lib nova sobre o mesmo lock, e o inverso; e os valores reais do PadSim (1800/3600) com o WARN de três números presente e o teto efetivo igual a 3600.

Propriedade PBT: para teto de espera gerado em [0, 200] e teto de posse declarado gerado (ausente, 0, e valores entre 1 e 100000), o teto efetivo é 0 quando ausente e igual ao declarado quando positivo, e o WARN de três números aparece se e somente se `declarado + reserva > espera`; e para estados de campo gerados de `beneficiary` e `acquired_at` (ausente, vazio, não numérico, ≤ 0, futuro, válido), o lock só é reclamado nos estados válidos com beneficiário morto ou idade acima do efetivo.

Mutação: remover o ramo de beneficiário faz o cenário #144 sair 75; tratar `acquired_at` ausente como idade infinita faz o w151[49](c) sair rc 0 antes de 8 s (L2 D5, M13); remover a confirmação de morte antes de `_fhm_reclaim_orphan` faz o cenário de detentor imortal (outro uid simulado) remover o lock com o detentor vivo.

Arquivos: `template/.forge/scripts/lib/heavy-mutex.sh`, `template/.forge/hooks/git/pre-push`, `template/.forge/schemas/forge.schema.json` (`stale_after_s` e a paridade de `root` de L2 D12), `template/.forge/forge.yaml` (comentário da chave, sem valor), gate novo, README, CHANGELOG.

### #146 — SIGINT não aciona `_hr_sig` quando INT nasce ignorado

**#146** · Closes #146 · gate novo: sim

Causa raiz: bash não interativo não arma `trap` sobre sinal ignorado na entrada. `template/.forge/scripts/heavy-run.sh:191` (`trap "_hr_sig $s" "$s"`) vira no-op quando o wrapper é lançado com `SIGINT=SIG_IGN` herdado (`( nohup ... & ) &`), e a carga herda a mesma disposição.

Desenho: depois de armar, o wrapper confere `trap -p INT`; se veio vazio, ele se reexecuta uma vez com a disposição resetada por um processo não bash (`perl -e '$SIG{INT}=$SIG{TERM}="DEFAULT"; exec @ARGV'`, com uma variável de guarda contra laço), e a carga é lançada com INT e TERM na disposição padrão. HUP fica de fora do reset, herdado como veio: resetar HUP também mataria, no fechamento do terminal, o processo que o lançamento em `nohup` do campo existe para proteger — exatamente o invariante que a Onda 3/#144 exige preservar (dono em `nohup` sem beneficiário declarado não é reclamado). Se HUP precisar de tratamento próprio no wrapper, é decisão separada, fora deste PR. Sem `perl`, recusa com rc 70 e diagnóstico em vez de rodar sem trap. Alternativa descartada: ignorar o problema e documentar o lançamento, que é exatamente o modo `nohup` do campo; e `set -m` no wrapper, que não reverte `SIG_IGN` herdado (medido na triagem).

Vermelho, executado (`/tmp/fh-A-146.sh`, `FORGE_HEAVY_MUTEX_ROOT` em mktemp): `bash -c "trap '' INT; exec bash heavy-run.sh --resource r -- sleep 12" &` e `kill -INT` aos 2 s; esperado rc 130 em menos de 3 s. Hoje:

```
[controle] set -m, INT padrão na entrada : rc=130 elapsed=2s lock_restante=0 sleep_12_vivo=0
[caso] set -m, INT IGNORADO na entrada   : rc=0 elapsed=13s lock_restante=0 sleep_12_vivo=0
```

Gate que fica: `tests/w<NNN>-heavy-run-signal-disposition-gate.sh`, positiva rc 130 e `sleep` morto em menos de 3 s no caso ignorado, e controle idêntico no caso padrão. Propriedade PBT: não se aplica; o espaço exercitado é {INT, TERM} × {padrão, ignorado}, quatro casos — HUP não entra no reset e por isso não faz parte deste espaço (ver desenho acima); um cenário à parte confirma que a disposição de HUP herdada (ignorada ou padrão) atravessa a reexecução sem ser alterada. Mutação: remover a reexecução faz o caso ignorado voltar a rc 0 com ~13 s.

Arquivos: `template/.forge/scripts/heavy-run.sh`, gate novo, README, CHANGELOG.

### #127 — o doctor desce em worktrees e mede menção como configuração

**#127** · Closes #127 · gate novo: sim

Causa raiz: `template/.forge/scripts/doctor.sh:115` e `:119` fazem `grep -rl` sobre `$ROOT/.forge` inteiro e filtram só a saída; o filtro `USER_DATA` (`:114`) não exclui `liaison/` nem `ledger/`, onde `.claude/` aparece como texto de conversa.

Desenho, reaproveitando L6 D (§2.3): universo por inclusão da fonte canônica — `rules/`, `agents/`, `skills/`, `commands/`, `templates/` e os arquivos canônicos de topo de `.forge/` — passado explicitamente ao `grep`, com contador de arquivos examinados e terceiro estado quando o universo é vazio. Alternativa descartada: ampliar a denylist com `liaison|ledger|worktrees`, que continua pagando a descida quando o filtro é de saída e deixa entrar o próximo diretório de dados que alguém criar.

Vermelho, executado (`/tmp/fh-R02-Bupdate.sh`): menção a `.claude/settings.json` só em `.forge/liaison/ch/log/p.jsonl` e numa worktree; esperado `✓ fonte canônica sem refs`. Hoje:

```
  ✗ harness: 1 arquivo(s) da fonte canônica com refs .claude/
  varredura bruta desce em worktrees? 1
```

Gate que fica: `tests/w<NNN>-doctor-scan-universe-gate.sh`: menção só em liaison/ledger/worktrees dá ✓ e o contador de examinados é maior que zero (positiva); menção plantada em `rules/` dá ✗ (contrafactual); um shim de `grep` em PATH registra argv e nenhum caminho contém `/worktrees/`. Revalidar w158. Propriedade PBT: para colocações geradas de menções em diretórios aleatórios (canônicos e de dados), a contagem reportada é igual ao número de arquivos com menção dentro do universo de inclusão. Mutação: voltar `$ROOT/.forge` como universo faz o cenário do liaison dar ✗.

Arquivos: `template/.forge/scripts/doctor.sh`, gate novo, README, CHANGELOG.

### #129 — a isenção .NET não alcança caminho relativo

**#129** · Closes #129 · gate novo: sim

Causa raiz: `template/.forge/hooks/pre-tool-use/validate-naming-conventions.sh:51` exige `/` antes de `src|tests|services|deploy`; caminho relativo que começa no segmento não casa e o `elif` reprova PascalCase.

Desenho: âncora `(^|/)(src|tests|services|deploy)(/|$)`. Alternativa descartada: absolutizar o caminho no início do hook, que muda o que é impresso nas mensagens e depende do cwd de quem chama.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `bash validate-naming-conventions.sh "src/Axis.T.Infrastructure/Communications/BanklyCommunication.cs"`; esperado rc 0. Hoje:

```
  relativo rc=1
  absoluto rc=0
  controle mysrc rc=1
```

Gate que fica: `tests/w<NNN>-naming-path-provenance-gate.sh`, positiva relativo rc 0 e contrafactual `mysrc/Communications/X.cs` rc 1. Propriedade PBT: para caminhos gerados com o segmento isento em profundidade aleatória, diretórios PascalCase aleatórios e prefixo absoluto presente ou ausente, o veredito com prefixo é igual ao veredito sem prefixo; e segmento com prefixo colado (`mysrc`, `srcx`) nunca isenta. Mutação: voltar a âncora a `/` faz o caso relativo sair rc 1.

Arquivos: `template/.forge/hooks/pre-tool-use/validate-naming-conventions.sh`, gate novo, README, CHANGELOG.

### LDG-0181 — o runner do template tem dois desfechos por alvo

**LDG-0181** · gate novo: sim (w239, runner do template) e cenário novo no w212 (runner interno) · depois do PR da #135 (mesmo `template/.forge/scripts/tests/run-all.sh`)

Causa raiz, medida em 2026-09-25: `template/.forge/scripts/tests/run-all.sh:72` executa o alvo e todo rc≠0 cai no mesmo ramo ✗; `:91` reexecuta `"$@"` para imprimir o tail, o que roda o alvo duas vezes e, num alvo morto por sinal, mata duas vezes; `grep -cE 'UNV|sinal'` no arquivo dá 0. O runner interno (`tests/run-all.sh`) já tem três estados desde o LDG-0180, mas sai rc 0 com "OK — suíte 100% verde" (`:272`) quando zero gates rodam. O template distribui o runner com zero testes (`find template/.forge/scripts/tests -type f` → só o próprio `run-all.sh`) e o `pre-push` o executa (`pre-push:476-478`).

Desenho, conforme DA-01: no template, 0 verde, 1 reprovação (precedência sobre 3), 3 não verificado (sinal 129–192, 126/127 dependência ausente, árvore não medida), 64 e 66 continuam uso e diretório; o ramo de falha grava a saída da primeira execução em log e imprime o `tail -20` do log, sem reexecutar; zero testes dá rc 0 com a linha nominal `nada a rodar`. No runner interno, zero gates dá UNV e rc 3. Retrocompatível: nos dois runners o 3 continua bloqueando como o 1. Alternativa descartada: renumerar o template para o mapa do runner interno (2 para argumento desconhecido), que mudaria o rc de uso que um consumidor pode testar.

Vermelho, a executar contra a base no PR: no diretório de testes de um consumidor sintético, um alvo `kill -TERM $$` e outro `exit 1`, cada um gravando uma linha num marcador; esperado rc 3 com linha UNV nomeando o sinal no primeiro caso, rc 1 no segundo e uma linha por alvo no marcador. Pela leitura de `:72` e `:91`, hoje sai rc 1 nos dois e o alvo que falha grava duas linhas; o implementador cola a saída real.

Gate que fica: `tests/w239-template-runner-tres-estados-gate.sh`: alvo morto por sinal dá rc 3 e UNV nomeando o sinal; `exit 127` dá rc 3 nomeando dependência ausente; `exit 1` dá rc 1, inclusive quando outro alvo sai 3 (precedência); uma linha por alvo no marcador (positiva de não reexecução); zero testes dá rc 0 com `nada a rodar`; argumento desconhecido dá 64 e diretório inexistente dá 66 (contrafactuais de contrato). No w212, cenário novo: zero gates dá UNV e rc 3. Revalidar w80, w146, w153, w212 e w213, que executam os runners. Propriedade PBT: para listas geradas de 0 a 6 alvos com rc em {0, 1, 2, 126, 127, 130, 137, 143}, o rc do runner é 1 se algum alvo reprova, senão 3 se algum não foi verificado, senão 0; e cada alvo executa exatamente uma vez. Mutação: recolocar a reexecução faz o marcador ganhar uma segunda linha; tratar 129–192 como reprovação faz o cenário do sinal sair rc 1; piso 1 no template faz o cenário de zero testes sair rc 3.

Arquivos: `template/.forge/scripts/tests/run-all.sh`, `tests/run-all.sh`, `tests/w212-runner-tres-estados-gate.sh`, gate novo, README, CHANGELOG; a nota de release da 0.17.0 descreve o rc 3 aos consumidores.

### #157 — o `/forge:upgrade` não verifica o resultado do overlay

**#157** · Closes #157 · gate novo: sim (w240) · depois do PR do LDG-0181 (J-05); antes do PR da #153 (mesmo `upgrade.md`)

Causa raiz: o protocolo de `template/.forge/commands/harness/upgrade.md` termina em aplicar (passo 3), garantir `core.hooksPath` (4), medir a propagação para worktrees (5) e resumir (6); nenhum passo roda a suíte do consumidor nem compara as reprovações com a versão anterior ao overlay (`grep -c run-all template/.forge/commands/harness/upgrade.md` → 0, medido em 2026-09-25). O corpo da issue mede dois episódios num upgrade 0.6.0 → 0.15.0: regressões em dez arquivos que a revisão de diff não viu, e um teste realinhado ao valor novo que apagou o defeito do relatório.

Desenho, a proposta da issue: um passo novo entre o 3 e o 4 manda rodar `bash .forge/scripts/tests/run-all.sh` (e os checks declarados no `FORGE.md`) depois do overlay, e upgrade sem essa execução não é declarado concluído; cada reprovação é triada contra a versão pré-upgrade (`git show HEAD:<path>` ou o backup em `<git-dir>/forge-backups/`, resolvido por `git rev-parse --git-dir` como em `bin/forge.mjs:596`, porque numa worktree ligada `.git` é arquivo) em três classes com remediação distinta (regressão, evolução legítima do template, fixture desatualizada); o critério de desempate (`git grep -n -- '<valor antigo>'` em código de produção) vem antes de chamar algo de fixture desatualizada; alvo com desfecho não verificado (rc 3, LDG-0181) é reexecutado isoladamente antes de classificar, nunca classificado como regressão; e o passo 6 lista cada reprovação com a classe atribuída. Por que depois do LDG-0181: sem o terceiro estado, o runner confunde gate morto com reprovado, e a triagem classificaria morte como regressão. Alternativa descartada: rodar a suíte dentro de `bin/forge.mjs update`, que muda o contrato e a duração do comando para todo consumidor.

Vermelho, executado: `grep -c run-all template/.forge/commands/harness/upgrade.md`, esperado ≥1 com a linha entre os passos 3 e 4. Hoje: `0`.

Gate que fica: `tests/w240-upgrade-verifica-suite-gate.sh`, estático e por posição de linha: o passo que roda `run-all.sh` fica entre "Aplique" e o passo do `core.hooksPath`; as três classes nomeadas; o critério de desempate com `git grep`; a reexecução isolada de alvo não verificado; o resumo com a classe por reprovação; espelho do plugin idêntico. Revalidar w63 (confere a chegada de `upgrade.md` pelo overlay), `plugin-sync-gate` e w200. Propriedade PBT: não se aplica. Mutação: mover o passo para depois do resumo faz o confronto de posição falhar; remover a classe "fixture desatualizada" faz a contagem de classes falhar.

Arquivos: `template/.forge/commands/harness/upgrade.md` (+ espelho `plugin/forge/commands/upgrade.md` via `npm run build:plugin`), gate novo, README, CHANGELOG.

**DoD da Onda 3:** um esperante atrás de dono vivo com beneficiário morto adquire com rc 0 e a linha do motivo, e o contrafactual `nohup` sem beneficiário continua 75; `heavy-run.sh` lançado com INT ignorado sai 130 em menos de 3 s; um push de deleção pura imprime a linha própria e deixa o marker vazio, enquanto entrada vazia e mista gravam o marker; um check que excede o teto declarado sai rc≠0 com "morto por teto"; o doctor dá ✓ com menção só em dados e contador de examinados maior que zero; o hook de nomes aceita `src/...` relativo e continua reprovando `mysrc/...`; o runner do template distingue verde, reprovado e não verificado com os rc 0, 1 e 3, executa cada alvo uma única vez e sai rc 0 com `nada a rodar` sobre zero testes, enquanto o runner interno sai rc 3 sobre zero gates; e `upgrade.md` manda rodar a suíte do consumidor depois do overlay e triar cada reprovação em uma das três classes.

Critério de saída do Bloco B: DoD da Onda 3 no consumidor sintético, `node tools/plan-progress.mjs --plan ... --wave 3` com tudo ✓, ensaio de campo e mensagem de release como no Bloco A, o PR de reconciliação do Bloco B (protocolo, item 11) mergeado, e só depois a #135 fechada à mão conforme DA-19. Não publicar a #157 antes de o runner do template ter três estados.

## Onda 4 — o que passa verde sem medir (Bloco C, 0.18.0)

### #119 — lib antiga com gates CSV imprime "0 gate(s)" e passa

**#119** · Closes #119 · gate novo: não (amplia `tests/w190-pre-push-gate-reader-gate.sh`)

Causa raiz: a guarda de leitor indisponível em `template/.forge/hooks/git/pre-push:418` só dispara quando `_gates_inline` é vazio (forma mapeada); com CSV declarado, `:431` (`forge_runtime_gate_entries "$ROOT" || true`) engole o `command not found` e `:437-440` imprime NO-GATES com rc 0.

Desenho, a forma (b) da issue: se o frontmatter declara `gates:` com valor e o leitor devolve zero entradas, bloquear com `pre-push BLOQUEADO: runtime.gates declara <valor> e o leitor devolveu ZERO gate(s)`, nomeando a causa quando a função não existe (`type forge_runtime_gate_entries`). Alternativa descartada: mover a guarda para antes da forma, sem olhar o valor, que recusaria o primeiro push de todo projeto novo com `gates:` vazio (o comentário de `:410-417` registra isso).

Vermelho, executado (`/tmp/fh-R02-Bprepush.sh`): `gates: check-aa,check-bb`, os dois scripts presentes, função renomeada na lib e `gate-phase.mjs` removido; esperado rc≠0 com "leitor devolveu ZERO". Hoje:

```
.forge/hooks/git/pre-push: line 431: forge_runtime_gate_entries: command not found
pre-push: runtime.gates NO-GATES — 0 gate(s) declarado(s) no FORGE.md
pre-push OK
```

Gate que fica: cenários novos no w190 — lib antiga + CSV bloqueia com a mensagem nominal (positiva), lib nova + CSV imprime "2 gate(s) de fase 'source'" (controle), `gates:` vazio segue NO-GATES com rc 0 (contrafactual). Propriedade PBT: não se aplica; o espaço é {função presente, ausente} × {CSV, mapeada, vazia}, seis casos exercitados. Mutação: remover a contradição "declarou e leu zero" faz o cenário da lib antiga sair rc 0.

Arquivos: `template/.forge/hooks/git/pre-push`, `tests/w190-pre-push-gate-reader-gate.sh`, CHANGELOG.

### #106 — `runtime.test` sem guarda de cobertura

**#106** · Refs #106 · gate novo: sim

Causa raiz: `template/.forge/hooks/git/pre-push:325` executa `fm_field test` como texto livre; nada confronta o comando com as superfícies de build da árvore (`grep -cE 'sln|csproj|dotnet'` no hook → 0).

Desenho: aviso, nunca bloqueio por padrão: se a árvore rastreada (`git ls-files`) contém `*.sln` ou `*.csproj` e `runtime.test` não contém `dotnet`, imprimir `pre-push: AVISO — <n> solution(s) .NET rastreada(s) e runtime.test ('<cmd>') não invoca dotnet; a suíte .NET não roda neste gate`. Reconhecimento restrito à stack .NET, que é a medida (axis-go-cloud: 24 `.sln`, `test: pnpm test`). Alternativa descartada: bloquear, que reprovaria todo push de consumidor cujo `runtime.test` chama um script que por sua vez chama `dotnet` — a heurística por comando não vê através de script. Fica `Refs`: a issue pede decisão sobre bloqueio e sobre as demais stacks. Decisão: DA-12 (só aviso, só .NET; bloqueio opt-in e outras stacks viram roadmap na Onda 8) e DA-20 (depois do merge, a #106 é fechada à mão com comentário que aponta esse item).

Vermelho, executado (`/tmp/fh-R02-Bprepush.sh`): `App.sln` rastreado e `test: echo SUITE-RAN >> marker`; esperado a linha de AVISO. Hoje:

```
pre-push: test OK
pre-push OK
  avisos dotnet/.sln: 0
```

Gate que fica: `tests/w<NNN>-prepush-cobertura-dotnet-gate.sh`: `.sln` + `pnpm test` imprime o AVISO e sai rc 0 (positiva e não bloqueio); `test: dotnet test App.sln` não avisa (contrafactual); `.sln` não rastreado não avisa. Propriedade PBT: para árvores geradas (0 a 3 arquivos `.sln`/`.csproj`, rastreados ou não) e comandos gerados (com e sem `dotnet` em posição aleatória), o aviso aparece se e somente se há arquivo .NET rastreado e o comando não contém `dotnet`. Mutação: remover a condição de rastreado faz o cenário não rastreado avisar.

Arquivos: `template/.forge/hooks/git/pre-push`, gate novo, README, CHANGELOG.

### #138 — Red-first sem caminho em change `type: feature` que corrige defeito

**#138** · Closes #138 · gate novo: sim · depois do PR da #139

Causa raiz: todo ponto de decisão testa `type === 'bugfix'`: `template/.forge/scripts/lib/red-evidence-ops.mjs:69` e `:219`, `check-red-first.mjs:166`, `:350` e `:539`, `red-evidence.sh:66` e `:122`, `hooks/git/lib/check-red-first.sh:123` e `spec-verify.sh:118`. Em `feature`, a escrita recusa e a leitura responde `n/a` com rc 0.

Desenho, reaproveitando L5 D1–D3 e D20: `manifest.yaml` ganha `fixes_defects` (lista de ids); o predicado único `isDefectFixing(manifest)` = `type === 'bugfix' || fixes_defects não vazio`, em `lib/defect-scope.mjs` novo, consumido pelos nove sítios; em change que declara a lista, a cobrança exige uma entrada de `entries` (da #139) por id declarado. O WARN do item 3d deixa de dizer "type mudou" quando a lista existe. Alternativas descartadas: relaxar a escrita para qualquer `type` (opção A), que registra sem cobrar; derivar de commits `fix(...)` (opção C), heurística sobre mensagem.

Vermelho, executado (`/tmp/fh-A-139.sh`, segundo bloco): mesmo change com `type: feature`; esperado, com `fixes_defects` declarado e sem evidência, `check` rc≠0. Hoje o campo não existe e o change fica fora da política:

```
FAIL (red-evidence só se aplica a change type:bugfix, got: feature)
OK (n/a — type: feature)
  check rc=0
```

Gate que fica: `tests/w<NNN>-red-defect-scope-gate.sh`: `feature` + `fixes_defects: [D1]` sem evidência reprova nomeando D1 (positiva); `feature` sem o campo segue `n/a` (contrafactual); dois ids e uma entrada reprova nomeando o faltante. Revalidar w106, w107 e w144. Propriedade PBT: para manifestos gerados (`type` em {bugfix, feature, refactor, chore}, `fixes_defects` ausente, vazio ou com 1 a 3 ids), a aplicabilidade reportada pelos nove sítios é idêntica entre eles e igual a `isDefectFixing`. Mutação: voltar um dos sítios a `type === 'bugfix'` faz a propriedade de igualdade entre sítios falhar nomeando o arquivo.

Arquivos: os nove sítios acima, `template/.forge/scripts/lib/defect-scope.mjs` (novo), `template/.forge/schemas/spec-manifest.schema.json`, `template/.forge/rules/testing/regression-red-first.md`, `template/.forge/commands/testing/red.md` (+ plugin), gate novo, README, CHANGELOG.

### #150 — replay sem controle positivo aceita falha adjacente

**#150** · Closes #150 · gate novo: não (amplia `tests/w107-red-replay-gate.sh`) · depois do PR da #138 (mesmos `red.md` e `regression-red-first.md`)

Causa raiz: `template/.forge/scripts/lib/red-replay.mjs:469-473` (`matchesPattern` devolve `true` com padrão nulo) e `:643-675` (base falhou → `observed`, sem prova de que a base seria capaz de ficar verde). `record` já exige `--failure-pattern` (`red-evidence-ops.mjs:114`), mas o schema aceita `null` e um padrão genérico legítimo produz o mesmo desfecho.

Desenho: (1) `replay` recusa `failure_pattern` nulo ou vazio com `not-possible` e rc≠0, sem mexer no schema; (2) campo opcional `positive_control` (comando que precisa passar na base, na mesma corrida e no mesmo checkout); declarado e falhando na base, o veredito é `not-possible` com a saída do controle no excerpt. Alternativa descartada: tornar `failure_pattern` obrigatório no schema, que invalida evidências gravadas por escritores antigos em vez de só recusar o replay. Decisão: DA-13 (`positive_control` opcional; a obrigatoriedade vira roadmap na Onda 8) e DA-21 (fecha pelo próprio PR, com `Closes #150`): a regra `regression-red-first.md` e o comando `red.md` ganham o item 3 do corpo, que diz que âncora que não falha na base é defeito do teste e que o teste afirma o caminho, não só o resultado. Se o texto não entrar, o PR volta a `Refs` e a issue é fechada à mão com o resíduo rastreado.

Vermelho, executado (`/tmp/fh-A-150.sh`): fixture em que a base falha só por fixture ausente e o "fix" é cosmético; com `failure_pattern: null`, esperado rc≠0. Hoje:

```
[B] failure_pattern nulo (campo opcional no schema?) → replay:
OK replay — Red observado (ancestry, base 72ad02f) e Green confirmado em HEAD
  rc=0
```

Gate que fica: cenários novos no w107 — nulo recusa com `not-possible` (positiva: status gravado `not-possible` e motivo nomeado); `positive_control` que falha na base dá `not-possible`; controle que passa na base mantém o `observed` do caso legítimo (contrafactual). Propriedade PBT: para padrões gerados (nulo, vazio, string aleatória presente ou ausente na saída da falha), `observed` nunca é gravado com padrão nulo ou vazio. Mutação: devolver `true` para padrão nulo em `matchesPattern` faz o cenário nulo gravar `observed`.

Arquivos: `template/.forge/scripts/lib/red-replay.mjs`, `template/.forge/schemas/red-evidence.schema.json` (`positive_control` opcional), `template/.forge/rules/testing/regression-red-first.md`, `template/.forge/commands/testing/red.md` (+ espelho `plugin/forge/commands/red.md` via `npm run build:plugin`), `tests/w107-red-replay-gate.sh`, CHANGELOG. Revalidar `plugin-sync-gate` e w200.

### #128 — run-manifest.sh descarta o `--root` do chamador

**#128** · Closes #128 · gate novo: sim

Causa raiz: `template/.forge/scripts/run-manifest.sh:6` anexa `--root "$ROOT"` depois de `"$@"`, e `template/.forge/scripts/lib/run-manifest.mjs:23` deixa a última ocorrência vencer.

Desenho: o wrapper só anexa `--root` quando o chamador não passou um; `parseArgs` recusa chave escalar repetida com valores diferentes (`FAIL: --root informado duas vezes com valores diferentes`) e aceita repetição idêntica. Alternativa descartada: recusar toda repetição, idêntica ou não, que quebraria chamador que repete por construção sem ganho de segurança.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `bash A/.forge/scripts/run-manifest.sh write --root B --stage verify --dir B/out --status passed`; esperado `head_sha` igual ao HEAD de B. Hoje:

```
  rc=0
  head_sha gravado=5b77af532748 A=5b77af532748 B=956f8e41f07e
```

Gate que fica: `tests/w<NNN>-run-manifest-root-gate.sh`: `head_sha` = HEAD de B (positiva); valores diferentes recusam; sem `--root`, grava o HEAD da árvore do wrapper (contrafactual). Revalidar w90 e w91. Propriedade PBT: para permutações geradas dos argumentos com `--root` em posição aleatória, o `head_sha` gravado é sempre o HEAD do `--root` do chamador. Mutação: voltar o anexo incondicional faz o cenário principal gravar o HEAD de A.

Arquivos: `template/.forge/scripts/run-manifest.sh`, `template/.forge/scripts/lib/run-manifest.mjs`, gate novo, README, CHANGELOG.

### #133 — flag desconhecida aceita e flag engolida como valor em liaison-ops e deferral-ops

**#133** · Closes #133 · gate novo: sim

Causa raiz: guarda aplicada por sítio, sem declaração verificável de cobertura. `template/.forge/scripts/deferral-ops.sh:133-150` (`status`) não tem laço de parsing e `:114-115` (`test`) lê só `$1`; `template/.forge/scripts/liaison-ops.sh:771` (`--thread) filter_thread="$2"`) não chama `forge_reject_flag_as_value`, e L4 §1.1 contou 11 sítios assim. `lib/argparse.sh` nunca existiu no template (a regressão do corpo vem do overlay da #101 no consumidor).

Desenho, reaproveitando L4 §1.4: completar a guarda nos 11 sítios de `liaison-ops.sh`, laço de recusa em `deferral-ops.sh test/status` e em `wave-ops.sh`, mais um teste estrutural que enumera todo `--flag) x="$2"` sem guarda nos `*-ops.sh` e exige zero. Alternativa descartada: adotar a camada declarativa `_ap_ctx` do axis-fare-validator, contrato novo de lib incompatível com o `argparse_guard_value` do Axis.PadSimulator. Decisão: DA-14 (guarda por sítio e teste estrutural; a camada declarativa canônica vira roadmap na Onda 8).

Vermelho, executado (`/tmp/fh-A-133.sh`): `deferral-ops.sh status chg --lixo x` e `liaison-ops.sh inbox canal-a --thread --show`; esperado rc 1 nos dois. Hoje:

```
OK (0 tested, 0 resolved, 0 open)
  rc=0
(nenhuma thread)
  rc=0
```

Gate que fica: `tests/w<NNN>-arg-surface-gate.sh`, com as recusas nominais (positivas: mensagem cita a flag) e os controles de uso legítimo em rc 0. Revalidar w51, w201 e w220 (o gate da #123 exercita `transport set --kind fs-union --path`, cujo parsing de flags esta seção muda). Propriedade PBT: para cada subcomando e pares gerados (F, G) do seu conjunto de flags com valor, `cmd --F --G` sai rc≠0 citando G. Mutação: remover a guarda de `--thread` em `inbox` faz o par (thread, show) sair rc 0.

Arquivos: `template/.forge/scripts/liaison-ops.sh`, `deferral-ops.sh`, `wave-ops.sh`, gate novo, README, CHANGELOG.

### #103 — `resolve` repetido duplica a nota e recarimba

**#103** · Closes #103 · gate novo: não (amplia `tests/w211-ledger-detail-acumulativo-gate.sh`)

O título já está corrigido por `f824165` (PR #114): `add --type roadmap --title --detail` sai rc 1 com mensagem nominal, reexecutado pelo orquestrador. O resíduo que o corpo pede no mesmo change reproduz. Causa raiz: `template/.forge/scripts/ledger-ops.sh:392` atribui `e.resolved_at = now` e anexa `Resolvido: <nota>` sem checar se a entrada já está no status pedido.

Desenho: `resolve` sobre entrada já em `resolved`/`wont-fix` sai rc 1 com `FAIL: LDG-NNNN já está '<status>' desde <resolved_at> — use update --detail para acrescentar nota`, sem escrever. Alternativa descartada: no-op silencioso com rc 0, que esconde de quem chama que o segundo ato não aconteceu.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `ledger-ops.sh resolve <id> --note n1` duas vezes; esperado segunda rc 1. Hoje:

```
  resolve1 rc=0
  resolve2 rc=0
  resolved detail="d0 — Resolvido: n1 — Resolvido: n1"
```

Gate que fica: cenário novo no w211 — segunda chamada rc 1 com a mensagem que cita o carimbo anterior (positiva), `resolved_at` byte-idêntico e nota presente uma vez. Propriedade PBT: para k gerado em [2, 5] chamadas de `resolve`, a nota aparece exatamente uma vez e `resolved_at` é o da primeira. Mutação: remover a checagem de status faz a segunda chamada sair rc 0.

Arquivos: `template/.forge/scripts/ledger-ops.sh`, `tests/w211-ledger-detail-acumulativo-gate.sh`, CHANGELOG.

### #108 — ack que falha o cursor em silêncio e doctor que emudece

**#108** · Refs #108 · gate novo: sim

Causa raiz: `template/.forge/scripts/liaison-ops.sh:732-738` engole a falha de avanço de cursor num `catch {}` vazio e imprime `OK ack`; `template/.forge/scripts/doctor.sh:231` (`2>/dev/null || true`) e `:232` (`-n`) somem com a linha de liaison quando `status` falha.

Desenho: o `catch` imprime `WARN: ack publicado, mas o cursor não avançou (<motivo>)` em stderr, rc 0 (o ack já está publicado); o doctor, com `status` rc≠0, imprime `✗ harness: LIAISON: status falhou — <primeira linha do erro>`. Fica `Refs`: o passivo retroativo de cursores pré-#105 (item 1) não reproduz sem estado gerado por código antigo. Decisão: DA-22 (o PR documenta em `commands/harness/liaison.md` que `read <canal> --upto <msg_id>` é o reparo de acks anteriores ao #105; depois do merge, a #108 é fechada à mão com comentário que aponta dois itens novos na Onda 8, o passivo de cursores pré-#105 a medir em campo e a dívida de leitura, ackada e não lida). Alternativa descartada: falhar o `ack` quando o cursor não avança, que faria um ato de protocolo já publicado reportar falha.

Vermelho, executado (`/tmp/fh-R02-Bliaison.sh`): `liaison-cursor.mjs` removido, `ack` de mensagem de terceiro; e `state.json` inválido com `doctor.sh`; esperado WARN no primeiro e linha de liaison no segundo. Hoje:

```
  ack rc=0 stderr/stdout: OK ack — qq-0001 confirma pp-0002
  state depois: {"cursors":{}}
  doctor linhas LIAISON: 0
```

Gate que fica: `tests/w<NNN>-liaison-diagnostico-mudo-gate.sh`: WARN presente e ack gravado no log (positiva); doctor com estado inválido imprime a linha de erro; estado válido imprime a linha normal (contrafactual). Propriedade PBT: não se aplica. Mutação: esvaziar o `catch` de novo faz o cenário do WARN falhar.

Arquivos: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/doctor.sh`, `template/.forge/commands/harness/liaison.md` (+ espelho `plugin/forge/commands/liaison.md` via `npm run build:plugin`), gate novo, README, CHANGELOG.

### #109 — liaison não distingue mensagem enviada de publicada

**#109** · Closes #109 · gate novo: sim

Causa raiz: `template/.forge/scripts/liaison-ops.sh:325` cria `state.json` só com `cursors`, nenhum `sync` grava o que publicou, e o `status` não compara log próprio com o hub.

Desenho: `sync` com push bem-sucedido grava `published: { "<self>": "<último msg_id publicado>" }` em `state.json` (chave aditiva; leitores atuais só leem `cursors`), e `status` imprime `<n> própria(s) não publicada(s)` quando o log próprio tem mensagens posteriores à marca. Alternativa descartada: `send` e `ack` publicarem best-effort, que muda o protocolo de envio de todo consumidor. Decisão: DA-23 (fecha pelo próprio PR, com `Closes #109`): a marca d'água ganha também o carimbo da hora do push (`published_at` por remetente, gravado depois de `t_push` rc 0), e o `status` imprime `· N própria(s) não publicada(s) (há Xmin)` medido contra esse carimbo, nunca contra `created_at`, que é a data do HEAD (`liaison-ops.sh:99`). DA-15: o gate de acks distinguir "ack não publicado" vira roadmap na Onda 8.

Vermelho, executado (`/tmp/fh-R02-Bliaison.sh`): `send` sem `sync`, depois `status`; esperado `1 própria(s) não publicada(s)`. Hoje:

```
  LIAISON/ch: 1 thread(s) · 3 não lida(s) · 0 em quarentena
  menções a 'publicad': 0
  state.json keys: [ 'cursors' ]
```

Gate que fica: `tests/w<NNN>-liaison-outbox-watermark-gate.sh`: antes do `sync` a linha aparece com a contagem certa (positiva), depois do `sync` desaparece, `published` aponta o último id e `published_at` foi gravado; com o relógio do teste adiantado, o `(há Xmin)` reflete a distância até `published_at`, não até `created_at`. Propriedade PBT: para sequências geradas de `send` e `sync` intercaladas, a contagem de não publicadas é igual ao número de mensagens próprias ausentes do log do hub. Mutação: não gravar `published` no `sync` faz a contagem pós-sync ficar maior que zero.

Arquivos: `template/.forge/scripts/liaison-ops.sh` (grava `published` e `published_at` após `t_push` retornar 0, lendo o último `msg_id` do próprio log em `LIAISON_CHANNEL_DIR`), gate novo, README, CHANGELOG.

### #117 — o nome do blob não é o sha256 dos bytes

**#117** · Closes #117 · gate novo: não (amplia `tests/w110-liaison-core-gate.sh`)

Causa raiz: `template/.forge/scripts/liaison-ops.sh:298` calcula `M.sha256Hex(buf.toString('binary'))`, e `template/.forge/scripts/lib/liaison-merge.mjs:37-39` faz hash do texto UTF-8 dessa string latin1: diverge de `shasum -a 256` em todo byte acima de 0x7F.

Desenho: blob novo é nomeado por `createHash('sha256').update(buf)`. Retrocompatível por medição: nenhum leitor recalcula o nome, `BODY_REF_RE` (`liaison-merge.mjs:267`) só confere o padrão `^blobs\/[A-Za-z0-9._-]+$` e o import só confere existência (`liaison-import.mjs:165-173`); nomes antigos seguem válidos como identificadores opacos. Alternativa descartada: migrar os nomes do acervo, que reescreve `body_ref` já publicados entre repositórios.

Vermelho, executado (`/tmp/fh-R02-Bliaison.sh`): `send --body-file` com "não, ação"; esperado prefixo do nome igual a `shasum -a 256` do blob. Hoje:

```
  nome=51ad79897c371dd154667ae63e5732dd686fd8d5e5f21bc81345f09e03da22fb
  shasum=f72d52dadc701adb2cdfdc50e2e53d71e15e4b2e53626b6aaf4f1cb14366f162
```

Gate que fica: cenário novo no w110 — prefixo igual ao `shasum` para conteúdo acentuado (positiva) e para ASCII (controle); um `body_ref` com nome antigo continua importando. Propriedade PBT: para buffers gerados de 0 a 4 KB com bytes aleatórios em [0, 255], o prefixo do nome é igual ao sha256 dos bytes. Mutação: voltar a `toString('binary')` faz o caso acentuado divergir.

Arquivos: `template/.forge/scripts/liaison-ops.sh`, `tests/w110-liaison-core-gate.sh`, CHANGELOG.

### #149 — `forge_find_prune` não poda nada e não tem invocador

**#149** · Closes #149 · gate novo: sim

Causa raiz: três defeitos em `template/.forge/scripts/lib/scan-exclude.sh`: aspas simples ecoadas viram literais (`:22`), parênteses sem escape quebram `eval` e o `-false` colado ao último padrão anula `vendor` (`:24`); e nenhum script do template carrega a lib.

Desenho: a função passa a preencher um array (`forge_find_prune_args <nome-do-array>`) com `\(`, `-name`, padrão, `-o` e `\) -prune -o`, sem `-false`, e o uso documentado passa a ser `find "$P" "${arr[@]}" ...` (bash 3.2); `forge_find_prune` antigo é removido do template porque nunca teve chamador. Invocador: o primeiro varredor por `find` do template que hoje repete a lista de poda passa a consumi-la (candidato nomeado na triagem: `doctor.sh::find_marker`, a medir no PR). Alternativa descartada: consertar o `echo` para uso com `eval`, que mantém a interface que quebra com espaço em padrão.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `find "$P" $(forge_find_prune) -name package.json -print | grep -cE 'node_modules|vendor'`, esperado 0; e contagem de invocadores, esperado ≥1. Hoje:

```
  podados errado (node_modules|vendor listados): 2
  invocadores da lib no template: 0
```

Gate que fica: `tests/w<NNN>-scan-exclude-prune-gate.sh`, com `src/package.json` listado (positiva) e os podados ausentes, sob `bash` explícito. Propriedade PBT: para subconjuntos gerados de `FORGE_SCAN_EXCLUDE` materializados como diretórios (incluindo o último da lista e padrões com glob), nenhum arquivo sob diretório excluído é listado e todo arquivo fora deles é. Mutação: recolocar `-false` faz `vendor` reaparecer.

Arquivos: `template/.forge/scripts/lib/scan-exclude.sh`, o invocador escolhido, gate novo, README, CHANGELOG.

### #153 — copiar `.forge` de outro consumidor é upgrade disfarçado sem aviso

**#153** · Closes #153 · gate novo: não (amplia `tests/w191-doctor-orphan-gate-gate.sh`)

Causa raiz: `template/.forge/commands/harness/upgrade.md:65-66` não trata cópia entre consumidores, e `template/.forge/scripts/doctor.sh:448-521` detecta só `check-*.sh` órfão (entregue por `d7d4ad4` e `6dd3952`), não lib sem invocador nem divergência entre `template_version` e a versão dos hooks.

Desenho: o doctor ganha duas linhas `!`: lib em `scripts/lib/` que nenhum script, hook ou lib sourceia ou importa, nomeada; e `forge.yaml template_version` diferente da versão gravada no cabeçalho de `machinery.lock`. `upgrade.md` ganha a seção "copiar .forge de outro repositório é upgrade parcial". Alternativa descartada: recusar a execução do doctor com divergência, que tira o diagnóstico justamente de quem precisa dele.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `.forge/scripts/lib/zz-orfa.sh` sem invocador; `doctor.sh | grep -c zz-orfa`, esperado ≥1. Hoje:

```
  menções a zz-orfa no doctor: 0
```

Gate que fica: cenários novos no w191 — lib órfã nomeada (positiva), lib sourceada não nomeada (contrafactual), versão divergente gera `!`. Deve rodar depois do PR da #149, que dá invocador à `scan-exclude.sh`. Controle sobre consumidor recém-criado por `init` (J-25): zero linhas de lib órfã, e o PR decide invocador ou isenção declarada para `api-surface.mjs` e `pbt.mjs`. A edição de `upgrade.md` é revalidada contra a base que já contém a #157 (Onda 3). Propriedade PBT: não se aplica. Mutação: remover a varredura de libs faz o cenário órfão dar 0.

Arquivos: `template/.forge/scripts/doctor.sh`, `template/.forge/commands/harness/upgrade.md` (+ plugin), `tests/w191-doctor-orphan-gate-gate.sh`, CHANGELOG.

### LDG-0153 — o doctor não informa divergência do `_common.sh` contra o template

**LDG-0153** · gate novo: não (amplia `tests/w191-doctor-orphan-gate-gate.sh`) · depois do PR da #153 (mesmo `doctor.sh`)

Causa raiz, do detail do ledger: `.forge/cache/machinery.lock` grava o sha256 do template por caminho (`bin/forge.mjs:361`, `:384`), e `bin/forge.mjs:617-643` já calcula exatamente essa comparação para o WARN de drift do update; o doctor não a faz, e o consumidor só descobre o `_common.sh` divergente quando um push destrói o hub. A justificativa antiga de não implementar ("não há referência local") está corrigida no próprio detail.

Desenho: o doctor compara o sha de `scripts/lib/transports/_common.sh` e dos demais transportes com o do `machinery.lock` e imprime `!` nomeando o arquivo e os dois shas; sem lock, imprime "não medido: sem machinery.lock", nunca ✓; exceção viva declarada (#101/#131) troca a linha pelo nome da exceção e a razão. Alternativa descartada: comparar com o template publicado pela rede, que o doctor não faz em nenhum outro ponto.

Vermelho, a executar contra a base no PR: consumidor sintético com `_common.sh` alterado; `bash .forge/scripts/doctor.sh | grep -c _common.sh`, esperado ≥1.

Gate que fica: cenários novos no w191 — divergente nomeado com os dois shas (positiva), idêntico sem linha (contrafactual), sem lock "não medido", exceção viva nomeada com a razão. Propriedade PBT: não se aplica. Mutação: remover a comparação faz o cenário divergente dar 0.

Arquivos: `template/.forge/scripts/doctor.sh`, `tests/w191-doctor-orphan-gate-gate.sh`, CHANGELOG.

**DoD da Onda 4:** cada cenário que hoje termina verde sem medir passa a terminar com uma saída nominal que só existe depois da correção — "leitor devolveu ZERO" no pre-push com lib antiga, AVISO .NET, `not-possible` com padrão nulo, reprovação de `feature` com `fixes_defects` sem evidência, `head_sha` do `--root` do chamador, recusa de flag engolida, recusa de `resolve` repetido citando o carimbo, WARN de cursor, contagem de não publicadas, prefixo de blob igual ao `shasum`, `src/package.json` listado sem os podados, lib órfã nomeada pelo doctor, e a divergência do `_common.sh` local contra o `machinery.lock` nomeada pelo doctor (LDG-0153) — e cada um tem o contrafactual de uso legítimo em rc 0 no mesmo gate.

Critério de saída do Bloco C: `node tools/plan-progress.mjs --plan ... --wave 4` com tudo ✓, ensaio de campo, mensagem de release, o PR de reconciliação do Bloco C (protocolo, item 11) mergeado, e só depois a #106 e a #108 fechadas à mão conforme DA-20 e DA-22.

## Onda 5 — prosa, contrato de agente e interface (Bloco D, 0.19.0)

### #126 — o cabeçalho do `_common.sh` diz que `behind` é recusado e o código une

**#126** · Closes #126 · gate novo: sim

Causa raiz: `template/.forge/scripts/lib/transports/_common.sh:19-20` ("recusar é a única saída — inclusive sob reparo") entrou em `d7d4ad4`; o `case 1` de `:158-170` passou a unir em `a86fdd7` e o cabeçalho não acompanhou.

Desenho, reaproveitando L6 D (§1.4): o cabeçalho vira a tabela de desfechos (`ff`, `behind` une, `diverged` recusa, `equal` no-op) e um gate executa os quatro casos e confronta cada desfecho com a linha da tabela. Alternativa descartada: só editar a frase, que deixa a próxima divergência sem detector.

Vermelho, executado: `grep -c 'recusar é a única saída — inclusive sob reparo' template/.forge/scripts/lib/transports/_common.sh`, esperado 0 com a linha de `behind` dizendo "une". Hoje: `1`.

Gate que fica: `tests/w<NNN>-transport-contract-coherence-gate.sh`: para cada linha da tabela, o caso executado produz o rc e o token declarados (positiva: `behind` rc 0 com `liaison-push-union` e hub preservado). Propriedade PBT: não se aplica; quatro desfechos exaustivos. Mutação: trocar "une" por "recusa" na linha de `behind` faz o confronto falhar; mudar o `case 1` para `return 1` também.

Arquivos: `template/.forge/scripts/lib/transports/_common.sh` (só comentário), gate novo, README, CHANGELOG.

### #136 — `--help` cai no ramo de comando desconhecido

**#136** · Closes #136 · gate novo: não (amplia o gate de superfície de argumento criado pelo PR da #133)

Causa raiz: os dispatchers não tratam `--help`/`-h`: `template/.forge/scripts/liaison-ops.sh:1295`, `ledger-ops.sh:600`, `wave-ops.sh:224` e `deferral-ops.sh:153` caem em "comando desconhecido" ou mostram usage pelo ramo de erro, rc 1; `red-evidence.sh:105` idem.

Desenho: `-h|--help|help` como primeiro argumento imprime o usage em stdout com rc 0; comando inválido continua rc 1 em stderr. O universo é derivado (todo `template/.forge/scripts/*-ops.sh` mais `red-evidence.sh`), não escrito à mão; L4 §2.2 alargou para 14 scripts e este plano mantém o universo da issue mais o predicado derivado, a medir no PR. Precedente interno: `run-all.sh:29`. Alternativa descartada: usage em stderr com rc 0, que quebra `script --help | grep`.

Vermelho, executado: `bash template/.forge/scripts/liaison-ops.sh --help; echo rc=$?`, esperado rc 0 com `Usage`. Hoje:

```
liaison-ops --help rc=1 FAIL: comando desconhecido '--help'
ledger-ops --help rc=1 FAIL: comando desconhecido '--help'
```

Gate que fica: cenários novos no gate de superfície de argumento — para cada script do universo, `--help` e `-h` rc 0 com `Usage` em stdout (positiva) e `comando-que-nao-existe` rc 1 (contrafactual). Propriedade PBT: a própria varredura sobre o universo derivado. Mutação: remover o ramo de help de um script faz a linha daquele script falhar.

Arquivos: os cinco scripts, o gate da #133, CHANGELOG.

### #145 — `/forge:pentest scan` não alcança o toolchain do consumidor

**#145** · Closes #145 · gate novo: sim

Causa raiz: três defeitos em `template/.forge/scripts/pentest-ops.sh`: nome fixo `PENTEST_IMAGE="forge-pentest"` (`:26`), tag `:latest` em nove sítios (`:180-181`, `:221-233`, `:261`, `:281`) e `docker run ... pentest-scan` (`:257-262`) sem contrato escrito nem diagnóstico.

Desenho, reaproveitando L6 §4.3 com fallback: precedência `image:` do `docker-compose.yml` em `tool_dir` > `runtime.pentest.image` > `forge-pentest:latest`; o fallback final imprime `WARN: tag latest (proibida pelas rules) — declare runtime.pentest.image`; antes de `scan`, `docker run --entrypoint sh <img> -c 'command -v pentest-scan'` e, se ausente, rc 4 com `FAIL: a imagem <img> não expõe pentest-scan <apk> <outdir> (contrato em commands/waves/pentest.md)`. O contrato do entrypoint é documentado. Alternativa descartada: trocar o default para uma tag versionada, que declara "não buildado" em toda imagem já construída pelos consumidores. Decisão: DA-16 (fallback mantido com WARN; a remoção vira roadmap na Onda 8, condicionada ao WARN ter circulado por ao menos uma release menor e a um censo dos 7 consumidores sem uso do fallback; o harness entrega só o contrato do entrypoint).

Vermelho, executado (`/tmp/fh-A-145.sh`, docker por stub): compose declara `axis/pentest:dev`; esperado `status` inspecionando essa referência e `scan` rc 4 nomeando `pentest-scan`. Hoje:

```
  docker image inspect forge-pentest:latest
exec: pentest-scan: not found
FAIL pentest:scan — workflow estático falhou
```

Gate que fica: `tests/w<NNN>-pentest-image-contract-gate.sh`, com stub de docker: compose > runtime > fallback com WARN; imagem com `pentest-scan` roda o scan (contrafactual). Revalidar w142 e w206. Propriedade PBT: para combinações geradas das três fontes presentes ou ausentes, a imagem inspecionada é sempre a de maior precedência presente. Mutação: remover a leitura do compose faz o cenário 1 inspecionar `forge-pentest:latest`.

Arquivos: `template/.forge/scripts/pentest-ops.sh`, `template/.forge/commands/waves/pentest.md` (+ plugin), gate novo, README, CHANGELOG.

### #140 — a receita A4 não distingue controle domado de não domado

**#140** · Refs #140 · gate novo: não (amplia `tests/w96-frontend-ui-review-gate.sh`)

O script que reprova (`check-frontend-design-system.sh`) não existe no template (0 arquivos em `template/.forge/scripts`, `log -S native-control` vazio); é gate local do azim-crm. O que o produtor entrega e reproduz: a receita A4 em `template/.forge/skills/frontend-ui-review/SKILL.md:81-91` casa `type="color"` qualquer que seja o CSS irmão, poder discriminante zero.

Desenho, reaproveitando L6 §3.3: A4 vira scanner determinístico advisory (`scripts/scan-native-controls.py` da skill) que reconhece os dois escapes da regra 12 de `rules/frontend/design-system.md:37` — pseudo-elemento domado no CSS do componente ou encapsulamento em componente do DS — e imprime `OK` para eles. Fica `Refs`: a metade bloqueante da issue mora no consumidor. Alternativa descartada: trazer o gate bloqueante do azim-crm para o template. Decisão: DA-17 (A4 advisory, OK/WARN, com o scanner discriminante; gate bloqueante opt-in vira roadmap na Onda 8) e DA-24 (depois do merge, a #140 é fechada à mão com comentário).

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): mesmo `<input type="color">`, um com `::-webkit-color-swatch` no CSS irmão e outro sem; esperado desfechos diferentes. Hoje:

```
  domado: WARN controles nativos
  cru: WARN controles nativos
```

Gate que fica: cenários novos no w96, domado `OK` (positiva) e cru `WARN` (contrafactual). Propriedade PBT: para combinações geradas de tipo de controle × presença do pseudo-elemento correto × encapsulamento, o veredito é `OK` se e somente se um dos dois escapes está presente para aquele tipo. Mutação: ignorar o CSS irmão faz o caso domado dar `WARN`.

Arquivos: `template/.forge/skills/frontend-ui-review/SKILL.md`, `template/.forge/skills/frontend-ui-review/scripts/scan-native-controls.py` (novo), `tests/w96-frontend-ui-review-gate.sh`, README (linha Estrutura: o `.py` novo muda a contagem de skills que o w200 confere, J-21), CHANGELOG. Revalidar w200.

### #151 — `change-test-contract` manda direto para "evidência pendente"

**#151** · Closes #151 · gate novo: não (amplia `tests/w197-normative-text-parity-gate.sh`)

Causa raiz: `template/.forge/rules/testing/change-test-contract.md:19` oferece uma única saída ("registrar explicitamente a evidência pendente") para nível de teste que não pode rodar. Premissa em remedição: a ficha A mediu 1 de 7 repositórios com a rule instalada que a estendem (azim-crm), não "consumidores" no plural; o dado é provisório até a remedição do orquestrador, e o desenho não depende dele.

Desenho: a regra passa a ordenar três saídas — criar o objeto (harness real e descartável), reescrever o critério com registro de quem decidiu, e só então pendência declarada — e o relatório de `/forge:verify` passa a marcar nível pendente com token distinto de verificado. Alternativa descartada: manter a saída única e só acrescentar exemplo, que não muda a ordem de decisão. Decisão: DA-18 (só o dono humano da spec reescreve o critério, com registro nominal de quem decidiu; em modo yolo, o yolo-gate não reescreve e escala).

Vermelho, executado: `grep -ciE 'criar o objeto|harness real e descart' template/.forge/rules/testing/change-test-contract.md`, esperado ≥1 com as três saídas em ordem. Hoje: `0`. A metade de `/forge:verify`: vermelho NÃO executado — exige fixture de verify com nível pendente que ainda não existe; o implementador a escreve e observa as duas linhas iguais antes de corrigir.

Gate que fica: cenário novo no w197, que já confronta texto normativo: as três saídas presentes na ordem declarada (positiva por posição de linha). Propriedade PBT: não se aplica. Mutação: inverter a ordem das saídas faz o confronto de posição falhar.

Arquivos: `template/.forge/rules/testing/change-test-contract.md`, o comando ou template do relatório de verify, `tests/w197-normative-text-parity-gate.sh`, CHANGELOG.

### #152 — `security-reviewer` sem checagem de proveniência

**#152** · Closes #152 · gate novo: sim

Causa raiz: `template/.forge/agents/review/security-reviewer.md` cobre RBAC e IDOR (`:21`, `:159`) e não tem passo que pergunte quem escreve o campo usado na decisão de autorização, nem que percorra registros filhos.

Desenho: passo novo no pipeline do agente — para todo campo lido numa decisão de autorização ou proveniência, identificar o escritor; campo escrito pelo próprio verificado (ex.: `payload.runId`) sem ancoragem server-side é BLOCKER, e o passo percorre os registros filhos. Eval em `template/.forge/evals/` com a fixture `payload.runId` esperando BLOCKER. Alternativa descartada: só gate estático de texto, que prova a presença da frase e não o comportamento do agente.

Vermelho, executado: `grep -ciE 'proveni|quem escreve' template/.forge/agents/review/security-reviewer.md`, esperado ≥1. Hoje: `0` (controle positivo `grep -c IDOR` → `2`). O vermelho comportamental do eval: NÃO executado — exige rodar o agente LLM, fora do escopo determinístico desta rodada.

Gate que fica: `tests/w<NNN>-security-reviewer-provenance-gate.sh` (estático: passo presente e referenciado no checklist de saída) mais o caso de eval registrado no harness de evals. Propriedade PBT: não se aplica. Mutação: remover o passo faz o gate estático falhar.

Arquivos: `template/.forge/agents/review/security-reviewer.md`, `template/.forge/evals/` (caso novo), gate novo, README, CHANGELOG.

**DoD da Onda 5:** o gate de coerência executa os quatro desfechos do push e todos batem com o cabeçalho; `--help` sai rc 0 com usage em todo script do universo derivado e comando inválido continua rc 1; `pentest scan` contra imagem sem entrypoint sai rc 4 nomeando o binário e imagem com entrypoint roda; a receita A4 dá `OK` para controle domado e `WARN` para cru; a rule de testes lista as três saídas em ordem; e o `security-reviewer` tem o passo de proveniência referenciado no checklist, com o eval registrado e o seu vermelho declarado como não executado.

## Onda 5b — delegação a subagente e verificação nas skills e rules (Bloco D, 0.19.0)

### #155 — `/forge:analyze`: quem julga e quem grava

**#155** · Closes #155 · gate novo: sim (w241) · antes do PR da #159 (mesmo `analyze.md`)

Causa raiz: `template/.forge/commands/specs/analyze.md:23-25` (seção `## Saída`) só diz "Grave `analysis.md` no change com: ..."; quando a análise é delegada a um subagente revisor sem permissão de escrita, o harness recusa a escrita e a sessão orquestradora transcreve à mão, e no caso da issue o prompt de delegação foi reescrito em quatro rodadas seguidas.

Desenho: a seção `## Saída` ganha a regra de que o revisor delegado devolve a tabela e a síntese do formato de saída como texto, a sessão orquestradora grava `analysis.md`, e o arquivo registra quem revisou (subagente e modelo) e quem transcreveu. Alternativa descartada: dar escrita ao subagente revisor, que junta julgamento e gravação no mesmo agente.

Vermelho, executado: `grep -ciE 'transcrev|transcri' template/.forge/commands/specs/analyze.md`, esperado ≥1 entre `## Saída` e `## Conflito é bloqueante`. Hoje: `0`.

Gate que fica: `tests/w241-analyze-quem-grava-gate.sh`, estático: a regra dentro da seção `## Saída` (por posição de linha, antes de `## Conflito é bloqueante`), os dois campos de registro presentes, espelho do plugin idêntico. Revalidar gw1 (lê `analyze.md`), `plugin-sync-gate` e w200. Propriedade PBT: não se aplica. Mutação: mover a regra para a seção `## Regras` faz o confronto de posição falhar.

Arquivos: `template/.forge/commands/specs/analyze.md` (+ espelho `plugin/forge/commands/analyze.md` via `npm run build:plugin`), gate novo, README, CHANGELOG.

### #156 — delegação TDD precisa nomear o mecanismo do vermelho

**#156** · Closes #156 · gate novo: sim (w242)

Causa raiz: `template/.forge/commands/specs/implement.md:41` (passo 2 do "Loop de execução") diz só "TDD-first quando há lógica verificável", e o passo 4 descreve o commit sem conferir o conteúdo do commit do vermelho; o comentário da própria issue mede o mesmo padrão em `template/.forge/agents/coding/task-coder.md:289` (`"test_policy": "TDD-first quando aplicável. ..."`) e em `template/.forge/commands/coding/coding-loop.md`, que delega ao `task-coder` onda a onda. Na issue, duas de cinco tasks delegadas trouxeram cerca de 1.400 linhas de implementação no commit rotulado como vermelho.

Desenho: os três pontos de entrada nomeiam o mecanismo, não só o princípio: tipos vazios ou stubs que lançam "não implementado" para o teste compilar; vermelho observado por falha de asserção, nunca por falha de compilação; commit contendo só testes e stubs; implementação no commit seguinte. E a conferência recai sobre o artefato: a sessão orquestradora roda `git show --stat <sha-do-vermelho>` e rejeita o commit que traz arquivo de produção além dos stubs, o mesmo princípio do item 3 do protocolo por PR deste plano. Alternativa descartada: só reforçar "TDD estrito" no prompt, que a issue mede como ineficaz.

Vermelho, executado: `grep -ci stub` e `grep -c 'show --stat'` em cada um dos três arquivos, esperado ≥1 em todos. Hoje: `0` nos seis.

Gate que fica: `tests/w242-implement-red-mecanismo-gate.sh`, estático sobre os três arquivos: mecanismo nomeado (stub, falha por asserção, commit só de testes) e a conferência por `git show --stat` presentes em cada um; espelhos do plugin idênticos. Revalidar w50 (lê `implement.md`), `plugin-sync-gate` e w200. Propriedade PBT: não se aplica. Mutação: remover o parágrafo de `task-coder.md` faz o gate falhar nomeando o arquivo.

Arquivos: `template/.forge/commands/specs/implement.md`, `template/.forge/agents/coding/task-coder.md`, `template/.forge/commands/coding/coding-loop.md` (+ espelhos `plugin/forge/commands/implement.md` e `plugin/forge/commands/coding-loop.md` via `npm run build:plugin`), gate novo, README, CHANGELOG. `agents/` é enriquecível (`bin/forge.mjs:352`): consumidor com `task-coder.md` customizado não recebe o texto, e a nota de release diz isso.

### #158 — comparador gerado × versionado nas rules de testes

**#158** · Closes #158 · gate novo: sim (w243)

Causa raiz: `template/.forge/rules/testing/quality-gates.md` só menciona snapshot na seção de Regressão Visual (`grep -ci versionado` → 1, e a ocorrência é "fixtures versionados", `:56`), e `template/.forge/rules/architecture/api-and-contracts.md` declara o contrato como fonte da verdade sem dizer o que um teste de comparação pode prescrever. No caso da issue, um comparador de contrato OpenAPI bloqueou pushes por três semanas mandando regenerar por cima de três edições deliberadas, uma delas a correção de uma exposição de superfície interna.

Desenho: seção nova "Comparação gerado × versionado" em `quality-gates.md` com os três itens da issue: asserções de propriedade do artefato, independentes da comparação; mensagem de falha que não prescreve regenerar, nomeia as duas causas possíveis e aponta `git log -p -- <arquivo>`; e, em `api-and-contracts.md`, a regra de que onde o contrato versionado é fonte da verdade nenhum teste tem como remediação sobrescrevê-lo com o gerado. Alternativa descartada: um gate genérico de comparação no template, que exigiria conhecer o gerador de cada consumidor. `rules/` é enriquecível (`bin/forge.mjs:352`): quem customizou essas regras não recebe o texto, e a nota de release da 0.19.0 nomeia `quality-gates.md` em azim-crm, lionclaw e collatra e `api-and-contracts.md` no Axis.PadSimulator (J-20).

Vermelho, executado: `grep -ciE 'gerado × versionado|gerado x versionado' template/.forge/rules/testing/quality-gates.md`, esperado ≥1. Hoje: `0`.

Gate que fica: `tests/w243-comparador-gerado-versionado-gate.sh`, estático: a seção presente com os três itens; a mensagem-modelo nomeia as duas causas (positiva) e não contém instrução de regenerar e commitar (negativa pareada); referência cruzada presente em `api-and-contracts.md`. Revalidar w186 (lê cabeçalhos de `quality-gates.md`) e w200. Propriedade PBT: não se aplica. Mutação: trocar a mensagem-modelo por "rode a geração e commite" faz o gate falhar.

Arquivos: `template/.forge/rules/testing/quality-gates.md`, `template/.forge/rules/architecture/api-and-contracts.md`, gate novo, README, CHANGELOG.

### #159 — teto e regra de convergência no Review delegado e no analyze

**#159** · Closes #159 · gate novo: sim (w244) · depois do PR da #155 (mesmo `analyze.md`)

Causa raiz: `template/.forge/commands/specs/requirements.md:36-40` limita o loop builder→validator a 3 iterações e `:63` limita o `review` autônomo do yolo a 3, mas a decisão **Review** do gate humano (`:51`) volta ao passo 1 sem teto; `analyze.md` não tem limite de rodadas nem distingue pendência operacional de defeito de artefato. Medido em 2026-09-25: só `design.md:39` remete ao `/forge:requirements` ("Igual ao `/forge:requirements`"); `tasks.md` não tem a remissão que a issue supõe, então a regra precisa ser escrita também nele. No caso da issue, um gate de requirements delegado levou 14 rodadas.

Desenho: (1) regra de convergência em `requirements.md`, herdada por `design.md` pela remissão e escrita em `tasks.md`: a régua de severidade é fixada na primeira rodada e repetida no prompt de cada rodada seguinte, e duas rodadas seguidas com MAJOR ou BLOCKER no mesmo mecanismo introduzido por correção anterior param o loop e escalam ao dono a decisão de causa raiz; (2) decisões `Review` consecutivas contam para o mesmo teto de 3 do yolo, e ao atingi-lo a escalada é obrigatória; (3) em `analyze.md`, a mesma regra entre rodadas e a classificação de cada achado em defeito de artefato ou pendência operacional, que não bloqueia e vai para ledger ou handoff. A escalada é registrada em `approvals.yaml` com a decisão `block` e motivo nominal, valor que o schema já aceita (`approvals.schema.json:38`, e `iteration` já tem máximo 3 em `:42`), sem tocar `approval-log.sh`; se o PR medir que precisa de valor novo, ele passa a editar `approval-log.sh` e o schema e entra antes do LDG-0171 e do LDG-0183 na ordem de merge. Coerente com DA-18: reescrever critério continua sendo do dono da spec. Alternativa descartada: teto só no yolo, que é o caso que a issue mede como já coberto.

Vermelho, executado: `grep -ci converg` em `requirements.md`, `analyze.md` e `autonomy-yolo.md`, esperado ≥1 em cada. Hoje: `0` nos três.

Gate que fica: `tests/w244-review-delegado-convergencia-gate.sh`, estático sobre `requirements.md`, `tasks.md`, `analyze.md` e `autonomy-yolo.md` (regra de convergência, teto contado nas decisões Review, classificação no analyze), mais a remissão de `design.md` a `requirements.md` presente, porque a regra chega por ela; e cenário executável em que `approval-log.sh` grava a escalada com `block` e o schema a valida. Revalidar w95 (lê `autonomy-yolo.md` e `approval-log.sh`), w30 (schemas), gw1, `plugin-sync-gate` e w200; e w21, w22, w32, w33, w42 e w192 se `approval-log.sh` mudar. Propriedade PBT: não se aplica. Mutação: apagar a remissão de `design.md` faz o gate falhar nomeando o arquivo.

Arquivos: `template/.forge/commands/specs/requirements.md`, `template/.forge/commands/specs/tasks.md`, `template/.forge/commands/specs/analyze.md`, `template/.forge/rules/conventions/autonomy-yolo.md` (+ espelhos `plugin/forge/commands/requirements.md`, `plugin/forge/commands/tasks.md` e `plugin/forge/commands/analyze.md` via `npm run build:plugin`), gate novo, README, CHANGELOG; só se medido necessário, `template/.forge/scripts/approval-log.sh` e `template/.forge/schemas/approvals.schema.json`.

**DoD da Onda 5b:** `analyze.md` manda o revisor delegado devolver texto e registra revisor e transcritor na seção de saída; os três pontos de entrada da delegação TDD nomeiam stub, falha por asserção e commit só de testes, com a conferência por `git show --stat`; `quality-gates.md` tem a seção gerado × versionado com a mensagem-modelo que nomeia as duas causas e não manda regenerar, e `api-and-contracts.md` a referência cruzada; e `requirements.md`, `tasks.md`, `analyze.md` e `autonomy-yolo.md` têm a regra de convergência e o teto contado nas decisões Review, com a escalada gravada por `approval-log.sh` e validada pelo schema. Cada gate estático tem a mutação que o reprova.

Critério de saída do Bloco D: `node tools/plan-progress.mjs --plan ... --wave 5` e `--wave 5b` com tudo ✓; mensagem de release que nomeia, por consumidor, as regras e agentes enriquecíveis preservados que não recebem o texto novo (`quality-gates.md` em azim-crm, lionclaw e collatra; `api-and-contracts.md` no Axis.PadSimulator); o PR de reconciliação do Bloco D (protocolo, item 11) mergeado; e só depois a #140 fechada à mão conforme DA-24.

## Onda 7 — dívida interna (Bloco E, 0.19.x ou 0.20.0)

### LDG-0171 e LDG-0183 — raiz resolvida pela posição do script

**LDG-0171** · **LDG-0183** · gate novo: sim (w245, um gate para os dois) · depois do LDG-0153 no `doctor.sh`; depois da #159 se ela tocar `approval-log.sh`

Causa raiz (J-01, J-19): 37 sítios `SCRIPT_DIR/../..` em 37 arquivos e 3 na forma `dirname` resolvem a raiz pela posição do script; no dogfood isso aponta para `template/`, que é o LDG-0183 (`spec-new.sh:17` e `approval-log.sh`). A correção que o detail do LDG-0183 sugeria (`forge_resolve_root`) está errada, e a nota de correção já está no item: `forge_resolve_root` resolve para o tronco por desenho, e levaria para o tronco o estado de change de quem trabalha em worktree (há changes só em worktree: 19 no axis-go-cloud, 2 no Axis.PadSimulator, 7 no azim-crm).

Desenho: primeiro uma tabela medida dos 40 sítios com o resolvedor certo para cada um (estado de change, aprovação e ordinal usam `forge_worktree_root "$SCRIPT_DIR"`, como `gate-ordinal.sh`; ledger e liaison usam `forge_resolve_root`), anexada ao primeiro PR; depois PRs por grupo de sítios. Nenhum sítio de estado de change passa a usar `forge_resolve_root`.

Gate que fica: `tests/w245-resolvedor-tres-layouts-gate.sh`, com três layouts: dogfood (o change nasce em `<raiz>/.forge/specs/active`, nunca em `template/`), consumidor no tronco, e consumidor em worktree (sha de `<tronco>/.forge/specs/active` idêntico antes e depois). Revalidar w204 e w193 (resolução de raiz do ordinal) e w21, w22, w32, w33, w42, w95 e w192 (`approval-log.sh`). Propriedade PBT: para layouts gerados (tronco ou worktree, com ou sem `FORGE_ROOT`, dogfood ou consumidor), o change nasce sempre na árvore que invoca. Mutação: trocar o resolvedor por `forge_resolve_root` faz o cenário worktree falhar.

Arquivos: os 40 sítios da tabela, `template/.forge/scripts/lib/forge-root.sh` só se faltar primitivo, gate novo, README, CHANGELOG.

### LDG-0158, LDG-0167 e LDG-0173 — alocador de ordinais e ids

**LDG-0158** · **LDG-0167** · **LDG-0173** · gate novo: não (amplia `tests/w204-ordinal-root-resolution-gate.sh` e `tests/w193-tree-derived-state-gate.sh`)

Desenho: LDG-0158, `next` passa a rodar `git -C` no repositório de `--path`, sem misturar o remoto do cwd com a árvore de outro repositório; LDG-0173, conforme DA-05, `next` mantém stdout e rc e imprime em stderr WARN nomeando os ordinais maiores ou iguais ao devolvido já presentes em outras refs `origin/*`; LDG-0167, o mesmo WARN cobre a colisão de ordinal de gate medida, e para id de ledger o PR mede se um aviso aditivo equivalente em `ledger-ops.sh add` cabe sem mudar o id alocado; se não couber, o item fica com decisão registrada. O resto do LDG-0173 (universo que define o número, registro de reserva) vira item de roadmap na Onda 8, criado pelo PR de reconciliação do Bloco E. Mutação: remover o WARN faz o cenário com duas refs falhar.

Arquivos: `template/.forge/scripts/gate-ordinal.sh`, `template/.forge/scripts/ledger-ops.sh` se couber, os dois gates, CHANGELOG.

### Demais itens da dívida interna

**LDG-0176** · gate novo: sim (w246) — `graph.json` commitado defasado. O gate compara o conjunto de ids de nodes do grafo commitado com o do grafo regenerado (conjunto, nunca contagem), e a mutação que commita um grafo sem um gate existente o faz falhar. Arquivos: gate novo, `.forge/graph/graph.json` regenerado, README, CHANGELOG.

**LDG-0161** · gate novo: não (amplia `tests/w13-init-gate.sh`) — as duas cópias do `FORGE.md` de scaffold passam a diferir só nos placeholders, por paridade afirmada no w13, sem gerador novo.

**LDG-0152** · gate novo: não (amplia `tests/w190-pre-push-gate-reader-gate.sh`) — um leitor único de campo do frontmatter do `FORGE.md` para `pre-push`, `handoff-gen.sh` e `on-session-start.sh`, só depois de todos os PRs de `pre-push` desta rodada (a #106 é o último); cenário de versão mista entre o `pre-push` do tronco e a lib da worktree (protocolo, item 4).

**LDG-0157** · gate novo: não (amplia `tests/w120-ai-attribution-gate.sh`) — `check-ai-attribution.sh` distingue `node` ausente (rc 127) de violação: mensagem "não verificado: node ausente" em vez do banner de assinatura detectada, mantendo o bloqueio.

**LDG-0188** · gate novo: não (amplia `tests/w198-liaison-push-union-gate.sh`) — o caminho `--repair-own-log` (`_common.sh:206-207`) passa pela validação de um escritor por arquivo antes do `cp`/`mv`; depois do PR da #126, que edita o cabeçalho do mesmo `_common.sh`.

**LDG-0100** · gate novo: não (amplia `tests/w136-session-start-liaison-acks-gate.sh` e o cenário de doctor) — só depois do merge da #123 (DA-26): wont-fix com a condição de reabertura reescrita para "algum canal com kind diferente de fs, fs-union ou manual", verificada por WARN aditivo e não bloqueante do doctor que nomeia canal e kind. O PR de código entrega o WARN; a mudança de status para wont-fix é gravada pelo PR de reconciliação do Bloco E. No placar, fica `~` com decisão registrada.

O lote restante dos `! cmd` nus (J-19), fora dos 14 gates da Onda 0, entra nesta onda como o item novo de ledger que o PR de reconciliação do Bloco 0 cria.

**DoD da Onda 7:** `node tools/plan-progress.mjs --plan ... --wave 7` com tudo ✓, ou `~` só com decisão registrada (o LDG-0100 como wont-fix por DA-26); o gate de três layouts verde, com a mutação para `forge_resolve_root` reprovando o cenário worktree e o recontrole verde; o WARN de ordinal presente numa fixture com duas refs e ausente com uma; o grafo commitado com o mesmo conjunto de nodes do regenerado; e o PR de reconciliação do Bloco E (protocolo, item 11) mergeado, com as resoluções da onda, o wont-fix do LDG-0100 e o item de roadmap do resto do LDG-0173 em negrito na Onda 8.

## Onda 8 — fora desta rodada (Bloco F)

Nenhum destes itens muda de status nesta rodada, salvo promoção decidida pelo dono. Cada um vira um change via `/forge:spec new`, priorizado com o dono ao fim do Bloco E.

- **LDG-0008** — roadmap de enforcement determinista de TDD e PBT; pede change SDD próprio.
- **LDG-0029**, **LDG-0162** e **LDG-0010** — cadeia do route-scan, nesta ordem: universo da varredura, `MapGroup()` não ancorado, e só então a promoção do SRF-01 a bloqueante.
- **LDG-0021** — tech-debt adiado: a prova de mutação mede regras, não a superfície de entrada; change SDD próprio.
- **LDG-0065** — tech-debt adiado: enforcement mecânico de Java e Python; roadmap de packs.
- **LDG-0178** — esquema canônico de `hooks.manifest` da camada do consumidor, depois que a thread de liaison fechar (DH-2).
- **LDG-0160** — fases pre-deploy e post-deploy sem executor (DA-02).
- **LDG-0151** — chaves de schema que prometem default sem leitor, decisão por chave (DA-03).
- **LDG-0140** — segunda metade do harvest (DA-04).
- **LDG-0184** — parar o update em exceção expirada (lado forte de DH-1).
- **LDG-0185** — teto de posse derivado ligado por padrão (lado forte de DH-5).
- **LDG-0186** — trocar o nome default do recurso, condicionado a registro de famílias (lado forte de DH-3).
- **LDG-0187** — recomendar `fs-union` como padrão ativo (lado forte de DH-4).

Itens que as decisões mandam para esta onda e que ainda não têm id. Este é o único lugar que fixa quando nascem: cada um é criado pelo PR de reconciliação do bloco em que a issue de origem fecha (protocolo, item 11), com `FORGE_ROOT` inline, em sequência e um por vez, e entra em negrito aqui no mesmo PR; nenhum PR de código cria item de ledger. Qualquer frase de decisão que diga "no PR" ou "depois do merge" sobre a criação desses itens se lê por esta regra. São eles, com o bloco que os cria: Bloco A, recusa opt-in do handoff e alinhamento do `/forge:handoff` (DA-09, #120); Bloco B, política para deleção de ref protegida (DA-10, #132/#134) e teto por teste no `run-all.sh` do template (DA-19, #135); Bloco C, cobertura de outras stacks e bloqueio opt-in no `runtime.test` (DA-12 e DA-20, #106, um item), `positive_control` obrigatório (DA-13, #150), camada declarativa canônica de argparse (DA-14, #133), gate de acks distinguir ack não publicado (DA-15, #109), e passivo de cursores pré-#105 e dívida de leitura (DA-22, #108, dois itens); Bloco D, remoção do fallback `latest` do pentest (DA-16, #145) e gate A4 bloqueante opt-in (DA-17 e DA-24, #140, um item); Bloco E, o resto do LDG-0173 (DA-05). O lote restante dos `! cmd` nus não é desta onda: nasce no PR de reconciliação do Bloco 0 e vai para a Onda 7.

**DoD da Onda 8:** o placar reconcilia os itens desta onda sem órfão nem fantasma, e nenhum deles muda de status por efeito desta rodada salvo promoção decidida pelo dono; a positiva é a linha `✓ todo item aberto está em exatamente uma onda` na saída de `node tools/plan-progress.mjs`.

## Fechamento de issue já corrigida

Nenhuma das 36 issues está corrigida em título e corpo inteiros, e por isso não há onda de fechamento (uma onda sem item faz o placar sair rc 2). A mais próxima é a #103: o título foi corrigido por `f824165` (PR #114) e `ledger-ops.sh add --type roadmap --title --detail` sai rc 1 com mensagem nominal, mas o resíduo de `resolve` repetido reproduz e está na Onda 4. A #140 não reproduz no produtor (o script bloqueante nunca existiu no template), mas a receita A4 do template reproduz a falta de discriminação e está na Onda 5.

## Ordem de merge

Pares e cadeias de PR que tocam o mesmo arquivo de maquinaria, na ordem em que devem entrar; cada PR é revalidado contra a base que já contém os anteriores. Reconciliada com os blocos (J-04): nenhuma cadeia manda um item de bloco posterior entrar antes de um de bloco anterior, e a conferência mecânica abaixo prova isso.

| Arquivo | Ordem | Por quê |
|---|---|---|
| `bin/forge.mjs` | #101/#131 → #142 | as linhas `SOBRESCRITO` e o leitor de exceções nascem no primeiro; a mensagem de merge da #142 fica no relatório que o primeiro já reformata. A #125 não edita `bin/forge.mjs`; sua dependência de #101/#131 é de ordem e está na tabela seguinte |
| `template/.forge/scripts/lib/sync-adapters.mjs` | #130 → #160 → #125 | a #160 lê o `settings.json` existente e a #125 deriva a fiação sobre esse merge; sem a guarda de principal da #130, os gates das duas reconciliam a fixture ao importar |
| `template/.forge/hooks/git/pre-push` | #141 → #132/#134 → #135 → #144/#137 → #119 → #106 → LDG-0152 | a #141 muda a resolução dos sítios delegados e abre a cadeia (J-07); o curto-circuito de deleção antecede `run_check`, que a #135 reescreve; a #144/#137 passa o beneficiário por ambiente; a #106 acrescenta o aviso ao lado da linha `:325` já estável; o LDG-0152 consolida o `fm_field` só depois de todos |
| `template/.forge/scripts/tests/run-all.sh` | #135 → LDG-0181 | a #135 anuncia o nome antes de executar; o LDG-0181 reescreve o ramo de falha em volta desse anúncio |
| `template/.forge/commands/harness/upgrade.md` | #101/#131 → #157 → #153 | a documentação das exceções entra primeiro; o passo de suíte da #157 depende do LDG-0181; a seção de cópia entre consumidores da #153 é revalidada contra a base com a #157 |
| `template/.forge/scripts/doctor.sh` | #160 → #142 → #127 → #108 → #149 → #153 → LDG-0153 → LDG-0171 → LDG-0100 | a mensagem de `:157` primeiro; a linha `HEAVY-MUTEX` da #142 vem no Bloco A; universo de varredura antes do diagnóstico de liaison; a lib órfã da #153 é medida depois que a #149 dá invocador à `scan-exclude.sh`; a divergência do `_common.sh` depois da #153; a raiz do doctor (LDG-0171) e o WARN de kind (LDG-0100) por último |
| `template/.forge/scripts/liaison-ops.sh` | #117 → #108 → #109 → #133 → #136 | do trecho mais baixo e isolado (`:298`) para o dispatcher (`:1295`), que a #136 reescreve |
| `template/.forge/scripts/deferral-ops.sh` | #133 → #136 | o laço de recusa em `status` e `test` precisa existir antes do ramo de help no dispatcher |
| `template/.forge/scripts/ledger-ops.sh` | #103 → #136 → LDG-0167 | a recusa de `resolve` repetido é local; o help reescreve o dispatcher; o aviso de id do LDG-0167, se couber, vem depois |
| `template/.forge/scripts/lib/red-evidence-ops.mjs`, `lib/check-red-first.mjs` | #139 → #138 | a #138 itera `entries` criadas pela #139 |
| `template/.forge/commands/testing/red.md`, `rules/testing/regression-red-first.md` | #139 → #138 → #150 | a #139 documenta `entries`, a #138 o escopo de defeito, e a #150 acrescenta o item 3 do corpo (DA-21) sobre as duas |
| `template/.forge/scripts/red-evidence.sh` | #138 → #136 | o help da #136 toca o dispatcher de `red-evidence.sh` |
| `template/.forge/schemas/red-evidence.schema.json` | #139 → #150 | os dois acrescentam propriedades ao mesmo schema estrito |
| `template/.forge/scripts/lib/transports/_common.sh` | #126 → LDG-0188 | a #126 reescreve o cabeçalho em tabela de desfechos; o LDG-0188 muda o caminho de reparo que a tabela descreve |
| `template/.forge/commands/specs/analyze.md` | #155 → #159 | a regra de quem grava entra na seção `## Saída`; a de convergência, em `## Regras` |
| `template/.forge/scripts/approval-log.sh` | #159 → LDG-0171/LDG-0183 | só se a #159 medir que precisa de decisão nova no schema; a troca de resolvedor vem depois |
| `README.md` (badge `gates-N`) | ordem de merge de todos os PRs com gate novo | o w200 exige a igualdade no mesmo commit; cada PR recalcula o badge contra a base em que entra |

## Dependências de ordem sem arquivo compartilhado

Pares que precisam entrar nesta ordem sem editar o mesmo arquivo. A coluna Força separa a dependência rígida, que a conferência mecânica exige, da branda, que a conferência lista sem exigir e que só obriga o PR que entrar por último a revalidar o gate do outro.

| Depende de | Deve entrar depois | Força | Por quê |
|---|---|---|---|
| LDG-0182 | #125 | rígida | a #125 revalida o w62, cujo `! cmd` nu o Bloco 0 converte |
| #101/#131 | #125 | rígida | a sobrescrita nominal e a exceção honrada fecham a metade `hooks/` do desarme |
| #144/#137 | #146 | rígida | a #146 confere a armação de trap que o laço de aquisição reformado continua chamando (`heavy-mutex.sh:790`), mas só edita `heavy-run.sh` |
| LDG-0181 | #157 | rígida | a triagem da #157 precisa do terceiro estado do runner (J-05) |
| #133 | #123 | branda | sem arquivo nem semântica comum (J-04): a #123 só usa `transport set --kind`, que funciona sem a guarda de flag-como-valor. A #123 entra antes, no Bloco A, pela medição do axis-device-platform (seção da #123), e o PR da #133 revalida o w220 quando entrar |
| #123 | LDG-0100 | rígida | o LDG-0100 só vira wont-fix depois de `check-liaison-acks.sh` tratar `fs-union` (DA-26) |

### Conferência mecânica da ordem

Conferida em 2026-09-25 por um script efêmero que lê este documento (segunda versão, depois da revisão adversarial do adendo). Ele extrai a onda e o bloco de cada id em negrito pelos cabeçalhos `## Onda N — ... (Bloco X, ...)`, recusa ondas fora de ordem de bloco, e compara todo par i<j de três fontes pela chave (bloco, onda), em ordem lexicográfica, e não só pelo bloco: as cadeias da tabela de ordem de merge, todas rígidas; a tabela de dependências sem arquivo, lendo a coluna Força, em que a linha branda é listada e não exigida; e as dependências escritas só na linha de status das seções ("depois do PR da", "antes do PR da", "depende do PR de", "só depois"), todas rígidas. Resultado: 9 ondas, 71 ids em negrito, 38 cadeias (16 de cabeçalho de seção), 135 pares rígidos, 0 violação, 0 id fora das ondas, e 1 par brando invertido e não exigido (#133 → #123, pela razão escrita na tabela). Controles negativos, cada um sobre uma cópia mutada deste documento: a cadeia de `upgrade.md` invertida para `#101/#131 → #153 → #157` dá `FALHA #153 (onda 4, bloco C) → #157 (onda 3, bloco B)`; uma linha rígida `#123 → #142`, dentro do mesmo Bloco A, dá `FALHA #123 (onda 2, bloco A) → #142 (onda 1, bloco A)`, que a versão anterior, só por bloco, não enxergava; o cabeçalho da #138 trocado para "antes do PR da #139" dá `FALHA #138 (onda 4, bloco C) → #139 (onda 2, bloco A)`; e a linha #133 → #123 marcada como rígida dá `FALHA #133 (onda 4, bloco C) → #123 (onda 2, bloco A)`. O recontrole sobre o documento sem mutação volta a 0 violação e rc 0. A conferência não ordena PRs dentro da mesma onda (a ordem ali é a das tabelas), e toda edição destas tabelas, dos cabeçalhos de onda ou das linhas de status das seções repete a conferência antes do merge.

## Tabela de ordinais

Uma linha por issue que ganha gate novo. O orquestrador preenche o ordinal contra `origin/*` e as branches em voo.

| Issue | Gate (slug provisório) | Ordinal |
|---|---|---|
| #101 | update-exceptions (mesmo gate da #131) | w214 |
| #131 | update-exceptions (mesmo gate da #101) | w214 |
| #125 | hook-wiring-derived | w215 |
| #130 | module-import-side-effect | w216 |
| #142 | heavy-mutex-partition | w217 |
| #139 | red-evidence-entries | w218 |
| #107 | liaison-blob-recovery | w219 |
| #123 | liaison-fs-union | w220 |
| #144 | heavy-mutex-posse (mesmo gate da #137) | w221 |
| #137 | heavy-mutex-posse (mesmo gate da #144) | w221 |
| #146 | heavy-run-signal-disposition | w222 |
| #141 | delegacao-arvore-do-hook | w223 |
| #132 | prepush-delecao-pura (mesmo gate da #134) | w224 |
| #134 | prepush-delecao-pura (mesmo gate da #132) | w224 |
| #135 | prepush-teto-de-check | w225 |
| #127 | doctor-scan-universe | w226 |
| #129 | naming-path-provenance | w227 |
| #106 | prepush-cobertura-dotnet | w228 |
| #138 | red-defect-scope | w229 |
| #128 | run-manifest-root | w230 |
| #133 | arg-surface | w231 |
| #108 | liaison-diagnostico-mudo | w232 |
| #109 | liaison-outbox-watermark | w233 |
| #149 | scan-exclude-prune | w234 |
| #126 | transport-contract-coherence | w235 |
| #145 | pentest-image-contract | w236 |
| #152 | security-reviewer-provenance | w237 |
| #160 | settings-json-merge (também o LDG-0189) | w238 |
| LDG-0181 | template-runner-tres-estados | w239 |
| #157 | upgrade-verifica-suite | w240 |
| #155 | analyze-quem-grava | w241 |
| #156 | implement-red-mecanismo | w242 |
| #158 | comparador-gerado-versionado | w243 |
| #159 | review-delegado-convergencia | w244 |
| LDG-0171 | resolvedor-tres-layouts (mesmo gate do LDG-0183) | w245 |
| LDG-0183 | resolvedor-tres-layouts (mesmo gate do LDG-0171) | w245 |
| LDG-0176 | graph-defasagem | w246 |

Reservado por `template/.forge/scripts/gate-ordinal.sh next --path .` em 2026-09-15, contra `origin/develop` (máximo remoto `w213`) e a árvore local (máximo local `w0`); conferido sem colisão contra as branches `wip/upgrade-safety-ldg-0131` (máximo `w154`) e `wip/deepspec-run-manifest-ldg-0165` (nenhum ordinal). 24 gates distintos, faixa `w214`–`w237`, sem repetição.

São 27 linhas e 24 gates distintos no R02. As outras nove issues do R02 (#120, #119, #150, #103, #117, #153, #136, #140, #151) ampliam gates existentes.

Adendo de 2026-09-25: as linhas w238–w246 (10 linhas, 9 gates distintos) foram atribuídas à mão, nunca por `gate-ordinal.sh next`, que só lê o tronco remoto (LDG-0167, LDG-0173). Conferidas contra as 60 refs locais (`git for-each-ref`: heads, remotes e tags, com `git ls-tree -r --name-only <ref> -- tests`), em que o máximo é w213 e nenhuma tem ordinal maior ou igual a w214; e contra as 86 cabeças de PR remotas (`git ls-remote origin 'refs/pull/*/head'`): 48 com objeto local, máximo w213 (`refs/pull/147/head`), e 38 sem objeto local, todas de PRs fechados entre #3 e #68, não medidas. A faixa w214–w237 do R02 continua livre em todas as refs medidas. O LDG-0189 não tem gate próprio: entra no w238, gate novo da #160, no mesmo PR. Ampliam gates existentes, sem ordinal novo: LDG-0182 (w80), LDG-0153 (w191), LDG-0158, LDG-0167 e LDG-0173 (w204 e w193), LDG-0161 (w13), LDG-0152 (w190), LDG-0157 (w120), LDG-0188 (w198) e LDG-0100 (w136).

## O que faz o placar sair com rc diferente de zero

Lido em `tools/plan-progress.mjs`. Sai rc 2 em: erro de uso (argumento desconhecido ou flag sem valor); plano inexistente; nenhuma seção `## Onda N — título`; onda sem item extraído; `--wave` com onda inexistente; item em duas ondas; ledger com JSON ilegível; `--universe` ausente ou ilegível. Sai rc 1 em: ledger não medido (arquivo ausente ou zero entradas); reconciliação com órfão (item aberto no repositório fora do plano) ou fantasma (item do plano inexistente no universo); ou rede ligada com `gh issue list` falhando. Não mudam o rc: ondas não entregues e itens abertos (o placar só conta), onda sem `**DoD` (só imprime aviso), entradas de ledger com status nulo ou `resolved` sem carimbo (só imprime `✗` na seção de integridade), `--help` (rc 0) e `--no-network`, que declara a cegueira e pula a reconciliação de issues sem rc 1.

## Decisões que o brief não cobriu

1. #101 e #131 num PR só, com a #125 em PR separado que depende dele: as três passam por `bin/forge.mjs:623-633`, mas a #125 tem duas causas próprias (`sync-adapters.mjs:233` e o contrato argv do gancho) e depende também da #130.
2. #138 e #139 em PRs separados, com ordem declarada, contra a sugestão da triagem de desenhá-las juntas: os loci são distintos e L5 continua valendo como desenho único executado em dois passos.
3. Desvios em relação aos spikes para ficar retrocompatível: exceção expirada preserva em vez de parar (L1 D3), teto de posse opt-in em vez de derivado (L2 D3), backup em vez de recusa no handoff, fallback `latest` com WARN no pentest.
4. Nenhuma onda de decisão e nenhuma onda de fechamento, porque nenhuma issue atende aos critérios e uma onda vazia faz o placar sair rc 2; as duas viraram seções sem "Onda".
5. #123: a decisão do dono (DH-4) cobre só a recomendação do kind aos consumidores. Incluir o kind em si não dependia dela, porque `fs-union` é aditivo e opt-in e a leitura antiga já recusa kind desconhecido (`liaison-config.mjs:86`), medido. A posição no Bloco A vem da medição no axis-device-platform, registrada na seção da #123.
6. #117 é retrocompatível por medição: nenhum leitor recalcula o nome do blob (`BODY_REF_RE` só confere padrão).
7. #136 amplia o gate criado pela #133 em vez de ganhar gate próprio, o que prende a ordem de merge entre as duas.
8. (R02) Nenhuma entrada de ledger entrou na onda de uma issue; LDG-0153, LDG-0178 e LDG-0181 são vizinhas com locus distinto. Superado pelo adendo: onda = bloco, e o LDG-0181 e o LDG-0153 entram nas Ondas 3 e 4 como itens próprios, ao lado das issues vizinhas, enquanto o LDG-0178 fica na Onda 8.

## O que ficou sem medir

A suíte completa e a duração dela, vetadas pela regra de concorrência desta rodada. O vermelho comportamental de cada issue do R02 depois de 2026-09-15 (a base não se moveu, mas só houve checagens estáticas em 2026-09-25) e os vermelhos das seções novas que dizem "a executar contra a base no PR" (#160, LDG-0181, LDG-0153, LDG-0182). O efeito real de `forge update` nas árvores de consumidor, que só teve dry-run e clones sem o lock rastreado. A equivalência do `fs-union.sh` do axis-device-platform com o da #123, cujo código ainda não existe. O `guard-machinery-drift` do axis-fare-validator diante de exceções que expiram. O conteúdo integral das cerca de 153 mensagens de liaison não lidas. Quantas das 17 a 19 linhas `! cmd` nuas estão de fato mortas. As 38 cabeças de PR remotas sem objeto local, todas de PRs fechados entre #3 e #68, na conferência de ordinais. Consumidores em versões rc.
