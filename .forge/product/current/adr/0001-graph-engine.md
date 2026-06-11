# 0001. Engine do grafo de código: subset local nativo + tree-sitter opt-in

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
3. **Subset local nativo + tree-sitter (WASM) opt-in** — (2) como default, com camada AST opcional via `web-tree-sitter` (WASM puro, sem `node-gyp`) já disponível no MVP4.

Spike com protótipo executado (`docs/plans/spikes/w40-graph-engine-spike.md`): extractor zero-dep de imports JS/TS produziu o grafo real do workspace de forma determinista (hash estável), 0,07 s, sem dependência — provando a viabilidade da camada nativa.

## Decisão

**Opção 3** — subset local nativo como engine **default** (zero-dep, cobre o caso comum sem instalar nada) **mais** uma camada AST **opt-in** via `web-tree-sitter` (WASM) disponível desde o MVP4 para projetos que aceitem a dependência opcional em troca de precisão de AST real.

Racional: preserva o princípio zero-dep no caminho default (nada quebra para quem não opta), e ainda assim entrega AST real onde a precisão importa, sem `node-gyp` (WASM não compila nativo). Graphify descartada por violar o zero-dep; a camada AST entra como tree-sitter (não Python).

## Consequências

- **Positivas:** default sem dependência (privacidade, zero tokens para estrutura, coerência com `discover-lite`/validadores); AST real disponível quando desejado; schema de nodes/edges sob nosso controle (§16.3); cache incremental por fingerprint sha256.
- **Negativas/débitos:** dois caminhos de extração para manter (nativo + tree-sitter) na W4.1 — maior superfície; `web-tree-sitter` + grammars WASM (C#/Go/TS/Kotlin) viram dependência opcional do alvo, com seu próprio versionamento e tamanho (alguns MB por grammar, baixados sob demanda, fora do commit — §20). A validação determinística do grafo (§19.5) deve cobrir ambos os caminhos com a mesma suíte.

## Links

- Spike: `docs/plans/spikes/w40-graph-engine-spike.md`
- Plano: `docs/plans/04-mvp4-brownfield-graph.md` (W4.0)
- Origem: gate HITL da W4.0 (decisão de Milton, 2026-06-11)
