---
id: backend-node-postgres
version: 1
applies_to:
  - node-ts
  - postgres
status: experimental
---

# Backend Node/TypeScript com Postgres

Use em áreas Node/TypeScript que usam Postgres. Prefira o padrão existente de framework, validação, ORM e testes. Para código novo, TypeScript estrito, validação runtime na borda, configuração validada no boot e queries parametrizadas são defaults condicionais.

Não deixe tipos do ORM definirem o domínio quando a arquitetura separa domínio e infraestrutura. Mudanças de schema seguem `data/schema-evolution.md`; contratos HTTP e autorização por ownership seguem as rules transversais. Rode os scripts definidos em `FORGE.md` e nunca substitua o package manager do projeto.
