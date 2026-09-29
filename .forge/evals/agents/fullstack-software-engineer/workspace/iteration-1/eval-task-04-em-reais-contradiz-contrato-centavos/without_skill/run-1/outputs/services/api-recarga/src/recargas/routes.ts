import { Router } from "express";
import { z } from "zod";
import type { RecargaRepository } from "./repository.js";

const listQuery = z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) });

// Valor em reais, com no máximo duas casas decimais (ex.: 25, 25.5, 25.50).
const novaRecargaBody = z.object({
  cartaoId: z.string().min(1),
  valor: z
    .number()
    .positive()
    .refine((v) => Number.isInteger(Math.round(v * 100)), {
      message: "valor deve ter no máximo duas casas decimais.",
    }),
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
    const parsed = novaRecargaBody.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ code: "INVALID_BODY", message: "Dados de recarga inválidos." });
    }
    const recarga = await repo.create(parsed.data);
    return res.status(201).json(recarga);
  });

  return router;
}
