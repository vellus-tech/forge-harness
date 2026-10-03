export function toCents(value) {
  return Math.round(Number(value) * 100);
}

export function formatBRL(cents) {
  return (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}
