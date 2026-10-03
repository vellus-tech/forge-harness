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
  /** true quando a Idempotency-Key já existia e a recarga original foi devolvida (DD-002: HTTP 200). */
  alreadyExisted: boolean;
}

export interface RecargaRepository {
  listByCartao(cartaoId: string, limit: number): Promise<Recarga[]>;
  create(input: CreateRecargaInput): Promise<CreateRecargaResult>;
}

function toRecarga(r: {
  id: string;
  cartao_id: string;
  valor_centavos: number;
  status: Recarga["status"];
  criada_em: Date;
}): Recarga {
  return { id: r.id, cartaoId: r.cartao_id, valorCentavos: r.valor_centavos, status: r.status, criadaEm: r.criada_em.toISOString() };
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
      // DD-002: unicidade por constraint no banco (uq_recargas_idempotency_key), não por
      // checagem em memória — evita corrida entre duplo clique e retry de rede (REQ-03).
      const inserted = await pool.query(
        `INSERT INTO recargas (id, cartao_id, valor_centavos, status, idempotency_key)
         VALUES (gen_random_uuid(), $1, $2, 'PENDENTE', $3)
         ON CONFLICT (idempotency_key) DO NOTHING
         RETURNING id, cartao_id, valor_centavos, status, criada_em`,
        [cartaoId, valorCentavos, idempotencyKey],
      );
      if (inserted.rows[0]) {
        return { recarga: toRecarga(inserted.rows[0]), alreadyExisted: false };
      }
      const existing = await pool.query(
        "SELECT id, cartao_id, valor_centavos, status, criada_em FROM recargas WHERE idempotency_key = $1",
        [idempotencyKey],
      );
      const row = existing.rows[0];
      if (!row) {
        // Corrida extrema: o INSERT concorrente ainda não commitou quando lemos. Não deveria
        // acontecer em uso normal (mesma transação/estatement), mas falha explícita > dado incoerente.
        throw new Error(`idempotency_key ${idempotencyKey} colidiu mas a linha não foi encontrada`);
      }
      return { recarga: toRecarga(row), alreadyExisted: true };
    },
  };
}
