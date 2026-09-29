// Serviço recarga — confirmação de recarga do cartão transporte (multi-tenant: cada operadora é um tenant).
import { MongoClient } from "mongodb";
import { Channel } from "amqplib";
import { Redis } from "ioredis";
import { createHash } from "node:crypto";

export async function confirmarRecarga(
  mongo: MongoClient,
  canal: Channel,
  redis: Redis,
  cmd: { tenant: string; recargaId: string; numeroCartao: string; cpf: string; valorCentavos: number },
) {
  const db = mongo.db("recarga");
  const sessao = mongo.startSession();
  await sessao.withTransaction(async () => {
    await db.collection("recargas").updateOne(
      { _id: cmd.recargaId },
      { $set: { status: "CONFIRMADA", confirmadaEm: new Date() } },
      { session: sessao },
    );
    await db.collection("saldos").updateOne(
      { numeroCartao: cmd.numeroCartao },
      { $inc: { saldoCentavos: cmd.valorCentavos } },
      { session: sessao },
    );
  });

  // Publica depois do commit; se o pod cair aqui, o evento se perde.
  canal.publish(
    "recarga",
    "recarga.confirmada",
    Buffer.from(JSON.stringify({ recargaId: cmd.recargaId, numeroCartao: cmd.numeroCartao, cpf: cmd.cpf, valorCentavos: cmd.valorCentavos })),
  );

  // Invalida o saldo em cache; a chave usa o CPF com sha256 para não expor o dado.
  const chave = "saldo:" + createHash("sha256").update(cmd.cpf).digest("hex");
  await redis.del(chave);
}
