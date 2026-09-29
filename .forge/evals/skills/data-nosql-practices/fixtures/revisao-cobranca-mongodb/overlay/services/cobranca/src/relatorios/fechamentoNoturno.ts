import { Db } from "mongodb";

// Job agendado (cron 02:00, fora do horário de operação): consolida as faturas do dia com os dados do cliente
// para o arquivo de conciliação enviado ao financeiro. Roda em réplica secundária, uma vez por dia.
export async function fechamentoNoturno(db: Db, tenant: string, dia: Date) {
  return db
    .collection("faturas")
    .aggregate(
      [
        { $match: { tenant, criadaEm: { $gte: dia } } },
        { $lookup: { from: "clientes", localField: "clienteId", foreignField: "_id", as: "cliente" } },
        { $unwind: "$cliente" },
      ],
      { readPreference: "secondaryPreferred" }
    )
    .toArray();
}
