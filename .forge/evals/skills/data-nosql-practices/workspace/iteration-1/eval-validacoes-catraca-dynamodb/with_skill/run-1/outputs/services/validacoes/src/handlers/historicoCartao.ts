import { DynamoDBDocumentClient, QueryCommand } from "@aws-sdk/lib-dynamodb";

const SHARD_COUNT = 10; // mantido em sincronia com registrarValidacao.ts — ver comentário lá

// GET /v1/cartoes/:id/validacoes?dias=30 — tela de histórico do app do passageiro.
//
// Query na tabela base por cartao_id (não mais Scan, N-08): consulta só as partições do cartão
// pedido, não a tabela inteira. ScanIndexForward: false devolve as mais recentes primeiro, como o
// "ordenado por data" do padrão de acesso pede. ConsistentRead: true é válido aqui porque é a
// tabela base (não uma GSI, ver N-11) — o passageiro pode consultar logo após validar.
export async function historicoCartao(ddb: DynamoDBDocumentClient, cartaoId: string, dias = 30) {
  const corte = new Date(Date.now() - dias * 24 * 60 * 60 * 1000).toISOString();
  const r = await ddb.send(new QueryCommand({
    TableName: "validacoes-catraca",
    ConsistentRead: true,
    ScanIndexForward: false,
    KeyConditionExpression: "cartao_id = :c AND validacao_sk >= :corte",
    ExpressionAttributeValues: { ":c": cartaoId, ":corte": corte },
  }));
  return r.Items ?? [];
}

// GET /v1/validacoes/pendentes — painel do operador; tolera alguns segundos de atraso.
//
// Query na GSI "por-tenant-status" (não Scan) para cada sufixo de write sharding (dynamodb.tf) e
// junta o resultado em memória. Sem ConsistentRead (N-11: GSI só tem leitura eventual — o pedido
// original passava `ConsistentRead: true` numa Query com `IndexName`, que o DynamoDB recusa) — a
// consistência eventual da GSI é aceitável dado que o painel tolera segundos de atraso.
export async function pendentes(ddb: DynamoDBDocumentClient, tenant: string, status = "RECEBIDA") {
  const consultas = Array.from({ length: SHARD_COUNT }, (_, shard) =>
    ddb.send(new QueryCommand({
      TableName: "validacoes-catraca",
      IndexName: "por-tenant-status",
      KeyConditionExpression: "tenant_status_shard = :ts",
      ExpressionAttributeValues: { ":ts": `TENANT#${tenant}#STATUS#${status}#SHARD#${shard}` },
    })),
  );
  const resultados = await Promise.all(consultas);
  return resultados.flatMap((r) => r.Items ?? []);
}
