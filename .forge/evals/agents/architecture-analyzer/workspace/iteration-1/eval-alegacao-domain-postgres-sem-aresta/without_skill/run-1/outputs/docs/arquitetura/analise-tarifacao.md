# Análise de arquitetura — módulo de tarifação de integração

Data: 2026-09-26
Fonte: `.forge/graph/graph.json` (grafo estático de imports, gerado em 2026-09-26T17:17:01Z) e leitura direta dos arquivos em `src/`.

## Mapa de camadas

| Camada | Arquivo | Depende de |
|---|---|---|
| api | `src/api/tarifa-controller.ts` | `application/calcular-tarifa.ts` |
| application | `src/application/calcular-tarifa.ts` | `domain/tarifa.ts`, `infrastructure/postgres-tarifa-repository.ts` |
| domain | `src/domain/tarifa.ts` | `domain/tabela-tarifaria.ts` |
| domain | `src/domain/tabela-tarifaria.ts` | (nenhuma) |
| infrastructure | `src/infrastructure/postgres-tarifa-repository.ts` | `domain/tabela-tarifaria.ts` |
| (sem camada classificada) | `src/main.ts` | `api/tarifa-controller.ts` |

Fluxo de dependência observado: `main → api → application → {domain, infrastructure}`, e tanto `application` quanto `infrastructure` dependem de `domain` (tipo `TabelaTarifaria`). Isto é o sentido correto numa arquitetura em camadas/hexagonal: as bordas externas (api, infrastructure) apontam para dentro, para o domínio; o domínio não aponta para fora.

## Verificação da alegação (domain → infrastructure)

**Alegação do tech lead:** o domínio (`src/domain/tarifa.ts`) chamaria o `PostgresTarifaRepository` diretamente.

**Resultado da checagem:** não confirmado. O grafo `.forge/graph/graph.json` não contém nenhuma aresta `src/domain/tarifa.ts → src/infrastructure/postgres-tarifa-repository.ts`, e a leitura do arquivo confirma: `tarifa.ts` importa apenas `TabelaTarifaria` (um tipo do próprio domínio, em `src/domain/tabela-tarifaria.ts`) e não referencia `PostgresTarifaRepository` em nenhum ponto do código.

Quem de fato importa e instancia `PostgresTarifaRepository` é a camada de application, em `src/application/calcular-tarifa.ts`:

```ts
import { Tarifa } from '../domain/tarifa';
import { PostgresTarifaRepository } from '../infrastructure/postgres-tarifa-repository';

export async function calcularTarifa(input: {...}) {
  const tabela = await new PostgresTarifaRepository().tabelaVigente();
  return new Tarifa(tabela).calcular(...);
}
```

`Tarifa.calcular` recebe a `TabelaTarifaria` já resolvida via injeção no construtor — o domínio não sabe que a tabela veio do Postgres, nem depende do módulo de infraestrutura. Essa é exatamente a inversão de dependência esperada.

**Ponto de atenção real, mas diferente do relatado:** existe um comentário `TODO` em `src/domain/tarifa.ts` que descreve uma *intenção futura* de buscar a tabela vigente direto no `PostgresTarifaRepository` dentro do próprio domínio:

```ts
// TODO(tarifa): buscar a tabela vigente direto no PostgresTarifaRepository
// (src/infrastructure/postgres-tarifa-repository.ts) para evitar passar pela application.
```

Isso provavelmente foi o que o tech lead viu no código e interpretou como a violação já existente. Hoje é apenas um comentário — não há import nem chamada correspondente —, mas se esse TODO for implementado como está descrito, aí sim criaria a aresta domain → infrastructure e quebraria a regra de dependência (domínio não pode depender de infraestrutura). Recomendo tratar o TODO como um risco a vigiar, não como uma violação já registrada, e sinalizar ao autor do comentário que a abordagem proposta não deve ser implementada.

## Conclusão para a retro

- Não há violação de camadas hoje. O grafo e o código confirmam que `domain/tarifa.ts` depende apenas de outro artefato de domínio (`tabela-tarifaria.ts`); a leitura da tabela no Postgres é responsabilidade da camada de application, que orquestra domain + infrastructure.
- A causa provável do mal-entendido é o comentário TODO em `tarifa.ts`, que descreve (mas não implementa) exatamente esse acoplamento indevido.
- Ação sugerida: remover ou reformular o TODO para não sugerir a violação, e, se necessário, abrir um item de dívida técnica para decidir formalmente que esse caminho não será seguido.
