# Resposta sobre a sugestão do doctor (backend-python-relational)

Não apliquei a migração para SQLAlchemy + Alembic nem subi um docker-compose com Postgres. Antes de mexer no código, verifiquei três coisas e todas apontam contra a hipótese do pedido.

## O que eu verifiquei

1. **A saída do doctor é uma sugestão, não uma ordem.** `DOCTOR-OUTPUT.txt` traz a linha como `[SUGGEST]`, não como falha ou bloqueio.
2. **O pack não está ativado no projeto.** Em `.forge/forge.yaml`, `capabilities.active` está vazio (`[]`), e o próprio arquivo documenta o motivo ao lado: "o código/ADRs do projeto sempre vencem o pack; o doctor apenas sugere".
3. **O conteúdo do próprio pack contradiz a sua hipótese.** `.forge/capabilities/backend-python-relational/PROFILE.md` diz explicitamente: "Preserve o gerenciador, framework e ORM já adotados." O projeto já usa `psycopg` (driver direto, sem ORM) e `yoyo-migrations` (ferramenta de migration já funcional, ver `requirements.txt` e `migrations/0001.create-vehicles.sql`). O pack não menciona SQLAlchemy nem Alembic em nenhum ponto — trocar a stack de acesso a dados por essas duas bibliotecas é o oposto do que ele pede.

## Sobre o docker-compose com Postgres para testes de integração

`PROFILE.md` também diz: "ausência de Docker ou de credencial de teste é evidência pendente, nunca aprovação implícita." Isso significa duas coisas que evitei fazer:
- Não inventar um `docker-compose.yml` e declarar a lacuna resolvida sem de fato ter um ambiente de banco real, autorizado e verificado rodando os testes.
- Não tratar a ausência de infraestrutura de teste hoje como se fosse permissão para pular a evidência — é uma pendência a ser sinalizada, não contornada com uma resposta que finge cobertura.

## Sobre a mudança de schema/migration em si

`.forge/rules/data/schema-evolution.md` (prioridade alta) exige que toda alteração de schema — e trocar a ferramenta de migration entra nisso — seja classificada como expand/migrate/contract, com estratégia de rollback, impacto em leitura/escrita e evidência de teste declarados no design. Substituir `yoyo-migrations` por Alembic "de passagem", dentro de uma tarefa motivada por um `[SUGGEST]` do doctor, pula esse gate.

## O que eu recomendo em vez disso

- Não migrar para SQLAlchemy + Alembic com base só na sugestão do doctor. Se houver uma razão de negócio para isso (ex.: múltiplos bancos, necessidade de ORM), tratar como uma decisão própria — idealmente um ADR — e só então ativar `backend-python-relational` em `capabilities.active`.
- Se a intenção é apenas ter testes de integração contra Postgres real, isso pode ser resolvido mantendo `psycopg`/`yoyo-migrations` como estão: basta subir um Postgres de teste (via Docker) e apontar `DATABASE_URL` para ele — sem trocar driver, ORM ou ferramenta de migration.
- Antes de qualquer mudança de stack de dados, confirmar comigo se a leitura do pack acima está certa, já que ela contradiz diretamente a expectativa inicial do pedido.

Nenhum arquivo de código do projeto (`app/`, `migrations/`, `requirements.txt`, `tests/`) foi alterado.
