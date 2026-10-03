import type { Cobranca } from "../src/domain/CobrancaRepository.js";

export function repoEmMemoria(inicial: Cobranca[] = []) {
  const dados = new Map(inicial.map((c) => [c.id, c]));
  return {
    async buscar(id: string) { return dados.get(id) ?? null; },
    async marcarPaga(id: string) { const c = dados.get(id); if (c) c.status = "paga"; },
  };
}
