resource "aws_s3_bucket_public_access_block" "comprovantes" {
  block_public_acls = true
}
rule {
  bucket_key_enabled = true
  apply_server_side_encryption_by_default {
    sse_algorithm = "aws:kms"
  }
}
