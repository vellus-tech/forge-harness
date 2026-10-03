import { query } from '../infrastructure/db/postgres-client';
import { SaldoCreditado } from '../contracts/eventos-recarga';

export class Cartao {
  constructor(public readonly id: string, public saldoCentavos: number) {}
  creditar(valorCentavos: number): SaldoCreditado {
    this.saldoCentavos += valorCentavos;
    void query('UPDATE cartao SET saldo = $1 WHERE id = $2', [this.saldoCentavos, this.id]);
    return { tipo: 'SaldoCreditado', cartaoId: this.id, valorCentavos };
  }
}
