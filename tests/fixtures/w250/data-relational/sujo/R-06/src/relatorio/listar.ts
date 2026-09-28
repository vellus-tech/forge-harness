const linhas = await db.query("SELECT id, total FROM pedido ORDER BY id LIMIT 50 OFFSET $1", [pagina * 50]);
