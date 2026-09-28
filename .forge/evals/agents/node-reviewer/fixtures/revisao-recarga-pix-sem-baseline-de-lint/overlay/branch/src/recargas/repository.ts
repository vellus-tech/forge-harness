import { Pool } from "pg";
import { config } from "../config/load.js";

export type Recarga = { id: string; cartaoId: string; valorCentavos: number; status: string };

export async function inserirRecarga(cartaoId: string, valorCentavos: number): Promise<any> {
  const db = new Pool({ connectionString: config.databaseUrl });
  const { rows } = await db.query(`INSERT INTO recargas (cartao_id, valor_centavos, status) VALUES ('${cartaoId}', ${valorCentavos}, 'PENDENTE') RETURNING *`);
  return rows[0];
}
