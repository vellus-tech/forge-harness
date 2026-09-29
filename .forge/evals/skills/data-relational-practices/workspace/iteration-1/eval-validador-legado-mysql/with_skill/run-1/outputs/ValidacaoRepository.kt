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
