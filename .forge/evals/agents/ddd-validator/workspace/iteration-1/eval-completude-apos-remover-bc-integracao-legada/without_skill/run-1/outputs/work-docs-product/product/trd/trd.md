# TRD — Embarque Fácil

- Serviços backend em Go; comunicação interna via gRPC (ADR-0001).
- PostgreSQL com um schema por bounded context; nenhum serviço acessa schema de outro contexto (ADR-0002).
- Eventos de integração em RabbitMQ com contrato versionado (Published Language).
- Deployables: `validacao-svc`, `carteira-svc`, `recarga-svc`, `notificacoes-svc`, `bff-app`.
