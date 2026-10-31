# Analysis — add-unified-knowledge-search
## Status: PASS
## Achados
| ID | Severidade (BLOCKER/HIGH/MEDIUM) | Tipo (coverage/conflict/drift/risk) | Onde | Recomendação |
|---|---|---|---|---|
| A-01 | HIGH | risk | tasks.md TASK-01..08 (paths); `tests/w200-readme-inventory-gate.sh` [1] e [6] | O gate w200 compara duas contagens mantidas à mão no README com a árvore real (`scripts/ (146)` e o badge `gates-181`). Da TASK-01 à TASK-08 cada task acrescenta arquivo em `scripts/` e/ou um gate novo, e só a TASK-09 atualiza o README: o w200 fica vermelho do primeiro commit da TASK-01 até a TASK-09. Recomendação: cada task atualiza as duas contagens no seu commit verde e declara `README.md` nos paths; a TASK-06 (`depende: —`) é serializada depois da Wave 1 ou prevê rebase da linha de contagem. |
| A-02 | HIGH | risk | requirements REQ-03 (último critério), REQ-07 (evidence do verify); evidence/semantic-feasibility.md §5; design §6 | A evidência já mostra dois critérios de aceite reprovados no holdout (REQ-03: MRR lexical 0,714 contra 0,730 do BM25; REQ-07: re-rank 0,749 contra 0,753). Recomendação: registrar em approvals, antes do `/forge:implement`, a decisão do dono sobre o desfecho esperado: aceitar a parada, ou redefinir o critério com justificativa que não venha do holdout. |
| A-03 | MEDIUM | conflict | REQ-11 (3º critério) × tasks TASK-03/TASK-05 | O REQ-11 situa o conjunto em `tests/fixtures/kb/eval/` e exige o `holdout.json` no git antes do commit que introduz as constantes de `lib/kb-fuse.mjs`, mas `kb-fuse.mjs` nasce na TASK-03 e a cópia de fixture só na TASK-05. Recomendação: colocar as duas cópias de fixture no commit vermelho da TASK-03 (ou antes), ou emendar o REQ-11 para ancorar em `evidence/prototype/holdout.json`. |
| A-04 | MEDIUM | conflict | design §2.9 / TASK-09 × ADR 0001 (baseline) | A ADR 0004, que emenda a 0001, só nasce na TASK-09, depois que as TASK-06..08 materializam a camada opt-in. Recomendação: antecipar a ADR para a TASK-06 (ou antes). |
| A-05 | MEDIUM | drift | design §2.2 (tabela de módulos) × §2.3 / §2.2.1; proposal §4 | A tabela da §2.2 diz que `kb-corpus.mjs` importa só `node:*`, mas a §2.3 o faz usar `lib/yaml-lite.mjs` e `expectedTrust` de `lib/liaison-trust.mjs`; a proposal diz que reaproveita `lib/untrusted-render.mjs`, que só exporta `renderUntrusted`. Recomendação: corrigir a tabela; para a neutralização, extrair um `neutralize()` exportado de `untrusted-render.mjs` (e incluí-lo nos paths da TASK-04) ou ter gate de paridade. |
| A-06 | MEDIUM | coverage | requirements "Checklist de cobertura de superfície" × design §2.11 × tasks.md "Medições" item 1 | (1) Nenhuma linha do checklist define as flags do `eval` (`--json`, `--lexical`) usadas na medição 1 e na §2.11; (2) o checklist atribui `semantic remove|status` à TASK-07, mas é a TASK-04 que implementa `remove` e o `status` sem camada; (3) a linha `info` do doctor não aparece no checklist. Recomendação: ajustar as três linhas. |
| A-07 | MEDIUM | coverage | tasks.md tabela de Rastreabilidade × cabeçalhos das tasks | A tabela liga REQ-10 → TASK-04 e REQ-02 → TASK-05, mas os cabeçalhos dessas tasks não rastreiam esses REQs. Recomendação: sincronizar. |
| A-08 | MEDIUM | risk | design §2.2.1 (instalação na raiz de estado, compartilhada) × rule `conventions/machinery-propagation.md` | Pins são maquinaria por branch; uma worktree com pins diferentes vê "pins mudaram" e, se rodar `semantic install`, sobrescreve a instalação compartilhada e degrada as outras worktrees. Recomendação: endereçar a instalação por `pins_sha256` ou restringir `semantic install` ao checkout principal. |
| A-09 | MEDIUM | risk | NFR-01 × semantic-feasibility.md §4.1 × design §6 | O processo inteiro de `query --lexical` mediu 0,34 s contra a meta de 200 ms; a margem das correções do §2.4 é estreita e o plano B não tem task. Recomendação: fixar no NFR o que é medido e decidir antes o destino do plano B (task condicional ou ledger). |
| A-10 | MEDIUM | risk | design §2.10/§2.12 (devDependencies) × `.github/workflows/ci.yml` (`npm ci \|\| npm install`) | `--ignore-scripts` só cobre o consumidor; no CI e no `npm ci` da worktree o `postinstall` de `protobufjs` roda, e o fallback `\|\| npm install` contorna o lockfile. Recomendação: `ignore-scripts=true` num `.npmrc` (ou a flag no CI) na TASK-06, e reavaliar o fallback. |

## Pendências operacionais (não bloqueiam o artefato)
- O story sharding (`/forge:shard`) é obrigatório em scale 3 e é o próximo passo. Destino: handoff.
- O `spec-delta.yaml` ainda é o template com placeholders; o dono declarado é a medição 6 do verify (REQ-FHT-070…080). Destino: handoff.
- As medições de tempo do verify devem rodar serializadas por `lib/heavy-mutex.sh` (rule `heavy-resource-serialization.md`). Destino: handoff.
- Checagens deterministas limpas: `validate-spec.sh` OK sem WARN SRF-01; `impact-freshness.mjs` `fresh` (G5); `check-data-governance.sh` limpo. Destino: handoff.

## Síntese (2-3 linhas)
A cobertura ponta a ponta fecha nas duas direções (proposal §2.1–2.7 → REQ-01..11 → design §2.3–2.12 → TASK-01..09 + medições do verify), e o recorte do `kb-cli.mjs` por task é coerente e sem colisão. Não há BLOCKER. Os dois HIGH pedem ação antes do implement: a suíte fica vermelha por w200 durante as TASK-01..08 (A-01), e dois critérios de aceite já reprovam no holdout medido (A-02), o que pede decisão do dono registrada agora, não no verify.

## Revisão
Revisor: general-purpose (opus) | Transcrito por: sessão orquestradora (add-unified-knowledge-search, 2026-10-30)

## Tratamento pela sessão orquestradora (registro, não reinterpretação dos achados)
- A-01: cada commit verde das TASK-01..08 atualiza `scripts/ (N)` e o badge `gates-N` do README; `README.md` entra nos paths dessas tasks; a TASK-06 roda depois da Wave 1 (implementação sequencial).
- A-02: a decisão do dono delegada já está registrada no `approvals.yaml` (gate `design_reviewed`, rodada 1, ratificação (c): o design foi aceito sabendo que o verify tende a parar em REQ-03/REQ-07 no holdout, sem ajustar constantes ao holdout já visto; se parar, a decisão volta ao dono com as opções do diagnóstico do canal de entidades).
- A-03: as cópias `tests/fixtures/kb/eval/{calibration,holdout}.json` entram no commit vermelho da TASK-03, antes do commit que introduz as constantes de `kb-fuse.mjs`.
- A-04: a ADR 0004 entra no commit verde da TASK-06 (as asserções de conteúdo continuam no w294 da TASK-09).
- A-05: tabela da §2.2 corrigida; `lib/untrusted-render.mjs` passa a exportar `neutralize()`, usado por `renderUntrusted` e pelo `kb-cli.mjs` (TASK-04), sem mudar a saída de `renderUntrusted`.
- A-06, A-07: checklist e rastreabilidade sincronizados.
- A-08: risco registrado no design §6 e no `/forge:kb`: a instalação é única por máquina e deve ser feita a partir do checkout principal; worktree com pins divergentes cai para lexical com "pins mudaram" e não deve rodar `semantic install`.
- A-09: NFR-01 passa a dizer explicitamente que mede o processo inteiro (`time kb.sh query --lexical`); se a medição do verify passar de 200 ms, o plano B (postings binárias) vai ao ledger com o número medido.
- A-10: risco registrado no design §6 (o `postinstall` de `protobufjs` é uma checagem de versão; o fallback do CI fica como pendência no ledger, fora do escopo deste change).
