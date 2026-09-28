# Análise de impacto — change 2026-09-rotacao-jwt (scale 3)

## Escopo do change
Arquivos alterados declarados pelo usuário: `src/auth/jwt.ts` e `src/auth/index.ts`, para rotacionar a chave de assinatura por `kid` (key id).

## Método
Li manualmente os nove arquivos-fonte do projeto (não usei nenhum artefato de skill/agent — baseline `without_skill`) e reconstruí o grafo de dependências por inspeção de imports, cruzando com `work/.forge/graph/graph.json` (grafo já construído, 9 nodes / 11 edges, gerado 2026-09-26) como conferência. Os dois bateram.

## Cadeia de dependência (quem importa o quê)

```
src/auth/jwt.ts  (sign, verify, Claims)
  <- src/auth/index.ts        (re-exporta sign/verify/Claims)
       <- src/middleware/auth.ts        (requireAuth -> verify)
            <- src/api/routes/payments.ts  (pay)
            <- src/api/routes/users.ts     (getMe)
       <- src/middleware/rate-limit.ts     (rateLimit -> verify, usa claims.sub)
            <- src/api/routes/payments.ts  (pay)

src/api/server.ts expõe as rotas:
  '/me'  -> getMe   (routes/users.ts)
  '/pay' -> pay     (routes/payments.ts)
```

`src/billing/invoice.ts` e `src/utils/logger.ts` não dependem de JWT (logger é dependência de jwt.ts, não o contrário) — fora do raio de impacto.

## Partes da API expostas pela mudança

1. **`GET /me`** (rota `users.ts` -> `getMe`) — chama `requireAuth(h)` -> `verify(header)`. Qualquer mudança de comportamento/formato em `verify` (ex.: passar a exigir lookup de chave pública por `kid`, rejeitar tokens sem `kid` reconhecido, ou lançar erro diferente em chave não encontrada) muda o comportamento de autenticação desse endpoint diretamente.

2. **`POST /pay`** (rota `payments.ts` -> `pay`) — é o ponto de **maior exposição**, porque chama `verify` **duas vezes por request**, por dois caminhos independentes:
   - via `requireAuth` (middleware/auth.ts)
   - via `rateLimit` (middleware/rate-limit.ts), que também lê `claims.sub` diretamente do retorno de `verify`
   
   Isso significa que qualquer incompatibilidade entre o novo formato de claims/token (ex.: `kid` obrigatório, ou uma nova forma de erro quando a chave do `kid` não está mais no keyset) atinge esse endpoint em dois pontos de falha, não um. Se a rotação invalidar tokens antigos (ainda em uso por clientes com token não expirado) antes do keyset ter as duas chaves (antiga + nova) disponíveis, `/pay` passa a falhar tanto na autenticação quanto no rate limiting.

3. **Contrato de `Claims`** (`sub`, `kid`, `exp`) é reexportado publicamente via `src/auth/index.ts` — qualquer consumidor externo ao módulo `auth` que importe o tipo `Claims` (hoje: nenhum fora de `middleware/auth.ts` e `middleware/rate-limit.ts`, mas é a superfície de tipo pública do módulo) está sujeito a quebra se o formato mudar (ex.: adicionar campo `kid` obrigatório que hoje já existe, então sem risco aqui — mas se a rotação adicionar um novo campo, tipo `keyVersion`, o tipo muda).

## Risco específico de rotação por `kid`

O `jwt.ts` atual (antes do change) tem uma única chave implícita — `sign`/`verify` não fazem lookup de chave nenhuma (a implementação atual só faz base64url encode/decode, sem assinatura criptográfica real e sem seleção de chave). Introduzir rotação por `kid` implica adicionar um keyset (mapa `kid -> chave`) dentro de `jwt.ts`. Consequência prática para o raio de impacto:

- Se `verify` passar a lançar exceção para `kid` desconhecido (chave rotacionada/removida do keyset), **tokens emitidos com a chave anterior deixam de validar** assim que a chave antiga sair do keyset — isso derruba `/me` e `/pay` para qualquer sessão ativa com token antigo, até expirar naturalmente.
- Recomendação de mitigação (fora do escopo desta análise, só sinalizando): manter o keyset com pelo menos duas chaves (atual + anterior) durante a janela de expiração dos tokens (`exp`), e só remover a chave antiga do keyset depois que o maior `exp` emitido com ela já tiver passado.

## Resumo para arquivamento

Nível de exposição da mudança na API pública: **2 endpoints REST expostos** (`GET /me`, `POST /pay`), sendo `POST /pay` o de maior risco por chamar `verify` duas vezes via dois middlewares distintos. Nenhum endpoint fica fora do raio — não há rota que use auth por caminho diferente de `src/auth/index.ts`. Antes de `/forge:archive`, recomenda-se rodar a suíte de testes (não executada aqui — apenas leitura estática) cobrindo `/me` e `/pay` com: (a) token assinado com chave nova, (b) token assinado com chave antiga ainda dentro da janela de expiração, (c) token com `kid` desconhecido.

## Nota metodológica (baseline without_skill)
Esta análise foi feita por leitura manual de código-fonte e do grafo já existente, sem qualquer artefato de skill/agente do harness (proibido pelo protocolo do eval). Não tenho acesso a um comando `/forge:impact` determinístico neste modo; o resultado acima é best-effort humano/LLM, sujeito a erro que uma ferramenta determinística de grafo cobriria de forma mais confiável (ex.: edges dinâmicos/reflection não capturados por leitura estática).
