# Spike W4.0 — Engine do grafo: Graphify vs subset local

| | |
|---|---|
| **Versão** | 1.0 |
| **Data** | 2026-06-11 |
| **Status** | Decidido (HITL 2026-06-11) — **Opção C**: subset local nativo (default) + tree-sitter WASM opt-in. ADR `0001-graph-engine` no baseline. |
| **Wave** | W4.0 (docs/plans/04-mvp4-brownfield-graph.md) |
| **Critérios** | §22.7 + §16.2 do doc de projeto |
| **Decisão registrada em** | ADR no baseline do workspace (`/forge:adr new`) após aprovação |

## Pergunta do spike

Qual engine constrói o grafo de código do Forge (`.forge/graph/graph.json`), atendendo aos critérios da §22.7: dependência (Python vs Node/nativo), privacidade (tudo local), custo de tokens, as linguagens da stack alvo (C#/.NET, Go, TypeScript/React, Kotlin/Android), schema do grafo, cache e facilidade de adapter?

## Princípio inviolável que enquadra a decisão

O Forge é **zero-dependency nos projetos-alvo**: scripts são bash + Node ≥ 20 `.mjs`, sem build step, sem `node_modules` no alvo (`ajv`/`yaml` são devDeps **apenas do workspace de desenvolvimento**). Isso já guiou MVP1–MVP3 (instalador, sync-adapters, validadores, delta-apply — todos zero-dep). Qualquer engine que exija runtime extra no alvo (Python, native bindings) atrita com o princípio central, não com uma preferência.

O doc reforça: §4.2 manda **não copiar do Spec Kit** "dependência de IDE" e telemetria por default; §16.2 prescreve "AST local/determinístico para código; LLM apenas para semântica".

## Opções avaliadas

### A — Graphify (Python)

Ferramenta pronta, multi-linguagem. **Exige Python no alvo** + suas dependências. Privacidade depende da configuração; custo de manutenção fora do nosso controle.

### B — Subset local nativo (Node, zero-dep) — extractors deterministas por linguagem

Extractors por linguagem em Node nativo: parse de imports/defs/refs por tokenização leve + regex robustas, derivando nodes (módulos/símbolos) e edges (import/call/ref). LLM **apenas** para semântica (summaries, intenção) — nunca para estrutura. Estende o padrão já provado no `discover-lite` (W2.3).

### C — Subset local + tree-sitter (WASM) como camada AST opt-in

Igual a B no default, mas com camada AST opcional via `web-tree-sitter` (WASM puro, sem `node-gyp`) para precisão quando o projeto-alvo aceitar instalar a dependência opcional. Adia o custo de precisão sem quebrar o default zero-dep.

## Evidência (protótipo executado neste spike)

Extractor estrutural zero-dep de imports JS/TS (≈30 linhas, Node nativo) rodado sobre `template/.forge/scripts/`:

```
nodes: 6, edges: 3
lib/delta-apply.mjs     -> lib/yaml-lite.mjs   (import)
lib/validate-archive.mjs -> lib/yaml-lite.mjs  (import)
lib/validate-spec.mjs   -> lib/yaml-lite.mjs   (import)
```

As 3 edges são **exatamente** as dependências reais (os três módulos que importam `yaml-lite`). Resultado **determinista** (hash idêntico em execuções repetidas), local, 0,07 s, zero-dep. Prova de viabilidade da extração estrutural sem AST externo para a primeira linguagem; o mesmo padrão se aplica a C#/Go/Kotlin com extractors irmãos.

## Matriz de decisão (critérios §22.7)

| Critério | A — Graphify (Python) | **B — Subset local nativo** | C — B + tree-sitter WASM |
|---|---|---|---|
| Dependência no alvo | ❌ Python + libs | ✅ nenhuma (Node nativo) | ⚠️ opcional (WASM, sem node-gyp) |
| Privacidade (tudo local) | ⚠️ depende | ✅ total | ✅ total |
| Custo de tokens (estrutura) | ✅ zero | ✅ zero (LLM só semântica) | ✅ zero |
| Stack de Milton (C#/Go/TS/Kotlin) | ✅ ampla | ⚠️ um extractor por linguagem (nosso) | ✅ grammars prontas |
| Precisão estrutural | ✅ alta | ⚠️ boa (heurística) | ✅ alta (AST real) |
| Schema do grafo (controle) | ⚠️ externo | ✅ nosso (nodes/edges §16.3) | ✅ nosso |
| Cache / incremental por fingerprint | ⚠️ adaptar | ✅ nativo (sha256, padrão discover) | ✅ nativo |
| Facilidade de adapter | ⚠️ engine externa | ✅ alinha aos scripts existentes | ✅ |
| Coerência com o princípio zero-dep | ❌ viola | ✅ preserva | ✅ default preserva |
| Esforço de implementação (W4.1) | médio (integração) | médio (extractors) | alto (B + bindings WASM) |

## Recomendação

**Opção B — subset local nativo (zero-dep) como engine única no v0.1.** Razões:

1. **Não quebra o princípio central** que sustenta todo o MVP1–3. Graphify (A) o viola frontalmente; o doc rejeita dependência de IDE/runtime herdada do Spec Kit.
2. **Privacidade e custo:** tudo local, zero tokens para estrutura (LLM só para summaries — §16.2).
3. **Coerência:** reusa o padrão do `discover-lite` (detecção de stack, fingerprints sha256, manifest) e dos validadores zero-dep. Schema de nodes/edges sob nosso controle (§16.3).
4. **Risco de precisão é gerenciável:** a evidência mostra extração estrutural fiel para imports; os extractors por linguagem nascem cobrindo o essencial (módulos, símbolos top-level, imports/refs) e a validação determinística (§19.5) flagra cobertura insuficiente.

**tree-sitter (C) fica registrado no ADR como evolução v0.2**, acionada **se** os pilotos (Fase 8) mostrarem que a heurística nativa perde precisão relevante em alguma linguagem — aí entra como camada AST opt-in, sem virar default. Isso mantém o MVP4 enxuto e o princípio intacto, com porta de saída explícita.

**Graphify (A) descartada** por violar o zero-dep — sua única vantagem (cobertura ampla pronta) não compensa a dependência Python que o projeto recusa por design.

## Consequências para a W4.1

- `/forge:graph build` = orquestração de extractors nativos por linguagem (detectados pelo discover) → `graph.json` (schema nosso) + `report.md` + `manifest.json` + `cache/`.
- `forge validate graph` (§19.5) valida schema/integridade/cobertura — e serve de rede de segurança para a heurística.
- Atualização incremental por fingerprint estrutural (sha256 do conteúdo normalizado) — mudança cosmética não reprocessa: zero tokens.
- LLM entra só na curadoria de summaries dos nós, opt-in e cacheado.

## Decisão final (HITL 2026-06-11)

**Opção C — subset local nativo (default) + tree-sitter WASM opt-in**, já no MVP4. Milton optou por antecipar a camada AST real (tree-sitter, não Python) em vez de adiá-la para v0.2: o default permanece zero-dep, e a precisão de AST fica disponível desde já para quem habilitar. Registrado no ADR `0001-graph-engine` do baseline. Impacto na W4.1: dois caminhos de extração (nativo + tree-sitter WASM) sob a mesma suíte de validação determinística (§19.5); `web-tree-sitter` + grammars viram dependência **opcional** do alvo (fora do commit).

## Controle de versão do documento

- Milton Silva - 2026-06-11 - Versão 1.0: spike comparativo com protótipo de evidência; recomendação Opção B (subset local nativo), tree-sitter como evolução v0.2.
- Milton Silva - 2026-06-11 - Versão 1.1: decisão HITL — **Opção C** (nativo default + tree-sitter WASM opt-in no MVP4). ADR `0001-graph-engine`.
