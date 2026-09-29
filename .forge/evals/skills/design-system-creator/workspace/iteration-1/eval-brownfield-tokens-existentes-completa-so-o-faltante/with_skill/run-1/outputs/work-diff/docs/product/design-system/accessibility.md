# Acessibilidade — Rotaviva

| Campo | Valor |
|---|---|
| Versão | 0.1.0 |
| Data | 2026-09-26 |
| Status | Rascunho para revisão |

## Histórico de Versões

| Versão | Data | Autor | Mudança |
|---|---|---|---|
| 0.1.0 | 2026-09-26 | design-system-creator (agente) | Primeira versão |

## Padrão alvo

**WCAG 2.1 AA** em todo o kit; **AAA** nos fluxos financeiros (recarga, extrato, saldo) — a Rotaviva move dinheiro do passageiro, então os fluxos de maior risco recebem o padrão mais alto quando praticável (contraste de texto, alvo de toque, mensagens de erro claras).

## Caveat de contraste — cor de marca

`--brand` (#0F9D8A) sobre `--n-0` (branco) mede **≈ 3,3–3,4:1** — abaixo do mínimo AA de 4,5:1 para texto normal, mas acima do mínimo de 3:1 para texto grande (≥24px ou ≥18,7px bold), ícones e elementos gráficos. Decisão registrada na conversa de handoff (`chats/chat1.md`): usar a marca **só em CTAs curtos e ícones-ação**, nunca em texto corrido pequeno.

Aplicação no kit:
- `Button` primary usa `--brand` como fundo com texto `--n-0` — passa (fundo sólido, não é o caso de texto-sobre-branco).
- `BottomNav`: o rótulo da aba ativa (`fs-12`, texto corrido pequeno) usa peso 600 em `--fg`, **não** `--brand` — só o ícone recebe a cor de marca. Ver comentário em `blocks/BottomNav/BottomNav.module.css`.
- Qualquer novo uso de `--brand` em texto deve ser ≥ `--fs-20` (20px) ou ir para ícone/CTA, nunca parágrafo ou label pequena.

## Tooling

- **`jest-axe`** (`runA11y` em `test/axe.ts`) roda em todo teste de primitivo/bloco (`*.test.tsx`).
- **`@storybook/addon-a11y`** roda no browser real do Storybook — é a fonte confiável para `color-contrast`, porque **jsdom não avalia contraste**: `jest-axe` reporta essa regra como `incomplete` (não falha os testes de unidade). Qualquer decisão de contraste deve ser validada no addon, não só no CI de unit test.
- Coverage gates do `vitest` (linha 80% / branch 75% / funções 80%) cobrem `components/`, `blocks/` e `lib/`.

## Checklists por tipo

**Botões e controles interativos**
- [ ] Anel de foco visível (`outline: 2px solid var(--brand); outline-offset: 2px`), nunca removido.
- [ ] Alvo de toque ≥ 40×40px (blocos usam `size sm` só quando o contexto já garante espaçamento).
- [ ] Estado `disabled` comunicado visualmente (opacidade) e via atributo nativo (não só CSS).

**Formulários (`Input`)**
- [ ] `label` associado via `htmlFor`/`id` (nunca placeholder como único label).
- [ ] Erro comunicado via `aria-invalid="true"` + `aria-describedby` apontando para a mensagem, não só cor.
- [ ] Hint/erro nunca é a única pista — o campo problemático também muda de borda (`--danger`).

**Ícones (`Icon`, `@rotaviva/icons`)**
- [ ] Ícone puramente decorativo: `aria-hidden` (automático quando não há `aria-label`).
- [ ] Ícone que é o único conteúdo de um controle (ex.: botão de notificações): `aria-label` obrigatório no elemento interativo pai.

**Navegação (`BottomNav`)**
- [ ] Aba ativa marcada com `aria-current="page"`.
- [ ] Estado ativo comunicado por mais que cor (peso da fonte + `aria-current`).

## Leitor de tela — padrões do kit

- Botões-ícone (`AppHeader` notificações, itens do `ShortcutGrid`) sempre com `aria-label` textual em pt-BR ("Notificações", não "bell").
- `TripRow` usa `Icon` com `aria-label="Linha {n}"` no ícone de ônibus, já que ele carrega informação (não é puramente decorativo).
- Nenhum uso de `aria-hidden` em conteúdo que carrega informação — só em glifos redundantes com texto visível adjacente.
