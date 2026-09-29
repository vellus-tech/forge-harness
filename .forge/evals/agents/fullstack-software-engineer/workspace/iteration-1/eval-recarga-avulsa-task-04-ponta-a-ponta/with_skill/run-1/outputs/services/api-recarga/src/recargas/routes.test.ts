import express from "express";
import request from "supertest";
import { describe, expect, it, vi } from "vitest";
import type { CreateRecargaResult, Recarga, RecargaRepository } from "./repository.js";
import { recargaRoutes } from "./routes.js";

function appWith(repo: RecargaRepository) {
  const app = express();
  app.use(express.json());
  app.use(recargaRoutes(repo));
  return app;
}

function notImplementedCreate(): Promise<CreateRecargaResult> {
  throw new Error("create não deveria ser chamado neste teste");
}

const RECARGA_EXEMPLO: Recarga = {
  id: "b6f6c1b2-2f8d-4a3d-8c1d-6a2d3d8e0f10",
  cartaoId: "C1",
  valorCentavos: 5000,
  status: "PENDENTE",
  criadaEm: "2026-09-26T12:00:00.000Z",
};

describe("GET /recargas/:cartaoId", () => {
  it("rejeita limit fora da faixa", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], create: notImplementedCreate };
    const res = await request(appWith(repo)).get("/recargas/C1?limit=500");
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_QUERY");
  });
});

describe("POST /recargas", () => {
  it("rejeita quando o header Idempotency-Key está ausente", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], create: notImplementedCreate };
    const res = await request(appWith(repo)).post("/recargas").send({ cartaoId: "C1", valorCentavos: 5000 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("MISSING_IDEMPOTENCY_KEY");
  });

  it("rejeita valor abaixo de R$ 1,00", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], create: notImplementedCreate };
    const res = await request(appWith(repo))
      .post("/recargas")
      .set("Idempotency-Key", "11111111-1111-1111-1111-111111111111")
      .send({ cartaoId: "C1", valorCentavos: 50 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_BODY");
  });

  it("rejeita valor acima de R$ 500,00", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], create: notImplementedCreate };
    const res = await request(appWith(repo))
      .post("/recargas")
      .set("Idempotency-Key", "11111111-1111-1111-1111-111111111111")
      .send({ cartaoId: "C1", valorCentavos: 50001 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_BODY");
  });

  it("cria a recarga e devolve 201 na primeira chamada com uma Idempotency-Key nova", async () => {
    const create = vi.fn(async (): Promise<CreateRecargaResult> => ({ recarga: RECARGA_EXEMPLO, created: true }));
    const repo: RecargaRepository = { listByCartao: async () => [], create };
    const res = await request(appWith(repo))
      .post("/recargas")
      .set("Idempotency-Key", "11111111-1111-1111-1111-111111111111")
      .send({ cartaoId: "C1", valorCentavos: 5000 });
    expect(res.status).toBe(201);
    expect(res.body).toEqual(RECARGA_EXEMPLO);
    expect(create).toHaveBeenCalledWith({
      cartaoId: "C1",
      valorCentavos: 5000,
      idempotencyKey: "11111111-1111-1111-1111-111111111111",
    });
  });

  it("reenvio com a mesma Idempotency-Key devolve 200 e não cria segunda recarga (REQ-03)", async () => {
    const create = vi.fn(async (): Promise<CreateRecargaResult> => ({ recarga: RECARGA_EXEMPLO, created: false }));
    const repo: RecargaRepository = { listByCartao: async () => [], create };
    const res = await request(appWith(repo))
      .post("/recargas")
      .set("Idempotency-Key", "11111111-1111-1111-1111-111111111111")
      .send({ cartaoId: "C1", valorCentavos: 5000 });
    expect(res.status).toBe(200);
    expect(res.body).toEqual(RECARGA_EXEMPLO);
  });
});
