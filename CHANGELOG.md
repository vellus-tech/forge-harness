# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.
O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o versionamento segue [SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

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

[Unreleased]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc7...HEAD
[0.1.0-rc7]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc6...v0.1.0-rc7
[0.1.0-rc6]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc5...v0.1.0-rc6
[0.1.0-rc5]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc4...v0.1.0-rc5
[0.1.0-rc4]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc3...v0.1.0-rc4
[0.1.0-rc3]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc2...v0.1.0-rc3
[0.1.0-rc2]: https://github.com/vellus-tech/forge-harness/compare/v0.1.0-rc1...v0.1.0-rc2
[0.1.0-rc1]: https://github.com/vellus-tech/forge-harness/releases/tag/v0.1.0-rc1
