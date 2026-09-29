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

# Acesso do integrador RotaCard (conta AWS 111122223333, role rotacard-sync) ao prefixo
# exports/rotacard/ do bucket de exports, via bucket policy cross-account escopada ao prefixo.
# Opção 2 do pedido em docs/pedido-parceiro.md: evita access key/secret de longa duração
# (opção 1) e evita URL pré-assinada de 7 dias cobrindo o prefixo inteiro (opção 3).
data "aws_iam_policy_document" "exports_rotacard_access" {
  statement {
    sid    = "RotaCardListPrefix"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::111122223333:role/rotacard-sync"]
    }
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.exports.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["exports/rotacard/*"]
    }
  }

  statement {
    sid    = "RotaCardGetObjects"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::111122223333:role/rotacard-sync"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.exports.arn}/exports/rotacard/*"]
  }
}

resource "aws_s3_bucket_policy" "exports_rotacard_access" {
  bucket = aws_s3_bucket.exports.id
  policy = data.aws_iam_policy_document.exports_rotacard_access.json
}
