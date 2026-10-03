import type { Lancamento } from './lancamento.ts';

/**
 * Filtra lançamentos por intervalo de datas fechado [inicio, fim] (ISO YYYY-MM-DD).
 * Função pura: não acessa rede nem armazenamento, e não muta a entrada (Req 1.1, Req 1.2, Req 1.3).
 */
export function filtrarPorPeriodo(lancamentos: Lancamento[], inicio: string, fim: string): Lancamento[] {
  if (inicio > fim) {
    throw new RangeError(`inicio (${inicio}) não pode ser posterior a fim (${fim})`);
  }
  return lancamentos.filter((l) => l.data >= inicio && l.data <= fim);
}
