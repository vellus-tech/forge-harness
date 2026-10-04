Análise de impacto do change 2026-09-rotacao-jwt rodada sobre o grafo existente (.forge/graph/graph.json). Sementes: src/auth/jwt.ts e src/auth/index.ts. Resultado: 7 arquivos impactados, dos quais 2 são as sementes e 5 são consumidores transitivos (src/middleware/auth.ts, src/middleware/rate-limit.ts, src/api/routes/users.ts, src/api/routes/payments.ts, src/api/server.ts).

Superfície exposta pela mudança no JWT:

Símbolos de auth expostos: sign(claims), verify(token) e o tipo Claims { sub, kid, exp }, exportados por jwt.ts e reexportados por auth/index.ts. Qualquer mudança de contrato nesses três símbolos (por exemplo, a rotação por kid alterando a assinatura, o formato do token ou o uso de kid em verify) propaga para os consumidores abaixo.

Endpoints HTTP afetados: a rota /me (getMe) depende de requireAuth, que chama verify. A rota /pay (pay) depende de requireAuth e de rateLimit, que também chama verify. Ou seja, as duas rotas da API mapeadas em server.ts ficam expostas à mudança de token.

Achado a verificar antes do archive: rateLimit recebe o header bruto e chama verify(header) sem remover o prefixo "Bearer ", enquanto requireAuth faz esse replace. Essa inconsistência já existe hoje e pode fazer verify falhar no caminho de /pay; não foi tocada aqui.

Limitações: a análise de impacto é por import entre arquivos, não por símbolo. As afirmações sobre símbolos vieram da leitura direta do código dos 7 arquivos. O grafo tem 9 nós com resumos marcados como stale, e 4 nós sem camada classificada.

Situação do change: o manifest está em status implemented, mas tasks.md não foi concluído, os gates estão todos false, a proposta ainda é template sem preenchimento, e archive.eligible está false com motivo "tasks not implemented". Antes de pedir o archive, esses pontos precisam ser resolvidos, senão o pré-flight do archive deve reprovar.

Registro: resultado bruto em .forge/specs/active/2026-09-rotacao-jwt/impact.json (gerado dentro do workspace de execução).
