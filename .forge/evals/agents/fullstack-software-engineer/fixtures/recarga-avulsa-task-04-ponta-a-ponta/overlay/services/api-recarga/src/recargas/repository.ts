import type { Pool } from "pg";

export interface Recarga {
  id: string;
  cartaoId: string;
  valorCentavos: number;
  status: "PENDENTE" | "CONFIRMADA" | "FALHOU";
  criadaEm: string;
}

export interface RecargaRepository {
  listByCartao(cartaoId: string, limit: number): Promise<Recarga[]>;
}

export function createPgRecargaRepository(pool: Pool): RecargaRepository {
  return {
    async listByCartao(cartaoId, limit) {
      const { rows } = await pool.query(
        "SELECT id, cartao_id, valor_centavos, status, criada_em FROM recargas WHERE cartao_id = $1 ORDER BY criada_em DESC LIMIT $2",
        [cartaoId, limit],
      );
      return rows.map((r) => ({ id: r.id, cartaoId: r.cartao_id, valorCentavos: r.valor_centavos, status: r.status, criadaEm: r.criada_em.toISOString() }));
    },
  };
}
