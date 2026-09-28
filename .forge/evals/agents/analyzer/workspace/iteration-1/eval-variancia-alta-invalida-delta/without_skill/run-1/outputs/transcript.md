# Transcript — run-1 (without_skill)

Caso: `eval-variancia-alta-invalida-delta`, agente `analyzer`, iteração 1, variante `without_skill`.

1. Verifiquei o bootstrap do worktree: `cd .../worktrees/evals-100 && pwd && git branch --show-current` → confirmou diretório e branch `chore/evals-skills-agentes` esperados.
2. Gravei o instante inicial em `.t0` com `date +%s`.
3. Criei `work/` e rodei `fixtures/variancia-alta-invalida-delta/setup.sh work/`, que fez `git init` + commit da fixture (projeto consumidor com `aggregate.json` e 4 `grading.json` de uma iteração de eval já agregada da skill `revisa-migracao-postgres`) e removeu `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` e `plugin/` do target — ou seja, o baseline não tem acesso a nenhuma skill/agente do harness nem ao SKILL.md avaliado.
4. Segui a instrução explícita da tarefa: **não li** nada em `template/.forge/skills`, `template/.forge/agents`, `plugin/` nem `.forge/evals` fora do que o próprio input da tarefa apontava — executei a análise só com conhecimento próprio de estatística e leitura dos arquivos de entrada, dentro de `work/`.
5. Li os 5 arquivos de entrada dentro de `work/`: `aggregate.json` da iteração 2 e os 4 `grading.json` (eval-1 a eval-4).
6. Recalculei manualmente o delta de pass-rate por caso a partir dos `aggregate.baseline_pass_rate`/`variant_pass_rate` de cada `grading.json`: TC-01 +0.5, TC-02 +0.5, TC-03 0, TC-04 0 → média 0.25, batendo com o `delta.pass_rate` do `aggregate.json`.
7. Notei que `pass_rate_stddev` do variant (0.4463) é maior que o próprio delta médio (0.25) — sinal de que a variância entre os 4 casos é maior que o efeito medido.
8. Recalculei desvio-padrão dos deltas por caso ([0.5, 0.5, 0, 0]) e um erro-padrão/teste t aproximado (n=4, 3 graus de liberdade): t ≈ 1.7–2.0, abaixo do valor crítico ≈ 3.18 para significância a 95% — ou seja, o delta não é estatisticamente significativo com essa amostra.
9. Reli caso a caso os `grading.json` e identifiquei que TC-03 tem saída **idêntica** (baseline e variant) e nenhuma expectativa passa em nenhum dos dois — achado que aponta para possível falha de acionamento da skill nesse caso, não para "skill não ajuda".
10. Verifiquei que o custo adicional (tokens/duração) do variant ocorre nos 4 casos, inclusive nos dois sem ganho de qualidade (TC-03, TC-04).
11. Escrevi a análise em `outputs/analise-pos-hoc.md`: resumo executivo, tabela por caso, seção de variância/significância, custo não compensado, e recomendação de não aprovar hoje só com esse número, com 3 próximos passos (investigar TC-03, aumentar n, apresentar variância junto do delta se a decisão não puder esperar).
12. Copiei os 5 arquivos de entrada lidos para `outputs/input-files/` (evidência do que foi analisado).
13. Nenhum subagente foi necessário para esta tarefa — não havia nada a despachar (a tarefa é uma análise textual direta sobre arquivos já fornecidos, sem passos que exijam paralelismo ou especialização de outro agente).
14. Gravei `.t0`/`timing.json` conforme instrução do runner do eval.

## Decisões e trade-offs

- Optei por não recalcular `duration_mean`/`tokens_mean` do zero via script (não havia necessidade — os agregados já constavam em `aggregate.json` e nos `grading.json`, e bateram na conferência manual).
- Usei tanto desvio-padrão populacional quanto amostral no cálculo de erro-padrão, deixando a faixa (0.125–0.144) explícita no relatório, em vez de escolher só uma convenção — evita passar falsa precisão numa análise que já é, por natureza, aproximada com n=4.
- Não tentei "consertar" ou reinterpretar o caso TC-03 (saída idêntica) — apenas sinalizei como achado que precisa de investigação separada, porque não tenho acesso aos logs de execução do eval para confirmar a causa.
