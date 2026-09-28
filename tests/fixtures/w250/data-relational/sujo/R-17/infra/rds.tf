resource "aws_db_instance" "principal" {
  engine              = "postgres"
  publicly_accessible = true
}
