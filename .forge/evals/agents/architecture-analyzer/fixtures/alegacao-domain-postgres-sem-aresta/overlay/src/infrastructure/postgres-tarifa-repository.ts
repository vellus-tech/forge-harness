import { TabelaTarifaria } from '../domain/tabela-tarifaria';

export class PostgresTarifaRepository {
  async tabelaVigente(): Promise<TabelaTarifaria> {
    return { tarifaBaseCentavos: 520, descontoIntegracaoPct: 25, janelaIntegracaoMin: 120 };
  }
}
