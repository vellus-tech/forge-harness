# Conflito relevante — pedido do adquirente parceiro × regra de integração

## Resposta ao usuário

Não vou implementar os três pedidos do jeito que o adquirente pediu — cada um viola a regra de integração do projeto (externo é REST ou fila dedicada, gRPC nunca exposto a terceiro, exceção só com ADR) e um deles cria escopo de CHD desnecessário. Isto é conflito arquitetural relevante (segurança/contrato de API e evento), então paro aqui e trago a decisão para você antes de alterar `infra/rabbitmq/definitions.json`, `k8s/` e `contracts/asyncapi/pagamentos.yaml`.

1. **Usuário do parceiro com permissão total no vhost `pagamentos`** (D-AP-02 / RMQ-AP-27) — vhost dá isolamento lógico, não de rede nem de recurso: o parceiro passaria a autenticar nos nós internos, ver e alterar a topologia interna, e um backlog dele dispararia os alarmes de memória/disco do cluster inteiro (que também servem o publicador de pagamento). Correção do catálogo: fila do parceiro num broker ou cluster de borda dedicado, com usuário só dele, TLS e permissão restrita ao prefixo dele, alimentada por shovel/federation (ou o relay do produto); vhost de parceiro no cluster interno só por ADR e com limites (`max-connections`, `max-queues`, `max-length`, `overflow`).
2. **`PaymentService` gRPC publicado em Ingress com TLS** (D-AP-01) — gRPC é malha interna; a superfície externa é REST ou fila, sem exceção, pela regra do dono (`.forge/rules/architecture/internal-grpc-communication.md`, tabela de exceções: "Webhooks recebidos de third-party → REST/JSON"; nenhuma linha cobre "cliente third-party consumindo gRPC interno"). Correção: adaptador REST com OpenAPI só para o que o parceiro precisa (`GetStatus` → `GET /transacoes/{id}/status`), nunca abrir o `.proto` interno; gRPC-Web só para cliente próprio e com ADR — não é o caso aqui.
3. **PAN completo no evento `TransacaoAutorizada`** (T-02) — fila quorum, stream, tópico, DLQ e parking lot são armazenamento persistente; PAN em claro no evento leva o broker, os discos, os backups e as DLQs para o escopo de CHD (PCI DSS), inclusive das filas internas que já consomem esse evento. O schema atual já carrega `pan_token`, que é o formato correto. Se o parceiro casa a conciliação por PAN hoje, a integração deve casar por `pan_token` (ou `transaction_id`) — mudança do lado deles, não do nosso evento.

## Alternativa proposta

- **Consulta de status:** adaptador REST/OpenAPI dedicado ao parceiro (ex.: `GET /parceiros/adquirente/transacoes/{transaction_id}/status`), que internamente chama `PaymentService.GetStatus` via gRPC — o gRPC continua interno, sem Ingress/Gateway/GRPCRoute apontando para `payment-service` ou a porta `50051`.
- **Conciliação:** broker (ou cluster) de borda dedicado ao parceiro, TLS, usuário só dele, alimentado a partir do `pagamentos.eventos` interno por shovel ou federation (alternativa: webhook assíncrono). Nenhuma credencial do parceiro toca o cluster RabbitMQ interno; nenhum usuário `.*` em `infra/rabbitmq/definitions.json`.
- **Evento:** `TransacaoAutorizada` mantém `pan_token` (já presente no schema); a conciliação do parceiro casa por `pan_token`/`transaction_id`, não por PAN.
- Se o negócio decidir que alguma dessas exceções vale a pena mesmo assim (ex.: vhost de parceiro no cluster interno com limites), a regra do dono exige ADR explícito registrando o motivo e os limites — não é uma decisão que o agente toma sozinho na implementação.

## Decisão pendente (HITL)

Preciso que você escolha antes de eu tocar em qualquer um dos três arquivos:

- (a) seguir a alternativa acima (adaptador REST + broker de borda + `pan_token`) — recomendado, sem ADR necessário porque não abre exceção à regra;
- (b) abrir ADR justificando uma das exceções (ex.: vhost de parceiro no cluster interno, com limites RMQ-BP-24) — aí eu implemento conforme o ADR aprovado;
- (c) bloquear a integração até a decisão do negócio ficar clara.

Nada foi alterado em `infra/rabbitmq/definitions.json`, `k8s/` ou `contracts/asyncapi/pagamentos.yaml` enquanto aguardo essa decisão.

## IDs do catálogo citados

D-AP-01, D-AP-02, RMQ-AP-27, T-02 — `.forge` (template, referência): `skills/data-streaming-practices/references/antipatterns.md`.
