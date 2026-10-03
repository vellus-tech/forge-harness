# Zona bronze do lake: arquivos brutos das fontes, no formato em que chegam.
resource "aws_s3_bucket" "bronze" {
  bucket = "pagamentos-bronze-prd"
}

resource "aws_s3_bucket_versioning" "bronze" {
  bucket = aws_s3_bucket.bronze.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bronze" {
  bucket = aws_s3_bucket.bronze.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.bronze_kms_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "bronze" {
  bucket                  = aws_s3_bucket.bronze.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Prefixos atuais: bronze/validacoes/ (validadores embarcados), bronze/cadastro/ (export diário do cadastro de passageiros).

# --------------------------------------------------------------------------------------------------
# bronze/liquidacao/ — arquivo de liquidação da adquirente (docs/fonte-liquidacao.md)
#
# DECISÃO DE DESENHO (ver docs/design-bronze.md para o raciocínio completo): o pedido original era
# habilitar Object Lock modo compliance no bucket `pagamentos-bronze-prd` inteiro. Isso não foi
# implementado como pedido, por dois motivos técnicos, não por preferência:
#
#   1. Object Lock só pode ser habilitado na CRIAÇÃO do bucket (ou por pedido ao suporte AWS para um
#      bucket já existente com versionamento). `pagamentos-bronze-prd` já existe e já está em uso —
#      não há como o Terraform "ligar" Object Lock nele em uma alteração normal de recurso.
#   2. Mesmo que fosse possível, Object Lock é uma configuração de BUCKET, não de prefixo. Travar o
#      bucket inteiro em modo compliance por 5 anos trava também bronze/cadastro/ (CPF, e-mail,
#      telefone de passageiros) — dado sujeito a pedido de eliminação via LGPD Art. 18, que ficaria
#      tecnicamente impossível de atender até o retention expirar. Não há como excluir um prefixo do
#      Object Lock do bucket.
#
# Por isso, a liquidação da adquirente ganha um bucket dedicado, com Object Lock habilitado desde a
# criação e escopo restrito a essa única fonte.
# --------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "bronze_liquidacao_worm" {
  bucket              = "pagamentos-bronze-liquidacao-worm-prd"
  object_lock_enabled = true
}

resource "aws_s3_bucket_versioning" "bronze_liquidacao_worm" {
  bucket = aws_s3_bucket.bronze_liquidacao_worm.id
  versioning_configuration {
    status = "Enabled" # obrigatório para Object Lock
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bronze_liquidacao_worm" {
  bucket = aws_s3_bucket.bronze_liquidacao_worm.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.bronze_kms_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "bronze_liquidacao_worm" {
  bucket                  = aws_s3_bucket.bronze_liquidacao_worm.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ATENÇÃO — RETENÇÃO: implementado com os 5 anos / modo compliance pedidos, mas isso diverge do
# requisito jurídico registrado em docs/fonte-liquidacao.md (18 meses, com eliminação obrigatória
# depois disso). Em modo compliance NINGUÉM — nem root, nem suporte AWS — consegue apagar ou reduzir
# o retention antes do prazo. Se o jurídico não confirmar por escrito uma retenção de 5 anos
# especificamente para esta fonte, este objeto vai ficar preso 3,5 anos além da obrigação legal
# descrita, sem forma de correção. Ver "Pendência para decisão humana" em docs/design-bronze.md antes
# de aplicar isto em produção — este é o maior risco desta mudança.
resource "aws_s3_bucket_object_lock_configuration" "bronze_liquidacao_worm" {
  bucket = aws_s3_bucket.bronze_liquidacao_worm.id
  rule {
    default_retention {
      mode  = "COMPLIANCE"
      years = 5
    }
  }
}

# Nega DeleteObject/DeleteObjectVersion em bronze/liquidacao/* para qualquer principal, e nega
# tentativa de contornar o retention via governance bypass. Redundante com o Object Lock em modo
# compliance (que já bloqueia exclusão), mas mantido por defesa em profundidade e porque foi pedido
# explicitamente — também nega tráfego fora de TLS, hardening padrão de bucket que guarda dado de
# cartão.
resource "aws_s3_bucket_policy" "bronze_liquidacao_worm" {
  bucket = aws_s3_bucket.bronze_liquidacao_worm.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyDeleteLiquidacao"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
        ]
        Resource = "${aws_s3_bucket.bronze_liquidacao_worm.arn}/bronze/liquidacao/*"
      },
      {
        Sid       = "DenyRetentionBypass"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:BypassGovernanceRetention"
        Resource  = "${aws_s3_bucket.bronze_liquidacao_worm.arn}/bronze/liquidacao/*"
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.bronze_liquidacao_worm.arn,
          "${aws_s3_bucket.bronze_liquidacao_worm.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })
}

# Prefixo único deste bucket: bronze/liquidacao/ (arquivo posicional da adquirente, layout v4, como
# chega do SFTP — inclui PAN completo sem máscara; ver docs/design-bronze.md, seção PCI DSS).
