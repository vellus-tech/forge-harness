import { Router } from "express";
import { z } from "zod";
import type { RecargaRepository } from "./repository.js";

const listQuery = z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) });

// REQ-02: valor mínimo R$ 1,00 e máximo R$ 500,00. DD-001: sempre inteiro em centavos.
const VALOR_MIN_CENTAVOS = 100;
const VALOR_MAX_CENTAVOS = 50_000;

const createBody = z.object({
  cartaoId: z.string().min(1),
  valorCentavos: z.number().int().min(VALOR_MIN_CENTAVOS).max(VALOR_MAX_CENTAVOS),
});

const idempotencyKeyHeader = z.string().uuid();

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
    const key = idempotencyKeyHeader.safeParse(req.header("Idempotency-Key"));
    if (!key.success) {
      // DD-002: header obrigatório, gerado pelo cliente por tentativa de compra.
      return res.status(400).json({ code: "IDEMPOTENCY_KEY_REQUIRED", message: "Header Idempotency-Key (UUID) é obrigatório." });
    }

    const body = createBody.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json({
        code: "INVALID_VALOR",
        message: `O valor da recarga deve estar entre ${VALOR_MIN_CENTAVOS / 100} e ${VALOR_MAX_CENTAVOS / 100} reais.`,
      });
    }

    const { recarga, alreadyExisted } = await repo.create({
      cartaoId: body.data.cartaoId,
      valorCentavos: body.data.valorCentavos,
      idempotencyKey: key.data,
    });
    // DD-002: chave repetida devolve a recarga já criada com 200; primeira criação devolve 201.
    return res.status(alreadyExisted ? 200 : 201).json(recarga);
  });

  return router;
}
