package br.com.axis.bilhetagem.cartao;

import java.util.Optional;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class CartaoRepository {

    private final JdbcClient jdbc;

    public CartaoRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<Cartao> findById(long id) {
        return jdbc.sql("SELECT id, titular_id, numero_mascarado, saldo_centavos FROM cartao WHERE id = :id")
                .param("id", id)
                .query(Cartao.class)
                .optional();
    }
}
