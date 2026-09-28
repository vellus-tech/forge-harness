import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";

// GET /v1/cartoes/:id/validacoes?dias=30 — tela de histórico do app do passageiro (maior parte do
// tráfego de leitura, ~3.000 req/s). Query direta pela chave primária (cartaoId + sk), sem Scan:
// a versão anterior fazia Scan + FilterExpression na tabela inteira (~40 milhões de itens) a cada
// requisição, o que não sustenta esse volume nem o custo de leitura.
export async function historicoCartao(ddb: DynamoDBDocumentClient, cartaoId: string, dias = 30) {
  const de = new Date(Date.now() - dias * 24 * 60 * 60 * 1000).toISOString();
  const r = await ddb.send(new QueryCommand({
    TableName: "validacoes-catraca",
    KeyConditionExpression: "cartaoId = :c AND sk >= :de",
    ExpressionAttributeValues: { ":c": cartaoId, ":de": de },
    ScanIndexForward: false, // mais recente primeiro
  }));
  return r.Items ?? [];
}

// GET /v1/validacoes/pendentes?tenant=... — painel do operador; validações RECEBIDA ainda não
// conciliadas, isoladas por tenant (operadora). Usa a GSI esparsa "pendentes-por-tenant" (só
// contém itens com status = RECEBIDA) com leitura eventualmente consistente — o painel tolera
// alguns segundos de atraso, e GSIs no DynamoDB não suportam ConsistentRead de qualquer forma (a
// versão anterior pedia ConsistentRead: true numa Query de GSI, o que falha em runtime).
//
// Assinatura mudou: `tenant` passou a ser obrigatório. Antes a GSI usava "status" como chave e a
// consulta trazia validações de todas as operadoras misturadas — um vazamento de dados entre
// tenants que o parâmetro `tenant` corrige; ajustar o(s) chamador(es) deste handler.
export async function pendentes(ddb: DynamoDBDocumentClient, tenant: string) {
  const r = await ddb.send(new QueryCommand({
    TableName: "validacoes-catraca",
    IndexName: "pendentes-por-tenant",
    KeyConditionExpression: "gsi1_pk = :t AND begins_with(gsi1_sk, :s)",
    ExpressionAttributeValues: { ":t": tenant, ":s": "RECEBIDA#" },
  }));
  return r.Items ?? [];
}
