# Transcript — eval-brownfield-tokens-existentes-completa-so-o-faltante / without_skill / run-1

Modo: `without_skill` — nenhuma leitura de `template/.forge/skills`, `template/.forge/agents`,
`template/plugin` ou `.forge/evals`; execução com conhecimento próprio.

## 1. Bootstrap e preparação

1. `cd .../evals-100 && pwd && git branch --show-current` — confirmado `evals-100` /
   `chore/evals-skills-agentes`, conforme esperado.
2. `date +%s > run-1/.t0` — instante inicial gravado.
3. `mkdir -p run-1/work` e `bash fixtures/.../setup.sh run-1/work` — projeto brownfield materializado.

## 2. Reconhecimento do projeto (`work/`)

4. Inventário do topo do repo: monorepo pnpm (`pnpm-workspace.yaml`, `packages/*`), `AGENTS.md`
   gerado pelo Forge, `design-handoff/rotaviva-design-system/` com o bundle já extraído (rede
   bloqueada, conforme a tarefa do usuário).
5. Lidos, nessa ordem (seguindo a ordem sugerida pelo próprio README do handoff):
   - `design-handoff/rotaviva-design-system/README.md` — aponta ordem de leitura.
   - `chats/chat1.md` — transcript da decisão de marca: roxo `#7A3CF0` inicial → trocado para
     verde-petróleo `#0F9D8A` por parecer "banco digital genérico"; contraste ~3.4:1 sobre branco
     avisado pelo assistente e aceito pelo usuário só para CTA curto/ícone; **sem dark mode**.
   - `project/README.md` — contexto de marca/voz (Rotaviva = carteira de mobilidade urbana).
   - `project/SKILL.md` — "hard nos": nunca redesenhar o símbolo em SVG (usar sempre os PNGs),
     nunca `--brand` em texto corrido pequeno, nunca remover o anel de foco; cheat-sheet de voz.
   - `project/colors_and_type.css` — tokens completos (brand, neutros, semânticas, tipografia,
     espaçamento 4pt, raios, sombras, motion).
   - `project/preview/{buttons,inputs,badges-cards}.html` — anatomia CSS dos primitivos.
   - `project/ui_kits/rotaviva-app/{README,RotavivaComponents,Screens}.jsx` — blocos
     (`AppHeader`, `BalanceCard`, `TripRow`, `ShortcutGrid`, `BottomNav`) e telas (`HomeScreen`,
     `RechargeScreen`), fluxo Início → Recarregar → Confirmação.
6. Comparado o handoff com o que já existe no repo:
   - `packages/design-tokens/src/{tokens/brand.ts,tokens/scale.ts,css/tokens.css}` — **idênticos**
     ao handoff, `--brand #0F9D8A` etc.
   - `docs/product/design-system/tokens.md` — versão 1.2.0, **status Aprovado**, com histórico de
     versão datado (2026-09-10) e nota de que o pacote vence em divergência.
   - Conclusão: este é o cenário "brownfield — tokens existentes, completa só o faltante". Os
     tokens **não foram tocados**. Faltam: pacote de ícones, pacote de componentes UI e os docs de
     design-system/components/accessibility (tokens.md já existe).

## 3. Decisões de implementação

7. **Ícones (`packages/icons`)**: os blocos do handoff referenciam ícones por nome de string
   (`bell`, `wallet`, `credit-card`, `circle-help`, `bus`) sem trazer um set de ícones. Decidido
   implementar como SVG inline (`stroke="currentColor"`, 24×24, prop `size`), sem depender de uma
   lib externa não instalável neste sandbox (sem rede) — 5 componentes: `Bell`, `Wallet`,
   `CreditCard`, `CircleHelp`, `Bus`.
8. **UI components (`packages/ui-components`)**: espelhada a anatomia CSS dos `preview/*.html` em
   `src/css/components.css` (que importa `@rotaviva/design-tokens/css`), e portados os blocos/telas
   do `.jsx` de referência para TSX tipado, com acessibilidade adicionada onde o handoff só tinha
   anatomia visual: `aria-label` no botão de notificação sem texto, `aria-invalid` +
   `aria-describedby` + `role="alert"` no `Input` com erro, `aria-current="page"` na aba ativa do
   `BottomNav`, ícones decorativos `aria-hidden`.
9. **Marca**: `Button.primary` usa `--brand` como cor de **fundo**, nunca como cor de texto sobre
   fundo claro — respeitando a restrição de contraste do handoff. `AppHeader` usa `<img>` para o PNG
   da marca (nunca um SVG redesenhado do símbolo), conforme o "hard no" do `SKILL.md` do handoff.
10. **Não implementado**: tela de confirmação de recarga (3º passo do fluxo "Início → Recarregar →
    Confirmação") — não estava no `ui_kits` do handoff, então não foi inventada; registrada como
    pendência em `docs/.../components.md`.
11. **Build/install não executados**: sem rede no sandbox para `pnpm install`; os `package.json` e
    `tsconfig.build.json` foram escritos espelhando o padrão já usado por
    `packages/design-tokens` (mesmo `tsconfig` base, `exports` com `types`/`import`, CSS via
    subpath `./css`), mas a build real (`tsc`) fica pendente do ambiente que instalar as deps.
12. **Docs**: escritos `design-system.md`, `components.md`, `accessibility.md` em
    `docs/product/design-system/`, seguindo o mesmo formato de cabeçalho (tabela Versão/Data/Status
    + Histórico de Versões) já usado em `tokens.md`. `tokens.md` não foi alterado.

## 4. Arquivos criados

```
packages/icons/{package.json,tsconfig.build.json,src/{types.ts,Bell.tsx,Wallet.tsx,CreditCard.tsx,CircleHelp.tsx,Bus.tsx,index.ts}}
packages/ui-components/{package.json,tsconfig.build.json,src/{index.ts,css/components.css,primitives/{Button,Input,Badge,Card}.tsx,blocks/{AppHeader,BalanceCard,TripRow,ShortcutGrid,BottomNav}.tsx,screens/{HomeScreen,RechargeScreen}.tsx}}
docs/product/design-system/{design-system.md,components.md,accessibility.md}
```

Nenhum arquivo pré-existente foi modificado (tokens e docs de tokens permaneceram intocados, conforme
o cenário brownfield "só o faltante").

## 5. Subagentes

Nenhum subagente foi spawnado de verdade (proibido pelas regras deste run). O despacho que seria
feito, caso fosse permitido, está registrado em `outputs/subagent-dispatch.md`.

## 6. Encerramento

13. Entregáveis copiados de `work/` para `outputs/` (packages/icons, packages/ui-components,
    docs/product/design-system/{design-system,components,accessibility}.md).
14. `timing.json` escrito a partir de `.t0` e `date +%s` no encerramento.
15. Tamanho de `work/` verificado (~5,7 MB) — abaixo do limite de 20 MB, `work/` mantido.
