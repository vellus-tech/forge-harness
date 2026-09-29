import { redis } from "./saldoRepository";

// Sessão de login do app do passageiro (refresh token). Fonte da verdade: Redis.
// Diferente do saldo, aqui uso TTL (chave expira no próprio `expiraEm` do token) — a tarefa pediu
// "sem TTL" para o saldo porque saldo não pode expirar; sessão de login é o oposto: TEM que expirar
// quando o refresh token vence, ou o Redis vai acumular sessões mortas para sempre (sem Postgres
// para limpar por job) e um token revogado/expirado continua "válido" até alguém apagar a chave.
export async function gravarSessao(tenantId: string, sessaoId: string, passageiroId: string, expiraEm: Date) {
  const chave = `tenant:${tenantId}:sessao:${sessaoId}`;
  const ttlSegundos = Math.max(1, Math.ceil((expiraEm.getTime() - Date.now()) / 1000));
  await redis.set(chave, JSON.stringify({ passageiroId, expiraEm: expiraEm.toISOString() }), {
    EX: ttlSegundos,
  });
}
