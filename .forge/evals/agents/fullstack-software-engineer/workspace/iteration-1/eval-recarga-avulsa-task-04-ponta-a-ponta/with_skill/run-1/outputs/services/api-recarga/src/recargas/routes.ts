import { Router } from "express";
import { z } from "zod";
import type { RecargaRepository } from "./repository.js";

// REQ-02: faixa permitida para recarga avulsa é R$ 1,00 (100 centavos) a R$ 500,00 (50000 centavos).
const VALOR_MINIMO_CENTAVOS = 100;
const VALOR_MAXIMO_CENTAVOS = 50000;

const listQuery = z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) });

const createBody = z.object({
  cartaoId: z.string().min(1),
  valorCentavos: z.number().int().min(VALOR_MINIMO_CENTAVOS).max(VALOR_MAXIMO_CENTAVOS),
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
    // DD-002: Idempotency-Key é obrigatória e validada antes do corpo — é a fronteira
    // que garante que retry de rede/duplo clique não gere duas recargas (REQ-03).
    const idempotencyKey = req.header("Idempotency-Key");
    if (!idempotencyKey) {
      return res.status(400).json({ code: "MISSING_IDEMPOTENCY_KEY", message: "Header Idempotency-Key é obrigatório." });
    }

    const parsed = createBody.safeParse(req.body);
    if (!parsed.success) {
      return res
        .status(400)
        .json({ code: "INVALID_BODY", message: "Valor de recarga fora da faixa permitida (R$ 1,00 a R$ 500,00)." });
    }

    const { recarga, created } = await repo.create({
      cartaoId: parsed.data.cartaoId,
      valorCentavos: parsed.data.valorCentavos,
      idempotencyKey,
    });
    return res.status(created ? 201 : 200).json(recarga);
  });

  return router;
}
