# Laudo de arquitetura: violações de camada no código do fornecedor

## Sumário executivo

A análise estática do código-fonte (7 arquivos TypeScript em `src/`) confirma duas violações de dependência entre camadas. Ambas são dependências de camadas internas para camadas externas, contrariando o princípio de inversão de dependência da Clean Architecture. Não há, no repositório, a regra normativa do contrato (`rules/architecture/clean-architecture.md` não existe na árvore analisada), então a qualificação "violação contratual" depende da cláusula do contrato, que não foi analisada aqui.

## Violações confirmadas

### V1. Camada de aplicação depende da camada de API

Arquivo: `src/application/validar-embarque.ts`, linha 2. O import `STATUS_EMBARQUE_NEGADO` vem de `src/api/status-http.ts`. A aplicação deveria ser ignorante do transporte HTTP; a constante de status HTTP pertence à borda (API), e a aplicação não deveria conhecê-la. Aresta do grafo: `src/application/validar-embarque.ts` para `src/api/status-http.ts` (`kind: import`, `resolved: true`).

### V2. Camada de domínio depende da camada de infraestrutura

Arquivo: `src/domain/embarque.ts`, linha 1. O import `publicar` vem de `src/infrastructure/mqtt-publisher.ts`, e a entidade `Embarque.registrar` chama `publicar('embarques', evento)` diretamente, acoplando a regra de negócio ao transporte MQTT (hoje um `console.log`). Aresta do grafo: `src/domain/embarque.ts` para `src/infrastructure/mqtt-publisher.ts` (`kind: import`, `resolved: true`).

## Pontos de atenção (não classificados como violação)

Dependência de domínio para contratos (`src/domain/embarque.ts` para `src/contracts/eventos-embarque.ts`) não foi contada como violação, porque contratos são tipos de fronteira; a regra do fornecedor deve dizer se o domínio pode depender deles. Se a regra proibir, entra como V3.

`src/main.ts` está na camada `unknown` (ponto de composição, sem camada atribuída pelo engine). Ele não foi contado como violação, porque é a raiz de composição e depende da API. A cobertura de camadas do grafo é 0,8571 (6 de 7), e o `main.ts` é o único nó fora da taxonomia pelo heurístico.

O grafo marca `summaries_stale: 7` e nenhum nó tem resumo. Isso não afeta a conclusão, que depende só das arestas de importação.

## Limitações do laudo

O grafo gerado não contém campo de violação. As violações acima foram derivadas das arestas de importação com a regra de direção de dependência da Clean Architecture, porque a regra específica do contrato não está na árvore analisada. Os arquivos `.claude/agents` e `.forge/agents` aparecem como excluídos no status do Git da cópia de trabalho; isso não altera os arquivos de `src/`, que são a base da análise.

## Prova técnica: .forge/graph/graph.json

Conteúdo integral do arquivo gerado em `.forge/graph/graph.json`, na data de geração indicada dentro dele:

```json
{
  "schema": "graph/v0",
  "generated_at": "2026-10-04T16:48:16.318Z",
  "engine": "native",
  "root": "<RUN>/work",
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
