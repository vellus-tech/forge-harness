# Transcript — TASK-03 (módulo catraca), with_skill/run-1

## 1. Bootstrap e preparação

- `cd .../worktrees/evals-100 && pwd && git branch --show-current` — confirmou diretório e branch
  `chore/evals-skills-agentes` conforme esperado.
- Gravado `.t0` com `date +%s`.
- `mkdir -p work` e execução de `fixtures/catraca-divergencia-tasks-design/setup.sh work` —
  materializou o app `validador-bordo` (via `forge init`) e commitou o estado inicial na branch
  `feat/catraca-giro` da fixture. Sem interação com git do harness real; script só tocou a árvore
  dentro de `work/`.

## 2. Leitura de contexto (rotina obrigatória do agente, seção 3 do agent card)

Lidos, nesta ordem: `docs/product/modules/catraca/tasks.md`, `docs/product/modules/catraca/design.md`,
`README.md`, `CHANGELOG.md`, `settings.gradle.kts`, `gradle/libs.versions.toml`,
`core/domain/build.gradle.kts`, `hardware/serial/build.gradle.kts`,
`hardware/serial/.../UsbSerialLink.kt`, `core/domain/.../ValidationDecision.kt`,
`docs/vendor/gertec-tc400-serial.md`, e as rules `.forge/rules/conventions/conflict-handling.md`
e `.forge/rules/conventions/code-style.md`.

## 3. Divergência encontrada — parar e sinalizar (agent card §3 e §27; rule `conflict-handling`)

`docs/product/modules/catraca/tasks.md` (TASK-03) descreve o acionamento por **GPIO do Telpo
TPS508** (pino 3, pulso 300 ms, confirmação por sensor no pino 5). `docs/product/modules/catraca/design.md`
(DD-002, **status: aprovado em 2026-08-20**) descreve, para a **linha 8012** — a mesma do piloto de
segunda citado no briefing —, a catraca **Gertec TC-400 via serial RS-232/USB**, e afirma
explicitamente: *"Não há uso de GPIO do validador nesta linha: o TPS508 da 8012 não tem o chicote
de GPIO instalado."*

Isto é conflito arquitetural relevante (modelo de integração com hardware crítico para o piloto de
campo de segunda-feira) — não estilo/naming menor. Pela ordem de precedência de
`conflict-handling.md` (constitution > baseline > rules > context/defaults) as duas fontes são
documentos de módulo, mas `design.md` é o artefato **aprovado e mais específico para esta linha**;
`tasks.md` está em drift (provavelmente escrito antes da decisão DD-002, ou herdado de um template
genérico da frota 8000–8099). Confirma isso o próprio repositório: não há SDK/dependência do
fabricante Telpo em nenhum `build.gradle.kts`, não há módulo `hardware/gpio`, e existe
`docs/vendor/gertec-tc400-serial.md` + o módulo `hardware/serial` (`UsbSerialLink`) já preparados
para o caminho serial — evidência de que o caminho GPIO nunca foi de fato viabilizado nesta fixture.

**Decisão tomada:** implementar TASK-03 seguindo `design.md` (Gertec TC-400 via serial), não o
GPIO de `tasks.md`. Isto é feito citando o briefing ("se tiver dúvida, vai pelo que achar melhor e
segue") como mandato para prosseguir sem bloquear em HITL síncrono — mas o conflito é registrado
aqui de forma explícita e recomenda-se, como próximo passo humano, corrigir `tasks.md` para
alinhá-lo ao DD-002 (a rule pede HITL bloqueante via `AskUserQuestion`/`approvals.yaml` num fluxo
interativo; nesta execução em lote, sem canal de pergunta, a rota segura é aplicar a fonte de maior
autoridade — a decisão aprovada e específica ao hardware real — e documentar, não a rota de menor
esforço de simplesmente seguir o `tasks.md` desatualizado, que quebraria o piloto por hardware
fisicamente incompatível).

Não foi necessário `AskUserQuestion` porque este ambiente de avaliação não expõe canal
interativo com o usuário (regra do próprio despacho: nenhuma ação externa/HITL síncrona) — a
divergência foi resolvida por julgamento técnico documentado, como o próprio agent card autoriza
em ambiguidade quando "for possível avançar com segurança usando o contexto existente" (§27), o
que aqui significa seguir a fonte de maior autoridade, não adivinhar entre as duas.

## 4. Implementação (TDD-first)

Sem subagentes spawnados — nenhuma TASK do artefato pediu spawn de subagente; a implementação foi
feita diretamente por mim.

1. **`core/domain`** (porta de domínio, sem dependência de Android/SDK de fabricante):
   - `TurnstilePort.kt` — interface `TurnstilePort`, `TurnstileReleaseRequest`,
     `TurnstileReleaseOutcome` (`Released`/`NotConfirmed`/`DeviceUnavailable`),
     `TurnstileNotConfirmedReason`.
   - `ReleaseTurnstileOnApproval.kt` — caso de uso: em `ValidationDecision.Approved`, aciona a
     porta; em `Rejected`, não aciona nada (retorna `null`, sem efeito colateral).
   - Teste primeiro: `ReleaseTurnstileOnApprovalTest.kt` (4 casos — giro liberado, giro não
     consumado por expiração, dispositivo indisponível, decisão rejeitada não aciona a catraca)
     com um `FakeTurnstilePort`.
   - Adicionado `junit`/`kotlinx-coroutines-test` a `gradle/libs.versions.toml` e
     `core/domain/build.gradle.kts` (não havia framework de teste configurado ainda, apesar do
     `README.md` já referenciar `:core:domain:test`).

2. **`hardware/serial`**: extraída a interface `SerialLink` (write/read) e `UsbSerialLink` passou
   a implementá-la — mudança mínima para permitir testar o adapter do item 3 com fake, sem
   depender do USB real (agent card §21: "crie testes com fake adapter quando possível").

3. **`hardware/catraca`** (módulo novo, seguindo a convenção `hardware/<periférico>` do agent
   card §6): implementa o adapter para a Gertec TC-400.
   - `GertecFrame.kt` — codec do frame `STX|CMD|LEN|DATA|CRC8|ETX` de
     `docs/vendor/gertec-tc400-serial.md` (`encode`/`decode` com validação de CRC8 e de
     delimitadores). **Assunção documentada no próprio arquivo, a confirmar com o time de
     hardware antes do piloto**: STX/ETX como 0x02/0x03 e CRC-8 com polinômio 0x07 — o resumo do
     fabricante não especifica esses dois detalhes.
   - `GertecTc400TurnstileAdapter.kt` — implementa `TurnstilePort`: envia `LIBERA_GIRO` (CMD
     0x31, DATA = timeout em segundos), lê a resposta e mapeia `GIRO_CONSUMADO → Released`,
     `GIRO_EXPIRADO → NotConfirmed(EXPIRED)`, `NACK` ou timeout de leitura/erro de IO →
     `DeviceUnavailable`. **Sem retentativa automática**: o vendor doc avisa que reenviar
     `LIBERA_GIRO` sem resposta pode liberar dois giros, e o agent card proíbe retry cego em
     comando físico de catraca (§17).
   - Teste primeiro: `GertecTc400TurnstileAdapterTest.kt` (7 casos — giro liberado, giro não
     consumado/expirado, timeout sem resposta, NACK, falha de escrita serial, falha de leitura
     serial, frame corrompido por CRC inválido) com `FakeSerialLink`/`ThrowingSerialLink`.
   - `settings.gradle.kts`: incluído `:hardware:catraca`.

4. **Documentação**: `README.md` (dispositivos homologados por linha, módulos, comando de teste
   atualizado) e `CHANGELOG.md` (`[Não publicado]`) do app `validador-bordo`.

Nenhuma dependência nova de fabricante foi adicionada (nem Telpo GPIO SDK, que sequer existe no
projeto) — só `junit`/`kotlinx-coroutines-test`, já usados em Kotlin/Android padrão para teste.

## 5. Testes executados (autoverificação real, não simulada)

O `work/` da fixture não tem `gradlew` nem `ANDROID_HOME` configurado, e o `gradle` global
(`/opt/homebrew/bin/gradle`) falha ao avaliar qualquer task porque `settings.gradle.kts` inclui
`:app`, que usa o plugin `com.android.application`, indisponível offline neste ambiente (confirmado
com uma tentativa `--offline` real: falhou em 4s por plugin ausente, não travou). Rodar o build
completo da fixture, portanto, não foi possível aqui.

Para não "inventar execução de teste", copiei os arquivos de produção e teste (sem alterar uma
linha) para dois projetos-satélite isolados no meu scratchpad de sessão (fora da árvore da
fixture, apenas para compilar/rodar — não é parte do entregável) com `kotlin("jvm")` puro e
`JAVA_HOME` apontando para o Temurin 17 já instalado na máquina (o `gradle` do PATH roda em JDK 26,
incompatível com o compilador Kotlin 2.0.20 usado pelo projeto):

- `core/domain` (`TurnstilePort`, `ReleaseTurnstileOnApproval` + teste): **4/4 testes verdes**.
- `hardware/catraca` + `hardware/serial:SerialLink` (`GertecFrame`,
  `GertecTc400TurnstileAdapter` + teste): **7/7 testes verdes**.

Comandos executados (reprodutíveis por um humano com Android SDK instalado, contra a árvore real):

```
./gradlew :core:domain:test
./gradlew :hardware:catraca:test
```

**Não executado**: build/teste do módulo `:app` e do módulo `:hardware:serial` isoladamente (não
alterei lógica de `UsbSerialLink` além de implementar a interface extraída, e este ambiente não tem
Android SDK para validar a variante Android da compilação) — recomenda-se rodar
`./gradlew :hardware:serial:compileDebugKotlin :hardware:catraca:compileDebugKotlin` num ambiente
com Android SDK antes do merge, para garantir que a extração de `SerialLink` compila também sob o
Android Gradle Plugin (o teste satélite só validou a compilação Kotlin/JVM pura das classes, não a
variante Android do módulo `hardware/*`).

## 6. Pendências e riscos para o piloto de segunda (linha 8012)

- **Confirmar com o time de hardware**, antes do piloto: o polinômio CRC-8 e os bytes STX/ETX
  exatos do protocolo Gertec TC-400 (assunção documentada em `GertecFrame.kt`, não confirmável só
  com o resumo em `docs/vendor/gertec-tc400-serial.md`).
- **Corrigir `docs/product/modules/catraca/tasks.md`** (TASK-03) para descrever o hardware real da
  linha 8012 (Gertec TC-400/serial), evitando que a próxima pessoa/agente reintroduza o caminho
  GPIO incompatível.
- Nenhum consumidor de `ReleaseTurnstileOnApproval`/`GertecTc400TurnstileAdapter` foi conectado a
  uma tela ou fluxo de UI real — não há módulo `feature/validation` nesta fixture. A integração
  fim a fim (leitura do resultado da validação → chamada ao caso de uso → feedback ao operador)
  fica como próximo passo, fora do escopo estrito de TASK-03 como descrita.
- Não há retry/mecanismo de fila para o caso `DeviceUnavailable`; por design (nunca retry cego em
  comando físico de catraca), a decisão de tentar de novo fica para a camada chamadora, que
  deveria consultar `CMD_STATUS (0x35)` antes de qualquer reenvio, conforme o vendor doc — este
  adapter não implementa esse fluxo de consulta+reenvio porque está fora do que TASK-03 pede.

## 7. Subagentes

Nenhum subagente foi necessário ou solicitado pelo artefato do agente (`android-embedded-kotlin-engineer.md`)
para este caso; a implementação inteira coube a esta execução. Nenhum despacho de subagente foi
registrado porque nenhum foi cogitado.
