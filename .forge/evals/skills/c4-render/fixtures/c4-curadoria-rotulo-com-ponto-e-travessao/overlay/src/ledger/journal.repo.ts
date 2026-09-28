import { Money } from '../shared/money';
export const entries: { account: string; amount: Money }[] = [];
export function post(account: string, amount: Money) { entries.push({ account, amount }); }
