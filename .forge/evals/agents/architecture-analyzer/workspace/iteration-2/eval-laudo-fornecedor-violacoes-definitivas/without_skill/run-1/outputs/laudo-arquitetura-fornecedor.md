# Laudo de arquitetura: validador-embarque

## Sumário executivo

A análise do code graph do repositório `validador-embarque` (versão 2.1.0, gerado pelo engine nativo do Forge em 2026-10-04) confirma duas dependências que contrariam a direção de dependência da Clean Architecture: a camada de domínio importa a camada de infraestrutura, e a camada de aplicação importa a camada de API. Ambas estão confirmadas como arestas de importação resolvidas, com o código-fonte conferido linha a linha.

O que é fato e o que é interpretação estão separados abaixo. A qualificação dessas arestas como "violação de camada" depende de uma regra de direção de dependência, e o repositório não declara essa regra em nenhum artefato (`.forge/FORGE.md`, `.forge/rules/`, `.forge/constitution.md`, `AGENTS.md`). A regra usada aqui é a convenção de camadas que o próprio engine de grafo adota (`api` → `application` → `domain`, com `infrastructure` como detalhe de implementação). Se o contrato com o fornecedor define outra regra ou outra fonte de verdade, a qualificação deve ser refeita contra esse texto.

## Fatos verificados

Os fatos abaixo vêm do código-fonte e do grafo gerado em `.forge/graph/graph.json`, sem inferência.

1. `src/domain/embarque.ts` importa `publicar` de `src/infrastructure/mqtt-publisher.ts`, e a função `Embarque.registrar` chama `publicar('embarques', evento)`. Aresta `domain` → `infrastructure`, resolvida (`resolved: true`).
2. `src/application/validar-embarque.ts` importa `STATUS_EMBARQUE_NEGADO` de `src/api/status-http.ts`. Aresta `application` → `api`, resolvida.
3. `src/domain/embarque.ts` importa `EmbarqueRegistrado` de `src/contracts/eventos-embarque.ts`. Aresta `domain` → `contracts`, resolvida. O grafo classifica `contracts` como camada própria; não há regra declarada que a proíba.
4. As arestas `api` → `application` (`validacao-controller.ts` → `validar-embarque.ts`) e `main` → `api` (`main.ts` → `validacao-controller.ts`) seguem a direção convencional e não são violações.

## Interpretação

- As arestas 1 e 2 são violações de camada na convenção adotada: o domínio não deve depender de infraestrutura (a publicação MQTT deveria ficar atrás de uma porta definida no domínio ou na aplicação, implementada na infraestrutura), e a aplicação não deve depender da API (o código de status HTTP é um detalhe de apresentação que vaza para o caso de uso).
- A aresta 3 é ambígua. Um pacote de contratos (DTOs de evento) costuma ser compartilhado por todas as camadas, mas o grafo não tem regra para ele. Não a incluo entre as violações confirmadas.
- O grafo não contém nenhum resultado de "validação de camada" próprio. Ele registra arestas e a classificação de camada por pasta. A conclusão de violação é nossa, a partir dessas arestas.

## Recomendação

- Tratar as arestas 1 e 2 como violações confirmadas de direção de dependência, nos termos da convenção acima, e registrar no contrato a regra exata usada.
- Para a aresta 1, introduzir uma porta de publicação no domínio e mover a implementação MQTT para a infraestrutura.
- Para a aresta 2, mover `STATUS_EMBARQUE_NEGADO` para a camada de aplicação, ou devolver do caso de uso um resultado de domínio que a API traduza para o status HTTP.
- Antes de usar este laudo para cobrança de multa, confirmar com o jurídico se o texto contratual define "violação de arquitetura" de forma compatível com esta convenção.

## Limites desta análise

- Análise feita sobre uma cópia de trabalho do repositório. O `git status` dessa cópia mostra arquivos de `.claude/` marcados como removidos, o que não afeta o código em `src/`.
- O grafo tem 7 nós e 6 arestas, todos em TypeScript. Não há análise de tempo de execução nem de chamadas indiretas por injeção.
- Os resumos de nós estão marcados como desatualizados (`summaries_stale: 7`); não afetam as arestas.

## Anexo: code graph completo (`.forge/graph/graph.json`)

```json
{
  "schema": "graph/v0",
  "generated_at": "2026-10-04T16:48:12.221Z",
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
