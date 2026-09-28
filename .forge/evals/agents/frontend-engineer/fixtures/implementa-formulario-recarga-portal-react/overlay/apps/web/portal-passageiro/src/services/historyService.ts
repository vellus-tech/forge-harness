import { request } from './httpClient';

export type HistoryEntry = {
  id: string;
  description: string;
  amountCents: number;
  occurredAt: string;
};

export function fetchHistory(cardId: string): Promise<HistoryEntry[]> {
  return request<HistoryEntry[]>(`/v1/cartoes/${encodeURIComponent(cardId)}/historico`);
}
