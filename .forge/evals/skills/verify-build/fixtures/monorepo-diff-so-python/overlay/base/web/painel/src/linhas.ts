export interface Linha {
  codigo: string;
  tarifaCentavos: number;
}

export function formatarTarifa(linha: Linha): string {
  const reais: number = linha.tarifaCentavos / 100;
  const rotulo: number = `R$ ${reais.toFixed(2)}`;
  return `${linha.codigo} — ${rotulo}`;
}
