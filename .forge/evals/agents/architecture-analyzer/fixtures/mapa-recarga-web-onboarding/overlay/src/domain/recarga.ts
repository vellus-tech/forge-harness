import { Cartao } from './cartao';
import { RecargaSolicitada } from '../contracts/eventos-recarga';

export class Recarga {
  private constructor(public readonly cartaoId: string, public readonly valorCentavos: number) {}
  static criar(cartao: Cartao, valorCentavos: number): RecargaSolicitada {
    if (valorCentavos <= 0 || valorCentavos > 50000) throw new Error('valor de recarga fora do limite');
    return { tipo: 'RecargaSolicitada', cartaoId: cartao.id, valorCentavos };
  }
}
