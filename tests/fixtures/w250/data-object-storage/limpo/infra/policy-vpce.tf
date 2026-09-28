resource "aws_s3_bucket_policy" "interno" {
  policy = jsonencode({ Statement = [{ Effect = "Allow", Principal = "*", Action = "s3:GetObject", Condition = { StringEquals = { "aws:SourceVpce" = var.vpce } } }] })
}
