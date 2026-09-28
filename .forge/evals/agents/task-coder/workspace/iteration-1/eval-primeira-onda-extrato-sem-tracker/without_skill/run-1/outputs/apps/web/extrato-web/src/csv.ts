import type { Lancamento } from './lancamento.ts';

const CABECALHO = ['data', 'tipo', 'centavos'].join(';');

export function exportarCsv(lancamentos: Lancamento[]): string {
  const linhas = lancamentos.map((l) => [l.data, l.tipo, String(l.centavos)].join(';'));
  return [CABECALHO, ...linhas].join('\n');
}
