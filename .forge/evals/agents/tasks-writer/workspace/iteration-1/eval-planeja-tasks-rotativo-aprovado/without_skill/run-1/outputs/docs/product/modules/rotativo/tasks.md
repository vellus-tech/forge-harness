# Tasks — ROT — Estacionamento Rotativo Digital

- Versão: 1.0.0
- Data: 2026-09-26
- Status: Pronto para sprint
- Referência base: requirements.md v1.1.0, design.md v1.0.0
- Stack: .NET 8, Clean Architecture, PostgreSQL 16 (Flyway), xUnit, FsCheck, NetArchTest (ADR-0001); Transactional Outbox + RabbitMQ (ADR-0002)

## Convenções desta lista

Cada TASK traz contexto suficiente para o task-coder implementar sem reabrir requirements.md/design.md por completo. IDs de requisito (Req/RNF/PBT) e de decisão de design (DD) são rastreados em "Origem". Toda TASK que altera `Domain` ou `Infrastructure` roda o teste de arquitetura NetArchTest do Wave 5 antes de ser dada como concluída.

## Wave 1 — Esqueleto e domínio

### TASK-01 — Estrutura de projetos e migration inicial

- Origem: Design §1, §5
- Criar projetos `Rotativo.Domain`, `Rotativo.Application`, `Rotativo.Infrastructure`, `Rotativo.Api`, `Rotativo.Contracts` (Clean Architecture, ADR-0001).
- Adicionar migration Flyway `V1__ativacoes.sql` com tabelas `ativacoes`, `idempotency_keys`, `outbox` e índice `(placa, estado)` (Design §5).
- Critério de aceite: solução compila; migration aplica em banco limpo via Flyway.

### TASK-02 — Value objects `Placa`, `Minutos`, `Dinheiro`

- Origem: Design §2; RNF 2
- `Placa`: valida formato Mercosul e antigo; expõe `Mascarada()` retornando apenas os 3 últimos caracteres (RNF 2 — nunca logar placa completa).
- `Minutos`: inteiro positivo, sem limite próprio (o limite é da zona, ver TASK-03).
- `Dinheiro`: centavos em `long`, sem ponto flutuante.
- Testes: xUnit para casos de borda de formato de placa; FsCheck property-based para `Dinheiro` (soma/subtração não perde precisão) — cobre base de PBT-02.
- Critério de aceite: testes unitários verdes; nenhum caminho de código loga `Placa` bruta (apenas `Mascarada()`).

### TASK-03 — Aggregate `Ativacao` e evento de domínio

- Origem: Design §2; Req 1, Req 2; PBT-03
- Aggregate `Ativacao` (Id, Placa, ZonaId, MinutosTotais, Estado, ExpiraEm) com invariante: soma de minutos (ativação + extensões) não excede o tempo máximo da zona (Req 2.1 / ROT-002).
- Máquina de estados: `Ativa → Expirada` ou `Ativa → Cancelada`; nenhuma transição sai de estado terminal (PBT-03).
- Evento de domínio `AtivacaoConfirmada` disparado na confirmação da compra.
- Testes: FsCheck codificando PBT-03 diretamente (gerar sequências de transições e afirmar que nenhum estado terminal retorna a `Ativa`).
- Critério de aceite: PBT-03 executando e verde; violação de invariante lança exceção de domínio tipada.
- Depende de: TASK-02.

## Wave 2 — Casos de uso (Application)

### TASK-04 — `ComprarAtivacaoCommand` + handler

- Origem: Design §3, §4 (DD-001); Req 1
- Handler debita `minutos × tarifa_por_minuto` da carteira e cria a ativação na mesma transação (Req 1.1).
- Rejeita com `ROT-001` (saldo insuficiente, Req 1.2) e `ROT-002` (minutos excedem tempo máximo da zona, Req 1.3).
- Idempotência (DD-001): usa tabela `idempotency_keys (key, request_hash, response_json, criado_em)`, retenção de 24 h; requisição repetida com a mesma `Idempotency-Key` retorna a mesma resposta sem novo débito (Req 1.4).
- Testes: FsCheck codificando PBT-01 (N requisições com a mesma chave → exatamente uma ativação e um débito) e PBT-02 (conservação de saldo) para este fluxo.
- Critério de aceite: PBT-01 e PBT-02 verdes para o fluxo de compra; caminho de rejeição coberto por teste unitário para ROT-001 e ROT-002.
- Depende de: TASK-03.

### TASK-05 — `EstenderAtivacaoCommand` + handler

- Origem: Design §3; Req 2
- Rejeita com `ROT-002` quando a soma de minutos (ativação + extensões) excede o tempo máximo da zona (Req 2.1).
- Rejeita com `ROT-003` quando a ativação está expirada ou cancelada (Req 2.2).
- Testes: estende a suíte de PBT-02 (conservação de saldo) para incluir extensões aceitas.
- Critério de aceite: testes unitários cobrindo os dois caminhos de rejeição (ROT-002, ROT-003) e o caminho de sucesso.
- Depende de: TASK-04.

### TASK-06 — `ConsultarAtivacoesPorPlacaQuery` + handler

- Origem: Design §3, §6; Req 3
- Retorna apenas ativações com estado `Ativa` no instante da consulta (Req 3.1).
- Handler não impõe autorização (ver TASK-08 para o escopo OAuth na borda HTTP, Req 3.2).
- Critério de aceite: teste unitário garante que ativações `Expirada`/`Cancelada` não aparecem no resultado.
- Depende de: TASK-03.

## Wave 3 — Infraestrutura

### TASK-07 — Outbox e publicação de `AtivacaoConfirmada`

- Origem: Design §4 (DD-002); ADR-0002
- `AtivacaoConfirmada` gravado na tabela `outbox` na mesma transação da confirmação da compra (DD-002, ADR-0002).
- Relay em background publica da `outbox` para a exchange `rotativo.eventos` (RabbitMQ); nenhum handler publica diretamente no broker (ADR-0002).
- Critério de aceite: teste de integração comprova que o evento aparece na `outbox` dentro da mesma transação do commit da ativação (falha simulada após o commit não perde o evento).
- Depende de: TASK-04.

### TASK-08 — Endpoints HTTP e autorização por escopo OAuth

- Origem: Design §6, §7; Req 1, Req 2, Req 3.2
- `POST /v1/ativacoes` e `POST /v1/ativacoes/{id}/extensoes`: escopo `motorista:write`.
- `GET /v1/ativacoes?placa=`: escopo `fiscalizacao:read` (Req 3.2).
- Mapeamento de erros de domínio para HTTP: `ROT-001` → 422, `ROT-002` → 422, `ROT-003` → 409 (Design §7).
- `Idempotency-Key` obrigatória nos dois endpoints de escrita (DD-001).
- Critério de aceite: teste de integração por endpoint cobrindo escopo ausente (403) e cada código de erro do catálogo.
- Depende de: TASK-04, TASK-05, TASK-06.

## Wave 4 — Observabilidade

### TASK-09 — Logs, métricas e latência

- Origem: Design §8; RNF 1, RNF 2
- Log estruturado usa `placa_mascarada` (`Placa.Mascarada()`) em todos os pontos de log e trace — nunca a placa completa (RNF 2).
- Métrica `rotativo_ativacoes_total{zona}` e histograma de latência de `POST /v1/ativacoes` (RNF 1).
- Critério de aceite: teste de latência/carga (ou verificação estática de instrumentação, se carga real não couber na sprint) confirma p95 abaixo de 300 ms com 200 req/s simulado; inspeção de log confirma ausência de placa completa em qualquer nível.
- Depende de: TASK-08.

## Wave 5 — Regras de arquitetura e fechamento

### TASK-10 — Teste de arquitetura (NetArchTest)

- Origem: Design §8; ADR-0001
- Regra NetArchTest: `Rotativo.Domain` não referencia `Rotativo.Infrastructure` nem `Rotativo.Api`.
- Critério de aceite: teste falha propositalmente com uma referência violada (sanity check) e depois passa limpo; incluído no pipeline de CI antes do merge.
- Depende de: TASK-01 (roda continuamente a partir daí; é o gate de saída da sprint).

## Rastreabilidade rápida

| Requisito/Decisão | TASKs |
|---|---|
| Req 1 (comprar) | TASK-04 |
| Req 2 (estender) | TASK-05 |
| Req 3 (consultar) | TASK-06, TASK-08 |
| RNF 1 (latência) | TASK-09 |
| RNF 2 (mascaramento) | TASK-02, TASK-09 |
| PBT-01 (idempotência) | TASK-04 |
| PBT-02 (conservação de saldo) | TASK-02, TASK-04, TASK-05 |
| PBT-03 (máquina de estados) | TASK-03 |
| DD-001 (idempotência) | TASK-04, TASK-08 |
| DD-002 (outbox) | TASK-07 |
| ADR-0001 (stack/camadas) | TASK-01, TASK-10 |
| ADR-0002 (outbox) | TASK-07 |
