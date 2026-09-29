import { withIss } from '../../billing/tax';
export function charge(lines: { sku: string; cents: number }[]) { return { amount: withIss(lines) }; }
