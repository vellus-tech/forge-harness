Revisão feita. Veredito: não pronto para abrir PR para develop.

Gravei em `work/review/dotnet-review.json` (13 achados) e `work/review/resumo.md`.

Bloqueantes:
- DN-01 (crítica): DescontoService é Singleton e depende de TarifaDbContext (Scoped). Correção: Scoped ou IDbContextFactory.
- DN-02 (alta): cálculo em decimal com 0.5m, contra a regra money-as-cents. Deve ser inteiro em centavos.
- DN-04 (alta): o endpoint de matrícula não tem autenticação e permite enumerar estudantes. Decisão de negócio e segurança antes do PR.
- DN-05 (alta): linha inexistente vira 500 (deveria ser 404); falha do SGE também vira 500 e não há política de fallback definida.

Outros: new HttpClient por chamada sem timeout e com .Result (DN-03); matrícula sem escape na URL (DN-06); parsing por Contains (DN-07); filtro em memória (DN-08); host placeholder fixo (DN-09); nenhum teste, contra a regra TDD (DN-10); contrato de resposta cru (DN-11); log pouco informativo (DN-12).

Atenção também: a árvore de trabalho tem 198 remoções não commitadas em .forge/ e .claude/. Não estão no diff contra main, mas um git add -A as levaria ao branch. Restaure antes de commitar.

Validação: o build não concluiu (dotnet build --no-restore falhou por falta de project.assets.json, e o restore exige rede, proibida nesta execução). Não há projeto de testes na solução, então nada foi executado.

Decisões tomadas sem humano disponível: não alterei nenhum código do branch; a revisão só gravou os dois arquivos em review/.
