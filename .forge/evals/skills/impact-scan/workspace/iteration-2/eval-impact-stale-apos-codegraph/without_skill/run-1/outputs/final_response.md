O impact.json do change 2026-09-estorno-parcial foi regenerado e o pré-flight do archive agora dá "fresh".

O que causou: o impact.json era de um grafo anterior (fingerprint 511fd603...). Depois dos commits de estorno parcial o grafo mudou, e a comparação de fingerprint acusou stale.

O que fiz: rodei `graph.sh build` e depois `impact.sh --change 2026-09-estorno-parcial`. O affected_paths src/billing/ expande para invoice.ts, refund.ts e tax.ts; o impacto agora inclui também src/api/routes/refunds.ts, src/billing/refund.ts, payments.ts e daily.ts.

Pendências e observações:
- Não commitei: graph.json e impact.json estão modificados no working tree.
- 7 summaries do grafo estão marcados como stale. Não regenerei porque dependem de LLM; isso não afeta o fingerprint.
- No working tree há deleções pré-existentes em .claude/agents/ e .forge/agents/. Não toquei nelas, mas vale checar antes de commitar.
- O archive não foi disparado, como combinado.
