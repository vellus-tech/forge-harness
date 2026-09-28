# Despacho de subagentes (simulado, não executado)

Regra do run: nenhum subagente foi de fato spawnado nesta execução — este arquivo registra o que
seria despachado caso a política do run permitisse.

## Avaliação

A definição do agente `android-embedded-kotlin-engineer` (`template/.forge/agents/engineering/android-embedded-kotlin-engineer.md`)
não lista nenhuma ferramenta de spawn de subagente em `tools:` (apenas Read, Glob, Grep, Write, Edit,
Bash, mcp__context7__*) e não menciona orquestração de subagentes em sua rotina operacional
(seção 28). A TASK-04 é uma unidade única e pequena (imprimir comprovante após aprovação, com
adapter de hardware isolado) — não há fan-out natural que justificasse dividir o trabalho entre
múltiplos agentes especializados.

## Despacho que seria feito, se necessário

Nenhum. Para esta TASK específica, um único agente `android-embedded-kotlin-engineer` (modelo
`sonnet`, conforme frontmatter do próprio agente) é suficiente: o escopo é um caso de uso de
domínio + um adapter de hardware, ambos dentro da especialidade do agente.

Caso a TASK fosse maior (ex.: onda completa do módulo `recarga` com múltiplas TASKs paralelizáveis
sem dependência entre si), o despacho hipotético seria:

| Ordem | Agente | Modelo | Prompt resumido |
|---|---|---|---|
| 1 | android-embedded-kotlin-engineer | sonnet | Implementar TASK-04 (impressão de comprovante) — este run |
| — | (nenhuma outra TASK paralela identificada nesta fixture) | — | — |

Nenhuma chamada de spawn foi executada; este arquivo é só o registro do que seria despachado.
