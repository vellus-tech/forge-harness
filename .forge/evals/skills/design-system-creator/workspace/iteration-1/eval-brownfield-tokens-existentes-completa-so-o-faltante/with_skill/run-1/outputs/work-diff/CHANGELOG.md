# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).

## [Não lançado]

### Adicionado

- `packages/icons` (`@rotaviva/icons`): wrapper `Icon` sobre `lucide-react` (escala 4-pt: 16/20/24/32/40/48) e `RotavivaMark` (X/mark via PNG real, variantes teal/black/white).
- `packages/ui-components` (`@rotaviva/ui-components`): primitivos `Button`, `Input`, `Badge`, `Card`, `Eyebrow`; blocos `AppHeader`, `BalanceCard`, `TripRow`, `ShortcutGrid`, `BottomNav`; padrões de tela `HomeScreen`/`RechargeScreen` + fluxo navegável de recarga (Storybook, categoria Padrões, não exportados na API pública); Storybook (`@storybook/react-vite` + `addon-a11y` + `addon-themes`) e stories de Fundamentos (Introdução, Cores, Tipografia, Espaçamento, Raios e Sombras, Motion, Iconografia).
- `docs/product/design-system/{design-system,components,accessibility}.md` — `tokens.md` já existia e não foi alterado (bate com o handoff).

### Observações

- `packages/design-tokens` (tokens, fontes) **já existia e já batia com o handoff** — não foi recriado nesta rodada (brownfield-safe).
- Branch de feature recomendado pela skill: `feat/design-system/rotaviva-ui-kit`. Neste ambiente de eval a criação de branch (`git switch -c`) foi **simulada, não executada** (regra do harness proíbe `git checkout`/mudança de branch aqui) — ver `outputs/transcript.md`. O repositório permanece em `main` neste workspace descartável.
