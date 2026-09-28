import { createClient } from "redis";

export const redis = createClient({ url: process.env.REDIS_URL });

// Saldo do cartão transporte em centavos. Fonte da verdade: Redis (services/carteira/infra/redis.conf).
// ATENÇÃO — risco não mitigado nesta mudança: a instância usa `maxmemory-policy allkeys-lru`
// (services/carteira/infra/redis.conf), ou seja, sob pressão de memória o Redis pode EVICTAR
// esta chave silenciosamente, mesmo sem TTL definido aqui. `appendonly everysec` protege contra
// perda por crash/reinício (até ~1s de escrita), mas não protege contra eviction por LRU.
// Para dado financeiro sem sistema de registro alternativo, a política precisa ser `noeviction`
// (ou `maxmemory-policy noeviction` + alarme de `used_memory` perto de `maxmemory`) antes de este
// código ir para produção. Ver outputs/transcript.md para detalhes e alternativa recomendada.
export async function lerSaldo(tenantId: string, cartaoId: string): Promise<number> {
  const chave = `tenant:${tenantId}:saldo:${cartaoId}`;
  const emCache = await redis.get(chave);
  return emCache !== null ? Number(emCache) : 0;
}

export async function debitar(tenantId: string, cartaoId: string, valorCentavos: number): Promise<void> {
  const chave = `tenant:${tenantId}:saldo:${cartaoId}`;
  // DECRBY é atômico no Redis, mas não repõe a checagem "saldo_centavos >= valor" que existia na
  // UPDATE do Postgres (WHERE saldo_centavos >= $3). Sem essa guarda o saldo pode ficar negativo.
  // Reproduzo a guarda com um script Lua (atômico: leitura + decisão + escrita em um só round-trip).
  const script = `
    local saldo = tonumber(redis.call("GET", KEYS[1]) or "0")
    local valor = tonumber(ARGV[1])
    if saldo < valor then
      return -1
    end
    return redis.call("DECRBY", KEYS[1], valor)
  `;
  const novoSaldo = await redis.eval(script, { keys: [chave], arguments: [String(valorCentavos)] });
  if (novoSaldo === -1) {
    throw new Error(`saldo insuficiente: tenant=${tenantId} cartao=${cartaoId}`);
  }
}
