# Proposal — add-unified-knowledge-search

> Change `add-unified-knowledge-search` (type: `feature`, scale 3) — criado em 2026-10-30 por milton. Gates humanos deste change delegados pelo dono a revisores adversariais independentes (aceite formal delegado em 2026-10-30).

## 1. Por quê (problema / motivação)

O harness já consulta o grafo de código (`/forge:query`, implementado por `graph.sh query|path`), mas só sobre nodes, edges e caminhos de import. Não existe busca sobre o resto do conhecimento que o próprio harness acumula: o baseline (`.forge/product/current/`, incluindo os ADRs), as specs arquivadas (`.forge/specs/archived/`), o ledger durável (`.forge/ledger/ledger.json`), os planos (`docs/plans/`), o `CHANGELOG.md` e as mensagens próprias do canal liaison. Hoje, responder "já decidimos isso antes?" depende de o agente lembrar onde procurar e gastar tokens abrindo arquivo por arquivo; o histórico de memória deste projeto registra a consequência (itens de ledger reabertos, subagentes instruídos contra decisões já aprovadas em plano, `feedback-ler-plano-antes-de-despachar`).

Nesta instância do repositório o corpus elegível mede 335 documentos, 5,4 MB de texto e 5.167 trechos (medição em `evidence/corpus-measurement.md`). É grande demais para leitura integral e pequeno o bastante para um índice em Node puro, sem banco externo.

O projeto externo `akitaonrails/ai-memory` funde busca textual, entidades e vizinhança por links via Reciprocal Rank Fusion (RRF) e oferece vetores como camada opcional; foi rejeitado pelo dono como dependência por motivos de segurança (entre eles, envio de texto integral sem sanitização a provedores cloud quando configurado). A ideia de fusão explicável é aproveitável; a implementação, não.

Decisão explícita do dono, não negociável: a memória semântica com re-rank deve ser implementada (embeddings e re-rank são requisito central, não opcional do change). Restrição central do projeto, também não negociável: o Forge é zero-dependency nos projetos-alvo (`docs/plans/spikes/w40-graph-engine-spike.md`, ADR 0001).

## 2. O que muda

1. Um índice derivado e determinístico do conhecimento acumulado, reconstruído por comando (sem LLM), gravado em `.forge/kb/` e ignorado pelo git.
2. Uma busca local que funde, por RRF ponderado e explicável, os sinais: texto integral (BM25), entidades (ids de ledger, ADR, REQ, gates, paths, comandos) e vizinhança por links entre documentos, sempre disponível sem nada instalado.
3. Uma camada semântica implementada neste change: embeddings densos locais (canal vetorial adicional na fusão) e re-rank por cross-encoder local sobre os candidatos fundidos, ativada explicitamente pelo consumidor e executada inteiramente na máquina, sem binding nativo, sem `node-gyp` e sem provedor cloud.
4. Uma superfície de uso nova (`/forge:kb` com `build`, `query`, `status`, `eval`, `semantic install|remove|status`) e o apontamento cruzado a partir de `/forge:query`.
5. Saída que explica por que cada resultado apareceu (canal, posição em cada canal, contribuição RRF, score do re-rank quando ativo) e deixa claro quando a camada semântica não está ativa.
6. Exclusão por construção de dado não confiável: blobs do liaison e qualquer mensagem de peer (`trust: untrusted-peer`) não entram no índice.
7. Um conjunto de avaliação versionado (calibração e holdout) e o avaliador `kb.sh eval`, para que a escolha de pesos e modelos seja medida, não opinada.

## 3. O que NÃO muda (fora de escopo)

- O grafo de código e `graph.sh` (`build|update|query|path|...`) seguem como estão; nenhum comportamento existente muda.
- Nenhuma dependência de runtime entra no `package.json` do harness nem no projeto-alvo por padrão; a camada semântica é instalada sob demanda pelo consumidor, fora do `package.json` dele. O `package.json` do harness só ganha `devDependencies` (workspace de desenvolvimento, nunca publicadas como dependência), nas mesmas versões exatas dos pins, para que a suíte exercite a inferência real offline.
- Nenhuma chamada a LLM e nenhuma chamada de rede no caminho de busca, em nenhum modo. Download só no comando explícito de ativação da camada semântica.
- Provedor de embeddings em cloud não é implementado neste change (decisão e motivo em requirements).
- Geração de resposta sintetizada a partir dos resultados (RAG) fica fora: a busca devolve evidência ranqueada, o agente decide o que ler.
- Indexação de código-fonte (papel do grafo) e de `.forge/specs/active/` (artefato em trabalho, instável) fica fora do default.

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template` (novos requisitos REQ-FHT de busca unificada).
- **Paths afetados:** `template/.forge/scripts/kb.sh`, `template/.forge/scripts/lib/kb-*.mjs`, `template/.forge/scripts/lib/kb-pins/`, `package.json` e `package-lock.json` (só devDependencies), `template/.forge/commands/graph/kb.md`, `template/.forge/commands/graph/query.md`, `installer/gitignore.patch`, `template/.forge/scripts/doctor.sh`, `tests/wNNN-kb-*-gate.sh`, fixtures de teste, `README.md`, `CHANGELOG.md`.
- **Dependências:** nenhuma spec ativa; reaproveita `lib/untrusted-render.mjs` (conceito de dado não confiável) e o padrão de índice derivado de `.forge/graph/`.
- **Riscos:** (a) camada semântica puxar dependência nativa ou rede por padrão, violando zero-dep — detectado por gate que roda a busca sem a camada instalada e por gate que inspeciona o caminho de import; (b) ranking piorar com sinais fundidos sem calibração — detectado pelo conjunto de avaliação versionado e pelas métricas em evidence; (c) dado de peer não confiável vazar para o índice — detectado por gate com fixture de liaison contendo `untrusted-peer`; (d) download de modelo adulterado — mitigado por sha256 fixado por arquivo e recusa em divergência.

## 5. Próximos passos

`/forge:requirements` → `/forge:design` (com medição registrada em `evidence/`) → `/forge:tasks` → `/forge:analyze` → `/forge:shard` → `/forge:implement` → `/forge:verify` → `/forge:archive`, com cada gate humano delegado a revisor adversarial independente.
