import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { pool } from "../db/client.js";

const Params = z.object({ id: z.string().uuid() });

export async function paymentsRoutes(app: FastifyInstance) {
  app.get("/payments/:id", async (req, reply) => {
    const { id } = Params.parse(req.params);
    const merchantId = req.headers["x-merchant-id"];
    const { rows } = await pool.query(
      "SELECT id, amount_cents, status FROM payments WHERE id = $1 AND merchant_id = $2",
      [id, merchantId],
    );
    if (rows.length === 0) return reply.code(404).send({ error: "not_found" });
    return rows[0];
  });
}
