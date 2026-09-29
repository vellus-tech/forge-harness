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
    const repo: RecargaRepository = { listByCartao: async () => [], create: async () => { throw new Error("unused"); } };
    const res = await request(appWith(repo)).get("/recargas/C1?limit=500");
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_QUERY");
  });
});

describe("POST /recargas", () => {
  it("cria recarga com valor válido em reais", async () => {
    const repo: RecargaRepository = {
      listByCartao: async () => [],
      create: async ({ cartaoId, valor }) => ({
        id: "11111111-1111-1111-1111-111111111111",
        cartaoId,
        valor,
        status: "PENDENTE",
        criadaEm: new Date().toISOString(),
      }),
    };
    const res = await request(appWith(repo)).post("/recargas").send({ cartaoId: "C1", valor: 25.5 });
    expect(res.status).toBe(201);
    expect(res.body.valor).toBe(25.5);
    expect(res.body.status).toBe("PENDENTE");
  });

  it("rejeita valor com mais de duas casas decimais", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], create: async () => { throw new Error("unused"); } };
    const res = await request(appWith(repo)).post("/recargas").send({ cartaoId: "C1", valor: 25.555 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_BODY");
  });

  it("rejeita valor não positivo", async () => {
    const repo: RecargaRepository = { listByCartao: async () => [], create: async () => { throw new Error("unused"); } };
    const res = await request(appWith(repo)).post("/recargas").send({ cartaoId: "C1", valor: 0 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_BODY");
  });
});
