# Medição (a) — payload do PreToolUse de `SendMessage`

Medido em 2026-10-30 com Claude Code 2.1.314 (`claude --version`), macOS, a pedido do orquestrador do change `add-liaison-native-bridge` (REQ-04, REQ-05; itens 2, 3 e 7 do `design-inputs.md`).

## Método

Ambiente descartável em `<SCRATCH>/measure-sendmessage/`, fora de qualquer repositório git (`git rev-parse` falhou ali, conferido). Um `settings.json` de teste registrou um gancho `PreToolUse` com matcher `SendMessage` que grava o stdin em `captures/pre-<ts>.json` e SEMPRE sai com exit 2, e um `PostToolUse` com matcher `ListAgents` só de registro (exit 0). Execução headless, sem tocar a configuração do usuário:

```
claude -p '<roteiro>' --settings <SCRATCH>/settings.json --setting-sources "" --model sonnet \
  --allowedTools "SendMessage,ListAgents,Agent,ToolSearch" --output-format stream-json --verbose
```

`--setting-sources ""` impede o carregamento de settings de usuário, projeto e local; só o arquivo de teste vale. O aninhamento NÃO foi recusado: a sessão filha rodou com os marcadores herdados (`CLAUDECODE` etc.), sem precisar desligar nenhum. A ferramenta `SendMessage` estava disponível como ferramenta diferida (carregada por `ToolSearch`). Foram duas execuções: a primeira validou que o gancho dispara (caso 1); a segunda cobriu os demais casos. Destinos de sessão usados: só `forge-harness-23` (a sessão do orquestrador que pediu a medição) e o endereço `uds:` dela. Nenhuma outra sessão listada foi endereçada.

Prova de não entrega: todas as sete chamadas de `SendMessage` voltaram com `PreToolUse:SendMessage hook error: [...capture.sh]: measurement hook: SendMessage bloqueado de propósito (nada foi entregue)` no stream (`is_error: true`). O caso 6 (broadcast) foi recusado pelo próprio Claude Code antes do gancho.

Higienização: ids de sessão viram `<SESSION_ID>`, outros UUIDs `<UUID>`, `tool_use_id` vira `<TOOL_USE_ID>`, agentId vira `<AGENT_ID a+16hex>`, o ref do `ListAgents` vira `<REF 6hex>`, o pid no socket vira `<PID>`, o home vira `<HOME>` e o diretório de rascunho vira `<SCRATCH>`. Nomes de campo e valores estruturais foram mantidos.

## Resultados

| Caso pedido | `to` enviado | `recipient_kind` | Observação |
|---|---|---|---|
| 1 — subagente por nome | `probe-helper` | `name` | O `Agent` de 2.1.314 não tem parâmetro `name` (só `description`, `prompt`, `run_in_background`, `subagent_type`), então não existe subagente nomeado nesse modo; o nome é classificado como `name`, igual a um nome de sessão. |
| 1b — subagente por agentId | `<AGENT_ID>` (`a` + 16 hex) | `agent` | Forma que o `Agent` devolve no spawn. |
| 2 — `main` | `main` | `main` | Só chamado de dentro de subagente; o payload ganha `agent_id` e `agent_type` no topo, e `transcript_path` aponta para o transcript da sessão PAI. |
| 3 — sessão local por nome | `forge-harness-23` | `name` | Indistinguível do caso 1 pelo payload. |
| 3b — sessão por nome com ref | `forge-harness-23 [<REF>]` | `name` | O ref (6 hex) não deriva de `sessionId`, `bridgeSessionId` nem do socket (conferido por prefixo e por sha256 dos três): não há como mapear o ref ao registro local. |
| 4 — sessão por `uds:` | `uds:/tmp/cc-socks/<PID>.sock` | `session` | O parser do Claude Code reconhece a forma (classe `session`); a entrega por esse endereço não foi verificada, por desenho (o gancho bloqueou). |
| 5 — só `notify_when_idle` | `forge-harness-23` | `name` | Mesmo omitindo `message`, o payload traz `message: ""` e `content: ""` junto de `notify_when_idle: true`; não há `summary`. |
| 6 — vários destinos | `*` | — | Recusado pelo Claude Code antes do gancho: `broadcast (to: "*") is no longer supported — send a message per recipient`. Não existe forma de envio múltiplo em 2.1.314; o gancho nunca vê esse caso. |

Fatos que o design usa:

1. O `tool_input` que o gancho recebe é o normalizado pelo Claude Code, não o literal do modelo: além de `to`, `message`, `summary` e `notify_when_idle`, traz `type: "message"`, `recipient` (cópia de `to`), `recipient_kind` e `content` (cópia de `message`). O corpo aparece em dois campos.
2. `recipient_kind` tem quatro valores observados: `name`, `agent`, `main`, `session`. Só `agent` e `main` identificam destino interno com certeza; `name` cobre subagente nomeado, colega, sessão local, sessão remota e nuvem.
3. O payload não traz a lista de destinos do `ListAgents` nem a resolução que o Claude Code fará: quem classifica `name` é o gancho, pelo registro de sessões.
4. A documentação embutida da ferramenta (descrição do `SendMessage` em 2.1.314) afirma que um nome que também é de agente em processo é entregue ao agente em processo ("the bare name always wins"), e que um nome igual em várias sessões exige o ref. Isso é texto do fornecedor, não medição.
5. O `ListAgents` (capturado por `PostToolUse`) devolve `tool_response.listing`, texto livre com uma linha por sessão (`<nome> [<ref>] · <kind> · <status> · started <idade>`), sem `cwd` nem socket.

## Fixtures higienizadas

### caso 1 — subagente por nome (nome inexistente como agente nomeado; Agent sem parâmetro name em 2.1.314)

```json
{
  "session_id": "<SESSION_ID>",
  "transcript_path": "<HOME>/.claude/projects/<PROJECT_SLUG>/<SESSION_ID>.jsonl",
  "cwd": "<SCRATCH>/work",
  "prompt_id": "<UUID>",
  "permission_mode": "default",
  "effort": {
    "level": "high"
  },
  "hook_event_name": "PreToolUse",
  "tool_name": "SendMessage",
  "tool_input": {
    "to": "probe-helper",
    "summary": "measurement case 1",
    "message": "measurement case 1",
    "type": "message",
    "recipient": "probe-helper",
    "recipient_kind": "name",
    "content": "measurement case 1"
  },
  "tool_use_id": "<TOOL_USE_ID>"
}
```

### caso 2 — main, chamado por subagente em background

```json
{
  "session_id": "<SESSION_ID>",
  "transcript_path": "<HOME>/.claude/projects/<PROJECT_SLUG>/<SESSION_ID>.jsonl",
  "cwd": "<SCRATCH>/work",
  "prompt_id": "<UUID>",
  "permission_mode": "default",
  "agent_id": "<AGENT_ID a+16hex>",
  "agent_type": "general-purpose",
  "effort": {
    "level": "high"
  },
  "hook_event_name": "PreToolUse",
  "tool_name": "SendMessage",
  "tool_input": {
    "to": "main",
    "summary": "measurement case 2",
    "message": "measurement case 2",
    "type": "message",
    "recipient": "main",
    "recipient_kind": "main",
    "content": "measurement case 2"
  },
  "tool_use_id": "<TOOL_USE_ID>"
}
```

### caso 1b — subagente pelo agentId cru

```json
{
  "session_id": "<SESSION_ID>",
  "transcript_path": "<HOME>/.claude/projects/<PROJECT_SLUG>/<SESSION_ID>.jsonl",
  "cwd": "<SCRATCH>/work",
  "prompt_id": "<UUID>",
  "permission_mode": "default",
  "effort": {
    "level": "high"
  },
  "hook_event_name": "PreToolUse",
  "tool_name": "SendMessage",
  "tool_input": {
    "to": "<AGENT_ID a+16hex>",
    "summary": "measurement case 1b",
    "message": "measurement case 1b",
    "type": "message",
    "recipient": "<AGENT_ID a+16hex>",
    "recipient_kind": "agent",
    "content": "measurement case 1b"
  },
  "tool_use_id": "<TOOL_USE_ID>"
}
```

### caso 3 — sessão local por nome

```json
{
  "session_id": "<SESSION_ID>",
  "transcript_path": "<HOME>/.claude/projects/<PROJECT_SLUG>/<SESSION_ID>.jsonl",
  "cwd": "<SCRATCH>/work",
  "prompt_id": "<UUID>",
  "permission_mode": "default",
  "effort": {
    "level": "high"
  },
  "hook_event_name": "PreToolUse",
  "tool_name": "SendMessage",
  "tool_input": {
    "to": "forge-harness-23",
    "summary": "measurement case 3",
    "message": "ephemeral: presence\nmeasurement case 3",
    "type": "message",
    "recipient": "forge-harness-23",
    "recipient_kind": "name",
    "content": "ephemeral: presence\nmeasurement case 3"
  },
  "tool_use_id": "<TOOL_USE_ID>"
}
```

### caso 3b — sessão local por nome com [ref] do ListAgents

```json
{
  "session_id": "<SESSION_ID>",
  "transcript_path": "<HOME>/.claude/projects/<PROJECT_SLUG>/<SESSION_ID>.jsonl",
  "cwd": "<SCRATCH>/work",
  "prompt_id": "<UUID>",
  "permission_mode": "default",
  "effort": {
    "level": "high"
  },
  "hook_event_name": "PreToolUse",
  "tool_name": "SendMessage",
  "tool_input": {
    "to": "forge-harness-23 [<REF 6hex>]",
    "summary": "measurement case 3b",
    "message": "measurement case 3b",
    "type": "message",
    "recipient": "forge-harness-23 [<REF 6hex>]",
    "recipient_kind": "name",
    "content": "measurement case 3b"
  },
  "tool_use_id": "<TOOL_USE_ID>"
}
```

### caso 4 — sessão por endereço uds:

```json
{
  "session_id": "<SESSION_ID>",
  "transcript_path": "<HOME>/.claude/projects/<PROJECT_SLUG>/<SESSION_ID>.jsonl",
  "cwd": "<SCRATCH>/work",
  "prompt_id": "<UUID>",
  "permission_mode": "default",
  "effort": {
    "level": "high"
  },
  "hook_event_name": "PreToolUse",
  "tool_name": "SendMessage",
  "tool_input": {
    "to": "uds:/tmp/cc-socks/<PID>.sock",
    "summary": "measurement case 4",
    "message": "measurement case 4",
    "type": "message",
    "recipient": "uds:/tmp/cc-socks/<PID>.sock",
    "recipient_kind": "session",
    "content": "measurement case 4"
  },
  "tool_use_id": "<TOOL_USE_ID>"
}
```

### caso 5 — só notify_when_idle, sem message

```json
{
  "session_id": "<SESSION_ID>",
  "transcript_path": "<HOME>/.claude/projects/<PROJECT_SLUG>/<SESSION_ID>.jsonl",
  "cwd": "<SCRATCH>/work",
  "prompt_id": "<UUID>",
  "permission_mode": "default",
  "effort": {
    "level": "high"
  },
  "hook_event_name": "PreToolUse",
  "tool_name": "SendMessage",
  "tool_input": {
    "to": "forge-harness-23",
    "message": "",
    "notify_when_idle": true,
    "type": "message",
    "recipient": "forge-harness-23",
    "recipient_kind": "name",
    "content": ""
  },
  "tool_use_id": "<TOOL_USE_ID>"
}
```

### caso 6 — broadcast (resultado da ferramenta, sem payload de gancho)

```text
<error><tool_use_error>broadcast (to: "*") is no longer supported — send a message per recipient</tool_use_error></error>
```

## Limites desta medição

- Não houve subagente nomeado nem colega de time (agent teams) no modo headless: o caso "subagente por nome" do REQ-05 foi medido como "nome que não resolve a sessão nenhuma". O formato do registro de um agente nomeado no transcript não foi observado.
- Sessões em Remote Control e na nuvem não puderam ser medidas: não havia nenhuma com nome repetido de sessão local (item 3 do `design-inputs.md`). O design trata o caso por desenho (fail-closed), não por medição.
- O ambiente de teste e os transcripts da sessão filha (gerados em `~/.claude/projects/<slug-do-scratch>/`) foram apagados ao fim da medição.
