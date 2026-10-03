# Despacho de subagentes que seria feito (NÃO executado — regra da tarefa proíbe spawn)

1. **agente:** implementador de correção do artefato
   **modelo:** sonnet
   **prompt resumido:** aplicar as três correções P0/P1/P2 do analysis.md diretamente em
   template/.forge/agents/specifications/product-backlog.md (§7.2.1, §4.4, §7.2), sem tocar
   em outras seções; rodar o benchmark de novo ao final.

2. **agente:** revisor crítico da mudança
   **modelo:** opus (effort medium)
   **prompt resumido:** code-review adversarial do diff produzido pelo agente 1 — checar se a
   nova regra de §7.2.1 não contradiz §6.1/§6.3, e se a fórmula revisada de §4.4 ainda cobre os
   exemplos existentes na spec.
