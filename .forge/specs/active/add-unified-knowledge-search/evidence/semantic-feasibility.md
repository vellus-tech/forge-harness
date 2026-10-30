# Viabilidade da camada semântica — add-unified-knowledge-search

Medido em 2026-10-30, Apple M5 (10 núcleos), macOS, Node 26.0.0 (e checagens pontuais em 20.20.2 e 22.22.2). Protótipo em `evidence/prototype/` (`measure.mjs` primeira rodada; `measure2.mjs` calibração com cache). Tudo aqui é medido, salvo onde marcado "estimativa".

## 1. Runtime de inferência sem binário nativo

| Candidato | Versão | Licença | Dependências | Binário nativo / script de instalação | Veredito |
|---|---|---|---|---|---|
| `onnxruntime-web` | 1.31.1 | MIT | 6 JS (`long`, `platform`, `protobufjs`, `flatbuffers`, `guid-typescript`, `onnxruntime-common`) | nenhum `*.node`; sem `install`/`postinstall`; WASM (`ort-wasm-simd-threaded*.wasm`) | aceito |
| `@huggingface/tokenizers` | 0.2.0 | Apache-2.0 | zero | JS puro | aceito |
| `@huggingface/transformers` | 4.3.2 | Apache-2.0 | `onnxruntime-node` (postinstall baixa binário nativo) e `sharp` (nativo) | sim | rejeitado (viola "sem binding nativo") |
| `onnxruntime-node` | 1.31.1 | MIT | — | `postinstall` + binário nativo | rejeitado |

Conferências executadas: `npm install --ignore-scripts onnxruntime-web@1.31.1` (18 pacotes, 153 MB em disco, `find -name '*.node'` vazio); inferência real de um modelo ONNX em Node 20.20.2, 22.22.2 e 26.0.0, só com o provedor `wasm`; Node 26 executa com threads WASM (CPU observada ~260 %). Metadados conferidos no registry npm em 2026-10-30.

Inferência real com modelo ONNX gerado à mão (protobuf escrito pelo próprio teste, 284 e 352 bytes): `Gather` devolve as linhas esperadas da matriz e `Gather → ReduceMean → MatMul` devolve 0,267, o valor calculado à mão. Isso viabiliza o teste de inferência real na suíte, offline, sem baixar modelo de produção (`evidence/prototype/onnx-fixture.mjs`).

Rede: `node --permission --allow-fs-read='*'` bloqueia `fetch` com `ERR_ACCESS_DENIED` no Node 26 (flag `--allow-net` existe); no Node 22 o mesmo comando acessa a rede (modelo de permissões sem controle de rede). Daí o REQ-09 exigir os dois mecanismos.

## 2. Modelos candidatos (metadados da API do Hugging Face, sha256 conferido após download)

| Papel | Modelo | Arquivo | Tamanho | sha256 (LFS) | Licença | Língua |
|---|---|---|---|---|---|---|
| embedding | `Xenova/multilingual-e5-small` (de `intfloat/multilingual-e5-small`) | `onnx/model_int8.onnx` | 118.054.593 B | `4d24e2bc…cc0d47333da0b1b741410eb128` (completo em models.json) | MIT (modelo original) | multilíngue |
| embedding | idem | `tokenizer.json` | 17.082.730 B | `0b44a9d7…` | — | — |
| re-rank | `cross-encoder/mmarco-mMiniLMv2-L12-H384-v1` | `onnx/model_qint8_arm64.onnx` | 118.620.017 B | `1825907d…5c8b4` | Apache-2.0 | multilíngue (mMARCO) |
| re-rank | idem | `tokenizer.json` | 17.082.660 B | `62c24cdc…` | — | — |
| embedding estático | `minishlab/potion-multilingual-128M` | `model.safetensors` | 512.361.560 B | `14b5eb39…` | MIT | multilíngue |
| embedding estático | `minishlab/potion-base-8M` | `model.safetensors` | 30.236.760 B | `f65d0f32…` | MIT | inglês |

O corpus é majoritariamente pt-BR, por isso modelos só-inglês (ex.: `all-MiniLM-L6-v2`, `ms-marco-MiniLM-L-6-v2`) não foram adotados; `potion-base-8M` entrou só como controle e confirmou o esperado (abaixo). Reranker `jina-reranker-v2-base-multilingual` descartado por licença CC-BY-NC-4.0 e 280 MB; `bge-reranker-v2-m3` descartado por 570 MB em int8.

Download total da camada escolhida: ~150 MB do runtime npm (descompactado) + ~270 MB de modelos e tokenizadores.

## 3. Qualidade no conjunto de calibração (34 consultas, `evidence/prototype/queries.json`)

Métricas em nível de documento. Primeira rodada (`measure.mjs`, tokenizador Unigram aproximado escrito no protótipo; pesos lexicais WE = 0,5, WL = 0,1, links restritos ao top 20 das sementes):

| Configuração | hit@1 | hit@5 | hit@10 | MRR |
|---|---|---|---|---|
| BM25 isolado | 0,441 | 0,735 | 0,794 | 0,556 |
| BM25 + entidades (RRF) | 0,412 | 0,735 | 0,794 | 0,541 |
| Lexical fundido (BM25 + entidades + links) | 0,353 | 0,647 | 0,853 | 0,491 |
| Lexical fundido + re-rank (cross-encoder) | 0,382 | 0,735 | 0,853 | 0,534 |
| potion-base-8M, vetor isolado | 0,118 | 0,324 | 0,441 | 0,230 |
| potion-multilingual-128M, vetor isolado | 0,176 | 0,529 | 0,735 | 0,345 |
| Lexical + potion-multilingual (RRF) | 0,265 | 0,647 | 0,824 | 0,441 |
| Lexical + potion-multilingual + re-rank | 0,265 | 0,735 | 0,824 | 0,473 |
| **multilingual-e5-small, vetor isolado** | 0,353 | **0,824** | 0,882 | 0,557 |
| **Lexical + e5 (RRF, peso 1)** | **0,471** | 0,765 | 0,853 | **0,604** |
| Lexical + e5 + re-rank (RRF k = 5 entre posições) | 0,353 | 0,824 | 0,853 | 0,560 |

Leituras: (1) o embedding denso e5 é o único sinal que supera o BM25 em hit@5 sozinho; os embeddings estáticos (potion) pioram a fusão e foram descartados; (2) os links, com peso cheio, derrubam o hit@1 (0,441 → 0,176 com peso 1 e sem restrição); com peso 0,1 e restritos a candidatos ainda custam hit@1 e ganham hit@10; (3) o re-rank na forma da primeira rodada sobe o hit@5 e derruba o hit@1, e por isso a forma de combinação é calibrada na seção 5.

Calibração dos pesos lexicais (mesma rodada, sem camada semântica):

| WE (entidades) | WL (links) | Links restritos a | hit@1 | hit@5 | hit@10 | MRR |
|---|---|---|---|---|---|---|
| 1,0 | 1,0 | — | 0,176 | 0,471 | 0,647 | 0,319 |
| 0,5 | 0,25 | — | 0,324 | 0,647 | 0,882 | 0,461 |
| 0,5 | 0,5 | — | 0,324 | 0,676 | 0,765 | 0,442 |
| 0,5 | 0 | — | 0,412 | 0,735 | 0,794 | 0,541 |
| 0,5 | 0,25 | top 20 | 0,324 | 0,676 | 0,794 | 0,455 |
| 0,5 | 0,25 | top 50 | 0,294 | 0,676 | 0,765 | 0,438 |

## 4. Latência e custo

| Operação | Medido |
|---|---|
| Embeddings e5 de 5.167 trechos (WASM, 256 tokens por trecho) | 1.153,8 s (~19 min, ~0,22 s por trecho) — custo de primeira vez; cache por sha256 do trecho evita recálculo |
| Embeddings potion-multilingual de 5.167 trechos (JS puro) | 36,5 s |
| Carga do potion-multilingual (512 MB) | 1,7 s |
| Re-rank cross-encoder de 10 candidatos (380 tokens) | 3,4–4,6 s por consulta |
| Memória residente no fim da rodada completa | baixa (o processo devolve a memória dos modelos; pico não instrumentado) |

## 5. Calibração final (com tokenizador oficial e cache)

PREENCHER-RUN2

## 6. Limitações

As consultas e os rótulos foram escritos pelo autor do change sobre este corpus. O conjunto de calibração (34) foi usado para escolher pesos; o holdout (15, `evidence/prototype/holdout.json`) foi escrito e versionado (commit `5a2675bc`) antes da calibração final e não foi usado para escolher nada. Com 34 consultas, uma consulta vale ~0,03 em hit@k: diferenças menores que 0,06 são ruído. Números valem como comparação relativa entre modos neste corpus, não como qualidade absoluta, e não são comparáveis ao hit@5 citado pelo autor do `ai-memory` (0,617 → 0,779), que é de outro corpus e não foi verificado.
