# Transcrição: eval A/B conciliacao-csv (iteração 2)

1. Leitura do prompt.md e do pedido (eval A/B, 2 casos, sem grader, ajuste de SKILL.md até o variant ganhar).
2. Inspeção de work/: .forge/runners.yaml aponta para ./tools/claude-stub.sh (confirmado). Stub lido: grava uma linha em .eval-runner/calls.jsonl; with_skill = prompt contém "name: conciliacao-csv"; não executa a skill nem lê CSV.
3. Verificação do eval_dir pedido: .forge/evals/skills/conciliacao-csv/ NÃO existe (só .gitkeep em .forge/evals/skills/). Não há evals.json, workspace/iteration-2, nem baseline/variant definidos.
4. Leitura de skills-dev/conciliacao-csv/SKILL.md (v1: separador ; ou ,, data DD/MM/AAAA, tolerância D±1) e de .forge/specs/active/conciliacao-csv-v2/design.md (v2: separador vírgula, ISO AAAA-MM-DD, tolerância D±2).
5. Leitura de .forge/evals/README.md: results.json, grading.json e aggregate.json são produzidos pelo fluxo; estatística e vencedor saem de scripts (eval-aggregate.sh, eval-holdout.sh), não de julgamento do modelo.
6. Execução do stub para os dois casos (TC-01 caso-junho-simples, TC-02 caso-extrato-iso): ambos com with_skill=false, pois o prompt não contém o texto da skill. Sem diferença possível entre os lados.
7. Não gravei results.json nem editei SKILL.md: sem eval_dir e com o stub incapaz de distinguir baseline de variant, qualquer vencedor e nota seriam inventados. Não rodei o loop de ajuste de SKILL.md.
8. Nenhuma rede usada. Escritas apenas em work/.eval-runner/calls.jsonl e neste outputs/.
