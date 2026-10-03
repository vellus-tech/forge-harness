# Acessibilidade — Rotaviva

| Campo | Valor |
|---|---|
| Versão | 0.1.0 |
| Data | 2026-09-26 |
| Status | Rascunho |

## Contraste

- `--brand` (`#0F9D8A`) sobre branco mede ~3.4:1 — abaixo de 4.5:1 (AA para texto normal). O handoff
  restringe seu uso a CTA curto e ícone-ação (texto grande/bold ou elemento não textual, onde 3:1 já
  é aceitável). Os componentes seguem essa regra: `Button.primary` usa `--brand` como fundo (não como
  cor de texto sobre fundo claro), e nenhum bloco usa `--brand` em texto corrido.
- `--fg` (`#14202A`) sobre `--surface`/`--surface-muted` e `--n-0` sobre `--brand`/`--danger` não
  foram medidos numericamente nesta rodada — ficam como verificação pendente antes de produção.

## Foco

Todo elemento interativo (`.btn`, `.input`, itens de `ShortcutGrid`, links de `BottomNav`) mantém
`:focus-visible` com anel de 2px na cor `--brand` — nunca removido, conforme
`design-handoff/rotaviva-design-system/project/SKILL.md`.

## Semântica e rótulos

- `AppHeader`: o botão de notificações não tem texto visível — carrega `aria-label="Notificações"`.
- `Input`: erro liga `aria-invalid="true"` e associa a mensagem via `aria-describedby` com
  `role="alert"`; hint (quando não há erro) também é associado por `aria-describedby`.
- `BottomNav`: aba ativa marcada com `aria-current="page"`.
- `ShortcutGrid`/`TripRow`: ícones são puramente decorativos (`aria-hidden`); o rótulo textual ao lado
  carrega o significado.

## Tipografia e toque

- Tamanhos de fonte em `px` fixos (herdados dos tokens) — não foi verificado reflow com zoom de texto
  do navegador (200%) nesta rodada.
- Altura mínima de alvo de toque: `.input` tem 48px; `.btn` (tamanho padrão) não foi medido contra o
  mínimo de 44×44px recomendado — verificação pendente.

## Pendências

Este documento registra o que foi aplicado nos componentes desta rodada, não uma auditoria WCAG
completa. Uma auditoria com medição de contraste real (ferramenta dedicada) e teste de leitor de tela
fica como próximo passo antes de considerar o design system pronto para produção.
