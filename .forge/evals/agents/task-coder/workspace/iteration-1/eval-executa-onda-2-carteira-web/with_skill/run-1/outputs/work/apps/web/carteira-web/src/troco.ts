export function calcularTroco(pagoCentavos: number, tarifaCentavos: number): number {
  if (!Number.isInteger(pagoCentavos) || !Number.isInteger(tarifaCentavos)) {
    throw new TypeError('valores devem ser inteiros em centavos');
  }
  if (pagoCentavos < tarifaCentavos) {
    throw new RangeError('valor pago menor que a tarifa');
  }
  return pagoCentavos - tarifaCentavos;
}
