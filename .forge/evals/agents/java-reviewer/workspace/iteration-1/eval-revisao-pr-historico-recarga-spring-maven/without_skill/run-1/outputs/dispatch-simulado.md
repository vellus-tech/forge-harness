# Despacho de subagente (simulado, nao executado)

Nenhum subagente foi de fato spawnado nesta run (proibido pelas regras do eval).
Se pudesse delegar, o despacho seria:

- agente: java-reviewer (ou um analogo de revisao de codigo Java)
- modelo: sonnet
- prompt resumido: "Revisar o diff develop..HEAD do modulo bilhetagem-recarga (Spring Boot 3 / Maven / JdbcClient / Flyway / Postgres), focado no endpoint POST /api/v1/recargas, no GET /api/v1/cartoes/{cartaoId}/recargas e na migration V7 que renomeia recarga.valor para valor_centavos; gravar findings em .forge/reviews/java-reviewer.json com arquivo, linha, cenario e severidade."

Como este e o proprio caso `without_skill`, a revisao foi executada diretamente pela sessao corrente, sem delegacao, usando apenas conhecimento proprio de Java/Spring/JDBC/SQL.
