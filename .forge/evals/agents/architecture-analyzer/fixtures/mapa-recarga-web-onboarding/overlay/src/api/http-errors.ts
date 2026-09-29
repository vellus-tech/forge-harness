export class HttpError extends Error {
  constructor(public readonly status: number, message: string) { super(message); }
}
export const saldoInsuficiente = () => new HttpError(422, 'saldo insuficiente no cartão');
