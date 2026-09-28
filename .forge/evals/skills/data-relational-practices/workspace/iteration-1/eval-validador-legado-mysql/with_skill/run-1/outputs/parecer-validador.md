# Parecer — migrations e retry de deadlock do validador-legado

Escopo revisado: `services/validador-legado/db/migrations/20260930_idx_linha_data.sql`, `services/validador-legado/db/migrations/20260930_cartao_uid_varchar.sql`, `services/validador-legado/src/main/kotlin/br/com/exemplo/validador/ValidacaoRepository.kt` e `services/validador-legado/docs/banco.md` (contexto). Engine: MySQL 8.4/InnoDB, tabela `validacoes` com ~180M linhas, pico de 2 mil inserções/s, sem janela de manutenção (24x7).

## Veredito

Duas mudanças **não podem subir como estão** — a migration de `cartao_uid` bloqueia escrita numa tabela sem janela de manutenção, e o retry de deadlock tem um bug de correção de dados (pode descartar linhas silenciosamente). A migration de índice precisa de um ajuste pequeno antes do merge. `banco.md` tem uma afirmação factualmente errada sobre isolamento que pode induzir decisão errada em código de conciliação futuro.

## 1. `docs/banco.md` — isolamento do InnoDB (correção factual)

O documento afirma que o isolamento default do InnoDB é READ COMMITTED "como no Postgres". Isso está errado: **o default do InnoDB é REPEATABLE READ**, não READ COMMITTED — são motores com defaults diferentes e a mesma etiqueta de nível de isolamento tem semânticas diferentes entre eles (phantom reads, gap locks). Não é uma questão cosmética: leitura de conciliação escrita supondo READ COMMITTED pode se comportar diferente do esperado sob REPEATABLE READ (snapshot mais antigo dentro da mesma transação).

**Correção sugerida** (aplicada em `outputs/banco.md.patch` e já refletida no `work/` desta revisão):

```diff
- O isolamento usado é o default do InnoDB, que é READ COMMITTED como no Postgres, então as leituras de conciliação não precisam de cuidado extra.
+ O isolamento default do InnoDB é REPEATABLE READ (não READ COMMITTED — esse é o default do Postgres, não do MySQL). A etiqueta do nível é a mesma nos dois motores, mas o comportamento de phantom read e gap lock é diferente; não portar suposição de isolamento do Postgres para o MySQL. Leituras de conciliação que dependam de ver commits recentes de outra transação em andamento devem reabrir a transação, não assumir READ COMMITTED implícito.
```

Evidência: MySQL 8.4, InnoDB transaction isolation levels (default REPEATABLE READ) — referenciado em `references/best-practices.md` da skill `data-relational-practices`, linha "Defaults: PostgreSQL Read Committed; InnoDB REPEATABLE READ; ...".

## 2. `db/migrations/20260930_idx_linha_data.sql` — falta `ALGORITHM`/`LOCK` explícitos

Achado do scanner: **R-22** (aviso), `ALTER TABLE ... ADD INDEX` numa migração MySQL sem `ALGORITHM=INPLACE, LOCK=NONE` explícitos. No MySQL 8.4 um índice secundário é INPLACE/online por padrão, mas sem os dois explícitos uma variação silenciosa (versão de servidor diferente, coluna com tipo que não suporta INPLACE) cai em cópia bloqueante sem avisar; com eles explícitos, o MySQL recusa a DDL em vez de travar a tabela de 180M linhas em produção. A migration anterior da mesma tabela (`20260815_idx_dispositivo.sql`, já aplicada) segue essa convenção — a nova quebra o padrão do próprio repositório.

**Correção** (SQL completo em `outputs/20260930_idx_linha_data.sql`):

```sql
-- Nova: índice para a consulta de conciliação por linha e dia.
ALTER TABLE `validacoes` ADD INDEX `idx_validacoes_linha_data` (`linha_id`, `validado_em`), ALGORITHM=INPLACE, LOCK=NONE;
```

Sem outros problemas nesta migration.

## 3. `db/migrations/20260930_cartao_uid_varchar.sql` — `ALGORITHM=COPY, LOCK=SHARED` bloqueante (achado alto)

Achado do scanner: **R-13** `[alto]` — `ALGORITHM=COPY`/`LOCK` forçado no MySQL. `MODIFY COLUMN cartao_uid VARCHAR(32) NOT NULL` muda o tipo da coluna (CHAR→VARCHAR), o que exige reescrita da tabela inteira no InnoDB (`ALGORITHM=COPY` não é opcional aqui — é a única forma de fazer essa troca de tipo). `LOCK=SHARED` bloqueia toda escrita durante a cópia inteira das ~180M linhas, e a tabela recebe até 2 mil inserções/s sem nenhuma janela de manutenção. Isso não é um lock breve: é uma indisponibilidade de escrita de duração proporcional ao tamanho da tabela — minutos a horas, dependendo do hardware, com fila de 2 mil inserts/s se acumulando atrás do lock (o próprio caso R-13 do catálogo é exatamente "`ALTER TABLE` que bloqueia escrita por minutos ou horas").

Achado secundário do scanner, dispensado após leitura: **R-04** (aviso) marcou a linha por conter `CHAR(14)` no comentário — é o padrão de tipo problemático do Postgres (`char(n)` que preenche com espaço), mas a regra é escopada a PostgreSQL e aqui é MySQL mudando de CHAR para VARCHAR, que é a direção certa de tipo; o problema real desta migration é o método (R-13), não o tipo de destino. **R-21** (aviso, ausência de `lock_timeout`) também dispensado: `lock_timeout` é GUC do PostgreSQL, não existe equivalente direto configurado por sessão no MySQL da mesma forma — falso positivo de engine no scanner para as três linhas MySQL do diretório.

**Correção — expand → migrate → contract** (`rules/data/schema-evolution.md` e correção documentada do R-13: "mudança que exige cópia vira coluna nova com backfill"). Não existe forma de trocar CHAR(14)→VARCHAR(32) via INPLACE nesta tabela; a saída é não fazer a troca de tipo em uma única DDL:

**Passo 1 — expand (este PR, arquivo revisado em `outputs/20260930_cartao_uid_varchar.sql`):** adicionar coluna nova, nullable, sem tocar a antiga. `ADD COLUMN` com coluna nullable e sem default é `INSTANT` no MySQL 8.4 — não bloqueia leitura nem escrita:

```sql
-- Revisada: cartao_uid vai de CHAR(14) para VARCHAR(32) via expand -> migrate -> contract
-- (R-13: ALGORITHM=COPY/LOCK=SHARED nesta tabela de ~180M linhas e 2 mil inserts/s, sem
-- janela de manutenção, travaria escrita por minutos/horas). Este arquivo é só o passo 1.
ALTER TABLE `validacoes` ADD COLUMN `cartao_uid_v2` VARCHAR(32) NULL, ALGORITHM=INSTANT, LOCK=NONE;
```

**Passo 2 — migrate (fora desta migration, job de aplicação):** dupla escrita no `ValidacaoRepository` (todo `INSERT` novo grava `cartao_uid` e `cartao_uid_v2` iguais) + backfill em lotes idempotentes por faixa de PK/tempo, com throttle e observabilidade, para as ~180M linhas existentes — exatamente o gate que `schema-evolution.md` exige declarar (engine, impacto leitura/escrita, estratégia de retomada após falha). Não incluído neste PR porque é código de aplicação e um job, não uma migration SQL.

**Passo 3 — contract (migration futura, só depois do backfill 100% verificado e da janela de compatibilidade encerrada):** tornar `cartao_uid_v2` `NOT NULL`, promover como coluna canônica e remover a `cartao_uid` (CHAR) antiga. `MODIFY ... NOT NULL` em coluna já populada também não é INPLACE garantido no InnoDB — se a validação de NOT NULL exigir rebuild, essa etapa final deve rodar com `gh-ost`/`pt-online-schema-change` (a própria correção do catálogo R-13/R-22 aponta essas ferramentas para o que não é online), nunca com `ALGORITHM=COPY, LOCK=SHARED` direto em produção sem janela.

Evidência: MySQL 8.4 online DDL (INSTANT para `ADD COLUMN` sem default volátil, COPY obrigatório para troca de tipo) — `references/best-practices.md` e `references/antipatterns.md` (R-13) da skill `data-relational-practices`.

## 4. `ValidacaoRepository.kt` — retry de deadlock com bug de correção de dados

Dois problemas, um deles grave:

**4.1 Código de erro errado.** O conjunto `codigosDeadlock = setOf(1205)` trata 1205 como deadlock. No MySQL, **1213 é deadlock** (a transação inteira é abortada pelo InnoDB) e **1205 é lock wait timeout** — que por padrão (`innodb_rollback_on_timeout=OFF`) desfaz só a última instrução, não a transação inteira. O código atual nunca vai tratar um deadlock real (1213), que é o cenário citado na tarefa.

**4.2 Perda silenciosa de linhas (o bug sério).** No `catch`, o código sempre reexecuta `inserir(conn, validacoes.last())` — a última validação da lista — independentemente de qual instrução falhou, e comita em seguida. Como o lote inteiro está numa transação (`autoCommit = false`) e nada foi commitado ainda, se o erro ocorrer, por exemplo, ao inserir o item 3 de um lote de 5, os itens 1–2 nunca foram persistidos; o retry insere só o item 5 e comita — os itens 1 a 4 somem sem exceção, sem log de erro, sem retry visível. Além disso, depois de um deadlock (1213) o InnoDB já desfez a transação inteira no servidor; reexecutar uma instrução na mesma `conn`/transação abortada tende a falhar, e mesmo quando não falha, não há garantia nenhuma sobre o que sobrou da transação.

**Correção** — retry do **lote inteiro**, em conexão/transação nova a cada tentativa, com backoff, distinguindo os dois códigos apenas para efeito de log (ambos tratados como "reexecute tudo, é mais seguro"), e ordem estável de chaves para reduzir a chance de deadlock entre lotes concorrentes (`references/antipatterns.md`, R-11: "retry com backoff da transação inteira" + "ordem consistente de locks"). Arquivo completo em `outputs/ValidacaoRepository.kt`:

```kotlin
package br.com.exemplo.validador

import java.sql.Connection
import java.sql.SQLException
import javax.sql.DataSource

class ValidacaoRepository(private val dataSource: DataSource) {

    // MySQL: 1213 = deadlock (a transação inteira é abortada pelo InnoDB, precisa
    // reiniciar do zero); 1205 = lock wait timeout (por padrão desfaz só a última
    // instrução, mas tratamos como "reexecute o lote inteiro" por segurança, já
    // que não há garantia do estado parcial da transação após o erro).
    private val codigosRetentaveis = setOf(1213, 1205)
    private val maxTentativas = 3

    fun registrarLote(validacoes: List<Validacao>) {
        // Ordem estável de chave reduz a chance de dois lotes concorrentes colidirem
        // em ordem inversa de lock (causa clássica de deadlock).
        val ordenadas = validacoes.sortedBy { it.cartaoUid }
        var tentativa = 0
        while (true) {
            try {
                dataSource.connection.use { conn ->
                    conn.autoCommit = false
                    try {
                        ordenadas.forEach { inserir(conn, it) }
                        conn.commit()
                    } catch (e: SQLException) {
                        conn.rollback()
                        throw e
                    }
                }
                return
            } catch (e: SQLException) {
                tentativa++
                if (e.errorCode !in codigosRetentaveis || tentativa >= maxTentativas) {
                    throw e
                }
                Thread.sleep(backoffMs(tentativa))
                // volta ao topo do while: nova conexão, nova transação, lote inteiro de novo.
            }
        }
    }

    private fun backoffMs(tentativa: Int): Long = 50L * (1L shl tentativa)

    private fun inserir(conn: Connection, v: Validacao) {
        conn.prepareStatement(
            "INSERT INTO validacoes (cartao_uid, linha_id, dispositivo_id, validado_em) VALUES (?, ?, ?, ?)"
        ).use { ps ->
            ps.setString(1, v.cartaoUid)
            ps.setLong(2, v.linhaId)
            ps.setLong(3, v.dispositivoId)
            ps.setObject(4, v.validadoEm)
            ps.executeUpdate()
        }
    }
}

data class Validacao(val cartaoUid: String, val linhaId: Long, val dispositivoId: Long, val validadoEm: java.time.Instant)
```

A reexecução do lote inteiro é segura porque o `rollback()` desfaz a transação da tentativa anterior por completo antes de tentar de novo — não há risco de inserção duplicada.

## Resumo — o que bloqueia o merge

| Item | Severidade | Ação |
|---|---|---|
| `20260930_cartao_uid_varchar.sql`: `ALGORITHM=COPY, LOCK=SHARED` numa tabela de 180M linhas sem janela | **Bloqueante** | Trocar por expand→migrate→contract; só o passo 1 (expand, INSTANT) sobe nesta migration |
| `ValidacaoRepository.kt`: retry reexecuta só o último item e usa código de erro errado (1205 em vez de 1213) | **Bloqueante** | Retry do lote inteiro em transação nova, códigos 1213/1205, ver correção acima |
| `20260930_idx_linha_data.sql`: falta `ALGORITHM=INPLACE, LOCK=NONE` explícitos | Ajuste antes do merge | Adicionar a cláusula, como na migration anterior da mesma tabela |
| `docs/banco.md`: isolamento do InnoDB descrito como READ COMMITTED | Correção de documentação | REPEATABLE READ é o default real; corrigir o texto |

Achados do scanner dispensados como falso positivo de engine (não exigem ação): R-04 e R-21 na migration de `cartao_uid` (regras escopadas a PostgreSQL, aplicadas por engano a SQL do MySQL pelo detector estático).
