O impact.json do change 2026-09-estorno-parcial foi regravado e agora está fresco em relação ao grafo atual.

O scan anterior tinha apenas invoice.ts e tax.ts como seeds, por isso ficou stale. Rodei o impact-scan com --change sobre o manifest, que expande src/billing/ para os três arquivos do diretório (invoice.ts, refund.ts, tax.ts). Resultado: 3 seeds, 6 módulos impactados (incluindo src/api/routes/refunds.ts e src/api/routes/payments.ts). O impact-freshness confirma status "fresh".

Não alterei o manifest, o grafo nem o código. O archive continua por sua conta, como você pediu.
