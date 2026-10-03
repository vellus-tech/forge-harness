# Transcript — eval-case `variancia-alta-invalida-delta`, with_skill, run-1

Papel assumido: `eval-analyzer`, conforme `template/.forge/agents/quality/analyzer.md` (issue #176 — revisão A/B de skills e agentes, protocolo do skill-creator).

## Passos executados

1. Verifiquei o bootstrap do worktree: `cd .../worktrees/evals-100 && pwd && git branch --show-current` → confirmou `evals-100` e a branch `chore/evals-skills-agentes`, conforme esperado. Prossegui.
2. Gravei o instante inicial em `.t0` com `date +%s`.
3. Criei `work/` e rodei `fixtures/variancia-alta-invalida-delta/setup.sh work/`, que monta o projeto-fixture (skill avaliada em `tools/claude-skills/revisa-migracao-postgres/SKILL.md`, `evals.json`, e a iteração 2 já agregada: `aggregate.json` + 4 `grading.json`) e faz `git init` + commit interno ao fixture — ação do próprio script de setup, não um `git commit` meu.
4. Li o artefato do agente (`template/.forge/agents/quality/analyzer.md`) e segui o protocolo: não recalcular estatística, interpretar `aggregate.json` e os `grading.json`, produzir `analysis.json` com findings apontando para casos/expectativas concretos e um verdict consistente com os números.
5. Notei que o diretório de trabalho já continha resíduos de uma execução anterior deste mesmo eval-case (datados de 26/set, dois dias antes de hoje) — incluindo um `analysis.json` pronto dentro de `work/` e um `outputs/` com `dispatch.md`/`transcript.md`/`.forge/` de uma rodada prévia. Tratei esse conteúdo como não confiável (não é o resultado desta execução) e refiz a análise a partir dos dados brutos (`aggregate.json` + 4 `grading.json`), sem copiar o texto anterior — o resultado convergiu para o mesmo veredito porque os dados são inequívocos, não porque copiei.
6. Li `aggregate.json`: baseline pass_rate_mean 0.3125 (stddev 0.2073), variant pass_rate_mean 0.5625 (stddev 0.4463), delta +0.25; duration_mean_ms baseline 18000 → variant 22600 (+4600); tokens_mean baseline 5550 → variant 6575 (+1025).
7. Testei o critério de variância alta (§ do agente: stddev da variant ≳ metade do mean): 0.4463 / 0.5625 ≈ 0.79 — bem acima do limiar. Delta agregado não é confiável isoladamente.
8. Li os 4 `grading.json` (TC-01..TC-04) e recalculei o pass-rate por caso a partir das expectativas individuais (`passed: true/false`), sem usar os campos `aggregate` já embutidos nos próprios grading.json como atalho — conferi expectativa por expectativa:
   - TC-01: baseline 2/4 (0.5) → variant 4/4 (1.0), delta +0.5.
   - TC-02: baseline 2/4 (0.5) → variant 4/4 (1.0), delta +0.5.
   - TC-03: baseline 0/4 (0.0) → variant 0/4 (0.0), delta 0 — `variant_result.output` idêntico ao `baseline_result.output` (mesmo texto, tokens quase iguais: 4200 vs 4300) → sinal de não-triggering para o prompt informal ("dá uma olhada... antes de eu subir").
   - TC-04: baseline 1/4 (0.25) → variant 1/4 (0.25), delta 0 — só a expectativa de lock passa; as outras 3 seguem falhando apesar do custo maior (7600 vs 6000 tokens).
9. Verifiquei regressão local (variant `passed:false` com baseline `passed:true`) em todas as 16 combinações caso×expectativa: nenhuma ocorreu.
10. Concluí verdict `inconclusive`: sem regressão, mas variância alta + ganho concentrado em 2/4 casos + 1 caso de não-triggering + 1 caso de miss sistemático invalidam o delta agregado como base de aprovação hoje.
11. Escrevi `analysis.json` em `work/.forge/evals/skills/revisa-migracao-postgres/workspace/iteration-2/analysis.json`, seguindo o schema do agente (skill, verdict, summary, findings tipados por `kind`/`case`/`expectation`/`detail`, recommendation única e acionável).
12. Copiei os artefatos relevantes para `outputs/`: `analysis.json`, `aggregate.json` (referência), e os 4 `grading.json` renomeados em `outputs/grading/`. Removi o `outputs/.forge/` residual da execução anterior (redundante com o `analysis.json` já copiado na raiz de `outputs/`) para não deixar duas cópias divergentes.
13. Registrei em `dispatch.md` o despacho de subagente que faria em operação normal — não executado, conforme a regra do prompt ("nunca spawne subagentes; registre o despacho que faria").
14. `work/` ficou em ~256 KB (bem abaixo do limite de 20 MB) — não foi apagado.
15. Escrevi este `transcript.md` e, na sequência, `timing.json` com `t0`/`t1`/`duration_ms`.

## Decisão de escopo

Não editei a `SKILL.md` avaliada nem os `grading.json` de entrada — só escrevi `analysis.json`, conforme a regra do agente ("não edite a skill nem os gradings; só escreva analysis.json"). Não rodei `git commit/push`, `tests/run-all.sh`, `npm test`, `docker`, `ledger-ops.sh`, `liaison-ops.sh`, `gh` (escrita) ou `npm publish` — nenhum desses foi necessário para esta tarefa de análise pós-hoc.

## Resultado (para a reunião)

Verdict: **inconclusive** — não aprovar a skill `revisa-migracao-postgres` hoje só com base no delta agregado de pass-rate +0.25. Motivo: stddev da variant (0.4463) é ~79% do próprio mean, o ganho está concentrado em 2 dos 4 casos, um caso mostra sinal de não-triggering (TC-03) e outro mantém falha sistemática mesmo com a skill ativa (TC-04). Nenhuma regressão local. Recomendação: rodar novo eval com n≥8-10 casos para reduzir a variância, e otimizar a description da skill para cobrir prompts informais (TC-03) e reforçar reversibilidade/estimativa de bloqueio em `ALTER TYPE` (TC-04). Detalhe completo em `outputs/analysis.json`.
