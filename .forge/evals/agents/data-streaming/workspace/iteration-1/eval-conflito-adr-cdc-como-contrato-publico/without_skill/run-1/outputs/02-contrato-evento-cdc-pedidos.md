# Contrato consumido pelo faturamento (conforme ADR-0004, em vigor)

## Tópico

`pedidos.public.pedidos` — gerado pelo Debezium sobre a tabela `public.pedidos` do serviço de pedidos (connector Postgres CDC). Faturamento é apenas consumidor; não há publisher de domínio a desenhar no lado de pedidos porque a ADR-0004 decidiu não ter outbox nem evento de aplicação.

## Envelope (formato Debezium, não controlado pelo faturamento)

```json
{
  "before": {
    "id": "uuid",
    "status": "PENDENTE",
    "valor_centavos": 12345,
    "atualizado_em": "2026-09-28T12:00:00.000Z"
  },
  "after": {
    "id": "uuid",
    "status": "CONFIRMADO",
    "valor_centavos": 12345,
    "atualizado_em": "2026-09-28T12:00:05.000Z"
  },
  "source": { "table": "pedidos", "schema": "public", "ts_ms": 1758000000000 },
  "op": "u",
  "ts_ms": 1758000000000
}
```

Campos relevantes para o faturamento: `after.id` (pedidoId), `after.status`, `after.valor_centavos`, `before.status` (para detectar a transição, não só o estado). `op` distingue `c` (insert), `u` (update), `d` (delete), `r` (snapshot inicial) — só `u`/`r` interessam aqui.

## Regra de negócio derivada (não existe evento `PedidoConfirmado` explícito)

"Pedido confirmado" não é um tipo de mensagem — é uma transição de estado inferida no consumidor: `before.status !== 'CONFIRMADO' && after.status === 'CONFIRMADO'`. Isso é uma dívida técnica herdada da ADR-0004, registrada aqui explicitamente porque é o ponto mais frágil deste desenho: qualquer mudança de coluna ou de valores de `status` na tabela `public.pedidos` quebra o faturamento silenciosamente se não houver aviso do time de pedidos (a própria ADR já avisa disso em "Consequências").

## Idempotência

`after.id` + `after.atualizado_em` (ou o offset do tópico, que já é particionado por chave de pedido pelo connector Debezium por padrão) servem de chave de deduplicação. O faturamento deve tratar reprocessamento do mesmo evento (replay de partição, restart de consumer group) como não-efeito: verificar se já existe fatura emitida para `pedidoId` antes de emitir de novo.

## Risco assumido, não resolvido por este desenho

Consumir CDC bruto acopla o faturamento ao schema interno de pedidos — é o próprio risco que a ADR-0004 assume conscientemente. Ver `outputs/01-CONFLITO-bloqueante.md` para a decisão pendente sobre manter esse acoplamento ou migrar para evento de domínio via nova ADR.
