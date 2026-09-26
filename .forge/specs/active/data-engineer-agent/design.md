# Design — data-engineer-agent

> Design técnico do change `data-engineer-agent`. Fonte canônica do que se entrega: `template/.forge/**`. Base de conhecimento: `research/base-consolidada.md` deste change (julgada em 2026-09-26; cópia fiel do insumo); as referências a "base §N" apontam para ela. As decisões estão numeradas D-01 a D-11 e consolidadas no §3; a revisão do validador de 2026-09-26, item a item, está no §3.1, e os conflitos com rules do template no §2.9.

## 1. Contexto e restrições

- **Plataforma de subagentes (conferido em 2026-09-26 na documentação do Claude Code, `code.claude.com/docs/en/sub-agents`, e remedido na revisão do validador):** um subagente pode criar subagentes até três níveis abaixo da conversa principal (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`; `1` desliga o aninhamento). A lista entre parênteses de `tools: Agent(a, b)` **só vale quando o agente roda como thread principal com `claude --agent`**; numa definição usada como subagente, "any type list inside the parentheses is ignored" e o subagente pode criar qualquer tipo. No limite de profundidade o Claude Code retira a ferramenta `Agent` e "the subagent at the limit does its delegated work itself", então o modo degradado depende só do prompt. A lista de `tools` em si (sem `Write`, por exemplo) é respeitada nos dois modos. Hooks declarados no frontmatter (`hooks.PreToolUse` com matcher por nome de ferramenta) valem nos dois modos e só enquanto o agente está ativo; são o mecanismo de restrição efetiva (REQ-10, D-11). O campo `skills` pré-carrega o conteúdo integral das skills no contexto do subagente; `.claude/agents/` é varrido recursivamente, então `agents/data/` funciona como as categorias existentes.
- **Projeção e distribuição já existem:** `sync-adapters.mjs` copia `agents/**` para `.claude/agents/` e `skills/**` para `.claude/skills/` e `.agents/skills/`; `bin/forge.mjs` trata `agents` e `skills` como maquinaria (`MACHINERY_DIRS`) e como diretórios enriquecíveis (`ENRICHABLE_DIRS`) no `forge update`. `evals/` não é maquinaria. Nenhum código de projeção muda.
- **Plugin só carrega commands:** `plugin-build.mjs` gera `plugin/forge/commands/**` a partir de `template/.forge/commands/**`; agentes e skills não passam por ele.
- **Gates existentes que este change toca ou pode derrubar:** `w200` (contagem do README), `w209` bloco B (toda varredura recursiva extratora sob `template/` e `tests/` precisa de `-a`), `w102` (projeção dinâmica de skills), `tests/snapshot/claude-contract.bats` C2/C4 (frontmatter YAML parseável com `description`), `w14` e `npx-pack-gate` (projeção do adapter), `plugin-sync-gate`, check de vazamento `.claude/` do `doctor`, `w213` e a sentinela de árvore rastreada do `run-all.sh` (gate nunca muta arquivo rastreado).
- **Rules que já governam o domínio:** `rules/data/data-governance.md` (matriz transversal, RLS obrigatório em tabela multi-tenant de domínio, Redis nunca fonte de verdade, "transacional de negócio → MongoDB"), `data-config-sql.md`, `data-transactional-nosql.md`, `data-cache.md`, `schema-evolution.md`, `rules/domain/money-as-cents.md` (`BIGINT NOT NULL` na menor unidade, nunca `DECIMAL`/`NUMERIC`; `applies_to` .NET, React e Kotlin), `rules/architecture/pii-pci-classification.md` (pack opt-in `pii-pci`; classificação como código em `data-classification.json`), `rules/architecture/internal-grpc-communication.md` (gRPC síncrono interno por padrão, mensageria com AsyncAPI para evento, exceções só com ADR) e `rules/conventions/conflict-handling.md` (conflito relevante bloqueia: parar, HITL, registrar em `approvals.yaml`). Pela ordem de autoridade do `FORGE.md` (constitution > baseline/ADRs > rules > contexto), skill é contexto: rule vence skill, e onde a divergência é relevante vale o §2 da `conflict-handling.md`, não "citar e seguir" (§2.9).
- **Mecanismo de PCI já existente:** `scripts/check-data-governance.sh` (gate `gw3`) acha PAN, CPF e e-mail dentro de chamada de log e campo marcado `forge:sensitive-field` sem entrada no `data-classification.json` (schema `data-classification.schema.json`); decisões de governança de dado têm molde em `templates/product/adr-data-governance.md`. Os especialistas usam esse mecanismo em vez de reinventá-lo; os detectores por nome de campo das skills (C-15, T-02) são complemento de severidade `aviso` (§2.5).
- **Regra do dono (integração):** interno serviço a serviço é gRPC; externo é REST (síncrono) ou fila/mensageria (assíncrono); nunca gRPC para terceiro. Coincide com a rule `internal-grpc-communication.md` do template, que passa a ser a fonte citada pelos agentes; a frase canônica do §2.4 carrega também o que a rule acrescenta (síncrona, AsyncAPI, exceções por ADR).

## 2. Decisão técnica

### 2.1 Taxonomia de roteamento (D-01)

O orquestrador classifica por três eixos, nesta ordem de precedência: **(1) padrão de acesso dominante** (transação multi-entidade, lookup por chave, varredura histórica, trabalho assíncrono, blob imutável), **(2) forma do dado** (estruturado, semiestruturado, não estruturado — classificação de uso corrente, sem norma que a defina, base §0.1) e **(3) produto** citado no pedido. O produto nunca decide sozinho: Redis como fonte da verdade não é cache, e JSON pode morar em `jsonb`, em documento ou numa tabela analítica. É a leitura dos cinco passos da Microsoft ("Understand data models", [J]) com a ressalva que a própria página faz: persistência poliglota é o destino comum, não o ponto de partida.

Matriz sinal → especialista (base §0.2), que vai literal para o corpo do orquestrador:

| Sinal dominante | Modelo | Especialista |
|---|---|---|
| Transação multi-entidade estrita, integridade referencial, dinheiro, estoque, ledger, cobrança; migração de schema, lock, isolamento, deadlock, N+1, paginação, pool | Relacional OLTP | `data-relational` |
| Agregado de forma evolutiva lido e escrito inteiro, chave de partição, escala horizontal por partição (DynamoDB, MongoDB, Cosmos DB, Cassandra); travessia de relacionamento de profundidade variável (grafo) | Documento, chave-valor persistente, coluna larga, grafo | `data-nosql` |
| Lookup sub-ms de cópia derivada, sessão efêmera, TTL, invalidação, stampede, Redis/Valkey como cache | Chave-valor em memória | `data-cache` |
| Binário grande, arquivo, backup, export, zona bruta de lake, URL pré-assinada, lifecycle, WORM, bucket | Objeto | `data-object-storage` |
| Varredura histórica, agregação, BI, modelagem dimensional, dbt, warehouse, lakehouse, Iceberg/Delta, particionamento e clustering de tabela | Analítico/OLAP | `data-analytical` |
| Trabalho assíncrono, desacoplar cadência, evento de domínio, fan-out, replay, outbox, CDC, saga, idempotência de consumidor, schema de evento, RabbitMQ, Kafka | Fila, stream, log | `data-streaming` |

A primeira linha da matriz (transação multi-entidade estrita → relacional) colide com a linha "transacional de negócio → MongoDB" de `rules/data/data-governance.md`; o texto final dessa linha depende da decisão HITL H-01 (§2.9) e não entra no orquestrador antes dela.

Regras de desempate (base §0.3, ajustadas às rules do template), também literais no orquestrador:

1. Fonte da verdade decide o dono, e Redis nunca é fonte de verdade: `data-governance.md` e `data-cache.md` dizem "nunca fonte de verdade". Pedido que usa Redis como armazenamento primário (inclusive sessão durável) é conflito com rule: o orquestrador devolve o bloco `CONFLITO` (§2.3) e, na mesma resposta, roteia a escolha do armazenamento durável para `data-nosql` ou `data-relational` pela matriz; `data-cache` responde só pela parte que é cache. Não é desenho válido no template.
2. Fila nunca no cache: fila, lock durável ou job em Redis com eviction é antipattern de `data-cache`; o desenho da fila é de `data-streaming`.
3. Medallion tem dois donos: `data-object-storage` responde por bucket por zona, prefixos, lifecycle, criptografia, acesso público, WORM e small files no nível de objeto; `data-analytical` por formato de tabela, particionamento/clustering de tabela, modelagem, dbt, contratos e manutenção de tabela.
4. Particionamento: diretório estilo Hive é aceitável para arquivo bruto (`data-object-storage`); tabela silver/gold segue `data-analytical` (particionamento oculto, liquid clustering, não particionar abaixo de ~1 TB no Databricks).
5. CDC e invalidação: o mecanismo (outbox, Debezium, slot) é de `data-streaming`; a política de invalidação é de `data-cache`.
6. Séries temporais: ingestão operacional por chave e janela curta vai para `data-nosql` (ou `data-relational` com extensão tipo TimescaleDB quando o volume cabe e a consulta cruza dado transacional); agregação histórica vai para `data-analytical`.
7. Busca textual e vetorial não têm especialista: `data-relational` quando `jsonb`/full-text/`pgvector` bastam; caso contrário, "fora da cobertura", dito explicitamente. Índice de busca nunca é fonte da verdade.
8. Superfície externa: nenhum especialista propõe acesso direto de terceiro a banco, cache, tópico, vhost ou bucket internos (§2.4).

### 2.2 Orquestrador `data-engineer` (D-02, D-04)

Arquivo `template/.forge/agents/data/data-engineer.md`. Frontmatter:

```yaml
---
name: data-engineer
description: |
  Use para qualquer decisão ou revisão de dados — modelagem e migração relacional, chave de partição e consistência em NoSQL, cache, bucket e ciclo de vida de objeto, warehouse/lakehouse e dbt, filas e eventos (RabbitMQ, Kafka, outbox, CDC). Classifica o pedido pelo padrão de acesso, delega ao especialista certo e sintetiza. Não use para busca vetorial dedicada, para código sem persistência nem para infraestrutura de rede.
tools:
  - Agent(data-relational, data-nosql, data-cache, data-object-storage, data-analytical, data-streaming)
  - Read
  - Grep
  - Glob
hooks:
  PreToolUse:
    - matcher: "Agent|Task"
      hooks:
        - type: command
          command: 'bash "$CLAUDE_PROJECT_DIR/.forge/scripts/data-agent-allowlist.sh"'
model: sonnet
---
```

A lista entre parênteses de `Agent(...)` só restringe no modo `claude --agent data-engineer`; no modo subagente, que é o caminho principal (descrição ou `@data-engineer`), ela é ignorada. A restrição efetiva nos dois modos é o hook `PreToolUse` do frontmatter (D-11, REQ-10): `template/.forge/scripts/data-agent-allowlist.sh` lê o JSON do hook na entrada padrão, aceita só `tool_input.subagent_type` entre os seis especialistas e nega com exit 2 qualquer outro tipo (inclusive `general-purpose`, `task-coder` ou agente com `Write`), com fail-closed para JSON malformado, campo ausente e falta de `node`. O script fica em `scripts/` (maquinaria levada pelo overlay do `forge update`) e não em `agents/data/`, porque o que está em `agents/**` é projetado para `.claude/agents/` e o caminho do hook passaria a conter `.claude/` (check de vazamento do `doctor`). Com o hook, "uma árvore, um escritor" (D-03) volta a valer: nada que o orquestrador consiga criar tem `Write` ou `Edit`. Limites registrados: hooks de frontmatter são ignorados em subagente de plugin (não é o caso: os agentes vêm de `.claude/agents/`), e o nome do campo `subagent_type` é confirmado por controle positivo com trace real antes do A/B (§2.7).

Corpo, nesta ordem: `Missão`; `Taxonomia` (matriz e regras do §2.1); `Protocolo` (1. ler `.forge/rules/data/*`, `.forge/rules/domain/*` aplicáveis, `rules/architecture/internal-grpc-communication.md`, ADRs e baseline do projeto; 2. classificar e declarar a classificação em uma linha; 3. se o pedido colide com rule do projeto em decisão relevante, devolver o bloco `CONFLITO` e não seguir com a parte em conflito; 4. decompor pedido multi-domínio em uma pergunta por especialista, com o contexto mínimo e os paths relevantes; 5. delegar; 6. sintetizar atribuindo cada recomendação ao especialista de origem, repassando todo bloco `CONFLITO` que um especialista devolver e marcando divergências entre eles); `Checklist transversal` (base §0.4 e §7: dado sensível PCI/LGPD com `check-data-governance.sh` e `data-classification.json`, multi-tenant com RLS obrigatório em PostgreSQL pela rule, custo da unidade dominante, reversibilidade e expand/contract, maturidade operacional — backup testado, monitoramento, runbook); `Regra de integração` (§2.4); `Modo degradado`; `Fora da cobertura`.

Modo degradado: sem a ferramenta `Agent` (profundidade máxima atingida, quando o Claude Code a retira do subagente; ou ferramenta de IA sem subagentes), o orquestrador não responde no lugar do especialista; devolve

```text
PLANO DE ROTEAMENTO
classificação: <eixo 1> / <eixo 2> / <produto>
especialistas: <esp>[, <esp>...]
pergunta por especialista:
  - <esp>: <pergunta reformulada com contexto mínimo e paths>
checklist transversal: <itens aplicáveis>
```

para que quem o chamou acione os especialistas. Como o Claude Code, no limite de profundidade, instrui o subagente a fazer o trabalho ele mesmo, esse comportamento só existe se o prompt vencer essa instrução; por isso ele é verificado por dois casos críticos do eval com `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` (§2.7), não pela presença do bloco no texto. Os especialistas continuam utilizáveis diretamente (pela descrição ou por `@<esp>`).

Fora do Claude Code a projeção é parcial, e o `agents/README.md` diz isso: as skills só chegam a `.agents/skills/` com o adapter `agents-skills` ou `forge-cli` (`sync-adapters.mjs`, `emitAgentsSkills`); o adapter `codex` puro consome só o `AGENTS.md` e não recebe nem agentes nem skills. O modo degradado, portanto, não supõe skill disponível: o `PLANO DE ROTEAMENTO` nomeia o caminho `.forge/skills/<esp>-practices/`, que existe em qualquer instalação.

Modelo (D-04): `sonnet` no orquestrador e nos especialistas. A regra do dono proíbe herança implícita de modelo; o valor é sempre explícito.

### 2.3 Especialistas (D-03)

Seis arquivos `template/.forge/agents/data/<esp>.md`, mesmo molde. Frontmatter:

```yaml
---
name: <esp>
description: |
  <quando usar, com gatilhos concretos do domínio; quando não usar, apontando o especialista vizinho>
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - mcp__context7__resolve-library-id
  - mcp__context7__query-docs
skills:
  - <esp>-practices
model: sonnet
---
```

Os nomes das ferramentas context7 são os que o servidor expõe hoje (`resolve-library-id` e `query-docs`, conferidos na lista de ferramentas da sessão em 2026-09-26); `get-library-docs`, usado por cinco agentes existentes, não resolve mais, e com allowlist de `tools` a mitigação "context7 para versão corrente" (§6) ficaria morta. Os cinco agentes antigos ficam como follow-up (§3.1).

Sem `Write`, `Edit` nem `Agent`: o especialista é consultivo — devolve recomendação, DDL, policy ou trecho de código na resposta, e quem escreve é o agente de engenharia ou o `task-coder` (uma árvore, um escritor). `Bash` existe para rodar o `scan.sh`, o `check-data-governance.sh` e comandos de leitura. Seções do corpo, nesta ordem: `Missão`, `Escopo` (quando usar e quando não, da base §N.1), `Protocolo`, `Checklist`, `Antipatterns bloqueados` (ids do catálogo), `Regra de integração` (§2.4), `Quando devolver ao orquestrador` (pedido que cruza para outro domínio pela matriz do §2.1).

`Protocolo` do especialista, nesta ordem: 1. ler `.forge/rules/data/*`, `.forge/rules/domain/*` aplicáveis (ex.: `money-as-cents.md`), ADRs e baseline do projeto; 2. se a recomendação da skill diverge de rule/ADR em decisão relevante pela `rules/conventions/conflict-handling.md` (isolamento, segurança, contrato, modelo de domínio, estratégia de persistência), **parar** e devolver o bloco `CONFLITO` abaixo, sem recomendar a parte em conflito; divergência não relevante (estilo, nome) segue a fonte de maior autoridade e é citada; 3. rodar `bash .forge/scripts/check-data-governance.sh --path <paths afetados>` e, quando existir `data-classification.json`, usá-lo como autoridade sobre quais campos são PAN/PII; 4. rodar `bash .forge/skills/<esp>-practices/scripts/scan.sh --root <paths afetados>`; 5. julgar cada `FOUND` lendo o arquivo; 6. responder, citando o id de cada antipattern.

```text
CONFLITO
decisão: <o que está em jogo, em uma linha>
posição A: <recomendação> — fonte: <rule/ADR do projeto, caminho>
posição B: <recomendação> — fonte: <skill/base, caminho>
precedência: <qual vence pela ordem do FORGE.md §2.1>
opções: aplicar a fonte de maior autoridade (recomendado) | abrir ou atualizar ADR | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para ADR
```

O especialista não tem `AskUserQuestion` nem escreve `approvals.yaml`; ele para e devolve. Quem conduz o HITL e o registro é a sessão principal (ou o pipeline `/forge:*` em curso), como manda o §2 da `conflict-handling.md`.

### 2.4 Frase canônica da regra de integração

Os sete agentes carregam, na seção `Regra de integração`, este parágrafo literal (o gate [10] procura a frase entre aspas):

> "Comunicação síncrona interna entre serviços é gRPC por padrão, com contrato `.proto` versionado; evento assíncrono interno vai por mensageria, com contrato AsyncAPI e schema registrado; comunicação externa é REST (síncrona) ou fila/mensageria (assíncrona); gRPC nunca é exposto a terceiros, e nenhum terceiro recebe acesso direto a banco, cache, tópico, fila, vhost ou bucket internos; toda exceção exige ADR." Fonte: `.forge/rules/architecture/internal-grpc-communication.md`. Formas válidas de entrega a terceiro (parceiro, adquirente, integrador): API REST (com idempotency key em POST com efeito), fila ou tópico dedicado por parceiro com vhost/usuário/ACL próprios, webhook, e URL pré-assinada de curta duração para objeto. Cliente próprio (web/mobile do produto) não é terceiro: para ele a rule admite REST, GraphQL em BFF e gRPC-Web com browser, sempre como exceção registrada em ADR; os agentes nunca estendem essas exceções a terceiro e não as propõem por padrão.

A frase acrescenta à versão anterior o que a rule já dizia e ela omitia: "síncrona" (a rule manda gRPC para comunicação síncrona interna, não para toda comunicação interna), o contrato AsyncAPI do evento (a base §6.6 e o REQ-04 só pediam Schema Registry/Protobuf; agora a tabela de transporte do `best-practices.md` tem a coluna de contrato) e a exigência de ADR para exceção. A regra do dono ("nunca gRPC a terceiros; externo é REST ou fila") continua literal e prevalece sobre qualquer leitura das exceções da rule.

### 2.5 Skills de referência (D-07) e `scan.sh`

Estrutura por skill (`<esp>-practices`), no molde de `node-quality-scan`:

```text
template/.forge/skills/<esp>-practices/
├── SKILL.md                     # ≤ 120 linhas: protocolo, o que o scanner não faz, sessão limpa, referências
├── references/best-practices.md # boas práticas por tópico, com marca de evidência e fontes (links)
├── references/antipatterns.md   # catálogo: ### <ID> — <nome> + Sintoma / Por quê / Correção / Detecção / Evidência
└── scripts/scan.sh              # detecção estática das entradas com Detecção: scan.sh <ID>
```

Formato de entrada do catálogo:

```markdown
### RMQ-AP-10 — Requeue infinito
- **Sintoma:** mensagem que falha volta à cabeça da fila e é reentregue sem fim; CPU alta, `redeliver` crescente, fila parada atrás dela.
- **Por quê:** `nack`/`reject` com `requeue=true` recoloca a mensagem; em quorum, `basic.nack` não incrementa `delivery-count`, então o `delivery-limit` não a contém. Em amqplib e Spring AMQP o requeue é `true` por padrão.
- **Correção:** erro permanente com `reject` ou `nack(requeue=false)` para a DLX; erro transitório com retry fora da fila principal (RMQ-BP-12).
- **Detecção:** `scan.sh RMQ-AP-10` (estática); runtime: taxa de redeliver por fila.
- **Evidência:** [J] quorum queues e amqplib channel API; Spring AMQP exception handling.
```

`Detecção` usa quatro rótulos: `scan.sh <ID>` (estática, o scanner executa), `ferramenta` (linter ou analisador externo que o projeto roda: squawk, strong_migrations, SQLFluff, dbt-project-evaluator, Checkov), `runtime` (consulta ou comando contra sistema real, documentado e nunca executado pelo scanner) e `revisão` (sem detector confiável). Comandos de runtime e de ferramenta são os da base, reescritos com `grep -a`/`rg` quando varrem árvore; itens de base §8.2 ("Incerto") entram com o rótulo `[Incerto]` e nunca como detector de severidade `alto`.

Contrato do `scan.sh` (idêntico nos seis; D-08):

- Uso: `scan.sh [--root <dir>] [--json <arquivo>] [--max <n>]`; `--root` default `.`.
- Motor: `rg --hidden --no-ignore --text --no-heading --line-number --no-messages` quando presente, `grep -arnE` quando não; mesmo padrão nos dois. As três flags do `rg` são obrigatórias: sem elas o `rg` pula arquivo oculto (`.github/`, `.devcontainer/`, `.env*`), arquivo listado no `.gitignore` e arquivo binário, e o `grep -r` não pula, então os dois motores varreriam universos diferentes. A saída dos dois passa por `LC_ALL=C sort -t: -k1,1 -k2,2n` antes de ser contada e emitida, porque nem o `rg` (paralelo) nem o `grep -r` (ordem do diretório no sistema de arquivos) garantem ordem. O padrão copiado de `node-quality-scan/scripts/scan.sh` tem o defeito das flags e não é modelo neste ponto (follow-up no §3.1).
- Padrões sem `\b` (o `grep` BSD não o reconhece): a fronteira é escrita com classe explícita, `(^|[^A-Za-z0-9_])` antes e `([^A-Za-z0-9_]|$)` ou `([^0-9]|$)` depois; exclusão por filtro, nunca por lookahead; bytes de controle removidos da saída como em `node-quality-scan`.
- Diretórios ignorados, por filtro de caminho aplicado igual aos dois motores: `node_modules`, `dist`, `build`, `.git`, `vendor`, `target`, `.venv`, `coverage`, `generated`. Nenhum outro critério de exclusão (nem `.gitignore`, nem arquivo oculto).
- Saída: uma linha por regra (`OK <ID> [<sev>] nenhuma ocorrência` ou `FOUND <ID> [<sev>] <n> ocorrência(s)` e as localizações `  <arquivo>:<linha>: <trecho>` até `--max`), depois `ARQUIVOS-VARRIDOS <n>` com o total de arquivos do universo de extensões da skill, contado por `find` independente do motor. Universo zero: `NADA-EXAMINADO`, exit 3.
- Severidade: `alto` só quando o detector é preciso (fronteira explícita, provado contra os sósias da fixture limpa) e a prática é inequívoca na base ([J], [1F] ou [2F] **no detector**, não só na prática); todo detector marcado [Heurística] ou [Interp.], inclusive quando a prática é [J], é `aviso`. Exit 0 sem `alto`, 1 com `alto`, 2 uso, 3 nada examinado.
- Sem rede, sem credencial, sem ler variável de ambiente de conexão.

Regras estáticas por skill (as demais entradas do catálogo são `ferramenta`, `runtime` ou `revisão`). "Código" = `ts, tsx, js, jsx, mjs, cjs, py, rb, java, kt, go, cs`; "IaC" = `tf, yaml, yml, json, conf, properties, toml, hcl`.

| Skill | ID | Sev | Detecta (arquivos) |
|---|---|---|---|
| relational | R-03 | alto | `CREATE [UNIQUE] INDEX` sem `CONCURRENTLY`; `ALTER COLUMN … TYPE`; `RENAME COLUMN`/`RENAME TO`; `SET NOT NULL` (`*.sql`) |
| relational | R-04 | aviso | `timestamp` sem fuso, `char(n)`, `money`, `json` (não `jsonb`), `serial` (`*.sql`) |
| relational | R-06 | aviso | `OFFSET` com parâmetro ou literal ≥ 3 dígitos, `.offset(`, `.skip(` (código, `*.sql`) |
| relational | R-10 | alto | `WITH (NOLOCK)`, `READ UNCOMMITTED` (código, `*.sql`) |
| relational | R-12 | aviso | `SET search_path`, `LISTEN`, `pg_advisory_lock(` (código) — só é defeito atrás de PgBouncer em modo transaction |
| relational | R-13 | alto | `ALGORITHM=COPY`, `LOCK=SHARED`/`EXCLUSIVE` (`*.sql`) |
| relational | R-14 | aviso | `SELECT *` (código) |
| relational | R-17 | aviso | `publicly_accessible = true` em `aws_db_instance`, `aws_rds_cluster_instance` e equivalentes (IaC) — regra de integração |
| relational | R-18 | aviso | arquivo IaC com `0.0.0.0/0` e porta `5432` ou `3306` (`from_port`, `to_port`, `port`) no mesmo arquivo; localização é a linha do CIDR — regra de integração |
| nosql | N-01 | aviso | `$push` sem `$slice` na linha (código) |
| nosql | N-04 | aviso | `$lookup` (código) |
| nosql | N-06 | aviso | `hash_key`/`partition_key_path(s)` com `status`, `type`, `date`, `country`, `state`, `category` (IaC) |
| nosql | N-07 | alto | `w: 1`, `w=1`, `WriteConcern.W1`/`ACKNOWLEDGED` (código), com fronteira explícita antes de `w` e depois do `1` (`(^|[^A-Za-z0-9_])w[[:space:]]*[:=][[:space:]]*['"]?1([^0-9]|$)`); a fixture limpa traz `flow: 1` e `w: 10` como sósias |
| nosql | N-08 | aviso | `ScanCommand`, `.scan(`, `Scan(` (código) |
| nosql | N-09 | aviso | `list_append` (código) |
| nosql | N-10 | aviso | `projection_type = "ALL"` (IaC) |
| nosql | N-11 | alto | `ConsistentRead: true` e `IndexName` na mesma linha ou no mesmo objeto de uma linha (código) |
| nosql | N-13 | alto | `ALLOW FILTERING`; `CREATE [CUSTOM] INDEX` em `*.cql` |
| nosql | N-15 | aviso | `BEGIN [UNLOGGED] BATCH` (`*.cql`, código) |
| nosql | N-17 | aviso | `-[:RELATED_TO]`, `HAS`, `LINK`, `CONNECTED` genéricos (`*.cypher`, código) |
| nosql | N-18 | aviso | `bindIp: 0.0.0.0`, `bind_ip = 0.0.0.0`, `bindIpAll: true`, `--bind_ip_all` (`mongod.conf`, IaC, compose) — regra de integração |
| nosql | N-19 | aviso | arquivo IaC com `0.0.0.0/0` e porta `27017` no mesmo arquivo — regra de integração |
| cache | C-02 | aviso | `.set(`/`.hset(`/`.hmset(` sem `ex=`, `px=`, `EX`, `PX`, `expire`, `ttl`, `timeout` na linha (código) |
| cache | C-08 | aviso | `lru_cache`, `Caffeine`, `MemoryCache`, `node-cache` sem `expireAfterWrite`/`ttl`/`maxAge` na linha (código) |
| cache | C-09 | aviso | `"KEYS"` literal de comando ou `.keys(` sobre cliente redis (código) |
| cache | C-10 | alto | `maxmemory-policy noeviction`, `maxmemory 0` (IaC, `redis.conf`) |
| cache | C-11 | alto | `protected-mode no`, `bind 0.0.0.0` (`redis.conf`, IaC) |
| cache | C-15 | aviso | escrita em cache com nome de campo de cartão como identificador inteiro (fronteira explícita dos dois lados, para não casar `span`, `company`, `expand`): `pan`, `card_num`, `cardnumber`, `cvv`, `cvc`, `track1/2`, `pin_block`, `expiry` (código) — T-01 da base §7.1, detector [Heurística]; complemento do `check-data-governance.sh`, que é a fonte quando há `data-classification.json` |
| cache | C-16 | aviso | arquivo IaC com `0.0.0.0/0` e porta `6379` no mesmo arquivo — regra de integração |
| object-storage | O-01 | alto | `acl = "public-read"`/`"public-read-write"`, `block_public_acls = false`, `allUsers`, `allAuthenticatedUsers`, `allowBlobPublicAccess: true` (IaC) |
| object-storage | O-02 | aviso | `ExpiresIn`/`expires_in`/`expiresIn`/`Expires` com 4+ dígitos (código) |
| object-storage | O-08 | aviso | arquivo com `sse_algorithm = "aws:kms"` sem `bucket_key_enabled` (IaC; localização é a linha do kms) |
| object-storage | O-11 | alto | `image: minio/minio` (IaC, `Dockerfile`, compose) |
| object-storage | O-13 | aviso | `overwrite`, `MERGE INTO`, `DELETE FROM` na mesma linha que `raw`/`bronze` (código, `*.sql`) |
| object-storage | O-14 | aviso | `partitionBy(` com coluna `id`, `uuid`, `user`, `customer` (código) |
| analytical | A-06 | aviso | `PARTITIONED BY (`, `INSERT … PARTITION (` (`*.sql`) |
| analytical | A-08 | aviso | modelo com `materialized='incremental'` sem `unique_key` no arquivo (`models/**/*.sql`) |
| analytical | A-10 | alto | `source(` sob `models/marts/` |
| analytical | A-12 | aviso | `SELECT *` sob `models/marts/` |
| analytical | A-14 | alto | `invalidate_hard_deletes` (`snapshots/`, `*.yml`, `*.sql`) |
| streaming | RMQ-AP-01 | alto | auto-ack: `basicConsume(…, true`, `auto_ack=True`, `noAck: true`, `autoAck: true`, `AcknowledgeMode.NONE`, `acknowledge-mode: none` |
| streaming | RMQ-AP-03 | aviso | `newConnection(`, `BlockingConnection(`, `amqp.connect(`, `amqp.Dial(`, `CreateConnection(`/`CreateConnectionAsync(` (código) |
| streaming | RMQ-AP-04 | aviso | `basicGet(`, `basic_get(`, `.Get(` em canal, `BasicGet(` (código) |
| streaming | RMQ-AP-06 | alto | `ha-mode`, `ha-params`, `ha-sync-mode` (IaC, código) |
| streaming | RMQ-AP-07 | aviso | `x-queue-mode`, `queue-mode` (IaC, código) |
| streaming | RMQ-AP-08 | aviso | arquivo que publica (`basicPublish`, `basic_publish`, `.publish(`, `PublishWithContext`, `BasicPublish`) sem `confirmSelect`, `confirm_delivery`, `createConfirmChannel`, `.Confirm(`, `ConfirmSelect`, `publisher-confirm-type` |
| streaming | RMQ-AP-09 | aviso | `waitForConfirms` (código) |
| streaming | RMQ-AP-10 | alto | `basicNack(…, …, true)`, `basic_nack(… requeue=True`, amqplib `.nack(msg)` de um argumento, Go `.Nack(…, true)`, `default-requeue-rejected: true` |
| streaming | RMQ-AP-12 | aviso | arquivo que publica sem `delivery_mode=2`, `PERSISTENT_`, `persistent: true`, `amqp.Persistent`, `DeliveryMode = 2` |
| streaming | RMQ-AP-14 | aviso | `x-dead-letter-exchange`, `x-message-ttl`, `x-max-length`, `x-delivery-limit`, `x-overflow` em código |
| streaming | RMQ-AP-15 | aviso | `queueDeclare(…, false, false`, `durable: false`, `durable=False` (código) |
| streaming | RMQ-AP-17 | alto | `x-delayed-message`, `x-delayed-type`, `rabbitmq_delayed_message_exchange` |
| streaming | RMQ-AP-18 | alto | `basicQos(…, true)`, `basic_qos(… global_qos=True` |
| streaming | RMQ-AP-19 | aviso | `cluster_partition_handling` com `pause_minority`/`autoheal`/`pause_if_all_down` |
| streaming | RMQ-AP-20 | aviso | `loopback_users.guest = false`, `loopback_users = none`, `default_user = guest` (`rabbitmq.conf`, compose) — T-05 da base §7.1 |
| streaming | KFK-AP-01 | alto | `enable.auto.commit` `true` explícito (a ausência da chave também é defeito, pois o default é `true`; fica como `revisão`) |
| streaming | KFK-AP-02 | alto | `acks` `0` ou `1`, `enable.idempotence` `false`, `retries` `0`, com fronteira explícita depois do dígito (`([^0-9]|$)`); a fixture limpa traz `acks=10` e `retries=03` como sósias |
| streaming | KFK-AP-03 | aviso | `new ProducerRecord<…>(topic, value)` de dois argumentos (código) |
| streaming | KFK-AP-06 | alto | `replication_factor = 1`, `min.insync.replicas` `1`, `unclean.leader.election.enable` `true` (IaC) |
| streaming | KFK-AP-09 | aviso | listener `PLAINTEXT://0.0.0.0` em `listeners`/`KAFKA_LISTENERS`/`advertised.listeners` (`server.properties`, compose, IaC) — T-05 e regra de integração |
| streaming | D-AP-01 | aviso | `grpc` em manifests de Ingress, Gateway ou Service `LoadBalancer` (IaC) |
| streaming | D-AP-02 | aviso | permissão total `".*"` em `configure`/`write`/`read` de `definitions.json` ou de `rabbitmq_permissions` (Terraform); quem é usuário externo continua sendo julgamento de revisão, o scanner só aponta a permissão irrestrita |
| streaming | D-AP-04 | aviso | arquivo IaC com `0.0.0.0/0` e porta `5672`, `5671`, `9092` ou `9093` no mesmo arquivo — regra de integração |
| streaming | SCH-AP-01 | alto | `required` em `*.proto` |
| streaming | T-02 | aviso | campo `pan`, `card_number`, `cvv`, `cvc`, `track`, `pin_block` como identificador inteiro (fronteira explícita, para não casar `span`, `company`, `expand`) em `*.proto`, `*.avsc` e JSON Schema de evento — T-02 é [Interp.] na base §7.1; complemento do `check-data-governance.sh` |

Ids novos (`SCH-AP-*`, `INB-AP-*`, `OBX-AP-*`, `CDC-AP-*`) catalogam antipatterns que a base descreve em prosa sem id (base §6.6); a evidência é a mesma da prosa. Os detectores marcados "regra de integração" (R-17, R-18, N-18, N-19, C-16, KFK-AP-09, D-AP-04) e o estático de D-AP-02 entram por esta revisão (validador, item 8): a norma vem da regra do dono e do §2.4, não de fato de produto julgado na base, por isso a `Evidência` deles é `[Interp.]` com a fonte normativa citada e a severidade é `aviso`; RMQ-AP-20 e KFK-AP-09 também se apoiam em T-05 (base §7.1, [1F + Heurística]), onde a base só oferecia `rabbitmqctl` em runtime e a checagem estática do `rabbitmq.conf` é viável. Detectores de "mesmo arquivo" (R-18, N-19, C-16, D-AP-04, O-08) são aproximação deliberada: Terraform espalha CIDR e porta em linhas diferentes, e o scanner não faz parse de HCL. Os padrões concretos (regex) são escritos na TASK de cada skill, conferidos contra a fixture suja e a limpa, e documentados em `antipatterns.md`; esta tabela fixa o que cada regra detecta, não a expressão.

`best-practices.md` do `data-streaming` tem a seção `## RabbitMQ` com as treze subseções do REQ-04, na ordem: `Plataforma 4.x` (base §6.2), `Exchanges e roteamento` (topic durável por domínio, alternate exchange e `mandatory` para não roteável, consistent hash para partição por chave; a semântica fina de `headers`/`x-match` e de `basic.return` é [Incerto], base §8.2 item 5), `Filas quorum`, `DLX e poison message`, `Ack e prefetch`, `Publisher confirms`, `Retry` (nativo em 4.3; filas de espera por patamar antes; nunca o plugin), `Idempotência e inbox`, `Ordem`, `Streams`, `Operação e segurança`, `Receita de referência` (base §6.3, literal) e `Migrações` (espelhadas → quorum, Mnesia → Khepri antes do 4.3, delayed exchange → retry nativo; procedimento Mnesia → Khepri marcado [Incerto]). Depois: `## Kafka`, `## Padrões de integração` (inbox, outbox, CDC, saga, schema de evento com AsyncAPI e schema registry, event sourcing) e `## Escolha de transporte` (tabela da base §6.7, com a coluna de contrato: `.proto` para gRPC síncrono interno, AsyncAPI mais schema registrado para evento, OpenAPI para REST externo).

### 2.6 Gate `tests/w250-data-engineer-agents-gate.sh` (D-09)

Ordinal: `w250` é **piso manual desta rodada**, não saída do `gate-ordinal.sh next`. Remedido em 2026-09-26: `gate-ordinal.sh next` devolve `w239`, derivado do tronco remoto `origin/develop` (máximo w238), e `gate-ordinal.sh check` acusa 0 colisão em 125 ordinais. Acima do tronco, os refs conferidos só tomam `w239` (`fix/update-preserva-deriva`) e `w248` (`fix/ldg-0201-git-dir-herdado`); `w240` a `w246` estão reservados na tabela de ordinais de `docs/plans/2026-09-15-plano-issues-abertas.md`. O piso w250 deixa w239 a w249 para essas frentes; a versão anterior deste parágrafo dizia "w247 já tomado", o que nenhum ref sustenta, e a proposal atribuía o w250 ao `next`, o que também estava errado. Não há colisão hoje; `gate-ordinal.sh check` roda de novo antes do push. O gate é escrito como funções que recebem a raiz (`confere_* <root>`), para que a mutação rode sobre cópia em diretório temporário. Cenários:

- **[0] universo:** sete agentes em `agents/data/` e seis skills `data-*-practices`, via `lib/gate-universe.sh`; zero reprova.
- **[1] frontmatter:** `validate-frontmatter.sh --strict-xml` nos dois diretórios termina em `OK`; o frontmatter dos treze arquivos de entrada (sete agentes e seis `SKILL.md`) parseia com o pacote `yaml` (devDependency do repositório, presente no CI como o `ajv` do [15]) e tem `description` — a mesma propriedade que o C2/C4 do `claude-contract.bats` verifica com PyYAML, que o CI pode não ter; o `lib/yaml-lite.mjs` não serve aqui porque não lê bloco `|`. Sem o pacote, o cenário é `INCONCLUSIVO` e o gate sai 99, nunca aprova.
- **[2] roteamento:** lista do `Agent(...)` do orquestrador = conjunto dos seis nomes (restrição do modo `--agent`); frontmatter com `hooks.PreToolUse`, `matcher` que casa `Agent` e `Task`, e comando apontando para `.forge/scripts/data-agent-allowlist.sh` (restrição do modo subagente); todo nome da matriz tem arquivo; todo arquivo de especialista aparece na matriz; nenhum nome fantasma. Este cenário prova texto; o comportamento é provado pelo [16] e pelo trace do eval (§2.7).
- **[3] especialistas:** `skills:` aponta para skill existente; `model` presente; `tools` sem `Write`, `Edit`, `Agent`, e com `mcp__context7__query-docs` (nunca `get-library-docs`); as sete seções na ordem do §2.3; o `Protocolo` contém `.forge/rules/data/`, `conflict-handling`, o marcador `CONFLITO`, `check-data-governance`, `data-classification.json` e `scan.sh`, e o do orquestrador contém também `PLANO DE ROTEAMENTO`.
- **[4] skills:** três arquivos (mais `scan.sh`); corpo do `SKILL.md` ≤ 120 linhas; toda entrada `### <ID> —` de `antipatterns.md` tem os cinco rótulos; `best-practices.md` tem as seções de cobertura mínima do REQ-03.
- **[5] bijeção:** ids com `Detecção: scan.sh <ID>` = ids emitidos pelo `scan.sh` sobre a fixture limpa.
- **[6] detecção:** fixture suja faz cada regra emitir `FOUND` com `arquivo:linha`; fixture limpa faz todas emitirem `OK`; duas execuções idênticas (`cmp -s`); exit 1 só quando há `alto`.
- **[7] portabilidade:** numa cópia temporária da fixture suja acrescida de um arquivo oculto (`.github/x.yml`), de um arquivo listado num `.gitignore` da própria cópia e de um arquivo com byte de controle, cada um com uma ocorrência de regra estática, a saída com `rg` e com `PATH` sem `rg` é byte-idêntica e as três ocorrências aparecem nas duas. O cenário só vale como prova se o `rg` estiver presente; sem `rg` na máquina ele é `INCONCLUSIVO` e o gate sai 99.
- **[8] contador:** diretório sem arquivo do universo da skill dá `NADA-EXAMINADO` e exit 3.
- **[9] RabbitMQ:** treze subseções e ids `RMQ-BP-01..17`, `RMQ-AP-01..20` contíguos.
- **[10] integração:** frase canônica nos sete agentes; tabela de transporte com a coluna de contrato (`AsyncAPI` presente) e `D-AP-01..03` presentes; o `Checklist transversal` do orquestrador contém `PCI DSS`, `LGPD`, `multi-tenant`, `RLS`, `custo`, `reversibilidade`, `check-data-governance` e `data-classification.json`.
- **[11] refutados:** fora de `antipatterns.md`, nenhuma ocorrência de recomendação refutada ou obsoleta: `ha-mode`, `x-queue-mode`/`lazy` como recomendação, `x-delayed-message`, "3–4x"/"4x o WAL", "max.in.flight … desativa", partição Hive recomendada para silver/gold.
- **[12] fiação:** `capability-dispatcher/SKILL.md` cita `data-engineer` e as seis skills, com a `description` byte-idêntica à do tronco; os quatro revisores `code-review/{node,java,python,dotnet}-reviewer.md` citam `data-engineer` e ao menos um `data-*-practices/scripts/scan.sh`; os `PROFILE.md` de `backend-{java,python,dotnet}-relational` e `backend-node-postgres` citam `data-relational-practices`; `agents/README.md` tem `### Dados (data/)` com sete links que resolvem e a nota de projeção fora do Claude Code; nenhum arquivo novo contém `.claude/`.
- **[13] projeção:** instalação real num temporário com `--adapters claude,agents-skills` projeta sete agentes em `.claude/agents/data/`, seis `SKILL.md` em `.claude/skills/data-*-practices/` e em `.agents/skills/`, com `scan.sh`, e `.forge/scripts/data-agent-allowlist.sh` executável.
- **[14] mutação (sobre cópia):** (a) tirar `data-cache` da lista do `Agent(...)` → [2] reprova nomeando `data-cache`; (b) apagar o rótulo `Correção` de uma entrada → [4] reprova nomeando o id; (c) apagar a regra `RMQ-AP-10` do `scan.sh` → [5] reprova nomeando `RMQ-AP-10`; (d) inserir "use `ha-mode: all`" em `best-practices.md` → [11] reprova; (e) acrescentar `general-purpose` ao conjunto aceito pelo script de hook → [16] reprova nomeando `general-purpose`. Controle antes (cópia íntegra aprova) e recontrole depois (cópia restaurada por `cp` do original, `cmp -s` contra o original, aprova de novo).
- **[15] evals:** sete `evals.json` no formato do skill-creator adotado pela frente `evals-100` (§2.7), conferidos por `node` sem schema externo: `skill_name` igual ao nome do agente, `artifact_kind` = `agent`, `artifact_path` que resolve para o arquivo do agente, `evals[]` com três casos por especialista e doze para o orquestrador, `id` inteiro único, `eval_name` kebab-case único, `prompt` e `expected_output` não vazios, `files` array, `assertions[]` com ao menos dois objetos `{name, text}` e uma assertion `regra-de-integracao-respeitada` por caso; no orquestrador, seis casos com prefixo `critico-`, dois deles `critico-degradado-*`. Se a frente paralela publicar um schema para esse formato antes da TASK-16, o [15] passa a validar por ele (ajv 2020 de `node_modules`, sem ajv `INCONCLUSIVO` e exit 99). Resolução de `ajv` e `yaml`: `node_modules` do próprio checkout; em worktree sem `node_modules`, o do checkout principal (diretório pai de `git rev-parse --git-common-dir`), dito na saída de qual veio.
- **[16] hook de allowlist:** o script `data-agent-allowlist.sh` recebe na entrada padrão JSON sintético de `PreToolUse`: cada um dos seis especialistas sai 0; `general-purpose`, `task-coder` e um nome inventado saem 2 com o nome na saída de erro; JSON malformado, `subagent_type` ausente e `PATH` sem `node` saem 2 (fail-closed). Contador de controle: seis aceitos e ao menos cinco negados examinados, zero reprova.
- **[17] conflito com rule:** os sete agentes citam `rules/conventions/conflict-handling.md` e trazem o bloco `CONFLITO` com os campos `decisão`, `posição A`, `posição B`, `precedência` e `opções`; nenhum agente nem skill contém "cite a divergência e siga" ou equivalente; `data-relational-practices` não recomenda `numeric`/`DECIMAL` para valor monetário fora de `antipatterns.md` e cita `money-as-cents.md`; nenhuma skill recomenda Redis como fonte de verdade.

Fixtures em `tests/fixtures/w250/<esp>/{sujo,limpo}/`, uma linha por regra estática na suja. A fixture suja carrega texto que o w209 aceita (sem byte de controle) e nenhum literal de credencial: nada de senha, `usuario:senha@` em URL de conexão, `default_pass` ou token, para não disparar o `check-secrets.sh range` do CI sobre o diff do PR; `amqp://`, `postgres://` e afins aparecem sem userinfo. A limpa carrega os sósias que um padrão frouxo casaria (`flow: 1`, `w: 10`, `acks=10`, `retries=03`, `span`, `company`, `expand`). O arquivo oculto, o arquivo ignorado por `.gitignore` e o arquivo com byte de controle do cenário [7] são criados pelo gate numa cópia temporária, nunca versionados. O gate nunca escreve em arquivo rastreado.

### 2.7 Evals A/B (D-10)

**Formato.** `.forge/evals/agents/<nome>/evals.json` na raiz do dogfood, fora do `template/`, no formato do skill-creator que a frente paralela `evals-100` (branch `chore/evals-skills-agentes`) já usa nesse mesmo diretório (em 2026-09-26, sem commit e em andamento: 47 arquivos em `.forge/evals/agents/` e 13 em `.forge/evals/skills/`): `skill_name` (nome do agente), `artifact_kind: "agent"`, `artifact_path`, `evals[]` com `id` inteiro, `eval_name`, `prompt`, `expected_output`, `files`, `assertions[]` de `{name, text}` e, quando o caso precisa de árvore preparada, `fixture: fixtures/<eval_name>/setup.sh`. O `evals.schema.json` do template (`skill`, `test_cases[]`, `id` string) não é usado: os dois formatos no mesmo diretório seriam incompatíveis e o [15] reprovaria os arquivos da outra frente (validador, item 5). Todo caso tem a assertion `regra-de-integracao-respeitada` ("a resposta não propõe gRPC a terceiro nem acesso direto de terceiro a banco, cache, tópico, fila, vhost ou bucket internos").

**Mecanismo de execução** (validador, item 6; o `quality/executor.md` só injeta `SKILL.md` no prompt e não tem `Agent`, e a raiz de dogfood não tem `.claude/` nem `.forge/agents`, então nada disso serve como está):

1. Dois braços instalados de verdade no scratchpad da sessão: `installer/install.sh --adapters claude` em `<scratch>/evals-data/variante` e em `<scratch>/evals-data/baseline`; no braço baseline, `.claude/agents/data/`, `.claude/skills/data-*-practices/` e `.forge/{agents/data,skills/data-*-practices}` são apagados, com contador de controle (`find` conta zero arquivo de dados na baseline e 7 + 6 na variante; outra contagem para o processo).
2. Controle positivo do trace antes de qualquer caso: um `claude -p "@data-cache <pergunta trivial>" --model sonnet --output-format stream-json --verbose` na variante precisa mostrar um `tool_use` de nome `Agent` (ou `Task`) com `input.subagent_type` = `data-cache`; e um `@data-engineer` pedindo explicitamente `general-purpose` precisa mostrar a negação do hook (exit 2) no trace. Se o nome do campo divergir, o script do hook e o [16] são corrigidos antes de seguir (REQ-10).
3. Especialista, braço variante: `claude -p "@<esp> <prompt>" --model sonnet --output-format stream-json --verbose` no diretório da variante, com timeout por `perl -e 'alarm N; exec @ARGV'`; o texto avaliado é o resultado do `tool_use` do especialista extraído do trace, não o repasse da thread principal. Braço baseline: o mesmo `prompt` sem `@<esp>`, `--model sonnet`, no diretório da baseline; avalia-se o resultado final.
4. Orquestrador: os doze casos rodam só no braço variante como `claude -p "@data-engineer <prompt>"`; os dois `critico-degradado-*` rodam com `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`. Um extrator `node` sobre o stream-json lista todos os `tool_use` de nome `Agent`/`Task` com `input.subagent_type`, inclusive os aninhados (`parent_tool_use_id` não nulo), e compara o conjunto de tipos criados abaixo do orquestrador com o conjunto esperado do caso; grava `routing.json` com caso, repetição, esperado, observado e veredito. Um caso extra roda `claude -p --agent data-engineer` para cobrir o modo thread principal.
5. Repetições: três por caso e por braço. Cada repetição K grava `workspace/iteration-1/eval-K/grading.json` no formato que `eval-aggregate.sh` lê (`skill`, `aggregate.baseline_pass_rate`, `aggregate.variant_pass_rate`, `test_cases[]` com `variant_result`/`baseline_result`), com o julgamento das assertions feito por um grader independente (subagente com modelo explícito, sem acesso ao braço de origem da resposta); `eval-aggregate.sh workspace/iteration-1` produz média e desvio-padrão entre as três repetições.
6. Critério: especialista aprovado quando `delta.pass_rate > 0` e `delta.pass_rate` maior que o maior dos dois desvios-padrão do `aggregate.json`; com n = 3 isso não é teste de significância, é a exigência mínima de que o ganho supere o ruído observado (validador, item 19). Roteamento: cada caso julgado pela maioria das três repetições; os seis críticos passam todos e os seis de domínio único passam ao menos cinco. Integração: zero falha de `regra-de-integracao-respeitada` na variante, em qualquer repetição.

Os artefatos ficam em `workspace/iteration-1/` ao lado de cada `evals.json`; o resumo e os números vão para o `verification.md`.

| Agente | Caso | Prompt (resumo) | Expectations centrais |
|---|---|---|---|
| data-relational | desenho | ledger multi-tenant em PostgreSQL 16 com saldo por conta: DDL e isolamento | `bigint` identity ou UUIDv7; valor monetário em `BIGINT NOT NULL` na menor unidade, citando `money-as-cents.md` (nunca `numeric`, `money` ou `float`); `timestamptz`; índice na FK; RLS habilitado na tabela multi-tenant (obrigatório pela `data-governance.md`), com `tenant_id` à frente do índice composto como complemento, nunca como alternativa; Serializable ou lock explícito com retry em `40001`/`40P01`; a expectation sobre a escolha do store é fixada depois do HITL H-01 (§2.9): na opção (a), a resposta traz o bloco `CONFLITO` sobre o store antes do DDL |
| data-relational | revisão | migração com `CREATE INDEX` simples e `RENAME COLUMN` em tabela grande, deploy com aplicação no ar | cita R-03; `CONCURRENTLY` fora de transação; expand/contract para o rename; `lock_timeout` na sessão |
| data-relational | fronteira | adquirente quer usuário read-only direto na tabela de transações | recusa acesso direto; propõe REST ou fila dedicada; não propõe gRPC externo; trata PAN como token |
| data-nosql | desenho | DynamoDB para pedidos por cliente e por status a 50 mil/s | partition key de alta cardinalidade; sort key hierárquica; GSI com write sharding para status; sem Scan; cita 3.000 RCU/1.000 WCU por partição |
| data-nosql | revisão | Terraform com `hash_key = "status"`, código com `ScanCommand` e `ConsistentRead: true` em GSI | cita N-06, N-08, N-11 com correção |
| data-nosql | fronteira | MongoDB P-S-A com `w:1` para pagamentos, "o default já é majority" | corrige: com árbitro o default cai para `w:1`; recomenda P-S-S e `majority` (N-07) |
| data-cache | desenho | tarifas lidas 10 mil/s, atualizadas por hora, multi-tenant | cache-aside; TTL com jitter; namespace por tenant; delete após commit; proteção contra stampede; `maxmemory` explícito e política |
| data-cache | revisão | `redis.set` sem TTL, `redis.keys('user:*')`, delete antes do commit | cita C-02, C-09, C-01 com correção |
| data-cache | fronteira | cachear PAN e CVV por 5 min para retentativa | recusa (SAD não persiste após autorização, PCI 3.3.1; Redis persiste); propõe token |
| data-object-storage | desenho | comprovantes PDF com retenção de 5 anos e download pelo app | bucket privado com BPA; SSE-KMS com Bucket Key; versionamento com expiração de não correntes; abort de multipart; URL pré-assinada de minutos; WORM só com obrigação legal e conciliação LGPD |
| data-object-storage | revisão | Terraform com `acl = "public-read"`, `ExpiresIn: 604800`, `image: minio/minio` | cita O-01, O-02, O-11 com correção |
| data-object-storage | fronteira | parceiro pede credencial IAM de leitura no bucket interno | recusa; URL pré-assinada curta ou REST; nunca gRPC externo |
| data-analytical | desenho | vendas de bilhetes para BI com tarifa mudando no tempo | quatro passos de Kimball; grão declarado; SCD2 com chave substituta; `dbt snapshot` estratégia `timestamp`; testes `unique`/`not_null` no grão |
| data-analytical | revisão | incremental sem `unique_key`, mart com `source()`, snapshot com `invalidate_hard_deletes` | cita A-08, A-10, A-14; migração para `hard_deletes` |
| data-analytical | fronteira | "particione por dia a tabela Delta de 50 GB no Databricks" | não particionar abaixo de 1 TB; liquid clustering |
| data-streaming | desenho | fila de pagamentos com retry e DLQ em RabbitMQ 4.3 | quorum; `delayed-retry-*` nativo; DLX at-least-once com `overflow=reject-publish`; `delivery-limit`; confirms; ack manual; prefetch; inbox; não usa plugin delayed nem `ha-mode` |
| data-streaming | revisão | amqplib com `ch.nack(msg)` no catch, `noAck: true`, policy `ha-mode: all` | cita RMQ-AP-10 (requeue default e `nack` fora do `delivery-limit`), RMQ-AP-01, RMQ-AP-06 |
| data-streaming | fronteira | expor o serviço gRPC de eventos de transação ao integrador | recusa gRPC externo; fila dedicada em vhost/usuário próprios, webhook ou REST; payload sem PAN |
| data-engineer | domínio único (6) | um prompt por especialista: relacional, NoSQL, cache, objeto, analítico, streaming | tipo de subagente criado, lido do trace, é o esperado e só ele; resposta declara a classificação |
| data-engineer | `critico-multi-*` (2) | outbox com invalidação de cache (streaming + cache); comprovante em bucket com evento de conclusão para o parceiro (object-storage + streaming) | os dois tipos esperados criados, lidos do trace; síntese atribui cada recomendação ao especialista de origem |
| data-engineer | `critico-fora-cobertura` | busca vetorial semântica em 50 milhões de documentos | nenhum especialista criado; "fora da cobertura" dito explicitamente |
| data-engineer | `critico-conflito-rule` | Redis como armazenamento primário de sessão durável | bloco `CONFLITO` citando `data-governance.md`/`data-cache.md`; escolha do store durável roteada a `data-nosql` ou `data-relational`; nunca aceita Redis como fonte de verdade |
| data-engineer | `critico-degradado-*` (2) | um prompt de domínio único e um multi-domínio, com `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` | bloco `PLANO DE ROTEAMENTO` com os especialistas certos; nenhum subagente criado no trace; nenhuma recomendação de especialista improvisada |

### 2.8 Integrações

- `skills/capability-dispatcher/SKILL.md`: passo novo no protocolo — "se a área afetada envolve persistência, cache, bucket, analítico ou mensageria, indique o `data-engineer` ou carregue só a skill `data-*-practices` do domínio afetado" — e uma tabela área → skill. A `description` não muda (motivo no §3.1, item 10): o disparo por cache, bucket ou RabbitMQ é trabalho da `description` do `data-engineer`, medido pelo eval de roteamento, não do dispatcher, que carrega capability packs.
- `agents/code-review/{node,java,python,dotnet}-reviewer.md`: no item que já trata persistência/transações, uma linha nova — "quando o diff toca migração, persistência, cache, bucket ou mensageria, rode `bash .forge/skills/data-<domínio>-practices/scripts/scan.sh --root <paths>` e trate cada `FOUND` como candidato; decisão de desenho (modelo, chave de partição, topologia) vai para o `data-engineer`". É o ponto por onde o pipeline (`code-evaluator` → revisor da stack) chega aos agentes novos.
- `capabilities/backend-{java,python,dotnet}-relational/PROFILE.md` e `capabilities/backend-node-postgres/PROFILE.md`: ponteiro para `data-relational-practices` (catálogo e `scan.sh`) na seção de persistência.
- `agents/README.md`: seção `### Dados (data/)` no catálogo, com os sete agentes, e a nota de projeção fora do Claude Code (§2.2).
- `scripts/data-agent-allowlist.sh`: script do hook do REQ-10, executável, sem dependência além de `bash` e `node`.
- `README.md`: contagens de `agents/` (47 → 54), `skills/` e `scripts/` (+1) recalculadas pelo critério do w200 no momento da TASK, e menção ao especialista de dados na lista de capacidades; `CHANGELOG.md` `[Unreleased]`.
- `.forge/graph/graph.json`: regenerado com `FORGE_ROOT=<worktree> bash template/.forge/scripts/graph.sh build` depois do último arquivo novo; o grafo já indexa `skills/*/scripts/scan.sh` (conferido: `dotnet-quality-scan/scripts/scan.sh` é nó), então seis `scan.sh` novos e o script do hook o deixariam defasado, o que o w246 planejado (LDG-0176) reprova.
- Nenhuma mudança em `rules/data/*` nem em `rules/domain/money-as-cents.md` neste change; os especialistas as leem no protocolo e as seguem (§2.9).

### 2.9 Conflitos com rules do template (conflict-handling)

A versão anterior deste design tratava a divergência com rules por "precedência, divergência citada, follow-up registrado" (D-06), que é exatamente o "registra e segue" que `rules/conventions/conflict-handling.md` §2 proíbe para estratégia de persistência. Remedido contra as rules, são quatro divergências entre a base (research) e o template; três se resolvem porque o change passa a obedecer a rule, sem decisão a tomar, e uma exige HITL.

| # | Base / versão anterior | Rule do template | Tratamento |
|---|---|---|---|
| C-1 | `numeric` para valor (base §1.2; eval de desenho do relacional) | `domain/money-as-cents.md` §4: `BIGINT NOT NULL` na menor unidade, nunca `DECIMAL`/`NUMERIC` | Obedecer: a skill recomenda `BIGINT` na menor unidade e cita a rule; `numeric` fica para decimal exato não monetário (taxa, quantidade fracionária). O ponto da base (`numeric` em vez do tipo `money` e de `float`) continua em R-04. Sem decisão pendente |
| C-2 | "`tenant_id` à frente do índice composto **ou** RLS" (eval de desenho) | `data/data-governance.md`: RLS obrigatório em tabela multi-tenant de domínio, dispensa só por exceção formal | Obedecer: RLS obrigatório; o índice por `tenant_id` é complemento de desempenho, nunca alternativa. Sem decisão pendente |
| C-3 | Redis como armazenamento primário tratado como desenho válido (desempate 1; caso de roteamento → nosql) | `data-governance.md` e `data-cache.md`: Redis nunca fonte de verdade | Obedecer: desempate 1 reescrito (§2.1); o caso de roteamento vira `critico-conflito-rule` e espera o bloco `CONFLITO`. Sem decisão pendente |
| H-01 | Transação multi-entidade estrita, dinheiro, ledger → relacional (matriz §2.1, base §0.2, [J] Microsoft) | `data-governance.md`: "Transacional de negócio, eventos, schema flexível, alto volume → MongoDB" | **Conflito relevante (estratégia de persistência): decisão humana antes da implementação** |

Opções do H-01, apresentadas na TASK-01 via HITL:

- **(a) Aplicar a rule (maior autoridade), recomendado para este change.** A matriz roteia "transacional de negócio" como a rule manda: `data-nosql` responde pelo store transacional (MongoDB com transação multi-documento, `majority`, P-S-S), e `data-relational` fica com o que a rule atribui ao PostgreSQL (parâmetros, configuração, relacional paramétrico) e com projetos cujo ADR escolheu relacional. Quando o pedido pede relacional para transacional de negócio sem ADR, o especialista devolve o bloco `CONFLITO`. Não muda rule nenhuma.
- **(b) Abrir ADR e change próprio para revisar `data-governance.md`** ("transação multi-entidade estrita → relacional"), com este change bloqueado até lá. Muda uma rule em uso pelos consumidores e sai do escopo da issue #177.
- **(c) Bloquear** o change até o dono decidir a estratégia.

A decisão entra em `approvals.yaml` do change (gate `design_reviewed`, com `decision` e `reason`), e a linha 1 da matriz, o caso de desenho do `data-relational` e o texto do `Protocolo` são fixados a partir dela na TASK-01. Se a opção for (b), o follow-up do ADR é registrado no ledger pelo orquestrador desta rodada (este change não chama `ledger-ops.sh`).

Em tempo de uso, o mesmo tratamento vale para qualquer projeto consumidor: especialista que detecta conflito relevante entre a skill e rule/ADR do projeto devolve o bloco `CONFLITO` (§2.3) e não segue com a parte em conflito; quem conduz o HITL é a sessão principal.

## 3. Alternativas consideradas

| Decisão | Alternativa | Prós | Contras | Por que não |
|---|---|---|---|---|
| D-01 taxonomia | Rotear pela forma do dado (estruturado/semi/não estruturado), como a issue sugere | Simples, vocabulário conhecido | Forma não determina armazenamento: JSON vai para `jsonb`, documento, evento ou tabela analítica; Redis e Postgres atravessam formas | Mantida como eixo 2, nunca como eixo primário |
| D-01 taxonomia | Rotear pelo produto citado | Classificação trivial | Redis como fonte da verdade não é cache; pedido sem produto fica sem rota; incentiva a resposta "use o que já tem" | Produto é eixo 3 e desempate |
| D-01 taxonomia | Só OLTP × OLAP | Clássico | Não cobre cache, objeto nem mensageria | Insuficiente |
| D-01 taxonomia | Um especialista por modelo de armazenamento (dez, como a Azure) | Cobertura completa | Busca, vetorial e séries temporais sem demanda medida; manutenção de dez catálogos | Seis especialistas, lacunas declaradas e regras de desempate 6 e 7 |
| D-02 orquestrador | Skill roteadora carregada no contexto principal | Funciona em qualquer ferramenta | Sem contexto isolado; o catálogo inteiro competiria com o resto da sessão | A issue pede subagente com contexto próprio; o aninhamento é suportado |
| D-02 orquestrador | Comando `/forge:data` | Entrada explícita | 57º comando, plugin e contagens mudam; o disparo por descrição já existe | Pode vir depois, se o eval de roteamento mostrar disparo fraco |
| D-02 orquestrador | Sem orquestrador, só os seis especialistas | Menos uma peça | Pedido multi-domínio fica sem síntese e sem checklist transversal | Rejeitado |
| D-03 especialistas | Especialista com `Write`/`Edit` | Aplica a correção direto | Dois escritores na árvore; exige disciplina de ferramenta e build | Consultivo; quem escreve é engenharia ou `task-coder` |
| D-04 modelo | `opus` nos especialistas | Julgamento mais forte | Custo por consulta alto para pergunta frequente | `sonnet`; o eval diz se precisa subir |
| D-04 modelo | `haiku` no orquestrador | Barato | Decomposição e síntese multi-domínio exigem mais | `sonnet` |
| D-05 plugin | Tocar o plugin | — | Plugin só carrega commands | Plugin intocado; `plugin-sync-gate` revalidado |
| D-06 conflito | Reescrever `data-governance.md` ("transacional de negócio → MongoDB") para alinhar à taxonomia | Um template coerente | Muda uma rule em uso por consumidores, fora do escopo da issue, e exige ADR de governança | É a opção (b) do H-01; só com decisão humana e em change próprio (§2.9) |
| D-06 conflito | Precedência com divergência citada e follow-up (versão anterior) | Não trava o change | É o "registra e segue" que `conflict-handling.md` §2 proíbe para estratégia de persistência | Rejeitado pelo validador (item 4); substituído por obediência à rule em C-1..C-3 e HITL no H-01 |
| D-06 conflito | A skill ignora a rule | — | Viola a ordem de autoridade do FORGE.md | Rejeitado |
| D-07 skills | Uma skill única de dados | Menos arquivos | Contexto grande carregado para pergunta de um domínio só | Seis skills, pré-carga seletiva |
| D-07 skills | Conhecimento no corpo do agente | Menos indireção | Sem progressive disclosure; o catálogo fica ilegível | Agente enxuto, referência na skill |
| D-08 scanner | Scanner que conecta no sistema (`pg_stat`, `redis-cli`, `rabbitmqctl`) | Pega o que o texto não mostra | Credencial, rede, risco operacional, não determinístico | Runtime documentado, não executado |
| D-08 scanner | Scanner como gate bloqueante do verify | Enforcement | Detectores heurísticos; falso positivo treina a ignorar | Instrumento do especialista; `alto` só com detector preciso |
| D-09 gate | Gates separados por especialista | Falha localizada | Seis gates quase idênticos | Um gate com funções por raiz e mensagens que nomeiam o alvo |
| D-10 evals | `template/.forge/evals/agents/` | Chega ao consumidor no init | `workspace/iteration-N` iria para o template; `evals/` não é maquinaria e o update não o leva | Dogfood `.forge/evals/agents/` |
| D-10 evals | `evals.schema.json` do template com `skill` = nome do agente (versão anterior) | Schema já validado por ajv | Formato incompatível com o que a frente `evals-100` grava no mesmo diretório (`skill_name`, `evals[]`, `id` inteiro, `assertions`); o [15] reprovaria os arquivos da outra frente | Rejeitado; adotado o formato do skill-creator (§2.7) |
| D-10 evals | Estender `evals.schema.json` com campo `agent` | Semântica exata | Mexe no schema e no w30, e continua incompatível com a outra frente | Rejeitado |
| D-11 allowlist | Confiar na lista de `Agent(...)` | Zero código | Ignorada no modo subagente, que é o caminho principal (doc oficial) | Mantida só para o modo `--agent` |
| D-11 allowlist | Só instrução no prompt do orquestrador | Zero código | Não é restrição; o orquestrador pode criar agente com `Write` | Rejeitado |
| D-11 allowlist | `PreToolUse` global em `settings.json` via `hooks.manifest` | Vale para toda a sessão | Precisaria saber quem é o chamador do `Agent`, e restringiria a sessão principal e os outros agentes | Rejeitado |
| D-11 allowlist | Hook `PreToolUse` no frontmatter do orquestrador chamando `scripts/data-agent-allowlist.sh` | Vale nos dois modos e só enquanto o orquestrador está ativo; testável com JSON sintético | Uma peça de maquinaria a mais; depende do nome do campo `subagent_type` (conferido por controle positivo) | Escolhido (REQ-10) |

### 3.1 Revisão do validador (2026-09-26): o que foi aceito, parcialmente aceito e rejeitado

Cada item foi remedido contra a árvore do worktree, a worktree `evals-100` e a documentação oficial antes de entrar; nenhum foi aceito só pelo texto do validador.

| Item | Veredito | Medição | O que mudou no change |
|---|---|---|---|
| 1 allowlist sem efeito como subagente | Aceito | Doc oficial citada no §1, conferida em 2026-09-26 | REQ-10, D-11, hook no frontmatter, cenário [16], mutação (e), trace no eval, casos de modo degradado |
| 2 `numeric` × `money-as-cents` | Aceito | `money-as-cents.md` §4 lido | C-1 do §2.9; eval de desenho do relacional; [17] |
| 3 RLS "ou" e Redis como fonte da verdade | Aceito | `data-governance.md` linhas 25 e 33, `data-cache.md` linha 13 | C-2 e C-3 do §2.9; desempate 1; caso `critico-conflito-rule` |
| 4 D-06 é "registra e segue" | Aceito | `conflict-handling.md` §2 e `agents/README.md` linha 15 | §2.9 com HITL H-01, bloco `CONFLITO`, REQ-11, TASK-01 |
| 5 formato de evals colide com `evals-100` | Aceito | 60 `evals.json` sem commit na `evals-100` (47 de agentes, 13 de skills), campos `skill_name`, `evals[]`, `id` inteiro, `expected_output`, `assertions`; `artifact_kind`/`artifact_path` em 30 deles | §2.7 adota o formato; [15] reescrito; D-10 |
| 6 A/B sem mecanismo | Aceito | `quality/executor.md` só injeta `SKILL.md`; raiz sem `.claude/`; `eval-aggregate.sh` lê `eval-*/grading.json` | §2.7 com instalação por braço, controle positivo de trace, extrator de roteamento e repetições |
| 7 severidade contra a própria regra | Aceito | Base: C-15/T-01 [Heurística], T-02 [Interp.], RMQ-AP-19 "Heurística detector"; N-07 e KFK-AP-02 da base usam `\b` | C-15, T-02 e RMQ-AP-19 viram `aviso`; N-07 e KFK-AP-02 com fronteira explícita e sósias na fixture limpa |
| 8 detecção estática faltante | Parcial | Padrões viáveis por linha ou por arquivo | Aceitos R-17, R-18, N-18, N-19, C-16, KFK-AP-09, RMQ-AP-20, D-AP-04, todos `aviso`. D-AP-02 ganha só detector de permissão total `".*"`: quem é usuário externo não é decidível por texto e fica em revisão |
| 9 mecanismo de PCI esquecido | Parcial | `check-data-governance.mjs` acha PAN/CPF/e-mail em chamada de log e campo marcado `forge:sensitive-field` sem classificação; não procura nome de campo em escrita de cache nem em schema de evento | Protocolo roda `check-data-governance.sh` e usa `data-classification.json` como autoridade; `adr-data-governance.md` citado. C-15 e T-02 ficam, como `aviso` complementar, porque cobrem superfície que o gate não cobre |
| 10 pontos de integração | Parcial | Revisores e `PROFILE.md` conferidos | Revisores e `PROFILE.md` entram (REQ-07, TASK-13). **Rejeitado** mudar a `description` do `capability-dispatcher`: a frente `evals-100` mede o disparo dessa skill (`.forge/evals/skills/capability-dispatcher/`), e mudar a `description` no meio da medição invalida o número dela; além disso o dispatcher carrega capability packs, e o disparo por cache, bucket ou RabbitMQ é da `description` do `data-engineer`, medida pelo eval de roteamento |
| 11 regra gRPC incompleta | Aceito | `internal-grpc-communication.md` linhas 5, 29–35 | Frase canônica do §2.4 com "síncrona", AsyncAPI, ADR e a distinção cliente próprio × terceiro |
| 12 scanner não determinístico | Aceito | `node-quality-scan/scripts/scan.sh` chama `rg` sem `--hidden --no-ignore --text`; `dotnet-quality-scan` idem | Contrato do §2.5 fixa as flags e a ordenação; [7] com arquivo oculto, ignorado e binário |
| 13 "deve" sem verificador | Aceito | [3] e [10] só olhavam seções | Casos críticos com critério próprio; [3], [10] e [17] conferem conteúdo; assertion global por caso |
| 14 três × quatro rótulos | Aceito | REQ-03 × §2.5 | REQ-03 com os quatro rótulos do design |
| 15 origem do ordinal | Aceito | `gate-ordinal.sh next` → w239; refs só com w239 e w248 | §2.6 e proposal §4 corrigidos; w250 declarado piso manual |
| 16 spec-delta atribui o delta ao w250 | Aceito | REQ-09, Notas | REQ-FHT-062 passa a exigir só a forma dos casos; o delta é evidência de verificação |
| 17 nome da ferramenta context7 | Aceito | Lista de ferramentas da sessão: `mcp__context7__query-docs` e `resolve-library-id` | Especialistas com `query-docs`; [3] recusa `get-library-docs` |
| 18 projeção fora do Claude e colisão por `name:` | Aceito como documentação | `sync-adapters.mjs`: `codex` sem alvo extra; `agents-skills` e `forge-cli` chamam `emitAgentsSkills`; `ENRICHABLE_DIRS` preserva por caminho | §2.2 e `agents/README.md` dizem o limite; §5 registra a colisão por `name:`; detector no `doctor` é follow-up |
| 19 grafo, segredo na fixture, n = 3 | Aceito | `graph.json` tem nó para `dotnet-quality-scan/scripts/scan.sh`; CI roda `check-secrets.sh range` no diff | Regeneração do grafo na TASK-17; fixture sem credencial e `check-secrets` no REQ-08; três repetições e critério acima do desvio-padrão |

**Follow-ups para o orquestrador registrar no ledger** (este change não chama `ledger-ops.sh`): (1) flags `--hidden --no-ignore --text` e ordenação em `node-quality-scan` e `dotnet-quality-scan`, com o mesmo cenário do [7]; (2) `mcp__context7__get-library-docs` → `query-docs` em `product-backlog`, `backend-engineer-dotnet`, `android-embedded-kotlin-engineer`, `frontend-engineer` e `fullstack-software-engineer`; (3) `doctor` acusar dois agentes com o mesmo `name:` em `.claude/agents/**`; (4) schema versionado para o formato skill-creator de `.forge/evals/**`, a combinar com a frente `evals-100`; (5) se o H-01 decidir (b), change e ADR para revisar `data-governance.md`.

## 4. Contratos e integrações afetados

- **Contrato de subagente do Claude Code:** campos `name`, `description`, `tools`, `skills`, `model`, `hooks`; `Agent(...)` como allowlist só no modo `--agent`; `hooks.PreToolUse` com matcher `Agent|Task` como restrição nos dois modos. Se a plataforma mudar a sintaxe, o gate [2], o [16] e o C2/C4 acusam; se mudar o nome do campo `subagent_type`, o controle positivo do §2.7 acusa antes do A/B.
- **Contrato do hook `data-agent-allowlist.sh`:** entrada padrão com o JSON de `PreToolUse`; exit 0 aceita, exit 2 nega com o motivo na saída de erro; fail-closed.
- **Contrato de skill (Agent Skills):** `SKILL.md` com frontmatter validado por `validate-frontmatter.sh`; `references/` sem frontmatter.
- **Contrato do scanner:** saída, códigos de saída, flags do motor e ordenação do §2.5, iguais nos seis; mudança é breaking para o especialista e exige atualizar o gate.
- **Formato de evals:** o do skill-creator usado pela frente `evals-100` em `.forge/evals/**`; `evals.schema.json` sem alteração e sem uso neste change.
- **Adapters:** sem alteração de código; a projeção é testada no [13].

## 5. Plano de migração / rollout

Aditivo. Consumidores recebem agentes, skills e o script do hook no próximo `forge update` (overlay de `MACHINERY_DIRS`) e no `init`; nenhuma configuração é exigida. Consumidor que tenha agente próprio em `agents/data/<mesmo arquivo>` fica protegido pelo tratamento de `ENRICHABLE_DIRS` (arquivo local preservado, conflito no relatório do update). Esse tratamento é **por caminho**: um agente do consumidor em outra pasta com `name: data-cache` não é detectado, e os dois passam a disputar o mesmo nome no Claude Code, que identifica o agente só pelo `name:`. Limite registrado; detector no `doctor` é follow-up (§3.1). Fora do Claude Code, as skills só chegam com o adapter `agents-skills` ou `forge-cli`; o `codex` puro recebe só o `AGENTS.md`. Nada a desfazer em rollback além de apagar os diretórios novos e o script do hook.

## 6. Riscos e mitigação

| Risco | Probabilidade | Impacto | Mitigação / detecção |
|---|---|---|---|
| Especialista contradiz rule do projeto (ex.: `data-governance.md` manda MongoDB para transacional) | Alta | Alto | Obediência à rule em C-1..C-3; HITL H-01 antes da implementação; em uso, bloco `CONFLITO` e parada (§2.9); caso `critico-conflito-rule` no eval |
| Orquestrador cria subagente fora dos seis (modo subagente ignora a lista de `Agent(...)`) | Alta sem hook | Alto | Hook `PreToolUse` fail-closed (REQ-10); [16]; trace do eval |
| Nome do campo `subagent_type` diferente do suposto | Baixa | Alto | Controle positivo com trace real antes do A/B; correção do script e do [16] antes de seguir |
| Falso positivo do scanner | Média | Médio | Severidade `aviso` para heurística e [Interp.]; fronteira explícita e sósias na fixture limpa; "o que o scanner não faz" no `SKILL.md`; exit 0 só com avisos |
| Scanner vê universos diferentes com e sem `rg` | Média sem as flags | Médio | Flags obrigatórias e ordenação no §2.5; [7] com arquivo oculto, ignorado e binário |
| Fato de plataforma envelhece (RabbitMQ 4.3, Kafka 4.2, Redis 8.6) | Alta | Médio | Marca de evidência com data; `mcp__context7__query-docs` nos especialistas para versão corrente; revisão semestral |
| Varredura recursiva sem `-a` em arquivo novo | Média | Baixo | Regra de redação no §2.5; revalidar w209 |
| Fixture dispara `check-secrets` no CI | Média sem a regra | Médio | Fixture sem credencial; `check-secrets.sh path tests/fixtures/w250` na TASK-02 e na TASK-17 |
| Grafo defasado | Alta sem a TASK | Baixo | `graph.sh build` na TASK-17 |
| Colisão de ordinal w250 com frente paralela | Média | Baixo | `gate-ordinal.sh check` antes do push; renomear se colidir |
| Eval com delta ≤ ruído em algum especialista | Média | Alto | Não aprova; revisão da skill e novo ciclo; nunca julgamento no olho |
| Aninhamento indisponível no consumidor | Baixa | Médio | Modo degradado com `PLANO DE ROTEAMENTO`, verificado por caso crítico; especialistas acionáveis direto |
| Contagem do README errada | Média | Baixo | Recalcular pelo critério do w200 na TASK de inventário |

## 7. Rastreabilidade

| REQ | Seção do design que o atende |
|---|---|
| REQ-01 | §2.1, §2.2, §2.7 |
| REQ-02 | §2.3 |
| REQ-03 | §2.5, §2.9 |
| REQ-04 | §2.5 (seção RabbitMQ) |
| REQ-05 | §2.5 (contrato e tabela de regras) |
| REQ-06 | §2.2 (checklist transversal), §2.4, §2.5 (detectores de exposição) |
| REQ-07 | §2.8, §4, §5 |
| REQ-08 | §2.6 |
| REQ-09 | §2.7 |
| REQ-10 | §1, §2.2, §3 (D-11), §4 |
| REQ-11 | §2.3 (bloco `CONFLITO`), §2.9 |
