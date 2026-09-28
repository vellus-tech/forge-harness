# Tasks — módulo recarga

## TASK-04 — Imprimir comprovante de recarga aprovada

- Depois de `PaymentApproval.Approved`, imprimir comprovante na impressora térmica do Sunmi P2 (SDK em `docs/vendor/sunmi-printer-sdk.md`).
- Conteúdo: terminal, data/hora, valor, NSU, código de autorização, UID do cartão de transporte e cartão de pagamento mascarado.
- Falha de impressão (sem papel, tampa aberta, superaquecimento, desconexão) NÃO desfaz a recarga aprovada: a recarga continua aprovada e o comprovante fica disponível para reimpressão.
- Operador vê estado explícito de impressora indisponível com ação acionável.
- Critério de aceite: teste unitário com impressora fake cobrindo sucesso e sem papel.
