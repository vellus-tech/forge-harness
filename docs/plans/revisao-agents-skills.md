# Revisão de Conteúdo — Agents e Skills (template Forge)

| | |
|---|---|
| **Versão** | 1.1 |
| **Data** | 2026-06-10 |
| **Status** | Aplicado (W1.5) — pendências catalogadas com wave dona |
| **Escopo** | Auditoria dos 35 agents + 4 skills migrados na W1.1, antes do MVP2 |
| **Proveniência** | **Todos os achados são herdados do template `/init-project` original** (confirmado contra `snapshot/project-bootstrap/`). A migração W1.1 só reescreveu paths; o conteúdo é fiel ao original. Não há regressão introduzida pela execução do Forge. |

> Método: 6 revisores em paralelo (spec-generators, spec-validators, architecture+code-review, coding+review, engineering, skills). Checagens determinísticas prévias (paths/cross-refs/frontmatter) já estavam limpas.

## Decisões (HITL 2026-06-10)

1. **O template é universal** (qualquer projeto), não o template dos projetos de Milton. Critério de aplicação derivado: **exemplos didáticos de domínio permanecem** (todo template precisa de exemplos; pagamentos é o domínio de referência e está sempre marcado como exemplo) — **identificadores de pessoa/produto/serviço reais saem** ou viram exemplo explicitamente adaptável.
2. **Wave única (W1.5) para todas as correções acionáveis** — ALTO, MÉDIO e BAIXO. Itens estruturais com wave dona já planejada (689 refs `docs/product/`, XML em descriptions) permanecem nas waves donas (MVP2/3 e MVP5) por razão técnica, não por adiamento: o primeiro não tem destino antes do spec lifecycle existir; o segundo tem plano registrado de medição A/B antes de mudar comportamento.

---

## ALTO — todos corrigidos na W1.5

### Resíduos espúrios de projeto/pessoa real
- ✅ **`adr-writer.md`**: `@MiltonSilvaJr` → "os tech leads do projeto".
- ✅ **`product-backlog.md`**: menção ao LionClaw removida. Idem em `context.md` (header) e `validate-frontmatter.sh` (comentário de proveniência) — mesmo critério, descobertos na execução.
- ✅ **`security-reviewer.md`**: `auth-service` → "serviço emissor de tokens (ex.: ...)"; grep de permissões virou exemplo adaptável (`services/<auth-service>/src/`) com instrução de derivar símbolos do repo real; seção CDE/PCI condicionada ("aplicável apenas a projetos no escopo PCI") com paths como padrões de exemplo; anti-pattern generalizado.
- ✅ **`deploy-orchestrator.md` / `platform-reviewer.md`** (+ `deploy-wave.md`, mesmo padrão): ADRs `0022`/`0036` → "ADRs de plataforma em `docs/product/adr/` (ex.: ...), quando existirem". `naming.md` mantém `0036-...` como exemplo de formato (legítimo).
- ✅ **`module-validator.md`**: exemplo `cde-token-vault`/`token-vault-service` → `billing-engine`/`billing-service`. Idem `coding-status.md` (tabela de módulos).

### Contradições internas / refs quebradas
- ✅ **Conflito `T-NN` vs `TASK-NN`**: formato unificado em `TASK-NN` em task-coder (regex `TASK-[0-9]+`), sprint-orchestrator, deploy-orchestrator, coding-status, coding-loop e product-backlog. A convenção de label Jira `task:TASK-NN` que o sprint **assumia** foi efetivamente criada no product-backlog (não existia — descoberta da execução). Divergência aritmética entre cenários ilustrativos (waves contínuas vs reiniciadas) catalogada como cosmética.
- ✅ **`nfrd-generator.md`**: completado — §4 entrada, §5 saída, §6 processo (8 passos), §7 template do NFRD, §8 qualidade, §9 escrita, §10 convenções `NFR-<CAT>-NN` (14 categorias), §11 resumo final, §12 restrições. Modelado no `frd-generator`. Exemplo de ADR da §3.4 genericizado.
- ✅ **`frontend-engineer.md`**: §3 reescrita — skills de design são **opcionais e externas ao template**; carregar se disponíveis, senão a §13 é o piso de qualidade; obrigatoriedade do `ui-premium-veo3` removida; `load_skill` (tool inexistente) removido.
- ✅ **`fullstack-software-engineer.md`** (e os 4 engineering): seção Git virou **bimodal** — standalone (proibições preservadas; humano controla o repo) vs orquestrado (segue `commit_policy` explícita de payload do `task-coder`/`code-evaluator`; push só se a política mandar). Regra absoluta reformulada nos 4. Isso reconcilia §22 ↔ Modo B ↔ payload do task-coder.
- ✅ **`design-system-creator/SKILL.md`**: path corrigido (`.forge/rules/conventions/document-versioning.md`); `master` → `main` (×3).
- ✅ **engineering (4)**: `.forge/context/<arquivo>.md` (dir inexistente) → `.forge/context.md` (entrada única com as seções); dedup do item `docs/product/adr/` na lista de leitura.
- ✅ **`frd-nfrd-validator.md`**: seção `## 18. ADRs Sugeridos` adicionada ao template do relatório (coerente com §11.2/§11.3).
- ✅ **`code-evaluator.md`**: duplicação "ou `<modulo>` ou `<modulo>`" removida.

---

## MÉDIO — todos corrigidos na W1.5

- ✅ **`clean-architecture-reviewer.md`**: nota explícita de escopo de stack (.NET) com instrução de adaptação para outras stacks (renomear quebraria cross-refs; descartado).
- ✅ **`ddd-architect.md`**: Passo 12 agora gera os **4 artefatos** do context-map (`README/relations/patterns/diagram.md`) com templates — fecha o contrato com `ddd-validator`/`module-generator`/`module-validator`; tabela de artefatos obrigatórios estendida; §4.2 alinhada.
- ✅ **`task-coder.md`**: `case "$STACK"` → `case "$DOMINANT_STACK"` com ramos alinhados ao detector (`dotnet|frontend|android|none`).
- ✅ **engineering (4)**: tools concedidas no frontmatter — `Bash` + `mcp__context7__{resolve-library-id,get-library-docs}`; `Agent` no fullstack (router Modo B). **Descoberta da execução:** `task-coder` também invocava specialists "via Agent tool" sem tê-la — concedida.
- ✅ **`product-backlog.md`**: `mcp__context7__query-docs` → `get-library-docs` (frontmatter + corpo).
- ✅ **`quality-reviewer.md`**: linha `.kiro/` reformulada como guard preventivo (sem pressupor migração de Kiro). Demais guards anti-`.kiro` dos spec agents mantidos (defensivos, válidos universalmente).
- ✅ **`discovery-agent.md`**: caminho oficial `docs/discovery/discovery-notes.md` (fallback de leitura para legado na raiz); `run-spec-pipeline` alinhado — fecha o contrato com frd/trd-generator.
- ✅ **Paths de ADR**: canônico `docs/product/adr/` em 12 arquivos (incluindo o próprio comando `/forge:new-adr`, que criava em `docs/adr/`). Exceções intencionais: lista de inspeção do discovery-agent e fallback legado documentado do trd-generator.
- ✅ **`backend-engineer-dotnet.md`**: §5 ganhou nota "Layout de referência" (proibições valem para repos que adotam o padrão); `core-money` virou exemplo.

---

## BAIXO — aplicados ou com dono

- ✅ **Model IDs**: `claude-{sonnet-4-6,opus-4-7,haiku-4-5}` → aliases `sonnet`/`opus`/`haiku` nos 35 agents (future-proof; resolve no runtime da instalação).
- ✅ **`using-git-worktrees`**: renumeração corrigida (0,1,2,3 — sem furo).
- ◻ **Viés de domínio nos exemplos** (pagamentos/transporte): **mantidos por decisão** (template universal precisa de exemplos; domínio de referência ok). Identificadores reais saíram (acima).
- ◻ **Acoplamento a `docs/product/`** (689 refs): wave dona MVP2 (commands → change ativo) e MVP3 (agents → baseline). Sem destino antes disso.
- ◻ **XML em descriptions** (DEBT-W1.1-XML, 13 arquivos: 10 agents + 2 commands + 1 skill): wave dona MVP5 com medição A/B (mudar description = mudar triggering).

---

## Descobertas da execução W1.5 (não estavam na v1.0)

1. **Rules e `context.md` carregam o mesmo acoplamento** ao projeto de referência (`jwt-permissions.md` descreve um bug de UM repo com paths/símbolos reais; `jwt-authentication.md`, `nbr-5891-rounding.md`, `tdd.md §PBT core-money`, exemplos docker com `auth-service`; `context.md` "Team stack defaults" com o contexto regulado). **Fora do escopo desta revisão (agents+skills) e desta wave.** Tratamento exige decisão própria: o contrato C3 congela 27 rules; provável separação "rules core vs rules de exemplo/domínio" na migração MVP2/MVP3. Pendência registrada.
2. **Label Jira fantasma**: a convenção `task:TASK-NN` que `sprint-orchestrator`/`deploy-orchestrator` consomem não era produzida por ninguém — agora o `product-backlog` a grava (com nota de desambiguação por módulo no JQL).
3. **`task-coder` sem tool `Agent`** no frontmatter (mesma classe do achado dos engineering) — corrigido.
4. **Bug de gate pré-existente** (não é regressão da W1.5; w12 falhava em develop puro): o check de placeholders órfãos do doctor não excluía `.forge/templates/` — que carrega `<PROJECT_*>` por design — e o `install.sh` os **destruía** ao substituir na árvore inteira (o template instalado deixava de ser template). Corrigidos doctor, install e gate w13; w12/w13/w14 verdes com exit codes reais (a rodada anterior mascarava exit code com pipe).
5. **Contagem do DEBT-XML**: confirmados 11 arquivos em agents+skills (10+1) + 2 commands = 13 da nota original; idêntico no snapshot (nenhuma description alterada pela W1.5).

## O que está SAUDÁVEL (não precisou de ação)

- Cross-refs entre agents: todas resolvem; nenhuma quebrada.
- Consistência validator↔generator (specs): sólida nos 6 pares (estruturas, status, versionamento batem).
- Skills `verify-build`, `verify-diff-claims`, `using-git-worktrees`: limpas e bem integradas ao `code-evaluator`.
- Namespace `/forge:*`: consistente em todas as invocações de comando.

## Controle de versão do documento

- Milton Silva - 2026-06-10 - Versão 1.0: consolidação da revisão de 6 revisores paralelos.
- Milton Silva - 2026-06-10 - Versão 1.1: decisões HITL (universal; wave única) e aplicação na W1.5 — ALTO/MÉDIO 100% corrigidos, BAIXO aplicado ou com wave dona; descobertas da execução registradas (rules acopladas, label Jira fantasma, Agent tool no task-coder, bug de gate templates/placeholders).
