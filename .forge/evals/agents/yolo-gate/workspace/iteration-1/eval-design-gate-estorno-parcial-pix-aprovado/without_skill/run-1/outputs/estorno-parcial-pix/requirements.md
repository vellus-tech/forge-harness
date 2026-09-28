# Requirements — estorno-parcial-pix

## REQ-01 — Solicitar estorno parcial

- **Quando** o lojista envia `POST /api/v1/pagamentos/{id}/estornos` com `valor_centavos` > 0 para uma cobrança Pix liquidada, **o sistema deve** criar um estorno em estado `SOLICITADO` e responder 202 com o `estorno_id`.
- **Critérios de aceite:**
  - [ ] valor em centavos inteiros (long); valores ≤ 0 respondem 422 `VALOR_INVALIDO`.
  - [ ] cobrança não liquidada responde 409 `COBRANCA_NAO_LIQUIDADA`.
- **Rastreia:** proposal §2

## REQ-02 — Limite acumulado

- **Quando** a soma dos estornos não rejeitados de uma cobrança somada ao novo pedido excede o valor original, **o sistema deve** recusar com 422 `LIMITE_EXCEDIDO` sem criar estorno.
- **Critérios de aceite:**
  - [ ] dois pedidos concorrentes que juntos excedem o limite: exatamente um é aceito.
- **Rastreia:** proposal §2

## REQ-03 — Idempotência

- **Quando** o lojista repete o pedido com o mesmo header `Idempotency-Key` em até 24 h, **o sistema deve** devolver a mesma resposta do primeiro pedido sem criar novo estorno.
- **Critérios de aceite:**
  - [ ] repetição com corpo diferente e mesma chave responde 422 `CHAVE_REUSADA`.
- **Rastreia:** proposal §2

## Requisitos não funcionais do change

- **NFR-01 —** p95 de `POST /estornos` ≤ 300 ms com 50 req/s (k6 em staging; métrica `http_server_duration`).

## Fora de escopo (reafirmação)

- Estorno de cartão; estorno iniciado pelo pagador.
