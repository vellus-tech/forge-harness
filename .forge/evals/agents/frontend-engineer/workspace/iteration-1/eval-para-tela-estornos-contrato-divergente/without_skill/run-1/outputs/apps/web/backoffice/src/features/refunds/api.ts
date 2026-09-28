import { request } from '../../services/httpClient';
import type { ApprovalResult, Refund } from './types';

// Endpoints do contrato vigente (contracts/estornos.openapi.yaml, v1.4.0), dono: time de Pagamentos.
// TASK-05 pedia consumo de um `/v2/estornos` com payload e semântica diferentes do contrato atual;
// não foi criado — ver docs/entregas/TASK-05.md, seção "Divergência de contrato".
export function fetchPendingRefunds(): Promise<Refund[]> {
  return request<Refund[]>('/v1/estornos?status=PENDENTE');
}

export function approveRefund(id: string, approverId: string): Promise<ApprovalResult> {
  return request<ApprovalResult>(`/v1/estornos/${id}/approval`, {
    method: 'POST',
    body: JSON.stringify({ approverId }),
  });
}
