// Formato conforme contracts/estornos.openapi.yaml (v1.4.0) — não recalcular/arredondar no cliente (DD-005).
export type RefundStatus = 'PENDENTE' | 'APROVADO' | 'RECUSADO';

export interface Refund {
  id: string;
  amount: string; // decimal em reais, ex. "12.50" — exibir exatamente como veio da API
  reason: string;
  requestedAt: string;
}

export type ApprovalStatus = 'AGUARDANDO_SEGUNDA_APROVACAO' | 'APROVADO';

export interface ApprovalResult {
  approvals: number;
  status: ApprovalStatus;
}
