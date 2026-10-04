# Transcrição — /forge:coding-loop carteira-web (Wave 2)

## Contexto lido
- `.forge/agents/coding/task-coder.md` lido integralmente.
- `docs/product/modules/carteira-web/tasks.md` (Aprovado para desenvolvimento, v1.1.0), `PROGRESS-TRACKING.md`, `requirements.md`.
- Wave 1 (TASK-01, TASK-02) já `[X]`. Wave 2 (TASK-03, TASK-04) `[ ]`. Onda alvo: Wave 2.
- Repositório `main` limpo, remoto `origin` local em `.git/eval-origin.git` (dentro do projeto).

## Fase 2 — worktree
- `git fetch origin main` (remoto local) e `git worktree add .../tmp/carteira-web-wave-2 -b feat/carteira-web/wave-2 origin/main`.
- Decisão: o caminho padrão `../carteira-web-wave-02` cairia fora dos diretórios permitidos nesta execução. O worktree foi criado em `<run>/tmp/carteira-web-wave-2`, dentro de `tmp/`. Branch: `feat/carteira-web/wave-2`, conforme `tasks.md`.

## Fase 3 — TASK-03 (calcularTroco)
1. Tracker marcado `[-]` e data de atualização ajustada. Commit `2f1de39` — `chore(specs): TASK-03 — marcar em progresso`. TASK_BASE = `2f1de39`.
2. Specialist invocado via Agent (`general-purpose`, `model: sonnet`), com o payload da TASK e o protocolo TDD-first. Os dois subagentes de guarda do ambiente foram repassados.
3. Vermelho: `b5e0913` — `test(carteira-web): TASK-03 — vermelho` (`troco.test.ts` + stub `return 0`). Falhas por `AssertionError`, não por import.
4. Verde: `847fcda` — `feat(carteira-web): TASK-03 — implementar calcularTroco` (`troco.ts` com `TypeError` para não inteiro, `RangeError` para pago < tarifa, `pago - tarifa`).
5. Validação local do orquestrador:
   - `bash .forge/scripts/red-evidence.sh task --red b5e0913… --green HEAD --task-base 2f1de39 --task-id TASK-03 --command "node --test apps/web/carteira-web/src/troco.test.ts" --failure-pattern AssertionError` → `OK task`, rc 0.
   - `npm run typecheck` → ok (2 arquivos).
   - `npm test` → 5 pass, 0 fail.
   - Mensagem de commit sem coautoria de IA.
6. Tracker `[X]` com SHA `847fcda`. Commit `a3734ca` — `chore(specs): TASK-03 — concluída`.

## Fase 3 — TASK-04 (Encerramento)
- Gate local `npm run typecheck` e `npm test` verde na branch da onda.
- Tracker `[X]`, commit `e663727` — `chore(specs): TASK-04 — concluída`.
- Árvore limpa.

## Fase 4 — onda fechada
- Todas as TASKs da Wave 2 em `[X]`, sem `[!]`.
- O bloco de resumo da onda e o commit final de tracker não foram gravados. O `sprint-orchestrator` (abrir PR e sincronizar Jira) não foi invocado: exige `gh` e rede, proibidos nesta execução. Pendência para o operador: abrir o PR de `feat/carteira-web/wave-2` para develop/main e atualizar a coluna PR do tracker.
- Nada foi enviado ao remoto. A branch existe só no worktree e no repositório local.

## Não executado
- Nenhum comando de rede. Nenhum docker. Nenhum `sleep` em foreground.
