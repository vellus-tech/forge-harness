# Refactor — add-unify-changelog-skill

> Especificação do refactor `add-unify-changelog-skill` — mudança interna com **duas divergências de saída intencionais, documentadas abaixo**, e sem alteração do contrato de entrada dos comandos.
> Este artefato substitui `requirements.md` no tipo `refactor`. O archive só ocorre se o comportamento preservado foi verificado.

## 1. Invariantes comportamentais (o que NÃO pode mudar)

- REQ-01 — `/forge:update-changelog <component> <type> <description>` continua aceito com os três argumentos posicionais. Quando a branch não é protegida e não há `release-please-config.json` no componente, produz o mesmo efeito de hoje: entrada `- <description>` na seção `### <Seção-pt-BR>` dentro de `[Unreleased]` do `<component>/CHANGELOG.md`. Nas duas condições novas (branch protegida, release-please presente) e nos quatro gates pós-escrita, o comportamento é o descrito em REQ-08..REQ-11 — não é mais "sempre escreve", e isso é intencional (ver nota de escopo abaixo).
- REQ-02 — O hook `post-merge` continua rodando automaticamente em todo merge, sem exigir invocação manual, e continua sendo no-op quando não há `CHANGELOG.md` na raiz ou quando `HEAD` não é merge (mesmas condições de hoje).
- REQ-03 — O hook `post-merge` continua idempotente: reexecutar sobre o mesmo merge não duplica entradas. A idempotência continua ancorada no sufixo `(<hash>)` ao final de cada linha gerada automaticamente — esse sufixo é preservado pelo motor novo, porque é a própria chave de deduplicação.
- REQ-03b — O marcador `**[BREAKING]**` para commits com `!` (ex. `feat(auth)!: ...`) continua sendo adicionado pelo motor que o hook chama.
- REQ-03c — O hook `post-merge` nunca commita: só edita `CHANGELOG.md` e imprime aviso de mudança pendente, como hoje.
- REQ-03d — Quando `node` não está disponível no `PATH`, o passo de changelog do hook é no-op (sem erro observável), como hoje.
- REQ-03e — Quando o CHANGELOG raiz não tem `## [Unreleased]`, o motor cria a seção antes da primeira versão numerada, como hoje.
- REQ-04 — As demais responsabilidades do `post-merge` continuam exatamente como hoje, fora do escopo deste change: `git worktree prune`; PROPOR (não remover, exceto com `FORGE_WORKTREE_AUTOCLEAN=1`) a remoção de worktrees mergeadas limpas; verificação de integridade do liaison log; sugestão de `/forge:promote-staging` em `develop`.
- REQ-05 — A regra de delegação estrita do `post-merge` (issue #49: diretório presente + alvo ausente = erro, nunca no-op silencioso) continua valendo para o novo alvo que o hook chama.
- REQ-05b — A delegação ao tronco quando a worktree que executa o hook tem `.forge/` desatualizado (issue #141, coberta hoje pelo w223) continua valendo para o novo alvo.
- REQ-05c — Quando a worktree não tem `.forge/` nenhum (harness não instalado), o passo de changelog permanece no-op silencioso (rc 2 de `resolve_delegated`), como hoje.
- REQ-06 — O formato Keep a Changelog (`## [Unreleased]`, `### <Seção>`, lista `- `) é preservado em ambos os caminhos (comando e hook).
- REQ-07 — O hook `post-merge`, ao resolver o motor de rascunho, resolve **só a cópia do projeto** (`.forge/skills/readme-generator/...` via `resolve_delegated`, no mesmo padrão dos outros alvos do hook) — nunca a skill de escopo de usuário. Isso evita que uma máquina com a `readme-generator` (Python, contrato diferente) de outro consumidor seja executada pelo hook deste repositório.

**Comportamento novo, intencionalmente acrescentado (sem REQ anterior correspondente — âncoras próprias para o `/forge:verify`):**

- REQ-08 — `/forge:update-changelog` sem `type`/`description` entra em modo derivado: deriva entradas de Conventional Commits da branch atual (via `--subject "<título>"` para squash merge, ou `--path <componente>` varrendo o intervalo de commits do componente). `--path` apontando para um componente inexistente reprova com rc 2 (não produz "nada a registrar" por vacuidade).
- REQ-09 — Em qualquer modo, o comando para sem editar nada quando a branch atual é `develop`, `master` ou `main`.
- REQ-10 — Em qualquer modo, se o componente tem `release-please-config.json`, o comando não edita o CHANGELOG e aponta para o título do PR como fonte da entrada de release.
- REQ-10b — O hook `post-merge`, ao encontrar `release-please-config.json` na raiz, também não edita o CHANGELOG raiz (no-op informativo, mesma linha de raciocínio do REQ-10) — sem isso, o comando e o hook voltariam a divergir exatamente no caso que a issue #238 aponta como risco ("a `[Unreleased]` manual fica abaixo da próxima versão gerada e o arquivo sai fora de ordem"). Essa checagem roda ANTES da guarda de ausência de CHANGELOG do REQ-02 ser avaliada quanto a criar arquivo novo — ou seja, com release-please presente, o hook nunca cria nem edita `CHANGELOG.md` raiz, independentemente do REQ-14.
- REQ-11 — Depois de escrever (em qualquer modo), o comando roda quatro gates e só conclui se todos passarem: `released` (cada seção `## [X.Y.Z]` do arquivo anterior idêntica byte a byte no novo), `preserve` (nenhum bloco antigo sumiu), `lint` (travessão, quebra de linha dentro de parágrafo, acentuação, placeholder, link) e `check-ai-attribution.sh text`.
- REQ-12 — `resolve-skill.sh <nome> [<arquivo-obrigatório>...]` é usado **só pelo comando** `/forge:update-changelog` (nunca pelo hook — ver REQ-07). Resolve nesta ordem: `FORGE_SKILL_DIR_<NOME>` → `.forge/skills/<nome>` do projeto → skill de usuário do adapter ativo. Ausência nas três: `FAIL skill <nome> ausente`, rc 1 — nunca volta ao comportamento antigo do comando em silêncio.
- REQ-13 — O hook `post-merge` resolve o motor de rascunho pelo MESMO mecanismo que já usa para os outros alvos delegados (`resolve_delegated`, restrito a `.forge/skills/readme-generator/...` do projeto — REQ-07), não pelo `resolve-skill.sh` do comando. Quando esse motor falta (diretório presente, arquivo ausente) ou falha ao rodar, o hook registra `delegation_failed=1` e sai com o mesmo padrão observável já usado para os outros alvos delegados (linha própria, exit≠0), nunca como "post-merge OK".
- REQ-14 — O deduplicador do motor de rascunho aceita `CHANGELOG.md` ainda inexistente nos modos chamados pelo comando (explícito e derivado — cria com cabeçalho Keep a Changelog padrão em vez de falhar com erro de arquivo ausente). Não se aplica ao modo `--merge-range` do hook, que é no-op sem CHANGELOG (REQ-02).

**Divergências de saída intencionais (NÃO são regressão — são o próprio defeito da issue #238 sendo corrigido):**

- DIV-01 — O hook `post-merge` passa a escrever seções em **pt-BR** (`### Adicionado`/`### Alterado`/`### Corrigido`), não mais em inglês (`Added`/`Changed`/`Fixed`). Mapeamento explícito: `feat` → Adicionado, `fix` → Corrigido, `perf` → Corrigido (alinhado à tabela de `conventional-commits.md`, que agrupa `perf` em `[Fix]` — o `.mjs` atual o agrupava em `Changed`, o que também é corrigido aqui). Quem já tem entradas em inglês no histórico do CHANGELOG raiz as mantém (não há migração retroativa de blocos já publicados); as seções **dentro do bloco `[Unreleased]` ainda não liberado** passam a conviver com cabeçalhos em dois idiomas até a próxima release — aceito explicitamente como transição de uma vez, não corrigido retroativamente: o invariante "nunca alterar versões já liberadas" (gate `released`) não se aplica a `[Unreleased]`, mas normalizar retroativamente o idioma das entradas já escritas ali por execuções anteriores do hook é, ainda assim, fora de escopo deste change.
- DIV-02 — O hook `post-merge` deixa de gravar entradas para commits `refactor` e `revert`. Só `feat`/`fix`/`perf` entram, conforme a tabela de `rules/conventions/conventional-commits.md`. Um merge que só tivesse `refactor`/`revert` elegíveis antes, e nenhum `feat`/`fix`/`perf`, passa a ser no-op onde antes gerava entrada — isso é a correção pedida pela issue, não um bug novo.

**Nota de escopo sobre REQ-01 e tipo `refactor`:** as condições novas em REQ-09/REQ-10/REQ-11 são aditivas (o modo explícito de três argumentos continua funcionando no caminho feliz), mas são comportamento observável novo, não só correção interna. Isso é aceito deliberadamente dentro do tipo `refactor` porque a issue #238 pede exatamente essas salvaguardas como parte da unificação, e nenhuma delas remove ou contradiz o que existia — ver `proposal.md §2`.

## 2. Área impactada

Ver `manifest.yaml > affected_paths`. Resumo: comando `/forge:update-changelog` (camada fina), skill nova `readme-generator` (motor de rascunho + gates, porção CHANGELOG), script novo `resolve-skill.sh`, hook `post-merge` (religado ao motor da skill em vez de `changelog-from-merge.mjs`), remoção com tombstone de `changelog-from-merge.mjs` e `tests/changelog-merge-gate.sh`, reescrita de `tests/w147-hook-delegation-gate.sh` / `tests/w223-delegacao-arvore-do-hook-gate.sh` / `tests/w248-git-dir-isolation-gate.sh` para o novo alvo, e teste de regressão novo para os gates `released`/`preserve`.

## 3. Motivação e resultado esperado

Issue #238: três caminhos escrevem CHANGELOG com comportamentos divergentes (classe LDG-0014). Resultado esperado: um único motor de derivação/gates (a skill), usado tanto pelo comando (modo explícito ou derivado) quanto pelo hook (modo derivado, sem gates de bloqueio — ele não bloqueia merge). Sucesso medido por: (a) suíte `npm test` verde incluindo os gates reescritos e o novo teste de regressão; (b) nenhuma seção em inglês ou entrada `refactor`/`revert` nova gravada pelo hook após a mudança; (c) `/forge:update-changelog` continuando a funcionar nos dois modos (explícito e derivado).

## 4. Riscos

| Risco | Detecção | Mitigação |
|---|---|---|
| Reescrever w147/w223/w248 perde cobertura original (erro ausência de script, delegação ao tronco, isolamento GIT_DIR) | Comparar cenário a cenário entre o teste antigo e o novo antes de apagar o antigo; `npm test` verde | Checklist de paridade de cenários em `tasks.md`; revisor adversarial no `/forge:verify` |
| Hook `post-merge` sem gate de bloqueio grava algo mal formado (git ignora exit status) | `tests/w147`/`w223` continuam cobrindo o caminho de erro observável (linha própria + `delegation_failed`) | Hook mantém o padrão já existente de `delegation_failed=1` quando o motor falhar |
| Colisão de nome `readme-generator` entre a skill do template e a de escopo de usuário do Payments | `resolve-skill.sh` resolve a cópia do projeto primeiro; sem ambiguidade de precedência | Precedência documentada no próprio `resolve-skill.sh` e no SKILL.md |
| Gates `released`/`preserve`/`lint` do comando, se portados em Python, introduzem dependência de `python3` só no comando (não no hook) | `doctor` não checa hoje `python3`; grep em `template/.forge` por outros usos | Decisão de design: portar também os gates e o motor de rascunho em Node, evitando qualquer dependência nova de `python3` — ver `design.md` |
| `installer/removed-files.txt` esquecido deixa `.mjs` órfão em consumidores já instalados | `forge:doctor` após update num clone de teste | Entrada obrigatória no tombstone, verificada em `tasks.md` |
| `tests/w248-git-dir-isolation-gate.sh` usa `tests/changelog-merge-gate.sh` como gate real de vítima para o isolamento de `GIT_DIR`; apagar sem substituto quebra o w248 | `npm test` reprova o w248 | Substituir a vítima pelo teste de regressão novo dos gates `released`/`preserve` (item 6 da estratégia) — ele também é um gate real que lê/escreve arquivo via git, servindo ao mesmo propósito de vítima |
| `plugin/forge/commands/update-changelog.md` é espelho vivo do comando; editar só a fonte e esquecer o rebuild deixa o plugin dessincronizado (classe de BLOCKER já vista no PR #42) | `build-plugin.sh --check` ou diff manual pós-mudança | Rodar `build-plugin.sh` como último passo da implementação, antes do `npm test` final. `snapshot/project-bootstrap/` é referência imutável (travada por `tests/snapshot/verify-manifest.sh`) e não é tocada por este change — não há rebuild a fazer ali |

## 5. Estratégia de migração

1. Portar o motor de rascunho (deriva de Conventional Commits) e os gates `released`/`preserve`/`lint` da skill Payments para Node, em `template/.forge/skills/readme-generator/scripts/` — vermelho primeiro (testes novos falhando), depois verde.
2. Criar `resolve-skill.sh` com a precedência documentada (projeto → skill de usuário) e falha explícita.
3. Reescrever `template/.forge/commands/docs/update-changelog.md` como camada fina (modo explícito preservado + modo derivado novo + trava de branch protegida + detecção de release-please + os quatro gates).
4. Religar `template/.forge/hooks/git/post-merge` ao motor da skill (idioma pt-BR, mapeamento restrito a feat/fix/perf), mantendo a regra de delegação estrita (REQ-05).
5. Remover `changelog-from-merge.mjs` e `tests/changelog-merge-gate.sh`, com tombstone em `installer/removed-files.txt`. `template/machinery-history.json` não é tocado (gerado por `tools/build-machinery-history.mjs` no pós-tag).
6. Reescrever `w147`/`w223`/`w248` para o novo alvo, cenário a cenário (w248 passa a usar o teste de regressão do item 7 como vítima real, no lugar de `changelog-merge-gate.sh`; precisa nascer com o mesmo preâmbulo de isolamento de `GIT_DIR` que o antigo tinha).
7. Escrever o teste de regressão dos gates `released`/`preserve` (4 controles: versão publicada alterada, versão removida, bloco removido, conjunto vazio) e um teste cobrindo os cenários que `changelog-merge-gate.sh` cobria hoje (feat/fix geram entrada, chore ignorado, refactor/revert ignorados, idempotência, no-op sem merge, no-op sem CHANGELOG raiz, no-op com release-please), agora contra o motor novo.
8. Rodar `build-plugin.sh` para sincronizar `plugin/forge/commands/update-changelog.md` com a fonte editada em `template/.forge/commands/docs/`. `snapshot/project-bootstrap/` não é tocado.
9. `npm test` completo verde.

## 6. Testes de não-regressão

- [ ] Suíte existente verde antes (baseline) e depois da mudança.
- [ ] REQ-01 a REQ-07 (invariantes preservados, incluindo sufixo `(<hash>)`, `**[BREAKING]**`, "nunca commita", no-op sem `node`, criação de `[Unreleased]`, delegação ao tronco #141, no-op sem `.forge/`, resolução só da cópia do projeto) cobertos por teste automatizado.
- [ ] REQ-08 a REQ-14 (modo derivado, trava de branch, recusa com release-please, quatro gates, `resolve-skill.sh` com falha explícita rc 1, `delegation_failed` do motor novo, dedup com CHANGELOG inexistente) cobertos por teste automatizado — cada um com pelo menos um caso positivo e um negativo.
- [ ] DIV-01 e DIV-02 cobertos por teste automatizado que prova a NOVA saída (pt-BR com `perf`→Corrigido, sem refactor/revert), não a antiga.
- [ ] `tests/w147-hook-delegation-gate.sh`, `tests/w223-delegacao-arvore-do-hook-gate.sh`, `tests/w248-git-dir-isolation-gate.sh` verdes contra o novo alvo, com paridade de cenário confirmada (lista cenário a cenário em `tasks.md`).
- [ ] Teste de regressão novo para `released`/`preserve` com os 4 controles da issue (também serve de vítima real ao w248).
- [ ] Teste novo cobrindo os cenários que `changelog-merge-gate.sh` cobria (feat/fix→entrada, chore ignorado, refactor/revert ignorados, idempotência, no-op sem merge, no-op sem CHANGELOG raiz, no-op com release-please) contra o motor novo.
- [ ] `build-plugin.sh` rodado e sem diff residual em `plugin/forge/commands/update-changelog.md`. `snapshot/project-bootstrap/` confirmadamente intocado (fora do diff do change).
- [ ] Verificação de performance: não aplicável (hook e comando operam sobre volumes pequenos de commits/arquivo; sem requisito de latência declarado).
