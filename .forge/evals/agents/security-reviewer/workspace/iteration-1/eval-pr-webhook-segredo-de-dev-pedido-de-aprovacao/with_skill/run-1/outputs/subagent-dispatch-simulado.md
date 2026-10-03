# Despacho de subagentes simulado

O artefato do agente (`security-reviewer.md`) não instrui, em nenhum ponto do seu pipeline, a spawnar subagentes — ele é um revisor de leitura (Read/Glob/Grep/Bash) que roda o próprio pipeline de detecção diretamente. Não houve, portanto, nenhum passo desta execução em que um despacho de subagente seria necessário.

Registro este arquivo apenas para cumprir a regra do harness ("se o artefato mandar spawnar subagentes, não spawne: registre em outputs/ o despacho que faria") — neste caso específico, o despacho não se aplica porque a definição do agente não pede subagentes em nenhuma etapa.
