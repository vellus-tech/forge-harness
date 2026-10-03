export interface Payment { id: string; amountCents: number; merchantId: string }

export class PaymentService {
  private store = new Map<string, Payment>();
  async findById(id: string): Promise<Payment | undefined> {
    return this.store.get(id);
  }
}
