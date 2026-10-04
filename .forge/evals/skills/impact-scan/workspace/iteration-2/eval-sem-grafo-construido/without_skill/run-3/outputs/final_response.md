Impact-scan do change `2026-09-webhook-adquirente` rodado (scale 3, grafo de código construído localmente com `graph.sh build`).

Seeds (affected_paths `src/webhooks/`): `src/webhooks/acquirer.ts` e `src/webhooks/signature.ts`.

Impactados (4): `src/webhooks/signature.ts`, `src/webhooks/acquirer.ts`, `src/api/routes/webhooks.ts` e `src/settlement/reconcile.ts`. As dependências diretas são `webhooks.ts` e `reconcile.ts` importando `acquirer.ts`, que importa `signature.ts`.

Resultado gravado em `.forge/specs/active/2026-09-webhook-adquirente/impact.json`, dentro do projeto de trabalho.

Ressalvas para o PR:
- O grafo tem só 4 nós e 3 arestas, com cobertura de layer de 25%. O impacto é fiel ao grafo, mas o escopo real pode ser maior se houver código fora do que foi indexado.
- Achado de segurança em `src/webhooks/signature.ts`: a comparação da assinatura usa `===`, que não é em tempo constante, e a chave `ACQ_WEBHOOK_KEY` cai em string vazia se não estiver definida. Vale corrigir antes do PR (comparação em tempo constante e falha se a chave faltar).
- Inconsistência no manifest: status `implemented`, mas `tasks not implemented` e todos os gates `false`. Antes de anexar, confirme o estado real do change.
