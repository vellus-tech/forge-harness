ch.publish("dominio.eventos", "pedido.criado", Buffer.from(corpo), { persistent: true });
