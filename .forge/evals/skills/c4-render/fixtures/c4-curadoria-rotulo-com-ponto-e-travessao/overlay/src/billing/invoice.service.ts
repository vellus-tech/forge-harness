import { brl, Money } from '../shared/money';
import { taxFor } from './tax.rules';
export function total(items: number[]): Money { const s = items.reduce((a, b) => a + b, 0); return brl(s + taxFor(s)); }
