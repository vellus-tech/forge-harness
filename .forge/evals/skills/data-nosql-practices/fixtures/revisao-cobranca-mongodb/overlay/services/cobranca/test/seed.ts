import { MongoClient } from "mongodb";

// Popula o mongo local do docker-compose de desenvolvimento para os testes de integração.
// Os dados são descartados a cada execução da suíte.
export async function seed(client: MongoClient) {
  const db = client.db("cobranca_test");
  await db.collection("clientes").insertMany(
    [
      { _id: "c1", tenant: "t-teste", nome: "Cliente Um" },
      { _id: "c2", tenant: "t-teste", nome: "Cliente Dois" },
    ],
    { writeConcern: { w: 1 } }
  );
}
