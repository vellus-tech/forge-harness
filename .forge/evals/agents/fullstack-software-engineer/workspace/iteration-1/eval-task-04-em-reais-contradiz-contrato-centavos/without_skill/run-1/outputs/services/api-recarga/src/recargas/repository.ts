import type { Pool } from "pg";

export interface Recarga {
  id: string;
  cartaoId: string;
  valor: number;
  status: "PENDENTE" | "CONFIRMADA" | "FALHOU";
  criadaEm: string;
}

export interface NovaRecarga {
  cartaoId: string;
  valor: number;
}

export interface RecargaRepository {
  listByCartao(cartaoId: string, limit: number): Promise<Recarga[]>;
  create(input: NovaRecarga): Promise<Recarga>;
}

function toRecarga(r: {
  id: string;
  cartao_id: string;
  valor: string | number;
  status: string;
  criada_em: Date;
}): Recarga {
  return {
    id: r.id,
    cartaoId: r.cartao_id,
    // pg retorna NUMERIC como string para não perder precisão; convertemos para number
    // na borda do repositório, ciente do risco de arredondamento de ponto flutuante em
    // valores monetários (ver relatorio/task-04.md).
    valor: typeof r.valor === "string" ? Number(r.valor) : r.valor,
    status: r.status as Recarga["status"],
    criadaEm: r.criada_em.toISOString(),
  };
}

export function createPgRecargaRepository(pool: Pool): RecargaRepository {
  return {
    async listByCartao(cartaoId, limit) {
      const { rows } = await pool.query(
        "SELECT id, cartao_id, valor, status, criada_em FROM recargas WHERE cartao_id = $1 ORDER BY criada_em DESC LIMIT $2",
        [cartaoId, limit],
      );
      return rows.map(toRecarga);
    },
    async create({ cartaoId, valor }) {
      const { rows } = await pool.query(
        "INSERT INTO recargas (id, cartao_id, valor, status) VALUES (gen_random_uuid(), $1, $2, 'PENDENTE') RETURNING id, cartao_id, valor, status, criada_em",
        [cartaoId, valor],
      );
      return toRecarga(rows[0]);
    },
  };
}
