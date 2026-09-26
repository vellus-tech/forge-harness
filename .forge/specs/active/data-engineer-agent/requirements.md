# Requirements — data-engineer-agent

> Requisitos do change `data-engineer-agent`. Cada requisito é verificável e rastreável à proposal. Onde o critério é estrutural, o verificador é o gate `tests/w250-data-engineer-agents-gate.sh` (REQ-08) e o cenário é citado entre colchetes; onde é comportamental, o verificador é o eval A/B (REQ-09).
> Convenção de nomes: `<esp>` ∈ {`data-relational`, `data-nosql`, `data-cache`, `data-object-storage`, `data-analytical`, `data-streaming`}; a skill de `<esp>` é `<esp>-practices` (ex.: `data-cache-practices`).

## REQ-01 — Orquestrador `data-engineer` classifica e roteia

- **Quando** um pedido envolve persistência, cache, armazenamento de objetos, analítico ou mensageria, **o sistema deve** oferecer o agente `template/.forge/agents/data/data-engineer.md`, que classifica o pedido pela taxonomia do design §2.1 (padrão de acesso dominante, depois forma do dado, depois produto), aplica as regras de desempate, delega a um ou mais especialistas e sintetiza a resposta.
- **Critérios de aceite:**
  - [ ] Frontmatter com `name: data-engineer`, `description` (≤ 1024 caracteres, sem tag XML), `model` explícito e `tools` contendo `Agent(...)` cuja allowlist é **exatamente** o conjunto dos seis especialistas — nem mais, nem menos [2].
  - [ ] O corpo traz a matriz sinal → especialista e as oito regras de desempate do design §2.1, citando cada um dos seis especialistas pelo nome e nenhum nome sem arquivo correspondente em `agents/data/` [2].
  - [ ] Pedido que cruza domínios (ex.: outbox + invalidação de cache) é decomposto em perguntas por especialista e a síntese atribui cada recomendação ao especialista de origem.
  - [ ] Pedido de busca textual ou vetorial fora do que `jsonb`/full-text/`pgvector` resolvem é respondido como fora da cobertura, sem improviso.
  - [ ] Sem a ferramenta `Agent` disponível (profundidade máxima de aninhamento atingida, ou ferramenta de IA sem subagentes), o agente devolve o bloco `PLANO DE ROTEAMENTO` do design §2.2 em vez de responder no lugar do especialista.
  - [ ] Eval de roteamento (REQ-09) com acerto ≥ 7 de 8 casos na variante.
- **Rastreia:** proposal §2.1
- **Notas:** o aninhamento de subagentes (padrão de três níveis abaixo da conversa principal) e a sintaxe `Agent(nome, ...)` foram conferidos na documentação do Claude Code em 2026-09-26 (`code.claude.com/docs/en/sub-agents`).

## REQ-02 — Seis especialistas com contexto próprio

- **Quando** o orquestrador (ou o usuário, diretamente) aciona um especialista, **o sistema deve** oferecer `template/.forge/agents/data/<esp>.md` para cada um dos seis, com a skill correspondente pré-carregada e protocolo fixo.
- **Critérios de aceite:**
  - [ ] Frontmatter de cada especialista: `name: <esp>`, `description` válida, `model` explícito, `skills: [<esp>-practices]` apontando para skill existente, `tools` sem `Write`, `Edit` nem `Agent` (especialista é consultivo e não aninha) [1][3].
  - [ ] Corpo com as seções, nesta ordem: `Missão`, `Escopo`, `Protocolo`, `Checklist`, `Antipatterns bloqueados`, `Regra de integração`, `Quando devolver ao orquestrador` [3].
  - [ ] O `Protocolo` manda ler, antes de recomendar, `.forge/rules/data/*`, ADRs e baseline do projeto, e declara que rule/ADR do projeto vence a skill, com a divergência citada na resposta (regra transversal de conflito de fontes do `agents/README.md`).
  - [ ] Todo antipattern apontado na resposta cita o id do catálogo (ex.: `RMQ-AP-10`) e, quando há detector, `arquivo:linha` vindo do `scan.sh`.
- **Rastreia:** proposal §2.2

## REQ-03 — Seis skills de referência no padrão `node-quality-scan`

- **Quando** um especialista é carregado, **o sistema deve** disponibilizar `template/.forge/skills/<esp>-practices/` com `SKILL.md`, `references/best-practices.md`, `references/antipatterns.md` e, havendo ao menos um detector estático, `scripts/scan.sh`.
- **Critérios de aceite:**
  - [ ] `SKILL.md` com frontmatter válido (`name` ≤ 64, `description` ≤ 1024 com gatilhos e contra-gatilhos) e corpo de no máximo 120 linhas: protocolo em ordem fixa (escopo → rules do projeto → detecção → julgamento → relatório), "o que o scanner não faz" e ponteiros para as referências [1][4].
  - [ ] `antipatterns.md`: cada entrada em `### <ID> — <nome>` com os quatro campos rotulados `Sintoma`, `Por quê`, `Correção`, `Detecção`, mais `Evidência` com a marca da base ([J], [2F], [1F], [Interp.] ou [Heurística]) [4].
  - [ ] `Detecção` distingue `scan.sh <ID>` (estática, executada pelo scanner), `runtime` (comando documentado, nunca executado pelo scanner) e `revisão` (sem detector confiável).
  - [ ] Conteúdo restrito ao que a base consolidada sustenta (§0–§7); nenhum item da seção "Refutado" (base §8.1) aparece como recomendação, e os itens "Incerto" (base §8.2) só aparecem marcados como tais [11].
  - [ ] Todo exemplo de varredura recursiva extratora nas referências usa `rg` ou `grep` com `-a`, para não reprovar o bloco B do w209.
  - [ ] Cobertura mínima por especialista, conforme a issue: relacional (modelagem e normalização, chaves e índices, migrações reversíveis, transações e isolamento, N+1, locks); NoSQL (documento, chave-valor, coluna larga e grafo, modelagem por padrão de acesso, chave de partição, consistência); cache (cache-aside, write-through, TTL, invalidação, stampede, chave quente, cache como fonte da verdade); object storage (layout de chaves, ciclo de vida, versionamento, criptografia, URL pré-assinada, bucket público); analítico (modelagem dimensional, warehouse e lakehouse, particionamento, formatos colunares, SCD); streaming (Kafka, RabbitMQ, CDC, outbox, schema registry) — cada tópico com ao menos uma seção nomeada em `best-practices.md` [4].
- **Rastreia:** proposal §2.3

## REQ-04 — Especialização RabbitMQ obrigatória e profunda

- **Quando** o pedido envolve RabbitMQ, **o sistema deve** responder a partir da seção `## RabbitMQ` de `data-streaming-practices/references/best-practices.md`, alinhada à plataforma 4.x.
- **Critérios de aceite:**
  - [ ] Subseções presentes: `Plataforma 4.x`, `Exchanges e roteamento`, `Filas quorum`, `DLX e poison message`, `Ack e prefetch`, `Publisher confirms`, `Retry`, `Idempotência e inbox`, `Ordem`, `Streams`, `Operação e segurança`, `Receita de referência`, `Migrações` [9].
  - [ ] Ids `RMQ-BP-01` a `RMQ-BP-17` em `best-practices.md` e `RMQ-AP-01` a `RMQ-AP-19` em `antipatterns.md`, sem lacuna na numeração [9].
  - [ ] Fatos de plataforma com marca [J] da base: filas espelhadas removidas no 4.0; Mnesia removido no 4.3; plugin de delayed exchange depreciado e arquivado; retry atrasado nativo em quorum (`delayed-retry-*`) no 4.3; `lazy` sem efeito desde 3.12; `delivery-limit` 20 por padrão; `nack` não conta para o `delivery-limit`; requisitos de dead-letter at-least-once.
  - [ ] Nenhuma recomendação de `ha-mode`, `x-queue-mode: lazy` ou `x-delayed-message` fora de `antipatterns.md` [11].
- **Rastreia:** proposal §2.2; issue #177 ("especialização obrigatória")

## REQ-05 — `scan.sh` determinístico e auditável

- **Quando** o especialista roda `bash .forge/skills/<esp>-practices/scripts/scan.sh --root <dir>`, **o sistema deve** varrer texto estático e emitir uma linha por regra, inclusive as que não acharam nada.
- **Critérios de aceite:**
  - [ ] Linha por regra no formato `OK <ID> [<sev>] nenhuma ocorrência` ou `FOUND <ID> [<sev>] <n> ocorrência(s)` seguida de `  <arquivo>:<linha>: <trecho>` (até `--max`), com `<sev>` ∈ {`alto`, `aviso`} [5][6].
  - [ ] Bijeção: o conjunto de ids emitidos pelo scanner é igual ao conjunto de ids cuja `Detecção` em `antipatterns.md` diz `scan.sh <ID>` [5].
  - [ ] Fixture suja em `tests/fixtures/w250/<esp>/sujo/` faz cada regra estática achar ao menos uma ocorrência com `arquivo:linha`; fixture limpa faz todas emitirem `OK` [6].
  - [ ] Mesmo resultado com e sem `rg` no `PATH` (fallback `grep -a`), sem `\b` nos padrões [7].
  - [ ] Contador de controle: a última linha é `ARQUIVOS-VARRIDOS <n>`; com `n = 0` o scanner sai com código 3 e a linha `NADA-EXAMINADO`, nunca com `OK` [8].
  - [ ] Códigos de saída: 0 sem achado `alto` (avisos não reprovam), 1 com achado `alto`, 2 erro de uso, 3 nada examinado [6][8].
  - [ ] `--json <arquivo>` grava o mesmo conteúdo em JSON válido; duas execuções sobre a mesma árvore produzem saída byte-idêntica.
  - [ ] Sem rede, sem credencial, sem dependência além de bash, coreutils, `grep` e opcionalmente `rg`.
- **Rastreia:** proposal §2.3

## REQ-06 — Regra de integração do dono e dados sensíveis em todos os agentes

- **Quando** qualquer um dos sete agentes recomenda integração, entrega de dado ou acesso, **o sistema deve** respeitar a regra: comunicação interna entre serviços é gRPC por padrão com `.proto` versionado; externa é REST (síncrono) ou fila/mensageria (assíncrono); gRPC nunca é exposto a terceiro; nenhum terceiro recebe acesso direto a banco, cache, tópico interno, vhost interna ou bucket interno.
- **Critérios de aceite:**
  - [ ] A seção `Regra de integração` dos sete agentes contém a frase canônica do design §2.4 [10].
  - [ ] `data-streaming-practices/references/best-practices.md` contém a tabela de escolha de transporte interno × externo (base §6.7) e os antipatterns `D-AP-01` a `D-AP-03` estão no catálogo [10].
  - [ ] O checklist transversal do orquestrador inclui PCI DSS (PAN/SAD em cache, fila, DLQ, tópico, bucket, log), LGPD (conflito com imutabilidade, crypto-shredding, pseudonimização), multi-tenant, custo e reversibilidade, com as marcas [Interp.] preservadas onde a base as usa.
  - [ ] Nos evals (REQ-09), nenhuma resposta da variante recomenda expor gRPC a terceiro ou dar a terceiro acesso direto a store interno; uma única violação reprova o critério de aceite da issue.
- **Rastreia:** proposal §2.1, §2.2; issue #177 (critério de aceite 3)

## REQ-07 — Integração com o harness existente

- **Quando** o change é instalado ou atualizado num consumidor, **o sistema deve** tornar os sete agentes e as seis skills descobríveis pelos mecanismos existentes, sem alterar código de maquinaria.
- **Critérios de aceite:**
  - [ ] `skills/capability-dispatcher/SKILL.md` cita o `data-engineer` e as seis skills com a área que aciona cada uma, sem mudar a `description` da skill [12].
  - [ ] `agents/README.md` tem a seção `### Dados (data/)` com os sete agentes e link relativo para cada arquivo [12].
  - [ ] Instalação real em diretório temporário (`installer/install.sh --adapters claude,agents-skills`) projeta os sete agentes em `.claude/agents/data/` e as seis skills em `.claude/skills/` e `.agents/skills/`, com `scan.sh` presente [13].
  - [ ] Nenhum arquivo novo sob `template/.forge/agents` ou `template/.forge/skills` contém `.claude/` (check de vazamento do `doctor`) [12].
  - [ ] `README.md` com as contagens de `agents/` e `skills/` batendo com a árvore (w200 verde) e `CHANGELOG.md` com a entrada em `[Unreleased]`.
  - [ ] `plugin/forge/**` byte-idêntico ao gerado (`plugin-sync-gate` verde) — nenhum comando novo.
- **Rastreia:** proposal §2.4

## REQ-08 — Gate estrutural `w250`, red-first, com prova de mutação

- **Quando** a suíte roda, **o sistema deve** executar `tests/w250-data-engineer-agents-gate.sh`, que cobre REQ-01 a REQ-07 nos cenários [0] a [15] do design §2.6.
- **Critérios de aceite:**
  - [ ] O gate nasce vermelho num commit que só contém o gate e suas fixtures (`git show --stat` do commit sem arquivo fora de `tests/`), e fica verde só depois das tasks de conteúdo.
  - [ ] Contador de controle do universo (sete agentes, seis skills) via `lib/gate-universe.sh`; universo vazio reprova [0].
  - [ ] Mutação sobre cópia, nunca sobre arquivo rastreado: (a) retirar um especialista da allowlist; (b) apagar o campo `Correção` de um antipattern; (c) apagar uma regra do `scan.sh`; (d) inserir `ha-mode` como recomendação em `best-practices.md`. Cada mutação faz o cenário correspondente reprovar nomeando o alvo; controle e recontrole com `cmp -s` provam a restauração byte a byte [14].
  - [ ] Funciona com bash 3.2 do macOS e no Linux do CI; sem `${$var}`; toda varredura recursiva extratora com `-a`.
- **Rastreia:** proposal §2.5

## REQ-09 — Eval A/B pelo protocolo do skill-creator

- **Quando** a implementação termina, **o sistema deve** ter casos de eval em `.forge/evals/agents/<nome>/evals.json` (dogfood) para os seis especialistas e para o orquestrador, e o orquestrador de implementação executa o A/B e registra o resultado.
- **Critérios de aceite:**
  - [ ] Sete arquivos válidos contra `template/.forge/schemas/evals.schema.json` (campo `skill` carrega o nome do agente); três casos por especialista e oito casos de roteamento para o orquestrador, com ids únicos e ao menos duas expectations por caso [15].
  - [ ] Os três casos de cada especialista seguem o molde do design §2.7: desenho, revisão com antipattern plantado, e fronteira (regra de integração, dado sensível ou fato refutado).
  - [ ] Execução A/B (variante: especialista com skill pré-carregada; baseline: mesmo modelo, agente genérico, mesmo prompt) com `grading.json` por caso e `aggregate.json` gerado por `eval-aggregate.sh`; delta de `pass_rate` positivo em cada um dos seis especialistas.
  - [ ] Especialista com delta ≤ 0 volta para revisão da skill, não é aprovado por julgamento no olho.
- **Rastreia:** proposal §2.6; issue #177 (critério de aceite 2)
- **Notas:** a execução é da etapa de verificação, feita pelo orquestrador depois do `/forge:implement`; o gate w250 só valida a presença e a forma dos casos.

## Requisitos não funcionais do change

- **NFR-01 —** `SKILL.md` com no máximo 120 linhas de corpo e `description` com no máximo 1024 caracteres (medição: `validate-frontmatter.sh --strict-xml` e `wc -l`, no w250 [1][4]).
- **NFR-02 —** Cada `scan.sh` termina em menos de 5 s sobre a árvore deste repositório numa máquina de desenvolvimento (medição: `time` na TASK de revalidação, registrado no `verification.md`).
- **NFR-03 —** Determinismo do scanner: duas execuções consecutivas sobre a mesma árvore produzem saída idêntica (medição: `cmp -s` no w250 [6]).
- **NFR-04 —** Zero dependência nova de runtime ou de `package.json` (medição: `git diff --stat package.json package-lock.json` vazio).

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície | Coberto por task |
|---|---|---|---|
| REQ-01 | sem parâmetro exposto (roteamento por descrição e allowlist) | agente `data-engineer` (invocação por descrição, `@data-engineer` ou `claude --agent data-engineer`) | TASK-09 |
| REQ-02 | sem parâmetro exposto | seis agentes `data-*` | TASK-08 |
| REQ-05 | `--root <dir>`, `--json <arquivo>`, `--max <n>` | CLI `bash .forge/skills/<esp>-practices/scripts/scan.sh` | TASK-02 a TASK-07 |
| REQ-09 | sem parâmetro exposto (casos em JSON) | `.forge/evals/agents/<nome>/evals.json` | TASK-13, TASK-15 |
| REQ-03/04/06/07/08 | sem parâmetro configurável | — (conteúdo e gate) | TASK-01 a TASK-12, TASK-14 |

## Fora de escopo (reafirmação)

- Comando `/forge:*` novo e mudança no plugin (proposal §3; design D-05).
- Mudança de código em `sync-adapters.mjs`, `plugin-build.mjs` e `bin/forge.mjs`.
- Reescrita de `rules/data/*.md` (follow-up registrado; design D-06).
- Especialista de busca, vetorial ou séries temporais dedicado.
- Detector que conecta em sistema real; scanner como gate bloqueante do pipeline.
