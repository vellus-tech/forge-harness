# TRD — Tarifa Viva

- Serviços em Go, comunicação interna gRPC; superfície externa REST.
- Mensageria: RabbitMQ (exchange `tarifa-viva.eventos`).
- Persistência: PostgreSQL por serviço; Redis como cache de listas de bloqueio no validador.
- Adquirente de recarga: gateway REST da adquirente contratada (tokenização + autorização).
- Liquidação: CronJob diário às 02:00 gera arquivo CNAB por operadora em bucket S3.
