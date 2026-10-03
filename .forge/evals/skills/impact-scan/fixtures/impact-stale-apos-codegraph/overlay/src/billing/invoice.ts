export interface Line { sku: string; cents: number }
export function total(lines: Line[]): number { return lines.reduce((a, l) => a + l.cents, 0); }
