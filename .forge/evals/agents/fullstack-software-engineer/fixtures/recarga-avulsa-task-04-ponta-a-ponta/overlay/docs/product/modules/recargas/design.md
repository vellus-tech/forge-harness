# Design — módulo recargas

- **DD-001** — Todo valor monetário trafega e é persistido como inteiro em centavos de BRL (`valorCentavos` / `valor_centavos`). Nunca ponto flutuante.
- **DD-002** — `POST /recargas` exige o header `Idempotency-Key` (UUID gerado pelo cliente por tentativa de compra). Chave repetida devolve a recarga já criada com HTTP 200; a primeira criação devolve 201. A unicidade é garantida por constraint no banco, não por checagem em memória.
- **DD-003** — Chamadas HTTP do portal passam exclusivamente por `apps/web/portal-recarga/src/api/client.ts`.
- **DD-004** — Erros públicos seguem o shape `{ code, message }` já definido em `contracts/openapi/api-recarga.yaml`; o contrato é atualizado antes do código.
