# Rotaviva — Design System
**Tokens**

- **Versão:** 1.0.0
- **Data:** 2026-09-26
- **Status:** Rascunho
- **Referência pai:** docs/product/design-system/design-system.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 1.0.0 | 2026-09-26 | Atual | Primeira versão, gerada a partir do handoff `rotaviva-design-system` |

---

> Espelho legível de `packages/design-tokens/src/css/tokens.css`. **O pacote vence em caso de divergência** — este documento existe para leitura humana, não é a fonte de verdade.

## Marca (brand)

| Token | Valor | Uso |
|---|---|---|
| `--brand` | `#0F9D8A` | CTAs curtos, ícones-ação. **Não usar em texto corrido pequeno** — contraste ~3.4:1 sobre branco (decisão registrada no chat de design). |
| `--brand-hover` | `#0C8575` | Hover de elementos com `--brand` |
| `--brand-press` | `#0A6E61` | Estado pressionado |
| `--brand-soft` | `#E3F5F2` | Fundo do botão secundário |

## Neutros

| Token | Valor |
|---|---|
| `--n-0` | `#FFFFFF` |
| `--n-50` | `#F6F8F9` |
| `--n-100` | `#EDF1F3` |
| `--n-300` | `#C5CED4` |
| `--n-500` | `#7A8791` |
| `--n-700` | `#3E4A53` |
| `--n-900` | `#14202A` |

## Semânticas

| Token | Valor | Papel |
|---|---|---|
| `--success` | `#1E8E3E` | Viagem aprovada |
| `--warning` | `#B26A00` | Viagem pendente |
| `--danger` | `#C62828` | Erro, bloqueio de cartão |
| `--info` | `#1565C0` | Informativo |

## Superfície / texto

| Token | Valor derivado |
|---|---|
| `--surface` | `var(--n-0)` |
| `--surface-muted` | `var(--n-50)` |
| `--fg` | `var(--n-900)` |
| `--fg-muted` | `var(--n-500)` |

## Tipografia

- Display: `Sora` (600/700) — títulos, saldo, valores grandes.
- UI: `Manrope` (400/500/600) — copy, botões, labels.
- Ambas via Google Fonts (`@import` como primeira regra de `tokens.css`) — este handoff **não trouxe fontes self-hosted**.
- Escala: `--fs-12`, `--fs-14`, `--fs-16`, `--fs-20`, `--fs-28`.

## Espaçamento (grade 4 pt)

`--s-1` (4px) · `--s-2` (8px) · `--s-3` (12px) · `--s-4` (16px) · `--s-6` (24px) · `--s-8` (32px)

## Raios

`--r-sm` (8px) · `--r-md` (12px) · `--r-lg` (20px) · `--r-pill` (999px)

## Sombras

`--shadow-1` — cards em repouso. `--shadow-2` — elementos elevados (ex.: `PhoneFrame` no Storybook).

## Motion

`--ease-out` (`cubic-bezier(0.2, 0.8, 0.2, 1)`), `--dur-fast` (120ms — press de botão), `--dur-base` (200ms).

## Modo escuro

**Não existe.** O chat de design fechou explicitamente "nada de modo escuro por enquanto — só claro". Não há camada `[data-theme="dark"]` em `tokens.css`.
