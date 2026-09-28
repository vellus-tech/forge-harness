// Split da tarifa integrada ônibus+metrô: 45% para a operadora de ônibus,
// 55% para o metrô, com o centavo residual do arredondamento indo para o metrô.
export function splitIntegratedFare(totalCents) {
  if (!Number.isInteger(totalCents) || totalCents < 0) {
    throw new Error('totalCents deve ser um inteiro não negativo (valor em centavos)');
  }

  // Multiplica antes de dividir (aritmética em inteiros até a divisão final)
  // para evitar erro de ponto flutuante de "totalCents * 0.45".
  const busCents = Math.floor((totalCents * 45) / 100);
  const metroCents = totalCents - busCents; // resíduo do arredondamento fica com o metrô

  return { busCents, metroCents };
}
