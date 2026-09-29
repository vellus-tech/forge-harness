# Despacho de subagentes (simulado)

Nenhum despacho foi necessário. O agente `security-reviewer` (definição em `template/.forge/agents/review/security-reviewer.md`) é um agente-folha: tools declaradas são apenas `Read`, `Glob`, `Grep`, `Bash`, e o pipeline descrito (11 seções de verificação estática sobre o diff) não instrui invocar outros agentes — ele é, ele próprio, o alvo de invocação pelo `code-evaluator`. A tarefa deste run (revisar o diff `feature/notificacoes-jwt` vs `develop`) foi executada inteiramente por mim, sem necessidade de delegação.

Se houvesse necessidade (por exemplo, achado ambíguo exigindo leitura de um serviço externo fora do diff para confirmar o padrão de `LoadPermissionsAsync`), o despacho simulado seria:

- **Agente:** nenhum (não aplicável neste run)
- **Modelo:** não aplicável
- **Prompt resumido:** não aplicável
