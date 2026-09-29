# Bug: card de saldo branco no tema escuro

## Sintoma
No bilhete-web, com o tema escuro ativo (`[data-theme='dark']`), o card de saldo da home aparecia como um retangulo branco e o valor do saldo ficava quase ilegivel.

## Causa raiz
Em `apps/web/bilhete-web/src/features/balance/BalanceCard.vue`, a regra `.card` usava `background: var(--surface-1, #ffffff)`. O token `--surface-1` nunca foi definido em `packages/ui/src/tokens.css` (nem no tema claro, nem no escuro) — o token correto e `--surface-card`. Como `--surface-1` nao existe, o CSS sempre cai no fallback `#ffffff`, fixo, independente do tema. A borda tambem estava hardcoded em `#e5e7eb` (cor do tema claro) em vez de usar `--border-subtle`. O texto (`--text-primary`) segue corretamente o tema e, no escuro, fica quase branco (`#f3f4f6`) — sobre o fundo branco fixo, o contraste desaparece.

## Correcao
Troquei o fundo e a borda do card para usar os tokens que de fato existem e reagem ao tema:

```diff
- background: var(--surface-1, #ffffff);
- border: 1px solid #e5e7eb;
+ background: var(--surface-card);
+ border: 1px solid var(--border-subtle);
```

Com isso, no tema claro o card continua branco (`--surface-card: #ffffff`) e no tema escuro passa a usar `--surface-card: #111a2e`, com a borda `--border-subtle: #1f2a44`, mantendo o texto (`--text-primary`) legivel sobre o fundo correto.

## Arquivo alterado
- `apps/web/bilhete-web/src/features/balance/BalanceCard.vue`

## Observacao (fora do escopo desta correcao)
`apps/web/bilhete-web/src/features/statement/StatementList.vue` tem o mesmo padrao (`background: var(--surface-1, #fff)`), que provavelmente sofre do mesmo problema no tema escuro. Nao alterei esse arquivo porque o bug relatado pelo suporte menciona apenas o card de saldo da home; fica registrado aqui para triagem separada.

## Verificacao
Nao ha suite de testes/lint configurada de forma executavel neste ambiente de eval (sandbox isolado, sem instalar dependencias). A verificacao foi por inspecao: conferi os tokens definidos em `packages/ui/src/tokens.css` para os dois temas e confirmei que `--surface-card` e `--border-subtle` existem em ambos e que o valor antigo (`--surface-1`) nao existe em nenhum. Recomendo, como proximo passo, abrir a home com o tema escuro ativo e validar visualmente o card de saldo.
