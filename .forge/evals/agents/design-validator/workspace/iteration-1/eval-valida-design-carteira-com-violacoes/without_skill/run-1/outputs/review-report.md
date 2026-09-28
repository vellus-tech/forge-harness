# Revisão arquitetural — Carteira design.md v0.3.0 → v0.3.1

Baseline: `requirements.md` v1.2.0 (aprovado) · ADR-0001, ADR-0002, ADR-0003 · rules `architecture/clean-architecture.md`, `architecture/api-and-contracts.md`, `architecture/mtls-internal-services.md`, `architecture/jwt-authentication.md`, `architecture/pii-pci-classification.md`, `domain/money-as-cents.md`, `domain/audit-immutability.md`, `conventions/database-naming.md`.

## Corrigido direto no design.md (ajuste mecânico, sem decisão de design em aberto)

| # | Violação | Onde | Regra violada |
|---|---|---|---|
| 1 | `double Saldo` / `double valor` no aggregate `Carteira`, coluna `saldo FLOAT`, `valor FLOAT` | Modelo de Domínio, Schema | ADR-0002 / `domain/money-as-cents.md` (dinheiro é `long`/`BIGINT` em centavos; `float`/`double` proibidos em cálculo de tarifa e saldo) |
| 2 | Anotações `[Table]`, `[Key]`, `DbSet<Movimentacao>` diretamente no aggregate de domínio (DD-001 justificava isso como "menos código") | Modelo de Domínio | ADR-0001 / `architecture/clean-architecture.md` regras 12–14 (`Domain` nunca referencia EF Core; mapeamento é da `Infrastructure` via `IEntityTypeConfiguration<T>`) — é o anti-pattern listado explicitamente na rule |
| 3 | Tabela `movimentacao` sem `tenant_id` | Schema | RNF-02 ("dados segregados por operadora em todas as tabelas e eventos") e `conventions/database-naming.md` ("`tenant_id` obrigatório em todas as tabelas de dados de negócio") |
| 4 | Payload de eventos publicados/consumidos sem `event_version`, `correlation_id`, `causation_id`, `tenant_id`, `idempotency_key`; valores em reais decimais (`4.4`, `10.6`) em vez de centavos | AsyncAPI / Eventos | ADR-0003 (envelope obrigatório) + ADR-0002 (centavos) |
| 5 | CPF em claro no log estruturado (`carteira_id` e `cpf`) e nota "CPF armazenado em claro para facilitar suporte" na seção Segurança | Observabilidade, Segurança | RNF-03 (LGPD, CPF nunca em log sem mascaramento) e `architecture/pii-pci-classification.md` (mascaramento sempre em `enforce`, na borda de emissão) |

Nenhuma correção acima alterou a intenção funcional dos casos de uso já cobertos — são renomeações de tipo/coluna, remoção de acoplamento de infraestrutura do domínio e adição de campos obrigatórios por ADR/regra já aprovados. Versão bumpada para 0.3.1 com changelog e o DD-001 marcado como revogado (mantido no histórico, não apagado).

## Achados maiores — apontados, não corrigidos (exigem decisão de design)

| # | Achado | Por que é maior | Recomendação |
|---|---|---|---|
| A | **REQ-04 (bloqueio de carteira) sem nenhuma cobertura no design** — falta caso de uso, endpoint, estado persistido e trilha de auditoria (autor/data/motivo) | É um requisito funcional aprovado inteiro ausente, não um ajuste de campo; exige novo comando, nova tabela de auditoria append-only (`domain/audit-immutability.md`) e checagem no `DebitarTarifaHandler` | Devolver ao design-writer antes de `/forge:tasks` — bloqueante |
| B | **ADR-0003 (outbox transacional + inbox de idempotência) não desenhado** — o design descreve apenas o payload do evento, não o mecanismo que garante publicação/consumo exatamente-uma-vez por `recarga_id` (REQ-02, PBT-02), nem DLQ/retry | Falha direta de PBT-02 ("reprocessar o mesmo RecargaConfirmada N vezes resulta em um único crédito") se implementado como está; exige novas tabelas `outbox`/`inbox` e fluxo de consumo, não é um typo | Devolver ao design-writer antes de `/forge:tasks` — bloqueante |
| C | **Global Query Filter multi-tenant não confirmado para `movimentacao` e para o outbox/inbox a desenhar** | Depende da solução do item B; menor que A/B mas não é apenas redação | Pode ser resolvido no mesmo ciclo que B, como nota de esclarecimento |

## Veredicto sobre seguir para `/forge:tasks`

**Não recomendado ainda.** REQ-04 (achado A) e a garantia transacional de ADR-0003/PBT-02 (achado B) são lacunas de requisito/propriedade aprovados, não polimento — se o `tasks-writer` quebrar o design atual em tasks, as tasks vão nascer sem tarefa para bloqueio de carteira e sem outbox/inbox, e a sprint entregaria um saldo que pode ser creditado em duplicidade. Os cinco itens mecânicos (1–5) já estão corrigidos nesta v0.3.1 e não bloqueiam mais nada.
