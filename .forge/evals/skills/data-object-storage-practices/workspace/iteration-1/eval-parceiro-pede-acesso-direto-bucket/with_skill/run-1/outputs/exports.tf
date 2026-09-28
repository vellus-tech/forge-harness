# Bucket de exports: arquivos de conciliação por parceiro em exports/<parceiro>/AAAA-MM-DD.csv.
#
# Pedido do integrador RotaCard (docs/pedido-parceiro.md, 2026-09-28): usuário IAM com access
# key, bucket policy para a conta AWS deles, ou URL pré-assinada de todo o prefixo válida por
# 7 dias. Nenhuma das três é implementada aqui: a decisão H-02 (a) do dono do domínio
# object-storage só admite entrega a terceiro por URL pré-assinada de um único objeto nomeado,
# expiração em minutos, emitida por endpoint REST autenticado do produto, com log de emissão e
# bucket privado. Ver docs/resposta-rotacard.md e o registro em outputs/decisao-acesso-rotacard.md.
# Este bucket permanece privado (nenhuma policy/ACL/usuário IAM adicionados para terceiros).
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
