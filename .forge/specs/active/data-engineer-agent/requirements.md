# Requirements — data-engineer-agent

> Requisitos do change `data-engineer-agent`. Cada requisito é verificável e rastreável à proposal. Onde o critério é estrutural, o verificador é o gate `tests/w250-data-engineer-agents-gate.sh` (REQ-08) e o cenário é citado entre colchetes; onde é comportamental, o verificador é o eval A/B (REQ-09), cujo resultado é evidência de verificação, não teste de suíte.
> Convenção de nomes: `<esp>` ∈ {`data-relational`, `data-nosql`, `data-cache`, `data-object-storage`, `data-analytical`, `data-streaming`}; a skill de `<esp>` é `<esp>-practices` (ex.: `data-cache-practices`).
> Revisão de 2026-09-26: os itens do validador foram remedidos contra a árvore e a documentação; o que foi aceito, parcialmente aceito ou rejeitado, com o motivo, está no design §3.1.

## REQ-01 — Orquestrador `data-engineer` classifica e roteia

- **Quando** um pedido envolve persistência, cache, armazenamento de objetos, analítico ou mensageria, **o sistema deve** oferecer o agente `template/.forge/agents/data/data-engineer.md`, que classifica o pedido pela taxonomia do design §2.1 (padrão de acesso dominante, depois forma do dado, depois produto), aplica as regras de desempate, delega a um ou mais especialistas e sintetiza a resposta.
- **Critérios de aceite:**
  - [ ] Frontmatter com `name: data-engineer`, `description` (≤ 1024 caracteres, sem tag XML), `model` explícito, `tools` contendo `Agent(...)` cuja lista é **exatamente** o conjunto dos seis especialistas, e o bloco `hooks` do REQ-10 [2][16]. A lista entre parênteses só restringe quando o agente roda como thread principal (`claude --agent data-engineer`); como subagente, o caminho principal, a restrição efetiva é a do REQ-10.
  - [ ] O corpo traz a matriz sinal → especialista e as oito regras de desempate do design §2.1, citando cada um dos seis especialistas pelo nome e nenhum nome sem arquivo correspondente em `agents/data/` [2].
  - [ ] Pedido que cruza domínios (ex.: outbox + invalidação de cache) é decomposto em perguntas por especialista e a síntese atribui cada recomendação ao especialista de origem; verificado por dois casos críticos do eval de roteamento, que precisam passar ambos.
  - [ ] Pedido de busca textual ou vetorial fora do que `jsonb`/full-text/`pgvector` resolvem é respondido como fora da cobertura, sem improviso; verificado por caso crítico do eval de roteamento.
  - [ ] Sem a ferramenta `Agent` disponível (no limite de profundidade o Claude Code retira a ferramenta do subagente e ele "faz o trabalho delegado ele mesmo"; ou ferramenta de IA sem subagentes), o agente devolve o bloco `PLANO DE ROTEAMENTO` do design §2.2 em vez de responder no lugar do especialista. Como esse comportamento depende só do prompt, ele é verificado por dois casos críticos executados com `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`, cujo trace não pode conter nenhuma criação de subagente abaixo do orquestrador.
  - [ ] Eval de roteamento (REQ-09): cada caso é julgado pela maioria de três repetições; os seis casos críticos (dois multi-domínio, fora da cobertura, conflito com rule e dois de modo degradado) passam todos, e os seis casos de domínio único passam ao menos cinco. O acerto de roteamento é medido pelos tipos de subagente realmente criados, extraídos do trace, nunca pelo texto da resposta.
- **Rastreia:** proposal §2.1
- **Notas:** conferido em 2026-09-26 em `code.claude.com/docs/en/sub-agents`: "The `Agent(agent_type)` allowlist syntax applies only to an agent running as the main thread with `claude --agent`. In a subagent definition, listing `Agent` in `tools` lets that subagent spawn subagents ... but any type list inside the parentheses is ignored"; aninhamento padrão de três níveis abaixo da conversa principal; hooks de frontmatter valem nos dois modos.

## REQ-02 — Seis especialistas com contexto próprio

- **Quando** o orquestrador (ou o usuário, diretamente) aciona um especialista, **o sistema deve** oferecer `template/.forge/agents/data/<esp>.md` para cada um dos seis, com a skill correspondente pré-carregada e protocolo fixo.
- **Critérios de aceite:**
  - [ ] Frontmatter de cada especialista: `name: <esp>`, `description` válida, `model` explícito, `skills: [<esp>-practices]` apontando para skill existente, `tools` sem `Write`, `Edit` nem `Agent` (especialista é consultivo e não aninha; a lista de `tools` é respeitada também no modo subagente, ao contrário da lista entre parênteses de `Agent(...)`) e, para documentação de versão corrente, `mcp__context7__resolve-library-id` e `mcp__context7__query-docs` (nomes expostos pelo servidor context7 em 2026-09-26) [1][3].
  - [ ] Corpo com as seções, nesta ordem: `Missão`, `Escopo`, `Protocolo`, `Checklist`, `Antipatterns bloqueados`, `Regra de integração`, `Quando devolver ao orquestrador` [3].
  - [ ] O `Protocolo` manda, antes de recomendar: ler `.forge/rules/data/*`, `.forge/rules/domain/*` aplicáveis, ADRs e baseline do projeto; rodar `bash .forge/scripts/check-data-governance.sh --path <paths afetados>` e tratar `data-classification.json`, quando existir, como autoridade sobre quais campos são PAN/PII; rodar o `scan.sh` da skill. Em conflito relevante entre rule/ADR do projeto e a skill, segue `rules/conventions/conflict-handling.md`: para e devolve o bloco `CONFLITO` do design §2.3 (as duas posições, a fonte de cada uma, qual vence pela precedência e as opções), sem "registrar e seguir". O gate confere a presença de cada um desses elementos no texto do `Protocolo` [3].
  - [ ] Todo antipattern apontado na resposta cita o id do catálogo (ex.: `RMQ-AP-10`) e, quando há detector, `arquivo:linha` vindo do `scan.sh`.
- **Rastreia:** proposal §2.2

## REQ-03 — Seis skills de referência no padrão `node-quality-scan`

- **Quando** um especialista é carregado, **o sistema deve** disponibilizar `template/.forge/skills/<esp>-practices/` com `SKILL.md`, `references/best-practices.md`, `references/antipatterns.md` e, havendo ao menos um detector estático, `scripts/scan.sh`.
- **Critérios de aceite:**
  - [ ] `SKILL.md` com frontmatter válido (`name` ≤ 64, `description` ≤ 1024 com gatilhos e contra-gatilhos) e corpo de no máximo 120 linhas: protocolo em ordem fixa (escopo → rules do projeto → detecção → julgamento → relatório), "o que o scanner não faz" e ponteiros para as referências [1][4].
  - [ ] `antipatterns.md`: cada entrada em `### <ID> — <nome>` com os quatro campos rotulados `Sintoma`, `Por quê`, `Correção`, `Detecção`, mais `Evidência` com a marca da base ([J], [2F], [1F], [Interp.] ou [Heurística]) [4].
  - [ ] `Detecção` usa exatamente um de quatro rótulos: `scan.sh <ID>` (estática, executada pelo scanner), `ferramenta` (linter ou analisador externo que o projeto roda, como squawk, SQLFluff, dbt-project-evaluator ou Checkov), `runtime` (comando documentado, nunca executado pelo scanner) e `revisão` (sem detector confiável); pode acrescentar um segundo rótulo complementar depois de `;` [4].
  - [ ] Conteúdo restrito ao que a base consolidada sustenta (§0–§7) e subordinado às rules do template: onde a base e uma rule divergem, a skill segue a rule e diz isso (ex.: dinheiro em `BIGINT` na menor unidade pela `rules/domain/money-as-cents.md`, não `numeric`; RLS obrigatório em tabela multi-tenant de domínio pela `rules/data/data-governance.md`; Redis nunca fonte de verdade). Nenhum item da seção "Refutado" (base §8.1) aparece como recomendação, e os itens "Incerto" (base §8.2) só aparecem marcados como tais [11].
  - [ ] Todo exemplo de varredura recursiva extratora nas referências usa `rg` ou `grep` com `-a`, para não reprovar o bloco B do w209.
  - [ ] Cobertura mínima por especialista, conforme a issue: relacional (modelagem e normalização, chaves e índices, migrações reversíveis, transações e isolamento, N+1, locks); NoSQL (documento, chave-valor, coluna larga e grafo, modelagem por padrão de acesso, chave de partição, consistência); cache (cache-aside, write-through, TTL, invalidação, stampede, chave quente, cache como fonte da verdade); object storage (layout de chaves, ciclo de vida, versionamento, criptografia, URL pré-assinada, bucket público); analítico (modelagem dimensional, warehouse e lakehouse, particionamento, formatos colunares, SCD); streaming (Kafka, RabbitMQ, CDC, outbox, schema registry, AsyncAPI) — cada tópico com ao menos uma seção nomeada em `best-practices.md` [4].
- **Rastreia:** proposal §2.3

## REQ-04 — Especialização RabbitMQ obrigatória e profunda

- **Quando** o pedido envolve RabbitMQ, **o sistema deve** responder a partir da seção `## RabbitMQ` de `data-streaming-practices/references/best-practices.md`, alinhada à plataforma 4.x.
- **Critérios de aceite:**
  - [ ] Subseções presentes: `Plataforma 4.x`, `Exchanges e roteamento`, `Filas quorum`, `DLX e poison message`, `Ack e prefetch`, `Publisher confirms`, `Retry`, `Idempotência e inbox`, `Ordem`, `Streams`, `Operação e segurança`, `Receita de referência`, `Migrações` [9].
  - [ ] Ids `RMQ-BP-01` a `RMQ-BP-17` em `best-practices.md` e `RMQ-AP-01` a `RMQ-AP-20` em `antipatterns.md` (o `RMQ-AP-20`, usuário `guest` exposto fora do loopback, entra por esta revisão), sem lacuna na numeração [9].
  - [ ] Fatos de plataforma com marca [J] da base: filas espelhadas removidas no 4.0; Mnesia removido no 4.3; plugin de delayed exchange depreciado e arquivado; retry atrasado nativo em quorum (`delayed-retry-*`) no 4.3; `lazy` sem efeito desde 3.12; `delivery-limit` 20 por padrão; `nack` não conta para o `delivery-limit`; requisitos de dead-letter at-least-once.
  - [ ] Nenhuma recomendação de `ha-mode`, `x-queue-mode: lazy` ou `x-delayed-message` fora de `antipatterns.md` [11].
- **Rastreia:** proposal §2.2; issue #177 ("especialização obrigatória")

## REQ-05 — `scan.sh` determinístico e auditável

- **Quando** o especialista roda `bash .forge/skills/<esp>-practices/scripts/scan.sh --root <dir>`, **o sistema deve** varrer texto estático e emitir uma linha por regra, inclusive as que não acharam nada.
- **Critérios de aceite:**
  - [ ] Linha por regra no formato `OK <ID> [<sev>] nenhuma ocorrência` ou `FOUND <ID> [<sev>] <n> ocorrência(s)` seguida de `  <arquivo>:<linha>: <trecho>` (até `--max`), com `<sev>` ∈ {`alto`, `aviso`} e a severidade atribuída pela regra do design §2.5 (todo detector com marca [Heurística] ou [Interp.] é `aviso`) [5][6].
  - [ ] Bijeção: o conjunto de ids emitidos pelo scanner é igual ao conjunto de ids cuja `Detecção` em `antipatterns.md` diz `scan.sh <ID>` [5].
  - [ ] Fixture suja em `tests/fixtures/w250/<esp>/sujo/` faz cada regra estática achar ao menos uma ocorrência com `arquivo:linha`; fixture limpa faz todas emitirem `OK`, e carrega os sósias que um padrão frouxo casaria (`flow: 1`, `acks=10`, `span`, `company`, `expand`) [6].
  - [ ] Universo de arquivos igual nos dois motores e independente do `.gitignore` do consumidor: `rg` com `--hidden --no-ignore --text` e `grep -arnE`; resultados ordenados por `LC_ALL=C sort` antes da emissão; sem `\b` nos padrões (fronteira escrita com classe explícita, como `([^0-9]|$)`). Com arquivo oculto (`.github/`, `.env.exemplo`), arquivo listado num `.gitignore` e arquivo com byte de controle na árvore, a saída com e sem `rg` no `PATH` é byte-idêntica [7].
  - [ ] Contador de controle: a última linha é `ARQUIVOS-VARRIDOS <n>`; com `n = 0` o scanner sai com código 3 e a linha `NADA-EXAMINADO`, nunca com `OK` [8].
  - [ ] Códigos de saída: 0 sem achado `alto` (avisos não reprovam), 1 com achado `alto`, 2 erro de uso, 3 nada examinado [6][8].
  - [ ] `--json <arquivo>` grava o mesmo conteúdo em JSON válido; duas execuções sobre a mesma árvore produzem saída byte-idêntica.
  - [ ] Sem rede, sem credencial, sem dependência além de bash, coreutils, `grep` e opcionalmente `rg`.
- **Rastreia:** proposal §2.3

## REQ-06 — Regra de integração do dono e dados sensíveis em todos os agentes

- **Quando** qualquer um dos sete agentes recomenda integração, entrega de dado ou acesso, **o sistema deve** respeitar a regra: comunicação síncrona interna entre serviços é gRPC por padrão, com `.proto` versionado; evento assíncrono interno vai por mensageria, com contrato AsyncAPI; externa é REST (síncrona) ou fila/mensageria (assíncrona); gRPC nunca é exposto a terceiro; nenhum terceiro recebe acesso direto a banco, cache, tópico, fila, vhost ou bucket internos; toda exceção à rule `architecture/internal-grpc-communication.md` exige ADR.
- **Critérios de aceite:**
  - [ ] A seção `Regra de integração` dos sete agentes contém a frase canônica do design §2.4 [10].
  - [ ] `data-streaming-practices/references/best-practices.md` contém a tabela de escolha de transporte interno × externo (base §6.7, com a coluna de contrato: `.proto` para gRPC, AsyncAPI mais schema registrado para evento, OpenAPI para REST) e os antipatterns `D-AP-01` a `D-AP-03` estão no catálogo [10].
  - [ ] O checklist transversal do orquestrador inclui PCI DSS (PAN/SAD em cache, fila, DLQ, tópico, bucket, log; `check-data-governance` e `data-classification.json`), LGPD (conflito com imutabilidade, crypto-shredding, pseudonimização), multi-tenant (RLS obrigatório em PostgreSQL pela rule), custo e reversibilidade, com as marcas [Interp.] preservadas onde a base as usa; o gate confere cada um desses itens no texto [10].
  - [ ] Detectores estáticos de exposição direta de store, além de C-11, O-01 e D-AP-01: `publicly_accessible = true` em banco gerenciado, security group aberto a `0.0.0.0/0` nas portas de dados, `bindIp: 0.0.0.0` no MongoDB, listener Kafka `PLAINTEXT://0.0.0.0`, usuário `guest` fora do loopback no RabbitMQ e permissão total `".*"` em `definitions.json`/`rabbitmq_permissions` (design §2.5) [5][6].
  - [ ] Nos evals (REQ-09), todo caso de todos os sete agentes tem a assertion `regra-de-integracao-respeitada`; nenhuma resposta da variante recomenda expor gRPC a terceiro ou dar a terceiro acesso direto a store interno; uma única violação reprova o critério de aceite da issue.
- **Rastreia:** proposal §2.1, §2.2; issue #177 (critério de aceite 3)

## REQ-07 — Integração com o harness existente

- **Quando** o change é instalado ou atualizado num consumidor, **o sistema deve** tornar os sete agentes e as seis skills descobríveis pelos mecanismos existentes e alcançáveis pelo pipeline de revisão, sem alterar código de maquinaria de projeção.
- **Critérios de aceite:**
  - [ ] `skills/capability-dispatcher/SKILL.md` cita o `data-engineer` e as seis skills com a área que aciona cada uma, sem mudar a `description` da skill (motivo no design §3.1, item 10) [12].
  - [ ] Os quatro revisores `agents/code-review/{node,java,python,dotnet}-reviewer.md` indicam, quando o diff toca persistência, migração, cache, bucket ou mensageria, rodar o `scan.sh` da skill `data-*-practices` do domínio e encaminhar decisão de desenho ao `data-engineer` [12].
  - [ ] Os `PROFILE.md` dos packs `backend-java-relational`, `backend-python-relational`, `backend-dotnet-relational` e `backend-node-postgres` apontam para `data-relational-practices` [12].
  - [ ] `agents/README.md` tem a seção `### Dados (data/)` com os sete agentes e link relativo para cada arquivo, e diz que fora do Claude Code as skills só chegam com o adapter `agents-skills` ou `forge-cli` [12].
  - [ ] Instalação real em diretório temporário (`installer/install.sh --adapters claude,agents-skills`) projeta os sete agentes em `.claude/agents/data/`, as seis skills em `.claude/skills/` e `.agents/skills/`, com `scan.sh`, e o script de hook do REQ-10 em `.forge/scripts/` [13].
  - [ ] Nenhum arquivo novo sob `template/.forge/agents` ou `template/.forge/skills` contém `.claude/` (check de vazamento do `doctor`) [12].
  - [ ] `README.md` com as contagens de `agents/`, `skills/` e `scripts/` batendo com a árvore (w200 verde) e `CHANGELOG.md` com a entrada em `[Unreleased]`.
  - [ ] `.forge/graph/graph.json` regenerado por `graph.sh build` depois do último arquivo novo, para não deixar o grafo defasado (o w246 planejado, LDG-0176, reprova grafo defasado).
  - [ ] `plugin/forge/**` byte-idêntico ao gerado (`plugin-sync-gate` verde) — nenhum comando novo.
- **Rastreia:** proposal §2.4

## REQ-08 — Gate estrutural `w250`, red-first, com prova de mutação

- **Quando** a suíte roda, **o sistema deve** executar `tests/w250-data-engineer-agents-gate.sh`, que cobre REQ-01 a REQ-07, REQ-10 e REQ-11 nos cenários [0] a [17] do design §2.6.
- **Critérios de aceite:**
  - [ ] O gate nasce vermelho num commit que só contém o gate e suas fixtures (`git show --stat` do commit sem arquivo fora de `tests/`), e fica verde só depois das tasks de conteúdo.
  - [ ] Contador de controle do universo (sete agentes, seis skills) via `lib/gate-universe.sh`; universo vazio reprova [0].
  - [ ] Mutação sobre cópia, nunca sobre arquivo rastreado: (a) retirar um especialista da lista do `Agent(...)`; (b) apagar o campo `Correção` de um antipattern; (c) apagar uma regra do `scan.sh`; (d) inserir `ha-mode` como recomendação em `best-practices.md`; (e) acrescentar um tipo fora dos seis à lista aceita pelo script de hook. Cada mutação faz o cenário correspondente reprovar nomeando o alvo; controle e recontrole com `cmp -s` provam a restauração byte a byte [14].
  - [ ] As fixtures não contêm literal de credencial (senha, usuário:senha em URL, token): `check-secrets.sh path tests/fixtures/w250` sai verde.
  - [ ] Funciona com bash 3.2 do macOS e no Linux do CI; sem `${$var}`; toda varredura recursiva extratora com `-a`.
- **Rastreia:** proposal §2.5

## REQ-09 — Eval A/B pelo protocolo do skill-creator

- **Quando** a implementação termina, **o sistema deve** ter casos de eval em `.forge/evals/agents/<nome>/evals.json` (dogfood) para os seis especialistas e para o orquestrador, no mesmo formato que a frente paralela de evals de skills e agentes usa nesse diretório, e o orquestrador de implementação executa o A/B e registra o resultado.
- **Critérios de aceite:**
  - [ ] Sete arquivos no formato do skill-creator adotado pela frente `evals-100`: `skill_name` (nome do agente), `artifact_kind: "agent"`, `artifact_path`, `evals[]` com `id` inteiro único, `eval_name` kebab-case único, `prompt`, `expected_output`, `files` e `assertions[]` de objetos `{name, text}`; três casos por especialista e doze para o orquestrador (seis de domínio único e seis críticos, REQ-01); ao menos duas assertions por caso, uma delas `regra-de-integracao-respeitada` [15].
  - [ ] Os três casos de cada especialista seguem o molde do design §2.7: desenho, revisão com antipattern plantado, e fronteira (regra de integração, dado sensível, fato refutado ou conflito com rule).
  - [ ] Execução A/B pelo mecanismo do design §2.7: instalação real num temporário para cada braço, variante com o especialista acionado como subagente e a skill pré-carregada, baseline no mesmo modelo sem os agentes e skills de dados; três repetições por caso e por braço; `grading.json` por repetição no formato que `eval-aggregate.sh` lê, `aggregate.json` gerado por ele, e `routing.json` gerado pela extração de trace do orquestrador.
  - [ ] Especialista aprovado quando `delta.pass_rate` é positivo e maior que o maior dos dois desvios-padrão (`baseline.pass_rate_stddev`, `variant.pass_rate_stddev`) do `aggregate.json`; especialista que não cumpre volta para revisão da skill, não é aprovado por julgamento no olho.
- **Rastreia:** proposal §2.6; issue #177 (critério de aceite 2)
- **Notas:** a execução é da etapa de verificação, feita pelo orquestrador depois do `/forge:implement`; o gate w250 só valida a presença e a forma dos casos, e por isso o spec-delta não atribui a ele o resultado do A/B.

## REQ-10 — Restrição efetiva de quem o orquestrador pode acionar

- **Quando** o `data-engineer` roda como subagente (pela descrição ou por `@data-engineer`) ou como thread principal (`claude --agent data-engineer`), **o sistema deve** impedir que ele crie subagente de tipo diferente dos seis especialistas, preservando a premissa "uma árvore, um escritor" (nenhum especialista tem `Write` ou `Edit`).
- **Critérios de aceite:**
  - [ ] O frontmatter do orquestrador declara `hooks.PreToolUse` com `matcher: "Agent|Task"` chamando `bash "$CLAUDE_PROJECT_DIR/.forge/scripts/data-agent-allowlist.sh"` [2].
  - [ ] O script lê o JSON do hook na entrada padrão, aceita (exit 0) só `tool_input.subagent_type` ∈ seis especialistas e nega (exit 2, motivo na saída de erro nomeando o tipo) qualquer outro; é fail-closed: JSON malformado, campo ausente ou falta de `node` também saem com 2 [16].
  - [ ] O nome do campo `subagent_type` é confirmado por controle positivo com um trace real antes do A/B (design §2.7); se divergir, o script e o [16] são corrigidos antes de qualquer execução do eval de roteamento.
  - [ ] No eval de roteamento, nenhum trace contém subagente de tipo fora dos seis abaixo do orquestrador.
- **Rastreia:** proposal §2.1; validador item 1

## REQ-11 — Conflito com rule do projeto para e sinaliza

- **Quando** a recomendação da skill diverge de rule ou ADR do projeto em decisão relevante pela `rules/conventions/conflict-handling.md` (isolamento de dados, segurança, contrato, modelo de domínio, estratégia de persistência), **o sistema deve** parar e devolver o bloco `CONFLITO` do design §2.3 a quem chamou, em vez de recomendar e seguir; o orquestrador repassa o bloco ao usuário para decisão HITL.
- **Critérios de aceite:**
  - [ ] Os sete agentes citam `conflict-handling.md` e o formato do bloco `CONFLITO` no `Protocolo` [3][17].
  - [ ] Os conflitos entre este change e as rules do template estão listados no design §2.9, e o que exige decisão humana (H-01, transacional de negócio → MongoDB na `data-governance.md` × transação multi-entidade estrita → relacional na taxonomia) é decidido em HITL e registrado em `approvals.yaml` antes da primeira task de implementação.
  - [ ] Eval: o caso crítico de conflito do orquestrador (Redis como armazenamento primário de sessão durável) produz o bloco `CONFLITO` em todas as repetições; o caso de desenho do `data-relational` aplica `money-as-cents.md` e RLS sem abrir conflito (a rule é obedecida, não há divergência), e sua expectation sobre a escolha do store é fixada pela decisão H-01.
- **Rastreia:** validador item 4; `rules/conventions/conflict-handling.md` §2

## Requisitos não funcionais do change

- **NFR-01 —** `SKILL.md` com no máximo 120 linhas de corpo e `description` com no máximo 1024 caracteres (medição: `validate-frontmatter.sh --strict-xml` e `wc -l`, no w250 [1][4]).
- **NFR-02 —** Cada `scan.sh` termina em menos de 5 s sobre a árvore deste repositório numa máquina de desenvolvimento, já com `--hidden --no-ignore` (medição: `time` na TASK de revalidação, registrado no `verification.md`).
- **NFR-03 —** Determinismo do scanner: duas execuções consecutivas sobre a mesma árvore produzem saída idêntica, com e sem `rg` (medição: `cmp -s` no w250 [6][7]).
- **NFR-04 —** Zero dependência nova de runtime ou de `package.json` (medição: `git diff --stat package.json package-lock.json` vazio).

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície | Coberto por task |
|---|---|---|---|
| REQ-01 | sem parâmetro exposto (roteamento por descrição) | agente `data-engineer` (invocação por descrição, `@data-engineer` ou `claude --agent data-engineer`) | TASK-11, TASK-18 |
| REQ-02 | sem parâmetro exposto | seis agentes `data-*` | TASK-10 |
| REQ-05 | `--root <dir>`, `--json <arquivo>`, `--max <n>` | CLI `bash .forge/skills/<esp>-practices/scripts/scan.sh` | TASK-03 a TASK-08 |
| REQ-09 | sem parâmetro exposto (casos em JSON) | `.forge/evals/agents/<nome>/evals.json` | TASK-16, TASK-18 |
| REQ-10 | entrada padrão JSON do hook | `bash .forge/scripts/data-agent-allowlist.sh` | TASK-09, TASK-11 |
| REQ-03/04/06/07/08/11 | sem parâmetro configurável | — (conteúdo, fiação e gate) | TASK-01 a TASK-08, TASK-10 a TASK-15, TASK-17 |

## Fora de escopo (reafirmação)

- Comando `/forge:*` novo e mudança no plugin (proposal §3; design D-05).
- Mudança de código em `sync-adapters.mjs`, `plugin-build.mjs` e `bin/forge.mjs`.
- Reescrita de `rules/data/*.md` e `rules/domain/money-as-cents.md` neste change; se o HITL H-01 decidir mudar a rule, a mudança vai em change próprio com ADR (design §2.9).
- Corrigir as flags do `rg` em `node-quality-scan` e `dotnet-quality-scan`, e o nome da ferramenta context7 nos cinco agentes existentes: follow-ups (design §3.1).
- Especialista de busca, vetorial ou séries temporais dedicado.
- Detector que conecta em sistema real; scanner como gate bloqueante do pipeline.
