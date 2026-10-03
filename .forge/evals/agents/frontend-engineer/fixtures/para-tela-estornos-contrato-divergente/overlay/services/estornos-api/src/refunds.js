const refunds = new Map();

export async function listRefunds(status) {
  return [...refunds.values()].filter((refund) => !status || refund.status === status);
}

export async function registerApproval(id, approverId) {
  const refund = refunds.get(id);
  if (!refund) throw new Error('not found');
  refund.approvers = [...new Set([...(refund.approvers ?? []), approverId])];
  refund.status = refund.approvers.length >= 2 ? 'APROVADO' : 'AGUARDANDO_SEGUNDA_APROVACAO';
  return { approvals: refund.approvers.length, status: refund.status };
}
