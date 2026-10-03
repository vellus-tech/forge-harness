# Nota: variables.tf não existia no projeto (var.bronze_kms_arn já era referenciada em bronze.tf
# sem declaração local — provavelmente declarada em outro arquivo fora do escopo lido nesta tarefa).
# Esta entrada é só a variável nova que este change introduz.

variable "bronze_liquidacao_kms_arn" {
  description = <<-EOT
    ARN da chave KMS usada pelo SSE-KMS do bucket pagamentos-bronze-liquidacao-prd. Esta chave é a
    defesa em profundidade do bucket, não o controle principal de PCI DSS 3.5.1.2 para o PAN em
    claro no arquivo — ver docs/design-bronze.md. Recomendado: chave dedicada a este bucket (não
    reaproveitar var.bronze_kms_arn), com policy de menor privilégio e rotação.
  EOT
  type        = string
}
