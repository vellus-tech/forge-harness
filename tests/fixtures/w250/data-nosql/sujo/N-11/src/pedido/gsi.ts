const r = await client.send(new QueryCommand({ TableName: "pedidos", IndexName: "por-cliente", ConsistentRead: true }));
