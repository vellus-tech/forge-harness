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
