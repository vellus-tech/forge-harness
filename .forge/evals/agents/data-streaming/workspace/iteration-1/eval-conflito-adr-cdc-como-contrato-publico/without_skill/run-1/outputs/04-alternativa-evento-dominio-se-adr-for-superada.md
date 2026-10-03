# Alternativa: evento de domínio `PedidoConfirmado` — só se a ADR-0004 for superada

Não implementar sem uma ADR nova aprovada que supere a ADR-0004 (ver `outputs/01-CONFLITO-bloqueante.md`). Registrado aqui apenas para não bloquear o `task-coder` caso a decisão humana vá nessa direção.

## Contrato AsyncAPI (esboço, formato exigido por `.forge/rules/architecture/api-and-contracts.md`)

```yaml
asyncapi: 3.0.0
info:
  title: Eventos de Pedido
  version: 1.0.0
channels:
  pedido-confirmado:
    address: pedidos.eventos.pedido-confirmado
    messages:
      PedidoConfirmado:
        payload:
          type: object
          required: [pedidoId, valorCentavos, confirmadoEm]
          properties:
            pedidoId:
              type: string
              format: uuid
            valorCentavos:
              type: integer
              minimum: 0
            confirmadoEm:
              type: string
              format: date-time
```

## Pré-requisitos de infraestrutura que essa alternativa implica

- Tabela de outbox em `services/pedidos` (transacional com o `UPDATE` de status em `repositorio.ts`) + relay (ex. Debezium Outbox Event Router) publicando em `pedidos.eventos.pedido-confirmado`.
- Retirar o acoplamento do faturamento ao schema interno de `public.pedidos` (resolve o risco descrito em `outputs/02`).
- Custo de implementação que a própria ADR-0004 já descartou uma vez por esse motivo ("Alternativas descartadas") — a nova ADR precisa justificar por que o trade-off mudou.
