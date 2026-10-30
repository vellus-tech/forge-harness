# Tasks — add-unified-knowledge-search

> Tasks do change `add-unified-knowledge-search`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (commit de vermelho + commit de implementação), rastreável a um REQ/seção do design, e declara o que toca.
> Cada task declara `Teste (comando)` e `Padrão de falha` (e `Setup do teste`, quando o teste precisa das devDependencies): o Red é provado por execução (`red-evidence.sh task`). Neste repositório todo arquivo de produção mora sob `template/.forge/` (ou `.forge/`), que `isInfraPath` trata como infraestrutura (segmento iniciado por ponto), então o commit de vermelho contém **só arquivos sob `tests/`** (gate e fixtures de teste), sem stub de produção; cada gate converte a ausência do comportamento em `FAIL [n]` explícito (nada de erro de módulo ou de `set -e` antes da linha de falha), e o verde traz a implementação.
> O `red-evidence.sh task` roda o teste numa worktree efêmera em `$TMPDIR`, sem `node_modules`: as tasks cujo gate exige as devDependencies (`onnxruntime-web`, `@huggingface/tokenizers`) declaram `Setup do teste: npm ci --ignore-scripts --no-audit --no-fund --loglevel=error`. Depois da TASK-06, a worktree de trabalho também precisa de `npm ci`.
> Ordinais de gate (`w284`…`w294`) derivados de `gate-ordinal.sh next` em 2026-10-30 (máximo remoto `w283`); colisão com branch paralela é resolvida por renomeação na hora do merge, nunca por reserva.
> Cada task tem gate(s) próprio(s) que passa(m) no verde dela; nenhum gate depende de task posterior.

## Wave 1 — Fundação lexical (zero-dep)

- [ ] TASK-01 — Corpus: fontes, exclusões (inclusive `expectedTrust` de `lib/liaison-trust.mjs`), corte em trechos, impressões digitais de conteúdo e rápida (rastreia: REQ-01, REQ-02, design §2.3, §2.4; paths: `template/.forge/scripts/lib/kb-corpus.mjs`, `tests/w284-kb-corpus-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w284-kb-corpus-gate.sh`
  - Padrão de falha: `FAIL \[[^]]+\]`
- [ ] TASK-02 — Índice lexical: normalização, BM25, entidades, grafo de links, texto em `texts.bin`, serialização determinística (rastreia: REQ-02, REQ-03, design §2.4; paths: `template/.forge/scripts/lib/kb-lexical.mjs`, `tests/w285-kb-lexical-gate.sh`; depende: TASK-01)
  - Teste (comando): `bash tests/w285-kb-lexical-gate.sh`
  - Padrão de falha: `FAIL \[[^]]+\]`
- [ ] TASK-03 — Fusão: RRF ponderado, propagação de links e combinação do re-rank (desempate pelo cross-encoder) como funções puras, com as constantes calibradas (rastreia: REQ-03, REQ-07, design §2.5, §2.6; paths: `template/.forge/scripts/lib/kb-fuse.mjs`, `tests/w286-kb-fuse-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w286-kb-fuse-gate.sh`
  - Padrão de falha: `FAIL \[[^]]+\]`

## Wave 2 — CLI lexical, avaliação e guardas do caminho lexical

- [ ] TASK-04 — `kb.sh` e `kb-cli.mjs` no modo lexical: build, query, status, saída texto e `--json`, neutralização de trecho, reconstrução automática e regravação da impressão rápida, `--lexical`, `--top`, erros de uso, carga dinâmica da camada semântica pela raiz de estado (rastreia: REQ-02, REQ-03, REQ-04, REQ-08, design §2.2, §2.2.1, §2.5, §2.11; paths: `template/.forge/scripts/kb.sh`, `template/.forge/scripts/lib/kb-cli.mjs`, `tests/w287-kb-cli-gate.sh`; depende: TASK-02, TASK-03)
  - Teste (comando): `bash tests/w287-kb-cli-gate.sh`
  - Padrão de falha: `FAIL \[[^]]+\]`
- [ ] TASK-05 — `kb.sh eval` (modos bm25 e lexical, métricas, consulta sem relevante, aviso de fragmento largo), conjunto de avaliação versionado e guardas do caminho lexical: estáticos de imports, provedores de LLM e programas do `kb.sh`; `git` substituto; bloqueio de rede (permissões do Node e interceptador `--require` com pontos de estrangulamento) sobre build/query/status/eval/semantic status/semantic remove; canário de controle positivo (rastreia: REQ-04, REQ-09, REQ-11, NFR-03, design §2.8, §2.11, §2.12; paths: `template/.forge/scripts/lib/kb-cli.mjs`, `tests/fixtures/kb/eval/calibration.json`, `tests/fixtures/kb/eval/holdout.json`, `tests/fixtures/kb/semantic-env.sh`, `tests/fixtures/kb/serve.mjs`, `tests/fixtures/kb/no-network.cjs`, `tests/fixtures/kb/net-canary.mjs`, `tests/fixtures/kb/fake-git.sh`, `tests/w289-kb-eval-gate.sh`, `tests/w288-kb-offline-lexical-gate.sh`; depende: TASK-04)
  - Teste (comando): `bash tests/w289-kb-eval-gate.sh && bash tests/w288-kb-offline-lexical-gate.sh`
  - Padrão de falha: `FAIL \[[^]]+\]`
  - Nota: a ordem holdout → constantes do REQ-11 é provada sobre `evidence/prototype/holdout.json` (versionado em `5a2675bc`/`7dd0a8bc`, antes de `lib/kb-fuse.mjs` existir); as cópias em `tests/fixtures/kb/eval/` são byte a byte iguais (o w289 confere com `cmp`).

## Wave 3 — Camada semântica

- [ ] TASK-06 — Pins do runtime e dos modelos e devDependencies do workspace nas mesmas versões (rastreia: REQ-05, design §2.2, §2.6, §2.10; paths: `template/.forge/scripts/lib/kb-pins/package.json`, `template/.forge/scripts/lib/kb-pins/package-lock.json`, `template/.forge/scripts/lib/kb-pins/models.json`, `package.json`, `package-lock.json`, `tests/w290-kb-pins-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w290-kb-pins-gate.sh`
  - Padrão de falha: `FAIL \[[^]]+\]`
- [ ] TASK-07 — Instalação da camada semântica: `lib/kb-integrity.mjs` (varredura de binário nativo por extensão e assinatura, hash dos pins, conferência completa, status), `lib/kb-install.mjs` (único módulo com rede: anúncio, `npm ci --ignore-scripts`, varredura, download com sha256 e tamanho, só https ou loopback, `installed.json` por último) e `kb.sh semantic install|remove|status`; teste estático de que só o ramo `semantic install` carrega o instalador; fixtures de modelos ONNX gerados e `npm` substituto (rastreia: REQ-05, design §2.6 (integridade), §2.7, §2.10, §2.12; paths: `template/.forge/scripts/lib/kb-integrity.mjs`, `template/.forge/scripts/lib/kb-install.mjs`, `template/.forge/scripts/lib/kb-cli.mjs`, `tests/fixtures/kb/make-semantic-fixture.mjs`, `tests/fixtures/kb/fake-npm.sh`, `tests/w291-kb-install-gate.sh`; depende: TASK-05, TASK-06)
  - Teste (comando): `bash tests/w291-kb-install-gate.sh`
  - Padrão de falha: `FAIL \[[^]]+\]`
  - Setup do teste: `npm ci --ignore-scripts --no-audit --no-fund --loglevel=error`
- [ ] TASK-08 — Carga e inferência: `lib/kb-semantic.mjs` (carga confinada a `runtime/node_modules`, embeddings com prefixos e mean pooling, cache `vectors.bin` de arquivo único gravado a cada 200 trechos e retomado após interrupção, aviso de vetores faltando, cross-encoder com trecho representante vetorial) e integração no `kb-cli.mjs` (canal vetorial, re-rank e campo `rerank` no `--json`, `--no-rerank`, modos `semantic` e `semantic+rerank` do `eval`, oito casos degradados); bloqueio de rede no modo semântico e nos degradados (rastreia: REQ-06, REQ-07, REQ-08, REQ-09, REQ-11, design §2.6, §2.8; paths: `template/.forge/scripts/lib/kb-semantic.mjs`, `template/.forge/scripts/lib/kb-cli.mjs`, `tests/w292-kb-semantic-gate.sh`, `tests/w293-kb-offline-semantic-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/w292-kb-semantic-gate.sh && bash tests/w293-kb-offline-semantic-gate.sh`
  - Padrão de falha: `FAIL \[[^]]+\]`
  - Setup do teste: `npm ci --ignore-scripts --no-audit --no-fund --loglevel=error`

## Wave 4 — Superfície e ADR

- [ ] TASK-09 — Superfície e ADR: `/forge:kb` (subcomandos, leitura do resultado, política de cloud, nota sobre alertas de SCA/Dependabot nos pins), remissão em `/forge:query`, `.gitignore` e `gitignore.patch`, linha `info` do `doctor.sh` pela raiz de estado (sem node, sem criar `.forge/kb/semantic`), plugin regenerado, README e inventário, ADR 0004 emendando a 0001 com o registro da licença dos dados de treino (rastreia: REQ-05, REQ-09, REQ-10, design §2.9, §2.12; paths: `template/.forge/commands/graph/kb.md`, `template/.forge/commands/graph/query.md`, `installer/gitignore.patch`, `.gitignore`, `template/.forge/scripts/doctor.sh`, `plugin/forge/`, `README.md`, `.forge/product/current/adr/0004-opt-in-runtime-layer.md`, `.forge/product/current/adr/README.md`, `tests/w294-kb-surface-gate.sh`; depende: TASK-08)
  - Teste (comando): `bash tests/w294-kb-surface-gate.sh`
  - Padrão de falha: `FAIL \[[^]]+\]`

## Medições e provas do verify (fora das tasks, com comando e critério de parada)

Feitas pela sessão no `/forge:verify`, sobre o código das tasks, com a camada instalada de verdade (`kb.sh semantic install` a partir dos pins) e registradas em `evidence/`:

1. REQ-03 — `kb.sh eval tests/fixtures/kb/eval/{calibration,holdout}.json --lexical`: MRR do `lexical` ≥ MRR do `bm25` e hit@5 no máximo uma consulta abaixo, nas duas partições; registrar também a linha sem links. Falhou → change não segue para archive; decisão ao dono.
2. REQ-06 — `kb.sh eval` com a camada: hit@5 de `semantic+rerank` ≥ `lexical` nas duas partições; registrar `semantic` com e sem propagação. Falhou → decisão ao dono.
3. REQ-07 — `semantic` contra `semantic+rerank`: re-rank não piora o MRR; na calibração, se piorar, recalibrar (commit em `lib/kb-fuse.mjs` com nova medição); no holdout, se piorar, decisão ao dono sobre o default do re-rank.
4. NFR-01/NFR-02 — `time kb.sh query` lexical (< 200 ms) e semântica com re-rank (< 10 s), build semântico inicial; repetido em x86_64 (Node x64 sob Rosetta, declarado como emulação).
5. Prova de mutação das guardas que não têm vermelho próprio: injetar `fetch(` numa cópia de um `lib/kb-*.mjs`, `curl` no `kb.sh`, um host de LLM, e um `.node` plantado, e conferir que w288/w291/w292 reprovam (controle) e voltam a passar sem a mutação (recontrole).
6. `spec-delta.yaml` autorado a partir dos REQs verificados (REQ-FHT-070…080) antes do archive; `CHANGELOG.md` atualizado pelo archive.

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 | TASK-01 |
| REQ-02 | TASK-01, TASK-02, TASK-04, TASK-05 |
| REQ-03 | TASK-02, TASK-03, TASK-04; medição 1 |
| REQ-04 | TASK-04, TASK-05 |
| REQ-05 | TASK-06, TASK-07, TASK-09 |
| REQ-06 | TASK-08; medição 2 |
| REQ-07 | TASK-03, TASK-08; medição 3 |
| REQ-08 | TASK-04, TASK-08 |
| REQ-09 | TASK-05, TASK-08, TASK-09 |
| REQ-10 | TASK-04, TASK-09 |
| REQ-11 | TASK-05, TASK-08 |
| NFR-01, NFR-02 | medição 4 |
| NFR-03 | TASK-05 |
| design §2.9 (ADR 0004) | TASK-09 |
