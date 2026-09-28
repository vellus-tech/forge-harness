resource "aws_security_group_rule" "redis" {
  from_port   = 6379
  to_port     = 6379
  cidr_blocks = ["10.0.0.0/16"]
}
