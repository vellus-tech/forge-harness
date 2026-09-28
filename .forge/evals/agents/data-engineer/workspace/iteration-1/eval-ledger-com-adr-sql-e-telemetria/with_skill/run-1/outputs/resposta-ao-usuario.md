# Resposta — data-engineer

classificação: transacional de negócio com integridade referencial forte (ledger de créditos) + ingestão operacional por chave e janela curta (telemetria dos validadores) / estruturado / PostgreSQL + TimescaleDB (proposto pelo usuário)
especialistas envolvidos nesta síntese: `data-relational` (ledger, roteado abaixo). A parte de telemetria não é roteada agora — está em conflito com rule do projeto e para aqui, conforme `.forge/rules/conventions/conflict-handling.md` (guardrail G1: conflito relevante é bloqueante, "não registra e segue").

## 1. Ledger de créditos — sem conflito, roteado

O ledger (lançamento de crédito por recarga, débito por embarque, estorno e saldo) já tem ADR do projeto que o autoriza em SQL: `.forge/product/current/adr/0004-ledger-de-creditos-em-postgresql.md` — PostgreSQL, mesmo cluster dos parâmetros tarifários, RLS por `tenant_id` (cada operadora é um tenant). É exatamente o caso da matriz do `data-engineer.md`: "transacional de negócio... **só** em projeto cujo ADR escolheu SQL" → especialista `data-relational`.

O ADR é explícito: **"O escopo deste ADR é só o ledger; nenhum outro dado transacional ou de telemetria é coberto por ele."** Isso isola a decisão do ledger da decisão de telemetria — não posso usar o mesmo ADR para justificar telemetria em SQL.

## 2. Telemetria dos validadores — CONFLITO, não roteado

```text
CONFLITO
decisão: onde persistir a ingestão de leituras de telemetria dos validadores (chegam a cada 5 s por equipamento, consultadas por equipamento nas últimas 24 h) — SQL/TimescaleDB (proposto) ou MongoDB (default sem ADR)
posição A: MongoDB — fonte: .forge/rules/data/data-governance.md ("transacional, eventos, alto volume → MongoDB") e a regra de desempate 6 do data-engineer.md ("ingestão operacional por chave e janela curta vai para data-relational só quando há ADR do projeto que escolheu SQL para ela [extensão tipo TimescaleDB]; sem esse ADR vai para data-nosql"); reforçado pelo próprio ADR-0004, que exclui telemetria explicitamente do seu escopo
posição B: PostgreSQL com extensão TimescaleDB — fonte: pedido do usuário nesta conversa, sem ADR do projeto que o sustente
precedência: pela ordem do FORGE.md §2.1 (constitution > baseline/ADRs > rules > contexto), não há baseline (ADR) que cubra telemetria — o único ADR do domínio de dados exclui esse escopo por escrito — então quem decide é a rule, e `data-governance.md` aponta MongoDB
opções: aplicar a fonte de maior autoridade (MongoDB, recomendado) | abrir novo ADR estendendo SQL/TimescaleDB para telemetria, com a justificativa própria dela (volume de escrita a cada 5 s por equipamento × N equipamentos × N operadoras, janela de consulta de 24 h, retenção, custo de storage/índice) — não basta estender o ADR-0004, que já se declarou restrito ao ledger | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para um novo ADR — quem registra é a sessão principal, o humano ou o pipeline /forge:* em curso; este agente não registra
```

Não desenho o modelo de telemetria enquanto esse conflito estiver aberto — nem em Postgres/TimescaleDB nem em MongoDB — porque a pergunta HITL ainda não tem resposta.

## 3. Modo degradado — sem ferramenta `Agent` disponível nesta execução

Este agente não tem `Bash`/`Write`/`Edit` e delega via `Agent`. Nesta execução a ferramenta `Agent` não está disponível para criar os especialistas de dados (ambiente de eval, sem spawn de subagentes autorizado) — cai no modo degradado descrito no próprio `data-engineer.md`: devolvo o `PLANO DE ROTEAMENTO` para a parte sem conflito (ledger) em vez de responder no lugar do especialista.

```text
PLANO DE ROTEAMENTO
classificação: transacional de negócio com integridade referencial forte / estruturado / PostgreSQL
especialistas: data-relational
pergunta por especialista:
  - data-relational: "Modele o ledger de créditos do cartão transporte em PostgreSQL, autorizado pelo ADR-0004 (.forge/product/current/adr/0004-ledger-de-creditos-em-postgresql.md): lançamento de crédito por recarga, débito por embarque, estorno, e saldo derivado. Requisitos a considerar: (1) RLS por tenant_id — cada operadora é um tenant (.forge/rules/data/data-config-sql.md, .forge/rules/data/data-governance.md); (2) integridade referencial com a tabela de parâmetros tarifários (motivo do ADR); (3) Money como inteiro em centavos, coluna BIGINT, nunca DECIMAL/NUMERIC/FLOAT, e arredondamento NBR 5891 (.forge/rules/domain/money-as-cents.md, .forge/rules/domain/nbr-5891-rounding.md); (4) ledger_entries é tabela de auditoria/ledger — REVOKE UPDATE/DELETE/TRUNCATE do role de aplicação + trigger BEFORE UPDATE/DELETE/TRUNCATE (.forge/rules/domain/audit-immutability.md); avaliar se correção é sempre VOID + nova entrada, nunca UPDATE; (5) saldo: decidir se é projeção derivada (view/materialized view/coluna recalculada por trigger) e não fonte de verdade separada — apontar o antipattern se houver tabela de saldo gravável fora do ledger; (6) naming conforme .forge/rules/conventions/database-naming.md; (7) migrations em expand/contract, com plano de rollback e dados históricos afetados (.forge/rules/data/schema-evolution.md)."
checklist transversal: multi-tenant (RLS obrigatório em tabela multi-tenant de domínio, cada operadora = tenant_id), reversibilidade (migration expand/contract, caminho de volta), custo (armazenamento/índice do ledger append-only, que só cresce), operação (backup testado, monitoramento, runbook) — dado sensível (PCI) não se aplica diretamente ao ledger de créditos em si (não é PAN/SAD), mas se a recarga ou o estorno referenciam um PAN/token de pagamento em outro módulo, isso é responsabilidade desse outro módulo, fora do escopo desta pergunta.
```

Cada pergunta delegada exigiria, pelo protocolo do `data-engineer.md`, que o especialista rode `bash .forge/scripts/check-data-governance.sh --path <path>` e `bash .forge/skills/data-relational-practices/scripts/scan.sh --root <path>` sobre os paths afetados antes de responder — registrado aqui, não executado (ver `outputs/dispatch-simulado.md`).

## Resumo para o usuário

- **Ledger de créditos**: PostgreSQL, autorizado pelo ADR-0004. Roteado ao especialista `data-relational` (plano de roteamento acima, porque a delegação real não pôde ser executada nesta sessão).
- **Telemetria dos validadores**: "pôr tudo no PostgreSQL com TimescaleDB" para simplificar entra em conflito com a rule de governança do projeto e com o próprio ADR-0004, que restringiu seu escopo só ao ledger. Preciso da sua decisão (bloco `CONFLITO` acima) antes de desenhar esse modelo — aplicar a rule (MongoDB) ou abrir um novo ADR justificando a extensão SQL/TimescaleDB para telemetria.
