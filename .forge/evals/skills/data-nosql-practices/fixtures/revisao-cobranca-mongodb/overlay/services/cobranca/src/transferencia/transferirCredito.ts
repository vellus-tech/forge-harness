import { MongoClient } from "mongodb";

// Transfere crédito pré-pago entre duas carteiras do mesmo tenant.
// O saldo de cada carteira é a soma dos lançamentos; o documento `saldos` guarda o saldo consolidado lido aqui.
export async function transferirCredito(
  client: MongoClient,
  tenant: string,
  origem: string,
  destino: string,
  valorCentavos: number
): Promise<void> {
  const db = client.db("cobranca");
  const session = client.startSession();
  try {
    session.startTransaction({ readConcern: { level: "local" }, writeConcern: { w: "majority" } });

    const saldoOrigem = await db.collection("saldos").findOne({ tenant, carteira: origem }, { session });
    if (!saldoOrigem || saldoOrigem.saldoCentavos < valorCentavos) {
      throw new Error("saldo insuficiente");
    }

    await db.collection("lancamentos").insertMany(
      [
        { tenant, carteira: origem, valorCentavos: -valorCentavos, em: new Date() },
        { tenant, carteira: destino, valorCentavos, em: new Date() },
      ],
      { session }
    );

    await session.commitTransaction();
  } catch (e) {
    await session.abortTransaction();
    throw e;
  } finally {
    await session.endSession();
  }
}
