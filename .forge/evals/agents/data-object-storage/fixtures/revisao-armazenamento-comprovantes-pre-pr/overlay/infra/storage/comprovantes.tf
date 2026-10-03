resource "aws_s3_bucket" "comprovantes" {
  bucket = "comprovantes-prd"
}

resource "aws_s3_bucket_public_access_block" "comprovantes" {
  bucket                  = aws_s3_bucket.comprovantes.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
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

resource "aws_kms_key" "comprovantes" {
  description = "Chave dos comprovantes"
}
