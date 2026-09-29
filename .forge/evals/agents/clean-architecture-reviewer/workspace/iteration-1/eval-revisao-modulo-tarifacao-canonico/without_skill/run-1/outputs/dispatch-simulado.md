# Despacho de subagentes (simulado, não executado)

Regra do harness para esta run: nunca spawnar subagentes de fato; registrar aqui o despacho que seria feito.

Para este caso de eval (`without_skill`, revisão de Clean Architecture de um único módulo pequeno, 5 projetos / 7 arquivos .cs), o trabalho coube inteiro a este agente, lendo os `.csproj` e os `.cs` diretamente — não haveria ganho real em fragmentar em subagentes. Se o módulo fosse maior (múltiplos bounded contexts, dezenas de arquivos por camada), o despacho hipotético seria:

- **agente:** `clean-architecture-reviewer` (por camada) × 1 por camada (Api, Application, Domain, Infrastructure, Contracts)
  **modelo:** sonnet
  **prompt resumido:** "Liste todos os `using` e referências de `.csproj` desta camada; aponte qualquer dependência que aponte para fora da direção permitida (Domain não pode importar Infrastructure/Api/Application; Application não pode importar Infrastructure/Api)."
- **agente:** `clean-architecture-reviewer` (síntese)
  **modelo:** opus (effort medium)
  **prompt resumido:** "Consolide os achados por camada num único relatório docs/revisoes/clean-arch-tarifacao.md, removendo duplicatas e ordenando por severidade."

Neste run, a síntese foi feita diretamente por este agente, sem despacho.
