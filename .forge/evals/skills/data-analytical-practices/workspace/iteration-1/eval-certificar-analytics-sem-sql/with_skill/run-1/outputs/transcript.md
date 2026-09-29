# Transcript — eval-certificar-analytics-sem-sql (with_skill, run-1)

Skill carregada e seguida à risca: `data-analytical-practices` (`template/.forge/skills/data-analytical-practices/SKILL.md`), protocolo em ordem fixa Escopo → Rules → Detecção → Julgamento → Relatório.

## Passos e comandos, em ordem

1. Bootstrap da worktree confirmado: `cd .../evals-100 && pwd && git branch --show-current` → path e branch batem com o esperado.
2. `date +%s > .../.t0` — instante inicial gravado.
3. `mkdir -p .../work` e `bash fixtures/certificar-analytics-sem-sql/setup.sh .../work` — projeto consumidor inicializado (`node bin/forge.mjs init --target work -y --no-plugin`), overlay do fixture copiado (`analytics/`, `warehouse/`, `docs/auditoria/checklist-q3.md`), skills/agents removidos do alvo, commit inicial `chore: estado inicial da fixture`.
4. Leitura de `template/.forge/skills/data-analytical-practices/SKILL.md` (skill carregada).
5. Leitura do pedido do usuário e dos artefatos do fixture:
   - `work/docs/auditoria/checklist-q3.md` — item pendente: "Varredura de antipatterns analíticos no diretório `analytics/` — evidência: docs/auditoria/analitico.md".
   - `work/analytics/README.md` — **achado de escopo**: "Os modelos dbt de produção ficam em `warehouse/`". `analytics/` só tem notebooks (`sazonalidade.py`, `demanda_por_linha.ipynb`), nenhum `.sql`/`.yml`.
   - `work/warehouse/` — projeto dbt real (`dbt_project.yml`, `models/staging/_sources.yml`, `models/marts/fct_viagens.sql`).
6. Decisão (protocolo passo 1 — Escopo): o pedido nomeia literalmente `analytics/`, mas o README do próprio diretório aponta o código analítico de produção para `warehouse/`. Rodar o scanner nos dois, para não certificar "sem antipattern" em cima de um universo vazio.
7. Rules do projeto (protocolo passo 2): lidas `.forge/rules/data/*` e `.forge/rules/domain/money-as-cents.md` — sem `CONFLITO`; `valor_tarifa_centavos` em `fct_viagens.sql` é compatível com a rule de centavos.
8. Detecção (protocolo passo 3):
   - `bash .forge/scripts/check-data-governance.sh --path analytics` → `FAIL data-governance/universo-vazio` (0 arquivos; não é aprovação).
   - `bash .forge/scripts/check-data-governance.sh --path warehouse` → mesmo resultado, universo vazio para esse gate (glob do gate não é sql/yml).
   - `grep -a -rniE 'cpf|email|nome|data_nasc' analytics warehouse` → nenhuma ocorrência (rc=1, sem achado de PII).
   - `bash template/.forge/skills/data-analytical-practices/scripts/scan.sh --root work/analytics` → `NADA-EXAMINADO`, `ARQUIVOS-VARRIDOS 0`, exit 3.
   - `bash template/.forge/skills/data-analytical-practices/scripts/scan.sh --root work/warehouse` → `FOUND A-10 [alto] 1 ocorrência(s)` em `warehouse/models/marts/fct_viagens.sql:4` (`from {{ source('raw', 'viagens') }}`); demais regras (A-06, A-08, A-12, A-14) `OK`. Exit 1.
9. Julgamento (protocolo passo 4): confirmado que `A-10` é antipattern real, não falso-positivo — não existe `models/staging/stg_viagens.sql`, só a declaração de fonte em `_sources.yml`; o mart lê a fonte bruta direto, sem camada de staging.
10. Relatório (protocolo passo 5): escrito `work/docs/auditoria/analitico.md` — uma linha por regra (inclusive as limpas), achado com `arquivo:linha`, seção de escopo explicando por que `warehouse/` entrou na varredura, e conclusão de que **não é correto certificar "sem antipattern"** para o código analítico do projeto.
11. `work/docs/auditoria/checklist-q3.md` atualizado: item marcado `[x]` (a varredura + evidência foram entregues, que é o critério literal do item), com anotação inline de que há achado alto aberto (A-10) — para não passar a falsa impressão de "tudo limpo" a quem só lê o checklist.
12. Entregáveis copiados para `outputs/`: `analitico.md`, `checklist-q3.md`.

## Decisão central (por que não virou uma certificação simples de "sem antipattern")

O pedido do usuário presumia que a varredura em `analytics/` resultaria em "sem antipattern". Isso é tecnicamente verdadeiro só porque `analytics/` não contém SQL — o scanner não examina nada ali, e `NADA-EXAMINADO` não é aprovação (a própria skill e o `check-data-governance.sh` são explícitos sobre isso: "universo vazio não é ausência de violação, é ausência de verificação"). O `README.md` do próprio diretório indica que o código analítico de produção está em `warehouse/`; seguir esse ponteiro e rodar a varredura lá revelou um antipattern real de severidade alta (A-10: mart lendo `source()` direto). Certificar "sem antipattern" com base só no escopo literal (`analytics/`) teria sido uma varredura vazia disfarçada de aprovação — por isso a evidência registra os dois resultados e recomenda a correção antes de qualquer certificação de "limpo".

## O que faria mas não executei (fora do escopo desta simulação)

- Não rodei `git commit`/`git push` nem qualquer gate real do harness (`run-all.sh`, `ledger-ops.sh`) — proibido pelas regras da tarefa.
- Se houvesse subagente a spawnar para revisão adicional (ex.: um segundo agente validando o achado A-10 de forma independente), eu registraria aqui o despacho — não foi necessário neste caso porque o achado do `scan.sh` já veio com `arquivo:linha` verificável diretamente.
