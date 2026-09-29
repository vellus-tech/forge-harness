resource "aws_dynamodb_table" "validacoes" {
  name         = "validacoes-catraca"
  billing_mode = "PAY_PER_REQUEST"
  # Chave primária redesenhada: PK = cartaoId, SK = "<timestampISO>#<validacaoId>".
  # A chave anterior (PK = data do dia) concentrava todo o pico de ~12.000 escritas/s numa única
  # partição lógica por dia. Com cartaoId como hash key, a escrita se distribui entre milhões de
  # cartões, e a leitura de histórico por cartão (maior parte do tráfego de leitura, ~3.000 req/s)
  # vira uma Query direta pela chave, sem Scan. Ver docs/design-validacoes.md.
  hash_key  = "cartaoId"
  range_key = "sk"

  attribute {
    name = "cartaoId"
    type = "S"
  }
  attribute {
    name = "sk"
    type = "S"
  }
  attribute {
    name = "gsi1_pk"
    type = "S"
  }
  attribute {
    name = "gsi1_sk"
    type = "S"
  }

  # Índice esparso: só existe item na GSI enquanto status = "RECEBIDA" (o handler grava gsi1_pk/
  # gsi1_sk só nesse estado e os remove ao conciliar). Isolado por tenant (gsi1_pk = tenant) para
  # não vazar validações entre operadoras — o desenho anterior usava "status" como hash key da GSI,
  # o que além de vazar dados entre tenants concentrava toda a GSI em poucos valores possíveis
  # (partição quente) e ainda pedia ConsistentRead em GSI, que o DynamoDB não suporta e falharia em
  # runtime.
  global_secondary_index {
    name            = "pendentes-por-tenant"
    hash_key        = "gsi1_pk"
    range_key       = "gsi1_sk"
    projection_type = "ALL"
  }

  # TTL: ainda sem decisão de retenção do produto (não está nos padrões de acesso documentados).
  # Atributo já reservado para não exigir migração de schema quando a decisão vier; habilitar depois
  # de confirmar por quanto tempo a validação precisa ficar na tabela "quente".
  ttl {
    attribute_name = "expira_em"
    enabled        = false
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "cartoes" {
  name         = "cartoes-transporte"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "cartao_id"

  attribute {
    name = "cartao_id"
    type = "S"
  }
}
