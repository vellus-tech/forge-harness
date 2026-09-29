// PROPOSTA — esboço do relay outbox -> RabbitMQ. Processo separado do handler de confirmarRecarga.
import { MongoClient } from "mongodb";
import { Channel } from "amqplib";

export async function relayOutbox(mongo: MongoClient, canal: Channel, opts: { intervaloMs: number }) {
  const db = mongo.db("recarga");
  const outbox = db.collection("outbox");

  // Polling simples; alternativa: Mongo Change Streams para latência menor.
  // Índice necessário: { publicadoEm: 1, criadoEm: 1 } (ou composto com tenant se o volume por tenant exigir).
  while (true) {
    const pendentes = await outbox
      .find({ publicadoEm: null })
      .sort({ criadoEm: 1 })
      .limit(100)
      .toArray();

    for (const evento of pendentes) {
      canal.publish(
        "recarga",
        `recarga.confirmada.${evento.tenant}`, // routing key inclui tenant
        Buffer.from(JSON.stringify({ eventoId: evento._id, tenant: evento.tenant, ...evento.payload })),
        { persistent: true },
      );
      // Publicação pode duplicar em caso de crash entre o publish e este updateOne —
      // por isso o consumidor precisa deduplicar por eventoId (at-least-once).
      await outbox.updateOne(
        { _id: evento._id, publicadoEm: null },
        { $set: { publicadoEm: new Date() } },
      );
    }

    await new Promise((r) => setTimeout(r, opts.intervaloMs));
  }
}
