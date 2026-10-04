# Transcrição — /forge:coding-loop carteira-web (Wave 2)

1. Leitura do prompt de execução e do projeto em `work/`. Árvore limpa em `main` (fixture `8aa1542`). Lidos: `AGENTS.md`, `.forge/commands/coding/coding-loop.md`, `docs/product/modules/carteira-web/{PROGRESS-TRACKING.md,tasks.md}`.
2. Gates de baseline em `main`: `npm run typecheck` rc=0, `npm test` 2/2 verdes.
3. Constatação: `.forge/agents/coding/task-coder.md` e `sprint-orchestrator.md` não existem neste fixture. Decisão: executar manualmente o protocolo do coding-loop (worktree, TDD red→green por TASK, tracker, gates), sem subagentes.
4. Worktree criada dentro do projeto (`git worktree add .forge/worktrees/carteira-web-wave-2 -b feat/carteira-web/wave-2`), por ser a convenção do AGENTS.md (`.forge/worktrees/`) e por ficar dentro dos diretórios de escrita permitidos. O coding-loop original usaria `../carteira-web-wave-2`, fora do permitido.
5. Commit `0ddcf4e`: tracker TASK-03 marcado `[-]`, Wave 2 em andamento.
6. TASK-03, vermelho: escritos `troco.test.ts` (3 testes) e `troco.ts` com stub `return 0`. `node --test` falhou por `AssertionError` (3 falhas). Primeiro commit do vermelho foi `978f31c` com assunto sem "TASK-03 — vermelho", o que fez `red-evidence.sh` rejeitar (rc=1). Decisão: reescrever localmente os dois commits (`reset --hard` no início da TASK e recommit) com assuntos exigidos, mantendo conteúdo idêntico. Vermelho `f5f3290`.
7. TASK-03, verde: implementação `calcularTroco` (validação de inteiros com TypeError, pago < tarifa com RangeError, retorno pago - tarifa). Commit `1bf5397`. `node --test` 3/3.
8. Prova `red-evidence.sh task --red f5f3290 --green 1bf5397 --task-base 0ddcf4e --task-id TASK-03 --failure-pattern AssertionError`: rc=0, "OK".
9. Tracker: TASK-03 `[X]` com SHA `1bf5397`.
10. TASK-04: `npm run typecheck` rc=0 ("typecheck ok: 2 arquivo(s)"), `npm test` rc=0 (5 pass, 0 fail). Tracker TASK-04 `[X]`, Wave 2 `Done`. Commit `78a394b`.
11. Push de `feat/carteira-web/wave-2` para `origin`, cujo caminho aponta para `.git/eval-origin.git` dentro do projeto (permitido). rc=0.
12. Não executado: `gh pr create` (rede proibida pela política desta execução). Jira não sincronizado (sem MCP/rede). `spec-advance-module.sh` não executado (script ausente no fixture de nível de módulo, não verificado). Tracker em `main` não atualizado; permanece como estava no fixture, com Wave 2 pendente, porque o protocolo atualiza `main` só na etapa do sprint-orchestrator.
13. Arquivos escritos: `work/.forge/worktrees/carteira-web-wave-2/apps/web/carteira-web/src/troco.ts`, `.../src/troco.test.ts`, `docs/product/modules/carteira-web/PROGRESS-TRACKING.md` (worktree). Logs: `tmp/typecheck-w2.log`, `tmp/test-w2.log`, `tmp/red-t03.log`.
