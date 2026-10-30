# Requirements — add-ledger-evidence-aging

> Requisitos do change `add-ledger-evidence-aging`. Cada requisito é verificável e rastreável à proposal. Convenções usadas em todos os REQs: **status ativo** = `open`, `planned` ou `in-progress`; **status encerrado** = `resolved`, `wont-fix`, `promoted` ou `superseded` (este último introduzido aqui); **data do commit HEAD** = `git log -1 --format=%cI` no ROOT resolvido, a mesma noção de tempo que `ledger-ops.sh` já usa para `created_at` (nunca relógio de parede); toda porta de escrita nova herda as obrigações transversais das existentes (flag desconhecida e valor vazio reprovam via `lib/arg-guards.sh`, recusa fora de git ou sem commit, re-render do `LEDGER.md`, aviso de divergência de ROOT).

## REQ-01 — Schema aditivo e compatível com ledgers existentes

- **Quando** `ledger.schema.json` é aplicado a qualquer `ledger.json`, **o sistema deve** aceitar, como campos opcionais de cada entrada, `last_verified` (`string` ISO-8601 ou `null`), `evidence` (array de objetos de evidência, REQ-03), `supersedes` (`string` no padrão `^LDG-[0-9]{4}$` ou `null`) e `links.superseded_by` (mesmo padrão ou `null`), e aceitar `superseded` no enum de `status`, sem tornar nenhum desses campos obrigatório.
- **Critérios de aceite:**
  - [ ] O `ledger.json` do próprio repositório (sem nenhum dos campos novos) continua passando na conformidade de schema do gate existente `w202` sem edição do arquivo.
  - [ ] Uma entrada com os quatro campos preenchidos de forma válida passa no schema; uma entrada com `supersedes: "LDG-12"` (padrão inválido) ou com `evidence[0].kind` fora do enum reprova.
  - [ ] Cada registro de `evidence` exige no schema os cinco campos `at`, `kind`, `ref`, `observed` e `verdict`, com `kind` em `file|commit|test|command`, `verdict` em `confirmed|changed` e `additionalProperties: false`: um registro sem `observed` ou com campo extra reprova no schema (e, portanto, no `w202` sobre o ledger real).
  - [ ] `required` da entrada permanece exatamente `["id","type","title","status","source","created_at","dedup_key"]`.
  - [ ] Nenhuma porta existente (`add` sem flag nova, `update`, `note`, `resolve`, `promote`, `harvest`) passa a gravar os campos novos.
- **Rastreia:** proposal §2.1, §3
- **Notas:** compatibilidade é por aditividade, não por migração: item antigo envelhece a partir de `created_at` (REQ-05).

## REQ-02 — Porta `verify`: reverificação explícita que carimba `last_verified`

- **Quando** o operador roda `ledger-ops.sh verify <LDG-NNNN> --kind <k> --ref "<r>" --observed "<txt>" --verdict confirmed|changed`, **o sistema deve** acrescentar ao fim de `evidence` um registro `{at, kind, ref, observed, verdict}` com `at` = data do commit HEAD, gravar `last_verified` = esse mesmo `at`, avançar `updated_at` para o mesmo valor e re-renderizar o `LEDGER.md`.
- **Critérios de aceite:**
  - [ ] `--kind`, `--ref`, `--observed` e `--verdict` são todos obrigatórios; a ausência de qualquer um reprova nomeando a flag, sem gravar nada.
  - [ ] Com `--verdict changed`, o `detail` recebe ao fim um bloco `CORREÇÃO DE REGISTRO (<AAAA-MM-DD>): <observed> [evidência: <kind> <ref>]`, separado por linha em branco, preservando integralmente o `detail` anterior (mesma convenção acumulativa de `note`); com `--verdict confirmed`, o `detail` não muda.
  - [ ] `verify` sobre entrada com status encerrado (`resolved`, `wont-fix`, `promoted`, `superseded`) reprova nomeando o status, sem gravar; entrada inexistente reprova nomeando o id.
  - [ ] Duas reverificações sucessivas resultam em `evidence` com dois registros na ordem de execução e `last_verified` igual ao `at` do último; nenhuma reverificação anterior é apagada ou reescrita.
  - [ ] `verify` não altera `status`, `resolved_at`, `priority`, `severity` nem `title`.
  - [ ] `last_verified` só é gravado por `verify`: `note` (inclusive `--kind measurement`), `update`, `resolve`, `promote`, `harvest`, `/forge:close` e `/forge:archive` não o tocam. `note --kind measurement` imprime em stderr um aviso de que a nota não conta como reverificação e aponta o comando `verify`.
- **Rastreia:** proposal §2.2
- **Notas:** fechamento (`resolve` via archive/close) não carimba `last_verified` porque leva o item a status encerrado, e item encerrado não envelhece (REQ-05).

## REQ-03 — Conteúdo mínimo da evidência, verificado por script

- **Quando** `verify` recebe uma evidência, **o sistema deve** recusar, antes de qualquer escrita, toda evidência cujo conteúdo não possa ser conferido contra o estado real do repositório, segundo o `kind` (enum fechado):
  - `file` — `ref` no formato `<caminho>:<linha>` ou `<caminho>:<linha>-<linha>`, caminho relativo à raiz do projeto, que existe como arquivo regular depois de resolvido por `realpath` (link simbólico cujo destino fica fora da raiz reprova), linhas dentro do intervalo `1..<número de linhas do arquivo>` e intervalo crescente;
  - `commit` — `ref` resolve para um commit em `git rev-parse --verify` no ROOT; o valor gravado é o SHA completo de 40 caracteres, não o abreviado digitado;
  - `test` — `ref` é `<caminho>` ou `<caminho>::<nome>`, com `<caminho>` existente como arquivo regular relativo à raiz;
  - `command` — `ref` é a linha de comando executada, não vazia. O `verify` **nunca executa** o `ref`: `command` é o tipo de evidência mais fraco, sustentado apenas pelo `--observed`, e a documentação diz isso.
- **Critérios de aceite:**
  - [ ] `--observed` exige ao menos 20 caracteres após remover espaços nas pontas e não pode ser igual ao `ref` nem ao `title` da entrada; violação reprova citando a regra.
  - [ ] Para cada `kind`, um caso válido grava e cada violação listada acima (formato, caminho inexistente, linha zero, linha além do fim, intervalo invertido, commit inexistente, caminho absoluto ou com `..` saindo da raiz) reprova com mensagem que nomeia o `kind` e a regra violada, deixando o `ledger.json` byte-a-byte intacto.
  - [ ] `--kind` fora do enum reprova listando os quatro valores aceitos.
  - [ ] Para `kind=test` com `::<nome>`, `<nome>` precisa aparecer literalmente no arquivo (busca de texto fixo); ausência reprova nomeando o arquivo e o nome.
- **Rastreia:** proposal §2.2, §4 risco (b)
- **Notas:** a verificação vale no momento do `verify`; evidência gravada é histórica e não é reconferida depois (o arquivo pode ter mudado, que é justamente o que a próxima reverificação mede). A "raiz do projeto" é o ROOT resolvido por `forge_resolve_root` — o mesmo diretório cujo `ledger.json` está sendo gravado (o checkout principal, ou `FORGE_ROOT`). Um `verify` disparado de dentro de um worktree confere a evidência contra a árvore do ROOT, não contra o worktree; o aviso de divergência de ROOT já emitido pelas portas de escrita anuncia isso, e o comando `/forge:ledger` documenta. Conferir contra o worktree exigiria gravar no ledger de uma branch, o que a resolução de ROOT existe para impedir.

## REQ-04 — Supersessão com elo bidirecional e cadeia consultável

- **Quando** o operador roda `ledger-ops.sh add ... --supersedes <LDG-B>`, **o sistema deve** criar a entrada nova com `supersedes: "LDG-B"` e, na mesma escrita atômica, levar `LDG-B` a `status: superseded`, com `resolved_at` e `updated_at` = data do commit HEAD, `links.superseded_by` = id novo e um bloco `SUBSTITUÍDO (<AAAA-MM-DD>): por <id novo>` acrescentado ao fim do `detail` de `LDG-B`.
- **Critérios de aceite:**
  - [ ] `--supersedes` reprova sem gravar nada quando o alvo não existe, quando o alvo não está em status ativo (inclusive `promoted`, que está sob rastreio de um change, e `superseded`, que já tem sucessor) ou quando o valor não casa `^LDG-[0-9]{4}$`.
  - [ ] `update` não aceita `--supersedes` (flag desconhecida reprova), e `resolve` recusa entrada em `superseded` como já encerrada.
  - [ ] `add --status superseded` e `update <id> --status superseded` reprovam sem gravar e apontam `add --supersedes` como a única porta para esse status (mesma lógica da recusa de `resolved`/`wont-fix` da issue #78: o status só nasce junto do elo e do carimbo).
  - [ ] `spec-new.sh --from-ledger <LDG-B>` com `LDG-B` em `superseded` cria o change (o `--from-ledger` é não-bloqueante hoje, inclusive para id inexistente) mas **não** grava `ledger_origin` nem tenta `promote`, e imprime `WARN` nomeando o sucessor (`links.superseded_by`) e o comando para ligar o change a ele (`ledger-ops.sh promote <sucessor> --to <change-id>`). Assim nenhum change nasce com `ledger_origin` apontando para item encerrado, e o archive nunca tenta resolver um `superseded`.
  - [ ] Uma entrada em `superseded` não sai desse status por porta nenhuma: `update <id> --status <qualquer>` e `promote <id>` reprovam nomeando o sucessor (`links.superseded_by`); o trabalho continua no sucessor.
  - [ ] `ledger-ops.sh show <LDG-NNNN>` imprime a entrada (id, tipo, status, título, `created_at`, `last_verified` ou "nunca reverificado", cada registro de `evidence` e o `detail`) e a cadeia de supersessão completa nas duas direções — da raiz mais antiga ao sucessor mais recente, marcando a posição da entrada consultada — para uma cadeia A substitui B substitui C consultada a partir de qualquer um dos três.
  - [ ] Dado um `ledger.json` corrompido com ciclo de supersessão ou elo apontando para id inexistente, `show` termina, imprime a cadeia até o ponto do defeito e nomeia o defeito (`ciclo` ou `elo quebrado`), sem laço infinito.
  - [ ] `list` acrescenta ` · reverificado em AAAA-MM-DD` à linha de uma entrada com `last_verified` e `(substitui LDG-B)` à de uma entrada com `supersedes`, e o `LEDGER.md` mostra o mesmo elo na entrada ativa e conta `superseded` entre os encerrados da seção.
- **Rastreia:** proposal §2.3
- **Notas:** `supersedes` só nasce no `add`; por isso uma entrada nova nunca pode formar ciclo pela porta, e o guarda de ciclo do `show` existe para dado corrompido à mão.

## REQ-05 — Sinal determinístico de idade: `stale`

- **Quando** o operador roda `ledger-ops.sh stale [--days N] [--as-of <ISO-8601>] [--strict]`, **o sistema deve** examinar todas as entradas em status ativo, calcular para cada uma a idade em dias inteiros `floor((as_of - referência) / 86400000 ms)`, onde referência = `last_verified` se presente, senão `created_at`, e as_of = `--as-of` se dado, senão a data do commit HEAD, e listar as entradas com idade estritamente maior que o limiar.
- **Critérios de aceite:**
  - [ ] Limiar: `--days N` (inteiro ≥ 1) vence; senão `ledger.stale_days` de `.forge/forge.yaml` (inteiro ≥ 1); senão 30. Valor inválido em qualquer das duas fontes (zero, negativo, não inteiro) reprova `stale` com código 2 nomeando a fonte, nunca cai no default em silêncio. `--as-of` não interpretável como data ISO-8601 também reprova com código 2. Sem data de commit HEAD (fora de git ou sem commit) e sem `--as-of`, `stale` reprova com código 2 apontando `--as-of`; com `--as-of`, roda normalmente.
  - [ ] A primeira linha da saída declara o universo e o resultado: `LEDGER stale: <K> de <A> ativo(s) sem reverificação há mais de <N> dia(s) (referência <AAAA-MM-DD>, limiar <N> de <--days|forge.yaml|default>)`, inclusive com `0 de 0` para ledger vazio.
  - [ ] Cada entrada envelhecida ocupa uma linha `<id> — <idade>d — <nunca reverificado (registrado em AAAA-MM-DD) | reverificado em AAAA-MM-DD> — <título>`, ordenadas por idade decrescente e, no empate, por id.
  - [ ] Entradas em status encerrado nunca entram no universo nem na lista, qualquer que seja a idade.
  - [ ] Inconsistências são listadas numa seção própria e contadas, nunca tratadas como item recente: `last_verified` presente sem nenhum registro em `evidence`; `last_verified` diferente do maior `at` de `evidence`; data de referência não interpretável; data de referência posterior ao as_of (idade negativa).
  - [ ] Código de saída: 0 sem `--strict`, haja ou não itens envelhecidos; com `--strict`, 1 quando houver ao menos um item envelhecido ou uma inconsistência, 0 caso contrário.
  - [ ] Mesma entrada `ledger.json` + mesmo as_of + mesmo limiar produzem saída byte-idêntica.
- **Rastreia:** proposal §2.4, §3 (não-bloqueante)
- **Notas:** `forge.yaml` é lido sem parser YAML novo (NFR-01), pelo mesmo idioma `awk` de bloco que `doctor.sh` já usa para `heavy_mutex`.

## REQ-06 — Fiação no ciclo de vida e nas consultas existentes

- **Quando** o estado do ledger é consultado pelos caminhos já existentes, **o sistema deve** expor o envelhecimento e a supersessão sem que o operador precise lembrar do comando `stale`.
- **Critérios de aceite:**
  - [ ] `ledger-ops.sh status` (one-line de `/forge:status`) acrescenta ` · <K> sem reverificação há mais de <N>d` quando K > 0, com o mesmo cálculo e limiar do `stale`; com K = 0 a linha fica como hoje. Limiar inválido no `forge.yaml` não derruba o `status`: a linha ganha ` · limiar ledger.stale_days inválido` em vez da contagem. Sem data de commit HEAD, o `status` continua funcionando como hoje e a linha ganha ` · idade não medida (sem commit HEAD)` em vez da contagem; o `doctor` imprime `info` equivalente.
  - [ ] `/forge:doctor` obtém a contagem delegando a `FORGE_ROOT=<ROOT do doctor> ledger-ops.sh stale` (nunca reimplementando o cálculo) e imprime uma linha informativa (`info`) com a contagem de itens envelhecidos e o comando `ledger-ops.sh stale` quando K > 0, e `ok` quando K = 0; com limiar inválido no `forge.yaml`, imprime `info` nomeando a chave; em nenhum desses casos reprova o doctor nem altera seu código de saída.
  - [ ] `ledger-ops.sh list` marca de forma determinística cada entrada ativa envelhecida com o sufixo ` · sem reverificação há <idade>d`, com o mesmo cálculo e limiar do `stale` (as_of = data do commit HEAD). Como `/forge:resume` e o hook `SessionStart` consultam `list --status open --by-priority --top 5`, o item envelhecido chega marcado exatamente onde o próximo trabalho é escolhido, sem depender de o agente lembrar do `stale`. Sem commit HEAD ou com limiar inválido, `list` lista sem as marcas e imprime uma linha `WARN` em stderr dizendo por quê, sem mudar o código de saída.
  - [ ] O `LEDGER.md` mostra, em cada entrada ativa, `reverificado em AAAA-MM-DD` quando há `last_verified`, sem imprimir idade (que dependeria da data de render e quebraria a renderização determinística).
- **Rastreia:** proposal §2.5

## REQ-07 — `superseded` é encerrado para todo leitor do ledger

- **Quando** qualquer leitor do ledger distribuído classifica entradas em ativas e encerradas, **o sistema deve** tratar `superseded` como encerrado.
- **Critérios de aceite:**
  - [ ] Os conjuntos de status encerrado de `ledger-render.mjs`, do `status` e do `note` de `ledger-ops.sh` incluem `superseded`; a contagem "N itens ativos" do `LEDGER.md` e a do `status` excluem entradas `superseded`.
  - [ ] O gate `w202` (acordo entre a contagem ativa do `LEDGER.md` e a do JSON) continua passando com `superseded` presente no conjunto lido do renderizador.
  - [ ] O design inventaria, por busca no código, todo leitor que classifica status do ledger, e o gate novo afirma a presença de `superseded` em cada conjunto inventariado.
- **Rastreia:** proposal §4 risco (c)

## REQ-08 — Documentação e configuração distribuídas

- **Quando** o change é entregue, **o sistema deve** documentar o mecanismo em todas as superfícies que o consumidor lê.
- **Critérios de aceite:**
  - [ ] `commands/harness/ledger.md` documenta `verify` (com os quatro `kind` e o conteúdo mínimo), `show`, `stale` (limiar, `--strict`, não-bloqueante) e `add --supersedes`; a cópia gerada em `plugin/forge/commands/` fica sincronizada (o gate existente de sincronia do plugin passa).
  - [ ] `commands/harness/ledger.md` também documenta: que o `verify` nunca executa o `ref` de `command`; que a idade é medida pelo commit HEAD do ROOT (um checkout principal parado subnotifica); que `status`/`doctor`/`list` são advisory e o bloqueio em CI é opt-in via `stale --strict`, sem nenhum workflow ligado por padrão; e que o status de entrada `superseded` é distinto do motivo `superseded` do `/forge:close` de um change (que mantém o item `promoted`).
  - [ ] `commands/harness/resume.md` diz que item marcado `sem reverificação há <idade>d` no topo do ledger deve ser reverificado (`verify`) antes de ser sugerido como próximo passo; a cópia em `plugin/forge/commands/` fica sincronizada.
  - [ ] `rules/conventions/ledger-consultation.md` ganha a regra operacional: antes de agir sobre um item ou sugeri-lo como próximo trabalho, conferir se está envelhecido e reverificar com `verify`; item que mudou de natureza é substituído com `add --supersedes`, não reescrito.
  - [ ] `template/.forge/forge.yaml` declara `ledger.stale_days: 30` comentado, e `forge.schema.json` aceita `ledger.stale_days` como inteiro ≥ 1.
  - [ ] `CHANGELOG.md` tem entrada na seção não publicada; o inventário de gates do `README.md` reflete o gate novo.
  - [ ] O usage/`help` de `ledger-ops.sh` lista `verify`, `show` e `stale`.
- **Rastreia:** proposal §2.5

## REQ-09 — Gate de teste hermético com prova de mutação

- **Quando** a suíte roda, **o sistema deve** exercitar REQ-01 a REQ-07 num repositório git sintético isolado (nunca o `ledger.json` rastreado), com contadores de universo e provas de mutação.
- **Critérios de aceite:**
  - [ ] O gate segue o padrão `tests/wNNN-*-gate.sh` (número decidido só no merge), é descoberto pelo `tests/run-all.sh` e passa isoladamente e dentro da suíte completa.
  - [ ] Ao menos três provas de mutação com controle, mutação e recontrole: remover a validação de conteúdo mínimo da evidência faz uma evidência inválida gravar; remover o carimbo de `last_verified` no `verify` faz o item continuar envelhecido; remover `superseded` do conjunto encerrado do renderizador faz a contagem "N itens ativos" do `LEDGER.md` da fixture divergir de um valor esperado fixo, conhecido por construção da fixture (oráculo independente do renderizador, já que o `w202` lê o conjunto do próprio renderizador e não enxergaria a mutação). Restauração verificada por `cmp`.
  - [ ] Os gates existentes do ledger (`w98`, `w157`, `w194`, `w202`, `w203`, `w207`, `w211`) continuam verdes.
- **Rastreia:** proposal §2.6

## Requisitos não funcionais do change

- **NFR-01 —** Zero dependência nova de runtime: só bash, node (≥ 20, módulos nativos) e git, como o resto de `ledger-ops.sh` (medição: `package.json` sem `dependencies` novas; script sem `require` de pacote externo).
- **NFR-02 —** Determinismo: nenhuma porta nova lê relógio de parede (medição: busca por `Date.now`, `new Date()` sem argumento e `date` de shell nas porções novas do script devolve zero ocorrência; datas vêm do commit HEAD ou de `--as-of`).
- **NFR-03 —** Escrita atômica e sem perda: toda porta nova grava via `_write_json` (arquivo temporário + `mv`) e preserva bytes de `detail` existentes (medição: o gate compara o `detail` anterior como prefixo do novo).

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | campos `last_verified`, `evidence`, `supersedes`, `links.superseded_by`, status `superseded` | arquivo `ledger.schema.json` (contrato de dados do `ledger.json`) | a definir em tasks.md |
| REQ-02 | `--kind`, `--ref`, `--observed`, `--verdict` | CLI `ledger-ops.sh verify` | a definir em tasks.md |
| REQ-03 | regras de conteúdo mínimo por `kind` | CLI `ledger-ops.sh verify` (mensagens de recusa) | a definir em tasks.md |
| REQ-04 | `--supersedes` | CLI `ledger-ops.sh add --supersedes`, `ledger-ops.sh show`, `list`, `LEDGER.md` | a definir em tasks.md |
| REQ-05 | `--days`, `--as-of`, `--strict`, `ledger.stale_days` | CLI `ledger-ops.sh stale`; campo de config `forge.yaml > ledger.stale_days` | a definir em tasks.md |
| REQ-06 | sem parâmetro exposto novo (reaproveita o limiar do REQ-05) | CLI `ledger-ops.sh status`, `ledger-ops.sh list` (e por ela `/forge:resume` e o hook `SessionStart`), `/forge:doctor`, `LEDGER.md` | a definir em tasks.md |
| REQ-07 | sem parâmetro exposto (classificação interna de status) | leitores do ledger | a definir em tasks.md |
| REQ-08 | `ledger.stale_days` documentado | `forge.yaml`, `forge.schema.json`, `commands/harness/ledger.md`, rule | a definir em tasks.md |
| REQ-09 | sem parâmetro exposto (gate de teste) | `tests/` | a definir em tasks.md |

## Fora de escopo (reafirmação)

- Bloqueio por idade em qualquer fluxo padrão (change, gate, archive, suíte): só `stale --strict`, invocado explicitamente.
- Memória de sessão do Claude Code (`~/.claude/projects/.../memory/`).
- Confiança numérica, pontuação ou cálculo por LLM.
- Migração ou reescrita retroativa de `ledger.json` de consumidores; carimbo automático de `last_verified` em close/archive/note/update.
- Mudança de semântica de `open`/`planned`/`in-progress`/`resolved`/`wont-fix`/`promoted`, `harvest`, `promote`, `resolve`, `note` ou da guarda de `detail`.
