# Onda F — consolidação, schema e varreduras

Especificação implementável. Insumo: `docs/plans/2026-09-07-backlog-zero.md`, seções "Invariantes", "Método de prova" e "Onda F". Fecha LDG-0152, LDG-0151, LDG-0161, LDG-0171, LDG-0164 e LDG-0176.

Data das medições: 2026-09-07. Árvore: `/Users/milton/Documents/projects/forge-harness`, branch `develop`, commit `3bb67f5`. Rigor reduzido por decisão do dono — três rodadas de revisão em vez de cinco. Isso não afrouxa invariante nenhuma; significa que os defeitos das quatro especificações anteriores precisam ser evitados no primeiro rascunho, e não corrigidos na quarta rodada.

Todo número deste documento veio de um comando executado nesta sessão, e a saída está colada ao lado. Onde eu não executei, digo em letra que não executei e o que impediu. Onde a especificação declara propriedade em vez de comando, é por aplicação deliberada da invariante 19 — o implementador escolhe o primitivo e prova que ele discrimina.

Nenhum gate da suíte foi executado na produção desta especificação: gate manual concorrente com `npm test` produz falha fantasma em gate alheio (`feedback-suite-sem-concorrencia`). As reproduções abaixo montam bancadas em `$TMPDIR` que extraem blocos dos arquivos de produção por `sed`, ou copiam `template/.forge` inteiro para um `git init` efêmero, sem editar um byte de arquivo rastreado. As exceções, todas nomeadas e todas somente-leitura sobre a árvore real: `check-suite-wiring.sh` invocado duas vezes (§5.1), porque a divergência que ele expõe é o defeito de LDG-0171; `node tools/validate-forge.mjs` uma vez (§13); e `lib/graph-build.mjs`, executado contra cópias em `$TMPDIR`, nunca contra `.forge/graph/` da árvore real (§7.1). O `pre-push` de produção foi executado contra bancadas em `$TMPDIR` (§2.5), nunca contra esta árvore.

**Onde eu NÃO executei, e a previsão é de leitura.** As cores previstas para `w135`, `w97`, `w151`, `w13`, `w20`, `w190`, `w191`, `w192`, `w199`, `w200`, `w204` e `plugin-sync-gate` sob o confinamento vêm de **leitura das fixtures e das asserções**, mais o contrafactual dos leitores isolados em bancada — não de execução dos gates. A única previsão de cor confirmada por execução de ponta a ponta é a do `w147[4]`, cujo controle e contrafactual eu rodei nos dois estados pelo canal real do hook (§2.5). O implementador roda os demais; a especificação diz o que espera e por quê, e distingue as duas coisas em letra.

---

## 1. O eixo comum: seis itens, três perguntas

A onda não é uma lista de faxinas. Os seis itens respondem a três perguntas que o harness faz a si mesmo e hoje responde de forma inconsistente.

**Quem tem o direito de dizer o que o `FORGE.md` declara?** LDG-0152 (leitores duplicados), LDG-0151 (chaves declaradas sem leitor) e LDG-0161 (dois arquivos, nenhum gerando o outro) são três faces do mesmo contrato. O harness tem um leitor canônico do frontmatter em JavaScript, quatro reimplementações em bash e nenhum gate que confira se as reimplementações concordam. A regra de extração é **herdada**, nunca reinventada — foi essa a lição que quase publicou uma allowlist envenenada no perfil strix, e `pentest-ops.sh:329-338` já a escreve em letra.

**Onde é a raiz?** LDG-0171. O padrão `SCRIPT_DIR/../..` responde certo no layout instalado e errado no layout de dogfood, e responde os dois em silêncio.

**A prova de mutação prova alguma coisa?** LDG-0164 e LDG-0176 são o mesmo cuidado em escalas diferentes: uma mutação que muda bytes sem mudar decisão, e um artefato gerado que ninguém confere contra o gerador.

O que junta os seis num PR só é a bancada: todos se medem lendo a árvore e comparando duas leituras da mesma coisa. Separá-los produziria quatro branches disputando os mesmos arquivos (`pre-push`, `FORGE.md`, `tests/`), que é exatamente o pedágio que LDG-0167 e LDG-0173 cobraram.

---

## 2. LDG-0152 — o leitor do `FORGE.md`

### 2.1 O que o item afirma, e o que a varredura mostra

O registro diz: *"o mesmo awk de leitura de campo escalar do bloco `runtime:` existe em `template/.forge/hooks/git/pre-push`, em `handoff-gen.sh:42` e como idioma declarado em `hooks/session/on-session-start.sh:11`"*. Duas das três afirmações procedem, a terceira **não procede**, e há **quatro** leitores BASH que o item não menciona (a conta é sobre o subconjunto bash da tabela abaixo; contando os sítios JavaScript são mais).

**O predicado do censo, definido em letra antes do número.** Um *leitor bash do bloco `runtime:`* é um autômato `awk` embarcado em arquivo de `template/`, `bin/`, `installer/`, `tools/` ou `lib/` que contém uma regra cujo padrão ancora em `^runtime:` — é isso, e não o nome da função nem o arquivo, que define o universo. O comando que o materializa:

```
$ grep -rnE '^[[:space:]]*/\^runtime:' template/ bin/ installer/ tools/ lib/
template/.forge/hooks/git/pre-push:186:    /^runtime:/ { inblk=1; next }
template/.forge/hooks/git/pre-push:352:    /^runtime:/ { inblk=1; next }
template/.forge/hooks/git/pre-push:363:    /^runtime:/ { inblk=1; next }
template/.forge/scripts/pentest-ops.sh:59:    /^runtime:[[:space:]]*$/ { inrt=1; next }
template/.forge/scripts/pentest-ops.sh:353:    /^runtime:[[:space:]]*(#.*)?$/ { inrt=1; next }
template/.forge/scripts/pentest-ops.sh:380:    /^runtime:[[:space:]]*(#.*)?$/ { inrt=1; next }
template/.forge/scripts/pentest-ops.sh:405:    /^runtime:[[:space:]]*(#.*)?$/ { inrt=1; next }
template/.forge/scripts/handoff-gen.sh:45:    /^runtime:/ { inblk=1; next }
template/.forge/scripts/lib/forge-runtime.sh:26:    /^runtime:/ { inb=1; next }
```

**Nove autômatos em quatro arquivos** — testemunha de data de 2026-09-07, jamais critério de gate; o critério está em §8.1, cenários `[1]` e `[3]`. A tabela abaixo os nomeia, e os sítios JavaScript vêm de `grep -rn -- '\^---\\n' --include='*.mjs'`:

| # | Sítio | O que lê | Confinado ao frontmatter? | Terminador do bloco |
|---|---|---|---|---|
| 1 | `hooks/git/pre-push:184` `fm_field` | escalar de `runtime:` | **não** | `/^[a-z_]+:/` |
| 2 | `scripts/handoff-gen.sh:42` `fm_field` | escalar de `runtime:` | **não** | `/^[a-z_]+:/` |
| 3 | `scripts/lib/forge-runtime.sh:22` `forge_get_runtime` | escalar de `runtime:` | **não** | `/^[^ ]/` |
| 4 | `hooks/git/pre-push:351` `gates_key_present` | presença de `  gates:` | **não** | `/^[a-z_]+:/` |
| 5 | `hooks/git/pre-push:362` `gates_inline_raw` | valor inline de `  gates:` | **não** | `/^[a-z_]+:/` |
| 6 | `scripts/pentest-ops.sh:54` `pentest_cfg` (awk em `:59`) | escalar de `runtime.pentest` | **não**, por decisão escrita | reset por chave de topo |
| 7 | `scripts/pentest-ops.sh:349` `pentest_cfg_strix` (awk em `:353`) | escalar de `runtime.pentest.strix` | **sim**, via `pentest_frontmatter_of:339` | reset por chave de topo |
| 7b | `scripts/pentest-ops.sh:376` `pentest_cfg_strix_list` (awk em `:380`) | lista de `runtime.pentest.strix` | **sim**, mesmo extrator | reset por chave de topo |
| 7c | `scripts/pentest-ops.sh:398` `has_pentest_strix_config` (awk em `:405`) | presença do bloco `strix:` | **sim**, mesmo extrator | reset por chave de topo |
| 8 | `scripts/lib/gate-phase.mjs:42` `frontmatterOf` | o frontmatter inteiro | **sim** | `/^---\n([\s\S]*?)\n---/` |
| 9 | `tools/validate-forge.mjs:39` | o frontmatter inteiro | **sim** | mesma regex |
| 10 | `scripts/lib/sync-adapters.mjs:74` `fmExtract` | `<top>.<sub>` do frontmatter | **sim** | mesma regex |
| 11 | `scripts/lib/graph-layers.mjs:109` `readForgeFrontmatter` | o frontmatter inteiro | **sim** | mesma regex |

**A terceira afirmação do item não procede, e a refutação é medida.** `hooks/session/on-session-start.sh:11-20` não contém uma cópia de `fm_field`: contém `_yaml_auto`, que lê **`.forge/forge.yaml`**, não o `FORGE.md`, e procura `auto: true|false` sob uma chave de topo, não um escalar sob `runtime:`. O único elo é um comentário na linha 11 dizendo *"same idiom as fm_field in handoff-gen.sh"*. E confinar `_yaml_auto` ao frontmatter seria destruí-lo: executado nesta rodada, `grep -c '^---$' template/.forge/forge.yaml` devolve **0** e `grep -cE '^[a-z_]+:' template/.forge/forge.yaml` devolve **15** — o `forge.yaml` não tem frontmatter porque é YAML inteiro, e um leitor confinado devolveria vazio para todas as quinze chaves. O sítio 3 de LDG-0152 é, portanto, um comentário errado, e a correção lá é textual.

### 2.2 O defeito reproduzido — os leitores bash leem a PROSA

Bancada em `$TMPDIR/f-fm`, montada por `{ echo 'FORGE_MD="$1"'; sed -n '184,190p' template/.forge/hooks/git/pre-push; echo 'echo "fm_field test = [$(fm_field test)]"'; } > hoje.sh && bash hoje.sh <fixture>` — o corpo real de `fm_field` extraído por `sed`, sem editar produção. O `FORGE.md` da bancada tem frontmatter **sem** bloco `runtime:` e, no corpo, um exemplo de documentação dentro de uma cerca ```` ```yaml ````:

```
fm_field test = [echo "ISTO E APENAS UM EXEMPLO DA DOC"]
fm_field gates = [check-exemplo]
--- leitor canônico (gate-phase.mjs) sobre o mesmo arquivo:
gateEntries = []
frontmatter contém runtime?  false
```

O leitor canônico devolve lista vazia e diz que o frontmatter não tem `runtime:`. Os leitores bash devolvem o comando de um exemplo de documentação como se fosse a suíte declarada do projeto. É a mesma classe do R2 do perfil strix — um leitor novo de um arquivo com leitor canônico reinventando a regra de extração — com a diferença de que ali o dano era ampliar uma allowlist e aqui é `run_check "test" "$(fm_field test)"` executar o que estiver escrito na prosa.

### 2.3 Os leitores bash não são o mesmo leitor — eles divergem entre si

Segunda bancada, mesma metodologia, os três corpos extraídos por `sed -n '184,190p'` do `pre-push`, `sed -n '42,49p'` do `handoff-gen.sh` e `sed -n '22,30p'` do `lib/forge-runtime.sh`. Quatro entradas, cada uma com a saída dos três:

```
--- CASO 1: runtime SEM test; bloco seguinte com hífen no nome tem test
  pre-push fm_field(test)      = [VAZOU DO BLOCO SEGUINTE]
  handoff-gen fm_field(test)   = [VAZOU DO BLOCO SEGUINTE]
  forge_get_runtime(test)      = []
--- CASO 2: runtime SEM test; linha de topo iniciada por '#' e depois um bloco com test
  pre-push fm_field(test)      = []
  handoff-gen fm_field(test)   = []
  forge_get_runtime(test)      = []
--- CASO 3: bloco runtime só na PROSA (fora do frontmatter), em cerca de código
  pre-push fm_field(test)      = [COMANDO DE EXEMPLO DA DOC]
  handoff-gen fm_field(test)   = [COMANDO DE EXEMPLO DA DOC]
  forge_get_runtime(test)      = [COMANDO DE EXEMPLO DA DOC]
--- CASO 4: chave repetida — runtime no frontmatter e um segundo runtime na prosa
  pre-push fm_field(test)      = [npm test]
  handoff-gen fm_field(test)   = [npm test]
  forge_get_runtime(test)      = [npm test]
```

O CASO 1 é a divergência: um bloco de topo cujo nome tem hífen (`x-vendor:`) não casa `/^[a-z_]+:/`, então os dois `fm_field` **atravessam a fronteira do bloco** e leem a chave do bloco seguinte; `forge_get_runtime`, que termina em `/^[^ ]/`, para corretamente. Os dois `fm_field` são byte a byte iguais entre si — `diff` das duas extrações devolve só a linha de comentário do `pre-push` e a guarda `[ -f "$FORGE_MD" ]` do `handoff-gen` —, mas nenhum dos dois é igual ao terceiro. "Três cópias do mesmo awk" é falso: são **duas cópias de um awk e uma implementação diferente com o mesmo nome de contrato.**

### 2.4 Decisão 1 — a regra de extração é UMA e é a do leitor canônico: confinada ao frontmatter

O harness já tem a regra escrita em quatro sítios JavaScript e num sítio bash. **Os quatro sítios JavaScript são byte a byte a MESMA regex, e isso é medido:**

```
$ grep -rho 'match(/\^---.*)' template/.forge/scripts/lib/gate-phase.mjs tools/validate-forge.mjs \
    template/.forge/scripts/lib/sync-adapters.mjs template/.forge/scripts/lib/graph-layers.mjs \
  | sed 's/;$//' | sort -u
match(/^---\n([\s\S]*?)\n---/)
```

Uma forma só, nas linhas 43, 39, 75 e 113 respectivamente. **O sítio bash não é a mesma regra, e a divergência foi medida.** `pentest_frontmatter_of:339` fecha o frontmatter em `$0 == "---"` (linha exatamente igual); a regex canônica fecha em `\n---`, isto é, em qualquer linha que **comece** por `---`. Num documento cujo corpo tem uma linha `----` — separador horizontal legítimo em markdown — os dois discordam:

```
documento: ---\nforge_version: 1\n----\nruntime:\n  test: DA-PROSA\n---
  JS (regex canônica)                      corpo=["forge_version: 1"]
  bash pentest_frontmatter_of              corpo=[forge_version: 1|----|runtime:|  test: DA-PROSA|]
  fm_field(test) sobre o corpo do bash   = [DA-PROSA]
```

Herdar `pentest_frontmatter_of` seria, portanto, **reinventar a regra pela sexta vez**, com uma divergência própria. Um extrator awk que fecha em `/^---/` (prefixo, não igualdade) reproduz a regra canônica nos dois casos adversariais:

```
$ awk 'NR==1 { if ($0 ~ /^---$/) { infm=1; next } else { exit } } infm && /^---/ { exit } infm { print }'
  caso "runtime no frontmatter"  JS=[forge_version: 1|runtime:|  test: DO-FRONTMATTER|]  bash=[idem]
  caso "----  no corpo"          JS=[forge_version: 1|]                                  bash=[idem]
```

**A regra herdada é essa**, e a §8.1 `[4]` a prende por execução diferencial contra o leitor canônico — o gate não confia neste parágrafo, ele remede. Os **seis** sítios bash não confinados da tabela de §2.1 (linhas 1 a 6) passam a herdá-la; cinco a implementam, e o sexto (`pentest_cfg`) é a isenção declarada de §2.6.

**Alternativa descartada: unificar os awk sem confinar.** Fecharia a divergência do CASO 1 e deixaria aberto o CASO 3, que é o caso com dano. Um harness em que os leitores concordam sobre a leitura errada é pior do que um em que discordam, porque a concordância compra confiança.

**Retrocompatibilidade, medida no ecossistema inteiro antes da decisão.** Varredura somente-leitura (`for d in ~/Documents/projects/*/.forge/FORGE.md; do grep -n '^---$\|^runtime:' "$d"; done`) dos treze `.forge/FORGE.md` sob `~/Documents/projects` (`agent-smith`, `axis-fare-validator`, `axis-go-cloud`, `Axis.AcqSimulator`, `Axis.PadSimulator`, `azim-crm`, `collatra`, `cpf-cnpj-validator`, `docuseal`, `forge-harness`, `forge-test`, `lionclaw`, `payments`): **todos os treze abrem com frontmatter**, o delimitador de fechamento está entre as linhas 33 e 115, e **toda** ocorrência de `^runtime:` está na linha 17 ou 18 — dentro do frontmatter, em todos. Zero árvores do campo têm `runtime:` fora do frontmatter. O `forge-harness` é o único sem bloco `runtime:` algum, e é o dogfood, que a Fase 1 vai preencher. O confinamento é, portanto, um no-op no ecossistema medido.

**E ele alinha o bash com o que o resto do harness já faz.** `tools/validate-forge.mjs:40` **reprova** um `FORGE.md` sem frontmatter (`FAIL FORGE.md has no YAML frontmatter`); `sync-adapters.mjs:75` e `graph-layers.mjs:113` devolvem `{}`. Um `FORGE.md` sem frontmatter já é um documento que metade do harness recusa a ler; o bash era a metade que lia mesmo assim.

### 2.5 Decisão 2 — o confinamento tem colateral MEDIDO em quatro gates rastreados, e eles entram no mesmo PR

Esta é a invariante 15 aplicada antes de propor, e ela mordeu duas vezes — a segunda porque o **predicado da primeira varredura estava errado**.

**O predicado errado, e por que ele errava.** A primeira varredura perguntou *"que fixture de `FORGE.md` em `tests/` não tem delimitador `---`?"* e achou quatro. O predicado correto é *"que fixture de `FORGE.md` em `tests/` tem um bloco `runtime:` FORA do frontmatter?"* — e ele é estritamente mais largo, porque inclui a fixture que tem frontmatter bem formado e escreve o `runtime:` **depois** do `---` de fechamento. Essa fixture existe, é `tests/w147-hook-delegation-gate.sh:83`, e a varredura antiga passou ao largo dela.

Varredura com o predicado certo — `for f in tests/*.sh; do grep -q 'FORGE\.md' "$f" && grep -q 'runtime:' "$f" && echo "$f"; done`, seguida de inspeção de cada sítio, que é o passo que decide se o `runtime:` está dentro ou fora do frontmatter:

```
tests/w131:182  tests/w135:35   tests/w142:63,81  tests/w147:83   tests/w151:924,1186
tests/w171:69   tests/w190:72   tests/w191:68     tests/w199:90   tests/w20:144
tests/w206:283,301,…            tests/w97:34
```

Destes, têm frontmatter bem formado **com** o `runtime:` dentro — logo, indiferentes ao confinamento: `w131`, `w142`, `w171`, `w190`, `w191`, `w199`, `w20`, `w206`. As fixtures de `w142` e `w206` alimentam `pentest-ops.sh`, cujo `pentest_cfg` a onda **não** confina (§2.6), e nenhum dos dois invoca o `pre-push` (`grep -c 'pre-push'` devolve `0` nos dois). Sobram **cinco** sítios em **quatro** gates.

Contrafactual executado campo a campo, com os leitores de hoje e os mesmos leitores precedidos do extrator de §2.4, os dois sobre as fixtures literais de produção:

```
== fixture w135:35 (SEM frontmatter)
  hoje      typecheck=[echo TYPECHECK-RAN] test=[echo TEST-RAN] gates_key=[y]
  confinado typecheck=[]                   test=[]              gates_key=[]
== fixture w97:34 (SEM frontmatter)
  hoje      typecheck=[pnpm typecheck]     test=[]              gates_key=[]
  confinado typecheck=[]                   test=[]              gates_key=[]
== fixture w151:924 e :1186 (SEM frontmatter)
  hoje      typecheck=[] test=[sh -c 'echo CARGA-EXECUTOU >> "$MARK"'] gates_key=[]
  confinado typecheck=[] test=[]                                        gates_key=[]
== fixture w152:696 (SEM frontmatter e SEM runtime:)
  hoje      typecheck=[] test=[] gates_key=[]      confinado idem — não muda de cor
```

E, para o quinto sítio, o contrafactual pelo **canal real**, não pelo leitor: bancada em `$TMPDIR` com `cp -R template/.forge` num `git init`, a fixture literal do `w147[4]`, e o `pre-push` de produção contra uma cópia dele com o extrator injetado imediatamente antes de `fm_field`:

```
== fixture w147:83 (COM frontmatter; bloco runtime: no CORPO)
  hoje      rc=1  "pre-push BLOQUEADO: gate 'gate-fantasma' declarado em runtime.gates e …/gate-fantasma.sh não existe."
  confinado rc=0  "pre-push OK"  — e a saída NÃO contém a string 'gate-fantasma'
```

Este é o colateral que importa, e ele é o pior de todos: `gates_key_present` vai a vazio, o bloco inteiro de `runtime.gates` é pulado, e um gate declarado e inexistente **deixa de bloquear o push, em silêncio**. É exatamente a classe que a onda existe para combater, produzida pela onda. O `w147[4]` exige rc≠0 **e** o nome do gate na saída, então ele vai a vermelho — e a correção da fixture não é acrescentar `---` (ela já os tem), é **mover o bloco `runtime:` para dentro do frontmatter**.

| Gate | Fixture | Asserções que morrem | Correção no mesmo PR |
|---|---|---|---|
| `tests/w135-push-refs-export-gate.sh` | linha 35, `cat > FORGE.md` sem `---` | `[1]` linha 99 (`o gate declarado em runtime.gates não chegou a rodar`) e `[3]` linhas 149, 150 e 152 (`typecheck OK`, `test OK`, gate de `runtime.gates`) | acrescentar `---` de abertura e fechamento à fixture |
| `tests/w97-hook-portability-gate.sh` | linha 34, idem | `[3]` linha 44: `grep -q 'typecheck PULADO'` | idem |
| `tests/w151-heavy-mutex-gate.sh` | linhas 924 e 1186, `printf 'runtime:\n  test: …'` sem `---` | `[37]` linha 1196: `grep -q "CARGA-EXECUTOU" "$MARK37"` | idem, nas duas |
| `tests/w147-hook-delegation-gate.sh` | linha 83, frontmatter PRESENTE e `runtime:` no corpo | `[4]` linhas 87-96: exige rc≠0 e `gate-fantasma` na saída | **mover** o bloco `runtime:` para dentro do frontmatter — acrescentar `---` não resolve |

`tests/w152-push-ahead-gate.sh:696` escreve `printf '# FORGE.md (fixture minimal…)\n'` — sem frontmatter **e** sem bloco `runtime:`. Sob confinamento ele continua devolvendo vazio, como hoje; não muda de cor e não precisa de edição. Registro porque a varredura o encontra e um revisor que só olhasse o predicado "fixture sem `---`" acharia que faltou um.

Dois dos quatro nomes — `w135`, `w97` — estão literalmente na lista de quatro gates que uma onda desta rodada quase deixou vermelhos por trocar vocabulário sem varrer. A varredura foi feita duas vezes, com dois predicados, e a segunda achou o `w147`. A edição das **cinco** fixtures, nos **quatro** gates, entra na definição de pronto, nominalmente — e o `w147` está lá pelo nome, porque foi a omissão dele que reprovou a revisão 1.

### 2.6 Decisão 3 — o `pre-push` NÃO delega `typecheck`/`test` a lib nenhuma

Medido: `run_check "typecheck" "$(fm_field typecheck)"` e `run_check "test" "$(fm_field test)"` estão nas linhas 324-325 do `pre-push`; o `source` de `lib/forge-runtime.sh` está na linha 369 e é **condicional** a `gates_key_present` ser não-vazio (linha 370). Mover `fm_field` para um lib exigiria sourcear esse lib incondicionalmente e antes da linha 324, e criaria uma dependência nova de um arquivo que pode não existir no checkout: `core.hooksPath` é absoluto e compartilhado por todos os worktrees, mas `.forge/scripts/` é conteúdo próprio de cada um (issues #41, #73, #81, e o comentário de `w168:122-125` escreve o motivo). Hoje uma worktree sem `.forge/scripts/` ainda roda typecheck e test; com a delegação, ou o hook bloqueia (desproporcional para typecheck) ou degrada em silêncio (que é o defeito da onda D).

**Decisão fechada:** os cinco sítios bash passam a implementar a **mesma regra**, provada por execução diferencial num gate, e não a compartilhar o **mesmo arquivo**. Concretamente:

- `handoff-gen.sh` **perde** o seu `fm_field` e passa a chamar `forge_get_runtime` de `lib/forge-runtime.sh` — é um script em `.forge/scripts/`, irmão de `lib/`. Essa é a consolidação de código que LDG-0152 pede, e ela cabe onde não custa contrato **desde que a ausência do lib seja tratada, e ela não é hoje**. A guarda existente, `[ -f "$FORGE_MD" ] || { echo ""; return; }` (`handoff-gen.sh:43`), é sobre o **`FORGE.md`** ausente, não sobre o **lib** ausente; confundir as duas seria trocar um leitor duplicado por uma recusa nova. Medido: `handoff-gen.sh:10` é `set -euo pipefail`, e um `source` incondicional de um lib inexistente sob `set -e` mata o script:

  ```
  bancada em $TMPDIR, script mínimo com `set -euo pipefail` e `. "$ROOT/.forge/scripts/lib/forge-runtime.sh"`:
    lib ausente, source INCONDICIONAL   → rc=1, "No such file or directory", não chega ao fim
    lib ausente, source com guarda + stub → rc=0, "test=[]", chega ao fim
  ```

  O lib existe desde a 0.11.0; todo consumidor anterior a ela cai no primeiro caminho. **A propriedade que a onda declara**, e que o gate A `[6b]` prova: *o gerador de handoff termina com rc 0 e os campos de runtime em `n/d` quando `lib/forge-runtime.sh` não existe no checkout.* O implementador escolhe o primitivo (guarda `[ -f ]` com stub local, `command -v` sobre a função depois do source condicional, ou outro) e prova que ele discrimina — invariante 19.
- `pre-push` mantém `fm_field`, `gates_key_present` e `gates_inline_raw` **no próprio arquivo**, com a extração confinada, pelo motivo medido acima.
- `forge_get_runtime` passa a confinar.
- `pentest_cfg` **não muda** — a assimetria já está decidida e escrita em `pentest-ops.sh:333-338`, com a justificativa de retrocompatibilidade de quem tem o bloco `pentest:` fora de frontmatter formal. Reverter uma decisão registrada exige medição própria, e esta onda não a faz; ela **declara a exceção** no gate, com o motivo, no formato de isenção auditável do harness.

**Alternativa descartada: um `lib/forge-frontmatter.sh` novo, sourceado por todos.** Descartada por três medições. (a) O `pre-push` não pode depender dele (acima). (b) Um lib novo em `.forge/scripts/lib/` obriga a mais uma guarda "diretório existe e arquivo não ⇒ BLOQUEADO" no padrão de `pre-push:232-234` e `:383`, o que transforma um item P3 de consolidação numa mudança de contrato de push para todo adotante que ainda não rodou `forge update`. (c) O ganho seria nulo sobre a decisão adotada: a propriedade que importa é a **concordância**, e a concordância é assertável sem compartilhar arquivo — enquanto compartilhar arquivo **não** garante concordância (`pentest_cfg` e `pentest_cfg_strix` estão no mesmo arquivo e discordam por decisão).

### 2.7 Decisão 4 — o confinamento não pode criar um caminho de silêncio verde

Medido: `pre-push:206` é `[ -n "$cmd" ] || { echo "pre-push: $label não definido — skip"; return 0; }`. Um `FORGE.md` que perdesse os delimitadores passaria, sob confinamento, de "roda a suíte" para "skip", sem nada dizer. É o falso-verde que a onda D combate, e seria criado por esta.

**Decisão fechada, e o predicado da guarda é o que segue — não "o arquivo não tem frontmatter".** O predicado ingênuo ("existe e não tem frontmatter") **não cobre o caso motivador da onda**: o CASO 3 de §2.2/§2.3 e a fixture do `w147:83` têm frontmatter **presente** e o bloco `runtime:` no corpo, e é justamente aí que a leitura de hoje pega a prosa e a leitura confinada vai a vazio. Medido: com a fixture do `w147[4]`, o `pre-push` confinado imprime `typecheck não definido — skip` e `test não definido — skip` e sai `pre-push OK` — o silêncio verde que esta seção existe para impedir, criado pela guarda errada.

O predicado é: **existe no arquivo uma linha `^runtime:` fora do frontmatter, e o frontmatter não contém `^runtime:`.** Ele dispara nos dois casos — arquivo sem frontmatter (todo o arquivo é "fora do frontmatter") e frontmatter presente com o bloco no corpo — e não dispara quando o bloco está no lugar certo, nem quando não há bloco nenhum. Quando ele dispara, o `pre-push` emite uma linha nomeando que o bloco `runtime:` foi encontrado fora do frontmatter e por isso não foi lido, antes das duas chamadas de `run_check`. A onda **não** inventa vocabulário: se `lib/gate-verdict.sh` da onda D já estiver na árvore, a linha é um `INCONCLUSIVO` emitido por `forge_verdict_say` com capacidade declarada; se a onda D ainda não tiver aterrissado, a linha é impressa pelo próprio hook, com a mesma forma, e migra no PR da onda D. A ordem do plano-mestre põe D antes de F, então o caminho esperado é o primeiro; o segundo existe para que F não fique bloqueada por D.

**A propriedade, e não o comando:** a linha tem de ser distinguível por `grep` de "campo não declarado" e de "campo declarado e vazio", que são estados legítimos e frequentes (`templates/FORGE.md` entrega `test:` vazio de fábrica, e `w192[4d]` depende disso). O implementador escolhe o texto e prova a distinção com os três casos.

**Varredura de invariante 15 para essa linha nova.** `grep -rn 'não definido — skip' tests/` devolve zero, e nenhum gate compara a saída do `pre-push` byte a byte contra golden: os goldens do repositório são de `run-gates.sh` (`tests/fixtures/w171/`) e do grafo (`tests/fixtures/codegraph-layer-map/`), e as asserções sobre a saída do `pre-push` em `w152`, `w160`, `w168` e `w190` são todas `grep -q`. Uma linha informativa a mais não derruba nenhuma delas.

---

## 3. LDG-0151 — as seis chaves que prometem default

### 3.1 O defeito confirmado, e o contexto que o item não tinha

Varredura executada nesta rodada, chave a chave, sobre `template/`, `bin/`, `installer/`, `tools/` e `lib/`, com `--include='*.sh' --include='*.mjs' --include='*.js' --include='*.json'`: `sdd.default_mode`, `sdd.default_rigor`, `sdd.default_scale`, `sdd.archive_policy`, `sdd.human_gate_required` e `quality.evals_root` aparecem **exclusivamente** em `template/.forge/schemas/forge.schema.json`, nos dois `FORGE.md` do template, em `template/.forge/forge.yaml` (só `evals_root`), em `tests/w20-spec-gate.sh:139-143` (uma fixture) e em documentação. Nenhum leitor. O item procede.

Três medições que o item não traz e que mudam a decisão:

**(a) O `forge.schema.json` não é lido por nada que o adotante execute.** `grep -rn 'forge.schema.json' template/ bin/ tools/ installer/ package.json .github/` devolve exatamente duas linhas: o `$id` dentro do próprio arquivo e `tools/validate-forge.mjs:18`. E `tools/` **não vai no pacote npm** — `package.json` declara `files: ["bin/","template/","installer/gitignore.patch","installer/gitattributes.patch","installer/install.sh","installer/removed-files.txt","CHANGELOG.md"]`. O schema viaja para todo consumidor e nenhum código do consumidor o compila. O cabeçalho de `validate-forge.mjs` diz o escopo em letra: valida `template/.forge/forge.yaml` e `template/.forge/FORGE.md`, os dois arquivos do próprio template.

**(b) O schema já não descreve o campo — remedido nesta rodada com `ajv`, não citado de segunda mão.** O cabeçalho de `tests/w199-schema-reader-parity-gate.sh:17-23` afirma que cinco dos treze `FORGE.md` já reprovam contra `forgeFrontmatter`. Compilei `$defs.forgeFrontmatter` com `ajv` (dependência de desenvolvimento já presente) e validei o frontmatter de cada um dos treze:

```
REPROVA Axis.AcqSimulator :: /runtime must NOT have additional properties
REPROVA Axis.PadSimulator :: /runtime must NOT have additional properties
REPROVA axis-fare-validator :: /runtime must NOT have additional properties
REPROVA axis-go-cloud :: /runtime must NOT have additional properties
REPROVA forge-harness :: must have required property 'project' | 'sdd' | 'runtime'
PASSA   agent-smith, azim-crm, collatra, cpf-cnpj-validator, docuseal, forge-test, lionclaw, payments
--- 13 documentos; 5 reprovam; 0 por 'gates'
```

Cinco de treze, nenhum por `gates` — a citação procede, agora por medição própria. Um DoD escrito como "estes documentos passam a validar" seria falso pela raiz.

**(c) Duas das seis têm gêmea hard-coded com o valor idêntico.** Medido: `sed -n '21p'` de `template/.forge/scripts/spec-new.sh` é `ID="${1:-}"; shift || true` e `sed -n '22p'` é `TYPE=""; SCALE="2"; RIGOR="spec-anchored"; MODE=""; OWNER=""; FROM_LEDGER=""` — a linha dos defaults é a **22**, e é ela que as citações de `spec-new.sh:22` neste documento endereçam. O `2` e o `spec-anchored` são exatamente os valores que `FORGE.md` declara em `sdd.default_scale` e `sdd.default_rigor`. O default existe, funciona e está no lugar errado.

### 3.2 A restrição de contrato que decide quase tudo — medida

`template/.forge/schemas/forge.schema.json`, `$defs.forgeFrontmatter.properties.sdd`, tem `additionalProperties: false` e `required: ["default_mode","default_rigor","default_scale","archive_policy","human_gate_required"]`. O mesmo `additionalProperties: false` vale em `$defs.forgeManifest`, onde mora `quality.evals_root`.

Consequência: **remover uma dessas chaves de `properties` não a torna ignorada — torna todo documento que a declara inválido**, porque `additionalProperties: false` passa a rejeitá-la. E os treze `FORGE.md` do ecossistema a declaram. Isso separa este item de LDG-0008: lá, `require_human_approval_before_archive` foi **removida** de `forge.yaml` e do schema (é o que `w192[3]`, linhas 106-109, assere), e isso foi seguro porque o valor era um interruptor de enforcement duplicado e a chave nunca fora obrigatória. Aqui a remoção tem custo em toda árvore instalada, mesmo que hoje ninguém valide — no dia em que alguém validar, valida contra um schema que reprova o arquivo que o próprio harness entregou.

### 3.3 Decisão por chave — fechadas

| Chave | Decisão | Por quê, com a medição |
|---|---|---|
| `sdd.default_scale` | **FIAR** em `spec-new.sh` | O default já existe hard-coded em `spec-new.sh:22` com o valor idêntico (`SCALE="2"`). Fiar é trocar o literal por uma leitura com fallback ao mesmo literal: zero mudança de comportamento no valor de fábrica, e a chave passa a decidir. |
| `sdd.default_rigor` | **FIAR** em `spec-new.sh` | Idem, `RIGOR="spec-anchored"`. |
| `sdd.default_mode` | **FIAR como degrau da escada, com recusa nomeada para valor não mapeável** | `spec-new.sh:42-50` já resolve `MODE` por uma escada: explícito > derivado do `--type` > heurística de repositório (`product/current` ou `docs/product` existem ⇒ brownfield, senão greenfield). A chave entra **entre** a derivação por tipo e a heurística. Mas o vocabulário do schema e o do script **não coincidem**, e isso decide o desenho: ver §3.4, que é onde a colisão está medida. |
| `sdd.archive_policy` | **FIAR** em `lib/validate-archive.mjs` | O enum tem **dois** valores (`after_verified_implementation`, `manual_override`), então não é o restatement de um invariante: `manual_override` é um segundo comportamento prometido e inexistente. Fiar como a chave que decide se o pré-flight exige o estado `verified` ou aceita a passagem declarada, no mesmo formato de dispensa anunciada que `w192[5]` já exige (`grep -qi "dispensa"` na saída). |
| `sdd.human_gate_required` | **DEPRECAR no lugar, não remover** | Precedente direto e medido: `w192[3]` decidiu que `require_human_approval_before_archive` não devia ser fiada porque *"a capacidade existe e funciona sob outro nome"* — `gates.human_archive_approval`, exigido por `validate-archive.mjs:154-155` e escrito por `approval-log.sh`. Aqui é a mesma chave sob um terceiro nome. Mas ela é `required` num schema com `additionalProperties: false` (§3.2), então a remoção quebraria os treze documentos do campo. **Fica onde está, com o comentário ao lado apontando o gate real**, e o gate da onda a assere como deprecada declarada, não como leitor ausente. |
| `quality.evals_root` | **FIAR** onde a raiz de evals é resolvida | `template/.forge/forge.yaml:25` declara `evals_root: .forge/evals`; o valor não é `required`, mas remover ainda esbarra em `additionalProperties: false`. Fiar é barato e a chave passa a valer. |

### 3.4 A decisão que sobra: os DOIS vocabulários de `sdd.default_mode`, e o valor de fábrica

**A colisão, medida antes de qualquer decisão.** O enum do schema e o conjunto que `spec-new.sh` aceita não são o mesmo conjunto:

```
$ node -e 'const s=require("./template/.forge/schemas/forge.schema.json");
           console.log(JSON.stringify(s.$defs.forgeFrontmatter.properties.sdd.properties.default_mode))'
{"enum":["greenfield","brownfield","feature","bugfix","refactor"]}

$ sed -n '50p' template/.forge/scripts/spec-new.sh
case "$MODE" in greenfield|brownfield|feature-only) ;; *) echo "FAIL (--mode invalid: $MODE)"; exit 2 ;; esac
```

Os seis valores, executados contra o script real numa bancada em `$TMPDIR` (`FORGE_ROOT=$B bash …/spec-new.sh chg-<v> --type feature --mode <v>`):

```
greenfield   rc=0  OK .forge/specs/active/chg-greenfield
brownfield   rc=0  OK .forge/specs/active/chg-brownfield
feature      rc=2  FAIL (--mode invalid: feature)
bugfix       rc=2  FAIL (--mode invalid: bugfix)
refactor     rc=2  FAIL (--mode invalid: refactor)
feature-only rc=0  OK .forge/specs/active/chg-feature-only
```

**Três dos cinco valores que o schema abençoa fazem o script recusar com exit 2, e um valor que o script aceita não existe no schema.** E o `FORGE.md` que o harness distribui **documenta os cinco na margem**: `template/.forge/FORGE.md:12` é `default_mode: brownfield          # greenfield | brownfield | feature | bugfix | refactor`. O diagnóstico cabe numa frase: o enum do schema é, valor por valor, o conjunto de `--type` (`feature|bugfix|refactor|greenfield|brownfield`, `spec-new.sh:37`), não o de `--mode`. Alguém copiou o vocabulário errado, e a chave nunca foi fiada, então ninguém notou.

**Por que fiar sem resolver isso seria pior do que não fiar.** Com a chave acima da heurística, um projeto que declare `default_mode: feature` — declaração **válida** pelo schema que o harness distribui, e sugerida pelo comentário que o harness entrega — passa a não conseguir criar change nenhum sem `--mode` explícito. A fiação transformaria uma decoração inofensiva numa recusa.

**Decisão fechada, em três partes, cada uma com a sua medição.**

**(i) O enum do schema é ALARGADO com `feature-only`, e alargar é medidamente seguro.** Estreitar um enum invalida documento do campo, exatamente como remover chave sob `additionalProperties: false` (§3.2); **acrescentar** um membro não pode invalidar documento nenhum, porque todo valor antes válido continua válido. Medido, não presumido — compilei os dois schemas com `ajv` e validei os treze documentos do campo contra ambos:

```
default_mode=greenfield    schema-hoje=ACEITA  schema-alargado=ACEITA
default_mode=brownfield    schema-hoje=ACEITA  schema-alargado=ACEITA
default_mode=feature       schema-hoje=ACEITA  schema-alargado=ACEITA
default_mode=bugfix        schema-hoje=ACEITA  schema-alargado=ACEITA
default_mode=refactor      schema-hoje=ACEITA  schema-alargado=ACEITA
default_mode=feature-only  schema-hoje=RECUSA  schema-alargado=ACEITA
--- 13 documentos do campo; veredito mudou em 0
```

**(ii) Valor declarado que o `spec-new.sh` não aceita é RECUSA NOMEADA, nunca mapeamento silencioso e nunca queda para a heurística.** Mapear `feature`/`bugfix`/`refactor` para `feature-only` seria adivinhar a intenção de quem escreveu; cair na heurística seria silêncio verde sobre uma declaração que o dono acredita estar valendo — o defeito que esta onda inteira combate. A recusa nomeia os dois vocabulários e o caminho de saída (`--mode` explícito ou correção da chave), e sai com o mesmo rc 2 de toda validação de entrada do script. Os três valores continuam **válidos pelo schema** — a onda não os remove, porque removê-los invalidaria documento do campo (§3.2) —, e é por isso que a incompatibilidade dos dois vocabulários vira **item de ledger próprio**, aberto por esta onda com esta medição: reconciliá-los de verdade exige decidir qual dos dois é o vocabulário de `mode`, e essa é decisão de contrato, não de faxina.

**(iii) O valor de fábrica dos dois `FORGE.md` do template muda de `brownfield` para `greenfield`**, e o comentário da linha 12 passa a listar o vocabulário de `--mode` (`greenfield | brownfield | feature-only`), não o de `--type`. Justificativa medida: `templates/FORGE.md` é o scaffold de um projeto que acabou de nascer, e a heurística de `spec-new.sh:49` responde `greenfield` para um repositório sem `product/current` nem `docs/product` — que é exatamente o estado de um projeto recém-inicializado. Trocar o valor de fábrica para `greenfield` faz a chave **concordar** com a heurística no dia zero e passar a valer no dia em que o dono a mudar. Nenhum projeto existente muda de comportamento sem que alguém edite o próprio `FORGE.md`.

**O caso não coberto, dito em voz alta.** Um projeto brownfield que declarou `default_mode: brownfield` (o valor de fábrica de hoje) e **não** tem `product/current` nem `docs/product` passa, depois desta onda, a receber `brownfield` onde antes recebia `greenfield`. Isso é a chave funcionando, e é uma mudança de comportamento real: o `--mode` derivado entra no `manifest.yaml` do change e governa quais templates `spec-new.sh` instala. É benigno (o dono declarou o que queria), é reversível por uma linha, e vai na entrada do `CHANGELOG.md` desta onda com essas palavras. Um consumidor que não queira a mudança passa `--mode` explícito, que continua vencendo tudo.

### 3.5 A varredura de invariante 15 para as seis chaves

`grep -rn 'default_mode\|default_rigor\|default_scale\|archive_policy\|human_gate_required\|evals_root' tests/` devolve **uma** ocorrência que assere: `tests/w20-spec-gate.sh:139-143`, uma fixture de `FORGE.md` que declara as cinco `sdd.*`. Ela não assere valores e não muda de cor com a fiação, porque a fiação lê a chave e cai no fallback quando ela está ausente — e ali ela está presente com os valores de fábrica de hoje. **Exceção:** com a mudança de `default_mode` para `greenfield` no template, a fixture do `w20` continua declarando `brownfield`, o que é legítimo (é uma fixture, não o template) e não é asserido. Conferido lendo as linhas 139-143.

**Segunda varredura, exigida pela armadilha B — quem, em `tests/`, invoca `spec-new.sh`.** A fiação muda uma string e um comportamento de produção; `grep -rln 'spec-new' tests/*.sh` devolve **27** arquivos, e o risco seria uma bancada cujo `FORGE.md` declare `sdd.*` diferente do fallback e que chame `spec-new` sem `--scale`. Medido: das 27, a única que escreve um bloco `sdd:` numa fixture é `tests/w20-spec-gate.sh:139-143`, ela declara exatamente os valores de fábrica (`default_scale: 2`, `default_rigor: spec-anchored`), e a única chamada a `spec-new` naquele arquivo (`w20:115`) passa `--scale 2` explícito. Nenhuma das 27 muda de cor. `grep -rn 'default_mode' tests/` devolve só `w20:139` — o valor de fábrica `brownfield` do template não é asserido por gate nenhum, então a troca de (iii) não derruba ninguém.

`tests/w192-declared-switch-has-reader-gate.sh:52-55` mantém a lista `SWITCHES` com as duas chaves de **enforcement**, e o comentário da linha 51 remete a LDG-0151. A onda **acrescenta** as seis a uma segunda lista, com predicado próprio, no gate novo — não as mistura na `SWITCHES`, porque o texto de reprovação de `w192[1]` diz *"o harness afirma cobrar algo que não cobra"*, o que é falso para chave que promete default.

---

## 4. LDG-0161 — os dois `FORGE.md`

### 4.1 O defeito, medido

`wc -l template/.forge/FORGE.md template/.forge/templates/FORGE.md` devolve **173** e **114** linhas. `diff template/.forge/FORGE.md template/.forge/templates/FORGE.md | grep -c '^>'` devolve **0** — nenhuma linha existe só no segundo. `diff -u` entre os dois mostra que o segundo é o primeiro **menos** quatro blocos, todos presentes só no primeiro: o bloco `codegraph:` do frontmatter (7 linhas, `layers: []` e `orphans_by_design: []`), a seção `## 2.1 Source-of-truth precedence (authority order)`, a seção `## 7. Code graph: layer map and the meaning of unknown` e a seção `## 8. Autonomy (HITL vs YOLO)`. Não há uma única linha presente só no segundo.

`installer/install.sh:63` é `cp -R "$SOURCE" "$TARGET/.forge"` — os dois viajam. As linhas 67-68 excluem `*/templates/*` da substituição de placeholders, e `tests/w13-init-gate.sh:25-26` assere as duas metades disso: nenhum `<PROJECT_*>` fora de `templates/`, e `<PROJECT_SLUG>` **presente** em `.forge/templates/FORGE.md`.

`grep -rn 'templates/FORGE.md'` sobre `template/.forge/commands`, `agents`, `scripts`, `rules`, `bin/` e `installer/` devolve **zero**: nenhum código lê esse arquivo. O irmão dele, sim — `bin/forge.mjs:342-343` documenta que `.forge/templates/AGENTS.md` é a **fonte** do `AGENTS.md` da raiz, e `sync-adapters.mjs:94` o lê. `templates/FORGE.md` é o único arquivo de `templates/` que não tem consumidor e não tem gerador.

### 4.2 Decisão fechada — paridade byte a byte, provada por `cmp`

`template/.forge/templates/FORGE.md` passa a ser **byte a byte idêntico** a `template/.forge/FORGE.md`, e um cenário do gate da onda o assere com `cmp`.

Isso funciona porque os dois já são o mesmo documento na origem: `template/.forge/FORGE.md:4` é `name: <PROJECT_SLUG>`, ou seja, o arquivo canônico **também** carrega os placeholders na fonte, e a divergência entre os dois no consumidor é produzida em tempo de instalação pela exclusão de `*/templates/*`, exatamente como hoje. A identidade é na **fonte**; a divergência no **alvo** é a que `w13:25-26` assere, e ela continua idêntica.

Premissa conferida antes de decidir, porque `w192[4d]` depende dela: `grep -nE '^[[:space:]]*test:[[:space:]]*$' template/.forge/FORGE.md template/.forge/templates/FORGE.md` devolve a linha **21** nos dois arquivos. A paridade não muda o `test:` vazio de fábrica, e `w192:208-209` continua verde.

**Alternativa descartada 1 — apagar `templates/FORGE.md`.** Derruba `w13:26`, que exige o arquivo com placeholder, e obrigaria a mover essa asserção para outro arquivo de `templates/`. Exige também exercitar `installer/removed-files.txt`, cujo contrato de segurança (documentado no cabeçalho do arquivo e imposto por `w63`) é que *"um path aqui NUNCA pode existir no template atual"* — uma segunda maquinaria acionada para não ganhar nada, já que o custo de manter o arquivo é zero depois que o `cmp` o prende ao irmão.

**Alternativa descartada 2 — transformar `templates/FORGE.md` num symlink para `../FORGE.md`.** Refutada por execução. Bancada em `$TMPDIR/f-sym`, com um `cp -R` e a mesma linha de substituição do installer (`find … -type f … -exec perl -pi -e 's/<PROJECT_SLUG>/$ENV{SLUG}/g'`):

```
dst/templates/FORGE.md é symlink? sim
<dst>/FORGE.md
--- após substituição em -type f:
FORGE.md      : a: proj
templates/... : a: proj
```

O `find -type f` não visita o symlink, como esperado — e o conteúdo lido através dele vem **substituído**, porque aponta para o arquivo que foi substituído. `grep -q '<PROJECT_SLUG>' .forge/templates/FORGE.md` iria a zero e `w13:26` ficaria vermelho. A alternativa parecia a mais elegante das três e é a única que a execução refuta.

**Alternativa descartada 3 — asserir paridade só da parte normativa** (frontmatter e títulos de seção, deixando a prosa divergir). Descartada porque toda fronteira negociável vira uma discussão sobre de que lado da fronteira o próximo parágrafo cai, e foi por essa fronteira que o bloco de `phase:` do PR #105 foi depositado na cópia errada — que é o incidente que o ledger cita como origem do item.

### 4.3 O que a paridade custa, dito antes

Toda edição futura do `FORGE.md` do template passa a exigir a mesma edição nos dois arquivos, sob pena de gate vermelho. É o custo que a decisão compra deliberadamente: é exatamente o esquecimento que produziu o item. O `cmp` diz qual comando resolve, e a mensagem de reprovação o carrega. **O comando prescrito foi executado**, sobre cópias em `$TMPDIR` e nunca sobre `template/`: antes, `cmp -s` devolve rc 1; depois de `cp <canônico> <cópia de templates>`, rc 0; e `grep -c '<PROJECT_SLUG>'` na cópia resultante devolve **1**, de modo que a asserção de `w13:26` continua satisfeita pela fonte. Prescrever sem executar é a armadilha E, e ela vale para uma linha de `cp` como vale para um pipeline.

---

## 5. LDG-0171 — a varredura do `SCRIPT_DIR/../..`

### 5.1 O defeito, reproduzido por mim, num sítio que ninguém tinha medido

O item registra que o padrão sobrevive em 34 sítios exatos e 38 arquivos, e que *"não foi avaliado se os outros 33 têm o mesmo dano ou se a subida fixa é correta neles"*. A varredura é o trabalho.

Contagem executada nesta rodada — `grep -rn 'SCRIPT_DIR/\.\./\.\.\|SCRIPT_DIR}/\.\./\.\.\|\$(dirname "\$0")/\.\./\.\.' template/ bin/ tools/ installer/ tests/` devolve **41 linhas em 39 arquivos** (o mesmo predicado com `grep -rl` devolve 39; o número de arquivos, não o de linhas, era o que estava errado na primeira redação). Destas, **38 linhas em 38 arquivos de `template/.forge/scripts/`** e 3 em `tests/w204-ordinal-root-resolution-gate.sh` (dois comentários e a linha 145, que é a mutação daquele gate). As 38 se distribuem em cinco formas, contadas por `grep -rh … template/.forge/scripts/ | sed 's/^ *//' | sort | uniq -c | sort -rn`:

```
  33 ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
   2 ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   1 ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"   # .forge/scripts → raiz do projeto
   1 ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   1 [ -n "$ROOT" ] || ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

O "34 na forma exata" do registro é `33 + 1` (a linha com comentário à direita é a mesma forma). Registro a aritmética porque o número do ledger não é o número do `grep`, e o próximo leitor vai refazer a conta.

**A subida em si, medida:**

```
SCRIPT_DIR=template/.forge/scripts ; ../.. => /Users/milton/Documents/projects/forge-harness/template
worktree_root => /Users/milton/Documents/projects/forge-harness
```

**O dano, reproduzido num sítio com consequência.** `template/.forge/scripts/check-suite-wiring.sh` lê `$ROOT/package.json` e os workflows de CI. Invocado das duas formas contra a árvore real (somente-leitura):

```
=== SEM FORGE_ROOT (layout dogfood: ROOT vira template/)
OK suite-wiring/universo — 5 ponto(s) de entrada examinado(s) (workflows de CI, hooks do git, FORGE.md e package.json de …/forge-harness/template)
OK suite-wiring — .forge/scripts/tests/run-all.sh invocado em .forge/hooks/git/pre-push
OK suite-wiring-runners/universo — 1 runner(s) de suíte examinado(s) (tests .forge/scripts/tests em …/forge-harness/template)
OK suite-wiring — 1 runner(s) fiado(s) em 5 ponto(s) de entrada examinado(s)
rc=0

=== COM FORGE_ROOT=raiz
OK suite-wiring/universo — 3 ponto(s) de entrada examinado(s) (workflows de CI, hooks do git, FORGE.md e package.json de …/forge-harness)
OK suite-wiring — tests/run-all.sh invocado em .github/workflows/ci.yml
OK suite-wiring — tests/run-all.sh invocado em package.json
OK suite-wiring-runners/universo — 1 runner(s) fiado(s)…
rc=0
```

Os dois são **verdes** e respondem sobre **repositórios diferentes**: cinco pontos de entrada dentro do scaffold contra três pontos de entrada do projeto real, e a fiação afirmada num caso é `.forge/hooks/git/pre-push` do template, no outro é o `ci.yml` e o `package.json` do repositório. O contador de controle não salva ninguém, porque ele conta o universo errado com igual convicção. É falso-verde por resolução de raiz, e é o que o item pedia que fosse medido antes de generalizar.

**E o dano não está nos comandos `git`.** Executado: `git -C template rev-parse --show-toplevel` devolve `/Users/milton/Documents/projects/forge-harness`, porque `git` sobe até o `.git` mais próximo. Um script que faça `git -C "$ROOT" …` com `ROOT=template/` acerta por acidente. O dano está nos caminhos de arquivo: `template/docs`, `template/package.json`, `template/tests` e `template/.git` **não existem**; os quatro existem na raiz (exceto `AGENTS.md`, que não existe em lugar nenhum deste repositório). Medido com um laço de `[ -e ]`.

### 5.2 A varredura: o critério de classificação, fechado

Um sítio é classificado pelo **dado que o `ROOT` resolvido endereça**, e não pela forma da linha:

- **C1 — o `ROOT` só endereça `$ROOT/.forge/…`.** No layout de dogfood, `template/` é a raiz **correta**: o dado é o scaffold, e `template/.forge/` é onde ele mora. A subida está certa por deriva de layout, e o sítio **não muda**. É a alínea que o item suspeitava existir e ninguém tinha confirmado.
- **C2 — o `ROOT` endereça dado de PROJETO, lendo ou gravando, e não conteúdo do scaffold.** Inclui `$ROOT/docs`, `$ROOT/package.json`, `$ROOT/tests`, `$ROOT/AGENTS.md`, e inclui também quem apenas **lê** dado de projeto que por acaso mora sob `.forge/` — `template/.forge/specs` e `template/.forge/ledger` existem em disco, então um leitor de `$ROOT/.forge/specs` em layout de dogfood lê o **scaffold** em vez do `.forge/specs` da raiz, calado. A cláusula "grava estado durável" da primeira redação deixava esse caso fora e faria o varredor classificar como C1 sítios que o item pediu para medir. Em dogfood, `template/` é raiz **errada**. O sítio migra para `forge_worktree_root "$SCRIPT_DIR"` (`lib/forge-root.sh:61`), que é o remédio já provado por `w204`.
- **C3 — o sítio ignora `FORGE_ROOT`.** Defeito próprio, independente da subida: `build-plugin.sh:16`, `sync-adapters.sh:8` e `smoke-adapters.sh:10` resolvem `ROOT` sem consultar a variável que o harness inteiro usa para declarar a raiz. Migram, e a migração conserta as duas coisas de uma vez, porque `forge_worktree_root` consulta `FORGE_ROOT` primeiro (`lib/forge-root.sh:63`).

**Primeira passada da classificação, executada, com o predicado grosseiro `grep -oE '\$(ROOT|\{ROOT\})/[A-Za-z0-9_.-]+' | grep -v '/\.forge'` sobre `template/.forge/scripts/*.sh`.** Ele acende em **nove** scripts, dos quais **seis** estão no universo dos 38 (`check-suite-wiring`, `doctor`, `ingest-legacy`, `publish-docs`, `spec-new`, `check-heavy-mutex`); os outros três (`dotnet-baseline.sh`, `node-baseline.sh`, `gate-ordinal.sh`) endereçam dado de projeto mas **não** usam a subida fixa, e por isso estão corretamente fora do universo — o que é, por si, uma medição a favor de o critério ser o dado endereçado e não a forma da linha. Seis sítios com dado fora de `.forge/`, mais os três de C3:

| Sítio | Endereça fora de `.forge/` | Classe candidata |
|---|---|---|
| `check-suite-wiring.sh:28` | `$ROOT/package.json` | **C2** (dano reproduzido em §5.1) |
| `doctor.sh:44` | `$ROOT/AGENTS.md` | **C2**, e ver §5.3 |
| `ingest-legacy.sh:12` | `$ROOT/docs` | **C2** |
| `publish-docs.sh:11` | `$ROOT/docs` | **C2** |
| `spec-new.sh:17` | `$ROOT/docs` | **C2** |
| `check-heavy-mutex.sh:11` | `$ROOT/…` (variável) | a reclassificar por leitura |
| `build-plugin.sh:16`, `sync-adapters.sh:8`, `smoke-adapters.sh:10` | — | **C3** |
| os 29 restantes | nada fora de `.forge/` pelo predicado | **C1 candidato** |

**Esta tabela é uma primeira passada e a especificação diz isso em letra.** O predicado só enxerga `$ROOT/<literal>`; um script que passe `$ROOT` inteiro para um lib em node endereça o que o lib endereçar, e o `grep` não vê. A onda **exige** que o implementador produza a classificação completa dos 38, sítio a sítio, e que ela seja **um artefato executável e não uma tabela em markdown** — um varredor em `template/.forge/scripts/` que emite a classe de cada sítio a partir do código, para que a classificação não envelheça no dia em que alguém acrescentar um `$ROOT/docs` a um script hoje C1. O gate assere a classificação; a tabela acima é o insumo, não o produto.

### 5.3 `doctor.sh:44` — o sítio que o item nomeia, e a decisão que ele exige

`doctor.sh:34-40` já **documenta** a resolução para `template/` como comportamento conhecido: *"sempre resolve ROOT para `template/`, o diretório-fonte do pacote — e então o guard de placeholders `<PROJECT_*>` se autoflagra"*, com a saída indicada (`FORGE_ROOT=<repo> bash template/.forge/scripts/doctor.sh --report`). Migrar `doctor.sh` para `forge_worktree_root` **mudaria** esse comportamento documentado: sem `FORGE_ROOT`, o doctor passaria a examinar a raiz do repositório e o guard de placeholders deixaria de se autoflagrar — o que é a melhoria — mas ele também passaria a exigir de `forge-harness` (que não é consumidor completo, e cuja Fase 1 é justamente resolver isso) coisas que o dogfood não tem.

**Decisão fechada: `doctor.sh` migra, e migra DEPOIS da Fase 1, não nesta onda.** A Fase 1 instala a maquinaria na raiz e é ela que decide o que o doctor deve encontrar lá; migrar antes trocaria um comportamento documentado por outro cujo alvo ainda não existe. A onda **assere** o sítio como C2 **conhecido e pendente**, com o motivo, na mesma allowlist auditável de isenção que o harness já usa para universo vazio (`.forge/empty-universe-allowlist.txt`, formato `<chave>  # motivo: <justificativa>`) — isenção declarada e revisável, nunca silêncio. E `doctor.sh:44` também é o único sítio que usa `$(dirname "$0")` em vez de `${BASH_SOURCE[0]}`, o que o torna sensível a ser invocado por `source`; isso entra na mesma nota.

**Alternativa descartada: migrar os 38 de uma vez.** Descartada por duas medições. Primeira, C1 existe e é a maioria: migrar um sítio C1 **introduz** o defeito em vez de corrigi-lo, porque faria um script cujo dado é o scaffold passar a endereçar a raiz do repositório. Segunda, migrar exige `source` de `lib/forge-root.sh` em cada script, e `gate-ordinal.sh:38-41` mostra o preço: a ausência do lib vira uma recusa nova (`FAIL gate-ordinal — …/forge-root.sh ausente`). Trinta e oito recusas novas num único PR, em scripts que viajam no tarball, é mudança de contrato disfarçada de faxina.

---

## 6. LDG-0164 — a varredura da mutação-fantasma

### 6.1 O defeito, reproduzido e restrito ao que ele é

O registro descreve a linha do `w195[11]` antes da correção: `perl -0pi -e 's/…/cp "$own" "$tmp"; if false; then/'` com o `$` do lado **direito** sem escape. Em `-e` entre aspas simples, o shell não expande; `$own` e `$tmp` chegam ao perl como variáveis do **perl**, não declaradas, portanto vazias.

Reproduzido em `$TMPDIR/f-mut`, com um alvo sintético que reproduz a forma do `_dir_push`:

```
=== FORMA DEFEITUOSA (LDG-0164): $ sem escape do lado direito, aspas simples
  cmp: MUDOU (o controle de bytes aprova)
3:  cp "" ""; if false; then
=== FORMA CORRETA: $ escapado
3:  cp "$own" "$tmp"; if false; then
```

O `cmp` de controle aprova a mutação — o arquivo mudou mesmo — e o que foi injetado é `cp "" ""`, que não copia nada. A asserção seguinte media o efeito do engano.

### 6.2 O método: por que não é sintático, e o que o torna decidível mesmo assim

O mandato observa, corretamente, que o critério não pode ser "tem `$` no lado direito" — o `$` **escapado** também aparece, e é justamente a forma correta. O que separa as duas é se o perl **interpola** o `$`, e isso é decidível pela combinação de três coisas, todas literais no fonte do gate:

1. o estilo de aspas do argumento `-e` (aspas simples ⇒ o shell não tocou; aspas duplas ⇒ o shell já expandiu tudo que não estava escapado);
2. o lado direito de cada `s/…/…/`, extraído respeitando as barras invertidas;
3. a lista de sigilos que o perl **não** trata como variável do usuário: `$1`–`$9`, `${N}`, `$&`, `$ENV{…}`.

O item (3) não é opcional, e o contrafactual está medido. Aplicando o escape indiscriminado a uma mutação legítima do `w206`:

```
escrita   : [  : # MUTATED]
escapada  : [$1: # MUTATED]
DIVERGEM -> falso positivo se o oráculo escapar $1
```

Um detector que escapasse `$1` acusaria uma mutação correta. A exclusão de capturas não é preciosismo, é o que faz o detector ter valor de verdade.

**A soundness da leitura sintática tem uma premissa, e ela foi conferida.** Uma variável do perl só é vazia se ninguém a atribuiu. `grep -rn 'perl .*-e' tests/*.sh | grep -E 'BEGIN|my \$|our \$|\$[a-z_]+\s*='` devolve **uma** linha, `tests/w151-heavy-mutex-gate.sh:322`, que é `perl -e 'my $p=fork(); …'` — um `perl -e` sem `-pi`, que não é substituição e não entra no universo. Nenhuma expressão de mutação atribui variável do perl. A premissa entra no gate como uma asserção própria, para que continue verdadeira.

### 6.3 A varredura, executada: zero suspeitos — e por que o denominador NÃO pode ser o critério

Detector escrito em perl e rodado sobre `tests/*.sh` nesta sessão. Ele localiza cada invocação de `perl -pi`/`perl -0pi` com `-e`, identifica o estilo de aspas, percorre o argumento extraindo cada `s/PAT/REPL/` com respeito a `\`, e marca o lado direito quando encontra `$nome` não precedido de barra invertida e fora da lista de (3). O detector inteiro vive em `$TMPDIR/f-det.pl` e a invocação é `perl "$TMPDIR/f-det.pl" tests/*.sh`; a linha final que ele imprime é o contador de controle:

```
$ perl "$TMPDIR/f-det.pl" tests/*.sh
TOTAL	linhas=89	substituicoes=94	suspeitos=0
```

**Veredito: zero suspeitos. Denominador: 94 substituições em 89 linhas — e esse par é testemunha de data, não critério.** Uma redação anterior deste documento trouxe `94 / 90` e um extrator independente escrito por um revisor trouxe `95 / 90` sobre a mesma árvore, no mesmo commit. Três extratores, três denominadores, e nenhum deles errado: o número depende de o extrator aceitar delimitadores alternativos (`s#…#…#`), de como conta uma linha com duas substituições e de onde ele considera que o argumento de `-e` termina. **É por isso que o gate C nunca compara o denominador contra literal**: ele publica o número que examinou (contador de controle, `[6]`), assere a **propriedade** (`[1]`: nenhuma substituição interpola variável do perl) e prova que a propriedade não é vácua pela contrapositiva executada (`[2]`) e pelo piso de universo não-vazio. Um gate que fixasse `94` reprovaria no dia em que alguém trocasse `s/…/…/` por `s#…#…#` sem defeito nenhum, e é exatamente a armadilha A.

**O único candidato que qualquer extrator acende, e por que ele não é suspeito.** `tests/w205-quick-plan-design-skip-gate.sh:73` usa **aspas duplas** no argumento de `-e`, então o shell já expandiu o que havia antes de o perl ver a expressão — o item (1) do método de §6.2 o exclui corretamente, e é o item (1) que faz "zero suspeitos" ser uma afirmação com valor de verdade em vez de um `grep` frouxo.

**Contrapositiva, e ela é obrigatória: um detector que devolve zero pode estar quebrado.** Repliquei o defeito histórico numa cópia do `w195` em `$TMPDIR` (removendo o escape do lado direito da linha 430) e rodei o mesmo detector:

```
$ cp tests/w195*.sh "$TMPDIR/f-det-cp/w195-mutado.sh"
$ perl -0pi -e '…remove o escape do lado direito da linha 430…' "$TMPDIR/f-det-cp/w195-mutado.sh"
$ sed -n '430p' "$TMPDIR/f-det-cp/w195-mutado.sh"
perl -0pi -e 's/if ! node "\$mod" …; then/cp "$own" "$tmp"; if false; then/' "$COMMON"
$ perl "$TMPDIR/f-det.pl" "$TMPDIR/f-det-cp/w195-mutado.sh"
SUSPEITO	/…/f-det-cp/w195-mutado.sh:430	$own,$tmp
TOTAL	linhas=2	substituicoes=2	suspeitos=1
```

O detector acende sobre o defeito replantado e fica calado sobre a árvore de hoje. O zero é um zero medido, não um zero por não ter olhado.

### 6.4 Decisão fechada — o entregável é o detector, não a migração de 90 sítios

LDG-0164 pede a varredura. A varredura está feita e o resultado é limpo. O que fecha o item é o **detector**, porque sem ele o próximo `perl -0pi` volta a trazer a classe, e o registro do item diz exatamente isso: *"varrer os demais gates … é trabalho que este item não fez"*.

Nasce `template/.forge/scripts/check-mutation-hygiene.sh`, gate de fase `source`, que:

- varre um caminho (`--path`, com o mesmo idioma de `check-shell-pipeline.sh` e `check-secrets.sh`) atrás de invocações de `perl -pi`/`perl -0pi` com `-e`;
- **reprova** o lado direito com variável do perl interpolável fora de captura e de `$ENV`;
- **reprova** expressão de mutação que atribua variável do perl (a premissa de §6.2);
- publica contador de controle: quantas substituições examinou, com o terceiro estado de universo vazio via `lib/gate-universe.sh`, que é o mecanismo que o harness já tem;
- distingue "não consegui examinar" — sem `perl` no `PATH` — de "examinei e está limpo", pelo vocabulário da onda D quando ele estiver na árvore, e por rc próprio quando não estiver (mesma regra de §2.7).

**O que este detector NÃO decide, e é o limite honesto do item.** A classe maior — *mutação que muda bytes e não muda decisão* — não é decidível estaticamente. Uma mutação bem formada pode ainda ser inerte porque casa zero vezes (o `cmp` de controle pega esse caso, e a maioria dos gates o tem), porque muda um comentário, ou porque muda um ramo que o cenário não exercita. Decidir isso exigiria rodar cada cenário com e sem a mutação — as 130 execuções que o mandato recusa, com razão.

**Decisão sobre o resíduo:** a onda **não** o fecha e **não** finge fechá-lo. Ela entrega uma mitigação barata e nomeada: o detector também reprova quando a substituição, aplicada a uma sonda derivada do próprio lado esquerdo, produz um alvo que **não passa mais no analisador sintático da linguagem do alvo** — `bash -n` para `.sh`, `node --check` para `.mjs`. Uma mutação que torna o alvo insintático não está medindo a decisão do alvo, está medindo o crash. Isso é decidível e barato. O que sobra depois disso — mutação sintaticamente válida, byte-diferente e semanticamente inerte — vai para um item de ledger próprio, aberto por esta onda, com esta medição anexada.

**Alternativa descartada — migrar os 90 sítios para um `forge_mutate`/`forge_restore` num lib novo.** É a solução completa e é desproporcional aqui: toca ~40 arquivos de gate rastreados, num item P2 cuja varredura devolveu zero ocorrências, e cada arquivo tocado é um gate que pode ficar vermelho por um motivo que nada tem a ver com o item. Fica registrado como a evolução natural do detector no dia em que a classe voltar a aparecer.

---

## 7. LDG-0176 — o grafo commitado contra a regeneração

### 7.1 O defeito, reproduzido

`.forge/graph/graph.json` rastreado, lido com `node -e` (variável de ambiente, nunca argumento posicional — `node -e '<código>' <caminho>` põe o caminho em `process.argv[1]`, e essa é uma das três prescrições que derrubaram a terceira rodada de outra especificação):

```
$ G=".forge/graph/graph.json" node -e 'const g=JSON.parse(require("fs").readFileSync(process.env.G,"utf8"));
    console.log("generated_at:",g.generated_at); console.log("nodes:",g.nodes.length,"edges:",g.edges.length);
    console.log("tests/:",g.nodes.filter(n=>n.id.startsWith("tests/")).length)'
generated_at: 2026-09-04T19:53:54.648Z
nodes: 256 edges: 51
tests/: 114
```

Regeneração numa bancada em `$TMPDIR`, nunca contra `.forge/graph/` da árvore real:

```
$ B="$TMPDIR/f-graph"; rm -rf "$B"; mkdir -p "$B"; git archive HEAD | tar -x -C "$B"
$ rm -rf "$B/.forge/graph"
$ ( cd "$B" && node template/.forge/scripts/lib/graph-build.mjs )
OK .forge/graph/graph.json (310 nodes, 59 edges; 310 summaries stale)
```

Diferença de **conjuntos de ids**, que é a comparação que o plano-mestre exige:

```
$ A=".forge/graph/graph.json" C="$B/.forge/graph/graph.json" node -e '<compara os dois conjuntos de ids>'
commitado: 256  regenerado: 310
só no commitado (0):
só no regenerado (54): template/.forge/capabilities/backend-node-postgres/assets/eslint-rules/core-rules.cjs, …
tests/ commitado: 114  regenerado: 150
dos 54 só-no-regenerado, em tests/: 36
```

Cinquenta e quatro nós existem na árvore e não no grafo; **zero** existem no grafo e não na árvore. Trinta e seis dos 54 são gates de `tests/`. Nada no repositório compara as duas coisas: `grep -rn 'graph.sh\|graph-build' .github/workflows/ template/.forge/hooks/ package.json` devolve **zero**, e os scripts do `package.json` são apenas `test` e `build:plugin`.

### 7.2 Duas propriedades do artefato que decidem o desenho do gate

**O conjunto de ids é determinístico; o arquivo não é.** Duas regenerações consecutivas sobre a mesma bancada:

```
$ for i in 1 2; do ( cd "$B" && node template/.forge/scripts/lib/graph-build.mjs >/dev/null &&
    node -e '<imprime nodes, edges, sha256 dos ids ordenados e generated_at>' ); done
rodada: nodes=310 edges=59 ids-sha=571b9a9116e6817a generated_at=2026-09-07T21:23:26.948Z
rodada: nodes=310 edges=59 ids-sha=571b9a9116e6817a generated_at=2026-09-07T21:23:33.670Z
```

`generated_at` é relógio de parede. Comparar arquivos por `cmp` é impossível por construção, e comparar **contagem** envelheceria a cada gate novo — é o que o plano-mestre manda evitar. Comparar o **conjunto de ids** é a única comparação estável, e ela é estável de verdade: o sha do conjunto ordenado bate entre rodadas.

**O universo do grafo é o que `codegraph.include_paths` diz que é.** `.forge/FORGE.md:3-5` da raiz declara `include_paths: ["template/.forge/**"]`, com o motivo escrito nas linhas 10-16 (o engine pula diretórios de nome oculto por default, e neste repositório `template/.forge/` é código-fonte do produto). Sem essa declaração o grafo não teria nó nenhum de `template/.forge/`. O gate herda o universo do `FORGE.md`; ele não redefine universo.

### 7.3 Decisão 1 — a bancada, e por que o custo dela NÃO vira número nesta especificação

O gate regenera numa cópia em `$TMPDIR`, nunca na árvore real: `lib/graph-build.mjs:357-383` escreve `graph.json`, `report.md`, `cache/fingerprints.json` e `cache/summaries.json`, e os quatro são rastreados (`git ls-files .forge/graph/`). Um gate que os reescrevesse seria a repetição literal de LDG-0175.

**Sobre o custo, esta especificação não traz número absoluto, e a razão é uma medição.** Uma redação anterior trazia três tempos de montagem em milissegundos. Eles não reproduzem — nem em outra máquina, nem **na mesma máquina, no mesmo commit, em duas execuções consecutivas do comando idêntico**:

```
$ for i in 1 2; do rm -rf "$B/a"; mkdir -p "$B/a"; <cronômetro> git archive HEAD | tar -x -C "$B/a" <cronômetro>; done
  rodada 1: 19472 ms  arquivos=1171
  rodada 2: 29692 ms  arquivos=1171
$ <o mesmo com> git ls-files -z -co --exclude-standard | tar --null -T - -cf - | tar -x -C "$B/b"
  rodada 1: 85384 ms  arquivos=1178
```

Cinquenta e dois por cento de variação entre duas rodadas do mesmo comando, numa máquina com outra suíte em execução. Um tempo absoluto nessas condições é ruído com casas decimais, e afirmá-lo na especificação seria plantar um número que o próximo revisor não reproduz — que é a classe de defeito que esta rodada existe para eliminar. **O que reproduz, e portanto fica:** a **contagem de arquivos** (1171 para `git archive HEAD`, estável entre rodadas) e a **ordem** entre os dois primitivos (`git ls-files … | tar --null -T -` foi o mais lento em todas as rodadas de todas as medições feitas neste plano). A razão entre eles **não** fica: ela deu de 2,9× a 4,4× nesta medição e valores bem diferentes em outras, e uma afirmação que oscila assim não sustenta peso.

| Primitivo | Arquivos | Conjunto de ids |
|---|---|---|
| `git ls-files -z -co --exclude-standard \| tar --null -T - -cf - \| tar -x` | 1178 | a verificar pelo implementador |
| `git archive HEAD \| tar -x` | **1171** | `571b9a9116e6817a` (medido, §7.2) |
| `cp -R` seletivo de `{template,tests,tools,bin,installer,contracts}` + `package.json` + `.forge/FORGE.md` | enumeração à mão | a verificar pelo implementador |

**Decisão:** a especificação **declara a propriedade** — a bancada tem de conter todo arquivo que o engine consideraria na árvore real, e o gate tem de terminar dentro de um **teto declarado em letra pelo implementador no cabeçalho do gate**, medido por ele na máquina dele, com o comando colado ali — e **não prescreve o primitivo**, por invariante 19. **O gate nunca assere tempo**: uma asserção de tempo numa suíte que roda em CI compartilhado é um gerador de falso-vermelho, e a medição acima é a prova. O que a especificação entrega ao implementador são as duas armadilhas medidas: `git ls-files … | tar --null -T -` é a forma que parece mais correta e foi a mais lenta em toda medição; e o `cp -R` seletivo é rápido **porque enumera as raízes à mão**, o que é um literal que envelhece no dia em que este repositório ganhar um diretório de código novo no topo — exatamente a invariante 14, agora numa lista de diretórios em vez de num número.

**Uma armadilha da bancada, medida por acidente e registrada porque ela produz um verde falso.** Ao montar a bancada com `git archive HEAD`, o `.forge/graph/graph.json` **commitado** viaja junto. Um passo de leitura que rodasse antes da regeneração leria o artefato antigo e o compararia consigo mesmo. Aconteceu comigo nesta sessão: uma das quatro bancadas reportou `nodes=256` porque uma guarda `[ -f "$grafo" ]` pulou a regeneração. O gate tem de remover ou ignorar o grafo que viajou, e a asserção que o prova é um sinal positivo de que a regeneração de fato rodou — nunca a mera existência do arquivo.

### 7.4 Decisão 2 — HEAD, não a árvore de trabalho, e os nove desfechos medidos

**Decisão:** o gate compara o `graph.json` **commitado** contra a regeneração sobre o **conteúdo commitado**. A pergunta que ele responde é *"o artefato que está no repositório corresponde ao que o gerador produziria a partir do que está no repositório?"*, e as duas metades têm de vir da mesma fonte. Medido, hoje as duas fontes coincidem, e a razão é mais durável do que a lista de não rastreados do dia: o universo do grafo é `codegraph.include_paths: ["template/.forge/**"]` (§7.2), e `git ls-files -o --exclude-standard -- 'template/.forge'` devolve **zero** arquivos. Não há nada não rastreado dentro do universo, logo as duas bancadas veem o mesmo conjunto. (Os não rastreados desta árvore hoje são os próprios rascunhos de especificação sob `docs/plans/spikes/`, fora do universo por construção — e é justamente por isso que a justificativa não pode ser "o único não rastreado é X": X muda a cada sessão.)

**Alternativa descartada — comparar contra a árvore de trabalho.** Um arquivo `.mjs` de rascunho, não rastreado e não ignorado, deixaria o gate vermelho sobre um arquivo que ninguém vai publicar. É o risco que `w200:15-17` já nomeia para si mesmo (*"um arquivo não rastreado sob `template/.forge/<dir>` deixaria este gate vermelho localmente e verde no CI, e é um risco aceito"*) e que aqui não precisa ser aceito, porque a pergunta natural do artefato é sobre o que foi commitado.

**Os desfechos, enumerados, e o sexto procurado de propósito:**

| # | Estado | Desfecho |
|---|---|---|
| 1 | ids do commitado == ids da regeneração | **OK**, com o contador de nós examinados |
| 2 | há id na regeneração ausente do commitado | **FAIL**, nomeando até N ids e o total (o estado de hoje: 54) |
| 3 | há id no commitado ausente da regeneração | **FAIL**, nomeando-os — é o caso de arquivo apagado sem regenerar, e um gate que só olhasse a direção 2 ficaria verde sobre ele |
| 4 | `.forge/graph/graph.json` ausente na árvore | **FAIL** — neste repositório o grafo é rastreado; a ausência é perda de artefato, não ausência de contrato |
| 5 | `node` ausente do `PATH`, ou `lib/graph-build.mjs` ausente | **terceiro estado** — não verde, não vermelho; §2.7 vale aqui |
| 6 | **repositório git sem nenhum commit** | `git archive HEAD` sai **128** com `fatal: not a valid object name: HEAD` — medido nesta sessão num `git init` vazio. **Terceiro estado**, jamais verde: não há conteúdo commitado contra o qual comparar |
| 7 | a regeneração falha (rc≠0 do engine) | **terceiro estado**, com o rc e a saída do engine na linha |
| 8 | a regeneração devolve **zero** nós | **FAIL por vacuidade**, via `lib/gate-universe.sh` — é o desfecho de um `include_paths` quebrado, e ele é indistinguível de sucesso se ninguém contar |
| 9 | `graph.json` **presente e ilegível** | **terceiro estado**, e são DUAS formas, não uma. Medido: JSON truncado ⇒ `JSON.parse` lança `SyntaxError`, e sem tratamento o gate morre com stack trace — terceiro estado por acidente, não por desenho; JSON válido **sem a chave `nodes`** ⇒ leitura devolve `undefined`, e um gate que fizesse `g.nodes.length` morreria, mas um que tratasse `undefined` como lista vazia cairia no desfecho 8 e reprovaria por vacuidade sobre o artefato **errado** (o commitado, não a regeneração). O gate valida a forma do artefato commitado ANTES de comparar, e o terceiro estado nomeia qual das duas formas encontrou |

**Sobre a palavra "exaustiva".** Esta enumeração **não** se declara exaustiva, e a razão é empírica: a redação anterior tinha oito desfechos, dizia tê-los procurado, e o nono — `graph.json` presente e ilegível — foi encontrado por um revisor, não por mim. Ela é a enumeração mais cuidadosa deste documento e ainda assim ficou incompleta uma vez; declará-la fechada seria a armadilha D. O desfecho 6 (`git archive HEAD` em repositório sem commit, rc 128) e o desfecho 9 foram cada um procurado de propósito e executados; o que a especificação afirma é que os nove estão medidos, não que não há um décimo.

### 7.5 Decisão 3 — o custo recorrente, nomeado antes de cobrar

Com o gate no ar, **todo PR que acrescente ou remova um arquivo que o engine enxerga passa a exigir a regeneração do grafo no mesmo PR**. É a mesma disciplina que o repositório já pratica para o plugin (`npm run build:plugin`), e é o preço de ter detector. A mensagem de reprovação carrega o comando exato que resolve.

**Duas consequências que o implementador precisa saber, e uma delas vira item de ledger.**

Primeira: as ondas G, H, I e J vêm depois de F na ordem do plano-mestre, e as que acrescentarem arquivo terão de regenerar. Isso vai na linha do `CHANGELOG.md` e na comunicação da onda, não como surpresa no primeiro PR vermelho.

Segunda, e é dívida nova: `generated_at` muda a cada execução, então **regenerar sempre suja a árvore**, mesmo quando nada estrutural mudou. `graph.sh update` (linhas 20-26) executa `graph-build.mjs` de qualquer forma e só **compara** os fingerprints depois, então ele também reescreve `graph.json` com um `generated_at` novo. Quem rodar a regeneração só para conferir fica com um diff de uma linha para descartar. A onda **não** conserta isso — consertar exige decidir se `generated_at` sai do artefato, vira granularidade grossa ou passa a ser a data do commit, e é decisão de contrato do `graph.schema.json`. Vira item de ledger aberto por esta onda, com esta medição.

---

## 8. Os gates da onda

A onda entrega **três** gates novos e acrescenta cenários a **um** existente. Nenhum ordinal é alocado aqui (§11).

### 8.1 Gate A — o contrato do `FORGE.md` (LDG-0152, LDG-0151, LDG-0161)

**Cenários, denominador fixo por construção — 15 blocos: `[1]` a `[12]`, mais `[6b]`, `[10b]` e `[10c]`.** O denominador é fixo porque está escrito aqui e é conferido pelo cabeçalho do próprio gate, não porque alguém conte os blocos depois.

| # | O que assere | Como falha HOJE |
|---|---|---|
| `[1]` | **Propriedade** — todo autômato do censo (predicado de §2.1) confina a leitura ao frontmatter pela regra medida em §2.4, salvo os declarados na isenção auditável | vermelho: **seis** dos nove autômatos não confinam hoje (linhas 1 a 6 da tabela de §2.1), e a isenção declara **um** (`pentest_cfg`) |
| `[2]` | **Contrapositiva do censo** — o predicado do censo não casa uma função sintética que não lê `runtime:` | verde hoje e depois; existe para provar que `[1]` não é vácuo |
| `[3]` | **Piso NOMINAL do censo, no conjunto PÓS-onda** — o censo tem de encontrar, cada um pelo nome do arquivo e da função, os **oito** autômatos que sobrevivem à onda: `pre-push` ×3, `lib/forge-runtime.sh` `forge_get_runtime`, e `pentest-ops.sh` ×4. `handoff-gen.sh` **não** está no piso, porque o passo 7 de §13 o remove — um piso escrito com o conjunto de hoje (nove) ficaria vermelho contra a implementação correta, que é a armadilha A. O **número** de autômatos é impresso como contador de controle e **nunca** comparado contra literal: acrescentar um leitor novo não pode reprovar o gate, remover um dos oito tem de reprovar | vermelho por ausência do censo |
| `[4]` | **Execução diferencial** — os leitores bash e o leitor canônico concordam sobre um corpus de `FORGE.md` adversariais: bloco só na prosa dentro de cerca, chave de topo com hífen depois do bloco, `runtime:` duplicado, arquivo sem frontmatter, frontmatter sem fechamento, frontmatter bem formado com `runtime:` no corpo (a forma do `w147:83`), e **linha `----` no corpo** — o caso que separa a regra canônica (`\n---`, prefixo) da regra de `pentest_frontmatter_of` (`$0 == "---"`, igualdade), medido em §2.4 | vermelho: medido em §2.2, §2.3 e §2.4, os leitores discordam em três dos sete casos |
| `[5]` | **Os DOIS casos do predicado de §2.7, pelo canal real** — (a) `FORGE.md` **sem** frontmatter com `runtime:` no arquivo e (b) `FORGE.md` **com** frontmatter bem formado e `runtime:` no corpo (a forma do `w147:83` e do CASO 0 de §2.2): nos dois o `pre-push` diz que encontrou o bloco fora do frontmatter e não o leu, e a linha é distinguível por `grep` de "campo não declarado" e de "campo declarado e vazio". Um cenário com um caso só deixaria (b) passando calado, que é o silêncio verde medido em §2.5 | vermelho nos dois: hoje ele lê a prosa e segue calado (§2.7) |
| `[6]` | `handoff-gen.sh` não tem `fm_field` próprio e produz o mesmo valor de `forge_get_runtime` para `test`, `typecheck` e `lint` | vermelho: `grep -c 'fm_field' template/.forge/scripts/handoff-gen.sh` devolve **4** hoje |
| `[6b]` | **Degradação sem o lib, pelo canal real** — numa bancada onde `.forge/scripts/lib/forge-runtime.sh` **não existe**, `handoff-gen.sh` termina com **rc 0** e escreve os campos de runtime como `n/d`. É a propriedade de §2.6, e sem este cenário a onda troca um leitor duplicado por uma recusa nova num script que nunca recusou | verde hoje (o `fm_field` é local e não depende de lib nenhum); o cenário existe para que a mudança do passo 7 **não** o derrube, e é vermelho contra a implementação ingênua (`source` incondicional sob `set -euo pipefail` ⇒ rc 1, medido em §2.6) |
| `[7]` | `hooks/session/on-session-start.sh` não afirma no comentário ser o mesmo idioma de `fm_field` — e `_yaml_auto` continua lendo `forge.yaml` corretamente, com um caso positivo | vermelho na primeira metade (linha 11), verde na segunda; o par existe para que a correção do comentário não vire remoção da função |
| `[8]` | **Propriedade das seis chaves** — toda chave de `sdd.*`/`quality.*` da lista de "promete default" tem leitor que **decide**, fora de linha de comentário, em `scripts/`, `hooks/` ou `bin/`, **ou** está na lista de deprecadas declaradas com o motivo escrito ao lado | vermelho: zero leitores para as seis (§3.1) |
| `[9]` | **Contrapositiva** — uma chave sintética inexistente tem zero leitores pelo mesmo predicado | verde hoje; prova que `[8]` não é frouxo |
| `[10]` | **Comportamento, não menção** — `spec-new.sh` num repositório cujo `FORGE.md` declara `default_scale: 4` cria o change com `scale: 4`; com a chave ausente, cria com `2` | vermelho: `SCALE="2"` é literal em `spec-new.sh:22` |
| `[10b]` | **O par do valor não mapeável de `default_mode`** — `FORGE.md` declarando `default_mode: feature` (válido pelo schema, recusado pelo script, §3.4): `spec-new.sh` sem `--mode` sai **rc 2** com mensagem que nomeia os dois vocabulários; e o pareado, `default_mode: feature-only`, cria o change com `mode: feature-only`. Sem o par, a decisão de §3.4 fica sem asserção que a prove, e a implementação "cai na heurística" passaria | vermelho: hoje a chave não é lida, então os dois casos caem na heurística indistinguivelmente |
| `[10c]` | **Contrato do schema alargado** — um documento com `default_mode: feature-only` valida contra `forgeFrontmatter`, e os cinco valores de hoje continuam validando | vermelho: `feature-only` reprova hoje (§3.4, medido com `ajv`) |
| `[11]` | `template/.forge/FORGE.md` e `template/.forge/templates/FORGE.md` são idênticos por `cmp`, e o `w13`-invariante segue: os dois carregam `<PROJECT_SLUG>` na fonte | vermelho: 173 contra 114 linhas (§4.1) |
| `[12]` | **Contador de controle** — corpus de `[4]` vazio, censo de `[3]` vazio, ou lista de chaves de `[8]` vazia, reprova pelo `lib/gate-universe.sh` | vermelho por ausência |

**Prova de mutação — quatro mutações, cada uma com o contrafactual declarado e a acusação que o gate deve emitir.** Todas operam sobre **cópias em `$TMPDIR`**, nunca sobre `template/`; a restauração é por `cp` do original seguido de `cmp -s` byte a byte, e o **recontrole** reexecuta a asserção e exige que ela volte ao estado anterior. Sem o recontrole a prova não vale (`feedback-mutacao-fantasma-restore`).

| Mutação | Alvo (cópia) | Contrafactual que ela precisa produzir | Cenário que deve acusar |
|---|---|---|---|
| M1 — remover o confinamento de um leitor bash (o passo que extrai o corpo do frontmatter) | cópia do `pre-push` | o leitor volta a ler o `runtime:` da prosa: o valor lido no CASO 3 do corpus deixa de ser vazio | `[4]` |
| M2 — trocar o terminador de bloco de um leitor bash pelo do outro (`/^[a-z_]+:/` ↔ `/^[^ ]/`) | cópia de `lib/forge-runtime.sh` | o valor lido no caso "chave de topo com hífen" muda de vazio para o valor do bloco seguinte | `[4]` |
| M3 — neutralizar a leitura de `sdd.default_scale` em `spec-new.sh` | cópia de `spec-new.sh` | com `default_scale: 4` declarado, o change nasce com `scale: 2` | `[10]` |
| M4 — acrescentar uma linha a uma das duas cópias do `FORGE.md` | cópia do par | `cmp` passa a divergir | `[11]` |

**Regra de higiene das quatro, imposta pelo gate novo de §6.4 e repetida aqui porque é onde ela é fácil de violar:** nenhuma delas usa `$` do lado direito de um `perl -0pi` sem escape. M1 e M2 operam sobre corpos de `awk` cheios de `$0` — é exatamente o terreno de LDG-0164. O implementador **mede** cada mutação antes de escrever a linha da matriz: aplica, observa o efeito no valor lido, e só então declara.

### 8.2 Gate B — cenários novos em `tests/w204-ordinal-root-resolution-gate.sh` (LDG-0171)

O `w204` já existe e já é o gate da resolução de raiz; LDG-0171 é a metade dele que ficou aberta. Os cenários entram lá e **não consomem ordinal**.

**A numeração, medida antes de escolher.** `grep -nE '^echo "\[' tests/w204-ordinal-root-resolution-gate.sh` devolve quatro cenários — `[1]` (linha 87), `[2]` (96), `[3]` (110) e `[4]` (138) —, então os seis novos são **`[5]` a `[10]`**, e não uma numeração paralela. O cabeçalho do `w204` (linhas 26-40) enumera os cenários em prosa e **também** é editado no mesmo commit: um cabeçalho que descreve quatro cenários num arquivo que roda dez é o mesmo tipo de literal envelhecido que a onda combate.

| # | O que assere | Como falha HOJE |
|---|---|---|
| `[5]` | **Propriedade** — todo sítio de `SCRIPT_DIR/../..` em `template/.forge/scripts/` está classificado como C1, C2 ou C3 pelo varredor, e nenhum fica sem classe | vermelho: não há varredor, e 37 dos 38 sítios nunca foram classificados |
| `[6]` | **Piso NOMINAL do universo** — o varredor encontra, cada um pelo nome do arquivo, os sítios que a onda **não** migra (os C1) e os que ela migra; o **número** é impresso como contador de controle e nunca comparado contra literal, e o gate reprova em zero pelo `lib/gate-universe.sh`. Um piso escrito como "38" ficaria vermelho no primeiro script novo, e um escrito como "≥38" ficaria vermelho quando a migração de C2/C3 tirar sítios da forma antiga — as duas saídas são a armadilha A | vermelho por ausência |
| `[7]` | Nenhum sítio classificado **C2** continua com a subida fixa, exceto os da isenção auditável, e cada isenção tem motivo escrito | vermelho: `check-suite-wiring.sh`, `ingest-legacy.sh`, `publish-docs.sh` e `spec-new.sh` têm |
| `[8]` | **Comportamento, pelo canal real** — `check-suite-wiring.sh` invocado sem `FORGE_ROOT` a partir do layout de dogfood examina o universo do **repositório**, não o de `template/`. A asserção é a **identidade** entre as duas invocações (com e sem `FORGE_ROOT`), não um número de pontos de entrada: cravar "3" envelheceria no primeiro workflow de CI novo | vermelho, medido em §5.1: 5 pontos de entrada contra 3, e rc 0 nos dois |
| `[9]` | Nenhum sítio **C3** resolve o `ROOT` ignorando `FORGE_ROOT` | vermelho: três sítios |
| `[10]` | **Mutação** — reverter um sítio C2 para a subida fixa faz `[8]` reprovar; restaurar por `git checkout --` (o padrão de `w204[4]`) faz voltar | — |

O `[8]` é o cenário que importa, porque é comportamento observado pelo canal real e não leitura de fonte: sem ele, `[5]` e `[7]` seriam um gate de estilo. O contrafactual dele está medido e colado em §5.1. Sobre o `[10]`: o `w204[4]` de hoje muta o **arquivo rastreado real** e restaura por `git checkout --` sob `trap` — é o padrão da casa naquele gate, e o `[10]` o segue em vez de inventar um segundo padrão de mutação dentro do mesmo arquivo.

### 8.3 Gate C — higiene de mutação (LDG-0164)

| # | O que assere | Como falha HOJE |
|---|---|---|
| `[1]` | **Propriedade** — nenhuma substituição de `perl -pi`/`-0pi` em `tests/` interpola variável do perl no lado direito. O gate **imprime** quantas examinou e **nunca** compara esse número contra literal (§6.3: três extratores deram três denominadores sobre a mesma árvore) | verde no conteúdo (zero suspeitos, §6.3) e **vermelho por ausência do detector** |
| `[2]` | **Contrapositiva executada** — sobre uma cópia em `$TMPDIR` com o defeito de LDG-0164 replantado, o detector acusa, nomeando arquivo, linha e as variáveis | vermelho por ausência; o efeito está medido em §6.3 |
| `[3]` | Nenhuma expressão de mutação atribui variável do perl (a premissa de soundness) | verde no conteúdo, vermelho por ausência |
| `[4]` | `$1`–`$9`, `${N}` e `$ENV{…}` **não** são acusados — cenário pareado, com uma mutação legítima do corpus real | vermelho por ausência; sem ele o detector seria um gerador de falso positivo, e o contrafactual está em §6.2 |
| `[5]` | A substituição, aplicada a uma sonda derivada do lado esquerdo, não produz alvo insintático (`bash -n` / `node --check`) | vermelho por ausência |
| `[6]` | **Contador de controle** — zero substituições examinadas reprova pelo `lib/gate-universe.sh` | vermelho por ausência |
| `[7]` | **Terceiro estado** — sem `perl` no `PATH`, o gate não devolve verde | vermelho por ausência |
| `[8]` | **Mutação do próprio detector** — remover a exclusão de capturas faz `[4]` reprovar; remover a detecção de `$` faz `[2]` reprovar; restaurar por `cmp` faz os dois voltarem | — |

O `[8]` é a prova de mutação do detector sobre si mesmo, e os dois contrafactuais estão medidos: com a exclusão removida, o `$1` do `w206` produz `  : # MUTATED` em vez de `$1: # MUTATED`; com a detecção removida, a cópia replantada do `w195` deixa de acender.

### 8.4 Gate D — grafo commitado × regeneração (LDG-0176)

| # | O que assere | Como falha HOJE |
|---|---|---|
| `[1]` | **Propriedade** — o conjunto de ids do `graph.json` commitado é igual ao da regeneração sobre o conteúdo commitado | **vermelho**: 54 ids só na regeneração (§7.1) |
| `[2]` | A reprovação **nomeia** ids, nos dois sentidos, e diz o comando que regenera | vermelho por ausência |
| `[3]` | **Direção inversa** — id presente no commitado e ausente da regeneração também reprova; exercitado injetando um id sintético na cópia do grafo | vermelho por ausência; é o desfecho 3 de §7.4, hoje com zero ocorrências reais, o que o torna invisível sem cenário próprio |
| `[4]` | **Sinal positivo de que a regeneração rodou** — a bancada não pode aprovar lendo o `graph.json` que viajou junto com a cópia | vermelho por ausência; a armadilha está medida em §7.3 |
| `[5]` | **Contador de controle** — regeneração com zero nós reprova por vacuidade | vermelho por ausência |
| `[6]` | **Terceiro estado** — sem `node`, ou com o engine reprovando, ou com `git archive HEAD` em 128 (repositório sem commit), o gate não é verde nem vermelho | vermelho por ausência; o rc 128 está medido em §7.4 |
| `[6b]` | **Terceiro estado, artefato ilegível** — `graph.json` commitado truncado (⇒ `SyntaxError` no `JSON.parse`) e `graph.json` válido **sem a chave `nodes`** (⇒ leitura `undefined`): nos dois o gate nomeia a forma que encontrou e não é verde nem vermelho, e em nenhum deles ele morre com stack trace nem cai no `[5]` reprovando por vacuidade sobre o artefato errado | vermelho por ausência; as duas formas estão medidas no desfecho 9 de §7.4 |
| `[7]` | **Mutação** — remover um id do `graph.json` da cópia faz `[1]` acusar aquele id; acrescentar um id inexistente faz `[3]` acusar; restaurar por `cmp` faz os dois voltarem | — |

O `[7]` opera sobre **cópia** do grafo em `$TMPDIR`. Mutar o `.forge/graph/graph.json` rastreado repetiria LDG-0175 literalmente, dentro da onda que existe, entre outras coisas, para não repetir esse tipo de coisa.

**Ponto de atenção do `[1]`: ele é o único cenário desta onda cuja cor depende de a implementação ter regenerado o grafo.** A ordem de implementação (§13) põe a regeneração **por último**, depois de todos os arquivos novos existirem — inclusive os três gates e o lib. Regenerar no meio produz um grafo que já nasce defasado dos arquivos que a própria onda ainda vai criar.

---

## 9. Onde entra cada camada de teste

**PBT — aplica-se, em um ponto, e com espaço de entrada de verdade.** O leitor do frontmatter é um parser, e a invariante 5 do plano nomeia parser explicitamente. A propriedade: *para todo documento gerado com um frontmatter bem formado e um corpo arbitrário, o valor que os leitores bash devolvem para uma chave de `runtime:` é igual ao que o leitor canônico devolve.* O gerador varia o que importa e o que o corpus de exemplos escolhidos a dedo não cobre: presença e ausência de bloco `runtime:` no frontmatter, presença de um bloco homônimo no corpo, chaves de topo com caracteres fora de `[a-z_]`, comentários de fim de linha, valores com `:` embutido, indentação de dois e de quatro espaços, e o documento sem delimitador de fechamento. O K de iterações é decidido pelo implementador contra o orçamento de tempo do gate, e o gate publica quantos casos gerou — um PBT sem contador é a mesma vacuidade de sempre.

**Teste de contrato — aplica-se em três fronteiras publicadas.** (a) `forge.schema.json`, tocado pelas decisões de §3.3: as seis chaves continuam aceitas e nenhuma vira `additionalProperties` proibida — a assimetria de §3.2 exige que isso seja assertado, não presumido. (b) `graph.json`: o gate D é, por natureza, um teste de contrato entre o artefato e o gerador. (c) O par `FORGE.md`/`templates/FORGE.md`, cuja identidade é o contrato que `[11]` prende.

**Integração — é onde metade desta onda vive.** LDG-0152, LDG-0151 e LDG-0171 são todos defeitos de **fiação**: a função existe e ninguém a chama (as seis chaves), ou a função é chamada com o argumento errado (a raiz). Teste unitário sobre `forge_get_runtime` nasce verde e não diz nada; `[10]` do gate A e `[8]` do gate B exercem o caminho real, do gatilho ao efeito.

**E2E — aplica-se num ponto, e é `[5]` do gate A**: o `pre-push` num repositório git de verdade, com `core.hooksPath` absoluto e `git push` para um remoto `--bare`, que é a bancada que `w190` já tem e que `rules/testing/gate-delivery-channel.md` exige. Um gate que invocasse o hook direto provaria o alvo e não o canal.

**O que NÃO se aplica, com justificativa medida.** Gate de fase `pre-deploy`/`post-deploy`: nenhuma peça desta onda produz artefato implantável, e `run-gates.sh --phase` reprova por `universo-vazio` quando nenhum gate declara a fase — invariante 18, e a onda não fia chamada nova de fase. Teste de performance: **não se aplica, e a razão é uma medição, não uma preferência.** O gate mais caro da onda é o D, e §7.3 mostra o mesmo comando de montagem variando 52% entre duas execuções consecutivas na mesma máquina. Uma asserção de tempo sobre um número assim é um gerador de falso-vermelho em CI compartilhado. O que a onda entrega no lugar é um **teto declarado em letra** no cabeçalho do gate D, medido pelo implementador na máquina dele com o comando colado ali, e conferido de novo quando alguém suspeitar — nunca assertado pela suíte.

---

## 10. Retrocompatibilidade — o que já está instalado e o que quebra

| Mudança | O que já está instalado no campo | Quebra? |
|---|---|---|
| Confinamento dos leitores bash ao frontmatter | os treze `.forge/FORGE.md` medidos, todos com `runtime:` dentro do frontmatter (§2.4) | **não**, no ecossistema medido. Quebra um `FORGE.md` sem frontmatter — que `tools/validate-forge.mjs:40` já reprova e que `sync-adapters.mjs` e `graph-layers.mjs` já leem como `{}` |
| Linha nova do `pre-push` para `FORGE.md` sem frontmatter | nenhum gate compara a saída do `pre-push` por golden (§2.7) | **não** |
| `handoff-gen.sh` passa a depender de `lib/forge-runtime.sh` | o lib existe desde a 0.11.0; consumidores anteriores a ela não o têm | **degrada, mas só porque a onda o especifica** — não de graça. Medido (§2.6): sob o `set -euo pipefail` de `handoff-gen.sh:10`, um `source` incondicional de lib inexistente sai **rc 1**; a guarda que já existe no arquivo é sobre o `FORGE.md` ausente, não sobre o lib. A onda declara a propriedade (rc 0 e campos em `n/d` sem o lib) e o gate A `[6b]` a prova. Sem isso, esta linha seria falsa e a onda trocaria um leitor duplicado por uma recusa nova |
| Fiação de `default_scale`, `default_rigor`, `archive_policy`, `evals_root` | os treze `FORGE.md`/`forge.yaml` declaram os valores de fábrica | **não**: a fiação lê a chave e cai no literal de hoje quando ela falta, e os valores de fábrica são idênticos aos literais |
| Fiação de `default_mode` + troca do valor de fábrica para `greenfield` | valor de fábrica hoje é `brownfield` | **muda comportamento** para um projeto brownfield sem `product/current` nem `docs/product` que tenha mantido o valor de fábrica (§3.4). Nomeado, reversível por uma linha, e vai no `CHANGELOG.md` |
| `sdd.human_gate_required` deprecada no lugar | `required` no schema, presente nos treze | **não**: nada é removido |
| Paridade dos dois `FORGE.md` | `templates/` é `ENRICHABLE` em `bin/forge.mjs:352`, então `forge update` **preserva** a cópia local de quem a editou | **não**: a paridade é do template, na fonte. Consumidor que editou a sua cópia continua com ela |
| `check-mutation-hygiene.sh` novo em `template/.forge/scripts/` | nada o declara em `runtime.gates` de ninguém | **não**: nasce como gate disponível, e declará-lo é decisão de cada projeto. **Neste repositório a fiação é por `tests/`, não por `runtime.gates`** — medido: a raiz não tem `core.hooksPath` configurado, não tem `.forge/scripts/`, e o `.forge/FORGE.md` da raiz não tem bloco `runtime:` algum (só `forge_version` e `codegraph.include_paths`, com fechamento na linha 6). Declarar `runtime.gates` ali antes da Fase 1 criaria declaração sem executor. A palavra "assertada" saiu desta linha porque não havia cenário que a sustentasse |
| Migração dos sítios C2/C3 para `forge_worktree_root` | `lib/forge-root.sh` existe desde a correção de LDG-0171 no `gate-ordinal.sh` | **recusa nova** em consumidor que não tenha o lib, exatamente como `gate-ordinal.sh:38-41` já faz. É o motivo de a migração ser **por sítio classificado**, e não pelos 38 (§5.3) |
| Gate D no ar | — | **custo recorrente**: todo PR que muda o universo do grafo regenera (§7.5) |

---

## 11. Alocação de ordinal, e o inventário que esta onda envelhece

Medido nesta rodada: o máximo em `tests/` local é **w207** (`ls tests/ | grep -oE '^w[0-9]+' | sed 's/w//' | sort -n | tail -3` devolve `205`, `206`, `207`). `git ls-remote --heads origin` devolve quatro refs: `develop` em `3bb67f5`, `main` em `49bc97d`, `wip/deepspec-run-manifest-ldg-0165` e `wip/upgrade-safety-ldg-0131`. Há também a branch local `feat/fase1-dogfood-completo` desta rodada, e as demais ondas em voo pedem ordinal ao mesmo tempo.

A onda precisa de **três** ordinais — gates A, C e D — e **não aloca nenhum**. Invariante 10: o ordinal é alocado pelo orquestrador, uma vez, no momento de escrever o arquivo, conferido contra `origin/*` **e** contra as branches em voo. O gate B não consome ordinal: os seis cenários entram no `w204`.

**O inventário do `README.md` envelhece nesta onda, e a invariante 14 manda dizer qual linha.** `tests/w200-readme-inventory-gate.sh` reconfere a tabela `## 📁 Estrutura` contra `find "<root>/<dir>" -type f ! -name 'README.md'`. Executado nesta rodada, as sete linhas batem hoje:

```
$ for d in agents commands contracts skills rules schemas scripts; do
    echo "$d $(find template/.forge/$d -type f ! -name 'README.md' | wc -l | tr -d ' ')"; done
agents 47   commands 56   contracts 5   skills 20   rules 50   schemas 27   scripts 136
$ grep -nE '\((1[0-9][0-9]|[0-9]+)\)' README.md   # linhas 228-235 da seção "## 📁 Estrutura"
228:├── agents/  (47)   229:├── commands/ (56)   232:├── skills/   (20)
233:├── rules/   (50)   234:├── schemas/ (27)     235:└── scripts/ (136)
``` A onda acrescenta `check-mutation-hygiene.sh` a `template/.forge/scripts/`, e possivelmente o varredor de §5.2 — cada arquivo novo ali **exige** a atualização de `scripts/ (136)` no `README.md`, no mesmo PR, sob pena de `w200[1]` vermelho. A definição de pronto carrega essa linha nominalmente, e ela é o motivo de a especificação **não** escrever o número final: ele depende de quantos arquivos o implementador criar, e escrever `137` aqui seria plantar o defeito que a invariante nomeia.

**E o `README.md` tem uma SEGUNDA contagem que esta onda envelhece — o badge —, e a primeira redação a esqueceu.** `tests/w200-readme-inventory-gate.sh:258-271` é o cenário `[6]`, e o predicado dele é explícito: `badge_n` vem de `grep -oE 'gates-[0-9]+' README.md | head -1 | cut -d- -f2` e `arvore_n` de `find "$WS/tests" -maxdepth 1 -name '*-gate.sh' | wc -l`. Medido nesta rodada, os dois devolvem **131** e o cenário está verde. A onda cria **três** arquivos `tests/w<N>-*-gate.sh` (gates A, C e D), então o badge da linha 12 do `README.md` tem de ir a **134** no mesmo PR, sob pena de `w200[6]` vermelho. A especificação **não** escreve `134` como asserção — ela escreve o comando que mede e a regra "o badge é a contagem da árvore" —, mas escreve o número aqui como testemunha de data para que o implementador saiba de quanto é o salto que ele deve conferir. Vale a mesma disciplina da contagem de `scripts/`: quem conta é o `find`, não este documento.

**Os gates rastreados que esta onda toca ou cujas fixtures ela edita**, todos nomeados por medição e não por suposição:

| Gate | O que muda | Por quê |
|---|---|---|
| `tests/w135-push-refs-export-gate.sh` | fixture da linha 34 ganha delimitadores `---` | §2.5, contrafactual medido |
| `tests/w97-hook-portability-gate.sh` | fixture da linha 33 ganha `---` | §2.5 |
| `tests/w151-heavy-mutex-gate.sh` | fixtures das linhas 924 e 1186 ganham `---` | §2.5 |
| `tests/w147-hook-delegation-gate.sh` | fixture da linha 83 tem o bloco `runtime:` **movido** para dentro do frontmatter | §2.5, contrafactual pelo canal real: rc 1 ⇒ rc 0 sem confinamento da fixture |
| `tests/w204-ordinal-root-resolution-gate.sh` (cabeçalho) | as linhas 26-40 passam a enumerar dez cenários | §8.2 |
| `tests/w204-ordinal-root-resolution-gate.sh` | ganha seis cenários | §8.2 |
| `tests/w200-readme-inventory-gate.sh` | **não** é editado; o `README.md` é | §11 |
| `tests/w192-declared-switch-has-reader-gate.sh` | **não** é editado; a lista `SWITCHES` continua com as duas de enforcement | §3.5 |
| `tests/w20-spec-gate.sh` | **não** é editado; a fixture de 139-143 não assere valores | §3.5 |
| `tests/w13-init-gate.sh` | **não** é editado; `[1]` continua verde com a paridade | §4.2, premissa conferida |

---

## 12. O que a onda explicitamente NÃO faz

**Não cria um lib de leitura de frontmatter em bash.** Decisão de §2.6, com as três medições que a sustentam. O que a onda entrega é a **concordância provada**, não o arquivo compartilhado.

**Não reverte a assimetria de `pentest_cfg`.** `pentest-ops.sh:333-338` a decidiu com justificativa escrita; revertê-la exige medir a retrocompatibilidade do bloco `pentest:` fora de frontmatter no campo, e essa medição não foi feita. A onda a declara como isenção auditável, com motivo.

**Não remove nenhuma chave de `forge.schema.json`.** §3.2 mede por que remover é mais caro do que parece.

**Não migra `doctor.sh:44`.** §5.3: o sítio migra depois da Fase 1, que decide o que o doctor deve encontrar na raiz.

**Não migra os 38 sítios de `SCRIPT_DIR/../..`.** Migra os classificados C2 e C3, e assere a classificação dos C1 em vez de mexer neles. Migrar um C1 introduz o defeito.

**Não migra as 90 linhas de `perl -pi` para um harness de mutação.** §6.4: a varredura devolveu zero suspeitos, e tocar quarenta gates para fechar um item cuja incidência é zero troca risco por nada.

**Não fecha a classe maior de mutação-fantasma** — mutação sintaticamente válida, byte-diferente e semanticamente inerte. §6.4 diz por que não é decidível estaticamente e abre item próprio.

**Não conserta o `generated_at` do `graph.json`.** §7.5 abre item próprio.

**Não regenera `.forge/graph/report.md`, `cache/fingerprints.json` nem `cache/summaries.json` como objeto de asserção.** O gate D compara ids de `graph.json`. Os outros três são regenerados junto porque o engine os escreve, e a onda os commita, mas nenhuma asserção fala sobre eles — asserir sobre `summaries.json` exigiria decidir o que significa um summary `stale`, e são 310 hoje.

**Não toca `.forge/HANDOFF.md`, `.forge/ledger/`, `.forge/liaison/` nem qualquer repositório consumidor.** As leituras dos treze `FORGE.md` de `~/Documents/projects` foram somente-leitura.

**Não declara `check-mutation-hygiene.sh` no `runtime.gates` de consumidor nenhum — nem no deste repositório.** Medido (§10): a raiz não tem `core.hooksPath`, não tem `.forge/scripts/` e o `FORGE.md` dela não tem bloco `runtime:`. A fiação dos três gates novos na suíte deste repositório é por `tests/`, que é o que `check-suite-wiring.sh` confere; `runtime.gates` na raiz é assunto da Fase 1, não desta onda.

**Não toca a assimetria dos vocabulários de `default_mode` além de alargar o enum com `feature-only`.** §3.4: reconciliar os dois vocabulários de verdade é decisão de contrato e vira item de ledger próprio.

---

## 13. Ordem de implementação e definição de pronto

A ordem não é preferência: cada passo depende do anterior por medição.

1. **Gate C primeiro** — o detector de higiene de mutação. Ele nasce antes das outras três provas de mutação porque é ele que as valida. Escrever M1 e M2 do gate A sem ele é escrever mutação sobre corpos de `awk` cheios de `$0` sem rede.
2. **Gate B** — o varredor de raiz e os seis cenários do `w204`. Independente dos demais, e é o que produz a classificação que a migração C2/C3 usa.
3. **Migração dos sítios C2 e C3**, com o `w204` já vermelho antes e verde depois.
4. **Gate A, na ordem interna: `[4]` antes de tudo.** A execução diferencial é o vermelho que prova a divergência; ela precisa estar montada antes de qualquer confinamento, ou o confinamento vira mudança sem prova.
5. **Confinamento dos cinco sítios bash**, com as **cinco** fixtures de `w135`, `w97`, `w151` (duas) e `w147` editadas **no mesmo commit**. A do `w147` é **movimento** do bloco `runtime:` para dentro do frontmatter, não acréscimo de `---`. Editá-las depois deixa a suíte vermelha entre dois commits, e a invariante 9 diz que verificação é serializada.
6. **A linha nova do `pre-push`** (§2.7), com a distinção dos três estados provada.
7. **`handoff-gen.sh` perde o `fm_field`.**
8. **As seis chaves**: fiação em `spec-new.sh`, `lib/validate-archive.mjs` e a resolução de `evals_root`; **alargamento do enum de `default_mode` com `feature-only`** e a recusa nomeada para valor não mapeável (§3.4); troca do valor de fábrica de `default_mode` e do comentário da linha 12 nos dois `FORGE.md`; comentário de deprecação de `human_gate_required`.
9. **Paridade dos dois `FORGE.md`** — depois do passo 8, porque o passo 8 edita o frontmatter dos dois e fazer a paridade antes obrigaria a refazê-la.
10. **Gate D**, escrito e observado vermelho contra o grafo de hoje.
11. **`README.md`**: contagem de `scripts/` atualizada **e o badge de gates** (linha 12) atualizado — as duas contagens, não uma; `w200` tem cenário para cada.
12. **Regeneração do grafo, por último**, quando todos os arquivos novos já existem, e commit dos quatro arquivos de `.forge/graph/`.
13. **`CHANGELOG.md`**, com a mudança de comportamento de `default_mode` (§3.4) e o custo recorrente do gate D (§7.5) escritos como o consumidor os sente.

**Definição de pronto — cada linha verificável por comando, não por relatório:**

- Os três gates novos e o `w204` passam, cada um imprimindo o próprio contador de controle com o número que examinou.
- `w200[1]` (contagem de `scripts/`) e `w200[6]` (badge de gates) passam, com os dois números do `README.md` conferidos pelo `find` do próprio gate — nunca pelo número escrito nesta especificação.
- `w135`, `w97`, `w151`, **`w147`**, `w13`, `w20`, `w60`, `w101`, `w63`, `w152`, `w190`, `w191`, `w192`, `w199`, `w200`, `w204` e `plugin-sync-gate` passam — a lista nominal de §11, mais os que exercitam `pre-push` (`w152`, `w190`, `w191`) e `handoff-gen` (`w60`, `w101`, `w63`, medidos por `grep -rln 'handoff-gen' tests/*.sh`), conferida gate a gate contra o baseline e **não** por "a suíte passou". O `w147` está nesta lista **nominalmente** porque o confinamento o derruba pelo caminho pior (§2.5) e uma lista que o omitisse já reprovou uma revisão desta especificação.
- `npm run build:plugin` roda e `plugin-sync-gate[1]` passa. **Medido que a onda não deveria mexer no plugin** — `plugin-build.mjs` gera a partir de `--commands template/.forge/commands` e a onda não edita comando nenhum —, mas a disciplina do repositório é rodar o build e deixar o gate decidir, não deduzir do escopo que ele está sincronizado; o próprio `plugin-sync-gate.sh:23` prescreve esse comando na mensagem de reprovação.
- `bash -n` limpo em todo `.sh` tocado; nenhum uso de `declare -A`, `${var,,}`, `${var^^}`, `mapfile` ou `readarray` (bash 3.2, invariante 8).
- `cmp -s template/.forge/FORGE.md template/.forge/templates/FORGE.md` devolve 0.
- O detector de §6.3 devolve zero suspeitos sobre `tests/` e acusa sobre a cópia com o defeito replantado.
- A comparação de ids do gate D devolve conjuntos iguais; o número de nós é **impresso**, nunca assertado contra literal.
- `node tools/validate-forge.mjs` passa, com as seis chaves ainda no schema e com `feature-only` acrescentado ao enum de `default_mode`. **O comando foi executado nesta rodada contra a árvore de hoje** e devolve rc 0 com catorze linhas `OK`, incluindo `OK FORGE.md frontmatter vs forgeFrontmatter` — prescrever sem executar é a armadilha E.
- Os seis itens do ledger transitam para `resolved` com a evidência do padrão dos 85 anteriores; os dois itens novos de §6.4 e §7.5 são abertos no mesmo commit, com as medições deste documento anexadas.
- Nenhum texto de coautoria de IA em commit, PR ou issue; PR contra `develop`.

---

## 14. O que esta onda registra e não fecha

**O `forge.schema.json` viaja para todo consumidor e nenhum código do consumidor o compila** (§3.1, alínea (a)). Isso é maior que LDG-0151 e vale para o schema inteiro, não para seis chaves. A contagem foi **remedida nesta rodada**, com o comando colado:

```
$ for f in template/.forge/schemas/*.json; do b="$(basename "$f")";
    echo "$(grep -rl "$b" template/.forge/scripts template/.forge/hooks bin/ 2>/dev/null | wc -l | tr -d ' ') $b"; done \
  | sort -n
0 adapter-capability … 0 archive-state-machine … 0 forge.schema.json … 0 waves.schema.json   (19 com zero)
1 alerts-as-code … 1 approvals … 1 data-classification … 1 graph … 1 red-evidence
2 ledger.schema.json   2 spec-manifest.schema.json
--- schemas com ZERO leitores embarcados: 19 de 26
```

Dezenove de vinte e seis, reproduzido; o número é testemunha de data e o item de ledger é o entregável, não uma asserção. A leitura de `lib/validate-spec.mjs:58` explica por quê: as regras são *"mirror of spec-manifest.schema.json"*, reimplementadas determinísticamente em vez de compiladas. Isso pode ser desenho legítimo (só três libs usam `ajv`, e `ajv` é dependência de desenvolvimento) ou pode ser uma segunda LDG-0008 em escala maior. **Eu não o medi o suficiente para afirmar**: o `grep` não vê um carregador que monte o caminho do schema por concatenação, e conferi apenas um caso (`validate-spec.mjs`). Vira item de ledger com esta ressalva escrita, não uma afirmação.

**`doctor.sh:44` é o único sítio que usa `$(dirname "$0")` em vez de `${BASH_SOURCE[0]}`** e, portanto, resolve errado se o script for `source`ado. Não medi se algum caminho o sourceia. Entra na nota de §5.3.

**A classe maior de mutação-fantasma** (§6.4) e **o `generated_at` que suja a árvore a cada regeneração** (§7.5) viram itens próprios, cada um com a medição desta sessão anexada.

**Os dois vocabulários de `mode`** (§3.4). O enum de `sdd.default_mode` no `forge.schema.json` é, valor por valor, o conjunto de `--type` de `spec-new.sh:37`, e não o de `--mode` de `spec-new.sh:50`; o `FORGE.md` que o harness distribui documenta os cinco na margem da linha 12. Esta onda alarga o enum com `feature-only` (medidamente seguro) e faz `spec-new.sh` recusar com mensagem nomeada os três valores que ele não aceita, mas **não** reconcilia os dois vocabulários: estreitar o enum invalidaria documento do campo pela mesma restrição que §3.2 mede, e decidir qual dos dois é o vocabulário canônico de `mode` é decisão de contrato. Vira item de ledger com a medição dos seis valores executados anexada.

---

## 15. Respostas ao veredito da revisão 1

Cada item abaixo foi **remedido por comando meu** antes de ser aceito. Onde a medição do revisor procedeu, digo que procedeu e o que mudou; onde ela não procedeu, refuto com o comando. Refutar com medição é legítimo, e este documento já refutou o próprio registro do ledger em §2.1.

### 15.1 Os quatro bloqueadores

**BLOQUEADOR 1 — o `w147[4]` e o predicado da guarda. PROCEDE, integralmente, e é o achado mais grave da revisão.** Remedi por conta própria, nos dois estados, pelo canal real do hook: bancada em `$TMPDIR` com `cp -R template/.forge` num `git init`, a fixture literal de `w147:83`, e o `pre-push` de produção contra uma cópia dele com o extrator de frontmatter injetado imediatamente antes de `fm_field`. Controle: `rc=1`, `pre-push BLOQUEADO: gate 'gate-fantasma' …`. Contrafactual: `rc=0`, `pre-push OK`, e a saída **não contém** a string `gate-fantasma`. Ao nível de leitor, `gates_key_present` vai de `y` para vazio e `gates_inline_raw` de `gate-fantasma` para vazio. As duas correções exigidas estão feitas: (a) §2.5 foi **reescrita com o predicado certo** — "bloco `runtime:` fora do frontmatter", não "fixture sem `---`" —, a varredura foi refeita sobre os treze arquivos de `tests/` que mencionam `FORGE.md` e `runtime:`, o `w147` entrou na tabela de §2.5, na de §11 e na lista nominal da definição de pronto de §13; (b) §2.7 teve o **predicado da guarda trocado** para "existe uma linha `^runtime:` fora do frontmatter e o frontmatter não a contém", e o cenário `[5]` do gate A passou a exigir os **dois** casos.

**BLOQUEADOR 2 — a colisão de enums de `default_mode`. PROCEDE.** Remedi: `node -e` sobre o schema devolve `{"enum":["greenfield","brownfield","feature","bugfix","refactor"]}`, `sed -n '50p' spec-new.sh` mostra `case "$MODE" in greenfield|brownfield|feature-only`, e os seis valores executados contra o script real numa bancada dão `rc=0, 0, 2, 2, 2, 0` na ordem `greenfield, brownfield, feature, bugfix, refactor, feature-only`. **Acrescento uma medição que o revisor não trouxe e que muda o diagnóstico:** o enum do schema é, valor por valor, o conjunto de `--type` (`spec-new.sh:37`), e o `FORGE.md` que o harness distribui **documenta os cinco na margem da linha 12**. Não é uma divergência que apareceu por deriva; é o vocabulário errado copiado uma vez. A decisão foi aberta e refeita em três partes (§3.4), e a terceira saída que o revisor listou — restringir o enum — foi **descartada por medição, mas a sua vizinha foi adotada**: estreitar invalida documento do campo, **alargar não pode**, e alarguei com `feature-only` conferindo com `ajv` que o veredito dos treze documentos do campo não muda em nenhum. Valor não mapeável vira recusa nomeada, nunca mapeamento silencioso e nunca queda para a heurística. O cenário `[10]` ganhou os pares `[10b]` e `[10c]`.

**BLOQUEADOR 3 — o piso de seis e o denominador ambíguo. PROCEDE.** Remedi o censo com um predicado definido em letra antes do número — *autômato `awk` cuja regra ancora em `^runtime:`* — e o comando que o materializa devolve **nove** autômatos em quatro arquivos, não seis nem sete: o `pentest-ops.sh` tem **quatro**, e a tabela de §2.1 nomeava dois. O piso do cenário `[3]` deixou de ser um número e passou a ser o **conjunto nominal PÓS-onda** (os oito que sobrevivem, `handoff-gen.sh` fora porque o passo 7 o remove), com o número impresso como contador de controle e nunca comparado contra literal. As três formas incompatíveis que o revisor apontou — "sete linhas bash", "os cinco sítios não confinados", "cinco dos seis não confinam" — foram reconciliadas: são **nove** autômatos, dos quais **seis** não confinam (linhas 1 a 6 da tabela), **cinco** passam a confinar e **um** é a isenção declarada.

**BLOQUEADOR 4 — a retrocompatibilidade não medida do `handoff-gen.sh`. PROCEDE.** Remedi: `handoff-gen.sh:10` é `set -euo pipefail`, e numa bancada mínima em `$TMPDIR` um `. "$ROOT/.forge/scripts/lib/forge-runtime.sh"` incondicional sobre lib inexistente sai `rc=1` com `No such file or directory` sem chegar ao fim do script; a mesma bancada com guarda e stub sai `rc=0`. A guarda que §2.6 citava (`[ -f "$FORGE_MD" ]`, linha 43) é sobre o **`FORGE.md`**, não sobre o lib — o revisor está certo, e a linha de §10 estava afirmando proteção que não existia. §2.6 passou a **declarar a propriedade** (rc 0 e campos em `n/d` sem o lib), a linha de §10 foi reescrita, e o gate A ganhou o cenário `[6b]`, que é vermelho contra a implementação ingênua.

### 15.2 As medições que não reproduziram

**Remedidas — o comando está colado ao lado do número na seção citada:**

| Medição | Onde | O que a remedição deu |
|---|---|---|
| Os cinco de treze `FORGE.md` que reprovam contra `forgeFrontmatter`, nenhum por `gates` | §3.1(b) | **Confirmado por medição própria com `ajv`**, não mais citado do cabeçalho do `w199`: 5 reprovam, 0 por `gates`; quatro por `/runtime must NOT have additional properties` e o dogfood por `required` ausente |
| Os 19 de 26 schemas sem leitor embarcado | §14 | **19 de 26**, reproduzido com o laço colado; segue sendo item de ledger com a ressalva, nunca asserção |
| O grafo commitado × regeneração (256/51, 310/59, 114/150, 0 e 54) | §7.1 | **Todos reproduzidos**, agora com os três comandos colados: leitura do commitado, `git archive HEAD` + `graph-build.mjs`, e a comparação de conjuntos. Acrescentei "dos 54 só-no-regenerado, 36 em `tests/`" |
| O determinismo do conjunto de ids | §7.2 | **`ids-sha=571b9a9116e6817a` nas duas rodadas**, o mesmo valor da redação anterior, com o laço colado |
| As quatro regexes JavaScript serem a mesma | §2.4 | **Confirmado**: `grep -rho … \| sort -u` devolve **uma** forma. E encontrei o que o revisor não tinha como ver: a regra bash "confinada" (`pentest_frontmatter_of`) **não** é a mesma, e a divergência está medida no caso `----` |
| As fixtures de `w135`/`w97`/`w151`, campo a campo | §2.5 | **Remedidas campo a campo**, com `gates_key_present` incluído — e foi aí que apareceu que o `w135` perde também `[1]` e a linha 152 de `[3]`, não só as linhas 149-150 |
| O contador do `README.md` | §11 | **As sete linhas batem**, com o `find` e o `grep` do `README.md` colados |
| Os seis cenários novos do `w204` | §8.2 | **Remedido o que faltava**: `grep -nE '^echo "\['` devolve quatro cenários existentes, então os novos são `[5]`–`[10]`, e o cabeçalho do `w204` (linhas 26-40) entra na lista de arquivos editados |
| A varredura de `perl -pi` | §6.3 | **Remedida com o detector colado**: `linhas=89 substituicoes=94 suspeitos=0`. O veredito (zero) reproduz; o denominador **não**, e a seção agora explica por quê e o converte em contador de controle |

**Removidas — porque não reproduzem e um número que não reproduz não fica:**

| Medição | Onde estava | Por que saiu |
|---|---|---|
| Os três tempos de montagem (52.635 / 6.300 / 4.216 ms) e os pares montagem+regeneração | §7.3 e §9 | **Remedidos e descartados por não reproduzirem nem na mesma máquina**: `git archive HEAD \| tar -x` deu 19.472 ms e 29.692 ms em duas rodadas consecutivas do comando idêntico, 52% de variação. Ficam a contagem de arquivos (1171, estável) e a ordem entre os primitivos; sai a razão entre eles, que oscilou de 2,9× a 4,4× contra o 8,4× afirmado. §9 passou a dizer que teste de performance **não se aplica**, e §7.3 substituiu o número por um **teto declarado em letra** pelo implementador, medido por ele, nunca assertado pela suíte |
| "Os três primitivos produzem o mesmo conjunto de ids" | §7.3 | Medi o conjunto de ids **de um** deles (`git archive`). A afirmação sobre os três virou coluna "a verificar pelo implementador" na tabela |
| "o único não rastreado desta árvore é `.claude/`" | §7.4 | Falsa hoje — os não rastreados são os próprios rascunhos sob `docs/plans/spikes/`. Substituída por uma justificativa que não envelhece: `git ls-files -o --exclude-standard -- 'template/.forge'` devolve **zero**, e o universo do grafo é `template/.forge/**` |

**Nove remediadas contra três removidas.**

### 15.3 As ressalvas de redação

Todas aceitas e corrigidas, cada uma remedida: §3.1(c) (a linha dos defaults é a **22**, e a citação `spec-new.sh:22` que o documento faz depois estava certa); §5.1 (**39** arquivos, não 38 — 38 em `template/.forge/scripts/` mais o `w204`); §5.2 (**seis** sítios no universo dos 38, não quatro; e o critério C1/C2 passou a falar em "dado de PROJETO, lendo ou gravando", que é o que cobre o leitor de `$ROOT/.forge/specs` em dogfood); §10/§12 (a palavra "assertada" saiu — medido que a raiz não tem `core.hooksPath`, nem `.forge/scripts/`, nem bloco `runtime:` no `FORGE.md`, e a fiação dos gates novos é por `tests/`); §2.1 (a abertura diz "quatro leitores **BASH**"); §7.4 (o nono desfecho entrou, com as **duas** formas de ilegibilidade medidas, e a enumeração deixou de se declarar exaustiva).

Sobre §6.2: a inversão apontada estava no sumário que acompanhou a entrega, não no corpo do documento — o bloco colado em §6.2 sempre disse `escrita: [  : # MUTATED]` e `escapada: [$1: # MUTATED]`, que é a direção correta. Nada a corrigir aqui; o defeito era do sumário, e o sumário desta rodada não o repete.

### 15.4 A varredura das cinco armadilhas, no documento inteiro

**A — literal que envelhece em asserção.** Sete sítios revisados. Corrigidos: o piso de seis do gate A `[3]` (virou conjunto nominal pós-onda); o piso do gate B `[6]` (idem, nominal); o denominador do gate C `[1]` (virou contador de controle impresso); o "5 contra 3 pontos de entrada" do gate B `[8]` (a asserção é a **identidade** entre as duas invocações, não o número). Confirmados como já corretos: o `w204[1]` de hoje, que a especificação não toca; e o gate D, que compara **conjuntos de ids** e imprime a contagem sem asseri-la. O contador de `scripts/` do `README.md` estava tratado em §11 desde a primeira redação. **O badge NÃO estava, e a varredura o achou** — este é o achado da própria armadilha A dentro deste documento. `grep -nE '!\[|badge|shields\.io' README.md` devolve cinco badges, e um deles é `gates-131%20passing` na linha 12; `tests/w200-readme-inventory-gate.sh:258-271` o compara com `find tests -maxdepth 1 -name '*-gate.sh' | wc -l`, e os dois valem **131** hoje. A onda cria três gates, então o badge vai a **134** no mesmo PR. §11 e a definição de pronto de §13 passaram a nomear as **duas** contagens do `README.md`, não uma. Os outros quatro badges (CI, licença, versão npm, runtime) não carregam contagem que esta onda mova.

**B — string de produção mudada sem varrer `tests/`.** As strings novas ou alteradas por esta onda são: a linha de §2.7 no `pre-push` (varredura feita: `grep -rn 'não definido — skip' tests/` devolve **zero**, e nenhum gate compara a saída do `pre-push` contra golden — os goldens do repositório são de `run-gates.sh` e do grafo); a mensagem de recusa de `default_mode` em `spec-new.sh` (varredura feita: **27** arquivos de `tests/` invocam `spec-new.sh`, e nenhum declara `sdd.*` numa fixture exceto `w20:139-143`, que traz os valores de fábrica e chama `spec-new` com `--scale 2` explícito); e a saída de `handoff-gen.sh` (varredura feita: `w60`, `w101` e `w63`, agora nominais na definição de pronto). **O espelho em `plugin/forge`:** medido que `plugin-build.mjs` gera a partir de `--commands template/.forge/commands` e que a onda não edita comando nenhum, mas `npm run build:plugin` entra na definição de pronto assim mesmo — quem decide se o plugin está sincronizado é o `plugin-sync-gate`, não a dedução de escopo.

**C — linha de matriz de mutação sem contrafactual medido.** As quatro matrizes de §8 foram revisadas linha a linha. As de M1, M2, M3, M4 e as do gate C `[8]` trazem contrafactual escrito, e §8.1 já exige em letra que o implementador **meça cada mutação antes de escrever a linha da matriz**. O contrafactual do gate C `[8]` está medido nos dois sentidos (§6.2 para a exclusão de capturas, §6.3 para a detecção de `$`). O do gate D `[7]` opera sobre cópia do grafo em `$TMPDIR` e as duas direções estão medidas em §7.1 (0 e 54).

**D — enumeração que se diz exaustiva.** Duas no documento. A dos desfechos de §7.4 **deixou de se declarar exaustiva**, com a razão empírica escrita: ela tinha oito, dizia tê-los procurado, e o nono veio de fora. A do censo de §2.1 passou a vir com **predicado definido antes do número**, que é o que torna a contagem verificável em vez de exaustiva por declaração — e a própria revisão dela já achou três autômatos que a primeira redação não listava.

**E — prescrição de comando que nunca executei.** Varridos os comandos que a especificação manda rodar. Executados nesta rodada: `node tools/validate-forge.mjs` (rc 0, catorze `OK`); o `cp` da paridade dos dois `FORGE.md`, sobre cópias em `$TMPDIR`, com `cmp -s` rc 1 antes e rc 0 depois e `<PROJECT_SLUG>` preservado; `git archive HEAD` (inclusive o rc 128 em repositório sem commit); `graph-build.mjs`; `spec-new.sh` com os seis valores de `--mode`; o `pre-push` de produção nos dois estados. **Não executado, e dito em letra:** `npm run build:plugin`, porque ele escreve em `plugin/`, que é árvore rastreada, e esta rodada não edita arquivo rastreado fora desta especificação — a prescrição não é minha, é a que `plugin-sync-gate.sh:23` já emite na própria mensagem de reprovação. `npx forge-harness update` aparece apenas em citação de mensagem já existente do `pre-push`, não como prescrição desta onda.
