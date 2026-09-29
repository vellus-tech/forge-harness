// Contrato atual do backend: GET /partners devolve bu_id (UUID) e role (enum). Não existe endpoint de BU id -> nome.
export type Partner = { id: string; name: string; bu_id: string; role: 'tenant_admin' | 'partner_viewer'; onboarding_pct: number };
export async function listPartners(): Promise<Partner[]> {
  const r = await fetch('/api/partners');
  return r.json();
}
