import type { TarifaRepository } from "../dominio/tarifa-repository.js";
import { calcularIntegracao } from "../dominio/tarifa.js";

export async function cotarIntegracao(repo: TarifaRepository, linhaA: string, linhaB: string, minutos: number, em: Date): Promise<number> {
  const [a, b] = await Promise.all([repo.buscarVigente(linhaA, em), repo.buscarVigente(linhaB, em)]);
  if (!a || !b) throw new Error("tarifa vigente não encontrada");
  return calcularIntegracao(a, b, minutos);
}
