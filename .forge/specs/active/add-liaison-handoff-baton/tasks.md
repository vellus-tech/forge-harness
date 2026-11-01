# Tasks — add-liaison-handoff-baton

> Tasks do change `add-liaison-handoff-baton`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (um commit), rastreável a um REQ/seção do design, e declara o que toca; vermelho e implementação ficam em tasks separadas, em pares (ver abaixo).
> Cada task declara `Teste (comando)` e `Padrão de falha` (e `Setup do teste`, opcional): o Red é provado por execução (`red-evidence.sh task`) e uma task sem os dois campos é marcada `[!]`, não pulada.

> **IMPLEMENTAÇÃO BLOQUEADA.** Nenhuma task deste arquivo pode começar antes de `add-liaison-native-bridge` estar mesclado em `develop`. A TASK-01 é o portão: ela fica `[!]` até a mesclagem, e todas as demais dependem dela, direta ou transitivamente. O motivo é concreto: a TASK-05 migra para a trava o `send --via cross-session` que só existe naquele change, a TASK-25 usa o `notify` dele, e o design (§1, §5) assume contratos dele (`notify`, `isPublished`, validação de `via` no `validateEnvelope`, flag `--session` do `send`) que precisam ser reconferidos contra o código mesclado.

> **Formato do vermelho.** Todo gate deste change imprime cada asserção que falha como `FAIL [<cenário>] <detalhe>` (por exemplo `FAIL [send-concorrente] seq repetido`), a assinatura que `lib/red-classify.mjs` reconhece como falha comportamental de gate shell, e o `Padrão de falha` das tasks casa com ela. Gate de função ou módulo novo não depende de stub: o commit de vermelho toca só `tests/` (código em `template/.forge/scripts/` num commit de vermelho é recusado como `vermelho-infra` pelo `red-evidence.sh task`), e o driver do gate captura a falha de import ou de export ausente e imprime `FAIL [<cenário>]` para cada asserção não executada, o que o classificador, que é comportamental primeiro, aceita como vermelho.

> **Pares vermelho/verde.** Cada task de implementação tem antes uma task de gate vermelho própria, com um gate só dela, de modo que o verde de cada implementação é provado pelo mesmo comando que provou o vermelho. As três tasks sem par (TASK-01, portão de dependência; TASK-12, regressão das suítes existentes; TASK-34, verificação final) são isentas de `red-evidence.sh task`, e a TASK-25 (aceitação ponta a ponta) tem prova própria descrita na nota dela; todas de `red-evidence.sh task` e dizem isso no próprio texto.

> **Ordinais de gate.** Os nomes `tests/wNNN-*-gate.sh` abaixo têm o ordinal em aberto de propósito: ele é atribuído com `template/.forge/scripts/gate-ordinal.sh next` no momento em que cada gate é criado, e renomeado em cascata no rebase se colidir (convenção do harness: ordinal de gate só na hora do merge). O sufixo descritivo é o identificador estável das tasks.

## Wave 0 — Portão de dependência

- [X] TASK-01 — Conferir que `add-liaison-native-bridge` está em `develop`, rebasear esta branch, reconferir os contratos usados pelo design e fazer as medições de ambiente (rastreia: design §1, §2.7, §2.8, §5; paths: `tests/liaison-baton-dependency-gate.sh`, `tests/fixtures/liaison-baton/session-identity/`, `.forge/specs/active/add-liaison-handoff-baton/design.md`; depende: —)
  - Teste (comando): `bash tests/liaison-baton-dependency-gate.sh`
  - Padrão de falha: `^FAIL \[`
  - Isenta de par vermelho/verde (portão). Concluída em 2026-11-01: `add-liaison-native-bridge` confirmado mesclado (`a86c51a6`, PR #245, ancestral de `origin/develop`); branch mesclada sobre `origin/develop` sem conflitos (c63422c7). Os quatro contratos confirmados linha a linha no código mesclado: `liaison-ops.sh notify` existe, `lib/liaison-publish.mjs` exporta `isPublished`, `lib/liaison-pointer.mjs` exporta `resolvePointer`, `validateEnvelope` valida `via` com `cross-session`, `send` aceita `--session` — todos batem com o que o design assume. Medições de ambiente (Claude Code 2.1.316, ambiente headless descartável fora de git) em `tests/fixtures/liaison-baton/session-identity/README.md`: `session_id` do `PostToolUse` ≡ `CLAUDE_CODE_SESSION_ID` (confirmado); tool de subagente DISPARA o `PostToolUse` com o `session_id` da sessão pai (mais `agent_id`/`agent_type`); `hookSpecificOutput.additionalContext` em `PostToolUse` É aceito e chega ao modelo (confirmado por eco verbatim); `--resume` preserva `session_id`; `/clear` gera `session_id` novo com `source: clear` (via `SessionStart`); compactação não medida diretamente, tratada como risco residual documentado (o design já não depende do resultado). Nenhuma divergência real dos contratos nem das suposições firmes do design: liberado para a Wave 1 sem nova rodada de `design_reviewed`.

## Wave 1 — Ordem determinística, trava do log próprio e publicação sem trava

- [X] TASK-02 — Gate vermelho do desempate de `sender` por code point sob `LANG`/`LC_ALL` variados (rastreia: REQ-04; paths: `tests/liaison-sender-order-gate.sh`; depende: TASK-01)
  - Teste (comando): `bash tests/liaison-sender-order-gate.sh`
  - Padrão de falha: `^FAIL \[ordem-sender\]`
- [X] TASK-03 — `compareSender` por code point em `threadOrder` e na escolha do `thread-open` de `mergeLogs` (rastreia: REQ-04, design §2.6.1; paths: `template/.forge/scripts/lib/liaison-merge.mjs`; depende: TASK-02)
  - Teste (comando): `bash tests/liaison-sender-order-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-04 — Gate vermelho da trava do log próprio: 20 `send` concorrentes, duas worktrees, timeout de 10 s nomeando o dono, recuperação por pid morto e por idade, dois recuperadores concorrentes mais um adquirente, trava sem `owner.json` com menos e mais de 120 s, conferência de `nonce` antes de gravar, faixa de `FORGE_LIAISON_LOCK_WAIT_MS`, nomes de trava com `@` sem colisão (canal `locks`, ids com ponto), escritores concorrentes de `state.json` e `baton-local.json` sem atualização perdida nem JSON truncado, varredura de escrita dinâmica (preload `NODE_OPTIONS=--require`) e estática (bash), trava fora do `export` e do versionamento, seção crítica ≤ 2 s p95 com 2.000 mensagens (rastreia: REQ-09, REQ-11, NFR-02; paths: `tests/wNNN-liaison-own-log-lock-gate.sh`, `tests/fixtures/liaison-lock/`; depende: TASK-01)
  - Teste (comando): `bash tests/wNNN-liaison-own-log-lock-gate.sh`
  - Padrão de falha: `^FAIL \[(send-concorrente|worktrees|recuperacao|nonce|escrita-fora|estado-local)\]`
- [ ] TASK-05 — `liaison-lock.mjs` (trava do log e travas de estado local) e `liaison-append.mjs` (`appendOwn`, `appendOwnDecided`, modo `union-own`); migração de `send`, `ack`, `thread open`, `thread join`, `conflicts resolve` e `send --via cross-session` para `appendOwn`; trava de `state.json` em `liaison-cursor.mjs` e `liaison-publish.mjs` (rastreia: REQ-09, design §2.2, §2.4; paths: `template/.forge/scripts/lib/liaison-lock.mjs`, `template/.forge/scripts/lib/liaison-append.mjs`, `template/.forge/scripts/lib/liaison-cursor.mjs`, `template/.forge/scripts/lib/liaison-publish.mjs`, `template/.forge/scripts/liaison-ops.sh`; depende: TASK-04)
  - Teste (comando): `bash tests/wNNN-liaison-own-log-lock-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-06 — Gate vermelho da publicação sem trava nos transportes de diretório (`fs`, `fs-union`, `manual`): `union-own` sob a trava, tmp do hub com nome único nos dois caminhos, limpeza de tmp órfão do próprio `self` com mais de 10 min e preservação do de outro remetente, sequência por tentativa (instantâneo, blobs, união, `mv`), conferência contra o log próprio relido depois do `mv`, prazo interno (`FORGE_LIAISON_PUSH_DEADLINE_S`) parando entre tentativas, barreira `FORGE_LIAISON_TEST_BARRIER` forçando os três cenários (push mais antigo fazendo o último `mv` e reparando; push morto entre `mv` e conferência, com restauração pelo push seguinte; `send --body-file` entre blobs e união) com contadores (≥ 1 reparo forçado, 0 no controle e no recontrole), gate estático da barreira (nenhum script a define, um único helper a lê), `markPublished({ observedFile })` gravando só o prefixo observado e podendo descer, `status` rebaixando marca acima do hub, `isPublished` recusando mensagem ausente do hub, `pulled_at` gravado pelo pull, `fs-union` recusando tronco sem os marcadores da opção C, `sync --push-only` concorrendo com 10 `send` sem mensagem perdida no log próprio nem no hub depois da última conferência, 20 repetições aleatórias de pushes concorrentes sem arquivo truncado nem quarentena em peer (rastreia: REQ-09, REQ-03, REQ-15; paths: `tests/wNNN-liaison-publish-fs-gate.sh`, `tests/fixtures/liaison-publish/`; depende: TASK-05)
  - Teste (comando): `bash tests/wNNN-liaison-publish-fs-gate.sh`
  - Padrão de falha: `^FAIL \[(union-own|tmp|ordem-tentativa|reparo|barreira|marca|pulled-at|fs-union)\]`
- [ ] TASK-07 — Publicação sem trava nos transportes de diretório: `union-own` no lugar do `cp`, tmp único e limpeza, sequência por tentativa, laço de conferência com prazo, barreira de teste e contadores, `LIAISON_OBSERVED_FILE` e `markPublished({ observedFile })`, rebaixamento no `status`, `pulled_at` em `sync-local.json`, conferência do `fs-union` por `declare -f` (rastreia: REQ-09, REQ-03, REQ-15, design §2.4; paths: `template/.forge/scripts/lib/transports/_common.sh`, `template/.forge/scripts/lib/transports/fs-union.sh`, `template/.forge/scripts/lib/liaison-publish.mjs`, `template/.forge/scripts/lib/liaison-append.mjs`, `template/.forge/scripts/liaison-ops.sh`; depende: TASK-06)
  - Teste (comando): `bash tests/wNNN-liaison-publish-fs-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-08 — Gate vermelho da publicação no transporte `git` com remoto bare local: repositório temporário por execução, `ls-remote` decidindo branch ausente e falha de rede que não vira ausência, primeira publicação por commit vazio, `add` explícito sem tmp na branch, `push HEAD:refs/heads/<branch>` sem force e laço de recusa com prazo, observação pelo commit enviado, `t_pull` por `git archive` sem checkout, dois `sync` simultâneos (push e completo) sem quarentena, limpeza de órfão só por idade preservando execução viva, falha limpa com o clone antigo apagado durante a execução, 5 repetições aleatórias (rastreia: REQ-09, REQ-15; paths: `tests/wNNN-liaison-publish-git-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/wNNN-liaison-publish-git-gate.sh`
  - Padrão de falha: `^FAIL \[(git-[a-z-]+)\]`
- [ ] TASK-09 — Transporte `git` em repositório temporário descartável por execução (rastreia: REQ-09, REQ-15, design §2.4; paths: `template/.forge/scripts/lib/transports/git.sh`, `template/.forge/scripts/lib/transports/_common.sh`; depende: TASK-08)
  - Teste (comando): `bash tests/wNNN-liaison-publish-git-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-10 — Gate vermelho do escritor de versão antiga: worktree de fixture com a maquinaria antiga gravando durante uma claim; diário do `appendOwn` gravado só depois do `rename` (gravação abortada não gera aviso); aviso no `status` e no `baton status` (este último só depois da TASK-24, coberto lá); `doctor` nomeando a worktree sem a sentinela `# forge-liaison: own-log-lock v1` e silencioso para a worktree com ela (rastreia: REQ-09, design §2.4; paths: `tests/wNNN-liaison-own-log-journal-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/wNNN-liaison-own-log-journal-gate.sh`
  - Padrão de falha: `^FAIL \[(diario|status-reescrito|doctor-worktree)\]`
- [ ] TASK-11 — Diário de gravações em `appendOwn`, conferência no `status`, sentinela no `liaison-ops.sh` e aviso no `doctor` (rastreia: REQ-09, design §2.4, §5; paths: `template/.forge/scripts/lib/liaison-append.mjs`, `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/doctor.sh`; depende: TASK-10)
  - Teste (comando): `bash tests/wNNN-liaison-own-log-journal-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-12 — Todos os gates existentes do liaison verdes depois da troca de desempate, da trava e da publicação sem trava (rastreia: REQ-11; paths: —; depende: TASK-03, TASK-09, TASK-11)
  - Teste (comando): `for g in tests/*liaison*-gate.sh; do bash "$g" || { echo "FAIL [$g] regressão"; exit 1; }; done`
  - Padrão de falha: `^FAIL \[`
  - Isenta de par vermelho/verde (regressão de suítes existentes).

## Wave 2 — Forma da mensagem e dobra

- [ ] TASK-13 — Gate vermelho da forma em duas camadas: paridade schema × `validateEnvelope` na camada de envelope, bateria do `validateBaton` (um caso por regra, inclusive aritmética do lease e `in_reply_to`), `content_sha` cobrindo `baton`, fonte única de `op`/estados/vereditos/flags por verbo, compatibilidade com o import da última tag sem `baton` e aceitação de `op` desconhecido pelo import deste harness (rastreia: REQ-01, REQ-11; paths: `tests/wNNN-liaison-baton-envelope-gate.sh`, `tests/fixtures/liaison-baton/envelopes/`; depende: TASK-12)
  - Teste (comando): `bash tests/wNNN-liaison-baton-envelope-gate.sh`
  - Padrão de falha: `^FAIL \[(paridade|validate-baton|content-sha|fonte-unica|compat)\]`
- [ ] TASK-14 — `liaison-baton.mjs` (`BATON_OPS`, `BATON_STATES`, `BATON_VERDICTS`, `BATON_VERB_FLAGS`, `validateBaton`), camada de envelope do `baton` e `BATON_OP_PATTERN` em `liaison-merge.mjs`, propriedade `baton` no schema e nota de `stamped_at` na descrição de `created_at` (rastreia: REQ-01, design §2.2, §2.3, §4.1; paths: `template/.forge/scripts/lib/liaison-baton.mjs`, `template/.forge/scripts/lib/liaison-merge.mjs`, `template/.forge/schemas/liaison-message.schema.json`; depende: TASK-13)
  - Teste (comando): `bash tests/wNNN-liaison-baton-envelope-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-15 — Gate vermelho da dobra e da estabilidade: um caso por linha da tabela do REQ-04 (inclusive `wrong-thread`, `before-offer`, `not-an-offer`, `forked` em threads diferentes e `malformed` por `op` desconhecido), desempate, 200 permutações, duas réplicas em ordens diferentes, `provisional`/`stable` com três repositórios, buraco de `seq`, `eligible` restrito, `detectClockSkew` ignorando mensagens com `baton` e mantendo o aviso para as demais, dobra ≤ 500 ms p95 com 2.000 mensagens (rastreia: REQ-04, REQ-05, REQ-06, NFR-02; paths: `tests/wNNN-liaison-baton-fold-gate.sh`, `tests/fixtures/liaison-baton/fold/`; depende: TASK-14)
  - Teste (comando): `bash tests/wNNN-liaison-baton-fold-gate.sh`
  - Padrão de falha: `^FAIL \[(veredito-[a-z-]+|permutacao|replicas|stable|clock-skew|perf-dobra)\]`
- [ ] TASK-16 — `foldBatons` e `stability` em `liaison-baton.mjs`; `detectClockSkew` ignorando mensagens com `baton` (rastreia: REQ-04, REQ-05, REQ-06, design §2.3, §2.5, §2.6; paths: `template/.forge/scripts/lib/liaison-baton.mjs`, `template/.forge/scripts/lib/liaison-merge.mjs`; depende: TASK-15, TASK-03)
  - Teste (comando): `bash tests/wNNN-liaison-baton-fold-gate.sh`
  - Padrão de falha: `^FAIL \[`

## Wave 3 — CLI `baton`

- [ ] TASK-17 — Gate vermelho de configuração e identidade de sessão: defaults, faixas inválidas nomeando a chave e afetando só `offer`/`claim`, parâmetros da oferta prevalecendo sobre a configuração local, `--session`/`CLAUDE_CODE_SESSION_ID`, padrão do identificador, duas sessões do mesmo repositório como titulares diferentes (rastreia: REQ-06, REQ-10; paths: `tests/wNNN-liaison-baton-config-gate.sh`; depende: TASK-16)
  - Teste (comando): `bash tests/wNNN-liaison-baton-config-gate.sh`
  - Padrão de falha: `^FAIL \[(config-[a-z-]+|session-[a-z-]+)\]`
- [ ] TASK-18 — `readBatonConfig`, sub-bloco `liaison.baton` comentado no `forge.yaml` do template, resolução e validação de `session` no `liaison-ops.sh` (rastreia: REQ-06, REQ-10, design §2.6, §2.7; paths: `template/.forge/scripts/lib/liaison-baton.mjs`, `template/.forge/forge.yaml`, `template/.forge/scripts/liaison-ops.sh`; depende: TASK-17)
  - Teste (comando): `bash tests/wNNN-liaison-baton-config-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-19 — Gate vermelho de `offer` e `claim`: oferta sem reivindicação implícita, recusas sem gravar (thread só interna, `--for` fora da thread, `eligible` só com o próprio), `eligible` gravado, 10 `claim` concorrentes de 10 sessões, pré-condições de `claim`, redução do lease ao máximo da oferta, `lost-held` na folga, aviso de `sync` antes de tomada por vencimento contra titular de outro repositório quando `pulled_at` é anterior ao `lease_until` dela (e ausente sem `pulled_at` recente); escopo de escrita, `check-liaison-acks.sh` e `trust` sobre fixture de três repositórios, `sender` adulterado no import (rastreia: REQ-02, REQ-03, REQ-11; paths: `tests/wNNN-liaison-baton-claim-gate.sh`, `tests/fixtures/liaison-baton/three-repos/`; depende: TASK-18, TASK-07)
  - Teste (comando): `bash tests/wNNN-liaison-baton-claim-gate.sh`
  - Padrão de falha: `^FAIL \[(offer-[a-z-]+|claim-[a-z-]+|acks|trust|import-sender)\]`
- [ ] TASK-20 — Verbos `offer` e `claim` lendo `BATON_VERB_FLAGS`, `liaison-baton-local.mjs` (claims vencedoras, índice de titulares, `next_renew_at`), aviso de tomada com `pulled_at`, saída com `sync` e `notify` (rastreia: REQ-02, REQ-03, REQ-15, design §2.2, §2.7; paths: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/lib/liaison-baton.mjs`, `template/.forge/scripts/lib/liaison-baton-local.mjs`; depende: TASK-19)
  - Teste (comando): `bash tests/wNNN-liaison-baton-claim-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-21 — Gate vermelho de `renew`, `release`, `complete`, `withdraw`: titular com lease vencido (sem `renew`, com `claim` de retomada, com `release`/`complete`), retirada com titular sumida além da folga, recusas sem gravar nomeando a titular, expiração, liberação, conclusão e retirada distinguíveis no estado e no histórico, `renew` sem `--lease` mantendo o prazo vigente, aviso de `sync --push-only` após `renew` manual, corpos com varredura de segredo (rastreia: REQ-06, REQ-07; paths: `tests/wNNN-liaison-baton-lifecycle-gate.sh`; depende: TASK-20)
  - Teste (comando): `bash tests/wNNN-liaison-baton-lifecycle-gate.sh`
  - Padrão de falha: `^FAIL \[(renew|release|complete|withdraw)-[a-z-]+\]`
- [ ] TASK-22 — Verbos `renew`, `release`, `complete`, `withdraw` (rastreia: REQ-06, REQ-07, design §2.7; paths: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/lib/liaison-baton-local.mjs`; depende: TASK-21)
  - Teste (comando): `bash tests/wNNN-liaison-baton-lifecycle-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-23 — Gate vermelho de consulta e diagnóstico: `baton status`/`list` texto e `--json` (formato fixado por fixture), órfãs, moldura `untrusted-render`, linha de bastões no `status` geral, `CHANNEL.md` com `op`/`session`/`stamped_at`/veredito e idêntico byte a byte sob relógios diferentes, rótulo `expired` e aviso de carimbo no futuro só fora do `CHANNEL.md`, perda tardia com duas réplicas, aviso de log próprio reescrito no `baton status` (cenário da TASK-10), `inbox` e `inbox --titles-only` condensando 30 renovações de peer numa linha por bastão com o cursor avançando sobre elas (rastreia: REQ-05, REQ-06, REQ-08, REQ-09; paths: `tests/wNNN-liaison-baton-status-gate.sh`, `tests/fixtures/liaison-baton/status/`; depende: TASK-22, TASK-11)
  - Teste (comando): `bash tests/wNNN-liaison-baton-status-gate.sh`
  - Padrão de falha: `^FAIL \[(status-[a-z-]+|list-[a-z-]+|render-[a-z-]+|perda-tardia|inbox-condensado|reescrito)\]`
- [ ] TASK-24 — Verbos `status` e `list`, linha de bastões no `status` geral, mensagens de bastão no `liaison-render.mjs`, aviso de carimbo no futuro, detecção de perda tardia, aviso de reescrita no `baton status`, condensação de `renew` no `inbox` (rastreia: REQ-05, REQ-06, REQ-08, design §2.5, §2.6, §2.7, §2.9; paths: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/lib/liaison-render.mjs`, `template/.forge/scripts/lib/liaison-baton-local.mjs`; depende: TASK-23)
  - Teste (comando): `bash tests/wNNN-liaison-baton-status-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-25 — Gate de aceitação ponta a ponta, escrito vermelho antes dos verbos: oferta, duas reivindicações concorrentes, renovação, liberação, nova reivindicação e conclusão entre duas réplicas com transporte `fs`, com e sem `notify`, mesmo resultado; ponteiro do `notify` aceito pelo gancho de saída do change dependente e `notify` sobre oferta não publicada recusado como antes; checagem do `w113` sobre os arquivos novos (rastreia: REQ-15, REQ-03, REQ-05; paths: `tests/wNNN-liaison-baton-e2e-gate.sh`; depende: TASK-18)
  - Teste (comando): `bash tests/wNNN-liaison-baton-e2e-gate.sh`
  - Padrão de falha: `^FAIL \[e2e-[a-z-]+\]`
  - Nota: escrito e visto vermelho logo depois da TASK-18, antes da TASK-20; fica verde quando a TASK-24 termina, sem task de implementação própria (a implementação é a das TASK-20, TASK-22 e TASK-24). Isenta de `red-evidence.sh task` (o verde não é filho direto do vermelho, o que a checagem de topologia recusaria): a prova é a saída do gate registrada em `evidence/` no commit da TASK-25 (vermelho) e no commit da TASK-24 (verde), conferidas no `verify`.

## Wave 4 — Ciclo de vida

- [ ] TASK-26 — Gate vermelho da renovação automática: fiação `PostToolUse` nas quatro combinações de `liaison.auto` e `auto_renew` e para consumidor com `settings.json` pré-existente, desligar e religar sem duplicar nem deixar órfão, 50 eventos seguidos e 10 eventos concorrentes com exatamente uma renovação, só a sessão do evento, nunca lease vencido, cache invalidado após `claim` e após `renew --lease 60`, perda tardia importada limpando o cache, configuração inválida avisando só fora do caminho rápido, `sync --push-only` destacado com transporte travado (FIFO) sem prender o evento, nenhum descendente vivo após o vigia (`pgrep -g`), `publish-result-<pid>.json` notado pelo caminho rápido, JSON `additionalContext` emitido uma vez para perda, falha de publicação e configuração inválida, transporte `manual`/`gh` com aviso, rc 0 sempre, p95 ≤ 150 ms nos caminhos sem bastão e fora da hora e ≤ 2,5 s no caminho que renova (rastreia: REQ-12, NFR-02; paths: `tests/wNNN-liaison-baton-auto-renew-gate.sh`; depende: TASK-24)
  - Teste (comando): `bash tests/wNNN-liaison-baton-auto-renew-gate.sh`
  - Padrão de falha: `^FAIL \[(fiacao-[a-z-]+|renova-[a-z-]+|cache-[a-z-]+|destacado-[a-z-]+|aviso-[a-z-]+|perf-[a-z-]+)\]`
- [ ] TASK-27 — `hooks/session/on-post-tool-use.sh` (caminho rápido sem `node`, cache invalidado por tamanho e `mtime` do log próprio e por `publish-result-*`, `FORGE_BATON_RENEW_IF_DUE=1`, `FORGE_LIAISON_LOCK_WAIT_MS=300`, publicação destacada em grupo próprio com vigia de 30 s, aviso por `additionalContext`) e, em `sync-adapters.mjs`, `PostToolUse` derivado em `preToolUseWiring`, `readYamlNestedFlag`, `CMD_POST_TOOL_USE` no universo owned; `doctor.sh` reconhecendo a categoria (rastreia: REQ-12, design §2.8, §4.4; paths: `template/.forge/hooks/session/on-post-tool-use.sh`, `template/.forge/scripts/lib/sync-adapters.mjs`, `template/.forge/scripts/lib/liaison-lock.mjs`, `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/doctor.sh`; depende: TASK-26)
  - Teste (comando): `bash tests/wNNN-liaison-baton-auto-renew-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-28 — Gate vermelho do início de sessão: ofertas elegíveis, bastões detidos, nota "detido por outra sessão (<id>); libere com `baton release --session <id>` ou aguarde o vencimento" para bastão de outra sessão deste repositório, perdas tardias exibidas uma vez em duas sessões consecutivas, aviso de log próprio reescrito, assunto com moldura, linha de falha, nenhuma linha sem bastão (rastreia: REQ-13, REQ-09; paths: `tests/wNNN-liaison-baton-session-start-gate.sh`; depende: TASK-24)
  - Teste (comando): `bash tests/wNNN-liaison-baton-session-start-gate.sh`
  - Padrão de falha: `^FAIL \[(inicio-[a-z-]+)\]`
- [ ] TASK-29 — Bloco de bastões no `on-session-start.sh` (rastreia: REQ-13, design §2.9; paths: `template/.forge/hooks/session/on-session-start.sh`, `template/.forge/scripts/lib/liaison-baton-local.mjs`; depende: TASK-28)
  - Teste (comando): `bash tests/wNNN-liaison-baton-session-start-gate.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-30 — Gate vermelho de `--from-handoff`: exclusão com `--body`/`--body-file`, handoff gerado na hora quando ausente, teto de 64 KB, achado de segredo, falha de geração, nada gravado em nenhuma recusa, gate existente do handoff verde (rastreia: REQ-14; paths: `tests/wNNN-liaison-baton-handoff-gate.sh`; depende: TASK-20)
  - Teste (comando): `bash tests/wNNN-liaison-baton-handoff-gate.sh`
  - Padrão de falha: `^FAIL \[from-handoff-[a-z-]+\]`
- [ ] TASK-31 — `--from-handoff` no `baton offer`, executado antes da trava (rastreia: REQ-14, design §2.10; paths: `template/.forge/scripts/liaison-ops.sh`; depende: TASK-30)
  - Teste (comando): `bash tests/wNNN-liaison-baton-handoff-gate.sh`
  - Padrão de falha: `^FAIL \[`

## Wave 5 — Norma, documentação e verificação

- [ ] TASK-32 — Gate vermelho de documentação: `baton` no `argument-hint`, flags documentadas de cada verbo iguais às de `BATON_VERB_FLAGS`, seção do bastão na rule com os tópicos do REQ-16, a referência à classe "trabalho sobreposto", a publicação sem serialização com seu resíduo, as variáveis internas e os limites (escritor de versão antiga, limpeza por idade, bind mount, janela residual entre a conferência de `nonce` e o `rename`), nota do `/forge:handoff`, `liaison.md` registrando que o `status` geral pode gravar a marca, cabeçalho de `liaison-ops.sh` e descrição de `created_at` citando `stamped_at`, plugin em sincronia, `docs/refer/slash-commands.md` com o subcomando (rastreia: REQ-16, REQ-10; paths: `tests/wNNN-liaison-baton-docs-gate.sh`; depende: TASK-27, TASK-29, TASK-31)
  - Teste (comando): `bash tests/wNNN-liaison-baton-docs-gate.sh`
  - Padrão de falha: `^FAIL \[doc-[a-z-]+\]`
- [ ] TASK-33 — Documentação: `liaison.md`, `handoff.md`, rule `liaison-protocol.md` (com `last_reviewed`), comentário de cabeçalho do `liaison-ops.sh`, plugin regenerado, `docs/refer/slash-commands.md` (rastreia: REQ-16, REQ-05, REQ-10, REQ-12, REQ-14, design §2.11; paths: `template/.forge/commands/harness/liaison.md`, `template/.forge/commands/harness/handoff.md`, `template/.forge/rules/conventions/liaison-protocol.md`, `template/.forge/scripts/liaison-ops.sh`, `plugin/forge/commands/liaison.md`, `plugin/forge/commands/handoff.md`, `docs/refer/slash-commands.md`; depende: TASK-32)
  - Teste (comando): `bash tests/wNNN-liaison-baton-docs-gate.sh && FORGE_ROOT="$(pwd)/template" bash template/.forge/scripts/validate-rules.sh`
  - Padrão de falha: `^FAIL \[`
- [ ] TASK-34 — `CHANGELOG.md` sob `[Unreleased]`, badge de gates do `README.md`, inventário de gates e scripts; item de ledger para o limite de 9.999 mensagens por remetente do padrão de `msg_id` (`ledger-ops.sh add`, origem neste change); relatório de NFR-02 com as medições dos gates; varredura de NFR-01; suíte completa verde (rastreia: REQ-16, NFR-01, NFR-02, NFR-03, design §2.11; paths: `CHANGELOG.md`, `README.md`, `docs/`, `.forge/ledger/`; depende: TASK-33, TASK-25, TASK-12)
  - Teste (comando): `npm test`
  - Padrão de falha: `FAIL`
  - Isenta de par vermelho/verde (verificação final); os gates de documentação existentes (CHANGELOG, badge, inventário) é que ficam vermelhos até ela.

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 | TASK-13, TASK-14 |
| REQ-02 | TASK-19, TASK-20 |
| REQ-03 | TASK-06, TASK-07, TASK-19, TASK-20, TASK-25 |
| REQ-04 | TASK-02, TASK-03, TASK-15, TASK-16 |
| REQ-05 | TASK-15, TASK-16, TASK-23, TASK-24, TASK-25, TASK-33 |
| REQ-06 | TASK-15, TASK-16, TASK-17, TASK-18, TASK-21, TASK-22, TASK-23, TASK-24 |
| REQ-07 | TASK-21, TASK-22 |
| REQ-08 | TASK-23, TASK-24 |
| REQ-09 | TASK-04, TASK-05, TASK-06, TASK-07, TASK-08, TASK-09, TASK-10, TASK-11, TASK-23, TASK-28 |
| REQ-10 | TASK-17, TASK-18, TASK-32, TASK-33 |
| REQ-11 | TASK-04, TASK-12, TASK-13, TASK-19 |
| REQ-12 | TASK-26, TASK-27, TASK-33 |
| REQ-13 | TASK-28, TASK-29 |
| REQ-14 | TASK-30, TASK-31, TASK-33 |
| REQ-15 | TASK-06, TASK-07, TASK-08, TASK-09, TASK-20, TASK-25 |
| REQ-16 | TASK-32, TASK-33, TASK-34 |
| NFR-01 | TASK-34 |
| NFR-02 | TASK-04 (seção crítica), TASK-15 (dobra), TASK-26 (gancho), TASK-34 (relatório) |
| NFR-03 | todas as tasks de gate vermelho (TASK-02, 04, 06, 08, 10, 13, 15, 17, 19, 21, 23, 25, 26, 28, 30, 32); conferido no `verify` |
| Dependência `add-liaison-native-bridge` (design §1, §5) | TASK-01 |
| Escritor de versão antiga (design §2.4, §5) | TASK-10, TASK-11 |
