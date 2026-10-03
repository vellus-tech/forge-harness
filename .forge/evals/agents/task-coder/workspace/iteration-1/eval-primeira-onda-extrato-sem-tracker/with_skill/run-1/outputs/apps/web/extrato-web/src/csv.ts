import type { Lancamento } from './lancamento.ts';

/**
 * Exporta lançamentos em CSV com separador ';' e valores em centavos (Req 2.1).
 * Função pura: não acessa rede nem armazenamento.
 */
export function exportarCsv(lancamentos: Lancamento[]): string {
  const cabecalho = 'data;tipo;centavos';
  const linhas = lancamentos.map((l) => `${l.data};${l.tipo};${l.centavos}`);
  return [cabecalho, ...linhas].join('\n');
}
