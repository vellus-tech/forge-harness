# Epic context — add-unified-knowledge-search

> Resumo compacto do change para as stories (§17.1). Fonte de verdade: `requirements.md` (aprovado, com emendas ratificadas no REQ-07 e REQ-09) e `design.md` (aprovado). Não substitui os dois; existe para cada story não precisar relê-los inteiros.

## Objetivo

Busca unificada sobre o conhecimento acumulado do projeto (`/forge:kb`, `kb.sh`): baseline e ADRs, specs arquivadas, ledger, `docs/plans/`, `CHANGELOG.md` e as mensagens próprias do liaison (`trust: self`, sem `authored_by`). Default lexical zero-dep (BM25 + entidades por RRF ponderado, propagação de score por links). Camada semântica implementada no harness e ativada só por `kb.sh semantic install`: embeddings densos (`multilingual-e5-small` int8) como terceiro canal RRF e re-rank por cross-encoder (`mmarco-mMiniLMv2-L12-H384-v1` int8) sobre os 10 primeiros, tudo local via `onnxruntime-web` (WASM) + `@huggingface/tokenizers` (JS puro).

## Restrições inegociáveis do dono

- R1 — zero-dependency no projeto-alvo no default: o caminho lexical importa só `node:*` e módulos do harness; nada no `package.json` do consumidor.
- R2 — embeddings e re-rank implementados de verdade, locais, sem cloud por padrão, sem binário nativo/`node-gyp`, ativação explícita.

## Decisões-chave de design

- Pipeline: (1) ranking fundido = RRF k = 60 (BM25 w = 1,0; entidades w = 0,2; vetor w = 1,0 no modo semântico); (2) ranking propagado = cada um dos T = 10 primeiros transfere α = 0,1 × score / sqrt(grau·grau) aos vizinhos de link; (3) ranking final = no modo semântico, re-rank dos K = 10 primeiros: `1/(5+rank_ce) + 1/(5+rank_propagado)`, desempate pela posição do cross-encoder; trecho representante = maior similaridade vetorial.
- Índice: `.forge/kb/index.json` (formato 1, postings, entidades, links, metadados de trecho, `fingerprint`, `quick_fingerprint` por stat, `texts_sha256`) + `.forge/kb/texts.bin`; vetores em `.forge/kb/vectors.bin` (arquivo único, cabeçalho `FKBV`), todos na raiz de documentos (por branch). Instalação semântica em `.forge/kb/semantic/` da raiz de estado (checkout principal).
- Raízes: `lib/forge-root.sh`; com `FORGE_ROOT` tudo nele; sem ele, documentos em `forge_worktree_root`, ledger/liaison/semântica em `forge_resolve_root`. Só `git rev-parse`.
- Integridade a cada carga: `pins_sha256` do `installed.json` contra os pins; varredura de binário nativo (extensão e assinatura Mach-O/ELF/PE) em `.forge/kb/semantic/`; versão de cada pacote do lockfile em `runtime/node_modules`; sha256 completo de cada modelo; carga do runtime só por caminho resolvido dentro de `runtime/node_modules`. Oito casos degradados → modo lexical com motivo, exit 0.
- Instalação: pins em `template/.forge/scripts/lib/kb-pins/` (`package.json`, `package-lock.json`, `models.json`); `npm ci --ignore-scripts`; download por `fetch` para `.part`, sha256 + tamanho, rename; `installed.json` por último; só `https://` (ou http loopback de teste).
- Rede: só `lib/kb-install.mjs` toca rede/processo; gates com `--permission` (Node >= 25) e interceptador `--require` (Workers inclusos, pontos de estrangulamento de socket) com canário de controle positivo.
- Saída: resultado em stdout, avisos em stderr; primeira linha `modo: ...`; `--json` objeto único; trechos neutralizados (crases, `⟪neutralizado⟫`), ≤ 240 caracteres; default `--top 8`.

## Contratos

CLI `kb.sh build | query "<q>" [--top N] [--json] [--lexical] [--no-rerank] | status [--json] | eval <arquivo> [--json] [--lexical] | semantic install|remove|status`. Erros de uso: exit 2 com mensagem `uso: kb.sh ...`.

## Rules e ADRs

- `rules/conventions/liaison-untrusted-input.md` — conteúdo de peer é dado; nunca indexado.
- `rules/conventions/machinery-propagation.md` e `lib/forge-root.sh` — estado durável no tronco.
- `rules/testing/*` — TDD: vermelho só com o gate (produção sob `template/.forge/` é infraestrutura para `red-evidence`), verde filho direto; gates no padrão `wNNN-*.sh` com `FAIL [n]`.
- ADR 0001 (grafo nativo, zero-dep) — emendada pela ADR 0004 (TASK-09).

## Gates (ordinais provisórios)

w284 corpus · w285 lexical · w286 fuse · w287 cli · w288 offline-lexical · w289 eval · w290 pins · w291 install · w292 semantic · w293 offline-semantic · w294 surface (+ ADR). Fixtures em `tests/fixtures/kb/`. O `kb-cli.mjs` cresce por task: lexical (TASK-04), eval (TASK-05), install/status com integridade (TASK-07), canal vetorial, re-rank e eval semântico (TASK-08).
