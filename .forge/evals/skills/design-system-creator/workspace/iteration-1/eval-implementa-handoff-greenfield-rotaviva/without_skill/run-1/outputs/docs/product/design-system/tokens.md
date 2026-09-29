# Tokens

Fonte da verdade: `design-handoff/rotaviva-design-system/project/colors_and_type.css`. Espelhados em `packages/design-tokens/src/tokens.css` (CSS custom properties, uso direto) e `packages/design-tokens/src/index.ts` (mesmos valores tipados em TS).

## Cor

| Token | Valor | Uso |
|---|---|---|
| `--brand` | `#0F9D8A` | CTA primário, ícone-ação, item ativo de navegação. **Nunca** em texto corrido pequeno (ver `accessibility.md`). |
| `--brand-hover` / `--brand-press` | `#0C8575` / `#0A6E61` | Estados de interação do CTA primário. |
| `--brand-soft` | `#E3F5F2` | Fundo do botão secundário. |
| `--n-0` … `--n-900` | escala neutra fria (7 degraus) | Superfície, texto, bordas. |
| `--success` / `--warning` / `--danger` / `--info` | verde/âmbar/vermelho/azul | Badges de status de viagem, validação de campo. |

## Tipografia

Display `Sora` (600/700), UI `Manrope` (400/500/600), ambas via Google Fonts — sem self-host neste handoff. Escala: `--fs-12` a `--fs-28` (5 degraus).

## Espaçamento, raio, sombra, motion

Grade de 4 pt (`--s-1` a `--s-8`). Raios generosos (`--r-sm` 8px a `--r-lg` 20px, mais `--r-pill` para botões/badges). Duas sombras suaves (`--shadow-1`, `--shadow-2`). Motion: `--ease-out` + `--dur-fast`/`--dur-base` para transições de botão (`transform: scale(0.96)` no `:active`).

## Tema

Apenas claro — decisão explícita do usuário em `chats/chat1.md` ("nada de modo escuro por enquanto"). Nenhum token `data-theme="dark"` foi criado.
