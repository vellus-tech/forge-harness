# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.
O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o versionamento segue [SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

## [0.1.0-rc17] — 2026-07-11

### Added
- **Controle de ciclo do ledger (item → change → baixa), fechando a lacuna do rc16.** No rc16 a promoção de um item do ledger a um change era **procedural** (a rule pedia `/forge:ledger promote`, mas nada garantia) — e havia dois buracos de ida-e-volta: promover-e-abandonar (item sumia do roadmap sem entrega) e entregar-sem-baixa (change arquivado deixava o item `promoted` para sempre). Agora o elo é **declarado uma vez e o resto é automático**: `/forge:spec new <id> --from-ledger LDG-NNNN` marca a entrada `promoted` **e** grava `ledger_origin` no manifest; a partir daí `spec-close.sh`/`archive-spec.sh` fecham o ciclo deterministicamente antes do `mv` — **archive → `resolved`** (entregue ao baseline), **close abandoned/rejected → reaberto `open`** (volta ao roadmap), **close delivered-externally → `resolved`**, **superseded → permanece `promoted`** (o sucessor carrega). É a mesma filosofia inescapável da captura: uma vez declarado o elo, a baixa não depende de memória. Rede de segurança **advisory** (não-bloqueante) no `/forge:doctor`: sinaliza itens `promoted` cujo change de destino sumiu sem baixa. Superfície: `spec-new.sh` (+`--from-ledger`), `spec-manifest.schema.json` (`ledger_origin` opcional), `archive-spec.sh`, `spec-close.sh`, `doctor.sh`, comando `spec.md`, rule `ledger-consultation.md §3`, novo gate `w98-ledger-roundtrip-gate` + asserção no `w32`.

### Fixed
- **`LEDGER.md` não renderiza mais "→ promovido para" em item reaberto** (revisão adversarial, LOW): um item que volta a `open` por `close abandoned/rejected` mantém `promoted_to` como histórico, mas exibi-lo confundia (apontava um change abandonado). O render só mostra o elo em `promoted`/`resolved`.

## [0.1.0-rc16] — 2026-07-11

### Added
- **Ledger durável de projeto — `/forge:ledger` + `.forge/ledger/LEDGER.md`.** Fecha a lacuna de não haver **nenhum artefato durável** para roadmap, dívida técnica, bugs conhecidos, follow-ups e ideias que sobreviva entre changes. Até aqui o único ledger (`deferrals.json`) era **escopado a um change**, **bloqueante** e **efêmero** (migra para `specs/archived/` no close/archive e vira história morta), e os findings de `/forge:analyze` (`analysis.md`) e `/forge:verify` (`verification.md`) morriam junto — uma descoberta fora de escopo se perdia se o humano não abrisse um ADR ou anotasse à mão. O ledger é o oposto: **durável** (vive em `.forge/ledger/`, fora de `MACHINERY_DIRS` — preservado byte-a-byte pelo `update`, como `specs/`/`graph/`), **não-bloqueante** (registrar nunca trava um change) e **de projeto**. Store estruturado (`ledger.json` + `ledger.schema.json`, entradas tipadas `roadmap|tech-debt|known-bug|follow-up|feature-idea` com id `LDG-NNNN`) e view mestre `LEDGER.md` renderizada **deterministicamente** (ordenação por tipo→prioridade→severidade→id, nunca por timestamp; `created_at` = data do commit HEAD; seção "Notas" preservada entre gerações). Respeita a postura do harness (`context.md`: "durable state lives in structured manifests, not mutable memory").
- **Captura automática inescapável (mesmo se o HITL esquecer).** O harvest é injetado dentro do `spec-close.sh` e `archive-spec.sh` **imediatamente antes do `mv`** que move (mata) a pasta do change — como não há como fechar/arquivar sem rodar esses scripts, a captura é inescapável e **determinística, sem LLM**: deferrals `open`→`follow-up`, `wont-fix`→`tech-debt`; findings `MEDIUM`/`LOW` do `analysis.md`→`tech-debt` (grep da mesma tabela pipe que o `spec-transition.sh` já usa como único gate enforçado); desvios/RESSALVAS do `verification.md`→`follow-up`. Idempotente por `dedup_key` (`${change_id}:${ref}`) e best-effort (falha nunca aborta o close/archive). É o análogo *positivo* do gate de BLOCKER: em vez de bloquear, coleta.
- **Ledger como motor de "próximo passo".** `/forge:resume` e `/forge:status` passam a consultar o ledger; a rule `conventions/ledger-consultation.md` instrui qualquer agente a olhar o `LEDGER.md` ao sugerir trabalho e a `promote` uma entrada quando ela vira change (`/forge:spec new`). Pode nascer **semeado** (`/forge:ledger add --type roadmap|feature-idea` para módulos/features/arquitetura planejados). Surfacing opt-in no início da sessão via `forge.yaml > ledger.auto: true` (reusa o hook `SessionStart`, mesma infra do `handoff.auto`).

### Changed
- **Invariante do `/forge:close` atualizada:** o close agora tem um efeito colateral **intencional e não-bloqueante** — o harvest para `.forge/ledger/`. O gate `w22` sanciona `.forge/ledger/**` como o único novo alvo de escrita fora de `.forge/specs/**` (o archive já escrevia fora da pasta: CHANGELOG, capabilities). Comentário do `spec-close.sh` alinhado.
- **`forge.yaml` ganha o bloco de topo `ledger:` (`auto: false`).** Propaga a projetos existentes via o merge aditivo de chaves de topo do `update` (rc15); validado por `forge.schema.json`.

## [0.1.0-rc15] — 2026-07-10

### Fixed
- **`forge update` remove órfãos de maquinaria por tombstone (não só overlay aditivo).** Até aqui o `update` só *adicionava/sobrescrevia* arquivos de maquinaria e **nunca deletava** — então um arquivo renomeado ou removido entre versões sobrevivia como órfão inerte no consumidor. Sintoma real: após o rename `/forge:build` → `/forge:codegraph` (rc13), todo projeto atualizado ficava com `commands/graph/build.md` **e** `codegraph.md`, mantendo o slash command stale `/forge:build` vivo. Agora o `update` lê `installer/removed-files.txt` (manifesto **curado** de paths que o template renomeou/removeu, versionado junto com o bin) e **deleta** cada um que exista no consumidor, listando as remoções; o `--dry-run` as prevê (`- <arquivo> (órfão)`). A deleção é **curada de propósito, não "tudo que não está no template"**: um consumidor pode legitimamente ter commands/agents/rules autorais sob `.forge/` (a resolução via `custom/` ainda não é implementada — `sync-adapters`/`plugin-build` varrem `.forge/` diretamente), e apagá-los às cegas seria perda de trabalho. Invariante imposta pelo gate `w63`: nenhum path do manifesto pode existir no template atual (senão o overlay o escreveria e a tombstone o apagaria em seguida). Backup `.forge.bak-N` cobre. _Achado da revisão adversarial: a versão inicial "reconcile-to-template" (deletar tudo fora do template) apagaria silenciosamente arquivos autorais do consumidor, já que o contrato de escape via `custom/` não existe no código; trocada por tombstones antes do merge._
- **`forge update` mescla chaves de topo novas do `forge.yaml` do template.** O `update` preservava todo o `forge.yaml` do projeto (por design) e só tocava `harness.template_version` — então uma **seção de topo nova** de uma versão (ex.: o bloco `autonomy:` do `--yolo`, rc14) **nunca chegava** aos consumidores, deixando a feature inutilizável sem edição manual. Agora, além do `template_version`, o `update` faz **merge aditivo**: acrescenta blocos de topo inteiros que faltam (preservando byte-a-byte tudo que o projeto já tinha, sem tocar chaves ou sub-chaves existentes — limite honesto: só seções de topo ausentes, o caso comum de feature nova). Blocos com placeholder UPPERCASE não resolvido (`<PROJECT_*>`, `<INSTALLED_AT>`, …) **não** são mesclados — o `update` não injeta token cru — e emitem **aviso** (não somem em silêncio). Previsto no `--dry-run` (`~ forge.yaml (+ <chave>: bloco novo)` / `! forge.yaml (<chave>: exige preenchimento manual)`).
- **Hook `pre-push`: `mktemp` incompatível com BSD/macOS bloqueava todo `git push` local.** `mktemp /tmp/forge-prepush-XXXXXX.log` falha no BSD (o template precisa **terminar** na sequência de X; qualquer sufixo depois — `.log` — aborta), e o `pre-push` então abortava o push com erro em vez de rodar typecheck/test. Corrigido para `mktemp "${TMPDIR:-/tmp}/forge-prepush-XXXXXX"` (portável GNU+BSD). Novo gate `w97` grepa os hooks contra o footgun (template de `mktemp` com caractere após os X) para impedir regressão. _Root-cause upstream do padrão em que consumidores reaplicavam o fix a cada upgrade._

### Changed
- **Backup do `update` exclui `worktrees/`.** O `.forge.bak-N` (cópia) passa a pular `.forge/worktrees/` — working trees de git worktrees linkados são potencialmente enormes e carregam ponteiros `gitdir` que quebram numa cópia.
- **Gate `w63` cobre a semântica nova.** Casos: `[d]` órfão tombstoned removido, `[d1]` **segurança** — arquivo autoral não-tombstoned do consumidor preservado, `[d2]` `custom/` preservado byte-a-byte, `[d3]` chave de topo nova do `forge.yaml` mesclada (remove `autonomy` do fixture e confirma o merge de volta), `[6]` invariante das tombstones (nenhuma existe no template).
- **`custom/README.md` alinhado à realidade** — documenta explicitamente que a resolução automática por `custom/` ainda **não** está implementada (rc15); adições autorais vivem em `.forge/` e são preservadas pela deleção curada por tombstone.

## [0.1.0-rc14] — 2026-07-10

### Added
- **Skill `frontend-ui-review` — auditoria de despadronização de UI.** Revisa frontend contra o design system com gates **determinísticos** (custo zero, sem LLM) antes da revisão semântica: **A1 scan de token fantasma** (⭐ diferença de conjuntos `var(--x)` referenciados − `--x:` definidos — acha o universo de tokens nunca definidos que "funcionam" em light e viram buraco no dark; script real `scan-phantom-tokens.py`), A2 cor hardcoded, A3 fallback literal (`var(--x, #hex)` mascara contrato quebrado), A4 controle nativo do browser, A5 cobertura na superfície inteira (não só o diff). Mais verificação de tema (dark como forçador de qualidade), revisão semântica (primitivo faltante × improviso, dado cru GUID/enum vazando, bordas/espaçamento/raio como tokens, a11y) e auditoria de qualidade de teste (estrutura × comportamento real). As **convenções de escrita** correspondentes entraram na rule `frontend/design-system.md` (regras 10-12: proibido token fantasma, proibido fallback literal, controle nativo domado/encapsulado — a rule previne, a skill audita). Fiada no `frontend-engineer` (rodar antes de declarar UI pronta). Gate `w96` exercita o scanner (fixture com/sem fantasma + allowlist).
- **Modo autônomo `--yolo` (§12.2).** Novo `forge.yaml > autonomy.mode` (`hitl` default | `yolo`): em yolo, os gates HITL de aprovação (§12.1) deixam de parar no `AskUserQuestion` e são decididos por um subagente **Opus effort high** (novo agent `review/yolo-gate.md`), que analisa o artefato com rigor adversarial, emite a decisão canônica (approve/review/reject/block/…) e a registra via `approval-log.sh --autonomous`. Deixa fluxos e loops (run-spec-pipeline, specs-loop, coding-loop, gates de spec, ship) rodarem ponta-a-ponta sem humano no teclado. Duas invariantes de segurança: **(1) honestidade de auditoria** — a decisão grava `autonomous: true` + `decided_by: "forge-yolo (opus, high)"`, nunca mascarada como humana, e todo approve autônomo carrega o motivo (o script recusa approve autônomo sem `--reason`), então uma auditoria filtra o que a máquina liberou; **(2) yolo decide gates, não mascara falhas** — `[!]`, blockers e conflito de fontes continuam parando, e `review` autônomo itera no máx. 3× e escala. **Hard-stops** configuráveis: `human_hard_stops` (default `human_archive_approval` — mutação de baseline exige humano em domínio regulado, §13.1) e `irreversible_hard_stops` (deploy prd, promote-staging, remoção de adapter, branch cleanup) nunca são auto-aprovados. Superfície: `forge.yaml`, `approval-log.sh --autonomous`, `approvals.schema.json`/`validate-spec.mjs` (campo `autonomous`), agent `yolo-gate`, rule `conventions/autonomy-yolo.md`, wiring em 10 comandos, FORGE.md §7, referência §12.2, gate `w95`.

## [0.1.0-rc13] — 2026-07-10

### Added
- **Estado terminal `delivered-externally` no `/forge:close`.** Fecha a lacuna de uma spec cuja obra foi **entregue fora do pipeline** (ex.: PR direto que nunca percorreu requirements→design→tasks→verify): antes, os únicos terminais eram `abandoned`/`rejected` (pré-`implementing`, significam *não entregue*), `superseded` (exige sucessor) e `archived` (exige o pipeline completo + toca o baseline). Forçava mapear entrega real para `abandoned` — auditicamente falso, já que o que uma auditoria varre é o `status:` no topo do manifest. O novo terminal é *positivo* e vale de **qualquer** estado (como `superseded`): `status: delivered-externally`, `archive.kind: closed_without_baseline_update` (a entrega está no código real, não em deltas do pipeline), decisão `deliver-external` no `approvals.yaml`, `--note` obrigatória carregando a evidência (link do PR). Baseline intocado pela máquina de spec — reconciliar `product/current` é passo separado. Superfície: `spec-close.sh`, `approval-log.sh`, `validate-spec.mjs`, `approvals.schema.json`, `spec-manifest.schema.json`, `archive-state-machine.yaml`, comando `close.md` e gate `w22` (caso `[5b]`).
- **Convenção `conventions/code-style.md`** — nova rule que governa a **forma interna** do código que cada TASK produz, fechando a lacuna entre "task bem decomposta" e "código bem escrito": early return / guard clauses, aninhamento ≤3, uma função–uma responsabilidade–um nível de abstração, sem literais mágicos, assinaturas enxutas (sem flag booleana), tratamento de erro fail-fast (nunca engolir; exceção de domínio × `Result`), imutabilidade/pureza por padrão, comentar o "porquê", regra de três (contra abstração prematura) e fronteira defensiva × núcleo confiável. Escopo é estilo — imutabilidade de domínio e validação por camada continuam deferidas a `architecture/ddd.md` e `architecture/clean-architecture.md` por link, sem re-derivar. Enforcement por checklist de revisão + linter da stack quando configurado (smell, **não** novo gate bloqueante de CI). Fiada em todo o fluxo: `tasks-writer` (§1.11, herdada por todo `tasks.md` gerado, + anti-patterns), os 4 engineering agents (leem antes de codificar), `quality-reviewer` (dono do checklist) e `task-coder` (contexto passado aos specialists).

### Changed
- **Slash command `/forge:build` renomeado para `/forge:codegraph`.** O comando constrói o grafo de código; o nome antigo era ambíguo (colidia conceitualmente com `/forge:build-plugin` e não dizia o quê construía). Todas as referências funcionais (`/forge:graph build` em commands, agents, skills e mensagens de erro dos scripts) e a documentação canônica (`docs/refer/slash-commands.md`) foram atualizadas; o engine (`.forge/scripts/graph.sh build`) permanece inalterado. Plugin regenerado.

## [0.1.0-rc12] — 2026-07-09

### Fixed
- **`core.hooksPath` sobrescrevia silenciosamente um valor customizado pré-existente.** `npx forge-harness init`/`update` e `installer/install.sh` passam a checar o valor atual antes de escrever: ausente/default → seta `.forge/hooks/git` (comportamento preservado); já correto → no-op; customizado para outro valor → **preservado**, com nota informativa. `core.hooksPath` vive em `.git/config`, compartilhado entre worktrees sem `extensions.worktreeConfig` — achado real ao propagar `forge update` em `axis-go-cloud` (2×): um `core.hooksPath = .githooks` intencional foi apagado silenciosamente, vazando para o checkout principal.

## [0.1.0-rc11] — 2026-07-09

### Added
- **Proveniência de execução inspirada no DeepSpec.** Novo `run-manifest/v1` registra stage, runner, orçamento, inputs/outputs com hashes e proveniência Git segura (branch, SHA, dirty files, diff stat e hash do diff — sem diff bruto, testado com segredo real injetado no diff). `spec-verify` e `archive-spec` gravam evidência em `evidence/runs/*/run-manifest.json` de forma **bloqueante por contrato** (nunca por falha de I/O da própria gravação); `meta-aggregate` e `eval-aggregate` gravam de forma best-effort.
- **Contratos de I/O por estágio + benchmark registry.** Nova árvore `.forge/contracts/stages/*.yaml` (verify, archive, eval, run-spec-pipeline, skill-lifecycle-eval), validador determinístico `validate-stage-contract.sh`, schemas `run-manifest`/`benchmark-case`, `budget-preflight.sh` (perfis `standard/quick/regulated/brownfield-heavy` com precedência flag > manifest.yaml > forge.yaml > default; `--set key.path=value` restrito a eval/benchmark), e `/forge:eval benchmark <case|suite>` com cinco casos canônicos pequenos (`greenfield-small`, `brownfield-bugfix`, `refactor-invariant`, `docs-only`, `multi-module-scale3`). `npx forge-harness update` passa a sincronizar também `.forge/contracts/`.

## [0.1.0-rc10] — 2026-07-09

### Fixed
- **Gate de pre-push (`check-docs-reviewed.sh`) tratava maquinaria do harness como código do produto.** Um commit `chore(forge): atualiza harness` (via `npx forge-harness update`) tocando `.forge/**` passava a exigir README/CHANGELOG do projeto consumidor sem necessidade — achado ao propagar o rc9 para projetos reais. Excluídos da classificação user-facing: `.forge/**`, `.claude/**`, `.agents/**`, `.cursor/**`, `.kiro/**`, `AGENTS.md`, `CLAUDE.md`, `QWEN.md`, `GEMINI.md`. Refino de classificação, não válvula de escape — código real do produto continua exigindo docs.
- **`doctor` — guard de refs `.claude/` agora exclui também `hooks/`** (mesma categoria de `adapters/`/`scripts/`, já excluídos): scripts de hook legitimamente referenciam o diretório gerado `.claude/`.

## [0.1.0-rc9] — 2026-07-09

### Added
- **`npx forge-harness update` / `/forge:upgrade`** — atualização cirúrgica do harness num projeto que já tem `.forge/`. Faz overlay **aditivo** da maquinaria (`agents/ commands/ hooks/ schemas/ scripts/ skills/ templates/ rules/`, `adapters/*.yaml` sem locks, `README.md`) — sobrescreve/adiciona, nunca deleta — e **preserva** os dados do projeto: `specs/`, `product/current/` (baseline), `custom/`, `evals/`, `runners.yaml`, `constitution.md`, `context.md`, `FORGE.md`, e todo o `forge.yaml` exceto `harness.template_version`. Inclui `--dry-run` (lista mudanças sem escrever), backup `.forge.bak-N` (opt-out via `--no-backup`), reconciliação de adapters ativos (`sync-adapters --adapter all`), correção do `core.hooksPath`, re-materialização do plugin e `doctor` como post-check. Substitui o antigo caminho destrutivo (`init --force` movia o `.forge/` inteiro para backup). O slash `/forge:upgrade` tem nome próprio para não colidir com `/forge:update` (grafo de código).

### Fixed
- **`doctor` — falso-positivo nas varreduras de "refs `.claude/`" e placeholders `<PROJECT_*>`.** Os guards varriam `.forge/**` inteiro, incluindo `specs/`, `worktrees/`, `product/`, `evals/` e `custom/` — conteúdo autorado pelo usuário (texto de spec pode citar `.claude/`; arquivos de deploy em worktrees carregam tokens do próprio app). Agora esses diretórios de dado são excluídos; só a maquinaria canônica é varrida.

## [0.1.0-rc8] — 2026-07-09

### Added
- **Integração com o draw.io MCP para elaboração e manutenção de diagramas.** Nova rule `conventions/diagram-tooling.md` define a política em camadas: fonte textual versionada (Mermaid/`infra.py`) como verdade, draw.io como camada de elaboração/edição visual, e ordem de preferência de tooling — MCP `drawio` (`open_drawio_mermaid`/`open_drawio_xml`/`open_drawio_csv`) → plugin Claude Code `drawio@drawio` (`.drawio` nativos + export PNG/SVG/PDF com `--embed-diagram`) → fallback determinista `mermaid-to-drawio.sh` (canônico em CI/offline). Os comandos `/forge:mermaid-to-drawio`, `/forge:infra-diagram` e `/forge:c4` referenciam o caminho MCP (incl. `search_shapes` para shapes reais e nota de data residency para diagramas PCI); convenção registrada no `context.md`.
- **`/forge:ship`** — comando novo que costura commit → PR → revisão → merge em `develop` → cleanup num único fluxo, reaproveitando o protocolo de descrição do `/forge:prepare-pr`. O próprio comando é o gate humano (§20.4): cada etapa só roda porque o usuário o invocou explicitamente. Alvo do PR é sempre `develop` (convenção vellus-tech).
- **`/forge:resume`** — comando novo que emite o mandato de retomada de sessão (estado do change ativo via `progress.json`/`manifest.yaml`/`deferrals.json`, no mesmo padrão barato de leitura do `/forge:status`/`/forge:progress`) e reafirma as regras operacionais fixas (model explícito em subagente, proibição de `docker build` em subagente, `git -C` explícito em worktrees, validação real antes de concluir TASK, checkpoint por módulo/PR) — elimina a fricção de reescrevê-las à mão a cada retomada.
- **Seção "Disciplina de ferramenta"** adicionada, de forma idêntica, aos 30 agents com `Write`/`Edit` no front-matter: Read obrigatório imediatamente antes de Edit/Write, proibição de `docker build`/`docker compose up --build` em subagente (delegar ao orquestrador via `run_in_background`), e autoverificação com build/teste real antes de retornar. Convenção registrada em `agents/README.md`.
- **Checklist de cobertura de superfície** no template de `requirements.md`: mapeia todo parâmetro/config/flag exposto para a tela/endpoint/CLI correspondente e a task que o implementa. `/forge:analyze` passa a cruzar essa matriz (item 6 do protocolo) e trata `NEEDS CLARIFICATION` nela como achado `BLOCKER` de tipo `coverage` — gate de cobertura antes do marco, não depois.
- **Protocolo "Conflito no índice (README/index)"** em `/forge:adr` e `/forge:archive`: índice de ADR e `archived/index.yaml` são append-only por natureza; em conflito de merge a resolução correta é união das entradas (nunca `checkout --ours`/`--theirs` cego), seguida de reordenação por número e revalidação da numeração sequencial.
- **`worktree-reconcile.sh`** — script determinista (sem LLM) que lista, por worktree de `git worktree list --porcelain`, branch/ahead-behind do upstream/status curto (staged/dirty/untracked)/último commit, sempre via `git -C`. Referenciado em `/forge:coding-loop` como passo obrigatório de retomada após subagentes interrompidos/mortos, antes de redistribuir tasks.
- **`/forge:dev rebuild`** — novo subcomando: derruba a stack e rebuilda `--no-cache`. Documenta a regra de que builds .NET com cache mount NuGet compartilhado (`--mount=type=cache,id=nuget-*`) devem rodar **sequencialmente** (corrupção já observada em paralelo), enquanto os demais serviços podem paralelizar; roda em background pelo orquestrador, nunca em subagente. Inclui limpeza opcional de branches merged em `develop` (`--clean-branches`), sempre com confirmação explícita.
- **`doctor.sh`** detecta (best-effort, quando a CLI `claude` está disponível) se o plugin `/forge:*` está instalado/habilitado no Claude Code do operador — sintoma real que motivou o check: usuário colando o corpo dos comandos como texto porque `/forge:*` não existia silenciosamente. Sem `claude` no PATH, o check é pulado; o achado é sempre informativo (nunca reprova o doctor, por ser estado global do operador) e sugere `npx forge-harness install-plugin`.
- **`/forge:handoff`** — handoff portátil e agente-agnóstico (`.forge/HANDOFF.md`) para passar contexto entre sessões e entre code agents (Codex, Cursor, Gemini, Claude Code), não só dentro do Claude Code. Núcleo determinístico via script `handoff-gen.sh` (lê manifest/progress/deferrals/runtime/git); só um delta narrativo curto é escrito pelo modelo. Não é fonte da verdade — o estado canônico continua em `.forge/specs/active/<id>/`. Automação é opt-in via flag `handoff.auto: false` no `forge.yaml`; quando `true`, `sync-adapters` liga hooks SessionStart/SessionEnd no adapter Claude para regenerar/injetar o handoff automaticamente (rule-based, sem LLM). Default off = zero mudança de comportamento.
- **Gate de pre-push HARD-REQUIRE de docs**: bloqueia push com mudança user-facing (commits `feat`/`fix`/`perf` ou qualquer arquivo de código-fonte) se `README.md` e `CHANGELOG.md` não estiverem no diff do push. Sem válvula de escape.

### Changed
- **`/forge:resume`** passa a ingerir a seção "Delta narrativo" do `.forge/HANDOFF.md` quando existe, além do estado via `progress.json`/`manifest.yaml`/`deferrals.json`.
- **`AGENTS.md` gerado** ganha um ponteiro para `.forge/HANDOFF.md`, para que agentes não-Claude descubram o handoff.

## [0.1.0-rc7] — 2026-06-16

### Changed
- **`/forge:doctor` e `/forge:status` agora respondem com orientação clara quando rodados num repo sem o engine Forge.** Como os comandos `/forge:*` são globais (plugin) e aparecem em qualquer projeto, rodá-los num repo sem `.forge/` antes só falhava ao tentar executar um script inexistente. Agora há uma pré-checagem no corpo do comando: se `.forge/forge.yaml` não existe, o agente instrui `npx forge-harness@latest init` (e lembra que não há `/forge:init` por design — o bootstrap é do instalador) em vez de quebrar.

## [0.1.0-rc6] — 2026-06-16

### Changed
- **Slash commands `/forge:*` agora vêm de um plugin do Claude Code** (não mais de `.claude/commands/`). O Claude Code (>= 2.x) descontinuou o namespace via subdiretório em `.claude/commands/` — o `:` virou exclusivo de plugins. O harness gera o plugin `forge` da mesma fonte `.forge/commands/**` (lib `plugin-build.mjs` + comando `/forge:build-plugin`). Distribuição: `npx forge-harness install-plugin` (auto no `init`) **e** marketplace git (`.claude-plugin/marketplace.json`). O adapter `claude` deixa de projetar `.claude/commands/`; o `reconcile` poda dests órfãos de adapters ativos (contrato C1 v1.3).

### Fixed
- Comando `/forge:skill` renomeado para **`/forge:skill-lifecycle`**: o nome `skill` (exato) colide com a infra de skills do Claude Code e **derruba o carregamento do plugin inteiro** silenciosamente. `plugin-build.mjs` agora valida nomes reservados. Novo gate `plugin-sync-gate.sh`.

## [0.1.0-rc5] — 2026-06-15

### Added
- `init --force` agora **protege trabalho de produto**: se o `.forge` existente tem specs (ativos/arquivados) ou docs de produto (ADRs etc.), pede confirmação explícita (interativo) ou **bloqueia com exit 3** (não-interativo, ex.: CI) em vez de sobrescrever. Novo flag `--force-content` para sobrescrever mesmo assim (ainda faz backup em `.forge.bak-N`). Template fresh/greenfield não é afetado. Gate `npx-pack-gate.sh` cobre os três cenários.

## [0.1.0-rc4] — 2026-06-15

### Added
- `/forge:design-system` — slash command que é o ponto de entrada explícito para a skill `design-system-creator` (instala o Storybook, cria os assets de design system e desenvolve as UIs a partir de um handoff do Claude Design), com pré-checagem de stack (monorepo pnpm + React + CSS Modules).

## [0.1.0-rc3] — 2026-06-15

### Fixed
- `npx forge-harness init`: a mensagem final de "próximos passos" apontava comandos inexistentes (`/forge:init`, `/forge:spec-new`); agora sugere os comandos reais (`/forge:status`, `/forge:spec new`) + nota de stack-scan (`runtime:` do `FORGE.md`) para codebase existente.

## [0.1.0-rc2] — 2026-06-13

### Added
- **Instalação via `npx forge-harness init`** — bin `bin/forge.mjs` (zero-dep, cross-platform) porta o `installer/install.sh`; o template viaja no tarball, dispensando `git clone`. Interativo por padrão, ou por flags (`--target/--name/--slug/--desc/--adapters/--yes`). Novo gate `npx-pack-gate.sh` valida o conteúdo do tarball + paridade com o `install.sh` (29 gates).
- `package.json` pronto para publicação: `bin`, `files` (allowlist), `engines.node >=20`, `license: MIT`, `repository`/`homepage`/`bugs`.
- `mermaid-to-drawio` usa Graphviz (`dot`) para layout limpo do `.drawio` (fallback colunas zero-dep).
- `/forge:mermaid-to-drawio` — converte Mermaid (flowchart) em `.drawio` (mxGraph) editável visualmente no draw.io; `/forge:infra-diagram` agora emite os três formatos (`.py`, `.md`, `.drawio`).

### Fixed
- Frontmatter YAML inválido (`: `/`&`) em descrições de comando/agente quebrava o carregamento; corrigido e o contrato passa a validar command/agent/skill (com pyyaml na CI).
- `/forge:infra-diagram` — scaffold de diagram-as-code (mingrammer/diagrams) a partir do docker-compose: ícones reais, clusters por tipo, base para diagramas de infra e PCI DSS.

## [0.1.0-rc1] — 2026-06-12

Primeiro release candidate. Harness Spec-Driven Development completo (MVP1–MVP5) +
consolidação (Fase 8) + code graph com insights de arquitetura.

### Added
- **Núcleo canônico** `.forge/` como fonte única (governança, specs, rules, agents, skills).
- **Ciclo de vida SDD** com gates HITL: `spec new → clarify → requirements → design → tasks → implement → verify → archive`, loops builder→validator (`[MISS]`/`[CONFLICT]`/`[CLARIFY]`, máx. 3 iterações).
- **Multi-adapter** (8): claude, codex, gemini, qwen, cursor, kiro, forge-cli, agents-skills — gerados de `AGENTS.md` com lockfile determinista e detecção de drift.
- **Validadores deterministas** (§19): harness, spec, archive, frontmatter, graph.
- **Baseline & archive**: capabilities versionadas, spec-delta com apply determinista, ingestão de `docs/product/` legado sem perda.
- **Code graph** nativo (zero-dep, zero tokens): build, validate, query, path, **deps** (módulo→módulo + violações de camada + `--by-project`), **symbols** (símbolo-nível + herança), **C4** colorido por camada (`.md` Mermaid, agregação para módulos grandes), overview HTML interativo.
- **Eval harness opt-in** (§17.8): A/B with-skill vs baseline, grading schematizado, holdout train/test, meta-avaliação do próprio harness.
- **Story sharding + waves + deferrals** para sessões longas; `/forge:dev`, `/forge:progress`.
- **Hooks Git**: pre-commit (worktree-guard), pre-push (typecheck+test), post-merge (worktree prune + **changelog automático** em commits convencionais).
- **PoC notação MDL 2.0** (mdlmodel.com): `graph mdl` gera diagramas MDL do code graph.
- **Suíte de gates** (28) consolidada em `tests/run-all.sh`.
- **`/init-project` global** delegando ao installer do Forge.

### Notas
- Toda a camada Quality (eval/meta) é **opt-in** (`quality.evals_enabled: false` por default).
- Pendente para v0.1.0 final: teste manual em Claude Code real (contrato C10) + remoção dos wrappers deprecados.

[Unreleased]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc12...HEAD
[0.1.0-rc12]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc11...v0.1.0-rc12
[0.1.0-rc11]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc10...v0.1.0-rc11
[0.1.0-rc10]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc9...v0.1.0-rc10
[0.1.0-rc9]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc8...v0.1.0-rc9
[0.1.0-rc8]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc7...v0.1.0-rc8
[0.1.0-rc7]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc6...v0.1.0-rc7
[0.1.0-rc6]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc5...v0.1.0-rc6
[0.1.0-rc5]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc4...v0.1.0-rc5
[0.1.0-rc4]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc3...v0.1.0-rc4
[0.1.0-rc3]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc2...v0.1.0-rc3
[0.1.0-rc2]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc1...v0.1.0-rc2
[0.1.0-rc1]: https://github.com/vellus-tech/forge-harness/releases/tag/v0.1.0-rc1
