# Design — add-ledger-evidence-aging

> Design técnico do change `add-ledger-evidence-aging`. Nenhuma decisão aqui é transversal o bastante para ADR: tudo fica dentro da maquinaria do ledger, que já tem contrato próprio (`ledger.schema.json`, `ledger-ops.sh`, rule `ledger-consultation.md`).

## 1. Contexto e restrições

- **Uma fonte de escrita.** Todo `ledger.json` é escrito só por `ledger-ops.sh` (porta por subcomando, `_write_json` atômico, `_render` a cada mutação). As portas novas seguem o mesmo idioma: parsing com `lib/arg-guards.sh` (flag desconhecida e valor vazio reprovam), `_require_git_date` (recusa fora de git/sem commit), `forge_warn_root_divergence` nas portas que escrevem, mutação dentro de um bloco `node -` com heredoc.
- **ROOT é o checkout principal.** `forge_resolve_root` devolve `FORGE_ROOT` ou o tronco (via `--git-common-dir`), nunca o worktree. Caminhos de evidência são resolvidos contra esse ROOT, que é o mesmo diretório cujo `ledger.json` está sendo gravado.
- **Uma noção de tempo.** Datas vêm do commit HEAD (`git log -1 --format=%cI`), nunca de relógio de parede. Idade é diferença entre duas datas ISO, ambas determinísticas.
- **Não-bloqueante.** A rule `ledger-consultation.md` diz que registrar no ledger nunca trava nada. O sinal de idade é advisory; só `--strict` explícito devolve código de falha.
- **Duas verdades proibidas.** O comentário do `ledger-ops.sh` sobre `resolved_at` (issue #78) registra que manter dois carimbos para o mesmo fato produziu drift medido. Por isso `last_verified` só é escrito por uma porta (`verify`) e sempre junto do registro de evidência que o justifica, e o `stale` audita a coerência entre os dois.
- **Leitores existentes classificam status por conjunto literal.** Medido por busca (`rg "resolved', 'wont-fix', 'promoted'"` e variantes em `template/`, `bin/`, `tests/`): `lib/ledger-render.mjs` (`CLOSED`, linha 45), `ledger-ops.sh` `note` (`CLOSED`, linha 383), `ledger-ops.sh` `status` (`CLOSED`, linha 597). `ledger-ops.sh resolve` recusa por comparação literal (`resolved`/`wont-fix`, linha 427). `tests/w157` tem uma lista de status como dado de propriedade (não classifica ativo/encerrado e não precisa mudar). `doctor.sh` só filtra `promoted`. `hooks/session/on-session-start.sh` e `commands/harness/resume.md` consultam `list --status open`, que já exclui qualquer status diferente de `open`.
- **Gates existentes que olham as portas** (medido por busca em `tests/`): `w193 [9]` deriva o universo de portas de escrita da linha `add|update|...)` do `forge_warn_root_divergence` e reprova porta sem caso na matriz — `verify` entra nessa linha e ganha caso na matriz do `w193` (é porta de escrita: grava `ledger.json`). `w193 [8]` e `w211 [19]` exigem que `list` (porta de leitura) não emita o aviso de divergência; a marca de envelhecimento não muda isso, e o `WARN` de degradação do `list` só aparece sem HEAD ou com limiar inválido, condições que essas fixtures não produzem (elas têm commit e usam o `forge.yaml` do template). Nenhum gate compara a saída do `list` byte a byte: `w211 [17]` e `w193 [8]` só procuram o id/título na saída, e fixtures criadas no próprio HEAD têm idade 0, sem marca. `show` e `stale` são portas de leitura e ficam fora da lista de divergência.
- **Gates de mutação que casam literais de `ledger-ops.sh`** (medido por busca dos `perl -0pi` em `tests/` que apontam para o script): `w211 [20/M5]` casa o literal `add|update|note|resolve|promote|harvest|render)` da lista de portas; `w207 [6]` casa `^(  add|[a-z|]*)|render)` (exige `render` no fim da lista); `w193 [9]` deriva o universo pela linha que começa em `  add|`; `w211 [20/M8]` casa `if (e.status === 'resolved' || e.status === 'wont-fix') {` no `resolve`; `w257 [HM]` casa a linha inteira do ramo `-h|--help|help` com o texto de usage atual; `w202 [5]` exige `_validate_enum_field ... "source.origin"` imediatamente antes de `_require_git_date` no `add`. Estratégia por alvo, todas parte deste change: (i) `verify` entra na lista de portas **entre `note` e `resolve`** — preserva o `add|` inicial do `w193` e o `|render)` final do `w207`, e o `w211 M5` passa a casar por âncora (`s/^(  add\|[a-z|]*?)\|note(\|[a-z|]*\))/$1$2/m`, o mesmo idioma ancorado do `w207`, imune à próxima porta); (ii) a recusa de `superseded` no `resolve` entra como `if` próprio **antes** da linha literal, que fica intacta para o `M8`; (iii) a linha de usage muda (REQ-08) e o alvo do `w257 [HM]` é atualizado para o texto novo; (iv) a validação de padrão de `--supersedes` no shell entra antes das validações de enum do `add`, nunca entre `source.origin` e `_require_git_date`. Além desses, há alvos de **primeira ocorrência** (perl sem `/g`) dentro do `note` e do `update`: `w211 M1` (`if (destroi && repl !== '1') {`), `M2` (`e.detail = prev ? prev + SEP + bloco : bloco;`), `M3` (`const day = String(now).slice(0, 10);`), `M4` (`  _render\n  echo "OK note`), `M6` (`de.indexOf(prev) === -1`), `M7` (`if (prev && prev.indexOf(text) !== -1) {`), `M8` (acima); `w194` (`[ -n "$value" ] && return 0` em `arg-guards.sh`, a linha `NOCHANGE` do `update` e `*) _reject_unknown "add"...`). Como o bloco do `add` (onde nasce o `SUBSTITUÍDO`) vem antes do `note` no arquivo, uma cópia literal dessas linhas no código novo passaria a ser a primeira ocorrência e roubaria a mutação. Regra de implementação: o código novo **não repete byte a byte nenhuma linha-alvo** — usa nomes próprios (`sepV`/`blocoV`/`diaV` e afins) para o acréscimo acumulativo do `verify` e do `SUBSTITUÍDO` — e não depende de posição no arquivo. Detecção: os próprios `w211`/`w194`/`w193` rodam no DoD da TASK-03 e da TASK-04 e na suíte completa antes do verify (TASK-11), e um alvo roubado aparece como `[20/Mn]` vermelho.
- **Zero dependência de runtime** (NFR-01) e determinismo (NFR-02).

## 2. Decisão técnica

### 2.1 Schema (REQ-01)

Em `properties.entries.items.properties` de `ledger.schema.json`, campos novos todos opcionais, `required` intocado:

```json
"last_verified": { "type": ["string", "null"], "description": "Data do commit HEAD da última reverificação (gravada só por verify). Igual ao maior evidence[].at." },
"evidence": { "type": "array", "items": { <objeto de evidência, inline> } },
"supersedes": { "type": ["string", "null"], "pattern": "^LDG-[0-9]{4}$" }
```

`links.properties` ganha `"superseded_by": { "type": ["string", "null"], "pattern": "^LDG-[0-9]{4}$" }`; `status.enum` ganha `"superseded"`. O objeto de evidência é declarado **inline** em `evidence.items` (não em `$defs`), porque o gate existente `w202` compila `properties.entries.items` isoladamente com ajv, e um `$ref` para `#/$defs/...` não resolveria a partir dessa sub-raiz. O objeto tem `additionalProperties: false`, `required: ["at","kind","ref","observed","verdict"]`, `kind` enum `["file","commit","test","command"]`, `verdict` enum `["confirmed","changed"]`, `ref` e `observed` com `minLength: 1`, `at` string. O schema garante forma; o conteúdo mínimo (REQ-03) é do script, porque depende do estado do repositório no momento da escrita e não cabe em JSON Schema.

### 2.2 Porta `verify` (REQ-02, REQ-03)

```
ledger-ops.sh verify <LDG-NNNN> --kind file|commit|test|command --ref "<r>" --observed "<txt>" --verdict confirmed|changed
```

Fluxo, com toda recusa antes de qualquer escrita:

1. Parsing com `VERIFY_FLAGS="--kind --ref --observed --verdict"`, `_require_value` em cada uma e `_reject_unknown`; cada uma das quatro ausente reprova nomeando a flag.
2. `kind` e `verdict` validados contra o enum do schema por `_validate_enum_field` (a fonte única de enum já existente), estendido para descer em arrays: no caminho `evidence.kind`/`evidence.verdict`, ao passar por um nó com `items`, o helper entra em `items.properties` (mudança de uma linha, sem afetar os caminhos existentes, que não atravessam array).
3. `_require_git_date` (fixa `GIT_DATE_NOW`), `_init_ledger`.
4. `kind=commit`: no shell principal, `sha="$(git -C "$ROOT" rev-parse --verify --quiet "${ref}^{commit}")"`; vazio reprova. O `ref` gravado passa a ser `sha` (40 caracteres).
5. Bloco node único que: localiza a entrada (inexistente reprova); recusa status encerrado (`resolved`, `wont-fix`, `promoted`, `superseded`) nomeando-o; valida `observed` (trim ≥ 20, diferente de `ref` e de `title`); valida o conteúdo por `kind` (abaixo); acrescenta o registro `{at: now, kind, ref, observed, verdict}`; grava `last_verified = now` e `updated_at = now`; se `verdict = changed`, acrescenta ao `detail` `CORREÇÃO DE REGISTRO (<dia>): <observed> [evidência: <kind> <ref>]` com o separador `\n\n` do `note` (ou como único conteúdo se `detail` vazio).
6. `_write_json`, `_render`, `OK verify — <id> reverificado (<verdict>, <kind>)`.

Validação por `kind` (dentro do node, com `fs` e `path` nativos):

- `file`: regex `^(.+):([0-9]+)(?:-([0-9]+))?$`; caminho não pode ser absoluto; `real = fs.realpathSync(path.join(ROOT, p))` deve existir e `path.relative(realpath(ROOT), real)` não pode começar por `..` nem ser absoluto (cobre `..` e symlink que sai da raiz); `fs.statSync(real).isFile()`; número de linhas = `conteúdo.split('\n').length` menos 1 se o arquivo termina em `\n`; exige `1 ≤ l1 ≤ l2 ≤ linhas`.
- `test`: `ref` dividido em `::` (primeiro separador); a parte de caminho passa pelas mesmas regras de existência/contenção do `file`, sem linha; se houver `<nome>`, ele precisa aparecer literalmente no conteúdo do arquivo (`conteúdo.includes(nome)`).
- `command`: `ref.trim()` não vazio (o `_require_value` já barra vazio; o trim barra só-espaços). O `ref` é gravado como texto e **nunca executado**: executar comando arbitrário vindo de flag numa porta de escrita do ledger seria superfície de execução sem ganho de prova (a saída observada já vem em `--observed`).
- `commit`: já resolvido no passo 4.

A mensagem de cada recusa segue a forma `FAIL: ledger-ops: verify <id> --kind <k>: <regra violada>`.

`note --kind measurement` ganha uma linha `WARN` em stderr: a nota foi gravada e não conta como reverificação; para isso, `ledger-ops.sh verify <id> ...`. O `note` não muda de comportamento em nenhum outro aspecto.

### 2.3 Supersessão (REQ-04)

`add` ganha `--supersedes <LDG-B>` (em `ADD_FLAGS`). Validação de padrão no shell (`^LDG-[0-9]{4}$`). No bloco node do `add`, antes de criar a entrada: localiza `B` (inexistente reprova), exige status ativo (senão reprova nomeando o status e, para `promoted`, o change que o rastreia). Na mesma estrutura em memória, cria a entrada nova com `supersedes: B` e muta `B`: `status = 'superseded'`, `resolved_at = updated_at = now`, `links.superseded_by = novo id` (criando `links` se ausente), e acrescenta `SUBSTITUÍDO (<dia>): por <novo id>` ao `detail` com separador `\n\n`. Uma única `_write_json` grava as duas mudanças, então não há estado intermediário em disco.

`update` não ganha a flag; o `_reject_unknown` existente já recusa. `resolve` passa a recusar também `superseded` por um `if` próprio antes da condição da linha 427, que fica literalmente intacta (alvo do `w211 M8`); `promoted` continua resolvível porque é o caminho do archive.

Portas de status fechadas para `superseded`, no idioma da recusa da issue #78: o `case` de `add --status` e o de `update --status` (linhas 214 e 283) ganham `superseded` ao lado de `resolved|wont-fix`, com mensagem própria apontando `add --supersedes`. Saída do status: no bloco node do `update`, se a entrada está em `superseded` e `--status` foi passado, reprova (exit 4 já é usado pela guarda de detail; usa exit 5) nomeando `links.superseded_by`; no bloco node do `promote`, entrada em `superseded` reprova do mesmo jeito. `update` de `title`/`priority`/`severity`/`detail` numa entrada `superseded` continua permitido (correção de registro histórico não reabre nada).

`show <LDG-NNNN>` (leitura, sem aviso de divergência) imprime:

```
LDG-0003 [tech-debt/open] (P2/MEDIUM) — <título>
  registrado: 2026-09-05 · reverificado: 2026-10-30 (ou "nunca reverificado")
  evidência:
    1. 2026-10-30 confirmed file src/a.ts:12 — <observed>
  cadeia de supersessão: LDG-0001 → LDG-0002 → [LDG-0003]
  detail:
    <detail>
```

A cadeia é montada andando para trás por `supersedes` e para frente por `links.superseded_by`, com conjunto de visitados: ao revisitar um id, para e imprime `(ciclo em LDG-NNNN)`; ao encontrar id ausente, para e imprime `(elo quebrado: LDG-NNNN não existe)`. Sem cadeia, a linha diz `cadeia de supersessão: —`.

`list` acrescenta ` · reverificado em <dia>` quando há `last_verified`, ` (substitui LDG-B)` quando `supersedes` está preenchido e ` · sem reverificação há <idade>d` quando a entrada ativa está envelhecida segundo `ageReport` (mesmo módulo, limiar e as_of = HEAD do `stale`; §2.4). A resolução do limiar e da data do HEAD acontece no shell antes do bloco node do `list`; se qualquer uma falhar, o `list` passa `days` vazio ao node, que lista sem marcas, e o shell imprime `WARN: ledger-ops: list sem marca de envelhecimento — <motivo>` em stderr, mantendo rc 0. É por esse caminho que `/forge:resume` e o hook `SessionStart` (ambos chamam `list --status open --by-priority --top 5`) recebem a marca sem mudança no hook.

`spec-new.sh`: antes do bloco que grava `ledger_origin` (linha 134), quando `--from-ledger` foi dado e o `ledger.json` existe, um `node -e` lê o status e o `links.superseded_by` da entrada. Se o status for `superseded`, o script não grava `ledger_origin`, pula o `promote` e imprime `WARN: ledger: <B> foi substituído por <sucessor> — change criado sem elo; para ligar: ledger-ops.sh promote <sucessor> --to <id>`. Qualquer outro caso (inclusive id inexistente) mantém o comportamento atual, coberto pelo `w98 [4]`. `ledger-render.mjs` acrescenta à linha da entrada ` · reverificado em <dia>` quando há `last_verified` e uma linha `  ↳ substitui \`LDG-B\`` quando há `supersedes`; entradas sem os campos novos renderizam byte-idênticas às de hoje.

### 2.4 Cálculo de idade: `lib/ledger-aging.mjs` (REQ-05, REQ-06)

Módulo ESM novo, sem dependência, com uma função pura e um modo CLI:

- `ageReport(entries, { asOf, days })` devolve `{ universe, stale: [{id, age, ref, kind: 'never'|'verified', title}], inconsistent: [{id, reason}] }`. Universo = entradas com status ativo. Referência = `last_verified ?? created_at`. Idade = `Math.floor((Date.parse(asOf) - Date.parse(ref)) / 86400000)`. Inconsistência (e a entrada sai do cálculo de idade): referência não interpretável (`Number.isNaN(Date.parse(...))`), referência posterior ao as_of (idade negativa), `last_verified` presente com `evidence` ausente ou vazio, `last_verified` diferente do maior `evidence[].at` (comparação de string ISO, que é a forma gravada por `verify`). Ordenação: idade desc, id asc.
- CLI `node ledger-aging.mjs <ledger.json> <asOf> <days> <origem-do-limiar> [--summary]`: imprime o relatório completo do `stale` ou, com `--summary`, uma linha `K A` para o `status`.

`ledger-ops.sh stale` resolve o limiar: `--days` (inteiro ≥ 1 por regex `^[1-9][0-9]*$`) > `ledger.stale_days` lido de `$ROOT/.forge/forge.yaml` com o mesmo idioma `awk` de bloco que o `doctor` usa para `heavy_mutex` > 30. Valor presente e inválido em qualquer fonte reprova com rc 2 nomeando a fonte. `as_of` = `--as-of` (validado por regex de data ISO `^[0-9]{4}-[0-9]{2}-[0-9]{2}` mais `Date.parse` não-NaN; inválido reprova com rc 2) ou a data do HEAD obtida por `_git_date` **no shell principal** (não `_require_git_date`, que sai com rc 1 e não fala de `--as-of`): vazia, o `stale` sai com rc 2 e a mensagem `sem data de commit HEAD em <ROOT> — passe --as-of <data ISO>`. É desse caminho que vem o rc 2 "sem HEAD" que o `doctor` mapeia para `info`. Saída do CLI; com `--strict`, rc 1 se `stale` ou `inconsistent` não vazios.

`ledger-ops.sh status` chama o mesmo módulo em modo `--summary` com as_of = data do HEAD (se não houver commit, omite a contagem com ` · idade não medida (sem commit HEAD)`) e acrescenta ` · K sem reverificação há mais de Nd` quando K > 0. Limiar inválido no `forge.yaml` vira ` · limiar ledger.stale_days inválido` em vez de falhar.

`doctor.sh`, no bloco advisory do ledger já existente, roda (com `|| true` e captura do rc, para que nenhum código de saída do `stale` vaze para o doctor) `FORGE_ROOT="$ROOT" bash "$ROOT/.forge/scripts/ledger-ops.sh" stale` e lê a primeira linha: K > 0 vira `info "harness: ledger — K item(ns) ativo(s) sem reverificação há mais de N dia(s) (rode ledger-ops.sh stale)"`; K = 0 vira `ok`; rc 2 (limiar inválido ou sem HEAD) vira `info` com a primeira linha do stderr; qualquer outro rc ≠ 0 vira `info "harness: ledger — idade não medida (stale rc=<n>)"`. Nunca incrementa o contador de falhas do doctor.

### 2.5 Conjunto encerrado (REQ-07)

Leitor interno adicional, achado na validação das tasks: `tools/plan-progress.mjs` (placar do plano de issues, não distribuído a consumidores) classifica `resolved` como entregue e `wont-fix`/`promoted` como reclassificado, e qualquer outro status como aberto. `superseded` entra no balde `RECLASSIFIED` (encerra por decisão, não por entrega), na mesma task dos conjuntos `CLOSED`.

`superseded` entra nos três conjuntos `CLOSED` inventariados (§1) e na recusa do `resolve`. O gate novo lê cada um desses sítios por regex sobre o arquivo-fonte (idioma do `w202 [3]`) e afirma a presença de `superseded`, falhando se o padrão não for encontrado (guarda contra o sítio mudar de forma e o check passar por vacuidade).

### 2.6 Configuração e documentação (REQ-08)

Além do listado abaixo, `ledger.md` documenta: `command` nunca executado; idade medida pelo HEAD do ROOT (checkout parado subnotifica); `status`/`list`/`doctor` advisory e CI opt-in via `stale --strict` sem workflow ligado por padrão; homônimo `superseded` (status de entrada × motivo de `/forge:close`). `resume.md` (passo 5) ganha a instrução de reverificar item marcado antes de sugeri-lo e uma linha dizendo que o resume lista só `open` (itens `planned`/`in-progress` envelhecidos aparecem no `/forge:status`, no `/forge:doctor` e no `stale`, não no resume — limitação herdada do filtro, fora de escopo); `npm run build:plugin` sincroniza a cópia.

`forge.schema.json`: `ledger.properties.stale_days = { "type": "integer", "minimum": 1 }`. `template/.forge/forge.yaml`: chave **ativa** `stale_days: 30` sob `ledger:` (não comentada — "comentado" no REQ-08 significa acompanhada de comentário explicativo; com a chave ativa, o `stale` de um consumidor recém-instalado declara a origem `forge.yaml`, e o operador vê onde mudar), com comentário dizendo o que mede, que é advisory e como o `--strict` serve a CI. `commands/harness/ledger.md`: blocos de uso de `verify`, `show`, `stale`, `add --supersedes` e uma seção "Reverificação e envelhecimento"; `npm run build:plugin` regenera `plugin/forge/commands/ledger.md`. Rule `ledger-consultation.md`: regra operacional 7 (antes de agir sobre um item ou sugeri-lo, conferir `stale`/`show`; reverificar com `verify`; item que mudou de natureza vira `add --supersedes`), `last_reviewed` atualizado. Usage de `ledger-ops.sh` (cabeçalho e `help`) lista os três subcomandos novos. `CHANGELOG.md` na seção não publicada; badge/inventário do `README.md`.

### 2.7 Gate (REQ-09)

`tests/wNNN-ledger-evidence-aging-gate.sh` (número no merge), no molde do `w211`: fixture copiada de `template/.forge` para `mktemp -d`, `git init` com commit em data fixa (2019-03-04) para que a data do HEAD nunca coincida com hoje, `FORGE_ROOT` apontando para a fixture, `_run_to` em todo comando externo, retrato do `ledger.json` real antes/depois (o gate nunca escreve nele), contador de cenários declarados × executados. Cenários por REQ e as três provas de mutação do REQ-09 sobre cópias dos arquivos da fixture (nunca sobre `template/`), restauração por cópia de fonte nunca escrita e conferida com `cmp`. A terceira mutação (tirar `superseded` do `CLOSED` do renderizador da fixture) usa como oráculo um número fixo de itens ativos conhecido por construção da fixture, comparado com o "N itens ativos" do `LEDGER.md` re-renderizado — independente do conjunto do renderizador, que é o que está sendo mutado.

## 3. Alternativas consideradas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| Derivar `last_verified` de `evidence` (sem campo próprio) | Uma verdade só, sem auditoria de coerência | Contraria o desenho aprovado pelo dono (campo explícito); todo leitor externo teria que recalcular | Mantido o campo, escrito por uma porta só e auditado pelo `stale` |
| Carimbar `last_verified` no `/forge:archive`/`/forge:close` | Zero esforço do operador | Esses fluxos encerram o item, e item encerrado não envelhece; carimbo sem evidência é exatamente o campo vazio que se quer evitar | Rejeitado |
| Contar `note --kind measurement` como reverificação | Reaproveita o hábito existente | Texto livre sem referência conferível; voltaria a ser "campo de preenchimento" | Rejeitado; o `note` avisa e aponta para `verify` |
| Supersessão sem status novo (fechar o anterior como `wont-fix`) | Não mexe nos leitores | Semântica falsa ("não vamos fazer") e perde o elo no conjunto de status | Rejeitado; status `superseded` com inventário dos leitores |
| Gate de CI reprovando o ledger do próprio repositório por idade | Força a reverificação | Viola o "não-bloqueante por design"; hoje reprovaria 38 de 38 itens e travaria todo PR | Rejeitado; `--strict` fica disponível para quem optar |
| Confiança numérica (sessões × recência × contradições), como no `ai-memory` | Sinal mais rico | Pontuação sem calibração vira número que ninguém sabe ler; fora de escopo declarado | Rejeitado |
| Evidência só validada por schema (formato) | Simples | Formato não prova que o arquivo/commit existe; `ref: "x:1"` passaria | Rejeitado; validação de conteúdo no script |

## 4. Contratos e integrações afetados

- **`ledger.schema.json`** — mudança aditiva (campos opcionais, valor novo de enum). Ledger antigo valida sem alteração. Um harness antigo lendo um ledger novo: o renderizador antigo não conhece `superseded` e o contaria como ativo — aceitável porque harness e ledger são atualizados juntos pelo `forge update`, e o efeito seria só de contagem. Consumidor com enum estendido (registrado no liaison) não é afetado: nenhum valor existente sai do enum.
- **CLI `ledger-ops.sh`** — três subcomandos novos (`verify`, `show`, `stale`) e uma flag nova em `add`; nenhuma flag ou saída existente muda, exceto o sufixo opcional no `status` e no `list` (aditivo ao fim da linha).
- **`LEDGER.md`** — texto aditivo apenas em entradas com campos novos.
- **`forge.yaml`/`forge.schema.json`** — chave nova opcional.

## 5. Plano de migração / rollout

Sem migração: itens existentes envelhecem a partir de `created_at`. No primeiro `forge update` de um consumidor, `ledger-ops.sh status` passa a mostrar a contagem de itens velhos — o rollout é o próprio sinal. Para o dogfood deste repositório, nenhum item é reverificado dentro deste change (não é escopo; o ledger do tronco é durável e não é escrito por branch de feature).

## 6. Riscos e mitigação

| Risco | Probabilidade | Impacto | Mitigação / detecção |
|---|---|---|---|
| Mudança de texto em `ledger-ops.sh` quebra ou rouba alvo literal de mutação de outro gate (`w211` M1–M8, `w194`, `w207`, `w193`, `w257`, `w202`) | Alta sem inventário | Gate existente vermelho na suíte | Inventário e estratégia por alvo em §1; `npm test` completo antes do verify |
| Leitor do ledger não inventariado conta `superseded` como ativo | Média | Contagem divergente | Inventário por busca em §1; gate afirma cada conjunto; `w202 [3]` compara render × JSON |
| Evidência de `file` aponta para o tronco quando o operador está num worktree em outra branch | Média | Evidência confere arquivo de outra branch | ROOT é o mesmo do `ledger.json` gravado (comportamento já documentado); `forge_warn_root_divergence` avisa; documentado no comando |
| Operador contorna o conteúdo mínimo com `--kind command` e texto genérico | Média | Evidência fraca | `observed` ≥ 20 caracteres e ≠ `ref`/`title`; a revisão humana do PR vê o registro estruturado; limite assumido e documentado |
| Sinal de idade vira ruído e é ignorado | Média | Envelhecimento continua silencioso na prática | Limiar configurável; contagem no `status`/`doctor` (onde o operador já olha); rule manda conferir antes de sugerir trabalho |
| `forge.yaml` com `stale_days` inválido derruba `/forge:status` | Baixa | Comando de status quebrado | `status` degrada para aviso textual; só `stale` reprova (rc 2) |
| Datas `created_at` legadas em formato não ISO | Baixa | Idade errada | Data não interpretável vira inconsistência listada, nunca item "recente" |

## 7. Rastreabilidade

| REQ | Seção do design que o atende |
|---|---|
| REQ-01 | §2.1, §4 |
| REQ-02 | §2.2 |
| REQ-03 | §2.2 (validação por `kind`) |
| REQ-04 | §2.3 (inclui `spec-new.sh`) |
| REQ-05 | §2.4 |
| REQ-06 | §2.3 (render, `list`), §2.4 (`status`, `doctor`) |
| REQ-07 | §1 (inventário), §2.5 |
| REQ-08 | §2.6 |
| REQ-09 | §2.7 |
| NFR-01 | §1, §2.4 |
| NFR-02 | §1, §2.4 |
| NFR-03 | §2.2, §2.3 (escrita única) |

## 8. Notas do gate `design_reviewed` (incorporadas à implementação)

- **Comparação cronológica, não lexical.** A inconsistência "`last_verified` diferente do maior `evidence[].at`" compara por `Date.parse` (offsets diferentes entre commits não geram falso positivo); `last_verified` deve ser igual, em instante, ao `at` do último registro. Se o HEAD do ROOT for anterior ao `last_verified` corrente, o `verify` grava normalmente e avisa em stderr (o relógio do ROOT voltou no tempo).
- **Definição única de ativo.** O universo do `stale`, do sufixo do `status` e da marca do `list` é "status fora do conjunto encerrado" (`resolved`, `wont-fix`, `promoted`, `superseded`), a mesma forma que `status` e o renderizador usam; para ledgers conformes ao enum isso coincide com `open`/`planned`/`in-progress`, e um consumidor com enum estendido não vê o cabeçalho do `stale` divergir do `status`.
- **Portas de leitura.** `stale` e `show` chamam `_init_ledger`, como `status` e `list` já fazem; `show` de id inexistente sai com rc 1.
- **Formato canônico da linha do `list`.** `<id> [<type>/<status>] (<tags>) — <título>` seguido, nesta ordem e só quando aplicáveis, de ` (substitui LDG-B)`, ` · reverificado em AAAA-MM-DD`, ` · sem reverificação há <idade>d`.
- **Fuso do `--as-of`.** Data sem hora é lida como UTC pelo `Date.parse`; o resultado é determinístico, mas pode deslocar a idade em um dia em relação a datas com offset. Documentado no `ledger.md`.
- **Rollout.** O `forge update` não reescreve `forge.yaml` de consumidor existente; esses verão a origem `default` (30) até declararem a chave. Dito no `CHANGELOG.md`.
- **Guardas de argumento.** `--days` e `--as-of` do `stale` usam `_require_value` no mesmo `case`, como exige o `w257 [E]`.
