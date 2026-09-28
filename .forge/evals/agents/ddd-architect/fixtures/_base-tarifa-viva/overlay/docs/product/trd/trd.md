# TRD — Tarifa Viva

## Decisões técnicas existentes
- TEC-01: backend em serviços containerizados; comunicação interna gRPC; superfície externa REST.
- TEC-02: PostgreSQL como banco transacional; mensageria via fila (RabbitMQ).
- TEC-03: o validador embarcado roda firmware de terceiro (fornecedor ValidaBus) com protocolo proprietário de sincronização em lote; o modelo de dados dele é instável entre versões de firmware.
- TEC-04: push via provedor terceirizado (Firebase Cloud Messaging).
