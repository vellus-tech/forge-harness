# Plano — Guardrail de governança (conflito de fontes) + fonte da verdade de dados

| | |
|---|---|
| **Versão** | 1.0 |
| **Data** | 2026-06-11 |
| **Status** | **Implementado (2026-06-11)** — GW.1/GW.2/GW.3 entregues e mergeadas em `develop`. Gates gw1/gw2/gw3 verdes. |
| **Origem** | Achado do piloto azim-crm: conflito arquitetural detectado mas não-bloqueante |
| **Escopo aprovado** | G1–G4 completo (HITL) |
| **Vira change** | `forge-conflict-guardrails` (spec lifecycle) quando chegar a vez |

## 1. Incidente que originou o plano

No pipeline de specs do azim-crm, dois módulos tomaram decisões de isolamento multi-tenant divergentes:

- `account-management` (DD-002) seguiu a rule `database-naming.md` → "coluna `tenant_id` + filtro EF, RLS opcional".
- `organization` (DD-001) seguiu `DEC-006`/`ADR-0001` → "RLS defesa em profundidade".

O agente **detectou** o conflito ("Conflito arquitetural relevante detectado") e mesmo assim **prosseguiu** ("vou registrar para o HITL... Seguindo para tasks"), propagando a inconsistência.

**Causa raiz confirmada:** `database-naming.md:139` afirma "Isolamento via coluna, não via schema separado nem RLS (**conforme ADR de multi-tenancy**)" — a rule diz estar derivada de um ADR mas codifica a decisão **oposta** à do ADR-0001 vigente do projeto. É a pendência já registrada na W1.5/W3.3 (rules que carregam decisões do projeto de referência como convenções universais), cobrando o preço.

## 2. Taxonomia da falha (raiz → sintoma)

| ID | Falha | Natureza |
|---|---|---|
| F1 | Precedência de fontes não é normativa — nenhuma rule declara qual vence (raiz) | governança |
| F2 | Rule em drift vs ADR aceito, sem detecção | consistência de camadas |
| F3 | Decisão transversal (multi-tenancy) tratada como `DD` por módulo | modelagem |
| F4 | Conflito relevante não bloqueou — agente "registra e segue" (sintoma) | comportamento |

## 3. Guardrails (G1–G4)

### G1 — `[CONFLICT]` arquitetural é bloqueante (trata F4)

Conflito entre fontes normativas (rule↔ADR, módulo↔módulo, change↔baseline) vira **FAIL bloqueante** no loop builder→validator (§14.6) e no `/forge:analyze`. O agente **para e escala via HITL** (AskUserQuestion) antes de `tasks`/`implement` — nunca "registra e segue".

- **Entregáveis:** rule `.forge/rules/conventions/conflict-handling.md`; reforço no `/forge:analyze` (severidade `conflict` arquitetural = BLOCKER que trava `implement`); **propagar a regra "Pare e sinalize em conflito explícito"** (que os engineering agents já têm) aos agents de specification e architecture (que hoje **não a têm** — confirmado).

### G2 — Precedência de fontes normativa (trata F1, a raiz)

Declarar no `FORGE.md`/`constitution.md` a ordem de autoridade explícita:

```
constitution > baseline (ADRs/capabilities aprovadas) > rules > context/defaults
```

Conflito entre duas fontes → a de maior autoridade vence; a de menor é marcada como **drift a corrigir**. "ADR diz RLS, rule diz não-RLS" passa a ter resposta determinística.

### G3 — Rules ancoradas em ADR + detecção de drift (trata F2)

Cada rule que codifica decisão arquitetural declara o ADR que a fundamenta no frontmatter:

```yaml
based_on: [ADR-0001]   # rule é derivada desta decisão; drift se o ADR divergir/sumir
```

Validador determinista (§19) flagra: rule com `based_on` apontando para ADR inexistente no projeto, ou cujo status não é `accepted`. Converge com o saneamento de rules pendente (W1.5/W3.3): rules que impõem decisão de projeto deixam de ser "universais" e passam a apontar para o ADR do projeto.

### G4 — Decisões transversais com dono único (trata F3)

Decisões que **vinculam todos os bounded contexts** (multi-tenancy, auditoria, formato de erro, etc.) são marcadas como **globais** no baseline/constitution, não como `DD` por módulo. O validador de módulos/DDD checa que nenhuma `DD` local contradiz uma decisão global (estende o contrato produtor↔consumidor do DDD corrigido na W1.5).

## 4. Fonte da verdade de tratamento de dados (requisito HITL 2026-06-11)

A decisão de dados é **transversal** (G4) e se expressa **por tipo de store** — a `database-naming.md` única e Postgres-cêntrica foi insuficiente. A fonte da verdade é estruturada em três camadas:

### 4.1 Camada de decisão (ADR)

ADR(s) de governança de dados no baseline definindo a estratégia por classe de store e a **decisão transversal de isolamento multi-tenant** mapeada a cada mecanismo. É o `based_on` das rules de dados (G3).

### 4.2 Camada de rules derivadas (uma por tipo de store, ancoradas no ADR — G3)

| Rule | Store | Papel | Isolamento multi-tenant | Defesa em profundidade |
|---|---|---|---|---|
| `data-config-sql.md` | PostgreSQL (SQL) | parâmetros, configurações, paramétricos relacionais | `tenant_id` obrigatório + **EF Global Query Filter obrigatório** + **RLS obrigatório** p/ tabelas multi-tenant de domínio | RLS no banco; dispensa **só por exceção formal documentada** |
| `data-transactional-nosql.md` | MongoDB (NoSQL) | transacional, eventos, dados de negócio de alto volume | campo `tenant` obrigatório + **filtro de repositório/interceptor obrigatório** (Mongo não tem RLS nativo) | índice composto por `tenant`; interceptor de acesso na aplicação |
| `data-cache.md` | Redis / Memcache | cache efêmero, performance | **namespacing de chave por tenant** obrigatório (`tenant:{id}:...`) | TTL explícito; classes proibidas (segredos, PAN/CVV, PII sem mascarar); política de invalidação |

### 4.3 Matriz transversal (a chave que faltava)

A decisão **"isolamento multi-tenant"** é uma só (dono único — G4), expressa por store:

```
multi-tenant isolation (decisão global)
  ├─ PostgreSQL → tenant_id + EF filter + RLS (exceção só formal)
  ├─ MongoDB    → tenant field + filtro de repositório obrigatório + índice
  └─ Redis      → key namespace tenant:{id}:* + TTL + classes proibidas
```

Um módulo que escolha um mecanismo divergente do prescrito para seu store → **CONFLICT bloqueante** (G1), resolvido por precedência (G2: ADR de dados vence rule genérica).

**Decisão SQL canônica (do incidente, registrada):** `tenant_id` obrigatório; EF Global Query Filter obrigatório; RLS obrigatório para tabelas multi-tenant de domínio; RLS dispensável **só por exceção formal documentada**. Esta é a entrada `PostgreSQL` da matriz.

## 5. Plano de implementação (quando virar change, pós-MVP4)

Sugestão de waves do change `forge-conflict-guardrails` (type: feature, scale 3):

- **GW.1 — Precedência + bloqueio (G1, G2):** rule `conflict-handling.md`; bloco de precedência no `FORGE.md`/`constitution`; reforço no `/forge:analyze` e propagação da regra de bloqueio aos spec/architecture agents. Gate: fixture com rule↔ADR em conflito → `/forge:analyze` retorna BLOCKER e trava `implement`.
- **GW.2 — Rules ancoradas + drift (G3):** frontmatter `based_on` + validador de ancoragem (§19). Gate: rule apontando ADR inexistente/não-accepted → FAIL nomeando a rule.
- **GW.3 — Fonte da verdade de dados (G4 + §4):** ADR de governança de dados + as 3 rules de store + matriz transversal; validador de DDD/módulo estendido (DD local não contradiz decisão global). Saneia a `database-naming.md` em drift. Gate: módulo com mecanismo de isolamento divergente do store → CONFLICT bloqueante.

## 5.1 Resultado da implementação (2026-06-11)

- **GW.1 (G1+G2):** precedência de fontes no `FORGE.md` §2.1 + constitution princípio 11; rule `conventions/conflict-handling.md`; **enforcement determinista** — `spec-transition.sh` recusa `implementing` enquanto `analysis.md` tiver BLOCKER aberto/Status FAIL; `/forge:analyze` reforçado (conflito = BLOCKER, nunca rebaixar); regra de bloqueio propagada (agents/README + run-spec-pipeline). Gate `gw1`.
- **GW.2 (G3):** `validate-rules.{mjs,sh}` — rule com `based_on:[ADR-NNNN]` deve apontar para ADR existente e `accepted`, senão drift; integrado ao `validate-harness`/doctor; convenção no `rules/README`. Corrigido de quebra um bug latente que **eu** introduzira na W3.1 (description obrigatória batia nas 24 rules `title`-only — agora description só é exigida quando não há `title`). Gate `gw2`.
- **GW.3 (G4 + §4):** 4 rules em `rules/data/` (matriz `data-governance` + `data-config-sql`/`data-transactional-nosql`/`data-cache` com a decisão SQL canônica do incidente); `database-naming.md` **saneada** (não afirma mais "sem RLS conforme ADR"); `check-data-governance.{mjs,sh}` flagra o anti-padrão literal ("RLS opcional"/"sem RLS"/cache sem namespace de tenant) como CONFLICT; ADR template `templates/product/adr-data-governance.md`. Gate `gw3` (8 passos, incluindo o anti-padrão literal do incidente num change real).
- **Contrato v1.2:** cláusula C3 tornada aditiva (`>= 27` rules no modo generated); rules 27 → 32.

## 6. Relação com o saneamento de rules já pendente

Este plano **absorve e resolve** a pendência "rules acopladas ao projeto de referência" registrada na revisão W1.5 e reaberta na W3.3: a `database-naming.md` (e irmãs que codificam decisão de projeto) deixam de impor decisões universais e passam a ser rules de store ancoradas em ADR (G3) — exatamente o mecanismo que faltava.

## Controle de versão do documento

- Milton Silva - 2026-06-11 - Versão 1.0: registro do achado do piloto, taxonomia, guardrails G1–G4 (escopo HITL completo) e fonte da verdade de dados por tipo de store (requisito HITL). Implementação na fila pós-MVP4.
