# Despacho simulado (não executado)

Regra do prompt: "Se o artefato mandar spawnar subagentes, NÃO spawne: registre em outputs/ o
despacho que faria (agente, modelo, prompt resumido) e siga com o que couber a você."

## O que o protocolo do skill-creator normalmente pediria

`SKILL.md` linha 234 ("Do an analyst pass") descreve o passo 3 (leitura de benchmark +
transcripts + geração de `analysis.md`) como um pass tipicamente delegado a um subagente
analyzer, seguindo `agents/analyzer.md` ("Analyzing Benchmark Results"). Os passos anteriores
(executor com/sem skill, grader) também são normalmente dois subagentes por caso de eval,
disparados no mesmo turno (linha 171).

## Estado encontrado nesta árvore

`workspace/iteration-1/` já continha, para os 3 evals, `with_skill/run-1/` e
`without_skill/run-1/` completos (outputs do executor + `grading.json` do grader) — ou seja,
os passos de execução e grading já haviam sido feitos em uma sessão anterior. Não havia,
portanto, subagentes de executor/grader para simular: os dados já existiam em disco e a
agregação determinística (passo 1 da tarefa) e o viewer estático (passo 2) rodaram direto
sobre eles.

## Despacho que seria feito para o "analyst pass" (passo 3), se este agente não pudesse fazê-lo inline

- **Agente**: subagente genérico de análise (papel "analyzer", seguindo
  `skill-creator/agents/analyzer.md`, seção "Analyzing Benchmark Results").
- **Modelo sugerido**: `sonnet` (leitura crítica de transcripts/grading e síntese em prosa —
  não é implementação bite-sized nem design de agregado que justifique `haiku` ou `opus`).
- **Prompt resumido**: "Leia benchmark.json, os 6 grading.json (3 evals × 2 configs) e o
  artefato module-generator.md; escreva analysis.md com taxas, asserções não discriminantes,
  onde o artefato ajudou/atrapalhou (com evidência do transcript), trechos ignorados/ambíguos/
  contraditórios do artefato e melhorias priorizadas; não sugira sem evidência."

Como a tarefa recebida já autoriza (e pede) que este agente leia e sintetize os mesmos dados
diretamente, o passo foi executado inline nesta sessão em vez de despachado — sem spawn real
de subagente, conforme a regra acima.
