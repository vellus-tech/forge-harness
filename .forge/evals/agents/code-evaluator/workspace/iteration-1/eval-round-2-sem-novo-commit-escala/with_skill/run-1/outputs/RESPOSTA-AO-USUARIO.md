Não mergeie. Veredito do round 2: **REJECTED** (exit_code 1).

O `fullstack-software-engineer` relatou (`ci/code-evaluator/fse-round-1.md`) ter corrigido o SEC-001 e feito
push na branch `feat/tarifa/recarga-cartao`, mas isso não aconteceu de fato:

- `git rev-parse HEAD` no round 2 é idêntico ao `final_diff_sha` do round 1 (`be83a62...`) — nenhum commit
  novo existe no branch.
- `git log --all --grep="SEC-001"` não encontra nenhum commit com a mensagem alegada.
- O repositório não tem remote configurado (`git remote -v` vazio), então o push relatado não poderia ter
  ocorrido neste estado.
- Lendo `services/tarifa/tarifa/recarga.py:10` diretamente, o `logger.info` ainda grava `numero_cartao`
  inteiro — o SEC-001 (PCI DSS 3.4, PAN completo em log) continua aberto, sem qualquer alteração no código.

Pelo protocolo do `code-evaluator` (gate de anti-loop por fingerprint + anti-padrão "não re-rodar reviewers
se `diff_sha` não mudou"), isso é tratado como loop infinito: escalado direto para REJECTED, sem rodar de
novo os 5 reviewers sobre o diff idêntico, e sem despachar um round 3 automático do FSE.

Ação recomendada: peça ao FSE para reconciliar a branch (confirmar se o commit/push de fato saiu de outro
lugar e não chegou aqui, ou refazer a correção) antes de reabrir um novo round de avaliação.

Entregáveis: `outputs/ci/code-evaluator/round-2.json` (JSON estruturado), `outputs/code-evaluator-pr-comment.md`
(comentário de PR), `outputs/dispatch-log.md` (despacho de subagentes simulado — nenhum foi de fato invocado,
por regra do harness deste eval).
