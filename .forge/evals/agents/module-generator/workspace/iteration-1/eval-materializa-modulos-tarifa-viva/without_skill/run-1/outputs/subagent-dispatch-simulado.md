# Despacho de subagentes (simulado, não executado)

Nada no artefato desta execução `without_skill` instruiu spawnar subagentes — este é o caso de baseline, sem o protocolo `skill-creator`/`module-generator` disponível para leitura, e sem repositório de agentes especializados a invocar. A tarefa (materializar `docs/product/modules/` a partir de DDD/FRD/NFRD/TRD/data-model já aprovados) foi executada inteiramente com o conhecimento próprio do agente, sem necessidade de dispatch.

Se um protocolo de módulo estivesse disponível e pedisse paralelização, o despacho que eu faria seria:

| Agente (hipotético) | Modelo | Prompt resumido |
|---|---|---|
| module-readme-writer × 6 | haiku | "Escreva o README de `<módulo>` a partir do DDD segmentation, FRD, NFRD e data-model já lidos; siga o template X" — um por módulo, paralelizável por não haver dependência entre READMEs. |
| diagram-writer | sonnet | "Gere os três diagramas Mermaid (arquitetura, dependências, integração) a partir do context map e dos READMEs já escritos" — depende dos READMEs, roda depois. |
| module-index-writer | sonnet | "Componha o índice geral e a matriz de rastreabilidade com FRD/NFRD, cruzando com os READMEs e diagramas prontos" — depende de tudo acima. |

Como as regras desta execução proíbem spawn real, este arquivo registra apenas a intenção; o trabalho foi feito diretamente, sequencialmente, por mim.
