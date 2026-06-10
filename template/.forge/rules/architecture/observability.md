---
title: Observabilidade e Auditoria
applies_to:
  - backend
  - platform
priority: high
last_reviewed: 2026-05-08
---

# Observabilidade e Auditoria

## Os Três Pilares (Todos Obrigatórios)

**Métricas · Logs · Traces** — os três são mandatórios. Nenhum serviço vai para produção sem os três implementados.

## Correlation ID

- Todo request recebe um `correlationId` (UUID v4) na entrada — gerado pelo gateway ou pelo serviço se ausente
- `correlationId` propagado em todos os logs, eventos e chamadas downstream
- `correlationId` incluído em toda resposta de erro (`{ "error": "...", "code": "...", "correlationId": "..." }`)

## Métricas (Prometheus)

- Exposição via `/metrics` (prometheus-net)
- Métricas obrigatórias por serviço:
  - `http_requests_total` (por método, rota, status)
  - `http_request_duration_seconds` (histograma p50/p95/p99)
  - `domain_events_published_total` (por tipo de evento)
- ServiceMonitor configurado para coleta pelo Prometheus do cluster

## Logs (Loki via Promtail)

- Formato: JSON estruturado
- Campos obrigatórios em todos os logs: `correlationId`, `service`, `level`, `timestamp`
- Logs de ações sensíveis DEVEM incluir: quem (`userId`, `tenantId`), quando, origem (IP/serviço), o quê
- Logs **NUNCA** devem conter dados sensíveis: senhas, tokens, PAN, CPF, dados de pagamento
- Mascaramento obrigatório quando dados de log rozeiam PII

## Traces (Jaeger / OpenTelemetry)

- OpenTelemetry SDK configurado em todo serviço backend
- Spans criados para: handlers de comando/query, chamadas HTTP externas, operações de banco
- `correlationId` como atributo do trace root

## Audit Trail

- **Toda mudança de estado** deve ser auditável: quem, quando, por quê, de onde
- Dados de auditoria são **imutáveis** — tabelas `audit_*` são append-only
- Trigger de imutabilidade no banco (REVOKE UPDATE/DELETE + RAISE EXCEPTION)
- Retenção regulatória obrigatória (não usar TTL em tabelas de auditoria)
- Cross-ref: `domain/audit-immutability.md` (Fase 2.9)

## Stack Local

| Ferramenta | Porta | Propósito |
|------------|-------|-----------|
| Grafana | `localhost:3030` | Dashboards metrics + logs |
| Prometheus | `localhost:9090` | Coleta de métricas |
| Loki | `localhost:3100` | Agregação de logs |
| Jaeger UI | `localhost:16686` | Visualização de traces |
| Promtail | — | Coleta e envio de logs ao Loki |

Configurações em `platform/docker/compose/`.

## Dashboards Grafana

Cada serviço em produção DEVE ter dashboard provisionado em `platform/docker/compose/grafana/dashboards/` cobrindo:
- Taxa de requisições e latência (p95/p99)
- Taxa de erros 4xx/5xx
- Eventos de domínio publicados
- Saúde dos health checks

## Proibições Explícitas

- Deploy sem métricas expostas
- Logs sem `correlationId`
- PII em logs (senhas, tokens, CPF, dados de pagamento)
- Audit trail mutável (UPDATE/DELETE em tabelas `audit_*`)
