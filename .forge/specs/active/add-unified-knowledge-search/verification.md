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
- **Refactor no verify:** removidos `linkNeighbors`/`LINK_SEEDS` de `kb-lexical.mjs` (resto do desenho de links como canal, sem chamador) e corrigido o comentário do cache de vetores em `kb-cli.mjs`; `w285`, `w287`, `w288` e `w292` passam depois.
- **`lib/untrusted-render.mjs`:** passou a exportar `neutralize()`, usado por `renderUntrusted` e pelo `/forge:kb`; a saída de `renderUntrusted` não muda (`w112` e `w121` passam).
- **Instalação compartilhada por máquina:** a camada semântica fica no checkout principal; worktree com pins divergentes cai para lexical com "pins mudaram" (design §6, `kb.md`).
- **Fora do escopo, para o ledger:** fallback `npm ci || npm install` do CI contorna o lockfile (analysis A-10); baseline `forge-harness-template` traz um cenário de REQ-FHT-004 com barras invertidas multiplicadas (dado pré-existente, não tocado por este change).

## Licença dos dados de treino dos modelos — risco aceito pelo dono

Os dois modelos fixados (`multilingual-e5-small`, MIT; `mmarco-mMiniLMv2-L12-H384-v1`, Apache-2.0) foram treinados com dados derivados do MS MARCO, cujos termos são de uso não comercial. Depois de pesquisa de licenciamento feita pelo orquestrador, **Milton (dono do projeto) aceitou explicitamente o risco em 2026-10-31** e decidiu seguir sem trocar de modelo e sem segurar o change por revisão jurídica. Justificativa registrada: risco conhecido e documentado (design §6, ADR 0004), uso local sem redistribuição dos pesos pelo harness (o consumidor baixa da origem por comando explícito), e troca de modelo possível a qualquer momento por mudança de pins, sem mudança de código. Não é pendência aberta.

## Decisão pendente do dono (histórico — resolvida em 2026-10-31, ver "Remedição")

O que foi medido (detalhe em `evidence/verify-measurements.md` §1): na partição de **calibração** os três critérios de qualidade passam com folga; na de **holdout** (18 consultas), dois não passam:

- **REQ-03** — MRR do lexical 0,714 contra 0,730 do BM25 isolado (hit@5 igual). Causa medida por ablação: o canal de entidades vale zero na calibração e só tira no holdout (bm25 + entidades = 0,674), por casar siglas genéricas; a propagação de links ajuda no saldo (bm25 + links = 0,779).
- **REQ-07** — re-rank 0,750 contra 0,753 sem re-rank. Não é um empate isolado: o re-rank move 6 consultas, 3 para cima e 3 para baixo, e perde uma consulta em hit@1 e uma em hit@5.

Fatos que o dono precisa ter à vista: (a) as constantes de fusão e de re-rank não foram ajustadas ao holdout; (b) **a regra de desempate do re-rank foi trocada depois de o holdout ter sido visto** (da posição propagada para a posição do cross-encoder), motivada por uma contradição interna do critério (ii) do REQ-07 e ratificada no gate de design — a troca subiu o MRR do holdout de 0,721 para 0,749 e, mesmo assim, o critério não passa; o holdout do REQ-07 não está, portanto, intacto; (c) com 18 consultas, uma consulta vale 0,028 de MRR, e as duas diferenças (−0,016 e −0,003) estão abaixo disso; (d) leitura literal do REQ-07: a cláusula "se, ainda assim, piorar o MRR no holdout" vem depois de "se o re-rank piorar o MRR na calibração", que não ocorreu — por essa leitura o REQ-07 não bloquearia; este verify adota a leitura conservadora (bloqueia) e deixa a interpretação ao dono.

Pelos requisitos aprovados, o archive não acontece sem decisão do dono. O bloqueio está registrado no `approvals.yaml` (gate `implementation_verified`, `notes`) e é efetivo no gate `human_archive_approval`, que é do dono. Opções:

1. **Aceitar as duas perdas como ruído** e seguir para o archive (decisão explícita registrada). Fundamento: calibração passa com folga; no holdout o semântico com re-rank (0,750) supera o lexical (0,714) e o BM25 (0,730).
2. **REQ-03 — tirar as siglas genéricas do canal de entidades** (manter só ids reais: `LDG-NNNN`, `ADR NNNN`, `REQ-*`, `wNNN`, arquivos, `/forge:*`), por emenda do REQ-03; recalibrar só na calibração; escrever um holdout **novo** antes de medir (o atual está visto). Corrige só o REQ-03; o REQ-07 continua dependendo da opção 1, 4 ou 5.
3. **REQ-03 — canal de entidades com peso 0 (ou removido)**, justificável só pela calibração (onde ele contribui zero); exige emenda do REQ-03 (que exige o canal) e holdout novo, porque o atual já mostra bm25 + links em 0,779. Também só corrige o REQ-03.
4. **Não mudar código e medir num holdout novo e maior** (por exemplo 50 consultas, escritas antes de medir), para testar se as duas perdas são ruído. Vale para REQ-03 e REQ-07.
5. **REQ-07 — tirar o re-rank do default** (`--rerank` opcional), mantendo-o implementado e testado. Contraria o espírito da decisão "memória semântica com re-rank"; só com o dono.

Custo em emendas: as opções 2, 3 e 4 exigem emendar o REQ-11 do change (holdout novo; o critério atual proíbe mudar o `holdout.json` depois das constantes); as opções 2, 3 e 5 exigem emendar o REQ-FHT-072 ou o REQ-FHT-076 do `spec-delta.yaml` antes do archive; a opção 4 só exige emendar esses REQs se o holdout novo também falhar.
