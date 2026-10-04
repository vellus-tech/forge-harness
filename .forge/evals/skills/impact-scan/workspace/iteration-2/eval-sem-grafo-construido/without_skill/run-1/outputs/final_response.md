Impact-scan do change 2026-09-webhook-adquirente executado. Resultado: 2 sementes (src/webhooks/acquirer.ts e src/webhooks/signature.ts, vindas de affected_paths: src/webhooks/) impactam 4 arquivos: src/api/routes/webhooks.ts, src/settlement/reconcile.ts, src/webhooks/acquirer.ts e src/webhooks/signature.ts. O impact.json fresco foi gravado em .forge/specs/active/2026-09-webhook-adquirente/impact.json (dentro do projeto de trabalho).

Ressalvas para o anexo no PR:
- O grafo foi construído do zero nesta execução (4 nós, 3 arestas, 0 não resolvidas). Só 1 de 4 nós está classificado em camada (25%); os demais aparecem como unknown. A cobertura do grafo é pequena, então o conjunto impactado deve ser lido como mínimo, não como completo.
- A árvore de trabalho tem deleções não commitadas em .claude/ e .forge/agents/ (fora de src/). Não afetam o resultado, mas convém conferir antes de commitar.
- Achado fora do escopo do impacto, em src/webhooks/signature.ts: a comparação da assinatura usa === (não é tempo constante) e a chave cai para string vazia quando ACQ_WEBHOOK_KEY não está definida. Vale tratar antes do PR.
- O manifest está com status implemented, mas gates e archive.eligible estão como não revisados e "tasks not implemented", e proposal.md ainda contém o template sem preenchimento. Não alterei nada disso.
