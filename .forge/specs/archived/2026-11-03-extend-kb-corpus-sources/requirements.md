# Requirements — extend-kb-corpus-sources

> Requisitos do change `extend-kb-corpus-sources`. Cada requisito é verificável e rastreável à proposal.

## O que já existe hoje (verificado por leitura de código, não assumido)

Antes de declarar requisito sobre documentação dinâmica, conferimos o mecanismo real em
`template/.forge/scripts/lib/kb-corpus.mjs` e `template/.forge/scripts/lib/kb-cli.mjs`:

- **Fingerprint por conteúdo já existe e já é source-agnóstico.** `addFile()` grava `sha256` do
  texto de cada documento; `fingerprint(docs)` é o sha256 da lista ordenada `(id, sha256)`. Qualquer
  fonte nova que entrar pelo mesmo `addFile()`/`walk()` participa automaticamente — não é um
  mecanismo exclusivo de `baseline`/`archived-spec`, é genérico sobre `docs[]`.
- **Staleness já é detectada e já é reportada.** `quickFingerprint(roots)` (sha256 de
  `caminho\0tamanho\0mtimeMs` via `stat`, função `sourceFiles()`) é comparado em `indexState()`
  (`kb-cli.mjs:85-90`): `atual` (stat bate), `atual-conteudo` (stat mudou mas sha256 do corpus é
  igual — regrava a impressão rápida) ou `defasado` (conteúdo mudou de verdade). `loadIndex()`
  reconstrói automaticamente quando `defasado`; `kb.sh status` já expõe o estado (`cmdStatus`,
  `kb-cli.mjs:230-239`) em texto e `--json`.
- **O que falta para as fontes novas é só participação, não mecanismo novo.** Tanto
  `sourceFiles()` (para `quickFingerprint`) quanto `collect()` (para `fingerprint`/conteúdo) hoje
  só enumeram `baseline`, `archived-spec`, `plan`, `changelog`, `ledger`, `liaison`. Se
  `active-spec`/`extra-path` não forem adicionados aos DOIS enumeradores, eles ficam fora da
  detecção de staleness mesmo depois de indexados — esse é o gap real, coberto por REQ-06.
- **Status MADR (Accepted/Superseded/Deprecated/Rejected) não é extraído nem exibido em lugar
  nenhum hoje.** Confirmado por grep: não há parsing de `- **Status:**` (convenção MADR usada em
  `.forge/product/current/adr/*.md`, ex.: `0001-graph-engine.md:3`) em `kb-corpus.mjs`,
  `kb-lexical.mjs` nem `kb-cli.mjs`. Um ADR superseded é indexado e apresentado com o mesmo peso de
  um accepted vigente. Esse é um gap real, coberto por REQ-07.

## REQ-01 — Indexar specs ativas como fonte própria (`active-spec`), revertendo REQ-FHT-072

- **Quando** `kb.sh build`/`status` roda, **o sistema deve** incluir todo arquivo `.md`/`.yaml`/`.yml`
  sob `.forge/specs/active/**` no corpus, com `kind: 'active-spec'` — paralelo ao tratamento já
  existente de `archived-spec`, mesma função `walk()`/`addFile()`, mesmo corte em `chunk()`.
- **Supersessão explícita de baseline:** este REQ substitui integralmente REQ-FHT-072
  (`forge-harness-template/spec.yaml`), cujo `SCN-FHT-072-A` hoje exige que specs ativas NUNCA
  entrem no índice. A supersessão é só sobre a parte "specs ativas" da exclusão — peer/blob/
  código/node_modules continuam excluídos sem nenhuma mudança (essa é a parte com motivo de
  segurança real: procedência de conteúdo não confiável). No archive deste change, `spec-delta.yaml`
  grava um `modify_requirement` (full replacement) para REQ-FHT-072 com o texto/cenário novo.
- **Critérios de aceite:**
  - [ ] `collect()` retorna documentos com `kind: 'active-spec'` para todo arquivo elegível sob
    `.forge/specs/active/**` (qualquer profundidade, qualquer change ativo).
  - [ ] `sourceFiles()` (usada por `quickFingerprint`) enumera os mesmos arquivos — sem isso o REQ-06
    (staleness) não cobre esta fonte.
  - [ ] `kb.sh query` devolve resultados de `active-spec` quando o termo buscado só existe num
    requirements/design/tasks de spec ativa (não em baseline/archived).
  - [ ] Nenhum arquivo de `.forge/specs/archived/**` é reclassificado como `active-spec` (dois
    `walk()` distintos, sem overlap de raiz).
  - [ ] `tests/w309-kb-corpus-gate.sh` é atualizado: a asserção atual (linha ~86) que reprova
    qualquer `specs/active` no corpus passa a, ao contrário, EXIGIR que `specs/active/wip/
    proposal.md` apareça com `kind: active-spec`; a asserção sobre peer/blob/código/node_modules
    permanece inalterada (nunca entram).
  - [ ] Resultado de `kb.sh query` originado de `active-spec` é rotulado como tal na saída (texto e
    `--json`) — não misturado sem marca com baseline estável (proposal §4, risco a). Ver REQ-07 para
    o mecanismo de rótulo (mesmo campo estrutural usado para status MADR, generalizado para
    `origin_kind`/`doc.kind` já disponível no resultado).
- **Rastreia:** proposal §2 (item 1)
- **Notas:** mesmos filtros de extensão (`.md`, `.yaml`, `.yml`) das fontes atuais; nenhuma
  stories/evidence/approvals.yaml de spec ativa some filtrada por extensão naturalmente (não são
  `.md`/`.yaml`/`.yml` todas — `approvals.yaml`/`manifest.yaml`/`spec-delta.yaml` SÃO `.yaml` e
  entram; isso é aceitável e não um dado sensível).

## REQ-02 — Fonte configurável `kb.extra_paths` com allowlist obrigatória

- **Quando** o projeto declara `kb.extra_paths: [<globs>]` em `forge.yaml`, **o sistema deve**
  indexar os arquivos `.md`/`.yaml`/`.yml` que casam cada glob (relativo à raiz do projeto), com
  `kind: 'extra-path'`, desde que cada glob tenha uma entrada correspondente de allowlist-com-motivo.
- **Critérios de aceite:**
  - [ ] `forge.yaml` sem `kb.extra_paths` (ausente ou `[]`) não altera o comportamento atual —
    retrocompatibilidade total, nenhum projeto existente quebra.
  - [ ] Cada glob de `kb.extra_paths` exige entrada em `.forge/kb-extra-paths-allowlist.txt` no
    formato `<glob>  # motivo: <justificativa>` (mesmo padrão de
    `.forge/empty-universe-allowlist.txt`/`.forge/suppression-scan-exclude.txt`); glob sem entrada,
    ou entrada sem `# motivo:`, é **ignorado com aviso** em `kb.sh build`/`status` (nunca falha
    silenciosa — aparece em `skipped` com contagem e em stderr), nunca indexado.
  - [ ] Glob perigoso — `**` isolado (sem prefixo de diretório), `/` absoluto, `..` (path
    traversal) — é rejeitado mesmo com allowlist presente; a allowlist autoriza escopo, não
    contorna a validação estrutural do glob.
  - [ ] Arquivo fora da raiz do projeto (resolvido fora de `docRoot`) nunca é lido, independente de
    allowlist.
  - [ ] `docs/adr/**/*.md` e `docs/runbooks/**/*.md` de um sub-repositório (caso real do Payments),
    declarados em `kb.extra_paths` e allowlisted, aparecem no corpus com `kind: 'extra-path'`.
- **Rastreia:** proposal §2 (item 2), §4 (risco b)
- **Notas:** a allowlist mora no projeto consumidor (`.forge/kb-extra-paths-allowlist.txt`), não no
  template — cada projeto declara e justifica seus próprios caminhos extras.

## REQ-03 — Schema declara `kb.extra_paths`

- **Quando** `forge.schema.json` é usado para validar `forge.yaml`, **o sistema deve** declarar um
  bloco novo `kb` dentro de `forgeManifest` (hoje inexistente no schema) com a chave `extra_paths`
  (array de string) e descrição, aplicando `additionalProperties: false` a esse bloco novo — na
  mesma convenção já usada nos demais blocos do schema, não "preservando" algo que já existia.
- **Critérios de aceite:**
  - [ ] `forge.yaml` com `kb: { extra_paths: ["docs/adr/**"] }` valida sem erro.
  - [ ] `forge.yaml` com `kb: { extra_paths: ["x"], outra_chave: 1 }` falha a validação
    (`additionalProperties: false`).
  - [ ] `forge.yaml` com `kb.extra_paths` não-array (ex.: string solta) falha a validação.
- **Rastreia:** proposal §2 (item 3)

## REQ-04 — `kb.sh status`/`build` reportam contagem por fonte, incluindo as novas

- **Quando** `kb.sh status` ou `kb.sh build` roda, **o sistema deve** reportar quantos documentos
  vieram de cada `kind` presente no corpus (já existe para `baseline`/`archived-spec`/`plan`/
  `changelog`/`ledger`/`liaison` via `kinds` em `cmdStatus`) — estendido para sempre incluir
  `active-spec` e `extra-path` quando aplicável, e nunca omitir uma fonte com zero documentos
  quando ela está configurada (`extra_paths` não-vazio com 0 docs indexados é um sinal, não
  silêncio).
- **Critérios de aceite:**
  - [ ] `kb.sh status --json` inclui `kinds.active-spec` sempre que existir ao menos uma spec ativa
    elegível no repositório.
  - [ ] `kb.sh status --json` inclui `kinds["extra-path"]` sempre que `kb.extra_paths` estiver
    configurado, mesmo que o resultado seja `0` (glob não casou nada, ou tudo foi rejeitado por
    falta de allowlist) — o gap de cobertura é visível, nunca silencioso (proposal §2, item 4).
  - [ ] `kb.sh build` (saída texto) lista as mesmas chaves no resumo `pulados:`/contagem por fonte.
- **Rastreia:** proposal §2 (item 4)

## REQ-05 — Documentação não afirma cobertura total

- **Quando** a documentação do comando/skill `/forge:kb` descreve o escopo da busca, **o sistema
  deve** declarar explicitamente as fontes cobertas (incluindo `active-spec`/`extra-path` novas) e
  a limitação multi-repositório (cada `.forge/` próprio precisa do próprio `kb.sh build` — fora de
  escopo deste change, proposal §3), sem linguagem que implique cobertura total do conhecimento do
  projeto.
- **Critérios de aceite:**
  - [ ] `template/.forge/commands/graph/kb.md` (ou onde o escopo é descrito) lista as fontes atuais
    e as duas novas, com a ressalva multi-repo.
  - [ ] Nenhuma frase do tipo "busca sobre todo o conhecimento do projeto" sem qualificação
    permanece no texto.
  - [ ] A documentação orienta explicitamente: para registrar um fato/decisão pontual que não é
    documento formal, o caminho é `ledger-ops.sh add --type follow-up --title "<fato>" --detail
    "<texto>"` (já indexado como `kind: 'ledger'`, sem mecanismo novo — ver "Alternativa avaliada e
    descartada" abaixo), com a ressalva de que o enum de `type` do ledger não cobre todo fato
    possível (limitação conhecida, não resolvida por este change).
- **Rastreia:** proposal §2 (item 5)

## REQ-06 — Fontes novas participam do mecanismo de staleness já existente

- **Quando** um arquivo já indexado como `active-spec` ou `extra-path` muda de conteúdo (emenda,
  mudança de status, edição de runbook) entre dois `kb.sh build`, **o sistema deve** refletir essa
  mudança na próxima consulta — nunca servir a versão antiga como se fosse atual — reusando o
  mecanismo de fingerprint já existente (REQ-06 NÃO cria mecanismo novo; estende a participação
  dos enumeradores existentes).
- **Critérios de aceite:**
  - [ ] `sourceFiles()` enumera os arquivos de `active-spec` e `extra-path` (participam de
    `quickFingerprint`) — sem isso, uma edição que só muda `mtime`/conteúdo nessas fontes não
    dispara reconstrução.
  - [ ] Editar o conteúdo de um documento `active-spec` (ex.: atualizar um `requirements.md` de
    spec ativa) entre dois `kb.sh build` muda o `fingerprint()` agregado — `kb.sh status` reporta
    `defasado` até o próximo `build`, e o próximo `query` reflete o texto novo.
  - [ ] O mesmo vale para `extra-path`: editar um runbook já indexado e rodar `kb.sh query`
    (sem `build` explícito) aciona a reconstrução automática de `loadIndex()` (estado `defasado`) e
    devolve o conteúdo atualizado.
  - [ ] Renomear/remover um arquivo `extra-path` previamente indexado faz o doc desaparecer do
    próximo índice (não fica "fantasma" — `fingerprint()` muda porque a lista de `(id, sha256)`
    muda).
- **Rastreia:** proposal §2, item "Documentação é dinâmica" (1); mecanismo de fingerprint
  confirmado preexistente — esta REQ garante que as fontes novas (REQ-01, REQ-02) não fiquem fora
  dele.

## REQ-07 — Status MADR extraído e rotulado na resposta de busca

- **Quando** um documento indexado (de qualquer fonte: `baseline`, `active-spec`, `extra-path`) é
  um ADR no formato MADR (linha `- **Status:** <valor>` nas primeiras linhas do arquivo), **o
  sistema deve** extrair esse status como metadado do documento e exibi-lo como rótulo visível no
  resultado de `kb.sh query` quando o status indicar que o ADR não está mais vigente
  (`superseded`/`deprecated`/`rejected`, case-insensitive) — **decisão de design:** rótulo visível
  (ex.: `[SUPERSEDED] 0012-...`), **sem** alterar ranking/fusão/re-rank (preserva as constantes
  calibradas do change `add-unified-knowledge-search`, REQ-11) — filtro/reordenação por status foi
  considerado e descartado nesta rodada (ver design.md §3).
- **Critérios de aceite:**
  - [ ] Um ADR com `- **Status:** accepted` (ou `Aceito`, variação PT-BR documentada) não recebe
    rótulo — comportamento atual preservado.
  - [ ] Um ADR com `- **Status:** superseded`/`deprecated`/`rejected` (qualquer caixa) aparece em
    `kb.sh query` com o rótulo correspondente prefixado ao `doc`/`heading` na saída texto, e como
    campo `status` estruturado no resultado `--json` (nunca só embutido em string livre, para não
    forçar o consumidor a fazer parsing de rótulo).
  - [ ] Documento sem o cabeçalho MADR (qualquer outra fonte, ou ADR em formato divergente) não
    quebra a busca — campo `status` ausente/`null`, sem erro.
  - [ ] A extração roda sobre o texto do documento no momento do `collect()`/`chunk()` (não exige
    `build` adicional além do já necessário por REQ-06).
  - [ ] O resultado de `kb.sh query` (texto e `--json`) sempre expõe o `kind` de origem do
    documento (`baseline`, `active-spec`, `extra-path`, `archived-spec`, `plan`, `changelog`,
    `ledger`, `liaison`) como campo estruturado — generalização do mesmo mecanismo de rótulo usado
    para status MADR, cumprindo também o critério de REQ-01 (resultado de `active-spec` nunca
    misturado sem marca com baseline estável).
- **Rastreia:** proposal §2, item "Documentação é dinâmica" (2); proposal §4 (risco a, rótulo de
  origem de spec ativa).

## Alternativa avaliada e descartada — ingestão de nota ad-hoc via CLI

O usuário pediu avaliação de um mecanismo novo (`kb.sh note add "<texto>" [--tag]`) para inserir no
índice um fato/decisão falada/observação pontual que não é documento formal. Avaliamos as duas
rotas antes de decidir:

- **Rota A (descartada) — subcomando novo `kb.sh note add`**, gravando markdown em
  `.forge/kb/notes/<timestamp>-<slug>.md` e um `kind: 'note'` novo no corpus. Descartada porque: (1)
  criaria uma SEGUNDA trilha de auditoria para "conhecimento ad-hoc capturado fora de um artefato
  formal" — o projeto já tem uma (`ledger-ops.sh add`), e duas trilhas para o mesmo propósito é
  exatamente o tipo de drift que o ledger já existe para evitar (append-only, `dedup_key`, cadeia de
  supersessão); (2) exigiria o MESMO cuidado de segurança de todo caminho de escrita nova (nunca
  aceitar texto de peer/liaison sem trust, nunca segredo em texto livre) **sem** o controle que o
  ledger já tem (schema fixo, `type` enumerado, `--status`/`--supersedes` versionados) — construir
  essa validação do zero está fora da proporção de um change scale 2 cujo escopo é "fontes que o
  `kb-corpus.mjs` já sabe indexar", não "caminho de escrita nova no corpus"; (3) a proposal (§3,
  "o que NÃO muda") já declara este change como extensão de FONTES existentes/configuráveis, não
  como mecanismo de ingestão de conteúdo novo — um subcomando de escrita é uma mudança de natureza
  diferente da proposta aprovada.
- **Rota B (adotada) — documentar o caminho já existente, com o `--type` real do schema.**
  `ledger.schema.json` fixa `type` num enum fechado: `roadmap`, `tech-debt`, `known-bug`,
  `follow-up`, `feature-idea` — não existe `note`/`observation` (achado do `yolo-gate` na rodada 1
  do gate `requirements_reviewed`; comando documentado inicialmente teria falhado). O tipo mais
  próximo de "fato/decisão pontual para lembrar depois" já existente é `follow-up`. Caminho correto:
  `ledger-ops.sh add --type follow-up --title "<fato/decisão>" --detail "<texto livre>"` — grava
  entrada append-only, auditável, versionada em `.forge/ledger/ledger.json`, e **já é indexada hoje**
  pelo `kb-corpus.mjs` (`kind: 'ledger'`, função `ledgerText()`) — sem nenhuma mudança de código. O
  que faltava era só isso estar documentado como o caminho recomendado para conhecimento ad-hoc; ver
  REQ-05 (critério de aceite adicional abaixo). Se o fato não for naturalmente um "follow-up"
  (ex.: uma decisão já encerrada, sem ação pendente), o enum atual do ledger não tem tipo exato —
  isso é uma limitação conhecida e documentada, não resolvida por este change (ledger é "trabalho
  conhecido que sobrevive entre changes", não um diário de fatos; ver "Fora de escopo").
- **Nenhum REQ novo de mecanismo foi criado.** REQ-05 ganhou um critério de aceite adicional para
  documentar a Rota B explicitamente.

## Requisitos não funcionais do change

- **NFR-01 —** Nenhuma chamada de rede nova é introduzida pela indexação de `active-spec`/
  `extra-path`/status MADR (zero-dep preservado; método de medição: mesma guarda estática de
  imports/bloqueio de rede já usada em `tests/w313-kb-offline-lexical-gate.sh` e
  `tests/w318-kb-offline-semantic-gate.sh` — confirmado por leitura: os dois já iteram
  `lib/kb-*.mjs` genericamente (glob, não lista fixa de arquivo), logo cobrem o código novo deste
  change SEM precisar de edição; método de medição é apenas reexecutá-los, não estendê-los).
- **NFR-02 —** `kb.sh build` sobre um corpus com `active-spec`+`extra-path` adicionados não
  degrada o tempo de build de forma perceptível além do crescimento proporcional ao número de
  arquivos novos (método: comparação `time kb.sh build` antes/depois no próprio repositório,
  registrada em `verification.md`, sem meta numérica rígida — proporcionalidade, não regressão
  categórica).

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | nenhum (comportamento automático, sem flag) | `kb.sh build`/`status`/`query` (sem flag nova) | TASK-01 |
| REQ-02 | `kb.extra_paths` (lista de globs) | `forge.yaml`, lido por `kb.sh build`/`status`/`query` | TASK-02 |
| REQ-02 | `.forge/kb-extra-paths-allowlist.txt` (allowlist com motivo) | arquivo de projeto, lido por `kb-corpus.mjs` | TASK-02 |
| REQ-03 | `kb.extra_paths` no schema | `forge.schema.json` (validação de `forge.yaml`) | TASK-02 |
| REQ-04 | nenhum parâmetro novo — só saída | `kb.sh status --json`/texto, `kb.sh build` (saída) | TASK-03 |
| REQ-05 | nenhum parâmetro — só documentação | `template/.forge/commands/graph/kb.md` | TASK-04 |
| REQ-06 | nenhum parâmetro novo — extensão de mecanismo existente | `kb.sh status`/`build`/`query` (sem flag nova) | TASK-01, TASK-02 |
| REQ-07 | nenhum flag novo; campo `status` no resultado `--json` | `kb.sh query --json`/texto | TASK-03 |

- Nenhuma linha "N/A" sem justificativa: todos os parâmetros deste change são configuração
  (`forge.yaml`) ou saída observável de CLI já existente — não há tela nem endpoint HTTP (`/forge:kb`
  é um comando local, zero-dep, sem superfície de API/dados sensíveis).

## Fora de escopo (reafirmação)

- Resolver a topologia multi-repositório do Payments (cada `Payments.*` com `.forge/` próprio) —
  quem quiser índice único cross-repo roda `kb.sh build` em cada repositório separadamente.
- Mecanismo de rede/LLM na busca (a camada semântica já é local; isto não muda).
- Alterar o comportamento de segurança do liaison (mensagens de peer continuam nunca indexadas).
- Migrar ADRs/runbooks existentes para dentro de `.forge/product/current` — `extra_paths` os
  indexa onde já estão.
- Filtro/exclusão automática de ADR superseded dos resultados de busca (REQ-07 decide por rótulo
  visível, não por ocultação — um ADR superseded ainda é um fato histórico relevante para "já
  decidimos isso antes?").
