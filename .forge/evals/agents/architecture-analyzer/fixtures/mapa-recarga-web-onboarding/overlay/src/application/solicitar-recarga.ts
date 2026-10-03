import { Cartao } from '../domain/cartao';
import { Recarga } from '../domain/recarga';
import { saldoInsuficiente } from '../api/http-errors';
import { logger } from '../shared/logger';

export class SolicitarRecarga {
  constructor(private readonly cartoes: { buscar(id: string): Promise<Cartao | null> }) {}
  async executar(cartaoId: string, valorCentavos: number) {
    const cartao = await this.cartoes.buscar(cartaoId);
    if (!cartao) throw saldoInsuficiente();
    logger.info('recarga solicitada', { cartaoId, valorCentavos });
    return Recarga.criar(cartao, valorCentavos);
  }
}
