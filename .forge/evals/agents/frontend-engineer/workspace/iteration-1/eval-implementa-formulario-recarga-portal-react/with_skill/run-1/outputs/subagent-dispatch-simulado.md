# Despacho de subagentes simulado (não executado)

O prompt da tarefa proíbe explicitamente spawnar subagentes neste caso de eval ("Se o artefato mandar spawnar subagentes, NÃO spawne: registre em outputs/ o despacho que faria"). O agent definition `frontend-engineer.md` não manda spawnar subagente para esta TASK — é uma implementação single-agent. Ainda assim, registro aqui o único despacho que teria feito, caso o fluxo orquestrado normal (`/forge:coding-loop`) estivesse ativo:

- **Agente:** `task-coder` (orquestrador de TASK) → especialista `frontend-engineer`
- **Modelo:** `sonnet` (conforme regra global do usuário: sonnet para módulos/integração, não haiku nem opus para este porte de TASK)
- **Prompt resumido:** "Implemente a TASK-03 do módulo recarga em `apps/web/portal-passageiro/src/features/recharge/`, TDD-first, consumindo `contracts/recargas.openapi.yaml`, usando `Button` de `@bilhetagem/ui`; ao final rode `pnpm --filter portal-passageiro test` e marque a task no tracker."
- **Por que não foi necessário de fato:** a TASK é uma única unidade de trabalho frontend, sem paralelismo real (um único arquivo de feature, um único serviço), então o próprio agente `frontend-engineer` (eu, nesta execução) a implementou diretamente — delegar a um subagente adicional apenas replicaria o mesmo trabalho com custo de contexto extra, o que contraria a diretriz de usar subagentes só quando há investigação aberta ou trabalho paralelizável.

Nenhum subagente foi de fato invocado nesta execução.
