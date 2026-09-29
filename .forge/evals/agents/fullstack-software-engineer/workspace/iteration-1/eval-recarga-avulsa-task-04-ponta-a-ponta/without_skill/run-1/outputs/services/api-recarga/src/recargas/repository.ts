import type { Pool } from "pg";

export interface Recarga {
  id: string;
  cartaoId: string;
  valorCentavos: number;
  status: "PENDENTE" | "CONFIRMADA" | "FALHOU";
  criadaEm: string;
}

export interface NovaRecarga {
  cartaoId: string;
  valorCentavos: number;
  idempotencyKey: string;
}

export interface CreateRecargaResult {
  recarga: Recarga;
  created: boolean;
}

export interface RecargaRepository {
  listByCartao(cartaoId: string, limit: number): Promise<Recarga[]>;
  createRecarga(input: NovaRecarga): Promise<CreateRecargaResult>;
}

function toRecarga(r: {
  id: string;
  cartao_id: string;
  valor_centavos: number;
  status: string;
  criada_em: Date;
}): Recarga {
  return {
    id: r.id,
    cartaoId: r.cartao_id,
    valorCentavos: r.valor_centavos,
    status: r.status as Recarga["status"],
    criadaEm: r.criada_em.toISOString(),
  };
}

export function createPgRecargaRepository(pool: Pool): RecargaRepository {
  return {
    async listByCartao(cartaoId, limit) {
      const { rows } = await pool.query(
        "SELECT id, cartao_id, valor_centavos, status, criada_em FROM recargas WHERE cartao_id = $1 ORDER BY criada_em DESC LIMIT $2",
        [cartaoId, limit],
      );
      return rows.map(toRecarga);
    },

    async createRecarga({ cartaoId, valorCentavos, idempotencyKey }) {
      const inserted = await pool.query(
        `INSERT INTO recargas (id, cartao_id, valor_centavos, status, idempotency_key)
         VALUES (gen_random_uuid(), $1, $2, 'PENDENTE', $3)
         ON CONFLICT (idempotency_key) DO NOTHING
         RETURNING id, cartao_id, valor_centavos, status, criada_em`,
        [cartaoId, valorCentavos, idempotencyKey],
      );
      if (inserted.rows.length > 0) {
        return { recarga: toRecarga(inserted.rows[0]), created: true };
      }
      const existing = await pool.query(
        "SELECT id, cartao_id, valor_centavos, status, criada_em FROM recargas WHERE idempotency_key = $1",
        [idempotencyKey],
      );
      return { recarga: toRecarga(existing.rows[0]), created: false };
    },
  };
}
