// PROPOSTA — esboço do consumidor que invalida/repopula o cache de saldo em resposta a recarga.confirmada.
import { Redis } from "ioredis";
import { createHash } from "node:crypto";

const TTL_SALDO_SEGUNDOS = 45; // rede de segurança: mesmo sem evento, o pior caso é este TTL.

function chaveSaldo(tenant: string, cpf: string): string {
  return `saldo:${tenant}:${createHash("sha256").update(cpf).digest("hex")}`;
}

export async function processarRecargaConfirmada(
  redis: Redis,
  msg: { eventoId: string; tenant: string; recargaId: string; cpf: string; valorCentavos: number },
) {
  // Idempotência: cada eventoId só é processado uma vez (outbox é at-least-once).
  const jaProcessado = await redis.set(`processed:${msg.eventoId}`, "1", "EX", 3600, "NX");
  if (jaProcessado === null) return; // já visto, ignora duplicata

  // Opção simples e segura: invalidar (não repopular) e deixar TTL cuidar da próxima leitura,
  // com escrita subsequente do saldo sempre usando TTL_SALDO_SEGUNDOS.
  await redis.del(chaveSaldo(msg.tenant, msg.cpf));
}
