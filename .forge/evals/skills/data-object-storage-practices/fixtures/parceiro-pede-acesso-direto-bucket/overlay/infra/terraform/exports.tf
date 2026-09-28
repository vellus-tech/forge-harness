# Bucket de exports: arquivos de conciliação por parceiro em exports/<parceiro>/AAAA-MM-DD.csv.
resource "aws_s3_bucket" "exports" {
  bucket = "bilhetagem-exports-prd"
}

resource "aws_s3_bucket_public_access_block" "exports" {
  bucket                  = aws_s3_bucket.exports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "exports" {
  bucket = aws_s3_bucket.exports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.exports_kms_arn
    }
    bucket_key_enabled = true
  }
}
