import { calcularTarifa } from '../application/calcular-tarifa';

export class TarifaController {
  registrar() {
    return { rota: 'POST /tarifas/calculo', handler: calcularTarifa };
  }
}
