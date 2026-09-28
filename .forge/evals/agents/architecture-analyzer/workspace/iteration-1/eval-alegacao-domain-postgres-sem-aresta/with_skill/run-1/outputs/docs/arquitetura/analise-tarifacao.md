# Análise de arquitetura — tarifação de integração

## Alegação da retro: não confirmada pelo grafo

A alegação de que `src/domain/tarifa.ts` chama o `PostgresTarifaRepository` direto (`src/infrastructure/postgres-tarifa-repository.ts`) **não se confirma no grafo**. `graph.sh path src/domain/tarifa.ts src/infrastructure/postgres-tarifa-repository.ts` devolve `NO PATH (no resolved import chain ...)`, e `graph.sh query src/domain/tarifa.ts` mostra que a única aresta de saída desse arquivo é `src/domain/tarifa.ts -> src/domain/tabela-tarifaria.ts` (import dentro da própria camada domain). Não existe aresta nem caminho de `src/domain/tarifa.ts` para qualquer arquivo de `src/infrastructure`.

O que provavelmente o tech lead viu é o comentário `TODO` no topo de `src/domain/tarifa.ts` ("buscar a tabela vigente direto no PostgresTarifaRepository ... para evitar passar pela application"). É uma intenção registrada em comentário, não uma dependência existente no código — não gera import, não aparece como edge no grafo. Não deve ser registrado como violação `domain → infrastructure`.

## Violação real: application → infrastructure

O grafo tem uma violação candidata de fato, mas em outra aresta: `src/application/calcular-tarifa.ts -> src/infrastructure/postgres-tarifa-repository.ts`. Conferida contra `.forge/rules/architecture/camadas-tarifacao.md`, essa aresta descumpre a regra 2 ("`src/application` importar `src/infrastructure` diretamente — a application depende de uma porta (interface) declarada em `src/domain`, e a implementação é injetada em `src/main.ts`"). Hoje `calcularTarifa` instancia `PostgresTarifaRepository` diretamente em vez de depender de uma porta declarada em `src/domain`.

## Camadas presentes

| Camada | Nós |
|---|---|
| api | 1 |
| application | 1 |
| domain | 2 |
| infrastructure | 1 |
| unknown | 1 |

Nó `unknown`: `src/main.ts` (não classificado em nenhuma das quatro camadas pelo grafo).

## Fluxos de dependência

- `src/main.ts` → `src/api/tarifa-controller.ts`
- `src/api/tarifa-controller.ts` → `src/application/calcular-tarifa.ts`
- `src/application/calcular-tarifa.ts` → `src/domain/tarifa.ts`
- `src/application/calcular-tarifa.ts` → `src/infrastructure/postgres-tarifa-repository.ts`
- `src/domain/tarifa.ts` → `src/domain/tabela-tarifaria.ts`
- `src/infrastructure/postgres-tarifa-repository.ts` → `src/domain/tabela-tarifaria.ts`

## Violações de direção (candidatas, conferidas contra `.forge/rules/architecture/camadas-tarifacao.md`)

- **`src/application/calcular-tarifa.ts` → `src/infrastructure/postgres-tarifa-repository.ts`** — candidata. Regra 2 da camadas-tarifacao.md proíbe application importar infrastructure direto; a dependência deveria passar por uma porta em `src/domain`, com a implementação injetada em `src/main.ts`.
- **`src/domain/tarifa.ts` → `src/infrastructure/postgres-tarifa-repository.ts`** — não existe no grafo (ver seção acima). Não é violação, porque não é dependência.

## Pontos de concentração (fan-in)

| Nó | Fan-in |
|---|---|
| `src/domain/tabela-tarifaria.ts` | 2 |
| `src/application/calcular-tarifa.ts` | 1 |
| `src/domain/tarifa.ts` | 1 |
| `src/infrastructure/postgres-tarifa-repository.ts` | 1 |
| `src/api/tarifa-controller.ts` | 1 |

`src/domain/tabela-tarifaria.ts` é o nó de maior fan-in (2 importadores: `src/domain/tarifa.ts` e `src/infrastructure/postgres-tarifa-repository.ts`), esperado para um tipo de domínio compartilhado — não indica acoplamento problemático por si só.

## Recomendação para a retro

Levar à retro a correção da aresta real (`application → infrastructure`) e não a alegada (`domain → infrastructure`): extrair uma porta `TarifaRepository` em `src/domain`, implementá-la em `PostgresTarifaRepository`, e injetar a implementação em `src/main.ts`. Também vale remover ou revisar o comentário TODO em `tarifa.ts`, já que ele descreve um acoplamento que romperia a regra 1 (domain não pode importar infrastructure) caso fosse implementado.
