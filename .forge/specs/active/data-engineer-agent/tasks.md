# Tasks — data-engineer-agent

> Tasks do change `data-engineer-agent`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (1 commit), rastreável a um REQ/seção do design, e declara o que toca. Red-first: a TASK-01 entra vermelha num commit só de teste; cada task seguinte declara quais cenários do w250 ela torna verdes, e o implementador roda só o w250 e os gates listados na task, nunca a suíte completa.

## Wave 1 — Gate vermelho

- [ ] TASK-01 — Gate `tests/w250-data-engineer-agents-gate.sh` com os cenários [0]–[15] do design §2.6, escrito como funções `confere_* <root>`, e fixtures `tests/fixtures/w250/<esp>/{sujo,limpo}/` com uma linha suja por regra estática da tabela do §2.5; rodar e registrar o vermelho (esperado: [0] reprova por universo vazio nomeando `agents/data`); `git show --stat HEAD` só com arquivos sob `tests/`; `gate-ordinal.sh check` verde (rastreia: REQ-08, REQ-05; paths: `tests/w250-data-engineer-agents-gate.sh`, `tests/fixtures/w250/**`; depende: —)

## Wave 2 — Skills de referência e scanners

- [ ] TASK-02 — Skill `data-relational-practices`: `SKILL.md`, `references/best-practices.md` (base §1 e §7.3 relacional), `references/antipatterns.md` (R-01..R-16), `scripts/scan.sh` (R-03, R-04, R-06, R-10, R-12, R-13, R-14); verdes os cenários [4]–[8] para esta skill (rastreia: REQ-03, REQ-05; paths: `template/.forge/skills/data-relational-practices/**`; depende: TASK-01)
- [ ] TASK-03 — Skill `data-nosql-practices`: documento, chave-valor persistente, coluna larga e grafo (base §2), catálogo N-01..N-17, `scan.sh` (N-01, N-04, N-06, N-07, N-08, N-09, N-10, N-11, N-13, N-15, N-17) (rastreia: REQ-03, REQ-05; paths: `template/.forge/skills/data-nosql-practices/**`; depende: TASK-01)
- [ ] TASK-04 — Skill `data-cache-practices`: base §3 e T-01/T-04 da §7.1, catálogo C-01..C-15, `scan.sh` (C-02, C-08, C-09, C-10, C-11, C-15); referência cruzada a `rules/data/data-cache.md` sem duplicá-la (rastreia: REQ-03, REQ-05, REQ-06; paths: `template/.forge/skills/data-cache-practices/**`; depende: TASK-01)
- [ ] TASK-05 — Skill `data-object-storage-practices`: base §4, T-03, LGPD §7.2 (WORM × eliminação), catálogo O-01..O-14, `scan.sh` (O-01, O-02, O-08, O-11, O-13, O-14) (rastreia: REQ-03, REQ-05, REQ-06; paths: `template/.forge/skills/data-object-storage-practices/**`; depende: TASK-01)
- [ ] TASK-06 — Skill `data-analytical-practices`: base §5, catálogo A-01..A-14, `scan.sh` (A-06, A-08, A-10, A-12, A-14); regra de particionamento de tabela × arquivo bruto (design §2.1 regra 4) (rastreia: REQ-03, REQ-05; paths: `template/.forge/skills/data-analytical-practices/**`; depende: TASK-01)
- [ ] TASK-07 — Skill `data-streaming-practices`: seção `## RabbitMQ` com as treze subseções do REQ-04, RMQ-BP-01..17, receita de referência; `## Kafka` (KFK-BP-01..09); `## Padrões de integração`; `## Escolha de transporte` (base §6.7); catálogo RMQ-AP-01..19, KFK-AP-01..08, D-AP-01..03, INB-AP-*, OBX-AP-*, CDC-AP-*, SCH-AP-*, T-02; `scan.sh` com as regras estáticas da tabela do design §2.5; verdes [9] e [10] na parte da skill (rastreia: REQ-03, REQ-04, REQ-05, REQ-06; paths: `template/.forge/skills/data-streaming-practices/**`; depende: TASK-01)

## Wave 3 — Agentes

- [ ] TASK-08 — Seis especialistas `template/.forge/agents/data/<esp>.md` no molde do design §2.3 (frontmatter com `skills`, `model: sonnet`, sem `Write`/`Edit`/`Agent`; sete seções na ordem; frase canônica do §2.4); verdes [1], [3] e [10] na parte dos especialistas (rastreia: REQ-02, REQ-06; paths: `template/.forge/agents/data/data-{relational,nosql,cache,object-storage,analytical,streaming}.md`; depende: TASK-02, TASK-03, TASK-04, TASK-05, TASK-06, TASK-07)
- [ ] TASK-09 — Orquestrador `template/.forge/agents/data/data-engineer.md` (design §2.1 e §2.2: matriz, oito regras de desempate, protocolo, checklist transversal PCI/LGPD/multi-tenant/custo/reversibilidade/operação, modo degradado com `PLANO DE ROTEAMENTO`, fora da cobertura, frase canônica); verdes [0], [2] (rastreia: REQ-01, REQ-06; paths: `template/.forge/agents/data/data-engineer.md`; depende: TASK-08)

## Wave 4 — Integração com o harness

- [ ] TASK-10 — `capability-dispatcher/SKILL.md`: passo novo e tabela área → skill, `description` intacta; revalidar w102 (rastreia: REQ-07; paths: `template/.forge/skills/capability-dispatcher/SKILL.md`; depende: TASK-09)
- [ ] TASK-11 — `agents/README.md`: seção `### Dados (data/)` com os sete agentes e links relativos; verde [12] (rastreia: REQ-07; paths: `template/.forge/agents/README.md`; depende: TASK-09)
- [ ] TASK-12 — `README.md` (contagens de `agents/` e `skills/` recalculadas pelo critério do w200 no momento da task; menção ao especialista de dados) e `CHANGELOG.md` `[Unreleased]`; revalidar w200 (rastreia: REQ-07; paths: `README.md`, `CHANGELOG.md`; depende: TASK-10, TASK-11)

## Wave 5 — Casos de eval

- [ ] TASK-13 — Sete `evals.json` em `.forge/evals/agents/<nome>/` com os casos do design §2.7 (três por especialista, oito de roteamento), válidos no `evals.schema.json`; verde [15] e w250 inteiro verde (rastreia: REQ-09; paths: `.forge/evals/agents/**`; depende: TASK-09)

## Wave 6 — Verificação

- [ ] TASK-14 — Prova de mutação do [14] registrada (controle, mutação reprovando com o alvo nomeado, recontrole com `cmp -s`); revalidação dos gates que exercitam arquivos tocados: w200, w209, w102, w14, `npx-pack-gate`, `plugin-sync-gate`, `tests/snapshot/claude-contract.bats`, gate do `doctor` que cobre o check de vazamento `.claude/`; `gate-ordinal.sh check`; medição NFR-02 (`time` de cada `scan.sh` sobre a árvore); resultados em `verification.md` (rastreia: REQ-08, NFR-01, NFR-02, NFR-03, NFR-04; paths: `.forge/specs/active/data-engineer-agent/verification.md`; depende: TASK-12, TASK-13)
- [ ] TASK-15 — Execução A/B dos sete conjuntos pelo orquestrador (executor → grader → `eval-aggregate.sh`), artefatos em `.forge/evals/agents/<nome>/workspace/iteration-1/`; critério: delta de `pass_rate` positivo em cada especialista e roteamento ≥ 7/8; nenhuma resposta da variante viola a regra de integração; especialista reprovado volta para a TASK da skill correspondente (rastreia: REQ-09, REQ-06, REQ-01; paths: `.forge/evals/agents/**/workspace/**`, `.forge/specs/active/data-engineer-agent/verification.md`; depende: TASK-14)

## Gate que fica e revalidação

Gate que fica: `tests/w250-data-engineer-agents-gate.sh`, estrutural e executável (roda os scanners sobre fixtures e instala o harness num temporário). Revalidar: w200 (contagem do README), w209 (varredura recursiva com `-a` e bytes de controle nos arquivos novos), w102 (projeção dinâmica de skills), w14 e `npx-pack-gate` (projeção do adapter), `plugin-sync-gate` (plugin intocado), `tests/snapshot/claude-contract.bats` C2/C4 (frontmatter YAML), gate do `doctor` (vazamento `.claude/`). Propriedade PBT: não se aplica (conteúdo e contrato de saída; o determinismo do scanner é provado por `cmp -s` de duas execuções). Mutação: as quatro do design §2.6 [14], sempre sobre cópia.

## Execução sugerida (orquestrador)

Waves 2 e 3 são paralelizáveis por skill e por agente: um subagente `sonnet` por skill (conteúdo técnico denso, redação a partir da base, regex conferida contra fixture) e um para os seis especialistas; `sonnet` para o gate e a verificação; `opus` para a revisão crítica final (`code-evaluator`). Cada subagente recebe só a seção da base do seu domínio, autoverifica rodando o w250 e, na TASK-07, também o w209, e não roda a suíte completa.

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 §2.1, §2.2 | TASK-09, TASK-15 |
| REQ-02 §2.3 | TASK-08 |
| REQ-03 §2.5 | TASK-02, TASK-03, TASK-04, TASK-05, TASK-06, TASK-07 |
| REQ-04 §2.5 | TASK-07 |
| REQ-05 §2.5 | TASK-01, TASK-02, TASK-03, TASK-04, TASK-05, TASK-06, TASK-07 |
| REQ-06 §2.2, §2.4 | TASK-04, TASK-05, TASK-07, TASK-08, TASK-09, TASK-15 |
| REQ-07 §2.8, §4, §5 | TASK-10, TASK-11, TASK-12 |
| REQ-08 §2.6 | TASK-01, TASK-14 |
| REQ-09 §2.7 | TASK-13, TASK-15 |
| NFR-01..04 | TASK-14 |
