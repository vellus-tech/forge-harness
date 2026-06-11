# 0001. Engine do grafo de código: subset local nativo (zero-dep)

- **Status:** accepted
- **Data:** 2026-06-11
- **Decisores:** Milton (gate HITL da W4.0)

## Contexto e Problema

O MVP4 introduz a Understanding Layer (§16): um grafo de código persistente e determinístico que serve de pré-flight para brownfield, feature, bugfix, review e archive. Era preciso decidir a engine que extrai nodes/edges (§22.7), entre uma ferramenta pronta com dependência externa (Graphify/Python) e um subset local construído por nós.

## Drivers da Decisão

- **Princípio zero-dependency nos projetos-alvo** (bash + Node ≥ 20 `.mjs`, sem build step) — sustenta MVP1–MVP3 e o doc rejeita dependência herdada do Spec Kit (§4.2).
- Privacidade: extração 100% local, sem rede.
- Custo de tokens: estrutura sem LLM (§16.2 — "AST local/determinístico para código; LLM apenas para semântica").
- Stack alvo: C#/.NET, Go, TypeScript/React, Kotlin/Android.
- Precisão estrutural suficiente para impact analysis confiável (§16.4).

## Opções Consideradas

1. **Graphify (Python)** — pronta, multi-linguagem, mas exige Python no alvo (viola zero-dep).
2. **Subset local nativo (Node, zero-dep)** — extractors deterministas por linguagem; LLM só para semântica.
3. **Subset local nativo + tree-sitter (WASM) opt-in** — (2) como default, com camada AST opcional via `web-tree-sitter` (WASM puro, sem `node-gyp`) já no MVP4.

Spike com protótipo executado (`docs/plans/spikes/w40-graph-engine-spike.md`): extractor zero-dep de imports JS/TS produziu o grafo real do workspace de forma determinista (hash estável), 0,07 s, sem dependência — provando a viabilidade da camada nativa.

## Decisão

**Opção 2 — subset local nativo (Node, zero-dep) como engine única no v0.1.** A prova de conceito confirmou comportamento determinístico e fiel para a extração estrutural sem AST externo, sem Python e sem dependência alguma no alvo. Mantém o princípio zero-dep **puro** em todo o caminho — sem dois modos de extração para manter — e reusa o padrão já consolidado do `discover-lite` (detecção de stack, fingerprints sha256, manifest) e dos validadores.

**tree-sitter (Opção 3) fica registrado como evolução v0.2**, acionada **somente se** os pilotos (Fase 8) mostrarem que a heurística nativa perde precisão relevante em alguma linguagem — aí entra como camada AST opt-in via `web-tree-sitter` (WASM, sem `node-gyp`), nunca via Python. **Graphify (Opção 1) descartada** por violar o zero-dep.

## Consequências

- **Positivas:** caminho único, sem dependência (privacidade, zero tokens para estrutura, coerência com `discover-lite`/validadores); schema de nodes/edges sob nosso controle (§16.3); cache incremental por fingerprint sha256; superfície de manutenção mínima na W4.1 (um extractor por linguagem, sem bindings WASM).
- **Negativas/débitos:** precisão é heurística, não AST completo — mitigada por `forge validate graph` (§19.5), que flagra cobertura insuficiente, e pela porta de saída explícita para tree-sitter na v0.2 se um piloto exigir.

## Histórico de revisão da decisão

- **2026-06-11 (inicial):** gate HITL escolheu a Opção 3 (nativo default + tree-sitter WASM opt-in já no MVP4).
- **2026-06-11 (revisão, mesma sessão, antes de qualquer implementação da W4.1):** com o protótipo confirmando comportamento determinístico e satisfatório da camada nativa pura, a decisão foi revista para a **Opção 2** (subset local nativo, tree-sitter adiado para v0.2). Como nada havia sido construído sobre a decisão anterior, o ADR foi atualizado in-place em vez de superseded.

## Links

- Spike: `docs/plans/spikes/w40-graph-engine-spike.md`
- Plano: `docs/plans/04-mvp4-brownfield-graph.md` (W4.0)
- Origem: gate HITL da W4.0 (decisão de Milton, 2026-06-11)
