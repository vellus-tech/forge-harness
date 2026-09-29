# Acessibilidade

## Contraste da cor de marca (achado do próprio handoff)

O assistente que gerou o handoff já sinalizou, em `chats/chat1.md`, que `--brand` (`#0F9D8A`) sobre branco tem contraste ~3.4:1 — abaixo de 4.5:1 (WCAG 2.1 AA para texto normal), mas acima de 3:1 (AA para texto grande ≥18pt/14pt-bold e para componentes gráficos/UI). O usuário aceitou a cor com a restrição "só em CTA curto e ícone-ação". Nesta implementação:

- `Button.primary` usa `--brand` como fundo com texto branco (`--n-0`) — é um componente de UI (botão), não texto corrido, então cai na exceção de 3:1; ainda assim, o par fundo-verde/texto-branco deveria ser medido à parte (contraste de texto sobre o próprio botão, não do brand sobre branco) antes de produção — não foi possível medir aqui (ver seção de verificação).
- Nenhum componente usa `--brand` como cor de texto corrido sobre fundo branco.
- `BottomNav` usa `--brand` apenas para o texto do item ativo, que é curto (uma palavra) — dentro do limite aceito pelo usuário, mas vale confirmar com um teste de contraste real antes de shippar.

## Foco visível

Regra "hard no" do `project/SKILL.md": nunca remover o anel de foco. Todo elemento interativo (`.btn`, `.input`, botões de atalho, itens de `BottomNav`) mantém `:focus-visible { outline: 2px solid var(--brand); outline-offset: 2px }` em `primitives.css`/`blocks.css`. Note que o próprio anel de foco usa `--brand` como cor de contorno (não como texto), o que é o uso pretendido pela ressalva do usuário.

## Semântica e rótulos

- `AppHeader`: botão de notificação com `aria-label="Notificações"` (o ícone sozinho não é texto acessível).
- `InputField`: `label` associado por `htmlFor`/`id`, hint como texto irmão (não teria leitura garantida por screen reader sem `aria-describedby` — **gap**: não foi adicionado `aria-describedby` ligando o hint ao input; considerar antes de produção).
- `BottomNav`: `aria-current="page"` no item ativo; `TripRow`/`ShortcutGrid` sem `role` especial, pois usam elementos nativos (`li`, `button`).
- Imagem de marca (`AppHeader`) com `alt="Rotaviva"` — decorativa o suficiente para não precisar de `alt=""`, já que é o único indicador visual da marca no header.

## O que não foi verificado

Não há ferramenta de contraste automatizada disponível neste ambiente (sem rede, sem `pnpm install` executado — ver `outputs/transcript.md` para o porquê). Os números de contraste citados acima vêm do que o próprio transcript do handoff já registrou, não de medição nova.
