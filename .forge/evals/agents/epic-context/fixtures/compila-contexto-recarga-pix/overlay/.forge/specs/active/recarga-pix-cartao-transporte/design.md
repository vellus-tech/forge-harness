# Design — recarga-pix-cartao-transporte

## Visão geral

O módulo `recarga` passa a orquestrar a recarga Pix. A emissão da cobrança e o recebimento do webhook ficam no módulo `pix`, que publica o evento de domínio `RecargaPixLiquidada` consumido por `recarga`.

## Decisões

1. **Crédito só na liquidação** — o crédito do saldo é disparado pelo evento `RecargaPixLiquidada`, nunca pela criação da cobrança (REQ-02). Impacto: toda story de crédito depende do consumidor do evento, não do endpoint de criação.
2. **Idempotência por `txid`** — tabela `recarga_pix` com constraint única em `txid`; o consumidor faz upsert e ignora reentrega (REQ-03). Detalhado em ADR-0012.
3. **Comunicação interna gRPC** — `recarga` chama `pix.CobrancaService/CriarCobranca` via gRPC; o PSP é externo e só fala REST/webhook, conforme ADR-0015 e a rule `.forge/rules/architecture/internal-grpc-communication.md`.
4. **Eventos via RabbitMQ** — `RecargaPixLiquidada` é publicado na exchange `recarga.eventos` usando o outbox transacional já existente no módulo `pix`.
5. **Dado de pagador** — CPF armazenado apenas como HMAC-SHA256 com pepper do cofre; classificação conforme `.forge/rules/architecture/pii-pci-classification.md` (REQ-05).

## Contratos

- REST externo: `POST /v1/recargas/pix` (app → API) retorna `txid`, `qr_code_base64` e `expira_em`.
- Webhook do PSP: `POST /webhooks/psp/pix` com assinatura HMAC no header `X-PSP-Signature`.
- gRPC interno: `pix.v1.CobrancaService/CriarCobranca` (contrato em `proto/pix/v1/cobranca.proto`).
- Evento: `RecargaPixLiquidada` v1 (`txid`, `cartao_id`, `valor_centavos`, `liquidado_em`) na exchange `recarga.eventos`.

## Modelo de dados

```sql
CREATE TABLE recarga_pix (
  id uuid PRIMARY KEY,
  txid varchar(35) NOT NULL UNIQUE,
  cartao_id uuid NOT NULL,
  valor_centavos integer NOT NULL CHECK (valor_centavos BETWEEN 500 AND 50000),
  status varchar(16) NOT NULL,
  pagador_cpf_hmac char(64),
  expira_em timestamptz NOT NULL
);
```

## Concorrência

Webhook e job de expiração podem disputar a mesma cobrança: a transição de status usa `UPDATE ... WHERE status = 'PENDENTE'` e só o vencedor segue. Cobrança paga após `EXPIRADA` entra na fila de devolução (REQ-04).

## ADRs

- ADR-0012 — Idempotência de crédito por chave natural do provedor.
- ADR-0015 — gRPC interno, REST/webhook para parceiros externos.
