# Rotaviva — Design System
**Catálogo de Componentes**

- **Versão:** 1.0.0
- **Data:** 2026-09-26
- **Status:** Rascunho
- **Referência pai:** docs/product/design-system/design-system.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 1.0.0 | 2026-09-26 | Atual | Primeira versão, gerada a partir do handoff `rotaviva-design-system` |

---

## Primitivos (`components/`)

| Componente | Props principais | Variantes | Story |
|---|---|---|---|
| `Button` | `variant`, `size`, todos os atributos de `<button>` | `primary` \| `secondary` \| `ghost` \| `danger`; `md` \| `sm` | Componentes/Button |
| `Input` | `label` (obrigatório), `hint`, `invalid` | default, inválido | Componentes/Input |
| `Badge` | `status` | `success` \| `warning` \| `neutral` | Componentes/Badge |
| `Card` | atributos de `<div>` | — | Componentes/Card |
| `Eyebrow` | atributos de `<span>` | — | Componentes/Eyebrow |

## Blocos (`blocks/`) — do ui_kit `rotaviva-app`

| Bloco | Props | Composição | Story |
|---|---|---|---|
| `AppHeader` | `name`, `onNotificationsClick` | `RotavivaMark` + botão de notificações (`Bell`) | Blocos/AppHeader |
| `BalanceCard` | `balance`, `passName`, `onRecharge` | `Card` + `Eyebrow` + `Button` | Blocos/BalanceCard |
| `TripRow` | `line`, `when`, `amount`, `status` | `Icon(Bus)` + `Badge` | Blocos/TripRow |
| `ShortcutGrid` | `items: { icon, label, onClick }[]` | grade de botões com `Icon` | Blocos/ShortcutGrid |
| `BottomNav` | `active`, `onNavigate` | 4 abas fixas (Início/Viagens/Cartões/Perfil) | Blocos/BottomNav |

## Padrões (`patterns/` — só Storybook, fora da API pública)

| Padrão | Descrição |
|---|---|
| `PhoneFrame` | Moldura leve de telefone (375×720, `--shadow-2`) usada para ambientar as telas |
| `HomeScreen` | Header + saldo + atalhos + últimas viagens + nav inferior |
| `RechargeScreen` | Título + campo de valor + botão de confirmação |
| Fluxo de recarga | Composição interativa Início → Recarregar → Confirmação (story `Padrões/Fluxo de recarga`) |

## Ícones

`@rotaviva/icons` reexporta `Icon` (wrapper de `lucide-react`, `IconSize = 16\|20\|24\|32\|40\|48`) e `RotavivaMark` (PNG real, variantes `teal`/`black`/`white`). Ícones usados nos blocos: `Bell`, `Wallet`, `CreditCard`, `CircleHelp`, `Bus` — todos confirmados como exports válidos de `lucide-react`.
