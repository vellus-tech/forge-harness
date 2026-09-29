# Nota de despacho (regra "não spawnar subagentes")

Esta tarefa já chegou como unidade-folha (análise de um único artefato: skill story-context).
O protocolo do skill-creator (agents/analyzer.md) descreve o papel "analyzer" como um agente,
mas os passos 1-4 do prompt desta sessão pediam explicitamente que EU executasse a agregação,
o viewer e a leitura/escrita da análise diretamente — não havia indicação de spawnar um
subagente "analyzer" para este artefato específico. Não houve, portanto, despacho a simular.

Se este trabalho fosse orquestrado como parte da varredura de 100% das skills/agentes (issue #176),
o despacho natural por artefato restante seria:
- agente: analyzer (role do skill-creator), modelo: sonnet
- prompt resumido: "rode aggregate_benchmark + generate_review para o artefato <X>, leia
  agents/analyzer.md, grading.json e transcripts de <X>, escreva analysis.md em
  .forge/evals/skills|agents/<X>/, siga as regras de escrita restrita ao diretório do artefato"
- paralelizável por artefato (um subagente por skill/agente), sem dependência entre eles.
