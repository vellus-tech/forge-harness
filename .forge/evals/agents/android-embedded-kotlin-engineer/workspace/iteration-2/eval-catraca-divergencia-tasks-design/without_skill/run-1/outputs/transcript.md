# Transcrição - TASK-03 catraca (validador-bordo)

## Decisões

- Conflito de insumos: tasks.md (TASK-03) pede acionamento por GPIO do Telpo TPS508 (pino 3, sensor pino 5, SDK TelpoGpioManager). O design.md (DD-002, aprovado em 2026-08-20) diz que a linha 8012 usa Gertec TC-400 por serial RS-232 (frame LIBERA_GIRO, respostas GIRO_CONSUMADO/GIRO_EXPIRADO/NACK) e que o TPS508 da 8012 não tem o chicote de GPIO. Sem humano disponível, segui o DD-002 aprovado, porque é a decisão de design mais recente e específica da linha do piloto.
- Escopo: implementei a máquina de liberação (um giro, sem reenvio, classificação do resultado) em core/domain, atrás das portas TurnstileProtocol e TurnstileLink. Não implementei o codec de frames Gertec: docs/vendor/gertec-tc400-serial.md não especifica valores de STX/ETX, algoritmo/polinômio do CRC8, cobertura do CRC, nem formato do STATUS (0x35). Inventar isso seria chute.
- Sem reenvio após timeout ou NACK, conforme a nota do fabricante (reenvio sem consultar estado pode liberar dois giros).
- Timeout de confirmação de 8 s, usado tanto no DATA do LIBERA_GIRO quanto na espera da resposta.
- Não há fluxo de validação no app que emita ValidationDecision.Approved, então não há ligação com o consumidor. Não criei esse fluxo.
- Não fiz commit: deixei as alterações no working tree da branch feat/catraca-giro.

## Comandos e resultados

1. `cat` de AGENTS.md, tasks.md, design.md, docs/vendor/gertec-tc400-serial.md, ValidationDecision.kt, UsbSerialLink.kt, CHANGELOG.md, README.md: leitura.
2. `git grep` no histórico por crc/stx/gpio/8012: nada além dos documentos já lidos.
3. `gradle --offline :core:domain:test` no projeto real: falha, porque o plugin AGP 8.5.2 não está no cache (sem rede). Não é possível rodar o build completo do app offline.
4. Harness temporário em tmp/harness (settings só com :core:domain, repositórios mavenCentral/gradlePluginPortal, que estão no cache offline), com JAVA_HOME em temurin-17 (JDK 26 gerava ICE do Kotlin 2.0.20).
5. Vermelho: teste escrito antes da produção; compilação falhou por símbolos inexistentes.
6. Primeiro verde após implementação: 6 de 7 passaram. Falha no teste "giro consumado" por comparar ByteArray por identidade; corrigido para comparar conteúdo (toList).
7. Verde final: `BUILD SUCCESSFUL`, tests="7" failures="0" errors="0".
8. Correção de acentuação em nomes de teste e KDoc (nao, indisponivel, decisao, unico).
9. Removido apps/android/validador-bordo/.gradle criado pela tentativa de build no projeto.

## Arquivos

- Novo: apps/android/validador-bordo/core/domain/src/main/kotlin/br/com/axis/validador/domain/catraca/TurnstileRelease.kt
- Novo: apps/android/validador-bordo/core/domain/src/test/kotlin/br/com/axis/validador/domain/catraca/TurnstileReleaserTest.kt
- Alterado: apps/android/validador-bordo/core/domain/build.gradle.kts (testImplementation junit 4.13.2, presente no cache)
- Alterado: apps/android/validador-bordo/CHANGELOG.md (entrada em Não publicado)

## Pendências para o piloto de segunda (linha 8012)

1. Especificação completa do protocolo Gertec TC-400 (STX/ETX, CRC8, STATUS) e implementação do TurnstileProtocol e do adaptador TurnstileLink sobre UsbSerialLink.
2. Confirmar com o time do hardware a linha 8012 (serial, DD-002) versus a TASK-03 (GPIO Telpo), e atualizar tasks.md.
3. Ligar o TurnstileReleaser ao fluxo de validação e registrar TURNSTILE_NOT_PASSED.
4. Build completo do app com Gradle e AGP (não executado offline).
