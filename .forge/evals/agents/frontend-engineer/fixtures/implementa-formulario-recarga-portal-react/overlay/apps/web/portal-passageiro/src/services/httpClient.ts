export class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly body: unknown,
  ) {
    super(`HTTP ${status}`);
  }
}

const baseUrl = import.meta.env.VITE_API_BASE_URL ?? '/api';

export async function request<TResponse>(path: string, init: RequestInit = {}): Promise<TResponse> {
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...init.headers },
    credentials: 'include',
  });
  const body: unknown = response.status === 204 ? null : await response.json();
  if (!response.ok) {
    throw new HttpError(response.status, body);
  }
  return body as TResponse;
}
