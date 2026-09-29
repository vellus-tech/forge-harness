# Transcript — eval-corrige-card-saldo-branco-no-dark-vue / without_skill / run-1

## Contexto
Execução do caso de eval sem carregar nenhum artefato do skill-creator/agentes do harness (baseline `without_skill`). Trabalho feito apenas com conhecimento próprio do modelo, dentro de `work/` (fixture isolada gerada por `setup.sh`).

## Passos executados, em ordem

1. Gravei o instante inicial em `.t0` (`date +%s`).
2. Criei `work/` e rodei `setup.sh work/` para materializar a fixture (monorepo `bilhete-digital`, app Vue 3 + Pinia em `apps/web/bilhete-web/`, tokens de design em `packages/ui/src/tokens.css`).
3. Li `README.md` da fixture para entender onde ficam o app e os tokens.
4. Localizei os arquivos `.vue` relevantes: `apps/web/bilhete-web/src/features/balance/BalanceCard.vue` (o componente do bug relatado) e `apps/web/bilhete-web/src/features/statement/StatementList.vue`.
5. Li `BalanceCard.vue` e `packages/ui/src/tokens.css`.
   - `BalanceCard.vue` define `.card { background: var(--surface-1, #ffffff); border: 1px solid #e5e7eb; }`.
   - `tokens.css` define, em `:root`, os tokens `--surface-page`, `--surface-card`, `--surface-raised`, `--text-primary`, `--text-muted`, `--border-subtle`, etc.; em `[data-theme='dark']` redefine `--surface-card`, `--surface-raised`, `--text-primary`, `--text-muted`, `--border-subtle`.
   - Constatei que **`--surface-1` não existe em nenhum dos dois temas** — é um token inventado/errado, provavelmente resquício de uma refatoração de nomenclatura (`--surface-1` → `--surface-card`). Por isso o CSS sempre cai no fallback fixo `#ffffff`, tanto no tema claro quanto no escuro.
   - No tema escuro, `--text-primary` vira `#f3f4f6` (quase branco). Fundo fixo branco + texto quase branco = card "branco" e valor do saldo praticamente invisível — exatamente o sintoma relatado.
6. Apliquei a correção em `BalanceCard.vue`: troquei `background: var(--surface-1, #ffffff)` por `background: var(--surface-card)` e `border: 1px solid #e5e7eb` por `border: 1px solid var(--border-subtle)`, ambos tokens que existem e mudam corretamente por tema.
7. Notei que `StatementList.vue` tem o mesmo padrão (`background: var(--surface-1, #fff)`), mas o bug relatado pelo suporte fala apenas do card de saldo da home — optei por não alterar esse segundo arquivo para não extrapolar o escopo do chamado, e registrei a observação na doc de entrega para triagem separada.
8. Escrevi `docs/entregas/bug-card-saldo-dark.md` dentro de `work/`, com sintoma, causa raiz, diff da correção, arquivo alterado, a observação sobre `StatementList.vue` e uma seção de verificação.
9. Não rodei build/lint/testes: o ambiente de eval é uma fixture isolada sem `node_modules` instalado e as regras da tarefa proíbem `npm test`/instalação real neste caminho. A verificação foi por inspeção direta dos tokens definidos em `tokens.css` contra os usados no componente, comparando os dois temas.
10. Não houve necessidade de despachar subagentes — é uma correção pontual de uma única regra CSS em um único componente, dentro da capacidade de uma única passada de edição. Não há despacho a registrar.
11. Copiei os arquivos alterados (`BalanceCard.vue`, `bug-card-saldo-dark.md`) para `outputs/work/...` preservando o caminho relativo, e escrevi este transcript.
12. Fechamento: gravei `.t0`/`timing.json` e chequei o tamanho de `work/` para decidir se apago (ver `timing.json` para o resultado).

## Decisões e trade-offs
- Corrigi só o token quebrado (`--surface-1` → `--surface-card`) e a borda hardcoded, sem tocar em mais nada do componente (não mexi em tipografia, no `Intl.NumberFormat`, nem em estrutura do template) — mudança mínima e direta na causa raiz.
- Deixei `StatementList.vue` intocado por ter o mesmo bug potencial, mas fora do escopo do chamado de suporte; documentei em vez de "corrigir de brinde".
- Não instalei dependências nem rodei a stack Vue real para visualizar o resultado — o ambiente da eval é uma fixture minimalista sem app buildável fim-a-fim; a verificação ficou restrita à leitura cruzada dos tokens CSS, deixada explícita na doc de entrega como limitação.
