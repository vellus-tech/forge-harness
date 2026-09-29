# Bucket do lake (bronze/silver/gold), acessado só de dentro da VPC.
resource "aws_s3_bucket" "lake" {
  bucket = "bilhetagem-lake-prd"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.lake_kms_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "lake" {
  bucket = aws_s3_bucket.lake.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "SomenteViaVpce"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject"]
      Resource  = "${aws_s3_bucket.lake.arn}/*"
      Condition = { StringEquals = { "aws:SourceVpce" = var.lake_vpce_id } }
    }]
  })
}
