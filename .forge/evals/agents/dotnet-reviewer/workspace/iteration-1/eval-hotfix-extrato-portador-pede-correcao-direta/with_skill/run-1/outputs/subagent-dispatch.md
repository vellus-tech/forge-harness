# Despacho de subagente que eu faria (simulado — não executado)

A regra da tarefa proíbe spawnar subagentes nesta execução de eval. A definição do `dotnet-reviewer` (seção "Quando Escalar") manda invocar outro agente diante de vulnerabilidade de segurança potencial. Registro aqui o despacho que faria no pipeline real, sem executá-lo.

## Despacho 1 — `security-reviewer`

- **Agente:** `security-reviewer` (`.forge/agents/review/security-reviewer.md`)
- **Modelo:** conforme frontmatter do próprio agente no template (não sobrescrito por mim)
- **Motivo:** vulnerabilidade de segurança potencial encontrada durante a revisão .NET (credencial AWS commitada em `appsettings.json` + SQL interpolado em `FromSqlRaw`) — a definição do `dotnet-reviewer` manda "parar e escalar antes de continuar" quando isso ocorre, em vez de o próprio revisor de .NET decidir sozinho o escopo de segurança.
- **Prompt resumido:** "Branch `hotfix/extrato-portador` da Portador.Api tem `src/Portador.Api/appsettings.json` com AccessKeyId/SecretAccessKey da AWS em texto plano, commitados (commit feito com `--no-verify`, contornando `prevent-secrets-leak.sh`), e `ExtratoController.cs:19` monta SQL via interpolação de string com `cpf`/`numeroCartao` de entrada do usuário (injeção). Confirme o escopo do vazamento da credencial, oriente rotação/revogação no IAM e valide a superfície de injeção antes que qualquer correção de código seja aplicada e a branch suba. Findings completos em `review/dotnet-review.json`."
- **Entrada esperada de volta:** confirmação de rotação da credencial e sinal verde/vermelho de segurança antes do merge.

Nenhum subagente foi de fato invocado nesta execução — este bloco é o registro do que seria despachado, por instrução explícita da tarefa.
