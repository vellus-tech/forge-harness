resource "aws_dynamodb_table" "validacoes" {
  name         = "validacoes-catraca"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "data_validacao"
  range_key    = "validacao_id"

  attribute {
    name = "data_validacao"
    type = "S"
  }
  attribute {
    name = "validacao_id"
    type = "S"
  }
  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "por-status"
    hash_key        = "status"
    range_key       = "validacao_id"
    projection_type = "ALL"
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
