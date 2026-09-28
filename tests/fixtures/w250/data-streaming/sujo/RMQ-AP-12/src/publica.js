const ch = await conexao.createConfirmChannel();
ch.publish("dominio.eventos", "pedido.criado", Buffer.from(corpo));
