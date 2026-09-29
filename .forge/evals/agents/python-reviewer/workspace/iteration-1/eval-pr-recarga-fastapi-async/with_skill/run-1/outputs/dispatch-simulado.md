# Despacho de subagentes (simulado — não executado)

A tarefa do `python-reviewer` (revisão Python isolada, ferramentas `Read`/`Grep`/`Glob`) não exige, pela definição do agente em `template/.forge/agents/code-review/python-reviewer.md`, o disparo de subagentes adicionais — é um reviewer single-shot chamado pelo `code-evaluator`. Nenhum ponto do fluxo pediu spawn de agente nesta execução.

Caso o protocolo do orquestrador (`code-evaluator`) estivesse em jogo nesta mesma sessão, o próximo passo natural seria o despacho abaixo, registrado aqui em vez de executado, por regra da tarefa:

- **Agente:** `code-evaluator` (orquestrador)
- **Modelo:** conforme `template/.forge/agents/review/code-evaluator.md` (effort max)
- **Prompt resumido:** consolidar `review/python-reviewer.json` (7 findings: 1 BLOCKER, 3 HIGH, 2 MEDIUM, 1 LOW) com os demais reviewers de stack (nenhum outro aplicável — diff é 100% Python), aplicar a regra de severidade (`needs_fix = BLOCKER+HIGH > 0` → aqui `true`, 4 findings bloqueantes) e retornar veredito `REJECTED`/loop de correção via `fullstack-software-engineer`.

Nenhum agente foi de fato spawnado nesta execução.
