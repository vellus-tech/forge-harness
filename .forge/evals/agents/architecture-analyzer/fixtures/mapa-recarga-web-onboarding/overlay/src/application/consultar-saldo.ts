import { Cartao } from '../domain/cartao';
import { logger } from '../shared/logger';

export async function consultarSaldo(cartao: Cartao) {
  logger.info('consulta de saldo', { cartaoId: cartao.id });
  return cartao.saldoCentavos;
}
