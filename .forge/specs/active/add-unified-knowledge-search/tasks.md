# Tasks — add-unified-knowledge-search

> Tasks do change `add-unified-knowledge-search`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Cada task é atômica (commit de vermelho + commit de implementação), rastreável a um REQ/seção do design, e declara o que toca.
> Cada task declara `Teste (comando)` e `Padrão de falha`: o Red é provado por execução (`red-evidence.sh task`). Neste repositório todo arquivo de produção mora sob `template/.forge/`, que `isInfraPath` trata como infraestrutura (segmento iniciado por ponto), então o commit de vermelho contém **só o gate** (sem stub de produção): o gate falha com `FAIL [n]` ao não encontrar o comportamento, e o verde traz a implementação.
> Ordinais de gate (`w284`…`w293`) derivados de `gate-ordinal.sh next` em 2026-10-30 (máximo remoto `w283`); colisão com branch paralela é resolvida por renomeação na hora do merge, nunca por reserva.
> Cada task tem um gate próprio que passa no verde dela; gates de tasks posteriores não são pré-condição das anteriores.

## Wave 1 — Fundação lexical (zero-dep)

- [ ] TASK-01 — Corpus: fontes, exclusões, corte em trechos, impressões digitais de conteúdo e rápida (rastreia: REQ-01, REQ-02, design §2.3, §2.4; paths: `template/.forge/scripts/lib/kb-corpus.mjs`, `tests/w284-kb-corpus-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w284-kb-corpus-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-02 — Índice lexical: normalização, BM25, entidades, grafo de links, texto fora do JSON e serialização determinística (rastreia: REQ-02, REQ-03, design §2.4; paths: `template/.forge/scripts/lib/kb-lexical.mjs`, `tests/w285-kb-lexical-gate.sh`; depende: TASK-01)
  - Teste (comando): `bash tests/w285-kb-lexical-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-03 — Fusão: RRF ponderado, propagação de links e combinação do re-rank como funções puras, com as constantes calibradas (rastreia: REQ-03, REQ-07, design §2.5, §2.6; paths: `template/.forge/scripts/lib/kb-fuse.mjs`, `tests/w286-kb-fuse-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w286-kb-fuse-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`

## Wave 2 — CLI e avaliação

- [ ] TASK-04 — `kb.sh` e `kb-cli.mjs`: build, query, status, saída texto e `--json`, neutralização de trecho, reconstrução automática e regravação da impressão rápida, `--lexical`, `--top`, erros de uso, carga dinâmica da camada semântica na raiz de estado (rastreia: REQ-02, REQ-03, REQ-04, REQ-08, design §2.2, §2.2.1, §2.5, §2.11; paths: `template/.forge/scripts/kb.sh`, `template/.forge/scripts/lib/kb-cli.mjs`, `tests/w287-kb-cli-gate.sh`; depende: TASK-02, TASK-03)
  - Teste (comando): `bash tests/w287-kb-cli-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-05 — Avaliador `kb.sh eval` (modos, métricas, consulta sem relevante, aviso de fragmento largo) e conjunto de avaliação versionado (calibração e holdout, cópias literais da evidência) (rastreia: REQ-11, design §2.11; paths: `template/.forge/scripts/lib/kb-cli.mjs`, `tests/fixtures/kb/eval/calibration.json`, `tests/fixtures/kb/eval/holdout.json`, `tests/w288-kb-eval-gate.sh`; depende: TASK-04)
  - Teste (comando): `bash tests/w288-kb-eval-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`

## Wave 3 — Camada semântica

- [ ] TASK-06 — Pins do runtime e dos modelos e devDependencies do workspace nas mesmas versões (rastreia: REQ-05, design §2.2, §2.6, §2.10; paths: `template/.forge/scripts/lib/kb-pins/package.json`, `template/.forge/scripts/lib/kb-pins/package-lock.json`, `template/.forge/scripts/lib/kb-pins/models.json`, `package.json`, `package-lock.json`, `tests/w289-kb-pins-gate.sh`; depende: —)
  - Teste (comando): `bash tests/w289-kb-pins-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-07 — Camada semântica: instalador (`kb-install.mjs`, `semantic install|remove|status`), integridade na carga (pins, varredura nativa, versões, sha256), carga confinada a `runtime/node_modules`, embeddings com cache de arquivo único, cross-encoder, degradação nos oito casos; fixtures de teste (modelos ONNX gerados, servidor local, `npm` substituto) (rastreia: REQ-05, REQ-06, REQ-07, REQ-08, design §2.6, §2.7, §2.10; paths: `template/.forge/scripts/lib/kb-semantic.mjs`, `template/.forge/scripts/lib/kb-install.mjs`, `template/.forge/scripts/lib/kb-cli.mjs`, `tests/fixtures/kb/make-semantic-fixture.mjs`, `tests/fixtures/kb/serve.mjs`, `tests/fixtures/kb/fake-npm.sh`, `tests/fixtures/kb/semantic-env.sh`, `tests/w290-kb-semantic-gate.sh`, `tests/w291-kb-install-gate.sh`; depende: TASK-04, TASK-06)
  - Teste (comando): `bash tests/w290-kb-semantic-gate.sh && bash tests/w291-kb-install-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`

## Wave 4 — Guardas de rede e zero-dep, superfície, ADR

- [ ] TASK-08 — Gates de rede (permissões do Node e interceptador por `--require`, com pontos de estrangulamento de socket e canário de controle positivo, nos modos lexical, semântico e nos oito degradados), `git` substituto, estáticos (imports, hosts de LLM, programas do `kb.sh`, zero-dep do caminho lexical) (rastreia: REQ-04, REQ-08, REQ-09, NFR-03, design §2.8, §2.12; paths: `tests/w292-kb-offline-gate.sh`, `tests/fixtures/kb/no-network.cjs`, `tests/fixtures/kb/net-canary.mjs`, `tests/fixtures/kb/fake-git.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/w292-kb-offline-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-09 — Superfície: `/forge:kb`, remissão em `/forge:query`, `.gitignore` e `gitignore.patch`, linha `info` do `doctor.sh` (raiz de estado), plugin regenerado, README (rastreia: REQ-05, REQ-10, design §2.9, §2.12; paths: `template/.forge/commands/graph/kb.md`, `template/.forge/commands/graph/query.md`, `installer/gitignore.patch`, `.gitignore`, `template/.forge/scripts/doctor.sh`, `plugin/forge/`, `README.md`, `tests/w293-kb-surface-gate.sh`; depende: TASK-07)
  - Teste (comando): `bash tests/w293-kb-surface-gate.sh`
  - Padrão de falha: `FAIL \[[0-9]+\]`
- [ ] TASK-10 — ADR 0004 "camada opt-in com dependência instalada sob demanda", emendando o "sem dependência no alvo" da ADR 0001 (rastreia: design §2.9; paths: `.forge/product/current/adr/0004-opt-in-runtime-layer.md`, `.forge/product/current/adr/README.md`; depende: TASK-07)
  - Teste (comando): `test -f .forge/product/current/adr/0004-opt-in-runtime-layer.md && grep -q 0004 .forge/product/current/adr/README.md && grep -q 0001 .forge/product/current/adr/0004-opt-in-runtime-layer.md`
  - Padrão de falha: `.*`

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01 | TASK-01 |
| REQ-02 | TASK-01, TASK-02, TASK-04, TASK-08 |
| REQ-03 | TASK-02, TASK-03, TASK-04 |
| REQ-04 | TASK-04, TASK-08 |
| REQ-05 | TASK-06, TASK-07, TASK-09 |
| REQ-06 | TASK-07 |
| REQ-07 | TASK-03, TASK-07 |
| REQ-08 | TASK-04, TASK-07, TASK-08 |
| REQ-09 | TASK-08 |
| REQ-10 | TASK-04, TASK-09 |
| REQ-11 | TASK-05 |
| NFR-01, NFR-02 | medição no verify (evidence), sobre o código de TASK-04 e TASK-07 |
| NFR-03 | TASK-08 |
| design §2.9 (ADR) | TASK-10 |
