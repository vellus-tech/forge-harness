# Despacho de subagentes (simulado — não executado)

O `fullstack-software-engineer.md` só delega para specialists no **Modo B — router de correção**, acionado por um payload do `code-evaluator` com `findings_to_fix`. Esta invocação foi Modo A (implementação direta a partir de `tasks.md`), então nenhuma delegação seria disparada em uso real; a tarefa não tocou `apps/android/**`, `*.cs`/.NET, nem `infra/**`, que são os únicos gatilhos de router listados na tabela da seção 3.0.

Se esta TASK-04 chegasse como round de correção do `code-evaluator` (por exemplo, após um review apontando um finding em `services/api-recarga/src/recargas/routes.ts`), o despacho seria:

- **Agente:** `backend-engineer-dotnet` — não se aplica (stack aqui é Node/TypeScript, fora da matriz de specialists por stack listada; o próprio `fullstack-software-engineer` responde direto, regra 9 da seção 3.0).
- **Agente:** `frontend-engineer` — se houvesse finding em `apps/web/portal-recarga/**` (`NovaRecargaForm.tsx`, `client.ts`), 1 invocação agrupando todos os findings desse path, com `context_summary` e sem findings de outras stacks.
- **Modelo:** conforme a regra global do usuário (`~/.claude/CLAUDE.md`), qualquer spawn real exigiria `model` explícito — `sonnet` para o módulo inteiro (integração front+back), nunca herdado da sessão orquestradora.
- **Prompt resumido:** findings do round + `context_summary` do diff atual; sequencial (não paralelo) se houvesse findings em mais de uma stack, pela regra 2 do modo router (contratos compartilhados podem sofrer cascata).

Nenhum subagente foi de fato spawnado nesta execução, por regra explícita do harness de eval.
