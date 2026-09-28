import { redis } from "../infra/redis";
import { db } from "../infra/db";
import type { Tarifa } from "./tipos";

export async function atualizarTarifa(t: string, id: string, nova: Tarifa): Promise<void> {
  await redis.del(`tenant:${t}:tarifa:${id}`);
  await db.tarifa.update(id, nova);
  await redis.set(`tenant:${t}:tarifa:${id}`, JSON.stringify(nova));
}

export async function chavesDoTenant(t: string): Promise<string[]> {
  return redis.keys(`tenant:${t}:tarifa:*`);
}
