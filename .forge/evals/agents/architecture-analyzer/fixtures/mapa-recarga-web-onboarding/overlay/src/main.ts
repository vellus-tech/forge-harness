import { RecargaController } from './api/recarga-controller';
import { CartaoRepository } from './infrastructure/cartao-repository';
import { logger } from './shared/logger';

const controller = new RecargaController(new CartaoRepository());
logger.info('recarga-web iniciado', { controller: controller.constructor.name });
