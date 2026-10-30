# Requirements — add-unified-knowledge-search

> Requisitos do change `add-unified-knowledge-search`. Cada requisito é verificável e rastreável à proposal. Vocabulário: "modo lexical" é a busca sem a camada semântica (sempre disponível, zero dependência); "modo semântico" é a busca com a camada semântica ativada pelo consumidor (embeddings + re-rank locais). "Índice" é o artefato derivado em `.forge/kb/`. "Raiz" segue a convenção de `lib/forge-root.sh`: com `FORGE_ROOT` definido, tudo é lido e gravado nele; sem ele, os documentos versionados por branch (baseline, specs arquivadas, planos, `CHANGELOG.md`) e o índice vêm da árvore de trabalho corrente (`forge_worktree_root`), e o estado durável de projeto (ledger e liaison) vem do checkout principal (`forge_resolve_root`), como em `ledger-ops.sh` e `liaison-ops.sh`. A resolução usa só `git rev-parse` local.

## REQ-01 — Fontes indexadas e exclusões

- **Quando** o índice é construído, **o sistema deve** indexar exatamente estas fontes, quando existirem na raiz, e ignorar silenciosamente as ausentes: (a) todo `.md`, `.yaml`/`.yml` sob `.forge/product/current/`; (b) todo `.md`, `.yaml`/`.yml` sob `.forge/specs/archived/`; (c) cada entrada de `.forge/ledger/ledger.json` como um documento próprio, identificado pelo id da entrada; (d) todo `.md` sob `docs/plans/`; (e) `CHANGELOG.md` da raiz; (f) cada mensagem do log próprio do liaison (`.forge/liaison/<canal>/log/<self>.jsonl`, sendo `<self>` o `self.id` de `.forge/liaison/liaison.yaml`) cujo campo `trust` seja exatamente `self` e que não tenha `authored_by` (conteúdo de autoria externa escrito no nosso log), usando `subject` e `body` inline; o `body_ref` nunca é seguido, então mensagem cujo corpo está em blob entra só pelo `subject` (decisão deliberada: blobs ficam fora por construção).
- **Critérios de aceite:**
  - [ ] Com uma raiz de fixture contendo as seis fontes, `kb.sh build` lista no índice um documento por arquivo de (a), (b), (d), (e), um por entrada de ledger e um por mensagem `self`.
  - [ ] Nenhum arquivo sob `.forge/liaison/*/blobs/` aparece no índice, mesmo quando referenciado por `body_ref` de uma mensagem `self`.
  - [ ] Nenhuma mensagem com `trust` diferente de `self` (incluindo `untrusted-peer`, valor ausente ou valor desconhecido), nenhuma mensagem com `authored_by` e nenhuma linha de `log/<outro>.jsonl` aparece no índice.
  - [ ] `.forge/specs/active/`, código-fonte, `node_modules/`, `.git/` e `.forge/kb/` nunca são indexados.
  - [ ] Linha JSONL ilegível no liaison ou `ledger.json` ilegível não aborta o build: a fonte é pulada e o build reporta a contagem de itens pulados por fonte.
  - [ ] Raiz sem nenhuma das fontes produz índice vazio válido e a busca devolve zero resultados com exit 0.
- **Rastreia:** proposal §2.1, §2.6, §3
- **Notas:** a lista é fixa neste change; fontes configuráveis ficam fora de escopo (ver Fora de escopo).

## REQ-02 — Reconstrução determinística, sem LLM e sem rede

- **Quando** o operador roda `kb.sh build`, **o sistema deve** reconstruir o índice lexical a partir das fontes do REQ-01 de forma determinística, sem chamar LLM e sem acesso à rede, gravando-o em `.forge/kb/`.
- **Critérios de aceite:**
  - [ ] Dois `kb.sh build` consecutivos sem mudança nas fontes produzem arquivos de índice lexical byte-idênticos (nenhum timestamp de relógio, ordem estável).
  - [ ] O índice registra a impressão digital das fontes (sha256 do conteúdo de cada documento); `kb.sh status` informa se o índice está atual ou defasado em relação às fontes.
  - [ ] `kb.sh query` sobre índice ausente ou defasado reconstrói o índice lexical antes de buscar e informa isso numa linha em stderr (campo `rebuilt: true` no `--json`).
  - [ ] Build, query e status concluem com sucesso sob bloqueio de rede (mecanismo e cobertura no REQ-09).
- **Rastreia:** proposal §2.1, §3
- **Notas:** o custo medido de reconstrução lexical completa no corpus deste repositório é ~0,7 s (evidence/corpus-measurement.md), o que dispensa build incremental para o modo lexical.

## REQ-03 — Busca lexical fundida (default zero-dep)

- **Quando** o operador roda `kb.sh query "<texto>"` sem camada semântica ativa, **o sistema deve** ranquear documentos combinando três sinais: BM25 sobre o texto dos trechos e correspondência de entidades (ids de ledger, ADR, REQ, TASK, STORY, gates `wNNN`, nomes de arquivo, comandos `/forge:*`, siglas), fundidos por RRF ponderado; e vizinhança por links, aplicada sobre a fusão como propagação de score: cada um dos T primeiros documentos da fusão transfere aos seus vizinhos uma fração α do próprio score, amortecida pelo grau dos dois lados, o que pode reordenar candidatos e trazer vizinho que não casou a consulta. Link é uma aresta não direcionada entre dois documentos indexados quando o texto de um cita (i) o id de ledger (`LDG-NNNN`) que identifica o outro, (ii) o nome de arquivo do outro, quando esse nome é único no índice e não pertence à lista fechada de nomes genéricos de artefato (`proposal.md`, `design.md`, `tasks.md`, `requirements.md`, `manifest.yaml`, `approvals.yaml`, `verification.md`, `verification.yaml`, `analysis.md`, `spec-delta.yaml`, `bugfix.md`, `refactor.md`, `epic_context.md`, `index.yaml`, `spec.yaml`, `README.md`, `CHANGELOG.md`), ou (iii) o change-id de uma spec arquivada. A propagação, e não um terceiro canal RRF, é decisão medida: links como canal RRF, mesmo com peso 0,05, derrubaram o hit@5 do conjunto de calibração (evidence/semantic-feasibility.md §3.1).
- **Ordem do pipeline (vale para os dois modos):** (1) **ranking fundido**: RRF ponderado dos canais — BM25 e entidades no modo lexical; BM25, entidades e vetor no modo semântico; (2) **ranking propagado**: propagação de links sobre os T primeiros do ranking fundido; (3) **ranking final**: só no modo semântico e sem `--no-rerank`, re-rank sobre os K primeiros do ranking propagado; nos demais casos, o ranking final é o ranking propagado. A saída mostra a contribuição de cada etapa.
- **Critérios de aceite:**
  - [ ] Funciona numa raiz sem `node_modules`, sem a camada semântica instalada e com Node >= 20, usando apenas módulos built-in do Node.
  - [ ] O resultado é determinístico: a mesma consulta sobre o mesmo índice devolve a mesma ordem e os mesmos scores.
  - [ ] A normalização lexical trata acentuação e caixa (consulta "decisao" encontra "decisão").
  - [ ] Os pesos de fusão por canal, α e T da propagação são constantes documentadas no código e reportadas na saída `--json`; os valores finais e a grade avaliada ficam registrados em evidence.
  - [ ] Numa fixture em que o documento A casa a consulta por BM25 e o documento B não casa mas é citado por A, B aparece no resultado com contribuição de links maior que zero e a origem da propagação (A) nomeada no `--json`, e A traz contribuição de BM25 maior que zero.
  - [ ] Nas duas partições do conjunto de avaliação (REQ-11), sobre o corpus deste repositório, o modo lexical fundido atinge MRR maior ou igual ao do BM25 isolado e hit@5 no máximo uma consulta abaixo do BM25 isolado (uma consulta vale ~0,03 numa partição de 35 e é o ruído medido entre configurações vizinhas). Medição manual registrada em evidence no verify, como a do REQ-06, porque o corpus vivo muda a cada change e um gate sobre ele não seria hermético; se não passar, o change não segue para archive e a decisão volta ao dono.
- **Rastreia:** proposal §2.2

## REQ-04 — Saída explicável e de custo baixo de tokens

- **Quando** a busca devolve resultados, **o sistema deve** mostrar, por resultado, na saída texto e no `--json`: identificador do documento (path relativo ou `ledger:<id>`/`liaison:<msg_id>`), localização do trecho (heading ou linha inicial), score final, por canal RRF a posição e a contribuição, a contribuição da propagação de links com os documentos de origem, e, no modo semântico com re-rank, o score do cross-encoder e a posição antes e depois do re-rank.
- **Critérios de aceite:**
  - [ ] Canais de saída: o resultado vai para stdout; avisos operacionais (reconstrução automática do índice, vetores faltando) vão para stderr. Na saída texto, a primeira linha de stdout declara o modo; no `--json`, stdout contém exatamente um objeto JSON e o modo vem nos campos `mode` e `mode_reason`.
  - [ ] A primeira linha da saída declara o modo efetivo (`lexical` ou `semantic`) e, quando lexical, o motivo (`camada semântica não instalada`, `desativada por --lexical`, `falha ao carregar: <causa>`).
  - [ ] `--lexical` força o modo lexical mesmo com a camada semântica instalada, sem carregar o runtime (verificável: com runtime de fixture que lança ao ser importado, `--lexical` devolve resultados com exit 0 e motivo `desativada por --lexical`).
  - [ ] Todo trecho exibido sai como dado: na saída texto, dentro de bloco cercado, com crases triplas substituídas e com linhas que começam por `/<palavra>:` prefixadas por `⟪neutralizado⟫` (mesma regra de `lib/untrusted-render.mjs`); no `--json`, o campo de trecho traz o texto já neutralizado.
  - [ ] `--json` emite um objeto JSON válido com os mesmos campos, parseável por `JSON.parse`.
  - [ ] Default de 8 resultados (`--top N` ajusta, 1..50); trecho exibido com no máximo 240 caracteres por resultado.
  - [ ] Nenhuma etapa da busca chama LLM: garantido pelo bloqueio de rede do REQ-09 (sem rede não há chamada a provedor de LLM) e por teste estático que reprova, nos módulos da busca (`kb.sh`, `lib/kb-*.mjs`), qualquer referência, por limite de palavra e sem distinção de caixa, a hosts ou SDKs de provedores de LLM: `api.anthropic.com`, `@anthropic-ai`, `api.openai.com`, `openai`, `generativelanguage.googleapis.com`, `@google/generative-ai`, `api.voyageai.com`, `api.cohere.ai`, `api.mistral.ai`, `bedrock-runtime`, `ollama` (lista mantida no próprio gate).
- **Rastreia:** proposal §2.5

## REQ-05 — Ativação explícita da camada semântica, local e verificável

- **Quando** o consumidor roda `kb.sh semantic install`, **o sistema deve** instalar, sob `.forge/kb/semantic/` (diretório que só passa a existir por este comando), o runtime de inferência e os modelos da camada semântica, a partir das versões e hashes fixados na maquinaria do template (`template/.forge/scripts/lib/kb-pins/`, entregue pelo instalador e pelo `forge update` como qualquer script, fora de `.forge/kb/`), e recusar qualquer artefato cuja integridade não confira. A camada está "instalada" se e só se `.forge/kb/semantic/installed.json` existe. O runtime e o tokenizador são carregados exclusivamente de `.forge/kb/semantic/runtime/node_modules/`: o caminho resolvido de cada pacote (e de cada dependência listada no lockfile dos pins) tem de estar dentro desse diretório, e um pacote resolvido fora dele (por exemplo, no `node_modules` do projeto-alvo ou do próprio harness) conta como "pacote do runtime faltando" e nunca é importado.
- **Critérios de aceite:**
  - [ ] Este é o único comando do change que acessa a rede; ele declara, antes de baixar, o que será baixado, de onde e o tamanho aproximado.
  - [ ] Pacotes npm do runtime são instalados com versão exata e integridade fixadas por lockfile versionado no template, com scripts de instalação desativados, sem tocar o `package.json` do projeto-alvo.
  - [ ] Após a instalação, a presença sob `.forge/kb/semantic/` de qualquer binário nativo — arquivo `*.node`, `*.dylib`, `*.so`, `*.dll`, ou qualquer arquivo cujos primeiros bytes sejam a assinatura de executável Mach-O, ELF ou PE — reprova a instalação e a desfaz; a mesma varredura roda a cada carga da camada em `build`, `query` e `eval` e, se achar binário nativo, a camada não é carregada (modo lexical com motivo).
  - [ ] Cada arquivo de modelo é baixado de uma revisão fixada e conferido por sha256 fixado no template; divergência reprova, apaga o arquivo e não ativa a camada.
  - [ ] `kb.sh semantic remove` apaga `.forge/kb/semantic/` (e só ele; os pins em `lib/kb-pins/` permanecem) e a busca volta ao modo lexical; um `semantic install` seguinte funciona.
  - [ ] `kb.sh semantic status` informa instalado/não instalado e confere: versão de cada pacote instalado igual à do lockfile dos pins, ausência de binário nativo (critério acima) e sha256 de cada arquivo de modelo igual ao fixado.
  - [ ] O `package.json` do harness não tem bloco `dependencies` e suas `devDependencies` `onnxruntime-web` e `@huggingface/tokenizers` têm exatamente as versões do `package.json` dos pins (gate da suíte).
  - [ ] Teste com fixture que tem `node_modules/onnxruntime-web` e `node_modules/@huggingface/tokenizers` envenenados no nível do projeto (módulos que, ao serem importados, gravam um arquivo-marcador e lançam): com a camada não instalada, com a camada instalada, com a camada instalada sem um dos pacotes de topo e com a camada instalada sem uma dependência transitiva do lockfile (por exemplo `long`) que existe envenenada no projeto, o marcador nunca é criado nos quatro casos, e cada caso tem o seu resultado: não instalada, modo lexical com motivo `camada semântica não instalada`; instalada completa, `mode: semantic`; sem pacote de topo ou sem dependência transitiva, modo lexical com motivo de pacote faltando.
  - [ ] `installed.json` registra o sha256 do `package-lock.json` e do `models.json` dos pins usados na instalação; se os pins mudarem depois (por exemplo, por `forge update`), a camada não é carregada e o motivo pede reinstalação (`pins mudaram desde a instalação — rode kb.sh semantic install`).
  - [ ] Sem `npm` no `PATH`, `semantic install` falha com mensagem clara, exit diferente de 0, e não cria `installed.json`.
  - [ ] A URL de cada arquivo de modelo vem dos pins; o instalador aceita só `https://`, ou `http://` para `127.0.0.1`/`localhost` (servidor local de teste), e recusa qualquer outro esquema.
  - [ ] Nenhum outro caminho dispara a instalação: só `kb.sh semantic install` invoca o módulo de instalação (teste estático sobre o template inteiro), e `doctor.sh`, os hooks e o instalador/updater do harness não criam `.forge/kb/semantic/` (teste de execução de `doctor.sh` numa raiz de fixture).
- **Rastreia:** proposal §2.3, §3, §4 (riscos a e d)

## REQ-06 — Embeddings densos implementados

- **Quando** a camada semântica está instalada, **o sistema deve** calcular, no `kb.sh build`, um vetor denso por trecho com o modelo de embedding local, armazená-lo em cache endereçado por (modelo, sha256 do trecho) e, na consulta, acrescentar à fusão RRF um terceiro canal (o vetorial: similaridade de cosseno entre o vetor da consulta e os vetores dos trechos, ranqueada por documento pelo melhor trecho), na etapa (1) da ordem do pipeline do REQ-03.
- **Critérios de aceite:**
  - [ ] Um segundo `kb.sh build` sem mudança nas fontes não recalcula nenhum vetor (contagem de vetores calculados reportada igual a zero).
  - [ ] Trecho novo ou alterado recebe vetor no build seguinte; trecho removido sai do cache.
  - [ ] Na consulta, se parte dos trechos ainda não tem vetor, a busca segue com os vetores disponíveis e reporta quantos faltam.
  - [ ] O cache de vetores é gravado incrementalmente durante o build (no máximo a cada 200 trechos calculados): um build interrompido preserva os vetores já calculados, e o build seguinte só calcula os faltantes.
  - [ ] Um teste exercita a inferência real do runtime (não um dublê) sobre um modelo de fixture e verifica que textos de mesmo sentido ficam mais próximos que textos sem relação. Caminho de ativação do teste, sem override em produção: a raiz de fixture recebe uma cópia da maquinaria (`.forge/scripts/`) cujo `lib/kb-pins/models.json` aponta para modelos ONNX e tokenizadores de fixture servidos por um servidor HTTP local, com os sha256 deles; o teste roda o `kb.sh semantic install` real, com um `npm` substituto no `PATH` que copia para `runtime/node_modules` os pacotes das devDependencies do workspace (mesmas versões dos pins). Download, conferência de sha256, varredura nativa, conferência de versões e gravação de `installed.json` são o código de produção.
  - [ ] Na mesma fixture, trocar um byte de um arquivo de modelo instalado derruba a busca para lexical com motivo de integridade.
  - [ ] Com os modelos de produção fixados, nas duas partições do conjunto de avaliação (REQ-11), o modo semântico (com re-rank) atinge hit@5 maior ou igual ao do modo lexical. É medição manual registrada em evidence no verify (o download dos modelos não cabe na suíte, que é offline); se não passar, o change não segue para archive e a decisão volta ao dono. A mesma evidência registra, como informação, o modo semântico com e sem a propagação de links (α e T foram calibrados sem o canal vetorial).
- **Rastreia:** proposal §2.3

## REQ-07 — Re-rank que combina os sinais

- **Quando** a camada semântica está ativa e o operador consulta, **o sistema deve** reordenar os K primeiros candidatos do resultado já propagado (etapa 3 da ordem do pipeline do REQ-03; K = 10) com um cross-encoder local que pontua o par (consulta, trecho), e produzir a ordem final combinando a posição do cross-encoder com a posição no ranking propagado (etapa 2), de modo que nenhum dos dois sinais sozinho determine a ordem.
- **Critérios de aceite:**
  - [ ] A ordem final é função documentada das duas posições (a fórmula está no código e na saída `--json`), não apenas a ordem do cross-encoder.
  - [ ] Teste com scores de cross-encoder controlados sobre um ranking propagado `[A, B, C, D]`: (i) cross-encoder concordante (scores decrescentes A > B > C > D) mantém `[A, B, C, D]`; (ii) cross-encoder que põe D em primeiro e A em último move D para uma posição acima da 4ª e A para uma posição abaixo da 1ª; (iii) o resultado final é exatamente o previsto pela fórmula documentada nos dois casos.
  - [ ] K é constante documentada (10), não exposta como flag. Empate no score combinado é desempatado pela posição do cross-encoder (a mais alta vence), e isso faz parte da fórmula documentada. Emenda de 2026-10-30 na fase de design: o desempate pela posição propagada, aprovado antes, contradizia o critério (ii) quando o cross-encoder inverte os extremos de forma simétrica (A e D empatam e A ficava em 1º); o desempate pelo cross-encoder deixa o critério (ii) satisfeito para qualquer ordem que ponha D em primeiro e A em último, e não altera nenhuma métrica da partição de calibração (semantic-feasibility.md §5).
  - [ ] A evidence do verify registra, nas duas partições, o efeito do re-rank (com e sem re-rank) com os modelos de produção. Se o re-rank piorar o MRR na calibração, a combinação é recalibrada na calibração; se, ainda assim, piorar o MRR no holdout, o change não segue para archive e a decisão sobre o default do re-rank volta ao dono.
  - [ ] `--no-rerank` desativa só o re-rank, mantendo o canal vetorial; candidatos além de K mantêm a ordem do ranking propagado.
  - [ ] Um teste exercita a inferência real do cross-encoder pelo runtime sobre modelo de fixture.
- **Rastreia:** proposal §2.3

## REQ-08 — Degradação sem erro

- **Quando** a camada semântica não está instalada, está incompleta, tem integridade divergente ou falha ao carregar ou inferir, **o sistema deve** devolver o resultado do modo lexical, com exit 0, declarando o modo efetivo e o motivo na primeira linha (REQ-04), sem stack trace.
- **Critérios de aceite:**
  - [ ] Os oito casos (camada ausente; arquivo de modelo faltando; sha256 divergente; pacote do runtime faltando ou resolvido fora de `runtime/node_modules`; binário nativo presente; pins mudaram desde a instalação; runtime que lança ao ser importado, sem `--lexical`; runtime que lança na inferência) são cobertos por teste e todos devolvem resultados lexicais com exit 0 e o motivo correspondente. A conferência na carga é pelas duas coisas: versão de cada pacote contra o lockfile dos pins e sha256 de cada arquivo de modelo.
  - [ ] `kb.sh build` nos mesmos casos constrói o índice lexical, informa que os vetores não foram calculados e sai com exit 0.
  - [ ] Os oito casos também rodam sob o bloqueio de rede do REQ-09 (o caminho degradado não pode buscar modelo remoto).
  - [ ] Erros de uso (consulta vazia, `--top` fora da faixa, subcomando desconhecido) saem com exit diferente de 0 e mensagem de uso.
- **Rastreia:** proposal §2.3, §2.5

## REQ-09 — Nenhum dado sai da máquina; cloud não suportado neste change

- **Quando** qualquer subcomando de `kb.sh` roda (`build`, `query`, `status`, `eval`, `semantic status`, `semantic remove`), exceto `semantic install`, **o sistema deve** operar sem nenhuma chamada de rede; e o change não implementa provedor de embedding ou re-rank em cloud.
- **Critérios de aceite:**
  - [ ] Teste de execução sob bloqueio de rede cobre `build`, `query`, `status`, `eval`, `semantic status` e `semantic remove` no modo lexical, no modo semântico com modelos de fixture e nos oito casos degradados do REQ-08. Bloqueio: quando o Node em uso suporta o modelo de permissões com rede (`--permission` sem `--allow-net`, Node >= 25), a execução roda sob ele, o que cobre também threads de trabalho e processos filhos (bloqueados por ausência de `--allow-child-process`); em qualquer Node, roda também sob um interceptador pré-carregado pelo Node (`--require`, que, ao contrário de `--import`, é aplicado também dentro de cada Worker — emenda de 2026-10-30 na fase de design, medida) que faz lançar `fetch`, `http(s).request/get`, `net.connect/createConnection`, `tls.connect`, `dns.lookup/resolve`, `http2.connect`, `dgram.createSocket` e todas as funções de `child_process` (`spawn`, `exec`, `execFile`, `fork` e as variantes `*Sync`). O teste informa qual mecanismo rodou e, como controle positivo, roda um canário que tenta `fetch`, `net.connect`, socket cru e processo filho contra um servidor local na thread principal e dentro de um Worker: sob cada mecanismo, as oito tentativas têm de falhar; sem bloqueio (recontrole), as oito têm de passar.
  - [ ] Teste estático reprova se algum módulo da busca (`lib/kb-*.mjs`), fora do módulo de instalação, importar `node:http`, `node:https`, `node:net`, `node:tls`, `node:dgram`, `node:dns`, `node:child_process`, `node:http2` ou `node:worker_threads`, ou usar `fetch(`; e reprova se `kb.sh` ou qualquer arquivo que ele inclua por `source` invocar `curl`, `wget`, `nc`, `ssh`, `npm`, `npx` ou subcomando de rede do git (`fetch`, `pull`, `push`, `clone`, `ls-remote`, `remote`); o único uso de git permitido é `rev-parse` (resolução de raiz). O `npm ci` da instalação roda de dentro de `lib/kb-install.mjs`, a única exceção, carregado só por `semantic install`.
  - [ ] Teste de execução roda `kb.sh build`, `query` e `status` com um `git` substituto no `PATH` que registra cada subcomando recebido e confere que só `rev-parse` foi chamado.
  - [ ] No caso "modo semântico com modelos de fixture" sob bloqueio de rede, o teste confere que o modo efetivo foi `semantic` (campo `mode` do `--json`), para que uma queda silenciosa para lexical causada pelo próprio bloqueio não passe como sucesso; o bloqueio por permissões concede `--allow-worker` e leitura/escrita de sistema de arquivos, nunca rede nem processo filho.
  - [ ] A documentação do comando declara que não há provedor cloud e que qualquer provedor futuro só pode existir como opt-in explícito, nunca default, por causa de dado regulado (PCI DSS) nos repositórios consumidores.
- **Rastreia:** proposal §2.3, §3

## REQ-10 — Superfície de uso

- **Quando** o harness é instalado num projeto, **o sistema deve** expor a busca por `bash .forge/scripts/kb.sh` com os subcomandos `build`, `query`, `status`, `eval`, `semantic install|remove|status`, documentada no comando `/forge:kb`, e o comando `/forge:query` deve apontar para `/forge:kb` como a busca sobre conhecimento (não código).
- **Critérios de aceite:**
  - [ ] `template/.forge/commands/graph/kb.md` existe com frontmatter válido e o plugin gerado (`plugin/forge`) está sincronizado com ele.
  - [ ] `template/.forge/commands/graph/query.md` cita `/forge:kb`.
  - [ ] `.forge/kb/` está no bloco gerenciado de `installer/gitignore.patch`.
  - [ ] `doctor.sh` informa o estado da camada semântica como informação (nunca como falha) quando ausente.
- **Rastreia:** proposal §2.4

## REQ-11 — Conjunto de avaliação versionado

- **Quando** o change mede qualidade de ranking (REQ-03, REQ-06), **o sistema deve** usar um conjunto de avaliação versionado em `tests/fixtures/kb/eval/` com duas partições: `calibration.json` (no mínimo 30 consultas, a única usada para escolher pesos e constantes) e `holdout.json` (no mínimo 15 consultas, escritas antes da calibração final e nunca usadas para ajustar nada), e um avaliador determinístico `kb.sh eval <arquivo>`.
- **Critérios de aceite:**
  - [ ] Cada consulta tem `q` (texto) e `gold` (lista de fragmentos de id de documento; um resultado é relevante se seu id contém algum fragmento, sem distinção de caixa); toda consulta tem ao menos um documento relevante existente no corpus deste repositório (o avaliador reporta consulta sem relevante como erro).
  - [ ] Consultas são paráfrases: nenhuma consulta copia literalmente o título do documento relevante; ao menos 4 consultas por partição estão em inglês sobre documentos em português (sinal semântico entre línguas).
  - [ ] O `holdout.json` entra no histórico do git em commit anterior ao commit que introduz as constantes de fusão em `lib/kb-fuse.mjs`, e não muda depois desse commit (verificável por `git log --follow` do arquivo). A pré-calibração do protótipo (`evidence/prototype/`) usou só a partição de calibração; a escolha final de constantes também usa só ela, e o holdout é reportado, nunca otimizado.
  - [ ] Um gate da suíte, hermético, roda `kb.sh eval` sobre um corpus de fixture com consultas de fixture e confere as métricas calculadas contra valores esperados escritos à mão.
  - [ ] `kb.sh eval` reporta, por consulta, quantos documentos cada fragmento de `gold` casa e avisa em stderr quando um fragmento casa mais de 10 documentos (rótulo largo demais infla hit@k).
  - [ ] `tests/fixtures/kb/eval/calibration.json` e `holdout.json` são cópias literais de `evidence/prototype/queries.json` e `evidence/prototype/holdout.json` deste change.
  - [ ] `kb.sh eval` reporta, por modo disponível (BM25 isolado, lexical fundido e, se instalado, semântico com e sem re-rank), hit@1, hit@5, hit@10 e MRR em nível de documento, de forma determinística.
  - [ ] Limitação registrada no próprio arquivo de evidência: consultas e rótulos foram escritos pelo autor do change sobre este corpus; os números valem como comparação relativa entre modos, não como qualidade absoluta.
- **Rastreia:** proposal §4 (risco b)

## Requisitos não funcionais do change

- **NFR-01 —** Construção do índice lexical do corpus deste repositório em menos de 5 s e consulta lexical em menos de 200 ms (cache quente, máquina de desenvolvimento; medido por `kb.sh build`/`query` com `time`, registrado em evidence).
- **NFR-02 —** Consulta no modo semântico com re-rank em menos de 10 s no corpus deste repositório (mesma medição), e build semântico inicial reportando o tempo total.
- **NFR-03 —** Zero dependência no default: o modo lexical importa apenas módulos `node:*` e arquivos do próprio harness, verificado por teste estático e por execução numa raiz sem `node_modules`.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-02 | subcomando `build` | CLI `kb.sh build` | TASK-04 |
| REQ-02 | subcomando `status` | CLI `kb.sh status` | TASK-04 |
| REQ-03, REQ-04 | consulta, `--top N`, `--json` | CLI `kb.sh query "<texto>" [--top N] [--json]` | TASK-04 |
| REQ-07 | `--no-rerank` | CLI `kb.sh query ... --no-rerank` | TASK-08 |
| REQ-04, REQ-08 | `--lexical` (força modo lexical) | CLI `kb.sh query ... --lexical` | TASK-04 |
| REQ-11 | arquivo de avaliação | CLI `kb.sh eval <arquivo>` | TASK-05, TASK-08 |
| REQ-05 | `semantic install|remove|status` | CLI `kb.sh semantic <sub>` | TASK-07 |
| REQ-01 | fontes indexadas | sem parâmetro exposto (lista fixa) | TASK-01 |
| REQ-10 | comando do agente | `/forge:kb` (commands/graph/kb.md) | TASK-09 |

## Fora de escopo (reafirmação)

- Mudança em `graph.sh` ou no grafo de código.
- Fontes configuráveis pelo consumidor e indexação de `.forge/specs/active/` ou código-fonte.
- Provedor cloud de embeddings ou re-rank (não implementado; só poderia existir como opt-in explícito, decisão futura do dono).
- Resposta sintetizada por LLM (RAG); a busca devolve evidência.
- Indexar conteúdo de peers do liaison (`untrusted-peer`) ou blobs, mesmo com flag.
