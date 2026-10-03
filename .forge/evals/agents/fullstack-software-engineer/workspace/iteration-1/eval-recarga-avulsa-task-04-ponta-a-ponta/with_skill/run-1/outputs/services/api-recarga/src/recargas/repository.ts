import { randomUUID } from "node:crypto";
import type { Pool } from "pg";

export interface Recarga {
  id: string;
  cartaoId: string;
  valorCentavos: number;
  status: "PENDENTE" | "CONFIRMADA" | "FALHOU";
  criadaEm: string;
}

export interface CreateRecargaInput {
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
  create(input: CreateRecargaInput): Promise<CreateRecargaResult>;
}

function toRecarga(row: {
  id: string;
  cartao_id: string;
  valor_centavos: number;
  status: Recarga["status"];
  criada_em: Date;
}): Recarga {
  return {
    id: row.id,
    cartaoId: row.cartao_id,
    valorCentavos: row.valor_centavos,
    status: row.status,
    criadaEm: row.criada_em.toISOString(),
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

    async create({ cartaoId, valorCentavos, idempotencyKey }) {
      // REQ-03 / DD-002: unicidade garantida pela constraint em `idempotency_key`
      // (migration 002), não por checagem em memória — segura sob concorrência
      // (duplo clique, retry de rede simultâneo).
      const inserted = await pool.query(
        `INSERT INTO recargas (id, cartao_id, valor_centavos, status, idempotency_key)
         VALUES ($1, $2, $3, 'PENDENTE', $4)
         ON CONFLICT (idempotency_key) DO NOTHING
         RETURNING id, cartao_id, valor_centavos, status, criada_em`,
        [randomUUID(), cartaoId, valorCentavos, idempotencyKey],
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
