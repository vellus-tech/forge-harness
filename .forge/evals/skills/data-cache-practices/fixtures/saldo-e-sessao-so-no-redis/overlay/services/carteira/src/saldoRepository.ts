import { createClient } from "redis";
import { pool } from "./pg";

export const redis = createClient({ url: process.env.REDIS_URL });

const TTL_SALDO_S = 60;

// Saldo do cartão transporte em centavos. Fonte da verdade: tabela carteira.saldo no PostgreSQL.
export async function lerSaldo(tenantId: string, cartaoId: string): Promise<number> {
  const chave = `tenant:${tenantId}:saldo:${cartaoId}`;
  const emCache = await redis.get(chave);
  if (emCache !== null) return Number(emCache);
  const { rows } = await pool.query(
    "SELECT saldo_centavos FROM carteira.saldo WHERE tenant_id = $1 AND cartao_id = $2",
    [tenantId, cartaoId],
  );
  const saldo = rows[0]?.saldo_centavos ?? 0;
  await redis.set(chave, String(saldo), { EX: TTL_SALDO_S });
  return saldo;
}

export async function debitar(tenantId: string, cartaoId: string, valorCentavos: number): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      "UPDATE carteira.saldo SET saldo_centavos = saldo_centavos - $3 WHERE tenant_id = $1 AND cartao_id = $2 AND saldo_centavos >= $3",
      [tenantId, cartaoId, valorCentavos],
    );
    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
  await redis.del(`tenant:${tenantId}:saldo:${cartaoId}`);
}
