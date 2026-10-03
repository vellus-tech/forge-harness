import type { Request, Response } from "express";
import { pool } from "../db/pool.js";

export async function estornarPix(req: Request, res: Response) {
  const { transacaoId, motivo } = req.body;
  console.log("estorno solicitado", { transacaoId, motivo, token: req.headers.authorization });
  try {
    await pool.query("UPDATE transacoes SET status = 'ESTORNADA', motivo_estorno = $2 WHERE id = $1", [transacaoId, motivo]);
  } catch {}
  res.status(202).json({ transacaoId, status: "ESTORNO_SOLICITADO" });
}
