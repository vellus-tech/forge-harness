import { VALOR_MINIMO_CENTAVOS } from "./index.js";

export class RecargaService {
  validarValor(valorCentavos) {
    if (!Number.isInteger(valorCentavos)) throw new Error("valor deve ser inteiro em centavos");
    if (valorCentavos < VALOR_MINIMO_CENTAVOS) throw new Error("valor abaixo do mínimo");
    return true;
  }
}
