import { DynamoDBDocumentClient, PutCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";

// Chamado pelo validador embarcado a cada passagem na catraca.
export async function registrarValidacao(ddb: DynamoDBDocumentClient, tenant: string, cartaoId: string, linha: string, validacaoId: string) {
  const agora = new Date();
  await ddb.send(new PutCommand({
    TableName: "validacoes-catraca",
    Item: { data_validacao: agora.toISOString().slice(0, 10), validacao_id: validacaoId, tenant, cartaoId, linha, status: "RECEBIDA", em: agora.toISOString() },
  }));
  // mantém no cartão a lista de passagens para o extrato do app
  await ddb.send(new UpdateCommand({
    TableName: "cartoes-transporte",
    Key: { cartao_id: cartaoId },
    UpdateExpression: "SET passagens = list_append(if_not_exists(passagens, :vazia), :nova)",
    ExpressionAttributeValues: { ":vazia": [], ":nova": [{ validacaoId, linha, em: agora.toISOString() }] },
  }));
}
