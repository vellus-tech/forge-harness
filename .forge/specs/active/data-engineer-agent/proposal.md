# Proposal — data-engineer-agent

> Change `data-engineer-agent` (type: `feature`, scale 2, mode brownfield) — criado em 2026-09-26 por Milton Antonio da Silva Jr, a partir da issue #177.
> Fluxo dogfood: as skills `/forge:*` não rodam na raiz; os scripts do engine rodam por `FORGE_ROOT=<worktree> bash template/.forge/scripts/*.sh` e a fonte canônica do que se entrega é `template/.forge/**`.

## 1. Por quê (problema / motivação)

O harness não tem especialista em dados. Decisões de modelagem relacional, chave de partição NoSQL, política de cache, layout e ciclo de vida de bucket, modelagem dimensional e topologia de mensageria ficam hoje com os agentes de engenharia genéricos (`engineering/*`, `code-review/*`), que não carregam checklist de boas práticas nem catálogo de antipatterns por modelo de armazenamento. O efeito é conhecido: a mesma pergunta ("posso usar Redis para essa fila?", "partição por `status` no DynamoDB?", "`nack` com requeue resolve o retry?") recebe respostas genéricas, às vezes desatualizadas (filas espelhadas clássicas e o plugin de delayed exchange do RabbitMQ, ambos removidos ou arquivados), e nenhuma detecção mecânica acompanha o conselho.

As rules `rules/data/*` já existentes cobrem só a governança transversal de três stores (PostgreSQL, MongoDB, Redis) e o isolamento multi-tenant; não cobrem object storage, analítico nem mensageria, e não trazem detecção.

A base de conhecimento foi pesquisada em três frentes independentes e julgada por um avaliador independente (LLMs as a Judge): `research/base-consolidada.md` deste change, cópia fiel do julgamento de 2026-09-26. Só entra neste change o que o juiz sustentou; o refutado e o incerto ficam fora das regras duras (base §8).

## 2. O que muda

1. **Agente orquestrador `data-engineer`** em `template/.forge/agents/data/data-engineer.md`, que classifica o pedido pela taxonomia registrada no design (padrão de acesso dominante, depois forma do dado, depois produto), roteia para um ou mais especialistas via ferramenta `Agent` com allowlist, aplica o checklist transversal (dado sensível, multi-tenant, custo, reversibilidade, operação) e sintetiza a resposta. Sem a ferramenta `Agent` disponível, devolve um plano de roteamento estruturado em vez de improvisar a resposta de especialista.
2. **Seis subagentes especialistas** em `template/.forge/agents/data/`: `data-relational`, `data-nosql`, `data-cache`, `data-object-storage`, `data-analytical` e `data-streaming` — este último com especialização obrigatória e profunda em RabbitMQ 4.x (exchanges e roteamento, filas quorum, DLX, ack e prefetch, publisher confirms, retry nativo, idempotência, ordem, operação e migrações).
3. **Seis skills de referência**, uma por especialista, em `template/.forge/skills/data-<domínio>-practices/`, no padrão de `node-quality-scan`: `SKILL.md` enxuto com protocolo, `references/best-practices.md`, `references/antipatterns.md` (cada antipattern com sintoma, por quê, correção e detecção mecânica quando houver) e `scripts/scan.sh` determinístico para o que for detectável por varredura estática.
4. **Integração com o que já existe:** `capability-dispatcher` passa a indicar o especialista de dados pela área afetada; `agents/README.md` ganha a categoria `data/`; o inventário do `README.md` e o `CHANGELOG.md` são atualizados; a projeção pelos adapters (`.claude/agents`, `.claude/skills`, `.agents/skills`) é verificada numa instalação real, sem mudar o código do `sync-adapters`.
5. **Gate estrutural novo, red-first:** `tests/w250-data-engineer-agents-gate.sh`, com prova de mutação.
6. **Casos de eval A/B** pelo protocolo do skill-creator: três por especialista e um conjunto de roteamento para o orquestrador, em `.forge/evals/agents/<nome>/evals.json` (dogfood), executados pelo orquestrador depois da implementação.

## 3. O que NÃO muda (fora de escopo)

- Nenhum comando `/forge:*` novo; o plugin `plugin/forge/**` não muda (decisão D-05 do design).
- Código de `sync-adapters.mjs`, `plugin-build.mjs` e `bin/forge.mjs` intocado: `agents/` e `skills/` já são maquinaria projetada recursivamente e distribuída no overlay do `forge update`.
- As rules `rules/data/*.md` não são reescritas. A divergência entre `data-governance.md` ("transacional de negócio → MongoDB") e a taxonomia deste change ("transação multi-entidade estrita → relacional") é tratada por precedência (rule vence skill) e registrada como follow-up, não resolvida aqui (design D-06).
- Busca textual e vetorial não ganham especialista: lacuna declarada, com resposta explícita de "fora da cobertura" (base §0.3 item 7).
- Nenhum scanner conecta em banco, broker, cache ou nuvem: detecção de runtime (consultas a `pg_stat_*`, `redis-cli`, `rabbitmqctl`, APIs de nuvem) fica documentada em `antipatterns.md`, nunca executada pelo `scan.sh`.
- Nenhum scanner vira gate bloqueante do pipeline (`/forge:verify`, pre-push); eles são instrumento do especialista.

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template`.
- **Paths afetados:** `template/.forge/agents/data/`, `template/.forge/agents/README.md`, `template/.forge/skills/data-*-practices/`, `template/.forge/skills/capability-dispatcher/SKILL.md`, `tests/w250-data-engineer-agents-gate.sh`, `tests/fixtures/w250/`, `.forge/evals/agents/`, `README.md`, `CHANGELOG.md`.
- **Dependências:** nenhuma spec; depende do comportamento documentado do Claude Code para subagentes (aninhamento até três níveis por padrão, varredura recursiva de `.claude/agents/`, campos `skills` e `tools: Agent(...)` no frontmatter), conferido na documentação oficial em 2026-09-26.
- **Riscos:**
  - Conflito de fonte entre a skill e `rules/data/data-governance.md` na escolha de store — mitigado por precedência explícita e registro (D-06).
  - Scanner regex com falso positivo que treina o time a ignorar o relatório — mitigado por severidade `aviso` para todo detector marcado [Heurística] e exit 0 quando só há avisos.
  - Recursiva sem `-a` em `.md` ou `.sh` novo reprova o w209 — mitigado por regra de redação e revalidação do w209.
  - Colisão de ordinal com frente paralela (w250 escolhido por `gate-ordinal.sh next`, pela tabela de ordinais do plano e pelos refs remotos em 2026-09-26) — reconferir com `gate-ordinal.sh check` antes do push.
  - Contagem de `README.md` desatualizada derruba o w200 — tratada na TASK de inventário.

## 5. Próximos passos

`requirements` → `design` → `tasks` (este commit) → gate HITL de aprovação → `/forge:implement` por waves, red-first (TASK-01 é o gate vermelho, commit só de teste) → revalidação dos gates que exercitam arquivos tocados → execução dos evals A/B pelo orquestrador → `/forge:verify` → `code-evaluator` → PR para `develop`.
