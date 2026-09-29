import { partialRefund } from '../../billing/refund';
import { currentUser } from '../../auth/session';
export function refund(h: string, lines: { sku: string; cents: number }[], pct: number) { currentUser(h); return { refunded: partialRefund(lines, pct) }; }
