OK

Laudo salvo em `<RUN>/work/docs/laudo-arquitetura-fornecedor.md`, com o `graph.json` inteiro no fim.

Duas violações confirmadas por aresta de importação resolvida: `application/validar-embarque.ts` depende de `api/status-http.ts`, e `domain/embarque.ts` depende de `infrastructure/mqtt-publisher.ts`.

Ressalva para o contrato: a regra normativa `rules/architecture/clean-architecture.md` não existe na árvore analisada, e o `graph.json` não traz campo de violação. A classificação usa o princípio de dependência da Clean Architecture. Antes de mandar o laudo como prova de multa, confirme que a cláusula do fornecedor adota esse critério.
