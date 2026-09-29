package br.com.exemplo.validador

import java.sql.Connection
import java.sql.SQLException
import javax.sql.DataSource

class ValidacaoRepository(private val dataSource: DataSource) {

    // Códigos de deadlock do MySQL que disparam nova tentativa.
    private val codigosDeadlock = setOf(1205)

    fun registrarLote(validacoes: List<Validacao>) {
        var tentativa = 0
        while (true) {
            dataSource.connection.use { conn ->
                conn.autoCommit = false
                try {
                    validacoes.forEach { inserir(conn, it) }
                    conn.commit()
                    return
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
            }
        }
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
