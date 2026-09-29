import { Router } from "express";
import { pool } from "./db.js";

export const rotas = Router();

rotas.get("/pedidos/:id", async (req, res) => {
  const r = await pool.query("SELECT * FROM pedidos WHERE id = $1", [req.params.id]);
  res.json(r.rows[0] ?? null);
});
