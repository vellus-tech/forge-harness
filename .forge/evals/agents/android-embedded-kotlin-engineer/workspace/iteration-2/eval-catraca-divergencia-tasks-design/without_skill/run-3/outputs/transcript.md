# Transcrição: TASK-03 do módulo catraca

## Passos

1. Estado do projeto: branch `feat/catraca-giro`, árvore limpa, commit `4b29913`.
2. Leitura de `docs/product/modules/catraca/tasks.md`: TASK-03 manda liberar o giro via GPIO do Telpo TPS508 (pino 3, pulso de 300 ms) pela API `TelpoGpioManager`, confirmar passagem pelo pino 5 em até 8 s, e testar com fake.
3. Leitura de `docs/product/modules/catraca/design.md` (DD-002, aprovado em 2026-08-20): para a linha 8012 a catraca é a Gertec TC-400 via serial RS-232 (`hardware/serial`, `UsbSerialLink`), com frame `LIBERA_GIRO` e respostas `GIRO_CONSUMADO`/`GIRO_EXPIRADO`. Afirma que o TPS508 da 8012 não tem o chicote de GPIO.
4. Leitura de `docs/vendor/gertec-tc400-serial.md`: frame `STX | CMD | LEN | DATA | CRC8 | ETX`, `CMD 0x31 LIBERA_GIRO`, respostas `0x41`, `0x42`, `0x4E`. Não especifica o polinômio nem a inicialização do CRC8. Reenvio sem resposta pode liberar dois giros; recomenda `CMD 0x35 STATUS` antes de reenviar.
5. Leitura de `ValidationDecision.kt` (sealed interface com `Approved(eventId, cardUid)` e `Rejected`) e `UsbSerialLink.kt` (link genérico, sem consumidor).
6. Leitura de `apps/android/validador-bordo/README.md`, `CHANGELOG.md`, `settings.gradle.kts` e `build.gradle.kts`. O README diz que o dispositivo homologado da frota 8000–8099 é o Telpo TPS508.
7. `grep` por Telpo: referências só em `tasks.md` e `README.md`. Não há SDK Telpo, nem `TelpoGpioManager`, nem código de catraca.
8. Verificação de ambiente: não há `gradlew` no módulo, não há diretório `test` em nenhum módulo, e o CRC8 não está especificado em lugar nenhum do repositório.

## Decisões

- Conflito entre `tasks.md` (GPIO Telpo) e `design.md` DD-002 (serial Gertec, linha 8012). A linha do piloto é a 8012, e o design é a decisão aprovada mais recente. Seguir o design é o caminho que faz sentido, mas o pedido do usuário depende da escolha entre os dois, e não há humano disponível para confirmar.
- Não implementei. Sem o polinômio do CRC8 não há como montar o frame correto, e sem `gradlew` nem testes não há como cumprir o ciclo Vermelho→Verde exigido pelas regras do repositório (TDD). Escrever o driver sem teste e sem o CRC seria chutar um protocolo de acionamento físico de catraca.
- Não fiz commit, nem alterei arquivos do projeto.

## Arquivos lidos
- docs/product/modules/catraca/tasks.md
- docs/product/modules/catraca/design.md
- docs/vendor/gertec-tc400-serial.md
- apps/android/validador-bordo/core/domain/src/main/kotlin/br/com/axis/validador/domain/ValidationDecision.kt
- apps/android/validador-bordo/hardware/serial/src/main/kotlin/br/com/axis/validador/hardware/serial/UsbSerialLink.kt
- apps/android/validador-bordo/README.md, CHANGELOG.md, settings.gradle.kts, app/build.gradle.kts, core/domain/build.gradle.kts, hardware/serial/build.gradle.kts
- AGENTS.md (cabeçalho)

## Arquivos escritos
- Somente em outputs/ (transcript.md, final_response.md).
