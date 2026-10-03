# Contexto épico — recarga-pix-cartao-transporte

> Resumo compacto para embutir em cada story do /forge:shard. Substitui a releitura de proposal.md, requirements.md, design.md e tasks.md a cada story.

## Problema e objetivo

Hoje a recarga do cartão de transporte via Pix no guichê usa QR estático sem conciliação automática (41% das recargas em Pix manual, 312 divergências de crédito no SAC em agosto). O change introduz recarga via Pix com QR dinâmico (cobrança imediata `cob` do Bacen) gerada no app, com crédito automático no saldo do cartão disparado pela confirmação de liquidação do PSP. Fora de escopo: Pix Automático recorrente e estorno via MED.

## Requisitos (REQ)

- REQ-01 — Cobrança Pix imediata com QR dinâmico, valor entre R$ 5,00 e R$ 500,00, expiração de 15 minutos.
- REQ-02 — Crédito do saldo só ocorre após o webhook `pix.cob.concluida` confirmar a liquidação; nunca na geração do QR.
- REQ-03 — Um mesmo `txid` credita o cartão no máximo uma vez, mesmo com webhook reentregue (idempotência).
- REQ-04 — Cobrança expirada sem pagamento vira `EXPIRADA` e não credita; pagamento tardio é devolvido ao pagador.
- REQ-05 — CPF do pagador nunca persiste em claro; apenas hash salgado (HMAC-SHA256 com pepper do cofre) para conciliação.

## Decisões de design

1. Crédito disparado exclusivamente pelo evento de domínio `RecargaPixLiquidada`, nunca pelo endpoint de criação da cobrança (REQ-02) — toda story de crédito depende do consumidor do evento, não do endpoint.
2. Idempotência por `txid`: tabela `recarga_pix` com constraint única em `txid`; consumidor faz upsert e ignora reentrega (REQ-03, ADR-0012).
3. Comunicação interna `recarga` → `pix` é gRPC (`pix.v1.CobrancaService/CriarCobranca`); o PSP externo só fala REST/webhook (ADR-0015, rule interna de comunicação gRPC).
4. Evento `RecargaPixLiquidada` publicado na exchange RabbitMQ `recarga.eventos` via outbox transacional já existente no módulo `pix`.
5. CPF do pagador: apenas HMAC-SHA256 com pepper do cofre é armazenado (REQ-05, classificação PII/PCI da rule de arquitetura).

## Contratos

- REST externo: `POST /v1/recargas/pix` (app → API) → retorna `txid`, `qr_code_base64`, `expira_em`.
- Webhook do PSP: `POST /webhooks/psp/pix`, assinatura HMAC no header `X-PSP-Signature`.
- gRPC interno: `pix.v1.CobrancaService/CriarCobranca` (`proto/pix/v1/cobranca.proto`).
- Evento: `RecargaPixLiquidada` v1 — campos `txid`, `cartao_id`, `valor_centavos`, `liquidado_em` — exchange `recarga.eventos`.

## Modelo de dados

Tabela `recarga_pix`: `id` (uuid PK), `txid` (varchar(35) UNIQUE), `cartao_id` (uuid), `valor_centavos` (integer, CHECK 500–50000), `status` (varchar(16)), `pagador_cpf_hmac` (char(64)), `expira_em` (timestamptz).

## Concorrência

Webhook e job de expiração podem disputar a mesma cobrança: transição de status via `UPDATE ... WHERE status = 'PENDENTE'`, só o vencedor segue; pagamento após `EXPIRADA` entra na fila de devolução (REQ-04).

## ADRs relevantes

- ADR-0012 — Idempotência de crédito por chave natural do provedor.
- ADR-0015 — gRPC interno, REST/webhook para parceiros externos.

## Waves e tasks

- **Wave 1 — Contratos e persistência**: TASK-01 contrato gRPC `pix.v1.CobrancaService` (`proto/pix/v1/cobranca.proto`); TASK-02 migration `recarga_pix` com unique em `txid` (`src/recarga/migrations/`).
- **Wave 2 — Fluxo de cobrança**: TASK-03 endpoint `POST /v1/recargas/pix` com validação de faixa (REQ-01, `src/recarga/api/`, depende de TASK-01/02); TASK-04 webhook do PSP com verificação de assinatura e publicação de `RecargaPixLiquidada` via outbox (REQ-02, `src/pix/webhook/`, depende de TASK-01).
- **Wave 3 — Crédito e expiração**: TASK-05 consumidor idempotente de `RecargaPixLiquidada` que credita o saldo (REQ-02, REQ-03, `src/recarga/consumers/`, depende de TASK-02/04); TASK-06 job de expiração e fila de devolução (REQ-04, `src/recarga/jobs/`, depende de TASK-05); TASK-07 hash HMAC do CPF do pagador (REQ-05, `src/pix/webhook/`, depende de TASK-04).

## Status do manifesto

`spec-manifest.yaml`: scale 3, rigor spec-anchored, status `tasks-ready`; gates `requirements_reviewed`, `design_reviewed` e `tasks_reviewed` já `true`; `implementation_verified` e `human_archive_approval` ainda `false`.

## Fora do escopo deste contexto

O change ativo `migra-eventos-para-kafka` e as notas em `src/recarga/NOTAS.md` (TODO de lock distribuído Redlock, não confirmado por nenhum REQ/design deste change) não fazem parte deste change e não foram incorporados a este resumo.
