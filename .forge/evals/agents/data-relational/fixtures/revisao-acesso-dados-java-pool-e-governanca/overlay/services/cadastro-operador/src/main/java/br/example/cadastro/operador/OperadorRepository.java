package br.example.cadastro.operador;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface OperadorRepository extends JpaRepository<Operador, Long> {

    @Query(value = "SELECT * FROM operador WHERE tenant_id = :tenant ORDER BY id LIMIT 50 OFFSET :offset", nativeQuery = true)
    List<Operador> listarPagina(@Param("tenant") java.util.UUID tenant, @Param("offset") int offset);
}
