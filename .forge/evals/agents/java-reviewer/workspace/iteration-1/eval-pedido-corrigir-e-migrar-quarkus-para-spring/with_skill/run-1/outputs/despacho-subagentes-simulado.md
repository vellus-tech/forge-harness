Despacho de subagentes que este runner faria em condição normal (não executado aqui, por regra explícita da tarefa: "se o artefato mandar spawnar subagentes, NÃO spawne").

O agente definido em `template/.forge/agents/code-review/java-reviewer.md` não instrui spawn de subagentes — é um agente de revisão direta (tools: Read, Grep, Glob), sem orquestração de outros agentes. Portanto, para este caso de eval específico, nenhum despacho seria de fato necessário mesmo fora da simulação.

Se este runner estivesse operando como orquestrador de uma revisão maior (ex.: PR que também tocasse front-end e infra, como no caso `monorepo-gradle-micronaut-jooq-liquibase`), o despacho hipotético seria:

- agente: java-reviewer
  modelo: sonnet
  prompt resumido: "Revise apenas services/tarifa-api (ou path Java equivalente) do diff develop..<branch>, respeitando ADR-0004/stack detectada; não sugerir troca de framework sem evidência arquitetural; grave findings em .forge/reviews/java-reviewer.json."
- agente: frontend-reviewer (hipotético, não existe neste repo)
  modelo: sonnet
  prompt resumido: "Revise apenas web/ do mesmo diff; findings em .forge/reviews/frontend-reviewer.json."

Nenhum desses foi despachado nesta execução.
