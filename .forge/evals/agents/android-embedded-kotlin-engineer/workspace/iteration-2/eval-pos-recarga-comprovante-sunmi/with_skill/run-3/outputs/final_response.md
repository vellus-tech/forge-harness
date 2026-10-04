Implementei a parte de domínio da TASK-04 e o adapter Sunmi isolado, com commit local `7a2b051` na branch `feat/recarga-comprovante`. Não houve push.

O que está pronto e verificado: o caso de uso imprime o comprovante após a aprovação, com PAN mascarado, e falha de impressão não desfaz a recarga aprovada. Os 14 testes unitários de domínio e do adapter passaram num probe JVM isolado, porque o build Android completo não roda offline.

Não está pronto: a implementação real de `SunmiPrinterGateway` com `InnerPrinterManager` (bind e callbacks do SDK) não foi escrita, então o adapter ainda não está ligado à impressora; o módulo `app` não foi ligado ao caso de uso; a reimpressão e a tela de estado da impressora (critério de UX) não foram feitas; o módulo `hardware/printer` não foi compilado com Android Gradle.
