# Laudo de arquitetura: validador de embarque (fornecedor)

## Sumário executivo

O grafo de código (`.forge/graph/graph.json`, gerado em 2026-10-04) registra dois edges que cruzam camadas na direção que a arquitetura limpa desaconselha: `domain` para `infrastructure` e `application` para `api`. Os imports foram conferidos nos arquivos-fonte, então a relação existe no código. O que não existe, neste repositório, é a regra que declara essa direção como proibida: o diretório `.forge/rules/architecture/` referenciado pelo agente não está presente, e o diretório `.forge/product/current/adr/` está vazio. Por isso, nenhuma violação pode ser classificada como CONFIRMADA contra uma regra contratual. Elas permanecem CANDIDATAS até que o contrato ou a regra de camadas seja apresentado.

## Fatos

- Grafo com 7 nós e 6 edges; 6 nós classificados em camada e 1 não classificado (`src/main.ts`, camada `unknown`).
- Edge `src/domain/embarque.ts` para `src/infrastructure/mqtt-publisher.ts`: o domínio importa e invoca `publicar` diretamente, produzindo efeito colateral de publicação dentro da entidade `Embarque.registrar`.
- Edge `src/application/validar-embarque.ts` para `src/api/status-http.ts`: a camada de aplicação importa a constante `STATUS_EMBARQUE_NEGADO` da camada de API.
- Edges permitidos pela direção usual: `api` para `application`, `application` para `domain`, `domain` para `contracts`, `main` para `api`.
- Pontos de concentração por fan-in: `src/domain/embarque.ts` e `src/api/status-http.ts` recebem um import cada no grafo; nenhum nó tem fan-in superior a 1 neste grafo.
- Limite da amostra: o grafo tem 7 arquivos e 13 linhas no maior nó. Ele não representa necessariamente o validador completo do fornecedor, e este laudo não verifica essa correspondência.

## Interpretação

Os dois edges são violações de direção no sentido clássico de camadas: a regra de dependência aponta para dentro, e o domínio não deveria conhecer infraestrutura nem a aplicação deveria depender de detalhes de transporte HTTP. O primeiro é o mais grave, porque mistura regra de negócio (limite de saldo de 520 centavos) com publicação de evento, o que também dificulta testar a regra isoladamente. O segundo é menos grave e pode ser resolvido movendo a constante para a camada de domínio ou de contratos.

## Recomendação

Não emitir o laudo como definitivo nem afirmar violação confirmada. Antes do envio, é necessário obter (1) o texto do contrato ou do anexo técnico que define as camadas e a direção de dependência permitida, e (2) a confirmação de que este grafo corresponde ao código entregue pelo fornecedor. Com essas duas peças, cada edge acima pode ser reclassificado como confirmado ou afastado com base na regra citada.

## Grafo de referência (graph/v0, íntegro)

```json
{
  "schema": "graph/v0",
  "generated_at": "2026-10-04T16:48:15.290Z",
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
