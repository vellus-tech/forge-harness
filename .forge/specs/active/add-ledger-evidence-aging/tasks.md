# Tasks — add-ledger-evidence-aging

> Tasks do change `add-ledger-evidence-aging`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (commit de vermelho + commit de implementação), rastreável a um REQ/seção do design, e declara o que toca.
> Cada task declara `Teste (comando)` e `Padrão de falha`: o Red é provado por execução antes do Green.

O gate de teste do change vive num arquivo só, `tests/ledger-evidence-aging-gate.sh`. Ele fica sem ordinal `wNNN` dentro deste change por convenção do projeto (o número é decidido na hora do merge, renomeando em cascata se colidir); o `run-all.sh` descobre qualquer `tests/*-gate.sh`, então o gate roda na suíte desde a TASK-01. O critério "padrão `wNNN`" do REQ-09 se cumpre no renomeio do merge, que fica registrado como pendência para o dono.

O gate aceita um grupo de cenários como primeiro argumento (`schema`, `stale`, `verify`, `supersede`, `show`, `specnew`, `closed`, `wiring`, `docs`, `mutation`; sem argumento roda todos), de modo que cada task prova o próprio vermelho isoladamente. Contador de cenários: cada grupo declara quantos cenários tem; ao fim, o gate compara executados × declarados **dos grupos selecionados** (um grupo só confere o próprio total; sem argumento, a soma de todos) e reprova se divergirem — rodar um subconjunto nunca parece cenário perdido, e rodar tudo nunca aprova sem ter olhado tudo. Toda falha imprime `FAIL [<grupo>-<n>] ...` no início da linha (assinatura `shell-gate` do `red-classify.mjs`). A fixture grava o próprio `ledger.stale_days` no `forge.yaml` copiado (ou o remove), para que nenhum cenário dependa do valor de fábrica do template, que muda na TASK-09.

Para manter `npm test` verde entre tasks (o design §1 conta com a suíte para detectar alvo de mutação roubado), cada task que muda uma contagem do inventário do `README.md` atualiza o README no próprio commit verde: o badge de gates na TASK-01 (gate novo em `tests/`), a contagem de `scripts/` na TASK-02 (`lib/ledger-aging.mjs`).

## Wave 1 — Contrato de dados

- [X] TASK-01 — Schema aditivo: `last_verified`, `evidence` (objeto inline em `items`, cinco campos obrigatórios, `additionalProperties: false`), `supersedes`, `links.superseded_by`, status `superseded`; esqueleto do gate (fixture hermética, retrato do ledger real, contador por grupo); badge de gates do `README.md` (rastreia: REQ-01, REQ-09, design §2.1, §2.7; paths: `template/.forge/schemas/ledger.schema.json`, `tests/ledger-evidence-aging-gate.sh`, `README.md`; depende: —)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh schema`
  - Padrão de falha: `FAIL \[schema`

## Wave 2 — Portas novas do `ledger-ops.sh`

- [X] TASK-02 — Módulo `lib/ledger-aging.mjs` (função pura `ageReport` + CLI) e subcomando `stale`: universo = status fora do conjunto encerrado; referência `last_verified ?? created_at`; inconsistência de `last_verified` comparada por `Date.parse` (não por string); referência posterior ao as_of como inconsistência; limiar `--days` > `forge.yaml ledger.stale_days` > 30 com rc 2 para valor inválido; `--as-of` com rc 2 se ilegível; sem HEAD e sem `--as-of`, rc 2 via `_git_date` no shell principal; `--days`/`--as-of` com `_require_value`; `stale` chama `_init_ledger`; `--strict`; contagem de `scripts/` do `README.md` (rastreia: REQ-05, NFR-01, NFR-02, design §2.4, §8; paths: `template/.forge/scripts/lib/ledger-aging.mjs`, `template/.forge/scripts/ledger-ops.sh`, `tests/ledger-evidence-aging-gate.sh`, `README.md`; depende: TASK-01)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh stale`
  - Padrão de falha: `FAIL \[stale`
- [X] TASK-03 — Subcomando `verify`: validação de conteúdo mínimo por `kind` (file com `realpath` e contenção na raiz, commit gravado como SHA completo, test com `::nome` literal no arquivo, command nunca executado), `observed` ≥ 20 caracteres e diferente de `ref`/`title`, recusa de status encerrado, carimbo de `last_verified`/`updated_at`, bloco `CORREÇÃO DE REGISTRO` no veredito `changed` com nomes próprios (sem repetir linha-alvo de mutação do `note`), aviso em stderr se o HEAD for anterior ao `last_verified` corrente; aviso do `note --kind measurement`; `_validate_enum_field` descendo em `evidence.items`; `verify` na lista de portas de escrita do aviso de divergência (entre `note` e `resolve`), caso novo na matriz do `w193 [9]` e alvo do `w211 M5` reancorado (rastreia: REQ-02, REQ-03, NFR-02, NFR-03, design §1, §2.2, §8; paths: `template/.forge/scripts/ledger-ops.sh`, `tests/ledger-evidence-aging-gate.sh`, `tests/w193-tree-derived-state-gate.sh`, `tests/w211-ledger-detail-acumulativo-gate.sh`; depende: TASK-02)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh verify`
  - Padrão de falha: `FAIL \[verify`
  - DoD adicional (detecção cedo de alvo de mutação roubado): `bash tests/w211-ledger-detail-acumulativo-gate.sh && bash tests/w194-ledger-write-discipline-gate.sh && bash tests/w193-tree-derived-state-gate.sh` verdes depois do verde.
- [X] TASK-04 — Supersessão: `add --supersedes` com escrita única das duas entradas (validação de padrão no shell antes das validações de enum do `add`), recusas de `add`/`update --status superseded`, trava de saída de `superseded` em `update --status` e `promote`, `resolve` recusando `superseded` por `if` próprio antes da linha literal do `w211 M8`; sufixos do `list` na ordem canônica do design §8 (` (substitui …)`, ` · reverificado em …`) (rastreia: REQ-04, NFR-03, design §1, §2.3, §8; paths: `template/.forge/scripts/ledger-ops.sh`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-03)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh supersede`
  - Padrão de falha: `FAIL \[supersede`
  - DoD adicional: `bash tests/w211-ledger-detail-acumulativo-gate.sh && bash tests/w194-ledger-write-discipline-gate.sh && bash tests/w202-ledger-schema-conformance-gate.sh` verdes depois do verde.
- [X] TASK-05 — Subcomando `show`: entrada, `last_verified`/"nunca reverificado", registros de `evidence`, `detail` e cadeia de supersessão nas duas direções com guarda de ciclo e de elo quebrado; chama `_init_ledger`; id inexistente sai com rc 1 (rastreia: REQ-04, design §2.3, §8; paths: `template/.forge/scripts/ledger-ops.sh`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-04)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh show`
  - Padrão de falha: `FAIL \[show`
- [X] TASK-06 — `spec-new.sh --from-ledger` com item `superseded`: change criado sem `ledger_origin` e sem `promote`, `WARN` nomeando o sucessor e o comando de ligação; controle com item ativo mantém o elo (rastreia: REQ-04, design §2.3; paths: `template/.forge/scripts/spec-new.sh`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-04)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh specnew`
  - Padrão de falha: `FAIL \[specnew`

## Wave 3 — Leitores e fiação no ciclo de vida

- [X] TASK-07 — `superseded` nos conjuntos encerrados inventariados (`ledger-render.mjs`, `note` e `status` do `ledger-ops.sh`) e no balde `RECLASSIFIED` de `tools/plan-progress.mjs` (leitor interno achado na validação das tasks; sem ele uma entrada `superseded` apareceria como trabalho aberto no placar), com asserção por sítio no gate; render de ` · reverificado em` e `↳ substitui` na entrada ativa e `superseded` contado entre os encerrados da seção, sem mudar a renderização de entradas sem os campos novos (rastreia: REQ-04, REQ-06, REQ-07, design §2.3, §2.5; paths: `template/.forge/scripts/lib/ledger-render.mjs`, `template/.forge/scripts/ledger-ops.sh`, `tools/plan-progress.mjs`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-05)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh closed`
  - Padrão de falha: `FAIL \[closed`
- [X] TASK-08 — Fiação: sufixo de envelhecimento no `ledger-ops.sh status` e marca ` · sem reverificação há <idade>d` no `list` (último sufixo da ordem canônica), ambos com o mesmo universo do `stale` e com degradação para limiar inválido e sem commit HEAD; linha advisory no `doctor.sh` delegando a `ledger-ops.sh stale` **dentro** do guard `[ -f ledger.json ]` já existente (doctor sem ledger não cria o arquivo — cenário próprio no grupo `wiring`), com mapeamento de rc para `info` e sem alterar o código de saída do doctor (rastreia: REQ-06, NFR-02, design §2.3, §2.4, §8; paths: `template/.forge/scripts/ledger-ops.sh`, `template/.forge/scripts/doctor.sh`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh wiring`
  - Padrão de falha: `FAIL \[wiring`

## Wave 4 — Documentação, provas de mutação e fechamento

- [X] TASK-09 — Configuração e documentação: chave **ativa** `ledger.stale_days: 30` (com comentário) em `forge.yaml` e `stale_days` inteiro ≥ 1 em `forge.schema.json`; usage/help do `ledger-ops.sh` (com o alvo do `w257 [HM]` atualizado); `commands/harness/ledger.md` (verify, show, stale, `--supersedes`, `command` nunca executado, árvore da evidência, relógio do HEAD, fuso do `--as-of`, CI opt-in via `--strict`, homônimo `superseded`); regra 7 em `ledger-consultation.md`; instrução de reverificar item marcado e limitação do filtro `open` em `resume.md`; `npm run build:plugin` para as cópias em `plugin/forge/commands/`; medição do NFR-02 no gate com recorte fixo (arquivo inteiro `lib/ledger-aging.mjs` e os ramos `verify)`, `show)` e `stale)` do `ledger-ops.sh`) e prova de mutação própria (inserir `new Date()` num recorte faz a medição reprovar) (rastreia: REQ-08, NFR-02, design §2.6, §8; paths: `template/.forge/forge.yaml`, `template/.forge/schemas/forge.schema.json`, `template/.forge/scripts/ledger-ops.sh`, `template/.forge/commands/harness/ledger.md`, `template/.forge/commands/harness/resume.md`, `plugin/forge/commands/ledger.md`, `plugin/forge/commands/resume.md`, `template/.forge/rules/conventions/ledger-consultation.md`, `tests/ledger-evidence-aging-gate.sh`, `tests/w257-arg-surface-gate.sh`; depende: TASK-08)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh docs`
  - Padrão de falha: `FAIL \[docs`
- [X] TASK-10 — Provas de mutação com controle, mutação e recontrole (validação de evidência removida, carimbo de `last_verified` removido, `superseded` fora do `CLOSED` do renderizador contra oráculo fixo), restauração conferida por `cmp`, todas sobre cópias na fixture (rastreia: REQ-09, design §2.7; paths: `tests/ledger-evidence-aging-gate.sh`; depende: TASK-09)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh mutation`
  - Padrão de falha: `FAIL \[mutation`
  - Sem par vermelho/verde: task só de teste, sem código de produção (um verde sem implementação reprovaria como `vermelho-vazio` no `red-evidence.sh task`). A prova é a própria estrutura controle → mutação → recontrole de cada cenário, que precisa reprovar quando a mutação é aplicada e passar quando é restaurada.
- [X] TASK-11 — Fechamento: `CHANGELOG.md` na seção não publicada (com a nota de rollout: consumidor existente vê a origem `default` até declarar `ledger.stale_days`, porque o `forge update` não reescreve `forge.yaml`); gates existentes do ledger e de mutação (`w98`, `w157`, `w193`, `w194`, `w202`, `w203`, `w207`, `w211`, `w257`, `w156`, `w200`) verdes; suíte completa `npm test` verde; o renomeio do gate para `wNNN` na hora do merge é registrado no `verification.md` sob `Follow-ups abertos`, para que o harvest do archive o leve ao ledger e a pendência não dependa de memória (rastreia: REQ-08, REQ-09, NFR-01; paths: `CHANGELOG.md`; depende: TASK-10)
  - Teste (comando): `bash tests/run-all.sh`
  - Padrão de falha: `FAIL`
  - Sem par vermelho/verde: task de documentação e verificação, sem código de produção; a prova é a suíte completa verde depois do commit.

## Wave 5 — Achados do gate `implementation_verified` (rodada 1)

- [X] TASK-12 — Correções do Review do verify: inconsistência de `last_verified` visível no `list` (`· inconsistente`), no `status` (`· J inconsistente(s)`) e no `doctor` (linha `info`, nunca `ok`); `--as-of` com hora exige `Z`/`±hh:mm` e data inexistente no calendário é recusada (rc 2, saída independente do `TZ`); `ledger.stale_days` presente e vazio ou na forma em linha é erro; arquivo `..nome` legítimo aceito e evidência em `.git/` ou no próprio ledger recusada; `show` nomeia elo não recíproco e ciclo uma vez só; recusa de `update` em `superseded` sai com rc 1 (rastreia: REQ-03, REQ-04, REQ-05, REQ-06, NFR-02; paths: `template/.forge/scripts/ledger-ops.sh`, `template/.forge/scripts/lib/ledger-aging.mjs`, `template/.forge/scripts/doctor.sh`, `template/.forge/commands/harness/ledger.md`, `plugin/forge/commands/ledger.md`, `tests/ledger-evidence-aging-gate.sh`; depende: TASK-11)
  - Teste (comando): `bash tests/ledger-evidence-aging-gate.sh`
  - Padrão de falha: `FAIL \[(stale|verify|supersede|show|wiring)`

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 | TASK-01 |
| REQ-02 | TASK-03 |
| REQ-03 | TASK-03 |
| REQ-04 | TASK-04, TASK-05, TASK-06, TASK-07 |
| REQ-05 | TASK-02 |
| REQ-06 | TASK-07, TASK-08 |
| REQ-07 | TASK-07 |
| REQ-08 | TASK-09, TASK-11 |
| REQ-09 | TASK-01, TASK-10, TASK-11 |
| NFR-01 | TASK-02, TASK-11 |
| NFR-02 | TASK-02, TASK-03, TASK-08, TASK-09 |
| NFR-03 | TASK-03, TASK-04 |
| Design §8 | TASK-02, TASK-03, TASK-04, TASK-05, TASK-08, TASK-09, TASK-11 |
