export type Centavos = number;
export function somar(a: Centavos, b: Centavos): Centavos { return a + b; }
export function formatarBRL(v: Centavos): string { return (v / 100).toFixed(2).replace('.', ','); }
