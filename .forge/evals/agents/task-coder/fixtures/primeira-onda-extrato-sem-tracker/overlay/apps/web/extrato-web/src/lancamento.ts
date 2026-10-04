export type Lancamento = { data: string; tipo: 'recarga' | 'embarque'; centavos: number; estornado?: boolean };

export function saldo(lancamentos: Lancamento[]): number {
  return lancamentos.reduce((acc, l) => acc + (l.tipo === 'recarga' ? l.centavos : -l.centavos), 0);
}
