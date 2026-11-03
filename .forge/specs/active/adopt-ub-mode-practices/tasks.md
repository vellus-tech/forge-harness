# Tasks — adopt-ub-mode-practices

> Tasks do change `adopt-ub-mode-practices`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (commit de vermelho + commit de implementação), rastreável a um REQ/seção do design, e declara o que toca.
> Cada task declara `Teste (comando)` e `Padrão de falha`: o Red é provado por execução antes do Green.
> Nenhuma destas TASKs é executada nesta rodada — ver NFR-01 de `requirements.md`. `/forge:implement` roda numa sessão futura, sobre este mesmo change.

O gate de teste do change vive num arquivo só, `tests/adopt-ub-mode-practices-gate.sh` (sem ordinal `wNNN` dentro deste change, por convenção do projeto — o número real só se decide no merge, `requirements.md:23`; `run-all.sh` descobre qualquer `tests/*-gate.sh`, então o gate roda na suíte desde a TASK-01). O gate aceita um grupo de cenários como primeiro argumento (`script`, `implement-wiring`, `coding-loop-wiring`, `human-wiring`, `premise-mutation`, `suppression-grammar`, `suppression-wiring`, `suppression-mutation`, `spike`; sem argumento roda todos). Toda falha imprime `FAIL [<grupo>-<n>] ...` no início da linha (assinatura `shell-gate` do `red-classify.mjs`), e cada TASK testa só o próprio grupo.

**Correção de concepção em relação à 1ª redação deste `tasks.md` (achado real da revisão adversarial do gate `tasks_reviewed`):** a redação anterior testava os scripts novos diretamente (ex.: `bash check-attack-premise.sh --file fixture`), o que o motor de Red (`red-classify.mjs`/`red-replay.mjs`) classifica como `vermelho-padrao` (saída não é `FAIL [n]`) ou `verde-falha` (o comportamento correto do script é reprovar a fixture, então o "verde" também falha). A correção segue o padrão real já usado em changes arquivados (`2026-10-30-add-ledger-evidence-aging/tasks.md`): o GATE É O TESTE, nunca o script diretamente.

## Wave 1 — Attack the Premise, mecanismo base (REQ-01/REQ-02)

- [-] TASK-01 — Esqueleto do gate (fixtures dos dois formatos de bloco, contador por grupo) + script `check-attack-premise.sh` com as duas regras de disparo e o modo `--list` (rastreia: REQ-01, REQ-02; paths: `template/.forge/scripts/check-attack-premise.sh`, `tests/adopt-ub-mode-practices-gate.sh`; depende: —)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh script`
  - Padrão de falha: `FAIL \[script`

- [ ] TASK-02 — `implement.md`: âncora real do HALT ("marque `[!]`, **pare a execução** e reporte o que travou"), chamada ao script condicionada à causa "gate falha após 2 tentativas de correção", pré-condição de retomada (rastreia: REQ-01, REQ-02; paths: `template/.forge/commands/specs/implement.md`, `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-01)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh implement-wiring`
  - Padrão de falha: `FAIL \[implement-wiring`

- [ ] TASK-03 — `task-coder.md` §3.7: bloco acumulativo com campo `Gate`, chamada ao script, pré-condição de retomada no preflight que recusa abrir onda com `[!]` pendente (`task-coder.md:106`) (rastreia: REQ-01, REQ-02; paths: `template/.forge/agents/coding/task-coder.md`, `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-01)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh coding-loop-wiring`
  - Padrão de falha: `FAIL \[coding-loop-wiring`

- [ ] TASK-04 — `coding-loop.md`, `coding-status.md`, `session-discipline.md`, `gate-runner/SKILL.md`: documentação do mecanismo acumulativo (bloco nunca sobrescrito) e nova receita "Premissa nomeada" (rastreia: REQ-01; paths: `template/.forge/commands/coding/coding-loop.md`, `template/.forge/commands/coding/coding-status.md`, `template/.forge/rules/conventions/session-discipline.md`, `template/.forge/skills/gate-runner/SKILL.md`, `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-03)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh coding-loop-wiring`
  - Padrão de falha: `FAIL \[coding-loop-wiring` (grupo estendido nesta TASK com os cenários de documentação — mesmo grupo da TASK-03, cenários adicionais)

- [ ] TASK-05 — `verify.md` (seção `## Premissas atacadas` populada pelo modo `--list` do script) e `archive.md` §2 (linha de contagem no resumo que o humano já lê) (rastreia: REQ-01; paths: `template/.forge/commands/specs/verify.md`, `template/.forge/commands/specs/archive.md`, `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-01)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh human-wiring`
  - Padrão de falha: `FAIL \[human-wiring`

- [ ] TASK-06 — Provas de mutação do mecanismo REQ-01/02: controle → mutação → recontrole cobrindo a checagem interna, os dois pontos de chamada (TASK-02/03), os dois pontos de pré-condição de retomada, a linha de `archive.md` e a chamada `--list` de `verify.md` (rastreia: REQ-02; paths: `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-02, TASK-03, TASK-04, TASK-05)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh premise-mutation`
  - Padrão de falha: `FAIL \[premise-mutation`
  - Sem par vermelho/verde: task só de teste, sem código de produção novo (um verde sem implementação reprovaria como `vermelho-vazio`). A prova é a própria estrutura controle → mutação → recontrole de cada cenário.

## Wave 2 — Scanner de supressão sem referência (REQ-03/REQ-04)

- [ ] TASK-07 — Script `check-suppression-reference.sh` com interface fixada (`--staged` para o modo do `/forge:ship`, `--range <base>...<head>` para o `pre-push`), gramática de referência, resolvedor de base reusado (`_redfirst_resolve_base`, com o cenário "sem `origin/develop` acessível" neste grupo, com Red real — não só na mutação), exclusão de código gerado/vendorizado E do `.forge/` da RAIZ do repositório (um nível, `.forge/**` a partir de `git rev-parse --show-toplevel` — NUNCA recursivo por nome em qualquer profundidade, que reabriria o M2 original do `design_reviewed` ao bloquear consumidor que versiona `.forge/scripts/`, e deixaria `.forge/evals/` deste próprio repositório sem exclusão; `template/.forge/` é diretório IRMÃO de `.forge/`, não aninhado, então fica normalmente visível) (rastreia: REQ-03, REQ-04; paths: `template/.forge/scripts/check-suppression-reference.sh`, `tests/adopt-ub-mode-practices-gate.sh`; depende: —)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh suppression-grammar`
  - Padrão de falha: `FAIL \[suppression-grammar`
  - Fixtures de supressão suja (sem referência) são geradas em `/tmp` em tempo de execução pelo próprio gate, nunca versionadas em `tests/` — um arquivo sujo versionado bloquearia o push da própria branch deste change.

- [ ] TASK-08 — Higiene: adiciona referência rastreável às duas supressões do próprio harness encontradas durante o design, visíveis ao scanner por estarem em `template/.forge/` (irmão do `.forge/` excluído na TASK-07, não aninhado nele) (rastreia: REQ-03; paths: `template/.forge/scripts/lib/red-evidence-ops.mjs`, `template/.forge/skills/frontend-ui-review/scripts/scan-native-controls.py`, `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh suppression-grammar`
  - Padrão de falha: `FAIL \[suppression-grammar`
  - Sem par vermelho/verde: as duas linhas já existem e não mudam de comportamento, só ganham comentário de referência — não há vermelho comportamental a observar aqui, só o scanner (TASK-07) confirmando que a referência nova é válida.

- [ ] TASK-09 — Arquivo de exclusão do consumidor `.forge/suppression-scan-exclude.txt` e leitura pelo script (rastreia: REQ-03; paths: `template/.forge/scripts/check-suppression-reference.sh`, `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh suppression-grammar`
  - Padrão de falha: `FAIL \[suppression-grammar` (grupo estendido com o cenário de exclusão declarada pelo consumidor — item que NÃO está no escopo da TASK-07, para não duplicar: a TASK-07 cobre a gramática de referência e as duas exclusões de código gerado/`.forge/`; esta TASK cobre só o arquivo de exclusão adicional do consumidor)

- [ ] TASK-10 — Wiring em `/forge:ship` (`--staged`, passo 3 antes do commit) e `pre-push` (`--range` com a base resolvida, seguindo o padrão de isolamento de `w223` — copiar `scripts/` inteiro ativa `HARNESS_SUITE` dentro do teste, cuidado já registrado no `TASK-04` de `add-migration-review-rule`) (rastreia: REQ-03, REQ-04; paths: `template/.forge/commands/git/ship.md`, `template/.forge/hooks/git/pre-push`, `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh suppression-wiring`
  - Padrão de falha: `FAIL \[suppression-wiring`

- [ ] TASK-11 — Receita "Supressão sem referência" em `gate-runner/SKILL.md` e linha nova em `quality-gates.md` (rastreia: REQ-03; paths: `template/.forge/skills/gate-runner/SKILL.md`, `template/.forge/rules/testing/quality-gates.md`, `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh suppression-wiring`
  - Padrão de falha: `FAIL \[suppression-wiring` (grupo estendido com o cenário de documentação)

- [ ] TASK-12 — Provas de mutação do scanner de supressão: controle → mutação → recontrole cobrindo a gramática de referência, a exclusão `.forge/`, o resolvedor de base (cenário "sem `origin/develop`" já tem Red na TASK-07; a mutação prova que o fallback é a causa do comportamento, não coincidência) e o contrafactual de universo via `forge_universe_check` (rastreia: REQ-04; paths: `tests/adopt-ub-mode-practices-gate.sh`; depende: TASK-08, TASK-09, TASK-10, TASK-11)
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh suppression-mutation`
  - Padrão de falha: `FAIL \[suppression-mutation`
  - Sem par vermelho/verde: task só de teste, mesmo motivo da TASK-06.

## Wave 3 — Spike de medição, roteiro executável (REQ-05)

- [ ] TASK-13 — Script de spike: complexidade via `@babel/parser` (devDependency real deste repositório — `tools/` roda a partir do `node_modules` da raiz, então a dependência existe aqui; sobre um consumidor externo sem essa devDependency, o script resolve via `npx @babel/parser@<versão fixada>` da mesma forma que o `jscpd`) + duplicação (`jscpd` via `npx jscpd@<versão fixada>`, nunca instalado como dependência) sobre universo `git ls-files` (rastreia: REQ-05; paths: `tools/spike-complexity-duplication.mjs`, `tests/adopt-ub-mode-practices-gate.sh`; depende: —). Precedente de localização em `tools/`: `tools/plan-progress.mjs`.
  - Teste (comando): `bash tests/adopt-ub-mode-practices-gate.sh spike`
  - Padrão de falha: `FAIL \[spike`
  - Setup do teste: fixture com 2-3 arquivos de complexidade/duplicação conhecidas (um caso claramente acima do limiar, um claramente abaixo), para o gate comparar contra oráculo fixo

- [ ] TASK-14 — Execução real do spike sobre `Payments.DevPortal` e aplicação do critério de decisão (rastreia: REQ-05; paths: `.forge/specs/active/adopt-ub-mode-practices/spike-result.md`; depende: TASK-13). Arquivo novo, onde o resultado é gravado.
  - Teste (comando): N/A — esta TASK é a execução documentada do roteiro: rodar `tools/spike-complexity-duplication.mjs` sobre `Payments.DevPortal` (universo via `git ls-files`), classificar manualmente uma amostra de 20 achados acima do limiar como verdadeiro/falso-positivo (design §2.3 passo 3), aplicar a regra dos 30%, e gravar o resultado (limiar final ou "descartado") em `spike-result.md`
  - Sem par vermelho/verde: task de execução e registro, sem código de produção.

## Wave 4 — ADR e ledger (REQ-06/REQ-07)

- [ ] TASK-15 — Preenchimento da ADR com o resultado real do spike e publicação via `/forge:adr` (rastreia: REQ-06; paths: `.forge/specs/active/adopt-ub-mode-practices/design.md`, `.forge/product/current/adr/`; depende: TASK-14). Origem do texto a preencher: design.md §2.4. Destino criado pelo comando `/forge:adr`.
  - Teste (comando): N/A — esta TASK preenche a seção "Decision" do texto já existente em `design.md` §2.4 com o conteúdo de `spike-result.md` (TASK-14) e invoca `/forge:adr`, que cria e numera o arquivo
  - Sem par vermelho/verde: task documental.

- [ ] TASK-16 — Item de ledger para P4 (mutação sistemática via StrykerJS/Stryker.NET/PIT/mutmut sobre código de consumidor), condicionado (rastreia: REQ-07; paths: `.forge/ledger/ledger.json`, `.forge/ledger/LEDGER.md`; depende: —)
  - Teste (comando): `FORGE_ROOT="$(pwd)" bash template/.forge/scripts/ledger-ops.sh add --type tech-debt --title "Mutação sistemática (StrykerJS/Stryker.NET/PIT/mutmut) sobre código de consumidor, condicionada a lógica crítica" --detail "<texto literal do design.md §2.5>" --severity LOW --origin manual --change adopt-ub-mode-practices` seguido de `FORGE_ROOT="$(pwd)" bash template/.forge/scripts/ledger-ops.sh render`
  - Padrão de falha: `ledger-ops.sh add` com rc≠0, ou entrada ausente em `LEDGER.md` após o render
  - Sem par vermelho/verde: task de registro, sem código de produção.

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 | TASK-01, TASK-02, TASK-03, TASK-04, TASK-05, TASK-06 |
| REQ-02 | TASK-01, TASK-02, TASK-03, TASK-06 |
| REQ-03 | TASK-07, TASK-08, TASK-09, TASK-10, TASK-11, TASK-12 |
| REQ-04 | TASK-07, TASK-10, TASK-12 |
| REQ-05 | TASK-13, TASK-14 |
| REQ-06 | TASK-15 |
| REQ-07 | TASK-16 |
| NFR-01 | Todas (nenhuma executada nesta rodada) |
| NFR-02 | TASK-01, TASK-07 (interface/gates já nascem com nome/cenários/mutação especificados, sem decisão adicional) |
