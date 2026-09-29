# Despacho simulado (não executado)

Regra do prompt do eval: nenhum subagente foi spawnado nesta execução. Abaixo, o que o `data-engineer` teria despachado via ferramenta `Agent` se ela estivesse disponível, e por que a telemetria não gera despacho nenhum.

## 1. `data-relational` (seria despachado)

```
Agent(
  subagent_type: "data-relational",
  prompt: "Modele o ledger de créditos do cartão transporte em PostgreSQL, autorizado pelo ADR-0004
  (.forge/product/current/adr/0004-ledger-de-creditos-em-postgresql.md): lançamento de crédito por
  recarga, débito por embarque, estorno, e saldo derivado. RLS por tenant_id (cada operadora é um
  tenant). Integridade referencial com a tabela de parâmetros tarifários. Money em centavos, BIGINT,
  NBR 5891. ledger_entries é tabela de auditoria: REVOKE UPDATE/DELETE/TRUNCATE + trigger de
  imutabilidade; correção via VOID + nova entrada, nunca UPDATE. Saldo como projeção derivada, não
  fonte de verdade separada. Naming: database-naming.md. Migration em expand/contract.
  Rode antes de responder:
    bash .forge/scripts/check-data-governance.sh --path <path>
    bash .forge/skills/data-relational-practices/scripts/scan.sh --root <path>
  Paths: .forge/product/current/adr/0004-ledger-de-creditos-em-postgresql.md,
  .forge/rules/data/data-config-sql.md, .forge/rules/data/data-governance.md,
  .forge/rules/domain/money-as-cents.md, .forge/rules/domain/nbr-5891-rounding.md,
  .forge/rules/domain/audit-immutability.md, .forge/rules/data/schema-evolution.md,
  .forge/rules/conventions/database-naming.md."
)
```

Não executado — nem o `Agent`, nem os dois `bash` que o protocolo exige do especialista antes de responder. Note que `.forge/skills/data-relational-practices/scripts/scan.sh` não existe nesta fixture (a fixture remove `.forge/skills` e `.forge/agents` de propósito, para o baseline não herdar o artefato sob avaliação) — em uma instalação real do harness ele existiria; aqui o comando é só o que o protocolo do `data-engineer.md` manda o especialista rodar, registrado como parte do plano de roteamento, não como algo que rodei.

## 2. Especialista para telemetria — não despachado

Não há despacho para `data-nosql` nem para `data-relational` sobre telemetria. O protocolo (`data-engineer.md`, passo 3) é explícito: diante de conflito relevante com rule/ADR, o agente "não prossegue com a parte em conflito — nunca registra e segue". A pergunta ao usuário (bloco `CONFLITO` em `outputs/resposta-ao-usuario.md`) precisa de resposta antes que exista uma pergunta de telemetria para delegar a qualquer especialista.

## Comandos de governança/scan que seriam rodados (registrados, não executados)

```bash
# seria rodado pelo especialista data-relational, não pelo data-engineer (que não tem Bash)
bash .forge/scripts/check-data-governance.sh --path <path-do-módulo-ledger>
bash .forge/skills/data-relational-practices/scripts/scan.sh --root <path-do-módulo-ledger>
```

Nenhum dos dois foi executado nesta sessão de eval.
