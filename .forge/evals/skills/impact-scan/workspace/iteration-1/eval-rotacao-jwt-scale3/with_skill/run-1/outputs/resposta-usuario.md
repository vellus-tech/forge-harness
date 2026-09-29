# Impact scan — change 2026-09-rotacao-jwt (scale 3)

Impact scan: 2 arquivos tocados (`src/auth/jwt.ts`, `src/auth/index.ts`) → 7 módulos afetados (incluindo os 2 tocados).

Módulos de alto risco (>= 2 importadores): `src/middleware/auth.ts` (2 importadores: `src/api/routes/users.ts`, `src/api/routes/payments.ts`) e `src/auth/index.ts` (2 importadores: `src/middleware/auth.ts`, `src/middleware/rate-limit.ts`).

`impact.json` gravado em `.forge/specs/active/2026-09-rotacao-jwt/impact.json` — freshness OK (`graph_fingerprint` do impact bate com o grafo atual; sha256 do `graph.json` também confere com o gravado no setup do fixture, confirmando que o grafo não foi reconstruído nesta execução, conforme exige a skill).

## Superfície de API exposta pela mudança no JWT

A rotação de chave por `kid` altera `sign()`/`verify()` e o formato de `Claims` (novo campo `kid`) em `src/auth/jwt.ts`, reexportados sem alteração de assinatura pública em `src/auth/index.ts`. Toda a cadeia de consumidores passa por `verify()`, então os dois endpoints HTTP do serviço ficam expostos à mudança:

- **`/me`** (`src/api/routes/users.ts` → `getMe`) — chama `requireAuth` (`src/middleware/auth.ts`), que chama `verify()`. Qualquer token emitido com um `kid` que o verificador não reconheça quebra a autenticação desse endpoint.
- **`/pay`** (`src/api/routes/payments.ts` → `pay`) — chama tanto `requireAuth` (`src/middleware/auth.ts`) quanto `rateLimit` (`src/middleware/rate-limit.ts`), e as duas passam por `verify()`. É o endpoint com maior superfície: duas rotas de código (auth e rate-limit) dependem da rotação de chave, além de tocar `src/billing/invoice.ts` (não afetado pelo JWT, mas está no mesmo endpoint).

`src/api/server.ts` apenas registra as duas rotas (`/me`, `/pay`) e entra no impacto por transitividade, sem lógica própria sensível ao JWT.

## Recomendação antes do archive

Como scale = 3 e o change toca código, o `impact.json` fresco é pré-requisito do pré-flight de `/forge:archive` (§13.2). Antes de arquivar, validar manualmente que:
1. O verificador (`verify()`) suporta múltiplos `kid` simultâneos durante o período de rotação (tokens antigos ainda válidos não devem quebrar `/me` nem `/pay`).
2. `rateLimit()` usa `sub` do claim, não o `kid` — confirmado pelo código atual, então a rotação de chave não deveria afetar as contagens de rate limit por usuário.
