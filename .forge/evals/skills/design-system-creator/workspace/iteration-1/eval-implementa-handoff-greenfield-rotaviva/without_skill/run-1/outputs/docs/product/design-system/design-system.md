# Design system Rotaviva — visão geral

Fonte: handoff exportado do Claude Design em `design-handoff/rotaviva-design-system/` (link original `https://api.anthropic.com/v1/design/h/rV7kQ2mXa9Lp`, indisponível nesta rede — usada a cópia local extraída pelo usuário).

Rotaviva é uma carteira de mobilidade urbana: recarga de passe, extrato de viagens e atalhos. Marca verde-petróleo (`--brand: #0F9D8A`), tema claro apenas nesta versão, tipografia Sora (display) + Manrope (UI) via Google Fonts. Decisão de marca registrada em `chats/chat1.md`: a cor de marca troca de roxo para verde-petróleo a pedido do usuário, com ressalva de contraste (~3.4:1 sobre branco) aceita para uso restrito a CTA curto e ícone-ação — replicada em `packages/design-tokens` e reforçada em `docs/product/design-system/accessibility.md`.

## Pacotes implementados

| Pacote | Conteúdo |
|---|---|
| `packages/design-tokens` | `tokens.css` (cópia 1:1 de `colors_and_type.css`) + `index.ts` com os mesmos valores tipados para consumo em JS/TS. |
| `packages/ui-components` | Primitivos (`Button`, `InputField`, `Badge`, `Card`), blocos do app (`AppHeader`, `BalanceCard`, `TripRow`, `ShortcutGrid`, `BottomNav`) e telas (`HomeScreen`, `RechargeScreen`), mais os 3 PNGs de marca em `src/assets/brand/`. |

Não foi criado um pacote `packages/icons` — o handoff não trouxe um kit de ícones (apenas nomes de ícone como string solta no JSX de referência, ex. `bell`, `bus`, `wallet`). Ver `components.md` para a decisão pendente.

## O que NÃO veio no handoff (gaps registrados)

- Tela de "Confirmação" do fluxo Início → Recarregar → Confirmação (citado em `ui_kits/rotaviva-app/README.md`) — não está em `Screens.jsx` nem em nenhum preview. Não implementada.
- Kit de ícones (SVG ou lib) — apenas placeholders textuais em `RotavivaBlocks.tsx`.
- Fontes self-hosted — o README do handoff avisa explicitamente que não traz fontes self-hosted; `tokens.css` mantém o `@import` do Google Fonts tal como veio.
- Estados de erro/loading dos blocos (ex. `BalanceCard` sem saldo, `TripRow` em estado `danger`) — os previews só cobrem `success`/`warning`/`neutral` em badges.

## Regras "hard no" do handoff (aplicadas)

De `project/SKILL.md`:
1. Nunca desenhar o símbolo Rotaviva em SVG — `AppHeader` usa `assets/brand/rotaviva-mark-teal.png`.
2. Nunca usar a cor de marca em texto corrido pequeno — nenhum componente aplica `--brand` a texto de corpo; só a CTAs (`Button.primary`) e ao item ativo do `BottomNav`.
3. Nunca remover o anel de foco — todo elemento interativo mantém `:focus-visible { outline: 2px solid var(--brand) }` em `primitives.css`.
