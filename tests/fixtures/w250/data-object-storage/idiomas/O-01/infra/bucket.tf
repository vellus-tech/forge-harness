resource "aws_s3_bucket_policy" "p" { # w250:contexto
  policy = jsonencode({ Statement = [{ Effect = "Allow", Principal = "*", Action = "s3:GetObject" }] })
} # w250:contexto
resource "aws_s3_bucket_public_access_block" "b" { # w250:contexto
  block_public_policy = false
  ignore_public_acls = false
  restrict_public_buckets = false
} # w250:contexto
resource "azurerm_storage_container" "c" { container_access_type = "blob" }
