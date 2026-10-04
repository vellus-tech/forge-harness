O impact.json do change 2026-09-estorno-parcial está válido de novo. Regenerei com `bash .forge/scripts/impact.sh --change 2026-09-estorno-parcial`, que resolve as seeds a partir de `affected_paths: src/billing/`. Agora as seeds são invoice.ts, refund.ts e tax.ts, e o impacto soma 6 arquivos (incluindo src/api/routes/refunds.ts e src/reports/daily.ts). O `impact-freshness` devolve `fresh` contra o graph.json atual.

O arquivo alterado é `<RUN>/work/.forge/specs/active/2026-09-estorno-parcial/impact.json`. Não rodei o archive, não fiz commit e não toquei em manifest, graph ou código.

Ponto de atenção: o working tree tem deleções pré-existentes em `.claude/agents`, `.claude/skills`, `.forge/agents` e `.forge/skills`, que não mexi. Vale checar antes do archive.
