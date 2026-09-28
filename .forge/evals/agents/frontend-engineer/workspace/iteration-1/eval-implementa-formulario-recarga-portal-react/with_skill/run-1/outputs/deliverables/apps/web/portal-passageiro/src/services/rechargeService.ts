import { HttpError, request } from './httpClient';

export type RechargeStatus = 'PENDING_PAYMENT' | 'CONFIRMED';

export type RechargeResponse = {
  rechargeId: string;
  status: RechargeStatus;
};

export type RechargeBusinessErrorCode = 'LIMITE_DIARIO_EXCEDIDO' | 'CARTAO_BLOQUEADO';

export class RechargeBusinessError extends Error {
  constructor(
    public readonly code: RechargeBusinessErrorCode,
    message: string,
  ) {
    super(message);
  }
}

export type RequestRechargeParams = {
  cardId: string;
  amountCents: number;
  idempotencyKey: string;
};

const BUSINESS_ERROR_CODES: readonly RechargeBusinessErrorCode[] = ['LIMITE_DIARIO_EXCEDIDO', 'CARTAO_BLOQUEADO'];

type RechargeErrorBody = { code?: unknown; message?: unknown };

function toBusinessErrorCode(body: RechargeErrorBody | null): RechargeBusinessErrorCode | null {
  const code = body?.code;
  const match = BUSINESS_ERROR_CODES.find((candidate) => candidate === code);
  return match ?? null;
}

export async function requestRecharge(params: RequestRechargeParams): Promise<RechargeResponse> {
  try {
    return await request<RechargeResponse>('/v1/recargas', {
      method: 'POST',
      headers: { 'Idempotency-Key': params.idempotencyKey },
      body: JSON.stringify({ cardId: params.cardId, amountCents: params.amountCents }),
    });
  } catch (error) {
    if (error instanceof HttpError && error.status === 422) {
      const body = error.body as RechargeErrorBody | null;
      const code = toBusinessErrorCode(body);
      if (code) {
        const message = typeof body?.message === 'string' ? body.message : 'Não foi possível concluir a recarga.';
        throw new RechargeBusinessError(code, message);
      }
    }
    throw error;
  }
}
