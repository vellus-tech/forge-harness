import express from "express";
import request from "supertest";
import { describe, expect, it } from "vitest";
import type { CreateRecargaResult, RecargaRepository } from "./repository.js";
import { recargaRoutes } from "./routes.js";

function appWith(repo: RecargaRepository) {
  const app = express();
  app.use(express.json());
  app.use(recargaRoutes(repo));
  return app;
}

function fakeRepo(overrides: Partial<RecargaRepository> = {}): RecargaRepository {
  return {
    listByCartao: async () => [],
    create: async () => ({
      recarga: { id: "R1", cartaoId: "C1", valorCentavos: 2550, status: "PENDENTE", criadaEm: "2026-09-20T00:00:00.000Z" },
      alreadyExisted: false,
    }),
    ...overrides,
  };
}

const VALID_KEY = "b3f1c2d4-5e6f-4a7b-8c9d-0e1f2a3b4c5d";

describe("GET /recargas/:cartaoId", () => {
  it("rejeita limit fora da faixa", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], create: fakeRepo().create };
    const res = await request(appWith(repo)).get("/recargas/C1?limit=500");
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_QUERY");
  });
});

describe("POST /recargas", () => {
  it("cria recarga com valor em centavos dentro da faixa e devolve 201 (REQ-02, DD-001)", async () => {
    const res = await request(appWith(fakeRepo()))
      .post("/recargas")
      .set("Idempotency-Key", VALID_KEY)
      .send({ cartaoId: "C1", valorCentavos: 2550 });
    expect(res.status).toBe(201);
    expect(res.body.valorCentavos).toBe(2550);
  });

  it("rejeita sem Idempotency-Key (DD-002)", async () => {
    const res = await request(appWith(fakeRepo()))
      .post("/recargas")
      .send({ cartaoId: "C1", valorCentavos: 2550 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("IDEMPOTENCY_KEY_REQUIRED");
  });

  it("rejeita valor abaixo de R$ 1,00 (REQ-02)", async () => {
    const res = await request(appWith(fakeRepo()))
      .post("/recargas")
      .set("Idempotency-Key", VALID_KEY)
      .send({ cartaoId: "C1", valorCentavos: 50 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_VALOR");
  });

  it("rejeita valor acima de R$ 500,00 (REQ-02)", async () => {
    const res = await request(appWith(fakeRepo()))
      .post("/recargas")
      .set("Idempotency-Key", VALID_KEY)
      .send({ cartaoId: "C1", valorCentavos: 50_001 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_VALOR");
  });

  it("chave repetida devolve a recarga já criada com 200, não uma nova (REQ-03, DD-002)", async () => {
    const create: CreateRecargaResult = {
      recarga: { id: "R1", cartaoId: "C1", valorCentavos: 2550, status: "PENDENTE", criadaEm: "2026-09-20T00:00:00.000Z" },
      alreadyExisted: true,
    };
    const repo = fakeRepo({ create: async () => create });
    const res = await request(appWith(repo))
      .post("/recargas")
      .set("Idempotency-Key", VALID_KEY)
      .send({ cartaoId: "C1", valorCentavos: 2550 });
    expect(res.status).toBe(200);
    expect(res.body.id).toBe("R1");
  });
});
