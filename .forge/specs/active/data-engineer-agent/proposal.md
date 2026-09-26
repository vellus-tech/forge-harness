# Proposal — data-engineer-agent

> Change `data-engineer-agent` (type: `feature`, scale 2, mode brownfield) — criado em 2026-09-26 por Milton Antonio da Silva Jr, a partir da issue #177.
> Fluxo dogfood: as skills `/forge:*` não rodam na raiz; os scripts do engine rodam por `FORGE_ROOT=<worktree> bash template/.forge/scripts/*.sh` e a fonte canônica do que se entrega é `template/.forge/**`.

## 1. Por quê (problema / motivação)

O harness não tem especialista em dados. Decisões de modelagem relacional, chave de partição NoSQL, política de cache, layout e ciclo de vida de bucket, modelagem dimensional e topologia de mensageria ficam hoje com os agentes de engenharia genéricos (`engineering/*`, `code-review/*`), que não carregam checklist de boas práticas nem catálogo de antipatterns por modelo de armazenamento. O efeito é conhecido: a mesma pergunta ("posso usar Redis para essa fila?", "partição por `status` no DynamoDB?", "`nack` com requeue resolve o retry?") recebe respostas genéricas, às vezes desatualizadas (filas espelhadas clássicas e o plugin de delayed exchange do RabbitMQ, ambos removidos ou arquivados), e nenhuma detecção mecânica acompanha o conselho.

As rules `rules/data/*` já existentes cobrem só a governança transversal de três stores (PostgreSQL, MongoDB, Redis) e o isolamento multi-tenant; não cobrem object storage, analítico nem mensageria, e não trazem detecção.

A base de conhecimento foi pesquisada em três frentes independentes e julgada por um avaliador independente (LLMs as a Judge): `research/base-consolidada.md` deste change, cópia fiel do julgamento de 2026-09-26. Só entra neste change o que o juiz sustentou; o refutado e o incerto ficam fora das regras duras (base §8).

## 2. O que muda

1. **Agente orquestrador `data-engineer`** em `template/.forge/agents/data/data-engineer.md`, que classifica o pedido pela taxonomia registrada no design (padrão de acesso dominante, depois forma do dado, depois produto), roteia para um ou mais especialistas via ferramenta `Agent`, com a restrição de tipos feita por hook `PreToolUse` no frontmatter (a lista entre parênteses de `Agent(...)` só vale no modo `claude --agent`; como subagente ela é ignorada), aplica o checklist transversal (dado sensível, multi-tenant, custo, reversibilidade, operação) e sintetiza a resposta. Sem a ferramenta `Agent` disponível, devolve um plano de roteamento estruturado em vez de improvisar a resposta de especialista. Em conflito relevante com rule do projeto, ele e os especialistas param e devolvem um bloco `CONFLITO` para decisão humana, como manda `rules/conventions/conflict-handling.md`.
2. **Seis subagentes especialistas** em `template/.forge/agents/data/`: `data-relational`, `data-nosql`, `data-cache`, `data-object-storage`, `data-analytical` e `data-streaming` — este último com especialização obrigatória e profunda em RabbitMQ 4.x (exchanges e roteamento, filas quorum, DLX, ack e prefetch, publisher confirms, retry nativo, idempotência, ordem, operação e migrações).
3. **Seis skills de referência**, uma por especialista, em `template/.forge/skills/data-<domínio>-practices/`, no padrão de `node-quality-scan`: `SKILL.md` enxuto com protocolo, `references/best-practices.md`, `references/antipatterns.md` (cada antipattern com sintoma, por quê, correção e detecção mecânica quando houver) e `scripts/scan.sh` determinístico para o que for detectável por varredura estática.
4. **Integração com o que já existe:** `capability-dispatcher` passa a indicar o especialista de dados pela área afetada (sem mudar a `description`); os quatro revisores de `code-review/` e os `PROFILE.md` dos packs relacionais passam a apontar os scanners e o `data-engineer`; os especialistas usam o `check-data-governance.sh` e o `data-classification.json` que já existem para PCI/PII; `agents/README.md` ganha a categoria `data/`; o inventário do `README.md` e o `CHANGELOG.md` são atualizados; a projeção pelos adapters (`.claude/agents`, `.claude/skills`, `.agents/skills`) é verificada numa instalação real, sem mudar o código do `sync-adapters`.
5. **Gate estrutural novo, red-first:** `tests/w250-data-engineer-agents-gate.sh`, com prova de mutação.
6. **Casos de eval A/B** pelo protocolo do skill-creator, no mesmo formato que a frente paralela de evals grava em `.forge/evals/`: três por especialista e doze para o orquestrador (seis críticos), em `.forge/evals/agents/<nome>/evals.json` (dogfood), executados pelo orquestrador depois da implementação com instalação real por braço, três repetições e roteamento medido no trace.

## 3. O que NÃO muda (fora de escopo)

- Nenhum comando `/forge:*` novo; o plugin `plugin/forge/**` não muda (decisão D-05 do design).
- Código de `sync-adapters.mjs`, `plugin-build.mjs` e `bin/forge.mjs` intocado: `agents/` e `skills/` já são maquinaria projetada recursivamente e distribuída no overlay do `forge update`.
- As rules `rules/data/*.md` e `rules/domain/money-as-cents.md` não são reescritas. Onde a base diverge delas (dinheiro em `numeric`, RLS opcional, Redis como fonte da verdade), o change obedece à rule. A divergência entre `data-governance.md` ("transacional de negócio → MongoDB") e a taxonomia ("transação multi-entidade estrita → relacional") é conflito relevante de estratégia de persistência e vai para HITL antes da implementação (design §2.9, H-01), com registro em `approvals.yaml`; mudar a rule, se for a decisão, é change próprio com ADR.
- Busca textual e vetorial não ganham especialista: lacuna declarada, com resposta explícita de "fora da cobertura" (base §0.3 item 7).
- Nenhum scanner conecta em banco, broker, cache ou nuvem: detecção de runtime (consultas a `pg_stat_*`, `redis-cli`, `rabbitmqctl`, APIs de nuvem) fica documentada em `antipatterns.md`, nunca executada pelo `scan.sh`.
- Nenhum scanner vira gate bloqueante do pipeline (`/forge:verify`, pre-push); eles são instrumento do especialista.

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template`.
- **Paths afetados:** `template/.forge/agents/data/`, `template/.forge/agents/README.md`, `template/.forge/agents/code-review/{node,java,python,dotnet}-reviewer.md`, `template/.forge/capabilities/backend-{java,python,dotnet}-relational/PROFILE.md`, `template/.forge/capabilities/backend-node-postgres/PROFILE.md`, `template/.forge/skills/data-*-practices/`, `template/.forge/skills/capability-dispatcher/SKILL.md`, `template/.forge/scripts/data-agent-allowlist.sh`, `tests/w250-data-engineer-agents-gate.sh`, `tests/fixtures/w250/`, `.forge/evals/agents/data-*/`, `.forge/graph/graph.json`, `README.md`, `CHANGELOG.md`.
- **Dependências:** nenhuma spec; decisão humana H-01 antes da implementação; formato de evals da frente paralela `evals-100` (branch `chore/evals-skills-agentes`); comportamento documentado do Claude Code para subagentes (aninhamento até três níveis por padrão, varredura recursiva de `.claude/agents/`, campos `skills` e `hooks` no frontmatter, lista de `Agent(...)` só efetiva no modo `--agent`), conferido na documentação oficial em 2026-09-26.
- **Riscos:**
  - Conflito de fonte entre a skill e `rules/data/data-governance.md` na escolha de store — tratado por HITL antes da implementação (H-01) e, em uso, pelo bloco `CONFLITO` que para a resposta (design §2.9).
  - Orquestrador criando subagente fora dos seis no modo subagente — mitigado pelo hook `PreToolUse` fail-closed (REQ-10).
  - Scanner regex com falso positivo que treina o time a ignorar o relatório — mitigado por severidade `aviso` para todo detector marcado [Heurística] e exit 0 quando só há avisos.
  - Recursiva sem `-a` em `.md` ou `.sh` novo reprova o w209 — mitigado por regra de redação e revalidação do w209.
  - Colisão de ordinal com frente paralela: w250 é piso manual desta rodada; `gate-ordinal.sh next` devolve w239 pelo tronco, os refs remotos só tomam w239 e w248, e a tabela do plano reserva w240–w246 (design §2.6) — reconferir com `gate-ordinal.sh check` antes do push.
  - Contagem de `README.md` desatualizada derruba o w200 — tratada na TASK de inventário.

## 5. Próximos passos

`requirements` → `design` → `tasks` → correção pela revisão do validador (design §3.1) → gate HITL de aprovação, que inclui a decisão H-01 (TASK-01) registrada em `approvals.yaml` → `/forge:implement` por waves, red-first (TASK-02 é o gate vermelho, commit só de teste) → revalidação dos gates que exercitam arquivos tocados → execução dos evals A/B pelo orquestrador → `/forge:verify` → `code-evaluator` → PR para `develop`.
