# Tasks — red-replay-graft-base

> Tasks do change `red-replay-graft-base`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (1 commit), rastreável a um REQ/seção do design, e declara o que toca.

## Wave 1 — Red observado

- [X] TASK-01 — Gate `w108` reproduz a base falsa do replay em squash com ruído posterior (rastreia: bugfix.md §1; paths: `tests/w108-red-graft-gate.sh`; depende: —)
- [X] TASK-02 — Gate `w108[4]` reproduz a recusa de falha de gate shell como `unknown` (rastreia: bugfix.md §1; paths: `tests/w108-red-graft-gate.sh`; depende: TASK-01)

## Wave 2 — Correção

- [X] TASK-03 — `deriveBase` não usa ancestry quando o commit do caso carrega a correção; revert-synthesis reverte a correção e não a última mexida; estratégia `test-graft` com fallback (rastreia: bugfix.md §2; paths: `template/.forge/scripts/lib/red-replay.mjs`; depende: TASK-01)
- [X] TASK-04 — `graft_from` no schema, no template do artefato e na persistência do resultado (rastreia: bugfix.md §2; paths: `template/.forge/schemas/red-evidence.schema.json`, `template/.forge/templates/bugfix/red-evidence.json`, `template/.forge/scripts/lib/red-evidence-ops.mjs`; depende: TASK-03)
- [X] TASK-05 — Assinatura comportamental para falha de gate shell (`FAIL [n]`) (rastreia: bugfix.md §2; paths: `template/.forge/scripts/lib/red-classify.mjs`; depende: TASK-02)
- [X] TASK-06 — `BASE_STRATEGIES` exportada no validador do artefato + validação de `graft_from` (rastreia: bugfix.md §2; paths: `template/.forge/scripts/lib/red-evidence.mjs`; depende: TASK-04)

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| bugfix.md §1 (comportamento incorreto) | TASK-01, TASK-02 |
| bugfix.md §2 (comportamento esperado) | TASK-03, TASK-04, TASK-05, TASK-06 |
| bugfix.md §3 (não regride) | TASK-03 (w107[1] ancestry, w107[4] revert-synthesis), TASK-05 (w106 tabela de assinaturas) |
| bugfix.md §5 (testes de regressão) | TASK-01, TASK-02 |
