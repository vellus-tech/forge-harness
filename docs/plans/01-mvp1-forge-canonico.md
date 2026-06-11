# Plano MVP1 — `.forge` Canônico + Compatibilidade Claude (inclui Fase 0)

| | |
|---|---|
| **Versão** | 1.1 |
| **Data** | 2026-06-10 |
| **Status** | Aprovado para desenvolvimento |
| **Fases do doc** | Fase 0 (§22.1), Fase 1 (§22.2), Fase 2 (§22.3), Fase 3 (§22.4) |
| **MVP** | MVP1 (§23.1) + W1.4 (resolução I1 do master plan) |
| **Depende de** | — (início do projeto) |
| **Backlog (§24)** | #2, #3 (parcial), #4, #5, #6, #7, #8 |

## Objetivo

Estabelecer o `.forge/` canônico com adapter Claude de compatibilidade total, `AGENTS.md` gerado, symlinks e os primeiros adaptadores multi-agente — **sem tocar em graph, archive ou eval**. Ao final, um projeto-alvo inicializado via `/forge:init` se comporta em Claude Code exatamente como o template atual.

## Escopo

**Inclui:** Fase 0 (snapshot/contrato), árvore `.forge/` da §8 (governança + harness), migração dos 87 arquivos com reescrita de paths, `sync-adapters` (Claude + multi-agente), `/forge:init`, `/forge:doctor`, `/forge:status`, hooks Git §20.4, `staging.yml`, gitignore.patch.

**Não inclui:** lifecycle de specs (MVP2), baseline/archive (MVP3), graph (MVP4), eval/shard/waves (MVP5). `runners.yaml` entra apenas como stub (L2).

---

## Waves

### W0.1 — Workspace

- **Objetivo:** repo git funcional com a estrutura do workspace.
- **Entregáveis:**
  - `git init` em `forge-harness`; commit inicial com `docs/` em `main`; branch `develop` criada (integração); trabalho subsequente em `feature/<wave-id>`.
  - `.gitignore` do workspace (caches, `node_modules/`, outputs de teste).
  - Diretórios: `snapshot/`, `contracts/`, `template/`, `installer/`, `tools/`, `tests/`.
- **Depende de:** —
- **Gate:** `git log` tem commit inicial; estrutura de diretórios existe.

### W0.2 — Snapshot congelado

- **Objetivo:** referência imutável do comportamento atual.
- **Entregáveis:**
  - `cp -R ~/.claude/templates/project-bootstrap snapshot/project-bootstrap` + `cp ~/.claude/commands/init-project.md snapshot/`.
  - `snapshot/MANIFEST.sha256` — 88 entradas (arquivo + hash sha256).
  - `snapshot/path-inventory.txt` — inventário por arquivo das **979 ocorrências** (290 `.claude/` + 689 `docs/product`, medidas por grep em 69 arquivos): a parte `.claude/` é insumo do mapa de reescrita da W1.1; a parte `docs/product` é insumo da migração semântica nos MVPs 2–3.
  - `tests/snapshot/verify-manifest.sh` — recomputa hashes e compara com o MANIFEST.
  - Convenção: `snapshot/` é **read-only**; toda evolução acontece em `template/`.
- **Depende de:** W0.1
- **Gate:** `tests/snapshot/verify-manifest.sh` → `OK`.

### W0.3 — Contrato de compatibilidade do adapter Claude

- **Objetivo:** definir formalmente "o que não pode quebrar" (§22.1).
- **Entregáveis:**
  - `contracts/claude-adapter-contract.md`, cobrindo:
    1. Os **8 commands** continuam invocáveis (`run-spec-pipeline`, `specs-loop`, `coding-loop`, `coding-status`, `deploy-wave`, `new-adr`, `update-changelog`, `scaffold-tdd`), sob `/forge:*`, com wrappers temporários nos nomes antigos quando necessário.
    2. Os **35 agents** e **4 skills** disponíveis com mesmo comportamento.
    3. Hook `enforce-worktree-location` continua bloqueando worktrees fora do padrão (novo padrão: `.forge/worktrees/`).
    4. `doctor.sh` com mesmos exit codes e flags.
    5. Symlink `CLAUDE.md` preservado.
    6. **Teste real em Claude Code antes de remover qualquer fonte `.claude` legada.**
    7. Bloco YAML de identidade compatível no `AGENTS.md` gerado (protocolo de bootstrap de identidade dos agents não quebra).
  - `tests/snapshot/claude-contract.bats` — asserts estruturais (contagens, paths, settings.json válido, hook wired). Roda primeiro contra o snapshot; depois, o **mesmo teste** fecha a W1.2 contra a saída gerada.
- **Depende de:** W0.2
- **Gate:** contrato revisado e aprovado (**HITL**) + `claude-contract.bats` verde contra o snapshot.

### W1.0 — Esqueleto canônico (Fase 1, parte A)

- **Objetivo:** árvore `.forge/` de governança da §8 com manifestos validáveis.
- **Entregáveis (em `template/.forge/`):**
  - `FORGE.md` com o frontmatter YAML canônico da §9 (forge_version, project, sdd, runtime, integrations, quality).
  - Mapeamento documentado do YAML de identidade do AGENTS.md atual → FORGE.md: `project_name`→`project.name`, `project_display`→`project.display`, `repo_slug`→`project.repo_slug`, `default_branch`→`project.default_branch`, `jira_key`/`jira_site`→`integrations.jira`. O campo `issuer` (JWT) **não tem slot no YAML da §9** — decisão: preservado no bloco YAML compatível do `AGENTS.md` gerado (protocolo de bootstrap de identidade dos agents não quebra) e documentado em `context.md`.
  - `forge.yaml` (§10.1), `context.md` (§8.3 — stack/convenções de Milton), `constitution.md`, `README.md`, `runners.yaml` **stub** (`default_runner: claude-code`).
  - `.forge/custom/` (§8 — overrides por repo sem fork, padrão BMAD v6): diretório criado com README; regra de precedência (`custom/` sobrepõe o template) documentada no `FORGE.md` e validada pelo `doctor` (override órfão = drift).
  - `templates/FORGE.md` e `templates/AGENTS.md` (template da projeção, §7).
  - `schemas/forge.schema.json` e `schemas/adapter-capability.schema.json` (§10.6; draft 2020-12). **Nota:** a árvore da §8 lista `adapter-capability.schema.json` *e* `adapter.schema.json` — redundância do doc; consolidamos em **um** schema (`adapter-capability.schema.json`, que valida os `adapters/<a>.yaml`), decisão registrada no README de schemas.
- **Depende de:** W0.3
- **Gate:** `forge.yaml` e frontmatter do `FORGE.md` validam contra os schemas (ajv).

### W1.1 — Migração dos 87 arquivos (Fase 1, parte B) — **wave atômica, caminho crítico**

- **Objetivo:** todo o conteúdo do template em `.forge/` com paths reescritos; nunca entregar `.forge/` parcial.
- **Entregáveis:**
  - `tools/rewrite-paths.sh` — mapa determinista derivado do `path-inventory.txt`, cobrindo **apenas** as 290 refs `.claude/*`: `.claude/agents`→`.forge/agents`, `.claude/rules`→`.forge/rules`, `.claude/commands`→`.forge/commands`, `.claude/skills`→`.forge/skills`, `.claude/hooks`→`.forge/hooks`, `.claude/worktrees`→`.forge/worktrees`.
  - **Preservação de `docs/product/` (689 refs) no MVP1:** o pipeline SDD continua lendo/escrevendo em `docs/product/` — exigência do contrato de compatibilidade (W0.3/§22.1) e da regra §8.1 (`product/current/` só é alterado pelo archive, que nasce no MVP3). A migração dessas refs é semântica e faseada: MVP2/W2.1 (commands passam a escrever no change ativo, §22.5) e MVP3/W3.3 (agents reescritos contra baseline/change, §22.6).
  - `validate-frontmatter.sh` (**antecipado** da §19.4 — porte direto do LionClaw: `name` ≤ 64 chars lowercase+hífens, `description` ≤ 1024 chars sem tags XML): necessário aqui porque é gate desta wave; a W3.1 o consolida na suíte de validadores.
  - Migração por camada (ordem: rules → agents → commands → skills/hooks/scripts):
    - 27 rules → `.forge/rules/{conventions,architecture,domain,testing,frontend}/`.
    - 35 agents → `.forge/agents/{specifications,architecture,coding,review,...}/` (estrutura §8; `engineering` e `code-review` acomodados sob as categorias existentes).
    - 8 commands → `.forge/commands/{specs,coding,docs,testing}/`, **renomeados para o namespace `/forge:*`** (#7).
    - 4 skills → `.forge/skills/`; 5 hooks → `.forge/hooks/`; `doctor.sh` → `.forge/scripts/doctor.sh`.
  - Casos especiais nominais: `settings.json` (vira artefato gerado pelo adapter na W1.2, apontando `$CLAUDE_PROJECT_DIR/.forge/hooks/...`); `doctor.sh` (recalcular `ROOT` para o novo nível); `enforce-worktree-location.sh` (`.forge/worktrees/<change-id>/`, §20.4).
- **Depende de:** W1.0
- **Gate (grep-negativo + frontmatter):** `grep -r '\.claude/' template/.forge/` → **0 ocorrências** (exceto declarações em `adapters/claude.yaml`); `validate-frontmatter` passa em todos agents/skills/commands.

### W1.2 — sync-adapters + adapter Claude (Fase 2) — **caminho crítico**

- **Objetivo:** `.claude/**` vira artefato gerado; compatibilidade provada pelo contrato.
- **Entregáveis:**
  - `.forge/scripts/sync-adapters.sh` (entry bash) + `.forge/scripts/lib/sync-adapters.mjs` (Node ≥20, sem build step).
  - `.forge/adapters/claude.yaml` (declaração §10.6: generates, supports, source_hashes, smoke_tests, loss_warnings).
  - Geração: `.claude/commands/forge/*.md` (+ wrappers deprecados nos nomes antigos), `.claude/agents/**`, `.claude/skills/**`, `.claude/settings.json` (hooks → `.forge/hooks/`).
  - `AGENTS.md` na raiz como **projeção** do `FORGE.md` (subconjunto operacional, §7.2) com header de arquivo gerado (§7.4).
  - Symlinks `CLAUDE.md`/`QWEN.md`/`GEMINI.md` → `AGENTS.md`, com fallback de cópia materializada + hash.
  - `.forge/adapters/claude.lock.yaml` com sha256 de origem/destino (base do drift detection).
  - `templates/adapter/` (§8): template para declarar novos adapters (YAML §10.6 + lockfile + smoke test), consumido pela W1.4.
- **Depende de:** W1.1
- **Gate:** `tests/snapshot/claude-contract.bats` verde contra a **saída gerada** + idempotência (rodar sync 2× = diff vazio).

### W1.3 — init + doctor + infra git (parte da Fase 2 + itens v3 alocados por I4)

- **Objetivo:** instalação ponta a ponta num projeto-alvo.
- **Entregáveis:**
  - `installer/forge-init.md` — `/forge:init`: herda do `init-project.md` atual a inspeção, guarda contra sobrescrita (merge vs `--force` com backup), cópia do `template/`, symlink com `--no-symlink`, coleta e substituição de placeholders, verificação de órfãos, escaneio de stack; acrescenta: aplicação do `gitignore.patch` (§20), geração de adapters (`sync-adapters`), modos `--mode greenfield|brownfield`.
  - `/forge:doctor` — `doctor.sh` estendido com os checks da §19.1: FORGE.md existe, AGENTS.md é projeção válida, symlinks/cópias corretos, forge.yaml válido, lockfiles batem com hashes, paths `.claude` não vazam na fonte, smoke dos adapters.
  - `/forge:status` — estado do harness, specs ativas (vazio por ora), baseline e graph (I3).
  - Hooks Git da §20.4: `pre-commit` (gates rápidos, 1 linha), `pre-push` (typecheck+testes+gates), `post-merge` (progresso, changelog, remoção de worktree mergeada + prune), `worktree-guard` (porte do enforce-worktree-location para `.forge/worktrees/`), direcionadores `prepare-pr` e `promote-staging`.
  - `template/github/workflows/staging.yml` (§20.2: `on: push: branches: [staging]` + `workflow_dispatch`).
  - `/forge:dev up|sync|smoke` (§20.3) — stub funcional mínimo se houver compose no projeto-alvo; completável no MVP5.
  - `tests/fixtures/greenfield/` **mínima** (diretório vazio + reset) — as fixtures nascem quando primeiro usadas; consolidação final na W8.0.
- **Depende de:** W1.2
- **Gate (E2E):** na fixture greenfield: `init` em dir vazio sem git → estrutura completa + `doctor` exit 0; `init` em repo existente **sem** `--force` não sobrescreve nada.

### W1.4 — Adaptadores multi-agente (Fase 3; paralela a W1.3)

- **Objetivo:** agnosticismo real (§15).
- **Entregáveis:**
  - `adapters/{codex,qwen,kiro,gemini,cursor,agents-skills,forge-cli}.yaml` + geração:
    - Codex: `AGENTS.md` (já é a interface) + `.codex/skills/**` quando aplicável.
    - Qwen/Forge CLI: `.agents/commands/**`, `.agents/skills/**`, `QWEN.md → AGENTS.md`.
    - Kiro: `.kiro/steering/forge.md` — **nunca** `.kiro/specs/`.
    - Gemini: `GEMINI.md → AGENTS.md`.
    - Cursor: `.cursor/rules/forge.mdc` com `alwaysApply`.
    - Cross-tool: `.agents/skills/**` (padrão BMAD v6).
  - `loss_warnings` por adapter (ex.: "Codex recebeu AGENTS.md, mas slash commands nativos não materializados").
  - Lockfile + smoke test por adapter (§15): arquivos gerados existem, principal legível, hooks apontam paths reais, nenhum adapter contém paths de outro projeto.
- **Depende de:** W1.2
- **Gate:** smoke de cada adapter → `OK`.

---

## Definition of Done do MVP1

1. Árvore `.forge` completa instala via `/forge:init` (fixture greenfield e merge em repo existente).
2. Zero referências `.claude/` na fonte canônica (gate grep-negativo permanente).
3. `AGENTS.md` gerado + symlinks `CLAUDE.md`/`QWEN.md`/`GEMINI.md`.
4. Adapter Claude passa o **contrato da Fase 0** (`claude-contract.bats`).
5. `sync-adapters` idempotente, com lockfiles; `doctor` detecta drift.
6. Adapters Codex/Qwen/Kiro/Gemini/Cursor/agents-skills com smoke verde.

## Verificação end-to-end

1. `tests/run-mvp1.sh` (bats): verify-manifest, claude-contract (snapshot e gerado), idempotência do sync, E2E do init, smokes dos adapters.
2. **Teste manual obrigatório** (cláusula 6 do contrato): abrir Claude Code num projeto-alvo inicializado e confirmar commands (`/forge:*` e wrappers), agents, skills e o bloqueio do worktree-guard. Só após esse teste qualquer fonte `.claude` legada pode ser considerada substituída.

## Pendências/observações

- `runners.yaml` permanece stub até W5.2 (L2).
- `/forge:dev` entregue mínimo; completado na W5.1.
- **DEBT-W1.1-XML (registrada na execução):** 13 arquivos legados (10 agents, 2 commands, 1 SKILL.md) têm `description` com tags XML (`<example>`), violando o spec Agent Skills (§19.4) mas congelados pelo contrato C2/C4 (mudar description = mudar triggering). `validate-frontmatter.sh` trata como WARN por default (`--strict-xml` disponível). Sanear no MVP5 (`/forge:skill optimize` mede impacto antes/depois) ou em decisão explícita; migrar para o ledger (`/forge:defer`) quando ele existir (W5.1).
- **Ajuste W1.4b (seleção de adapters — decisão HITL 2026-06-10):** durante o teste C10 ficou claro que instalar os 8 adapters por default polui o workspace. Decisão do usuário: (1) `/forge:init` **pergunta** quais agentes o repo usa (multi-select, Claude pré-marcado por detecção) e instala **só os escolhidos**; (2) os adapters escolhidos são **versionados**. Implementado: `install.sh --adapters <lista>` (default `claude`); `sync-adapters.mjs` ganhou modos `--set <lista>` (reescreve a lista ativa em `forge.yaml` + reconcilia) e reconcile/**prune** (adapters removidos da lista têm pastas/símbolos podados, respeitando alvos compartilhados via união de dests dos ativos); `AGENTS.md` virou etapa **core** (sempre gerada, lockfile `core`) e cada adapter gera só seu symlink de raiz (`claude`→`CLAUDE.md`, `qwen`→`QWEN.md`, `gemini`→`GEMINI.md`) — antes o `claude` gerava os três (origem da poluição que o usuário viu). `forge.yaml harness.adapters` = conjunto **ativo** (≠ disponíveis, que são as declarações em `adapters/*.yaml`). `doctor` checa symlinks só dos adapters ativos e sinaliza órfãos de prune; `smoke-adapters.sh` roda só os ativos (`--all` para todos). Gate w14 reescrito para cobrir seleção, troca de conjunto e prune (8 passos). Isto realiza o "modo interativo (elicitação)" que o §14.1 já previa e que a entrega original do MVP1 implementou de forma incompleta.
- **Decisão de design (materialização dos adapters, HITL 2026-06-10):** mantida a **projeção por cópia** para os recursos de runtime do Claude Code (commands/agents/skills/settings), em vez de symlink de diretório ou stubs. Razão: a projeção transforma (namespacing `/forge:*`, wrappers deprecados, settings reescrevendo path de hooks, header de arquivo gerado), é robusta cross-tool/OS (§25) e permite drift-detection por hash. **Princípio confirmado:** o que o *modelo lê como contexto* (rules, context.md, constitution.md, FORGE.md) **não é duplicado** — vive só em `.forge/` e o `AGENTS.md` aponta para lá; o que o *runtime registra por path fixo* (slash commands, subagents, skills, hooks) é materializado em `.claude/` porque opera abaixo do prompt (instrução não os registra). Alternativas symlink+stub avaliadas e descartadas por robustez/transparência. Não reabrir sem novo gatilho.
- **Observação W1.1:** harmonização da nomenclatura de worktree (`<escopo>-<desc>` da rule git-worktree vs `<change-id>` da §20.4) adiada para o MVP2, quando change-id passa a existir; na W1.1 apenas os paths mudaram (contrato preservado). `doctor.sh` confirmado sem mudança de `ROOT` (mesma profundidade `.forge/scripts/` vs `.claude/scripts/`). `settings.json` e `README.md` raiz do `.claude/` intencionalmente não migrados (o primeiro é gerado pelo adapter na W1.2; o segundo foi substituído pelo `.forge/README.md` da W1.0).

- **Wave W1.5 (saneamento universal de agents/skills — decisões HITL 2026-06-10):** decididos (1) template **universal** — exemplos didáticos de domínio ficam, identificadores de pessoa/produto/serviço reais saem — e (2) wave única para todos os achados acionáveis de `docs/plans/revisao-agents-skills.md` (v1.1, com status por item). Aplicado nos 35 agents + 4 skills + commands relacionados: resíduos espúrios removidos; formato único `TASK-NN` (regex do task-coder corrigida; label Jira `task:TASK-NN` agora produzida pelo product-backlog); `$DOMINANT_STACK`; ddd-architect gera os 4 artefatos do context-map; §18 no frd-nfrd-validator; `nfrd-generator` completado (§4–§12); skills de design do frontend → opcionais; Git **bimodal** (standalone/orquestrado) nos 4 engineering + tools concedidas (Bash/context7; `Agent` no fullstack e no task-coder); path canônico `docs/product/adr/` (inclusive `/forge:new-adr`); discovery em `docs/discovery/`; model IDs → aliases (`sonnet`/`opus`/`haiku`); skill worktrees renumerada; `master`→`main`. **Bug de gate pré-existente corrigido:** doctor/install/w13 agora excluem `.forge/templates/` dos checks de placeholder (templates preservam `<PROJECT_*>` por design; o install não os destrói mais). Catalogado para waves donas: 689 refs `docs/product/` (MVP2/3), XML descriptions (MVP5), acoplamento de **rules**/context.md ao projeto de referência (decisão própria pendente — C3 congela as 27 rules).

## Controle de versão do documento

- Milton Silva - 2026-06-10 - Versão 1.0: plano inicial do MVP1 (inclui Fase 0).
- Milton Silva - 2026-06-10 - Versão 1.1: review crítico — 8 commands (não 7, contagem real verificada); 979 refs (290+689) com **reescrita restrita a `.claude/` no MVP1** (preserva compatibilidade §22.1/§8.1); `validate-frontmatter.sh` antecipado para a W1.1 (era gate antes de existir); adicionados `.forge/custom/`, `templates/adapter/`, fixture greenfield mínima; consolidação adapter-capability/adapter schema; decisão sobre campo `issuer`. Aprovado para desenvolvimento.
