# Passo 9 da skill (build + verificação) — simulado, não executado

Regra do harness deste eval proíbe rodar `npm test`/suítes reais e qualquer instalação/rede ("ou qualquer ação externa"). `pnpm install` também exigiria rede (bloqueada no cenário). Por isso os comandos abaixo — exatamente os do passo 9 do `SKILL.md` — **não foram executados**; documento aqui o que cada um faria e o resultado esperado dado o código escrito.

```bash
pnpm --filter @rotaviva/design-tokens --filter @rotaviva/icons run build
pnpm --filter @rotaviva/ui-components run typecheck
pnpm --filter @rotaviva/ui-components run lint
pnpm --filter @rotaviva/ui-components run test:ci
pnpm --filter @rotaviva/ui-components run storybook:build
```

## Expectativa por comando

- **`design-tokens`/`icons` build** — `tsc -p tsconfig.build.json` em cada um. `design-tokens` já buildava antes (brownfield). `icons` é novo; risco conhecido: `RotavivaMark.tsx` usa `new URL('../assets/...', import.meta.url)`, que `tsc` (module NodeNext) aceita mas só resolve de fato em bundler (Vite/Storybook) — comportamento esperado, mesmo padrão descrito na skill.
- **`typecheck`** (`tsc --noEmit` em `ui-components`) — maior risco real: os `.tsx` importam `@rotaviva/icons` e `@rotaviva/design-tokens` como pacotes de workspace; sem os `dist/` buildados primeiro (passo anterior) o resolver falha em "Cannot find module" — é exatamente a armadilha documentada na skill ("buildar design-tokens e icons ANTES"). Assumindo a ordem respeitada, o único ponto not-100%-certo é se `exactOptionalPropertyTypes: true` aceita `Input`'s `error?: string` sendo passado como `error={undefined}` em algum lugar — conferi e não há esse caso nos stories/testes escritos.
- **`lint`** — `eslint.config.js` foi criado do zero (repo não tinha eslint na raiz); não testado com o binário real, então pode haver ajuste de regras necessário na primeira rodada real (fora do escopo deste eval).
- **`test:ci`** (`vitest run --coverage`) — 8 arquivos de teste (`Button`, `Input`, `Badge`, `Card`, `Eyebrow`, `AppHeader`, `BalanceCard`, `TripRow`, `ShortcutGrid`, `BottomNav` — 10 no total) cobrindo comportamento + `runA11y`. Cobertura esperada alta em `components/`/`blocks/` porque cada arquivo tem teste dedicado; não há como confirmar os thresholds (80/75/80) sem rodar.
- **`storybook:build`** — depende de `storybook` + `@storybook/react-vite` instalados (não estão, sem rede). Estrutura de `.storybook/{main.ts,preview.tsx,manager.ts,storybook.css}` segue o que a skill pede (`@storybook/react-vite`, addons a11y+themes, `storySort` Fundamentos→Componentes→Blocos→Padrões, `tags:['autodocs']` default).

## Conclusão honesta

Nenhum destes comandos rodou. O código foi escrito para ser consistente com a skill e com os tokens/handoff reais, mas "tudo verde" (Definition of Done item 4) **não está verificado** neste eval — está simulado/documentado, como as regras do harness exigem.
