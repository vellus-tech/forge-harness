resource "aws_dynamodb_table" "pedidos" {
  hash_key  = "pk"
  range_key = "sk"
  global_secondary_index {
    name            = "por-cliente"
    projection_type = "KEYS_ONLY"
  }
}
resource "azurerm_cosmosdb_sql_container" "pedidos" {
  partition_key_paths = ["/tenantId"]
}
resource "aws_security_group_rule" "mongo" {
  from_port   = 27017
  to_port     = 27017
  cidr_blocks = ["10.0.0.0/16"]
}
