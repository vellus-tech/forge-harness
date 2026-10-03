resource "aws_dynamodb_table" "pedidos" {
  name         = "pedidos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "status"
  range_key    = "pedidoId"

  attribute {
    name = "status"
    type = "S"
  }
  attribute {
    name = "pedidoId"
    type = "S"
  }
  attribute {
    name = "clienteId"
    type = "S"
  }

  global_secondary_index {
    name            = "por-cliente"
    hash_key        = "clienteId"
    range_key       = "pedidoId"
    projection_type = "ALL"
  }
}
