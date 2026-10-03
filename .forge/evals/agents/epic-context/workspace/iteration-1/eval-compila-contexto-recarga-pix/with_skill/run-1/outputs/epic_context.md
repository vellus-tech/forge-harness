# Epic context — recarga-pix-cartao-transporte

> Gerado por epic-context agent. Leitura rápida — não substitui os artefatos originais.

## Objetivo

Permitir a recarga do cartão de transporte via Pix com QR dinâmico (cobrança imediata `cob` do Bacen), com crédito automático no saldo do cartão somente quando o PSP confirmar a liquidação pelo webhook, eliminando a conciliação manual do Pix estático hoje feita no guichê.

## Decisões de design

- Crédito só na liquidação, disparado pelo evento `RecargaPixLiquidada`, nunca pela criação da cobrança → toda story de crédito depende do consumidor do evento, não do endpoint de criação (REQ-02).
- Idempotência por `txid` via constraint única na tabela `recarga_pix` e upsert no consumidor → stories de crédito devem tratar reentrega de webhook sem duplicar crédito (REQ-03, ADR-0012).
- Comunicação interna entre `recarga` e `pix` é gRPC (`pix.v1.CobrancaService/CriarCobranca`) → stories de integração entre os dois módulos usam o contrato `.proto`, não um endpoint REST interno (ADR-0015).
- `RecargaPixLiquidada` é publicado na exchange `recarga.eventos` via o outbox transacional já existente em `pix` → stories de publicação de evento reaproveitam esse outbox, não implementam publicação direta.
- CPF do pagador é armazenado apenas como HMAC-SHA256 com pepper do cofre → nenhuma story persiste CPF em claro (REQ-05).
- Concorrência entre webhook e job de expiração é resolvida por transição de status condicional (`status = 'PENDENTE'` na atualização); pagamento que chega após expiração vai para fila de devolução, não é creditado → stories de crédito e de expiração devem coordenar por esse mecanismo (REQ-04).

## Contratos externos

- `POST /v1/recargas/pix` (app → API) — cria a cobrança e retorna `txid`, `qr_code_base64` e `expira_em`.
- `POST /webhooks/psp/pix` — webhook do PSP, assinatura HMAC no header `X-PSP-Signature`.
- gRPC interno `pix.v1.CobrancaService/CriarCobranca` — contrato em `proto/pix/v1/cobranca.proto`.
- Evento `RecargaPixLiquidada` v1 (`txid`, `cartao_id`, `valor_centavos`, `liquidado_em`) na exchange `recarga.eventos`.

## ADRs

- ADR-0012 — Idempotência de crédito por chave natural do provedor (o `txid`).
- ADR-0015 — Comunicação interna via gRPC; REST/webhook reservados a parceiros externos (o PSP).

## Rules

- `.forge/rules/architecture/internal-grpc-communication.md` — justifica o uso de gRPC entre `recarga` e `pix`.
- `.forge/rules/architecture/pii-pci-classification.md` — rege o hashing do CPF do pagador.

## Invariantes críticas

- Valor da recarga entre R$ 5,00 e R$ 500,00 (500–50000 centavos), validado na criação da cobrança.
- QR dinâmico expira em 15 minutos; cobrança expirada sem pagamento é marcada `EXPIRADA` e nunca credita.
- Crédito no saldo do cartão nunca ocorre na geração do QR — apenas na confirmação de liquidação pelo webhook.
- Um mesmo `txid` credita o cartão no máximo uma vez, mesmo com webhook reentregue.
- Pagamento que chega após a cobrança já estar `EXPIRADA` é devolvido ao pagador, não creditado.
- CPF do pagador nunca é persistido em claro — apenas o hash salgado (HMAC-SHA256 com pepper do cofre).
