# Relação de Slash Commands — Forge Harness

> Catálogo gerado a partir dos frontmatters em `template/.forge/commands/`. **47 commands** em 9 grupos.

Os `/forge:*` são entregues por um **plugin** do Claude Code (gerado de `.forge/commands/**` por `/forge:build-plugin` ou `bash .forge/scripts/build-plugin.sh`). O Claude Code (>= 2.x) reserva o namespace `:` para plugins — por isso os comandos vivem num plugin `name: forge`, não em `.claude/commands/`. O engine que eles chamam (`.forge/scripts/...`) vem do `.forge/` por projeto (instalado via `npx forge-harness init`).

## Como usar

No Claude Code digite `/` e o nome do command; argumentos vão na mesma linha. Ex.: `/forge:spec new minha-feature --type feature --scale 2`.

## Índice por grupo

- [Specs — SDD / Spec-Driven Development](#specs) — 13 commands
- [Coding — Dev loop & entrega](#coding) — 4 commands
- [Waves — Planejamento incremental](#waves) — 5 commands
- [Graph — Knowledge graph & brownfield](#graph) — 8 commands
- [Docs — Documentação & ADRs](#docs) — 8 commands
- [Harness — Manutenção do Forge](#harness) — 6 commands
- [Quality — Avaliação](#quality) — 1 commands
- [Testing — TDD](#testing) — 1 commands
- [Skills](#skills) — 1 commands


<a id="specs"></a>

## Specs — SDD / Spec-Driven Development

_Ciclo de vida de specs, pipeline ponta-a-ponta e loops de especificação._

| Command | Argumentos | Descrição |
|---|---|---|
| `/forge:analyze` | `[<change-id>]` | Análise cross-artifact do change ativo (proposal × requirements × design × tasks × constitution/rules) antes de implementar. |
| `/forge:archive` | `<change-id>` | Incorpora um change VERIFICADO ao baseline — pré-flight §13.1, dry-run, delta apply atômico (modify = substituição integral), move para archived e atualiza index/CHANGELOG. |
| `/forge:clarify` | `[<change-id>]` | Resolve ambiguidades do change ativo por elicitação — uma pergunta por vez via AskUserQuestion, sem inferir respostas. |
| `/forge:close` | `<change-id> [--reason abandoned\|rejected\|superseded]` | Encerra um change SEM atualizar o baseline — abandoned/rejected (antes de implementing) ou superseded (de qualquer estado). |
| `/forge:design` | `[<change-id>]` | Gera/refina o design técnico do change ativo com loop builder→validator (máx. |
| `/forge:implement` | `[<change-id>]` | Executa as tasks do change ativo com checkpoints — TASK a TASK, commit atômico por task, gates baratos via skill gate-runner. |
| `/forge:requirements` | `[<change-id>]` | Gera/refina os requirements do change ativo (requirements.md, bugfix.md ou refactor.md conforme o tipo) com loop builder→validator (máx. |
| `/forge:run-spec-pipeline` | `[--mode] [--strategy] [--modules] [--discovery-mode]` | Executa o pipeline completo de especificação (Discovery → PRD → FRD/NFRD → DDD → Modules → TRD → req/design/tasks por módulo) de forma autônoma, do zero até o **primeiro HITL gate**: validação huma… |
| `/forge:shard` | `[<change-id>]` | Fatia o tasks.md do change em stories auto-contidas (§17.1). |
| `/forge:spec` | `new [<change-id>] [--type feature\|bugfix\|refactor\|greenfield\|brownfield] [--scale 0..4]` | Gerencia o ciclo de vida de changes SDD — `spec new` cria um change ativo em .forge/specs/active/<change-id>/ com manifest validado por schema e templates do tipo/scale. |
| `/forge:specs-loop` | `[--skip-approved]` | Conduz loop autônomo de especificação de módulos em `docs/product/modules/<modulo>/`, guiado por `<modulo>/PROGRESS-TRACKING.md`, usando os agents requirements-writer, design-writer e tasks-writer. |
| `/forge:tasks` | `[<change-id>]` | Gera as tasks do change ativo — TASK-NN rastreáveis, ordenadas por dependência, agrupadas em waves — com gate HITL. |
| `/forge:verify` | `[<change-id>]` | Checkpoint review guiado do change implementado — confere REQ a REQ contra o código, roda os checks do FORGE.md via script, grava verification.md + verification.yaml e (após HITL) transiciona para… |


<a id="coding"></a>

## Coding — Dev loop & entrega

_Loop de codificação, status e deploy por wave; entrada para design system._

| Command | Argumentos | Descrição |
|---|---|---|
| `/forge:coding-loop` | `[modulo] [--wave] [--dry-run]` | Executa **uma onda inteira** de TASKs de um módulo via `task-coder`. |
| `/forge:coding-status` | `[modulo] [--jira-sync]` | Resumo do progresso de codificação de um ou todos os módulos deste projeto. |
| `/forge:deploy-wave` | `[modulo] [env] [--sha] [--strategy] [--approved-by]` | Promove um módulo para um ambiente (`dev` \| `stg` \| `prd`) via `deploy-orchestrator`. |
| `/forge:design-system` | `[<handoff-url>]` | Ponto de entrada explícito para a skill design-system-creator — instala o Storybook, cria os assets de design system (tokens, ícones, componentes) e desenvolve as UIs a partir de um handoff do Clau… |


<a id="waves"></a>

## Waves — Planejamento incremental

_Planejamento e execução por ondas, deferrals e progresso._

| Command | Argumentos | Descrição |
|---|---|---|
| `/forge:defer` | `[<change-id>] --reason \"<motivo>\" [--blocks \"<item,...>\"]` | Registra uma pendência no ledger do change ativo (§17.4). |
| `/forge:dev` | `up\|sync\|smoke [--env <dev\|test>]` | Ambiente de desenvolvimento local — up (sobe stack), sync (migrations + seeds), smoke (validação pré-PR). |
| `/forge:progress` | `[<change-id>]` | Mini-report curto do progresso do change ativo (§17.3). |
| `/forge:resolve-deferrals` | `[<change-id>] <deferral-id> resolve\|test [--note \"<resolução>\"]` | Marca deferrals do change como resolved (e depois tested). |
| `/forge:wave` | `plan\|open\|close\|status [<change-id>] [<wave-id>]` | Gerencia o plano de waves do change ativo — plan (deriva waves das stories), open (abre wave respeitando deps), close (fecha com gate), status (one-line). |


<a id="graph"></a>

## Graph — Knowledge graph & brownfield

_Descoberta, build, query e impacto sobre o grafo de conhecimento do repo._

| Command | Argumentos | Descrição |
|---|---|---|
| `/forge:baseline-extract` | `[--dry-run]` | Extrai capabilities-stub para um baseline vazio a partir dos boundaries do grafo de código (fluxo brownfield) — a parte determinista; requirements ficam para curadoria semântica ou para o archive d… |
| `/forge:build` | — | Constrói o grafo de código persistente (.forge/graph/graph.json) com o engine nativo zero-dep — nodes (arquivos/camadas) + edges (imports/refs) deterministas. |
| `/forge:c4` | — | Gera os diagramas C4 (Context/Container/Component em Mermaid) e o overview.html navegável — C4 + capabilities do baseline + estado dos changes ativos. |
| `/forge:discover` | — | Inventário determinístico do repositório (modo lite, §16.1) — stack, comandos run/test/build, estrutura, boundaries, mudanças e fingerprints — gravado em .forge/graph/manifest.json. |
| `/forge:impact` | `--change <id> \| --diff [<base>] \| --files a,b,c` | Análise de impacto de uma spec ou diff sobre o grafo de código — quais arquivos dependem (transitivamente) do que mudou. |
| `/forge:onboard` | `[<módulo ou capability>]` | Tour de arquitetura e domínio para um agente/humano novo no repositório — camadas, módulos, fluxos de dependência e pontos de concentração, derivados do grafo de código. |
| `/forge:query` | `<termo> \| path <de> <para>` | Consulta o grafo de código (nodes/edges/caminhos) antes de abrir arquivos crus — lookup barato para localizar módulos, dependências e caminhos de import. |
| `/forge:update` | — | Atualiza o grafo de código incrementalmente — só reprocessa se os fingerprints estruturais mudaram. |


<a id="docs"></a>

## Docs — Documentação & ADRs

_ADRs, changelog, backlog, diagramas de infra e publicação de docs._

| Command | Argumentos | Descrição |
|---|---|---|
| `/forge:adr` | `new <título-da-decisão>` | Cria um ADR (formato MADR) no baseline — .forge/product/current/adr/ — com numeração sequencial e índice atualizado. |
| `/forge:backlog` | — | Gera/sincroniza o backlog (markdown-first; Jira/GitHub Issues opcional) a partir de specs aprovadas — somente após gate humano explícito (§14.4). |
| `/forge:constitution` | — | Cria ou atualiza a constituição do projeto (.forge/constitution.md) — princípios inegociáveis que governam agentes e humanos. |
| `/forge:infra-diagram` | `[--out <dir>]` | Gera scaffold de diagrama de infraestrutura a partir do docker-compose em três formatos — infra.py (render com ícones via Graphviz, mingrammer/diagrams), infra.md (Mermaid editável) e infra.drawio… |
| `/forge:mermaid-to-drawio` | `<arquivo.md\|.mmd> [--out <arquivo.drawio>]` | Converte um diagrama Mermaid (flowchart, .md ou .mmd) em .drawio (mxGraph) editável visualmente no draw.io/diagrams.net — nós, shapes, subgraphs aninhados como containers, edges com rótulos e grupos. |
| `/forge:new-adr` | `[title]` | Cria um novo ADR no formato MADR com numeração sequencial automática em docs/product/adr/. |
| `/forge:publish-docs` | — | Publica o baseline (.forge/product/current/) em docs/product/ como publicação gerada para humanos, com lock de integridade — edições manuais em docs/product passam a ser detectadas pelo validate-ar… |
| `/forge:update-changelog` | `[component] [type] [description]` | Atualiza o CHANGELOG.md de um componente seguindo o formato Keep a Changelog. |


<a id="harness"></a>

## Harness — Manutenção do Forge

_Doctor, status, sync de adapters, build do plugin, PR e promoção de staging._

| Command | Argumentos | Descrição |
|---|---|---|
| `/forge:build-plugin` | `[--out <dir>] [--version <x>]` | Gera/atualiza o plugin Claude Code "forge" (slash commands /forge:*) a partir de .forge/commands/**. |
| `/forge:doctor` | — | Valida o harness Forge e a tooling do projeto (stacks, adapters, symlinks, drift de lockfile, placeholders orfaos). |
| `/forge:prepare-pr` | — | Prepara a descricao de um PR da branch de trabalho para develop a partir dos artefatos da mudanca. |
| `/forge:promote-staging` | — | Direcionador de promocao develop para staging (decisao humana). |
| `/forge:status` | — | Mostra o estado do harness Forge - specs ativas, baseline, graph e adapters - em formato curto. |
| `/forge:sync-adapters` | — | Regenera os adapters (.claude, AGENTS.md, symlinks) a partir da fonte canonica .forge. |


<a id="quality"></a>

## Quality — Avaliação

_Execução de evals de qualidade._

| Command | Argumentos | Descrição |
|---|---|---|
| `/forge:eval` | `harness <case-name> [--artifact requirements] [--runs N]` | Meta-avaliação do próprio harness (§18) — mede com números se um template/command/rule do Forge melhora os artefatos gerados, antes de propagá-lo ao time. |


<a id="testing"></a>

## Testing — TDD

_Scaffolding de testes._

| Command | Argumentos | Descrição |
|---|---|---|
| `/forge:scaffold-tdd` | `[test-name]` | Gera o esqueleto de um teste seguindo o ciclo Red-Green-Refactor, com estrutura AAA (Arrange-Act-Assert) e placeholder de PBT quando aplicável. |


<a id="skills"></a>

## Skills

_Ponto de entrada para skills._

| Command | Argumentos | Descrição |
|---|---|---|
| `/forge:skill` | `create\|eval\|optimize <skill-name> [--runner claude-code] [--iterations N]` | Cria, avalia (A/B) e otimiza skills do harness. |

