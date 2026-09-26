MATCH (a:Conta)-[:TRANSFERIU_PARA]->(b:Conta) RETURN a, b;
MATCH (c:Cliente)-[:HAS_ACCOUNT]->(d:Conta) RETURN c, d;
