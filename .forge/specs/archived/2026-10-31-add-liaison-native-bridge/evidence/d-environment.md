# Medição (d) — variáveis de ambiente do Claude Code no Bash do agente

Medido em 2026-10-30, Claude Code 2.1.314, no Bash de um subagente (general-purpose) da sessão do orquestrador. Usado pela recusa de `native allow|revoke|pin` em sessão de agente (REQ-12) e pela proibição de referência a variáveis de mensageria (REQ-01).

## Método

`env | cut -d= -f1 | grep -iE "claude|anthropic"` lista só os NOMES. A relação entre valores foi conferida por comparação de igualdade no próprio shell (`[ "$X" = "<valor esperado>" ] && echo ...`), imprimindo só o veredito; do token, só o comprimento. Nenhum valor foi impresso.

## Resultados

Nomes presentes: `CLAUDECODE`, `CLAUDE_CODE_SESSION_ID`, `CLAUDE_PID`, `CLAUDE_CODE_MESSAGING_TOKEN`, `CLAUDE_CODE_MESSAGING_SOCKET`, `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_CODE_CHILD_SESSION`, `CLAUDE_CODE_BRIDGE_SESSION_ID`, `CLAUDE_CODE_SESSION_ATTENDED`, `CLAUDE_CODE_EXECPATH`, `CLAUDE_EFFORT`, além de `ANTHROPIC_API_KEY` e `ANTHROPIC_DEFAULT_SONNET_MODEL`.

Relações conferidas por igualdade:

- `CLAUDE_CODE_SESSION_ID` no subagente é o id da sessão PAI (o subagente herda); é o transcript onde as mensagens nativas chegam, o que é o comportamento certo para `native check` e `send --via cross-session` rodados de dentro de um subagente.
- `CLAUDE_PID` é o pid da sessão pai, igual ao nome do arquivo `~/.claude/sessions/<pid>.json` dela.
- `CLAUDE_CODE_MESSAGING_SOCKET` é igual ao `messagingSocketPath` do registro da sessão pai.
- `CLAUDECODE` tem 1 caractere; `CLAUDE_CODE_MESSAGING_TOKEN` tem 32.

Consequências para o design: o par `CLAUDE_CODE_MESSAGING_SOCKET` + `CLAUDE_CODE_MESSAGING_TOKEN` dá ao agente tudo o que ele precisaria para falar com o socket sem passar pelo `SendMessage` (nota de convergência do gate); os marcadores de sessão podem ser removidos pelo próprio agente com `env -u`, por isso a recusa do CLI soma uma segunda camada (ancestralidade de processo) e continua sendo proteção contra liberação induzida, não fronteira. Os scripts do template não podem citar as duas variáveis de mensageria (REQ-01), então a lista de marcadores do REQ-12 usa `CLAUDECODE`, `CLAUDE_CODE_SESSION_ID`, `CLAUDE_PID` e `CLAUDE_CODE_ENTRYPOINT`.
