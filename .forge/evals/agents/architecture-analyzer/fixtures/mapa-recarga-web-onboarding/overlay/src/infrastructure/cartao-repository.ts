import { Cartao } from '../domain/cartao';
import { query } from './db/postgres-client';
import { logger } from '../shared/logger';

export class CartaoRepository {
  async buscar(id: string): Promise<Cartao | null> {
    const rows = (await query('SELECT id, saldo FROM cartao WHERE id = $1', [id])) as Array<{ id: string; saldo: number }>;
    logger.info('cartao buscado', { id, achou: rows.length > 0 });
    return rows[0] ? new Cartao(rows[0].id, rows[0].saldo) : null;
  }
}
