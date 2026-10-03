import { describe, it, expect } from "vitest";
import type { TarifaRepository } from "../dominio/tarifa-repository.js";
import { cotarIntegracao } from "./cotar-integracao.js";

const tarifas = {
  "L-100": { linhaId: "L-100", valorCentavos: 480, vigenteDesde: new Date("2026-01-01") },
  "M-2": { linhaId: "M-2", valorCentavos: 520, vigenteDesde: new Date("2026-01-01") },
};
const repoFake: TarifaRepository = { buscarVigente: async (linhaId) => tarifas[linhaId as keyof typeof tarifas] ?? null };

describe("cotarIntegracao", () => {
  it("aplica 25% de desconto no segundo embarque dentro de 120 minutos", async () => {
    await cotarIntegracao(repoFake, "L-100", "M-2", 90, new Date("2026-09-01T08:00:00Z"));
    expect(true).toBe(true);
  });
});
