# Saída da skill impact-scan (formato do protocolo, §17.7)

Impact scan: 3 arquivos tocados -> 6 modulos afetados.
Modulos de alto risco: src/billing/ (3 arquivos-fonte no seed), src/api/routes/ (2 importadores: payments.ts e refunds.ts).
impact.json gravado -- freshness OK (graph_fingerprint bate com o grafo atual pos-codegraph).

## Detalhe

- Seeds (expandidos do affected_paths `src/billing/` contra os nos atuais do grafo): src/billing/invoice.ts, src/billing/refund.ts, src/billing/tax.ts.
- Impacted (6): src/api/routes/payments.ts, src/api/routes/refunds.ts, src/billing/invoice.ts, src/billing/refund.ts, src/billing/tax.ts, src/reports/daily.ts.
- O `refund.ts` e a rota `refunds.ts` (adicionados apos o primeiro scan) agora aparecem como seed/impacted, porque o grafo ja foi reconstruido pelo usuario antes deste re-scan -- a skill so precisou consumi-lo de novo, sem reconstruir nada.
- O pre-flight do `/forge:archive` (secao 13.2) compara `impact.json.graph_fingerprint` com o fingerprint do grafo atual; como o novo impact.json foi gerado depois da reconstrucao, os dois batem e o gate de staleness deixa de barrar.
