# Transcript — eval-planeja-backlog-e-sprints-do-zero (with_skill / run-1)

## 1. Bootstrap e restrições

- `cd .../evals-100 && pwd && git branch --show-current` — confirmado `evals-100` / `chore/evals-skills-agentes`, conforme esperado pelo prompt.
- Registrado `t0 = date +%s` em `.t0`.
- Regras do ambiente de avaliação aplicadas integralmente: nenhum `git commit/push/checkout/stash`, nenhum `tests/run-all.sh`/`npm test`/`docker`/`ledger-ops.sh`/`liaison-ops.sh`/`gh` de escrita/`npm publish`/deploy real; nenhum `sleep` em foreground; nenhum spawn de subagente (o agente `product-backlog` não delega a subagentes na sua especificação, então não houve despacho a registrar); toda ação externa (sincronização Jira) foi simulada e documentada em vez de executada.

## 2. Preparação da fixture

- `mkdir -p .../run-1/work`
- `bash .../fixtures/planeja-backlog-e-sprints-do-zero/setup.sh .../run-1/work` — executado com sucesso (exit 0). Gerou um projeto Forge inicializado como "Passe Livre Digital" com `docs/product/modules/{card-wallet,fare-validation}/{README,requirements,design,tasks}.md`, `docs/product/trd/trd.md` e `docs/product/modules/modules-validation-report.md`, e removeu os artefatos do agente sob avaliação (`.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents`, `plugin`) para não contaminar o teste.

## 3. Leitura do artefato do agente

- Lido `template/.forge/agents/specifications/product-backlog.md` (harness, somente leitura) na íntegra: missão, posição no pipeline, princípios de planejamento de sprints (§4), mapeamento Módulos → Jira (§5), estrutura de output (§6), algoritmo de execução em 4 fases (§7), regras de sincronização (§8) e anti-patterns (§9). Segui esse artefato como definição do agente que sou nesta execução.

## 4. Fase 1 — Inspeção e validação

- `docs/product/backlog/progress-tracking.md` não existia → primeira execução.
- `Glob docs/product/modules/*/README.md` → 2 módulos: `card-wallet`, `fare-validation`.
- Confirmado quarteto completo (README + requirements + design + tasks) para os dois módulos. Nenhum módulo faltando artefato — não houve necessidade de interromper.
- Lido `docs/product/trd/trd.md`: 3 deployables (DEP-01 wallet-api, DEP-02 validation-sync, DEP-03 postgres-main), infraestrutura transversal (OpenTelemetry, JWT, RabbitMQ).
- Lido `docs/product/modules/modules-validation-report.md`: parecer geral "Aprovado com Ressalvas" — card-wallet Aprovado, fare-validation Aprovado com Ressalvas (SLO de latência de sincronização offline sem número no NFRD). Essa ressalva foi carregada para o plano de sprints como risco explícito na Sprint 3.

## 5. Extração de requisitos e tasks por módulo

- `card-wallet`: 3 RFs (RF-001 criar carteira, RF-002 recarga Pix, RF-003 saldo/extrato) e 7 TASKs (TASK-01..07), com cadeia de dependência TASK-01 → TASK-02 → TASK-03 → {TASK-04 → TASK-05 → TASK-07; TASK-06}.
- `fare-validation`: 3 RFs (RF-004 ingestão de lote, RF-005 integração temporal, RF-006 consulta de auditoria) e 7 TASKs (TASK-01..07), com dependência explícita de `card-wallet TASK-01` (TASK-01 de fare-validation) e de `card-wallet TASK-05` (TASK-04 de fare-validation, o `FareCalculator`).

## 6. Fase 2 — Construção do backlog (markdown primeiro)

- Mapeei 1 épico por módulo (EP-001 card-wallet, EP-002 fare-validation) — regra "Épico = Módulo" respeitada.
- Cada RF virou exatamente 1 user story (US-001..US-006), com critérios de aceite em Given/When/Then extraídos literalmente de `requirements.md`.
- TASKs do tipo `feature` que compartilham a mesma RF viraram tasks técnicas sob a story correspondente (ex.: TASK-04+TASK-05 de card-wallet, ambas RF-002, sob US-002). TASKs do tipo `infra` sem RF associada (TASK-01, TASK-02 de card-wallet; TASK-01, TASK-07 de fare-validation) viraram tasks sob o épico, sem story pai, por não terem valor direto ao usuário.
- Estimei story points em Fibonacci por complexidade declarada: 5 (CRUD simples com regra de conflito), 8 (integração externa com webhook/idempotência ou máquina de estado temporal), 3 (leitura/consulta simples). Total: 35 pontos em 6 stories.
- Escrevi `docs/product/backlog/product-backlog.md` com as 5 seções do template (épicos, stories, tasks, bugs — vazio nesta primeira execução —, e mapeamento Local↔Jira marcado como pendente).

## 7. Fase 3 — Plano de sprints (markdown primeiro)

- Grafo de dependências: fare-validation TASK-01 depende de card-wallet TASK-01 (mesmo runtime .NET 8, mas deployables e schemas distintos); fare-validation TASK-04 (`FareCalculator`) depende tanto de fare-validation TASK-03 quanto de card-wallet TASK-05 (webhook Pix, fonte do saldo a debitar).
- Ordenação topológica com granularidade 2–5 stories por sprint e teto de ~24 pontos (time de 4 devs, informado pelo usuário):
  - **Sprint 1** (fundação): scaffolds e schemas dos dois deployables + US-001 (criar carteira) — 20 pontos.
  - **Sprint 2**: US-002 (recarga Pix), US-003 (saldo/extrato), US-004 (ingestão de lote + cadastro mTLS), US-006 (consulta de auditoria) — 22 pontos. US-006 antecipada para esta sprint por não ter dependência de US-005, aproveitando capacidade ociosa.
  - **Sprint 3**: US-005 (integração tarifária de 60 min + confirmação de débito) + painel OpenTelemetry — 11 pontos, deliberadamente abaixo do teto para absorver a ressalva de SLO do relatório de validação.
- Sprint length: 2 semanas, início segunda-feira 2026-10-05 (conforme pedido do usuário) — Sprint 1: 2026-10-05 a 2026-10-18; Sprint 2: 2026-10-19 a 2026-11-01; Sprint 3: 2026-11-02 a 2026-11-15.
- Escrevi `sprints-planning.md` (visão executiva, mapa módulo→sprints, tabela de sprints, dependências críticas, riscos) e um `sprint-N-<slug>.md` por sprint, cada um com objetivo de sprint em 1 frase (padrão §4.4 da especificação), backlog detalhado com critérios de aceite e Definition of Done, riscos e checklist de encerramento.
- Escrevi `progress-tracking.md` registrando que a Fase 4 (Jira) não foi executada nesta rodada — não por falha de MCP, mas por restrição explícita do ambiente de avaliação — e apontando para o roteiro de execução real.

## 8. Fase 4 — Sincronização com Jira: simulada, não executada

- Por mandato do ambiente de avaliação ("simule e registre em outputs/ o que faria" para qualquer ação externa), não chamei nenhuma ferramenta `mcp__atlassian__*` real. Em vez disso, documentei em `outputs/jira-sync-simulation.md` a sequência exata que a §7.4 da especificação do agente determina: autenticação → descoberta do projeto PLD (já existente, reaproveitado, não recriado) → 2 épicos → 6 stories → 14 tasks → board de 4 colunas → 3 sprints com goal e atribuição de itens → atualização final do mapeamento Local↔Jira.
- Essa decisão respeita a regra "markdown primeiro, sempre" do agente (§8.1): o markdown ficou completo e estável antes de qualquer consideração sobre Jira, e nenhuma entrada de `product-backlog.md` §5 foi preenchida com Issue Key fictícia — todas ficaram explicitamente "pendente", para não criar uma ilusão de sincronização que não ocorreu.

## 9. Entregáveis e fechamento

- Copiados para `outputs/docs/product/backlog/`: `product-backlog.md`, `sprints-planning.md`, `sprint-1-fundacao-e-criacao-de-carteira.md`, `sprint-2-recarga-pix-cadastro-validador-e-auditoria.md`, `sprint-3-integracao-tarifaria-e-confirmacao-de-debito.md`, `progress-tracking.md`.
- `outputs/jira-sync-simulation.md` — despacho detalhado das chamadas Jira que seriam feitas.
- `work/` ficou com ~6,1 MB, abaixo do limite de 20 MB — não foi necessário apagar.
- `timing.json` escrito ao final com `t1 - t0` em segundos e milissegundos.

## Lacunas detectadas (para reportar ao usuário numa execução real)

- SLO de latência de sincronização offline do NFRD de fare-validation segue sem número — a Sprint 3 foi dimensionada com folga para isso, mas o valor definitivo deve ser confirmado antes do início dessa sprint.
- Nenhum bug ativo nesta primeira execução (backlog partiu direto da especificação).
- Capacidade de 24 pontos/sprint é estimativa do usuário, não medida — revisar após a Sprint 1 fechar com velocidade real.
