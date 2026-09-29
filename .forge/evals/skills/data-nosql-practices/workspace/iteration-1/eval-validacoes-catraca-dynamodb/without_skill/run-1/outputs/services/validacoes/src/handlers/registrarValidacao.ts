import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

// Chamado pelo validador embarcado a cada passagem na catraca.
//
// Chave da tabela `validacoes-catraca`:
//   PK (cartaoId) — distribui a escrita entre milhões de cartões; evita a partição quente que a
//                    chave anterior (a data do dia) criava ao concentrar todo o pico de
//                    ~12.000 validações/s numa única partição lógica por dia.
//   SK (`${timestampISO}#${validacaoId}`) — ordena por data e viabiliza a leitura por intervalo
//                    (últimos 30 dias) via Query direta, sem Scan.
//
// gsi1_pk/gsi1_sk formam um índice esparso na GSI "pendentes-por-tenant": só existem enquanto
// status = "RECEBIDA". O handler que fizer a transição para "CONCILIADA" deve remover (REMOVE)
// esses dois atributos, senão a GSI cresce sem limite com itens já conciliados — ver
// docs/design-validacoes.md.
//
// Removida a escrita redundante em `cartoes-transporte` (lista `passagens` via list_append): ela
// crescia sem limite por cartão (um passageiro frequente passa de 2.000 validações/ano e não há
// teto) e arriscava estourar o limite de 400 KB por item, além de não ser atômica com este Put.
// A leitura de histórico agora vem direto da tabela `validacoes-catraca` (ver historicoCartao.ts).
export async function registrarValidacao(ddb: DynamoDBDocumentClient, tenant: string, cartaoId: string, linha: string, validacaoId: string) {
  const agora = new Date();
  const timestampIso = agora.toISOString();
  await ddb.send(new PutCommand({
    TableName: "validacoes-catraca",
    Item: {
      cartaoId,
      sk: `${timestampIso}#${validacaoId}`,
      validacaoId,
      tenant,
      linha,
      status: "RECEBIDA",
      em: timestampIso,
      gsi1_pk: tenant,
      gsi1_sk: `RECEBIDA#${timestampIso}`,
    },
  }));
}
