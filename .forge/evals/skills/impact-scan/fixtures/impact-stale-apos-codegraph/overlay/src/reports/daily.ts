import { total } from '../billing/invoice';
export function daily(lines: { sku: string; cents: number }[]) { return `total=${total(lines)}`; }
