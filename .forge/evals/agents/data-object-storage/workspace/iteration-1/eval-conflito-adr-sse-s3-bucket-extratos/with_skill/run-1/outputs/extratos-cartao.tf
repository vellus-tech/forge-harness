# Rascunho no padrão de infra/storage/comprovantes.tf.
# Entregue como está: este agente (data-object-storage) não tem Write/Edit — não aplica na árvore.
# Quem aplica (task-coder ou agente de engenharia) só o faz depois da decisão humana sobre o
# bloco de criptografia abaixo, ver outputs/resposta.md (bloco CONFLITO).

resource "aws_s3_bucket" "extratos_cartao" {
  bucket = "extratos-cartao-prd"
}

resource "aws_s3_bucket_public_access_block" "extratos_cartao" {
  bucket                  = aws_s3_bucket.extratos_cartao.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- BLOQUEADO por conflito arquitetural — não preenchido por este agente ---------------------
# ADR-0003 (baseline) manda SSE-S3/AES256 em todo bucket novo, citando nominalmente
# "comprovantes, extratos, faturas". O checklist da skill data-object-storage-practices recomenda
# SSE-KMS com Bucket Key para dado regulado/PII, categoria em que name+CPF+últimos 4 dígitos do
# cartão se enquadra. Isolamento de dados/segurança é conflito arquitetural relevante por
# .forge/rules/conventions/conflict-handling.md §2 — bloqueante, decisão só depois do HITL.
# Ver outputs/resposta.md para o bloco CONFLITO completo e as duas opções de preenchimento prontas.
#
# resource "aws_s3_bucket_server_side_encryption_configuration" "extratos_cartao" {
#   bucket = aws_s3_bucket.extratos_cartao.id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "<PENDENTE: AES256 (ADR-0003) | aws:kms (checklist do agente)>"
#       # se aws:kms: kms_master_key_id = aws_kms_key.extratos_cartao.arn
#     }
#     bucket_key_enabled = true  # obrigatório se aws:kms (evita O-08 — throttling/custo de KMS,
#                                # o mesmo sintoma que motivou o ADR-0003 em 2026-02)
#   }
# }
# -------------------------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "extratos_cartao" {
  bucket = aws_s3_bucket.extratos_cartao.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Retenção de 5 anos por ciclo de vida (expiração), não Object Lock/WORM: a rule de
# best-practices só recomenda WORM compliance quando há obrigação legal de retenção registrada,
# e o pedido não cita uma — nada aqui impede trocar por Object Lock depois, com ADR próprio, se
# a obrigação legal for identificada.
resource "aws_s3_bucket_lifecycle_configuration" "extratos_cartao" {
  bucket = aws_s3_bucket.extratos_cartao.id

  rule {
    id     = "retencao-5-anos"
    status = "Enabled"

    expiration {
      days = 1826 # 5 anos
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Entrega ao app do produto: cliente próprio não é terceiro, mas a rule de integração exige
# registro em ADR para qualquer exceção de acesso direto de cliente. Padrão recomendado — mesmas
# restrições da decisão H-02 (a), estendidas ao app do produto via endpoint REST autenticado do
# backend de faturas (não do S3 direto):
#   1. App autentica no backend de faturas (REST, JWT do auth-service do produto).
#   2. Backend valida que o CPF/titular da sessão é dono do PDF pedido (autorização por
#      necessidade de conhecimento — Req 7).
#   3. Backend emite URL pré-assinada: HTTPS, objeto único, expiração em minutos, log de emissão.
#   4. App baixa direto da URL pré-assinada; nunca recebe credencial IAM nem policy do bucket.
# Isto é recomendação de desenho, não Terraform de IAM de app (fora do escopo deste agente —
# políticas de app ficam com quem desenha o backend de faturas).
