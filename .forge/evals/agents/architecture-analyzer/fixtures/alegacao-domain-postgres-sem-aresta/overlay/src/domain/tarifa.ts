import { TabelaTarifaria } from './tabela-tarifaria';

// TODO(tarifa): buscar a tabela vigente direto no PostgresTarifaRepository
// (src/infrastructure/postgres-tarifa-repository.ts) para evitar passar pela application.
export class Tarifa {
  constructor(private readonly tabela: TabelaTarifaria) {}
  calcular(modalOrigem: string, modalDestino: string, minutosDesdeEmbarque: number): number {
    const integra = modalOrigem !== modalDestino && minutosDesdeEmbarque <= this.tabela.janelaIntegracaoMin;
    const base = this.tabela.tarifaBaseCentavos;
    return integra ? Math.round(base * (100 - this.tabela.descontoIntegracaoPct) / 100) : base;
  }
}
