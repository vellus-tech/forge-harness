# Design — ROT — Estacionamento Rotativo Digital

- Versão: 1.1.0
- Data: 2026-09-24
- Status: Aprovado
- Referência base: docs/product/modules/rotativo/requirements.md v1.2.0
- ADRs aplicáveis: ADR-0001, ADR-0002

## 1. Visão geral

Serviço `rotativo` em .NET 8, Clean Architecture (ADR-0001), projetos `Rotativo.Domain`, `Rotativo.Application`, `Rotativo.Infrastructure`, `Rotativo.Api`, `Rotativo.Contracts`.

## 2. Domínio

- Aggregate `Ativacao` (Id, Placa, ZonaId, MinutosTotais, Estado, ExpiraEm) com invariante de tempo máximo da zona.
- Value objects `Placa` (valida formato Mercosul/antigo, expõe `Mascarada()`), `Minutos`, `Dinheiro` (centavos, `long`).
- Evento de domínio `AtivacaoConfirmada`.

## 3. Aplicação

- `ComprarAtivacaoCommand` + handler (débito da carteira e criação da ativação na mesma transação).
- `EstenderAtivacaoCommand` + handler.
- `ConsultarAtivacoesPorPlacaQuery` + handler.

## 4. Decisões inline

- **DD-001 — Idempotência:** tabela `idempotency_keys (key, request_hash, response_json, criado_em)` com retenção de 24 h; chave obrigatória em `POST /v1/ativacoes` e `POST /v1/ativacoes/{id}/extensoes`.
- **DD-002 — Evento via outbox:** `AtivacaoConfirmada` gravado na tabela `outbox` na mesma transação (ADR-0002) e publicado na exchange `rotativo.eventos`.

- **DD-003 — Estorno como lançamento de crédito:** o cancelamento não altera o débito original; gera lançamento de crédito em `carteira_lancamentos` e evento `AtivacaoCancelada` via outbox, na mesma transação.

## 5. Persistência

- Migration `V1__ativacoes.sql`: tabelas `ativacoes`, `idempotency_keys`, `outbox`; índice `(placa, estado)`.
- Migration `V2__cancelamento.sql`: coluna `cancelada_em` em `ativacoes` e tabela `carteira_lancamentos`.

## 6. API

| Método | Rota | Escopo | Erros |
|--------|------|--------|-------|
| POST | /v1/ativacoes | `motorista:write` | ROT-001, ROT-002 |
| POST | /v1/ativacoes/{id}/extensoes | `motorista:write` | ROT-002, ROT-003 |
| GET | /v1/ativacoes?placa= | `fiscalizacao:read` | — |
| DELETE | /v1/ativacoes/{id} | `motorista:write` | ROT-003 |

## 7. Catálogo de erros

| Código | HTTP | Mensagem |
|--------|------|----------|
| ROT-001 | 422 | Saldo insuficiente |
| ROT-002 | 422 | Tempo máximo da zona excedido |
| ROT-003 | 409 | Ativação não está vigente |

## 8. Observabilidade e segurança

- Log estruturado com `placa_mascarada` (RNF 2); métrica `rotativo_ativacoes_total{zona}` e histograma de latência de `POST /v1/ativacoes` (RNF 1).
- Teste de arquitetura com NetArchTest: `Domain` não referencia `Infrastructure` nem `Api`.
