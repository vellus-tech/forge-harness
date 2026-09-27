await session.withTransaction(async () => { await col.insertOne(doc, { session }); }, { readConcern: { level: "local" }, writeConcern: { w: "majority" } });
