# Despacho de subagentes (simulado — não executado)

As regras desta run proíbem explicitamente spawnar subagentes: qualquer despacho deve ser apenas registrado, não executado. Nenhum agente foi invocado nesta run. Este arquivo documenta o que seria despachado, caso a política permitisse.

## Despacho que seria feito

| # | Agente | Modelo | Prompt resumido | Por quê |
|---|---|---|---|---|
| 1 | `adr-writer` | sonnet | Redigir ADR reconciliando CONF-DDD-001: Recarga como bounded context pleno (ddd-segmentation.md, context-map, bounded-contexts/recarga/README.md) vs. módulo interno da Carteira (ADR-0003, Aceita). Apresentar as duas alternativas e pedir decisão humana. | Conflito entre artefatos DDD e uma ADR aceita — pelo mandato do `ddd-validator` (§7 "Quando Escalar": "Há conflito com ADR" → registrar Conflito Arquitetural; "Há duas modelagens DDD igualmente válidas" → propor ADR via `adr-writer`). Não decidido pelo validador. |
| 2 | `ddd-architect` | sonnet | Reexecutar a segmentação/context-map de Recarga após a decisão do ADR acima, para eliminar a divergência com a ADR-0003 antes de qualquer mudança de ownership de dados. | O relatório recomenda reexecução do `ddd-architect` como próximo passo (§18, "Próximos Passos"); não é trabalho deste agente de validação. |

Nenhum outro agente teria trabalho justificado nesta run: o escopo era avaliação crítica de modelagem DDD já materializada, sem código a gerar (`task-coder`), sem deploy (`deploy-orchestrator`) e sem PR a abrir (`sprint-orchestrator`). As duas mudanças pedidas pelo time de backend (promover PCI a Core; mover `carteira` para Recarga) foram avaliadas e recusadas diretamente pelo `ddd-validator` — não exigem despacho a outro agente, exigem decisão humana de produto/arquitetura (registrada como Pontos a Validar VAL-DDD-01 e VAL-DDD-02 no relatório).
