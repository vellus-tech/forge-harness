# Tasks — data-engineer-agent

> Tasks do change `data-engineer-agent`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua; renumeradas na revisão do validador de 2026-09-26).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (1 commit), rastreável a um REQ/seção do design, e declara o que toca. Red-first: a TASK-02 entra vermelha num commit só de teste; cada task seguinte declara quais cenários do w250 ela torna verdes, e o implementador roda só o w250 e os gates listados na task, nunca a suíte completa.

## Wave 0 — Decisão humana (bloqueia todo o resto)

- [!] TASK-01 — HITL do conflito H-01 (design §2.9: "transacional de negócio → MongoDB" na `data-governance.md` × "transação multi-entidade estrita → relacional" na matriz) pela `conflict-handling.md` §2, com as opções (a) aplicar a rule, recomendado, (b) ADR e change próprio para revisar a rule, (c) bloquear; confirmar no mesmo HITL o alinhamento C-1..C-3 (obediência à rule, sem opção a decidir). Registrar a decisão em `approvals.yaml` do change (gate `design_reviewed`, `decision` e `reason`) e fixar a partir dela a linha 1 da matriz do §2.1, o texto do `Protocolo` e a expectation de store do caso de desenho do `data-relational` (§2.7). Se (b), o orquestrador registra o follow-up no ledger; se (c), o change para aqui (rastreia: REQ-11; paths: `.forge/specs/active/data-engineer-agent/{approvals.yaml,design.md}`; depende: —)

## Wave 1 — Gate vermelho

- [ ] TASK-02 — Gate `tests/w250-data-engineer-agents-gate.sh` com os cenários [0]–[17] do design §2.6, escrito como funções `confere_* <root>`, e fixtures `tests/fixtures/w250/<esp>/{sujo,limpo}/` com uma linha suja por regra estática da tabela do §2.5 e os sósias na limpa, sem nenhum literal de credencial; JSON sintético de `PreToolUse` para o [16] gerado pelo próprio gate; rodar e registrar o vermelho (esperado: [0] reprova por universo vazio nomeando `agents/data`); `git show --stat HEAD` só com arquivos sob `tests/`; `check-secrets.sh path tests/fixtures/w250` verde; `gate-ordinal.sh check` verde (rastreia: REQ-08, REQ-05, REQ-10; paths: `tests/w250-data-engineer-agents-gate.sh`, `tests/fixtures/w250/**`; depende: TASK-01)

## Wave 2 — Skills de referência e scanners

- [ ] TASK-03 — Skill `data-relational-practices`: `SKILL.md`, `references/best-practices.md` (base §1 e §7.3 relacional, subordinada a `money-as-cents.md` e ao RLS obrigatório da `data-governance.md`, design §2.9), `references/antipatterns.md` (R-01..R-18), `scripts/scan.sh` (R-03, R-04, R-06, R-10, R-12, R-13, R-14, R-17, R-18) com o contrato de motor do §2.5; verdes os cenários [4]–[8] e a parte de [17] desta skill (rastreia: REQ-03, REQ-05, REQ-06, REQ-11; paths: `template/.forge/skills/data-relational-practices/**`; depende: TASK-02)
- [ ] TASK-04 — Skill `data-nosql-practices`: documento, chave-valor persistente, coluna larga e grafo (base §2), com a linha do H-01 conforme a decisão da TASK-01; catálogo N-01..N-19, `scan.sh` (N-01, N-04, N-06, N-07, N-08, N-09, N-10, N-11, N-13, N-15, N-17, N-18, N-19) (rastreia: REQ-03, REQ-05, REQ-06; paths: `template/.forge/skills/data-nosql-practices/**`; depende: TASK-02)
- [ ] TASK-05 — Skill `data-cache-practices`: base §3 e T-01/T-04 da §7.1, catálogo C-01..C-16, `scan.sh` (C-02, C-08, C-09, C-10, C-11, C-15, C-16); referência cruzada a `rules/data/data-cache.md` sem duplicá-la e sem nunca recomendar Redis como fonte de verdade; C-15 como `aviso` complementar ao `check-data-governance.sh` (rastreia: REQ-03, REQ-05, REQ-06; paths: `template/.forge/skills/data-cache-practices/**`; depende: TASK-02)
- [ ] TASK-06 — Skill `data-object-storage-practices`: base §4, T-03, LGPD §7.2 (WORM × eliminação), catálogo O-01..O-14, `scan.sh` (O-01, O-02, O-08, O-11, O-13, O-14) (rastreia: REQ-03, REQ-05, REQ-06; paths: `template/.forge/skills/data-object-storage-practices/**`; depende: TASK-02)
- [ ] TASK-07 — Skill `data-analytical-practices`: base §5, catálogo A-01..A-14, `scan.sh` (A-06, A-08, A-10, A-12, A-14); regra de particionamento de tabela × arquivo bruto (design §2.1 regra 4) (rastreia: REQ-03, REQ-05; paths: `template/.forge/skills/data-analytical-practices/**`; depende: TASK-02)
- [ ] TASK-08 — Skill `data-streaming-practices`: seção `## RabbitMQ` com as treze subseções do REQ-04, RMQ-BP-01..17, receita de referência; `## Kafka` (KFK-BP-01..09); `## Padrões de integração` com AsyncAPI; `## Escolha de transporte` (base §6.7, com coluna de contrato); catálogo RMQ-AP-01..20, KFK-AP-01..09, D-AP-01..04, INB-AP-*, OBX-AP-*, CDC-AP-*, SCH-AP-*, T-02; `scan.sh` com as regras estáticas da tabela do design §2.5; verdes [9] e [10] na parte da skill; revalidar w209 (rastreia: REQ-03, REQ-04, REQ-05, REQ-06; paths: `template/.forge/skills/data-streaming-practices/**`; depende: TASK-02)

## Wave 3 — Hook e agentes

- [ ] TASK-09 — Script `template/.forge/scripts/data-agent-allowlist.sh` (design §2.2, REQ-10): lê o JSON de `PreToolUse` na entrada padrão, aceita só os seis especialistas em `tool_input.subagent_type`, nega com exit 2 e motivo, fail-closed; verde [16] (rastreia: REQ-10; paths: `template/.forge/scripts/data-agent-allowlist.sh`; depende: TASK-02)
- [ ] TASK-10 — Seis especialistas `template/.forge/agents/data/<esp>.md` no molde do design §2.3 (frontmatter com `skills`, `model: sonnet`, `mcp__context7__query-docs`, sem `Write`/`Edit`/`Agent`; sete seções na ordem; `Protocolo` com rules, `check-data-governance`, `scan.sh` e bloco `CONFLITO`; frase canônica do §2.4); verdes [1], [3], [10] e [17] na parte dos especialistas (rastreia: REQ-02, REQ-06, REQ-11; paths: `template/.forge/agents/data/data-{relational,nosql,cache,object-storage,analytical,streaming}.md`; depende: TASK-03, TASK-04, TASK-05, TASK-06, TASK-07, TASK-08)
- [ ] TASK-11 — Orquestrador `template/.forge/agents/data/data-engineer.md` (design §2.1 e §2.2: matriz com a linha 1 fixada pela TASK-01, oito regras de desempate, protocolo com bloco `CONFLITO`, checklist transversal PCI/LGPD/multi-tenant/custo/reversibilidade/operação, modo degradado com `PLANO DE ROTEAMENTO`, fora da cobertura, frase canônica, `hooks.PreToolUse` chamando o script da TASK-09); verdes [0], [2] e o w250 até o [14] (rastreia: REQ-01, REQ-06, REQ-10, REQ-11; paths: `template/.forge/agents/data/data-engineer.md`; depende: TASK-09, TASK-10)

## Wave 4 — Integração com o harness

- [ ] TASK-12 — `capability-dispatcher/SKILL.md`: passo novo e tabela área → skill, `description` byte-idêntica à do tronco; revalidar w102 (rastreia: REQ-07; paths: `template/.forge/skills/capability-dispatcher/SKILL.md`; depende: TASK-11)
- [ ] TASK-13 — Revisores `code-review/{node,java,python,dotnet}-reviewer.md` (linha nova no item de persistência apontando `scan.sh` das `data-*-practices` e o `data-engineer`) e `PROFILE.md` de `backend-{java,python,dotnet}-relational` e `backend-node-postgres` (ponteiro para `data-relational-practices`); revalidar os gates que exercitam esses arquivos (`claude-contract.bats` C2/C4 para os revisores) (rastreia: REQ-07; paths: `template/.forge/agents/code-review/{node,java,python,dotnet}-reviewer.md`, `template/.forge/capabilities/backend-{java,python,dotnet}-relational/PROFILE.md`, `template/.forge/capabilities/backend-node-postgres/PROFILE.md`; depende: TASK-11)
- [ ] TASK-14 — `agents/README.md`: seção `### Dados (data/)` com os sete agentes, links relativos e a nota de projeção fora do Claude Code; verde [12] (rastreia: REQ-07; paths: `template/.forge/agents/README.md`; depende: TASK-12, TASK-13)
- [ ] TASK-15 — `README.md` (contagens de `agents/`, `skills/` e `scripts/` recalculadas pelo critério do w200 no momento da task; menção ao especialista de dados) e `CHANGELOG.md` `[Unreleased]`; revalidar w200 (rastreia: REQ-07; paths: `README.md`, `CHANGELOG.md`; depende: TASK-14)

## Wave 5 — Casos de eval

- [ ] TASK-16 — Sete `evals.json` em `.forge/evals/agents/<nome>/` no formato do skill-creator (design §2.7): três casos por especialista, doze para o orquestrador (seis de domínio único, seis `critico-*`), assertion `regra-de-integracao-respeitada` em todo caso; antes de escrever, reler o formato vigente na worktree `evals-100` e, se ela tiver publicado schema, usá-lo; verde [15] e w250 inteiro verde (rastreia: REQ-09, REQ-01, REQ-06; paths: `.forge/evals/agents/data-*/**`; depende: TASK-11)

## Wave 6 — Verificação

- [ ] TASK-17 — Prova de mutação do [14] registrada (controle, cinco mutações reprovando com o alvo nomeado, recontrole com `cmp -s`); revalidação dos gates que exercitam arquivos tocados: w200, w209, w102, w14, `npx-pack-gate`, `plugin-sync-gate`, `tests/snapshot/claude-contract.bats`, gw3 (o `check-data-governance.sh` passa a ser chamado pelos agentes), gate do `doctor` que cobre o check de vazamento `.claude/`; `check-secrets.sh path tests/fixtures/w250`; `gate-ordinal.sh check`; medição NFR-02 (`time` de cada `scan.sh` sobre a árvore, já com `--hidden --no-ignore`); regeneração de `.forge/graph/graph.json` com `graph.sh build`; resultados em `verification.md` (rastreia: REQ-07, REQ-08, NFR-01, NFR-02, NFR-03, NFR-04; paths: `.forge/specs/active/data-engineer-agent/verification.md`, `.forge/graph/graph.json`; depende: TASK-15, TASK-16)
- [ ] TASK-18 — Execução A/B pelo mecanismo do design §2.7: instalação por braço no scratchpad com contador de controle, controle positivo do trace (`subagent_type` e negação do hook), três repetições por caso e por braço, `grading.json` por repetição com grader independente de modelo explícito, `eval-aggregate.sh` por especialista, extrator de roteamento gerando `routing.json`; critério: `delta.pass_rate` positivo e acima do maior desvio-padrão em cada especialista, roteamento com os seis críticos verdes e ao menos cinco dos seis de domínio único, zero violação de `regra-de-integracao-respeitada`; especialista reprovado volta para a TASK da skill correspondente (rastreia: REQ-09, REQ-06, REQ-01, REQ-10, REQ-11; paths: `.forge/evals/agents/data-*/workspace/**`, `.forge/specs/active/data-engineer-agent/verification.md`; depende: TASK-17)

## Gate que fica e revalidação

Gate que fica: `tests/w250-data-engineer-agents-gate.sh`, estrutural e executável (roda os scanners sobre fixtures, exercita o script do hook com JSON sintético e instala o harness num temporário). Revalidar: w200 (contagem do README), w209 (varredura recursiva com `-a` e bytes de controle nos arquivos novos), w102 (projeção dinâmica de skills), w14 e `npx-pack-gate` (projeção do adapter), `plugin-sync-gate` (plugin intocado), `tests/snapshot/claude-contract.bats` C2/C4 (frontmatter YAML dos agentes novos e dos revisores tocados), gw3, gate do `doctor` (vazamento `.claude/`), `check-secrets.sh` sobre as fixtures. Propriedade PBT: não se aplica (conteúdo e contrato de saída; o determinismo do scanner é provado por `cmp -s` de duas execuções e dos dois motores). Mutação: as cinco do design §2.6 [14], sempre sobre cópia.

## Execução sugerida (orquestrador)

A TASK-01 é HITL e não se delega. Waves 2 e 3 são paralelizáveis por skill e por agente: um subagente `sonnet` por skill (conteúdo técnico denso, redação a partir da base, regex conferida contra fixture suja e sósias da limpa) e um para os seis especialistas; `sonnet` para o gate, o script do hook e a verificação; `opus` para a revisão crítica final (`code-evaluator`). Cada subagente recebe só a seção da base do seu domínio e a §2.9 do design, autoverifica rodando o w250 e, na TASK-08, também o w209, e não roda a suíte completa.

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 §2.1, §2.2, §2.7 | TASK-11, TASK-16, TASK-18 |
| REQ-02 §2.3 | TASK-10 |
| REQ-03 §2.5, §2.9 | TASK-03, TASK-04, TASK-05, TASK-06, TASK-07, TASK-08 |
| REQ-04 §2.5 | TASK-08 |
| REQ-05 §2.5 | TASK-02, TASK-03, TASK-04, TASK-05, TASK-06, TASK-07, TASK-08 |
| REQ-06 §2.2, §2.4, §2.5 | TASK-03, TASK-04, TASK-05, TASK-06, TASK-08, TASK-10, TASK-11, TASK-16, TASK-18 |
| REQ-07 §2.8, §4, §5 | TASK-12, TASK-13, TASK-14, TASK-15, TASK-17 |
| REQ-08 §2.6 | TASK-02, TASK-17 |
| REQ-09 §2.7 | TASK-16, TASK-18 |
| REQ-10 §2.2, D-11 | TASK-02, TASK-09, TASK-11, TASK-18 |
| REQ-11 §2.3, §2.9 | TASK-01, TASK-03, TASK-10, TASK-11, TASK-18 |
| NFR-01..04 | TASK-17 |
