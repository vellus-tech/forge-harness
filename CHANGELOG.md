# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.
O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o versionamento segue [SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

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

[Unreleased]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc8...HEAD
[0.1.0-rc8]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc7...v0.1.0-rc8
[0.1.0-rc7]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc6...v0.1.0-rc7
[0.1.0-rc6]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc5...v0.1.0-rc6
[0.1.0-rc5]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc4...v0.1.0-rc5
[0.1.0-rc4]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc3...v0.1.0-rc4
[0.1.0-rc3]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc2...v0.1.0-rc3
[0.1.0-rc2]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc1...v0.1.0-rc2
[0.1.0-rc1]: https://github.com/vellus-tech/forge-harness/releases/tag/v0.1.0-rc1
