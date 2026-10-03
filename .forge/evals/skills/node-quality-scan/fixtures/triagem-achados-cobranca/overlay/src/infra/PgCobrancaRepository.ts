import type { Pool } from "pg";
import type { Cobranca, CobrancaRepository } from "../domain/CobrancaRepository.js";

export class PgCobrancaRepository implements CobrancaRepository {
  constructor(private readonly pool: Pool) {}

  async buscar(id: string): Promise<Cobranca | null> {
    const r = await this.pool.query("SELECT id, valor_centavos, status FROM cobrancas WHERE id = $1", [id]);
    return r.rows[0] ?? null;
  }

  async marcarPaga(id: string): Promise<void> {
    await this.pool.query(`UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = '${id}'`);
  }
}
