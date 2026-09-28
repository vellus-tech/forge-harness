const OFFSET_PADRAO = 20;
const topo = elemento.offsetTop;
const linhas = await db.query("SELECT id, total FROM pedido WHERE id > $1 ORDER BY id LIMIT 50", [ultimoId]);
