# Tasks — add-portable-handoff

> Tasks ordenadas por dependência. `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada.
> Cada task é atômica (1 commit), rastreável a REQ/design, e declara o que toca.

## Wave 1 — Núcleo determinístico

- [X] TASK-01 — Template `handoff/HANDOFF.md` com 5 seções + regras fixas (rastreia: REQ-01; paths: `template/.forge/templates/handoff/HANDOFF.md`; depende: —)
- [X] TASK-02 — `handoff-gen.sh`: lê manifest/progress/deferrals/runtime/git via yaml-lite; emite seções 1-3,5 + marcador do delta; relocável por FORGE_ROOT (rastreia: REQ-02; paths: `template/.forge/scripts/handoff-gen.sh`; depende: TASK-01)
- [X] TASK-03 — Gate unitário do gerador: determinismo (2 execuções → diff vazio) + degradação sem FORGE.md (rastreia: REQ-02, NFR-02; paths: `tests/w40-handoff-gen-gate.sh`; depende: TASK-02)

## Wave 2 — Comando + plugin

- [X] TASK-04 — Comando `harness/handoff.md` (frontmatter + protocolo híbrido: script → delta narrativo) (rastreia: REQ-01; paths: `template/.forge/commands/harness/handoff.md`; depende: TASK-02)
- [X] TASK-05 — `npm run build:plugin` + bump de contagem em `docs/refer/slash-commands.md`; `plugin-sync-gate` verde (rastreia: REQ-07; paths: `plugin/forge/**`, `docs/refer/slash-commands.md`; depende: TASK-04)

## Wave 3 — Integração resume + descoberta

- [X] TASK-06 — `resume.md`: ingerir seção Delta narrativo de `.forge/HANDOFF.md` se existir (guard: ausência = intacto) (rastreia: REQ-03; paths: `template/.forge/commands/harness/resume.md`; depende: TASK-01)
- [X] TASK-07 — Ponteiro `.forge/HANDOFF.md` no `GENERATORS.agents` do `sync-adapters.mjs` (rastreia: REQ-04; paths: `template/.forge/scripts/lib/sync-adapters.mjs`; depende: —)

## Wave 4 — Gate de pre-push

- [X] TASK-08 — `check-docs-reviewed.sh`: classificador user-facing + exigência README+CHANGELOG (rastreia: REQ-06; paths: `template/.forge/hooks/git/lib/check-docs-reviewed.sh`; depende: —)
- [X] TASK-09 — Wire do helper no fim de `hooks/git/pre-push` (rastreia: REQ-06; paths: `template/.forge/hooks/git/pre-push`; depende: TASK-08)
- [X] TASK-10 — Gate `tests/w41-docs-review-gate.sh`: user-facing sem docs falha; docs-only passa; com docs passa (rastreia: REQ-06, REQ-07; paths: `tests/w41-docs-review-gate.sh`; depende: TASK-08)

## Wave 5 — Automação opt-in

- [X] TASK-11 — Hooks `session/on-session-{start,end}.sh` (rule-based) (rastreia: REQ-05; paths: `template/.forge/hooks/session/*.sh`; depende: TASK-02)
- [X] TASK-12 — Flag `handoff.auto: false` em `forge.yaml` + template (rastreia: REQ-05; paths: `forge.yaml`, `template/.forge/forge.yaml`; depende: —)
- [X] TASK-13 — `GENERATORS.claude`: emissão condicional de SessionStart/End quando `handoff.auto` (rastreia: REQ-05; paths: `template/.forge/scripts/lib/sync-adapters.mjs`; depende: TASK-11, TASK-12)
- [X] TASK-14 — Atualizar C5 (`claude-contract.bats`) p/ baseline + modo auto; smoke test `adapters/claude.yaml` (rastreia: REQ-05, REQ-07; paths: `tests/snapshot/claude-contract.bats`, `template/.forge/adapters/claude.yaml`; depende: TASK-13)

## Wave 6 — Docs (exercita o gate novo)

- [X] TASK-15 — `README.md` + `CHANGELOG.md [Unreleased]` documentando handoff + gate; contagem final de comandos (rastreia: REQ-07; paths: `README.md`, `CHANGELOG.md`; depende: TASK-05, TASK-14)

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 §2.1/2.2/2.7 | TASK-01, TASK-02, TASK-04 |
| REQ-02 §2.1 | TASK-02, TASK-03 |
| REQ-03 §2.3 | TASK-06 |
| REQ-04 §2.4 | TASK-07 |
| REQ-05 §2.5 | TASK-11, TASK-12, TASK-13, TASK-14 |
| REQ-06 §2.6 | TASK-08, TASK-09, TASK-10 |
| REQ-07 §4 | TASK-05, TASK-10, TASK-14, TASK-15 |
