rule {
  apply_server_side_encryption_by_default {
    sse_algorithm = "aws:kms"
  }
}
