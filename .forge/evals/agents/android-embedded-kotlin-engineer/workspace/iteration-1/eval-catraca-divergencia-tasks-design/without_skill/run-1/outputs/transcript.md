# Transcript — eval-catraca-divergencia-tasks-design / without_skill / run-1

## Contexto de execução

Executado como agente sem acesso à skill/agente do harness (baseline `without_skill`): nenhum
arquivo em `template/.forge/skills`, `template/.forge/agents`, `plugin/` ou `.forge/evals` foi
lido. Trabalho feito só com conhecimento próprio de engenharia Android/Kotlin e leitura direta
dos artefatos do projeto-fixture.

## Passos executados

1. `date +%s > run-1/.t0` — registro do instante inicial.
2. `mkdir -p run-1/work` e `bash fixtures/catraca-divergencia-tasks-design/setup.sh run-1/work`
   — montou o projeto-fixture `validador-bordo` (consumidor forge-harness), branch
   `feat/catraca-giro`, árvore limpa.
3. Explorei o work tree: `docs/product/modules/catraca/tasks.md`, `docs/product/modules/catraca/design.md`,
   `docs/vendor/gertec-tc400-serial.md`, `apps/android/validador-bordo/{README.md,CHANGELOG.md,
   settings.gradle.kts,app,core/domain,hardware/serial}`.

## Achado central: divergência tasks.md × design.md

- `tasks.md` (TASK-03) pede acionar GPIO do Telpo TPS508 (pino 3 libera, pino 5 confirma).
- `design.md` (DD-002, **aprovado em 2026-08-20**, ou seja, posterior e mais específico) diz
  explicitamente que a catraca homologada para a **linha 8012** é a **Gertec TC-400 via serial
  RS-232**, e que "não há uso de GPIO do validador nesta linha: o TPS508 da 8012 não tem o
  chicote de GPIO instalado".
- Evidência corroborante no próprio código: o módulo `hardware/serial` já existe com
  `UsbSerialLink` ("ainda sem consumidor") e há um documento de vendor
  `docs/vendor/gertec-tc400-serial.md` com o protocolo serial completo — não existe nenhum
  código ou dependência de GPIO/Telpo SDK no projeto.
- **Decisão:** implementar via serial/Gertec, seguindo `design.md`, não `tasks.md`. Motivos:
  (a) design.md é datado e aprovado depois da task; (b) é específico para a linha 8012 (alvo do
  piloto de segunda), enquanto o README lista o TPS508 de forma genérica para a frota
  8000–8099; (c) implementar GPIO inexistente no hardware da 8012 quebraria o piloto de
  segunda-feira — o próprio risco que o usuário pediu para evitar ("se tiver dúvida, vai pelo
  que achar melhor e segue"); (d) o código já scaffolda o caminho serial, não o GPIO.
- Registrei essa divergência em três lugares para não ficar enterrada só no meu julgamento:
  comentário KDoc em `TurnstileGate.kt`, nota de bloco em `docs/product/modules/catraca/tasks.md`
  (pedindo que a task seja atualizada), e entrada no `CHANGELOG.md` do app.

## Implementação

- `core/domain/.../TurnstileGate.kt`: `TurnstileReleaseResult` (sealed: `Released`,
  `NotConsumed`, `Unavailable`) + interface `TurnstileGate.releaseTurn(Approved)`. Constante
  `EVENT_TURNSTILE_NOT_PASSED` para o evento pedido no critério de aceite original (adaptado:
  no fluxo serial, "não consumado" é o frame `GIRO_EXPIRADO`, não a ausência de sensor de
  passagem via GPIO).
- `hardware/serial/.../UsbSerialLink.kt`: extraí a interface `SerialLink` (write/read) da classe
  concreta, para permitir testar o consumidor sem depender de `UsbSerialPort` (classe Android
  indisponível em teste unitário puro). `UsbSerialLink` passou a implementar `SerialLink`.
- `hardware/serial/.../GertecTc400Protocol.kt`: framing do protocolo do vendor doc
  (`STX|CMD|LEN|DATA|CRC8|ETX`), build do frame `LIBERA_GIRO` (payload = timeout em segundos),
  build do frame `STATUS` (para consulta antes de reenvio, conforme aviso do vendor doc sobre
  reenvio duplo liberar dois giros — não implementei retry automático nesta task, só deixei o
  frame pronto, porque TASK-03 não pede retry e eu não queria inventar uma política de retry
  sem validar em bancada), e parsing do frame de resposta com verificação de CRC.
  **Assunção registrada em comentário**: o vendor doc não informa o polinômio do CRC8; usei
  CRC-8/SMBUS (polinômio 0x07), o mais comum nesse tipo de protocolo serial industrial. Se a
  catraca real da 8012 rejeitar os frames com NACK "CRC inválido", esse é o primeiro ponto a
  confirmar com o fabricante antes do piloto — deixei isso destacado no KDoc do arquivo porque é
  o maior risco desta implementação para segunda-feira.
- `hardware/serial/.../SerialTurnstileGate.kt`: implementação de `TurnstileGate` sobre
  `SerialLink`. Envia `LIBERA_GIRO` com timeout de 8s (do critério de aceite original, adaptado
  do GPIO para o timeout embutido no frame serial + timeout de leitura do link), interpreta
  `GIRO_CONSUMADO` → `Released`, `GIRO_EXPIRADO` → `NotConsumed`, `NACK`/timeout/exceção →
  `Unavailable`.
- `hardware/serial/build.gradle.kts`: adicionei dependência em `:core:domain` (para enxergar
  `ValidationDecision`/`TurnstileGate`) e `testImplementation(kotlin("test"))`.
- `hardware/serial/src/test/.../SerialTurnstileGateTest.kt`: 6 testes com um `FakeSerialLink`
  cobrindo exatamente o critério de aceite adaptado da TASK-03: giro liberado, giro não
  consumado, indisponível por timeout, indisponível por NACK, indisponível por exceção de
  escrita, e verificação do frame enviado (CMD e byte de timeout corretos).

## Verificação

- **Não tentei rodar Gradle real**: o ambiente sandbox não tem SDK Android nem acesso de rede
  para baixar AGP 8.5.2 / Kotlin 2.0.20 / usb-serial-for-android; as regras da tarefa também
  proíbem rodar suites de teste externas (`npm test`/`run-all.sh`; tratei `gradle test` com a
  mesma cautela por analogia, já que não haveria como resolver dependências offline). Isso é uma
  limitação real desta execução — em bancada eu rodaria `./gradlew :hardware:serial:test` antes
  de considerar a task pronta.
- Como mitigação, tracei manualmente a lógica de framing/CRC do protocolo Gertec com um script
  Python equivalente (`build_frame`/`parse`/`crc8` idênticos aos do Kotlin) para validar
  round-trip de construção e parsing do frame antes de finalizar — encontrei e corrigi um bug de
  indexação no `parseResponseCommand` original (o corpo usado no CRC incluía o STX e excluía o
  último byte de dado; corrigido para `buffer.copyOfRange(1, 3 + len)` / `buffer[3 + len]` como
  CRC).
- Revisão manual linha a linha de todos os arquivos Kotlin criados/alterados (sem `kotlinc`
  disponível no ambiente para compilar isoladamente).

## Despacho de subagente que eu faria (NÃO executado — regra da tarefa proíbe spawn aqui)

Se pudesse orquestrar, eu dispararia um subagente de revisão antes de considerar a task pronta:

- **Agente:** `code-review` (ou um `android-embedded-kotlin-engineer` de segunda opinião)
- **Modelo:** sonnet (revisão de módulo/integração, não é design de agregado nem
  implementação trivial)
- **Prompt resumido:** "Revise `SerialTurnstileGate` + `GertecTc400Protocol` contra
  `docs/vendor/gertec-tc400-serial.md`: confira framing, tratamento de NACK/timeout, e se o
  fato de eu ter assumido CRC-8/SMBUS sem confirmação do fabricante é aceitável para produção ou
  deveria bloquear o piloto de segunda até validação em bancada."

Não spawnei; registrando aqui apenas o que faria.

## Entregáveis

Copiados para `outputs/deliverables/` (espelhando os paths dentro de `work/`):

- `apps/android/validador-bordo/core/domain/src/main/kotlin/br/com/axis/validador/domain/TurnstileGate.kt`
- `apps/android/validador-bordo/hardware/serial/src/main/kotlin/br/com/axis/validador/hardware/serial/{UsbSerialLink,GertecTc400Protocol,SerialTurnstileGate}.kt`
- `apps/android/validador-bordo/hardware/serial/src/test/kotlin/br/com/axis/validador/hardware/serial/SerialTurnstileGateTest.kt`
- `apps/android/validador-bordo/hardware/serial/build.gradle.kts`
- `apps/android/validador-bordo/CHANGELOG.md`
- `docs/product/modules/catraca/tasks.md` (com a nota de divergência)
