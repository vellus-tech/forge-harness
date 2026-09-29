# Transcript — eval-revisao-migracao-tarifa-no-ar / with_skill / run-1

Papel assumido: agente `data-relational` (definição em `template/.forge/agents/data/data-relational.md`, só leitura), seguindo o protocolo de 6 passos do próprio arquivo.

1. Bootstrap: `cd .../evals-100 && pwd && git branch --show-current` — confirmou diretório e branch esperados (`chore/evals-skills-agentes`).
2. `date +%s > run-1/.t0` — marca de início.
3. `mkdir -p run-1/work` e `bash fixtures/revisao-migracao-tarifa-no-ar/setup.sh run-1/work` — montou o projeto fixture (serviço `tarifacao` com `V030` já aplicada e `V031` pendente de revisão; `.forge/skills` e `.forge/agents` removidos do alvo pelo próprio `setup.sh` para não contaminar o baseline).
4. Leitura do fixture: `services/tarifacao/README.md` (deploy contínuo sem janela de manutenção, `viagem` com ~60M linhas, `linha` com alguns milhares, multi-tenant por `tenant_id`), `V030__linha_e_viagem.sql` (schema já em produção, com RLS e `lock_timeout`) e `V031__tarifa_por_linha.sql` (a migração a revisar).
5. Leitura da definição do agente `data-relational.md`: escopo, protocolo de 6 passos, checklist, catálogo de antipatterns bloqueados por padrão e regra de integração — usados como guia do que verificar e da ordem.
6. **Passo 1 do protocolo (rules e decisões do projeto):** leitura de `.forge/rules/data/data-governance.md` (matriz de isolamento multi-tenant por store, RLS obrigatório em PostgreSQL), `.forge/rules/data/schema-evolution.md` (expand/migrate/contract, gate de design), `.forge/rules/domain/money-as-cents.md` (dinheiro em `BIGINT`, nunca `NUMERIC`) e `.forge/rules/conventions/database-naming.md` (convenção `snake_case`, sufixo `_cents`, `idx_{table}_{cols}`). Nenhum ADR do repositório sobre este change.
7. **Passo 2 (conflito):** avaliado — `tarifa_parametro` é tabela paramétrica (tarifa por linha), que `data-governance.md` já atribui ao PostgreSQL sem ambiguidade; sem divergência relevante entre rule/ADR e a skill. Nenhum bloco `CONFLITO` a devolver.
8. **Passo 3 (dado sensível):**
   `cd run-1/work && bash .forge/scripts/check-data-governance.sh --path services/tarifacao/db/migrations`
   → `FAIL data-governance/universo-vazio` (exit 1). Interpretado pela linha, não só pelo exit code: o verificador só lê `.go/.kt/.ts/.rego/.py/.md`, não `.sql` — "não verificado por ele", não aprovação. Confirmado por leitura manual que nenhum campo do diff é PAN/PII.
9. **Passo 4 (varredura):**
   `bash template/.forge/skills/data-relational-practices/scripts/scan.sh --root run-1/work/services/tarifacao/db/migrations`
   (executado a partir do `template/`, já que o fixture removeu `.forge/skills` do próprio `work/`; `--root` aponta para o path afetado dentro de `work/`, sem `--json`, um único `--root`.)
   → `FOUND`: R-03 (2×, migração bloqueante — rename in-place e `CREATE INDEX` sem `CONCURRENTLY`), R-04 (2×, `serial` e `timestamp` sem fuso), R-19 (1×, `NUMERIC` em coluna monetária), R-20 (1×, RLS ausente), R-21 (2×, sem `lock_timeout` nos dois `ALTER`/`CREATE INDEX`). `ARQUIVOS-VARRIDOS 2`.
10. **Passo 5 (julgamento):** cada `FOUND` lido linha a linha contra `references/antipatterns.md` e contra o README do fixture (deploy com app no ar, 60M linhas em `viagem`) — todos confirmados como achados reais, não falso-positivo. Adicionado por revisão manual (não coberto pelo `scan.sh`, que marca R-01 como detecção `runtime`): `tarifa_parametro.linha_id` é FK sem índice próprio.
11. **Passo 6 (resposta):** escrita de `outputs/review.md` com cada achado (id do catálogo + `arquivo:linha` + correção), separação da correção em três migrações (`V031` transacional para a tabela nova, `V032` com `CREATE INDEX CONCURRENTLY` fora de transação para `viagem`, `V033` só a fase *expand* do rename de `linha.codigo`) e nota de que quem aplica é o agente de engenharia/`task-coder` (este agente não tem `Write`/`Edit`).
12. Entregáveis gravados em `outputs/`: `review.md`, `V031__tarifa_parametro.sql`, `V032__viagem_index_validador_concurrently.sql`, `V033__linha_codigo_linha_expand.sql`, este `transcript.md`.
13. Fechamento: gravação de `timing.json` a partir de `.t0` e checagem do tamanho de `work/` (limite 20 MB) — ver comandos no fim da sessão.

## Decisões e trade-offs

- Separar em três migrações em vez de "consertar" `V031` inline: `CREATE INDEX CONCURRENTLY` não roda dentro de transação, e misturar isso com `CREATE TABLE`/RLS/policy (que precisam ser atômicos) no mesmo script quebraria a atomicidade dessas últimas ou exigiria `executeInTransaction=false` para o script inteiro, perdendo o rollback atômico da tabela nova.
- A fase *contract* do rename de `linha.codigo` (parar de escrever na coluna antiga, então renomear/derrubar) foi deliberadamente deixada de fora — depende de quando a aplicação nova estiver 100% no ar, decisão de rollout que este agente não tem visibilidade nem mandato para tomar.
- Não foi aberto bloco `CONFLITO`: a tabela é paramétrica, dentro do escopo que `data-governance.md` já atribui ao PostgreSQL sem exigir ADR.
