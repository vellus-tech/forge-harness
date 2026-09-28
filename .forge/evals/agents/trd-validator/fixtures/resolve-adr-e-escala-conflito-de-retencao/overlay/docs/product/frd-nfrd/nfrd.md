# NFRD - Axis Validação

| Código | Categoria | Requisito |
|---|---|---|
| NFRD-PERF-01 | Performance | Latência p99 da validação de embarque (validador → resposta) ≤ 300 ms em horário de pico (5.000 validações/min). |
| NFRD-OBS-01 | Observabilidade | Todos os serviços emitem logs estruturados em JSON com `correlation_id` propagado entre serviços e eventos, métricas RED (rate, errors, duration) por endpoint e alerta quando p99 > 300 ms por 5 minutos. |
| NFRD-OBS-02 | Observabilidade | Health checks de liveness e readiness em todos os deployables. |
| NFRD-SEC-01 | Segurança | O PAN nunca é recebido, persistido nem logado pelos serviços Axis; somente o token emitido pelo gateway (ADR-0003). |
| NFRD-RET-01 | Retenção | Validações de embarque retidas por 5 anos para auditoria das operadoras. |
