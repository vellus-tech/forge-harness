# Rotaviva — Design System
**Visão geral**

- **Versão:** 1.0.0
- **Data:** 2026-09-26
- **Status:** Rascunho
- **Referência pai:** —

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 1.0.0 | 2026-09-26 | Atual | Primeira versão, gerada a partir do handoff `rotaviva-design-system` (Claude Design) |

---

## Princípios

Rotaviva é uma carteira de mobilidade urbana: o passageiro recarrega o passe de transporte, acompanha o extrato de viagens e usa atalhos (recarga, cartões, ajuda). O design system serve esse único fluxo — não é um kit genérico.

### Voz e marca

Direta, próxima, sem jargão bancário. Frases curtas. Valores sempre com "R$" e vírgula decimal. "Recarregar", nunca "efetuar recarga". "Suas viagens", nunca "histórico de transações".

Cor de marca verde-petróleo (`--brand: #0F9D8A`) — decisão final do chat de design, que trocou um roxo inicial (`#7A3CF0`, "parece banco digital genérico") por este tom. Neutros frios, grade de espaçamento de 4 pt, raios generosos em cards, sombras suaves. Tipografia display Sora, UI Manrope.

## As três camadas

1. **`packages/design-tokens`** — CSS custom properties + objetos TS tipados. Fonte de verdade visual.
2. **`packages/icons`** — wrapper único sobre `lucide-react` + a marca Rotaviva via PNG real.
3. **`packages/ui-components`** — primitivos (`components/`), blocos do app (`blocks/`) e composições de tela só-Storybook (`patterns/`).

## Fundamentos visuais

Ver `tokens.md` para a tabela completa. Resumo: cor de marca única (sem escala de matiz), neutros frios de `#FFFFFF` a `#14202A`, tipografia dupla (Sora display / Manrope UI), espaçamento em múltiplos de 4px, raios generosos (`--r-lg: 20px` em cards), sombras suaves de dois níveis.

## Regras absolutas

- **Stack:** CSS Modules + tokens (CSS custom properties). **Proibido Tailwind, Radix ou CSS-in-JS.**
- **Sem valor hardcoded** em `.module.css` — sempre `var(--...)`.
- **Nunca desenhar o mark Rotaviva em SVG** — sempre o PNG real de `@rotaviva/icons`.
- **Nunca remover o anel de foco** (`:focus-visible`, 2px `--brand`, offset 2px).
- **Nunca usar `--brand` em texto corrido pequeno** (contraste ~3.4:1 sobre branco).
- **Nunca importar `lucide-react` direto** num app ou bloco — sempre via `@rotaviva/icons`.
- `forwardRef` + helper `cn()` (clsx) em todo componente.
- Imports internos com extensão `.js` (NodeNext).
- Copy de UI em pt-BR, identificadores em inglês.

## Modo escuro

**Não existe nesta versão.** O usuário fechou explicitamente "nada de modo escuro por enquanto — só claro" no chat de design. `tokens.css` não tem camada `[data-theme="dark"]`; nenhum componente deve assumir uma.

## Instalação

```bash
pnpm install
pnpm --filter @rotaviva/design-tokens --filter @rotaviva/icons run build
```

## Template de componente

```
Componente/
├── Componente.tsx        # forwardRef + cn()
├── Componente.module.css # tokens-only
├── Componente.stories.tsx
├── Componente.test.tsx   # RTL + runA11y
└── index.ts
```

## Comandos Storybook

```bash
pnpm --filter @rotaviva/ui-components run storybook        # dev
pnpm --filter @rotaviva/ui-components run storybook:build  # build estático
```

## Checklist de PR

- [ ] Nenhum valor hardcoded em `.module.css` — só `var(--...)`.
- [ ] `forwardRef` + `cn()` no componente.
- [ ] Story com `tags: ['autodocs']`.
- [ ] Teste com `runA11y` cobrindo as variantes visualmente significativas.
- [ ] `typecheck`, `lint`, `test:ci`, `storybook:build` verdes.
- [ ] Sem Tailwind/Radix/CSS-in-JS introduzido.

## Anti-patterns

- Hex ou px direto em CSS Module em vez de token.
- SVG próprio do mark Rotaviva.
- `import 'lucide-react'` fora de `@rotaviva/icons`.
- Remover ou enfraquecer o `:focus-visible`.
- Assumir uma camada dark que não existe no handoff.
