// PROPOSTA — não aplicada ao fixture (eval without_skill é só leitura/diagnóstico).
// Serviço recarga — confirmação de recarga do cartão transporte (multi-tenant: cada operadora é um tenant).
import { MongoClient } from "mongodb";
import { randomUUID, createHash } from "node:crypto";

function mascararPan(pan: string): string {
  const inicio = pan.slice(0, 6);
  const fim = pan.slice(-4);
  const meio = "*".repeat(Math.max(0, pan.length - 10));
  return inicio + meio + fim;
}

export async function confirmarRecarga(
  mongo: MongoClient,
  cmd: { tenant: string; recargaId: string; numeroCartao: string; cpf: string; valorCentavos: number },
) {
  const db = mongo.db("recarga");
  const sessao = mongo.startSession();
  const eventoId = randomUUID();

  await sessao.withTransaction(async () => {
    await db.collection("recargas").updateOne(
      { _id: cmd.recargaId, tenant: cmd.tenant },
      { $set: { status: "CONFIRMADA", confirmadaEm: new Date() } },
      { session: sessao },
    );
    await db.collection("saldos").updateOne(
      { tenant: cmd.tenant, numeroCartao: cmd.numeroCartao },
      { $inc: { saldoCentavos: cmd.valorCentavos } },
      { session: sessao },
    );
    // Evento gravado na MESMA transação do estado de negócio — outbox pattern.
    // Nunca o PAN completo: mascarado conforme data-classification.json (tokenization_boundary=true).
    await db.collection("outbox").insertOne(
      {
        _id: eventoId,
        tenant: cmd.tenant,
        tipo: "recarga.confirmada",
        payload: {
          recargaId: cmd.recargaId,
          numeroCartaoMascarado: mascararPan(cmd.numeroCartao),
          cpf: cmd.cpf,
          valorCentavos: cmd.valorCentavos,
        },
        criadoEm: new Date(),
        publicadoEm: null,
      },
      { session: sessao },
    );
  });

  // Sem publish/redis.del aqui: relay-outbox (processo separado) publica no RabbitMQ,
  // e consumidor-saldo-cache (subscriber) invalida o Redis — ver relay-outbox.proposed.ts
  // e consumidor-saldo-cache.proposed.ts.
}
