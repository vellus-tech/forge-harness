import type { Pool } from "pg";
import type { Tarifa } from "../dominio/tarifa.js";
import type { TarifaRepository } from "../dominio/tarifa-repository.js";

export class PgTarifaRepository implements TarifaRepository {
  constructor(private readonly pool: Pool) {}

  buscarVigente(linhaId: string, em: Date): Promise<Tarifa | null> {
    return this.pool
      .query("SELECT linha_id, valor_centavos, vigente_desde FROM tarifas WHERE linha_id = $1 AND vigente_desde <= $2 ORDER BY vigente_desde DESC LIMIT 1", [linhaId, em])
      .then((r) => (r.rows[0] ? { linhaId: r.rows[0].linha_id, valorCentavos: r.rows[0].valor_centavos, vigenteDesde: r.rows[0].vigente_desde } : null));
  }
}
