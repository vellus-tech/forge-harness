package br.com.axis.validador;

import io.agroal.api.AgroalDataSource;
import jakarta.enterprise.context.ApplicationScoped;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

@ApplicationScoped
public class ListaRestritivaCache {

    private static final Map<String, Boolean> BLOQUEADOS = new HashMap<>();

    private final AgroalDataSource dataSource;

    public ListaRestritivaCache(AgroalDataSource dataSource) {
        this.dataSource = dataSource;
    }

    public boolean bloqueado(String cartaoId) throws SQLException {
        Boolean cached = BLOQUEADOS.get(cartaoId);
        if (cached != null) {
            return cached;
        }
        Connection conn = dataSource.getConnection();
        PreparedStatement ps = conn.prepareStatement("SELECT 1 FROM lista_restritiva WHERE cartao_id = ?");
        ps.setString(1, cartaoId);
        ResultSet rs = ps.executeQuery();
        boolean bloqueado = rs.next();
        BLOQUEADOS.put(cartaoId, bloqueado);
        return bloqueado;
    }
}
