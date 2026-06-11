# Plano MVP4 — Brownfield Graph + Understanding Layer

| | |
|---|---|
| **Versão** | 1.1 |
| **Data** | 2026-06-10 |
| **Status** | Aprovado para desenvolvimento |
| **Fases do doc** | Fase 6 (§22.7) + §16 (Understanding Layer) + §16.5 (C4, item v3 — resolução I4) |
| **MVP** | MVP4 (§23.4) |
| **Depende de** | MVP3 completo (W3.2 **e** W3.3 — a W4.0 usa `/forge:adr new`, entregue na W3.3) |
| **Backlog (§24)** | #15 (graph/impact completo) + `/forge:c4` (I4) |

## Objetivo

Tornar o Forge eficaz em repos legados e grandes: grafo de código persistente e determinístico, análise de impacto integrada ao fluxo (pré-tasks e pré-archive), onboarding e — produzindo entendimento, não só consumindo — diagramas C4 com HTML consolidado.

## Escopo

**Inclui:** decisão Graphify vs subset local (ADR), `/forge:graph build|query|update`, `forge validate graph` (§19.5), `/forge:impact`, `/forge:onboard`, `/forge:baseline extract` (fluxo brownfield §11.2), `/forge:c4` + `overview.html`, hook de atualização incremental.

**Não inclui:** waves/progress (MVP5); skills especialistas além de `c4-render` e `impact-scan` (MVP5/W5.1 — `impact-scan` nasce aqui como script e vira skill lá).

---

## Waves

### W4.0 — Spike de decisão: Graphify vs subset local

- **Objetivo:** decidir a engine do grafo pelos critérios da §22.7.
- **Entregáveis:**
  - Spike comparativo avaliando: dependência Python (Graphify) vs Node/nativo; privacidade (tudo local); custo de tokens; linguagens da stack de Milton (C#/.NET, Go, TypeScript/React); schema do grafo; cache; facilidade de adapter.
  - **ADR no próprio workspace** (usando `/forge:adr new` do MVP3 — dogfooding) com a decisão.
  - Recomendação default a validar no spike: **subset local** — AST determinista (tree-sitter ou compilador da stack) para nodes/edges; LLM apenas para semântica (summaries, intenção), conforme §16.2; evita a dependência Python que o doc rejeita no Spec Kit.
- **Depende de:** W3.2 e W3.3 (usa `/forge:adr new`)
- **Gate:** ADR aprovado (**HITL**). ✅ **CONCLUÍDA (2026-06-11):** spike com protótipo de evidência (`docs/plans/spikes/w40-graph-engine-spike.md`); decisão HITL = **Opção B — subset local nativo (zero-dep)** como engine única no v0.1 (após revisão na mesma sessão: a escolha inicial foi a Opção C, revista para B quando o protótipo confirmou determinismo satisfatório da camada nativa pura). ADR `0001-graph-engine` registrado no baseline do workspace (dogfooding do `/forge:adr`). **Consequência para a W4.1:** um único caminho de extração (extractor nativo por linguagem), sob a suíte de `forge validate graph` (§19.5); **tree-sitter adiado para v0.2**, acionável só se um piloto da Fase 8 exigir precisão de AST — sem dependência opcional no alvo no MVP4.

### W4.1 — Graph build + validação determinística

- **Objetivo:** grafo persistente e validável.
- **Entregáveis:**
  - `/forge:graph build` → `.forge/graph/{graph.json,report.md,manifest.json,cache/}` (§16.2); custo/logs locais fora do commit (§20).
  - `forge validate graph` (§19.5): schema de nodes/edges, integridade referencial, cobertura de camadas, IDs duplicados, nós órfãos, qualidade mínima de summaries, compatibilidade com changed files.
  - Hook de **atualização incremental por fingerprint estrutural**: mudança cosmética (comentário, whitespace) não dispara reprocessamento LLM — zero tokens (§16.2, padrão Understand Anything).
  - `/forge:graph update` integrado ao hook; `doctor` avisa staleness (§25).
  - `.forge/agents/graph/` (§8): agentes de análise (file analyzer, architecture analyzer — padrão Understand Anything §4.3) e o **graph reviewer** (§16.4), usado como gate opcional na W4.2.
- **Depende de:** W4.0
- **Gate:** `validate graph` → `OK` na fixture brownfield; rebuild após mudança cosmética não altera fingerprint nem consome tokens.

### W4.2 — Query, impact, onboard, baseline extract

- **Objetivo:** grafo em uso no fluxo, como pré-flight (§16, §16.4).
- **Entregáveis:**
  - `/forge:graph query` — `query/path/explain` antes de ler arquivos crus.
  - `/forge:impact` — diff impact de uma spec ou diff; **obrigatório para scale ≥ 3** (§11.2); integrado ao pré-flight do archive (passo 7 da §13.2, ponto deixado na W3.2) e recomendado antes de `/forge:tasks`.
  - `/forge:onboard` — tour de arquitetura/domínio para novos agentes/humanos (§16.4).
  - `/forge:baseline extract` — extrai baseline inicial de capabilities a partir de código/docs (fluxo brownfield §11.2); "graph reviewer" opcional como gate para brownfield grande (§16.4).
  - Script `impact-scan` (determinista; vira skill na W5.1).
- **Depende de:** W4.1
- **Gate:** impact de um diff conhecido na fixture lista **exatamente** os paths esperados (grep positivo); archive de change com código alterado exige impact atualizado.

### W4.3 — C4 + HTML consolidado (§16.5; paralela a W4.2)

- **Objetivo:** Understanding Layer que **produz** entendimento (greenfield e feature).
- **Entregáveis:**
  - `/forge:c4` → `.forge/graph/c4/{c1-context.mmd,c2-container.mmd,c3-component-<module>.mmd}` (Mermaid; Code opcional). Em greenfield deriva de design/contratos/data-model; em feature, atualização incremental dos módulos afetados.
  - `overview.html` em `.forge/graph/` (cópia opcional em `docs/product/`): C4 renderizados + índice de capabilities do baseline + estado de waves/progresso do change ativo + links para artefatos da spec. Gerado por **script determinístico** (Mermaid + template), sem custo de tokens além da curadoria.
  - Skill `c4-render` (entrada/saída estreitas, §17.7).
  - Convenções aplicadas: **sem pontos dentro de labels Mermaid**; sem em-dash em labels (gate grep-negativo).
- **Depende de:** W4.1
- **Gate:** HTML gerado renderiza os 3 níveis C4 na fixture; gate grep-negativo de pontos/em-dash em labels → `OK`.

---

## Definition of Done do MVP4

1. `graph build/validate/query/update` funcionais na fixture brownfield.
2. Atualização incremental por fingerprint (cosmético = zero tokens) demonstrada.
3. `impact` integrado ao pré-flight do archive e obrigatório para scale ≥ 3.
4. `onboard` e `baseline extract` produzem artefatos úteis na fixture brownfield.
5. `c4` + `overview.html` gerados de forma determinista.

## Verificação end-to-end

- Fluxo brownfield completo da §11.2 na fixture: `discover → graph build → onboard → baseline extract → spec new → impact → design → tasks → implement → verify → archive`, com o impact aparecendo no pré-flight.
- Diff sintético tocando 2 módulos → `impact` reporta os 2 e apenas os 2.
- `overview.html` aberto em navegador mostra C4 + capabilities + progresso.

## Pendências/observações

- A escolha da engine (W4.0) pode reduzir ou ampliar o esforço da W4.1; se o spike indicar integração Graphify viável sem Python no projeto-alvo, reavaliar.
- `c4`/`overview.html` são desacopláveis: se o cronograma apertar, podem ir para v0.2 sem quebrar DoD dos MVPs 1–3 (risco registrado no master plan).

## Notas de execução (2026-06-11 — MVP4 code-complete)

- **Engine:** subset local nativo (zero-dep), conforme ADR 0001 (decisão revista para Opção B). Tree-sitter permanece como evolução v0.2 acionável por piloto.
- **W4.1:** `graph build` extrai nodes (lang/loc/**fingerprint estrutural**/layer) + edges (imports JS/TS resolvidos; `using`→namespace C#; Go/Python best-effort). O fingerprint estrutural normaliza comentários/whitespace/**reflow de linha** (colapso total de whitespace) — comprovado no gate que mudança cosmética não altera o fingerprint nem o summary cacheado (**zero tokens**); mudança estrutural altera. `validate-graph` §19.5 completo; `graph.sh query|path` para lookup barato. Agents `file-analyzer`/`architecture-analyzer`/`graph-reviewer`; doctor avisa staleness. Contagem de agents 35→38 (cláusula aditiva C2 v1.1).
- **W4.2:** `impact` por alcançabilidade **reversa** no grafo (dependentes transitivos), com seeds de `--files`/`--diff`/`--change`. **Fechado o passo 7 da §13.2** que ficara pendente na W3.2: `validate-archive` exige `impact.json` fresco (fingerprint do grafo batendo) quando o change toca código e há grafo — ausente/stale ⇒ archive FAIL. `baseline extract` gera capability stubs por boundary (`services/<nome>`→capability), parte determinista; requirements ficam para curadoria. `onboard` via `architecture-analyzer`.
- **W4.3:** `c4` gera C1/C2/C3 (Mermaid, derivados do grafo) + `overview.html` (C4 + capabilities do baseline + changes ativos), determinista e zero-token. Convenção de labels (sem pontos, sem em-dash) garantida por sanitização e gate grep-negativo. Skill `c4-render`. `overview.html` usa Mermaid via CDN (artefato de visualização fora do commit).
- **Decisão de design:** `baseline extract` deriva capability do **segundo segmento** sob boundary roots (`services/billing`→`billing`); em projetos em camadas (`src/domain`) isso pega a camada — aceitável para v0 (stub revisável), ótimo para o layout `services/<nome>` de Milton.

## Controle de versão do documento

- Milton Silva - 2026-06-10 - Versão 1.0: plano inicial do MVP4.
- Milton Silva - 2026-06-10 - Versão 1.1: review crítico — dependência corrigida para MVP3 completo (W4.0 usa `/forge:adr new` da W3.3); explicitada a pasta `.forge/agents/graph/` da árvore §8 (analyzers + graph reviewer). Aprovado para desenvolvimento.
