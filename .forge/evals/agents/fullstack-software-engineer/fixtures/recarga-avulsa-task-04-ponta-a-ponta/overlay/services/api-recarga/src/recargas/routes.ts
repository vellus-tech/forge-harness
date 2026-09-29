import { Router } from "express";
import { z } from "zod";
import type { RecargaRepository } from "./repository.js";

const listQuery = z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) });

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

  return router;
}
