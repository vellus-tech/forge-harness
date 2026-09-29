package br.com.axis.bilhetagem.recarga;

import java.util.List;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class RecargaHistoricoQuery {

    private final JdbcClient jdbc;

    public RecargaHistoricoQuery(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public List<Recarga> listar(long cartaoId, String status) {
        String sql = "SELECT id, cartao_id, valor_centavos, status, criada_em FROM recarga "
                + "WHERE cartao_id = " + cartaoId + " AND status = '" + status + "' ORDER BY criada_em DESC";
        return jdbc.sql(sql).query(Recarga.class).list();
    }

    public Recarga inserir(long cartaoId, long valorCentavos) {
        return jdbc.sql("INSERT INTO recarga (cartao_id, valor_centavos, status) VALUES (:c, :v, 'PENDENTE') "
                        + "RETURNING id, cartao_id, valor_centavos, status, criada_em")
                .param("c", cartaoId)
                .param("v", valorCentavos)
                .query(Recarga.class)
                .single();
    }
}
