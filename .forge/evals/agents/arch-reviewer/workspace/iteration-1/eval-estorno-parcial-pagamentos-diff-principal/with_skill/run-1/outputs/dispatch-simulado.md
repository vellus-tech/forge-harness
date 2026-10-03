# Despacho de subagente simulado (não executado)

Regra do run proíbe spawnar subagentes nesta execução. Se pudesse, o despacho seria:

- **Agente:** nenhum — a tarefa (revisão arquitetural de um único diff de ~7 arquivos, já pequeno e coeso) não justifica delegar a um subagente; o próprio `arch-reviewer` executa a pipeline descrita em `template/.forge/agents/review/arch-reviewer.md` (grep nos `.csproj`, grep por `MassTransit`/EF Core/AWS SDK no Domain, leitura dos arquivos novos, checagem contra `clean-architecture.md`, `ddd.md` e `api-and-contracts.md`) diretamente, com Read/Grep/Bash.
- **Modelo:** sonnet (definido no frontmatter do agente).
- **Prompt resumido (se houvesse necessidade de paralelizar):** "Rode a pipeline de detecção de violação de regra de dependência sobre os `.csproj` do diff `develop..HEAD` em `services/pagamentos` e retorne apenas a tabela de ProjectReference por projeto, sem interpretar." — dispensável aqui porque são 5 `.csproj`, todos lidos em uma única chamada.

Nenhum subagente foi spawnado nesta execução.
