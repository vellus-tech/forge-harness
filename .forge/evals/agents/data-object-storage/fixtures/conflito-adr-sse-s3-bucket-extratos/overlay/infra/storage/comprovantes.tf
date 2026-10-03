resource "aws_s3_bucket" "comprovantes" {
  bucket = "comprovantes-prd"
}

resource "aws_s3_bucket_public_access_block" "comprovantes" {
  bucket                  = aws_s3_bucket.comprovantes.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "comprovantes" {
  bucket = aws_s3_bucket.comprovantes.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
