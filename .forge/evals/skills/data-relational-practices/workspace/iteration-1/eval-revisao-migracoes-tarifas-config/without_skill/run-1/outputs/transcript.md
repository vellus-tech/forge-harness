# Transcript — eval-revisao-migracoes-tarifas-config / without_skill / run-1

## Contexto de execução

Caso de eval `without_skill`: nenhuma skill/agente do harness foi lida (proibido explicitamente pela tarefa); a revisão usou só conhecimento próprio de PostgreSQL/engenharia de dados relacional. Nenhum arquivo do repositório-alvo foi modificado, conforme pedido pelo usuário ("Não mexe nos arquivos, só quero o diagnóstico").

## Passos

1. `date +%s > .t0` — marcado o instante inicial.
2. `mkdir -p work` e execução de `fixtures/revisao-migracoes-tarifas-config/setup.sh work` — o script chamou `node .../bin/forge.mjs init --target work -y --no-plugin`, copiou o overlay do projeto (`services/tarifas-config/...`) por cima, removeu `skills`/`agents`/`plugin` do alvo (para não vazar o artefato sob avaliação) e commitou o estado inicial em `work/.git`. Essa etapa é a preparação da fixture, não uma ação livre minha.
3. Inspecionei os arquivos do caso:
   - `work/services/tarifas-config/README.md`: serviço Node/TS, PostgreSQL 16, pool `node-postgres`, sem PgBouncer, multi-tenant por operadora.
   - `work/services/tarifas-config/migrations/V001__cria_tarifas.sql`: cria `tarifas` com `lock_timeout`, identidade, índice composto `(tenant_id, linha_id)` e RLS forçada — usado como referência de estilo/segurança já aprovada em produção.
   - `work/services/tarifas-config/migrations/V002__integracao_e_parametros.sql`: a migração sob revisão, marcada no próprio comentário como "sobe no deploy de quinta, com o serviço no ar (tarifas tem ~40 milhões de linhas)".
   - `work/services/tarifas-config/src/repositorios/tarifas_repo.ts`: único ponto de acesso a dados revisado, método `listar` com paginação por offset e `set_config` de tenant.
4. Busquei por configuração de runner de migração (Flyway/config) e não encontrei nenhuma — a convenção `V00x__descricao.sql` sugere Flyway/Postgres-migrate, mas sem `flyway.conf` no fixture não dá para confirmar se cada arquivo roda numa única transação; tratei isso como suposição a validar com o time (registrado no parecer).
5. Analisei a V002 statement a statement contra o cenário declarado (produção, ~40M linhas, deploy com serviço no ar), buscando: locks exclusivos evitáveis, reescrita de tabela, updates em massa sem lote, mudanças de schema sem janela de compatibilidade, e uma FK para `operadores` — tabela que não aparece em nenhuma migração do fixture, o que é o achado mais grave (a migração provavelmente falha antes de qualquer problema de lock).
6. Analisei `tarifas_repo.ts` à luz do padrão RLS multi-tenant de V001: identifiquei que `set_config('app.tenant_id', $1, false)` seta o parâmetro em escopo de **sessão** (não de transação) numa conexão devolvida ao `Pool` sem reset — risco de vazamento de dados entre tenants se algum caminho futuro reusar a conexão sem chamar `set_config` de novo. Também sinalizei paginação por `OFFSET` como problema de performance em 40M linhas, e `SELECT *` como acoplamento frágil ao rename de coluna da própria V002.
7. Escrevi o parecer em `work/docs/revisao-banco-tarifas.md`: sumário executivo, achados por severidade em migrações e no código, e uma seção de SQL corrigido dividindo a V002 original em cinco migrações menores (V002a a V002e) com `CREATE INDEX CONCURRENTLY`, backfill em lote, `CHECK NOT VALID` + `VALIDATE CONSTRAINT` antes de `SET NOT NULL`, RLS na tabela nova, e o `RENAME COLUMN` isolado numa migração posterior — mais a correção do repositório TypeScript (não aplicada ao arquivo original, só no parecer) usando `set_config(..., true)` dentro de transação e paginação por cursor.
8. Copiei o parecer para `outputs/revisao-banco-tarifas.md` e escrevi este `outputs/transcript.md`.
9. Conferi o tamanho de `work/` (~5,4 MB, abaixo do limite de 20 MB) — não precisou apagar.
10. Grava `timing.json` com `t0`/`t1` medidos em wall-clock (instrução do prompt; `total_tokens` fica zerado porque este ambiente não expõe contagem de tokens do subagente).

## Decisões e trade-offs

- Não assumi que a FK para `operadores` é um erro de digitação (poderia ser tabela criada em migração fora do escopo do fixture); registrei como pré-condição a confirmar, não como correção automática, porque a tarefa é diagnóstico, não implementação.
- Dividi a V002 em cinco migrações em vez de propor uma única migração "corrigida" com `CONCURRENTLY`/lote embutidos, porque `CREATE INDEX CONCURRENTLY` não pode rodar dentro de bloco de transação e um `UPDATE` em lote não cabe num único statement de migração transacional — juntar tudo de novo recriaria o mesmo problema de raio de bloqueio.
- Mantive a mudança de escala de `taxa_desconto_percentual` (V002c) comentada em vez de aplicá-la, porque é decisão de produto/negócio (2→4 casas decimais) que a revisão de banco não deve tomar sozinha — só documentei que reescreve a tabela inteira e por quê.
- Não toquei nos arquivos originais do fixture (README, migrations, repo.ts) — só criei `work/docs/revisao-banco-tarifas.md`, conforme pedido explícito do usuário.
