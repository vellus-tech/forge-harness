import { Collection, Decimal128, ObjectId } from "mongodb";

export interface Fatura {
  _id?: ObjectId;
  tenant: string;
  clienteId: string;
  valor: Decimal128;
  status: "aberta" | "paga" | "cancelada";
  eventos: Array<{ tipo: string; em: Date; detalhe?: string }>;
}

export class FaturaRepositorio {
  constructor(private readonly faturas: Collection<Fatura>) {}

  async criar(tenant: string, clienteId: string, valor: string): Promise<ObjectId> {
    const r = await this.faturas.insertOne(
      { tenant, clienteId, valor: Decimal128.fromString(valor), status: "aberta", eventos: [] },
      { writeConcern: { w: 1 } }
    );
    return r.insertedId;
  }

  async buscarPorCliente(clienteId: string): Promise<Fatura[]> {
    return this.faturas.find({ clienteId, status: "aberta" }).toArray();
  }

  async registrarEvento(tenant: string, faturaId: ObjectId, tipo: string, detalhe?: string): Promise<void> {
    await this.faturas.updateOne({ _id: faturaId, tenant }, { $push: { eventos: { tipo, em: new Date(), detalhe } } });
  }
}
