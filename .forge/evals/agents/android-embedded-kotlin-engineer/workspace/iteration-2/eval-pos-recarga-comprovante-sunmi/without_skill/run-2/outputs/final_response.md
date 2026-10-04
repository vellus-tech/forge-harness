TASK-04 implementada e commitada na branch `feat/recarga-comprovante` (commit `b67e7c5`, sobre `41f8b1b`). Nenhum push.

O que mudou:

- Após `PaymentApproval.Approved`, o `CompleteRechargeUseCase` formata e imprime o comprovante via `ReceiptPrinterPort`. O conteúdo é terminal, data/hora, valor, NSU, código de autorização, UID do cartão de transporte e cartão de pagamento mascarado.
- Falha de impressão não desfaz a recarga. O `RechargeOutcome.Approved` agora carrega o recibo e o `PrintResult`, então a recarga segue aprovada e o recibo fica disponível para reimpressão. Exceção da impressora vira `COMMUNICATION_ERROR`.
- Novo módulo `hardware/printer` com `SunmiPrinterAdapter` (usa `updatePrinterState()` antes de imprimir) e o mapeamento dos códigos 1 a 7 do SDK para falhas de domínio.
- Testes escritos antes da implementação: sucesso, sem papel, exceção, cancelamento, recusa sem impressão, formatador (32 colunas, PAN mascarado, valor e data) e mapeamento de estados.

O que não foi verificado:

- Os testes não rodaram e nada foi compilado. Não há `gradlew` no repositório, não havia rede e não há `kotlinc` local. Rodar `./gradlew :core:domain:test` e `:hardware:printer:test` é o primeiro passo antes do PR.
- O adapter do Sunmi foi escrito pela documentação do vendor (`docs/vendor/sunmi-printer-sdk.md`), que não traz as assinaturas de `InnerResultCallback` nem o pacote. Pacote e callbacks precisam ser conferidos contra o AAR `printerlibrary` 1.0.23. Não testado em Sunmi P2 físico.

Pendências e decisões a conferir:

- O app não tem código-fonte, então a tela do operador (estado de impressora com ação) e a ação de reimpressão não foram feitas. O estado já sai no `PrintResult`.
- O `RechargeReceipt` ainda carrega o PAN completo em memória; o mascaramento é só na impressão. Vale mascarar na origem.
- Fuso fixo em `America/Sao_Paulo` e `SimpleDateFormat` em vez de `java.time`, por causa do Android 7.1.
- Commit sem trailer de atribuição de IA, conforme sua regra global de commits.
