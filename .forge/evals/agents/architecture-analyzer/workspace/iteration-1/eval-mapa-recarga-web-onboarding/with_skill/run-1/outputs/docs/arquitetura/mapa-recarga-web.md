# Mapa de arquitetura — recarga-web

> Gerado a partir de `.forge/graph/graph.json` (11 nós, 19 edges, engine nativo). Ponto de partida para quem vai mexer na recarga via Pix.

## Camadas presentes e volume de código

| Camada | Arquivos | LOC | Papel |
|---|---|---|---|
| `src/api` | 2 | 16 | Controller HTTP e mapeamento de erro (`recarga-controller.ts`, `http-errors.ts`) |
| `src/application` | 2 | 23 | Casos de uso (`solicitar-recarga.ts`, `consultar-saldo.ts`) |
| `src/domain` | 2 | 23 | Entidades e regras de negócio (`cartao.ts`, `recarga.ts`) |
| `src/infrastructure` | 2 | 19 | Repositório e cliente de banco (`cartao-repository.ts`, `db/postgres-client.ts`) |
| `src/contracts` | 1 | 3 | Eventos publicados do agregado (`eventos-recarga.ts`) |
| não classificado (`unknown`) | 2 | 12 | `main.ts` (entrypoint/composição) e `shared/logger.ts` (utilitário transversal) |

Domain e application têm o maior volume de LOC (23 cada), seguidos de infrastructure (19) e api (16) — código bem distribuído, sem uma camada dominando desproporcionalmente.

## Fluxos de dependência (quem importa quem)

Direção observada, agregada por camada:

- `api` → `application` (`recarga-controller.ts` → `solicitar-recarga.ts`) — conforme a regra.
- `api` → `shared` (logger) — permitido para camadas não-domain.
- `application` → `domain` (`consultar-saldo.ts`, `solicitar-recarga.ts` → `cartao.ts`, `recarga.ts`) — conforme a regra.
- `application` → `api` (`solicitar-recarga.ts` → `http-errors.ts`) — **fora da direção permitida**, ver violações.
- `domain` → `contracts` (`cartao.ts`, `recarga.ts` → `eventos-recarga.ts`) — permitido por exceção (ADR-0003).
- `domain` → `infrastructure` (`cartao.ts` → `db/postgres-client.ts`) — **fora da direção permitida**, ver violações.
- `domain` → `domain` (`recarga.ts` → `cartao.ts`) — interno à camada.
- `infrastructure` → `domain` (`cartao-repository.ts` → `cartao.ts`) — conforme a regra.
- `infrastructure` → `infrastructure` (`cartao-repository.ts` → `db/postgres-client.ts`) — interno.
- `infrastructure`/`api`/`application`/entrypoint → `shared` (logger) — permitido para todas exceto domain.
- `main.ts` (entrypoint, fora da taxonomia de camadas) → `api/recarga-controller.ts`, `infrastructure/cartao-repository.ts`, `shared/logger.ts` — composição da aplicação, não é uma camada avaliada pela regra de direção.

## Violações de direção (candidatas)

Confirmadas contra `.forge/rules/architecture/camadas-recarga-web.md` (direção permitida: `api → application → domain`; `infrastructure → application, domain`; `shared` importável por todos menos `domain`; exceção aprovada: `domain → contracts/eventos-*`).

1. **`src/domain/cartao.ts` importa `src/infrastructure/db/postgres-client.ts`** (linha 1 do arquivo: `import { query } from '../infrastructure/db/postgres-client'`). Viola a proibição explícita nº 1 da regra (domain não pode importar infrastructure). É a violação mais grave do grafo: a entidade central `Cartao.creditar()` dispara SQL diretamente, acoplando a regra de negócio ao Postgres. Como você vai mexer na recarga via Pix, isso importa: qualquer novo evento de crédito (ex.: confirmação de pagamento Pix) que passe por `Cartao` herda esse acoplamento — o caminho limpo seria `domain` expor uma porta (interface) e `infrastructure` implementá-la, com a persistência disparada pelo `application`/`infrastructure`, não pelo `domain`.
2. **`src/application/solicitar-recarga.ts` importa `src/api/http-errors.ts`** (`saldoInsuficiente()`). Viola a proibição nº 2 (application não pode importar api). O caso de uso decide lançar um erro HTTP (`HttpError` com status 422) em vez de lançar um erro de domínio/aplicação e deixar a tradução para HTTP na borda (`api`). Ao adicionar o fluxo de Pix, um novo caso de uso que precise sinalizar falha (ex.: saldo divergente do valor creditado via Pix) tende a repetir esse padrão se não for corrigido antes.

Não há violação em `domain → contracts` (exceção aprovada ADR-0003) nem em `application → domain`/`infrastructure → domain`.

## Pontos de concentração (fan-in)

| Arquivo | Importado por (fan-in) |
|---|---|
| `src/shared/logger.ts` | 6 (recarga-controller, consultar-saldo, solicitar-recarga, cartao-repository, postgres-client, main) |
| `src/domain/cartao.ts` | 4 (consultar-saldo, solicitar-recarga, recarga.ts, cartao-repository) |
| `src/contracts/eventos-recarga.ts` | 2 (cartao.ts, recarga.ts) |
| `src/infrastructure/db/postgres-client.ts` | 2 (cartao.ts, cartao-repository.ts) |

`logger.ts` tem o maior fan-in, mas é um utilitário transversal sem lógica de negócio — baixo risco. **`cartao.ts` é o ponto de concentração que importa de fato**: é importado por duas camadas diferentes (application e infrastructure) mais outro arquivo de domain, e é o arquivo com a violação mais grave (acopla-se a `infrastructure`). Qualquer mudança em `Cartao` (como adicionar um método para crédito via Pix) tem raio de impacto amplo: dois casos de uso, o repositório e a outra entidade de domínio. Vale isolar a chamada a `query(...)` para fora de `cartao.ts` antes de estender esse fluxo.

## Recomendação para a mudança de Pix

Antes de adicionar o fluxo de recarga via Pix, considere corrigir a violação nº 1 (extrair a persistência de `Cartao.creditar()` para fora do domain, via porta/repositório) — assim o novo fluxo de confirmação de pagamento Pix nasce sem herdar o acoplamento a Postgres dentro da entidade. A violação nº 2 é mais localizada (só afeta `solicitar-recarga.ts`) e pode ser corrigida em paralelo, movendo a decisão de status HTTP para a camada `api`.
