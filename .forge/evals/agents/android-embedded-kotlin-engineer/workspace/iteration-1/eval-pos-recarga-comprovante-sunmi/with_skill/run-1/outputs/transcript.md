# Transcript — eval-pos-recarga-comprovante-sunmi / with_skill / run-1

Papel assumido: `android-embedded-kotlin-engineer`, conforme
`template/.forge/agents/engineering/android-embedded-kotlin-engineer.md`.

## Passos executados, em ordem

1. Bootstrap do run: confirmado `cd` no diretório da worktree (`evals-100`, branch
   `chore/evals-skills-agentes`) e gravado `.t0` com `date +%s`.
2. Criado `work/` e executado `fixtures/pos-recarga-comprovante-sunmi/setup.sh work` — monta o
   consumidor `pos-recarga` (Sunmi P2) via `forge init` + overlay da fixture, commitado na branch
   `feat/recarga-comprovante` com árvore limpa.
3. Lida a definição do agente `android-embedded-kotlin-engineer.md` na íntegra (seções 1–30) —
   rotina obrigatória (§3), regras de Kotlin/Android (§8), integração com hardware (§10), testes
   (§21), git (§26: nunca commit/push por iniciativa própria fora de `commit_policy` orquestrada),
   regras absolutas (§30).
4. Rotina de descoberta de contexto (§3), na ordem do agente:
   - `docs/product/modules/recarga/tasks.md` → TASK-04 (imprimir comprovante após
     `PaymentApproval.Approved`; falha de impressão não desfaz a recarga; operador vê estado
     explícito; critério de aceite: teste unitário com impressora fake, sucesso e sem papel).
     `requirements.md`/`design.md` do módulo não existem nesta fixture.
   - `apps/android/pos-recarga/README.md`, `CHANGELOG.md` — stack, dispositivo homologado (Sunmi
     P2, Android 7.1.2, SDK 25), periférico existente (NFC).
   - `docs/vendor/sunmi-printer-sdk.md` — contrato do SDK `com.sunmi:printerlibrary:1.0.23`:
     `InnerPrinterManager.bindService`, `printerInit`, `printText`, `lineWrap`,
     `updatePrinterState()` (códigos 1–7), chamadas assíncronas via AIDL, largura útil 32 colunas.
   - `gradle/libs.versions.toml` — dependência `sunmi-printer` já declarada, ainda não usada.
   - `settings.gradle.kts`, `app/build.gradle.kts`, `core/domain/build.gradle.kts`,
     `hardware/nfc/build.gradle.kts` — módulos `:app`, `:core:domain`, `:hardware:nfc`; Kotlin
     2.0.20, AGP 8.5.2, minSdk 25, compileSdk/targetSdk 34.
   - Código de domínio existente: `CompleteRechargeUseCase.kt` (TODO(TASK-04) explícito no ponto de
     inserção), `RechargeReceipt.kt`, `NfcReaderPort.kt`, `SunmiNfcReaderAdapter.kt` (padrão de
     adapter já estabelecido: porta pura no domínio, adapter isolado em `hardware/<periférico>`).
   - `.forge/rules/conventions/code-style.md` (early return, aninhamento ≤3, sem literais mágicos,
     nunca engolir erro silenciosamente).
5. Decisão de design (sem necessidade de ADR — decisão local ao módulo, análoga ao padrão já
   existente para NFC): seguir exatamente o padrão de porta/adapter já usado no repositório.
   - `PrinterPort` (domínio, `core/domain`): `status(): PrinterStatus` + `print(lines): PrintResult`
     — domínio não conhece Sunmi/AIDL, só os estados físicos abstraídos.
   - `ReceiptFormatter` (domínio, puro): monta as linhas do comprovante (terminal, data/hora, valor,
     NSU, autorização, cartão de transporte, cartão de pagamento **mascarado** — nunca PAN
     completo, conforme §16 do agente) respeitando as 32 colunas úteis; quebra em rótulo+valor em
     vez de truncar, para nunca cortar silenciosamente dígitos relevantes.
   - `CompleteRechargeUseCase` passa a receber `PrinterPort`, imprime **depois** de já ter montado
     o `RechargeReceipt` de uma aprovação, e nunca desfaz a aprovação por falha de impressão —
     `RechargeOutcome.Approved` passou a carregar também o `PrintResult`, dando ao operador o
     estado explícito do periférico (e a base para reimpressão, já que o `receipt` continua
     disponível independente do resultado de impressão).
   - `SunmiPrinterAdapter` (`hardware/printer`, módulo novo, mesma forma do `hardware/nfc`):
     isola o SDK do fabricante, traduz `updatePrinterState()` para `PrinterStatus`, e envolve as
     chamadas assíncronas AIDL (`printerInit`/`printText`/`lineWrap`) com
     `suspendCancellableCoroutine`. Assumida a superfície pública usual do SDK Sunmi
     (`com.sunmi.peripheral.printer.InnerPrinterManager` / `InnerPrinterCallback` /
     `SunmiPrinterService` / `InnerResultCallback`) para os nomes de classe/pacote que o resumo do
     fabricante (`docs/vendor/sunmi-printer-sdk.md`) não detalha — mesma situação já presente no
     `SunmiNfcReaderAdapter` existente, que também referencia uma classe do SDK (`SunmiNfcClient`)
     não resolvível localmente sem a dependência real do fabricante.
6. TDD: adicionados/ajustados testes em `core/domain` (módulo JVM puro, sem dependência Android)
   **antes** de considerar a implementação fechada:
   - `CompleteRechargeUseCaseTest.kt`: teste de sucesso original preservado; adicionado teste de
     impressão com impressora pronta (compara `printedLines` capturado pelo fake com
     `ReceiptFormatter.format`), teste de recarga aprovada com impressora sem papel (recarga
     continua `Approved`, `printResult` é `Unavailable(OutOfPaper)`, nada foi impresso), e teste
     de recarga recusada (impressora nunca é chamada).
   - `ReceiptFormatterTest.kt` (novo): mascaramento do cartão de pagamento (mantém só os últimos 4
     dígitos, PAN completo nunca aparece em nenhuma linha), todas as linhas ≤32 colunas, presença
     dos campos exigidos pela TASK-04.
7. Gradle wiring: `settings.gradle.kts` (`include(":hardware:printer")`), `app/build.gradle.kts`
   (`implementation(project(":hardware:printer"))`), novo `hardware/printer/build.gradle.kts`
   (mesma forma do `hardware/nfc`: `android-library` + `kotlin-android`, `implementation(libs.sunmi.printer)`).
8. Documentação: `README.md` (periférico impressora + comportamento de falha) e `CHANGELOG.md`
   (`[Não publicado]`) do app atualizados, em português brasileiro, conforme §22 do agente.
9. Autoverificação de build/teste — **não executada**, e isso é reportado explicitamente (o agente
   proíbe inventar execução de testes, §29): não há `gradlew` commitado na fixture, o `gradle` do
   sistema exigiria resolver `com.sunmi:printerlibrary:1.0.23` e `com.sunmi:nfclibrary:2.3.1` (que
   não são coordenadas Maven reais/resolvíveis) via rede, e o run está sob regra explícita de não
   realizar nenhuma ação externa (rede, build real) — qualquer uma dessas seria simulada, não
   executada. Testes recomendados antes do merge:
   - `./gradlew :core:domain:test` (ou `gradle :core:domain:test` com wrapper gerado) — cobre
     `CompleteRechargeUseCaseTest` e `ReceiptFormatterTest`.
   - Teste manual assistido em Sunmi P2 real: recarga aprovada com papel disponível (imprime),
     recarga aprovada sem papel (recarga permanece aprovada, tela mostra impressora indisponível
     com ação de reimpressão), tampa aberta, reconexão após desconexão do serviço AIDL.
10. Commit — **não realizado**. A regra do run proíbe `git commit`/`git push`, mesmo que o pedido
    original do usuário mencione "já faz o commit na branch". A mensagem de commit sugerida (padrão
    Conventional Commits, sem coautoria de IA, conforme §26 do agente e a política global do
    usuário) está registrada abaixo para quem for aplicar o commit manualmente.
11. Registrado despacho de subagentes simulado em `outputs/subagent-dispatch-log.md` — nenhum
    subagente foi de fato spawnado (regra do run); conclusão: para esta TASK isolada, um único
    agente é suficiente, sem fan-out.
12. Gravado `outputs/changes.patch` (diff completo contra `HEAD`) e cópia dos arquivos
    criados/alterados em `outputs/changed-files/`.

## Mensagem de commit sugerida (não aplicada)

```
feat(pos-recarga): imprime comprovante na impressora termica apos recarga aprovada

Adiciona PrinterPort/PrinterStatus/PrintResult ao dominio, ReceiptFormatter para o
layout de 32 colunas com cartao de pagamento mascarado, e o adapter Sunmi em
hardware/printer. Falha de impressao nunca desfaz a recarga ja aprovada.
```

## Resumo do que foi alterado

- `core/domain/.../PrinterPort.kt` (novo): porta `PrinterPort` + `PrinterStatus` + `PrintResult`.
- `core/domain/.../ReceiptFormatter.kt` (novo): formatação pura do comprovante (32 colunas, PAN
  mascarado).
- `core/domain/.../CompleteRechargeUseCase.kt`: passa a depender de `PrinterPort`, imprime após
  aprovação sem desfazê-la em caso de falha; `RechargeOutcome.Approved` ganhou `printResult`.
- `core/domain/.../CompleteRechargeUseCaseTest.kt`: testes de impressão com sucesso e sem papel.
- `core/domain/.../ReceiptFormatterTest.kt` (novo): mascaramento e largura de 32 colunas.
- `hardware/printer/build.gradle.kts` (novo módulo) e
  `hardware/printer/.../SunmiPrinterAdapter.kt` (novo): adapter Sunmi isolado do domínio.
- `settings.gradle.kts`, `app/build.gradle.kts`: incluem/dependem do novo módulo.
- `README.md`, `CHANGELOG.md`: documentam o novo periférico e o comportamento de falha.

## Testes executados

Nenhum (ver item 9 acima — não executado por ausência de wrapper Gradle e por a resolução de
dependências do SDK do fabricante exigir rede, vedada neste run).

## Testes recomendados

- `./gradlew :core:domain:test`.
- Testes manuais assistidos em Sunmi P2 real cobrindo sucesso, sem papel, tampa aberta e
  reconexão após desconexão do serviço AIDL da impressora.

## Riscos conhecidos

- Nomes de classe/pacote do SDK Sunmi (`com.sunmi.peripheral.printer.*`) foram assumidos a partir
  da superfície pública usual do fabricante, já que `docs/vendor/sunmi-printer-sdk.md` é um
  resumo sem esses detalhes — precisa ser confirmado contra a AAR real antes do merge (mesma
  lacuna já existente no `SunmiNfcReaderAdapter`).
- `hardware/printer` não tem teste automatizado próprio (mesmo padrão de `hardware/nfc`); a
  cobertura fica no `PrinterPort` fake em `core/domain`, conforme pedido no critério de aceite da
  TASK-04.
- `RechargeReceipt.paymentCardPan` continua guardando o PAN completo em memória (comportamento
  pré-existente, fora do escopo desta TASK) — o mascaramento acontece só na formatação do
  comprovante impresso. Vale um follow-up dedicado se o PAN completo também não puder transitar em
  outros pontos do fluxo (logs, sincronização).

## Impacto operacional em campo

- Operador não perde a recarga aprovada por falha de impressora — pode reimprimir depois que o
  problema físico for resolvido, já que o `receipt` está sempre disponível junto com o
  `printResult`.
- Estado de impressora indisponível chega tipado (`PrinterStatus`) até a camada de apresentação,
  permitindo mensagem acionável específica (ex.: "sem papel" vs. "tampa aberta") em vez de erro
  genérico.

## Pendências

- Confirmar os nomes reais das classes do SDK Sunmi contra a AAR `com.sunmi:printerlibrary:1.0.23`
  antes do merge.
- Criar a tela/estado de UI que consome `RechargeOutcome.Approved.printResult` (fora do escopo da
  TASK-04, que é só o caso de uso + adapter) e a ação de reimpressão mencionada no requisito.
- Rodar `./gradlew :core:domain:test` assim que houver wrapper/rede disponível.
