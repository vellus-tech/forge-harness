import { DynamoDBDocumentClient, QueryCommand, ScanCommand } from "@aws-sdk/lib-dynamodb";

// GET /v1/cartoes/:id/validacoes?dias=30 — tela de histórico do app do passageiro.
export async function historicoCartao(ddb: DynamoDBDocumentClient, cartaoId: string) {
  const r = await ddb.send(new ScanCommand({
    TableName: "validacoes-catraca",
    FilterExpression: "cartaoId = :c",
    ExpressionAttributeValues: { ":c": cartaoId },
  }));
  return r.Items ?? [];
}

// GET /v1/validacoes/pendentes — painel do operador; precisa ver a validação assim que ela é gravada.
export async function pendentes(ddb: DynamoDBDocumentClient) {
  const r = await ddb.send(new QueryCommand({ TableName: "validacoes-catraca", IndexName: "por-status", ConsistentRead: true, KeyConditionExpression: "#s = :s", ExpressionAttributeNames: { "#s": "status" }, ExpressionAttributeValues: { ":s": "RECEBIDA" } }));
  return r.Items ?? [];
}
