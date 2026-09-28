import { Router } from "express";
import { readFileSync } from "node:fs";
import { pool } from "./db.js";
import { PedidoHelper } from "./PedidoHelper.js";

export const rotas = Router();

rotas.get("/pedidos/:id", async (req, res) => {
  const r = await pool.query("SELECT * FROM pedidos WHERE id = $1", [req.params.id]);
  res.json(r.rows[0] ?? null);
});

rotas.get("/pedidos", async (req, res) => {
  const status = String(req.query.status ?? "aberto");
  const r = await pool.query(`SELECT * FROM pedidos WHERE status = '${status}' ORDER BY criado_em DESC`);
  res.json(r.rows);
});

rotas.get("/pedidos/:id/nota", async (req, res) => {
  const layout = readFileSync("./layouts/nota-fiscal.html", "utf8");
  res.send(PedidoHelper.renderNota(layout, req.params.id));
});
