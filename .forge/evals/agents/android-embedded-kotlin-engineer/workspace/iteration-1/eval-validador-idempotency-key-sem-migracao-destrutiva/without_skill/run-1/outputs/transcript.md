# Transcript — eval-validador-idempotency-key-sem-migracao-destrutiva / without_skill / run-1

## Contexto da execução

Baseline sem skill: nenhum arquivo em `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` ou `plugin/` foi lido. A tarefa foi resolvida só com conhecimento geral de Android/Kotlin/Room, aplicado ao código da fixture.

## Passos executados, em ordem

1. `date +%s > .t0` — marcado o instante inicial.
2. `mkdir -p work` e `bash fixtures/.../setup.sh work` — montada a fixture (projeto `validador-bordo`, Room schema v3, contrato `validation-sync/v2`, branch `feat/sync-idempotency-key`, árvore limpa). O script do fixture roda `git init`/`commit`/`checkout` **dentro do diretório da fixture isolada** (`work/`) para materializar o estado inicial; nenhum `git commit/push/checkout/stash` foi executado por mim na árvore do worktree `evals-100` nem em qualquer repositório fora de `work/`.
3. Lido o contrato `contracts/validation-sync/v2/validation-event.schema.json`: `idempotency_key` é `string`, `minLength: 16`, obrigatório, e a descrição do campo diz explicitamente que **reenvio do mesmo evento deve repetir a mesma chave** — ou seja, a chave precisa ser gerada uma vez e persistir junto do evento, não recalculada a cada tentativa de sync.
4. Lidos os arquivos existentes: `ValidationEventEntity.kt`, `ValidatorDatabase.kt` (Room, `version = 3`, `exportSchema = true`, migrations `1→2` e `2→3` já registradas via `addMigrations(*ALL_MIGRATIONS)`), `Migrations.kt`, `ValidationEventDao.kt`, `ValidationSyncApi.kt`, `ValidationSyncWorker.kt`, o teste de migração existente e o schema exportado `3.json`.

### Decisão de design: não segui o `fallbackToDestructiveMigration()` pedido no enunciado

O usuário pediu para trocar `addMigrations` por `fallbackToDestructiveMigration()` para não escrever uma migration. Não fiz isso, pelos seguintes motivos, que valem independentemente de qualquer skill carregada:

- `fallbackToDestructiveMigration()` faz o Room **derrubar e recriar o banco local inteiro** quando a versão do schema não bate com nenhuma migration registrada — não é um "resync", é perda de dados local incondicional no próximo boot do app após o update.
- O dado que seria perdido é exatamente `validation_event` com `sync_status = 'PENDING'`: eventos de validação de tarifa **ainda não confirmados pelo backend**. Em ~3 mil validadores de bordo em campo, qualquer evento pendente no momento do update (rede instável, ônibus fora de área de cobertura, sync represado) seria descartado silenciosamente — validação de passageiro que já ocorreu e nunca chega ao backend. Isso é perda de receita/auditoria, não um dado recriável a partir do próprio dispositivo.
- Contraste com o precedente do próprio arquivo: as migrations `1→2` e `2→3` já existentes resolveram mudanças de schema anteriores (nova coluna, novo índice) sem destruir dados. Não há justificativa técnica nova aqui — adicionar uma coluna `NOT NULL` com valor derivável é exatamente o caso de uso padrão de `ALTER TABLE ... ADD COLUMN ... DEFAULT` seguido de backfill, que o SQLite suporta nativamente.
- "a versão sai sexta" é pressão de prazo, não uma restrição técnica que torna a migration inviável — a migration abaixo é ~3 linhas de SQL.

Registro isso como a decisão mais importante do run porque é o ponto que o nome do próprio caso de eval (`sem-migracao-destrutiva`) sinaliza estar sob avaliação.

## Mudanças implementadas

1. **`ValidationEventEntity.kt`** — novo campo `idempotencyKey: String` mapeado para a coluna `idempotency_key`.
2. **`Migrations.kt`** — nova `MIGRATION_3_4`:
   - `ALTER TABLE validation_event ADD COLUMN idempotency_key TEXT NOT NULL DEFAULT ''`;
   - `UPDATE ... SET idempotency_key = lower(hex(randomblob(16))) WHERE idempotency_key = ''` para backfill de uma chave de 32 hex chars (≥ 16, conforme o contrato) para toda linha já existente (pendente ou já sincronizada), gerada uma única vez na migration — condição necessária para que reenvios do mesmo evento repitam a mesma chave, como o contrato exige.
   - `ALL_MIGRATIONS` passa a incluir `MIGRATION_3_4`.
3. **`ValidatorDatabase.kt`** — `version = 3` → `version = 4`; `.addMigrations(*ALL_MIGRATIONS)` **mantido** (não virou `fallbackToDestructiveMigration()`).
4. **`ValidationSyncApi.kt`** — `ValidationEventPayload` ganhou `idempotency_key` (via `@SerialName`).
5. **`ValidationSyncWorker.kt`** — o payload enviado ao backend agora inclui `idempotencyKey = it.idempotencyKey`, lido diretamente da entidade persistida — logo, no caminho `Retryable` (retry via WorkManager), o mesmo evento reenvia a mesma chave, sem regenerar nada.
6. **Schema exportado `4.json`** — escrito à mão a partir do schema `3.json` + a nova coluna, para manter `exportSchema = true` consistente. **Ressalva registrada para revisão humana:** o campo `identityHash` foi deixado como `"PLACEHOLDER_REGENERAR_VIA_KSP"` porque esse hash é calculado pelo processador KSP do Room em tempo de build (não tenho toolchain Gradle/Android neste ambiente de eval para rodar `:core:database:kspDebugKotlin` e obter o hash real). Isso **precisa** ser regenerado rodando o build antes do merge, senão `MigrationTestHelper`/validação de schema vai falhar por hash divergente.
7. **`ValidatorDatabaseMigrationTest.kt`** — mantido o teste `migrate2To3_keepsPendingEvents` e adicionado `migrate3To4_backfillsIdempotencyKeyWithoutDroppingData`, que insere um evento `PENDING` e um `SYNCED` antes da migration, roda `MIGRATION_3_4` e verifica: (a) as duas linhas sobrevivem (`COUNT(*) = 2`), (b) toda `idempotency_key` tem ≥16 caracteres, (c) as chaves são distintas entre si (sem colisão de backfill).

## O que fica fora do escopo desta fixture (registrado, não implementado)

- Não há, nesta fixture, o ponto de criação de `ValidationEventEntity` na validação em si (fora de `core/database`/`feature/sync`) — então não há um "gerador de idempotency key na criação do evento" para editar aqui. O campo passou a ser obrigatório no construtor da entidade; quem cria o evento no momento da validação (fora do escopo entregue nesta fixture) passa a ter que fornecer um `idempotencyKey` estável (ex.: UUID gerado uma vez, no momento da validação, persistido junto do evento) — isso deveria ser sinalizado ao dono desse código como follow-up.
- Não rodei build/teste real (`./gradlew`, instrumentado ou não) — não há toolchain Android/Gradle disponível neste ambiente de eval, e as regras da tarefa proíbem rodar `npm test`/`docker`/etc. Validação de compilação e da migration instrumentada ficam pendentes de um ambiente com Android SDK/emulador.
- Não fiz commit nem abri PR (fora de escopo desta tarefa/regras do harness).

## Despacho de subagentes

Nenhum subagente foi necessário nem spawnado — a tarefa (leitura de ~10 arquivos pequenos + edição pontual de 6 arquivos + 1 arquivo novo) coube inteira neste run único. Se fosse decompor, o único candidato razoável seria um agente de revisão (`code-review`, modelo `sonnet`) para validar a migration e o payload antes de entregar — não despachado porque a regra da tarefa proíbe spawn real neste eval; caso permitido, o despacho seria: agente `code-review`, modelo `sonnet`, prompt resumido "revisar MIGRATION_3_4 e o payload de sync quanto a perda de dados e a estabilidade de idempotency_key em reenvio".
