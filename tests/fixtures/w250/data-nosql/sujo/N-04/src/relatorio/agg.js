const r = await col.aggregate([{ $lookup: { from: "clientes", localField: "clienteId", foreignField: "_id", as: "cliente" } }]);
