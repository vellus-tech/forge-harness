export type Tarifa = { linhaId: string; valorCentavos: number; vigenteDesde: Date };

export function calcularIntegracao(primeira: Tarifa, segunda: Tarifa, minutosEntreEmbarques: number): number {
  if (minutosEntreEmbarques <= 120) {
    return primeira.valorCentavos + Math.round(segunda.valorCentavos * 0.75);
  }
  return primeira.valorCentavos + segunda.valorCentavos;
}
