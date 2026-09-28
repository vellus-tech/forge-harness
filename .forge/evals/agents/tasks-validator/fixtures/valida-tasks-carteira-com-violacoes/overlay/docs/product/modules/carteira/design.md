# Design — CRT — Carteira

- Versão: 0.4.0
- Data: 2026-09-04
- Status: Aprovado para desenvolvimento
- Base: requirements.md v1.2.0
- ADRs: ADR-0001, ADR-0002, ADR-0003

## Decisões inline

- **DD-001:** `Saldo` é Value Object sobre `long` em centavos (ADR-0002); operações que resultariam em saldo negativo lançam `SaldoInsuficienteException`.
- **DD-002:** Idempotência do crédito pela tabela `recarga_processada` com `txid` UNIQUE; crédito e inserção na mesma transação.

## API

| Método | Rota | Req |
|---|---|---|
| GET | `/v1/carteiras/{id}/saldo` | Req 2 |
| POST | `/v1/webhooks/pix` | Req 1 |

## Eventos

- `RecargaCreditada` (tópico `carteira.recargas`, via outbox) — Req 1.

## Persistência

- Migration `0001_carteira`: tabelas `carteira` (saldo_centavos bigint) e `recarga_processada` (txid unique).

## Catálogo de erros

- `CRT-001 CarteiraNaoEncontrada` (404), `CRT-002 SaldoInsuficiente` (422), `CRT-003 AcessoNegado` (403).

## Observabilidade e segurança

- Logs estruturados com `correlation_id`; enricher de mascaramento de CPF/e-mail (RNF 2).
- Autorização: passageiro só lê a própria carteira (`CRT-003`).
