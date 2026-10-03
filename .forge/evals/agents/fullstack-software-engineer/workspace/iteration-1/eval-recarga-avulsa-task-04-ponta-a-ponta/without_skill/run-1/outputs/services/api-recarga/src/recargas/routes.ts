import { Router } from "express";
import { z } from "zod";
import type { RecargaRepository } from "./repository.js";

const listQuery = z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) });

const criarRecargaBody = z.object({
  cartaoId: z.string().min(1),
  valorCentavos: z.number().int().min(100).max(50000),
});

export function recargaRoutes(repo: RecargaRepository): Router {
  const router = Router();

  router.get("/recargas/:cartaoId", async (req, res) => {
    const parsed = listQuery.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ code: "INVALID_QUERY", message: "Parâmetros de consulta inválidos." });
    }
    const recargas = await repo.listByCartao(req.params.cartaoId, parsed.data.limit);
    return res.json({ items: recargas });
  });

  router.post("/recargas", async (req, res) => {
    const idempotencyKey = req.header("Idempotency-Key");
    if (!idempotencyKey) {
      return res.status(400).json({ code: "MISSING_IDEMPOTENCY_KEY", message: "Header Idempotency-Key é obrigatório." });
    }
    const parsed = criarRecargaBody.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ code: "INVALID_BODY", message: "Valor deve estar entre R$ 1,00 e R$ 500,00." });
    }
    const { recarga, created } = await repo.createRecarga({ ...parsed.data, idempotencyKey });
    return res.status(created ? 201 : 200).json(recarga);
  });

  return router;
}
