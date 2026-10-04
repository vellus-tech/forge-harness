TASK-04 do módulo recarga implementada e commitada na branch `feat/recarga-comprovante` (commit local `3dac49d`, sem push).

O que mudou:

- Domínio (`core/domain`): nova porta `ReceiptPrinterPort` com `PrintResult` e `PrinterFailure`. `CompleteRechargeUseCase` imprime o comprovante depois de `PaymentApproval.Approved`. Falha de impressão ou exceção do driver não desfaz a aprovação: o resultado vem em `RechargeOutcome.Approved.print` e o comprovante fica no outcome para reimpressão.
- PAN: `RechargeReceipt` agora guarda só o PAN mascarado (últimos 4 dígitos). Antes carregava o PAN completo.
- Formatação: `toPrintLines()` gera o comprovante em 32 colunas, com terminal, data/hora (America/Sao_Paulo), valor, NSU, autorização, UID do cartão de transporte e pagamento mascarado.
- Hardware (`hardware/printer`, novo módulo): `SunmiReceiptPrinterAdapter` sobre `printerlibrary` 1.0.23. Consulta `updatePrinterState()` antes de imprimir e mapeia os códigos 1 a 7 para `PrinterFailure`. Roda em `Dispatchers.IO`.
- `settings.gradle.kts`, `app/build.gradle.kts`, README e CHANGELOG atualizados.

Testes:

- Vermelho primeiro: a suíte não compilava sem a API nova.
- Verde: 8 testes de domínio passam (sucesso, sem papel, exceção do driver, recusa sem impressão, formatação em 32 colunas, data em horário de São Paulo, máscara do PAN).
- O aceite pedido (fake cobrindo sucesso e sem papel) está coberto.

Limites desta execução:

- O build Gradle não roda offline: o AGP 8.5.2 não está no cache e a rede é proibida. Os testes de domínio foram rodados com o compilador Kotlin 2.0.20 do cache do Gradle, via script em `tmp/kt.sh`.
- O adaptador Sunmi não foi compilado contra o AAR real. Compilei contra stubs temporários dos nomes do SDK que eu conheço de memória (`InnerResultCallback`, `SunmiPrinterService`, pacote `com.sunmi.peripheral.printer`). Antes do PR, é preciso compilar com o AAR 1.0.23 de verdade e confirmar essas assinaturas.
- Não há UI do operador no repositório ainda, então o estado "impressora indisponível" com ação e a reimpressão ficam pendentes. O domínio já entrega o dado para isso.
- Acentos do comprovante dependem da codepage da impressora. Confirmar em hardware real.
- Commit feito a pedido seu, mesmo a definição do agente proibindo commit em modo standalone. Sem push e sem trailer de IA.
