# Requirements — add-liaison-native-bridge

> Requisitos do change `add-liaison-native-bridge`. Cada requisito é verificável e rastreável à proposal. Decisões de clarificação de 2026-10-30: C1 (peer sem canal em comum → recusar e orientar), C2 (mensagem sem destino declarado → bloquear), C3 refinada (workspace por padrão, com workspaces permitidos cadastrados, identificados por remote git, com motivo obrigatório, valendo só para a saída) e classe `internal-coordination` para o mesmo repositório. Revisão delegada, rodada 2 (2026-10-30): a contenção do cadastro é proteção contra liberação induzida, com detecção determinística de mudanças de contenção, e não fronteira de segurança, que só a configuração gerenciada do Claude Code oferece (documentada, fora do escopo); a origem de mensagem registrada é extraída do transcript pelo fingerprint, nunca informada por flag. Identificadores, classes, chaves e flags em inglês, conforme a convenção de nomenclatura do harness.

Termos usados abaixo.

- **Mensagem nativa**: mensagem trocada entre sessões do Claude Code por `SendMessage`/`ListAgents`, recebida embrulhada na tag `cross-session-message` (atributos `from`, `from-name`, `from-mode`).
- **Destino de sessão**: o destinatário de um `SendMessage` que endereça outra sessão (local, Remote Control ou nuvem), em oposição a um subagente, colega ou `main` da própria sessão.
- **Registro de sessões**: os arquivos `~/.claude/sessions/<pid>.json` mantidos pelo Claude Code (campos medidos em 2026-10-30, versões 2.1.310 e 2.1.314: `pid`, `name`, `cwd`, `messagingSocketPath`, `kind`, `status`).
- **Repositório** de uma sessão: o repositório principal do `cwd`, resolvido pelo `git-common-dir` (uma worktree pertence ao repositório principal dela).
- **Workspace** de uma sessão: a raiz do repositório git mais externo que contém o repositório da sessão, subindo a partir da raiz do repositório e parando antes do diretório home do usuário (o home e seus ancestrais nunca são workspace, mesmo que sejam repositório git). Sessão fora de repositório git tem como workspace o próprio `cwd`.
- **Identidade de workspace**: o remote `origin` do repositório raiz do workspace, normalizado para `host/owner/repo` sem esquema, credencial nem sufixo `.git`; sem remote, o caminho absoluto da raiz.
- **Classes efêmeras**: a lista fechada `identification | presence | schedule | turn-notice | reread-request | internal-coordination`.

## REQ-01 — `notify`: ponteiro canônico para mensagem publicada

- **Quando** o operador roda `liaison-ops.sh notify <channel> <msg_id> --to <destino>`, **o sistema deve** imprimir no stdout um ponteiro canônico (primeira linha `liaison:<channel>/<msg_id>`, seguida de `thread_id`, `content_sha` e `subject`) se a mensagem existir no log próprio e já tiver sido publicada por um `sync` com push bem-sucedido; caso contrário, recusar com rc ≠ 0 nomeando a condição que falhou.
- **Critérios de aceite:**
  - [ ] Mensagem própria publicada → rc 0 e ponteiro com canal, `msg_id`, `thread_id`, `content_sha` e `subject` idênticos aos do log.
  - [ ] `msg_id` inexistente no canal → rc ≠ 0 com "não existe".
  - [ ] `msg_id` do log de um peer → rc ≠ 0 com "não é mensagem própria".
  - [ ] Mensagem própria posterior à marca do último `sync` com push (mesma regra de publicação da issue #109) → rc ≠ 0 com "não publicada" e o comando `sync` que falta.
  - [ ] `--to` ausente ou flag desconhecida → rc ≠ 0 nomeando o subcomando `notify` e as flags aceitas.
  - [ ] Nenhum script ou gancho do template invoca o CLI de sessão nem abre conexão com socket de sessão (a busca de `socketPath` diferencia maiúsculas, para não casar a leitura permitida de `messagingSocketPath`). A checagem [10] do gate `w113` passa a reprovar estes padrões em `template/.forge/scripts/` e `template/.forge/hooks/`: `claude` seguido de `-p`, `--print`, `--resume`, `--continue` ou `-r`; `nc` com `-U`; `socat`; `curl` com `--unix-socket`; `net.connect`, `createConnection`, `new net.Socket` e `socketPath` em `.mjs`/`.js`; `AF_UNIX` em python; e qualquer referência a `CLAUDE_CODE_MESSAGING_TOKEN` ou `CLAUDE_CODE_MESSAGING_SOCKET`. Ler `messagingSocketPath` do registro de sessões e comparar strings não é conexão e não é padrão proibido. A checagem é vista vermelha com uma fixture que contém cada padrão e verde com o gancho real deste change.
- **Rastreia:** proposal §2.1
- **Notas:** `--to` aparece na saída só como informação; o envio é ato do agente.

## REQ-02 — Registro de mensagem nativa recebida (`--via cross-session`)

- **Quando** o operador registra uma mensagem nativa recebida com `liaison-ops.sh send <channel> --thread <id> --kind <k> --authored-by <repo-do-peer> --via cross-session --native-ref <fingerprint> [--session <id>] ...`, **o sistema deve** localizar a mensagem pelo fingerprint no transcript da sessão (por padrão a de `CLAUDE_CODE_SESSION_ID`), com o mesmo leitor do REQ-08, extrair dela `from`, `from-name` e `from-mode`, e gravar no log próprio uma mensagem com `trust: untrusted-peer`, `authored_by` do repositório do peer, `via: cross-session` e um objeto `cross_session` com esses três valores, o fingerprint e o booleano `origin_verified`. O operador não informa origem por flag. O corpo registrado é um resumo com as palavras do operador, não a cópia da mensagem (regra "cite, não incorpore").
- **Critérios de aceite:**
  - [ ] O enum `via` do schema aceita `cross-session`, e `validateEnvelope` passa a validar `via` e `cross_session` com as mesmas regras do schema (trabalho novo: hoje ele não valida `via`); uma bateria de envelopes válidos e inválidos dá o mesmo veredito nos dois.
  - [ ] `cross_session` só é aceito com `via: cross-session`, e `via: cross-session` exige `authored_by` e `cross_session` com os cinco subcampos obrigatórios `from_addr`, `from_name`, `from_mode`, `native_ref` e `origin_verified`, todos calculados pelo script.
  - [ ] Fingerprint não encontrado no transcript, transcript ilegível ou sessão não identificável → rc ≠ 0, nada gravado, nomeando o que faltou; o leitor reporta "instrumento quebrado" nas mesmas condições do REQ-08.
  - [ ] Os valores extraídos têm teto de 128 caracteres, rejeitam caracteres de controle e passam pela varredura de segredo do `send`.
  - [ ] O corpo passa pela varredura de segredo, pelos tetos e pelo blob do `send`, sem caminho de escrita paralelo.
  - [ ] Conferência de origem: quando o `from` extraído resolve no registro de sessões, o repositório do `cwd` daquela sessão é comparado com o `peer-path` do `authored_by` no `liaison.yaml`; se divergirem, o registro é recusado (rc ≠ 0, nada gravado) nomeando os dois caminhos. Quando não resolve (sessão encerrada, Remote Control, nuvem) ou o `authored_by` não tem `peer-path`, o registro é aceito com `origin_verified: false`, e `inbox --show` exibe "origem não verificada" dentro da moldura. Com conferência bem-sucedida, `origin_verified: true`.
  - [ ] `check-liaison-acks.sh` aceita a mensagem no log próprio (tem `authored_by`, logo não é `self`).
  - [ ] `inbox --show` exibe a mensagem sob o banner `UNTRUSTED` nomeando o repositório e o nome declarado, com os campos de `cross_session` dentro da moldura e neutralizados; o `CHANNEL.md` gerado por `render` mostra `via: cross-session` e o nome declarado rotulado como autodeclarado.
  - [ ] `--native-ref` ou `--session` sem `--via cross-session`, e `--via cross-session` sem `--native-ref`, reprovam nomeando a flag; não existe flag `--from-*`.
- **Rastreia:** proposal §2.2
- **Notas:** `from-name` não satisfaz o padrão de `authored_by` e não prova repositório; o repositório do peer é informado pelo operador, conferido contra o canal pelo REQ-03 e contra a sessão de origem pela conferência acima.

## REQ-03 — Peer sem canal em comum: recusar e orientar (C1)

- **Quando** o registro do REQ-02 nomeia em `--authored-by` um repositório que não está em `channels.<channel>.participants` do `liaison.yaml`, **o sistema deve** recusar com rc ≠ 0, sem gravar nada, e imprimir os dois caminhos de resolução com os ids preenchidos: incluir o peer no canal existente (`liaison-ops.sh open <channel> --participants <peer>`, que acrescenta participante) ou abrir um canal novo com ele (`open <novo-canal> --participants <peer>` e `transport set`), lembrando que o peer precisa fazer o mesmo no repositório dele.
- **Critérios de aceite:**
  - [ ] Peer participante do canal → registro aceito (a participação na thread não é exigida: `authored_by` não é cobrado por ack).
  - [ ] Peer não participante → rc ≠ 0, com `liaison.yaml`, log, blobs e cursor intactos (hash antes e depois), e saída contendo os dois caminhos.
  - [ ] Nenhum canal, thread, participante ou transporte é criado como efeito colateral.
- **Rastreia:** proposal §2.2 (decisão C1)

## REQ-04 — Gancho de saída: varredura de segredo em `SendMessage`

- **Quando** o agente chama `SendMessage` com texto para um destino de sessão, **o sistema deve** passar todos os campos string do `tool_input` (o corpo e qualquer outro, como um resumo) pela mesma varredura de `lib/secret-scan.mjs` usada pelo `send` e bloquear com exit 2 se houver achado, nomeando o padrão e nunca ecoando o trecho que casou.
- **Critérios de aceite:**
  - [ ] Corpo com cada família de padrão coberta por `secret-scan.mjs` → exit 2; corpo limpo → segue para as demais checagens.
  - [ ] Payload de destino de sessão do qual não se consegue extrair o corpo (stdin vazio, JSON malformado, campo de corpo ausente) → exit 2 (fail-closed), dizendo o que não foi possível ler, exceto no pedido só de aviso de ociosidade do REQ-05. O nome do campo de corpo e a forma do pedido de aviso são os medidos no design (REQ-05), não presumidos.
  - [ ] A saída de erro nunca contém o trecho que casou.
  - [ ] A varredura é a mesma função usada pelo `send` (um único leitor canônico de padrões), conferida por teste que altera um padrão e vê os dois caminhos mudarem juntos.
- **Rastreia:** proposal §2.3

## REQ-05 — Escopo do gancho: só destinos de sessão

- **Quando** o `SendMessage` endereça um subagente, colega ou o `main` da própria sessão, **o sistema deve** deixar passar sem aplicar REQ-04, REQ-06 e REQ-07; **quando** endereça um destino de sessão, deve aplicá-los; **quando** é só um pedido de aviso de ociosidade (`notify_when_idle`) sem texto para um destino de sessão, deve aplicar apenas o REQ-07, porque o pedido não carrega conteúdo mas presença também é informação.
- **Critérios de aceite:**
  - [ ] Fixtures de payload reais, capturadas no design por gancho de registro temporário, para os cinco casos: subagente por nome, `main`, sessão local por nome, sessão por endereço `uds:`, e pedido só de aviso de ociosidade para sessão.
  - [ ] Os dois primeiros casos → exit 0 sem checagem; o terceiro e o quarto → REQ-04, REQ-06 e REQ-07; o quinto → só REQ-07.
  - [ ] Destino endereçado por identificador curto (forma usada pelo Claude Code quando vários destinos respondem ao mesmo nome) → tratado como destino de sessão; se não resolver de forma única no registro local, exit 2 com mensagem dizendo que o destino é ambíguo ou remoto.
  - [ ] Destino que não se consegue classificar com certeza → tratado como destino de sessão (fail-closed), com mensagem dizendo por quê.
- **Rastreia:** proposal §2.3 e §4
- **Notas:** o mecanismo de classificação é decisão de design, a partir da medição do payload.

## REQ-06 — Destino declarado em toda mensagem que sai para sessão (C2)

- **Quando** o agente envia `SendMessage` com texto a um destino de sessão, **o sistema deve** exigir que a mensagem carregue um ponteiro de liaison válido (linha `liaison:<channel>/<msg_id>` que satisfaça as condições do REQ-01) ou, na primeira linha, a declaração `ephemeral: <class>` com uma das classes efêmeras; sem isso, bloquear com exit 2.
- **Critérios de aceite:**
  - [ ] Ponteiro válido → passa; ponteiro para mensagem inexistente, de peer ou não publicada → exit 2 nomeando a condição.
  - [ ] Declaração com classe da lista → passa (sujeita ao critério seguinte); classe fora da lista ou declaração fora da primeira linha → exit 2 listando as classes aceitas.
  - [ ] `ephemeral: internal-coordination` só passa quando o destino está no mesmo repositório da origem (mesmo `git-common-dir`, inclusive worktrees); para destino em outro repositório, mesmo que do mesmo workspace → exit 2 explicando que conteúdo substantivo entre repositórios é material de liaison.
  - [ ] Mensagem sem ponteiro nem declaração → exit 2 explicando as duas formas de declarar.
  - [ ] A validação do ponteiro lê o canal pelo tronco (`--git-common-dir`), igual ao `liaison-ops.sh`; uma sessão rodando numa worktree valida o mesmo ponteiro que a sessão do checkout principal.
- **Rastreia:** proposal §2.4 (decisão C2)
- **Notas:** o gate cobra a existência da declaração; se a classe escolhida está certa, só auditoria amostral responde (limite registrado na rule do REQ-09).

## REQ-07 — Contenção por workspace com workspaces permitidos (C3)

- **Quando** o agente envia `SendMessage` a um destino de sessão, **o sistema deve** resolver o destino no registro de sessões (por `name` ou por `messagingSocketPath`), calcular a identidade de workspace do destino e a da origem, e deixar passar só se forem iguais ou se a identidade do destino constar como entrada ativa em `allowed_workspaces` (REQ-12) do repositório da sessão de origem (o principal, pelo `git-common-dir`, mesmo quando a origem é repositório aninhado); nos demais casos, e quando o destino não puder ser resolvido, bloquear com exit 2.
- **Critérios de aceite:**
  - [ ] Destino no mesmo workspace (mesmo repositório, worktree do mesmo repositório inclusive fora da árvore principal, repositório aninhado) → passa.
  - [ ] Destino em outro workspace, sem cadastro → exit 2 nomeando as duas identidades e dizendo que liberar esse workspace é decisão do operador humano, feita fora da sessão (REQ-12). A mensagem não imprime comando pronto para copiar.
  - [ ] Destino em outro workspace cadastrado → passa.
  - [ ] Nome que casa com mais de uma sessão no registro → exit 2 pedindo o endereço `uds:`.
  - [ ] Destino sem registro local (Remote Control, nuvem, sessão encerrada) → exit 2, mesmo que algum workspace esteja cadastrado.
  - [ ] Registro ilegível ou sem `name`/`cwd`/`messagingSocketPath` → exit 2 (fail-closed) nomeando o arquivo.
  - [ ] Registro cujo `pid` não corresponde a processo vivo é ignorado na resolução (não gera falsa ambiguidade de nome nem resolve destino morto).
  - [ ] Endereços `uds:` são comparados após normalização de caminho (`/tmp` e `/private/tmp` no macOS são o mesmo).
  - [ ] O cadastro efetivo é lido pelo tronco (`--git-common-dir`), como no REQ-06.
  - [ ] O erro de bloqueio nunca sugere desarmar o gancho nem editar `hooks.manifest`/`settings.json`.
  - [ ] Fixture com o diretório home como repositório git (dotfiles) → as sessões não colapsam num único workspace.
  - [ ] Fixture do caso de 2026-10-30 (origem `forge-harness`, destino `ORQUESTRADOR` em `payments`) → exit 2 sem cadastro e exit 0 com `payments` cadastrado.
- **Rastreia:** proposal §2.7 (decisão C3)
- **Notas:** o registro de sessões não é documentado pelo Claude Code; a fixture fixa o formato medido em 2026-10-30.

## REQ-08 — Diagnóstico de cobertura do que chega

- **Quando** uma sessão termina (gancho `SessionEnd`) ou o operador roda `liaison-ops.sh native check [--session <id>]`, **o sistema deve** listar as mensagens nativas recebidas na sessão que não têm destinação: nem um registro no liaison com o mesmo fingerprint em `cross_session`, nem uma declaração feita com `liaison-ops.sh native dispose <fingerprint> --ephemeral <class>`. Deve também sinalizar à parte as recebidas de outro workspace e as de workspace desconhecido. O relatório do fim de sessão é persistido em estado local fora do repositório e exibido no início da próxima sessão do mesmo repositório, no bloco do liaison do `on-session-start.sh`, porque a saída do `SessionEnd` não chega ao modelo nem ao operador.
- **Critérios de aceite:**
  - [ ] Modo aviso: rc 0 sempre, nunca bloqueia o fim nem o início de sessão.
  - [ ] Fiação: `sync-adapters.mjs` fia o `SessionEnd` quando `liaison.auto` está ligado, mesmo com `handoff.auto` desligado; o gate de fiação cobre as quatro combinações dos dois flags.
  - [ ] Comportamento: `on-session-end.sh` roda o handoff só com `handoff.auto` e o diagnóstico só com `liaison.auto`, e a ausência do script de uma parte não impede a outra; o gate cobre as quatro combinações.
  - [ ] Persistência e entrega: o `SessionEnd` grava o relatório; o `SessionStart` seguinte do mesmo repositório o exibe uma vez, com contagens e fingerprints, e o marca como entregue; o relatório não entra em arquivo versionado.
  - [ ] Sessão analisada: sem `--session`, `native check` usa `CLAUDE_CODE_SESSION_ID` do ambiente; sem nenhum dos dois, recusa com rc ≠ 0 dizendo o que falta.
  - [ ] Fingerprint: `sha256`, em hex minúsculo de 64 caracteres, dos bytes UTF-8 de `JSON.stringify([from, fromName, body])`, sendo os três os valores literais da tag recebida; impresso pelo diagnóstico e aceito pelo `--native-ref` do REQ-02. A fixture fixa o valor esperado de um caso conhecido. Mensagens idênticas do mesmo remetente têm o mesmo fingerprint e uma única destinação cobre todas (comportamento aceito e documentado).
  - [ ] Os `from-name` e qualquer trecho de mensagem impressos no relatório passam por `untrusted-render` (moldura e neutralização).
  - [ ] A declaração de `dispose` fica fora do repositório (estado local não versionado) e aceita só as classes efêmeras.
  - [ ] O workspace de quem enviou é resolvido pelo registro de sessões a partir do `from`; se o registro do remetente já não existir, a mensagem é listada como "workspace desconhecido", nunca como "mesmo workspace".
  - [ ] Fixture de controle a cada execução: um transcript sintético com duas mensagens nativas precisa produzir duas detecções; senão, o diagnóstico reporta "instrumento quebrado" em vez de "nada pendente".
  - [ ] Transcript real que contém a string literal `cross-session-message` e do qual o parser extrai zero mensagens → "instrumento quebrado".
- **Rastreia:** proposal §2.5 e §4

## REQ-09 — Normas escritas

- **Quando** este change for entregue, **o sistema deve** ter `liaison-protocol.md` e `liaison-untrusted-input.md` atualizadas com: o critério de classes obrigatórias (decisão que afeta outro repositório, contrato ou ack, retratação, achado de segurança, pergunta bloqueante e resposta, trabalho sobreposto) e das classes efêmeras; a regra de que coordenação substantiva no mesmo repositório usa `internal-coordination` e não o liaison; a aplicação integral das regras 1 a 4 de dado não confiável à mensagem nativa, com a nota de que lá não existe nenhuma guarda mecânica de moldura, teto ou neutralização; a afirmação de que `from-name` é autodeclarado e não prova repositório nem empresa; a afirmação de que `allowed_workspaces` vale só para a saída e é proteção contra liberação induzida, não fronteira de segurança; e a recomendação de que repositórios em escopo PCI usem a configuração gerenciada do Claude Code para negar ou isolar a mensageria entre sessões, que é a única contenção que o próprio usuário do sistema não altera.
- **Critérios de aceite:**
  - [ ] As classes efêmeras da rule e as do código vêm de uma única fonte, conferida por teste (alterar a lista num lugar sem o outro reprova).
  - [ ] `validate-rules.sh` com `FORGE_ROOT` no template passa.
  - [ ] `last_reviewed` das duas rules atualizado.
  - [ ] Item aberto no ledger do harness para avaliar a configuração gerenciada nos repositórios PCI, com origem neste change.
- **Rastreia:** proposal §2.6

## REQ-10 — Empacotamento e propagação do gancho

- **Quando** o harness for instalado ou atualizado num consumidor, **o sistema deve** distribuir o gancho novo declarado em `hooks.manifest.default` com matcher `^SendMessage$`, contrato `stdin-json` e estado `armado` para instalação nova, e respeitar a regra existente para consumidor que já tem `.claude/settings.json` (nasce inativo e nomeado).
- **Critérios de aceite:**
  - [ ] `sync-adapters.mjs` gera a fiação do gancho a partir do manifesto, sem literal novo no código.
  - [ ] Consumidor de fixture com `settings.json` pré-existente recebe o gancho inativo e nomeado; instalação nova recebe armado.
  - [ ] `plugin/forge/commands/liaison.md` igual à versão do template (gate de sincronia do plugin verde).
- **Rastreia:** proposal §4

## REQ-11 — Documentação operacional

- **Quando** este change for entregue, **o sistema deve** ter `/forge:liaison` documentando `notify`, `native check`, `native dispose`, `native allow`/`native revoke` (com a restrição de execução humana), `--via cross-session` com `--native-ref` e `--session`, o gancho de saída e o fluxo campainha → `sync` → `inbox --show`; e ter atualizados o inventário de gates e scripts, `docs/refer/slash-commands.md`, a entrada em `CHANGELOG.md` sob `[Unreleased]` e o badge de contagem de gates do `README.md`.
- **Critérios de aceite:**
  - [ ] Os subcomandos novos constam do `argument-hint`; para cada subcomando novo ou alterado, o conjunto de flags no bloco de protocolo do comando é igual ao conjunto da mensagem de flags aceitas do script, conferido por teste.
  - [ ] O inventário de gates e scripts lista os gates e scripts novos.
  - [ ] A documentação do `send` em modo `cross-session` mostra só `--native-ref` e `--session`, sem flags de origem.
  - [ ] `docs/refer/slash-commands.md` descreve os subcomandos novos do `/forge:liaison`.
  - [ ] `CHANGELOG.md` tem entrada em `[Unreleased]` cobrindo o change, e o badge de gates do `README.md` bate com a contagem real (os gates de documentação existentes ficam verdes).
- **Rastreia:** proposal §2.1, §2.2, §2.5, §2.7

## REQ-12 — Cadastro de workspaces permitidos e detecção de mudanças de contenção

- **Quando** o operador humano cadastra um workspace com `liaison-ops.sh native allow <identidade> --reason "<motivo>"` (ou revoga com `native revoke <identidade> --reason "<motivo>"`), num terminal próprio fora de qualquer sessão do Claude Code, **o sistema deve** gravar a entrada em `allowed_workspaces` de um arquivo de configuração versionado do repositório, validado por schema, com `id` (identidade de workspace), `reason`, `granted_by` (`git config user.email`) e `granted_at` (data ISO), e registrar no mesmo arquivo a identidade do próprio repositório (`self_identity`) no primeiro cadastro. **Quando** o comando parte de uma sessão de agente, deve recusar. **Quando** um push, o `doctor` ou a preparação de PR encontram mudança de contenção, devem sinalizá-la para decisão humana.
- **Critérios de aceite:**
  - [ ] `native allow` e `native revoke` recusam com rc ≠ 0, sem tocar o arquivo, quando o ambiente tem qualquer marcador de sessão do Claude Code (`CLAUDECODE`, `CLAUDE_CODE_SESSION_ID`, `CLAUDE_PID`), dizendo que o cadastro é ato do operador num terminal fora da sessão.
  - [ ] Mudança de contenção é, de forma fechada: alteração do arquivo de cadastro; remoção, troca de estado ou de matcher da linha do gancho de `SendMessage` em `hooks.manifest`/`hooks.manifest.default`; ausência da fiação desse gancho no `.claude/settings.json` gerado quando o manifesto o declara armado; e identidade do remote `origin` diferente de `self_identity`.
  - [ ] O gancho de `pre-push` lista as mudanças de contenção do intervalo enviado (as três primeiras pelo diff, a quarta pelo estado atual) com aviso destacado, sem bloquear; o `doctor` reporta as mesmas quatro no estado atual; a preparação de PR (`/forge:prepare-pr` e `/forge:ship`) inclui uma seção "Mudanças de contenção" quando houver alguma, para que o humano decida no merge.
  - [ ] Fixtures cobrem cada uma das quatro mudanças, sendo detectada nos três pontos, e o caso sem mudança, sem falso positivo.
  - [ ] Fixture do cenário do revisor: agente bloqueado pelo REQ-07 tenta `native allow` → recusa; o mesmo agente edita o arquivo de cadastro diretamente e faz push → a mudança aparece no pre-push, no doctor e na seção do PR.
  - [ ] `--reason` ausente ou vazio → rc ≠ 0; identidade fora do formato normalizado → rc ≠ 0 mostrando o formato.
  - [ ] Cadastro repetido de identidade ativa é idempotente e não duplica a entrada; `revoke` não apaga a entrada: marca `revoked_at`, `revoked_by` e `revoke_reason`, e a entrada revogada deixa de liberar destino; `revoke` de identidade inexistente ou já revogada → rc ≠ 0; `allow` de identidade revogada cria entrada ativa nova e preserva a revogada.
  - [ ] O arquivo fica no repositório principal (versionável e revisável em PR); o local exato é decisão de design.
  - [ ] `doctor` avisa (sem reprovar): participante de canal cujo `peer-path` resolve para outro workspace não cadastrado; participante sem `peer-path` configurado, como "não verificável"; e workspace cadastrado ativo que não corresponde a nenhum participante. Participante no mesmo workspace não gera aviso.
  - [ ] A documentação diz que o cadastro vale só para a saída, que os dois lados precisam cadastrar para conversar, que remote com alias SSH (`git@<alias>:owner/repo`) gera identidade com o alias como host e deve ser cadastrado assim, e registra o limite: a contenção protege contra liberação induzida pelo próprio fluxo e torna qualquer contorno visível no push, no doctor e no PR; ela não é fronteira de segurança contra um agente determinado rodando como o mesmo usuário do sistema, papel que só a configuração gerenciada do Claude Code cumpre (REQ-09).
- **Rastreia:** proposal §2.7 (decisão C3 refinada; causa raiz decidida pelo dono na rodada 2)

## Requisitos não funcionais do change

- **NFR-01 —** O gancho de saída completa em ≤ 300 ms no p95 por chamada, sobre uma fixture de registro de sessões com 20 entradas e um workspace de fixture com repositório aninhado e worktree. Método: 50 execuções por caso do REQ-05, medidas com `node:perf_hooks`; fonte: relatório de verificação. A medição na máquina real (18 sessões em 2026-10-30) é informativa, não critério.
- **NFR-02 —** Zero dependência nova de runtime: bash, node (built-ins), git e o mesmo fallback `jq`/`python3` dos ganchos existentes. Método: diff de `package.json` vazio e varredura de `require`/`import` nos arquivos novos.
- **NFR-03 —** TDD: cada REQ tem ao menos um gate em `tests/` escrito e visto vermelho antes da implementação. Método: commit do teste vermelho anterior ao da implementação, conferido no `verify`.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | `notify <channel> <msg_id> --to <destino>` | CLI `liaison-ops.sh notify` | TASK-03, TASK-04, TASK-05 |
| REQ-02 | `--via cross-session`, `--native-ref`, `--session` | CLI `liaison-ops.sh send` | TASK-08, TASK-09 |
| REQ-03 | sem parâmetro exposto (comportamento de recusa do `send`) | CLI `liaison-ops.sh send` | TASK-08, TASK-09 |
| REQ-04 | sem parâmetro exposto (padrões vêm de `secret-scan.mjs`) | gancho PreToolUse `SendMessage` | TASK-14, TASK-15 |
| REQ-05 | sem parâmetro exposto | gancho PreToolUse `SendMessage` | TASK-14, TASK-15 |
| REQ-06 | linha `liaison:<channel>/<msg_id>`; primeira linha `ephemeral: <class>` | corpo do `SendMessage` | TASK-16, TASK-17 |
| REQ-07 | sem parâmetro próprio (usa REQ-12); desligar o gancho pelo `hooks.manifest` é mudança de contenção detectada pelo REQ-12 | gancho PreToolUse `SendMessage` | TASK-16, TASK-17 |
| REQ-08 | `native check [--session <id>]`; `native dispose <fingerprint> --ephemeral <class>` | CLI `liaison-ops.sh native`; ganchos `SessionEnd` e `SessionStart` | TASK-10, TASK-11 |
| REQ-10 | linha do gancho em `hooks.manifest` (matcher, contrato, estado) | `hooks.manifest` do consumidor | TASK-18, TASK-19 |
| REQ-12 | `native allow <id> --reason`, `native revoke <id> --reason` (só fora de sessão de agente); chaves `allowed_workspaces` e `self_identity` | CLI `liaison-ops.sh native` em terminal humano; arquivo de configuração versionado; `pre-push`, `doctor`, `/forge:prepare-pr`, `/forge:ship` | TASK-12, TASK-13, TASK-20, TASK-21 |

## Fora de escopo (reafirmação)

- Formato do store, transporte, import e cálculo de `trust` existentes.
- Coordenação substantiva entre sessões do mesmo repositório como material de liaison (ela usa `internal-coordination`).
- Espelhamento automático de mensagens nativas no liaison.
- Envio de `SendMessage` por script ou gancho.
- Bloqueio de mensagens recebidas (não existe evento de hook para isso; a proteção da entrada é o modo de permissão do Claude Code e a regra de dado não confiável).
- Bastão de handoff de dono único (próximo change da rodada).
- Alteração de configuração de permissão do Claude Code do usuário.
