# Transcript — eval `revisao-dbt-recargas-e-snapshot-passageiro` (with_skill, run-1)

Agente simulado: `data-analytical` (definição em `template/.forge/agents/data/data-analytical.md`, skill `data-analytical-practices` carregada por leitura direta, já que a árvore de trabalho do eval não projeta `.forge/skills/`).

## 1. Bootstrap e preparo

1. `cd .../.forge/worktrees/evals-100 && pwd && git branch --show-current` → confirmou `evals-100` / `chore/evals-skills-agentes`, como esperado.
2. `date +%s > .../run-1/.t0` — instante inicial gravado.
3. `mkdir -p .../run-1/work` e `bash .../fixtures/revisao-dbt-recargas-e-snapshot-passageiro/setup.sh .../run-1/work` — populou o projeto fixture (`analytics/` com dbt + `.forge` do projeto-alvo, sem `.forge/skills/`).
4. Inventariei a árvore criada (`find work -type f`): `analytics/dbt_project.yml`, `analytics/models/sources.yml`, `analytics/models/staging/stg_recargas.sql`, `analytics/models/marts/fct_recargas.sql`, `analytics/snapshots/snap_passageiro.yml`, mais `.forge/{adapters,capabilities,commands,contracts,custom,evals,hooks,ledger,liaison,product,rules,schemas,scripts,specs,templates}` e `.claude/settings.json`. Sem `.forge/skills/`.

## 2. Leitura da definição do agente e da tarefa

5. Li `template/.forge/agents/data/data-analytical.md` (frontmatter + protocolo de 6 passos + checklist + catálogo de antipatterns bloqueados A-01…A-15 + regra de integração) — segui-o à risca como definição do agente.
6. Tarefa do usuário: revisão analítica pré-merge do PR de dados em `analytics/` (recargas + cadastro de passageiros), com parecer do que está errado, como corrigir e trecho corrigido quando fizer sentido; quem aplica é o `task-coder` — reforça o "não tenho Write/Edit" do agente.

## 3. Protocolo — passo 1 (rules e decisões do projeto)

7. Li `.forge/rules/data/data-governance.md` (isolamento multi-tenant por store), `.forge/rules/data/schema-evolution.md` (evolução de schema, cita `money-as-cents.md` para valores monetários), `.forge/rules/domain/money-as-cents.md` (inteiro em centavos, obrigatório em todo domínio) e `.forge/skills/data-analytical-practices/SKILL.md` (do `template/`, já que a instância local não a tem) — nenhum ADR do projeto encontrado além dessas rules.

## 4. Protocolo — passo 2 (conflito relevante)

8. Nenhuma divergência rule × ADR/skill encontrada — os desvios do PR são contra a rule/skill diretamente, não uma escolha alternativa legítima. Não abri bloco `CONFLITO`.

## 5. Protocolo — passo 3 (dado sensível) e passo 4 (varredura)

9. `cd work && bash .forge/scripts/check-data-governance.sh --path analytics` → `FAIL data-governance/universo-vazio` (0 arquivos examinados, exit 1). Interpretado pela linha, não só pelo exit code: "não verificado" (o verificador só cobre `.go .kt .ts .rego .py .md`; dbt em `.sql`/`.yml` fica fora por desenho) — não é achado nem aprovação.
10. `bash .forge/skills/data-analytical-practices/scripts/scan.sh --root analytics` → `bash: ... No such file or directory` (exit 127). Confirmado com `ls .forge/skills` → diretório inexistente nesta árvore de trabalho.
11. Decisão registrada: tentei o caminho absoluto do `scan.sh` do `template/` como alternativa e concluí, sem executar, que o `data-agent-bash-guard.sh` (lido em `.forge/scripts/data-agent-bash-guard.sh`) só aceita o literal `.forge/skills/data-<domínio>-practices/scripts/scan.sh` relativo ao cwd — qualquer outro caminho cai em "script fora dos dois comandos do protocolo" (nega, exit 2). Não executei essa tentativa (seria um terceiro comando fora do allowlist); apenas li o guard e concluí pela leitura. Sem workaround dentro do protocolo: registrei a lacuna no parecer em vez de contornar o hook.
12. Inventário de dado pessoal do passo 3 (`cpf|email|telefone|nome|endereco|data_nasc`) feito manualmente por `Read` do `snap_passageiro.yml`, já que não há `data-classification.json` no projeto e o scanner estático não cobriu o path.

## 6. Protocolo — passo 5 (julgamento)

13. Li cada um dos 5 arquivos com `Read` e julguei contra `template/.forge/skills/data-analytical-practices/references/antipatterns.md` (catálogo A-01…A-16) e o checklist do agente:
    - `stg_recargas.sql`: A-08 (incremental sem `unique_key`/lookback, linhas 1 e 12) + violação de `money-as-cents.md` (linha 8, `numeric(12,2)` nomeado `valor_reais`).
    - `fct_recargas.sql`: A-10 (mart lê `source()` direto, linha 3) + A-12 (`SELECT *`, linha 3) + A-09 (sem contrato) + grão não declarado (checklist).
    - `snap_passageiro.yml`: A-14 (`invalidate_hard_deletes: true`, linha 8) + A-16 (`nome`/`email`/`telefone` em `check_cols`, linha 7).
    - Nenhum teste `unique`/`not_null` encontrado em nenhum `schema.yml` do projeto (não achei o arquivo) → A-11.
14. Antes de afirmar os defaults de correção, consultei o context7 (`mcp__context7__resolve-library-id` → `/dbt-labs/docs.getdbt.com`, depois `mcp__context7__query-docs` duas vezes): confirmei a sintaxe atual de `hard_deletes` (substituto de `invalidate_hard_deletes`, dbt 1.9+) e de `unique_key` + `incremental_strategy: merge` + lookback em modelo incremental, conforme exige o passo 6 do protocolo ("consulte o context7 antes de afirmar um default").

## 7. Protocolo — passo 6 (resposta)

15. Escrevi `outputs/parecer.md`: veredito (não recomendo merge no estado atual), 10 achados ordenados por severidade (6 bloqueantes, 2 altos, 1 médio, 1 informativo), cada um com o antipattern/rule citado, `arquivo:linha` e o trecho corrigido quando fazia sentido (achados 1 a 6), mais a seção de transparência sobre o `scan.sh` indisponível e as fontes consultadas no context7. Não toquei nos arquivos de `analytics/` — só li.

## 8. Encerramento

16. Não houve pergunta de esclarecimento necessária: a tarefa era autocontida (revisar o PR dado, devolver parecer sem aplicar).
17. Nenhum subagente foi spawnado (a tarefa não pediu; e a instrução do harness proíbe spawn nesta execução de eval de qualquer forma).
18. Escrevi `outputs/parecer.md` e este `outputs/transcript.md`; em seguida gravo `timing.json` com `t0`/`t1` e `total_tokens: 0` (não medido nesta simulação) e confiro o tamanho de `work/` antes de decidir se apago.
