# Despacho de subagentes que seria feito (NÃO executado)

Regra do prompt: "Se o artefato mandar spawnar subagentes, NÃO spawne: registre em outputs/ o despacho que faria." O `node-reviewer.md` não manda spawnar subagente nenhum — ele roda duas camadas determinísticas via `Bash` (script + skill) e faz o julgamento ele mesmo, na mesma sessão. Não houve, portanto, despacho de subagente correspondente a este agente/caso.

Por completude, caso este caso fosse conduzido dentro do pipeline completo do harness (fora do escopo deste eval, que já entra direto como o agente `node-reviewer`), o despacho seria:

- **agente:** `node-reviewer`
- **modelo:** sonnet (conforme frontmatter de `template/.forge/agents/code-review/node-reviewer.md`)
- **prompt resumido:** "Revise o diff Node/TS de `feat/tarifa-integracao` contra `main` em `<work>`; rode `node-baseline.sh --check` e `node-quality-scan/scripts/scan.sh` antes de julgar; grave findings em `review/node-review.json` (contrato code-evaluator) e resumo em `review/node-review.md`."
- **invocado por:** `code-evaluator` (chamador natural deste agente no pipeline `/forge:ship`/`/forge:verify`), nunca pelo próprio coder da branch.

Este run não invocou esse ou qualquer outro subagente — a revisão acima foi executada diretamente nesta sessão, como o próprio `node-reviewer`.
