import type { Tarifa } from "./tarifa.js";

// Porta do domínio: a infraestrutura implementa (PgTarifaRepository); os testes usam fake em memória.
export interface TarifaRepository {
  buscarVigente(linhaId: string, em: Date): Promise<Tarifa | null>;
}
