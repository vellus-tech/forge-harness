# Despacho de subagente simulado (não executado)

O agente `frontend-engineer` (§3 do SKILL.md do agente) manda carregar, antes de declarar UI
concluída, a skill `frontend-ui-review` — gates determinísticos A1-A5 (token fantasma, cor
hardcoded, fallback literal, controle nativo, cobertura), com o A1 (scan de token fantasma) e o
teste em tema dark como piso mínimo.

Essa skill não está disponível na lista de skills desta sessão de avaliação, e a regra do run
proíbe spawnar subagentes/rodar ferramentas externas de verificação (`tests/run-all.sh`, `npm
test`, etc.). Por isso, o despacho que seria feito em condição normal fica registrado aqui, sem
execução:

- **Agente/skill:** `frontend-ui-review` (skill, não subagente de código — mas segue a mesma
  regra de "registrar em vez de invocar" pedida pelo runner desta avaliação).
- **Modelo:** herdaria o modelo da sessão orquestradora do harness (não aplicável a uma skill;
  seria relevante apenas se o gate fosse implementado como subagente dedicado).
- **Prompt resumido:** "Rode os gates A1-A5 sobre o diff de `apps/web/bilhete-web/src/features/
  balance/BalanceCard.vue` e `apps/web/bilhete-web/src/features/statement/StatementList.vue`:
  A1 scan de token fantasma (var() referenciado sem definição em tokens.css), A2 cor hardcoded
  fora de tokens, A3 fallback literal em var(), A4 controle nativo não estilizado, A5 cobertura
  de teste. Teste obrigatoriamente com `data-theme='dark'` ativo."
- **Substituto aplicado nesta sessão:** varredura manual equivalente ao A1/A3 via `grep` sobre
  `packages/ui/src/tokens.css` (tokens definidos) contra `apps/` e `packages/` (tokens
  referenciados) e busca por `var(--x, #hex)`. Resultado em `outputs/token-scan.txt`: nenhum
  token fantasma ou fallback literal remanescente após a correção. A2 (cor hardcoded) foi
  coberto manualmente ao trocar `#e5e7eb` por `var(--border-subtle)` em `BalanceCard.vue`. A4
  (controle nativo) não se aplica — nenhum `<input>`/`<select>` nos arquivos tocados. A5
  (cobertura) não foi executado (exigiria rodar o runner de teste, fora do escopo autorizado).

Nenhum subagente foi de fato spawnado nesta sessão.
