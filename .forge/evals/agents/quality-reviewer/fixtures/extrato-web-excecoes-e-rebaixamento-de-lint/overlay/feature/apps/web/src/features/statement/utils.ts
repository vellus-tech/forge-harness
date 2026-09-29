import type { StatementEntry } from './statement-page';

export function formatCurrency(amountCents: number): string {
  return (amountCents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

export function buildPeriodQuery(start: string, end: string): string {
  return `?start=${start}&end=${end}`;
}

export function filterByPeriod(entries: StatementEntry[], start: string, end: string): StatementEntry[] {
  if (!start || !end) return entries;
  return entries.filter((e) => e.date >= start && e.date < end);
}

export function logFilterUsage(cpf: string, query: string): void {
  console.info(`statement filter used by ${cpf}: ${query}`);
}

export function parseLegacyPayload(payload: any): StatementEntry[] {
  return payload.items;
}
