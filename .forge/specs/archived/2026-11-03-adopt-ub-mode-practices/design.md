# Design — adopt-ub-mode-practices

> Design técnico do change `adopt-ub-mode-practices`. Decisões duráveis e transversais merecem ADR — a decisão de P2/P3 (complexidade/duplicação como sinal vs. gate) é a candidata natural, mas fica deliberadamente como ESTRUTURA pendente (§4.3), não como ADR publicada, porque a decisão depende do spike que este change não executa.

## 1. Contexto e restrições

- **Esta sessão produz só requirements/design/tasks.** Nenhuma TASK deste `tasks.md` roda via `/forge:implement` nesta rodada (NFR-01). Todo o design abaixo descreve o que uma sessão futura vai construir, não o que existe hoje.
- **O change vive em `.forge/specs/active/adopt-ub-mode-practices/`, nunca em `template/.forge/specs/active/`.** Esse segundo caminho é publicado no pacote npm (`package.json` → `files`) e sobrescrito em todo `forge update`/`init` de consumidor — erro cometido e corrigido durante a fase de requirements deste próprio change (ver histórico de commits). Esta restrição governa onde CADA artefato futuro deste change pode ou não pode morar:
  - Script/recipe que precisa chegar aos CONSUMIDORES (REQ-02, REQ-04) vai em `template/.forge/scripts/` ou `template/.forge/skills/gate-runner/SKILL.md`.
  - Gate que só PROVA o mecanismo em CI, sobre o próprio forge-harness (dogfood), vai em `tests/*-gate.sh` na raiz — este diretório NÃO é publicado, então um gate aqui nunca vira ferramenta do consumidor; ele só demonstra, neste repositório, que o mecanismo funciona.
- **O HALT existente (gate-runner: 2 tentativas por gate; TASK: `[!]` e para) não pode afrouxar.** São TRÊS mecanismos de retry distintos, com dono distinto, e o design precisa tratá-los separadamente (nota (a) do gate `requirements_reviewed`, abaixo detalhada em §2.1):
  1. **`/forge:implement` (`commands/specs/implement.md:54`)** — o caminho PRINCIPAL de TASK-by-TASK deste pipeline SDD: 2 tentativas de correção, depois `[!]` e HALT. É aqui que a maioria dos changes (inclusive este, se algum dia for implementado) passa.
  2. **`coding-loop`/`task-coder` (`agents/coding/task-coder.md` §3.7, `commands/coding/coding-loop.md:67,135`)** — um fluxo ESPECIALIZADO e paralelo, para squads trabalhando em ondas de módulos com sync Jira, que HALTa já na 1ª falha (não tem a mesma contagem de 2 tentativas do `implement.md`) e exige reinvocação manual do operador.
  3. **`gate-runner` (`skills/gate-runner/SKILL.md:14`)** — nível MAIS BAIXO, interno a qualquer um dos dois acima: 2 tentativas por GATE individual, depois trata como falha irrecuperável da task. Já escala para o `[!]` dos dois mecanismos acima quando se esgota — REQ-01 não duplica enforcement aqui, só herda o resultado.
- **`rules/testing/quality-gates.md`** já declara, em prosa, a convenção de supressão com referência (linha 74, exemplo `-- ver ISSUE-123`) e as proibições explícitas (linha 128, incluindo `#pragma warning disable`). REQ-03/04 tornam essa prosa determinística, sem contradizê-la.
- **`rules/conventions/code-style.md:58,99,135`** trata complexidade como gatilho de extração e duplicação pela regra de três — decisão que permanece válida e que a estrutura de ADR do REQ-06 precisa confrontar explicitamente, não ignorar.
- **Licenciamento do ub-mode mudou durante esta mesma rodada de requirements**: o repositório `unclebob/ub-mode` ganhou licença MIT em 2026-11-02 (commit `3da62bf`), depois do relatório original que motivou esta proposta. A razão para não copiar o `SKILL.md` literalmente deixa de ser "sem licença" (resolvida) e passa a ser "escopo e qualidade do texto não avaliados para este repositório" — a decisão de não copiar o texto continua, a justificativa muda. Isto corrige a nota (c) do gate `requirements_reviewed` — a seção "Fora de escopo" do `requirements.md` já foi atualizada (linha 103) durante esta mesma sessão.

## 2. Decisão técnica

### 2.1 REQ-01/REQ-02 — "Attack the Premise": enriquecer o HALT existente, com artefato NOVO e mínimo

**Correção de escopo em relação às 2 redações anteriores deste design (registrado através das rodadas sucessivas de validação):** as duas primeiras tentativas mapearam este REQ também sobre `/forge:red replay`. Essa aplicação estava CONCEITUALMENTE ERRADA, e a revisão adversarial confirmou por que: o replay do Red reproduz o defeito ORIGINAL sobre a árvore pré-correção — ele não exercita nenhuma correção, então "2ª tentativa de correção reprovada no replay" não é um evento que existe no mecanismo real. `red-evidence.schema.json` não tem (e não deveria ter) um conceito de "tentativa de correção reprovada". **Decisão final: este REQ se aplica SÓ aos dois mecanismos onde "tentativa de correção que falha" é um evento real — `/forge:implement` e `coding-loop`/`task-coder`. O caminho Red fica fora de escopo desta rodada**, e a proposta original (que citava "Attack the Premise" de forma genérica) é atendida parcialmente, com essa redução registrada aqui, não escondida.

**Gatilho exato (resolve o CLARIFY sobre `implement.md:54` cobrir três causas distintas numa frase só):** o texto real da linha é "Falha irrecuperável (**gate falha após 2 tentativas de correção**, dependência externa indisponível, decisão de produto necessária): marque `[!]`, **pare a execução** e reporte o que travou". Este REQ dispara SÓ na primeira causa — "gate falha após 2 tentativas de correção" — nunca nas outras duas (dependência externa, decisão de produto), que não são "tentativa de correção" nenhuma.

**Artefato novo (caminho `/forge:implement`, principal):** ao marcar `[!]` POR ESSA causa específica, o `implement.md` passa a acrescentar, imediatamente após a frase real "marque `[!]`, **pare a execução** e reporte o que travou", um bloco de formato fixo em `tasks.md`:

```markdown
- [!] TASK-04 — <título> (rastreia: REQ-02; paths: ...)
  > FALHA: gate falha após 2 tentativas de correção — <sintoma objetivo, 1 linha>
  > Gate: <nome do teste/gate que reprovou>
  > Premissa: <a suposição que as duas tentativas compartilhavam>
  > Ator(es) com o desequilíbrio: <quem/o que carrega a responsabilidade mal distribuída>
```

Os dois campos só existem quando o motivo do `[!]` é literalmente "gate falha após 2 tentativas de correção" — para as outras duas causas, o `[!]` fica como está hoje, sem os campos novos.

**Caminho `coding-loop`/`task-coder` — resolução final (4ª correção, as 3 anteriores se contradiziam entre si sobre quando o contador zera):**

O bloco "Última falha" (`task-coder.md` §3.7) deixa de ser sobrescrito a cada falha e passa a ACUMULAR uma entrada por ocorrência — sem isso, "comparar contra a última ocorrência da TASK" não tinha histórico para ler, que era a inconsistência real apontada na revisão. Cada entrada agora registra também o GATE que falhou (resolve "falha em gate diferente não deveria contar"):

```markdown
## ⚠️ Última falha — Wave 3 / TASK-01 (2ª ocorrência desta TASK neste gate)

**Quando:** 2026-05-10 22:23
**Gate:** `dotnet build`
**Specialist invocado:** ...
**Sintoma:** ...
**Premissa:** <preenchido só na 2ª ocorrência consecutiva DESTA TASK NO MESMO GATE>
**Ator(es) com o desequilíbrio:** <idem>
**Próxima ação humana:** ...
**Logs:** ...
```

Entradas anteriores da mesma ou de outras TASKs permanecem no arquivo (histórico, nunca apagado) — uma TASK que depois chega a `[X]` não some suas entradas de falha anteriores, que ficam como registro, sem efeito prático (a TASK já está fechada).

**Contagem, com a contradição da revisão resolvida (reinvocação do operador vs. "retomada humana zera"):** o contador é por par (`TASK-NN`, `Gate`) — uma falha num gate diferente da mesma TASK é sempre 1ª ocorrência desse par. Dentro do MESMO par, a distinção que resolve a contradição é: **reinvocar o `coding-loop` sobre a mesma TASK sem ter preenchido `Premissa:`/`Ator(es):` na ocorrência anterior CONTA como a 2ª ocorrência da série** (é só repetir a tentativa, não uma retomada informada); **só a reinvocação que segue uma ocorrência com `Premissa:`/`Ator(es):` preenchidos — ou seja, que o humano já viu a atribuição nomeada antes de decidir seguir — é que abre série nova** (reset do contador), porque essa é a retomada real que o ub-mode descreve ("remove the assignment... do not start another fix until you have done that"). Antes de a premissa ser nomeada, não existe "retomada informada" para abrir série nova — só mais uma tentativa da mesma série.

**O que NÃO muda:** nenhum dos dois halts ganha uma tentativa automática extra. `implement.md:54` continua parando após 2 tentativas de correção; `coding-loop.md:58,67` continua com HALT imediato na 1ª falha, reinvocação manual do operador. **O que muda** é a condição de RETOMADA informada (a reinvocação que segue a premissa nomeada): só conta como tendo atendido a este REQ se muda a atribuição nomeada em `Ator(es) com o desequilíbrio:`. Uma retomada que repete a forma das tentativas anteriores não atende ao REQ mesmo que o humano a autorize; a prosa da regra (não um gate, que não julga "mudou a atribuição?") orienta essa leitura.

**Formato único, estilo adaptado a cada arquivo (resolve a divergência bullet+blockquote vs. negrito):** os dois caminhos usam o MESMO conjunto de campos — `Gate`, `Premissa` (a partir da 2ª ocorrência), `Ator(es) com o desequilíbrio` (idem) — com a marcação que já é convenção de cada arquivo (`> Campo:` no bloco compacto de `tasks.md`; `**Campo:**` no bloco em negrito de `PROGRESS-TRACKING.md`). `check-attack-premise.sh --file <path>` reconhece os dois estilos de marcação pelo mesmo nome de campo, não pelo caractere de prefixo.

**Decisões de produto fixadas aqui:**
- **Retomada informada (pós-premissa nomeada) abre série nova** — não toda reinvocação, só a que segue uma ocorrência com premissa já registrada (ver acima).
- **Worktrees paralelas não precisam de trava nova** — o bloco vive em arquivo versionado (`tasks.md`/`PROGRESS-TRACKING.md`) com commit atômico por TASK já exigido pelo fluxo; diferente do hub do liaison, não há escrita concorrente de processos distintos a proteger aqui.
- **`session-discipline.md`** ganha uma referência curta na seção de "Falha irrecuperável", remetendo ao formato do bloco acima.
- **Persistência do bloco após `[X]`:** o bloco de falha em `tasks.md` (ou a entrada acumulada em `PROGRESS-TRACKING.md`) NÃO é removido quando a TASK fecha — `spec-verify.sh` recusa `[!]` aberto, mas o histórico de falhas de uma TASK hoje `[X]` permanece no arquivo como registro, exatamente o que a seção abaixo lê.
- **`verification.md`** (artefato real escrito por `/forge:verify`, estrutura confirmada em `commands/specs/verify.md` §2: `## Resultado` / `## Evidências por requisito` / `## Checks deterministas` / `## Desvios e observações`) ganha uma quinta seção, **`## Premissas atacadas`**, preenchida por um MODO LISTAGEM do próprio `check-attack-premise.sh` (`--list --file tasks.md` e `--list --file PROGRESS-TRACKING.md`), que lê os dois artefatos e lista toda TASK com `Premissa:`/`Ator(es):` preenchidos e como a retomada endereçou a atribuição — gerada, não escrita à mão.
- **A mitigação chega ao humano de fato, corrigindo a lacuna real encontrada na revisão final:** o `/forge:archive` §2 (`commands/specs/archive.md`) mostra hoje só um resumo de 2-3 linhas do delta via `AskUserQuestion`, SEM nunca abrir `verification.md` — a afirmação anterior deste design, de que o `human_archive_approval` "lê o campo", não tinha caminho real até o humano. Correção: o resumo do `archive.md` §2 passa a incluir uma linha adicional, derivada da contagem de `## Premissas atacadas` em `verification.md` ("N premissa(s) atacada(s) nesta implementação — ver verification.md"), tornando a mitigação visível no próprio texto que o humano já lê nesse gate, sem exigir que ele abra um arquivo extra para notar que existe algo a conferir.
- **Eixo "3" independente do teto de Review:** o teto de 3 rodadas de `Review` em gates HITL (`commands/specs/requirements.md:55-58`) conta rodadas de revisão humana de um ARTEFATO; o contador deste REQ conta falhas de execução de uma TASK no MESMO gate. Eixos diferentes, nenhum reaproveita o contador do outro.

**Gate novo (REQ-02), hospedagem e pontos de chamada reais:**
- **Script para consumidores:** `template/.forge/scripts/check-attack-premise.sh --file <tasks.md|PROGRESS-TRACKING.md> --task-id <id>` — UM script, mas com regra de disparo DIFERENTE por arquivo (isto é o contrato que a TASK futura implementa, sem ambiguidade): em `tasks.md`, os campos são exigidos sempre que a causa do `[!]` é literalmente "gate falha após 2 tentativas de correção" (um único bloco, sem conceito de "ocorrência"); em `PROGRESS-TRACKING.md`, são exigidos a partir da 2ª entrada do par (TASK, Gate) desde a última retomada informada (histórico acumulado). O script reconhece os dois formatos de marcação (`> Campo:` vs `**Campo:**`, cabeçalho `##`/`###` conforme `task-coder.md:408,503`) pelo nome do campo.
- **Consequência da reprovação, definida (resolve o MISS "o que acontece quando reprova"):** o script roda IMEDIATAMENTE após o bloco ser escrito, pelo mesmo processo que acabou de escrevê-lo — se reprovar, o relatório de HALT (a mensagem "humano decide" de `implement.md:54`) NÃO é emitido até os campos serem completados; é a implementação concreta de "do not start another fix until you have done that" do texto do ub-mode. Além disso, a checagem entra como PRÉ-CONDIÇÃO DE RETOMADA em dois pontos adicionais: `implement.md` (a seção que trata retomada/idempotência de uma TASK já em `[!]`) e o preflight de `task-coder.md` que hoje já recusa abrir nova onda com `[!]` pendente — os dois passam a recusar retomar uma TASK em `[!]` cuja 2ª ocorrência não tenha os campos.
- **Pontos de chamada (âncora de TEXTO real, conferida contra o arquivo — nunca número de linha):**
  - `commands/specs/implement.md`, imediatamente após a frase literal "marque `[!]`, **pare a execução** e reporte o que travou" (negrito original conferido no arquivo — a âncora precisa incluir os `**`), condicionado a essa causa específica ser "gate falha após 2 tentativas de correção".
  - `agents/coding/task-coder.md` §3.7, imediatamente após o bloco "Última falha" ser escrito no tracker.
- **Receita nova em `template/.forge/skills/gate-runner/SKILL.md`** ("Premissa nomeada").
- **Prova em CI deste repositório (dogfood):** grupos dedicados dentro do gate único do change (`tests/adopt-ub-mode-practices-gate.sh`, decidido na fase `/forge:tasks` — um gate só, por grupo de cenário, não um arquivo por mecanismo), com cenários SEPARADOS para os dois caminhos (resolve o CLARIFY da 5ª rodada — o cenário anterior só cobria `coding-loop`):
  - `tasks.md`: controle (`[!]` por "gate falha após 2 tentativas de correção" com `Premissa:`/`Ator(es):` → aceito), violação (mesma causa sem os campos → reprovado), contracontrole (`[!]` por dependência externa SEM os campos → aceito, porque essa causa não dispara o REQ).
  - `PROGRESS-TRACKING.md`: controle/violação como já descritos (2ª entrada do par TASK+Gate).
  - Mutação cobrindo a checagem interna E os dois pontos de chamada E os dois pontos de pré-condição de retomada E a linha nova de `archive.md` §2 E a chamada `--list` em `verify.md` (remover qualquer uma precisa fazer um cenário falhar — padrão `w198-liaison-push-union-gate.sh`).

**Schema:** nem `progress.schema.json` nem `red-evidence.schema.json` são estendidos — os campos vivem como texto dentro dos blocos markdown já existentes/estendidos acima (`tasks.md`, `PROGRESS-TRACKING.md`).

### 2.2 REQ-03/REQ-04 — Scanner de supressão sem referência, como gate bloqueante

**Gramática de referência válida, revisada** (a 1ª redação tentava distinguir `#123` de cor hex por comprimento/conteúdo e se contradizia — `#123` é simultaneamente exemplo que casa E exemplo de hex de 3 dígitos excluído. Correção: eliminar a ambiguidade removendo `#\d+` BARE da lista — toda referência por número exige uma palavra-chave antes, o que também já é o padrão real do exemplo canônico):

| Padrão | Sensível a caixa? | Exemplo que casa | Exemplo que NÃO casa (motivo) |
|---|---|---|---|
| `LDG-\d+` | Não | `LDG-0021`, `ldg-21` | — |
| `ADR-\d+` | Não | `ADR-0005` | — |
| `ISSUE-\d+` | Não | `ISSUE-123` (o exemplo canônico de `quality-gates.md:74`) | — |
| `(issue\|closes\|fixes\|ver)\s*#\d+` (case-insensitive na palavra, fronteira de palavra via `(^\|[^A-Za-z0-9])` antes e `([^A-Za-z0-9]\|$)` depois — NUNCA `\b`, que o BSD grep/sed do macOS não suporta; dígitos sempre decimais) | Não (palavra) / não (dígitos) | `issue #45`, `Closes #7`, `-- ver #123` | `#000`, `#1a2b3c` (nunca casam — não há padrão bare `#\d+`); `never #12`/`prefixes #3` (a fronteira de palavra exclui `issue`/`closes`/`fixes`/`ver` como sufixo de outra palavra) |

**Chave de tracker tipo Jira (`PAY-123` etc.) FICA FORA DE ESCOPO nesta rodada — simplificação, não omissão.** A 1ª tentativa deste design propôs uma allowlist em `forge.yaml`, mas o schema real (`template/.forge/schemas/forge.schema.json`) tem `additionalProperties: false` e não declara essa chave — a config Jira real do harness mora em `integrations.jira` do FRONTMATTER do `FORGE.md` (schema `forgeFrontmatter`, confirmado por grep), uma superfície de config DIFERENTE e mais arriscada de estender sob pressão de tempo nesta rodada. Decisão: `LDG-NNNN`/`ADR-NNNN`/`ISSUE-NNN`/`issue #NNN`/`closes #NNN`/`fixes #NNN` já cobrem o caso real sem exigir nova superfície de configuração; quem quiser referenciar Jira usa `# ver ISSUE-123` ou um item de ledger como ponte. Se houver demanda real por chave nativa de tracker, fica para change futuro que decida onde a allowlist mora.

Um comentário livre como `# TODO(nome): motivo`, sem nenhum identificador acima, NÃO conta como referência válida. Isto é um ENDURECIMENTO deliberado sobre `quality-gates.md:128` ("justificativa em comentário" — sem exigir ID hoje): a decisão consciente é subir a régua, documentada como tal na linha nova da rule (§4.2), não um relaxamento acidental da regra existente.

**Hospedagem — alternativas avaliadas (resolve o MISS "candidatos não avaliados"):**

| Candidato | Por que não |
|---|---|
| `node-quality-scan/scan.sh` (`template/.forge/skills/node-quality-scan/`) | Específico de Node — REQ-03 cobre também Python; duplicaria lógica entre dois scanners de stack |
| Gate isolado em `tests/*-gate.sh` chamado em runtime | `tests/` não é publicado (`package.json` → `files` só inclui `template/`) |
| `/forge:verify` | Opera sobre o change INTEIRO, não o diff incremental — rodaria sobre código não tocado por este change, fora do critério do REQ-03/04 |
| **Gate-runner (escolhido)** | Já é o catálogo de recipes genérico e stack-agnóstico consultado por quem monta QUALQUER sequência de gates deste harness (não um executor fixo — os pontos de chamada reais são `/forge:ship` e `pre-push`, abaixo); documentar a receita aqui, em vez de embutir a lógica só num script solto, deixa o mecanismo descobrível por qualquer comando futuro que precise da mesma checagem, sem duplicar a lógica entre JS/TS e Python |

- **Base do diff, corrigida (M1 da revisão final — a 1ª redação falhava silenciosamente sem `origin/develop`: `git merge-base` sem esse ref sai com rc 128/vazio, e o diff resultante contra `HEAD` fica vazio, aprovando por omissão):** reusar o resolvedor já real e testado deste repositório, `_redfirst_resolve_base`/`_docs_resolve_base` (`template/.forge/hooks/git/lib/check-red-first.sh:17-33`, mesmo padrão em `check-docs-reviewed.sh`) — cadeia `remote_sha` (se não for zero) → `origin/develop` → `origin/HEAD` → `origin/main` → commit raiz. O `pre-push` já tem esse resolvedor disponível; `/forge:ship` usa a mesma cadeia contra `HEAD` local (sem remote_sha, já que roda antes do push). Base vazia ou `git diff` com rc≠0 REPROVA com mensagem nomeando a causa, nunca aprova por omissão.
- **Script para consumidores:** `template/.forge/scripts/check-suppression-reference.sh`, com recipe nova em `template/.forge/skills/gate-runner/SKILL.md` ("Supressão sem referência" — grep sobre as LINHAS ADICIONADAS do diff, nunca o arquivo inteiro: `git diff "<base resolvida acima>"...HEAD -- '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' '*.py'` filtrando por linhas `+` — cobre TODAS as extensões JS/TS citadas no REQ-03, não só `.ts`/`.tsx`).
- **Exclusão de código gerado/vendorizado E do `.forge/` do CONSUMIDOR, ancorada na raiz — restaurada à forma original (M2 pedia exatamente isto; uma tentativa intermediária, durante a revisão de `tasks_reviewed`, tentou restringir a exclusão a subdiretórios de estado, o que reabriu o M2 original — consumidor que versiona `.forge/scripts/` voltaria a ser bloqueado — e deixou `.forge/evals/` deste próprio repositório, 9.369 arquivos versionados com supressões legítimas de fixture, fora da exclusão. Revertido para a forma simples, que resolve os dois problemas de uma vez):** glob `*_pb2.py`, `*.pb.ts`, `*_grpc_pb.*`, qualquer arquivo cujas primeiras 5 linhas contenham `@generated`/`DO NOT EDIT` (sem diferenciar maiúsculas/minúsculas) — E **todo o `.forge/` na RAIZ do repositório** (um nível, `git rev-parse --show-toplevel`/`.forge/**`, nunca recursivo por nome em qualquer profundidade). Como `template/.forge/` é um diretório IRMÃO de `.forge/` na raiz (não aninhado dentro dele), esta exclusão de um nível só já deixa `template/.forge/scripts/`/`template/.forge/skills/` normalmente visíveis ao scanner neste próprio repositório — sem precisar de nenhuma exceção por subdiretório. Achado concreto desta revisão: `template/.forge/scripts/lib/red-evidence-ops.mjs:484` e `template/.forge/skills/frontend-ui-review/scripts/scan-native-controls.py:723` têm hoje supressão sem identificador, visíveis ao scanner por estarem fora do `.forge/` da raiz — uma TASK de higiene (sem Red comportamental, só adiciona comentário) as conserta.
- **Lista de exclusão extensível PELO CONSUMIDOR (M3 — a 1ª redação chamava a lista de "extensível", mas ela morava num script que `forge update` sobrescreve, sem superfície de config, forçando `--no-verify` em falso positivo):** arquivo de projeto `.forge/suppression-scan-exclude.txt`, mesmo padrão já estabelecido por `.forge/empty-universe-allowlist.txt` (`gate-universe.mjs:11-17`) — path glob por linha, com `# motivo: <justificativa>` obrigatório, nunca reescrito por `forge update`.
- **Chamada real:** o script roda dentro do `/forge:ship`, no passo de testes/gates ANTES do commit mas DEPOIS de staged (`git diff --cached`, cobrindo o que será commitado; `ship.md` passo 3 precede o commit do passo 4 — corrigido aqui para não se contradizer com "antes do commit") e do hook `pre-push` (cobre o commit já feito, contra a base resolvida).
- **Prova em CI deste repositório:** grupo dedicado dentro do mesmo gate único (`tests/adopt-ub-mode-practices-gate.sh`), com os três cenários do REQ-04 (controle, violação, contrafactual de universo via `forge_universe_check`) MAIS o cenário "sem `origin/develop` acessível → cadeia de fallback resolve, nunca aprova por diff vazio" (este último com Red real no grupo de gramática, não só na mutação) e o mesmo padrão de mutação do §2.1.
- **Cobertura de stack nesta rodada:** JS/TS (todas as extensões da tabela acima) e Python, como já decidido no requirements. `rules/testing/quality-gates.md` ganha uma linha na seção "Portão de decisão para burndown de lint" citando o script novo como enforcement, sem alterar o exemplo canônico `-- ver ISSUE-123` nem o escopo C#/.NET/Bash (que fica fora, dito explicitamente).

### 2.3 REQ-05 — Roteiro do spike (não executado nesta rodada)

**Universo fixado, com a definição corrigida (M6 da revisão final — "excluir `.forge/` e `node_modules/`" não bastava: `Payments.DevPortal/.next/` não é ignorado pelo git e tem milhares de arquivos `.js` de BUILD, contra ~50 arquivos de código fonte — uma varredura de disco mediria o bundle numa proporção de dezenas para um):**
1. `template/.forge/scripts/**/*.mjs` deste repositório (consumidor interno).
2. `/Users/milton/Documents/projects/payments/Payments.DevPortal`, com o universo definido por **`git ls-files` (nunca varredura de disco)** — isso exclui `.forge/`, `node_modules/`, `.next/` e qualquer outro artefato de build não versionado, automaticamente, sem precisar enumerar exclusões.

**Roteiro executável (TASK de sessão futura):**
1. Complexidade: parser AST — `@babel/parser` só pode ser usado para medir o universo INTERNO deste repositório (onde já é devDependency); sobre `Payments.DevPortal` (consumidor externo, sem essa dependência), o script resolve a ferramenta via `npx <parser>@<versão fixada>` sem instalar nada permanentemente, nunca assumindo a presença de uma devDependency do harness num workspace de terceiros (script e local final: `tools/spike-complexity-duplication.mjs`, nunca `template/.forge/scripts/`, que seria publicado exigindo a dependência em todo consumidor) — percorrendo cada arquivo do universo, calculando complexidade ciclomática por função. Cobertura, ordem de preferência (corrigida — CC²+CC sem termo de cobertura é MATEMATICAMENTE IDÊNTICO a assumir cobertura zero, e isso é o viés que a revisão final apontou, não uma correção dele): (a) `Payments.DevPortal` não tem `vitest`/`c8`, mas o reporter `lcov` nativo de `node --test --experimental-test-coverage` existe a partir do Node 20 — a TASK confirma a versão instalada e usa esse reporter nativo antes de considerar qualquer alternativa; (b) só na ausência comprovada de qualquer fonte de cobertura, o spike reporta COMPLEXIDADE PURA (CC, sem elevar ao quadrado nem somar) como sinal, explicitamente rotulado "sem dado de cobertura" nos achados — nunca a fórmula CRAP completa com cobertura assumida zero.
2. Duplicação: `jscpd` via `npx jscpd@<versão fixada>` (nunca instalado como dependência do harness nem do consumidor — multi-linguagem, candidato a cobrir JS/TS/Python/C#/Bash, a confirmar no próprio spike) sobre o mesmo universo, limiar inicial 0,8 (ub-mode) e 0,82 (dryer) para comparação.
3. Critério de decisão: achados acima do limiar classificados manualmente numa amostra de 20 (ou todos, se menos que 20) como "verdadeiro positivo" (extração real compensa) ou "falso positivo conhecido" (switch/tabela de despacho, código gerado, teste parametrizado repetitivo). Se > 30% da amostra for falso-positivo conhecido no limiar padrão, o limiar sobe (não desce — menos ruído é a direção segura) e a amostra é recalculada; se mesmo assim > 30%, a proposta de gate bloqueante (vs. sinal) é descartada e a ADR do REQ-06 registra "sinal não-bloqueante" como decisão.
4. Execução **só-leitura** sobre `Payments.DevPortal` — nenhuma dependência nova instalada no consumidor (o risco da issue #10 do `crapper` upstream, que instala `@vitest/coverage-v8` sozinho).

### 2.4 REQ-06 — Estrutura de ADR, decisão pendente do spike

O `design.md` deste change (este arquivo, §2.4 abaixo como conteúdo literal a copiar) contém o texto completo da estrutura MADR. Uma TASK futura, depois do spike (§2.3), preenche a seção "Decision" com o resultado e invoca `/forge:adr` passando esse conteúdo decidido como entrada — `/forge:adr` cria o arquivo numerado em `.forge/product/current/adr/`; a TASK nunca cria ou numera manualmente.

> **[Conteúdo da futura ADR — rascunho literal]**
>
> **Title:** Complexidade (CRAP) e duplicação estrutural: sinal não-bloqueante, gate bloqueante, ou não adotar
>
> **Status:** DECIDIDO COM BASE NO SPIKE (REQ-05 / `adopt-ub-mode-practices`, resultado em `spike-result.md`)
>
> **Context:** O relatório `reference/plano-ub-mode-vs-forge-harness.md` identificou que o forge-harness não mede complexidade ciclomática nem duplicação estrutural sistematicamente, enquanto a skill `unclebob/ub-mode` trata ambas como gate bloqueante com limiar fixo (CRAP < 10, duplicação ≥ 0,8, via `crapper`/`dryer`). A convenção já registrada neste repositório (`rules/conventions/code-style.md:58,99,135`) trata complexidade como gatilho de extração (não gate) e duplicação pela regra de três (não limiar fixo) — uma filosofia deliberadamente diferente, de controle qualitativo em vez de numérico. **Nota de atualização:** o repositório `unclebob/ub-mode` ganhou licença MIT em 2026-11-02 (commit `3da62bf`), posterior ao relatório original. A razão para não copiar o `SKILL.md` literalmente deixa de ser "sem licença" (resolvida) e passa a ser "escopo e qualidade do texto não avaliados para este repositório" — a decisão de não copiar o texto permanece, a justificativa muda. **ADRs do baseline que restringem as opções abaixo** (achado da revisão final — nenhuma redação anterior as citou): ADR 0001 estabelece o princípio de zero dependências de execução (decidido para o engine do grafo, mas como princípio geral do harness) — um `jscpd` como GATE bloqueante que exige instalação no consumidor tensiona esse princípio, não o viola diretamente (0001 não cobre este mecanismo por escopo); ADR 0005 (camada opt-in instalada sob demanda, mesmo padrão já usado pela camada semântica do `/forge:kb`) é o precedente de COMO introduzir uma dependência nova sem violar 0001; ADR 0003 (Red-first) já decidiu, para outro mecanismo, que "sinal avisa, não veta" quando descartou coverage-diff como gate bloqueante — mesmo princípio em jogo aqui.
>
> **Options Considered:**
> 1. **Limiar fixo, gate bloqueante** (filosofia ub-mode) — simples de implementar, mas historicamente gera fatiamento cosmético perto do limiar (ver LDG-0061, `max-lines`) e falso positivo em `switch`/tabela de despacho.
> 2. **Sinal não-bloqueante no `code-evaluator`/`quality-reviewer`** — preserva a convenção atual (extração por julgamento), soma dado objetivo à revisão sem travar merge.
> 3. **Não adotar** — se o spike mostrar ruído alto (>30% falso-positivo mesmo após ajuste de limiar), o custo de manutenção não compensa.
> 4. **Depender das ferramentas upstream do ub-mode (`crapper`/`dryer`)** — descartada preventivamente: autor único, sem release, achado de segurança aberto no `crapper` (CWE-829, instala dependência sozinho; CWE-776, XXE no parser JaCoCo). Precedente do LDG-0061 recomenda vendorizar/reimplementar, nunca depender do upstream.
>
> **Decision:** Opção 2 — **sinal não-bloqueante**, mesmo princípio de ADR 0003 ("sinal avisa, não veta"). O spike real sobre `Payments.DevPortal` (50 arquivos, 429 funções; `spike-result.md`, TASK-14) mediu, no limiar inicial do ub-mode (CC < 10), 50% de falso-positivo numa amostra completa de 8 achados (n < 20, sem subamostragem) — bem acima dos 30% do critério de decisão. Subindo o limiar (nunca descendo, por desenho) para 15 o falso-positivo cai para 33,3%, ainda acima de 30%; só em 20 o falso-positivo zera (0/2). Mas nesse limiar o gate captura 2 de 429 funções (0,47%) — sinal raro demais para justificar um BLOQUEIO de merge: a Opção 1 (limiar fixo bloqueante) fica descartada não por ruído alto no limiar final, mas pela tensão oposta — limiar baixo o suficiente para capturar algo relevante reabre exatamente o fatiamento cosmético que `LDG-0061` já documentou neste repositório, e limiar alto o suficiente para não reabrir isso quase nunca dispara. A duplicação não teve achado algum nos limiares padrão do `jscpd` neste universo — resultado inconclusivo, nem confirma nem refuta a hipótese, sem amostra para aplicar a regra dos 30%. A Opção 3 (não adotar) fica descartada: mesmo sem gate bloqueante, a complexidade ciclomática por função é um dado objetivo que soma à revisão humana sem o custo/risco de travar merge — jogar fora o instrumento desperdiçaria a mediação já feita. A Opção 4 permanece descartada pelos motivos de segurança já registrados em Context.
>
> **Consequences:**
> - Positivas: `code-evaluator`/`quality-reviewer` ganham um dado objetivo (CC por função) para contextualizar a revisão de extração por julgamento já praticada (`code-style.md`), sem o risco de fatiamento cosmético de um gate bloqueante; a convenção qualitativa atual (regra de três, gatilho de extração) permanece intacta, reforçada em vez de substituída.
> - Negativas/débitos: (1) o instrumento de medição (`tools/spike-complexity-duplication.mjs`) conta `LogicalExpression` (`&&`/`||`/`??`) como ponto de decisão — 1 dos 4 falsos positivos do limiar 10 (`schemaFields`) veio especificamente desse viés (removendo os pontos de `LogicalExpression`, o CC cai de 13 para 7, abaixo do limiar); um segundo caso candidato (`operationPage`) foi descartado após recontagem mecânica — seu CC permanece acima do limiar (18 → 12) mesmo sem `LogicalExpression`, então sua classificação de falso-positivo depende só da razão estrutural (builder aditivo), não desse viés. Qualquer uso futuro do sinal precisa corrigir o viés confirmado (ao menos 1 caso real) primeiro, ou herda um viés de instrumento, não só de domínio. (2) A implementação concreta do sinal (P2/P3 do relatório original) fica FORA do escopo executável deste change — abre um change futuro, condicionado a essa correção de instrumento. (3) Duplicação como sinal fica sem validação real: a próxima medição (change futuro, ou reexecução deste mesmo roteiro sobre um universo maior) precisa confirmar se `jscpd` com limiares padrão produz sinal útil antes de integrá-lo a qualquer revisão.

### 2.5 REQ-07 — Item de ledger para P4, condicionado

Texto final, pronto para `ledger-ops.sh add --type tech-debt` numa TASK futura:

> **Título:** Mutação sistemática (StrykerJS/Stryker.NET/PIT/mutmut) sobre código de consumidor, condicionada a lógica crítica
> **Detalhe:** O forge-harness tem prova de mutação artesanal (controle/recontrole) em 73 dos 218 gates do próprio repositório (medido em 2026-11-02, durante este change — a contagem cresce a cada gate novo), mas nenhuma ferramenta de mutação roda sobre código de CONSUMIDOR via `/forge:verify`. Abrir um change de implementação só quando houver um consumidor com lógica crítica (ex.: um repositório de pagamentos) que justifique o custo de CI — rodar mutação sobre o próprio forge-harness é descartado: cada mutante exigiria `run-all.sh` (218 gates, já dividido em 3 shards de CI), custo proibitivo; a mutação artesanal por gate continua sendo o mecanismo deste repositório.
> **Severidade:** LOW (follow-up condicionado, sem data de ativação).
> **Origem:** manual, change `adopt-ub-mode-practices`.
> **Verificação do LDG-0021 feita agora, não deferida:** conferido no `LEDGER.md` real deste repositório — o LDG-0021 trata de "prova de mutação mede as regras que existem, não a superfície de entrada que elas deixam passar", um escopo sobre fuzzing guiado por gramática e corpus de adotantes, DIFERENTE do P4 aqui (ferramenta de mutação rodando sobre código de CONSUMIDOR via `/forge:verify`). Não há sobreposição real — este item nasce separado, sem `--ref`.

## 3. Alternativas consideradas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| REQ-01: permitir uma 3ª tentativa automática informada pela premissa (leitura inicial, errada) | Mais simples de implementar; "tenta mais uma vez" é familiar | Contradiz o texto real do ub-mode ("remove the assignment... do not start another fix until you have done that"); afrouxa o HALT que hoje já funciona | Corrigido no design atual: HALT não muda, só a condição de retomada |
| REQ-02/REQ-04: gate novo dentro de `tests/*-gate.sh`, chamado em runtime pelo consumidor | Reaproveita o padrão de gate já conhecido deste repositório | `tests/` não é publicado no pacote npm (`package.json` → `files` só inclui `template/`) — o consumidor nunca teria o gate | Dois artefatos: script em `template/.forge/scripts/` (consumidor) + gate em `tests/` só para provar aqui (dogfood) |
| REQ-03: aceitar qualquer `#\d+` BARE (sem palavra-chave) como referência, distinguindo cor hex por comprimento/conteúdo | Regex "parece" mais simples | A 1ª redação deste próprio design se contradisse (`#123` listado como exemplo que casa E como hex de 3 dígitos excluído) — heurística frágil | `#\d+` só conta PRECEDIDO de `issue`/`closes`/`fixes`/`ver`; cor hex nunca tem essa palavra, então nunca precisa ser distinguida por forma |
| REQ-03: aceitar chave de tracker tipo Jira (`[A-Z]{2,5}-\d+`) nesta rodada, com allowlist em `forge.yaml` | Cobriria referência de Jira nativamente | `forge.schema.json#/$defs/forgeManifest` tem `additionalProperties: false` e não declara essa chave — exigiria estender um contrato de config sob pressão de tempo, risco desproporcional ao valor | Fora de escopo (§2.2); `# ver ISSUE-123` ou item de ledger cobrem o caso real |
| REQ-05: medir duplicação/complexidade sobre TODO o workspace Payments | Amostra maior | `.forge/` de cada sub-repo replica milhares de `.mjs` do próprio harness, contaminando a medição; maioria dos sub-repos é .NET, fora do escopo desta rodada (JS/TS) | Universo fixado em um único sub-repo Node, excluindo `.forge/` |
| REQ-06: ADR já com decisão tomada nesta rodada | Fecha o ciclo mais rápido | Decidiria antes da medição que deveria fundamentar a decisão — inverteria spike → ADR → gate | Decision fica PENDENTE, por desenho |

## 4. Contratos e integrações afetados

### 4.1 Nenhum contrato de schema é alterado

**Correção de resíduo da 1ª/2ª redação:** este design chegou a propor extensão de `red-evidence.schema.json` para o caminho Red, removido do escopo em §2.1. Nenhum schema (`progress.schema.json`, `red-evidence.schema.json`, `forge.schema.json`) é tocado por este change — os campos de REQ-01 vivem como texto nos blocos markdown de §2.1, e REQ-03/04 não introduzem configuração nova (a chave de tracker Jira, que exigiria isso, ficou fora de escopo).

### 4.2 `rules/testing/quality-gates.md` (REQ-03)

Uma linha nova na seção "Portão de decisão para burndown de lint", citando o script novo (`check-suppression-reference.sh`) como enforcement determinístico — o exemplo canônico (`-- ver ISSUE-123`) e o escopo atual (burndown de lint herdado) não mudam.

### 4.3 `template/.forge/skills/gate-runner/SKILL.md` (REQ-02, REQ-04)

Duas receitas novas ("Premissa nomeada", "Supressão sem referência"), seguindo o formato de receita existente (uma linha `OK`/`FAIL`, log em `/tmp`).

## 5. Plano de migração / rollout

Ordem recomendada pelo relatório original, preservada aqui:

1. **P1 (REQ-01/02) e P5 (REQ-03/04)** — implementação direta, sem dependência de spike. Cada um é uma TASK de `tasks.md` autocontida.
2. **Spike (REQ-05)** — roteiro executado por uma sessão futura; resultado alimenta o REQ-06.
3. **ADR (REQ-06)** — decisão preenchida com o resultado do spike, publicada via `/forge:adr`.
4. **P2/P3** — implementação condicionada à decisão da ADR (fora do escopo executável deste change; change novo se a decisão for "adotar").
5. **P4 (REQ-07)** — fica como item de ledger até um consumidor crítico justificar o custo; sem data.

Nenhuma dessas TASKs quebra consumidor existente: P1/P5 são aditivos (campo novo opcional, gate novo que só reprova padrão já proibido em prosa); o spike é leitura; a ADR não tem efeito até uma implementação futura decidir agir sobre ela.

## 6. Riscos e mitigação

| Risco | Probabilidade | Impacto | Mitigação / detecção |
|---|---|---|---|
| Campo `Premissa:`/`Ator(es):` preenchido mecanicamente, sem reflexão real (o mesmo resíduo epistêmico do Red-first — o campo prova que algo foi escrito, não que está certo) | Média | Médio | O campo entra na revisão humana do `human_archive_approval`. **Limite honesto, não escondido:** por `autonomy-yolo.md:64`, `human_archive_approval` é hard-stop DEFAULT, mas configurável em `human_hard_stops` — um consumidor pode reconfigurar esse hard-stop para baixo. A mitigação depende de configuração que o consumidor controla, mesma categoria de limite que outras mitigações deste harness (nunca uma garantia absoluta de código) |
| Scanner de supressão (REQ-03/04) gerar falso positivo em código legítimo fora do universo previsto (ex.: arquivo gerado sem marcador `@generated` reconhecido) | Média | Baixo (bloqueia push, não dado) | Lista de exclusão por glob é extensível; decisão é bloqueante desde o início (REQ-03 fixa isso), sem modo WARN transitório — a correção de um falso positivo real é ampliar a exclusão, não suspender o gate |
| Spike (REQ-05) alterar o ambiente do consumidor `Payments.DevPortal` ao gerar cobertura | Baixa | Médio (risco já documentado, issue #10 do crapper) | Execução só-leitura, sem instalar dependência nova — usa `node --test --experimental-test-coverage` nativo (Node 20+); sem essa fonte, reporta complexidade pura (nunca CRAP com cobertura assumida zero, que infla o achado) — ver §2.3 |
| Universo de medição do spike incluir artefato de build não versionado (ex.: `.next/`), inflando falso positivo de duplicação | Média (achado real desta revisão) | Médio | Universo definido por `git ls-files`, nunca varredura de disco — exclui automaticamente tudo que não é código versionado |
| Dois mecanismos de "3 tentativas" (REQ-01 e o teto de Review de gates HITL) confundidos por quem lê a regra | Média | Baixo | Design explicita (§2.1, "Eixo independente do teto de Review") que são eixos independentes — um conta falha de execução, outro conta rodada de revisão humana; TASK de implementação repete essa distinção na prosa das rules editadas |
| Alguém esperar suporte a chave de tracker tipo Jira no REQ-03 e não encontrar | Baixa | Baixo | Fora de escopo explícito em §2.2, com alternativa documentada (`# ver ISSUE-123` ou ledger) — não é lacuna silenciosa |

## 7. Rastreabilidade

| REQ | Seção do design que o atende |
|---|---|
| REQ-01 | §2.1 |
| REQ-02 | §2.1 |
| REQ-03 | §2.2 |
| REQ-04 | §2.2 |
| REQ-05 | §2.3 |
| REQ-06 | §2.4 |
| REQ-07 | §2.5 |
| NFR-01 | §1 (restrição de caminho) |
| NFR-02 | §2.1, §2.2 (gates já nascem com nome/cenários/mutação especificados) |
