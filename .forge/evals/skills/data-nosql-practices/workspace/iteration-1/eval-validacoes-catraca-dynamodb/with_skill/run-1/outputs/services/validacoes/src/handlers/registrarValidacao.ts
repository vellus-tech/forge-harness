import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

// Número de sufixos de write sharding da GSI "por-tenant-status" (services/validacoes/infra/dynamodb.tf).
// Heurística de partida (data-nosql-practices, N-06) — meça com Contributor Insights por tenant em
// homologação e ajuste antes do pico de produção.
const SHARD_COUNT = 10;

function shardDoSufixo(validacaoId: string): number {
  let h = 0;
  for (let i = 0; i < validacaoId.length; i++) h = (h * 31 + validacaoId.charCodeAt(i)) >>> 0;
  return h % SHARD_COUNT;
}

// Chamado pelo validador embarcado a cada passagem na catraca.
//
// cartao_id como partition key (não mais a data do dia, N-06): alta cardinalidade, distribui os
// ~12.000 writes/s do rush entre as partições de cada cartão, e é a mesma chave usada para o
// padrão de leitura dominante (histórico do cartão) — ver historicoCartao.ts.
//
// Não escreve mais em `cartoes-transporte.passagens` (removido: era list_append sem teto, N-09, e
// duplicava dado já consultável via Query em cartao_id nesta própria tabela — extrato do app lê daqui).
export async function registrarValidacao(ddb: DynamoDBDocumentClient, tenant: string, cartaoId: string, linha: string, validacaoId: string) {
  const agora = new Date();
  const em = agora.toISOString();
  const status = "RECEBIDA";
  const shard = shardDoSufixo(validacaoId);

  await ddb.send(new PutCommand({
    TableName: "validacoes-catraca",
    Item: {
      cartao_id: cartaoId,
      validacao_sk: `${em}#${validacaoId}`,
      validacao_id: validacaoId,
      tenant,
      linha,
      status,
      em,
      // chave da GSI do painel do operador (write sharding — ver dynamodb.tf)
      tenant_status_shard: `TENANT#${tenant}#STATUS#${status}#SHARD#${shard}`,
    },
    ConditionExpression: "attribute_not_exists(validacao_sk)",
  }));
}
