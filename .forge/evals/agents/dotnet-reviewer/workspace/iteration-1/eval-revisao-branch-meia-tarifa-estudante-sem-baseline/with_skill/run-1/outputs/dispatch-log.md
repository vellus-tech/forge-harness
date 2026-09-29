# Registro de despacho de subagentes (simulado)

Regra do protocolo desta execução: não spawnar subagentes de fato; registrar aqui o que seria despachado, se algo fosse.

## Avaliação do critério "Quando Escalar" (dotnet-reviewer.md)

- **Mudança arquitetural (mover lógica entre camadas) → `clean-architecture-reviewer`**: não disparado. O achado mais grave (captive dependency: `DescontoService` Singleton injetando `TarifaDbContext` Scoped) é um defeito de ciclo de vida de DI, coberto pelo checklist item 3 do próprio `dotnet-reviewer` — não exige mover lógica entre camadas, só corrigir o registro do serviço em `Program.cs`. Resolvido dentro desta revisão, sem despacho.
- **Vulnerabilidade de segurança potencial → parar e escalar**: não disparado como bloqueio de execução. Os pontos de superfície de ataque encontrados (matrícula interpolada sem escape na URL do SGE, ausência de tratamento de erro que pode vazar stack trace) foram registrados como findings MEDIUM/HIGH no relatório em vez de justificarem parar a revisão — nenhum deles é uma vulnerabilidade já explorável neste diff que exija escalação imediata fora do relatório padrão.
- **Degradação de desempenho que requer profiling real**: não disparado. `.ToList().Where(...)` e a chamada bloqueante ao SGE são achados estáticos, decidíveis por leitura, sem necessidade de profiling.

## Despacho que seria feito, se houvesse

Nenhum. Nenhum subagente foi necessário para concluir esta revisão dentro do escopo do diff `feature/meia-tarifa-estudante` vs. `main`.
