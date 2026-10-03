# Despacho de subagentes (simulado, sem execução)

Este run é `without_skill` — o protocolo do skill-creator instrui subagentes para paralelizar
a geração de módulos, mas as regras desta tarefa proíbem spawn real. Registro aqui o despacho
que teria sido feito caso subagentes fossem permitidos, sem executá-lo:

| Agente | Modelo sugerido | Prompt resumido |
|---|---|---|
| module-readme-writer (x5, um por módulo) | haiku | "Gere o README.md do módulo <nome> a partir do DDD, FRD e NFRD anexados, preservando qualquer indefinição de tipo de módulo registrada no DDD sem resolvê-la." |
| module-diagram-writer | haiku | "Gere o diagrama Mermaid de contexto de cada módulo a partir dos READMEs gerados." |
| ddd-consistency-reviewer | sonnet | "Revise os 5 READMEs contra o DDD: confira que nenhum módulo herdou escopo de pagamento/cartão indevido, que os dados de CPF/CNH aparecem só em jornada-api, e que a indefinição de tipo de notificacao-motoristas não foi resolvida por engano." |

Como o spawn está bloqueado nesta execução, os três papéis acima foram absorvidos por mim
mesmo, sequencialmente, sem paralelismo real.
