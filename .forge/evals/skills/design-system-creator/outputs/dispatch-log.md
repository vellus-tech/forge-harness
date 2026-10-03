# Despacho simulado de subagentes (NÃO executado)

Regras da tarefa proíbem spawnar subagentes neste run. Registro aqui o que seria despachado
num pipeline real do skill-creator (agents/analyzer.md + orquestração normal do benchmark),
sem executar nenhum dos itens abaixo.

1. **agente**: `analyzer` (subagente do skill-creator)
   **modelo**: sonnet (padrão do skill-creator para leitura/síntese de benchmark)
   **prompt resumido**: ler `.forge/evals/skills/design-system-creator/workspace/iteration-1/benchmark.json`,
   aplicar o processo de "Analyzing Benchmark Results" (per-assertion, cross-eval, métricas) e
   gravar notas freeform em `workspace/iteration-1/analysis-notes.json`.
   **status**: não despachado — executado inline por esta sessão (ver analysis.md).

2. **agente**: `code-review` / revisor crítico independente (LLM-as-judge)
   **modelo**: opus (effort medium, conforme diretriz global do usuário para revisão crítica)
   **prompt resumido**: revisar este `analysis.md` contra `benchmark.json` e os transcripts brutos,
   sinalizando qualquer alegação sem evidência ou assertion mal formada antes de reportar ao humano.
   **status**: não despachado (regra do run); análise abaixo foi produzida com citação de evidência
   linha a linha em vez de revisão adversarial por segundo agente.

3. **agente**: `task-coder` / especialista de skill (se a análise recomendasse patch imediato no SKILL.md)
   **modelo**: haiku (implementação bite-sized) ou sonnet (se o patch tocar várias seções)
   **prompt resumido**: aplicar as melhorias priorizadas da seção 4 do `analysis.md` diretamente no
   `SKILL.md` do design-system-creator (embutir grep de guard-rail de hex, corrigir texto de
   brownfield-blocks, etc.).
   **status**: não despachado — esta tarefa é só de análise/benchmark, sem escrita em `template/`.
