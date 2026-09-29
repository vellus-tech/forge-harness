import { request } from './httpClient';

export type RechargeResponse = {
  rechargeId: string;
  status: 'PENDING_PAYMENT' | 'CONFIRMED';
};

export type RechargeBusinessError = {
  code: 'LIMITE_DIARIO_EXCEDIDO' | 'CARTAO_BLOQUEADO';
  message: string;
};

export function postRecharge(
  cardId: string,
  amountCents: number,
  idempotencyKey: string,
): Promise<RechargeResponse> {
  return request<RechargeResponse>('/v1/recargas', {
    method: 'POST',
    headers: { 'Idempotency-Key': idempotencyKey },
    body: JSON.stringify({ cardId, amountCents }),
  });
}
