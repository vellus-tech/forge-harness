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

# Prefixos atuais: bronze/validacoes/ (validadores embarcados), bronze/cadastro/ (export diário do
# cadastro de passageiros — PII: nome, CPF, e-mail, telefone; sem obrigação legal de retenção
# registrada, logo sem Object Lock — precisa continuar eliminável pela LGPD).
#
# bronze/liquidacao/ (arquivo de liquidação da adquirente) NÃO fica neste bucket: ver
# aws_s3_bucket.bronze_liquidacao abaixo e docs/design-bronze.md para o motivo (Object Lock só se
# liga na criação do bucket; este bucket já existe com bronze/cadastro/ e bronze/validacoes/ dentro,
# e um deny-DeleteObject ou Object Lock bucket-wide aqui prenderia PII do cadastro sem base legal).

# ---------------------------------------------------------------------------------------------
# Bucket dedicado: bronze/liquidacao/ — arquivo de liquidação da adquirente (contém PAN completo,
# 16–19 dígitos, sem máscara — CHD sob PCI DSS). Bucket próprio porque:
#   1. Object Lock só pode ser habilitado NA CRIAÇÃO do bucket (aws_s3_bucket.object_lock_enabled é
#      immutable/ForceNew) — não dá para ligar retroativamente em "pagamentos-bronze-prd" sem
#      recriá-lo, o que destruiria bronze/cadastro/ e bronze/validacoes/ já em produção.
#   2. Um Object Lock ou deny-DeleteObject bucket-wide travaria também bronze/cadastro/ (PII sem
#      obrigação legal de retenção — precisa seguir eliminável pela LGPD) e bronze/validacoes/
#      (nem é dado de negócio). WORM só se aplica ao prefixo com obrigação legal registrada
#      (docs/fonte-liquidacao.md: 18 meses para contestação de chargeback).
resource "aws_s3_bucket" "bronze_liquidacao" {
  bucket              = "pagamentos-bronze-liquidacao-prd"
  object_lock_enabled = true
}

resource "aws_s3_bucket_versioning" "bronze_liquidacao" {
  bucket = aws_s3_bucket.bronze_liquidacao.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Defesa em profundidade no nível do bucket. NÃO é o controle principal de PCI DSS 3.5.1/3.5.1.2
# para o PAN em claro que este bucket recebe — SSE-KMS é criptografia transparente de armazenamento
# e, sozinha, não atende 3.5.1.2 em mídia não removível. O controle primário é a criptografia em
# nível de arquivo, com chave gerida fora do lake (CDE), aplicada na borda de ingestão ANTES do
# PUT — ver docs/design-bronze.md, "Pendência fora do Terraform".
resource "aws_s3_bucket_server_side_encryption_configuration" "bronze_liquidacao" {
  bucket = aws_s3_bucket.bronze_liquidacao.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.bronze_liquidacao_kms_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "bronze_liquidacao" {
  bucket                  = aws_s3_bucket.bronze_liquidacao.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Object Lock em modo COMPLIANCE, retenção default de 548 dias (18 meses) — o único prazo com
# obrigação legal registrada para esta fonte (docs/fonte-liquidacao.md: contestação de chargeback).
# NÃO 5 anos: não há base legal documentada para esse prazo aqui, e travar por mais tempo que o
# exigido é reter dado sem base (contraria PCI DSS 3.2.1 e o princípio de minimização da LGPD).
# Compliance mode é irreversível (nem o root apaga durante a retenção) — validar esta configuração
# em modo GOVERNANCE num bucket de teste antes de aplicar aqui, conforme a prática recomendada.
resource "aws_s3_bucket_object_lock_configuration" "bronze_liquidacao" {
  bucket = aws_s3_bucket.bronze_liquidacao.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 548
    }
  }
}

# Ciclo de vida: expira o objeto exatamente no prazo de retenção documentado. Sem isso, Object Lock
# em compliance mode vira retenção "para sempre" na prática — e o jurídico pede eliminação depois
# dos 18 meses, não retenção indefinida (PCI DSS 3.2.1: reter só pelo prazo com base legal, depois
# eliminar). A expiração por ciclo de vida é ação do próprio serviço S3, não uma chamada
# DeleteObject sujeita a policy — por isso não é preciso (nem desejável) uma policy adicional
# negando DeleteObject aqui: o Object Lock já impede exclusão ANTES do prazo, e a expiração cuida
# da exclusão DEPOIS dele. [Interp. — validar este comportamento de exceção do lifecycle a policy
# de bucket com o time de plataforma/QSA antes de confiar nele como único mecanismo.]
resource "aws_s3_bucket_lifecycle_configuration" "bronze_liquidacao" {
  bucket = aws_s3_bucket.bronze_liquidacao.id
  rule {
    id     = "expira-liquidacao-18-meses"
    status = "Enabled"
    filter {
      prefix = "liquidacao/"
    }
    expiration {
      days = 548
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
