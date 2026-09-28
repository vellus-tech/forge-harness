import express from "express";
import request from "supertest";
import { describe, expect, it } from "vitest";
import type { RecargaRepository } from "./repository.js";
import { recargaRoutes } from "./routes.js";

function appWith(repo: RecargaRepository) {
  const app = express();
  app.use(express.json());
  app.use(recargaRoutes(repo));
  return app;
}

describe("GET /recargas/:cartaoId", () => {
  it("rejeita limit fora da faixa", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [] };
    const res = await request(appWith(repo)).get("/recargas/C1?limit=500");
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_QUERY");
  });
});

function makeRecarga(overrides: Partial<import("./repository.js").Recarga> = {}) {
  return {
    id: "r1",
    cartaoId: "C1",
    valorCentavos: 1000,
    status: "PENDENTE" as const,
    criadaEm: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

describe("POST /recargas", () => {
  it("rejeita corpo sem Idempotency-Key", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], createRecarga: async () => ({ recarga: makeRecarga(), created: true }) };
    const res = await request(appWith(repo)).post("/recargas").send({ cartaoId: "C1", valorCentavos: 1000 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("MISSING_IDEMPOTENCY_KEY");
  });

  it("rejeita valorCentavos abaixo de 100", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], createRecarga: async () => ({ recarga: makeRecarga(), created: true }) };
    const res = await request(appWith(repo))
      .post("/recargas")
      .set("Idempotency-Key", "550e8400-e29b-41d4-a716-446655440000")
      .send({ cartaoId: "C1", valorCentavos: 50 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_BODY");
  });

  it("rejeita valorCentavos acima de 50000", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], createRecarga: async () => ({ recarga: makeRecarga(), created: true }) };
    const res = await request(appWith(repo))
      .post("/recargas")
      .set("Idempotency-Key", "550e8400-e29b-41d4-a716-446655440000")
      .send({ cartaoId: "C1", valorCentavos: 50001 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_BODY");
  });

  it("cria a recarga e devolve 201 na primeira tentativa", async () => {
    let calls = 0;
    const repo: RecargaRepository = {
      listByCartao: async () => [],
      createRecarga: async () => {
        calls += 1;
        return { recarga: makeRecarga({ valorCentavos: 2000 }), created: true };
      },
    };
    const res = await request(appWith(repo))
      .post("/recargas")
      .set("Idempotency-Key", "550e8400-e29b-41d4-a716-446655440000")
      .send({ cartaoId: "C1", valorCentavos: 2000 });
    expect(res.status).toBe(201);
    expect(res.body.valorCentavos).toBe(2000);
    expect(calls).toBe(1);
  });

  it("devolve 200 com a recarga já existente quando a Idempotency-Key é reenviada", async () => {
    const repo: RecargaRepository = {
      listByCartao: async () => [],
      createRecarga: async () => ({ recarga: makeRecarga(), created: false }),
    };
    const res = await request(appWith(repo))
      .post("/recargas")
      .set("Idempotency-Key", "550e8400-e29b-41d4-a716-446655440000")
      .send({ cartaoId: "C1", valorCentavos: 1000 });
    expect(res.status).toBe(200);
    expect(res.body.id).toBe("r1");
  });
});
