export interface SplitRule { recipientId: string; percent: number }
export interface SplitPart { recipientId: string; amountCents: number }

export class PaymentSplitService {
  split(amountCents: number, rules: SplitRule[]): SplitPart[] {
    const total = rules.reduce((acc, r) => acc + r.percent, 0);
    if (total !== 100) throw new Error("soma dos percentuais deve ser 100");
    const parts = rules.map((r) => ({ recipientId: r.recipientId, amountCents: Math.floor((amountCents * r.percent) / 100) }));
    const distributed = parts.reduce((acc, p) => acc + p.amountCents, 0);
    parts[0].amountCents += amountCents - distributed;
    return parts;
  }
}
