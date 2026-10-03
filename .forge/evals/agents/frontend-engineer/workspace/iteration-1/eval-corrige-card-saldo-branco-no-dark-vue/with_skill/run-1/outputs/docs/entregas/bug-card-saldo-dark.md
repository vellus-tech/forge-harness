# Bug: card de saldo vira retângulo branco no tema escuro

## Sintoma reportado pelo suporte

No bilhete-web, com o tema escuro ligado, o card de saldo da home vira um retângulo branco e o valor do saldo praticamente some (baixo contraste sobre fundo claro inesperado).

## Causa raiz

`BalanceCard.vue` (o card de saldo) e `StatementList.vue` (extrato, mesmo defeito) referenciavam um token inexistente, `--surface-1`, com fallback literal: `background: var(--surface-1, #ffffff)`. Esse token nunca foi definido em `packages/ui/src/tokens.css` — o token real de fundo de card é `--surface-card`. Em qualquer tema, `--surface-1` não resolve, então o CSS sempre caía no fallback literal `#ffffff`, ignorando completamente o tema ativo (`[data-theme='dark']`). Como o texto (`--text-primary`) já estava correto e clareia no dark, o resultado era texto claro sobre fundo branco fixo — daí o "sumiço" do valor.

Esse é exatamente o anti-padrão de **token fantasma + fallback literal** descrito em `.forge/rules/frontend/design-system.md` (regras 10 e 11): o token fantasma "funciona" por acaso no tema claro (o fallback coincide com a cor certa) e vira um buraco visual no tema escuro.

`BalanceCard.vue` também tinha uma borda com cor hardcoded (`#e5e7eb`) em vez do token `--border-subtle`.

## Correção aplicada

- `apps/web/bilhete-web/src/features/balance/BalanceCard.vue`: `background: var(--surface-1, #ffffff)` → `background: var(--surface-card)`; `border: 1px solid #e5e7eb` → `border: 1px solid var(--border-subtle)`.
- `apps/web/bilhete-web/src/features/statement/StatementList.vue`: `background: var(--surface-1, #fff)` → `background: var(--surface-card)` (mesmo defeito, mesma correção, para não deixar a mesma classe de bug viva num componente irmão).

Nenhum token novo foi criado; `--surface-card` e `--border-subtle` já existiam em `packages/ui/src/tokens.css`, com valores definidos tanto para `:root` (claro) quanto para `[data-theme='dark']`.

## Verificação

- Varredura manual de tokens fantasma (`var(--x)` referenciado vs. definido em `tokens.css`) e de fallback literal em `var()` nos diretórios `apps/` e `packages/`: zero ocorrências após a correção (evidência em `outputs/token-scan.txt`).
- **Não executei build, `vitest`/testes automatizados nem o app no navegador nesta sessão** — está fora do escopo autorizado deste run de avaliação (proibição explícita de `npm test`/execução real). Ficam pendentes de execução por quem rodar a suíde do projeto:
  - `pnpm --filter bilhete-web test` (o teste existente `BalanceCard.test.ts` cobre apenas o valor formatado, não a cor de fundo; recomendo adicionar um teste ou verificação visual que force `document.documentElement.dataset.theme = 'dark'` e verifique que o card não usa branco fixo).
  - Inspeção visual manual no navegador alternando `useTheme().toggle()` para confirmar contraste no dark.

## Impacto visual/UX

Card de saldo e lista de extrato passam a herdar corretamente a superfície de card do tema ativo (clara ou escura), restaurando o contraste entre fundo e texto no dark. Nenhuma mudança visual no tema claro (o valor de `--surface-card` em `:root` é `#ffffff`, idêntico ao fallback antigo).

## Pendências

- Adicionar teste de regressão que cubra especificamente o tema escuro (nenhum teste hoje no repositório varia `data-theme`).
- Considerar o gate determinístico A1 da skill `frontend-ui-review` (scan de token fantasma) como CI gate, conforme já recomendado em `.forge/rules/frontend/design-system.md`.
