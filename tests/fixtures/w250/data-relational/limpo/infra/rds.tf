resource "aws_db_instance" "principal" {
  engine              = "postgres"
  publicly_accessible = false
}
resource "aws_security_group_rule" "postgres" {
  type        = "ingress"
  from_port   = 5432
  to_port     = 5432
  cidr_blocks = ["10.0.0.0/16"]
}
