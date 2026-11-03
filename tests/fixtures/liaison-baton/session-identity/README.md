# Fixture — identidade de sessão (TASK-01, `add-liaison-handoff-baton`)

Medido em 2026-11-01, Claude Code 2.1.316 (`claude --version`), macOS, em ambiente descartável
fora de qualquer repositório git (`git rev-parse` falhou ali, conferido), a pedido do próprio
change. Mesmo método da medição (a)/(d) do change dependente `add-liaison-native-bridge`
(`.forge/specs/archived/2026-10-31-add-liaison-native-bridge/evidence/`): `settings.json` de teste
com `--settings <dir>/settings.json --setting-sources ""` (nenhuma configuração do usuário, do
projeto ou local carregada), execuções headless (`claude -p ...`), gancho temporário de registro
que nunca sai de rc diferente de 0 e nunca propaga nenhum valor sensível (só ids de sessão, que
não são segredo). O ambiente de teste foi apagado ao fim da medição.

## Método

Um gancho `PostToolUse` (matcher `.*`) grava o `stdin` recebido, compara `session_id` do JSON
contra `CLAUDE_CODE_SESSION_ID` do próprio ambiente do processo do gancho, e registra o veredito
em `verdicts.log`; na primeira chamada, imprime
`{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"<marcador>"}}` com rc 0
para testar se o Claude Code aceita e entrega o campo ao modelo. Um gancho `SessionStart` (sem
matcher) grava `source` e `session_id` de cada disparo. Quatro execuções:

1. **Caso 1 — sessão principal x subagente.** Um prompt pede: rodar `Bash` no nível principal,
   depois invocar um subagente (`Agent`, `general-purpose`) que roda `Bash` e reporta `DONE`.
2. **Caso 2 — `additionalContext`.** Um prompt roda `Bash` uma vez e pede ao modelo, na resposta
   final, para citar literalmente qualquer texto extra de contexto injetado por gancho que não
   fosse o `stdout` do próprio comando (ou responder `NONE`); o gancho emite o marcador na
   primeira chamada.
3. **Caso 3 — `--resume`.** Uma primeira execução roda `Bash` e termina; uma segunda, com
   `claude --resume <session_id da primeira>`, roda `Bash` outra vez.
4. **Caso 4 — `/clear`.** Uma única invocação com `--input-format stream-json` enfileira três
   turnos de usuário: `Bash`, a mensagem literal `/clear`, `Bash` de novo.

## Resultados

### 1. `CLAUDE_CODE_SESSION_ID` (ambiente do gancho) ≡ `session_id` (JSON de entrada do gancho)

Confirmado nas quatro execuções, sempre `match=yes`; nenhuma divergência observada. É o mesmo fato
que a medição (d) do change dependente já tinha confirmado por outro caminho (variável de ambiente
do Bash do agente comparada ao registro de sessão), agora confirmado diretamente no payload do
`PostToolUse`.

### 2. Tool de subagente DISPARA o `PostToolUse` do gancho, com o `session_id` da sessão PAI

Três eventos capturados no caso 1, nesta ordem:

| # | `tool_name` | `session_id` | `agent_id` | `agent_type` |
|---|---|---|---|---|
| 1 | `Bash` (nível principal) | `<SID>` | ausente | ausente |
| 2 | `Bash` (dentro do subagente) | `<SID>` (mesmo da sessão principal) | `a` + 16 hex | `general-purpose` |
| 3 | `Agent` (retorno do spawn, nível principal) | `<SID>` | ausente | ausente |

O `PostToolUse` DISPARA para ferramentas executadas dentro de um subagente, com o mesmo
`session_id` da sessão principal (nunca um id próprio do subagente) e com `agent_id`/`agent_type`
no payload identificando que a chamada veio de um subagente. Consequência para o design (§2.8,
§2.7): o caminho rápido do gancho de renovação também corre durante trabalho de subagente, porque
o evento chega com o `session_id` certo; a limitação textual do design ("um turno parado... à
espera de... subagente, não dispara `PostToolUse` da sessão principal") descreve a sessão
principal ficar ociosa enquanto o subagente roda, não a ausência do evento — o evento existe, só
rotulado como vindo de um subagente, e o gancho de renovação não precisa (e não deve) distinguir
os dois casos, porque a titularidade é por `session_id`, não por `agent_id`.

### 3. `hookSpecificOutput.additionalContext` em `PostToolUse` É ACEITO e chega ao modelo

Confirmado: o modelo, instruído a citar verbatim qualquer contexto extra recebido, reproduziu
exatamente o texto do marcador emitido pelo gancho (`TASK01-MARKER-ac-probe-xyz123: ...`). O
campo não aparece como uma entrada própria no `stream-json` de saída (não há chave
`additionalContext` nem `hookSpecificOutput` em nenhuma linha do transcript) — ele é injetado
silenciosamente no contexto que o modelo recebe, sem virar uma mensagem visível na API de
streaming; só a resposta do próprio modelo revela que o recebeu. Consequência para o design: a
suposição condicional do §2.8 ("se ausente na versão medida, o aviso cai para o início de sessão e
para o `baton status`") NÃO se aplica — na versão medida (2.1.316), o aviso por `additionalContext`
funciona como desenhado, e pode ser o canal primário, com o início de sessão e o `baton status`
como reforço/fallback (papel que já exerciam).

### 4. `--resume` preserva o `session_id`

Confirmado: a segunda execução (`claude --resume <id>`) gerou um evento de `PostToolUse` com o
MESMO `session_id` da primeira execução (`5d624044-a288-49f9-bd95-826d22c0e82f` nas duas).
Confirma a suposição do design §2.7 ("identificador igual mantém a titularidade").

### 5. `/clear` inicia sessão NOVA, com `source: clear` e `session_id` diferente

Confirmado por `SessionStart`:

```
source=startup session_id=07cff47f-8737-4eb0-a70f-9ce5f698c06a
source=clear   session_id=32c2b656-ef88-48ff-9b9d-ed99254fcac3
```

Confirma a suposição do design §2.7 ("`/clear` inicia sessão nova... identificador novo").
Nota metodológica: ao enfileirar `/clear` como terceiro turno num único `--input-format
stream-json`, o cliente processou os dois turnos de `Bash` adjacentes antes de aplicar o reset
(ambos os `PostToolUse` capturados trazem o `session_id` anterior ao `clear`); o fato medido que
importa — `source: clear` sempre vem com um `session_id` novo, nunca o anterior — ficou confirmado
de qualquer forma pelo evento de `SessionStart`, que é a fonte de verdade que o design cita.

### 6. Compactação — NÃO medida diretamente nesta rodada

Forçar uma compactação real exige acumular contexto suficiente, o que não foi reproduzido num
ambiente descartável headless dentro do orçamento desta task. A documentação oficial
(`code.claude.com/docs/en/hooks`, consultada em 2026-11-01) confirma que `compact` é um valor de
`source` do `SessionStart` distinto de `startup`/`resume`/`clear`/`fork`
("`"compact"` after compaction"), mas o trecho obtido não afirma explicitamente se o `session_id`
muda. O design (§2.7) já declara que o mecanismo não depende do resultado desta medição
especificamente: identificador igual mantém a titularidade, identificador novo segue o caminho do
REQ-10 (liberar antes ou retomar depois de `lease_until` + folga) — qualquer um dos dois
comportamentos é coberto sem mudança de design. Tratado como risco residual documentado na rule
(TASK-32/33), não como bloqueio.

## Veredito para a TASK-01

Nenhuma divergência real entre os quatro contratos do change dependente (confirmados linha a linha
no código mesclado) e as suposições do design. Dos dois itens que a TASK-01 explicitamente deixava
em aberto (disparo de `PostToolUse` por subagente; suporte de `additionalContext`), ambos saíram
com resultado FAVORÁVEL e mais forte que o pior caso que o design já tolerava — a nota do design
que dizia "se ausente, cai para fallback" não precisa ser exercida. Implementação liberada para
seguir direto à Wave 1, sem nova rodada de `design_reviewed`.

## Fixtures higienizadas

### Caso 1 — evento de `PostToolUse` disparado por tool de subagente (sanitizado)

```json
{
  "session_id": "<SID>",
  "transcript_path": "<HOME>/.claude/projects/<PROJECT_SLUG>/<SID>.jsonl",
  "cwd": "<SCRATCH>/work",
  "hook_event_name": "PostToolUse",
  "tool_name": "Bash",
  "agent_id": "<AGENT_ID a+16hex>",
  "agent_type": "general-purpose",
  "tool_input": { "command": "echo subagent-probe" },
  "tool_response": { "...": "..." }
}
```

### Caso 4 — eventos de `SessionStart` em sequência (sanitizado)

```
{"hook_event_name":"SessionStart","source":"startup","session_id":"<SID_A>"}
{"hook_event_name":"SessionStart","source":"clear","session_id":"<SID_B>"}
```

## Limites desta medição

- Medido num processo `claude -p` headless fora de qualquer repositório; não foi medido dentro de
  uma sessão interativa real nem dentro deste worktree.
- Compactação não foi exercida (item 6).
- `--continue` não foi medido separadamente de `--resume`; a documentação oficial agrupa os dois
  sob o mesmo `source: resume`, e o design já trata os dois identicamente.
- Agent teams / subagente nomeado (`name` em vez de `agentId`) não foi medido; fora do escopo desta
  task (o design usa só `session_id`, nunca nome de agente).
