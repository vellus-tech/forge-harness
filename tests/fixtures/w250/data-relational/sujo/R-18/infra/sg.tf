resource "aws_security_group_rule" "postgres" {
  type        = "ingress"
  from_port   = 5432
  to_port     = 5432
  cidr_blocks = ["0.0.0.0/0"]
}
