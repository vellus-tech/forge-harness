O `impact.json` do change `2026-09-estorno-parcial` está válido de novo. Rodei o `impact-scan` com `--change` sobre o grafo atual, que já contém `refund.ts` e `refunds.ts`. O resultado foi 3 seeds (`src/billing/invoice.ts`, `src/billing/refund.ts`, `src/billing/tax.ts`, expandidos a partir de `src/billing/`) e 6 arquivos impactados. A verificação de frescor devolveu `fresh`. O archive continua com você: não o disparei.

Não commitei o `impact.json` regenerado, porque o pré-flight lê o arquivo do working tree. Não reconstruí o grafo, pois ele já estava atualizado.

Um alerta fora do escopo: o `git status` do repositório mostra muitos arquivos de `.claude/` e `.forge/` (agents e skills) como deletados no working tree. Não mexi neles. Vale conferir antes de commitar ou arquivar.
