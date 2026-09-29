# Resposta do data-relational ao pedido de DDL para o ledger de cobrança

CONFLITO
decisão: store do transacional de negócio do ledger de cobrança (contas de operadora, saldo, lançamentos de débito/crédito, transferência entre contas) — PostgreSQL (pedido) vs. store determinado pela rule
posição A: MongoDB — fonte: `.forge/rules/data/data-governance.md` ("Transacional de negócio, eventos, schema flexível, alto volume → MongoDB"; ledger/cobrança está listado explicitamente no escopo de negócio do `data-relational.md`)
posição B: PostgreSQL 16 — fonte: pedido do usuário, sem ADR do projeto que o respalde (`.forge/product/current/adr/` só tem `ADR-0001-grpc-interno.md`, que decide comunicação síncrona interna por gRPC e diz explicitamente "nenhuma decisão de store de dados é tomada aqui")
precedência: pela ordem do FORGE.md §2.1 (`constitution > baseline/ADRs > rules > contexto/defaults`), sem ADR aceito que escolha SQL para este transacional de negócio, a rule (`data-governance.md`) é a fonte de maior autoridade disponível e vence o pedido do usuário, que é apenas contexto/default
opções: aplicar a fonte de maior autoridade (recomendado — modelar o ledger em MongoDB, conforme `data-governance.md`) | abrir ou atualizar ADR (registrar formalmente a decisão de usar PostgreSQL para este transacional de negócio, se for essa a escolha do time, e então este agente aplica o ADR e cita-o) | bloquear
registro: a decisão humana vai para `approvals.yaml` do change em curso, ou vira ADR — quem registra é a sessão principal ou o pipeline `/forge:*` em curso; este agente (data-relational) não registra

## Por que não recebi só "aqui está o DDL"

O pedido do usuário — "ledger do `services/cobranca`: contas de operadora com saldo, lançamentos de débito e crédito, e transferência entre contas sem saldo negativo, multi-tenant" — é exatamente o caso que o meu próprio frontmatter marca como fora do meu escopo sem ADR: "transacional de negócio (pedido, pagamento, dinheiro, estoque, **ledger, cobrança**) somente em projeto cujo ADR escolheu SQL... Não use para escolher o store do transacional de negócio sem esse ADR (a `data-governance.md` manda MongoDB: devolve CONFLITO)".

Verifiquei o baseline do projeto (`.forge/product/current/adr/`) e encontrei apenas o `ADR-0001-grpc-interno.md`, que trata de comunicação **entre serviços** (gRPC), não de persistência, e diz isso na própria seção de consequências. Não há nenhum ADR aceito que escolha SQL para o transacional de negócio da cobrança. Pela `.forge/rules/conventions/conflict-handling.md` (G1), divergência sobre **estratégia de persistência** é conflito arquitetural relevante — bloqueante — e a ordem de precedência do FORGE.md manda parar e escalar via HITL, nunca "registrar e seguir" ou entregar o DDL como se a escolha do store estivesse resolvida.

## O que eu recomendo concretamente

1. **Curto prazo (para o task-coder aplicar hoje):** se o time confirmar que quer seguir com PostgreSQL, a via rápida e correta é abrir um ADR curto (`/forge:adr`) registrando essa decisão — "ledger de cobrança em PostgreSQL, por causa de X (ex.: necessidade de transação ACID multi-linha para a transferência sem saldo negativo, que é natural em SQL e exigiria padrão saga/two-phase em Mongo)". Com esse ADR aceito, eu sigo o ADR, cito-o na resposta e endereço o DDL pedido — condicionado ao ADR, nunca como recomendação minha de trocar o store por conta própria.
2. **Alternativa:** modelar o ledger em MongoDB, seguindo `data-governance.md` e `.forge/rules/data/data-transactional-nosql.md`, e pedir a recomendação ao especialista `data-nosql` (fora do meu escopo).
3. Em qualquer um dos dois casos, o mecanismo de isolamento multi-tenant já está definido por `data-governance.md` (dono único): em PostgreSQL, `tenant_id` + EF Global Query Filter (se aplicável na stack) + **RLS obrigatório** em toda tabela multi-tenant de domínio; em MongoDB, campo `tenant` + filtro de repositório/interceptor obrigatório (Mongo não tem RLS nativo). Essa parte não é o conflito — é convergente nos dois stores.

## DDL de referência — só decisão do agente de engenharia/task-coder, condicionado ao ADR

Não estou anexando DDL nesta resposta porque fazer isso antes da resolução do conflito seria "registrar e seguir" — exatamente o antipadrão que `conflict-handling.md` cita como origem desta regra (o incidente do piloto). Assim que o ADR estiver aceito (ou a decisão por MongoDB estiver registrada), reabra a pergunta e eu devolvo o DDL PostgreSQL 16 completo (contas, lançamentos, `BIGINT` em centavos, `CHECK` de saldo não negativo via lock/trigger ou constraint transacional, RLS por `tenant_id`, índices e migração expand/contract) já condicionado ao ADR e citando-o.
