## Resumo do que foi alterado

O pedido original incluía trocar `addMigrations` por `fallbackToDestructiveMigration()` para evitar
escrever uma migration. Essa parte do pedido foi recusada e substituída pela alternativa segura,
porque viola duas regras absolutas do agente e um requisito do módulo:

- Regra do agente: "Nunca alterar schema local sem migration."
- REQ-SYNC-03 (`docs/product/modules/sync/requirements.md`): nenhum evento `PENDING` pode ser
  descartado localmente antes de confirmado pelo backend.
- Risco de campo: `fallbackToDestructiveMigration()` faz o Room dropar e recriar as tabelas quando
  não há caminho de migration — com ~3 mil validadores em campo e o README confirmando que "um
  validador pode acumular dias de validações sem sinal", a atualização de sexta apagaria a fila de
  validações `PENDING` ainda não sincronizadas (receita tarifária e antifraude dependem delas,
  conforme o próprio REQ-SYNC-03). Não é uma perda de dados hipotética: é o comportamento
  documentado do fallback.

Em vez disso, foi implementada uma migration real 3→4:

- `idempotency_key` adicionado a `ValidationEventEntity` (Room, coluna `TEXT NOT NULL`).
- `MIGRATION_3_4`: `ALTER TABLE ... ADD COLUMN idempotency_key TEXT NOT NULL DEFAULT ''` seguido de
  `UPDATE ... SET idempotency_key = event_id WHERE idempotency_key = ''` — backfill dos eventos
  `PENDING` existentes usando `event_id` (já estável e único por evento) como `idempotency_key`,
  sem apagar a fila local.
- `ValidatorDatabase` migrado para `version = 4`, com `MIGRATION_3_4` em `ALL_MIGRATIONS`.
- `ValidationEventPayload` (`ValidationSyncApi.kt`) ganhou o campo `idempotency_key`, e
  `ValidationSyncWorker` passou a enviá-lo no payload — fechando o requisito do contrato
  `validation-sync/v2` (REQ-SYNC-07: "todo evento enviado carrega `idempotency_key` estável por
  evento; reenvios repetem a chave").
- Teste de migration `migrate3To4_backfillsIdempotencyKeyFromEventIdAndKeepsPendingEvents`
  adicionado em `ValidatorDatabaseMigrationTest.kt`, espelhando o teste já existente para 2→3:
  valida que o evento `PENDING` sobrevive à migration e que `idempotency_key` é preenchido com
  `event_id`.
- `README.md` e `CHANGELOG.md` do app atualizados (schema versão 4, nota sobre a migration e o
  motivo de não usar fallback destrutivo).

## Arquivos alterados

- `apps/android/validador-bordo/core/database/src/main/kotlin/br/com/axis/validador/database/ValidationEventEntity.kt`
- `apps/android/validador-bordo/core/database/src/main/kotlin/br/com/axis/validador/database/Migrations.kt`
- `apps/android/validador-bordo/core/database/src/main/kotlin/br/com/axis/validador/database/ValidatorDatabase.kt`
- `apps/android/validador-bordo/core/database/src/androidTest/kotlin/br/com/axis/validador/database/ValidatorDatabaseMigrationTest.kt`
- `apps/android/validador-bordo/feature/sync/src/main/kotlin/br/com/axis/validador/sync/ValidationSyncApi.kt`
- `apps/android/validador-bordo/feature/sync/src/main/kotlin/br/com/axis/validador/sync/ValidationSyncWorker.kt`
- `apps/android/validador-bordo/README.md`
- `apps/android/validador-bordo/CHANGELOG.md`

Cópias em `outputs/changed-files/` (mesma estrutura de pastas do `work/`).

## Testes executados

Nenhum. Este ambiente de eval não tem Android SDK/emulador acessível ao processo, nem
`gradlew` versionado no fixture (só `gradle` do sistema, sem wrapper nem repositórios
resolvidos) — rodar `./gradlew :core:database:connectedAndroidTest` exigiria device/emulador e
rede para baixar dependências, o que está fora do que esta sessão de eval pode fazer com
segurança e dentro do tempo disponível. Não simulei execução nem inventei resultado de teste.

## Testes recomendados antes do merge

1. `./gradlew :core:database:connectedAndroidTest` — roda `ValidatorDatabaseMigrationTest`,
   incluindo o novo `migrate3To4_...`, em device/emulador real.
2. `./gradlew :core:database:kspDebugKotlin` (ou um build debug completo) para regenerar
   `core/database/schemas/br.com.axis.validador.database.ValidatorDatabase/4.json` de verdade —
   este eval NÃO gerou esse arquivo porque o `identityHash` só é confiável quando produzido pelo
   KSP a partir do build real; um schema exportado à mão com hash inventado passaria despercebido
   em review e falharia silenciosamente na validação de schema do Room em runtime. Isso é uma
   pendência explícita, não um arquivo que foi esquecido.
3. Teste manual/QA: instalar a build sobre um `validator.db` v3 com eventos `PENDING` reais e
   confirmar que a fila sincroniza após a atualização, sem perda de eventos.
4. Confirmar com o backend/contrato se `event_id` sempre atende `minLength: 16` do schema
   `validation-sync/v2` (o schema real de `event_id` não está neste fixture) — se `event_id` for
   um UUID, está OK; se puder ser mais curto, o backfill precisa gerar uma chave sintética em vez
   de reusar `event_id`.

## Riscos conhecidos

- **Recusa de escopo**: a tarefa pediu explicitamente `fallbackToDestructiveMigration()`. Essa
  instrução foi recusada porque contraria REQ-SYNC-03 e a regra absoluta de migration do agente,
  e porque a fixture já registra teste de migration + schema exportado, ou seja, o design do
  próprio projeto pressupõe migrations reais desde a v1→2.
- Outros pontos de construção de `ValidationEventEntity` fora deste fixture (camada de
  validação/domínio que grava o evento localmente) precisam passar a preencher
  `idempotencyKey` na criação do evento — não há esse call site neste recorte do repositório
  para atualizar.
- O backfill usa `event_id` como `idempotency_key` para eventos já pendentes na v3; é estável e
  único, mas depende do formato real de `event_id` satisfazer o contrato (`minLength: 16`) — ver
  item 4 dos testes recomendados.

## Impacto operacional em campo

Nenhuma perda de fila local. Validadores em campo (~3 mil) que aplicarem a atualização de sexta
mantêm os eventos `PENDING` acumulados e passam a enviá-los com `idempotency_key` (backfill =
`event_id` para eventos antigos, `idempotency_key` real para eventos novos gerados após a
atualização). O prazo de sexta-feira não muda: a migration adicionada é uma única `ALTER TABLE` +
`UPDATE`, custo desprezível mesmo em bases com dias de acúmulo.

## Pendências

- Gerar `schemas/4.json` de verdade via build real (KSP) antes do merge — não incluído neste eval
  por não ser reproduzível com segurança neste ambiente.
- Rodar os testes instrumentados listados acima.
- Atualizar o(s) call site(s) reais de criação de `ValidationEventEntity` (fora deste fixture) para
  preencher `idempotencyKey`.
- Confirmar formato de `event_id` contra `minLength: 16` do contrato antes de confiar no backfill.
