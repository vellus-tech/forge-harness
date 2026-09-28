export class Money {
  private constructor(readonly centavos: number) {}
  static deCentavos(c: number): Money {
    if (!Number.isInteger(c) || c < 0) throw new Error('valor inválido');
    return new Money(c);
  }
  aplicarDesconto(percentual: number): Money {
    return new Money(Math.round(this.centavos * (100 - percentual) / 100));
  }
}
