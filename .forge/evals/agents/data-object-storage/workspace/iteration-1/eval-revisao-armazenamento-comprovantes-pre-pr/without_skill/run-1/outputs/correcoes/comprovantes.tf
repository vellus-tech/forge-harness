resource "aws_s3_bucket" "comprovantes" {
  bucket = "comprovantes-prd"
}

# Corrigido: os quatro controles precisam estar em true. O acesso ao objeto
# é feito exclusivamente via link pré-assinado (ver src/comprovantes/emitir-link.ts);
# não há motivo de negócio para permitir ACL ou bucket policy pública aqui.
resource "aws_s3_bucket_public_access_block" "comprovantes" {
  bucket                  = aws_s3_bucket.comprovantes.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "comprovantes" {
  bucket = aws_s3_bucket.comprovantes.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "comprovantes" {
  bucket = aws_s3_bucket.comprovantes.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.comprovantes.arn
    }
  }
}

# Novo: nega explicitamente qualquer conexão não-TLS ao bucket, em vez de
# depender só do cliente usar HTTPS por padrão.
resource "aws_s3_bucket_policy" "comprovantes_deny_insecure" {
  bucket = aws_s3_bucket.comprovantes.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.comprovantes.arn,
          "${aws_s3_bucket.comprovantes.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Corrigido: rotação automática de chave habilitada (rotação anual gerenciada
# pela AWS) — antes ausente.
resource "aws_kms_key" "comprovantes" {
  description         = "Chave dos comprovantes"
  enable_key_rotation = true
}
