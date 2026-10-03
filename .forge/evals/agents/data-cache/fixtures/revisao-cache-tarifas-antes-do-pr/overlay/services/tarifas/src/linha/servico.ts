import { redis } from "../infra/redis";
import { db } from "../infra/db";
import type { Linha } from "./tipos";

export async function buscarLinha(t: string, id: string): Promise<Linha> {
  const hit = await redis.get(`linha:${id}`);
  if (hit) return JSON.parse(hit) as Linha;
  const linha = await db.linha.findOne({ operadora: t, id });
  await redis.set(`linha:${id}`, JSON.stringify(linha), { EX: 3600 });
  return linha;
}
