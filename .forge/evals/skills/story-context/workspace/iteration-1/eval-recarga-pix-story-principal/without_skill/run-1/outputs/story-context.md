# Contexto — STORY-02: Confirmação do Pix por webhook e crédito no cartão

Épico: `2026-09-recarga-pix` (feature, scale 3, status `implementing`). Fonte: `.forge/specs/active/2026-09-recarga-pix/`.

## O que a story entrega

Receber o webhook de liquidação do PSP (`POST /webhooks/psp/pix`), validar a assinatura HMAC e creditar o saldo do cartão exatamente uma vez por `txid`. Cobre REQ-02 ("o saldo só é creditado depois que o PSP confirma a liquidação pelo webhook") e a regra de idempotência do §3 do design ("reentrega do mesmo txid responde 200 sem novo crédito").

## De quem ela depende

- **STORY-01 — Emissão da cobrança Pix de recarga** (`depends_on: [STORY-01]`, status `done`): já entregou a migration `recharge_ledger`, o cliente do PSP e o endpoint `POST /recargas` que gera o QR code. É o ledger e o txid gerados ali que o webhook desta story vai consultar/atualizar.
- Internamente, a própria STORY-02 já entregou TASK-04 (validação HMAC, `src/recarga/webhook-signature.ts` — conferido no código, função `assinaturaValida` já implementada com `timingSafeEqual`). As duas tasks restantes da story dependem dela.

Quem depende de STORY-02 (não é seu trabalho agora, mas define o que não pode quebrar): STORY-03 (conciliação diária) e STORY-04 (limite por CPF + estorno) — ambas com `depends_on: [STORY-02]`. STORY-04 em particular depende especificamente de TASK-06 (crédito via gRPC) para o fluxo de estorno de recarga não creditada.

## Tasks da story (Wave 2 do tasks.md do épico)

- [X] TASK-04 — Validação HMAC do header `x-psp-signature` (`src/recarga/webhook-signature.ts`) — feita.
- [ ] TASK-05 — Handler `POST /webhooks/psp/pix` idempotente por txid (`src/recarga/webhook.ts`; depende de TASK-04) — a fazer.
- [ ] TASK-06 — Crédito no serviço `saldo` via gRPC após confirmação (`src/recarga/credit.ts`; depende de TASK-05) — a fazer.

Critérios de aceite explícitos na story:
- Webhook com assinatura inválida responde 401 e não credita.
- Segundo webhook com o mesmo txid responde 200 e não credita de novo.

Fora de escopo desta story (não implementar aqui): conciliação diária (STORY-03) e estorno (STORY-04).

## O que não pode violar do épico (invariantes críticas, `epic_context.md`)

- Nunca creditar saldo antes do webhook de liquidação confirmado **e** com assinatura válida.
- Valores sempre em centavos inteiros (nunca float).
- Idempotência por `txid`: reentrega do mesmo `txid` responde 200 e não gera segundo crédito.
- Payload do webhook nunca é logado com CPF em claro.

Decisões-chave de design que restringem a implementação:
- Serviço `recarga` fala com o PSP por REST e com o serviço `saldo` por **gRPC interno** (ADR-0007) — TASK-06 deve chamar `saldo` via gRPC, não REST.
- Webhook do PSP autenticado por HMAC-SHA256 no header `x-psp-signature`; a chave vem do cofre de segredos, nunca hardcoded (`.forge/rules/security/secrets.md`).
- Contrato externo do PSP: `POST /webhooks/psp/pix` com corpo `{ txid, valor_centavos, status, liquidado_em }`.
- Persistência: `recharge_ledger` particionada por mês, guarda `txid`, valor em centavos, CPF, status e o payload bruto assinado do webhook.

## Por onde começar

1. Reler `src/recarga/webhook-signature.ts` (já pronto) — a função `assinaturaValida(corpo, assinatura, chave)` é o bloco de validação que TASK-05 vai chamar antes de processar o corpo do webhook.
2. TASK-05 (`src/recarga/webhook.ts`): handler que (a) valida a assinatura com `assinaturaValida`, retornando 401 se inválida; (b) busca o `txid` recebido em `recharge_ledger`; (c) se já estiver com status confirmado/creditado, responde 200 sem efeito colateral (idempotência); (d) caso contrário, marca a liquidação confirmada e dispara o crédito (TASK-06).
3. TASK-06 (`src/recarga/credit.ts`): chamada gRPC interna ao serviço `saldo` para creditar o valor em centavos, só disparada a partir do handler idempotente da TASK-05, nunca antes da confirmação assinada.
4. Ao terminar as duas tasks, validar contra os dois critérios de aceite da story (assinatura inválida → 401 sem crédito; txid repetido → 200 sem novo crédito) e contra as quatro invariantes do épico acima antes de considerar a story pronta — a STORY-04 (estorno) só poderá avançar depois que TASK-06 estiver de pé.

## Fontes lidas

- `.forge/specs/active/2026-09-recarga-pix/manifest.yaml`
- `.forge/specs/active/2026-09-recarga-pix/epic_context.md`
- `.forge/specs/active/2026-09-recarga-pix/requirements.md`
- `.forge/specs/active/2026-09-recarga-pix/design.md`
- `.forge/specs/active/2026-09-recarga-pix/tasks.md`
- `.forge/specs/active/2026-09-recarga-pix/stories/STORY-01.md`, `STORY-02.md`, `STORY-03.md`, `STORY-04.md`
- `src/recarga/webhook-signature.ts` (código já implementado da TASK-04)
