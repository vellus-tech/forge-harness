A análise de impacto do change 2026-09-rotacao-jwt foi executada sobre o grafo existente (.forge/graph/graph.json, gerado em 2026-10-04 às 16:46 UTC). O resultado foi gravado em .forge/specs/active/2026-09-rotacao-jwt/impact.json.

Seeds: src/auth/jwt.ts e src/auth/index.ts. Impactados (7): src/auth/jwt.ts, src/auth/index.ts, src/middleware/auth.ts, src/middleware/rate-limit.ts, src/api/routes/users.ts, src/api/routes/payments.ts e src/api/server.ts.

Superfície exposta pela mudança no JWT. O módulo src/auth/index.ts reexporta três símbolos: sign, verify e o tipo Claims (sub, kid, exp). Quem consome verify é o middleware: requireAuth (src/middleware/auth.ts) e rateLimit (src/middleware/rate-limit.ts). Esses dois alimentam as rotas da API: GET /me (getMe, em src/api/routes/users.ts) e /pay (pay, em src/api/routes/payments.ts). A tabela de rotas fica em src/api/server.ts. Ou seja, toda a superfície autenticada da API (/me e /pay) passa por verify. O sign não tem consumidor no grafo, mas continua exportado pelo index, portanto qualquer mudança de assinatura nele é mudança de API pública do módulo.

Duas observações que o impacto não resolve e que você precisa ver antes do archive:

1. O código atual não implementa rotação por kid. verify só faz JSON.parse do token, sem checar assinatura nem escolher chave pelo kid, e sign só inclui o kid nos claims. Os artefatos do change (design.md, tasks.md e spec-delta.yaml) ainda estão com o texto de template, sem decisões nem tarefas preenchidas, embora o manifest diga status implemented. Antes do archive, vale confirmar se a implementação está no branch certo ou se o manifest está adiantado.

2. O grafo tem a aresta src/auth/index.ts -> src/auth/jwt.ts duplicada, e a fingerprint do grafo não bate com o SHA-256 bruto dos arquivos. Pode ser só o critério de fingerprint estrutural, mas não verifiquei. Se quiser precisão total, rode /forge:update antes de confiar nos números.

Não rodei testes nem build: a tarefa era a análise de impacto, e o script não exige rede.
