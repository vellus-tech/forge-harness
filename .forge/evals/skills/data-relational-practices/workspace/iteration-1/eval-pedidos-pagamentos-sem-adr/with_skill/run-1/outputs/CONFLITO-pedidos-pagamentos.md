# CONFLITO — pedido de migration relacional para pedidos/pagamentos sem ADR

## Pedido

Criar `services/recargas/db/migrations/V003__pedidos_pagamentos.sql` com tabelas de pedido de recarga, itens do pedido e pagamento (valor, status, gateway, NSU, data), justificando que "o serviço já usa Postgres para os parâmetros (ADR-0001)".

## Por que isto é conflito arquitetural relevante (não segue para DDL)

1. **Escopo da skill `data-relational-practices`:** "O transacional de negócio (pedido, pagamento, dinheiro, estoque, ledger, cobrança) só entra aqui quando um ADR do projeto escolheu SQL para ele; sem esse ADR, pedido de relacional para transacional de negócio é conflito com a `data-governance.md` e a resposta é o bloco `CONFLITO`, não um DDL."
2. **`.forge/rules/data/data-governance.md`** (fonte única, dono único, decisão transversal) classifica por tipo de dado, não por serviço já usar um store: "Transacional de negócio, eventos, schema flexível, alto volume → MongoDB." Pedido e pagamento são exatamente "transacional de negócio".
3. **ADR-0001** (`.forge/product/current/adr/ADR-0001-postgresql-parametros-tarifarios.md`), a única decisão aceita no baseline deste serviço, é explícito no "Fora do escopo": "Esta decisão não trata o armazenamento dos pedidos de recarga, pagamentos nem conciliação; isso será objeto de outra decisão." Ou seja, ADR-0001 não cobre — e cobre explicitamente que NÃO cobre — o que o pedido pede.
4. Não existe, no baseline lido (`.forge/product/current/adr/`), nenhum outro ADR aceito que escolha SQL para pedidos/pagamentos do serviço de recargas.

O argumento do pedido ("o serviço já usa Postgres para os parâmetros, então aproveita o mesmo banco") é precisamente o raciocínio que a `data-governance.md` proíbe: a decisão de isolamento/store é transversal e por **tipo de dado**, não "already using the DB for something else, so reuse it for everything". Reaproveitar o schema de parâmetros para transacional de negócio sem ADR é divergência de mecanismo/store não amparada — conflito relevante por `conflict-handling.md` (afeta "estratégia de persistência" e "modelo de domínio").

## Posições e precedência

| Fonte | Posição | Autoridade (`conflict-handling.md` §1: constitution > baseline > rules > context) |
|---|---|---|
| Pedido do usuário / suposição "ADR-0001 já cobre" | Postgres, mesma migration sequence do serviço | context (menor autoridade) |
| ADR-0001 (baseline) | Explicitamente fora de escopo para pedidos/pagamentos | baseline |
| `data-governance.md` (rule, dono único) | Transacional de negócio → MongoDB, salvo ADR em contrário | rules |

Baseline (ADR-0001, "fora de escopo") e rules (`data-governance.md`, MongoDB para transacional) apontam na mesma direção e têm autoridade maior que a suposição do pedido. Não há fonte de maior autoridade dizendo o oposto.

## O que este run NÃO fez (por decisão, não por omissão)

- Não criou `V003__pedidos_pagamentos.sql`.
- Não desenhou o schema de pedido/item/pagamento em PostgreSQL.

Mesmo com o pedido dizendo "pode criar o arquivo direto", seguir o protocolo da skill (passo 2, rules do projeto) e encontrar o conflito exige **parar antes do DDL**, não registrar a divergência e prosseguir.

## Verificação executada (protocolo, passos 3–4)

- `bash .forge/scripts/check-data-governance.sh --path services/recargas` → `OK data-governance/universo` e `OK data-governance (1 .md, 0 código, no divergence)`. Não achou PAN/PII nem divergência de governança no que já existe (README + migrations V001/V002) — consistente: o conflito não é de PAN/PII, é de escolha de store para um domínio ainda não migrado.
- `bash .forge/skills/data-relational-practices/scripts/scan.sh --root services/recargas` (executado a partir do artefato do harness, já que o worktree de eval não traz `.forge/skills`) → 13 regras, todas `OK ... nenhuma ocorrência`, 2 arquivos varridos (V001, V002). Nada a reportar nas migrations existentes — o scanner não tem o que examinar porque V003 não foi criado.

## Opções para decisão humana (HITL, `conflict-handling.md` §2.2)

1. **Aplicar a fonte de maior autoridade (recomendado):** modelar pedido/item/pedido/pagamento em MongoDB, conforme `data-governance.md`, com filtro de `tenant` obrigatório na camada de repositório (Mongo não tem RLS nativo) — fora do escopo desta skill relacional; delegar ao especialista `data-transactional-nosql` (ou equivalente) se existir no projeto real.
2. **Abrir/atualizar ADR:** se a decisão do time for realmente usar PostgreSQL para pedidos/pagamentos (por exemplo, por necessidade de transação ACID forte entre pedido e pagamento, ou por já ter operação PostgreSQL no serviço), registrar um novo ADR (ex. `ADR-000X — PostgreSQL para pedidos e pagamentos do serviço de recargas`) que explicitamente supere/complemente o "fora de escopo" do ADR-0001, com a justificativa técnica. Só depois desse ADR aceito esta skill volta e desenha a migration.
3. **Block:** não prosseguir até a decisão ser tomada.

## Nota sobre o registro em `approvals.yaml`

O protocolo (`conflict-handling.md` §2.3) pede registrar a decisão em `approvals.yaml` no gate correspondente. Este run é um caso de eval isolado (sem pipeline `/forge:*` ativo, sem `change` aberto) — não há `approvals.yaml` de change a atualizar; o registro decisório está neste documento e no `transcript.md`.
