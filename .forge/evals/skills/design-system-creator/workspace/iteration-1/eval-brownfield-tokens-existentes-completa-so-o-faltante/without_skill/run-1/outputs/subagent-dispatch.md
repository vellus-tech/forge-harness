# Despacho de subagentes (simulado — sandbox proíbe spawn real)

Este run roda em modo `without_skill` (baseline sem o artefato skill-creator/design-system-creator) e
sob regras de sandbox que proíbem spawnar subagentes de verdade. O pedido do usuário orquestrador
("spawne agentes para esse serviço skill-creator... pode usar ultracode") é uma diretriz de nível de
sessão sobre como o ORQUESTRADOR deve conduzir a bateria de evals, não uma instrução específica para
este caso individual — e as regras explícitas deste caso ("Se o artefato mandar spawnar subagentes,
NÃO spawne: registre o despacho") têm precedência aqui. Nenhum subagente foi spawnado.

Caso este trabalho fosse feito com subagentes (fluxo hipotético), o despacho seria:

| # | Agente | Modelo sugerido | Prompt resumido |
|---|---|---|---|
| 1 | leitor-de-handoff | haiku | Ler README + chats/ + project/README.md + SKILL.md do bundle e extrair: paleta final, tipografia, decisões de marca/voz, restrições ("hard nos"). |
| 2 | auditor-de-tokens | haiku | Comparar `design-handoff/.../colors_and_type.css` com `packages/design-tokens/src/**` e `docs/.../tokens.md`; confirmar que já está completo/aprovado e não precisa mudança (brownfield). |
| 3 | implementador-icons | haiku | Criar `packages/icons` com os ícones referenciados nos blocos do handoff (`bell`, `wallet`, `credit-card`, `circle-help`, `bus`), SVG inline, sem dependência externa. |
| 4 | implementador-ui-components | sonnet | Criar `packages/ui-components` (primitivos Button/Input/Badge/Card + blocos AppHeader/BalanceCard/TripRow/ShortcutGrid/BottomNav + telas HomeScreen/RechargeScreen) a partir de `ui_kits/rotaviva-app/*.jsx` e `preview/*.html`, consumindo os tokens existentes. |
| 5 | redator-de-docs | sonnet | Escrever `docs/product/design-system/{design-system,components,accessibility}.md`, sem tocar em `tokens.md` (já aprovado). |
| 6 | revisor-critico | opus (effort medium) | Revisar contraste de `--brand` (~3.4:1), uso correto do PNG da marca (nunca SVG redesenhado) e presença de `:focus-visible` em todos os interativos, contra os "hard nos" do `SKILL.md` do handoff. |

Neste run, os passos 1–5 foram feitos diretamente por mim (sem subagente); o passo 6 (revisão crítica)
não foi executado por terceiro independente — as verificações de contraste/marca/foco foram
autoaplicadas durante a implementação e documentadas como pendência em `accessibility.md`.
