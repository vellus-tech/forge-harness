# Design system — Rotaviva

| Campo | Valor |
|---|---|
| Versão | 0.1.0 |
| Data | 2026-09-26 |
| Status | Rascunho |

## Histórico de Versões

| Versão | Data | Autor | Mudança |
|---|---|---|---|
| 0.1.0 | 2026-09-26 | Agente de codificação | Primeira versão — pacotes `@rotaviva/icons` e `@rotaviva/ui-components` a partir do handoff, sobre os tokens já aprovados em `@rotaviva/design-tokens` v1.2.0 |

## Escopo desta entrega

Os tokens (`@rotaviva/design-tokens` v1.2.0) já estavam completos e aprovados neste repositório — ver
`docs/product/design-system/tokens.md` — e não foram alterados. Esta entrega cobre o que faltava:
ícones e componentes React derivados do handoff em `design-handoff/rotaviva-design-system/`.

## Pacotes

| Pacote | Conteúdo |
|---|---|
| `@rotaviva/design-tokens` | Tokens de marca, neutros, tipografia, espaçamento, raios, sombras e motion (já existente). |
| `@rotaviva/icons` | Ícones inline SVG usados pelos blocos: `Bell`, `Wallet`, `CreditCard`, `CircleHelp`, `Bus`. |
| `@rotaviva/ui-components` | Primitivos (`Button`, `Input`, `Badge`, `Card`), blocos (`AppHeader`, `BalanceCard`, `TripRow`, `ShortcutGrid`, `BottomNav`) e telas (`HomeScreen`, `RechargeScreen`). |

## Marca e voz

Cor de marca verde-petróleo `--brand` (`#0F9D8A`), decidida no handoff após descartar um roxo inicial
(`#7A3CF0`) por parecer "banco digital genérico" — ver `design-handoff/rotaviva-design-system/chats/chat1.md`.
Tipografia display Sora, UI Manrope. Tema claro apenas nesta versão — dark mode foi explicitamente
recusado no handoff.

Voz direta e próxima, sem jargão bancário: "Recarregar" (não "efetuar recarga"), "Suas viagens" (não
"histórico de transações"). Valores sempre com "R$" e vírgula decimal.

## Restrições herdadas do handoff (`project/SKILL.md`)

- Nunca redesenhar o símbolo Rotaviva em SVG — sempre os PNGs de `assets/brand/`.
- Nunca usar `--brand` em texto corrido pequeno (contraste ~3.4:1 sobre branco) — reservado a CTA
  curto e ícone-ação.
- Nunca remover o anel de foco (`:focus-visible`).

## Como consumir

```tsx
import '@rotaviva/design-tokens/css';
import '@rotaviva/ui-components/css';
import { HomeScreen, RechargeScreen } from '@rotaviva/ui-components';
```

Ver `docs/product/design-system/components.md` para a API de cada componente e
`docs/product/design-system/accessibility.md` para as decisões de acessibilidade.
