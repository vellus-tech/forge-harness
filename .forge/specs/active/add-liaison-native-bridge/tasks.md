# Tasks — add-liaison-native-bridge

> Tasks do change `add-liaison-native-bridge`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task declara `Teste (comando)` e `Padrão de falha`.

## Como os pares vermelho → verde são operados

- Cada par é uma task de gate vermelho (`test(...)`) seguida da task de implementação (`feat(...)`), e o commit do verde é **filho direto** do commit do vermelho (senão a prova reprova `[topologia]`). A prova mecânica é `red-evidence.sh task` com `--red <sha do vermelho> --green <sha do verde>` sobre o `Teste (comando)` da task do verde; por isso a task do verde repete o `Padrão de falha` específico da task do vermelho.
- O commit do vermelho só traz arquivos em `tests/` (stub em `template/.forge/scripts/` conta como infraestrutura e reprova `[vermelho-infra]`). A marca `[X]` no `tasks.md` e o `status` da story também ficam fora do par (todo caminho `.forge/...` é infraestrutura para o `red-evidence`): vão num commit `chore(spec)` depois do verde, medido na Wave 1.
- O gate vermelho emite linhas `FAIL [n] <motivo>` por asserção e não pode quebrar por módulo ausente (importar o módulo novo dentro de `try`/checar existência antes e reportar `FAIL [n] ... ausente`), senão cai em `[vermelho-compilacao]`/`[vermelho-padrao]`.
- Gates novos levam nome provisório sem ordinal (`tests/<nome>-gate.sh`, descobertos pelo glob do `run-all.sh`) e a linha `# ORDINAL: wNNN atribuído na hora do merge` no cabeçalho; o número só é decidido no merge.
- Execução estritamente sequencial, na ordem em que as tasks aparecem neste arquivo (a TASK-27 vem antes da TASK-26, que é a última) (várias tasks tocam `liaison-ops.sh`, e o verde precisa ser filho direto do vermelho); nunca duas tasks em paralelo.
- Vermelho esperado fora da task: o `w200-readme-inventory-gate.sh` conta `tests/*-gate.sh` para o badge do `README.md` e fica vermelho desde o primeiro gate novo até a TASK-25, que atualiza o badge e o inventário; isso não é regressão das tasks intermediárias.
- Fixtures de transcript e registro usam `FORGE_CLAUDE_PROJECTS_DIR` e `FORGE_CLAUDE_SESSIONS_DIR` (design §2.4 passo 3 e §2.5), nunca `HOME` redirecionado.
- Exceção declarada: a TASK-03 só toca `tests/` (a checagem [10] do `w113` vive no próprio gate), então não há par provável pelo `red-evidence` (`[vermelho-vazio]`); a prova de que a checagem morde é interna ao gate: uma árvore de fixture com cada padrão proibido precisa reprovar a checagem, e a árvore real precisa passar (controle e recontrole no mesmo run).

## Wave 1 — Contratos e ponteiro canônico

- [X] TASK-01 — Gate vermelho de paridade de envelope e compatibilidade com peer v0.18.0 (tag ausente → FAIL "não verificável") (rastreia: REQ-02, design §4.1, §4.2; paths: `tests/liaison-envelope-parity-gate.sh`; depende: —)
  - Teste (comando): `bash tests/liaison-envelope-parity-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(via|cross_session|cross-session)`
- [X] TASK-02 — Schema e `validateEnvelope` aceitam `via: cross-session` e `cross_session` com as mesmas regras (rastreia: REQ-02, design §4.1; paths: `template/.forge/schemas/liaison-message.schema.json`, `template/.forge/scripts/lib/liaison-merge.mjs`; depende: TASK-01)
  - Teste (comando): `bash tests/liaison-envelope-parity-gate.sh && bash tests/w197-normative-text-parity-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(via|cross_session|cross-session)`
- [X] TASK-03 — Checagem [10] do `w113` estendida com os padrões proibidos de conexão e invocação de sessão do REQ-01, com fixture que contém cada padrão (precisa reprovar) e controle sobre a árvore real (precisa passar), sem casar `messagingSocketPath` (rastreia: REQ-01, design §2.3; paths: `tests/w113-liaison-enforce-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w113-liaison-enforce-gate.sh`
  - Padrão de falha: `FAIL \[10\]`
- [X] TASK-04 — Gate vermelho do `notify` (ponteiro idêntico ao log, recusas "não existe", "não é mensagem própria", "não publicada" com o `sync`, flags) e da fonte única de classes efêmeras e regex de declaração (rastreia: REQ-01, REQ-06, design §2.2, §2.3; paths: `tests/liaison-notify-gate.sh`; depende: —)
  - Teste (comando): `bash tests/liaison-notify-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(notify|resolvePointer|EPHEMERAL)`
- [X] TASK-05 — `native-classes.mjs`, `liaison-pointer.mjs` (`resolvePointer`), `isPublished` em `liaison-publish.mjs` e subcomando `notify` (rastreia: REQ-01, REQ-06, design §2.2, §2.3, §4.5; paths: `template/.forge/scripts/lib/native-classes.mjs`, `template/.forge/scripts/lib/liaison-pointer.mjs`, `template/.forge/scripts/lib/liaison-publish.mjs`, `template/.forge/scripts/liaison-ops.sh`; depende: TASK-04)
  - Teste (comando): `bash tests/liaison-notify-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(notify|resolvePointer|EPHEMERAL)`

## Wave 2 — Leitores compartilhados (transcript, registro, workspace)

- [X] TASK-06 — Gate vermelho dos leitores. Transcript: recepção pela tag com `from` `uds:` e `origin` só como conferência (design §2.6), fingerprints fixos da evidência b, controle embutido, candidata sem extração = instrumento quebrado, linha `api-request-shape` sozinha = nada pendente, controles negativos medidos (`origin.kind` `human`/`task-notification`/`coordinator`, `turnOrigin: "scheduled"`, `<agent-message>` com `origin.kind: "peer"`, turno humano que só cita a tag) = nada pendente, recepção sem `origin.body` extraída, formatos derivados, divergência tag × `origin` = instrumento quebrado. Registro: vivo/morto (pid e socket), ilegível, sem campo, homônimo, resolução por nome, por socket e por `sessionId` (registro da própria sessão), `/tmp` vs `/private/tmp`. Workspace: raiz (aninhado, worktree fora da árvore, home como repositório, fora de repositório), identidade (dois clones com `insteadOf`, forma scp, credencial, porta, sem remote) (rastreia: REQ-02, REQ-07, REQ-08, design §2.2, §2.5, §2.6; paths: `tests/native-readers-gate.sh`; depende: TASK-05)
  - Teste (comando): `bash tests/native-readers-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(transcript|registry|workspace)`
- [X] TASK-07 — `native-transcript.mjs`, `native-registry.mjs` e `native-workspace.mjs` (rastreia: REQ-02, REQ-07, REQ-08, design §2.2, §2.5, §2.6; paths: `template/.forge/scripts/lib/native-transcript.mjs`, `template/.forge/scripts/lib/native-registry.mjs`, `template/.forge/scripts/lib/native-workspace.mjs`; depende: TASK-06)
  - Teste (comando): `bash tests/native-readers-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(transcript|registry|workspace)`

## Wave 3 — Entrada: registro e diagnóstico de cobertura

- [X] TASK-08 — Gate vermelho de `send --via cross-session` e da recusa C1 (flags, fingerprint ausente, instrumento quebrado, tetos, caracteres de controle, segredo nos valores extraídos e no corpo, conferência de origem com os casos diverge/não resolve/ok/peer em worktree/pid divergente de `verifiedPeerPid`, hash de `liaison.yaml`/log/blobs/cursor antes e depois, nada criado como efeito colateral, `check-liaison-acks.sh`, `inbox --show` com "origem não verificada", `render`) (rastreia: REQ-02, REQ-03, design §2.4; paths: `tests/liaison-cross-session-record-gate.sh`; depende: TASK-02, TASK-07)
  - Teste (comando): `bash tests/liaison-cross-session-record-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(cross-session|native-ref|C1|origem)`
- [X] TASK-09 — `send` com `--via cross-session`, `--native-ref`, `--session`; recusa C1; conferência de origem; exibição em `inbox --show` e `render` (rastreia: REQ-02, REQ-03, design §2.4; paths: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/lib/liaison-render.mjs`; depende: TASK-08)
  - Teste (comando): `bash tests/liaison-cross-session-record-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(cross-session|native-ref|C1|origem)`
- [X] TASK-10 — Gate vermelho do diagnóstico `native check`/`native dispose` (destinação por registro e por `dispose`, classes, outro workspace e workspace desconhecido, moldura, `--session`/`--transcript`/ambiente e recusa sem sessão, persistência fora da árvore e entrega única com lista curta de relatórios, fiação de `SessionEnd` em `sync-adapters.mjs` e comportamento de `on-session-end.sh` nas quatro combinações de `handoff.auto`/`liaison.auto`, exibição no `on-session-start.sh`) (rastreia: REQ-08, design §2.6; paths: `tests/native-coverage-gate.sh`; depende: TASK-09)
  - Teste (comando): `bash tests/native-coverage-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(native check|dispose|SessionEnd|session-start)`
- [X] TASK-11 — `native check`, `native dispose`, estado local em `<git-common-dir>/forge-native/`, fiação `SessionEnd` por `handoff.auto` OU `liaison.auto`, `on-session-end.sh` e `on-session-start.sh` (rastreia: REQ-08, design §2.6; paths: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/lib/sync-adapters.mjs`, `template/.forge/hooks/session/on-session-end.sh`, `template/.forge/hooks/session/on-session-start.sh`; depende: TASK-10)
  - Teste (comando): `bash tests/native-coverage-gate.sh && bash tests/w62-handoff-hook-gate.sh && bash tests/w215-hook-wiring-derived-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(native check|dispose|SessionEnd|session-start)`

## Wave 4 — Saída: cadastro, detector e gancho

- [X] TASK-12 — Gate vermelho do cadastro e do detector: recusa do CLI `allow`/`revoke`/`pin` por cada marcador e por ancestral `claude`; lógica de escrita (idempotência, revogação, reativação, `self_identity`, formato, `--reason`) exercitada pela API de `native-allowlist.mjs`; caminho completo do CLI uma vez com `env -i` e um `ps` de fixture à frente do `PATH` (design §2.7, achado A-01 do analyze); cadastro efetivo só commitado; schema; detector `native containment` nos quatro tipos e no caso sem mudança, rc 2 quando não mede; `hook-unwired` pela derivação de `preToolUseWiring` com controle negativo de consumidor existente semeado inativo (nenhum achado) e por intervalo quando a fiação some do `settings.json` entre as pontas; `hooks.manifest` de consumidor corrompido (derivação `unresolved`) → rc 2, nunca "nada mudou" (rastreia: REQ-12, design §2.7, §4.3; paths: `tests/native-containment-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/native-containment-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(allow|revoke|pin|containment|hook-unwired)`
- [X] TASK-13 — `native-allowlist.mjs`, `native-containment.mjs`, schema `liaison-allowed-workspaces.schema.json` e subcomandos `native allow|revoke|pin|containment` (rastreia: REQ-12, design §2.7, §4.3; paths: `template/.forge/scripts/lib/native-allowlist.mjs`, `template/.forge/scripts/lib/native-containment.mjs`, `template/.forge/schemas/liaison-allowed-workspaces.schema.json`, `template/.forge/scripts/liaison-ops.sh`; depende: TASK-12)
  - Teste (comando): `bash tests/native-containment-gate.sh && bash tests/w30-schemas-gate.sh && bash tests/w215-hook-wiring-derived-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(allow|revoke|pin|containment|hook-unwired)`
- [X] TASK-14 — Gate vermelho do gancho de saída, parte 1 (classificação e segredo): os payloads da evidência a com os vereditos do REQ-05 (`main`, agentId, nome com registro único, `uds:`, só aviso de ociosidade, `[ref]`, nome sem registro com e sem `Agent` nomeado no transcript, nome de sessão igual a `Agent` nomeado, `*`/vírgula/quebra de linha, `recipient_kind` desconhecido); cada família de `SECRET_PATTERNS` → exit 2 sem eco; segredo em campo aninhado e em array; payload vazio, malformado e sem corpo → exit 2; teste de leitor único que altera um padrão de `secret-scan.mjs` e vê `send` e gancho mudarem juntos. Para destino de sessão com corpo limpo, o gate observa a classificação por uma saída que não depende das etapas 5 e 6 (a função de classificação exportada pelo módulo, ou o mesmo payload com segredo dando exit 2 pelo segredo), porque o exit final desses casos muda quando a TASK-17 entra (rastreia: REQ-04, REQ-05, design §2.5 etapas 1 a 4; paths: `tests/native-send-guard-gate.sh`; depende: TASK-05, TASK-07, TASK-13)
  - Teste (comando): `bash tests/native-send-guard-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(guard|gancho|recipient|secret)`
- [X] TASK-15 — `native-send-guard.mjs` (etapas 1 a 4) e `hooks/pre-tool-use/guard-cross-session-send.sh`; o estado intermediário (destino de sessão sem contenção nem destino declarado) nunca é fiado nem publicado, porque a linha do manifesto só entra na TASK-19 e a branch não é publicada antes do fim do change (rastreia: REQ-04, REQ-05, NFR-02, design §2.5; paths: `template/.forge/scripts/lib/native-send-guard.mjs`, `template/.forge/hooks/pre-tool-use/guard-cross-session-send.sh`; depende: TASK-14)
  - Teste (comando): `bash tests/native-send-guard-gate.sh && bash tests/w113-liaison-enforce-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(guard|gancho|recipient|secret)`
- [X] TASK-16 — Gate vermelho do gancho de saída, parte 2 (contenção e destino declarado) e gate de desempenho: contenção (mesmo repositório, worktree fora da árvore, aninhado, outro workspace com e sem cadastro, cadastro só não commitado, `self_identity` divergente, homônimo, sem registro, registro ilegível, pid morto, `/tmp` vs `/private/tmp`, home como repositório, dois clones com `insteadOf`, caso `forge-harness` → `payments` com exit 2 sem cadastro e exit 0 com cadastro, mensagem sem comando pronto e sem sugerir mexer em manifesto/settings); origem cruzada com o registro da própria sessão (`session_id` do payload com registro cujo workspace difere do `cwd` do payload → exit 2 "origem ambígua"; sem registro próprio → vale o `cwd` do payload); destino declarado (ponteiro válido, inexistente, de peer, não publicado, em worktree, destino não participante verificável e inconclusivo, classes válidas e inválidas, declaração fora da primeira linha, `internal-coordination` no mesmo repositório e entre repositórios, teto de 1024 bytes do texto livre, sem declaração); p95 ≤ 300 ms em 50 execuções por caso do REQ-05 sobre registro de 20 sessões (rastreia: REQ-06, REQ-07, NFR-01, design §2.5 etapas 5 e 6; paths: `tests/native-send-guard-gate.sh`, `tests/native-send-guard-perf-gate.sh`; depende: TASK-15)
  - Teste (comando): `bash tests/native-send-guard-gate.sh && bash tests/native-send-guard-perf-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(contenção|workspace|ponteiro|ephemeral|origem|p95)`
- [X] TASK-17 — Etapas 5 e 6 de `native-send-guard.mjs` (contenção, origem cruzada, destino declarado) e caches por execução (rastreia: REQ-06, REQ-07, NFR-01, design §2.5; paths: `template/.forge/scripts/lib/native-send-guard.mjs`; depende: TASK-16)
  - Teste (comando): `bash tests/native-send-guard-gate.sh && bash tests/native-send-guard-perf-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(contenção|workspace|ponteiro|ephemeral|origem|p95)`

## Wave 5 — Fiação: empacotamento e pontos de detecção

- [X] TASK-18 — Gate vermelho de empacotamento do gancho: linha do manifesto, fiação derivada sem literal novo em `sync-adapters.mjs`, consumidor com `settings.json` recebe inativo e nomeado, instalação nova recebe armado; passo de armar do §5 num consumidor existente mantém os quatro ganchos atuais fiados (com matcher e contrato efetivos) e arma o novo; manifesto sem marcador com só a linha nova não arma (controle); varredura de imports dos arquivos novos só `node:*`/relativos e `package.json` sem dependência nova (rastreia: REQ-10, NFR-02, design §4.4, §5; paths: `tests/native-hook-packaging-gate.sh`; depende: TASK-17)
  - Teste (comando): `bash tests/native-hook-packaging-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(manifest|armado|inativo|SendMessage|import)`
- [X] TASK-19 — Linha do gancho em `hooks.manifest.default` e ajustes nos gates de manifesto existentes (rastreia: REQ-10, design §4.4; paths: `template/.forge/hooks/pre-tool-use/hooks.manifest.default`; depende: TASK-18)
  - Teste (comando): `bash tests/native-hook-packaging-gate.sh && bash tests/w208-hooks-manifest-esquema-gate.sh && bash tests/w215-hook-wiring-derived-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(manifest|armado|inativo|SendMessage|import)`
- [X] TASK-20 — Gate vermelho dos pontos de detecção: pre-push lista as mudanças do intervalo sem bloquear; doctor reporta os quatro tipos, os avisos de cruzamento de participantes e os avisos extras (gancho inativo, `self_identity` ausente, `disableAllHooks`, sobreposição de settings, edição não commitada, cadastro do `HEAD` diferente do upstream); cenário do revisor (recusa do CLI, edição direta + push visível nos três pontos); gate de texto: `prepare-pr.md` e `ship.md` (template e plugin) invocam o detector, e `ship.md` (template e plugin), `yolo-gate.md` e `autonomy-yolo.md` exigem merge humano com mudança de contenção (rastreia: REQ-12, design §2.7, §4.3; paths: `tests/native-containment-wiring-gate.sh`; depende: TASK-13, TASK-19)
  - Teste (comando): `bash tests/native-containment-wiring-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(pre-push|doctor|prepare-pr|ship|yolo)`
- [X] TASK-21 — Detector fiado em `hooks/git/pre-push`, `doctor.sh`, `prepare-pr.md`, `ship.md`, `doctor.md`, `yolo-gate.md`, `autonomy-yolo.md` e cópias do plugin (rastreia: REQ-12, design §2.7; paths: `template/.forge/hooks/git/pre-push`, `template/.forge/scripts/doctor.sh`, `template/.forge/commands/harness/prepare-pr.md`, `template/.forge/commands/git/ship.md`, `template/.forge/commands/harness/doctor.md`, `template/.forge/agents/review/yolo-gate.md`, `template/.forge/rules/conventions/autonomy-yolo.md`, `plugin/forge/commands/`; depende: TASK-20)
  - Teste (comando): `bash tests/native-containment-wiring-gate.sh && bash tests/plugin-sync-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(pre-push|doctor|prepare-pr|ship|yolo)`

## Wave 6 — Normas, documentação e baseline

- [X] TASK-22 — Gate vermelho das normas: classes da rule = `EPHEMERAL_CLASSES` com mutação dos dois lados; frases normativas obrigatórias do design §2.8; `validate-rules.sh` com `FORGE_ROOT` no template; `last_reviewed` atualizado; itens de ledger com origem no change, lidos de `.forge/ledger/ledger.json` da worktree (configuração gerenciada PCI; medição do formato de agente nomeado; ADR "mensageria nativa é sinalização" sugerida no design §10, aceito aberto ou resolvido, porque a TASK-27 o resolve) (rastreia: REQ-09, design §2.2, §2.8, §10; paths: `tests/native-rules-parity-gate.sh`; depende: TASK-05)
  - Teste (comando): `bash tests/native-rules-parity-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(rule|classes|ledger|last_reviewed)`
- [X] TASK-23 — `liaison-protocol.md` e `liaison-untrusted-input.md` atualizadas e os três itens de ledger abertos com `FORGE_ROOT=<worktree>` (o ledger escrito e lido pelo gate é o da branch, `.forge/ledger/` desta worktree, commitado na task; o tronco nunca é tocado — afastamento declarado da rule `machinery-propagation` ("estado de projeto mora no tronco"), que segue a prática do dogfood de levar o ledger ao tronco pelo PR, e é a única forma de cumprir o limite desta execução de não tocar o checkout principal) (rastreia: REQ-09, design §2.8, §10; paths: `template/.forge/rules/conventions/liaison-protocol.md`, `template/.forge/rules/conventions/liaison-untrusted-input.md`, `.forge/ledger/`; depende: TASK-22)
  - Teste (comando): `bash tests/native-rules-parity-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(rule|classes|ledger|last_reviewed)`
- [ ] TASK-24 — Gate vermelho de documentação: `argument-hint` com os subcomandos novos; flags do bloco de protocolo = flags aceitas do script por subcomando novo ou alterado; `send` cross-session sem flags de origem; `slash-commands.md`; `CHANGELOG.md` com o passo de armar; `upgrade.md` template e plugin; ponteiro na primeira linha documentado (rastreia: REQ-11, REQ-10, design §4.5, §5; paths: `tests/native-docs-gate.sh`; depende: TASK-21)
  - Teste (comando): `bash tests/native-docs-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(argument-hint|flags|CHANGELOG|slash-commands|upgrade)`
- [ ] TASK-25 — Documentação: `/forge:liaison` (template e plugin), `upgrade.md` (template e plugin), `docs/refer/slash-commands.md`, inventário de gates e scripts, `CHANGELOG.md` `[Unreleased]`, badge do `README.md` (rastreia: REQ-11, REQ-10, design §5; paths: `template/.forge/commands/harness/liaison.md`, `template/.forge/commands/harness/upgrade.md`, `plugin/forge/commands/liaison.md`, `plugin/forge/commands/upgrade.md`, `docs/`, `CHANGELOG.md`, `README.md`; depende: TASK-24)
  - Teste (comando): `bash tests/native-docs-gate.sh && bash tests/w200-readme-inventory-gate.sh && bash tests/plugin-sync-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\].*(argument-hint|flags|CHANGELOG|slash-commands|upgrade)`
- [X] TASK-27 — ADR "Mensageria nativa entre sessões é sinalização; o registro durável é o liaison" no baseline, no protocolo do `/forge:adr` (constitution §9; design §10; achado A-03 do analyze), com índice atualizado e o item de ledger correspondente resolvido (rastreia: REQ-09, design §10; paths: `.forge/product/current/adr/`, `.forge/ledger/`; depende: TASK-23)
  - Teste (comando): `FORGE_ROOT="$(pwd)" bash template/.forge/scripts/validate-spec.sh add-liaison-native-bridge && grep -q 'Mensageria nativa' .forge/product/current/adr/README.md`
  - Padrão de falha: `(FAIL|^$)`
- [ ] TASK-26 — `spec-delta.yaml` real do change (requisitos novos da capacidade `forge-harness-template`) e suíte completa verde, rodada sem outro gate em paralelo (rastreia: REQ-01..REQ-12, NFR-03; paths: `.forge/specs/active/add-liaison-native-bridge/spec-delta.yaml`; depende: TASK-02, TASK-03, TASK-11, TASK-17, TASK-21, TASK-25, TASK-27)
  - Teste (comando): `FORGE_ROOT="$(pwd)" bash template/.forge/scripts/validate-spec.sh add-liaison-native-bridge && bash tests/run-all.sh`
  - Padrão de falha: `(FAIL|placeholder)`

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 | TASK-03, TASK-04, TASK-05 |
| REQ-02 | TASK-01, TASK-02, TASK-06, TASK-07, TASK-08, TASK-09 |
| REQ-03 | TASK-08, TASK-09 |
| REQ-04 | TASK-14, TASK-15 |
| REQ-05 | TASK-14, TASK-15 |
| REQ-06 | TASK-04, TASK-05, TASK-16, TASK-17 |
| REQ-07 | TASK-06, TASK-07, TASK-16, TASK-17 |
| REQ-08 | TASK-06, TASK-07, TASK-10, TASK-11 |
| REQ-09 | TASK-22, TASK-23, TASK-27 |
| REQ-10 | TASK-18, TASK-19, TASK-24, TASK-25 |
| REQ-11 | TASK-24, TASK-25 |
| REQ-12 | TASK-12, TASK-13, TASK-20, TASK-21 |
| NFR-01 | TASK-16, TASK-17 |
| NFR-02 | TASK-18, TASK-19 |
| NFR-03 | todos os pares vermelho → verde (TASK-03 com prova interna ao gate) |
| design §2.2 (módulos) | TASK-05, TASK-07, TASK-13, TASK-15, TASK-17 |
| design §2.3 | TASK-03, TASK-04, TASK-05 |
| design §2.4 | TASK-08, TASK-09 |
| design §2.5 | TASK-14, TASK-15, TASK-16, TASK-17 |
| design §2.6 | TASK-06, TASK-07, TASK-10, TASK-11 |
| design §2.7 (inclui merge humano em ship/yolo) | TASK-12, TASK-13, TASK-20, TASK-21 |
| design §2.8, §10 | TASK-22, TASK-23, TASK-27 |
| design §4.1, §4.2 | TASK-01, TASK-02 |
| design §4.3 | TASK-12, TASK-13, TASK-20 |
| design §4.4, §5 | TASK-18, TASK-19, TASK-24, TASK-25 |
