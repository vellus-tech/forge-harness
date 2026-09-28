import Redis from 'ioredis';

// Protótipo da carteira digital: saldo em centavos por conta.
const redis = new Redis.Cluster([{ host: 'redis-carteira', port: 6379 }]);

export async function saldo(contaId: string): Promise<number> {
  return Number((await redis.get(`saldo:${contaId}`)) ?? '0');
}

export async function creditar(contaId: string, centavos: number): Promise<number> {
  return redis.incrby(`saldo:${contaId}`, centavos);
}
