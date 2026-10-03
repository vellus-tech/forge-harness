# Mapa de arquitetura — recarga-web

Gerado a partir de `.forge/graph/graph.json` (11 nós, 19 arestas, engine nativo, cobertura de classificação de camada 81,8%). Este mapa serve de contexto rápido para quem vai mexer na recarga via Pix: mostra as camadas existentes, o tamanho de cada uma, quem depende de quem, onde a direção de dependência está sendo violada e onde o acoplamento está concentrado.

## Camadas e tamanho

| Camada | Arquivos | LOC | Observação |
|---|---|---|---|
| `api` | `http-errors.ts`, `recarga-controller.ts` | 16 | Camada de borda HTTP (controller + mapeamento de erro). |
| `application` | `consultar-saldo.ts`, `solicitar-recarga.ts` | 23 | Casos de uso, orquestram domínio e repositório. |
| `domain` | `cartao.ts`, `recarga.ts` | 23 | Entidades e regra de negócio (limite de recarga, crédito de saldo). |
| `infrastructure` | `cartao-repository.ts`, `db/postgres-client.ts` | 19 | Acesso a dado (Postgres) e implementação de repositório. |
| `contracts` | `eventos-recarga.ts` | 3 | Tipos de evento compartilhados entre domínio e futuros consumidores. |
| Não classificado (`unknown`) | `main.ts`, `shared/logger.ts` | 12 | `main.ts` é a composition root (é esperado que fique fora da taxonomia de camada); `shared/logger.ts` é utilitário transversal usado por todas as camadas — vale considerá-lo uma camada `shared` própria em vez de "não classificado". |

Total: 96 LOC em 11 arquivos TypeScript. Códigobase pequeno e ainda em formação — os problemas abaixo são baratos de corrigir agora e caros de arrastar para depois da mudança de Pix.

## Quem importa quem

```
main.ts
 ├─> api/recarga-controller.ts
 │    ├─> application/solicitar-recarga.ts
 │    │    ├─> domain/cartao.ts ──> infrastructure/db/postgres-client.ts   [VIOLAÇÃO]
 │    │    │                   └─> contracts/eventos-recarga.ts
 │    │    ├─> domain/recarga.ts ──> domain/cartao.ts
 │    │    │                    └─> contracts/eventos-recarga.ts
 │    │    ├─> api/http-errors.ts                                          [VIOLAÇÃO]
 │    │    └─> shared/logger.ts
 │    └─> shared/logger.ts
 ├─> infrastructure/cartao-repository.ts
 │    ├─> domain/cartao.ts (ver acima)
 │    ├─> infrastructure/db/postgres-client.ts ──> shared/logger.ts
 │    └─> shared/logger.ts
 └─> shared/logger.ts

application/consultar-saldo.ts ──> domain/cartao.ts (não é chamado a partir de main.ts hoje; ponta solta / não conectada ao controller)
                               └─> shared/logger.ts
```

A direção esperada num backend em camadas é `api → application → domain`, com `infrastructure` implementando interfaces que o domínio/aplicação definem (dependência apontando para dentro) e `contracts`/`shared` como eixos neutros que qualquer camada pode importar.

## Violações de direção de camada

1. **`domain/cartao.ts` importa `infrastructure/db/postgres-client.ts`** (`Cartao.creditar` chama `query(...)` diretamente). Isso inverte a seta que deveria apontar de infraestrutura para domínio: hoje a entidade de domínio conhece SQL e o client de Postgres. É a violação mais grave porque `Cartao` é o nó de domínio com mais fan-in (4) — qualquer teste ou reuso de `Cartao` arrasta infraestrutura de banco junto, e trocar de Postgres para outra coisa obriga mexer no domínio.
2. **`application/solicitar-recarga.ts` importa `api/http-errors.ts`** (usa `saldoInsuficiente()` para lançar `HttpError` com status HTTP). O caso de uso de aplicação não deveria conhecer o vocabulário HTTP (`status: 422`) — esse mapeamento é responsabilidade do controller/borda. Hoje, se a recarga via Pix precisar de um caso de uso reaproveitado fora de HTTP (ex.: fila, job), o erro HTTP vem junto.

Não há import cíclico entre os dois pontos acima nem em nenhum outro trecho do grafo — as violações são de direção, não de ciclo.

## Onde o acoplamento está concentrado

Por fan-in (quantos arquivos dependem dele — quanto maior, mais caro mexer sem quebrar consumidor):

| Arquivo | Fan-in | Leitura |
|---|---|---|
| `shared/logger.ts` | 6 | Ponto de acoplamento transversal esperado (logging); baixo risco por ser uma interface simples e estável. |
| `domain/cartao.ts` | 4 | Concentração real de risco: é a entidade central do domínio e, por causa da violação #1, também acopla quem a usa a Postgres indiretamente. É o arquivo a tratar com mais cuidado antes de tocar em Pix. |
| `contracts/eventos-recarga.ts` | 2 | Tipos de evento, acoplamento saudável (contrato compartilhado). |
| `infrastructure/db/postgres-client.ts` | 2 | Usado por `cartao.ts` (via violação #1) e por `cartao-repository.ts` (uso legítimo). |

Por fan-out (quantos outros arquivos ele arrasta — quanto maior, mais superfície de mudança em cascata ao alterá-lo):

| Arquivo | Fan-out | Leitura |
|---|---|---|
| `application/solicitar-recarga.ts` | 4 | É o caso de uso que a recarga via Pix provavelmente vai estender ou copiar; concentra domínio, contrato de erro HTTP (violação #2) e logging. |
| `main.ts` | 3 | Composition root, fan-out alto é esperado aqui. |
| `infrastructure/cartao-repository.ts` | 3 | Implementação de repositório, fan-out esperado. |

**Ponto de atenção específico para a mudança de Pix:** `solicitar-recarga.ts` é onde a nova via de recarga provavelmente vai entrar (paralelo ou dentro do fluxo atual). Ele já carrega duas violações de camada por vizinhança (depende de `domain/cartao.ts`, que por sua vez fura para infraestrutura, e depende diretamente de `api/http-errors.ts`). Vale limpar essas duas violações antes de adicionar a lógica de Pix, para não duplicar o padrão errado num segundo caso de uso.

## Observações adicionais

- `application/consultar-saldo.ts` não é importado por nenhum outro arquivo do grafo — não está com fan-in zero por ser dead code necessariamente, mas hoje não há nenhuma rota/controller em `api/` que o exponha; vale confirmar se falta o endpoint de consulta de saldo ou se ele é chamado por algo fora do escopo do grafo atual.
- `shared/logger.ts` e `main.ts` aparecem como camada `unknown` no grafo (20% dos nós, dentro do `layer_coverage.ratio` de 0,82). Isso é aceitável para `main.ts` (composition root não é uma camada de negócio), mas `shared/logger.ts` merece uma camada própria (`shared`/`cross-cutting`) na configuração do classificador, porque hoje ele mistura "não classificável" com "infraestrutura transversal legítima".

## Metodologia

Este mapa foi construído lendo diretamente `.forge/graph/graph.json` (nós, arestas, LOC e camada por arquivo) e o código-fonte de cada um dos 11 arquivos em `src/`, sem uso de skill ou agente especializado de análise de arquitetura — é o baseline `without_skill` do caso de eval `eval-mapa-recarga-web-onboarding`. Fan-in/fan-out foram contados manualmente a partir da lista de `edges` do grafo.
