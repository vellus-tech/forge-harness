resource "aws_security_group_rule" "redis_tls" { # w250:contexto
  from_port = 6380 # w250:contexto
  cidr_blocks = ["0.0.0.0/0"]
} # w250:contexto
