# Despacho de subagentes — NÃO executado (regra da task)

A regra de execução deste run proíbe spawnar subagentes reais. Nenhum agente listado abaixo foi
efetivamente invocado; a implementação inteira (tokens, primitivos, blocos, telas, docs) foi feita
diretamente por este agente, sequencialmente. O que seguiria é o que um orquestrador real
despacharia se pudesse paralelizar este trabalho:

1. **agente:** `design-tokens-builder` — **modelo:** haiku — **prompt resumido:** ler
   `project/colors_and_type.css` + `chats/chat1.md`, gerar `packages/design-tokens` (CSS + TS)
   com a ressalva de contraste do brand documentada.
2. **agente:** `ui-primitives-builder` — **modelo:** haiku — **prompt resumido:** portar os 3
   `preview/*.html` para `Button`/`InputField`/`Badge`/`Card` em React, mantendo classes e valores
   idênticos aos tokens, preservando `:focus-visible`.
3. **agente:** `ui-blocks-builder` — **modelo:** sonnet — **prompt resumido:** portar
   `RotavivaComponents.jsx`/`Screens.jsx` (anatomia de referência) para componentes de produção
   compostos a partir dos primitivos do passo 2; sinalizar gaps (ícones, tela de confirmação
   ausente).
4. **agente:** `design-docs-writer` — **modelo:** haiku — **prompt resumido:** gerar
   `docs/product/design-system/{design-system,tokens,components,accessibility}.md` a partir do que
   os passos 1–3 produziram + achados do handoff (contraste, hard-nos do `SKILL.md`).
5. **agente:** `design-review` — **modelo:** opus (effort medium) — **prompt resumido:** revisão
   crítica cruzando os 4 artefatos acima contra o handoff bruto — achar regra "hard no" violada,
   token inventado sem fonte no CSS, ou componente que diverge do preview sem justificativa
   registrada.

Este agente único absorveu os papéis 1–4 em sequência (sem paralelismo real, já que roda numa
única sessão sem tooling de spawn liberado) e fez uma auto-checagem equivalente ao papel 5 na
seção final do `transcript.md`.
