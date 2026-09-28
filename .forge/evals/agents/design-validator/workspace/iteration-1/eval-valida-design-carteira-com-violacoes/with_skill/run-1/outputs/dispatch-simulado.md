# Despacho de subagentes (simulado — não executado)

O harness desta execução proíbe spawnar subagentes de verdade neste run de eval; este arquivo registra o que
teria sido despachado se a execução fosse real, para fins de auditoria do eval.

A especificação `design-validator` (`.forge/agents/specifications/design-validator.md`) declara ferramentas
`Read`, `Glob`, `Grep` e roda em modelo único (`sonnet`) — não prevê, ela mesma, spawn de subagentes internos
para cumprir a validação. A tarefa foi completada por este agente sozinho, sem necessidade de dispatch adicional.

Se este fosse um caso onde o design-validator precisasse de apoio (por exemplo, checar um ADR referenciado
que não existisse no repositório, ou correlacionar com um design de outro módulo para verificar consistência
cross-module), o despacho simulado seria:

- Agente: nenhum necessário nesta execução.
- Modelo: n/a.
- Prompt resumido: n/a.

Nada foi de fato spawnado; esta nota substitui o dispatch real por registro, conforme instrução do harness.
