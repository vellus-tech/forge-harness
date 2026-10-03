export function formatarCentavos(centavos: number): string {
  if (!Number.isInteger(centavos)) throw new TypeError('valor deve ser inteiro em centavos');
  const sinal = centavos < 0 ? '-' : '';
  const abs = Math.abs(centavos);
  const reais = Math.floor(abs / 100).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `${sinal}R$ ${reais},${String(abs % 100).padStart(2, '0')}`;
}
