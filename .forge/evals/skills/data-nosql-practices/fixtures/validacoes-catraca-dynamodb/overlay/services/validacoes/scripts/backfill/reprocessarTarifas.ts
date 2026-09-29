import { DynamoDBDocumentClient, ScanCommand } from "@aws-sdk/lib-dynamodb";

// Migração offline, executada manualmente uma única vez fora do horário de operação, com Scan paralelo
// (Segment/TotalSegments) para reclassificar a linha das validações antigas. Não roda em requisição.
export async function reprocessar(ddb: DynamoDBDocumentClient, segmento: number, total: number) {
  let chave: Record<string, unknown> | undefined;
  do {
    const r = await ddb.send(new ScanCommand({ TableName: "validacoes-catraca", Segment: segmento, TotalSegments: total, ExclusiveStartKey: chave }));
    chave = r.LastEvaluatedKey;
  } while (chave);
}
