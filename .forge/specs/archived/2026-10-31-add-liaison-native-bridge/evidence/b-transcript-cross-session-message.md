# Medição (b) — formato da mensagem nativa recebida no transcript

Medido em 2026-10-30 sobre o transcript da sessão do orquestrador deste change (Claude Code 2.1.314; o remetente rodava 2.1.310), para o leitor do REQ-02 e do REQ-08.

## Método

Leitura do arquivo `~/.claude/projects/<slug>/<session-id>.jsonl` restrita às linhas que contêm a string `cross-session-message` (`grep`), cada linha decodificada como JSON por um script que percorre o objeto e reporta o caminho JSON de cada string que contém a tag, o tipo da linha, a forma da tag de abertura com os valores mascarados e a presença da tag de fechamento. Na segunda passada, só para as linhas de recepção, o script comparou os valores da tag com os do objeto estruturado da linha e imprimiu só booleanos e formas (letras viram `a`/`A`, dígitos viram `9`). O corpo enviado pelo peer não foi copiado para esta evidência; a fixture abaixo usa corpo fictício.

## Resultados

24 linhas contêm a string. Só 2 são recepções reais; as outras 22 são menções:

| Tipo de linha | Onde a string aparece | É recepção? |
|---|---|---|
| `user` com `isMeta: true`, `turnOrigin: "peer"`, `promptSource: "system"` | `$.message.content` (string, não array) | Sim (2 linhas) |
| `api-request-shape` | `$.shape.tools[N].description` (documentação do `SendMessage`, que cita `<cross-session-message from="...">`) | Não |
| `attachment` | `$.attachment.entries[0].description` (mesma documentação) | Não |
| `assistant` / `user` com `toolUseResult` | entradas e saídas de ferramenta que citam a tag (prompts de subagente, arquivos editados, saída de Bash) | Não |
| `queue-operation`, `api-request-blob` | conteúdo enfileirado e cópia da requisição | Não |

Consequência para o detector de "instrumento quebrado" do REQ-08: a string literal aparece em toda sessão que tem o `SendMessage` na lista de ferramentas, porque a documentação da ferramenta é gravada no transcript. Contar a string no arquivo inteiro daria "instrumento quebrado" em toda sessão sem recepção.

Forma da linha de recepção (campos estruturais; valores com `<...>` higienizados):

- `type: "user"`, `isMeta: true`, `isSidechain: false`, `turnOrigin: "peer"`, `promptSource: "system"`, `queueSkipSlashCommands: true`, `queueSkipAttachments: true`, `permissionMode` da sessão receptora.
- `message: { role: "user", content: <string> }`. A string é `"Another Claude session sent a message:\n"` + tag de abertura + `"\n"` + corpo + `"\n"` + `</cross-session-message>` + `"\n\n"` + um parágrafo fixo do Claude Code (543 caracteres, começa com "This came from another Claude session") orientando contra lavagem de permissão.
- Tag de abertura: `<cross-session-message from="<v>" from-name="<v>" from-mode="<v>">`, atributos sempre nessa ordem, entre aspas duplas. Nenhuma entidade HTML (`&...;`) apareceu nos atributos nem no corpo; o escape de aspas dentro de um atributo não foi observado (nenhum valor medido continha aspas).
- `from` tem a forma `uds:/tmp/cc-socks/<pid>.sock` (o `messagingSocketPath` do remetente no registro de sessões); `from-mode` valeu `bypass`.
- Objeto estruturado `origin` na mesma linha: `{ kind: "peer", from, verifiedPeerPid, msg_id, name, fromMode, body }`. Nas 2 recepções, `origin.from`, `origin.name`, `origin.fromMode` e `origin.body` são idênticos byte a byte a `from`, `from-name`, `from-mode` e ao corpo da tag; `verifiedPeerPid` é o pid do socket de `from`; `msg_id` é um UUID por mensagem.

Conclusões que o design usa: (1) a recepção é reconhecível sem regex pelo par `type: "user"` + `origin.kind: "peer"`, e a tag em `message.content` é a confirmação cruzada; (2) `verifiedPeerPid` permite a conferência de origem do REQ-02 pelo registro de sessões (`<pid>.json`), sem depender do nome autodeclarado; (3) o fingerprint do REQ-08 pode ser calculado do objeto `origin`, que coincidiu com os valores literais da tag; divergência entre os dois numa linha é sinal de instrumento quebrado.

## Fixture sintética (corpo fictício)

Duas linhas de recepção, no formato medido, para a fixture de controle do REQ-08. Os valores são inventados; nada foi copiado do peer real.

```json
{"type":"user","isMeta":true,"isSidechain":false,"turnOrigin":"peer","promptSource":"system","queueSkipSlashCommands":true,"queueSkipAttachments":true,"permissionMode":"default","uuid":"<UUID>","parentUuid":"<UUID>","sessionId":"<SESSION_ID>","timestamp":"2026-10-30T00:00:00.000Z","version":"2.1.314","message":{"role":"user","content":"Another Claude session sent a message:\n<cross-session-message from=\"uds:/tmp/cc-socks/11111.sock\" from-name=\"PEER-FIXTURE\" from-mode=\"default\">\ncorpo fictício de controle — mensagem 1\n</cross-session-message>\n\nThis came from another Claude session (parágrafo fixo omitido na fixture)."},"origin":{"kind":"peer","from":"uds:/tmp/cc-socks/11111.sock","verifiedPeerPid":11111,"msg_id":"<UUID>","name":"PEER-FIXTURE","fromMode":"default","body":"corpo fictício de controle — mensagem 1"}}
{"type":"user","isMeta":true,"isSidechain":false,"turnOrigin":"peer","promptSource":"system","queueSkipSlashCommands":true,"queueSkipAttachments":true,"permissionMode":"default","uuid":"<UUID>","parentUuid":"<UUID>","sessionId":"<SESSION_ID>","timestamp":"2026-10-30T00:00:01.000Z","version":"2.1.314","message":{"role":"user","content":"Another Claude session sent a message:\n<cross-session-message from=\"uds:/tmp/cc-socks/11111.sock\" from-name=\"PEER-FIXTURE\" from-mode=\"default\">\ncorpo fictício de controle — mensagem 2\n</cross-session-message>\n\nThis came from another Claude session (parágrafo fixo omitido na fixture)."},"origin":{"kind":"peer","from":"uds:/tmp/cc-socks/11111.sock","verifiedPeerPid":11111,"msg_id":"<UUID>","name":"PEER-FIXTURE","fromMode":"default","body":"corpo fictício de controle — mensagem 2"}}
```

Fingerprints esperados (REQ-08: `sha256` hex dos bytes UTF-8 de `JSON.stringify([from, fromName, body])`), calculados com `node:crypto`:

| Mensagem | Fingerprint |
|---|---|
| 1 | `b843a088d77925ead49ceac0181d3108da745af004d6e8d123ed7bc4467b4654` |
| 2 | `161d6df6c22d3f94b8c284be2ba6da60ed5cfbdac4d7636f2fef05d16eff4baf` |

A fixture de controle negativo é a mesma sessão com uma linha `api-request-shape` contendo a documentação da ferramenta (string literal presente, zero recepções): deve dar "nada pendente", não "instrumento quebrado".

## Medição complementar (rodada 2 do gate `design_reviewed`, 2026-10-30)

Feita pelo revisor delegado do gate, somente leitura, sobre os 60 transcripts mais recentes com mais de 10 KB em `~/.claude/projects` (últimos 3 dias), imprimindo só metadados (contagens de `type`, `origin.kind`, chaves e prefixos de valor), sem copiar corpo.

- `origin` não é exclusivo da mensageria entre sessões: linhas `type: "user"` com `origin.kind` `human` (743), `task-notification` (1893) e `coordinator` (7); `turnOrigin` `human`, `task_notification` e `scheduled` em 26 dos 60 arquivos.
- `origin.kind: "peer"` também marca mensagem interna de subagente para o `main`: 10 linhas com a tag `<agent-message>`, `from` em hex de agentId, `senderTaskId` e sem `verifiedPeerPid`.
- 63 recepções reais com a tag `cross-session-message` não têm `origin.body`; o corpo está só na tag.
- `verifiedPeerPid` coincide com o pid do socket de `from` em 3464 de 3464 linhas que o têm; `hopChain` (lista de ids) não altera a leitura.

Consequência adotada no design (§2.6): a tag é a fonte de `from`, `fromName`, `fromMode`, `body` e do fingerprint; recepção exige `from` com prefixo `uds:`; `origin` só confere os campos presentes. As conclusões (1) e (3) da seção anterior ficam substituídas por esta.
