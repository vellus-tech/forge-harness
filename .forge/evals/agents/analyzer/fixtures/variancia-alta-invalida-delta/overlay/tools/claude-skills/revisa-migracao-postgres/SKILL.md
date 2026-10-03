---
name: revisa-migracao-postgres
description: Revisa arquivos de migração SQL de PostgreSQL (ALTER TABLE, CREATE INDEX) quanto a locks, reversibilidade e tempo de bloqueio. Use quando pedirem revisão de migração.
---

# Revisão de migração Postgres

1. Identifique o lock de cada DDL.
2. Prefira CREATE INDEX CONCURRENTLY.
3. Exija down ou justificativa.
4. Estime o bloqueio pelo tamanho da tabela.
