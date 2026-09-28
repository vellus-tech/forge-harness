# Rotaviva — Design System
**Acessibilidade**

- **Versão:** 1.0.0
- **Data:** 2026-09-26
- **Status:** Rascunho
- **Referência pai:** docs/product/design-system/design-system.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 1.0.0 | 2026-09-26 | Atual | Primeira versão, gerada a partir do handoff `rotaviva-design-system` |

---

## Padrão

WCAG AA em todo o kit. **AAA em fluxos financeiros** (recarga, confirmação de valor) — Rotaviva movimenta saldo de transporte, então a tela de recarga (`RechargeScreen`) recebe o padrão mais alto: rótulos explícitos, `aria-describedby` no hint, `aria-invalid` no erro.

## Foco

Todo elemento interativo (`Button`, `Input`, itens de `ShortcutGrid`, links de `BottomNav`, botão de notificações do `AppHeader`) mantém `:focus-visible` com anel de 2px na cor de marca (`--brand`) e offset de 2px. **Nunca remover** — hard no do handoff (`project/SKILL.md`).

## Tooling

- **`jest-axe`** via o helper `test/axe.ts` (`runA11y`) — todo primitivo e bloco tem um teste rodando `runA11y` sobre as variantes visualmente significativas (ex.: as 4 variantes de `Button`, os 3 status de `Badge`/`TripRow`).
- **`@storybook/addon-a11y`** — roda no browser real, com `color-contrast` habilitado (`preview.tsx`).

### Caveat de contraste (jsdom vs. browser)

**jsdom não avalia contraste de cor.** `jest-axe` reporta a regra `color-contrast` como *incomplete*, nunca como falha — os testes unitários não pegam um contraste ruim. O contraste real só é verificado pelo `@storybook/addon-a11y` rodando num browser de verdade. Não trate um `test:ci` verde como prova de contraste suficiente.

## Cor de marca e contraste

`--brand` (`#0F9D8A`) sobre branco (`--n-0`) mede **~3.4:1** — decisão explícita do usuário no chat de design ("ok, aceito, só usa em CTA curto e ícone-ação"). Isso é suficiente para:

- Texto grande (≥18px regular ou ≥14px bold) e ícones — AA.
- CTAs curtos (ex.: "Recarregar" no `Button` primário) — a área do botão e o peso da fonte compensam.

**Não é suficiente** para texto corrido normal — nenhum bloco deste kit usa `--brand` para parágrafo ou label longo. Onde a cor de marca aparece em texto (ex.: aba ativa do `BottomNav`), o texto é curto (uma palavra) e semi-bold.

## Checklists por tipo

**Botões:** rótulo acessível (texto visível ou `aria-label`), estado `disabled` refletido no DOM, foco visível, alvo de toque ≥40px (o `sm` de `Button` fica em 40px de altura efetiva com padding).

**Campos:** `label` associado via `htmlFor`/`id`, hint via `aria-describedby`, erro via `aria-invalid` + hint com a mensagem (não só cor).

**Navegação:** `aria-current="page"` na aba ativa do `BottomNav`; `nav` com `aria-label` em `ShortcutGrid` e `BottomNav`.

**Listas:** `TripRow` como `<li>` dentro de `<ul>`/`<ol>` — nunca solto.

## Leitor de tela

- Ícones decorativos (sem `aria-label`) recebem `aria-hidden` automático via `Icon`.
- O botão de notificações do `AppHeader` tem `aria-label="Notificações"` (o ícone `Bell` sozinho não é anunciado).
- `RotavivaMark` usa `alt="Rotaviva"` por padrão — ajustável via prop quando decorativo dentro de um contexto que já anuncia a marca.
