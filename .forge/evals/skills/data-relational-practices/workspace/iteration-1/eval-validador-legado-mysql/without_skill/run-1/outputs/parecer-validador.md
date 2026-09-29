# Parecer — migrations e retry de deadlock do validador-legado

## Resumo executivo

Revisei as duas migrations novas (`20260930_idx_linha_data.sql` e `20260930_cartao_uid_varchar.sql`) e o retry de deadlock em `ValidacaoRepository.kt` contra o contexto descrito em `services/validador-legado/docs/banco.md` (MySQL 8.4, InnoDB, ~180 milhões de linhas, ~2 mil inserções/segundo, sem janela de manutenção, serviço 24x7). Encontrei três problemas que bloqueiam o deploy como está: um dado incorreto na própria documentação de contexto que mascara o risco real da segunda migration, a segunda migration em si (troca de tipo de `cartao_uid`) causando bloqueio de escrita prolongado numa tabela de 180M linhas sem janela, e um bug de perda de dados no retry de deadlock. A primeira migration (índice `idx_validacoes_linha_data`) está correta, mas incompleta — falta declarar `ALGORITHM`/`LOCK` explicitamente.

## 1. `docs/banco.md` — isolamento default do InnoDB está errado

O documento afirma: *"O isolamento usado é o default do InnoDB, que é READ COMMITTED como no Postgres"*.

Isso é factualmente incorreto. O nível de isolamento default do InnoDB é **REPEATABLE READ**, não READ COMMITTED — ao contrário do Postgres, cujo default é de fato READ COMMITTED. Essa diferença não é cosmética: sob REPEATABLE READ, o MySQL usa locking de intervalo (*gap locks* / *next-key locks*) em `UPDATE`/`DELETE`/`SELECT ... FOR UPDATE`, o que é justamente o que costuma gerar deadlocks em cargas de escrita concorrente como a descrita (pico de 2 mil inserções/s). Ou seja, a causa mais provável dos deadlocks que o retry em `ValidacaoRepository.kt` está tentando absorver é exatamente essa característica do REPEATABLE READ que o documento nega existir. Recomendo corrigir `banco.md` antes de basear qualquer decisão de arquitetura nele, e considerar explicitamente se `READ COMMITTED` (setado via `tx_isolation`/`transaction_isolation`) reduziria os gap locks nos inserts — mas isso é uma decisão separada, não algo a mudar nesta revisão sem validação própria.

## 2. `20260930_idx_linha_data.sql` — correta, mas incompleta

```sql
ALTER TABLE `validacoes` ADD INDEX `idx_validacoes_linha_data` (`linha_id`, `validado_em`);
```

Um `ADD INDEX` em InnoDB roda por padrão com `ALGORITHM=INPLACE, LOCK=NONE`, então funcionalmente isso deve funcionar sem bloquear escrita. Mas a migration anterior (`20260815_idx_dispositivo.sql`, já aplicada em produção) declara isso explicitamente. Numa tabela de 180M linhas sem janela de manutenção, não vale confiar no default do MySQL — se uma versão/config futura mudar o comportamento padrão, o ALTER falha silenciosamente para COPY (ou é rejeitado, dependendo da config `old_alter_table`). Corrija para:

```sql
-- Nova: índice para a consulta de conciliação por linha e dia.
ALTER TABLE `validacoes` ADD INDEX `idx_validacoes_linha_data` (`linha_id`, `validado_em`), ALGORITHM=INPLACE, LOCK=NONE;
```

Sem outras objeções a essa migration.

## 3. `20260930_cartao_uid_varchar.sql` — bloqueia escrita numa tabela sem janela de manutenção. NÃO subir como está.

```sql
ALTER TABLE `validacoes` MODIFY COLUMN `cartao_uid` VARCHAR(32) NOT NULL, ALGORITHM=COPY, LOCK=SHARED;
```

Mudar o tipo de uma coluna de `CHAR` para `VARCHAR` é uma mudança que o InnoDB não suporta via `ALGORITHM=INPLACE` — exige reconstrução da tabela inteira (`ALGORITHM=COPY`), e é por isso que a migration já está anotada assim; isso não é um erro de digitação. O problema é o que `LOCK=SHARED` significa na prática aqui: durante todo o `COPY`, a tabela aceita leituras mas **bloqueia todo `INSERT`/`UPDATE`/`DELETE`**. Numa tabela com 180 milhões de linhas e um serviço que roda 24x7 sem janela de manutenção, recebendo pico de 2 mil inserções por segundo, isso significa: (a) o `ALTER` provavelmente leva de dezenas de minutos a horas para copiar a tabela inteira; (b) durante esse tempo, todo validador embarcado que tentar registrar uma validação vai falhar ou enfileirar, gerando um backlog gigantesco ou perda de validações a depender de como o cliente trata timeout; (c) não há como abortar com segurança no meio sem perder o trabalho de cópia já feito. Isso é, na prática, uma indisponibilidade de escrita não anunciada em produção.

Duas alternativas, em ordem de preferência:

1. **Ferramenta de DDL online sem lock** (`pt-online-schema-change` do Percona Toolkit ou `gh-ost` do GitHub) — cria uma tabela-sombra, copia em background usando triggers/binlog para capturar escritas concorrentes, e faz o `RENAME` atômico no final. É o caminho padrão da indústria para exatamente esse cenário (tabela grande, sem janela, tipo de coluna mudando). Nenhuma das duas ferramentas está referenciada no repositório até onde revisei — se o projeto já usa uma delas em outra migration, alinhe com esse padrão; se não usa nenhuma, isso é uma decisão de infraestrutura que extrapola o escopo desta revisão e precisa ser validada com quem opera o banco antes do deploy.
2. **Expand/contract manual**: adicionar uma coluna nova `cartao_uid_novo VARCHAR(32)` (operação `INSTANT` em MySQL 8.0+, sem cópia), backfill em lotes pequenos com throttling para não competir com os 2 mil inserts/s, trigger ou dupla escrita na aplicação durante a transição, e só então trocar o nome/dropar a coluna antiga — de novo, o `DROP`/`RENAME` final ainda deve ser `INSTANT` ou de baixo impacto, mas o backfill é responsabilidade da aplicação, não do banco.

Não tenho como validar qual das duas é viável no ambiente real (se o Percona Toolkit está disponível, se dupla escrita é aceitável no código do validador) — isso precisa de confirmação de quem opera a infraestrutura. O que dá para afirmar com confiança é que o `ALGORITHM=COPY, LOCK=SHARED` como está não deve subir para produção neste serviço.

## 4. `ValidacaoRepository.kt` — retry de deadlock perde dados

```kotlin
} catch (e: SQLException) {
    if (e.errorCode in codigosDeadlock && tentativa < 3) {
        tentativa++
        // repete só a última instrução que falhou
        inserir(conn, validacoes.last())
        conn.commit()
        return
    }
    conn.rollback()
    throw e
}
```

Quando o InnoDB detecta um deadlock (erro 1205 — na verdade o código correto de deadlock é **1213**, `ER_LOCK_DEADLOCK`; 1205 é `ER_LOCK_WAIT_TIMEOUT`, um erro diferente com semântica diferente — trato os dois abaixo), ele já fez rollback automático e completo da transação da conexão que escolheu como vítima. Isso significa que, no momento em que o `catch` é acionado, **nenhuma das inserções do lote foi persistida**, não só a última. O código atual, no entanto, reexecuta e comita apenas `validacoes.last()` — ou seja, se o lote tinha 50 validações, 49 são silenciosamente descartadas e dadas como concluídas com sucesso (a função retorna sem erro). Isso é perda de dado de validação de bilhetagem, que tem implicação de conciliação financeira.

Além disso, `codigosDeadlock` contém apenas `1205`. O erro real de deadlock do MySQL é `1213`. Se o driver JDBC estiver reportando `getErrorCode()` corretamente, o retry pode nem estar sendo acionado para deadlocks de verdade (1213), só para lock wait timeout (1205) — que é um problema relacionado mas distinto (timeout de espera por lock, não escolha de vítima). Os dois merecem retry, mas com esse código faltando é possível que deadlocks reais estejam sempre subindo como falha direta sem nenhuma tentativa.

Por fim, o `while (true)` externo é decorativo: o único retry acontece inline dentro do `catch`, chama `conn.commit()` e dá `return` — se esse retry único também colidir em deadlock, a exceção não é capturada de novo (não há try/catch ao redor da chamada de retry) e sobe direto para o chamador, apesar do contador `tentativa < 3` sugerir até 3 tentativas. Não há backoff entre tentativas, o que agrava deadlocks em rajada sob os 2 mil inserts/s de pico.

Correção proposta — reexecuta o lote inteiro numa nova transação a cada tentativa, cobre os dois códigos de erro, e usa o `while` externo de verdade com um pequeno backoff:

```kotlin
package br.com.exemplo.validador

import java.sql.Connection
import java.sql.SQLException
import javax.sql.DataSource

class ValidacaoRepository(private val dataSource: DataSource) {

    // 1213 = ER_LOCK_DEADLOCK (deadlock detectado, InnoDB já reverteu a transação inteira).
    // 1205 = ER_LOCK_WAIT_TIMEOUT (esperou lock além de innodb_lock_wait_timeout).
    // Os dois justificam nova tentativa do lote inteiro numa transação nova.
    private val codigosRetentaveis = setOf(1213, 1205)
    private val maxTentativas = 3

    fun registrarLote(validacoes: List<Validacao>) {
        var tentativa = 0
        while (true) {
            try {
                dataSource.connection.use { conn ->
                    conn.autoCommit = false
                    try {
                        validacoes.forEach { inserir(conn, it) }
                        conn.commit()
                    } catch (e: SQLException) {
                        conn.rollback()
                        throw e
                    }
                }
                return
            } catch (e: SQLException) {
                if (e.errorCode in codigosRetentaveis && tentativa < maxTentativas) {
                    tentativa++
                    Thread.sleep(backoffMs(tentativa))
                    // volta ao topo do while e reexecuta o LOTE INTEIRO numa conexão/transação nova
                } else {
                    throw e
                }
            }
        }
    }

    private fun backoffMs(tentativa: Int): Long {
        // backoff exponencial curto com jitter para não sincronizar retries entre threads
        val base = 20L * (1L shl (tentativa - 1)) // 20ms, 40ms, 80ms
        return base + (0..20L).random()
    }

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

Nota: `Thread.sleep` bloqueia a thread chamadora durante o backoff — aceitável se `registrarLote` já roda num pool de workers dedicado (comum nesse tipo de ingestão), mas se for chamado de um contexto de corrotina/reator não bloqueante, trocar por um mecanismo de retry assíncrono equivalente. Não tenho visibilidade do chamador para confirmar qual é o caso aqui.

## Veredito

Não subir como está. Bloqueadores: item 3 (migration de `cartao_uid` bloqueia escrita numa tabela sem janela de manutenção — precisa de DDL online ou expand/contract) e item 4 (retry de deadlock descarta o lote inteiro exceto o último registro — perda de dado). Item 2 é um ajuste de segurança barato (declarar `ALGORITHM`/`LOCK` explicitamente) que recomendo fazer antes de subir, mas não bloqueia por si só. Item 1 é uma correção de documentação que deveria acontecer antes de qualquer decisão futura de isolamento ser tomada com base nela.
