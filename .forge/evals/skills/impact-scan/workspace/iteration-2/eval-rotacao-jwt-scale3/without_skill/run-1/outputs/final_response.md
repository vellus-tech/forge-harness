Análise de impacto do change `2026-09-rotacao-jwt` rodada com `.forge/scripts/impact.sh --change` sobre o grafo existente. Resultado: 2 seeds (`src/auth/jwt.ts`, `src/auth/index.ts`) impactam 7 arquivos. Nenhum arquivo foi alterado.

**Fatos (saída da análise e leitura do código)**

Superfície exposta pela mudança no JWT:

- Módulo `src/auth/index.ts` reexporta `sign`, `verify` e o tipo `Claims` (`{ sub, kid, exp }`). É a API pública do módulo de autenticação.
- Middleware `src/middleware/auth.ts`: `requireAuth(header)` remove o prefixo `Bearer ` e chama `verify`.
- Middleware `src/middleware/rate-limit.ts`: `rateLimit(header)` chama `verify(header)` diretamente, sem remover o prefixo.
- Rotas HTTP em `src/api/server.ts`: `/me` (`getMe`, devolve `sub`) e `/pay` (`pay`, chama `requireAuth` e `rateLimit`, devolve o total da fatura).

Cadeia de impacto: `jwt.ts` -> `auth/index.ts` -> `middleware/auth.ts` e `middleware/rate-limit.ts` -> `routes/users.ts` e `routes/payments.ts` -> `server.ts`.

**Problemas encontrados ao ler o código**

1. A rotação por `kid` não aparece no código. `sign` apenas serializa o JSON em base64url, sem chave e sem assinatura. `verify` apenas decodifica, sem checar assinatura, `kid` nem `exp`. O status do change está como `implemented`, mas o código atual não contém a rotação descrita. Vale checar se o commit certo foi analisado.
2. Bug em `/pay`. `pay` chama `requireAuth(h)`, que remove o `Bearer `, e depois `rateLimit(h)` com o header cru. Testei localmente com Node: `verify("Bearer " + token)` lança `SyntaxError`. Com qualquer header real, `/pay` falha antes de cobrar. Isso é consequência direta da superfície exposta pelo JWT.
3. Os artefatos do change (`proposal.md`, `requirements.md`, `design.md`, `tasks.md`, `spec-delta.yaml`) ainda são templates com placeholders. O `manifest.yaml` diz `archive.eligible: false` por "tasks not implemented". Pelo estado atual, o archive não deve ser pedido.

**Interpretação**

Na superfície atual, a mudança afeta a autenticação de `/me` e `/pay` e qualquer consumidor de `auth/index.ts`. Como o `verify` não valida assinatura, rotacionar chaves por `kid` hoje não teria efeito de segurança. Recomendo corrigir o `/pay` e preencher os artefatos antes do archive.

**Não verificado**

- O grafo foi construído antes desta análise. Não rodei `/forge:codegraph` de novo, então não confirmei se ele reflete o código atual além dos fingerprints.
- Não há testes no projeto para esses caminhos. O bug de `/pay` foi reproduzido só com um snippet isolado, não pela rota.
- `git status` mostra `.claude/agents/README.md` deletado no working tree. Não investiguei.
