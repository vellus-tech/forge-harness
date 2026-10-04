# Análise pós-hoc da iteração {{ITER}} de `{{NAME}}`

Você é o analista de um eval A/B já agregado. Antes de começar, leia `{{REPO}}/template/.forge/agents/quality/analyzer.md` e siga as regras dele: você não recalcula média, desvio, delta, intervalo nem veredito; você interpreta os números que o script já produziu e aponta o que a média esconde.

## Entradas (só leitura)

- `{{ITERDIR}}/verdict.json`: veredito do script, delta, IC 95%, taxa por caso e a contagem por asserção (`assertions`: aprovações/execuções com e sem o artefato nesta iteração, e `ref_with`/`ref_without` da iteração 1).
- `{{ITERDIR}}/benchmark.json` e os `grading.json` de cada execução em `{{ITERDIR}}/eval-*/{with_skill,without_skill}/run-*/` (com `outputs/` de cada execução, inclusive `transcript.md` e `final_response.md`).
- `{{ITERDIR}}/contamination.json`: auditoria do registro real de ferramentas de cada subagente.
- `{{ITERDIR}}/evals.json`: os casos e as asserções desta iteração.
- Iteração 1: `{{EVALDIR}}/workspace/iteration-1/benchmark.json` e `{{EVALDIR}}/analysis.md`.
- O artefato medido: `{{ARTIFACT}}`.
- Diferenças de método entre as iterações, para atribuir causa: na iteração 2 o executor roda fora do repositório do harness, numa cópia da fixture montada pela maquinaria de `develop`, com a mesma política nos dois braços (git local e subagentes permitidos, rede proibida), as dependências declaradas do artefato instaladas nos dois braços, 3 execuções por configuração, grader cego ao braço e a resposta final gravada em `final_response.md`. {{EXTRA}}

## O que gravar

Grave `{{ITERDIR}}/analysis.json`, o contrato de saída do `analyzer.md` (`skill`, `verdict`, `summary`, `findings`, `recommendation`), estendido com os campos abaixo. Todo texto em português do Brasil, com acentuação correta, sem quebra de linha dentro de frase.

- `skill`: `{{NAME}}`; `iteration`: {{ITER}}.
- `script_verdict`: copie de `verdict.json` o veredito, o delta, o IC 95% e o delta da iteração 1, sem recalcular (`{"verdict": ..., "delta": ..., "ci95": [...], "reference_delta": ...}`).
- `verdict`: `improve`, `neutral`, `regress` ou `inconclusive`, coerente com `script_verdict` (agrega → improve; neutro → neutral; prejudica → regress; indeterminado ou inconclusivo → inconclusive).
- `summary`: um parágrafo dizendo se e por que o delta mudou em relação à iteração 1.
- `change_causes`: lista de `{"class", "eval_id", "assertion", "detail"}` comparando a iteração 2 com a 1 asserção por asserção pela tabela `assertions`; `class` é uma de `eval_defeituoso` (asserção insatisfazível, ambígua ou que contradiz o artefato), `variancia` (oscila entre execuções do mesmo braço), `mudanca_de_metodo` (isolamento, dependências nos dois braços, política de sandbox, fixture corrigida) ou `ganho_real` (o artefato muda o comportamento de forma consistente nas 3 execuções); `detail` cita a evidência (execuções, trecho de `grading.json` ou de transcript).
- `dominant_cause`: a classe que explica a maior parte da diferença, com uma frase.
- `findings`: regressões locais (passa sem o artefato e falha com ele), falhas sistemáticas (falha nas duas configurações), alta variância, cada uma com `kind`, `case` ou `expectation` e `detail`.
- `contamination`: o que `contamination.json` mostra e se algum resultado deve ser descontado.
- `recommendation`: uma só, acionável.

Depois de gravar, rode `jq -e .script_verdict.verdict {{ITERDIR}}/analysis.json` e corrija se falhar. Não edite nenhum outro arquivo. A sua resposta a quem o chamou é só `OK` ou `FALHA: <motivo>`.
