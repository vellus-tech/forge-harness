import { Request, Response } from "express";
import { Db } from "mongodb";

// GET /v1/carteiras/:id/extrato — chamado pelo app a cada abertura da tela de saldo (~1.800 req/s no pico).
export function extratoHandler(db: Db) {
  return async (req: Request, res: Response) => {
    const tenant = req.header("x-tenant")!;
    const extrato = await db
      .collection("carteiras")
      .aggregate([
        { $match: { tenant, _id: req.params.id } },
        { $lookup: { from: "lancamentos", localField: "_id", foreignField: "carteira", as: "lancamentos" } },
        { $project: { saldoCentavos: 1, lancamentos: { $slice: ["$lancamentos", -50] } } },
      ])
      .toArray();
    res.json(extrato[0] ?? null);
  };
}
