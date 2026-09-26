await col.updateOne({ _id: id }, { $push: { itens: { $each: [item], $slice: -100 } } });
await col.insertOne(doc, { writeConcern: { w: "majority" } });
const fluxo = { flow: 1 };
const cfg = { w: 10 };
