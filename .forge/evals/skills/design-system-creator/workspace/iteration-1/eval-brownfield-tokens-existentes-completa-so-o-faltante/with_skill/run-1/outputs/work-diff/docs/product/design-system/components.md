# Componentes — Rotaviva

| Campo | Valor |
|---|---|
| Versão | 0.1.0 |
| Data | 2026-09-26 |
| Status | Rascunho para revisão |

## Histórico de Versões

| Versão | Data | Autor | Mudança |
|---|---|---|---|
| 0.1.0 | 2026-09-26 | design-system-creator (agente) | Catálogo inicial — primitivos, blocos e padrões |

## Primitivos (`packages/ui-components/src/components/`)

| Componente | Props principais | Variantes | Story |
|---|---|---|---|
| `Button` | `variant`, `size`, todos os atributos nativos de `<button>` | `primary`, `secondary`, `ghost`, `danger`; `size` `md`\|`sm` | `Componentes/Button` |
| `Input` | `label`, `hint`, `error`, atributos de `<input>` | com hint, com erro (`aria-invalid`) | `Componentes/Input` |
| `Badge` | `status` | `success`, `warning`, `neutral` | `Componentes/Badge` |
| `Card` | atributos de `<div>` | — (superfície base) | `Componentes/Card` |
| `Eyebrow` | atributos de `<span>` | — (rótulo uppercase) | `Componentes/Eyebrow` |

Todos: `forwardRef`, `cn()` (clsx), CSS Module tokens-only, `Componente.test.tsx` com RTL + `runA11y`.

## Blocos (`packages/ui-components/src/blocks/`) — do `ui_kit` do handoff

| Bloco | Origem no handoff | Composição | Story |
|---|---|---|---|
| `AppHeader` | `RotavivaComponents.jsx` → `AppHeader` | `RotavivaMark` + saudação + botão de notificações (`Icon`/Bell) | `Blocos/AppHeader` |
| `BalanceCard` | `RotavivaComponents.jsx` → `BalanceCard` | `Card` + `Eyebrow` + saldo + `Button` "Recarregar" | `Blocos/BalanceCard` |
| `TripRow` | `RotavivaComponents.jsx` → `TripRow` | `Icon` (ônibus) + linha/horário/valor + `Badge` de status | `Blocos/TripRow` |
| `ShortcutGrid` | `RotavivaComponents.jsx` → `ShortcutGrid` | grade de 3 colunas de botões com `Icon` | `Blocos/ShortcutGrid` |
| `BottomNav` | `RotavivaComponents.jsx` → `BottomNav` | nav de 4 abas, `aria-current="page"` na ativa | `Blocos/BottomNav` |

## Padrões (`packages/ui-components/src/patterns/`) — só Storybook, categoria "Padrões"

Composições das telas do `ui_kit` (`Screens.jsx`). **Não exportadas** em `src/index.ts` — não fazem parte da API pública do pacote.

| Padrão | Origem | Conteúdo |
|---|---|---|
| `HomeScreen` | `Screens.jsx` → `HomeScreen` | `AppHeader` + `BalanceCard` + `ShortcutGrid` + lista de `TripRow` + `BottomNav` |
| `RechargeScreen` | `Screens.jsx` → `RechargeScreen` | título + `Input` de valor + `Button` "Confirmar recarga" |
| Fluxo de recarga | — (composição do agente) | `PhoneFrame` + navegação interativa Início → Recarregar → Confirmação, story `Padrões/Fluxo de recarga` |

## Status

Todos os itens acima estão implementados como código-fonte nesta rodada. `typecheck`/`lint`/`test:ci`/`storybook:build` **não foram executados** neste ambiente de eval (rede bloqueada, instalação de dependências não realizada) — ver `outputs/build-verify-simulado.md` no workspace do eval para o que se espera de cada comando e por quê não rodaram aqui.
