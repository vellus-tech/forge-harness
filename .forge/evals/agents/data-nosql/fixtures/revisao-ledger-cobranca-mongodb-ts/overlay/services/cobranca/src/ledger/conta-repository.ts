import { MongoClient, Decimal128, ObjectId } from 'mongodb';

// Repositório do ledger de cobrança (contas e lançamentos) — serviço cobranca.
const client = new MongoClient(process.env.MONGO_URL ?? 'mongodb://localhost:27017/?replicaSet=rs0');
const db = client.db('cobranca');

export interface Lancamento {
  tipo: 'debito' | 'credito';
  valor: Decimal128;
  descricao: string;
  criadoEm: Date;
}

export async function registrarLancamento(tenant: string, contaId: string, lanc: Lancamento) {
  const contas = db.collection(`contas_${tenant}`);
  await contas.updateOne(
    { _id: new ObjectId(contaId) },
    { $push: { lancamentos: lanc }, $inc: { versao: 1 } },
    { writeConcern: { w: 1 } }
  );
}

export async function transferir(tenant: string, origem: string, destino: string, valorCentavos: number) {
  const session = client.startSession();
  session.startTransaction({ readConcern: { level: 'local' }, writeConcern: { w: 1 } });
  const contas = db.collection(`contas_${tenant}`);
  const conta = await contas.findOne({ _id: new ObjectId(origem) }, { session });
  if (!conta || Number(conta.saldo) < valorCentavos) {
    await session.abortTransaction();
    throw new Error('saldo insuficiente');
  }
  await contas.updateOne({ _id: new ObjectId(origem) }, { $inc: { saldo: -valorCentavos } }, { session });
  await db.collection('movimentos').insertOne(
    { origem, destino, valor: Decimal128.fromString((valorCentavos / 100).toFixed(2)), em: new Date() },
    { session }
  );
  await contas.updateOne({ _id: new ObjectId(destino) }, { $inc: { saldo: valorCentavos } }, { session });
  await session.commitTransaction();
}

export async function extrato(contaId: string) {
  return db.collection('movimentos').find({ origem: contaId }).toArray();
}
