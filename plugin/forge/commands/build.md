---
description: Constrói o grafo de código persistente (.forge/graph/graph.json) com o engine nativo zero-dep — nodes (arquivos/camadas) + edges (imports/refs) deterministas. LLM só para summaries opcionais, cacheados por fingerprint.
argument-hint: ""
---

# /forge:graph build — construir o grafo de código

Engine: subset local nativo (ADR `0001-graph-engine`) — extração estrutural determinista, zero dependência, zero tokens.

## 1. Construção (determinista)

```bash
bash .forge/scripts/graph.sh build
```

Gera `.forge/graph/{graph.json, report.md, cache/}`. Nodes = arquivos de código (lang, loc, fingerprint estrutural, layer heurística); edges = imports/refs internos resolvidos. Summaries nascem `null` (a estrutura não precisa de LLM).

## 2. Validação

```bash
bash .forge/scripts/graph.sh validate
```

`forge validate graph` (§19.5): schema, integridade referencial, IDs duplicados, órfãos, cobertura de camadas, qualidade de summaries, compatibilidade com changed files.

## 3. Summaries (opcional, sob demanda)

Os nós vêm com `summary: null`. Para enriquecer a semântica (útil ao `/forge:onboard` e `/forge:c4`), invoque o agent `file-analyzer` (Agent tool) **apenas nos nós relevantes** (ex.: alto fan-in) — cada summary é cacheado por fingerprint, então mudança cosmética não re-summariza (zero tokens). Não summarize o repo inteiro de uma vez sem necessidade.

## 4. Relatório (2-3 linhas)

Nodes/edges/linguagens, nós por camada (do `report.md`), e quantos summaries estão stale. Aponte linguagens detectadas que o extractor nativo não cobre bem (candidatas à camada tree-sitter opt-in — ADR 0001) se houver diretórios de código grandes fora do grafo.

## Regras

- Não edite `graph.json`/`cache/` à mão — são gerados; custo/logs ficam fora do commit (§20).
- Em repo grande, comece pelo `/forge:discover` (inventário lite) antes do grafo completo (§16.1).
