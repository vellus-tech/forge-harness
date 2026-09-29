# Chave de partição = cartao_id: alinhada ao padrão de leitura dominante (histórico do cartão,
# ~3.000 req/s) e de alta cardinalidade (cada cartão é uma partição), o que também distribui os
# ~12.000 registros/s de escrita do pico de rush. A chave anterior (data_validacao) tinha um único
# valor por dia — toda a escrita do dia caía numa partição só, muito acima do teto de 1.000 WCU/s
# por partição (N-06, catálogo data-nosql-practices).
#
# Chave de ordenação = validacao_sk (ISO-8601 do instante + validacao_id): mantém as validações de
# um cartão ordenadas por data e serve a consulta "últimos 30 dias" com Query + begins_with/>=,
# sem Scan (N-08).
resource "aws_dynamodb_table" "validacoes" {
  name         = "validacoes-catraca"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "cartao_id"
  range_key    = "validacao_sk"

  attribute {
    name = "cartao_id"
    type = "S"
  }
  attribute {
    name = "validacao_sk"
    type = "S"
  }
  # Chave composta e "shardeada" da GSI do painel do operador — ver comentário na GSI abaixo.
  attribute {
    name = "tenant_status_shard"
    type = "S"
  }
  attribute {
    name = "em"
    type = "S"
  }

  # Painel do operador: validações RECEBIDA ainda não conciliadas, por tenant; tolera segundos de
  # atraso (eventual consistency da GSI é aceitável — não usar ConsistentRead, N-11).
  #
  # Chave de partição = tenant_status_shard, não apenas "status" (N-06 do design original) nem
  # apenas "tenant": o número de tenants (operadoras) é baixo frente aos ~12.000 writes/s, e toda
  # validação nasce com status RECEBIDA — ou seja, a GSI recebe essencialmente o mesmo pico de
  # escrita da tabela base concentrado em poucas partições por tenant. Write sharding por sufixo
  # (SHARD_COUNT, ver services/validacoes/src/handlers) distribui esse pico; o leitor faz
  # SHARD_COUNT queries paralelas e junta o resultado (aceitável pela folga de "alguns segundos").
  # SHARD_COUNT = 10 é heurística de partida — meça com CloudWatch Contributor Insights por tenant
  # em homologação antes de produção e ajuste (fora do alcance desta varredura estática).
  #
  # Projeção INCLUDE (não ALL, N-10): o painel só precisa dos campos abaixo, não do item inteiro.
  global_secondary_index {
    name               = "por-tenant-status"
    hash_key           = "tenant_status_shard"
    range_key          = "em"
    projection_type    = "INCLUDE"
    non_key_attributes = ["validacao_id", "cartao_id", "linha", "status", "tenant"]
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "cartoes" {
  name         = "cartoes-transporte"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "cartao_id"

  attribute {
    name = "cartao_id"
    type = "S"
  }
}
