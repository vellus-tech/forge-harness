# Despacho de subagentes (simulado, não executado)

Regras da tarefa proíbem spawn real de subagentes nesta execução. O agente `clean-architecture-reviewer` (definido em `template/.forge/agents/architecture/clean-architecture-reviewer.md`) não pede escalonamento neste caso — a seção "Quando Escalar" só dispara `adr-writer` ou `ddd-validator` quando há decisão arquitetural nova ou divergência estrutural do módulo, e nenhuma das quatro violações encontradas se qualifica (são correções mecânicas dentro do padrão já adotado, ver `docs/revisoes/clean-arch-tarifacao.md` § Recomendação).

Se houvesse necessidade de escalar, o despacho seria:

- Nenhum despacho necessário neste caso.

(Nada foi spawnado; este arquivo documenta a ausência de despacho, conforme pedido pela tarefa.)
