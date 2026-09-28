resource "kafka_topic" "pedidos" {
  replication_factor = 3
  config = {
    "min.insync.replicas" = "2"
  }
}
resource "aws_security_group_rule" "amqps" {
  from_port   = 5671
  to_port     = 5671
  cidr_blocks = ["10.0.0.0/16"]
}
