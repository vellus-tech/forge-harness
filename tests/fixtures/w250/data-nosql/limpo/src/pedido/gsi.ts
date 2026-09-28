const r = await client.send(new QueryCommand({ TableName: "pedidos", IndexName: "por-cliente" }));
const item = await client.send(new GetItemCommand({ TableName: "pedidos", ConsistentRead: true }));
const proximo = scanner.next();
