import { SolicitarRecarga } from '../application/solicitar-recarga';
import { logger } from '../shared/logger';

export class RecargaController {
  constructor(private readonly repo: unknown) {}
  async post(body: { cartaoId: string; valorCentavos: number }) {
    logger.info('POST /recargas', { cartaoId: body.cartaoId });
    return new SolicitarRecarga(this.repo as never).executar(body.cartaoId, body.valorCentavos);
  }
}
