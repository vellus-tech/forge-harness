resource "aws_s3_bucket" "lake" {
  bucket              = "lake-pagamentos"
  object_lock_enabled = true
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.lake.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_kms_key" "lake" {
  description = "Chave do lake de pagamentos"
}

# Object Lock exige versionamento explícito no provider (não basta object_lock_enabled
# na criação do bucket) — sem este recurso, aws_s3_bucket_object_lock_configuration falha.
resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    default_retention {
      mode  = "COMPLIANCE"
      years = 10
    }
  }
  depends_on = [aws_s3_bucket_versioning.lake]
}

# Nega s3:DeleteObject e s3:DeleteObjectVersion em todo o prefixo bronze/.
# Redundante com o Object Lock COMPLIANCE (que já bloqueia deleção mecanicamente
# até o fim da retenção), mas adiciona defesa em profundidade contra alteração
# futura da configuração de lock ou contra principals com bypass governance.
# ATENÇÃO: este Deny não tem exceção — nem para papéis de break-glass/incident-response.
# Confirmar com o time de segurança se algum principal precisa de uma condição de exclusão
# antes de aplicar em produção.
resource "aws_s3_bucket_policy" "lake_bronze_deny_delete" {
  bucket = aws_s3_bucket.lake.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyDeleteObjectBronze"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
        ]
        Resource = "${aws_s3_bucket.lake.arn}/bronze/*"
      },
    ]
  })
}
