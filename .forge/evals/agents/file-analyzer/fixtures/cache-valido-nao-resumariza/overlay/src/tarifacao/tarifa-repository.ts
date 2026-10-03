import type { Pool } from 'pg';
import { Money } from '../shared/money';
import { Clock, relogioSistema } from '../shared/clock';
import { logger } from '../shared/logger';
import type { Tarifa, Modal } from './tarifa';
import type { Linha } from './linha';
import { pool as poolPadrao } from '../config/db-config';

type Row = { linha_id: string; modal: Modal; valor_centavos: number; vigente_desde: Date; vigente_ate: Date | null };

function paraTarifa(r: Row): Tarifa {
  return { linhaId: r.linha_id, modal: r.modal, valor: Money.deCentavos(r.valor_centavos), vigenteDesde: r.vigente_desde, vigenteAte: r.vigente_ate };
}

export class TarifaRepository {
  constructor(private readonly db: Pool = poolPadrao, private readonly clock: Clock = relogioSistema) {}

  async buscarVigente(linha: Pick<Linha, 'id'>, em: Date = this.clock.agora()): Promise<Tarifa | null> {
    const { rows } = await this.db.query<Row>(
      `SELECT linha_id, modal, valor_centavos, vigente_desde, vigente_ate FROM tarifas
        WHERE linha_id = $1 AND vigente_desde <= $2 AND (vigente_ate IS NULL OR vigente_ate > $2)
        ORDER BY vigente_desde DESC LIMIT 1`, [linha.id, em]);
    if (rows.length === 0) logger.warn({ linhaId: linha.id }, 'linha sem tarifa vigente');
    return rows[0] ? paraTarifa(rows[0]) : null;
  }

  async listarPorModal(modal: Modal): Promise<Tarifa[]> {
    const { rows } = await this.db.query<Row>(
      `SELECT linha_id, modal, valor_centavos, vigente_desde, vigente_ate FROM tarifas WHERE modal = $1 AND vigente_ate IS NULL`, [modal]);
    return rows.map(paraTarifa);
  }

  async encerrarVigencia(linhaId: string, ate: Date): Promise<void> {
    await this.db.query(`UPDATE tarifas SET vigente_ate = $2 WHERE linha_id = $1 AND vigente_ate IS NULL`, [linhaId, ate]);
  }
}
