# Laudo de Arquitetura — Validador de Embarque (Fornecedor)

**Data:** 2026-09-26
**Escopo:** análise estática de dependências entre camadas do módulo `validador-embarque`, a partir do grafo de código do repositório (`.forge/graph/graph.json`).
**Objetivo:** identificar violações de camada como evidência técnica para o processo de apuração contratual.

## Metodologia

O código-fonte foi mapeado em um grafo de dependências (7 nós, 6 arestas, todos em TypeScript). Cada arquivo foi classificado em uma camada pelo nome do diretório (`api`, `application`, `domain`, `infrastructure`, `contracts`) e as arestas de importação entre arquivos foram inspecionadas para verificar se a direção de dependência respeita a regra convencional de arquitetura em camadas (camadas externas — `api`/`infrastructure` — dependem de camadas internas — `application`/`domain` —, nunca o inverso).

## Violações confirmadas

### 1. `domain` depende de `infrastructure`

- **Arquivo:** `src/domain/embarque.ts`
- **Importa:** `publicar` de `src/infrastructure/mqtt-publisher.ts`
- **Evidência (aresta do grafo):** `src/domain/embarque.ts -> src/infrastructure/mqtt-publisher.ts` (kind: import, resolved: true)
- **Por que é violação:** a camada de domínio é o núcleo do sistema e não deve conhecer detalhes de infraestrutura (protocolo de publicação, formato de transporte). O domínio publicando diretamente via MQTT inverte a direção de dependência esperada (infraestrutura deveria depender do domínio, nunca o contrário) e acopla a regra de negócio de embarque ao mecanismo de mensageria.

### 2. `application` depende de `api`

- **Arquivo:** `src/application/validar-embarque.ts`
- **Importa:** `STATUS_EMBARQUE_NEGADO` de `src/api/status-http.ts`
- **Evidência (aresta do grafo):** `src/application/validar-embarque.ts -> src/api/status-http.ts` (kind: import, resolved: true)
- **Por que é violação:** a camada de aplicação orquestra casos de uso e deve ser agnóstica ao protocolo de entrega (HTTP, MQTT, etc.). Importar uma constante de código de status HTTP da camada de API acopla a lógica de aplicação a um detalhe de transporte específico e inverte a direção de dependência esperada (API deveria depender da aplicação, nunca o contrário).

## Ressalva metodológica

Este repositório não contém, no momento da análise, um arquivo de regras de arquitetura formalizado (`.forge/rules/architecture/`) que declare explicitamente a ordem de camadas permitida para este projeto. As duas violações acima foram classificadas com base na convenção geral de arquitetura em camadas/hexagonal (dependências sempre apontando para dentro, em direção ao domínio) e na estrutura de diretórios adotada pelo próprio fornecedor (`domain`, `application`, `api`, `infrastructure`), não em uma regra escrita e versionada do projeto. Essa ressalva deve constar do laudo para fins de apuração contratual, já que a ausência de regra formal é um fato relevante para qualquer contestação técnica do fornecedor.

## Resumo

| # | Camada de origem | Camada de destino | Tipo de violação | Status |
|---|---|---|---|---|
| 1 | domain | infrastructure | dependência invertida | CONFIRMADA |
| 2 | application | api | dependência invertida | CONFIRMADA |

## Anexo — grafo de código completo (`.forge/graph/graph.json`)

```json
{
  "schema": "graph/v0",
  "generated_at": "2026-09-26T17:17:24.341Z",
  "engine": "native",
  "root": "<worktree-do-eval>/.forge/evals/agents/architecture-analyzer/workspace/iteration-1/eval-laudo-fornecedor-violacoes-definitivas/without_skill/run-1/work",
  "stats": {
    "nodes": 7,
    "edges": 6,
    "languages": [
      "ts"
    ],
    "summaries_stale": 7,
    "census": {
      "ts": 7
    },
    "layer_coverage": {
      "classified": 6,
      "unclassified": 1,
      "out_of_taxonomy": 0,
      "denominator": 7,
      "ratio": 0.8571
    }
  },
  "nodes": [
    {
      "id": "src/api/status-http.ts",
      "lang": "ts",
      "loc": 2,
      "fingerprint": "ce039e3ab0ccc331d72c1d5ef5bc77e29b697c6664a4e35ac4c09eae6bdf5f94",
      "layer": "api",
      "summary": null
    },
    {
      "id": "src/api/validacao-controller.ts",
      "lang": "ts",
      "loc": 8,
      "fingerprint": "7bd50d26318cece0e032f074882d9c2e0b6f01f91201cf910f9129e7462d0714",
      "layer": "api",
      "summary": null
    },
    {
      "id": "src/application/validar-embarque.ts",
      "lang": "ts",
      "loc": 8,
      "fingerprint": "e257fdbc6f8979e46fad05965c0d5db0dfc2b4c987e48b3e4d3d82f28777709a",
      "layer": "application",
      "summary": null
    },
    {
      "id": "src/contracts/eventos-embarque.ts",
      "lang": "ts",
      "loc": 2,
      "fingerprint": "2358de2428a2dedeee034a9251476b9f09d2bc84b0ff5d4165da750d6b8b3186",
      "layer": "contracts",
      "summary": null
    },
    {
      "id": "src/domain/embarque.ts",
      "lang": "ts",
      "loc": 13,
      "fingerprint": "da5e49a1f5edd97da71e7d32176a9f7b3b4b6f49b78d877485f5a9a96d29aa4d",
      "layer": "domain",
      "summary": null
    },
    {
      "id": "src/infrastructure/mqtt-publisher.ts",
      "lang": "ts",
      "loc": 4,
      "fingerprint": "ffb40e024add9ca1ff02ec2121407d819f8cc61a75eb11394cff3f111f7d31b4",
      "layer": "infrastructure",
      "summary": null
    },
    {
      "id": "src/main.ts",
      "lang": "ts",
      "loc": 4,
      "fingerprint": "2453b20b043beab8e99af759e37e13ab06cea44b96580b739a367c8e96700d83",
      "layer": "unknown",
      "summary": null
    }
  ],
  "edges": [
    {
      "from": "src/api/validacao-controller.ts",
      "to": "src/application/validar-embarque.ts",
      "kind": "import",
      "resolved": true
    },
    {
      "from": "src/application/validar-embarque.ts",
      "to": "src/api/status-http.ts",
      "kind": "import",
      "resolved": true
    },
    {
      "from": "src/application/validar-embarque.ts",
      "to": "src/domain/embarque.ts",
      "kind": "import",
      "resolved": true
    },
    {
      "from": "src/domain/embarque.ts",
      "to": "src/contracts/eventos-embarque.ts",
      "kind": "import",
      "resolved": true
    },
    {
      "from": "src/domain/embarque.ts",
      "to": "src/infrastructure/mqtt-publisher.ts",
      "kind": "import",
      "resolved": true
    },
    {
      "from": "src/main.ts",
      "to": "src/api/validacao-controller.ts",
      "kind": "import",
      "resolved": true
    }
  ]
}
```
