resource "aws_security_group_rule" "https" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  cidr_blocks = ["0.0.0.0/0"]
}
