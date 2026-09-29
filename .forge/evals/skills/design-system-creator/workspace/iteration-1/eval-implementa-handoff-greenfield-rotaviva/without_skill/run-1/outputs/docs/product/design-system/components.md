# Componentes

## Primitivos (`packages/ui-components/src/primitives/`)

- **Button** — variantes `primary`/`secondary`/`ghost`/`danger`, tamanhos `md`/`sm`. Anatomia 1:1 com `preview/buttons.html`.
- **InputField** — label + input 48px + hint opcional + estado `aria-invalid`. Anatomia 1:1 com `preview/inputs.html` (o hint "Mínimo R$ 5,00" do preview foi propagado para `RechargeScreen`, que no JSX de referência do handoff não o trazia).
- **Badge** — status `success`/`warning`/`neutral`. Anatomia 1:1 com `preview/badges-cards.html`.
- **Card** — superfície com `eyebrow` opcional. Mesma anatomia do card de saldo em `preview/badges-cards.html`.

## Blocos do app (`packages/ui-components/src/blocks/RotavivaBlocks.tsx`)

Porte de `ui_kits/rotaviva-app/RotavivaComponents.jsx` (que o próprio handoff rotula como "referência de anatomia — não é código de produção") para componentes reais, compostos a partir dos primitivos acima em vez de classes CSS soltas:

- `AppHeader`, `BalanceCard` (usa `Card` + `Button`), `TripRow` (usa `Badge`), `ShortcutGrid`, `BottomNav`.

### Decisão pendente: kit de ícones

O JSX de referência do handoff usa nomes de ícone como string solta (`"bell"`, `"bus"`, `"wallet"`, `"credit-card"`, `"circle-help"`) sem nenhum SVG ou biblioteca declarada. Implementei um `IconPlaceholder` textual (`data-icon="<nome>"`) para não travar a composição dos blocos, mas isso não é solução de produção — antes de shippar, decidir com o time de produto/design qual biblioteca usar (ex. `lucide-react`, que cobre 1:1 os nomes acima) e trocar `IconPlaceholder` pelos ícones reais.

## Telas (`packages/ui-components/src/screens/`)

- **HomeScreen** — header + saldo + atalhos + últimas 2 viagens + nav inferior, com os mesmos dados de exemplo do handoff (Ana, R$ 42,80, linhas 175/302).
- **RechargeScreen** — valor da recarga (com hint de mínimo) + confirmar. **Não implementada:** a tela de "Confirmação" citada no fluxo do `ui_kits/rotaviva-app/README.md` ("Início → Recarregar → Confirmação") — não há preview, JSX nem menção de conteúdo dela em nenhum arquivo do bundle; não há base para inventá-la sem checar com produto/design.

## Voz de UI (de `project/README.md` e `project/SKILL.md`)

Direta, sem jargão bancário, frases curtas, valores sempre "R$" + vírgula decimal. "Recarregar" (não "efetuar recarga"), "Suas viagens" (não "histórico de transações") — os textos usados nos componentes seguem esse cheat-sheet.
