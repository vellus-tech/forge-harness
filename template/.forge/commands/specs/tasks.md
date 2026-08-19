---
description: Gera as tasks do change ativo — TASK-NN rastreáveis, ordenadas por dependência, agrupadas em waves — com gate HITL. Transiciona para tasks-ready.
argument-hint: "[<change-id>]"
---

# /forge:tasks — tasks do change

Argumentos: `$ARGUMENTS` (change-id opcional; sem argumento, use o único change ativo).

Pré-condição: a última fase exigida pelo scale está pronta (`requirements-ready` em scale 1; `design-ready` em scale ≥2; `proposed` em scale 0). **Exceção:** `type: bugfix` scale ≥2 pode chegar direto de `requirements-ready` (design é opcional para esse tipo — ver `/forge:design`, LDG-0030); `design-ready` continua sendo um estado válido se o bugfix optou por ele.

## 1. Geração

Preencha `tasks.md` (estrutura do template do change) derivando dos artefatos existentes:

- **`TASK-NN`** com numeração contínua; título objetivo; cada task atômica (≈1 commit);
- cada task declara: `rastreia:` (REQ-NN / seção do design / seção do bugfix), `paths:` previstos e `depende:` (TASK-NN ou —);
- agrupe em **waves** por dependência (uma wave só depende de waves anteriores; sem ciclos);
- inclua tasks de teste/verificação exigidas pelo artefato de requirements (bugfix: testes de regressão da §5 são tasks obrigatórias);
- **`type: bugfix` — a TASK do Red precede toda TASK de correção, com dependência explícita.** Abra uma `TASK-01` (ou a primeira da wave 1) dedicada a `/forge:red record` + `/forge:red replay` — `rastreia: bugfix.md §5`, DoD é a evidência gravada como `observed` (ver `.forge/rules/testing/regression-red-first.md`). Toda TASK que altera `fix_files` declara `depende: TASK-01` (ou o número correspondente). Nunca agrupe Red e correção na mesma task — mesmo quando a correção é trivial, a separação preserva a possibilidade de observar o Red isoladamente antes do Green.
- tabela de rastreabilidade ao final: todo REQ (ou invariante/teste de regressão) coberto por ≥1 task.

## 2. Checagem estrutural (antes do gate) — por script, não por leitura

A integridade do grafo de tasks é verificada por `lib/tasks-graph.mjs`, executado dentro do `validate-spec` na transição a `tasks-ready`. **Não confira estes itens lendo o arquivo** — rode o validador e corrija o que ele apontar:

```bash
bash .forge/scripts/validate-spec.sh <change-id>
```

**Bloqueiam** a transição: **TSK-01** dependência que aponta para TASK inexistente · **TSK-02** ciclo · **TSK-03** dependência para TASK de wave **posterior** · **TSK-04** ID **duplicado** · **TSK-06** **nenhuma** task declara metadados.

**Avisam** (`WARN`, não travam):

- **TSK-04 furo na numeração.** Ambíguo por natureza: pode ser task perdida num merge, mas também é o resultado de remover uma task sem renumerar — que é a operação segura, já que renumerar invalida referências gravadas em commits, PRs e stories.
- **TSK-05 não foi possível verificar.** Nenhum cabeçalho de wave reconhecido, logo a ordem topológica entre waves não foi conferida. Um check que não rodou é indistinguível de um check que passou, e é por isso que ele se anuncia.
- **SRF-01 cobertura de superfície.** Cruza o "Checklist de cobertura de superfície" do `requirements.md` contra o grafo: REQ que declara endpoint/rota sem que nenhuma das tasks que o cobrem produza superfície. Resolva declarando o `paths:` real da task que entrega a rota, ou abrindo a task que falta.
- **TSK-06 parte das tasks sem bloco de metadados.** As dependências dessas tasks não entraram no grafo. Avisa quando é pontual (task trivial é motivo plausível) e **bloqueia** quando é o plano inteiro — aí não sobrou aresta nenhuma, e TSK-01/02/03 passariam por vacuidade. `depende: —` é declaração de independência e não conta como omissão: o que se cobra é ter declarado, não ter dependência.
- **SRF-02 Checklist ausente ou vazio** — mesmo princípio do TSK-05: o SRF-01 não rodou, e isso aparece.
- **SRF-03 superfície de API declarada em prosa.** A célula fala em endpoint/rota mas não cita `VERB /path`. Medido contra um repositório real, 64% dos achados de SRF-01 caem em células assim ("endpoints de publicação no bff + tela admin") — e sobre prosa o oráculo de rota não tem o que cruzar: não dá para distinguir "o endpoint não existe" de "a task declarou `paths:` incompleto". Escrever `POST /api/v1/lists/ranges` no lugar de "endpoint de listas" é o que torna a cobertura verificável. Superfície que não é de API (tela, CLI, flag) não é cobrada.

O parser reconhece os campos `rastreia:`/`paths:`/`depende:` pelo **nome**, em qualquer ordem, com ou sem parênteses em volta — não há forma canônica a memorizar.

Estes eram itens de checklist para você conferir a olho. Num plano de 89 tasks, a conferência a olho deixou passar uma dependência de Wave 4 para Wave 7 — por isso viraram código.

Continua sendo seu: **nenhum REQ órfão na tabela de rastreabilidade** (o validador cobre a coerência de `traceability.yaml`, não a completude da tabela em prosa).

## 3. Gate HITL — `tasks_reviewed` (§12.1)

`AskUserQuestion` (resumo: nº de tasks, waves, cobertura): **Approve** / **Review** / **Reject** / **Block**.

```bash
bash .forge/scripts/approval-log.sh <change-id> --gate tasks_reviewed --decision <decision> [--reason "<motivo>"] --scope "tasks.md"
```

- **Approve** → `bash .forge/scripts/spec-transition.sh <change-id> tasks-ready`. Próximo: `/forge:analyze` (obrigatório em scale ≥3) e, também em scale ≥3, `/forge:shard` — `/forge:implement` reprova fechado (`validate-spec.sh`) se `dev_loop.sharded` não estiver `true`.
- **Review** → ajuste conforme o motivo e reapresente.
- **Reject**/**Block** → registre e pare.

## Regras

- Story sharding (épicos → stories auto-contidas) chega na W5.0 — não fatie aqui.
- Não inicie implementação neste comando.

## Modo autônomo (--yolo)

Se `autonomy.mode: yolo` (`forge.yaml`) ou `--yolo` na invocação, este gate não para no `AskUserQuestion`: invoque o agent `yolo-gate` (model **opus**, effort **high**) sobre o artefato — ele analisa, decide (approve/review/reject/block) e registra em `approvals.yaml` com `autonomous: true` via `approval-log.sh --autonomous`. `review` autônomo alimenta o loop até 3 iterações e então escala ao humano. Falhas de execução e conflitos de fontes continuam parando (não são gates). Ver `.forge/rules/conventions/autonomy-yolo.md`.
