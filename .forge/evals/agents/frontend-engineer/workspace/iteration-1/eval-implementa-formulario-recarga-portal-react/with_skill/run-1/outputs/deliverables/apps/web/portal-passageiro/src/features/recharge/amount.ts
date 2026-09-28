export const MIN_AMOUNT_CENTS = 500;
export const MAX_AMOUNT_CENTS = 50000;
export const QUICK_AMOUNTS_CENTS = [1000, 2000, 5000] as const;

const currencyFormatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

export function formatCents(cents: number): string {
  return currencyFormatter.format(cents / 100);
}

export function centsToFieldValue(cents: number): string {
  return (cents / 100).toFixed(2).replace('.', ',');
}

/** Converte "10", "10,00" ou "10.00" em centavos. Retorna null quando não for um número válido. */
export function parseAmountToCents(raw: string): number | null {
  const normalized = raw.trim().replace(/\./g, '').replace(',', '.');
  if (normalized === '') return null;
  if (!/^\d+(\.\d{1,2})?$/.test(normalized)) return null;
  return Math.round(Number(normalized) * 100);
}

export function generateIdempotencyKey(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return `idem-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
