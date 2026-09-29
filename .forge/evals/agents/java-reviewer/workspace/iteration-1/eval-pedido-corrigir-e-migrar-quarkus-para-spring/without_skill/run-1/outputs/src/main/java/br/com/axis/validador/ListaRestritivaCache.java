package br.com.axis.validador;

import io.agroal.api.AgroalDataSource;
import jakarta.enterprise.context.ApplicationScoped;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@ApplicationScoped
public class ListaRestritivaCache {

    private static final Duration TTL = Duration.ofMinutes(5);

    private final Map<String, Entrada> cache = new ConcurrentHashMap<>();
    private final AgroalDataSource dataSource;

    public ListaRestritivaCache(AgroalDataSource dataSource) {
        this.dataSource = dataSource;
    }

    public boolean bloqueado(String cartaoId) throws SQLException {
        Entrada cached = cache.get(cartaoId);
        Instant agora = Instant.now();
        if (cached != null && cached.expiraEm.isAfter(agora)) {
            return cached.bloqueado;
        }

        boolean bloqueado = consultar(cartaoId);
        cache.put(cartaoId, new Entrada(bloqueado, agora.plus(TTL)));
        return bloqueado;
    }

    private boolean consultar(String cartaoId) throws SQLException {
        try (Connection conn = dataSource.getConnection();
                PreparedStatement ps = conn.prepareStatement(
                        "SELECT 1 FROM lista_restritiva WHERE cartao_id = ?")) {
            ps.setString(1, cartaoId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        }
    }

    private record Entrada(boolean bloqueado, Instant expiraEm) {
    }
}
