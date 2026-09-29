# Componentes — Rotaviva

| Campo | Valor |
|---|---|
| Versão | 0.1.0 |
| Data | 2026-09-26 |
| Status | Rascunho |

Pacote: `@rotaviva/ui-components`. CSS obrigatório: `import '@rotaviva/ui-components/css'` (importa
`@rotaviva/design-tokens/css` por baixo).

## Primitivos

### Button

`variant`: `primary | secondary | ghost | danger` (padrão `primary`). `size`: `md | sm` (padrão `md`).
Demais props herdam `<button>`. `primary` usa `--brand` como fundo — reservado para CTA curto.

### Input

Campo controlado com `label` (obrigatório), `hint` opcional e `error` opcional. Quando `error` é
passado, o input recebe `aria-invalid="true"` e a mensagem substitui o hint com `role="alert"`.

### Badge

`tone`: `success | warning | neutral` (padrão `neutral`). Usado para status curto (ex.: status de
viagem).

### Card

Contêiner com `eyebrow` opcional (rótulo pequeno em maiúsculas acima do conteúdo).

## Blocos

| Bloco | Props principais | Observação |
|---|---|---|
| `AppHeader` | `name`, `onNotificationsClick?` | Usa o PNG oficial da marca — nunca SVG redesenhado. |
| `BalanceCard` | `balance`, `passName`, `onRechargeClick?` | `Card` com CTA `Button` primary sm. |
| `TripRow` | `line`, `when`, `amount`, `status`, `statusLabel` | `status` mapeia direto para `Badge.tone`. |
| `ShortcutGrid` | `items: { key, icon, label, onClick? }[]` | Grade de 3 colunas. |
| `BottomNav` | `active`, `onNavigate?` | 4 abas fixas: Início, Viagens, Cartões, Perfil. |

## Telas

| Tela | Composição |
|---|---|
| `HomeScreen` | `AppHeader` + `BalanceCard` + `ShortcutGrid` + lista de `TripRow` + `BottomNav`. |
| `RechargeScreen` | `Input` de valor + `Button` de confirmação. |

Fluxo navegável do handoff: Início → Recarregar → Confirmação. A tela de confirmação (terceiro passo)
não estava no `ui_kits` do handoff — não foi inventada aqui; ver `## Pendências` abaixo.

## Ícones (`@rotaviva/icons`)

`Bell`, `Wallet`, `CreditCard`, `CircleHelp`, `Bus` — SVG inline, `stroke="currentColor"`, 24×24 por
padrão, prop `size` para outros tamanhos. Ícones decorativos ficam `aria-hidden`; quando usados como
único conteúdo de um botão (ex.: sino do `AppHeader`), o botão carrega `aria-label`.

## Pendências (fora do escopo desta rodada)

- Tela de confirmação de recarga (terceiro passo do fluxo) não veio no handoff — não implementada.
- Storybook/testes visuais dos componentes não foram configurados nesta rodada (fora do pedido original).
