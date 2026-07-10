# Forge Project Harness — Documento de Projeto

| | |
|---|---|
| **Versão** | 3.1 |
| **Data** | 2026-06-10 |
| **Autor** | Milton Silva |
| **Status** | Aprovado |
| **Substitui** | v2.0 (2026-06-09), que substituiu o `plano-forge-harness-sdd.md` (v1) |
| **Escopo** | Evoluir o `/init-project` atual para um harness SDD completo, agnóstico de agente, chamado **Forge**, com raiz `.forge/`, fonte canônica `.forge/FORGE.md`, interface padrão `AGENTS.md`, lifecycle de specs `active → archived`, baseline de produto, adaptadores gerados e camada de qualidade com avaliação quantitativa. |

> **Convenção deste documento.** O corpo é em português brasileiro. Os artefatos voltados a LLMs (conteúdo de `FORGE.md`, `AGENTS.md`, schemas, rules, templates de comando) são apresentados em inglês, por eficiência de tokens, conforme a convenção já adotada por Milton. A terminologia regulatória (PCI DSS, fintech) permanece em português. "Objeto de Valor" é sempre escrito por extenso. Nomes de repositório não embutem tecnologia.

---

## 1. Sumário Executivo

O `/init-project` atual já é um harness real — não um simples prompt inicial. Ele entrega `AGENTS.md`, uma árvore `.claude/` com agentes especializados, slash commands, rules, hooks, skills e `doctor.sh`, além de uma política de versionamento de documentos de especificação. O pipeline SDD existente é forte em especificação ampla de produto: Discovery → PRD → FRD/NFRD → DDD → Modules → TRD, com `requirements/design/tasks` por módulo. O problema central não é falta de capacidade, e sim **acoplamento e governança**: o harness está preso ao ecossistema Claude (`.claude/`) e ao caminho `docs/product/`, sem uma raiz neutra, sem adaptadores multi-agente formais, sem um ciclo explícito de mudança ativa → baseline → arquivo, e com pouca representação machine-readable.

Este documento define o **Forge Project Harness**: uma camada canônica, agnóstica de agente, instalada em `.forge/`. A partir dela, `.claude/`, `.codex/`, `.agents/`, `.kiro/`, `.qwen/` e equivalentes passam a ser **adaptadores gerados** — nunca a fonte primária. O `FORGE.md` é o documento principal (a fonte rica de governança), e o `AGENTS.md` na raiz é a **interface canônica** que as ferramentas descobrem por convenção de indústria, gerada a partir do `FORGE.md`. `CLAUDE.md`, `QWEN.md`, `GEMINI.md` e outros apontam para o `AGENTS.md` por symlink, com cópia materializada como fallback.

O Forge é organizado em **cinco camadas**:

1. **Project Brain** — governança: `FORGE.md`, `forge.yaml`, constitution, contexto, rules e adaptadores.
2. **Spec Lifecycle** — SDD: `specs/active/`, `specs/archived/` e `product/current/` (baseline).
3. **Execution Harness** — operação: commands, agents, skills, hooks, scripts, worktrees e validadores.
4. **Understanding Layer** — brownfield: grafo de código, inventário, análise de impacto e onboarding.
5. **Dev Loop & Quality** — execução de longa duração e qualidade: story sharding com contexto embutido (inspirado no BMAD v6), loops builder→validator, e um **eval harness quantitativo** para skills, commands e templates do próprio Forge (inspirado no skill-creator da Anthropic, via LionClaw).

O modelo de rigor SDD recomendado é **spec-anchored por default**, com suporte explícito a `spec-first` (protótipos e features pequenas) e `spec-as-source` (contratos e geradores maduros: OpenAPI, AsyncAPI, Protobuf, schemas, SDKs, migrations). O ciclo de mudança é **change-based** (inspirado no OpenSpec): cada feature/bugfix/refactor vive em `.forge/specs/active/<change-id>/`; ao concluir e verificar, o Forge aplica os deltas ao baseline em `.forge/product/current/` e move a pasta para `.forge/specs/archived/YYYY-MM-DD-<change-id>/`.

A entrega é incremental, em **cinco MVPs**. O MVP1 estabelece o `.forge` canônico com o adaptador Claude de compatibilidade, sem tocar em graph nem em archive. Os MVPs seguintes adicionam lifecycle, baseline com schemas, brownfield/graph e, por fim, a camada de Dev Loop & Quality. A regra de ouro permanece: **usar o mínimo de rigor que remove a ambiguidade do contexto** — todo processo pesado (incluindo o eval quantitativo) é opt-in, com Quick Plan disponível para casos simples.

---

## 2. Visão e Objetivos

### 2.1 Problema

Milton mantém múltiplos produtos e ventures (Axis Mobfintech, Vellus, Consilium, Pitflow) sobre uma stack heterogênea (C#/.NET 8+, React, Go, TypeScript, PostgreSQL, MongoDB, Redis, Kubernetes, AWS, Azure, GCP - Google Cloud Platform) e contexto regulatório pesado (PCI DSS, fintech, PAT - Programa de Alimentação do Trabalhador, mobilidade urbana). O fluxo de desenvolvimento assistido por IA precisa ser **confiável e replicável para toda a equipe**, e precisa **sobreviver à troca da LLM acoplada**. O `/init-project` resolve parte disso, mas amarra o time ao Claude e a um layout de pastas específico.

### 2.2 Princípios

1. **Agnosticismo de agente.** A fonte de verdade é `.forge/`. Qualquer ferramenta (Claude Code, Codex, Qwen CLI, Gemini CLI, Antigravity CLI, Cursor, Kiro, Forge CLI, OpenCode, Kimi CLI) consome adaptadores gerados. Trocar de LLM não deve quebrar o fluxo.
2. **Spec como fonte de verdade.** Código é artefato derivado, gerado ou verificado contra a especificação. Cada artefato limita a ambiguidade do próximo.
3. **Mínimo de rigor necessário.** `spec-first`, `spec-anchored` e `spec-as-source` coexistem; níveis de complexidade scale-adaptive evitam cerimônia onde ela não agrega.
4. **Determinismo onde possível.** Manifests, schemas e validadores deterministas reduzem interpretação livre; agentes revisores complementam, não substituem, os validadores.
5. **Mudança rastreável e arquivável.** Todo trabalho vive como change ativo, é verificado, incorporado ao baseline e arquivado.
6. **Compatibilidade preservada.** A migração não pode quebrar o uso atual em Claude Code; o primeiro adaptador reproduz o comportamento existente.
7. **Padrão da indústria como interface.** `AGENTS.md` é a porta de entrada que as ferramentas esperam; o Forge o adota como interface canônica.

### 2.3 O que o Forge é

Uma camada de projeto instalável (`.forge/`) que padroniza governança, especificação, execução, entendimento de brownfield e qualidade, sobre qualquer agente de código. É a evolução do `/init-project`, agora nomeada, versionada e replicável.

### 2.4 O que o Forge não é

Não é um produto separado nem um runtime de agente. O **Forge CLI** (derivado do Qwen Code, já existente nos experimentos de Milton) é o runtime; o **Forge Project Harness** é a camada de projeto que esse e outros runtimes consomem. O harness não substitui o Jira/Confluence; ele alimenta backlog e documentação a partir de uma fonte SDD única.

---

## 3. Conceito de Spec-Driven Development

### 3.1 Leitura do paper

O paper anexo (*Spec-Driven Development: From Code to Contract in the Age of AI Coding Assistants*, Piskala, 2026) define SDD como a inversão da relação tradicional entre código e documentação: a especificação vira a fonte de verdade, e o código passa a ser artefato derivado, gerado ou verificado contra ela. O ponto relevante para o Forge não é "escrever mais documentos", e sim construir um sistema em que cada artefato restringe a ambiguidade do próximo, criando uma cadeia de responsabilidade da intenção à implementação.

O fluxo base do paper tem quatro fases, cada uma produzindo um artefato que guia a próxima, com revisão humana em cada checkpoint:

1. **Specify** — o que deve existir, em comportamento verificável (sem prescrever implementação).
2. **Plan/Design** — como construir, com decisões técnicas e restrições.
3. **Implement** — tarefas pequenas, rastreáveis e verificáveis, em incrementos validados.
4. **Validate** — confirmar que código, testes e comportamento batem com a especificação; se houver lacuna, corrigir o código ou revisar a spec.

O paper destaca que especificações funcionam como "super-prompts" que quebram problemas complexos em componentes modulares alinhados à janela de contexto dos agentes, habilitando execução paralela e reduzindo o "vibe coding". Também alerta para armadilhas que o Forge precisa evitar por design: **over-specification** (spec que vira pseudo-código), **specification rot** (spec que diverge do código), **specification as bureaucracy** (formulários em vez de clareza), **tooling complexity** (afogar-se em artefatos gerados) e **false confidence** (um teste de spec que passa só garante que o código bate com a spec — não que a spec está certa).

### 3.2 Os três níveis de rigor

| Nível | Uso no Forge | Decisão |
|---|---|---|
| `spec-first` | Clareza inicial antes de codar; protótipos, spikes, features pequenas | Permitido, **não** default para sistemas long-lived |
| `spec-anchored` | Spec viva + testes/validação contra ela | **Default do Forge** |
| `spec-as-source` | Humanos editam a spec; máquinas geram o código | Apenas em contratos e geradores maduros (OpenAPI, AsyncAPI, Protobuf, schemas, SDKs, migrations, alguns fluxos de UI) |

Conclusão prática: para os domínios de Milton — fintech, regulatório, mobilidade —, o Forge deve evitar tanto o "vibe coding" quanto um waterfall documental pesado. O equilíbrio é **SDD vivo**, com baseline, deltas e verificação. O `spec-as-source` é reservado para onde a geração já é confiável e auditável.

### 3.3 SDD com IA: o que isso muda no harness

Quando uma IA gera código a partir da spec mais rápido do que um humano digita, o gargalo se desloca para a **qualidade da especificação**. Daí três consequências de design para o Forge: (1) especificações precisam ser estruturadas para consumo por agentes (não só leitura humana); (2) a validação precisa estar embutida no fluxo (loops builder→validator, contract tests, validadores deterministas), pois LLMs não se autocorrigem de forma confiável sem sinal externo; (3) o trabalho deve ser fatiado em incrementos pequenos e auto-contidos (story sharding) para caber na janela de contexto e permitir checkpoints frequentes.

---

## 4. Análise das Fontes

### 4.1 Fontes internas

- `/Users/milton/.claude/commands/init-project.md` e templates `project-bootstrap/**` (AGENTS.md, run-spec-pipeline, specs-loop, document-versioning, doctor.sh).
- `/Users/milton/Documents/projects/forge` — runtime CLI já existente, derivado do Qwen Code, com uso de `.agents/` e `.forge/settings.json` em testes.
- Estrutura **LionClaw** (`.lionclaw/**`) — assistente pessoal desktop com sistema de identidade/memória em camadas, skill-creator completo (derivado do skill-creator oficial da Anthropic), workflow BuildPlan de 7 etapas e skills de design.

### 4.2 Fontes externas

- Paper anexo (arXiv:2602.00180v1) e referências do paper.
- **Kiro** — Specs, Steering e Hooks (feature-specs, bugfix-specs).
- **GitHub Spec Kit** — CLI de init e comandos `constitution`/`specify`/`plan`/`tasks`/`analyze`/`implement`.
- **OpenSpec** (Fission-AI) — filosofia change-based e brownfield-first; `propose → apply → verify → archive`.
- **Graphify** (safishamsi) — knowledge graph persistente de código/docs com AST local e LLM para semântica.
- **Understand Anything** (Egonex-AI) — pipeline multi-agente de scanner/analyzer e validação determinística de grafo.
- **BMAD-METHOD** (bmad-code-org) — metodologia de desenvolvimento ágil orientado por IA, em sua versão v6.
- **AGENTS.md / Agentic AI Foundation** — padrão de indústria sob a Linux Foundation.

### 4.3 O que aproveitar de cada referência

#### Kiro
Aproveitar: três arquivos base por spec (`requirements.md`/`bugfix.md`, `design.md`, `tasks.md`); dois caminhos de feature (requirements-first e design-first); Quick Plan para features bem entendidas; bugfix spec com comportamento atual/esperado/inalterado; análise de requirements antes do design (inconsistências, ambiguidades, gaps, constraints conflitantes); steering files e hooks como contexto persistente e automação. **Não** copiar: dependência de IDE, saída canônica em `.kiro/specs/`, archive menos explícito que o do OpenSpec.

#### Spec Kit
Aproveitar: CLI de init com integrações por agente; comandos separados (`constitution`, `specify`, `plan`, `tasks`, `analyze`, `implement`); extensões/presets com ordem de precedência; overrides project-local; scripts cross-platform; análise cross-artifact antes de implementar. **Não** copiar integralmente: dependência Python/uv (o Forge CLI é Node/TypeScript), `.specify/` como fonte primária, rigor de fase rígido demais para todo tipo de trabalho.

#### OpenSpec
Aproveitar: filosofia brownfield-first e change-based; separação entre `specs/` (verdade vigente) e `changes/` (deltas ativos); comandos `propose → apply → verify → archive`; archive que aplica deltas, valida e move para `archive/YYYY-MM-DD-<change-id>/`; modelo de workspace/coordenação multi-repo; schemas que dirigem a sequência de artefatos. **Não** copiar integralmente: leveza excessiva para casos regulados (o Forge precisa de PRD/FRD/NFRD/TRD/DDD quando o risco justificar); telemetria por default (se existir, opt-in e sem conteúdo).

#### Graphify
Aproveitar: knowledge graph persistente (código, docs, PDFs, imagens, vídeos); AST local/determinístico para código, LLM apenas para semântica; `query/path/explain` antes de ler arquivos crus; manifest/cache portáveis; hook de atualização incremental; uso em PR (impacto, comunidades compartilhadas, risco de merge). No Forge: `.forge/graph/graph.json`, `report.md`, `cache/`; grafo como pré-flight de brownfield/feature/bugfix/review/archive; custo/logs locais fora do commit.

#### Understand Anything
Aproveitar: pipeline multi-agente (project scanner, file analyzer, architecture analyzer, tour builder, graph reviewer, domain analyzer); grafo interativo para onboarding; diff impact analysis; validação determinística de schema/integridade referencial do grafo; auto-update por fingerprint estrutural (zero tokens quando a mudança é cosmética). No Forge: um "graph reviewer" como gate opcional para brownfield grande; `/forge:onboard` para gerar tour de arquitetura/domínio; diff impact antes de tasks e antes de archive.

#### BMAD-METHOD (v6)
O BMAD é a referência mais madura em **execução autônoma de longa duração** — exatamente o ponto onde o Forge v1 era mais fraco (forte em spec/governança, leve em dev loop). Aproveitar:

- **Story sharding com contexto embutido.** O planejamento é fatiado em story files discretos, cada um carregando o contexto específico necessário para o agente implementar aquela parte; a v6 usa sub-agente para compilar contexto de épico no início do dev loop. Resolve o problema de janela de contexto em implementações longas.
- **Scale-adaptive workflow.** O fluxo ajusta a profundidade de planejamento conforme a complexidade do projeto. Formaliza o que o Forge chama de Quick Plan como decisão sistemática (níveis de complexidade), não exceção manual.
- **Checkpoint review guiado.** Revisão humana ordenada por preocupação sobre commits/branches/PRs — bom modelo para o gate de `/forge:verify`.
- **Customização por override sem fork.** Todo agente/workflow é customizável via overrides em pasta dedicada. Excelente padrão: template global + `.forge/custom/` por repo, sem divergir do template da equipe.
- **Adapter `.agents/skills/` cross-tool.** A v6 adota o padrão cross-tool `.agents/skills/` para plataformas que o suportam (dezenas de plataformas suportadas). O Forge deve gerar esse adaptador.

**Não** copiar: personas teatrais (nomes de agentes personificados), peso cerimonial ágil (a própria v6 consolidou três agentes em um, sinal de inchaço anterior), e o acoplamento ao instalador deles. Atenção também ao alerta da própria documentação do BMAD sobre revisão adversarial: como a IA é instruída a achar problemas, ela acha problemas mesmo onde não existem — falsos positivos são esperados, e o humano decide o que é real.

#### LionClaw
O LionClaw contribui dois ativos de alto valor, além de padrões transversais:

- **Eval harness quantitativo (skill-creator).** É o skill-creator oficial da Anthropic, com pipeline de avaliação A/B: execução paralela de subagentes *with-skill* vs *baseline*, grader com evidências (`grading.json` com campos `text`/`passed`/`evidence`), blind comparator, post-hoc analyzer, agregação com mean±stddev e deltas de pass-rate/tempo/tokens, eval-viewer HTML com feedback humano, e otimização de triggering com split train/test 60/40 (seleção do melhor pela pontuação de teste, anti-overfitting). **Nenhuma** das outras referências (BMAD, Spec Kit, OpenSpec, Kiro) faz benchmark quantitativo com-vs-sem artefato nem otimização de triggering por holdout. É o diferencial do Forge.
- **Separação de camadas identidade/contexto/regras (SOUL/USER/MEMORY/RULES).** Padrão convergente de governança em arquivos markdown separados por função. Útil como modelo para o Project Brain — descartando a persona de assistente pessoal (SOUL.md).
- **Padrões transversais:** validação determinística por shell script (`validate-frontmatter.sh`); progressive disclosure de três níveis (metadata → corpo → recursos agrupados); "description é marketing" (descrições pushy contra undertriggering); elicitação one-question-at-a-time com regra anti-inferência e gate de pitch intermediário (BuildPlan); loop builder→validator com max-iterações e relatório `[MISS]`/`[CONFLICT]` + Status PASS/FAIL (BuildPlan, etapa 7).

**Não** copiar: acoplamentos ao runtime do LionClaw (`claude -p`, `AskUserQuestion`, subagentes paralelos nativos) sem abstraí-los; SOUL.md/persona; memória mutável de assistente como conceito central; conteúdo das skills de design (só o meta-padrão importa).

#### Qwen Harness (HarnessQwen v6.5)

O Harness Qwen é uma memória institucional valiosa sobre **orquestração de sessões autônomas longas** (planejar e implementar projetos de 60+ features rodando por horas em autopilot). Embora acoplado a Cline + Qwen local, seus mecanismos são portáveis e cobrem exatamente o que a v3 do Forge precisa para sessões longas. Aproveitar:

- **Organização por waves/sprints com índice mestre.** Um `00-index.json` lista todas as waves na ordem de execução, com `status` e `featuresCount` por wave; cada wave tem 4-7 features, cada feature tocando 1-5 arquivos. É a estrutura de ondas com dependências que viabiliza o trabalho longo.
- **Ponteiro de progresso (`current.txt`).** Aponta para a wave atual ou `DONE`. Permite ao orquestrador saber onde está sem reler nada.
- **Helper scripts de economia de contexto.** `feat-context.py` entrega, em um único comando, todo o contexto de uma feature (info + trecho exato da SPEC no range + conteúdo dos arquivos no range), com a regra dura de **não ler nada fora do range**. `sprint-status.py` dá o progresso (done/total por wave) sem abrir os JSONs. `feat-status.py`/`sprint-close.py` mudam estado sem reler o arquivo inteiro. Este é o padrão que o Forge adota para as **skills especialistas**: o orquestrador delega a um script/skill que retorna o mínimo necessário.
- **Gates deterministas por feature.** Scripts dedicados que retornam uma única linha (`OK`/`FAIL`): parseabilidade, import-resolve, unused, grep positivo (OR cross-file), grep negativo (NOT cross-file), consistency cross-file, paths, lifecycle, anti-empty. Smoke executado **pelo workflow**, não pelo modelo (anti auto-mentira), com timeout e exit code esperado.
- **Sprint Review Final.** Como um LLM não revisa 60+ arquivos de uma vez, a última wave é dedicada à revisão categorizada (`audit-final.py` em 7 categorias: consistency, dead code, security, anti-patterns, duplication, TODOs). Encerramento só com zero findings HIGH.
- **Disciplina de autopilot.** Zero confirmação entre features/waves; output mínimo entre features; sem resumir progresso a cada wave (só no fim); todo comando externo com `timeout`; output bruto vai para arquivo (`> /tmp/...; tail -20`), nunca para o chat.

A lição mais cara do Qwen é a **Classe G (context overflow)**: o contexto enche silenciosamente (dumps de grep, heredoc, output bruto) e, acima de ~85% da janela, o modelo degrada e pode travar por horas. Daí os helper scripts, os gates de uma linha e o orçamento de contexto. Essa é a justificativa técnica para a estratégia de skills especialistas do Forge.

**Não** copiar: acoplamento a Cline (`.clinerules/`, settings de Background Exec/Yolo), a pasta `.harness/` (vira `.forge/`) e o pressuposto de LLM local único — o Forge é multi-agente. Os mecanismos entram; o vínculo de runtime, não.

### 4.4 Síntese comparativa

| Capacidade | Kiro | Spec Kit | OpenSpec | BMAD v6 | LionClaw | **Forge (alvo)** |
|---|---|---|---|---|---|---|
| Raiz neutra/agnóstica | Não (`.kiro`) | Parcial (`.specify`) | Sim (`openspec/`) | Parcial | Não (`.lionclaw`) | **Sim (`.forge`)** |
| Interface `AGENTS.md` | Parcial | Sim | Parcial | Sim | Não | **Sim (canônica)** |
| Change-based + archive | Parcial | Não | **Sim** | Parcial | Não | **Sim** |
| PRD/FRD/NFRD/TRD/DDD | Não | Parcial | Não | Parcial | Parcial (BuildPlan) | **Sim** |
| Brownfield graph | Não | Não | Parcial | Não | Não | **Sim** |
| Story sharding (long-run) | Não | Parcial | Não | **Sim** | Não | **Sim** |
| Scale-adaptive | Parcial | Não | Não | **Sim** | Não | **Sim** |
| Validadores deterministas | Não | Parcial | Sim | Não | **Sim** | **Sim** |
| Builder→validator loop | Não | Read-only | Parcial | **Sim** | **Sim** | **Sim** |
| **Eval quantitativo A/B** | Não | Não | Não | Não | **Sim** | **Sim** |
| **Triggering optimization** | Não | Não | Não | Não | **Sim** | **Sim** |
| **Meta-avaliação do harness** | Não | Não | Não | Não | Não | **Sim (diferencial)** |
| Orquestração por waves (sessão longa) | Não | Não | Não | Parcial | Parcial | **Sim** |
| Ponteiro de progresso + mini-report | Não | Não | Não | Parcial | Parcial | **Sim ** |
| **Ledger de pendências/deferidos** | Não | Não | Não | Não | Não | **Sim (diferencial)** |
| Gates deterministas por feature | Não | Parcial | Sim | Não | **Sim** | **Sim** |
| Skills especialistas (economia de contexto) | Não | Não | Não | Parcial | **Sim** | **Sim** |

---

## 5. Diagnóstico do `/init-project` Atual

### 5.1 O que está bom

O template atual é mais completo do que o Spec Kit em governança interna e mais profundo do que o OpenSpec em trilha documental:

- 36 arquivos de agents (especificação, arquitetura, engenharia, review, coding, code review).
- 9 commands (pipeline SDD, loop de specs, coding loop, status, deploy wave, ADR, changelog, scaffold TDD).
- 28 rules (convenções, arquitetura, domínio, frontend, testes).
- 5 hooks/scripts/settings (worktree guard, `doctor.sh`).
- 4 skills (worktrees, build verification, diff claims, design-system creator).
- YAML de identidade no topo do `AGENTS.md`, com resolução runtime de `repo_slug`, `jira_key`, `jira_site`.
- Política de versionamento de documentos com status `Rascunho`, `Rascunho para revisão`, `Aprovado para desenvolvimento`, `Supersedido`.

### 5.2 Lacunas

1. **Acoplamento a `.claude/`.** Agentes, comandos, hooks, rules e skills vivem em `.claude/`. Para Claude isso é natural; para Codex, Qwen, Kiro, Gemini, Cursor e Forge CLI vira tradução informal.
2. **Fonte de verdade dispersa.** O `AGENTS.md` é a identidade, mas comandos e rules leem `.claude/**`, os documentos saem em `docs/product/`, e não há manifesto único de projeto/spec/harness.
3. **Sem ciclo active/archive formal.** Há versionamento e gates humanos, mas não uma operação canônica que diga "esta mudança foi implementada, verificada, aplicada ao baseline e arquivada".
4. **Pouca representação machine-readable.** Quase toda a governança está em Markdown. Falta `manifest.yaml`, schema e validadores deterministas para reduzir interpretação livre.
5. **Brownfield depende de leitura manual.** O pipeline escaneia o repo e preenche "como rodar/testar/estrutura", mas não constrói um mapa persistente de código/contratos/impacto.
6. **Kiro tratado como anti-path, não como modelo parcial.** O template proíbe `.kiro/specs/` (corretamente, para evitar duplicidade), mas ainda não absorveu bugfix specs, design-first, quick plan e análise de requirements antes do design. (NOTA: o Kiro não é um anti-path, pelo contrário, acredito que ele implementa muito bem o conceito SDD. Só não quero que nossa documentação use o padrão de nomenclatura de pastas .kiro)
7. **Execução de longa duração ausente.** Não há story sharding nem mecanismo para manter contexto através de implementações longas — o que o BMAD v6 resolve.
8. **Sem avaliação de qualidade dos próprios artefatos.** Não há como medir se um template/command/skill do harness está ajudando ou atrapalhando — capacidade que o eval harness do LionClaw traz.

---

## 6. Modelo Conceitual do Forge

O Forge tem cinco camadas. As quatro primeiras vêm do plano v1; a quinta (Dev Loop & Quality) é a principal adição da v2, consolidando os aprendizados do BMAD v6 e do LionClaw.

### 6.1 Camada 1 — Project Brain (governança)

`.forge/FORGE.md`, `.forge/forge.yaml`, `constitution.md`, contexto de projeto/usuário, rules e adaptadores. É onde a identidade, a política SDD, o nível de rigor default e as convenções vivem. Inspirada na separação de camadas do LionClaw (contexto, regras), descartando persona de assistente.

### 6.2 Camada 2 — Spec Lifecycle (SDD)

`.forge/specs/active/`, `.forge/specs/archived/` e `.forge/product/current/` (baseline). É a camada SDD change-based: cada mudança nasce ativa, é verificada, incorporada ao baseline e arquivada.

### 6.3 Camada 3 — Execution Harness (operação)

Commands, agents, skills, hooks, scripts, worktrees e validadores. É a camada operacional que executa o fluxo.

### 6.4 Camada 4 — Understanding Layer (brownfield)

Graph, inventário, análise de impacto, onboarding, extração de domínio e mapas de código/documento. É a camada que torna o Forge eficaz em repos legados e grandes.

### 6.5 Camada 5 — Dev Loop & Quality (execução longa + qualidade)

Duas responsabilidades complementares:

- **Dev Loop (story sharding).** Implementação de longa duração fatiada em stories auto-contidas, cada uma carregando o contexto relevante (trechos de requirements/design/contratos) para caber na janela do agente. Sub-agente compila o contexto de épico no início. Loops builder→validator com max-iterações fecham a correção com sinal externo.
- **Quality (eval harness).** Avaliação quantitativa de skills, commands e templates do próprio Forge: execução A/B (com-vs-sem artefato), grader com evidências, agregação com mean±stddev e deltas, e otimização de triggering por holdout train/test. Tudo opt-in.

---

## 7. Decisão: `AGENTS.md` versus `FORGE.md`

Esta é a definição que o projeto pediu explicitamente, e ela **altera a decisão #3 do plano v1** (que fazia todos os arquivos symlinkar diretamente para `FORGE.md`).

### 7.1 O padrão da indústria

`AGENTS.md` deixou de ser uma convenção entre outras e virou o padrão de fato. Lançado pela OpenAI em agosto de 2025, foi doado à **Agentic AI Foundation** (sob a Linux Foundation, fundada em dezembro de 2025), ao lado de MCP e goose. Já foi adotado por **mais de 60.000 projetos open-source** e é suportado nativamente por Codex, Copilot, Jules, Gemini CLI, Cursor, Zed, Windsurf, Warp e outros. A exceção relevante é o Claude Code, que ainda usa `CLAUDE.md`. O BMAD v6 mostra que a indústria também converge para o padrão cross-tool `.agents/skills/`.

Brigar contra um padrão da Linux Foundation só geraria atrito para a equipe. O Forge o adota como interface.

### 7.2 A decisão

A cadeia canônica do Forge tem três níveis:

```text
.forge/FORGE.md          # FONTE canônica (rica): governança, identidade, política SDD, lifecycle
        │  (forge sync-adapters projeta)
        ▼
AGENTS.md                # INTERFACE canônica (padrão de indústria): subconjunto operacional
        │  (symlink, ou cópia materializada como fallback)
        ▼
CLAUDE.md, QWEN.md, GEMINI.md, ...   # apontam para AGENTS.md
```

- **`.forge/FORGE.md` é a fonte de verdade rica.** Contém a governança completa do harness. É onde humanos e o Forge editam.
- **`AGENTS.md` (raiz) é a interface canônica.** É **gerado** a partir do `FORGE.md` por `forge sync-adapters`, contendo o subconjunto operacional que as ferramentas esperam (overview, setup, comandos de build/test, convenções, boundaries, como ler specs, como validar). É o que as ferramentas descobrem por convenção.
- **`CLAUDE.md`, `QWEN.md`, `GEMINI.md` e equivalentes são symlinks para `AGENTS.md`.** Quando a ferramenta não segue symlink, o Forge materializa uma cópia com header de arquivo gerado.

### 7.3 Por que `AGENTS.md` é gerado e não um symlink direto de `FORGE.md`

`FORGE.md` e `AGENTS.md` não são idênticos. O `FORGE.md` carrega governança específica do Forge (modos SDD, archive policy, lifecycle, níveis de rigor) que não pertence à interface padrão. O `AGENTS.md` é a projeção operacional, conformante ao padrão. Gerar (em vez de symlinkar diretamente) permite manter o `AGENTS.md` enxuto e padrão-conformante, enquanto o `FORGE.md` permanece a fonte rica. Os demais arquivos de agente symlinkam para o `AGENTS.md`, garantindo uma única interface materializada.

### 7.4 Header de arquivo gerado

Para ferramentas que não seguem symlink, a cópia materializada recebe:

```markdown
> Generated from .forge/FORGE.md by `forge sync-adapters`. Do not edit this file directly.
> Edit .forge/FORGE.md and re-run sync. Drift is detected by `forge doctor`.
```

---

## 8. Arquitetura e Estrutura de Pastas

```text
repo-root/
├── .forge/
│   ├── FORGE.md                      # fonte canônica rica (Project Brain)
│   ├── forge.yaml                    # manifesto machine-readable do harness
│   ├── constitution.md               # princípios do projeto
│   ├── context.md                    # contexto de stack/usuário/convenções (inspirado em USER/RULES do LionClaw)
│   ├── README.md
│   ├── runners.yaml                  # interface de runner configurável (Dev Loop & Quality)
│   ├── adapters/
│   │   ├── claude.yaml
│   │   ├── codex.yaml
│   │   ├── qwen.yaml
│   │   ├── kiro.yaml
│   │   ├── gemini.yaml
│   │   ├── cursor.yaml
│   │   ├── agents-skills.yaml         # padrão cross-tool .agents/skills/ (BMAD v6)
│   │   └── forge-cli.yaml
│   ├── agents/
│   │   ├── specifications/
│   │   ├── architecture/
│   │   ├── coding/
│   │   ├── review/
│   │   ├── graph/
│   │   ├── quality/                   # executor, grader, comparator, analyzer (eval harness)
│   │   └── README.md
│   ├── commands/
│   │   ├── specs/
│   │   ├── coding/
│   │   ├── docs/
│   │   ├── graph/
│   │   ├── review/
│   │   ├── skill/                     # create, eval, optimize
│   │   └── README.md
│   ├── rules/
│   │   ├── conventions/
│   │   ├── architecture/
│   │   ├── domain/
│   │   ├── frontend/
│   │   ├── testing/
│   │   └── README.md
│   ├── hooks/
│   ├── skills/
│   ├── scripts/
│   │   ├── doctor.sh
│   │   ├── sync-adapters.sh
│   │   ├── validate-harness.sh
│   │   ├── validate-frontmatter.sh    # validador determinista de frontmatter (LionClaw)
│   │   └── archive-spec.sh
│   ├── schemas/
│   │   ├── forge.schema.json
│   │   ├── spec-manifest.schema.json
│   │   ├── spec-delta.schema.json
│   │   ├── baseline-capability.schema.json
│   │   ├── adapter-capability.schema.json
│   │   ├── archive-state-machine.schema.json
│   │   ├── traceability.schema.json
│   │   ├── grading.schema.json        # eval harness (text/passed/evidence)
│   │   └── adapter.schema.json
│   ├── templates/
│   │   ├── FORGE.md
│   │   ├── AGENTS.md                   # template da interface gerada
│   │   ├── spec/
│   │   ├── bugfix/
│   │   ├── refactor/
│   │   ├── story/                      # template de story auto-contida (Dev Loop)
│   │   ├── product/
│   │   └── adapter/
│   ├── specs/
│   │   ├── active/
│   │   │   └── <change-id>/
│   │   │       ├── manifest.yaml
│   │   │       ├── proposal.md
│   │   │       ├── discovery.md
│   │   │       ├── requirements.md
│   │   │       ├── bugfix.md
│   │   │       ├── refactor.md
│   │   │       ├── design.md
│   │   │       ├── tasks.md
│   │   │       ├── stories/            # stories auto-contidas (Dev Loop)
│   │   │       ├── spec-delta.yaml
│   │   │       ├── traceability.yaml
│   │   │       ├── approvals.yaml
│   │   │       ├── verification.yaml
│   │   │       ├── verification.md
│   │   │       ├── contracts/
│   │   │       ├── data-model/
│   │   │       └── evidence/
│   │   └── archived/
│   │       ├── index.yaml
│   │       └── YYYY-MM-DD-<change-id>/
│   ├── product/
│   │   ├── current/
│   │   │   ├── capabilities/           # unidade canônica do baseline
│   │   │   ├── prd/
│   │   │   ├── frd-nfrd/
│   │   │   ├── ddd/
│   │   │   ├── trd/
│   │   │   ├── adr/
│   │   │   ├── glossary/
│   │   │   └── CHANGELOG.md
│   │   └── published/
│   ├── graph/
│   │   ├── graph.json
│   │   ├── report.md
│   │   ├── manifest.json
│   │   └── cache/
│   ├── evals/                          # eval harness (skills, commands, templates do Forge)
│   │   ├── skills/
│   │   ├── commands/
│   │   └── meta/                       # meta-avaliação do harness (diferencial)
│   ├── custom/                         # overrides por repo, sem fork (BMAD v6)
│   └── worktrees/
├── AGENTS.md            -> projeção gerada de .forge/FORGE.md
├── CLAUDE.md            -> AGENTS.md
├── QWEN.md              -> AGENTS.md
├── GEMINI.md            -> AGENTS.md
└── docs/product/        # opcional: publicação espelhada para humanos, não fonte primária
```

### 8.1 Diferença entre `specs/active/` e `product/current/` (esclarecimento)

Esta é a distinção central do Forge e merece clareza. Duas analogias ajudam: **`product/current/` é a "lei em vigor"; `specs/active/<change-id>/` é uma "emenda em tramitação".** Em termos de Git: `product/current/` é como a branch consolidada; cada `specs/active/<change-id>/` é como uma branch de feature em revisão.

| Aspecto | `.forge/specs/active/<change-id>/` | `.forge/product/current/` |
|---|---|---|
| O que é | Uma **mudança em andamento** (feature, bugfix, refactor) | O **estado vigente e verificado** do produto inteiro |
| Natureza | Delta (o que vai mudar) + plano + evidências | Baseline cumulativo (o que o produto É hoje) |
| Quantidade | Várias podem coexistir, uma por mudança | Uma só, sempre |
| Quem edita | O fluxo da mudança (requirements/design/tasks/stories) | **Ninguém edita à mão** — só o `/forge:archive` aplica deltas |
| Conteúdo | `proposal.md`, `requirements.md`, `design.md`, `tasks.md`, `stories/`, `spec-delta.yaml`, `verification.yaml` | `capabilities/**` com IDs estáveis, mais PRD/FRD/NFRD/TRD/DDD agregados e `CHANGELOG.md` |
| Ciclo de vida | Nasce → é planejada → implementada → verificada → **arquivada** | Cresce a cada archive; nunca é "concluída" |
| Após concluir | Vira `specs/archived/YYYY-MM-DD-<change-id>/` (histórico) | Recebe os deltas da mudança (passa a refletir o novo estado) |

Fluxo concreto: o desenvolvedor abre `specs/active/add-card-tokenization/`. Ali descreve **o que vai mudar** na capability `tokenization` (um delta: "adicionar REQ-TOK-001"). Implementa, verifica. No `/forge:archive`, o Forge lê o `spec-delta.yaml`, **aplica** o delta em `product/current/capabilities/tokenization/spec.yaml` (que passa a conter REQ-TOK-001) e **move** a pasta da mudança para `specs/archived/`. A partir daí, `product/current/` reflete a realidade nova; a pasta ativa sai do diretório de trabalho e vira registro histórico.

Por que separar: sem o baseline (`current/`), cada mudança teria que reconstruir "o que o produto já faz" para saber o que está alterando — e o brownfield ficaria impossível. Sem a pasta ativa (`active/`), não haveria onde planejar e verificar uma mudança antes de ela virar verdade. O `active/` é volátil e plural; o `current/` é durável e único.

### 8.2 Decisão: `.forge/product/current` versus `docs/product`

**`.forge/product/current` é a fonte de verdade SDD**; `docs/product/` é publicação opcional para humanos.

Motivos: o harness tem raiz `.forge`; a especificação precisa ficar perto dos manifests, schemas, traceability e archive; `docs/product/` continua existindo para relatórios, decks e handoffs, mas não é onde agentes decidem estado de lifecycle.

Trade-off: esconder specs em dot-folder reduz a visibilidade humana. Mitigação: `/forge:publish-docs` gera/atualiza `docs/product/` a partir de `.forge/product/current/`.

### 8.3 Decisão: `context.md` separado de `FORGE.md`

Inspirado na separação USER/RULES do LionClaw e alinhado ao `constitution.md` do Spec Kit e ao `project.md` do OpenSpec, o `.forge/context.md` carrega o contexto durável de stack e convenções de Milton (C#/.NET 8+, Go, React, TypeScript, PostgreSQL, AWS; PCI DSS; padrões de nomenclatura). Isso mantém o `FORGE.md` focado em governança e operação, e o `context.md` focado em "quem é o projeto e quais convenções valem". A memória mutável de assistente (MEMORY.md do LionClaw) **não** é portada como conceito central: o estado durável vive no lifecycle de specs e no manifest, que são superiores a uma memória mutável para um harness de engenharia.

---

## 9. `FORGE.md`

O `FORGE.md` substitui o papel atual do `AGENTS.md` como fonte principal de orientação. Conteúdo (em inglês, por eficiência de tokens):

- identidade do projeto;
- modo SDD default e nível de rigor default;
- nível de complexidade scale-adaptive default;
- stack;
- comandos de run/test/build;
- regras de linguagem e commits;
- como ler specs;
- como usar o graph;
- como trabalhar com worktrees;
- como validar antes de concluir;
- como arquivar specs.

YAML canônico no topo:

```yaml
---
forge_version: 1
project:
  name: <project-slug>
  display: <Project Display>
  description: <one-line description>
  repo_slug:
  default_branch:
  owners: []
  domains: []
sdd:
  default_mode: brownfield          # greenfield | brownfield | feature | bugfix | refactor
  default_rigor: spec-anchored      # spec-first | spec-anchored | spec-as-source
  default_scale: 2                  # 0..4 (scale-adaptive complexity)
  archive_policy: after_verified_implementation
  human_gate_required: true
runtime:
  primary_stack:
  package_manager:
  run:
  test:
  typecheck:
  lint:
integrations:
  jira:
  github:
  graph:
    enabled: true
    path: .forge/graph/graph.json
quality:
  evals_enabled: false              # opt-in
  runners_config: .forge/runners.yaml
---
```

---

## 10. Manifestos e Schemas

Markdown livre é ótimo para agentes, mas insuficiente para decisões de lifecycle. O Forge usa manifestos e schemas para tornar deterministas as operações críticas (especialmente archive). Sem isso, "aplicar deltas ao baseline" vira um merge manual assistido por agente.

### 10.1 `.forge/forge.yaml`

```yaml
version: 1
harness:
  name: forge
  installed_at: "2026-06-09T00:00:00Z"
  template_version: "0.1.0"
  adapters:
    - claude
    - codex
    - qwen
    - agents-skills
specs:
  root: .forge/specs
  active: .forge/specs/active
  archived: .forge/specs/archived
  baseline: .forge/product/current
graph:
  enabled: true
  root: .forge/graph
quality:
  enabled: false
  evals_root: .forge/evals
  runners: .forge/runners.yaml
  require_tests_before_archive: true
  require_traceability_before_archive: true
  require_human_approval_before_archive: true
```

### 10.2 `.forge/specs/active/<change-id>/manifest.yaml`

O manifesto ganha, na v2, o campo `scale` (nível de complexidade) e o bloco `dev_loop`.

```yaml
id: add-card-tokenization
type: feature                    # feature | bugfix | refactor | greenfield | brownfield
mode: brownfield
rigor: spec-anchored
scale: 3                         # 0..4 (scale-adaptive)
status: tasks-ready
created_at: "2026-06-09"
updated_at: "2026-06-09"
owner: milton
parent:
  baseline: .forge/product/current
affected_capabilities:
  - card-issuing
  - tokenization
affected_paths:
  - packages/api/src/tokenization
dependencies:
  specs: []
  code: []
gates:
  requirements_reviewed: false
  design_reviewed: false
  tasks_reviewed: false
  implementation_verified: false
  human_archive_approval: false
dev_loop:
  sharded: true
  stories_path: stories/
  epic_context_compiled: false
quick_plan:
  enabled: false
  skipped_phases: []
  justification:
archive:
  eligible: false
  reason: "tasks not implemented"
```

### 10.3 Níveis scale-adaptive

O campo `scale` (0..4) formaliza o Quick Plan como decisão sistemática, não exceção manual (padrão BMAD v6). Cada nível define quais fases são obrigatórias.

| Scale | Perfil | Fases obrigatórias | Gates |
|---|---|---|---|
| 0 | Trivial (typo, ajuste cosmético) | `tasks` | Verificação leve |
| 1 | Feature pequena / spike | `requirements` curto + `tasks` | Verificação |
| 2 | Feature padrão (default) | `requirements` + `design` + `tasks` | Review humano nos três |
| 3 | Feature complexa / multi-módulo | + `analyze` + story sharding | Review + impacto |
| 4 | Iniciativa regulada / alto risco | + FRD/NFRD/TRD/DDD + aprovação explícita | Review completo + aprovação regulatória |

Quando o usuário escolhe um nível abaixo do que o risco sugere, o `manifest.yaml` registra as fases puladas, a justificativa e os gates reduzidos.

### 10.4 `spec-delta.schema.json`

Define operações permitidas contra o baseline. Regra central: `modify_requirement` usa **substituição integral** do requisito, nunca patch parcial (lição do OpenSpec — deltas parciais perdem contexto no archive).

```yaml
operations:
  - op: add_requirement
    capability: tokenization
    requirement_id: REQ-TOK-001
    content_ref: requirements.md#req-tok-001
  - op: modify_requirement
    capability: card-issuing
    requirement_id: REQ-CARD-014
    full_replacement_ref: requirements.md#req-card-014
  - op: remove_requirement
    capability: legacy-export
    requirement_id: REQ-LEG-003
    reason: "Replaced by v2 export"
    migration: "Use REQ-EXP-011"
  - op: add_contract
    contract_type: openapi
    path: contracts/tokenization.openapi.yaml
```

### 10.5 `baseline-capability.schema.json`

Unidade canônica do baseline em `.forge/product/current/capabilities/<capability>/spec.yaml`. PRD, FRD/NFRD, TRD e DDD são visões agregadas ou publicadas a partir das capabilities; o merge primário do archive ocorre em capabilities com IDs estáveis.

```yaml
capability_id: tokenization
version: 1.2.0
status: current
requirements:
  - id: REQ-TOK-001
    title: Tokenize card PAN
    normative: SHALL
    scenarios:
      - id: SCN-TOK-001-A
        given: "A valid PAN from an enrolled issuer"
        when: "The tokenization request is approved"
        then: "The system returns a network token without exposing PAN"
    contracts:
      - contracts/tokenization.openapi.yaml#/paths/~1tokens/post
    tests:
      - tests/tokenization/tokenize-card.spec.ts
history:
  - change_id: add-card-tokenization
    archived_at: "2026-06-09"
```

### 10.6 `adapter-capability.schema.json`

Define o que cada adaptador suporta e como validar.

```yaml
adapter: claude
generates:
  - .claude/commands
  - .claude/agents
  - .claude/settings.json
supports:
  symlink: true
  slash_commands: true
  skills: true
  hooks: true
source_hashes:
  .forge/commands/specs/archive.md: sha256:...
smoke_tests:
  - name: commands-visible
    command: "list generated command files"
loss_warnings: []
```

### 10.7 `archive-state-machine.schema.json`

Define estados, transições, gates e exceções. `archived` só ocorre após `verified`, salvo comando explícito de `close`/`abandon` (que não atualiza baseline).

```text
idea -> proposed -> requirements-ready -> design-ready -> tasks-ready
tasks-ready -> implementing -> implemented -> verified -> archived
proposed|requirements-ready|design-ready|tasks-ready -> abandoned
any -> blocked
archived -> reopened
archived -> rolled-back
any -> superseded
```

### 10.8 `grading.schema.json` (novo na v2 — eval harness)

Schema do output do grader, com os campos exatos que o eval-viewer espera. Reusa o formato do skill-creator da Anthropic.

```json
{
  "expectations": [
    { "text": "The output includes REQ-TOK-001 with a testable scenario",
      "passed": true,
      "evidence": "requirements.md lines 12-20 define SCN-TOK-001-A in Given/When/Then" }
  ],
  "summary": { "passed": 1, "failed": 0, "total": 1, "pass_rate": 1.0 }
}
```

Restrições deterministas impostas pelo validador (alinhadas ao spec aberto Agent Skills): `name` ≤ 64 caracteres; `description` ≤ 1024 caracteres e sem tags XML; campos `text`/`passed`/`evidence` obrigatórios em cada expectation.

### 10.9 `runners.yaml` (novo na v2 — agnosticismo do eval)

A abstração que torna o eval harness agnóstico de agente. Substitui o `claude -p` hardcoded do LionClaw por uma interface "execute este prompt neste modelo e capture tokens/tempo/saída".

```yaml
version: 1
default_runner: claude-code
runners:
  claude-code:
    kind: cli
    command: "claude"
    args: ["-p", "{prompt}", "--output-format", "stream-json"]
    captures: [tokens, duration_ms, output]
    parallel: true
  codex:
    kind: cli
    command: "codex"
    args: ["exec", "{prompt}"]
    captures: [output]
    parallel: false
  forge-cli:
    kind: cli
    command: "forge"
    args: ["run", "-p", "{prompt}"]
    captures: [tokens, duration_ms, output]
    parallel: true
```

Onde subagentes paralelos não existem, o eval cai para execução serial (degradação graciosa).

### 10.10 `approvals.yaml` e `verification.yaml`

`approvals.yaml` registra decisões humanas:

```yaml
approvals:
  - gate: tasks_review
    approved_by: milton
    approved_at: "2026-06-09T18:00:00-03:00"
    commit: "abc1234"
    scope: "tasks.md for all Tier 1 modules"
    notes: "Aprovado para desenvolvimento"
```

`verification.yaml` registra evidências técnicas:

```yaml
verification:
  commit: "abc1234"
  checks:
    - name: test
      command: "npm test"
      status: passed
    - name: typecheck
      command: "npm run typecheck"
      status: passed
  evidence:
    - verification.md
    - evidence/test-output.txt
```

### 10.11 Artefatos de orquestração de sessão longa (novo na v3)

Para sessões longas, o change ativo ganha três artefatos machine-readable em `.forge/specs/active/<change-id>/`, herdados do padrão do Qwen v6.5 e adaptados ao Forge.

**`waves.json`** — organiza a execução em ondas com dependências (equivalente ao `00-index.json` do Qwen, agora por mudança):

```yaml
# representação YAML; o arquivo é JSON
project_or_change: add-card-tokenization
total_waves: 5
waves:
  - index: 0
    name: "Wave 0 — Foundation (shared types, contracts)"
    status: done           # pending | in-progress | done | blocked
    stories: [S01, S02]
    depends_on: []
  - index: 1
    name: "Wave 1 — DB layer (schema, migrations, repositories)"
    status: in-progress
    stories: [S03, S04, S05]
    depends_on: [0]
  - index: 2
    name: "Wave 2 — Tokenization service"
    status: pending
    stories: [S06, S07]
    depends_on: [1]
```

**`progress.json`** — ponteiro e agregados de progresso (alimenta o `/forge:progress`):

```yaml
current_wave: 1
status: in-progress       # in-progress | done
totals:
  stories_done: 5
  stories_total: 14
by_area:
  - area: "Module A (tokenization)"
    done: 2
    total: 7
  - area: "Infrastructure"
    done: 3
    total: 4
next_logical_step: "Implementar S06 (endpoint POST /tokens) na Wave 2"
```

**`deferrals.json`** — o ledger de pendências (ver seção 17.4):

```yaml
deferrals:
  - id: DEF-001
    raised_in: S04
    blocks: S09
    reason: "S04 needs the webhook contract only defined in Wave 3 (S12)"
    depends_on: S12
    status: open          # open | resolved | tested
    resolution: null
```

Os três arquivos são atualizados por scripts deterministas (não pelo modelo relendo tudo), preservando a economia de contexto.

---

## 11. Modos de Uso

O Forge suporta cinco modos. Cada um define o fluxo recomendado de comandos e os artefatos esperados. O nível scale-adaptive modula quais fases são obrigatórias dentro de cada modo.

### 11.1 Greenfield

Novo produto ou repo vazio.

```text
/forge:init --mode greenfield
/forge:spec new <idea>
/forge:clarify
/forge:requirements
/forge:design
/forge:tasks
/forge:analyze
/forge:implement
/forge:verify
/forge:archive
```

Artefatos: `.forge/FORGE.md`, `.forge/constitution.md`, `.forge/context.md`, `.forge/specs/active/<project-or-feature>/`, e `.forge/product/current/` criado no primeiro archive. Rigor default `spec-anchored`; `spec-first` permitido para protótipo descartável (registrar no manifesto as fases puladas e a justificativa).

### 11.2 Brownfield

Repo existente, legado, fork, produto em produção.

```text
/forge:init --mode brownfield
/forge:discover
/forge:codegraph
/forge:onboard
/forge:baseline extract
/forge:spec new <change>
/forge:impact
/forge:design
/forge:tasks
/forge:analyze
/forge:implement
/forge:verify
/forge:archive
```

Antes de qualquer mudança, o brownfield extrai: inventário de stack, comandos de run/test/build, estrutura e boundaries, contratos existentes, ADRs e docs, grafo de código e baseline de capacidades atuais. Rigor default `spec-anchored`, com graph/impact obrigatório para mudanças de alto impacto (scale ≥ 3).

### 11.3 Feature Only

Repo já inicializado, feature isolada.

```text
/forge:spec new --type feature <feature>
/forge:requirements
/forge:tasks
/forge:implement
/forge:verify
/forge:archive
```

Se o baseline existe, a feature cria deltas em `affected_capabilities`. Se não existe, o Forge cria baseline mínimo ou pergunta se é um `feature-only standalone`. Se a feature pular `design.md`, registrar no `manifest.yaml` como Quick Plan (scale 1), com motivo e responsável.

### 11.4 Bugfix

Bug com risco de regressão.

```text
/forge:spec new --type bugfix <bug>
/forge:root-cause
/forge:tasks
/forge:implement
/forge:verify
/forge:archive
```

Artefato principal `bugfix.md`: comportamento atual incorreto, comportamento esperado, comportamento que deve continuar inalterado, root cause, propriedades/PBTs ou testes de regressão.

### 11.5 Refactor

Mudança interna sem alteração intencional de comportamento.

```text
/forge:spec new --type refactor <refactor>
/forge:design
/forge:tasks
/forge:implement
/forge:verify
/forge:archive
```

Artefato principal `refactor.md`: invariantes comportamentais, área impactada, riscos, estratégia de migração, testes de não-regressão. Archive só ocorre se o comportamento preservado foi verificado.

---

## 12. Lifecycle de Spec

Estados principais:

```text
idea -> proposed -> requirements-ready -> design-ready -> tasks-ready
     -> implementing -> implemented -> verified -> archived
```

Estados laterais:

```text
blocked      # impedido por decisão, acesso, dependência ou bug externo
abandoned    # encerrado sem implementação e sem atualizar baseline
rejected     # revisado e recusado
superseded   # substituído por outra spec/change
reopened     # archive reaberto por divergência ou regressão
rolled-back  # archive revertido no baseline por rollback formal
```

Regras de transição:

- `proposed`: `proposal.md` existe.
- `requirements-ready`: `requirements.md` ou `bugfix.md` sem `NEEDS CLARIFICATION`.
- `design-ready`: `design.md` existe e passa no validador.
- `tasks-ready`: `tasks.md` completo, ordenado e rastreável.
- `implementing`: ao menos uma task em andamento.
- `implemented`: todas as tasks concluídas.
- `verified`: testes/checks/evidências registradas em `verification.md` e `verification.yaml`.
- `archived`: deltas aplicados ao baseline e pasta movida para archived.
- `abandoned`/`rejected`: podem mover a pasta para archived, com `archive.kind: closed_without_baseline_update`.
- `reopened`: exige motivo, baseline afetado e nova spec corretiva ou rollback.

### 12.1 Decisões humanas (HITL) via AskUserQuestion

Sempre que uma transição exigir decisão humana (Human-in-the-Loop), o agente **não** pergunta em texto livre: apresenta as opções via `AskUserQuestion` (ou o equivalente do runner), para que o usuário veja claramente as alternativas e o efeito de cada uma. Cada gate de aprovação (`requirements_reviewed`, `design_reviewed`, `tasks_reviewed`, `implementation_verified`, `human_archive_approval`) usa este padrão.

Opções canônicas apresentadas em cada gate:

| Opção | Efeito | Registro obrigatório |
|---|---|---|
| **Approve** | Marca o gate como aprovado; avança o lifecycle | autor, timestamp, commit, escopo |
| **Review (loop de ajuste)** | Dispara novo ciclo builder→validator com os ajustes pedidos | **motivo** (o que ajustar) — registrado |
| **Reject** | Recusa o artefato/etapa; transição para `rejected` | **motivo** — obrigatório |
| **Supersede** | Marca como substituído por outra spec/change | id da spec substituta + motivo |
| **Abandon** | Encerra sem atualizar baseline; move para archived | **motivo** — obrigatório |
| **Block** | Marca `blocked` (dependência/decisão/acesso pendente) | causa do bloqueio |

Regras: toda opção que não seja **Approve** exige um motivo por escrito, gravado em `approvals.yaml` (campos `decision` + `reason`) para auditoria — essencial em domínios regulados. A opção **Review** alimenta o loop de auto-ajuste (seção 14.6) com o motivo como instrução; não é rejeição, e sim pedido de iteração. O agente apresenta o `AskUserQuestion` com um resumo de 2-3 linhas do que está sendo decidido, sem despejar o artefato inteiro no chat (economia de contexto).

```yaml
approvals:
  - gate: design_review
    decision: review            # approve | review | reject | supersede | abandon | block
    reason: "Faltou tratar falha de tokenização parcial; ajustar design.md §4"
    decided_by: milton
    decided_at: "2026-06-10T11:00:00-03:00"
    iteration: 2
```

---

## 13. Política de Archive

Comando: `/forge:archive <change-id>`.

`/forge:archive` significa **incorporar mudança verificada ao baseline**. Para encerrar uma spec não implementada, usar `/forge:close <change-id> --reason abandoned|rejected|superseded`, que move a pasta para archived **sem** aplicar deltas.

### 13.1 Pré-flight obrigatório

- `manifest.yaml` válido contra schema.
- Sem `NEEDS CLARIFICATION`.
- `tasks.md` 100% concluído.
- `verification.md` presente.
- `approvals.yaml` presente quando `human_gate_required=true`.
- `traceability.yaml` presente e válido (requisitos → design → tasks → evidências).
- Testes/lints/typechecks definidos em `FORGE.md` executados, ou justificativa registrada.
- Para brownfield: diff impact analisado contra `.forge/graph/graph.json`.
- Para mudança de contrato: contract tests ou schema validation executados.
- Para domínios regulados/financeiros: aprovação humana explícita.

### 13.2 Operação

1. Validar change ativo.
2. Ler `spec-delta.yaml` e validar contra `spec-delta.schema.json`.
3. Preparar aplicação dos deltas em memória, sem gravar.
4. Validar o baseline resultante contra `baseline-capability.schema.json`.
5. Aplicar deltas a `.forge/product/current/capabilities/**`.
6. Atualizar PRD/FRD/NFRD/TRD/DDD publicados ou agregados quando o manifesto indicar impacto.
7. Atualizar graph se o código mudou.
8. Registrar archive metadata.
9. Mover `.forge/specs/active/<change-id>/` para `.forge/specs/archived/YYYY-MM-DD-<change-id>/`.
10. Atualizar `.forge/specs/archived/index.yaml` e `.forge/product/current/CHANGELOG.md`.

### 13.3 Sobre arquivar antes de implementar

É possível arquivar logo após a especificação estar completa, antes de codar — mas **não** é o default recomendado. O default seguro é arquivar após implementação verificada, porque archive deve significar "mudança concluída e incorporada ao baseline". Arquivar cedo demais separa a spec da evidência de que ela foi cumprida.

---

## 14. Comandos

Namespace `/forge:*`. Os comandos vivem em `.forge/commands/**` e são projetados para os adaptadores.

### 14.1 Bootstrap

| Comando | Objetivo |
|---|---|
| `/forge:init` | instala `.forge`, cria `FORGE.md`, gera `AGENTS.md`, symlinks e adapters; pode rodar em modo interativo (elicitação) |
| `/forge:doctor` | valida stack, ferramentas, hooks, adapters, specs e drift de symlinks |
| `/forge:sync-adapters` | gera/atualiza `AGENTS.md` e `.claude`, `.codex`, `.agents`, `.kiro`, `.qwen` |
| `/forge:status` | mostra estado do harness, specs ativas, baseline e graph |

### 14.2 SDD

| Comando | Objetivo |
|---|---|
| `/forge:spec new` | cria uma nova spec/change ativa |
| `/forge:clarify` | resolve ambiguidades e perguntas abertas (elicitação) |
| `/forge:requirements` | gera/refina requirements ou bugfix analysis (com loop builder→validator) |
| `/forge:design` | gera/refina design técnico (com loop builder→validator) |
| `/forge:tasks` | gera tasks rastreáveis, ordenadas por dependência; pode fatiar em stories |
| `/forge:analyze` | análise cross-artifact: spec/design/tasks/constitution |
| `/forge:implement` | executa tasks/stories com checkpoints |
| `/forge:verify` | valida implementação contra spec (checkpoint review guiado) |
| `/forge:archive` | aplica deltas ao baseline e move para archived |
| `/forge:close` | encerra spec sem atualizar baseline (`abandoned`, `rejected`, `superseded`) |

### 14.3 Brownfield e Grafo

| Comando | Objetivo |
|---|---|
| `/forge:discover` | inventário determinístico do repo |
| `/forge:codegraph` | cria ou reconstrói o grafo |
| `/forge:graph query` | responde com base no grafo |
| `/forge:impact` | análise de impacto de uma spec ou diff |
| `/forge:onboard` | gera mapa de arquitetura/domínio para novos agentes/humanos |
| `/forge:baseline extract` | extrai baseline inicial a partir de código/docs |

### 14.4 Docs e Governança

| Comando | Objetivo |
|---|---|
| `/forge:constitution` | cria/atualiza princípios do projeto |
| `/forge:adr new` | cria ADR em `.forge/product/current/adr/` |
| `/forge:publish-docs` | espelha baseline para `docs/product/` |
| `/forge:backlog` | gera backlog/Jira/GitHub Issues após gate humano |

### 14.5 Dev Loop & Quality (novo na v2)

| Comando | Objetivo |
|---|---|
| `/forge:shard` | fatia tasks/épico em stories auto-contidas com contexto embutido |
| `/forge:skill create` | cria uma skill com entrevista de intenção e frontmatter validado |
| `/forge:skill eval` | avalia uma skill via A/B (com-vs-sem) e produz benchmark |
| `/forge:skill optimize` | otimiza a description da skill por holdout train/test |
| `/forge:eval harness` | meta-avaliação: mede a qualidade de templates/commands do próprio Forge |
| `/forge:wave` | planeja/abre/fecha waves de execução com dependências (sessão longa) |
| `/forge:progress` | mini-report rápido: % do projeto, por módulo/área, infra, e próximo passo lógico |
| `/forge:defer` | registra uma pendência (item bloqueado por dependência) no ledger |
| `/forge:resolve-deferrals` | retoma e fecha as pendências do ledger ao fim do projeto, com teste |
| `/forge:c4` | gera/atualiza diagramas C4 + HTML consolidado (greenfield/feature) |
| `/forge:dev` | sobe/sincroniza o ambiente local Docker (`up`/`sync`/`smoke`) |

### 14.6 Loop builder→validator

Os comandos `/forge:requirements`, `/forge:design` e (opcionalmente) `/forge:tasks` rodam um loop interno de auto-correção com **sinal externo**, inspirado na etapa 7 do BuildPlan do LionClaw e na literatura de self-refine. O builder gera o artefato; o validator produz um relatório estruturado:

```text
## Status: PASS | FAIL
[MISS]     <requisito/seção ausente>
[CONFLICT] <inconsistência entre artefatos>
[CLARIFY]  <ambiguidade que exige decisão humana>
```

Regras: máximo de 3 iterações; se persistir `FAIL` após o limite, escalonar para revisão humana (não insistir). O humano decide o que é real — a literatura e a própria documentação do BMAD alertam que validadores adversariais geram falsos positivos. O loop reduz drift, não substitui julgamento.

---

## 15. Adaptadores por Agente

A fonte primária é `.forge/`. Adaptadores são gerados; nunca editados à mão.

| Agente/Ferramenta | Saída gerada |
|---|---|
| Claude Code | `.claude/commands/forge/*.md`, `.claude/agents/**`, `.claude/skills/**`, `.claude/settings.json` |
| Codex | `AGENTS.md` (já é a interface canônica), `.codex/skills/**` quando aplicável |
| Qwen/Forge CLI | `.agents/commands/**`, `.agents/skills/**`, `QWEN.md -> AGENTS.md` |
| Kiro | `.kiro/steering/forge.md`, hooks quando suportado; **sem** usar `.kiro/specs` como fonte |
| Gemini | `GEMINI.md -> AGENTS.md` e commands/skills conforme suporte |
| Cursor | `.cursor/rules/forge.mdc` com `alwaysApply` |
| VS Code/Copilot | `.github/copilot-instructions.md` ou guidance compatível |
| Cross-tool | `.agents/skills/**` (padrão adotado pelo BMAD v6 e dezenas de plataformas) |

Regras:

- O adaptador nunca é editado manualmente; toda edição ocorre em `.forge/**`.
- `forge sync-adapters` detecta drift e regenera.
- Quando symlink não funcionar, materializar cópia com header de arquivo gerado.
- Cada adaptador registra hashes de origem e destino em `.forge/adapters/<adapter>.lock.yaml`.
- Cada adaptador declara perda de capacidade (ex.: "Kiro steering gerado, mas hooks não instalados"; "Codex recebeu AGENTS.md, mas slash commands nativos não materializados").
- Cada adaptador tem ao menos um smoke test simples: comandos gerados existem, arquivo principal é legível, hooks apontam para paths reais, e nenhum adapter contém paths de outro projeto.

---

## 16. Camada de Entendimento (Brownfield / Graph)

Inspirada em Graphify e Understand Anything. O grafo é o pré-flight de brownfield, feature, bugfix, review e archive.

### 16.1 Inventário determinístico mínimo (antes do graph completo)

Para repos grandes, começar barato: changed files, fingerprints, staleness e affected paths. Só então construir o grafo completo.

### 16.2 Grafo

- AST local/determinístico para código; LLM apenas para semântica (resumos, intenção).
- Armazenado em `.forge/graph/` (`graph.json`, `report.md`, `manifest.json`, `cache/`).
- `query/path/explain` antes de ler arquivos crus.
- Hook de atualização incremental por fingerprint estrutural (zero tokens quando a mudança é cosmética).
- Custo/logs locais fora do commit.

### 16.3 Validação determinística do grafo (`forge validate graph`)

Inspirado em Understand Anything: schema de nodes/edges, integridade referencial, cobertura de camadas, IDs duplicados, nós órfãos, qualidade mínima de summaries, compatibilidade com changed files.

### 16.4 Onboarding e impacto

`/forge:onboard` gera um tour de arquitetura/domínio para novos agentes e humanos. `/forge:impact` roda diff impact antes de tasks e antes de archive. Um "graph reviewer" opcional age como gate para brownfield grande.

### 16.5 Diagramas C4 e HTML consolidado (greenfield e feature)

Em greenfield e em features novas, a Understanding Layer deve **produzir**, não só consumir, entendimento. O Forge gera diagramas C4 e um arquivo HTML consolidado que serve de mapa navegável do que está sendo construído.

- **Diagramas C4** (Context, Container, Component; Code opcional) gerados como Mermaid em `.forge/graph/c4/` (`c1-context.mmd`, `c2-container.mmd`, `c3-component-<module>.mmd`). Em greenfield, derivam do design (`design.md`, contratos, data-model); em feature, são atualizados de forma incremental para os módulos afetados. Respeitam a convenção de **não usar pontos dentro de labels Mermaid**.
- **HTML consolidado** (`.forge/graph/overview.html`, com cópia opcional em `docs/product/`): um único arquivo navegável que reúne os diagramas C4 renderizados, o índice de capabilities do baseline, o estado das waves/progresso da mudança ativa e os links para os artefatos da spec. É o "raio-x" do projeto para humanos — útil em onboarding, revisão e handoff.

Comando: `/forge:c4` gera/atualiza os diagramas e o HTML. Em greenfield roda após `/forge:design`; em feature, após `/forge:design` ou `/forge:tasks` para os módulos tocados. O HTML é gerado por um script determinístico (Mermaid + template), sem custo de tokens além da curadoria do conteúdo. Atende ao requisito de ter, ao fim, um artefato consolidado que mostra a arquitetura inteira de forma visual.

---

## 17. Camada de Dev Loop & Quality (núcleo da v2)

Esta é a principal evolução sobre o plano v1. Combina a execução de longa duração do BMAD v6 com o rigor de avaliação do skill-creator da Anthropic (via LionClaw).

### 17.1 Dev Loop — story sharding com contexto embutido

O problema: implementações longas estouram a janela de contexto; o agente perde o fio. A solução (BMAD v6): fatiar o épico/tasks em **stories auto-contidas**, cada uma carregando o contexto específico que o agente precisa para implementá-la — trechos relevantes de requirements, design e contratos —, em vez de depender de o agente reler tudo.

Fluxo:

1. `/forge:shard` lê `tasks.md` (e design/requirements) e gera `stories/` no change ativo.
2. Um sub-agente compila o **contexto de épico** uma vez no início (`epic_context_compiled: true` no manifest).
3. Cada story em `stories/` é um arquivo auto-contido com: objetivo, contexto embutido (referências + trechos), critérios de aceite como checklist, e dependências.
4. `/forge:implement` executa story por story, com checkpoint review (`/forge:verify`) ao final de cada uma.

Template de story (`.forge/templates/story/STORY.md`, em inglês):

```markdown
---
story_id: <change-id>-S03
epic: <change-id>
depends_on: [<change-id>-S01]
status: ready          # ready | in-progress | done | blocked
---
# <Story title>

## Goal
<one paragraph, behavior-focused>

## Embedded context
<relevant excerpts from requirements.md / design.md / contracts/, with refs>

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Out of scope
<what this story must NOT touch>
```

Isso é o "super-prompt" modular que o paper de SDD descreve, agora operacionalizado.

### 17.2 Orquestração de sessões longas (waves)

Para tarefas de horas — planejar um software complexo inteiro, implementar um módulo completo — o Forge organiza a execução em **waves** (ondas), absorvendo o mecanismo provado do Qwen v6.5 e adaptando-o ao lifecycle do Forge. Uma wave é um grupo de stories que pode ser executado quando suas dependências estão satisfeitas. As waves vivem em `waves.json` (seção 10.11), na pasta do change ativo.

Princípios da orquestração:

- **Dependências explícitas.** Cada wave declara `depends_on` (índices de waves anteriores). O Forge nunca abre uma wave cujas dependências não estão `done` ou cujos itens pendentes não foram registrados no ledger (seção 17.4).
- **Ordem canônica de fundação.** A Wave 0 é sempre fundação: tipos compartilhados, contratos, manifest de dependências instalado de uma vez. Isso evita a cascata de erros de import que o Qwen documentou (Classe B/C).
- **Smoke incremental cedo.** Toda wave que "sobe a stack" (auth, DB, integração externa) carrega seu próprio smoke, executado pelo workflow. Sem isso, bugs sutis acumulam por várias waves antes de aparecer (lição do Qwen: "smoke cedo > smoke tarde").
- **Autopilot entre waves.** O orquestrador avança de uma wave para a próxima sem confirmação intermediária, parando voluntariamente apenas quando o progresso chega a `DONE` ou quando um gate HITL é atingido (seção 12.1).
- **Fechamento com gate.** Uma wave só fecha quando todas as suas stories estão `done`, os gates deterministas passam e — se for a última wave — a Sprint Review Final (revisão categorizada) roda com zero findings HIGH.

Comando: `/forge:wave plan|open|close|status`. O `plan` deriva as waves de `tasks.md`/`stories/`; `open`/`close` avançam o ponteiro de progresso; `status` mostra o estado sem reler os JSONs.

### 17.3 Progress tracking e mini-report

O estado de progresso vive em `progress.json` (seção 10.11) e é atualizado por script determinístico a cada feature/story concluída — nunca pelo modelo relendo arquivos. O comando `/forge:progress` responde de forma **curta e objetiva**, exatamente como pedido: percentual do projeto inteiro, por módulo/área e por infraestrutura, e já aponta o próximo passo lógico.

Formato de saída do `/forge:progress` (exemplo):

```text
PROGRESSO — add-card-tokenization
Projeto:        36%  (5/14 stories)
Módulo A (tok): 29%  (2/7)
Módulo B (api): 50%  (3/6)  [bloqueado: 1 pendência]
Infra:          75%  (3/4)
Wave atual:     Wave 1 — DB layer (in-progress)
Pendências:     1 aberta (DEF-001, aguarda S12 na Wave 3)
Próximo passo:  implementar S06 (POST /tokens) ao fechar a Wave 1
```

Regra de ouro: o mini-report nunca despeja JSON nem relê o histórico no chat; é uma leitura agregada de `progress.json` + `deferrals.json`. Responde em segundos e cabe em poucas linhas.

### 17.4 Ledger de pendências (deferral ledger)

Este é o mecanismo que impede **gaps silenciosos** no projeto — o cenário que você descreveu: um módulo/feature fica incompleto porque depende de algo ainda não implementado, e isso se perde, virando bug no fim. O ledger (`deferrals.json`, seção 10.11) torna toda pendência explícita e rastreável.

Como funciona:

1. **Registro.** Quando uma story não pode ser concluída por depender de algo de outra wave/módulo ainda não pronto, o agente **não** improvisa nem deixa um TODO solto: registra um item no ledger via `/forge:defer` com `raised_in` (onde surgiu), `blocks` (o que ficou incompleto), `reason`, `depends_on` (o que falta) e `status: open`.
2. **Continuidade.** A story segue até onde é possível (stub explícito, interface definida), e o ledger garante que o pedaço faltante não some. O changelog da implementação (`product/current/CHANGELOG.md` e o log da wave) referencia o item.
3. **Resolução obrigatória no fim.** O projeto **não conclui** (não chega a `DONE`) com pendências `open`. O comando `/forge:resolve-deferrals` percorre o ledger, implementa cada item agora que sua dependência existe, e o marca `resolved`.
4. **Teste obrigatório.** Cada pendência resolvida é testada (smoke/teste dedicado) e passa a `tested`. Só com o ledger 100% `tested` o Forge libera o encerramento.

Isso fecha o loop que você apontou: nenhuma dependência cruzada vira gap permanente; tudo que foi adiado por falta de outra implementação é retomado, implementado e testado antes do fim.

### 17.5 Gates deterministas por feature

Cada feature/story passa por gates deterministas (scripts que retornam uma linha `OK`/`FAIL`), portados do Qwen v6.5 e generalizados para a stack de Milton (.NET/Go/TypeScript/React). Eles complementam os loops builder→validator (probabilísticos) com checagens objetivas e baratas:

- **Parseabilidade** do arquivo gerado (parser nativo do formato).
- **Import-resolve:** todo import aponta para arquivo/símbolo existente (Classe B do Qwen).
- **Unused:** sem imports/vars não usados (Classe C; em .NET/TS strict).
- **Grep positivo (OR cross-file):** cada padrão obrigatório aparece em ao menos um dos arquivos-alvo.
- **Grep negativo (NOT cross-file):** nenhum padrão proibido aparece (sem `TODO`/`FIXME`/`not implemented` residuais, sem em-dash em labels Mermaid, sem debug).
- **Consistency cross-file:** símbolo usado de forma consistente entre arquivos (Classe A: factory vs middleware, etc.).
- **Smoke executado pelo workflow** (não pelo modelo), com timeout e exit code esperado — anti auto-mentira.

Todo comando externo roda com `timeout`; a saída bruta vai para arquivo e só o `tail -20` é lido — disciplina anti-context-overflow.

### 17.6 Disciplina de autopilot e economia de contexto

A maior ameaça a uma sessão de horas é o **estouro de contexto** (Classe G do Qwen: 85%+ da janela degrada o modelo e pode travar). O Forge adota as regras que evitam isso:

- Output entre features é mínimo: um cabeçalho de início, o self-review, um cabeçalho de fim.
- Progresso não é resumido a cada wave — só no encerramento (ou sob demanda via `/forge:progress`).
- Nenhum dump de grep ou heredoc no chat; gates retornam uma linha; output bruto vai para `/tmp` + `tail`.
- Orçamento de contexto monitorado: ao passar do limite, pausar e compactar antes de gerar mais.
- O orquestrador **delega contexto** a scripts/skills especialistas (próxima seção) em vez de reler artefatos inteiros.

### 17.7 Skills especialistas (estratégia de economia de contexto)

Para sessões longas, manter o agente orquestrador enxuto é decisivo. A estratégia: **encapsular conhecimento e operações em skills muito especialistas**, que o orquestrador invoca e das quais recebe apenas o mínimo necessário — em vez de carregar tudo no próprio contexto. É o mesmo princípio do `feat-context.py` do Qwen (um comando entrega exatamente o contexto de uma feature e proíbe ler fora do range).

Diretrizes para skills especialistas no Forge:

- **Entrada/saída estreitas.** A skill recebe um alvo (uma story, um arquivo, um módulo) e retorna um resultado compacto e estruturado (uma linha de status, um JSON pequeno, um trecho no range exato). Nunca devolve o artefato inteiro.
- **Determinismo onde possível.** Operações mecânicas (extrair contexto de uma story, validar frontmatter, montar o diff de impacto, gerar o mini-report) são scripts, não prompts — custo de token quase nulo e resultado reprodutível.
- **Progressive disclosure.** Metadados da skill (name + description) ficam sempre no contexto (~100 tokens); o corpo e os recursos só são lidos quando a skill é acionada.
- **Catálogo inicial sugerido:** `story-context` (contexto de uma story no range exato), `impact-scan` (diff impact de uma mudança), `progress-report` (lê `progress.json`/`deferrals.json` e emite o mini-report), `wave-advance` (fecha story/wave e avança o ponteiro), `gate-runner` (roda os gates deterministas e retorna uma linha), `c4-render` (gera C4 + HTML). Cada uma é avaliável pelo eval harness (seção 17.8), inclusive quanto ao quanto de contexto economiza.

O efeito combinado: o orquestrador coordena; as skills especialistas carregam o peso cognitivo e devolvem migalhas. É isso que torna viável planejar/implementar por horas sem degradar.

### 17.8 Quality — eval harness quantitativo

O ativo mais diferenciado do Forge. Avalia **skills, commands e templates** com método A/B, algo que nenhum concorrente SDD tem. Tudo é opt-in (`quality.enabled`).

#### 17.8.1 Agentes de qualidade

Quatro agentes especializados em `.forge/agents/quality/`, com outputs JSON schematizados (padrão do skill-creator da Anthropic):

- **executor** — roda o artefato (skill/command/template) contra um prompt de teste via runner configurável; captura saída, tokens e tempo.
- **grader** — avalia as expectations contra a saída/transcript, com evidências (`grading.json`: `text`/`passed`/`evidence`).
- **comparator** — comparação cega A/B (não sabe qual configuração produziu cada saída).
- **analyzer** — análise pós-hoc dos resultados agregados; surfaceia padrões que a média esconde.

#### 17.8.2 Fluxo de avaliação de uma skill

```text
/forge:skill create      # entrevista de intenção -> SKILL.md com frontmatter validado
/forge:skill eval        # runs A/B (with-skill vs baseline) -> grading -> benchmark
/forge:skill optimize    # holdout train/test da description -> melhor por test score
```

A avaliação roda, para cada caso de teste, duas execuções via runner: uma **com** o artefato e uma **baseline** (sem). O grader avalia ambas; a agregação produz `mean ± stddev` e **deltas** de pass-rate, tempo e tokens. Um eval-viewer HTML opcional exibe os outputs e coleta feedback humano (`feedback.json`). Onde o runner não suporta paralelismo, as execuções são seriais.

#### 17.8.3 Otimização de triggering (holdout train/test)

A description de uma skill é o que decide se ela dispara. O `/forge:skill optimize` faz split 60/40 (train/test), itera melhorias na description e **seleciona a melhor pela pontuação de teste**, não de treino — anti-overfitting. Respeita o limite de 1024 caracteres. É a feature mais única do LionClaw e não existe em nenhum outro framework SDD.

#### 17.8.4 Estrutura de evals

```text
.forge/evals/
├── skills/
│   └── <skill>/
│       ├── evals.json              # prompts de teste (+ expectations)
│       └── workspace/
│           └── iteration-N/
│               └── eval-K/
│                   ├── with_skill/outputs/
│                   ├── without_skill/outputs/
│                   ├── grading.json
│                   └── timing.json
├── commands/
│   └── <command>/...
└── meta/                            # meta-avaliação do harness
```

#### 17.8.5 Proveniência, contratos e benchmarks canônicos (aprendizado DeepSpec)

O DeepSpec não é um harness SDD; é uma pipeline de treino/avaliação. O que o Forge absorve dele é disciplina operacional:

- **`run-manifest/v1`** registra stage, runner, orçamento, comandos, inputs/outputs com hashes e proveniência Git segura (branch, SHA, dirty files, diff stat e hash do diff). O diff bruto nunca é persistido.
- **Contratos de estágio** em `.forge/contracts/stages/*.yaml` declaram inputs, outputs, validadores, classe de orçamento e se evidência é obrigatória.
- **Benchmark registry** em `.forge/evals/benchmarks/` mantém casos canônicos pequenos para comparar mudanças do harness entre versões.
- **Budget preflight** emite uma linha antes de rodadas caras: perfil, runner, runs, timeout estimado, outputs esperados e uso de LLM/subagente.

Esses artefatos reforçam auditabilidade sem criar uma metodologia paralela: `spec`, `verify`, `archive` e `eval` continuam sendo o ciclo principal.

### 17.9 Princípio de cautela

O eval rigoroso é caro (tokens e tempo). Por isso é **opt-in** e nunca default. O default permanece `spec-anchored` com Quick Plan para casos simples. O plano v1 já alertava contra "acumular processo demais" — a v2 preserva esse alerta tratando toda a Camada 5 como capacidade avançada, não obrigatória.

---

## 18. Meta-avaliação do Harness (diferencial estratégico)

O eval harness não precisa avaliar só skills. Pode avaliar **os próprios templates, commands e rules do Forge** — rodar `/forge:requirements` com e sem um template, e medir a qualidade do artefato resultante via grader. Nenhum concorrente SDD (BMAD, Spec Kit, OpenSpec, Kiro) faz benchmark quantitativo dos próprios artefatos.

Implicações:

- `.forge/evals/meta/` é diretório de primeira classe.
- O Forge pode provar, com números, que uma mudança em um template melhora (ou piora) os artefatos gerados — antes de propagá-la para o time.
- Isso transforma a evolução do harness de "opinião" em "evidência", exatamente o que torna o fluxo confiável e replicável para toda a equipe.

Caso de uso concreto para Milton: ao padronizar FRD/épicos em Markdown estrito, medir se o novo template realmente reduz `[MISS]`/`[CONFLICT]` no validador, em vez de assumir.

---

## 19. Validadores Deterministas

O Forge precisa de validadores deterministas, não apenas agentes revisores. Eles complementam os loops builder→validator (que são probabilísticos) com checagens objetivas e reprodutíveis.

### 19.1 `forge validate harness`

- `.forge/FORGE.md` existe.
- `AGENTS.md` é projeção válida de `FORGE.md`; `CLAUDE.md`/`QWEN.md`/`GEMINI.md` apontam para `AGENTS.md` ou são cópias geradas.
- `.forge/forge.yaml` válido.
- adapters instalados batem com o manifest.
- paths antigos `.claude` hardcoded não vazam na fonte canônica.
- lockfiles de adaptadores batem com os hashes de `.forge/**`.
- smoke tests dos adaptadores passam.

### 19.2 `forge validate spec <change-id>`

- manifest válido; artefatos exigidos pelo tipo e pelo nível scale.
- headings obrigatórios; requirements com cenários/testabilidade; sem placeholders; status coerente; traceability coerente.
- `spec-delta.yaml` válido quando a spec pretende atualizar baseline.

### 19.3 `forge validate archive <change-id>`

- estado atual é `verified`; `spec-delta.yaml`, `approvals.yaml`, `verification.yaml` presentes e válidos.
- baseline resultante válido antes de gravar.
- ausência de mudança em `docs/product/` sem origem em `.forge/product/current`.

### 19.4 `forge validate frontmatter <path>`

Porta o `validate-frontmatter.sh` do LionClaw. Impõe os limites do spec aberto Agent Skills: `name` ≤ 64 caracteres (lowercase + hífens), `description` ≤ 1024 caracteres e sem tags XML, corpo idealmente < 500 linhas. Usado em skills e em commands com frontmatter.

### 19.5 `forge validate graph`

Schema de nodes/edges, integridade referencial, cobertura de camadas, IDs duplicados, nós órfãos, qualidade mínima de summaries, compatibilidade com changed files.

---

## 20. Política de Git, Fluxo de Branches e CI/CD

O Forge separa artefatos commitáveis de artefatos locais. Regra inicial:

| Caminho | Commitar? | Motivo |
|---|---|---|
| `.forge/FORGE.md` | Sim | Fonte de política do projeto |
| `.forge/forge.yaml` | Sim | Manifesto do harness |
| `.forge/context.md`, `.forge/constitution.md` | Sim | Contexto e princípios versionados |
| `.forge/rules`, `agents`, `commands`, `skills`, `hooks`, `scripts`, `schemas`, `templates` | Sim | Harness versionado |
| `.forge/custom/**` | Sim | Overrides do repo |
| `.forge/specs/active/**` | Sim, quando a spec for trabalho de time | Planejamento rastreável |
| `.forge/specs/archived/**` | Sim | Histórico e auditoria |
| `.forge/product/current/**` | Sim | Baseline vigente |
| `.forge/product/published/**` | Sim, se usado para handoff | Docs publicadas |
| `.forge/graph/graph.json` | Sim em brownfield relevante (Git LFS se grande) | Mapa compartilhado |
| `.forge/graph/report.md` | Sim | Onboarding e contexto |
| `.forge/graph/cache/**` | Não por default | Cache local |
| `.forge/evals/**/workspace/**` | Depende | Outputs textuais seguros sim; volumosos fora |
| `.forge/**/cost*.json`, `telemetry*`, `tmp/**`, `logs/**` | Não | Dados locais, volume ou custo |
| `.forge/specs/active/**/evidence/**` | Depende | Só evidências textuais seguras; outputs volumosos fora |
| `.forge/worktrees/**` | Não | Worktrees são checkouts locais de branches, não artefatos versionáveis; removidas após merge |

`/forge:init` aplica patch no `.gitignore` para os paths locais e nunca adiciona segredos ou outputs volumosos automaticamente.

### 20.1 Fluxo de branches e PRs

O Forge adota um fluxo enxuto centrado na branch `develop`, desenhado para **minimizar consumo de CI/CD** (créditos do GitHub Actions esgotam rápido quando a pipeline roda a cada push de branch de trabalho).

```text
feature/<change-id>  ──PR──▶  develop  ──(CI roda aqui, 1x)──▶  staging  ──▶  (futuro) main/prod
   │                            │                                  │
   trabalho do agente           integração + review               ambiente staging
   (commits frequentes,         (merge após aprovação HITL)        (deploy após pipeline verde)
    sem CI)
```

- **Branch de trabalho:** cada mudança vive em `feature/<change-id>` (ou `bugfix/`, `refactor/`). Commits frequentes e pequenos, **sem disparar pipeline**.
- **PR sempre para `develop`:** ao concluir e verificar localmente, abre-se PR da branch de trabalho para `develop`. O review acontece aqui (humano + checks locais/baratos).
- **Merge para `develop`:** após aprovação (gate HITL via `AskUserQuestion`, seção 12.1), faz-se o merge. `develop` é a integração contínua de baixo custo.
- **Promoção para `staging`:** a pipeline pesada (GitHub Actions) roda **uma vez**, ao promover `develop → staging`, não a cada branch. `staging` é o ambiente validado.

### 20.2 CI/CD econômico (rodar pipeline só após `develop`)

A decisão de custo: **não rodar GitHub Actions em pushes de branch de trabalho nem em todo PR.** Os checks baratos rodam localmente (hooks + gates deterministas), e a pipeline cara roda apenas na promoção de `develop` para `staging`.

- **Localmente / pré-merge (custo zero de Actions):** typecheck, lint, testes unitários, gates do Forge (parseabilidade, import-resolve, grep gates, consistency) e smoke incremental. Rodados por hooks de pre-commit/pre-push e pelos gates de `/forge:verify`.
- **GitHub Actions (custo real, 1x):** dispara **apenas** em push para `staging` (resultante da promoção). Pipeline completa: build, suíte integrada, contract tests, security scan e deploy para staging.
- **Configuração:** o workflow usa `on: push: branches: [staging]` (e opcionalmente `workflow_dispatch` para disparo manual), evitando `on: pull_request` e `on: push` em `develop`/branches de trabalho.

```yaml
# .github/workflows/staging.yml (gerado por /forge:init)
name: staging-pipeline
on:
  push:
    branches: [staging]
  workflow_dispatch: {}
jobs:
  verify-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: "# build + test + contract + scan + deploy staging"
```

Trade-off explícito: rodar CI só em `staging` economiza créditos, mas atrasa a detecção de quebras de integração até a promoção. Mitigação: os gates locais do Forge (rodados a cada feature/wave) e o smoke incremental por wave pegam a maioria dos problemas **antes** do merge em `develop`, mantendo `develop` sempre integrável. Para mudanças de alto risco (scale ≥ 3) ou de contrato, o Forge recomenda um disparo manual (`workflow_dispatch`) antes da promoção.

### 20.3 Sync com ambiente local (Docker Desktop)

O ambiente de desenvolvimento padrão é **Docker Desktop**. O Forge mantém o local sincronizado com o estado da mudança:

- `docker-compose.yml` (ou `compose.yaml`) como definição canônica dos serviços locais (app, PostgreSQL, RabbitMQ, etc., conforme a stack).
- `/forge:dev up` sobe o ambiente; `/forge:dev sync` reconcilia migrations/seeds com o estado atual da branch; `/forge:dev smoke` roda o smoke local.
- Antes de abrir PR para `develop`, o fluxo valida que o ambiente Docker sobe limpo e o smoke passa — substituindo boa parte do que a CI faria, sem gastar Actions.

### 20.4 Hooks e direcionadores (instrumentação)

O Forge instala hooks (Git + harness) que tornam o fluxo automático e barato:

| Hook / direcionador | Quando dispara | O que faz |
|---|---|---|
| `pre-commit` | antes do commit | gates rápidos: parseabilidade, Unicode (anti em-dash), anti-debug, lint dos arquivos staged. Output de 1 linha. |
| `pre-push` | antes do push da branch de trabalho | typecheck + testes unitários + gates import-resolve/consistency. Bloqueia push se falhar. |
| `prepare-pr` (direcionador) | ao rodar `/forge:verify` com sucesso | gera descrição do PR a partir de `requirements.md`/`tasks.md`, garante alvo `develop`, anexa evidências de `verification.yaml`. **Não abre o PR sozinho** sem confirmação. |
| `post-merge` (em `develop`) | após merge na develop | atualiza ponteiro de progresso, registra no changelog, **remove a worktree da branch mergeada** (`git worktree remove` + `git worktree prune`) e sugere se já é hora de promover para `staging`. |
| `promote-staging` (direcionador) | decisão humana (HITL) | faz `develop → staging` e deixa o push para `staging` disparar a única pipeline cara. |
| `worktree-guard` | ao criar worktree / em `pre-commit` | garante que toda worktree seja criada **dentro do projeto**, em `.forge/worktrees/<change-id>/`; bloqueia criação fora desse padrão e impede commit a partir de worktree órfã. |

Princípio: hooks e gates locais carregam o peso da verificação; o GitHub Actions é reservado para o que só faz sentido em ambiente limpo e controlado (deploy de staging). Isso resolve diretamente o esgotamento de créditos sem abrir mão de qualidade.

**Padronização de worktrees.** Toda worktree vive em `.forge/worktrees/<change-id>/` — dentro do diretório do projeto, nunca em caminho externo ou em temporário do sistema. Isso mantém o trabalho isolado por mudança, previsível e visível ao `forge doctor`. O `worktree-guard` recusa qualquer worktree criada fora desse padrão. **Cleanup após merge é obrigatório:** assim que a branch de uma mudança é mergeada em `develop`, o `post-merge` remove a worktree correspondente (`git worktree remove .forge/worktrees/<change-id>`) e roda `git worktree prune` para limpar referências mortas. O `forge doctor` sinaliza worktrees órfãs (mergeadas mas não removidas, ou presentes sem branch ativa) como drift a corrigir. O conteúdo de `.forge/worktrees/` não é versionado (ver tabela de ignore na seção 20).

---

## 21. Convenções e Padrões (cross-project)

O Forge incorpora as convenções já consolidadas por Milton, aplicáveis a todos os projetos:

- **Nomes de repositório** não embutem tecnologia (ex.: `RoleRepository`, não `PostgresRoleRepository`; a tecnologia vai no campo de descrição).
- **"Objeto de Valor"** sempre por extenso — nunca abreviado.
- **Nomes de campos** em stories/models sempre em inglês.
- **Métricas** referenciadas genericamente (ex.: "Métricas", não "Métricas Prometheus").
- **Sem pontos** dentro de labels de diagrama Mermaid.
- **Dinheiro** armazenado como inteiro em centavos; **Split Management** segue NBR 5891 para arredondamento monetário.
- **Isolamento multi-tenant** em Axis Payments PostgreSQL via campo `tenant_id` (não schema nem RLS).
- **EF Core** para persistência PostgreSQL no Access Control.
- **SettlementPolicy (Objeto de Valor)** com campos `settlement_frequency`, `settlement_day`, `min_balance_retention`, `auto_advance_enabled`, `advance_minimum_amount`, `settlement_account_id`; a entidade Tenant expõe `UpdateSettlementPolicy()` gerando o evento de domínio `SettlementPolicyUpdated`.
- **Specification Pattern** na camada de domínio de Settlement Policy (`IsEligibleForSettlementTodaySpec`, `HasMinimumBalanceForAdvanceSpec`).
- **Descrições de story** seguem o modelo do épico Seller Management: linguagem clara, critérios de aceite como checklist, sem nomes de tecnologia em entidades/campos.
- **Documentos FRD** seguem estrutura rígida com seções obrigatórias, regras de nomenclatura e Markdown puro.
- **Template de épico** com seções: 📌 Épico, 🎯 Objetivo, 🔗 Dependências Técnicas, 🧩 Estrutura de Persistência.
- **Controle de versão de documento** (Collatra): formato bullet `NOME - DATA - DESCRIÇÃO`.
- **TSP = Token Service Provider** (não Terminal Service Provider) no contexto de pagamentos.
- **Arquivos de instrução LLM e convenções arquiteturais em inglês** (eficiência de tokens); templates de saída e terminologia regulatória brasileira em português; a convenção "Objeto de Valor" preservada em PT-BR.

O Forge codifica essas convenções como rules em `.forge/rules/`, no meta-padrão recomendado (variáveis configuráveis + anti-padrões com o "porquê" + checklist final), e os validadores deterministas as fazem cumprir onde forem objetivas.

---

## 22. Migração do `/init-project` Atual

### 22.1 Fase 0 — Congelar snapshot

- Copiar o template atual para um branch/dir de referência.
- Inventariar todos os paths `.claude/**`, `docs/product/**`, `AGENTS.md`.
- Criar teste de snapshot para garantir que nada se perde.
- Definir contrato de compatibilidade do adapter Claude: mesmos comandos visíveis, mesmo comportamento de `doctor.sh`, hook de worktree continua bloqueando paths errados, wrappers temporários para paths antigos quando necessário, teste real em Claude Code antes de remover qualquer fonte `.claude` legada.

### 22.2 Fase 1 — Criar `.forge` canônico

- Mover a fonte de `AGENTS.md` para `.forge/FORGE.md`.
- Criar `.forge/forge.yaml` e `.forge/context.md`.
- Mover `.claude/rules`, `agents`, `commands`, `skills`, `hooks` e `scripts/doctor.sh` para `.forge/`.

### 22.3 Fase 2 — Gerar adaptador Claude

- Criar `forge sync-adapters --adapter claude`.
- Gerar `.claude/**` a partir de `.forge/**`.
- Garantir que o Claude continue vendo os mesmos commands/agents.
- Trocar hardcodes `.claude/rules` por referências relativas adaptadas.

### 22.4 Fase 3 — Gerar AGENTS.md + adaptadores Codex/Qwen/Forge CLI

- Gerar `AGENTS.md` como projeção de `FORGE.md`; criar symlinks `CLAUDE.md`/`QWEN.md`/`GEMINI.md → AGENTS.md`.
- Codex: garantir `AGENTS.md`; gerar skills/commands se suportado.
- Qwen/Forge CLI: usar `.agents/commands` e `.agents/skills`.
- Kiro: gerar steering, não specs.

### 22.5 Fase 4 — Lifecycle active/archive

- Criar `.forge/specs/active` e `.forge/specs/archived`.
- Criar manifests e schemas.
- Criar `/forge:spec new`, `/forge:verify`, `/forge:close`.
- Migrar `run-spec-pipeline` para criar change ativo.

### 22.6 Fase 5 — Baseline de produto

- Migrar `docs/product/` para `.forge/product/current/` como fonte; criar `/forge:publish-docs` para espelhar de volta.
- Para repos existentes, ingerir `docs/product/` sem apagar nada.
- Criar `baseline-capability.schema.json`, `spec-delta.schema.json`, `traceability.schema.json`, `approvals.yaml`, `verification.yaml`.
- Criar `/forge:archive` apenas depois de delta apply e baseline validation existirem.

### 22.7 Fase 6 — Brownfield graph

- Criar inventário determinístico mínimo antes do graph completo.
- Criar `/forge:graph build/query/update` e `/forge:impact`.
- Integrar Graphify ou implementar subset local (AST + LLM) conforme critério técnico: dependência Python, privacidade, custo, linguagens suportadas, schema, cache e facilidade de adapter.
- Guardar graph em `.forge/graph/`; usar `/forge:impact` antes de design/tasks/archive.

### 22.8 Fase 7 — Dev Loop & Quality

- Introduzir story sharding (`/forge:shard`, template de story, compilação de contexto de épico).
- Introduzir loops builder→validator em `/forge:requirements` e `/forge:design`.
- Introduzir o eval harness (`/forge:skill create|eval|optimize`, runners.yaml, agentes de qualidade) como opt-in.
- Habilitar meta-avaliação (`.forge/evals/meta/`).

### 22.9 Fase 8 — Qualidade e testes do harness

- Fixtures de greenfield, brownfield e feature-only.
- Testar init sem repo git; init em repo existente sem sobrescrever; symlink e fallback copy; archive com tasks incompletas; archive aplicando deltas ao baseline; sync adapters e drift detection.

---

## 23. MVPs

O MVP deve ser pequeno o suficiente para entregar valor sem reescrever tudo. A v2 mantém os quatro MVPs do v1 e adiciona o MVP5.

### 23.1 MVP1 — `.forge` canônico + compatibilidade Claude

- `.forge/FORGE.md`, `.forge/forge.yaml`, `.forge/context.md`.
- `AGENTS.md` gerado; `CLAUDE.md`/`QWEN.md`/`GEMINI.md` symlinkando para `AGENTS.md`.
- `.forge/rules`, `agents`, `commands`, `skills`, `hooks`, `scripts`.
- `forge sync-adapters --adapter claude`.
- `/forge:init`, `/forge:doctor`.
- `.gitignore` patch para caches, logs, tmp, cost e evidence volumosa.
- contrato e smoke test do adapter Claude.

### 23.2 MVP2 — Spec lifecycle

- `.forge/specs/active/<change-id>/manifest.yaml` (com `scale` e `dev_loop`).
- `/forge:spec new --mode greenfield|brownfield|feature|bugfix|refactor`.
- `/forge:requirements` e `/forge:design` **com loop builder→validator**.
- `/forge:tasks`, `/forge:verify`.
- `/forge:close` para `abandoned|rejected|superseded` (sem atualizar baseline).
- inventário brownfield mínimo: changed files, fingerprints e affected paths.

### 23.3 MVP3 — Baseline + schemas + archive

- `.forge/product/current/capabilities/**`.
- `traceability.yaml`, `spec-delta.schema.json`, `baseline-capability.schema.json`, `archive-state-machine.schema.json`, `approvals.yaml`, `verification.yaml`.
- validadores deterministas (`validate harness`, `validate spec`, `validate archive`, `validate frontmatter`).
- `/forge:archive` com delta apply real, baseline validation e move para archived.

### 23.4 MVP4 — Brownfield graph

- brownfield graph (`.forge/graph/`).
- `/forge:discover`, `/forge:graph build/query/update`, `/forge:impact`, `/forge:onboard`.
- `forge validate graph`.

### 23.5 MVP5 — Dev Loop & Quality (novo na v2)

- story sharding: `/forge:shard`, template de story, compilação de contexto de épico.
- eval harness opt-in: `/forge:skill create|eval|optimize`, `runners.yaml`, agentes de qualidade (executor/grader/comparator/analyzer), `grading.schema.json`.
- otimização de triggering por holdout train/test.
- meta-avaliação do harness (`.forge/evals/meta/`).

---

## 24. Backlog de Implementação

1. Criar a spec do Forge Harness em `.forge/specs/active/create-forge-project-harness/`.
2. Escrever o template `FORGE.md` e o template `AGENTS.md` (projeção).
3. Escrever `forge.yaml`, `context.md` e os schemas.
4. Criar o script `sync-adapters` (gera AGENTS.md + symlinks + adapter Claude).
5. Criar o adaptador Claude preservando o comportamento atual (snapshot/contrato).
6. Criar os adaptadores Codex/Qwen/Forge CLI e o `.agents/skills/`.
7. Migrar os commands atuais para o namespace `/forge:*`.
8. Migrar agents/rules/skills/hooks para `.forge`.
9. Implementar spec manifest e lifecycle (com `scale`).
10. Implementar `/forge:close` (abandoned/rejected/superseded) sem atualizar baseline.
11. Implementar baseline em `.forge/product/current`.
12. Implementar schemas de delta, capability, traceability e state machine.
13. Implementar archive com delta apply, validação prévia do baseline e move.
14. Implementar publish para `docs/product`.
15. Integrar inventário brownfield mínimo; depois graph/impact completo.
16. Implementar `/forge:shard`, template de story e compilação de contexto de épico.
17. Implementar loops builder→validator em `/forge:requirements` e `/forge:design`.
18. Implementar o eval harness (runners.yaml + agentes de qualidade + grading) opt-in.
19. Habilitar meta-avaliação do harness.
20. Adicionar testes de init, sync, validate, close, archive, shard, eval e adapter smoke.
21. Rodar piloto em um repo pequeno; depois em brownfield real.
22. Atualizar o template global `/init-project` para delegar ao Forge.

---

## 25. Riscos e Mitigações

| Risco | Impacto | Mitigação |
|---|---|---|
| Quebrar compatibilidade com Claude Code | Alto | primeiro adapter reproduz `.claude/**` atual por snapshot e contrato |
| Dot-folder reduzir visibilidade humana | Médio | `forge publish-docs` para `docs/product/` |
| Symlink não aceito por alguma ferramenta | Médio | fallback de cópia materializada com header e hash de origem |
| Archive aplicado cedo demais | Alto | default: archive somente após implementação verificada |
| Markdown livre gerar interpretação divergente | Alto | manifests/schemas/validators deterministas |
| Graph ficar stale | Médio | hook incremental + `forge doctor` avisa staleness |
| Acumular processo demais | Médio | níveis scale-adaptive, Quick Plan e eval harness opt-in |
| Nome `forge` conflitar com CLI existente | Médio | tratar o harness como camada de projeto do Forge CLI, não produto separado |
| Eval harness caro (tokens/tempo) | Médio | opt-in; degradação graciosa quando não há paralelismo; rodar só onde agrega |
| Runner não-agnóstico se amarrar a uma ferramenta | Médio | `runners.yaml` abstrai o executor; se inviável manter ≥3 agentes, reduzir escopo a Claude Code |
| Validador adversarial gerar falsos positivos | Médio | humano decide o que é real; max 3 iterações; `[CLARIFY]` escala decisão |
| Story sharding fragmentar contexto em excesso | Baixo | compilação de contexto de épico + dependências explícitas entre stories |

---

## 26. Decisões Recomendadas

1. **Nome e raiz:** adotar `Forge Project Harness`, raiz `.forge/`.
2. **Fonte principal:** `.forge/FORGE.md` (rica).
3. **Interface canônica:** `AGENTS.md` na raiz, **gerado** a partir do `FORGE.md`; `CLAUDE.md`/`QWEN.md`/`GEMINI.md` symlinkam para `AGENTS.md`. *(Altera a decisão #3 do v1.)*
4. **Contexto separado:** `.forge/context.md` para stack/convenções; `FORGE.md` focado em governança.
5. **Fonte de specs:** `.forge/specs` e `.forge/product/current`.
6. **Publicação humana:** `docs/product/` opcional e gerado.
7. **Default SDD:** `spec-anchored`; níveis scale-adaptive (0..4) formalizam o Quick Plan.
8. **Archive:** após implementação verificada, salvo override explícito.
9. **Brownfield:** graph/impact como parte do fluxo para repos grandes, não extra opcional.
10. **Adapters:** gerados, nunca fonte primária; incluir `.agents/skills/` cross-tool.
11. **Dev Loop:** story sharding com contexto embutido (BMAD v6) como Camada 5.
12. **Quality:** eval harness quantitativo (skill-creator/LionClaw) opt-in, com `runners.yaml` agnóstico.
13. **Meta-avaliação:** `.forge/evals/meta/` como diferencial — evoluir o harness por evidência, não opinião.
14. **Loops builder→validator:** em `/forge:requirements` e `/forge:design`, max 3 iterações, com escalonamento humano.
15. **Primeiro piloto:** adaptar o template atual para `.forge` mantendo Claude como adapter de compatibilidade.
16. **Namespace de comandos:** padronizar tudo sob `/forge:*` (ex.: `/forge:init`, `/forge:spec`, `/forge:wave`), evitando colisão com comandos nativos de cada agente e tornando o harness reconhecível em qualquer ferramenta.
17. **Orquestração de sessões longas:** waves com dependências + ponteiro de progresso + helper scripts de contexto (Qwen v6.5); autopilot com gates deterministas de uma linha e orçamento de contexto.
18. **Ledger de pendências:** toda dependência não satisfeita vira item deferido rastreável; nenhuma wave fecha deixando gap silencioso; o projeto só conclui após o ledger ser zerado e testado.
19. **Mini-report de progresso:** `/forge:progress` responde curto e objetivo (% do projeto, por módulo/área, infra) e já aponta o próximo passo lógico.
20. **HITL via AskUserQuestion:** toda decisão humana em transição é apresentada como opções (approve/review/reject/supersede/abandon/block), com motivo obrigatório para tudo que não seja approve, registrado em `approvals.yaml`.
21. **C4 + HTML consolidado:** em greenfield e feature, a Understanding Layer gera diagramas C4 (Mermaid) e um HTML navegável do projeto.
22. **Git/CI-CD econômico:** branches de trabalho → PR para `develop` → merge → promoção para `staging`; GitHub Actions roda só na promoção a `staging`; checks baratos via hooks locais e Docker Desktop.

---

## 27. Próxima Spec a Criar

Nome sugerido:

```text
create-forge-project-harness
```

Prompt para iniciar:

```text
Criar o Forge Project Harness: um harness SDD agnóstico de agente com raiz .forge,
FORGE.md como fonte principal rica, AGENTS.md como interface canônica gerada (com
CLAUDE.md/QWEN.md/GEMINI.md symlinkando para AGENTS.md), adapters para
Claude/Codex/Qwen/Forge CLI/.agents-skills, lifecycle de specs active/archive,
baseline em .forge/product/current, níveis scale-adaptive, story sharding com
contexto embutido, loops builder→validator, eval harness opt-in com runner
configurável, meta-avaliação do harness, validadores deterministas e migração do
template atual /init-project sem perder compatibilidade com .claude.
```

Primeira task real: implementar **MVP1** (`.forge` canônico + adapter Claude + AGENTS.md gerado + symlinks + doctor/sync), sem tocar ainda em graph, archive ou eval.

---

## Apêndice A — Glossário

- **Harness:** camada de projeto que padroniza governança, especificação, execução, entendimento e qualidade sobre agentes de código.
- **Baseline:** estado vigente do produto em `.forge/product/current/`, expresso em capabilities com IDs estáveis.
- **Capability:** unidade canônica do baseline (`capabilities/<capability>/spec.yaml`); fonte primária do merge no archive.
- **Change:** unidade de mudança ativa em `.forge/specs/active/<change-id>/`.
- **Delta:** operação de alteração do baseline (`add/modify/remove requirement`, `add_contract`), com substituição integral em `modify`.
- **Story (sharding):** fatia auto-contida de implementação, com contexto embutido, para caber na janela do agente.
- **Adapter:** projeção gerada de `.forge/**` para uma ferramenta específica (Claude, Codex, Qwen, Kiro, Cursor, etc.).
- **Eval harness:** subsistema opt-in de avaliação A/B quantitativa de skills/commands/templates.
- **Triggering optimization:** otimização da description de uma skill por holdout train/test, selecionada pela pontuação de teste.
- **Scale (0..4):** nível de complexidade scale-adaptive que modula quais fases são obrigatórias.
- **Builder→validator loop:** ciclo de auto-correção com sinal externo (relatório `[MISS]`/`[CONFLICT]`/`[CLARIFY]`, max 3 iterações).
- **Objeto de Valor:** value object do domínio (sempre por extenso, nunca abreviado).

## Apêndice B — Mudanças da v1 para a v2

1. **Interface canônica.** `AGENTS.md` passa a ser a interface gerada a partir do `FORGE.md`; os demais arquivos symlinkam para `AGENTS.md` (antes symlinkavam direto para `FORGE.md`). Justificativa: `AGENTS.md` é o padrão da Linux Foundation com 60k+ projetos.
2. **Quinta camada.** Adição da camada **Dev Loop & Quality** (story sharding do BMAD v6 + eval harness do skill-creator/LionClaw).
3. **Scale-adaptive.** O Quick Plan vira decisão sistemática via campo `scale` (0..4) no manifest.
4. **Loops builder→validator.** Auto-correção com sinal externo em `/forge:requirements` e `/forge:design`.
5. **Contexto separado.** Novo `.forge/context.md` (inspirado em USER/RULES do LionClaw), separando contexto de governança.
6. **Eval harness e meta-avaliação.** Novos `/forge:skill create|eval|optimize`, `.forge/evals/`, `runners.yaml`, `grading.schema.json`, e o diferencial de meta-avaliação do harness.
7. **MVP5.** Novo MVP para a Camada 5, opt-in.
8. **Adapter cross-tool.** Adição de `.agents/skills/` (padrão BMAD v6).

### Mudanças da v2 para a v3

1. **Orquestração de sessões longas (Qwen v6.5).** Waves com dependências, ponteiro de progresso, helper scripts de economia de contexto e disciplina de autopilot, absorvidos do HarnessQwen v6.5 (seções 4.3 e 17.2–17.7).
2. **Ledger de pendências/deferidos.** Novo mecanismo (`deferrals.json`) para itens bloqueados por dependência, com resolução e teste obrigatórios no fim (seção 17.4).
3. **Mini-report de progresso.** `/forge:progress` com saída curta e próximo passo (seção 17.3).
4. **Esclarecimento active vs current.** Nova seção 8.1 detalhando a diferença entre `specs/active/` e `product/current/`.
5. **HITL via AskUserQuestion.** Seção 12.1 com opções canônicas e motivo obrigatório registrado.
6. **C4 + HTML consolidado.** Seção 16.5 para greenfield/feature.
7. **Git/CI-CD econômico + Docker.** Seção 20 expandida com fluxo de branches, pipeline só em `staging`, sync Docker Desktop e hooks.
8. **Skills especialistas.** Reforço do padrão de delegar a scripts/skills que retornam o mínimo, para economizar contexto do orquestrador (seção 17.7).
9. **Novos comandos.** `/forge:wave`, `/forge:progress`, `/forge:defer`, `/forge:resolve-deferrals`, `/forge:c4`, `/forge:dev`.

### Ajuste v3.1

- **Worktrees padronizadas + cleanup obrigatório.** Toda worktree vive em `.forge/worktrees/<change-id>/` (dentro do projeto); `worktree-guard` bloqueia criação fora do padrão e o `post-merge` remove a worktree após o merge (`git worktree remove` + `git worktree prune`), seção 20.4. Documento marcado como **Aprovado**.

## Apêndice C — Referências

- Piskala, D. B. *Spec-Driven Development: From Code to Contract in the Age of AI Coding Assistants.* arXiv:2602.00180v1, 2026 (anexo).
- Agentic AI Foundation (Linux Foundation) — AGENTS.md, MCP, goose. Anúncio de formação, dez. 2025.
- GitHub Spec Kit — `github/spec-kit`.
- OpenSpec — `Fission-AI/OpenSpec` e openspec.dev.
- Kiro — kiro.dev (Specs, Steering, Hooks).
- BMAD-METHOD v6 — `bmad-code-org/BMAD-METHOD`.
- Graphify — `safishamsi/graphify`.
- Understand Anything — `Egonex-AI/Understand-Anything`.
- Anthropic Agent Skills / skill-creator — `anthropics/skills`; spec aberto Agent Skills.
- Huang et al. *Large Language Models Cannot Self-Correct Reasoning Yet.* arXiv:2310.01798, ICLR 2024.
- LionClaw (`.lionclaw/**`) — sistema interno de Milton (BOOTSTRAP/SOUL/USER/MEMORY/RULES, skill-creator, BuildPlan).
- HarnessQwen v6.5 — harness interno de Milton para Cline + Qwen local (waves, helper scripts de contexto, gates deterministas, Sprint Review Final, lições de context overflow / Classe G).

---

*Fim do documento. Versão 3.1 (aprovado) — Forge Project Harness. Próximo passo: criar a spec `create-forge-project-harness` e implementar o MVP1.*
