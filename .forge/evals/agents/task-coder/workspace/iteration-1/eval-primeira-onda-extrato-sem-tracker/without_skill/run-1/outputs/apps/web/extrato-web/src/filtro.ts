import type { Lancamento } from './lancamento.ts';

export function filtrarPorPeriodo(lancamentos: Lancamento[], inicio: string, fim: string): Lancamento[] {
  if (inicio > fim) {
    throw new RangeError(`inicio (${inicio}) não pode ser posterior a fim (${fim})`);
  }
  return lancamentos.filter((l) => l.data >= inicio && l.data <= fim);
}
