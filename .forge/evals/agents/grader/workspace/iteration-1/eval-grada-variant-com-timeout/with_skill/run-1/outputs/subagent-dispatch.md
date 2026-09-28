# Despacho de subagentes (simulado — não executado)

Conforme regra do sandbox de eval, nenhum subagente foi de fato spawnado nesta execução. O protocolo do `eval-grader` (grader.md) não manda spawnar subagentes para esta tarefa — grading de um único caso de teste (TC-01) é trabalho de leitura + escrita direta, sem necessidade de paralelismo ou delegação. Por isso não há despacho real a registrar além deste apontamento.

Se houvesse necessidade (ex.: múltiplos test_cases grandes em paralelo, ou uma segunda opinião cética sobre a nota "clara e bem escrita" do expectation TC-01.3), o despacho seria:

- **Agente:** `eval-grader` (um por test case, para paralelizar grading quando há múltiplos TCs)
- **Modelo:** sonnet (conforme frontmatter de `.forge/agents/quality/grader.md`)
- **Prompt resumido:** "Avalie TC-0N de `.../results.json` contra as expectativas em `.../evals.json`; produza o bloco `test_cases[N]` de `grading.json` com evidência literal, sem ancoragem cruzada entre baseline e variant."

Não aplicável aqui porque há apenas 1 test case (TC-01) e o trabalho coube inteiramente a este agente.
