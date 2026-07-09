# Contrato de Compatibilidade — Adapter Claude

| | |
|---|---|
| **Versão** | 1.2 |
| **Data** | 2026-06-10 |
| **Status** | Aprovado |
| **Wave** | W0.3 (docs/plans/01-mvp1-forge-canonico.md) |
| **Referência** | §22.1 do doc de projeto (Fase 0 — contrato de compatibilidade) |
| **Baseline** | `snapshot/project-bootstrap/` @ `snapshot/MANIFEST.sha256` (verificado por `tests/snapshot/verify-manifest.sh`) |

## Propósito

Este contrato define **o que não pode quebrar** quando o template atual (`.claude/**` + `AGENTS.md`) for substituído pela fonte canônica `.forge/**` com adapter Claude gerado (`forge sync-adapters --adapter claude`, wave W1.2). O teste executável `tests/snapshot/claude-contract.bats` verifica as cláusulas estruturais: primeiro contra o snapshot (estado de referência), depois contra a saída gerada do adapter (gate da W1.2).

**Princípio:** equivalência **funcional**, não layout idêntico. Os paths internos mudam (`.claude/*` → fonte em `.forge/*` com `.claude/**` gerado); o comportamento observável pelo usuário do Claude Code não muda.

---

## Cláusulas

### C1 — Commands (8)

Os 8 commands continuam invocáveis com o mesmo comportamento:

`run-spec-pipeline`, `specs-loop`, `coding-loop`, `coding-status`, `deploy-wave`, `new-adr`, `update-changelog`, `scaffold-tdd`.

No adapter gerado, os commands são invocáveis no namespace `/forge:*` (ex.: `/forge:run-spec-pipeline`).

**Revisão (v1.3) — origem dos `/forge:*` mudou de `.claude/commands/` para um PLUGIN.** A premissa original (um `.md` em `.claude/commands/forge/<nome>.md` vira `/forge:<nome>`) **deixou de valer**: o Claude Code (>= 2.x) descontinuou o namespace via subdiretório em `.claude/commands/` — o `:` passou a ser exclusivo de plugins. Por isso o adapter gerado **não projeta mais `.claude/commands/`** (nem os wrappers de alias legados). Os `/forge:*` passam a vir de um **plugin** `forge` (manifesto `name: forge`), gerado da MESMA fonte `.forge/commands/**` por `template/.forge/scripts/lib/plugin-build.mjs` e instalado por `npx forge-harness install-plugin` (auto no `init` quando o adapter claude está ativo) ou pelo marketplace git (`.claude-plugin/marketplace.json`). A preservação do legado (os 8 commands continuam existindo e invocáveis como `/forge:*`) é mantida **no plugin**; o snapshot (source) preserva os 8 `.claude/commands/` legados apenas como referência histórica congelada. Validação: `tests/plugin-sync-gate.sh` (sincronia + cobertura sem colisão) e `claude-contract.bats` (generated mode afirma a ausência de `.claude/commands/`).

### C2 — Agents (35 + README)

Os 35 agents permanecem disponíveis com o mesmo conteúdo funcional, por categoria: specifications (15), architecture (6), review (6), engineering (4), coding (3), code-review (1). O `README.md` de índice acompanha. **Cláusula aditiva (v1.1):** como em C1, o adapter gerado pode conter agents NOVOS do Forge (contagem `>= 35` no modo generated); a cláusula garante que nada do legado se perdeu, não impede crescimento. O snapshot (source) permanece exatamente 35.

### C3 — Rules (27 + README)

As 27 rules permanecem disponíveis, por categoria: architecture (12), conventions (9), domain (3), testing (2), frontend (1). Referências internas entre rules/agents são reescritas de forma consistente (gate grep-negativo da W1.1). **Cláusula aditiva (v1.2):** como C1/C2/C4, o adapter gerado pode conter rules NOVAS do Forge (contagem `>= 27` no modo generated; primeiras adições: `conventions/conflict-handling.md` na GW.1, e as rules de governança de dados na GW.3). O snapshot (source) permanece exatamente 27, e as 27 rules legadas são exigidas em ambos os modos.

### C4 — Skills (4)

`design-system-creator`, `using-git-worktrees`, `verify-build`, `verify-diff-claims` permanecem instaladas e dispará­veis (frontmatter `name`/`description` preservado em conteúdo equivalente). **Cláusula aditiva (v1.1):** o adapter gerado pode conter skills NOVAS do Forge (contagem `>= 4` no modo generated; primeira adição: `gate-runner`, W2.2). O snapshot (source) permanece exatamente 4, e as 4 skills legadas são exigidas em ambos os modos.

### C5 — Hooks (5 scripts; 1 wired)

Os 5 scripts de hook permanecem instalados: `pre-tool-use/{check-language-policy, enforce-worktree-location, prevent-secrets-leak, validate-naming-conventions}.sh` e `pre-commit/check-dockerfile-multiarch.sh`.

**Estado de referência fiel:** o `settings.json` atual wira **apenas** `enforce-worktree-location.sh` (PreToolUse, matcher `Bash`, via `$CLAUDE_PROJECT_DIR`). O adapter gerado preserva exatamente esse wiring (apontando para o novo path em `.forge/hooks/`), sem ativar os demais hooks silenciosamente — qualquer ativação adicional é mudança de comportamento e exige decisão explícita, fora deste contrato.

O comportamento de bloqueio do worktree-guard é preservado, com o path canônico migrando de `.claude/worktrees/` para `.forge/worktrees/<change-id>/` (§20.4 do doc; fail-open mantido).

### C6 — doctor.sh

Interface preservada: flags `--report` (default), `--install` (opt-in), `-h|--help`; **exit codes**: `0` (diagnósticos OK ou nenhuma stack detectada), `1` (diagnóstico load-bearing ausente no modo report), `2` (argumento desconhecido). Detecção de stacks .NET/Node-TS/Python/Kotlin mantida. Nunca instala nada sem `--install`; nunca roda automaticamente no init.

### C7 — Symlink CLAUDE.md

`CLAUDE.md` continua resolvendo para o guia de agentes. Cadeia nova: `CLAUDE.md → AGENTS.md` (gerado de `.forge/FORGE.md`). Fallback `--no-symlink` (cópia materializada com header de arquivo gerado) preservado.

### C8 — Bloco YAML de identidade

O `AGENTS.md` gerado mantém um bloco YAML frontmatter **compatível** com os 7 campos que os agents leem hoje: `project_name`, `project_display`, `repo_slug`, `default_branch`, `jira_key`, `jira_site`, `issuer`. O protocolo de bootstrap de identidade (derivar via `gh`/MCP e persistir) continua funcionando sem alteração nos agents.

### C9 — .gitignore

O `.gitignore` instalado continua cobrindo settings locais, cache e worktrees (paths atualizados para `.forge/` conforme §20 do doc).

### C10 — Teste real obrigatório (processual)

**Nenhuma fonte `.claude` legada é removida ou considerada substituída** antes de um teste manual em Claude Code real num projeto-alvo inicializado: commands `/forge:*` visíveis e executáveis (via plugin `forge`), agents/skills carregados, worktree-guard bloqueando worktree fora do padrão, doctor com exit codes corretos. (DoD do MVP1.)

---

## Verificação

| Quando | Como | Critério |
|---|---|---|
| W0.3 (agora) | `bats tests/snapshot/claude-contract.bats` contra `snapshot/project-bootstrap/` | 100% verde — fixa o estado de referência |
| W1.2 | mesmo bats com `CLAUDE_CONTRACT_TARGET` apontando para a saída gerada do `sync-adapters` (asserts de path adaptados à equivalência funcional) | 100% verde + idempotência (sync 2× = diff vazio) |
| W8.3 | bats final + diff de hashes init-global vs `template/` taggeado | 100% verde |
| Contínuo | `tests/snapshot/verify-manifest.sh` | snapshot íntegro (`OK`) |

## Fora de escopo deste contrato

- Saída do pipeline SDD em `docs/product/` — preservada no MVP1, migra por fase (MVP2: change ativo; MVP3: baseline). Coberto pelos planos 02/03.
- Ativação de hooks adicionais, novos commands `/forge:*` (init/doctor/status etc.) — são **adições**, não compatibilidade.

## Controle de versão do documento

- Milton Silva - 2026-06-10 - Versão 1.0: contrato inicial derivado do snapshot congelado (W0.2) e da leitura de doctor.sh/settings.json/AGENTS.md.
- Milton Silva - 2026-06-11 - Versão 1.1: cláusulas C2/C4 tornadas aditivas no modo generated (>= 35 agents / >= 4 skills), espelhando C1 — o contrato garante preservação do legado, não congela crescimento do Forge. Motivada pela skill `gate-runner` (W2.2).
- Milton Silva - 2026-06-11 - Versão 1.2: cláusula C3 tornada aditiva no modo generated (>= 27 rules), espelhando C1/C2/C4. Motivada pelo guardrail de conflito de fontes (rule `conflict-handling.md`, GW.1) e pelas rules de governança de dados (GW.3).
- Milton Silva - 2026-06-16 - Versão 1.3: C1 revisada — origem dos `/forge:*` migrou de `.claude/commands/` para um **plugin** `forge`. O Claude Code (>= 2.x) descontinuou o namespace via subdiretório em `.claude/commands/` (o `:` virou exclusivo de plugins), invalidando a premissa original. O adapter gerado deixa de projetar `.claude/commands/` e os wrappers de alias; o plugin (gerado da mesma fonte `.forge/commands/**`) entrega os comandos, instalado via `npx forge-harness install-plugin` (auto no init) ou marketplace git. Snapshot (source) mantém os 8 commands legados como referência histórica.
- Milton Silva - 2026-06-10 - Gate W0.3 decidido: **Approve** (HITL via AskUserQuestion; bats 13/13 verde contra o snapshot). Status → Aprovado.
