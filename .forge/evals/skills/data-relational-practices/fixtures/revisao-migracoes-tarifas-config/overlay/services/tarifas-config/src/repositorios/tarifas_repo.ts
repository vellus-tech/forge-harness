import { Pool } from 'pg';

export class TarifasRepositorio {
  constructor(private readonly pool: Pool) {}

  async listar(tenantId: string, limite: number, offset: number) {
    const client = await this.pool.connect();
    try {
      await client.query("SELECT set_config('app.tenant_id', $1, false)", [tenantId]);
      const r = await client.query(
        'SELECT * FROM tarifas ORDER BY vigente_desde DESC LIMIT $1 OFFSET $2',
        [limite, offset],
      );
      return r.rows;
    } finally {
      client.release();
    }
  }
}
