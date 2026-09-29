# ADR-0001 — gRPC interno, REST externo

- Status: Aceito · 2026-07-30

Comunicação entre módulos é gRPC com contrato .proto versionado; a superfície externa (app do passageiro, gateway de pagamento) é REST. Eventos assíncronos trafegam no RabbitMQ.
