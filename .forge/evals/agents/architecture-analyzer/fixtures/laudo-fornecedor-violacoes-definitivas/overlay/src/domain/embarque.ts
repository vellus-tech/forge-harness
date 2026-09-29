import { publicar } from '../infrastructure/mqtt-publisher';
import { EmbarqueRegistrado } from '../contracts/eventos-embarque';

export class Embarque {
  private constructor(public readonly cartaoId: string, public readonly linha: string, public readonly aprovado: boolean) {}
  static registrar(cartaoId: string, linha: string, saldoCentavos: number) {
    const e = new Embarque(cartaoId, linha, saldoCentavos >= 520);
    const evento: EmbarqueRegistrado = { tipo: 'EmbarqueRegistrado', cartaoId, linha, aprovado: e.aprovado };
    publicar('embarques', evento);
    return e;
  }
}
