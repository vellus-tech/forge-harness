resource "aws_security_group_rule" "gestao" { # w250:contexto
  from_port = 15672 # w250:contexto
  cidr_blocks = ["0.0.0.0/0"]
} # w250:contexto
