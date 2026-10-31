# Medições do verify — add-unified-knowledge-search

Medido em 2026-10-30 sobre o código de produção do HEAD da branch (TASK-01..09 concluídas), Apple M5, Node 26.0.0, com a camada semântica instalada de verdade por `kb.sh semantic install` a partir dos pins (`onnxruntime-web` 1.31.1 e `@huggingface/tokenizers` 0.2.0 via `npm ci --ignore-scripts`; modelos `multilingual-e5-small` int8 e `mmarco-mMiniLMv2-L12-H384-v1` qint8 conferidos por sha256; `kb.sh semantic status` → "integridade confere"). Corpus: 335 documentos, 5.134 trechos. Máquina sem suíte concorrente durante as medições de tempo.

## 1. Qualidade (`kb.sh eval` e `evidence/prototype/eval-noprop.mjs`)

### Calibração (35 consultas)

| Modo | hit@1 | hit@5 | hit@10 | MRR |
|---|---|---|---|---|
| bm25 | 0,429 | 0,743 | 0,771 | 0,556 |
| lexical sem links (informativo) | 0,429 | 0,743 | 0,771 | 0,556 |
| lexical (default) | 0,457 | 0,743 | 0,771 | 0,571 |
| semantic sem links (informativo) | 0,429 | 0,829 | 0,857 | 0,596 |
| semantic (default, sem re-rank) | 0,514 | 0,829 | 0,857 | 0,643 |
| semantic+rerank sem links (informativo) | 0,543 | 0,829 | 0,857 | 0,671 |
| semantic+rerank (default) | 0,600 | 0,857 | 0,857 | 0,709 |

### Holdout (18 consultas)

| Modo | hit@1 | hit@5 | hit@10 | MRR |
|---|---|---|---|---|
| bm25 | 0,611 | 0,889 | 0,944 | 0,730 |
| lexical sem links (informativo) | 0,500 | 0,889 | 0,944 | 0,674 |
| lexical (default) | 0,556 | 0,889 | 0,944 | 0,714 |
| semantic sem links (informativo) | 0,611 | 0,833 | 0,944 | 0,707 |
| semantic (default, sem re-rank) | 0,667 | 0,944 | 0,944 | 0,753 |
| semantic+rerank sem links (informativo) | 0,500 | 0,889 | 0,944 | 0,685 |
| semantic+rerank (default) | 0,611 | 0,889 | 0,944 | 0,750 |

(O `eval-noprop.mjs` dá 0,710 para semantic+rerank na calibração; o `kb.sh eval` dá 0,709 — diferença de empate de ponto flutuante na ordem de um par de documentos, sem efeito em hit@k.)

### Critérios aprovados

| Critério | Calibração | Holdout | Veredito |
|---|---|---|---|
| REQ-03 — lexical: MRR ≥ bm25 e hit@5 no máximo uma consulta abaixo | MRR 0,571 ≥ 0,556; hit@5 igual | **MRR 0,714 < 0,730**; hit@5 igual | **não passa no holdout** (−0,016 de MRR, menos que o valor de uma consulta, 0,028) |
| REQ-06 — semantic+rerank hit@5 ≥ lexical | 0,857 ≥ 0,743 | 0,889 ≥ 0,889 | passa |
| REQ-07 — re-rank não piora o MRR | 0,709 ≥ 0,643 (+0,066) | **0,750 < 0,753** (−0,003) | **não passa no holdout** (6 consultas movidas, saldo −1 em hit@1 e em hit@5) |

Pelos requisitos aprovados (REQ-03, último critério; REQ-07, critério de evidence), as duas falhas no holdout fazem o change parar antes do archive e devolvem a decisão ao dono. Nenhuma constante foi ajustada depois de o holdout ser visto; os números coincidem com os da projeção de design (semantic-feasibility.md §5), o que confirma a medição.

### Diagnóstico por consulta e por canal (corrigido após o gate `implementation_verified`, rodada 1)

**Ablação dos canais lexicais** (MRR; `abl.mjs` do revisor, reproduzido):

| Partição | bm25 | bm25 + entidades | bm25 + links | default (bm25 + entidades + links) |
|---|---|---|---|---|
| Calibração | 0,556 | 0,556 | 0,571 | 0,571 |
| Holdout | 0,730 | 0,674 | 0,779 | 0,714 |

Na calibração o canal de entidades contribui exatamente zero (nenhuma consulta cita id real; as que o acionam casam siglas); no holdout ele só tira (siglas genéricas `README`, `TDD`, `MVP`, `GIT_DIR` puxam documentos errados). A propagação de links ajuda no saldo nas duas partições, embora derrube uma consulta do holdout ("second MVP", 1→3). Ou seja: a falha do REQ-03 no holdout é do canal de entidades, não da fusão como um todo.

**Re-rank, por consulta, no holdout** (posição do primeiro relevante; só as que mudam entre modos; `perq.mjs`):

| Consulta (resumo) | lexical | semantic | semantic+rerank |
|---|---|---|---|
| update desarmava o consumidor | 7 | 5 | 7 |
| contagens do inventário do README | 2 | 1 | 1 |
| divergência silenciava o remetente | 1 | 2 | 2 |
| interruptores de qualidade sem leitor | 1 | 3 | **1** |
| enforcement só para .NET | 2 | 4 | **2** |
| cartões e dado de portador | 2 | 1 | **2** |
| plan for the second MVP | 3 | 1 | **3** |
| harvest do ledger | 3 | 4 | **2** |
| doctor flags placeholders | 2 | 1 | 1 |
| commits direto em develop | 22 | 43 | 43 |

O re-rank move 6 das 18 consultas: 3 sobem (3→1, 4→2, 4→2) e 3 descem (1→2, 1→3, 5→7); perde uma consulta em hit@1 (0,667→0,611) e uma em hit@5 (0,944→0,889). O −0,003 de MRR é o saldo de movimentos que quase se cancelam, não um empate isolado.

## 2. Latência (NFR-01, NFR-02; processo inteiro, melhor de 5, cache quente)

| Operação | arm64 (Node 26) | x86_64 (Node 20.20.2 x64 sob Rosetta — emulação) |
|---|---|---|
| `kb.sh query --lexical` | 0,127 s (alvo < 0,200 s: passa) | 0,215 s (emulado) |
| `kb.sh query --no-rerank` (semântico) | 1,39 s | — |
| `kb.sh query` (semântico com re-rank) | 2,22 s (alvo < 10 s: passa) | 4,98 s |
| `kb.sh build --lexical` (do zero) | 0,53 s (alvo < 5 s: passa) | — |
| `kb.sh build` com vetores (do zero, 5.014 vetores) | 374,5 s (~6 min) | — |
| `kb.sh build` incremental depois de uma edição no `CHANGELOG.md` | 3,0 s (26 vetores recalculados, 25 removidos) | — |

Paridade numérica arm64 × x86_64: para a mesma consulta, os cinco primeiros resultados e os scores do cross-encoder são idênticos até a 4ª casa decimal (`-2,1152`, `-3,2788`, `-5,0940`, `-4,9346`, `-6,8480`). O arquivo `model_qint8_arm64.onnx` roda no WASM em qualquer arquitetura.

## 3. Prova de mutação das guardas (`evidence/prototype/mutation.sh`)

Cada linha: cópia limpa do HEAD com uma mutação; o gate tem de reprovar (controle) e passar na cópia sem mutação (recontrole).

```
fetch( num módulo da busca        w288-kb-offline-lexical-gate.sh controle: FAIL [1] kb-lexical.mjs toca rede/processo: 165:export const x = () => | recontrole: PASS w288-kb-offline-lexical (7 casos; b => OK
host de LLM no CLI                 w288-kb-offline-lexical-gate.sh controle: FAIL [2] referência a provedor de LLM: /tmp/kb-mut.Wzrn5q/ws/template | recontrole: PASS w288-kb-offline-lexical (7 casos; b => OK
curl no kb.sh                      w288-kb-offline-lexical-gate.sh controle: FAIL [3] programa de rede no kb.sh ou incluídos: /tmp/kb-mut.Wzrn5q/w | recontrole: PASS w288-kb-offline-lexical (7 casos; b => OK
interceptador inerte (canário)    w288-kb-offline-lexical-gate.sh controle: FAIL [7] [interceptador] o bloqueio deixou passar: main:fetch:ok       | recontrole: PASS w288-kb-offline-lexical (7 casos; b => OK
corpus aceita untrusted-peer       w284-kb-corpus-gate.sh         controle: FAIL [1] esperados 9 documentos, obtidos 13: baseline .forge/product/c | recontrole: PASS w284-kb-corpus (9 casos)            => OK
varredura nativa desligada         w291-kb-install-gate.sh        controle: FAIL [4] binário nativo não desfez a instalação: kb semantic insta | recontrole: PASS w291-kb-install (7 casos)           => OK
sha256 de modelo não conferido    w292-kb-semantic-gate.sh       controle: FAIL [6] sha: primeira linha 'modo: semantic'                          | recontrole: PASS w292-kb-semantic (8 casos)          => OK
re-rank ignora o cross-encoder     w286-kb-fuse-gate.sh           controle: FAIL [5] re-rank discordante fora da fórmula                          | recontrole: PASS w286-kb-fuse (7 casos)              => OK
carga fora do confinamento         w292-kb-semantic-gate.sh       controle: FAIL [7] symlink-fora: módulo envenenado foi importado                | recontrole: PASS w292-kb-semantic (8 casos)          => OK
```

A mutação "carga fora do confinamento" passou no controle na primeira rodada: a conferência de versões do runtime pegava os casos testados antes de a conferência de caminho real ser alcançada, então nenhum caso exercitava o confinamento sozinho. Acrescentado ao `w292` [7] o caso de pacote do runtime trocado por symlink para fora do diretório instalado, com a versão certa e conteúdo envenenado (commit `test(kb): fuga do confinamento por symlink no gate semântico`); na segunda rodada a mutação reprova o gate (linha acima).

## 4. Vermelho por task (`red-evidence.sh task`, worktree efêmera)

Ver `evidence/task-red-proofs.txt`: TASK-01..09 com `OK task — teste do verde falha por asserção sobre o vermelho … (classificação: behavioral) e passa no verde …`. TASK-07 e TASK-08 com `--setup-command "npm ci --ignore-scripts --no-audit --no-fund --loglevel=error"`.

## 5. Ordem holdout → constantes (REQ-11)

`tests/fixtures/kb/eval/holdout.json` entrou em `b3bf0049` (vermelho da TASK-03), antes do verde `0b26397a` que cria `template/.forge/scripts/lib/kb-fuse.mjs`, e não mudou depois (`git log --follow`). A cópia de evidência entrou em `5a2675bc` e ganhou as três consultas em inglês em `7dd0a8bc`, antes de qualquer constante de fusão.

## 6. Suíte completa

`npm test` (`tests/run-all.sh`) no HEAD da TASK-09: `PASS=194 FAIL=0 SKIP=0 UNVERIFIED=0 (2839s)` — 181 gates pré-existentes + 11 novos (`w284`…`w294`) + 2 suítes bats. Execução dos 11 gates novos em Node 20.20.2 (o piso do harness): todos PASS (w288 e w293 com o interceptador, único mecanismo de bloqueio disponível em Node < 25).

## 7. Licença dos dados de treino

Risco (dados de treino derivados do MS MARCO, termos não comerciais) aceito explicitamente por Milton, dono do projeto, em 2026-10-31, após pesquisa de licenciamento do orquestrador; sem troca de modelo nem revisão jurídica pendente.

## 8. Remedição após a emenda do REQ-03 (2026-10-31)

Código: TASK-10 (siglas genéricas fora do canal de entidades, `INDEX_FORMAT` 2; vermelho provado, `task-red-proofs.txt`). Nenhuma outra constante mudou. Partição nova `holdout-2` (30 consultas, 5 em inglês), escrita sem rodar nenhuma busca e versionada no commit `f59565ef`, anterior ao vermelho da TASK-10 (`e8f1d9d8`). Saída bruta em `evidence/remeasure-2026-10-31.txt`; scripts `prototype/abl.mjs` e `prototype/perq.mjs`.

| Partição | bm25 | lexical | semantic | semantic+rerank |
|---|---|---|---|---|
| Calibração (MRR / hit@5) | 0,556 / 0,743 | 0,571 / 0,743 | 0,628 / 0,829 | 0,695 / 0,857 |
| Holdout-2, limpo (MRR / hit@5) | 0,751 / 1,000 | 0,759 / 0,967 | 0,756 / 0,900 | 0,809 / 0,933 |
| Holdout original, visto — só histórico (MRR / hit@5) | 0,730 / 0,889 | 0,779 / 0,889 | 0,790 / 0,944 | 0,750 / 0,889 |

hit@1 no holdout-2: bm25 0,567 · lexical 0,600 · semantic 0,633 · semantic+rerank 0,700.

Ablação (MRR): calibração bm25 0,556 · +links 0,571 · +entidades 0,556 · completo 0,571; holdout-2 bm25 0,751 · +links 0,796 · +entidades 0,721 · completo 0,759.

### Critérios, julgados na calibração e no holdout-2 (REQ-11 emendado)

| Critério | Calibração | Holdout-2 | Veredito |
|---|---|---|---|
| REQ-03 — lexical: MRR ≥ bm25 e hit@5 no máximo uma consulta abaixo | 0,571 ≥ 0,556; hit@5 igual | 0,759 ≥ 0,751; hit@5 0,967 contra 1,000 (uma consulta) | passa |
| REQ-06 — hit@5 de semantic+rerank ≥ lexical | 0,857 ≥ 0,743 | **0,933 < 0,967** (uma consulta) | **não passa no holdout-2** |
| REQ-07 — re-rank não piora o MRR | 0,695 ≥ 0,628 | 0,809 ≥ 0,756 | passa |

### Decisão do re-rank (critério do dono: opt-in se piorar mais consultas do que melhora)

No holdout-2, entre semantic e semantic+rerank, o re-rank melhora 8 consultas (2→1, 4→2, 2→1, 3→2, 3→1, 2→1, 6→2, 2→1) e piora 4 (1→2, 1→2, 2→3, 1→3); na calibração melhora 6 e piora 2. **O re-rank continua padrão.** (Medido sobre `--no-rerank` contra o default, posição do primeiro relevante por consulta.)

### O que falha e por quê (REQ-06)

A falha não é do re-rank: é do canal vetorial em duas consultas do holdout-2 cujo documento certo está em 1º no lexical e cai para 24º e 20º no semântico ("máquina de estados canônica do archive" e "guarda anti-recursão do gate da suíte"); o re-rank recupera uma parte do resto, mas não essas duas, porque elas saem do top 10. Em MRR e hit@1 o semantic+rerank é o melhor modo do holdout-2 (0,809 e 0,700 contra 0,759 e 0,600 do lexical).
