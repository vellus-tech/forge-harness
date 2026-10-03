import { validarEmbarque } from '../application/validar-embarque';

export class ValidacaoController {
  registrar() {
    return { topico: 'validador/+/embarque', handler: validarEmbarque };
  }
}
