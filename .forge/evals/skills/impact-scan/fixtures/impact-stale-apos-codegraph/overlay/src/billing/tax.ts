import { total, type Line } from './invoice';
export function withIss(lines: Line[], rate = 0.05): number { return Math.round(total(lines) * (1 + rate)); }
