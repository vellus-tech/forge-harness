resource "aws_security_group_rule" "mongo" {
  from_port   = 27017
  to_port     = 27017
  cidr_blocks = ["0.0.0.0/0"]
}
