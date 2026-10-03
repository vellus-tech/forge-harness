# Requirements — RCG — Recarga

- Versão: 1.0.0
- Data: 2026-09-02
- Status: Aprovado para desenvolvimento

### Req 1 — Gerar cobrança Pix de recarga

O passageiro DEVE gerar uma cobrança Pix (QR Code dinâmico) de R$ 5,00 a R$ 300,00 para recarregar a carteira.

### Req 2 — Expiração da cobrança

A cobrança Pix DEVE expirar em 30 minutos; pagamento após a expiração é estornado.

### RNF 1 — Idempotência na criação da cobrança

Repetir a requisição com o mesmo `Idempotency-Key` em até 24 horas devolve a mesma cobrança.

- **PBT-01 — Idempotência da criação:** N requisições com a mesma `Idempotency-Key` geram exatamente uma cobrança.
