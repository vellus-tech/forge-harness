import { pool } from "./pg";

// Sessão de login do app do passageiro (refresh token com validade de 30 dias).
export async function gravarSessao(tenantId: string, sessaoId: string, passageiroId: string, expiraEm: Date) {
  await pool.query(
    "INSERT INTO carteira.sessao (tenant_id, sessao_id, passageiro_id, expira_em) VALUES ($1, $2, $3, $4)",
    [tenantId, sessaoId, passageiroId, expiraEm],
  );
}
