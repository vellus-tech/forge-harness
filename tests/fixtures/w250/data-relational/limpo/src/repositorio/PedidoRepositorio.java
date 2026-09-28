String sql = "SELECT id, total FROM pedido WHERE id = ?";
int quantidade = contar("SELECT count(*) FROM pedido");
