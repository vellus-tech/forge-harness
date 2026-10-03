import { getTarifa } from './api/tarifa-controller';
import { postBilhete } from './api/bilhete-controller';
export const rotas = { 'GET /tarifa': getTarifa, 'POST /bilhete': postBilhete };
