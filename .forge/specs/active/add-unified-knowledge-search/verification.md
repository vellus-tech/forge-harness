# Verification — add-unified-knowledge-search

## Resultado: RESSALVAS

Toda a implementação foi conferida contra o código e os gates, e a suíte passa inteira. Dois critérios de qualidade medidos com os modelos de produção não passam na partição de holdout por margem menor que uma consulta: REQ-03 (MRR do lexical 0,714 contra 0,730 do BM25 isolado) e REQ-07 (re-rank 0,750 contra 0,753 sem re-rank). Pelos requisitos aprovados, isso impede o archive e devolve a decisão ao dono (seção "Decisão pendente do dono").

## Evidências por requisito

| REQ | Implementado em | Verificado por | Status |
|---|---|---|---|
| REQ-01 | `template/.forge/scripts/lib/kb-corpus.mjs` (`collect`, `chunk`; liaison só `trust === 'self'` e `expectedTrust(msg, self, self) === 'self'`; `body_ref` nunca seguido) | `tests/w284-kb-corpus-gate.sh` [1]–[7] (as seis fontes, blobs, cinco formas de mensagem não confiável, fontes proibidas, ilegíveis contados, raiz vazia, duas raízes); mutação "corpus aceita untrusted-peer" reprova o [3] | VERIFICADO |
| REQ-02 | `kb-corpus.mjs` (`fingerprint`, `quickFingerprint`), `kb-lexical.mjs` (`buildIndex`, `texts.bin`), `kb-cli.mjs` (`loadIndex`, `indexState`, regravação da impressão rápida) | `w284` [9]; `w285` [5]–[6]; `w287` [1]–[3] (byte-idêntico, atual/defasado/ausente, aviso em stderr, `rebuilt`); `w288` [6] e `w293` [1] (sob bloqueio de rede) | VERIFICADO |
| REQ-03 | `kb-lexical.mjs` (BM25, entidades, grafo de links), `kb-fuse.mjs` (`rrf`, `propagateLinks`, constantes), `kb-cli.mjs` (`search`) | `w285` [1]–[4], [7]; `w286` [1]–[3]; `w287` [6], [10]; `w288` [4] (só `node:*` e harness); medição de qualidade na seção "Medições" | VERIFICADO — critério de qualidade: calibração passa (MRR 0,571 ≥ 0,556); **holdout não passa** (MRR 0,714 < 0,730, hit@5 igual) |
| REQ-04 | `kb-cli.mjs` (`printText`, `--json`, `snippet` via `neutralize()` de `lib/untrusted-render.mjs`, `--top`, `--lexical`) | `w287` [4]–[9]; `w288` [2] (provedores de LLM); mutação "host de LLM no CLI" reprova o `w288` | VERIFICADO |
| REQ-05 | `lib/kb-pins/` (lockfile com `integrity`, `models.json` por revisão e sha256), `lib/kb-integrity.mjs`, `lib/kb-install.mjs`, `kb-cli.mjs` (`semantic install|remove|status`), confinamento em `kb-semantic.mjs` | `w290` [1]; `w291` [1]–[7]; `w292` [6] (oito degradados, inclusive pins alterados e binário nativo por extensão e por ELF), [7] (módulos envenenados no projeto, quatro situações), [8]; `w294` [2] (doctor não cria `.forge/kb/semantic`); mutações "varredura nativa desligada" e "carga fora do confinamento" reprovam | VERIFICADO |
| REQ-06 | `kb-semantic.mjs` (`embed`, `buildVectors`, `vectorSearch`, `vectors.bin` de arquivo único gravado a cada 200), `kb-cli.mjs` (canal vetorial) | `w292` [2]–[3], [5] (inferência real no `onnxruntime-web` com modelos ONNX de fixture; incremental; build interrompido preserva); qualidade com modelos de produção na seção "Medições" | VERIFICADO — critério de qualidade passa nas duas partições (hit@5 semantic+rerank 0,857 ≥ 0,743 e 0,889 ≥ 0,889) |
| REQ-07 | `kb-fuse.mjs` (`combineRerank`, desempate pelo cross-encoder), `kb-semantic.mjs` (`crossScore`, `representative`), `kb-cli.mjs` (re-rank, `--no-rerank`) | `w286` [4]–[6] (concordante, discordante nas duas ordens do meio, cauda); `w292` [4] (re-rank real com `ce_score`, `--no-rerank`); mutação "re-rank ignora o cross-encoder" reprova o `w286`; medição na seção "Medições" | VERIFICADO — critério de qualidade: calibração passa (MRR 0,709 contra 0,643 sem re-rank); **holdout não passa** (0,750 contra 0,753) |
| REQ-08 | `kb-cli.mjs` (`loadSemantic`, quedas para lexical), `kb-integrity.mjs` (`verify`) | `w292` [6] (oito casos, `query` e `build`, exit 0 e motivo); `w293` [2] (os oito sob bloqueio de rede); `w287` [8] (erros de uso, exit 2) | VERIFICADO |
| REQ-09 | só `lib/kb-install.mjs` importa `fetch`/`child_process`; `kb.sh` só chama `node` e `git rev-parse` | `w288` [1], [3], [5]–[7] e `w293` [1]–[2] (permissões do Node 26 sem `--allow-net` e interceptador `--require` com pontos de estrangulamento de socket; `mode: semantic` conferido; canário de 8 tentativas bloqueado sob cada mecanismo e liberado no recontrole); `kb.md` (política de cloud) por `w294` [1]; mutações "fetch( num módulo", "curl no kb.sh" e "interceptador inerte" reprovam | VERIFICADO |
| REQ-10 | `template/.forge/commands/graph/kb.md`, remissão em `query.md`, `installer/gitignore.patch`, `.gitignore`, `doctor.sh`, `plugin/forge/commands/kb.md`, README, `docs/refer/slash-commands.md` | `w294` [1]–[2] (inclui worktree git real sem `FORGE_ROOT`); `plugin-sync-gate`, `w133-gitignore-reconcile-gate`, `w200-readme-inventory-gate` | VERIFICADO |
| REQ-11 | `kb-cli.mjs` (`cmdEval`, `metrics`, aviso de fragmento largo, `gold_matches`), `tests/fixtures/kb/eval/` | `w289` [1]–[2] (métricas contra valores à mão, consulta sem relevante, cópias literais, 4 em inglês por partição); `w292` [8] (modos `semantic` e `semantic+rerank`); ordem holdout → constantes por `git log` (seção "Medições") | VERIFICADO |
| NFR-01 | `kb-lexical.mjs` (texto em `texts.bin`), `kb-corpus.mjs` (impressão rápida) | medição na seção "Medições" | VERIFICADO — consulta lexical 0,127 s (alvo < 0,200 s), build lexical 0,53 s (alvo < 5 s), arm64; 0,215 s em x86_64 emulado |
| NFR-02 | `kb-semantic.mjs` | medição na seção "Medições" | VERIFICADO — consulta semântica com re-rank 2,22 s (arm64) e 4,98 s (x86_64 emulado), alvo < 10 s; build de vetores do zero 374,5 s, incremental 3,0 s |
| NFR-03 | `kb-cli`/`kb-corpus`/`kb-lexical`/`kb-fuse` só com `node:*` e módulos do harness; camada semântica por `import()` dinâmico | `w288` [4]; todos os gates lexicais rodam em `/tmp`, sem `node_modules` acima; `w287` passa sem devDependencies | VERIFICADO |

## Checks deterministas

- `spec-verify.sh add-unified-knowledge-search`: `OK add-unified-knowledge-search (verification.yaml written)`; spec-delta autorado, não sobrescrito. `checks`: nenhum declarado em `FORGE.md runtime:` no dogfood (esperado).
- Checkpoints de story: `spec-verify.sh --story STORY-01..04`, todos OK (`stories/STORY-0N.verification.yaml`).
- Suíte completa (`npm test`): `PASS=194 FAIL=0 SKIP=0 UNVERIFIED=0` em 2.839 s (192 gates + 2 suítes bats).
- Os 11 gates novos em Node 20.20.2 (piso do harness): ver `evidence/verify-measurements.md` §6.
- Vermelho por task: TASK-01..09 provados por `red-evidence.sh task` (`evidence/task-red-proofs.txt`).
- Prova de mutação: 9 mutações nas guardas (rede, LLM, `curl`, canário, corpus, varredura nativa, sha256, confinamento, re-rank), todas reprovam o gate e voltam a passar sem a mutação (`evidence/verify-measurements.md` §3).

## Medições do verify

Ver `evidence/verify-measurements.md` (qualidade nas duas partições, com e sem propagação de links; latência arm64 e x86_64 emulado; paridade numérica; mutação; ordem holdout → constantes).

## Spec delta

`spec-delta.yaml` com 11 `add_requirement` na capability `forge-harness-template` (REQ-FHT-070…080), um por REQ, com cenários observáveis e os gates que os verificam. Numeração a partir de 070 porque a spec ativa `data-engineer-agent` reserva até REQ-FHT-064; colisão com change paralelo se resolve no merge.

## Desvios e observações

- **Desvio de código entre tasks, registrado:** o `kb-cli.mjs` foi recortado por task (lexical na TASK-04, eval na TASK-05, instalação e status na TASK-07, canal vetorial, re-rank e eval semântico na TASK-08), como pediu o revisor do gate de tasks; o vermelho de cada task foi provado por execução.
- **Gate fortalecido no verify:** a prova de mutação mostrou que a conferência de caminho real do runtime não era exercitada sozinha; acrescentado ao `w292` [7] o caso de symlink para fora do confinamento (só teste; o código já fazia a conferência).
- **`lib/untrusted-render.mjs`:** passou a exportar `neutralize()`, usado por `renderUntrusted` e pelo `/forge:kb`; a saída de `renderUntrusted` não muda (`w112` e `w121` passam).
- **Instalação compartilhada por máquina:** a camada semântica fica no checkout principal; worktree com pins divergentes cai para lexical com "pins mudaram" (design §6, `kb.md`).
- **Fora do escopo, para o ledger:** fallback `npm ci || npm install` do CI contorna o lockfile (analysis A-10); baseline `forge-harness-template` traz um cenário de REQ-FHT-004 com barras invertidas multiplicadas (dado pré-existente, não tocado por este change).

## Decisão pendente do dono

Os critérios do REQ-03 e do REQ-07 falham só no holdout, por menos que o valor de uma consulta (0,028 de MRR numa partição de 18), e nenhuma constante foi ajustada depois de o holdout ser visto. Pelos requisitos aprovados, o archive não acontece sem decisão do dono. Opções:

1. **Aceitar as duas perdas como ruído** (decisão explícita do dono registrada no `approvals.yaml`) e seguir para o archive. Fundamento: na calibração os dois critérios passam com folga; no holdout, a busca semântica com re-rank (0,750) ainda supera o lexical (0,714) e o BM25 (0,730), e o re-rank perde por um único empate.
2. **Corrigir a causa medida e medir de novo com um holdout novo:** emendar o REQ-03 para tirar do canal de entidades as siglas genéricas (só ids reais: `LDG-NNNN`, `ADR NNNN`, `REQ-*`, `wNNN`, arquivos, `/forge:*`), recalibrar só na calibração, escrever um holdout novo antes de medir (o atual está visto) e repetir o verify. Custo: uma rodada de requirements/design/tasks curta e uma task.
3. **Tirar o re-rank do default** (`--rerank` opcional em vez de `--no-rerank`), mantendo-o implementado — contraria o espírito da decisão "memória semântica com re-rank", por isso só com o dono.
