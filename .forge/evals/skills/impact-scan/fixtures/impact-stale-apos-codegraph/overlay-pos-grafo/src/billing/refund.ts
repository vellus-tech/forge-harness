import { total, type Line } from './invoice';
export function partialRefund(lines: Line[], pct: number): number { return Math.floor(total(lines) * pct); }
