# Transcript — eval-revisao-migracao-tarifa-no-ar / without_skill / run-1

Condição: `without_skill` — execução com conhecimento próprio, sem ler `.forge/skills/data-*-practices/` nem `.forge/agents/data/` (não existem no fixture, o que foi confirmado abaixo).

## Passos, em ordem

1. Gravei `.t0` com `date +%s` (instante inicial), conforme protocolo do runner.
2. Criei `work/` e rodei `fixtures/revisao-migracao-tarifa-no-ar/setup.sh work/` para materializar o projeto fixture.
3. Explorei a árvore de `work/services/tarifacao/`: `README.md` e `db/migrations/{V030,V031}*.sql`.
4. Li `services/tarifacao/README.md` — confirma o contexto crítico citado pelo usuário: PostgreSQL 16, Flyway, deploy contínuo sem janela (versão anterior da app ainda atendendo durante a migração), `viagem` com ~60M linhas, `linha` com "alguns milhares", multi-tenant por `tenant_id`.
5. Li `V030__linha_e_viagem.sql` (já aplicada em produção) para estabelecer o padrão vigente do schema: `bigint GENERATED ALWAYS AS IDENTITY`, `timestamptz`, valores monetários como `bigint ..._em_centavos`, RLS (`ENABLE`/`FORCE ROW LEVEL SECURITY` + policy por `tenant_id`) em toda tabela de domínio, e `SET lock_timeout = '5s'` no topo do script.
6. Li `V031__tarifa_por_linha.sql` (o alvo da revisão).
7. Confirmei que `work/.forge/agents` e `work/.forge/skills` não existem neste fixture — condição `without_skill` respeitada por construção, sem necessidade de evitar nada manualmente.
8. Consultei `work/AGENTS.md` só para entender a estrutura do repositório (não li nenhum skill/agent do diretório de artefato do harness em `template/` ou `.forge/evals`, conforme instruído).
9. Como as regras de dados do próprio projeto (`work/.forge/rules/data/*.md`, `work/.forge/rules/domain/money-as-cents.md`) são conteúdo do fixture-projeto (não o artefato sob avaliação), e diretamente relevantes ao que a tarefa pediu revisar, consultei:
   - `.forge/rules/data/schema-evolution.md` — fluxo expand/migrate/contract, gate de compatibilidade em produção.
   - `.forge/rules/data/data-governance.md` — RLS obrigatória em tabela multi-tenant PostgreSQL como anti-padrão bloqueante se ausente.
   - `.forge/rules/domain/money-as-cents.md` — proibição de `DECIMAL`/`NUMERIC`/`FLOAT` para dinheiro, exigência de `BIGINT` em centavos.
   Esses três arquivos corroboraram achados que eu já tinha identificado por conhecimento próprio de PostgreSQL/migrations em produção (locks de `CREATE INDEX`, rename quebrando app antiga, RLS, tipos monetários) — não introduziram achado novo que eu não teria feito sem eles, mas confirmam que são regras já pactuadas no projeto, não só opinião externa.
10. Analisei `V031` linha a linha contra: (a) o contexto do README (deploy sem janela + volume), (b) o padrão já estabelecido em V030, (c) boas práticas gerais de PostgreSQL em produção (locks de DDL, expand/contract, RLS, tipos). Identifiquei 8 achados, dois deles bloqueantes:
    - `CREATE INDEX` sem `CONCURRENTLY` em `viagem` (60M linhas) → lock de escrita.
    - `RENAME COLUMN codigo TO codigo_linha` → quebra a versão anterior da app, ainda no ar.
    - mais 6 achados de severidade média/baixa/sugestão (RLS ausente na tabela nova, tipo monetário, `serial` vs identity, `timestamp` vs `timestamptz`, `lock_timeout` ausente, índice de apoio ausente).
11. Escrevi a versão corrigida, dividida em dois arquivos por necessidade técnica (índice `CONCURRENTLY` não pode rodar na mesma transação que o resto do DDL, e o Flyway envolve cada script numa transação por padrão):
    - `outputs/V031__tarifa_parametro.sql` — tabela nova com RLS e tipos corretos, fase "expand" do rename via coluna nova + trigger de sincronismo.
    - `outputs/V032__idx_viagem_validador_id.sql` — índice em `viagem` com `CONCURRENTLY`, fora de transação, com runbook de recuperação de índice `INVALID`.
12. Escrevi `outputs/revisao.md` com os 8 achados (severidade, trecho problemático, por que quebra, correção), a explicação da divisão em dois arquivos, o mapeamento para as regras do projeto que corroboram cada achado, e o que deliberadamente não mudei (inclusive o adiamento da remoção de `codigo`, que depende de observação de rollout real e não é decisão de revisão de código).
13. Não rodei nenhum comando de escrita externa (sem `git commit/push`, sem `npm test`, sem `docker`, sem `gh`) — apenas leitura do fixture e escrita em `outputs/`, conforme as regras do prompt.
14. Nenhum subagente foi spawnado (não era necessário para esta tarefa de revisão de um único arquivo SQL).
15. Ao final: gravei `.t0`/`timing.json` conforme protocolo e verifiquei o tamanho de `work/` (bem abaixo de 20 MB — não precisou apagar).

## Decisões e trade-offs

- Optei por dual-write via trigger (em vez de, por exemplo, view de compatibilidade ou aplicação escrevendo nas duas colunas) porque a app antiga não vai ser tocada — o serviço está "no ar" com a versão atual, e o pedido é sobre a migration, não sobre mudar código da aplicação. Um trigger no banco é o único mecanismo que garante consistência entre `codigo` e `codigo_linha` sem depender de deploy coordenado de app.
- Não escrevi a migration V033 (drop de `codigo`) porque o timing correto depende de confirmação de que a versão antiga não está mais em produção — informação que não existe nesta revisão estática de código. Documentei o passo como pendência explícita em vez de adivinhar um SQL que poderia ser aplicado cedo demais.
- Mantive `IF NOT EXISTS`/`IF EXISTS` como idempotência básica em pontos sensíveis (índice concorrente), alinhado à regra do projeto de que migration precisa ser idempotente quando reexecutável.
