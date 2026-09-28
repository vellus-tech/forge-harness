package br.example.cadastro.config;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import javax.sql.DataSource;
import org.springframework.jdbc.datasource.DelegatingDataSource;

/** Aplica o tenant da requisição na conexão, para a policy de RLS de operador. */
public class TenantConnectionInterceptor extends DelegatingDataSource {

    public TenantConnectionInterceptor(DataSource hikari) {
        super(hikari);
    }

    @Override
    public Connection getConnection() throws SQLException {
        Connection conn = super.getConnection();
        try (Statement st = conn.createStatement()) {
            st.execute("SET app.tenant_id = '" + TenantContext.current() + "'");
        }
        return conn;
    }
}
