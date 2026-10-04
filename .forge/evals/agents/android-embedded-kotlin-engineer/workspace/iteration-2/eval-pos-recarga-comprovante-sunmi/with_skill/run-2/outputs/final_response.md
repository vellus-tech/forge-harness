FALHA: implementação da TASK-04 feita e testada no domínio (12 testes verdes em projeto isolado), mas não commitada e o adapter Sunmi não foi compilado.

- Commit não feito: o agente `android-embedded-kotlin-engineer` só commita com `commit_policy` de orquestrador (seção 26), e o pedido de commit conflita com essa regra. As mudanças estão na árvore de trabalho da branch `feat/recarga-comprovante`, sem commit.
- Build do módulo Android não executado: o AGP e a `com.sunmi:printerlibrary` 1.0.23 não estão no cache offline. Os testes de domínio rodaram num projeto temporário (kotlin-jvm 2.0.20, JDK 17): 12 testes, 0 falhas.
- `hardware/printer/SunmiPrinterAdapter.kt` foi escrito a partir de `docs/vendor/sunmi-printer-sdk.md`, sem conferir os tipos e callbacks no AAR 1.0.23. Precisa ser validado antes do merge.
- Fora do escopo: UI e fiação em `app/`, persistência do comprovante para reimpressão, e o `RechargeReceipt` que ainda guarda o PAN completo (avaliar com PCI).

Detalhes e lista de arquivos estão em `outputs/transcript.md`.
