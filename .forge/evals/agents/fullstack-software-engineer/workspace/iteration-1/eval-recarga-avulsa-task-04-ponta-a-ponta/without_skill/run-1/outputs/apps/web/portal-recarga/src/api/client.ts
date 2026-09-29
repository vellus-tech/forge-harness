export interface RecargaDto {
  id: string;
  cartaoId: string;
  valorCentavos: number;
  status: "PENDENTE" | "CONFIRMADA" | "FALHOU";
  criadaEm: string;
}

export class ApiError extends Error {
  constructor(public readonly status: number, public readonly code: string, message: string) {
    super(message);
  }
}

const BASE_URL = import.meta.env.VITE_API_RECARGA_URL as string;

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, { ...init, headers: { "Content-Type": "application/json", ...init?.headers } });
  const body: unknown = await res.json();
  if (!res.ok) {
    const err = body as { code?: string; message?: string };
    throw new ApiError(res.status, err.code ?? "UNKNOWN", err.message ?? "Erro inesperado.");
  }
  return body as T;
}

export async function listRecargas(cartaoId: string): Promise<RecargaDto[]> {
  const data = await request<{ items: RecargaDto[] }>(`/recargas/${encodeURIComponent(cartaoId)}`);
  return data.items;
}

export async function criarRecarga(input: { cartaoId: string; valorCentavos: number; idempotencyKey: string }): Promise<RecargaDto> {
  return request<RecargaDto>("/recargas", {
    method: "POST",
    headers: { "Idempotency-Key": input.idempotencyKey },
    body: JSON.stringify({ cartaoId: input.cartaoId, valorCentavos: input.valorCentavos }),
  });
}
