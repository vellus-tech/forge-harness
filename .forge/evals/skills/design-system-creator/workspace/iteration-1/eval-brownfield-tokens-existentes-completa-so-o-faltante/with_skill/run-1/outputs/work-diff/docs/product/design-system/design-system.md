# Design System — Rotaviva

| Campo | Valor |
|---|---|
| Versão | 0.1.0 |
| Data | 2026-09-26 |
| Status | Rascunho para revisão |

## Histórico de Versões

| Versão | Data | Autor | Mudança |
|---|---|---|---|
| 0.1.0 | 2026-09-26 | design-system-creator (agente) | Primeira versão — completa `icons`/`ui-components`/docs sobre os tokens já existentes |

## 1. Princípios

Rotaviva é uma carteira de mobilidade urbana: o passageiro recarrega o passe de transporte, acompanha o extrato de viagens e usa atalhos (recarga, cartões, ajuda). A marca é verde-petróleo, neutros frios, grade de espaçamento de 4 pt, raios generosos em cards e sombras suaves — sem jargão bancário, com frases curtas e valores sempre em "R$" com vírgula decimal (ver `chats/chat1.md` e `project/README.md` do handoff).

## 2. Três camadas

1. **`@rotaviva/design-tokens`** — cores, tipografia, espaçamento, raios, sombras e motion como CSS custom properties + objetos TS tipados. Fonte da verdade; qualquer outro documento cede a ela em caso de divergência.
2. **`@rotaviva/icons`** — wrapper único sobre `lucide-react` (`Icon`) e o mark oficial via PNG real (`RotavivaMark`). Nunca importar `lucide-react` diretamente num app ou bloco.
3. **`@rotaviva/ui-components`** — primitivos (`components/`), blocos do app (`blocks/`) e composições de tela só para Storybook (`patterns/`, categoria "Padrões" — não exportadas na API pública).

## 3. Fundamentos visuais

- Cor de marca `--brand` #0F9D8A (verde-petróleo), com `--brand-hover`/`--brand-press`/`--brand-soft` derivados.
- Neutros frios `--n-0` a `--n-900`.
- Tipografia display **Sora** (títulos, saldo) e UI **Manrope** (corpo, botões, labels), carregadas via Google Fonts — este handoff não trouxe `.ttf` self-hosted, então `tokens.css` só tem o `@import`, sem `@font-face`.
- Grade de espaçamento de 4 pt (`--s-1` a `--s-8`).
- Raios generosos em cards (`--r-lg` 20px) e pill em botões/badges (`--r-pill`).
- Sombras suaves (`--shadow-1`, `--shadow-2`).
- Motion: press mecânico `scale(0.96)` em `--dur-fast` (120ms), transições gerais em `--dur-base` (200ms), `--ease-out` como easing padrão.

## 4. Regras absolutas

- **Stack fixa: CSS Modules + tokens.** Sem Tailwind, sem Radix, sem CSS-in-JS. `.module.css` só usa `var(--…)` — nunca hex ou px soltos.
- **`forwardRef` + `cn()`** (wrap de `clsx`) em todo componente que renderiza um elemento DOM.
- **Ícones sempre via `@rotaviva/icons`** — nunca `import 'lucide-react'` direto num app/bloco.
- **Mark sempre via PNG real** (`RotavivaMark`) — nunca desenhar um SVG próprio do X/mark (`project/SKILL.md` do handoff).
- **Cor de marca nunca em texto corrido pequeno** — contraste `--brand` vs. branco ≈ 3,3–3,4:1; reservar para CTAs curtos e ícones-ação (ver `accessibility.md`).
- **Anel de foco nunca removido** — `outline: 2px solid var(--brand); outline-offset: 2px` em todo elemento interativo.
- **Apenas tema claro nesta versão** — o handoff (`chats/chat1.md`) fechou explicitamente "nada de modo escuro por enquanto"; `tokens.css` não tem camada dark. Documentado aqui com honestidade em vez de fingir suporte.
- **Copy de UI em pt-BR, identificadores em inglês.**

## 5. Modo escuro

**Não suportado nesta versão.** O handoff é explícito: "nada de modo escuro por enquanto — só claro. Fechado assim." (`chats/chat1.md`). `tokens.css` não define nenhuma camada `[data-theme="dark"]` ou `prefers-color-scheme`. Se um modo escuro for pedido no futuro, ele precisa vir de uma nova rodada de handoff — não deve ser inventado aqui.

## 6. Instalação

```bash
pnpm install
pnpm --filter @rotaviva/design-tokens --filter @rotaviva/icons run build
pnpm --filter @rotaviva/ui-components run storybook
```

## 7. Template de componente

```
components/MeuComponente/
├── MeuComponente.tsx        # forwardRef + cn()
├── MeuComponente.module.css # var(--…) apenas
├── MeuComponente.stories.tsx
├── MeuComponente.test.tsx   # RTL + runA11y
└── index.ts
```

## 8. Comandos Storybook

```bash
pnpm --filter @rotaviva/ui-components run storybook        # dev, porta 6006
pnpm --filter @rotaviva/ui-components run storybook:build  # build estático
```

## 9. Checklist de PR

- [ ] Nenhum hex/px hardcoded em `.module.css` — só `var(--…)`.
- [ ] `forwardRef` + `cn()` em todo componente novo.
- [ ] Ícone novo passa por `Icon` (`@rotaviva/icons`), nunca `lucide-react` direto.
- [ ] Story com `tags: ['autodocs']`.
- [ ] Teste cobre comportamento + `runA11y`.
- [ ] `typecheck`, `lint`, `test:ci` e `storybook:build` verdes.
- [ ] Nenhum commit/push feito sem pedido explícito.

## 10. Anti-patterns

- Reimportar `lucide-react` num app/bloco em vez de passar pelo `Icon`.
- Desenhar o X/mark em SVG em vez de usar o PNG real (`RotavivaMark`).
- Cor de marca em parágrafo/label de texto corrido pequeno.
- `className={undefined}` em `args` de story (usar `render` no lugar).
- Adicionar Tailwind/Radix/CSS-in-JS "só para esse componente".
- Reinventar `packages/design-tokens` quando ele já bate com o handoff (ver nota de brownfield no topo deste documento).

> **Nota de brownfield:** `packages/design-tokens` e este `tokens.md` já existiam e batiam com o handoff antes desta rodada — não foram recriados. Esta rodada completou apenas `packages/icons`, `packages/ui-components` e os três documentos que faltavam (`design-system.md`, `components.md`, `accessibility.md`).
