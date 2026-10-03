# Transcript — eval-planeja-backlog-e-sprints-do-zero / without_skill / run-1

## Contexto da execução

Caso de eval baseline (`without_skill`): executado sem ler `.forge/skills`, `.forge/agents` ou `plugin` do artefato sob avaliação, e sem ler `.forge/evals`. Apenas conhecimento próprio do modelo aplicado sobre os artefatos da fixture.

## Passos executados, em ordem

1. Verifiquei o bootstrap do diretório de trabalho (`cd .../evals-100 && pwd && git branch --show-current`) — confirmou o diretório e a branch `chore/evals-skills-agentes` esperados.
2. Criei o diretório do run (`run-1`) e gravei `.t0` com `date +%s` (epoch inicial) para medição de duração.
3. Criei `run-1/work` e executei a fixture: `bash fixtures/planeja-backlog-e-sprints-do-zero/setup.sh run-1/work`. O script roda `forge init` no diretório alvo, aplica o overlay base "Passe Livre Digital" + overlay específico do caso, faz `git init`/`commit` interno à fixture (parte do próprio script de setup, não uma ação minha fora do work/) e remove `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` e `plugin` do alvo — garantindo que o baseline sem o artefato não contamine o resultado.
4. Explorei o resultado da fixture: `docs/product/trd/trd.md`, `docs/product/modules/modules-validation-report.md`, e README/requirements/tasks de `card-wallet` e `fare-validation`.
5. Li os requisitos funcionais (RF-001 a RF-006) e as TASK-xx de cada módulo, e o TRD (deployables DEP-01 wallet-api, DEP-02 validation-sync, DEP-03 postgres-main compartilhado, mensageria RabbitMQ entre os dois).
6. Identifiquei a ressalva do relatório de validação de módulos: `fare-validation` aprovado com ressalva por falta de SLO numérico de latência de sincronização offline no NFRD — decidi registrar essa lacuna explicitamente no backlog em vez de inventar um número, e mapear a TASK-07 (painel OTel) de `fare-validation` como enabler de mitigação (instrumentação), deixando claro que o SLO em si segue pendente de definição de produto.
7. Montei o backlog agrupando as 14 TASK-xx (7 por módulo) em 12 stories por RF (ou como enabler de infraestrutura quando a TASK não tinha RF associado), com estimativa em pontos Fibonacci por complexidade técnica/superfície de teste, preservando a coluna "Depende de" original dos tasks.md e as dependências cruzadas descritas nos README (evento `WalletDebited`/`FareCharged` entre os dois módulos) e no TRD (schema Postgres compartilhado).
8. Escrevi `work/docs/product/backlog/backlog.md` (2 épicos, 12 stories, 58 pontos, seção de risco herdado da validação de módulos, seção de dependências entre épicos).
9. Planejei as sprints: time de 4 devs, ~24 pontos/sprint, sprints de 2 semanas a partir de segunda-feira 2026-10-05. Em vez de encher cada sprint até 24 pontos, sequenciei respeitando as dependências — por isso Sprint 1 (23 pts) e Sprint 2 (21 pts) ficam perto do teto, mas Sprint 3 (14 pts) fica abaixo, porque as três stories finais (FV-4 → FV-5, e FV-7) formam uma cadeia sequencial sem mais trabalho independente disponível para completar a capacidade sem violar dependência.
10. Escrevi `work/docs/product/backlog/sprint-plan.md` com as 3 sprints, datas (Sprint 1: 2026-10-05–2026-10-16; Sprint 2: 2026-10-19–2026-10-30; Sprint 3: 2026-11-02–2026-11-13), tabela de resumo e riscos de sequenciamento.
11. Sobre "sobe tudo pro Jira no projeto Scrum PLD": esta execução roda sob regras do harness de eval que proíbem qualquer ação externa real (incluindo `mcp__jira__*` de escrita). Em vez de chamar a ferramenta, registrei em `outputs/jira-dispatch-simulado.md` exatamente o que seria criado — 2 épicos, 12 stories com story points e subtarefas mapeadas às TASK-xx, links de bloqueio entre stories, e as 3 sprints com suas datas e composição — e sinalizei explicitamente que a pré-condição "o projeto PLD já existe" não foi verificada nesta execução (nenhuma chamada real, nem de leitura, foi feita ao Jira).
12. Não houve necessidade de despacho de subagentes: a tarefa (leitura de artefatos + síntese de backlog + plano de sprints) foi executada inteiramente com conhecimento próprio, sem abrir investigação paralela que justificasse subagentes; por isso não há arquivo de despacho de agentes nesta run.
13. Copiei `backlog.md` e `sprint-plan.md` de `work/docs/product/backlog/` para `outputs/docs/product/backlog/`.
14. Grave este `transcript.md`.
15. Ao final: capturei `t1=$(date +%s)`, calculei a duração a partir de `.t0`, e escrevi `timing.json`. Chequei o tamanho de `work/` antes de decidir se apagava (regra: apagar apenas se ultrapassar 20 MB).

## Decisões e trade-offs

- **Agrupamento por RF em vez de 1 story por TASK:** cada TASK-xx isolada seria granular demais para um backlog de produto (ex.: "endpoint" e "schema" não são incrementos de valor por si só); agrupei por RF/entrega vertical, mantendo a rastreabilidade para as TASK de origem numa coluna própria.
- **Enablers de infraestrutura como stories próprias (CW-1, FV-1, FV-7)** em vez de diluí-los dentro das stories de RF: infraestrutura compartilhada (schema, outbox, scaffold) bloqueia múltiplas stories de RF e merece visibilidade e estimativa própria no backlog e no board.
- **Sprint 3 abaixo da capacidade de 24 pontos:** optei por respeitar a cadeia de dependências (FV-4 → FV-5, e FV-7 dependendo de FV-3) em vez de forçar mais uma story adiantada sem trabalho independente disponível, o que geraria risco de bloqueio sem ganho real de throughput.
- **Não inventei o SLO de latência ausente:** o relatório de validação de módulos sinalizou a lacuna; preservei-a como risco explícito em vez de propor um número arbitrário, e mapeei apenas a instrumentação (TASK-07/FV-7) como mitigação parcial.
