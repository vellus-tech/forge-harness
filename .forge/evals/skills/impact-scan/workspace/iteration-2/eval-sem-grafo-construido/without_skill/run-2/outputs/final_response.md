Análise de impacto do change 2026-09-webhook-adquirente (scale 3) rodada com `impact.sh --change`. O grafo de código foi construído de novo com `graph.sh build` (4 nós, 3 arestas, todas resolvidas) e cobre os 4 arquivos de `src/`.

Sementes (affected_paths `src/webhooks/`): `src/webhooks/acquirer.ts` e `src/webhooks/signature.ts`.

Impactados (4):
- `src/webhooks/signature.ts`: a assinatura HMAC em si, alterada diretamente.
- `src/webhooks/acquirer.ts`: importa `signature.ts`, alterado diretamente.
- `src/api/routes/webhooks.ts`: importa `acquirer.ts`, impacto transitivo.
- `src/settlement/reconcile.ts`: importa `acquirer.ts`, impacto transitivo. Vale revisar, porque a conciliação depende do webhook da adquirente.

O resultado completo está em `.forge/specs/active/2026-09-webhook-adquirente/impact.json` (schema impact/v0, fingerprint do grafo `608ab562...`).

Ressalvas para o PR:
- O grafo é pequeno (só `src/`, 4 arquivos), então a análise cobre o que existe neste checkout. Não há testes nem outros diretórios no grafo.
- A árvore de trabalho tem muitos arquivos `.claude/` apagados e não commitados (estado pré-existente, não tocado por mim). Isso não afeta o resultado de `src/`, mas convém conferir antes de abrir o PR.
- O change está com status `implemented` e gates de revisão e verificação ainda `false`. A análise de impacto foi feita, mas o change não é elegível a archive.
