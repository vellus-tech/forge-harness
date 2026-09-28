export function formatarCentavos(valor: number): string {
  return `R$ ${(valor / 100).toFixed(2).replace(".", ",")}`;
}
