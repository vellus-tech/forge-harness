# Tasks — forge-update-command

> `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada. Task atômica (1 commit).

## Wave 1 — Núcleo do `update` no CLI

- [X] TASK-01 — Dispatch `update` + flags `--dry-run`/`--no-backup` + HELP em `bin/forge.mjs` (rastreia: REQ-01, REQ-06; paths: `bin/forge.mjs`; depende: —)
- [X] TASK-02 — `updateHarness()`: guard `.forge` existe, overlay aditivo da maquinaria (cpSync force), adapters/*.yaml sem locks, orphan-check (rastreia: REQ-02, REQ-03; paths: `bin/forge.mjs`; depende: TASK-01)
- [X] TASK-03 — `patchForgeYaml` (só template_version) + gitignore/hooksPath + sync-adapters `--adapter all` + plugin + doctor post-check + relatório (rastreia: REQ-04, REQ-05; paths: `bin/forge.mjs`; depende: TASK-02)
- [X] TASK-04 — `--dry-run`: lista mudanças sem escrever (rastreia: REQ-06; paths: `bin/forge.mjs`; depende: TASK-02)

## Wave 2 — Slash + doctor fix

- [ ] TASK-05 — Comando `harness/upgrade.md` + rebuild plugin + contagem 50→51 em `slash-commands.md` (rastreia: REQ-07; paths: `template/.forge/commands/harness/upgrade.md`, `plugin/forge/**`, `docs/refer/slash-commands.md`; depende: TASK-03)
- [X] TASK-06 — Doctor: excluir `specs|worktrees|product|evals|custom` das varreduras de refs `.claude/` e placeholders (rastreia: REQ-08; paths: `template/.forge/scripts/doctor.sh`; depende: —)

## Wave 3 — Testes

- [ ] TASK-07 — Gate `tests/w63-forge-update-gate.sh`: preservação (a–d), órfão (e), dry-run (f), doctor (g), idempotência (rastreia: REQ-09, NFR-02; paths: `tests/w63-forge-update-gate.sh`; depende: TASK-04)
- [ ] TASK-08 — Seção `[6]` no `tests/npx-pack-gate.sh`: init+update do tarball preserva produto + atualiza maquinaria + doctor verde (rastreia: REQ-09; paths: `tests/npx-pack-gate.sh`; depende: TASK-04)

## Wave 4 — Docs

- [ ] TASK-09 — `README.md` (uso do `update`) + `CHANGELOG.md [Unreleased]` (Added update/upgrade; Fixed doctor) (rastreia: REQ-09; paths: `README.md`, `CHANGELOG.md`; depende: TASK-05, TASK-08)

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 §2.1/2.2 | TASK-01, TASK-02 |
| REQ-02/03 §2.2 | TASK-02 |
| REQ-04 §2.3 | TASK-03 |
| REQ-05 §2.2 | TASK-03 |
| REQ-06 §2.4 | TASK-01, TASK-04 |
| REQ-07 §2.5 | TASK-05 |
| REQ-08 §2.6 | TASK-06 |
| REQ-09 §4 | TASK-07, TASK-08, TASK-09 |
