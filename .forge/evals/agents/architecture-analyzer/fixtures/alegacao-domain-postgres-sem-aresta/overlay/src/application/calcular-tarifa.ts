import { Tarifa } from '../domain/tarifa';
import { PostgresTarifaRepository } from '../infrastructure/postgres-tarifa-repository';

export async function calcularTarifa(input: { modalOrigem: string; modalDestino: string; minutosDesdeEmbarque: number }) {
  const tabela = await new PostgresTarifaRepository().tabelaVigente();
  return new Tarifa(tabela).calcular(input.modalOrigem, input.modalDestino, input.minutosDesdeEmbarque);
}
