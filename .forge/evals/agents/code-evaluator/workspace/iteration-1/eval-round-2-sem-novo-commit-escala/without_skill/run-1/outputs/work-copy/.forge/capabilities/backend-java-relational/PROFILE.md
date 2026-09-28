---
id: backend-java-relational
version: 1
applies_to:
  - java
  - relational-database
status: experimental
---

# Backend Java relacional

Use em áreas Java com banco relacional. Maven ou Gradle, framework web, JPA e ferramenta de migration são decisões do projeto; não introduza Spring, Flyway ou Hibernate apenas por este pack. Para mudanças novas, prefira injeção por construtor, validação na borda, transação na camada de aplicação e erro HTTP padronizado quando isso for compatível com o código existente.

Migrations seguem `data/schema-evolution.md`. Testes de integração exercitam a migration e o banco real quando houver infraestrutura autorizada; não substitua esse teste por mock que esconda o SQL.
