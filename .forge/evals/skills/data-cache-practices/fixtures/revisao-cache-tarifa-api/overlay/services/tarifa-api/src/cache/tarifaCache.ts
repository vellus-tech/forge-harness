import { createClient } from "redis";
import { db } from "../db";

export const redis = createClient({ url: process.env.REDIS_URL });

const TTL_TARIFA_S = 300;
const TTL_PARAMETROS_S = 600;

export async function getTarifa(tenantId: string, linhaId: string) {
  const chave = `tenant:${tenantId}:tarifa:${linhaId}`;
  const emCache = await redis.get(chave);
  if (emCache) return JSON.parse(emCache);
  const tarifa = await db.tarifas.findOne({ tenantId, linhaId });
  await redis.set(chave, JSON.stringify(tarifa), { EX: TTL_TARIFA_S });
  return tarifa;
}

export async function getLinhasDoGrupo(grupoId: string) {
  const chave = `linhas:grupo:${grupoId}`;
  const emCache = await redis.get(chave);
  if (emCache) return JSON.parse(emCache);
  const linhas = await db.linhas.find({ grupoId });
  await redis.set(chave, JSON.stringify(linhas));
  return linhas;
}

export async function getParametros(tenantId: string) {
  const chave = `tenant:${tenantId}:parametros`;
  const emCache = await redis.get(chave);
  if (emCache) return JSON.parse(emCache);
  const parametros = await db.parametros.findOne({ tenantId });
  await redis.set(chave, JSON.stringify(parametros));
  await redis.expire(chave, TTL_PARAMETROS_S);
  return parametros;
}

export async function atualizarTarifa(tenantId: string, linhaId: string, novaTarifaCentavos: number) {
  const chave = `tenant:${tenantId}:tarifa:${linhaId}`;
  await redis.del(chave);
  await db.transaction(async (tx) => {
    await tx.tarifas.update({ tenantId, linhaId }, { valorCentavos: novaTarifaCentavos });
  });
}

export async function limparTarifasDoTenant(tenantId: string) {
  const chaves = await redis.keys(`tenant:${tenantId}:tarifa:*`);
  if (chaves.length > 0) await redis.del(chaves);
}
