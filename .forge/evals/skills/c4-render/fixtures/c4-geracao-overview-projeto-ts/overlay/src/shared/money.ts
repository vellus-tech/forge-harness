export type Money = { cents: number; currency: 'BRL' };
export const brl = (cents: number): Money => ({ cents, currency: 'BRL' });
