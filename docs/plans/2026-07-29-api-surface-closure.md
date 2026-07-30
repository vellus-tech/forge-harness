# Fechamento de superfície: converter em script os checks que o harness já especifica

## Contexto

Um avaliador no `Axis.SecretWeapon` encontrou à mão que **duas rotas que o contrato promete e as telas chamam não têm task de implementação em nenhuma das 89** (`LDG-0091`, P1). É o quarto membro de uma família: símbolo sem chamador de produção (`LDG-0084`, `LDG-0085`), módulo com contrato e sem superfície (`LDG-0090`), e agora o vão entre duas waves do plano.

### O diagnóstico real, verificado no repositório

O primeiro instinto — "falta detectar rota HTTP" — está errado sobre a causa. **O harness já especifica os dois checks que teriam pegado isso, e ambos são instrução para LLM, não código:**

1. `commands/specs/analyze.md:21`, item 6, manda cruzar o "Checklist de cobertura de superfície" do `requirements.md` contra design e tasks, e diz textualmente que é isso "que impede a lacuna clássica de parâmetro implementado sem superfície de acesso descoberta só depois do marco". **Não existe script `analyze`** — é comando `.md`.
2. `commands/specs/tasks.md:27` manda auto-verificar que "nenhuma dependência aponta para TASK inexistente ou posterior (ordem topológica válida)". **É checklist em markdown.**

O template do `requirements.md` chega a registrar o motivo de existir do artefato: *"Uma auditoria pós-marco já encontrou lacunas desse tipo tarde demais."* O harness conhecia a classe, criou o artefato que a captura, e delegou o cruzamento a um modelo.

### Quatro defeitos reproduzíveis hoje, sem escrever convenção nova

| # | Defeito | Evidência verificada |
|---|---|---|
| A | **`LDG-0091` está declarado no artefato** | `requirements.md:398` — `REQ-05 \| Liberação ... após wrap \| **endpoint no orquestrador** ... \| TASK-27, TASK-28, TASK-63, TASK-81`. Nenhuma das quatro produz rota: 27/28 são lógica, 63 é o YAML do contrato, 81 é a tela |
| B | **Dependência para wave posterior** | TASK-89 está na Wave 4 e depende de TASK-45, que está na Wave 7. A auto-checagem de LLM deixou passar |
| C | **A porta de saída por omissão** | O `manifest.yaml` do maior change de API **não tem `affects_surfaces`** — logo o `## Mapa endpoint → ação → recurso → policy` nunca foi exigido, e não existe no `requirements.md` |
| D | **Auto-certificação de wave** | `wave-ops.sh:137` — `gate_result="OK"` por default; `close` aceita o veredito do chamador e não roda gate nenhum |

**Correção a uma conclusão do agente Opus:** ele afirmou que "nenhuma cadeia de precedência sobre artefatos existentes consegue reproduzir o `LDG-0091` — a informação não está lá". A informação **está** lá (defeito A). O que não está é o *path literal* — o Checklist diz "endpoint no orquestrador", não `/internal/v1/orchestrator/.../reveal`. Portanto o check **não precisa do path** para disparar, e **não precisa da convenção `expõe:`** para existir. Isso reordena tudo: a primeira onda entrega valor com zero convenção nova.

## Resultado pretendido

Que os checks que o harness já especifica passem a ser executados por script, no ciclo de vida do harness — não por um modelo lembrando de conferir, nem por uma task que o projeto precisa se lembrar de escrever.

---

## Ondas

### Onda A — o parser de tasks e os dois checks que pegam A e B (gate `w130`)

Zero convenção nova. Reproduz dois defeitos reais no repositório real.

- `lib/tasks-graph.mjs` — parser das linhas `- [ ] TASK-NN — <texto> (rastreia: …; paths: …; depende: …)` em `[{id, n, status, wave, title, traces, paths, dependsOn, line}]`. Cuidado no `paths:`: brace-expansion de shell, diretórios e listas com vírgula — expande o expansível, trata o resto como literal, sem fingir precisão.
- **TSK-01..04** em `validate-spec.mjs` na transição a `tasks-ready`: dependência pendurada, ciclo, **dependência para wave posterior**, ID duplicado/com furo. Substitui a auto-checagem de `commands/specs/tasks.md:27`, que passa a citar o script.
- **SRF-01** — cruza o `## Checklist de cobertura de superfície` (que é **incondicional** no template e está preenchido no change real) contra o grafo de tasks: linha cuja coluna *Superfície* nomeia endpoint/API e cuja coluna *Coberto por task* não contém nenhuma task que produza superfície. Substitui o item 6 de `analyze.md`.
- **PBT**: sobre grafo gerado de N tasks em W waves, `TSK-03` acusa se e somente se existe aresta para wave posterior; o parser é idempotente e insensível a espaçamento.

Critério de "produz superfície" nesta onda, deliberadamente conservador: task cujo `paths:` inclui arquivo/diretório que o grafo classifica `layer:api`, **ou** cujo texto casa verbo HTTP + path. O relato do agente mostrou que isso tem falso negativo estrutural (a TASK-56 entregou endpoint declarando `paths:` só em `SecretWeapon.Orchestrator/`, com a rota nascendo em `SecretWeapon.Transport.Api`) — então o veredito de SRF-01 é **por REQ, não por task**: reprova quando *nenhuma* das tasks cobrindo aquele REQ produz superfície. Isso sobrevive ao caso da TASK-56 e ainda pega o REQ-05.

### Onda B — fechar a porta de saída (gate `w131`)

- **SRF-00** — se o change implica superfície de API (diff tocando node `layer:api`, ou `contracts/openapi|asyncapi/**`, ou task com verbo+path no texto) e `affects_surfaces` não contém `api`, **reprova** nomeando quantos arquivos de API e de contrato o change toca. Sem isso, todo o resto é opt-out por omissão — e o defeito C prova que a omissão acontece justamente no change grande.
- **`wave close` roda `runtime.gates`** em vez de aceitar `--gate OK` do chamador. `--gate FAIL` continua podendo reprovar; `--gate OK` deixa de substituir execução. Gate provando que um `--gate OK` mentiroso não fecha mais a wave.

### Onda C — contrato ↔ código, nas duas direções (gate `w132`)

- `lib/route-scan.mjs` — **duas passadas** (indexar produtores e raízes; compor transitivamente), porque a cadeia real tem dois saltos e três arquivos: `Program.cs` `MapGroup("/internal/v1/orchestrator")` → `MapOrchestratorEndpoints()` → `MapOrchestratorEventStreamEndpoints()`. O `scan()` por linha de `source-scan.mjs` **não serve**; só `collect()` é reusável. Dialetos: .NET (atributos + minimal API), Spring, Ktor, Express/Nest/Fastify.
- `normalizePath()` — remove constraint de rota (`{id:long}` → `{}`), colapsa parâmetro, tira barra final. **Sem isso são 3 falsos positivos imediatos no repo real; com isso, `SUR-01 = 0`.** Alvo natural de PBT: idempotente, invariante a renome de parâmetro.
- `lib/api-surface.mjs` — **união** das fontes (authz-map ∪ OpenAPI ∪ tabela endpoint→policy ∪ Checklist), com `sources[]` por endpoint. Precedência **só** para metadado divergente (`authz-map > OpenAPI > tabela`). União e não precedência-com-fallback: fallback deixa a fonte menos completa silenciar a mais completa, que é a forma do próprio defeito.
- **SUR-01 contrato→código (bloqueia)** — pega `LDG-0090`. **SUR-02 código→contrato (`warn` default, agregado por prefixo de grupo, allowlist de infra documentada)** — a direção que a TASK-66 tinha; bloqueando de saída mata o gate no dia um (11 achados no repo real, 9 de legado sem contrato). **`route_unresolved` é reportado, nunca descartado** — prefixo irresolúvel fazendo `SUR-02` passar em silêncio é a falha de pré-requisito ausente que o repo proíbe.

### Onda D — promessa em prosa com vencimento (gate `w133`)

O contrato do orquestrador declara dois paths e diz *em prosa* que revelação e liberação "entram quando as tasks que os implementam fecharem". Prosa não tem vencimento; é por isso que é o formato do defeito.

- **CON-01** — arquivo em `contracts/**` citando `TASK-NN`/`REQ-NN` em prosa sem `x-forge-planned` correspondente reprova.
- **CON-02** — `x-forge-planned` cuja task não existe, ou cujo path duplica path já declarado, reprova.
- **CON-03 (a razão de existir)** — `x-forge-planned` cuja task está `[X]` e cujo path não aparece como rota nem como path declarado reprova. **A promessa expira quando seu dono fecha.** Isenta de `SUR-01` enquanto a task está aberta, o que remove a única objeção legítima a declarar endpoint futuro.
- Convenção `expõe:` na task line entra aqui, **aditiva**: dá precisão de path ao SRF-01, sem ser o preço de entrada.

### Onda E — símbolo sem chamador de produção (gate `w134`)

Fecha `LDG-0084`/`LDG-0085`. O eixo do grafo de arquivos **não serve**: `EnsureMutualExclusivity` e o chamador que o corrigiu vivem na mesma pasta e mesmo namespace, então não há `using` nem edge — fan-in de arquivo é 0 com e sem defeito. O oráculo certo é o que o auditor humano usou: contagem de ocorrências do nome, particionada em teste/não-teste.

- `lib/symbol-usage.mjs` — fan-in por nome sobre `collect()`, com `composition_roots` e `framework_bases`.
- **WIR-01 (bloqueia)** — símbolo referenciado por ≥1 arquivo de teste e **0** não-teste além do declarante. "Testado mas não fiado" é altíssimo sinal e ruído quase nulo.
- **WIR-02 (warn)** — símbolo sem referência alguma; sinal fraco, pega DTO/enum legítimo.
- Escopo aos arquivos **tocados pelo change**, nunca repo inteiro — é literalmente a lição do `LDG-0085` ("varrer os tipos públicos **novos**").
- Verificação de graça no histórico real: `EnsureMutualExclusivity` em `5ac5b87^` → WIR-01 vermelho; em `HEAD` → verde.

### Onda F — norma e release

- `rules/testing/coverage-both-directions.md`: check de cobertura entre artefato e realidade roda nos **dois** sentidos, e **cobertura pertence ao ciclo de vida da ferramenta, não a uma task do projeto** — a TASK-66 era invenção local, e por isso pôde nascer unidirecional.
- `rules/architecture/surface-declaration.md`: proibição de promessa em prosa; `x-forge-planned`; `expõe:`.
- `api-and-contracts.md` passa a apontar o enforcement (hoje proíbe "endpoint sem OpenAPI" sem gate). `rules/README.md`, `docs/refer/forge-project-harness.md` §19.7, `CHANGELOG`, `npm run build:plugin`.

Paralelizável: A ∥ E. Depois B, C. Depois D, F.

---

## Bateria de reprodução contra o repositório real

Critério de aceite: **cada achado humano vira número de saída de script.** Contra `secret-weapon/Axis.SecretWeapon/.forge/worktrees/envio-com-identidade`.

1. **TSK-03** → exatamente 1 achado: `TASK-89 (W4) → TASK-45 (W7)`; 89 tasks parseadas, 0 furo/duplicata/pendurada.
2. **SRF-01** → reprova a linha `REQ-05 | ... | endpoint no orquestrador | TASK-27, TASK-28, TASK-63, TASK-81` **hoje, sem editar nada**. É a prova do `LDG-0091`.
3. **SRF-00** → reprova o `manifest.yaml` real por não declarar `affects_surfaces: [api]` tocando 12+ paths de API. Controle: acrescentar `- api` numa cópia → verde.
4. **SUR-01 = 0** e **SUR-02 = 11** (2 orquestrador + 9 legado agregados). Mutação: apagar um `MapPost` → SUR-01 vermelho nomeando o path.
5. **route-scan = 37 rotas**, incluindo a de dois saltos. Mutação: renomear o produtor no chamador → 1 `route_unresolved`, **não** silêncio.
6. **WIR-01** → vermelho em `5ac5b87^`, verde em `HEAD`. Se em `HEAD` sob escopo do change der dezenas de achados, a calibração falhou e a onda não passa.
7. **Controle global** — espelho em `mktemp -d`, sem mutação, verde nos seis itens. Sem isso, nenhum vermelho acima prova nada (a lição das sete mutações fantasma por `node_modules` ausente).

Suíte completa (`npm test`, ~7 min, desacoplada) 100% verde antes de cada commit — hoje 68/68.

**Ledger**: item para `negative_contract_test` do `authz-map` sem enforcement (resolvível pelo mesmo motor de fan-in da Onda E); e registrar no `Axis.SecretWeapon` a correção factual de que a TASK-66 está na **Wave 7**, não na 8 — o posicionamento do gate estava certo, a falha foi só de direção.

---

## Adendo — a família tem cinco membros, não quatro

Levantamento posterior no ledger do change encontrou `LDG-0092` (P1, `known-bug`, aberto), que eu não conhecia ao desenhar o plano:

> A cadeia envio → identidade → bloco → mascaramento → store **não existe em produção: nenhuma das 89 tasks a costura.**

É o mesmo predicado no nível mais alto de todos. Não falta uma rota nem um chamador: **falta o caminho inteiro**. Cada parte existe e nada as monta. Isso muda duas coisas no plano:

1. **Reforça a Onda E** (`WIR-01`, símbolo testado e não fiado). Uma cadeia que não existe em produção é, mecanicamente, uma sequência de símbolos cada um sem chamador no caminho que roda — exatamente o oráculo do `WIR-01`, aplicado em série.
2. **Sugere um sexto check, fora do escopo atual**: alcançabilidade de ponta a ponta entre nodes declarados como extremos de um fluxo. O harness tem a base (`graph-deps.mjs` faz BFS, `graph-govern.mjs` faz `reaches`), mas falta o artefato que declare os extremos. Não desenhei — merece item de ledger, não improvisação.

A progressão completa, do mais baixo ao mais alto nível: símbolo sem chamador (`LDG-0084`, `LDG-0085`) → módulo sem superfície (`LDG-0090`) → rota prometida sem task (`LDG-0091`) → **cadeia sem costura** (`LDG-0092`). Um predicado, cinco granularidades. Se o validador cobrir só as do meio, a classe volta pelas pontas.
