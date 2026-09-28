resource "aws_security_group_rule" "amqp" {
  from_port   = 5672
  to_port     = 5672
  cidr_blocks = ["0.0.0.0/0"]
}
