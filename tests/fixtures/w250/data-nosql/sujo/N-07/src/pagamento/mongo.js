await col.insertOne(doc, { writeConcern: { w: 1 } });
