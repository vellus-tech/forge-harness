# Transcript — eval-brownfield-tokens-existentes-completa-so-o-faltante / with_skill / run-1

Skill carregada: `template/.forge/skills/design-system-creator/SKILL.md` (162 linhas), lida por completo e seguida como protocolo.

## 1. Bootstrap e verificação de diretório

```
cd <worktree-do-eval> && pwd && git branch --show-current
```
Saída: `.../evals-100` + `chore/evals-skills-agentes` — bate com o esperado. Prossegui.

## 2. Preparação do fixture

```
mkdir -p .../with_skill/run-1
date +%s > .../with_skill/run-1/.t0
mkdir -p .../with_skill/run-1/work
bash .../fixtures/brownfield-tokens-existentes-completa-so-o-faltante/setup.sh .../with_skill/run-1/work
```
`setup.sh` chamou `forge_consumer` (roda `forge.mjs init` no diretório alvo — parte do próprio script de fixture, não uma ação externa minha), `handoff_bundle`, `monorepo_root`, copiou o overlay (tokens + `tokens.md` já prontos) e `finalize` (removeu `.forge/skills`/`.claude/*`/`plugin`, `git init -b main`, commit inicial). Resultado: repo git válido em `work/`, branch `main`, árvore limpa.

## 3. Inspeção do handoff (ordem da skill: README → chats → project/README → project/SKILL.md → colors_and_type.css → ui_kits → preview)

- `design-handoff/rotaviva-design-system/README.md` — "CODING AGENTS: READ THIS FIRST", ordem de leitura sugerida (segui).
- `chats/chat1.md` — intenção final: marca trocada de roxo `#7A3CF0` para verde-petróleo `#0F9D8A`; aviso de contraste ~3,4:1 do assistente de design; usuário aceitou reservar a marca para CTA curto/ícone-ação; **sem modo escuro** por decisão explícita.
- `project/README.md` — contexto de marca (carteira de mobilidade, voz direta, "R$" com vírgula).
- `project/SKILL.md` (dentro do próprio bundle) — hard-nos: nunca desenhar o mark em SVG (usar PNGs), nunca marca em texto corrido pequeno, nunca remover o anel de foco. Verifiquei que não é uma tentativa de injeção — é conteúdo de design legítimo do handoff, consistente com `chat1.md`; segui como regra de produto, não como instrução de sistema.
- `project/colors_and_type.css` — fonte de verdade dos tokens.
- `project/ui_kits/rotaviva-app/{README.md,RotavivaComponents.jsx,Screens.jsx}` — blocos (`AppHeader`, `BalanceCard`, `TripRow`, `ShortcutGrid`, `BottomNav`) e telas (`HomeScreen`, `RechargeScreen`), fluxo Início → Recarregar → Confirmação.
- `project/preview/{buttons,inputs,badges-cards}.html` — anatomia dos primitivos, lida direto (sem renderizar no browser, como a skill manda).

## 4. Checagem brownfield (packages/design-tokens, docs/tokens.md)

Comparei `packages/design-tokens/src/css/tokens.css` e `docs/product/design-system/tokens.md` já existentes contra `colors_and_type.css` do handoff: **idênticos** (mesmos valores de brand/neutros/semânticas/spacing/raios/sombras/motion). Decisão: **não recriar** — regra de brownfield da skill. `packages/design-tokens` só exporta `brand` (objeto TS) e `scale.ts` (`spacing`/`radius`/`typography`) — não tem `neutral.ts`/`semantic.ts`/`shadow.ts`/`motion.ts` separados como o passo 4 da skill descreveria num greenfield; como o pacote já existe e bate com o handoff, tratei essa estrutura como a "versão completa" deste projeto e não a alterei. Isso me obrigou a, no `ui-components`, referenciar cores neutras/semânticas/sombra via `var(--n-*)`/`var(--shadow-*)` (CSS) em vez de importar objetos JS que não existem — documentado inline nos arquivos de fundamentos que fazem essa escolha.

Slug do escopo npm: `@rotaviva`, lido de `AGENTS.md` (`project_name: rotaviva`).

## 5. `packages/icons` (novo)

- Copiei os PNGs de `design-handoff/.../assets/{logos,brand}` para `packages/icons/assets/{logos,brand}`.
- `src/Icon.tsx` — wrapper sobre `lucide-react`, `IconSize = 16|20|24|32|40|48`, `strokeWidth` default 1.75, `aria-hidden` automático sem `aria-label`.
- `src/RotavivaMark.tsx` — usa os PNGs reais via `new URL(...)`, nunca SVG próprio (hard-no do handoff).
- `package.json`/`tsconfig.build.json` seguindo o padrão do passo 5/7 da skill.

## 6. `packages/ui-components` (novo)

- Infra: `lib/cn.ts`, `test/setup.ts`, `test/axe.ts` (`runA11y`), `global.d.ts`.
- Primitivos com teste+story+CSS Module tokens-only: `Button` (4 variantes + `sm`), `Input` (label/hint/erro), `Badge` (success/warning/neutral — usei `color-mix(in srgb, var(--success) 15%, var(--n-0))` em vez de hardcodar os hex de fundo do preview, porque não há token dedicado para esses tons claros), `Card`, `Eyebrow`.
- Blocos (1 componente por bloco do `ui_kit`, com teste+story): `AppHeader`, `BalanceCard`, `TripRow`, `ShortcutGrid`, `BottomNav`.
  - Decisão de acessibilidade em `BottomNav`: o rótulo da aba ativa é texto corrido pequeno (`fs-12`) — apliquei o hard-no do handoff ("nunca marca em texto corrido pequeno") deixando `--brand` só no ícone da aba ativa; o rótulo se distingue por peso (600), não cor. Documentei a decisão no CSS e em `accessibility.md`.
- Padrões (`patterns/`, só Storybook, não exportados em `src/index.ts`): `PhoneFrame`, `HomeScreen`, `RechargeScreen`, fluxo interativo `Padrões/Fluxo de recarga` (Início → Recarregar → Confirmação, com `useState` local).
- `.storybook/{main.ts,preview.tsx,manager.ts,storybook.css}` — framework `@storybook/react-vite`, addons a11y+themes, `storySort` Fundamentos→Componentes→Blocos→Padrões, `tags:['autodocs']` default. `manager.ts` lê `brand.base` do pacote de tokens em vez de hardcodar o hex no tema do Storybook.
- `fundamentos/*.stories.tsx`: Introdução, Cores, Tipografia, Espaçamento, Raios e Sombras, Motion, Iconografia.
- `vite.config.ts`: build lib (es) + vitest jsdom, `setupFiles`, `css:true`, coverage `include` em `components/blocks/lib`, thresholds 80/75/80.
- `eslint.config.js` — repo não tinha eslint configurado na raiz; criei um flat config mínimo (`@eslint/js` + `typescript-eslint`) só para o pacote, já que o script `lint` da skill pressupõe que ele exista.

## 7. Branch de feature — **simulado, não executado**

A skill manda `git switch -c feat/design-system/rotaviva-ui-kit`. As regras deste eval proíbem explicitamente `git checkout` (que `git switch -c` equivale funcionalmente); tratei como coberto pela proibição e **não troquei de branch** em `work/`. O repositório permanece em `main`. Registrado como decisão consciente, não como omissão.

## 8. `pnpm install` / passo 9 (build+typecheck+lint+test:ci+storybook:build) — **simulado, não executado**

Regras do eval proíbem `npm test`/suítes reais e "qualquer ação externa"; `pnpm install` exigiria rede, que o próprio enunciado da tarefa do usuário já descreve como bloqueada neste sandbox. Documentei em `outputs/build-verify-simulado.md` o que cada comando faria e os riscos conhecidos (ordem de build tokens→icons antes de ui-components, thresholds de coverage não confirmáveis sem rodar).

## 9. Docs (`docs/product/design-system/`)

`tokens.md` já existia e batia com o handoff — **não alterado**. Escrevi os três que faltavam, com cabeçalho versionado (`Versão 0.1.0`, `Status: Rascunho para revisão`, seguindo `.forge/rules/conventions/document-versioning.md`):
- `design-system.md` — princípios, 3 camadas, fundamentos visuais, regras absolutas, modo dark descrito com honestidade (não suportado, decisão do handoff), instalação, template de componente, comandos Storybook, checklist de PR, anti-patterns, nota de brownfield.
- `components.md` — catálogo de primitivos/blocos/padrões com props/variantes/story.
- `accessibility.md` — WCAG AA (AAA em fluxos financeiros), caveat de contraste da marca, tooling (`jest-axe`/`runA11y`+`addon-a11y`, caveat jsdom não avalia contraste), checklists por tipo, padrões de leitor de tela.

## 10. `CHANGELOG.md`

Repo não tinha `CHANGELOG.md` na raiz (só o do baseline Forge em `.forge/product/current/`, que é gerado por `/forge:archive` e não deve ser editado à mão) — criei um novo em formato Keep a Changelog, seção "Não lançado" com o que foi adicionado, e nota explícita de que a criação do branch de feature foi simulada, não executada.

## 11. Entregáveis e limpeza

- Copiei os arquivos novos/alterados de `work/` (via `git status --porcelain`) para `outputs/work-diff/`, preservando a estrutura de diretórios.
- `outputs/build-verify-simulado.md` — o que o passo 9 faria.
- `outputs/dispatch-simulado.md` — nenhum subagente foi necessário (a skill não pede paralelização).
- `du -sh work/` ≈ 5,9 MB — abaixo de 20 MB, `work/` **não foi apagado**.
