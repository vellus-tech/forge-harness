# Despacho de subagentes (simulado, não executado)

O caso de eval não exigiu nenhum subagente: o pedido do usuário ("entra na worktree e deixa o ambiente pronto") é single-shot e cabe inteiramente no fluxo da skill `using-git-worktrees` (Passo 0 → detecção, Passo 2 → setup, Passo 3 → baseline de testes), sem paralelismo nem investigação aberta que justifique delegação.

Se houvesse motivo para delegar, o despacho seria:

- **Agente:** nenhum necessário para este caso.
- **Modelo:** N/A.
- **Prompt resumido:** N/A.

Nenhum subagente foi de fato spawnado nesta execução, conforme a regra do harness para este caso de eval.
