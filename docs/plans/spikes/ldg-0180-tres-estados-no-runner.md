# LDG-0180 — três estados no runner da suíte

Item: **LDG-0180** [open] (P2) — `tests/run-all.sh` colapsa "gate reprovou" e "gate foi morto" no mesmo vermelho.
Branch: `feat/fase1-dogfood-completo` (PR #147, commit adicional).
Ordinal alocado: **w212** — `tests/w212-runner-tres-estados-gate.sh`.
Plano-mestre: `docs/plans/2026-09-07-backlog-zero.md`, invariantes 1 a 19.

## 1. O defeito, e por que ele é do instrumento

`tests/run-all.sh:70-90` implementa `run_one` com dois desfechos: `if "$@" >"$log" 2>&1; then pass; else fail; fi`. Todo `rc` diferente de zero vira a mesma parcela `fail`, o mesmo marcador `✗` e a mesma linha na lista `FALHARAM:`. Um gate que reprovou por asserção, um gate que o kernel matou por pressão de memória, um gate que estourou o teto de tempo e um gate que não achou uma dependência terminam com o mesmo veredito visual e o mesmo peso no resumo.

É a invariante 2 do plano-mestre — três estados, nunca dois — violada pelo instrumento que a cobra de todos os outros gates, e com o sinal invertido em relação ao falso-verde que o harness persegue: aqui o resultado é falso-**vermelho**, que faz alguém procurar defeito onde não há e, no limite, "consertar" código correto. Foi medido nesta sessão: `tests/w94-hookspath-preserve-gate.sh` e `tests/w99-orphan-lifecycle-gate.sh` apareceram como falha numa execução gate a gate sob pressão de memória e passaram limpos quando rodados isolados; os dois tinham sido mortos, não reprovados.

O gate `tests/w208-hooks-manifest-esquema-gate.sh:36` já descreve a limitação em letra: *"`run-all.sh` tem exatamente dois desfechos por gate e não há canal de skip para gate"*. É comentário, não asserção, então nenhum gate quebra por causa dele — mas ele passa a mentir quando esta onda entrar, e a onda o corrige junto.

## 2. Vermelho observado antes de existir implementação

O vermelho foi produzido rodando o **runner real de produção**, byte a byte, sobre um universo de fixtures que contém um representante de cada classe de desfecho. A cópia foi conferida por `shasum -a 256` contra `tests/run-all.sh` — as duas somas são iguais, então o que rodou é o arquivo de produção e não uma paráfrase dele.

```
$ shasum -a 256 tests/run-all.sh $T/tests/run-all.sh | awk '{print $1}' | uniq -c
   2 e7d8db476749edcafb3c22db88b50c57da0c712ad23b9c25cef0e5089344f6d7

$ bash $T/tests/run-all.sh
  ✓ w01-pass-gate.sh          # passa (rc 0)
  ✗ w02-assert-gate.sh        # reprova por asserção, imprime FAIL (rc 1)
  ✗ w03-silent-gate.sh        # reprova por asserção, NÃO imprime FAIL (rc 1, set -e nu)
  ✗ w04-kill-gate.sh          # morto por SIGKILL no meio (rc 137)
  ✗ w05-missing-gate.sh       # dependência ausente (rc 127)
  ✗ validators.bats           # bats com asserção falha (rc 1, "not ok")
  ✗ claude-contract.bats      # bats cujo worker foi morto por sinal (rc 1, zero "not ok")
PASS=1  FAIL=6  SKIP=0  (13s)
FALHARAM:
  - w02-assert-gate.sh
  - w03-silent-gate.sh
  - w04-kill-gate.sh
  - w05-missing-gate.sh
  - validators.bats
  - claude-contract.bats
rc_final=1
```

Seis desfechos de **quatro** naturezas diferentes, um único marcador, uma única parcela, um único código de saída. O vermelho vem da ausência real da funcionalidade: não existe no runner nenhum caminho que produza um terceiro marcador, nenhuma terceira parcela no resumo e nenhum terceiro código de saída. Nada foi fabricado — nem asserção que falha por sintaxe, nem fixture ausente, nem caminho errado.

## 3. O que foi medido nesta especificação

Toda decisão da seção 4 se apoia numa destas medições, feitas em `${TMPDIR}` nesta máquina (macOS 25.6.0, `/bin/bash` 3.2.57, `bats` 1.13.0).

### 3.1 A forma do `rc` por classe de desfecho

| fixture | como morre | `rc` observado | linhas `FAIL` no log | log vazio |
|---|---|---|---|---|
| `g-pass` | passa | 0 | 0 | não |
| `g-assert` | `echo "FAIL [2]…"; exit 1` | 1 | 1 | não |
| `g-assert-silent` | `[ 1 -eq 2 ]` sob `set -e` | 1 | **0** | não |
| `g-kill` | `kill -KILL $$` | 137 | 0 | não |
| `g-term` | `kill -TERM $$` | 143 | 0 | não |
| `g-missing` | binário inexistente sob `set -e` | 127 | 0 | não |
| `g-slow` sob `perl -e 'alarm 2; exec @ARGV'` | teto de tempo (SIGALRM) | 142 | 0 | não |

### 3.2 O discriminador barato do incidente NÃO é sólido como regra

O que salvou a sessão foi a **ausência** de linha `FAIL`, e a nota do ledger generaliza isso em *"um gate reprovado por asserção SEMPRE imprime FAIL"*. Medido sobre a suíte real, a generalização é falsa.

```
$ for g in tests/*-gate.sh; do tot=$((tot+1)); grep -qE '(^|[^A-Za-z])FAIL' "$g" && withfail=$((withfail+1)); done
gates=135  com_token_FAIL=119
```

Dezesseis dos 135 gates — `check-observability`, `graph-deps`, `graph-govern`, `graph-symbols`, `infra-scan`, `mdl-gen`, `mermaid-drawio`, `w103`, `w104`, `w23`, `w60`, `w61`, `w62`, `w92`, `w93`, `yaml-lite` — não contêm o token `FAIL` em lugar nenhum do fonte, e reprovam por um comando nu morrendo sob `set -euo pipefail`, sem imprimir nada.

E o problema é mais fino que "dezesseis arquivos": ele existe na granularidade da **asserção**, dentro de gates que têm o token. O próprio `tests/w80-suite-gate.sh` — o gate que guarda este runner — reprova em silêncio nas asserções `[1]` e `[2]`, que são `[ -d … ]`, `[ -f … ]` e `grep -q …` nus sob `set -e`, sem `|| { echo "FAIL …"; exit 1; }`. Medido, rodando o `w80` real com o `WS` deslocado para que a asserção `[1]` reprove:

```
rc=1
--- log completo ---
[1] fixtures com a forma esperada
--- ocorrências de FAIL no log: 0 ---
```

Um gate de produção deste repositório, reprovando por asserção, com `rc=1`, zero linhas `FAIL` e log truncado no meio do progresso: exatamente a assinatura que a regra ingênua atribuiria a uma morte por sinal. Adotar a ausência de `FAIL` como condição necessária para classificar reprovação rebaixaria essa família inteira de `FAIL` para "não verificado" — trocaria um falso-vermelho por um falso-verde, que é estritamente pior.

E há a direção oposta, medida na revisão adversarial e não nesta especificação — ela é a razão do achado corrigido em §11.4. A **presença** do token também não é sinal de reprovação, porque o caminho VERDE de gates reais NARRA o token. Medido nos logs de três gates de produção, todos com `rc` 0:

```
$ perl -e 'alarm 280; exec @ARGV' bash tests/w131-surface-declaration-gate.sh > /tmp/w131.log 2>&1; echo rc=$?
rc=0
$ /usr/bin/grep -nE '(^|[^A-Za-z])FAIL' /tmp/w131.log
21:[9] WAV-01 — '--gate FAIL' continua reprovando (o caminho honesto não regrediu)

w51-waves-progress-gate.sh    → 1 ocorrência  ([4] wave-ops close: OK fecha; FAIL recusa)
req13-affects-surfaces-gate.sh → 2 ocorrências
```

Portanto "o log já contém uma linha de reprovação" precisa ser lido como **linha**, e não como token em qualquer posição: a forma real é o token abrindo a linha. Medido sobre os 137 gates, as 2.843 aberturas `echo "FAIL` e as demais formas de emissão (`fail() { echo "FAIL $*"; }`, `console.error('FAIL …')`, `print("FAIL …")`) põem o token no início; nenhuma emissão de reprovação o coloca no meio. Quatro gates repassam a saída de sub-alvos indentada com `sed 's/^/      /'`, de modo que a reprovação de um sub-gate chega indentada ao log e precisa continuar agravando — daí o `[[:space:]]*` inicial do padrão.

### 3.3 `bats` não propaga a forma do sinal

Medido com `bats` 1.13.0:

| cenário | `rc` | plano TAP | linhas `^not ok` |
|---|---|---|---|
| asserção falha | 1 | `1..1` | 1 |
| worker morto por `SIGKILL` | **1** | `1..1` | **0** (e a linha do teste sai como `ok 1`, com um `Killed: 9` solto no log) |
| arquivo `.bats` com erro de sintaxe | **0** | `1..0` | 0 |
| processo `bats` inteiro sob `alarm 2` | 142 | `1..1` | — |

Duas consequências. Primeira: quando o sinal mata um worker e não o processo `bats`, o `rc` que chega ao runner é 1, não 128+N — a regra de faixa de sinal, sozinha, não cobre `bats`, e o discriminador disponível ali é a ausência de `^not ok`, que para `bats` **é** contratual (TAP), ao contrário do `FAIL` dos gates de shell. Segunda, e independente do item: **`bats` sobre um arquivo com erro de sintaxe sai 0 com plano `1..0`, e o runner de hoje marca `✓`** — é o pecado capital do harness, aprovar por não ter olhado para nada, vivo no runner de produção.

Os planos reais das duas suítes hoje, para dimensionar o piso: `bats --count tests/validators.bats` → 15, `bats --count tests/snapshot/claude-contract.bats` → 19.

### 3.4 A infraestrutura do próprio runner falhando parece reprovação

`run_one` faz `log="$(mktemp)"` sem checar. Sob `set -uo pipefail` (o runner não tem `-e`), um `mktemp` que falha — `TMPDIR` sem escrita, disco cheio, que é o vizinho de porta da pressão de memória que originou este item — deixa `log` vazio, e o redirecionamento morre:

```
$ bash -c 'set -uo pipefail; l=""; bash ./g-pass.sh >"$l" 2>&1; echo rc=$?'
bash: : No such file or directory
rc=1
```

Um gate que **passa** é classificado como reprovação, com `rc=1`, por falha da infraestrutura do runner. É um sexto caso que a enumeração ingênua de desfechos não tem — achado pela busca ativa que a invariante 17 exige.

### 3.5 Consumidores da saída e do código de saída do runner

Varredura de `tests/`, `.github/` e `package.json` (invariante 15): **nenhum** gate afirma qualquer string da saída do `run-all` — `PASS=`, `FALHARAM:`, `== Resultado ==`, `suíte 100% verde` e os marcadores `✓`/`✗`/`○` aparecem só dentro do próprio `tests/run-all.sh`. As três ocorrências de `✗` em `tests/` (`w112:141`, `w137:112`, `w153:128`) afirmam a saída do **doctor**, não a do runner. O vocabulário de saída está livre.

Invocadores: `package.json` (`"test": "bash tests/run-all.sh"`), `.github/workflows/ci.yml:49` (`run: bash tests/run-all.sh`) e `tools/plan-progress.mjs:263` (só cita o comando numa mensagem). Nenhum deles inspeciona o código de saída além do zero/não-zero implícito do shell e do GitHub Actions. Códigos de saída já ocupados pelo runner: `0`, `1` e `2` (argumento desconhecido) — e, a partir da onda concorrente LDG-0179, também o `4` (biblioteca da sentinela ausente), conferido na implementação: ver §11.3. O `3` segue livre.

O que **afirma o fonte** do runner é o `w80`, e ele é o risco real desta onda:

- `w80[3]` exige que todo `tests/*-gate.sh` apareça no `--list` — satisfeito automaticamente pelo `w212`.
- `w80[4]` e `w80[5]` **não afirmam nada**: as duas asserções são pipelines iniciados por `!`, e um comando cujo valor de retorno é invertido por `!` é isento do `set -e` por POSIX e pelo bash. O guarda anti-recursão do `w80` está morto. Ver a seção 11 — a afirmação original desta linha era falsa e foi corrigida com medição.
- `w80[7]` confere `GIT_CONFIG_COUNT` contra a contagem de `GIT_CONFIG_KEY_` — intocado.

### 3.6 Armadilha do bash 3.2

```
$ /bin/bash -c 'set -uo pipefail; arr=(); printf "  - %s\n" "${arr[@]}"'
/bin/bash: arr[@]: unbound variable
```

O `failed_names` de hoje escapa porque só é expandido quando `fail != 0`. O array novo do terceiro estado herda a armadilha e precisa da mesma guarda de contagem antes da expansão.

A medição acima cobriu só o array novo, e a revisão adversarial mostrou que os arrays **antigos** já violavam a regra. Medido contra o runner de produção, numa bancada com um gate fictício e nenhum arquivo `.bats`:

```
$ ( cd $B && bash $B/tests/run-all.sh ); echo rc=$?
  ✓ z01-pass-gate.sh
-- suítes bats (0) --
run-all.sh: line 220: BATS_SUITES[@]: unbound variable
rc=1
$ grep -c '^PASS=' saida   →  0
```

O runner morre **depois** de já ter executado e classificado todos os gates, sem imprimir `== Resultado ==`, e devolve 1 — indistinguível de "algum gate reprovou". É o mesmo colapso de dois estados que esta onda combate, com o agravante de perder toda a apuração. Três sítios: `"${GATES[@]}"` nas duas listagens do `--list` e no laço principal, e `"${BATS_SUITES[@]}"` no laço dos bats. `${#arr[@]}` é seguro com array vazio no bash 3.2 (medido); só a expansão dos elementos não é. Os três ganharam guarda nesta onda — ver §11.4.

## 4. Decisões fechadas

### D1 — o discriminador primário é a forma do `rc`; o log só pode agravar, nunca abrandar

**Decidido.** Um desfecho de gate de shell é classificado assim, nesta ordem: `rc` em `[129, 192]` é morte por sinal; `rc` 126 ou 127 é dependência ausente ou alvo não executável; `rc` 0 é passagem; qualquer outro `rc` diferente de zero é reprovação por asserção. O marcador `FAIL` no log entra **apenas** na direção que agrava: um desfecho com `rc` de sinal cujo log já contém uma **linha de reprovação** é classificado como reprovação, porque a violação chegou a ser observada e escondê-la atrás de "não verificado" apagaria um achado real.

"Linha de reprovação" é a FORMA que os gates usam para reprovar, não o token em qualquer posição: o token abrindo a linha, tolerando indentação — `^[[:space:]]*FAIL([^A-Za-z0-9_]|$)`. Ler "token em qualquer posição" reintroduz o próprio falso-vermelho que esta onda existe para eliminar, porque o caminho VERDE de gates reais narra o token (medição em §3.2, achado em §11.4).

**Alternativa descartada:** exigir a linha `FAIL` como condição necessária para classificar reprovação, que é o desenho que o texto do ledger sugere. Descartada pela medição 3.2: dezesseis dos 135 gates nunca imprimem o token, e asserções nuas sob `set -e` existem até dentro do `w80`, de modo que a regra rebaixaria uma família inteira de reprovações reais para "não verificado" — falso-verde no lugar de falso-vermelho. A ausência de `FAIL` foi um bom **heurístico humano** naquela noite, com duas amostras; ela não sobrevive como regra de máquina sobre 135 gates.

### D2 — `rc` 128 é reprovação, não "não verificado"

**Decidido.** A faixa de sinal começa em 129. O `rc` 128 fica com as reprovações.

**Alternativa descartada:** tratar 128 como "sinal 0" e portanto morte. Descartada porque o produtor esmagadoramente mais provável de 128 neste repositório é o `git`, que usa 128 para erro fatal — inclusive no caso que a invariante 17 já cobrou deste plano, o repositório sem nenhum commit em que `git diff HEAD` sai 128. Classificar o fatal do git como "não verificado" criaria falso-verde num caminho que hoje é corretamente vermelho; classificá-lo como reprovação, no pior caso, mantém o comportamento atual. O teto 192 cobre os 64 sinais do Linux e sobra folga sobre os 31 do macOS; `rc` 255 e vizinhos ficam com as reprovações, porque `exit 255` é idioma de script e não forma de sinal.

### D3 — `bats` tem ramo próprio, guiado pelo contrato TAP

**Decidido.** Para uma suíte `bats`: `rc` na faixa de sinal é "não verificado"; `rc` 0 com plano `1..0` ou sem linha de plano é "não verificado" por vacuidade; `rc` diferente de zero com ao menos uma linha `^not ok` é reprovação; `rc` diferente de zero com zero linhas `^not ok` é "não verificado".

**Alternativa descartada:** aplicar aos `bats` a mesma regra dos gates de shell. Descartada pela medição 3.3: o `bats` **absorve** o sinal do worker e devolve `rc` 1, então a regra de faixa nunca dispararia para o caso que mais importa. Ao contrário do `FAIL` dos gates, que é convenção não enforçada, `^not ok` é contrato do formato TAP que o `bats` emite — o que torna a ausência dele um discriminador legítimo ali e ilegítimo lá.

### D4 — suíte `bats` que não examinou nada é "não verificado", nunca verde

**Decidido.** Plano `1..0` (ou plano ausente) com `rc` 0 entra no terceiro estado. Custa uma condição no ramo que D3 já obriga a escrever, e fecha o falso-verde medido em 3.3.

**Alternativa descartada:** deixar fora do escopo e abrir item próprio. Descartada porque a especificação teria de documentar, em letra, que o runner marca `✓` sobre um arquivo `.bats` que não rodou teste nenhum — e publicar um falso-verde conhecido sem fechá-lo, numa onda cujo assunto é justamente a distinção de desfechos, seria indefensável. O piso está medido: as duas suítes reais planejam 15 e 19 testes, então nenhuma delas cai no ramo novo hoje.

### D5 — falha da infraestrutura do runner é "não verificado"

**Decidido.** Se o arquivo de log não pôde ser criado, o desfecho é "não verificado", com motivo próprio, e o runner não tenta interpretar um `rc` que não é do gate.

**Alternativa descartada:** abortar a suíte inteira ao primeiro `mktemp` falho. Descartada porque `mktemp` falha justamente sob a pressão de recursos que faz gates morrerem, e nesse cenário abortar destrói a informação parcial que o operador precisa para saber o que ainda foi verificado — que é o oposto do que esta onda entrega.

### D6 — "não verificado" tem marcador próprio, parcela própria e código de saída próprio; e bloqueia o CI

**Decidido.** Marcador visual distinto de `✓`, `✗` e `○`. Parcela própria na linha de resumo, ao lado de `PASS`, `FAIL` e `SKIP`, nunca somada a `FAIL`. Lista nominal própria, separada de `FALHARAM:`. E três códigos de saída, medidos:

```
                (fail,unv)= (0,0) (2,0) (0,2) (2,3)
  spec (D6)                     0     1     3     1
  somado ao FAIL                0     1     1     1
  tolerante (verde)             0     1     0     1
```

`0` só quando não há reprovação **nem** desfecho não verificado; `1` quando há ao menos uma reprovação, com precedência sobre o terceiro estado porque a reprovação é o achado acionável; `3` quando há desfecho não verificado e nenhuma reprovação.

**Alternativas descartadas, as duas nomeadas no enunciado do item.** *Tolerante* — "não verificado" sai 0: descartada porque uma suíte em que quarenta gates morreram por falta de memória reportaria verde, que é a definição do falso-verde que o harness existe para eliminar; o runner do GitHub Actions não é imune à pressão que produziu o incidente, e é exatamente ali que a tolerância esconderia regressão real. *Somado* — "não verificado" sai 1 junto com as reprovações: descartada porque reintroduz o defeito no único canal que o CI lê, o código de saída, e devolve a quem investiga a mesma pergunta que a onda existe para responder. Três estados no marcador e dois no código de saída é a invariante 2 cumprida pela metade.

Retrocompatibilidade fica preservada onde os consumidores medidos olham: `npm test`, o passo do `ci.yml` e qualquer `if run-all; then` continuam bloqueando em `3` exatamente como em `1`, porque testam zero contra não-zero. Nenhum consumidor medido compara o código com `1`. O código `2` continua sendo argumento desconhecido, e o `3` é escolhido por ser o primeiro livre.

### D7 — a onda toca `tests/run-all.sh`, e o runner do template entra no ledger

**Decidido.** A onda corrige `tests/run-all.sh` e o comentário desatualizado de `tests/w208-hooks-manifest-esquema-gate.sh:36`. `template/.forge/scripts/tests/run-all.sh` — o runner que o harness **entrega** aos consumidores — tem o mesmo defeito de dois desfechos e fica fora, com item de ledger novo aberto na mesma rodada.

**Alternativa descartada:** corrigir os dois no mesmo commit. Descartada porque o runner do template é outro programa, com outra superfície de retrocompatibilidade já medida: ele usa os códigos de saída `64` e `66`, aceita `--path`, tem guarda de vacuidade própria pelo contador `total`, e — o que exige análise separada — **reexecuta o comando** no ramo de falha para imprimir a saída, de modo que um teste morto por falta de memória seria morto duas vezes. Emendar isso de carona numa onda sobre o runner interno é o tipo de escopo que a revisão adversarial derruba, e a correção lá muda o comportamento de quatro consumidores instalados.

## 5. Contrato: propriedade e contrafactual

Conforme a invariante 19, esta especificação declara a propriedade que precisa valer e o contrafactual que a mutação tem de produzir; quem implementa escolhe o primitivo e prova que ele discrimina.

**P1 — totalidade.** Para todo `rc` inteiro em `[0, 255]` e todo log, a classificação devolve exatamente uma das três classes. Contrafactual: existir um `rc` que não cai em nenhuma classe, ou que cai em duas.

**P2 — passagem é só o zero.** `rc` 0 num gate de shell é a única entrada que produz passagem. Contrafactual: qualquer `rc` diferente de zero produzindo passagem.

**P3 — morte por sinal não é reprovação.** Um desfecho com `rc` na faixa de sinal e sem **linha** de reprovação no log — o token abrindo a linha, e não o token em qualquer posição — nunca é contado em `FAIL` nem marcado com `✗`. Contrafactual, nas duas direções: `rc` 137 com log de progresso limpo aparecendo na lista `FALHARAM:`, e `rc` 137 cujo log verde apenas CITA o token aparecendo na lista `FALHARAM:`.

**P3b — agravamento sobrevive à indentação.** Um desfecho com `rc` na faixa de sinal cujo log traz a linha de reprovação de um sub-alvo, indentada, continua sendo contado em `FAIL`. Contrafactual: a correção de P3 apertada até `^FAIL`, que devolve esse desfecho ao terceiro estado — falso-verde no lugar do falso-vermelho.

**P4 — reprovação silenciosa continua reprovação.** Um gate que reprova por asserção sem imprimir marcador algum permanece na classe de reprovação. Contrafactual: `rc` 1 com log sem `FAIL` migrando para o terceiro estado.

**P5 — o terceiro estado nunca é verde.** Nenhuma combinação de entradas produz código de saída 0 com contagem de não verificados maior que zero. Contrafactual: resumo com `(fail=0, unv>0)` saindo 0.

**P6 — a reprovação tem precedência.** Havendo reprovação e não verificado na mesma execução, o código de saída é o da reprovação. Contrafactual: `(fail>0, unv>0)` saindo 3.

**P7 — nenhum desfecho se perde.** A soma das quatro parcelas publicadas é igual ao número de alvos executados. Contrafactual: um alvo executado que não incrementa parcela nenhuma.

**P8 — vacuidade não é verde.** Uma suíte `bats` que planejou zero testes não é contada em `PASS`. Contrafactual: `1..0` com `rc` 0 marcado `✓`.

**Propriedade sobre espaço de entrada (invariante 5).** A classificação é função pura de `(tipo, rc, log)` e o espaço de `rc` é finito e pequeno: a varredura **exaustiva** de `rc` de 0 a 255 substitui com vantagem uma amostragem aleatória, com denominador 256 fixo por construção. Medido sobre o protótipo, com log de progresso sem marcador:

```
denominador=256  PASS=1  FAIL=189  UNVERIFIED=66  nao_classificado=0
```

`66` é `64` valores de sinal em `[129, 192]` mais `126` e `127`; `189` é `256 - 1 - 66`. A partição é a asserção, e qualquer deslocamento de fronteira a move.

## 6. Matriz de mutação — contrafactuais medidos

Todas as linhas abaixo foram **executadas** antes de escritas — as dez primeiras na implementação, as seis últimas na correção dos achados da revisão (§11.4) — primeiro contra um protótipo do classificador que reproduz a decisão da seção 4, e depois, na implementação, contra o gate real (§11) —, com controle (`shasum` do arquivo antes e depois, provando que a mutação não foi fantasma) e recontrole (restauração por cópia do original, com `shasum` conferido **e** reexecução provando que o comportamento voltou). Nenhuma delas remove código morto: cada uma altera a classificação de uma fixture que existe e é exercida.

| # | mutação | fixture | antes | depois (medido) | recontrole |
|---|---|---|---|---|---|
| M1 | desloca a faixa de sinal para fora de `[129,192]` | `g-kill`, `rc` 137 | `UNVERIFIED:sinal-9` | `FAIL` | volta a `UNVERIFIED:sinal-9`, sha idêntico |
| M2 | colapsa 126/127 em reprovação | `g-missing`, `rc` 127 | `UNVERIFIED:dependencia-ausente` | `FAIL` | volta, sha idêntico |
| M3 | exige o marcador `FAIL` para classificar reprovação (o desenho descartado em D1) | `g-assert-silent`, `rc` 1 sem marcador | `FAIL` | `UNVERIFIED:sem-marcador` | volta, sha idêntico |
| M4 | trata `bats` sem `^not ok` como reprovação | worker morto, `rc` 1 | `UNVERIFIED:sem-not-ok` | `FAIL` | volta, sha idêntico |
| M5 | trata plano `1..0` como passagem | `.bats` com erro de sintaxe, `rc` 0 | `UNVERIFIED:plano-vazio` | `PASS` | volta, sha idêntico |
| M6 | trata log não criado como reprovação | caminho de log vazio | `UNVERIFIED:sem-log` | `FAIL` | volta, sha idêntico |
| M7 | soma o terceiro estado ao `FAIL` no código de saída | resumo `(0,2)` | `3` | `1` | volta a `3` |
| M8 | trata o terceiro estado como verde | resumo `(0,2)` | `3` | `0` | volta a `3` |
| M9 | insere no runner uma invocação não-comentário do próprio runner | texto do runner | cenário 24 verde | cenário 24 acusa | volta, sha idêntico |
| M10 | insere um byte de controle no runner, cegando o scanner | texto do runner | controle da varredura verde | controle acusa | volta, sha idêntico |
| M11 | devolve o predicado de agravamento ao token em qualquer posição | `a10-narra`, log verde citando `FAIL`, `rc` 137 | `UNVERIFIED:sinal-9` | `FAIL` | volta, sha idêntico |
| M12 | aperta o predicado até `^FAIL`, sem tolerar indentação | `a11-indent`, reprovação de sub-alvo, `rc` 137 | `FAIL` | `UNVERIFIED:sinal-9` | volta, sha idêntico |
| M13 | troca o marcador de skip do runner por `⚠` | bancada sem `bats` no `PATH` | skip `○` ≠ terceiro estado | os dois marcadores colidem | volta, sha idêntico |
| M14 | remove a guarda de vacuidade do laço dos `bats` | bancada com gate e zero `.bats` | resumo publicado, `rc` 0 | `unbound variable`, sem resumo | volta, sha idêntico |
| M15 | remove a guarda de vacuidade do laço dos gates | bancada com zero gate e zero `.bats` | resumo publicado | `unbound variable`, sem resumo | volta, sha idêntico |
| M16 | remove as guardas das duas listagens do `--list` | mesma bancada, `--list` | `rc` 0, listagem vazia | `unbound variable`, `rc` 1 | volta, sha idêntico |

Nota de método, paga em espécie nesta medição: a primeira execução de **M6** foi contrafactual **nulo** — `antes=FAIL`, `depois=FAIL` — porque a bancada entregava um arquivo de log real ao caminho que só dispara quando o log não existe. A mutação alterava o arquivo (o `shasum` mudou, então não era mutação-fantasma no sentido de LDG-0164) e mesmo assim não movia nada, que é o caso da invariante 4: mutação que não derruba nada não prova nada. A linha só entrou na matriz depois de refeita com o caminho de log vazio, onde ela de fato move `UNVERIFIED:sem-log` para `FAIL`.

Segunda nota, também paga: a primeira versão do protótipo usava `n="$(grep -c … || echo 0)"`, e como `grep -c` imprime `0` **e** sai com `rc` 1 quando não casa, o `|| echo 0` anexava uma segunda linha e o `[ "$n" -ge 1 ]` seguinte quebrava com `integer expression expected`. É a família do LDG-0177. Quem implementar não deve herdar a forma: a contagem entra por atribuição direta, com `${var:-0}` cobrindo a saída vazia, e sem `|| echo`.

## 7. Gate w212 — cenários, denominador e mecanismo

`tests/w212-runner-tres-estados-gate.sh`, **27 cenários**, denominador fixo por construção — a exceção legítima que a invariante 14 admite, e cuja divergência é o próprio achado. O gate declara o esperado, conta o que examinou e reprova se os dois não baterem.

O mecanismo de exercício é **integração de ponta a ponta com o runner real**, não asserção sobre o texto do fonte: o gate copia `tests/run-all.sh` para `$T/tests/run-all.sh`, confere por `shasum -a 256` que a cópia é idêntica ao original — controle contra testar uma cópia velha —, planta em `$T/tests/` os gates fictícios de cada classe e as suítes `.bats` fictícias, e executa a cópia. O runner resolve seu `WS` por `BASH_SOURCE` e faz `cd`, então o universo executado é o das fixtures e não o da suíte real, sem recursão. Mecanismo verificado nesta especificação — é o que produziu o vermelho da seção 2.

Duas restrições de forma, medidas em 3.5 e 3.6, valem para o `w212` e para a edição do runner. A primeira: nenhuma linha **não-comentário** nova em `tests/run-all.sh` pode conter `run-all ` ou `run-all.sh`. Ela continua valendo, mas não porque o `w80` a imponha — ele não impõe, o guarda dele está morto (seção 11) —, e sim porque o `w212` passa a afirmá-la por conta própria no cenário 24, e porque consertar o `!` do `w80` é dívida aberta que tornaria a restrição executável de novo. A segunda: todo array precisa de guarda de contagem antes de ser expandido sob `set -u` no bash 3.2 — e não só os novos, porque os três sítios antigos já violavam a regra (§3.6).

Cenários:

1. o runner classifica por algo além de zero contra não-zero — existe um terceiro desfecho alcançável
2. gate que passa é contado em `PASS` e marcado `✓`
3. gate que reprova imprimindo `FAIL` é contado em `FAIL` e marcado `✗`
4. gate que reprova **sem** imprimir `FAIL` continua contado em `FAIL` — anti-regressão de D1
5. gate morto por `SIGKILL` não é contado em `FAIL` e não é marcado `✗`
6. gate morto por `SIGTERM` cai na mesma classe do cenário 5
7. gate morto pelo teto de tempo (`SIGALRM`, `rc` 142) cai na mesma classe
8. gate com dependência ausente (`rc` 127) cai na mesma classe
9. gate morto por sinal **depois** de imprimir `FAIL` é contado em `FAIL` — a direção que agrava, de D1
10. `rc` 128 é contado em `FAIL`, não no terceiro estado — D2
11. suíte `bats` com asserção falha (`^not ok` presente) é contada em `FAIL`
12. suíte `bats` com `rc` diferente de zero e zero `^not ok` cai no terceiro estado — D3
13. suíte `bats` com plano `1..0` cai no terceiro estado e nunca em `PASS` — D4
14. desfecho cujo arquivo de log não pôde ser criado cai no terceiro estado — D5
15. varredura exaustiva de `rc` 0 a 255: toda entrada recebe exatamente uma classe, zero não classificadas — P1
16. a partição da varredura bate com a fronteira declarada: uma passagem, 66 no terceiro estado, o resto em reprovação
17. o marcador do terceiro estado é distinto de `✓`, `✗` e do marcador de skip — e o de skip é **colhido da saída do runner**, numa bancada sem `bats` no `PATH`, e não de um literal escrito dentro do gate
18. a linha de resumo publica as quatro parcelas e a soma delas é igual ao número de alvos executados — P7
19. execução sem reprovação e sem não verificado sai 0
20. execução com ao menos uma reprovação sai 1, com ou sem não verificados — P6
21. execução com não verificados e zero reprovações sai 3 — P5
22. a lista nominal do terceiro estado é separada de `FALHARAM:` e traz o motivo de cada desfecho
23. `bash -n` limpo no runner, e nenhuma expansão de array desguardada sob `set -u` no bash 3.2 — medido em bancadas que de fato **esvaziam** os dois arrays (uma sem `.bats`, outra sem gate algum, incluindo o `--list`), e pelo resumo **publicado**, não pela ausência de uma mensagem
24. `tests/run-all.sh` não ganhou linha não-comentário citando `run-all ` ou `run-all.sh` — asserção **própria do `w212`** sobre o texto do runner, porque o `w80[4]` não discrimina isso (seção 11)
25. linha VERDE que apenas CITA o token `FAIL` não converte morte por sinal em reprovação — P3, a direção do falso-vermelho, com a fixture copiada literalmente do caminho verde do `w51`
26. linha de reprovação **indentada** (saída de sub-alvo) ainda agrava a morte por sinal — P3b, a contra-direção, que impede a correção de 25 de virar falso-verde
27. o gate examinou exatamente 27 cenários — contador de controle contra denominador declarado

## 8. Riscos

**O terceiro estado vira lixeira.** Um gate genuinamente quebrado que passe a morrer por sinal some do vermelho e vira ruído amarelo. Mitigação: o código de saída 3 bloqueia o CI igual ao 1, então nada é ignorado; e a lista nominal do cenário 22 obriga o runner a dizer o motivo de cada desfecho, não só a contagem.

**Fronteira de `rc` errada em outra plataforma.** A faixa `[129, 192]` é generosa para o macOS e exata para o Linux; se algum runtime devolver `rc` de sinal fora dela, o desfecho volta a ser contado como reprovação — degradação para o comportamento de hoje, nunca para falso-verde.

**Divergência entre o runner interno e o do template.** A partir desta onda os dois programas se comportam diferente diante da mesma morte, e é o do template que os consumidores executam. É o preço explícito de D7, e o item de ledger é o que impede que ele seja esquecido.

## 9. O que esta onda NÃO faz

- Não altera `template/.forge/scripts/tests/run-all.sh` — D7, com item de ledger novo.
- Não altera gate algum de `tests/` além do `w212` novo e do comentário desatualizado do `w208`.
- Não torna a convenção `FAIL` obrigatória para os gates, nem converte os dezesseis gates que reprovam em silêncio: a medição 3.2 é insumo desta decisão, e transformá-la em obra é item próprio.
- Não fecha a **vacuidade** do runner interno. Com as guardas de contagem no lugar (§11.4), uma árvore sem gate algum e sem suíte `.bats` deixa de abortar e passa a publicar `PASS=0 FAIL=0 SKIP=0 UNVERIFIED=0` com `rc` 0 — sai verde. É o mesmo buraco que D7 nomeia no runner do template, e a decisão é a mesma dos dois lados: qual é o piso de alvos abaixo do qual a suíte recusa em vez de aprovar. Medido e registrado como nota de medição em **LDG-0181**; a asserção correspondente ainda falta ao `w212`.
- Não trata o caso de o processo `run-all` **inteiro** ser morto, em que o resumo nunca chega a ser impresso; progresso durável entre gates é outro problema, com outra solução.
- Não muda o comportamento do runner diante de `SIGINT`, que hoje mata o gate corrente e segue para o próximo; o `rc` 130 passa a ser classificado no terceiro estado, o que é correto, mas a decisão de abortar a suíte fica fora.
- Não persegue o gate que imprime `FAIL` e sai 0 — falso-verde do gate, não do runner.
- Não toca `.forge/HANDOFF.md`, `.forge/liaison/` nem o ledger fora dos comandos `ledger-ops.sh`.

## 10. Definição de pronto

1. O vermelho da seção 2 está registrado no commit, e a execução do `w212` sobre o runner **antes** da correção reprova pela ausência real do terceiro estado.
2. `perl -e 'alarm 280; exec @ARGV' bash tests/w212-runner-tres-estados-gate.sh` sai 0 com os 27 cenários examinados e o contador de controle batendo.
3. `perl -e 'alarm 280; exec @ARGV' bash tests/w80-suite-gate.sh` sai 0 — o que ele de fato prova aqui é a asserção `[3]`, viva: o `w212` novo aparece no `--list` do runner. A ausência de linha não-comentário citando `run-all` é provada pelo cenário 24 do `w212`, não pelo `w80`.
4. As dezesseis mutações da seção 6 são reexecutadas contra o **gate real**, não contra o protótipo, cada uma com controle e recontrole, e cada uma faz o `w212` acusar.
5. `bash -n tests/run-all.sh` e `bash -n tests/w212-runner-tres-estados-gate.sh` limpos.
6. `tests/w208-hooks-manifest-esquema-gate.sh:36` não afirma mais que o runner tem dois desfechos.
7. Dois itens de ledger abertos, **LDG-0181** e **LDG-0182**. O primeiro para `template/.forge/scripts/tests/run-all.sh`, nomeando os fatos medidos em D7: códigos 64/66 já ocupados, `--path`, guarda de vacuidade por `total`, e a reexecução do comando no ramo de falha. O segundo para o guarda anti-recursão morto do `w80` (seção 11), nomeando o agravante medido — a segunda asserção do `[4]` já casa hoje sobre um comentário, de modo que consertar o `!` a deixa vermelha no mesmo instante — e a varredura que falta: ninguém procurou nos 136 gates outras asserções na forma `! comando` sob `set -e`.
8. A suíte completa roda uma vez, serializada pelo orquestrador e nunca por subagente, e o resultado é comparado gate a gate contra o baseline da branch.

## 11. Correções da implementação

A revisão adversarial reprovou esta especificação por um defeito único e localizado: ela afirmava como verificado um guarda que está morto, e ancorava nele um cenário do gate e um item da definição de pronto. A implementação reproduziu o achado com medição própria, corrigiu os quatro pontos afetados e registra aqui o fato medido, para que a correção não se perca no diff.

**O fato.** As asserções `[4]` e `[5]` do `tests/w80-suite-gate.sh` são pipelines iniciados por `!`. O bash — como o POSIX manda — não sai por `set -e` quando o valor de retorno do comando está sendo invertido por `!`. As duas asserções, portanto, nunca reprovam: elas calculam um valor e o descartam.

```
$ /bin/bash -c 'set -euo pipefail; ! true; echo "depois rc=$?"; exit 0'; echo "rc_total=$?"
depois rc=1
rc_total=0
```

**O agravante.** A segunda asserção do `[4]` — `! grep -E '(bash|sh|exec).*run-all' "$RA"` — **já casa hoje** sobre o runner de produção, na linha 43, que é comentário e a lista de exceções da primeira asserção isentaria mas a segunda não consulta:

```
$ grep -nE '(bash|sh|exec).*run-all' tests/run-all.sh
43:# `run-all.sh` se exclui; o w80 (gate da própria suíte) NÃO chama run-all (sem recursão).
```

Consertar o `!` sem tocar no resto deixa o `w80` vermelho no mesmo instante. Por isso a correção do guarda é item de ledger próprio e não carona desta onda, e por isso a frase "comentários estão isentos" vale só para a primeira asserção.

**A prova de ponta a ponta, com controle e recontrole.** Numa bancada em `$TMPDIR` onde `tests/` é reproduzido por symlinks e só `run-all.sh` e `w80-suite-gate.sh` são cópias, o `w80` roda com o `WS` válido. O controle usa o runner idêntico ao de produção, a mutação acrescenta exatamente a linha que a spec citava como derrubadora, e o recontrole restaura o original:

```
== CONTROLE ==
e7d8db476749edcafb3c22db88b50c57da0c712ad23b9c25cef0e5089344f6d7
rc=0
OK [4] OK [5]
== MUTAÇÃO (linha não-comentário citando run-all) ==
7a32d8579ffefaf0cfb350ccafd63a6c4509fb48c37aedf75d37e7275faae372
rc=0
OK [4] OK [5]
== RECONTROLE ==
e7d8db476749edcafb3c22db88b50c57da0c712ad23b9c25cef0e5089344f6d7
rc=0
OK [4] OK [5]
```

O `shasum` muda, logo a mutação não é fantasma; o `rc` não muda, logo o gate não acusa. A afirmação original — "uma linha não-comentário nova contendo `run-all ` ou `run-all.sh` derruba o `w80`, e ele morre em silêncio… Verificado" — media apenas que o texto atravessa a lista de exceções do primeiro `grep`, não que o gate reprova.

**O que mudou nesta especificação, ponto a ponto.**

1. §3.2 trocou o exemplo de asserção silenciosa: o `w80` reprova em silêncio nas asserções `[1]` e `[2]`, que são `[ -d … ]`, `[ -f … ]` e `grep -q …` nus sob `set -e`, e não nas `[4]`/`[5]`. A evidência colada logo abaixo — `rc=1`, log truncado em `[1]`, zero linhas `FAIL` — sempre foi dessa asserção `[1]`; só a atribuição estava errada. O argumento de D1 não depende do exemplo trocado e permanece de pé pelos dezesseis gates sem o token.
2. §3.5 substituiu a afirmação sobre o `w80[4]` pelo fato medido.
3. §7 manteve a restrição de forma sobre o texto do runner, mas parou de atribuí-la ao `w80`: quem passa a impô-la é o cenário 24 do próprio `w212`, como asserção sua. A implementação foi além e trocou o objeto da asserção — de "o token aparece" para "o runner é invocado" —, porque a redação por token reprovou uma linha legítima que apareceu na mesma branch; ver §11.2.
4. §7, cenário 24, virou asserção própria do `w212`. O denominador segue 25 — o cenário deixou de ser um que não pode falhar e passou a ter mutação que o derruba (M9 na seção 6).
5. §10, item 3 da definição de pronto, parou de atribuir ao `w80` uma discriminação que ele não faz, e passou a nomear a asserção `[3]`, que está viva, como o que aquele comando de fato prova.
6. §10, item 7, ganhou o segundo item de ledger: o guarda morto do `w80`. Os dois itens foram abertos por `ledger-ops.sh add` e receberam **LDG-0181** (dívida técnica, o runner do template) e **LDG-0182** (bug conhecido, o guarda morto do `w80`).

### 11.1 O vermelho da implementação, e as dez mutações contra o gate real

O `w212` foi escrito antes de existir terceiro estado no runner e rodado contra `tests/run-all.sh` intacto — `shasum` `e7d8db47…`, o mesmo da seção 2. Ele morreu no primeiro cenário, pela ausência real da funcionalidade:

```
$ shasum -a 256 tests/run-all.sh
e7d8db476749edcafb3c22db88b50c57da0c712ad23b9c25cef0e5089344f6d7  tests/run-all.sh
$ bash tests/w212-runner-tres-estados-gate.sh
[1] existe um terceiro desfecho alcançável
FAIL: gate morto por sinal recebeu o mesmo marcador de passagem ou de reprovação ('✗')
rc=1
```

Depois da correção o gate sai 0 com `25/25 cenários examinados`, e a matriz da seção 6 foi reexecutada contra o **gate real** — não contra o protótipo — numa bancada em `$TMPDIR` onde `tests/run-all.sh` e o próprio `w212` são cópias, de modo que o arquivo rastreado nunca é mutado, que é a lição do LDG-0175. Cada linha tem controle (`sha` e `rc` antes), mutação (`sha` obrigatoriamente diferente, senão seria mutação-fantasma) e recontrole (restauração por cópia, com `sha` conferido **e** o gate reexecutado provando que o comportamento voltou). Controle e recontrole saíram `sha` `c75de4f6…` com `rc` 0 nas dez linhas.

| # | `sha` da mutação | `rc` | cenário que acusou |
|---|---|---|---|
| M1 | `a19db4ae…` | 1 | `[5]` — morto por sinal recebeu o marcador de reprovação |
| M2 | `7f0feaa4…` | 1 | `[8]` — dependência ausente não caiu no terceiro estado |
| M3 | `c2ae54c2…` | 1 | `[4]` — reprovação silenciosa migrou para o terceiro estado |
| M4 | `43d93389…` | 1 | `[12]` — `bats` com worker morto contado como reprovação |
| M5 | `fa3046b4…` | 1 | `[13]` — plano `1..0` marcado como passagem |
| M6 | `5fa93ff9…` | 1 | `[14]` — log não criado deixou de trazer o motivo `sem-log` |
| M7 | `957c907f…` | 1 | `[21]` — `(0,2)` saiu 1 em vez de 3 |
| M8 | `7d69fbf7…` | 1 | `[21]` — `(0,2)` saiu 0, o falso-verde |
| M9 | `1302b8c8…` | 1 | `[24]` — invocação do runner dentro do runner |
| M10 | `787af0f8…` | 1 | `[24]` — byte de controle cegando o scanner |

Nenhuma delas foi no-op e nenhuma removeu código morto: as dez movem a classificação, o código de saída ou a leitura do texto do runner, sobre fixtures que existem e são exercidas em toda execução do gate.

### 11.2 Dois achados que a implementação trouxe, e que a especificação não previa

**O `awk` do macOS compara strings multibyte de forma inconsistente.** Com o marcador recortado de uma linha de saída em `m`, o padrão `$1 == m` casa com `✓`, `✗` e `⚠` ao mesmo tempo. A primeira versão do `w212` contou 256 passagens, 256 reprovações e 256 não verificados na varredura de 256 entradas, e o cenário 15 acusou — a soma 768 contra o denominador 256 é o contador de controle fazendo exatamente o serviço dele. A correção foi tirar do `awk` toda comparação de marcador: ele só recorta o campo, e quem compara é o shell ou o `grep`. Sem o cenário 15 a divergência teria passado como três medições plausíveis.

**O cenário 24 nasceu afirmando o token, e o token não é a propriedade.** Redigido como "nenhuma linha não-comentário citando `run-all `" ele reprovou uma linha legítima que apareceu nesta mesma branch: a sentinela de árvore rastreada da onda LDG-0179 imprime `run-all.sh: sentinela ausente …` quando a biblioteca falta — o runner é **nomeado**, não invocado. A propriedade que importa é anti-recursão, e o cenário passou a afirmá-la diretamente: `bash`, `sh`, `exec`, `source` ou `.` seguidos de um alvo que cite o runner. A invariante 19 é justamente isso — a especificação declara a propriedade, quem implementa escolhe o primitivo.

**E o cenário 24 quase virou falso-verde no caminho.** Uma tentativa malfeita de escrever a mutação M9 inseriu um byte NUL no runner; o `grep` do `PATH` desta máquina devolveu **vazio** sobre o arquivo inteiro, e a asserção de ausência passou — verde sobre um runner que continha a linha proibida, com `rc` 0 e nenhum aviso. É o LDG-0177 outra vez: varredura vazia não prova ausência. O cenário ganhou controle positivo — um token que o runner tem por construção precisa ser encontrado antes que a ausência do outro signifique alguma coisa — e a M10 existe para provar que o controle acusa.

### 11.3 Uma frente concorrente na mesma árvore, e o que isso mudou

O enunciado desta implementação afirmava que ninguém mais estava trabalhando na árvore. Não era o caso: durante a execução, `tests/run-all.sh` mudou no disco entre duas medições minhas, e a onda LDG-0179 acrescentou ao mesmo `run_one` uma sentinela de árvore rastreada — construída, corretamente, **sobre** o terceiro estado desta onda: ela reusa a variável `veredito`, acrescenta o desfecho `SUJOU` e o motivo `arvore-nao-medida`, e é explícita em agravar e nunca abrandar, que é a mesma regra de D1. Nada foi revertido.

Três consequências registradas, todas medidas depois da colisão. Primeira: o runner passou a exigir `template/.forge/scripts/lib/arvore-rastreada.sh` sob o seu `WS` e a sair **4** sem ela; o código `3` que D6 escolheu continua livre, e o `4` é da outra onda. Segunda: a bancada do `w212` precisou de um dublê neutro dessa biblioteca — ela é um colaborador com gate próprio (`w213`), e o que o `w212` mede é a classificação de desfecho; se o dublê sumir, o runner sai 4 e todos os cenários acusam. Terceira: a matriz de mutação foi inteiramente **reexecutada** contra o runner já com a sentinela (`sha` `c75de4f6…`), porque evidência colhida contra uma versão anterior do arquivo sob teste não vale para a versão que vai no commit.

### 11.4 Os achados da revisão adversarial, e o que a correção mudou

A revisão adversarial reprovou a implementação com cinco achados. Três eram meus e foram corrigidos; um é do orquestrador do commit e um fica registrado como preço medido da fronteira. O que segue é a reprodução própria de cada um e a medição da correção — não o relato do revisor.

**Achado 2 [ALTA] — o falso-vermelho que a onda existe para eliminar sobrevivia.** O predicado de agravamento era `grep -cE '(^|[^A-Za-z])FAIL'` sobre o log INTEIRO, isto é, o token em qualquer posição. Reproduzido nos logs verdes de três gates de produção deste repositório (§3.2): `w131-surface-declaration-gate.sh` imprime `[9] WAV-01 — '--gate FAIL' continua reprovando` numa execução que sai 0, e o mesmo vale para `w51` e `req13`. Qualquer um dos três morto por `SIGKILL` depois dessa linha — o cenário exato do incidente que originou este item — voltava a `✗` e a `FALHARAM:`. O predicado passou a exigir a FORMA que os gates usam para reprovar: `^[[:space:]]*FAIL([^A-Za-z0-9_]|$)`. Medido depois da correção, contra o runner real numa bancada com três fixtures mortas por `SIGKILL`:

```
  ⚠ x01-narra-gate.sh    não verificado (sinal-9, rc=137)   ← log verde citando o token
  ✗ x02-agrava-gate.sh                                       ← FAIL [9] no início da linha
  ✗ x03-indent-gate.sh                                       ← FAIL [3] indentado, de sub-alvo
  PASS=0  FAIL=2  SKIP=0  UNVERIFIED=1
```

A fixture `a08` do `w212` só exercitava a direção que agrava, e por isso era cega para o falso-positivo. Entraram duas fixtures novas em RUN A — `a10-narra-gate.sh`, com a linha copiada literalmente do caminho verde do `w51`, e `a11-indent-gate.sh`, com a reprovação indentada de sub-alvo — e os cenários **25** e **26**, uma por direção. As mutações **M11** (devolve o token em qualquer posição, `sha` `88c4c644…`) e **M12** (aperta até `^FAIL`, `sha` `9f332804…`) fazem o gate acusar em `[25]` e `[26]` respectivamente, com controle e recontrole em `0033f849…` e `rc` 0.

**Achado 3 [MÉDIA] — o cenário 17 não media.** Ele comparava o marcador do terceiro estado contra `MARK_SKIP='○'`, um literal escrito dentro do próprio gate, e nenhuma das sete bancadas exercitava o ramo `have_bats -eq 0` do runner: o `mkbench` sempre plantava o shim de `bats` no `PATH`. A asserção era meio-viva — pegava o terceiro estado migrando para `○`, e não pegava `○` migrando para o terceiro estado. Entrou a bancada **RUN H**, sem o shim, e o marcador de skip passa a ser colhido da saída do runner. A primeira versão dela reduzia o `PATH` a `/usr/bin:/bin`, o que funciona nesta máquina — o `bats` mora em `/opt/homebrew/bin` — e silenciaria o cenário num host onde ele esteja em `/usr/bin`, que é exatamente o defeito desta classe. A versão que ficou monta um diretório com symlinks só para as doze ferramentas que o runner usa, resolvidas por `command -v` e exigidas em caminho ABSOLUTO (`command -v` também devolve o nome de uma função, e um symlink `grep → grep` é o alvo cego do LDG-0177), e **confere** que o `bats` não é alcançável antes de concluir qualquer coisa. A mutação **M13** (`sha` `f2bbe495…`), que troca o `○` do runner por `⚠`, faz o `[17]` acusar com a mensagem `marcador do terceiro estado ('⚠') colide com … skip ('⚠')`.

**Achado 4 [MÉDIA] — o cenário 23 afirmava ausência que não valia.** O runner tinha três expansões de array desguardadas sob `set -u` (§3.6), e o `[23]` as procurava por `grep -q 'unbound variable'` nas saídas das bancadas A a F, todas com os dois arrays **não vazios** por construção do `mkbench`: a asserção não podia falhar. Aqui a correção não foi documentar o limite, foi fechá-lo — as três expansões ganharam guarda de contagem, e a asserção passou a medir o resumo PUBLICADO em bancadas que de fato esvaziam os arrays: **RUN I** (um gate, zero `.bats`) e **RUN J** (zero gate, zero `.bats`, mais o `--list`). Três mutações provam que o `[23]` acusa: **M14** (guarda dos bats, `sha` `d156e2c2…`), **M15** (guarda dos gates, `sha` `18972432…`, sintaticamente válida — a primeira tentativa removeu só o `if` e deixou o `fi` órfão, que reprova por erro de sintaxe e não pela propriedade) e **M16** (guardas do `--list`, `sha` `2ee6c10f…`). O que a correção **abre** está registrado em §9 e em LDG-0181: sem a expansão para matar o runner, a árvore vazia agora sai verde.

**Achado 1 [ALTA] — badge do README.** É do commit, não desta correção: a onda acrescentou o 137º gate e o badge ficou em 136, com a onda concorrente LDG-0179 mexendo no mesmo arquivo. Reconciliação de valor derivado, feita uma única vez por quem fecha o commit. Nenhum arquivo do README foi tocado aqui.

**Achado 5 [BAIXA] — `SIGPIPE` gerado pelo próprio alvo.** Fica como está, e o motivo é o mesmo de D2 invertido: `rc` 141 é indistinguível, pela forma do `rc`, de um `SIGPIPE` recebido de fora. Distinguir "sinal recebido" de "sinal que o alvo causou a si mesmo" exige instrumentar o alvo, não o classificador. O desfecho continua bloqueando o CI pelo código 3, e a lista nominal nomeia `sinal-13`, que é o fio para quem investigar. Preço medido da fronteira, registrado em §8.

**A matriz reexecutada, contra a versão do gate que vai no commit.** As seis mutações novas foram medidas duas vezes: a primeira contra a versão anterior do `w212`, e a segunda — que é a que vale — depois de a bancada RUN H trocar de mecanismo, porque evidência colhida contra outra versão do arquivo sob teste não vale para a versão que vai no commit. Controle e recontrole em `0033f849…` com `rc` 0 nas seis linhas, e `bash -n` limpo em **todas** as mutações, de modo que nenhuma acusa por erro de sintaxe em vez de pela propriedade:

| # | `sha` da mutação | `rc` | cenário que acusou |
|---|---|---|---|
| M11 | `88c4c644…` | 1 | `[25]` — a10 recebeu `✗`, o falso-vermelho de volta |
| M12 | `9f332804…` | 1 | `[26]` — a11 não agravou, falso-verde no lugar |
| M13 | `f2bbe495…` | 1 | `[17]` — o marcador de skip colidiu com o do terceiro estado |
| M14 | `d156e2c2…` | 1 | `[23]` — `unbound variable` na bancada sem `.bats` |
| M15 | `18972432…` | 1 | `[23]` — `unbound variable` na bancada sem gate |
| M16 | `2ee6c10f…` | 1 | `[23]` — `unbound variable` no `--list` |

**O que a correção NÃO tocou, por estar fora do escopo autorizado.** O `README.md` (achado 1, do orquestrador do commit), a biblioteca `arvore-rastreada.sh` e os gates adotantes da onda LDG-0179, e o guarda morto do `w80` — que continua em **LDG-0182**, com a varredura dos 137 gates atrás de outras asserções na forma `! comando` sob `set -e` ainda por fazer. Nenhum commit e nenhum push.
