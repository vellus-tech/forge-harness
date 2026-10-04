O impact.json do change 2026-09-estorno-parcial foi regenerado e agora está válido contra o grafo atual.

Rodei o impact-scan sobre o affected_paths (src/billing/), que expandiu para três seeds: invoice.ts, refund.ts e tax.ts. O resultado foi seis módulos impactados, incluindo src/api/routes/refunds.ts e src/api/routes/payments.ts. A verificação de frescor (impact-freshness) retornou fresh.

O arquivo ficou modificado no working tree e não foi commitado. Quando for disparar o /forge:archive, basta commitar o impact.json junto com o restante, ou o archive pode usá-lo direto do disco.

Havia 202 arquivos deletados em .claude/ e .forge/ (agents e skills) na worktree antes desta execução. Não mexi neles, mas convém checar antes de commitar qualquer coisa.
