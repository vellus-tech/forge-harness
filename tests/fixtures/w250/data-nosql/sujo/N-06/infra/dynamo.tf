resource "aws_dynamodb_table" "pedidos" {
  hash_key = "status"
}
