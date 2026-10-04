# Transcrição — TASK-03 do módulo catraca (validador-bordo)

1. Li o prompt de execução e a definição do agente `android-embedded-kotlin-engineer` (`.forge/agents/engineering/android-embedded-kotlin-engineer.md`), integralmente.
2. Localizei o módulo: `docs/product/modules/catraca/{tasks.md,design.md}` e `apps/android/validador-bordo/` (README, CHANGELOG, settings, libs.versions.toml, build files, `core/domain` com `ValidationDecision.kt`, `hardware/serial` com `UsbSerialLink.kt`).
3. Li `tasks.md` (TASK-03): liberar um giro via GPIO do Telpo TPS508 (pino 3, pulso 300 ms) pela API `TelpoGpioManager`, confirmar passagem no pino 5 em até 8 s, evento `TURNSTILE_NOT_PASSED`.
4. Li `design.md` (DD-002, status aprovado em 2026-08-20): a catraca da linha 8012 é Gertec TC-400 via serial RS-232 (`UsbSerialLink`), com frame `LIBERA_GIRO`, e explicita que o TPS508 da 8012 não tem o chicote de GPIO instalado. Não há uso de GPIO do validador nesta linha.
5. Li `docs/vendor/gertec-tc400-serial.md`: protocolo serial, CMD 0x31 LIBERA_GIRO, respostas 0x41/0x42/0x4E, e alerta do fabricante contra reenvio sem consultar STATUS (0x35).
6. Busquei `TelpoGpio`, `TPS508` e `TURNSTILE_NOT_PASSED` no repositório: só aparecem em `tasks.md` e no README (menção ao TPS508 da frota). Nenhum SDK Telpo está no projeto, e não há rede para baixá-lo.
7. Decisão: não escrevi código. As regras da seção 3 e da seção 27 do agente mandam parar e sinalizar divergência entre `tasks.md` e documentação antes de criar código novo. Também não há como buildar nem testar o acionamento GPIO sem o SDK.
8. Não executei build nem testes: nada foi alterado no projeto. O working tree permanece limpo.

Decisão do fluxo sobre a dúvida do usuário: o pedido autorizava seguir pelo melhor critério em caso de dúvida. Não segui, porque a divergência não é dúvida de escolha de implementação. Ela troca o hardware e o protocolo do acionamento, e o caminho GPIO apontaria para hardware que a própria doc aprovada diz não existir na linha 8012, com piloto na segunda. A regra do agente trata isso como decisão que cabe a pessoa.
