-- Ingestão de telemetria dos validadores — banco lógico dedicado (ex.: telemetria_db),
-- Postgres + extensão TimescaleDB. Separado do ledger_db por perfil de carga (ver ADR).
-- Chunk interval, política de compressão e retenção abaixo são pontos de partida —
-- precisam de ajuste com dados reais de volumetria (ver "Questões em aberto" no ADR).

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE telemetry_readings (
    tenant_id      UUID NOT NULL,
    equipment_id   UUID NOT NULL,
    reading_at     TIMESTAMPTZ NOT NULL,
    metric_payload JSONB NOT NULL,   -- trocar por colunas tipadas quando o schema do
                                      -- validador estiver estável (schema-evolution.md)
    ingested_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hypertable particionada por tempo. chunk_time_interval de 1h é um ponto de partida —
-- ajustar com a contagem real de equipamentos/tenant.
SELECT create_hypertable(
    'telemetry_readings',
    'reading_at',
    chunk_time_interval => INTERVAL '1 hour'
);

-- Padrão de consulta declarado: "por equipamento, últimas 24h".
CREATE INDEX idx_telemetry_readings_tenant_equipment_time
    ON telemetry_readings (tenant_id, equipment_id, reading_at DESC);

-- Isolamento multi-tenant: data-config-sql.md torna RLS obrigatório para tabela multi-tenant
-- de domínio em Postgres, sem exceção documentada para hypertable. Incluído aqui como
-- suposição a validar em spike — comportamento de RLS sobre chunk comprimido não é algo
-- que eu possa garantir sem testar.
ALTER TABLE telemetry_readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_telemetry_readings ON telemetry_readings
    USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Compressão: segmentar por tenant + equipamento para preservar a localidade da consulta
-- "últimas 24h por equipamento" mesmo em chunks comprimidos.
ALTER TABLE telemetry_readings SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'tenant_id, equipment_id',
    timescaledb.compress_orderby = 'reading_at DESC'
);

-- Comprimir o que já saiu da janela quente de consulta (24h). Valor conservador de
-- partida — ajustar após medir o padrão real de consulta.
SELECT add_compression_policy('telemetry_readings', INTERVAL '2 hours');

-- Retenção: NÃO decidido — depende de exigência regulatória/contratual que não foi
-- informada. Exemplo de como se aplicaria quando o prazo estiver definido:
-- SELECT add_retention_policy('telemetry_readings', INTERVAL '90 days');

-- Nenhum trigger de imutabilidade aqui — telemetria bruta não está no mesmo regime de
-- audit-immutability.md do ledger, e um trigger BEFORE UPDATE/DELETE bloquearia a própria
-- compressão/retenção do Timescale. Reavaliar se compliance exigir imutabilidade também
-- para telemetria.
