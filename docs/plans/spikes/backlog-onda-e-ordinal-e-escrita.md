# Onda E — alocação de ordinal e disciplina de escrita

Especificação implementável. Insumo: `docs/plans/2026-09-07-backlog-zero.md`, seções "Invariantes", "Definição de pronto do plano inteiro" e "Onda E". Fecha LDG-0173, LDG-0167, LDG-0158, #103 e LDG-0140.

Data das medições: 2026-09-07, com uma segunda rodada de medição na revisão 2 (esta). Árvore: `/Users/milton/Documents/projects/forge-harness`, `HEAD` em `3bb67f5`, branch corrente `feat/fase1-dogfood-completo` (o mandato desta onda dizia `develop`; os dois apontam para o mesmo commit, e o registro fica aqui porque a Fase 1 está em voo na mesma árvore).

**Regra que esta revisão passa a cumprir sem exceção: toda afirmação numérica vem com o comando que a produz, colado ao lado do número.** A revisão 1 listou sete afirmações minhas que ela não conseguiu reproduzir ou que eu não acompanhei de comando; cada uma foi remedida com o comando colado ou removida, e a §14 diz qual foi qual. A única afirmação que **não** é medição minha continua sendo a colisão de `w200` de LDG-0167 — as duas branches daquela noite não existem mais —, e ela deixa de ser palavra contra palavra: §2.2 traz o comando que lê o corpo do item de ledger de onde a citação sai. E onde o número conta algo da árvore (arquivos, gates, refs, entradas), ele é **testemunha de data e nunca critério**: a asserção correspondente usa propriedade mais piso derivado na execução.

Rigor reduzido por decisão do dono: três rodadas de revisão em vez de cinco. Isso não afrouxa nenhuma das dezenove invariantes — significa que os defeitos das quatro especificações anteriores precisam estar evitados desde o rascunho, e a §13 registra, item a item, como cada uma das cinco armadilhas foi tratada, incluindo a varredura completa refeita nesta revisão.

---

## 1. O eixo comum, e por que os cinco itens se corrigem juntos

Os cinco itens têm a mesma forma: **uma escrita durável é decidida a partir de um universo menor do que o universo real, e o resultado sai com `rc 0` e uma linha de `OK`**. Em LDG-0173, LDG-0167 e LDG-0158 o universo menor é o conjunto de refs que o alocador de ordinal consulta. Em #103 o universo menor é o conjunto de argumentos que o parser examina antes de gravar. Em LDG-0140 o universo menor é o conjunto de campos que o `harvest` preenche antes de criar a entrada. Nos cinco, o dano é o mesmo: um registro durável nasce afirmando algo que ninguém verificou, e o operador lê `OK`.

A onda tem, por isso, duas metades e não cinco frentes:

**Metade A — o universo do alocador.** `gate-ordinal.sh next` e `ledger-ops.sh add` escolhem um número novo a partir de uma leitura. A leitura é boa quando enxerga tudo o que já tomou número; hoje ela enxerga três refs nominais (ordinal) ou um único arquivo do disco (ledger). A correção é decidir o universo e declará-lo na saída.

**Metade B — a disciplina da porta de escrita.** `ledger-ops.sh resolve`, `deferral-ops.sh test`/`status` e `ledger-ops.sh harvest` gravam sem examinar tudo o que precisariam examinar. A correção é recusar o que não é conteúdo, e preencher com material da fonte o que a fonte tem.

### 1.1 O que esta onda NÃO consegue fechar, dito antes de começar

`next` **lê**, não **aloca**, e continuará lendo depois desta onda. Alocação de verdade exige uma autoridade compartilhada onde escrever a reserva antes de usá-la, e nenhuma das duas candidatas sobrevive à medição (§2.3, decisões 2 e 3). O que a onda entrega é o universo certo da leitura, o que transforma a maior parte das colisões reais em não-eventos e move a descoberta do resto para o push. O que ela **não** entrega é impedir que duas máquinas offline, ambas sem commit, escolham o mesmo número. Isso fica escrito no cabeçalho do script, como já está hoje, e o ledger dos dois itens registra a limitação em vez de a esconder.

### 1.2 A premissa do cabeçalho de `gate-ordinal.sh` está errada, e a onda a corrige em letra

`template/.forge/scripts/gate-ordinal.sh:9-12` afirma, sobre o id de ledger: *"O ledger tem UM arquivo físico que vive no tronco por desenho (`--git-common-dir`), e `add` calcula `max + 1` sobre esse arquivo único: a serialização é por construção."* A mesma frase está na nota de resolução de LDG-0067, dentro de `.forge/ledger/ledger.json`.

Ela é falsa, e a medição é de uma linha. `ledger.json` é arquivo **rastreado**: o caminho é único, o conteúdo não. Executado nesta rodada, no repositório real:

```
for r in origin/develop origin/main HEAD; do printf '%-16s ' "$r"
  git show "$r:.forge/ledger/ledger.json" 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);console.log(Math.max(...j.entries.map(e=>+e.id.slice(4))))}catch(e){console.log("SEM LEDGER NESSE REF")}})'
done
printf '%-16s ' disco; node -e 'const j=require("./.forge/ledger/ledger.json");console.log(Math.max(...j.entries.map(e=>+e.id.slice(4))))'
```

Saída de 2026-09-07, remedida nesta revisão:

```
origin/develop   176
origin/main      174
HEAD             176
disco            176
```

Um único caminho físico, três máximos. O arquivo serializa escritas **concorrentes** (duas worktrees escrevendo ao mesmo tempo disputam o mesmo inode); ele não serializa **branches**, porque um `git checkout` reescreve o conteúdo e o `max` volta para o da outra branch. Foi exatamente esse o mecanismo da segunda colisão de LDG-0167. A onda corrige o comentário junto com o código, porque um comentário que justifica não fazer algo é a razão pela qual o algo não foi feito.

---

## 2. LDG-0173 — o universo do `next`

### 2.1 O defeito, reproduzido

Bancada em `$TMPDIR`, montada nesta rodada: um repositório `up` com `develop` contendo `tests/w203`, `w204` e `w205`, e uma branch `feat/em-voo` que acrescenta `tests/w206-emvoo-gate.sh`; um clone `cl` posicionado em `develop`.

```
--- refs remotos no clone:
  refs/remotes/origin/HEAD
  refs/remotes/origin/develop
  refs/remotes/origin/feat/em-voo
--- tests/ local do clone:
w203-a-gate.sh  w204-b-gate.sh  w205-c-gate.sh
--- next (cwd = clone):
w206
  derivado do tronco remoto 'origin/develop' (máximo remoto w205) e da árvore local (máximo local w205)
rc=0
--- ls-tree origin/feat/em-voo:
tests/w203-a-gate.sh  tests/w204-b-gate.sh  tests/w205-c-gate.sh  tests/w206-emvoo-gate.sh
```

`next` devolveu `w206`, número que `origin/feat/em-voo` já publicou, e a linha de proveniência afirmou que derivou do tronco remoto — verdade parcial que soa como garantia total. A causa está em `gate-ordinal.sh:121-129`: `refs` é a lista literal `origin/develop origin/main origin/master`, e o laço **para no primeiro ref que responder** (`break` na linha 128).

### 2.2 O universo, decidido — e o caso que a enumeração de três camadas não cobria

Quatro camadas, e a quarta é a que fecha o caso real de LDG-0167:

| Camada | O que é | O que ela captura |
|---|---|---|
| U1 | a árvore de trabalho apontada por `--path` | o que esta branch tem no disco, commitado ou não — o que `next` já faz hoje |
| U2 | `refs/heads/*` do repositório de `--path` | branch local commitada e nunca publicada — a máquina do próprio operador |
| U3 | `refs/remotes/*` do repositório de `--path`, **todos os remotos**, não só `origin` | o que qualquer branch publicou em qualquer remoto conhecido |
| U4 | a árvore de trabalho de cada worktree irmã viva | arquivo criado numa worktree paralela e **ainda não commitado** |

**U4 é a camada que a enumeração de três teria perdido, e é onde o defeito de LDG-0167 mora.** O item registra que *"as duas frentes rodaram `gate-ordinal.sh next` antes de qualquer push"*. Isso é **dado do corpo do item de ledger, não medição minha** — as duas branches daquela noite não existem mais e a colisão não é reconstrutível —, e a revisão 1 fez bem em separá-la das medições. O que passa a vir com comando é a citação, para que o próximo revisor leia a fonte em vez de acreditar na paráfrase:

```
node -e 'const j=require("./.forge/ledger/ledger.json"); const e=j.entries.find(x=>x.id==="LDG-0167"); console.log(e.status, "|", e.title); console.log(e.detail)'
```

A saída de 2026-09-07 traz `open`, o título *"Duas frentes em paralelo reservaram o MESMO ordinal de gate (w200) — e o mesmo id de ledger"*, e no corpo as duas metades: `tests/w200-readme-inventory-gate.sh` contra `tests/w200-flag-como-valor-gate.sh`, e o `LDG-0166` criado duas vezes. Sem push, U3 é vazio; se a frente também não tinha commitado, U2 é vazio. O único lugar onde o `w200` da outra frente existia era o **diretório de trabalho da worktree irmã**. Uma correção que parasse em U3 fecharia LDG-0173 e deixaria LDG-0167 aberto, com a aparência de fechado.

**Os desfechos que a onda precisa cobrir, cada um medido nesta rodada:**

1. `--path` dentro de um repositório com refs → deriva de U1..U4.
2. `--path` dentro de um repositório **sem nenhum ref remoto** → degrada, e continua degradando com a declaração de hoje (medido: `w200` mais `ATENÇÃO: nenhum tronco remoto acessível … derivado SÓ DA ÁRVORE LOCAL`).
3. `--path` **fora de qualquer repositório git** → `git -C` sai `128` com `fatal: not a git repository`; degrada para U1.
4. `--path` num repositório git **sem nenhum commit** → nenhum ref resolve, o script degrada para U1 e devolve o máximo local mais um. Medido na bancada abaixo, cujo `tests/` tem `w007` e `w050`: a saída é `w51` com `rc 0` e a linha `ATENÇÃO: nenhum tronco remoto acessível (origin/develop origin/main origin/master) — derivado SÓ DA ÁRVORE LOCAL (máximo local w50).` no stderr, enquanto `git rev-parse --verify --quiet HEAD` no mesmo repositório sai `rc 1`. O `w51` é propriedade da bancada — máximo local mais um —, não constante do desfecho, e a asserção correspondente compara contra o máximo derivado na execução, nunca contra o literal. Correto por acidente hoje, e precisa continuar correto de propósito.
5. `--path` **inexistente** → medido: `w1` com `rc 0`, e **não** em silêncio — o stderr traz `ATENÇÃO: nenhum tronco remoto acessível (origin/develop origin/main origin/master) — derivado SÓ DA ÁRVORE LOCAL (máximo local w0).` A palavra certa não é silêncio e sim **indistinguibilidade**, e ela é pior: medido com `cmp`, o stdout e o stderr deste desfecho são **byte a byte idênticos** aos do desfecho (6). O defeito continua sendo defeito — número de lixo com `rc 0` sobre um caminho que não existe —, e é o único desfecho que a onda muda para recusa (§2.3, decisão 5).
6. `--path` existente e **vazio de ordinais** → `w1` é a resposta certa, e precisa vir **declarada**. É o controle positivo de (5), e hoje os dois colapsam: o `cmp` do desfecho (5) não acusa diferença nenhuma entre eles, que é a invariante 2 do plano violada dentro de um alocador. Num repositório com refs e `tests/` sem ordinal algum a saída de hoje é `w1` mais `derivado do tronco remoto 'origin/develop' (máximo remoto w0) e da árvore local (máximo local w0)`, que também não distingue "o ref não tem `tests/`" de "tem `tests/` e nenhum ordinal". A declaração ganha token próprio na decisão 6.
7. Um ref do universo **sem o diretório `tests/`** → `git ls-tree` devolve saída vazia com `rc 0`; o ref não contribui, e isso não é erro.
8. Uma worktree irmã `prunable` ou `locked`, e — separadamente — o bloco `bare` → medido em `git worktree list --porcelain` na bancada abaixo: `prunable` traz a linha `prunable gitdir file points to non-existent location` e o diretório não existe mais (pular); `locked` traz a linha `locked` e o diretório **existe** (varrer normalmente). O `bare` **não** é uma irmã, e a revisão 1 derrubou com razão a prosa que sugeria que fosse: `git worktree add --bare <path>` responde `error: unknown option 'bare'`, de modo que worktree bare não é construtível, e o bloco `worktree <path>` seguido só de `bare` aparece somente quando `worktree list --porcelain` roda **dentro de um repositório bare**, descrevendo o próprio repositório — medido num clone `--bare` cujo `<path>` contém `config`, `description` e `HEAD`, e nenhuma árvore de trabalho. A regra de pular o `bare` continua valendo e continua necessária, porque o alocador pode ser invocado a partir de um repositório bare; o que muda é a proveniência do caso, que é o primeiro bloco da listagem e não uma irmã.

**A bancada dos desfechos (4), (5), (6) e (8), colada porque número sem comando não fica.** Rodada nesta revisão, com `GIT_CONFIG_COUNT=3` desligando `gc.auto`/`maintenance.auto`/`gc.autoDetach` como `tests/run-all.sh` faz, `GO` apontando para uma cópia de `template/.forge/scripts/gate-ordinal.sh` em `$TMPDIR` e `W` sendo o diretório de bancada:

```
# (4) repositório sem nenhum commit
mkdir -p "$W/semcommit/tests" && cd "$W/semcommit" && git init -q -b develop .
: > tests/w007-x-gate.sh; : > tests/w050-x-gate.sh
bash "$GO" next --path "$W/semcommit/tests"        # → w51, rc 0, ATENÇÃO ... (máximo local w50)
git rev-parse --verify --quiet HEAD                # → rc 1

# (5) e (6) fora de qualquer repositório, e a comparação byte a byte entre os dois
mkdir -p "$W/vazio/tests" "$W/fora" && cd "$W/fora"
bash "$GO" next --path "$W/nunca/tests" >"$W/o5.out" 2>"$W/o5.err"    # → w1, rc 0
bash "$GO" next --path "$W/vazio/tests" >"$W/o6.out" 2>"$W/o6.err"    # → w1, rc 0
cmp -s "$W/o5.out" "$W/o6.out" && cmp -s "$W/o5.err" "$W/o6.err"      # → rc 0: IDÊNTICOS

# (6) variante com refs: repositório clonado cujo tests/ tem README.md e nenhum ordinal
mkdir -p "$W/up/tests" && cd "$W/up" && git init -q -b develop . && : > tests/README.md
git add -A && git -c user.email=a@b -c user.name=a commit -qm init
cd "$W" && git clone -q up cl && cd "$W/cl"
bash "$GO" next --path "$W/cl/tests"   # → w1 + "derivado do tronco remoto 'origin/develop' (máximo remoto w0) e da árvore local (máximo local w0)", stderr vazio

# (8) formas de worktree list --porcelain
git worktree add -q -b travada "$W/wt-travada"; git worktree lock "$W/wt-travada"
git worktree add -q -b sumida  "$W/wt-sumida";  rm -rf "$W/wt-sumida"
git worktree list --porcelain            # → blocos com 'locked' e com 'prunable gitdir file points to non-existent location'
git worktree add --bare "$W/wt-bare"     # → error: unknown option `bare'
git clone -q --bare "$W/main" "$W/espelho.git" && git -C "$W/espelho.git" worktree list --porcelain
                                          # → 'worktree <path>' seguido só de 'bare', e <path> tem config/description/HEAD
```

### 2.3 Decisões fechadas

**Decisão 1 — o universo é o conjunto de refs LOCAIS (`refs/heads/*` e `refs/remotes/*`) mais as worktrees vivas. A frescor dos refs remotos é responsabilidade do operador, e a saída diz isso.**
Alternativa descartada: consultar o remoto pela rede a cada invocação. Não é preferência, é impossibilidade medida. `git ls-remote` devolve apenas SHAs, e o objeto correspondente pode não estar no repositório local. Executado nesta rodada num clone criado por `file://` (transporte não-local, portanto sem compartilhamento de objetos), sobre uma branch nunca buscada:

```
$ git -C sb2 ls-remote --heads origin | awk '/feat\/em-voo/{print $1}'   → cfb23f0c…
$ git -C sb2 cat-file -e cfb23f0c…                                        → rc=1
$ git -C sb2 ls-tree --name-only cfb23f0c… tests/                         → rc=128
                                                                             fatal: not a tree object
```

Fechar essa lacuna exigiria um `git fetch` dentro do alocador, isto é, uma escrita no repositório e uma dependência de rede numa ferramenta que precisa funcionar offline. A saída honesta é ler o que está local e **declarar a data do último fetch conhecido** na linha de proveniência, para que o operador saiba o que está olhando. Registro, para não vender mais do que se entrega: num clone feito por caminho local o objeto está presente mesmo sem fetch (os dois primeiros experimentos desta rodada mostraram `ls-tree` funcionando sobre um SHA não buscado, porque `git clone` de caminho local compartilha objetos), e foi preciso o clone por `file://` para produzir o contraexemplo. A conclusão vale; o experimento que a sustenta é o segundo, não o primeiro.

**Decisão 2 — não nasce registro de reserva de ordinal.**
Alternativa descartada: um arquivo rastreado onde cada frente escreve o número que reservou. Ele teria exatamente o defeito que existe para curar: para ser visto por outra branch precisa ser **commitado e publicado**, e "em voo" quer dizer precisamente que ainda não foi. Um registro que só serve depois do push resolve o problema que o push já resolve. A variante que evitaria isso — publicar direto no tronco antes de usar — exige push em `develop`, que é dívida de processo já paga e registrada neste repositório, e depende de rede numa ferramenta que precisa funcionar sem ela.

**Decisão 3 — não nasce alocação com trava.**
Alternativa descartada: `flock` sobre um arquivo no `--git-common-dir`. Ela serializa worktrees da mesma máquina e não diz nada sobre a outra máquina, que é metade do problema; e introduz estado de trava numa ferramenta de leitura, com todo o custo de trava órfã, para cobrir um caso que U4 já cobre sem estado.

**Decisão 4 — o orçamento de processos é parte do contrato, e a unidade é a ÁRVORE distinta, nunca o ref.**
Censo dos repositórios de `~/Documents/projects`, remedido nesta revisão com o comando colado abaixo, que também produz o censo de §10 numa passada só:

```
cd ~/Documents/projects && for d in */; do [ -d "$d/.git" ] || continue
  printf '%-40s tests/w*=%-5s refs/remotes=%s\n' "${d%/}" \
    "$(git -C "$d" ls-files 'tests/w*' | wc -l | tr -d ' ')" \
    "$(git -C "$d" for-each-ref --format='%(refname)' refs/remotes/ | wc -l | tr -d ' ')"
done
```

Resultado de 2026-09-07: **20** diretórios com `.git`, e os quatro com muito ref remoto são `forge` com **1324** (dois remotos, `origin` e `upstream`), `axis-go-cloud` com **469**, `travessias-archive-2026-05-13` com **231** e `Axis.PadSimulator` com **150** (remotos `github` e `origin`). O `axis-go-cloud` tinha **474** na primeira medição desta rodada e tem **469** agora, sem nada da onda ter tocado nele: é a demonstração mais barata de que estes números são **testemunha de data**, nunca critério, e nenhuma asserção desta onda os usa.

Os tempos, remedidos no mesmo repositório com `time` e com as duas passadas registradas porque a primeira é de cache frio:

```
cd ~/Documents/projects/axis-go-cloud
time ( git for-each-ref --format='%(refname)' refs/remotes/ | while read -r r; do git ls-tree --name-only "$r" tests/ >/dev/null 2>&1; done )
time ( git for-each-ref --format='%(refname)' refs/remotes/ | sed 's|$|:tests|' | git cat-file --batch-check > /tmp/bc.out 2>/dev/null )
awk '$2=="tree"{print $1}' /tmp/bc.out | sort -u | wc -l
```

Um `git ls-tree` por ref, sobre os 469 refs, gastou **10,36 s de CPU** (`4,01s user + 6,35s system`) e **49,1 s de relógio** na passada quente — **63,8 s** na fria. A invocação única de `git cat-file --batch-check` gastou **0,11 s de CPU** e **1,89 s de relógio** na quente, colapsando os 469 refs em **23 sub-árvores distintas**. Reporto CPU **e** relógio de propósito: o relógio varia com o estado do cache e com o que mais está rodando na máquina — a primeira medição desta rodada registrou 13,35 s e 1,17 s, números que não reproduzi —, enquanto o custo de CPU é estável e é ele que carrega o argumento. O que sustenta a decisão não é nenhum dos absolutos e sim a **razão** entre as duas formas, de duas ordens de grandeza em qualquer das passadas, e o fato de o laço disparar um processo por ref. A saída do primitivo foi medida e distingue os dois casos que importam:

```
$ printf 'origin/develop:tests\norigin/develop:nao-existe\nref/inexistente:tests\n' | git cat-file --batch-check
b915ac3564fbfb26931f2bfc36e8ac25c5f40b87 tree 7370
origin/develop:nao-existe missing
ref/inexistente:tests missing
rc=0
```

**E o orçamento tem uma âncora de gate que já existe, medida nesta rodada:** `w193[4]` e `[5]` invocam `next` dentro de `_run_to 30`, um alarme de trinta segundos (`tests/w193-tree-derived-state-gate.sh:99` e `:111`). Uma implementação que gastasse os 49 s medidos num repositório de 469 refs não estouraria essa fixture, que tem poucos refs — o alarme não é a prova do orçamento, e `[9]` existe justamente porque ele não é. Mas ele é o piso de sanidade que impede a regressão mais grosseira de passar despercebida na suíte.

**A especificação declara a propriedade, não o primitivo** (invariante 19): *o número de processos `git` que o alocador dispara cresce com o número de árvores `tests/` distintas no universo, não com o número de refs*. O `cat-file --batch-check` acima é **uma** implementação que satisfaz a propriedade, e eu a executei — quem implementar pode escolher outra, desde que prove a discriminação pelo cenário `[9]` de §7.1.

**Decisão 5 — `--path` inexistente passa a RECUSAR, com `rc 2`.**
Medido: hoje `next --path <inexistente>` devolve `w1` com `rc 0`, enquanto `check --path <inexistente>` já reprova pelo `forge_universe_check` com `FAIL gate-ordinal/universo-vazio`. Duas metades do mesmo script com disciplinas opostas sobre o mesmo erro. `rc 2` porque a tabela do próprio script já usa `2` para uso incorreto (`--path exige um argumento`, `comando desconhecido`), e caminho que não existe é uso incorreto, não violação. O desfecho (6) de §2.2 — diretório presente e vazio — continua devolvendo `w1`, declarando que o universo estava vazio: é a diferença entre "não achei nada" e "não olhei em lugar nenhum", que é a invariante 2 do plano aplicada a um alocador.

**Decisão 6 — a linha de proveniência passa a publicar um contador, e a forma preserva os tokens que os gates existentes afirmam.**
Varredura da invariante 15, executada nesta rodada sobre `tests/`, para cada string que `next` imprime hoje. Dois gates afirmam essas strings, e nenhum outro:

| Gate | Cenário | O que afirma | Sobrevive? |
|---|---|---|---|
| `tests/w193-tree-derived-state-gate.sh` | `[4]`, linhas 101-103 | `grep -q "w201"` e `grep -qi "remoto\|origin"` | sim, se a linha nova continuar contendo `remoto` ou `origin` |
| `tests/w193-tree-derived-state-gate.sh` | `[5]`, linhas 113-115 | `grep -q "w200"` e `grep -qi "só da árvore local\|apenas da árvore local\|sem remoto"` | sim, se a degradação preservar uma das três formas |
| `tests/w193-tree-derived-state-gate.sh` | `[3]`, linha 83 | `sed -n 's/.*OK gate-ordinal — \([0-9][0-9]*\) .*/\1/p'` sobre a saída de `check` | sim — `check` não muda nesta onda |
| `tests/w204-ordinal-root-resolution-gate.sh` | `[1]`-`[4]` | só o ordinal, por `head -1`; nenhuma asserção sobre a mensagem | sim |

`template/.forge/rules/testing/quality-gates.md:112` descreve o mecanismo em prosa — *"deriva do tronco remoto (`git ls-tree origin/develop`)"* — e passa a mentir com a correção. **A rule é editada no mesmo PR**, e essa edição entra na definição de pronto (§11). `grep -rn 'gate-ordinal' template/.forge/rules/` devolve apenas as linhas 112 e 114 desse arquivo, remedido nesta revisão; `CHANGELOG.md` cita o mecanismo antigo em duas entradas históricas, que **não** são editadas, porque changelog descreve o que aquela versão fez.

**Os três tokens que a decisão FIXA, e a razão de o terceiro nascer nesta revisão.** A revisão 1 mostrou que a especificação fixava o vocabulário do caso derivado e do caso degradado e deixava o caso de **universo vazio** sem token nenhum, o que permitiria ao implementador considerar a mensagem de degradação de hoje como já satisfazendo a declaração — e o cenário `[6]` nasceria verde sem exercer verificação nova. Os três, agora:

| Situação | Token fixado | Canal | Distinção que ele carrega |
|---|---|---|---|
| derivou de ao menos um ref | `remoto` ou `origin` | stdout | é o que `w193[4]` afirma |
| nenhum ref **remoto** acessível | `sem remoto` (ou `só da árvore local`/`apenas da árvore local`) | stderr | é o que `w193[5]` afirma |
| universo examinado e **sem nenhum ordinal em uso** | `sem ordinal em uso` | stdout, ao lado dos contadores de `[7]` | separa "olhei e não havia número tomado" de "não olhei" |

O token novo é `sem ordinal em uso`, e ele é **exigido em letra como distinto** dos dois anteriores: uma implementação que reaproveitasse `sem remoto` para declarar universo vazio colapsaria de novo os dois estados que a invariante 2 manda separar. Medido nesta revisão para escolher a forma sem colidir com vocabulário instalado: `grep -rn 'universo-vazio' tests/*.sh` devolve **13** linhas e `grep -rn 'universo vazio' tests/*.sh` devolve **42**, todas sobre a recusa de `forge_universe_check` — que é `rc 1` e é outra coisa, porque ali o universo vazio **reprova**, enquanto no `next` ele é resposta legítima com `rc 0`. Por isso o token novo não reusa nenhuma das duas formas.

**Decisão 21 — sob `--remote <ref>` o universo é U1 mais o ref nomeado, e nada mais. A numeração desta decisão é por ordem de criação, não por posição: ela nasceu na revisão 1, quando o revisor mostrou que §2.3 declarava fechada uma semântica que não fechava.**

A revisão 1 acertou o diagnóstico e eu remedi o comportamento de hoje para fechar a decisão em vez de a supor. Medido nesta revisão, numa bancada em que a árvore local está em `develop` com `tests/w010` e `tests/w011`, `refs/heads/feat/local` tem `tests/w050` commitado e `origin/develop` tem os mesmos `w010`/`w011`:

```
git for-each-ref --format='%(refname)' refs/heads refs/remotes
# refs/heads/develop  refs/heads/feat/local  refs/remotes/origin/HEAD  refs/remotes/origin/develop
bash "$GO" next --path "$W/R/cl/tests" --remote origin/develop   # → w12  (derivado ... máximo remoto w11 ... máximo local w11)
bash "$GO" next --path "$W/R/cl/tests"                            # → w12  (idêntico: a flag não muda nada nesta fixture)
bash "$GO" next --path "$W/R/cl/tests" --remote origin/nao-existe # → w12  com a linha de degradação
```

O que a medição prova sobre hoje: `--remote` substitui a **lista de refs** (`gate-ordinal.sh:120`, `refs="$REMOTE_REF"`, com o default literal de três nomes na linha 121) e U1 continua entrando pelo `max="$local_max"` da linha 131 — logo a leitura "use este ref e só ele" é **falsa hoje**, e a especificação não podia declará-la fechada. As duas leituras que a redação anterior admitia divergem exatamente nesta fixture: universo `{U1, ref}` devolve `w12`, universo `{U1, U2, U4, ref}` devolve `w51`, porque `refs/heads/feat/local` carrega `w050`.

**A decisão é `{U1, ref}`**, isto é, `--remote` suprime U2, U3 e U4 e preserva U1. Três razões, e a primeira é a que decide: é a **continuação exata** do que o script faz hoje, e uma flag pública instalada no tarball não muda de significado numa onda cujo assunto é outro. A segunda é o propósito da flag, que é responder pelo ref que o operador nomeou — uma flag que ainda assim consultasse todas as branches locais não restringiria nada e a cláusula de contrato de §9 ficaria sem referente. A terceira é que o modo restrito fica **estritamente menos seguro** que o padrão, e isso é aceitável apenas porque é explícito: por isso a decisão vem com obrigação de saída, e a linha de proveniência sob `--remote` tem de **declarar que o universo foi restringido pela flag e nomear as camadas suprimidas**, na mesma disciplina da decisão 6.

**A fixture do teste de contrato, com o ordinal esperado, é a de cima.** Com `--remote origin/develop` a resposta esperada depois da onda é `w12`; sem a flag, sobre a mesma fixture, a resposta esperada é `w51`, porque U2 passa a contribuir. O vermelho de hoje é literal e é o mais barato de ler: as duas invocações devolvem `w12`, isto é, hoje `--remote` é indistinguível de não passar flag nenhuma nesta fixture, que é a definição operacional de flag decorativa. O teste de contrato reprova nos dois sentidos — quando `--remote` deixa de restringir (as duas respostas voltam a coincidir) e quando a restrição vaza para o caso sem flag (a resposta sem flag deixa de enxergar U2).

---

## 3. LDG-0158 — o `-C` ausente, e a armadilha do `/private` do macOS

### 3.1 O defeito, reproduzido

Duas bancadas independentes, `A` (remoto com `tests/w300`) e `B` (remoto e árvore com `w010`/`w011`), montadas nesta rodada:

```
=== next --path B/cl/tests, com cwd = A/cl:
w301
  derivado do tronco remoto 'origin/develop' (máximo remoto w300) e da árvore local (máximo local w11)
rc=0
=== next --path B/cl/tests, com cwd = B/cl (controle):
w12
  derivado do tronco remoto 'origin/develop' (máximo remoto w11) e da árvore local (máximo local w11)
rc=0
=== cwd fora de qualquer repositório git:
w12
  ATENÇÃO: nenhum tronco remoto acessível … derivado SÓ DA ÁRVORE LOCAL (máximo local w11)
rc=0
```

A mesma pergunta, três respostas. Pior que o número errado é a **linha de proveniência**: ela nomeia `origin/develop` sem dizer de qual repositório, e o repositório é o do diretório corrente. `gate-ordinal.sh:123` e `:124` são `git rev-parse --verify --quiet "$ref"` e `git ls-tree --name-only "$ref" "$rel/"`, ambos sem `-C`.

### 3.2 Decisão fechada, e a armadilha medida

O repositório de referência é o que **contém `--path`**, resolvido por `git -C "$TESTS_DIR" rev-parse --show-toplevel`. Medido nesta rodada:

```
$ git -C <dir fora de repo> rev-parse --show-toplevel   → rc=128  fatal: not a git repository …
$ git -C <dir inexistente>  rev-parse --show-toplevel   → rc=128  fatal: cannot change to '…': No such file or directory
$ git -C <dir dentro de repo> rev-parse --show-toplevel → rc=0    /private/var/folders/…/Bb/cl
```

**A armadilha:** `--path` foi passado como `/var/folders/…/Bb/cl/tests` e o `--show-toplevel` devolveu `/private/var/folders/…/Bb/cl`. No macOS `/var` é symlink para `/private/var`, e o git resolve o caminho físico. O cálculo de `rel` do script — `rel="${TESTS_DIR#"$ROOT"/}"`, `gate-ordinal.sh:118-119` — compara os dois textualmente: com prefixos diferentes o strip não acontece, `rel` cai no fallback literal `tests`, e o ordinal derivado do ref passa a olhar um caminho que pode nem existir naquele ref. A onda resolve os dois lados pelo mesmo caminho físico antes de comparar. Uma implementação que só acrescente `-C` e deixe o `rel` como está fica meio corrigida, e o cenário `[4]` de §7.1 é escrito para pegar exatamente isso: ele exige **igualdade das três invocações**, não apenas que a de fora do repositório pare de ganhar o remoto errado.

---

## 4. LDG-0167 — a segunda maquinaria: id de ledger

### 4.1 O defeito, reproduzido

Medido no repositório real nesta rodada, com `git show <ref>:.forge/ledger/ledger.json` e o mesmo `max` que `ledger-ops.sh add` calcula:

| ref | máximo LDG |
|---|---|
| `origin/develop` | 176 |
| `origin/main` | 174 |
| `origin/wip/upgrade-safety-ldg-0131` | 60 |
| `origin/wip/deepspec-run-manifest-ldg-0165` | **o arquivo não existe nesse ref** |
| arquivo do disco | 176 |

`ledger-ops.sh:163` (dentro do heredoc de `add`) calcula `max` sobre `data.entries` do **arquivo do disco** e nada mais. Uma branch com ledger à frente é invisível, e o id sai repetido — a segunda metade de LDG-0167.

### 4.2 O desfecho que a enumeração ingênua perderia

O quarto ref acima é o caso não coberto, e ele é real, não hipotético:

```
$ git show origin/wip/deepspec-run-manifest-ldg-0165:.forge/ledger/ledger.json
fatal: path '.forge/ledger/ledger.json' exists on disk, but not in 'origin/wip/…'
rc=128
```

Uma implementação que canalize `git show` para um parser de JSON e trate falha de parse como `max = 0` conta esse ref como se ele tivesse zero entradas — e o resultado fica **correto por acidente**, porque `max` é uma operação de máximo e zero nunca ganha. Ele deixa de ser correto no dia em que a mesma rotina for usada para "quantos refs contribuíram", que é justamente o contador de controle. **Decisão:** ref sem o arquivo é `pulado` e contabilizado numa terceira contagem — examinados, contribuíram, sem ledger — e as três aparecem na saída.

### 4.3 Decisões fechadas

**Decisão 7 — `add` calcula `max + 1` sobre a união de U1 (arquivo do disco), U2 (`refs/heads/*`) e U3 (`refs/remotes/*`). U4 não entra.**
U4 é desnecessário aqui por medição, não por esquecimento: `ledger-ops.sh:75` resolve `ROOT` por `forge_resolve_root`, que devolve o checkout principal, então todas as worktrees do mesmo repositório escrevem no **mesmo** `ledger.json`. O que elas não compartilham é o conteúdo entre branches (§1.2), e isso é U2/U3.

**Decisão 8 — buracos na sequência de ids passam a ser legítimos, e o schema diz isso.**
`template/.forge/schemas/ledger.schema.json` descreve `id` como *"Contador global monotônico (max existente + 1)"*. Com a união, uma árvore cujo arquivo local vai até 176 e cuja branch vizinha vai até 180 produz `LDG-0181` e deixa 177-180 vagos naquela árvore. A descrição do schema passa a dizer "maior id conhecido no repositório + 1, contando as branches; buracos são esperados e são o preço da unicidade". Executado nesta rodada, nenhum gate afirma contiguidade: `grep -rn 'max + 1\|max+1\|sequencial\|contígu\|gap' tests/w157*.sh tests/w202*.sh tests/w98*.sh template/.forge/schemas/ledger.schema.json` devolve zero linhas.

**Decisão 9 — nasce o detector de id duplicado, e ele é a metade que funciona sem rede.**
É a simetria exata de `gate-ordinal.sh check`, e ela não existe. Remedido nesta revisão, e a formulação passa a dizer o número em vez de dizer "nenhuma", porque a revisão 1 notou com razão que esta varredura convive no mesmo parágrafo com outras cujo resultado é literalmente zero linhas: `grep -rn 'entries.map(e=>e.id)\|new Set(.*\.id)\|id.*duplicad' template/.forge/scripts/ tests/ | wc -l` devolve **15**, e `… | grep -c 'LDG-'` devolve **0** — quinze linhas, todas sobre ids de grafo e de task, **nenhuma** sobre id de ledger. O detector reprova quando dois ids coincidem, nomeando o id e as duas entradas, com contador de controle e piso. O canal de entrega é o gate da suíte que já roda sobre o `ledger.json` **real** — o mesmo canal de `w157[1]` e `w202[1]` —, e é ele que faz a colisão aparecer no push de quem a criou em vez de no merge de quem não tem contexto.

**Decisão 10 — o comentário de `gate-ordinal.sh:9-12` e a nota de resolução de LDG-0067 são corrigidos.**
§1.2. Um comentário que declara serialização inexistente é a razão documentada de não se ter feito nada, e deixá-lo em pé entrega o item de novo daqui a três meses.

---

## 5. #103 — o que sobrou, medido, porque a issue está defasada

### 5.1 O núcleo da issue JÁ está fechado, e a especificação precisa dizer isso antes de propor trabalho

O corpo de #103 pede o critério de **pertencimento ao conjunto de flags declaradas**, e ele existe: `template/.forge/scripts/lib/arg-guards.sh:64-82` é `forge_reject_flag_as_value`, com `return 0` explícito no caminho de aceite. Bancada nesta rodada, com `.forge/` do template copiado para `$TMPDIR`:

```
$ ledger-ops.sh add --type roadmap --title --detail
FAIL: '--title' recebeu '--detail' como valor no subcomando 'add' — '--detail' é uma flag aceita em 'add', não conteúdo.
rc=1
$ ledger-ops.sh update LDG-0001 --detail --title
FAIL: '--detail' recebeu '--title' como valor no subcomando 'update' — …
rc=1
$ ledger-ops.sh list --top -3            → rc=0, lista normalmente
$ ledger-ops.sh add … --detail '---frontmatter'  → rc=0, grava o literal
```

Os dois controles que a issue exige (`--top -3` e `---frontmatter`) passam. O aviso do mandato desta onda — *"lib/arg-guards.sh já existe e sai com rc 1 — meça antes de assumir rc"* — está confirmado: `forge_reject_unknown` e `forge_reject_flag_as_value` encerram o processo com `exit 1`, e `forge_require_value` também. Nenhum rc novo é inventado nesta onda.

A cláusula "levar junto" também está parcialmente entregue e a issue não foi atualizada: `deferral-ops.sh` **não** termina mais em `*) shift ;;`. As linhas 52 e 78 citadas no corpo da issue e no mandato desta onda não existem mais com esse conteúdo; hoje são `deferral-ops.sh:66` e `:93`, e ambas chamam `forge_reject_unknown`. Medido: `deferral-ops.sh raise demo --reason "motivo real" --blockss archive` reprova com `rc 1`.

### 5.2 O que sobrou, com o censo completo das portas

Censo dos subcomandos, derivado do `case` principal de cada script com o comando colado — e a armadilha dos **dois** `case "$cmd" in` de `ledger-ops.sh` (linhas 123 e 128) já está dentro dele, porque o `f==2` é que pula o bloco de aviso de raiz:

```
awk '/^case "\$cmd" in$/{f++} f==2 && /^[a-z][a-z-]*\)$/{print}' template/.forge/scripts/ledger-ops.sh
grep -n 'case "\$cmd" in' template/.forge/scripts/ledger-ops.sh      # → 123 e 128
```

`ledger-ops.sh` tem **8** (`add`, `update`, `resolve`, `promote`, `harvest`, `render`, `status`, `list`) e `deferral-ops.sh` tem **4** (`raise`, `resolve`, `test`, `status`), **12** no total. Cada um exercitado com um argumento que ele não conhece, nesta rodada:

| Porta | Hoje | Fecha nesta onda? |
|---|---|---|
| `ledger-ops.sh render --lixo` | `OK <path>`, `rc 0` — argumento engolido | sim |
| `ledger-ops.sh status --lixo` | `LEDGER: vazio`, `rc 0` — engolido | sim |
| `deferral-ops.sh status <id> --lixo` | `OPEN (1/1 open: DEFER-01)`, `rc 0` — engolido | sim |
| `deferral-ops.sh test <id> DEFER-01 --lixo` | **`OK test — DEFER-01 marcado como tested`, `rc 0`** — engolido, e o registro muda de estado | sim |
| `ledger-ops.sh` `add`/`update`/`resolve`/`promote`/`harvest`/`list` | recusam, `rc 1` | já fechado |
| `deferral-ops.sh` `raise`/`resolve` | recusam, `rc 1` | já fechado |

A quarta linha merece a ênfase: `test` **grava** com o argumento desconhecido no chão. A primeira tentativa desta medição saiu `rc 1` e me enganou por um instante — a recusa vinha de `deferral-ops.sh:123` (*"deve estar resolved antes de testar"*), não da disciplina de argumento. Foi preciso levar o deferral a `resolved` primeiro para ver o `OK test` com o `--lixo` ignorado. Registro o passo em falso porque ele é a forma mais barata de um revisor concluir que a porta está fechada quando não está.

**O quinto item, que não é de parsing:** `ledger-ops.sh resolve` repetido sobre entrada já terminal. Medido:

```
$ ledger-ops.sh resolve LDG-0001 --note "primeira nota"   → OK resolve — LDG-0001 marcado como resolved   rc=0
$ ledger-ops.sh resolve LDG-0001 --note "segunda nota"    → OK resolve — LDG-0001 marcado como resolved   rc=0
  detail final: "conteudo — Resolvido: primeira nota — Resolvido: segunda nota"
  resolved_at recarimbado
```

É a mesma classe de `update` sem efeito, que já tem disciplina de no-op (`ledger-ops.sh:230`, com o `NOCHANGE` e o `rc 3` do heredoc traduzido para `rc 1`), e `resolve` ficou de fora.

### 5.3 Decisões fechadas

**Decisão 11 — as quatro portas ganham o laço de recusa, e `test`/`status`/`render` declaram conjunto de flags vazio com um literal legível.**
`forge_reject_unknown <sub> <flags aceitas> <arg>` imprime `flags aceitas em '<sub>': <lista>`; com lista vazia a linha sairia truncada. O literal passa a ser `(nenhuma)` para os subcomandos que não aceitam flag. É acréscimo de argumento, não de assinatura: a função continua com a mesma aridade.

**Decisão 12 — `resolve` recusa quando a entrada já está em estado terminal (`resolved` ou `wont-fix`), com `rc 1`, nomeando o estado atual e o `resolved_at` que já existe, e não grava nada.**
Alternativa descartada (a): tornar o `resolve` idempotente-silencioso quando a nota for idêntica. Descartada porque o caso real não é a nota idêntica — é a nota **diferente**, que hoje é anexada por cima e faz o `detail` narrar dois fechamentos do mesmo item. Alternativa descartada (b): um `--again` para reabrir e refechar. Descartada porque a porta certa para reabrir já existe (`update --status open`) e criar uma segunda dobraria a superfície para cobrir um caso que ninguém pediu.

**Decisão 13 — os dois chamadores de produção param de engolir o stderr do `resolve`.**
Medido: `archive-spec.sh:108` e `spec-close.sh:85` chamam `ledger-ops.sh resolve … >/dev/null 2>&1 && echo "ledger: …" || echo "WARN: ledger resolve de … falhou (não-bloqueante)"`. Com a decisão 12, uma entrada já terminal passaria a produzir a palavra `falhou` sobre um estado que não é falha, e o motivo estaria descartado pelo `2>&1`. A correção é de um token: `2>&1` sai, o stderr do script explica, e a mensagem do `||` passa a dizer que **não gravou** em vez de que **falhou**. Verificado que nenhum gate afirma essas strings: `grep -rn 'ledger resolve de\|entregue ao baseline\|entregue externamente' tests/*.sh` devolve zero linhas, remedido nesta revisão.

**A varredura simétrica, acrescentada na revisão 1 e agora medida.** Conferir presença de string não cobre o risco inverso: um gate que compare o **stdout** de `spec-close.sh`/`archive-spec.sh` por igualdade, ou que conte linhas, passaria a ver o stderr do `resolve` vazando quando o `2>&1` sair. Medido:

```
grep -rn 'spec-close\.sh\|archive-spec\.sh' tests/*.sh | wc -l                                   # → 23 linhas, em 9 gates
grep -rn -A4 'archive-spec\.sh\|spec-close\.sh' tests/*.sh | grep -cE '= *"\$out|wc -l|diff |cmp '  # → 0
grep -rn -A4 'archive-spec\.sh\|spec-close\.sh' tests/*.sh | grep -c 'grep -q'                     # → 16
```

Vinte e três invocações dos dois scripts, distribuídas em nove gates (`w22`, `w32`, `w33`, `w98`, `w100`, `w106`, `w107`, `w113`, `w172`), e **zero** asserções por igualdade, `wc -l`, `diff` ou `cmp` sobre a saída capturada — as dezesseis asserções sobre ela são todas `grep -q`, que é insensível a linha a mais. Vale registrar a ironia útil: vários desses gates capturam a saída **já com `2>&1`** (por exemplo `w32:152`, `w32:178`, `w106:232`), de modo que o stderr que a decisão 13 liberta cairia dentro da mesma variável — e mesmo assim nenhuma asserção quebra, porque nenhuma delas é de igualdade. O risco simétrico existe como classe e está medido em zero nesta árvore.

**A quebra que essa decisão NÃO causa, medida:** `w98[3]` e `w32[1]` exercitam o canal real (`close delivered-externally` e `archive` sobre um change com `ledger_origin`). Nos dois, a entrada está em `promoted` quando o `resolve` chega — `spec new --from-ledger` a coloca lá —, e `promoted` não é estado terminal. Confirmado na bancada: `resolve` sobre entrada `promoted` devolve `rc 0` e carimba. Os dois gates seguem verdes sem edição.

**Decisão 14 — `promote` repetido NÃO é tocado.**
Medido: `promote LDG-0001 --to ch1` seguido de `promote LDG-0001 --to ch2` devolve `rc 0` nas duas e deixa `promoted_to: "ch2"` com `change: ["ch1","ch2"]`. Isso é repromoção, não no-op: o item de fato passou a ser carregado por outro change, e o histórico dos dois fica em `links.change`. Não há dano medido, e alargar o escopo aqui misturaria assunto num diff. Fica registrado como observação, não como item.

---

## 6. LDG-0140 — a decisão de produto do `harvest`

### 6.1 O defeito, reproduzido, e a prova de que as entradas nasceram vazias

Bancada com um change contendo `analysis.md` (uma linha `MEDIUM`) e `verification.md` (dois bullets sob `## Follow-ups abertos`), nesta rodada:

```
$ ledger-ops.sh harvest demo-change --origin close
OK harvest demo-change (close) — 3 nova(s) entrada(s) no ledger      rc=0
{"id":"LDG-0001","type":"tech-debt","title":"acoplamento entre o leitor e o renderizador","detail":"","severity":"MEDIUM","priority":null,"ref":"AN-01"}
{"id":"LDG-0002","type":"follow-up","title":"O parser de rota ignora rotas com prefixo dinâmico","detail":"","severity":null,"priority":null,"ref":"verify-1"}
{"id":"LDG-0003","type":"follow-up","title":"Falta cobertura de PBT no normalizador de caminho","detail":"","severity":null,"priority":null,"ref":"verify-2"}
```

Três entradas, `detail` vazio nas três, `priority` nula nas três, `rc 0`, e **nenhum aviso** — enquanto `add` sem `--detail` emite `WARN: … nasceu SEM CONTEÚDO …` pelo mesmo motivo, no mesmo arquivo.

No ledger real, `origin: close|archive` responde por **8** entradas, e as 8 têm `priority: null`. As 8 aparecem hoje com `detail` preenchido, e isso **não** contradiz o defeito — é o `resolve` que preencheu: `ledger-ops.sh:273` compõe `detail = (e.detail ? e.detail + ' — ' : '') + label + ': ' + note`, e as 8 começam literalmente com `Resolvido: `, sem o ` — ` que existiria se houvesse conteúdo anterior. O `detail` vazio de nascença está provado pela ausência do separador, não por suposição.

Comparação que decide a segunda metade da questão, remedida nesta revisão no ledger real por origem, com o comando colado — o campo é `source.origin`, não um `origin` de topo, e essa é a armadilha que faz a mesma consulta escrita de memória devolver "107 manuais":

```
node -e '
const j=require("./.forge/ledger/ledger.json"); const g={};
for(const e of j.entries){ const s=e.source||{};
  const o=(s.origin==="close"||s.origin==="archive")?"harvest(close|archive)":(s.origin||"(sem origin)");
  g[o]=g[o]||{total:0,com_priority:0,com_detail:0,detail_comeca_Resolvido:0};
  g[o].total++; if(e.priority)g[o].com_priority++; if(e.detail)g[o].com_detail++;
  if(/^Resolvido: /.test(e.detail||"")) g[o].detail_comeca_Resolvido++; }
for(const k of Object.keys(g).sort()) console.log(k.padEnd(24), JSON.stringify(g[k]));
console.log("TOTAL", j.entries.length);'
```

Saída de 2026-09-07:

```
harvest(close|archive)   {"total":8,"com_priority":0,"com_detail":8,"detail_comeca_Resolvido":8}
manual                   {"total":97,"com_priority":95,"com_detail":97,"detail_comeca_Resolvido":3}
session                  {"total":2,"com_priority":2,"com_detail":2,"detail_comeca_Resolvido":0}
TOTAL 107
```

Os `8` de `detail_comeca_Resolvido` sobre `8` de total é a prova do nascimento vazio, e ela é do mesmo comando: se houvesse conteúdo anterior, o `detail` começaria por ele e o `Resolvido: ` viria depois de um ` — `. Os mesmos números em forma de tabela:

| origem | total | com `priority` | com `detail` |
|---|---|---|---|
| `manual` | 97 | 95 | 97 |
| `session` | 2 | 2 | 2 |
| `close` + `archive` (harvest) | 8 | **0** | 8 (todos por `resolve`, não por nascença) |

### 6.2 A decisão de produto, fechada

**Decisão 15 — o `harvest` continua sendo best-effort e continua não falhando o chamador. Ele passa a PREENCHER, não a recusar.**
Alternativa descartada: recusar a criação quando não há `detail`. Descartada por medição do dano: o `harvest` roda em `spec-close.sh:73` e `archive-spec.sh:103` **imediatamente antes de a pasta do change ser movida**, isto é, no último instante em que o dado existe. Recusar apagaria o achado em vez de o registrar incompleto, o que é estritamente pior. Registro, porque a leitura ingênua sugere o contrário: os dois chamadores já protegem o rc com `|| echo "WARN: … (não-bloqueante)"`, então tecnicamente o `harvest` **poderia** sair diferente de zero sem abortar o `close`. A promessa do cabeçalho — *"harvest … NUNCA falha o caller"* — não é o que impede a recusa; o que a impede é a perda do dado.

**Decisão 16 — `detail` é preenchido com a PROVENIÊNCIA, que sempre existe, por ser o único material que o `harvest` de fato tem.**
Os três caminhos de coleta e o que cada um pode escrever, todos determinísticos e sem inferência semântica:

| Caminho | `detail` hoje | `detail` a partir desta onda |
|---|---|---|
| `deferrals.json` | `d.reason` — já não vazio | inalterado |
| `analysis.md` | `''` | a linha de origem: change, `analysis.md`, o id da linha (`AN-01`) e a severidade lida |
| `verification.md` | `''` | a linha de origem: change, `verification.md`, o heading sob o qual o bullet estava e qual das duas portas de marcação o casou (`PENDENTE:` ou heading dedicado) |

Não é conteúdo inventado: é o endereço de onde o item veio, que é exatamente o que falta a quem lê a entrada dois meses depois e não consegue reconstruir o que ela queria dizer. A pasta do change já terá sido movida para `specs/archived/`, e o `detail` passa a dizer para onde olhar.

**Decisão 17 — `priority` é derivada da severidade por um mapeamento declarado, e a ausência de severidade vira `P3`.**
Mapeamento total sobre o domínio do enum de `severity` do schema — `BLOCKER`, `HIGH`, `MEDIUM`, `LOW`, `null`: `BLOCKER → P1`, `HIGH → P1`, `MEDIUM → P2`, `LOW → P3`, `null → P3`. `P0` não é alcançável por harvest, de propósito: `P0` é decisão de dono, e o `harvest` não é dono de nada. `BLOCKER` e `HIGH` não chegam hoje pelo caminho de `analysis.md` — o comentário de `ledger-ops.sh:354` diz que são gate-resolvidos antes —, e entram no mapeamento porque um caminho futuro pode trazê-los e um mapeamento parcial produziria `null` de novo, em silêncio.
Alternativa descartada: deixar `priority` nula e só avisar. Descartada pela tabela de §6.1: `0` de `8` entradas de harvest receberam prioridade por curadoria, contra `95` de `97` manuais. O caminho "avisa e espera curadoria" já foi testado pelo campo e não produziu curadoria nenhuma. `P3` não é um palpite sobre a importância do item: é o **piso**, a posição de quem ainda não foi avaliado, e `ledger-render`/`list --by-priority` já ordenam por ele.

**Decisão 18 — o `harvest` passa a AVISAR, na mesma forma do `add`, nomeando os ids que nasceram com `priority` derivada e não curada.**
O aviso vai para stderr, como o do `add`, e não muda o rc. É a peça que torna a lacuna visível em vez de silenciosa — e é o que faz a decisão 17 ser um piso declarado em vez de um dado fabricado que se passa por curadoria.

**Decisão 19 — as 8 entradas históricas com `priority: null` NÃO são retrofitadas.**
Elas estão todas `resolved`; carimbar prioridade em item fechado é reescrever histórico para satisfazer um gate. Consequência direta para o desenho do gate: a asserção nova de "toda entrada de harvest tem `detail` e `priority`" vale sobre a **saída do `harvest` numa fixture**, nunca sobre o `ledger.json` real. Um gate escrito sobre o ledger real nasceria vermelho sobre 8 entradas legítimas, e a saída mais provável de quem o encontrasse assim seria afrouxar a asserção.

---

## 7. O vermelho, antes do verde

Todo cenário abaixo falha hoje **pela ausência real da funcionalidade**, e o parágrafo *"como falha hoje"* de cada um cita a medição desta rodada ou a linha do arquivo que não existe.

### 7.1 No gate novo do alocador (ordinal e id de ledger)

O gate é um só. Ordinal de gate e id de ledger são duas maquinarias com a mesma classe de defeito, e LDG-0167 é literalmente o item que as junta; separá-los custaria dois ordinais e duplicaria a bancada de refs.

**`[1]` — universo inclui branch remota em voo.** Fixture de §2.1. Asserções: o ordinal devolvido é estritamente maior que o máximo de **todos** os refs, e a saída nomeia o ref que forneceu o máximo. *Como falha hoje:* devolve `w206`, medido em §2.1; `gate-ordinal.sh:121` é uma lista literal de três nomes e `:128` é um `break`.

**`[2]` — universo inclui head LOCAL nunca publicado.** Repositório sem remoto, `develop` com `w205`, branch local `feat/y` com `w206` commitado, árvore posicionada em `develop`. Asserção: ordinal `> w206`. *Como falha hoje:* `refs/heads/*` não aparece em lugar nenhum de `gate-ordinal.sh` — `grep -n 'refs/heads' template/.forge/scripts/gate-ordinal.sh` devolve zero linhas.

**`[3]` — universo inclui a árvore de trabalho de worktree irmã, com o arquivo NÃO commitado, e as formas de `worktree list` são tratadas.** `git worktree add`, criação de `tests/w206-…-gate.sh` na irmã sem commit, `next` invocado do principal. A mesma fixture carrega uma irmã removida do disco (`prunable`) e uma irmã `locked`. Três asserções, todas neste cenário: o ordinal devolvido é `> w206`; a irmã `prunable` é pulada **sem erro** (o `rc` não muda e o contador de worktrees varridas não a conta); a irmã `locked` é varrida normalmente, e um arquivo criado dentro dela contribui. *Como falha hoje:* `grep -n 'worktree' template/.forge/scripts/gate-ordinal.sh` devolve três linhas, e as três são `forge_worktree_root` (a resolução de raiz que o w204 instalou) ou prosa sobre ela; nenhuma é `git worktree list` — não há leitor, então as três asserções caem juntas. É o cenário que corresponde ao caso real de LDG-0167 e o único que `[1]` e `[2]` não cobrem.

*Nota de revisão:* na revisão 1 estas asserções viviam num rótulo próprio, chamado ali de 3b, e o revisor mostrou que isso tornava `CENARIOS_NOMINAL = 19` aritmeticamente impossível — eram vinte rótulos. Elas passam a ser asserções de `[3]`, o que é o desenho correto de todo modo: `prunable` e `locked` são **formas de entrada** do mesmo leitor de worktrees que `[3]` exercita, não cenários independentes dele.

**`[4]` — invariância ao cwd.** `next --path P` executado de três lugares: de dentro de `P`, de dentro de outro repositório, e de fora de qualquer repositório. Asserção: **as três primeiras linhas de stdout são idênticas**. *Como falha hoje:* `w12`, `w301` e `w12`, medido em §3.1.

**`[5]` — `--path` inexistente recusa.** Asserções: `rc` diferente de zero, a saída nomeia o caminho, e a saída **não** contém `^w[0-9]+$` como primeira linha. *Como falha hoje:* devolve `w1` com `rc 0`, medido em §2.2.

**`[6]` — controle positivo pareado de `[5]`: `--path` existente, dentro de um repositório com refs, e `tests/` sem ordinal algum.** Asserções: `rc 0`; primeira linha `w1`; a saída contém o token `sem ordinal em uso` fixado na decisão 6; a saída **não** contém `sem remoto` nem `só da árvore local`, porque nesta fixture o remoto está acessível e o universo é que está vazio; e os contadores de `[7]` declaram quantos refs foram examinados (maior que zero) e quantos contribuíram (zero). Sem esse par, `[5]` não distingue "recusa por caminho ausente" de "recusa por qualquer motivo", e sem a asserção de token o cenário nasceria verde sobre a mensagem que já existe.

*Como falha hoje, com a saída real colada — a revisão 1 derrubou com razão o "devolve `w1` sem declarar nada", que era falso.* Medido nesta revisão, num clone cujo `tests/` contém só um `README.md`: `rc 0`, stdout `w1` seguido de `  derivado do tronco remoto 'origin/develop' (máximo remoto w0) e da árvore local (máximo local w0)`, stderr vazio. Ele **declara**, mas declara a coisa errada: afirma ter derivado do tronco e reporta `máximo remoto w0`, número que é indistinguível entre "o ref não tem `tests/`", "tem `tests/` e nenhum arquivo" e "tem `tests/` cheio de arquivos que não são ordinais". Na variante de fora de repositório, medida no mesmo par de comandos, a saída é `w1` mais a linha de degradação — e **byte a byte idêntica** à de `[5]`, o que é o vermelho mais duro dos dois cenários: hoje o par `[5]`/`[6]` não é um par, é o mesmo desfecho escrito duas vezes. O vermelho de `[6]` é, portanto, a ausência do token `sem ordinal em uso` e a ausência dos contadores — nenhum dos dois existe em nenhuma das duas variantes.

**`[7]` — a proveniência publica contadores.** Asserção: a saída informa quantos refs foram examinados, quantos contribuíram e quantas worktrees foram varridas, e os números batem com a fixture. *Como falha hoje:* a linha de hoje nomeia **um** ref e nenhum contador.

**`[8]` — degradação declarada preservada.** Repositório sem remoto: número devolvido com `rc 0` e a frase de degradação. É o controle de retrocompatibilidade de `w193[5]`, que este gate não pode quebrar. *Hoje passa* — é o único cenário do gate que nasce verde, e ele existe para isso.

**`[9]` — orçamento de processos, com as duas cláusulas decidíveis e a do meio removida.** Fixture com 31 branches remotas mais `develop` compartilhando a **mesma** árvore `tests/`, e um shim de `git` no início do `PATH` que registra cada invocação antes de delegar ao git real. A revisão 1 apontou, com razão, que a cláusula "e é da ordem do número de árvores distintas" não é predicado decidível — o implementador não sabe quando ela falhou. Ela sai, e o cenário fica com duas cláusulas, ambas decidíveis, mais um teto com fator constante **derivado na execução** em vez de escrito à mão:

1. **Teto:** o número de invocações é **estritamente menor** que o número de refs do universo.
2. **Teto com constante derivada:** rode primeiro a fixture de **uma** árvore distinta e leia do shim o número `C` de invocações; na fixture de `A` árvores distintas, exija `invocações ≤ C + A`. O `C` é o prólogo fixo (resolução de raiz, enumeração de refs, listagem de worktrees) e nunca entra no arquivo como literal — é medido na mesma execução que o usa.
3. **Contrapositiva:** uma segunda fixture com `A` árvores `tests/` distintas gasta **ao menos** `A` invocações. Sem ela, uma implementação que não olhasse ref nenhum passaria com folga — é a prova de canal de §8.

*Como falha hoje, remedido nesta revisão com o shim que eu mesmo construí:* sobre um clone com **33** refs remotos (`origin/HEAD`, `origin/develop` e 31 branches), o shim registra **3** invocações, e são exatamente

```
-C <dir do script> rev-parse --show-toplevel
rev-parse --verify --quiet origin/develop
ls-tree --name-only origin/develop tests/
```

O shim é cinco linhas e está colado porque a revisão 1 não o reconstruiu:

```
cat > "$W/shim/git" <<SHIM
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$W/git-calls.log"
exec "$REALGIT" "\$@"
SHIM
chmod +x "$W/shim/git"; : > "$W/git-calls.log"
PATH="$W/shim:$PATH" bash "$GO" next --path "$W/cl/tests"
wc -l < "$W/git-calls.log"      # → 3
```

Hoje o cenário falha pela **contrapositiva**, não pelo teto: o alocador não olha as outras 32 refs. E a primeira linha do log é ela própria um achado que reforça §3 — o único `-C` do caminho de hoje resolve a raiz **do diretório do script**, nunca o repositório que contém `--path`.

**`[10]` — PBT: cota superior.** Para todo universo gerado (listas de ordinais distribuídas aleatoriamente entre U1, U2, U3 e U4), `next` devolve um valor **estritamente maior** que o máximo global. Seed fixa, shrinking exigido, e asserção sobre o gerador: uma execução em que todos os universos exceto U1 saíram vazios não conta como cobertura, e o teste afirma que ao menos um universo não-U1 foi exercido. *Como falha hoje:* o contraexemplo já é conhecido e minimizado — U1 = `{205}`, U3 = `{206}` devolve `206`.

**`[11]` — PBT: monotonicidade.** Acrescentar um ordinal a qualquer universo nunca diminui o valor devolvido. *Como falha hoje:* acrescentar `w206` a U3 não muda a resposta, medido.

**`[12]` — `ledger-ops.sh add` enxerga o máximo de outros refs.** Fixture com `ledger.json` commitado em `develop` até `LDG-0010` e numa branch até `LDG-0020`, árvore em `develop`. Asserção: o id criado é `LDG-0021` ou maior. *Como falha hoje:* `ledger-ops.sh:163` reduz sobre `data.entries` do arquivo do disco; o id sai `LDG-0011`.

**`[13]` — ref sem `ledger.json` não contamina e é contabilizado à parte.** Fixture com um ref onde o arquivo não existe. Asserções: o id criado ignora esse ref, e a saída declara quantos refs foram examinados, quantos contribuíram e quantos não tinham ledger. *Como falha hoje:* não há leitor de ref algum.

**`[14]` — detector de id duplicado.** Fixture com dois `LDG-0007`. Asserções: reprova, nomeia o id, nomeia as duas entradas. Pareado com o controle: um ledger íntegro passa e imprime quantos ids examinou. *Como falha hoje:* `grep -rn` por qualquer detector de id repetido devolve zero, medido em §4.3.

**`[15]` — o detector roda sobre o `ledger.json` REAL do repositório.** É o canal de entrega exigido por `testing/gate-delivery-channel.md`: um detector provado só em fixture não afirma nada sobre a árvore que ele existe para proteger. A asserção do universo é **piso derivado na execução**, nunca igualdade — o ledger cresce em toda rodada, inclusive nesta. *Como falha hoje:* não existe.

**`[16]` — contador de controle do próprio gate, com contrapositiva.** `CENARIOS_NOMINAL` escrito no arquivo, comparado por igualdade, mais a chamada a `forge_universe_check` com zero para provar que a guarda reprova. *Como falha hoje:* o arquivo não existe.

**`[17]`, `[18]`, `[19]` — as três provas de mutação de §8.**

**`CENARIOS_NOMINAL = 19`, e agora o número fecha com a contagem.** Os rótulos são `[1]` a `[19]`, contíguos, sem rótulo adicional — o rótulo 3b da revisão 1 foi absorvido por `[3]` e a ressalva "contando 3b" saiu junto, porque ela é que tornava o `19` impossível sobre vinte rótulos. O comando que recontou, e que o próximo revisor roda sem adivinhar qual é o recorte:

```
awk '/^### 7\.1 /{f=1} /^### 7\.2 /{f=0} f' docs/plans/spikes/backlog-onda-e-ordinal-e-escrita.md \
  | grep -o '`\[[0-9b]*\]`' | sort -u | wc -l        # → 19
```

Este é o **único** número de igualdade da onda, e é legítimo pela exceção que a invariante 14 concede: denominador de cenários do próprio gate, fixo por construção, cuja divergência é justamente o achado. Todo outro denominador desta onda é piso sobre universo derivado na execução.

**Nenhum cenário é ambiental**, e a formulação da revisão 1 citava um token inexistente. Medido nesta revisão: `grep -rn 'SCEN_AMB\|ambiental' template/.forge/rules/ tests/` devolve **zero** linhas, e `git grep -ln 'ambiental'` devolve **um** arquivo, que é a especificação da onda D — isto é, `SCEN_AMB` é vocabulário de outra onda ainda não mergeada, não convenção deste repositório. A convenção instalada é outra e foi medida: `grep -rhoE '^[A-Z_]*(NOMINAL|CENARIO[S]?|SCEN)[A-Z_]*=' tests/*.sh | sort | uniq -c` devolve `SCEN=` em **12** gates e `SCENARIOS_RUN=` em **5**, mais a chamada a `forge_universe_check`. O gate novo declara o contador por essa convenção. O que a onda afirma sobre ambiente é a **propriedade**, não um token: nenhum cenário remove binário do `PATH` nem depende de rede — os refs são construídos localmente e o único `PATH` manipulado é o do shim de `[9]`, que **acrescenta** um diretório em vez de remover um.

### 7.2 Em `w194-ledger-write-discipline-gate.sh` (#103 e LDG-0140)

**`w194[7]` é editado, e o motivo é uma enumeração que se diz exaustiva.** A linha 162 declara `SUBCOMMANDS=(update resolve promote harvest list)` sob o texto *"os outros cinco subcomandos"*, enquanto `ledger-ops.sh` tem **oito**. `render` e `status` nunca foram exercitados, e é por isso que os dois seguem engolindo argumento (§5.2). O contador `[12b]` não pega: `forge_universe_check` reprova em zero, não em incompleto. **Decisão 20:** a lista de `[7]` passa a ser **derivada na execução** dos rótulos do `case` principal do script, e o gate compara o tamanho da lista derivada com um **piso** escrito no arquivo. Derivar é possível e foi medido — `awk '/^case "\$cmd" in$/{f++} f==2 && /^[a-z][a-z-]*\)$/{print}'` devolve os oito rótulos —, e a armadilha está medida junto: `ledger-ops.sh` tem **dois** `case "$cmd" in` (linhas 123 e 128), e um derivador que casasse o primeiro pegaria o bloco de aviso de raiz, não os subcomandos. O primitivo fica com quem implementa; a obrigação é a contrapositiva: acrescentar um subcomando ao script sem cobri-lo faz o gate reprovar.

**`w194[14]` (novo) — `render` e `status` recusam argumento desconhecido.** *Como falha hoje:* medido em §5.2 — `OK <path>` e `LEDGER: vazio`, ambos `rc 0`.

**`w194[15]` (novo) — `resolve` repetido sobre entrada terminal recusa.** Asserções: `rc` diferente de zero; a saída nomeia o estado atual e o `resolved_at` existente; o `ledger.json` fica **byte a byte idêntico** (por `cmp` contra um snapshot). Pareado com o controle: `resolve` sobre entrada `open` e sobre entrada `promoted` continua gravando com `rc 0`. *Como falha hoje:* medido em §5.2 — duas execuções `OK`, `detail` com dois `Resolvido:` e `resolved_at` recarimbado.

**`w194[16]` (novo) — harvest preenche `detail` e `priority`.** Sobre a fixture de §6.1: as três entradas criadas têm `detail` não vazio contendo o nome do arquivo de origem, e `priority` no conjunto `{P1,P2,P3}` conforme a decisão 17. Asserção adicional sobre o aviso: a saída de erro nomeia os ids cuja prioridade foi derivada e não curada. *Como falha hoje:* medido em §6.1 — `detail:""` e `priority:null` nas três, sem aviso.

**`w194[17]` (novo) — PBT sobre o harvest.** Propriedade: *para todo par (`analysis.md`, `verification.md`) gerado, toda entrada que o `harvest` cria tem `detail` não vazio e `priority` não nula*. O gerador produz tabelas pipe com severidades sorteadas do enum e bullets sob os dois tipos de heading, com e sem marcador. Seed fixa e shrinking. Asserção sobre o gerador, exigida pelo item 5 da rule: uma rodada em que nenhum documento gerado produziu entrada alguma não conta, e o teste afirma que o número de entradas criadas na rodada é maior que zero.

### 7.3 Em `w201-flag-como-valor-gate.sh` (#103)

**`w201[12]` (novo) — `deferral-ops.sh test` e `status` recusam argumento desconhecido.** Asserção crítica para `test`: o `deferrals.json` fica **byte a byte idêntico** depois da recusa. *Como falha hoje:* medido em §5.2 — `OK test — DEFER-01 marcado como tested`, `rc 0`, com o `--lixo` descartado e o estado do registro alterado.

**Observação registrada, fora de escopo:** o cabeçalho de `tests/w201-flag-como-valor-gate.sh:2` diz `Gate W200`, resíduo do rename que resolveu a colisão de LDG-0167 à mão. Nenhum gate confere a paridade entre o ordinal do nome do arquivo e o do cabeçalho. Isso é achado, não trabalho desta onda: a correção do texto é trivial e entra no PR, mas o **detector** de divergência não entra, porque ele pertence à onda F, que já tem a varredura de texto normativo (`w197`) como bancada.

---

## 8. Prova de mutação — três provas, todas com contrafactual JÁ MEDIDO

O que dá força a esta seção é que a implementação ainda não existe, mas o comportamento pós-mutação **é o comportamento de hoje**, e ele está medido nas seções anteriores. Cada linha da matriz abaixo tem o seu contrafactual observado nesta rodada, e não uma previsão.

| # | Alvo | Mutação | O que o gate DEVE acusar | Contrafactual medido |
|---|---|---|---|---|
| M1 | `template/.forge/scripts/gate-ordinal.sh` | restaurar a lista literal de três refs e o `break` do laço | `[1]`, `[2]`, `[3]`, `[7]` e `[10]` reprovam | §2.1: `w206` sobre uma branch que já tem `w206` |
| M2 | `template/.forge/scripts/gate-ordinal.sh` | remover o `-C` das invocações de git e a resolução física de `rel` | `[4]` reprova, com as três invocações divergindo | §3.1: `w12`, `w301`, `w12` |
| M3 | `template/.forge/scripts/ledger-ops.sh` | restaurar `max` calculado só sobre `data.entries` do arquivo do disco | `[12]` e `[13]` reprovam | §4.1: três máximos distintos para um caminho único |

Protocolo, os seis passos, com o cuidado de LDG-0164 e de `feedback-mutacao-fantasma-restore`:

1. Cópia íntegra do alvo para `$TMPDIR` e `sha_antes` gravado. O primitivo de digest foi executado nesta rodada: `printf 'abc' | shasum -a 256 | awk '{print $1}'` devolve `ba7816bf…15ad`, 64 hex numa linha, disponível no macOS sem instalar nada.
2. A mutação é aplicada por **substituição integral** do arquivo a partir de uma cópia preparada em `$TMPDIR`, nunca por edição in-place com interpolação. **Proibido explicitamente:** `perl -0pi -e 's/x/y$var/'` com `$` sem escape do lado direito — em perl aquilo é variável do perl, vazia, a mutação vira no-op e o `cmp` de controle confirma que o arquivo mudou enquanto o comportamento não mudou. É LDG-0164, e o passo 3 existe para pegá-lo.
3. `sha_mutado`, e a asserção de controle da própria mutação: `[ "$sha_mutado" != "$sha_antes" ]`.
4. Rodar os cenários nomeados na matriz e exigir **FAIL pela mensagem que a asserção declara**. Um FAIL por outra mensagem não conta.
5. Restauração por `cp` da cópia íntegra, `sha_depois`, e asserção `[ "$sha_depois" = "$sha_antes" ]`.
6. **Recontrole:** rodar os mesmos cenários e exigir **PASS**. Sem o passo 6 a prova não vale.

**Os três alvos são arquivos rastreados e distribuídos no tarball.** A mutação acontece sobre uma **cópia da árvore em `$TMPDIR`**, nunca sobre a árvore de trabalho. Isto não é preciosismo: LDG-0175 registra um gate desta suíte que usou `template/.forge/scripts/tests/run-all.sh` — arquivo rastreado — como fixture, não restaurou, e foi encontrado com o arquivo de 70 linhas reduzido a um stub de 3. `w204[4]` muta o `gate-ordinal.sh` **da árvore real** e restaura por `git checkout --` sob `trap`; esta onda não replica esse padrão e não o corrige, porque corrigi-lo é da onda A.

**Prova de canal para o canal**, exigida por `gate-delivery-channel.md`: além de "quebro o alvo e o gate acusa", vale "quebro o canal e a prova acusa". O canal destes gates é a suíte (`tests/run-all.sh`), e `[9]` já exerce um canal alternativo — o shim de `PATH` — cuja retirada faria a asserção de orçamento passar por vacuidade. A contrapositiva de `[9]` é essa prova de canal.

---

## 9. Onde entram PBT, contrato, integração e E2E

**PBT — obrigatório, e por nome.** A invariante 5 do plano-mestre lista *"alocador de ordinal"* entre as unidades que recebem teste de propriedade, e LDG-0021 registra a lacuna. As três propriedades são `[10]`, `[11]` e `w194[17]`, todas com `lib/pbt.mjs`, seed fixa, shrinking e asserção sobre o gerador. Famílias da rule: **monotonicidade** (`[11]`), **invariante de conservação** na forma de cota superior (`[10]`) e **preservação de conteúdo** (`w194[17]`, "toda entrada criada carrega detalhe e prioridade").

**Onde PBT NÃO se aplica, com a medição.** O mapeamento de severidade para prioridade da decisão 17 tem domínio de **5** valores (o enum `severity` do schema, `null` incluído) e contradomínio de 3; enumerar é exaustivo e gerar seria decorativo, e a rule diz em letra *"Se a unidade não tem propriedade … não force"*. A disciplina de recusa de argumento de §5 é a mesma coisa: o predicado é pertencimento a um conjunto finito declarado, `w201` já o cobre por enumeração, e o espaço de entrada relevante são os 12 subcomandos, que `w194[7]` passa a derivar.

**Teste de contrato — três, todos com adotante instalado.**
1. **A assinatura de `gate-ordinal.sh`.** O script viaja no tarball; `next`, `check`, `--path` e `--remote` são superfície pública. A semântica de `--remote` sob o universo novo está fechada na **decisão 21** e não mais na prosa: universo `{U1, ref}`, com U2, U3 e U4 suprimidos e a supressão **declarada** na linha de proveniência. O teste de contrato usa a fixture da decisão 21 — árvore local em `develop` com `w010`/`w011`, `refs/heads/feat/local` com `w050`, `origin/develop` com `w010`/`w011` — e crava os dois ordinais esperados: **`w12` com `--remote origin/develop`** e **`w51` sem a flag**. Ele reprova nos dois sentidos: quando `--remote` deixa de restringir (as duas respostas voltam a coincidir, que é o estado de hoje, medido) e quando a restrição vaza para o caminho sem flag (a resposta sem flag deixa de enxergar U2). Sem esta cláusula, a decisão 1 tornaria `--remote` decorativo e nenhum gate notaria.
2. **`ledger.schema.json`.** A descrição de `id` muda (decisão 8) e `detail`/`priority` continuam opcionais e anuláveis (decisão 19). O teste afirma que uma entrada com `priority: null` **continua válida** — é o que mantém as 8 históricas legais — e casa em `tests/w199-schema-reader-parity-gate.sh` ou em `w202`, que já é o gate de conformidade do ledger.
3. **A saída de `next` como contrato de `w193`.** Os tokens `remoto`/`origin` no caso derivado e `só da árvore local` no degradado são afirmados por `w193[4]` e `[5]` (§2.3, decisão 6). Eles passam a ser contrato escrito, não coincidência: quem reescrever a mensagem sem preservá-los quebra dois gates rastreados.

**Teste de integração — é o eixo, não complemento.** Nenhum dos cinco defeitos é de função pura: `next` erra porque **consulta o repositório errado**, `add` erra porque **lê um arquivo só**, `test` erra porque **ninguém examina o argumento**. Uma função testada isoladamente nasce verde. Por isso toda asserção de §7.1 monta repositórios git de verdade, com refs, clones, branches e worktrees de verdade, e invoca o script como um operador o invocaria.

**E2E.** O fluxo de ponta a ponta que a onda toca é `/forge:close`/`/forge:archive` → `ledger-ops.sh harvest` → `ledger.json` → `LEDGER.md`, e ele já tem canal: `w98` e `w32` exercitam `spec-close.sh` e `archive-spec.sh` reais. A onda **não** cria E2E novo; ela verifica que os dois seguem verdes com a decisão 12, e §5.3 traz a medição que explica por que seguem (a entrada está em `promoted`, não em estado terminal, quando o `resolve` chega).

---

## 10. Retrocompatibilidade — o que já está instalado e o que quebra

**O que está publicado.** `gate-ordinal.sh`, `ledger-ops.sh` e `deferral-ops.sh` viajam no tarball desde antes da `0.14.0`, publicada no npm. Os três estão instalados nos consumidores.

**A medição que dimensiona o risco do lado do ordinal, e que muda o tamanho da conversa.** Censo **remedido nesta revisão** em `~/Documents/projects` — a revisão 1 só reproduziu a metade local, e o mandato é claro: número sem comando não fica. O comando é o mesmo da decisão 4, que produz os dois censos numa passada:

```
cd ~/Documents/projects && for d in */; do [ -d "$d/.git" ] || continue
  printf '%-40s tests/w*=%-5s refs/remotes=%s\n' "${d%/}" \
    "$(git -C "$d" ls-files 'tests/w*' | wc -l | tr -d ' ')" \
    "$(git -C "$d" for-each-ref --format='%(refname)' refs/remotes/ | wc -l | tr -d ' ')"
done
```

Resultado de 2026-09-07: **20** diretórios com `.git`, e apenas o `forge-harness` usa a convenção `tests/wNNN` — **110** arquivos rastreados aqui, **zero** nos outros dezenove (`agent-smith`, `axis-fare-validator`, `axis-go-cloud`, `Axis.AcqSimulator`, `Axis.PadSimulator`, `Axis.ValidadorAndroid.Client`, `azim-crm`, `collatra`, `cpf-cnpj-validator`, `docuseal`, `forge-test`, `forge`, `lionclaw`, `payments`, `prospera`, `travessias-archive-2026-05-13`, `travessias-old`, `travessias`, `vellus-enterprise-ai-platform`). O comando é somente leitura nos consumidores, e é por isso que ele pôde rodar. Nenhum adotante hoje nomeia gate por ordinal, então a mudança de universo de `next` não altera o comportamento observável de ninguém no campo. Isso não autoriza descuido — autoriza dizer que o custo de contrato do ordinal é **potencial**, não realizado, e que a peça que precisa de cuidado real é a de custo de CPU, que morde independentemente de quem usa (§2.3, decisão 4).

**O que quebra, nomeado antes de acontecer:**

| Mudança | Quem sente | O que fazer |
|---|---|---|
| `next --path <inexistente>` passa de `w1`/`rc 0` para recusa `rc 2` | script de terceiro que dependa do `w1` | é o objetivo: `w1` sobre caminho inexistente é lixo, e o CHANGELOG diz isso com essas palavras |
| `ledger-ops.sh resolve` sobre entrada terminal passa de `OK`/`rc 0` para recusa `rc 1` | os dois chamadores de produção, tratados pela decisão 13 | mensagem passa a dizer "não gravou", não "falhou" |
| `deferral-ops.sh test`/`status` e `ledger-ops.sh render`/`status` passam a recusar argumento desconhecido | quem passava argumento a mais e não percebia | é exatamente o que a issue pede |
| ids de ledger passam a ter buracos | leitor que assuma contiguidade | nenhum existe, medido em §4.3; a descrição do schema é atualizada |
| entradas novas de harvest passam a ter `priority` derivada | quem filtra por `priority: null` para achar "não curados" | o aviso de stderr da decisão 18 é o novo canal para isso, e o CHANGELOG o nomeia |

**A quebra que a onda causa na PRÓPRIA suíte, achada na varredura da armadilha A desta revisão e ausente da revisão 1.** O `README.md:12` carrega o badge `gates-131%20passing`, e `tests/w200-readme-inventory-gate.sh` `[6]` compara esse número **por igualdade** contra a árvore:

```
grep -oE 'gates-[0-9]+' README.md | head -1 | cut -d- -f2     # → 131
ls tests/*-gate.sh | wc -l                                    # → 131
```

A onda escreve **um** gate novo, o do alocador. No instante em que o arquivo entra em `tests/`, a árvore vai a 132, o badge continua em 131 e `w200[6]` reprova com *"o badge do README diz 131 gate(s) e a árvore tem 132"*. Não é hipótese: é o mesmo gate, com a mesma asserção de igualdade, que já existe verde hoje. **O bump do badge para 132 entra no mesmo PR e entra na definição de pronto.** É exatamente a armadilha que o mandato desta rodada nomeia — *contadores do README e badges, que duas ondas deste lote já esqueceram* — e ela não estava tratada aqui.

O resto do inventário do README **não** se mexe, e isso também foi medido em vez de suposto: `w200[1]` confere as contagens do bloco `## 📁 Estrutura`, que contam subdiretórios de `template/.forge/` (`agents/ (47)`, `commands/ (56)`, `contracts/ (5)`, `skills/ (20)`, `rules/ (50)`, `schemas/ (27)`, `scripts/ (136)`), e a linha `tests/` daquele bloco **não** tem contagem. A onda não acrescenta arquivo nenhum sob `template/.forge/` — ela edita `gate-ordinal.sh`, `ledger-ops.sh`, `deferral-ops.sh`, `archive-spec.sh`, `spec-close.sh`, `ledger.schema.json`, `quality-gates.md` e `commands/harness/ledger.md`, todos já existentes —, então `scripts/ (136)` e os outros seis seguem corretos. E nenhum outro gate crava contagem de gates: `grep -rn 'tests/\*-gate.sh' tests/*.sh` devolve quatro linhas, e só a de `w200:258` é asserção; as outras são `run-all.sh:48` (o próprio laço), `w193:8` (comentário) e `w80:40` (laço).

**O que NÃO quebra, medido:**

- `gate-ordinal.sh check`: intocado. `w193[3]` roda sobre o `tests/` real e continua lendo `OK gate-ordinal — <n> …` no mesmo formato.
- `w193[4]` e `[5]`: as fixtures continuam produzindo `w201` e `w200`, e a razão é a estrutura de cada uma, não coincidência. Em `[4]` o clone tem `tests/` local em `w199` (o `w200` é removido na linha 97 e o commit sem ele é a linha 98), a branch local em `w199` e o remoto em `w200`: alargar o universo acrescenta refs cujo máximo continua sendo `w200`, e a resposta segue `w201`. Em `[5]` não há remoto algum, e a única camada nova que passa a contribuir é `refs/heads/develop`, que carrega os mesmos `w198`/`w199` da árvore — máximo inalterado, resposta `w200`.
- **A mensagem de degradação de `[5]` precisa de cuidado redacional, e ele é asserção, não observação.** Com U2 no universo, dizer `derivado SÓ DA ÁRVORE LOCAL` passa a ser impreciso: refs locais também contribuíram. A saída degradada tem de continuar casando `só da árvore local|apenas da árvore local|sem remoto` — é o que `w193[5]:114-115` afirma — **e** ser verdadeira. A forma que satisfaz as duas é dizer que nenhum ref **remoto** estava acessível, nomeando o que de fato contribuiu; `sem remoto` é o token que sobrevive, e é o que a decisão 6 fixa como contrato.
- `w204[1]`-`[4]`: `[1]` é uma propriedade de igualdade entre dois modos de invocação, `[2]` é um piso sobre o máximo local medido, `[3]` é uma fixture sem remoto que devolve `w12`. Os três seguem verdes com o universo alargado, porque nenhum deles crava o valor devolvido no repositório real.
- `w98[3]` e `w32[1]`: §5.3, com a medição da entrada em `promoted`.
- `w51[…]`: chama `deferral-ops.sh test` e `status` **sem** argumento extra, medido nas linhas 112-113.
- `w157`, `w202`, `w203`, `w207`: as fixtures criam repositórios com uma branch e sem remoto, então a união de §4.3 devolve o mesmo máximo do arquivo do disco.
- Entradas com `priority: null` já existentes: continuam válidas pelo schema, decisão 19.

**A varredura da invariante 15, com o resultado.** Para cada string que a onda altera ou cuja alteração era candidata: `grep -rn 'ledger resolve de\|entregue ao baseline\|entregue externamente' tests/*.sh` → zero; `grep -rn 'OK resolve' tests/*.sh` → **uma** linha, `w51:111`, e é sobre `deferral-ops.sh`, cuja mensagem não muda; `grep -rn 'OK harvest' tests/*.sh` → zero, executado nesta rodada, e de todo modo a linha de `OK` do `harvest` não muda: o aviso da decisão 18 vai para stderr, ao lado dela; as quatro linhas de `w193`/`w204` estão na tabela de §2.3, decisão 6. **Nenhum gate rastreado precisa ser editado por causa de mudança de string nesta onda** — os únicos gates editados são os que ganham cenário novo (`w194`, `w201`) e o `w194[7]`, que muda por decisão de desenho e não por texto.

**Propagação, e ela deixa de ser condicional nesta revisão.** `template/.forge/**` é a fonte, e `template/.forge/commands/harness/ledger.md` tem gêmeo **byte a byte idêntico** em `plugin/forge/commands/ledger.md` (`diff template/.forge/commands/harness/ledger.md plugin/forge/commands/ledger.md` → `rc 0`, medido). A revisão 1 me deixou escrever "se o texto do comando mudar", e a varredura da armadilha B desta revisão mostra que ele **muda por obrigação**, em dois pontos medidos:

```
sed -n '42,43p' template/.forge/commands/harness/ledger.md
#   "Todos os seis subcomandos (`add`, `update`, `resolve`, `promote`, `harvest`, `list`) recusam
#    argumento que não conhecem, nomeando o subcomando."
```

Primeiro: a linha 42 declara **seis** subcomandos com a mesmíssima enumeração incompleta de `w194[7]`, e ela passa a ser falsa no instante em que `render` e `status` também recusam (decisão 11) — são oito. Segundo: o bloco de captura automática descreve o `harvest` sem o `detail` de proveniência, sem a prioridade derivada e sem o aviso, que são as decisões 16, 17 e 18. Os dois pontos são texto normativo do comando, não prosa decorativa. **Logo o plugin É regenerado com `npm run build:plugin`** — nunca `build-plugin.sh`, que instala em `$HOME` —, e `tests/plugin-sync-gate.sh` reprova com *"plugin/forge dessincronizado — rode: npm run build:plugin"* se alguém esquecer. Isso entra na definição de pronto. Registro ainda, como observação e não como trabalho: o `argument-hint` do frontmatter de `ledger.md` lista sete subcomandos e omite `harvest` — terceira enumeração incompleta do mesmo arquivo, corrigível no mesmo passo, e nomeada aqui para não virar achado de revisão. `template/.forge/rules/testing/quality-gates.md:112` é editado (decisão 6) e **não** tem gêmeo em `plugin/`. O `.forge/` da raiz deste repositório não é consumidor completo — está registrado no próprio `.forge/FORGE.md` e é alvo da Fase 1 do plano, que está em voo nesta mesma árvore —, então a onda não duplica nada na raiz; se a Fase 1 mergear antes, a maquinaria da raiz vem do `template/` por instalação, não por cópia manual.

---

## 11. Alocação de ordinal, ordem de implementação e definição de pronto

### 11.1 Alocação de ordinal — a onda NÃO aloca

Medido nesta rodada: o máximo é **w207** em `tests/` local, em `refs/heads/{develop,main,feat/fase1-dogfood-completo}` e em `origin/{develop,main}`; `origin/wip/upgrade-safety-ldg-0131` tem `w154` e `origin/wip/deepspec-run-manifest-ldg-0165` tem `w80`. Worktrees vivas: a principal e `/private/tmp/forge-baseline-wt` (detached), da Fase 1.

A onda precisa de **um** ordinal novo — o gate do alocador, especificado por inteiro em §7.1, com 19 cenários — e **não aloca nenhum**. Invariante 10 do plano: o ordinal é alocado pelo orquestrador, uma vez, no momento de escrever o arquivo, conferido contra `origin/*` **e** contra as branches em voo desta rodada. Há uma ironia útil aqui e ela é literal: esta é a onda que conserta o alocador, e ela é a que mais depende de não usar o alocador quebrado. As demais asserções vão para `w194` e `w201`, que já existem, e não consomem ordinal.

### 11.2 Ordem de implementação

1. **`gate-ordinal.sh`** — universo (U1..U4), semântica de `--remote` da decisão 21, `-C` com resolução física de caminho, recusa de `--path` inexistente, proveniência com contadores e com o token `sem ordinal em uso`. Vermelho `[1]`-`[9]`, verde, refactor. `-C` primeiro dentro deste passo: sem ele, `[1]`-`[3]` medem o repositório errado e podem passar por acidente.

   **Aviso operacional que a revisão 1 extraiu e que custa uma tarde se ficar implícito: `gate-ordinal.sh` precisa estar COMMITADO antes de qualquer execução de `tests/w204-ordinal-root-resolution-gate.sh`.** O `w204[4]` muta `template/.forge/scripts/gate-ordinal.sh` **na árvore real** e restaura com `git checkout -- "$GATEORD"`, que devolve o arquivo **inteiro** ao `HEAD` — e o faz tanto no caminho feliz (`w204:163`) quanto nos dois desvios de falha (`:149`, `:156`) e no `trap` de saída (`:60`). O comentário de `w204:56-57` registra a intenção de não desfazer trabalho não commitado, mas a chamada de `:163` é incondicional. Consequência literal: rodar a suíte com a correção da onda ainda não commitada **descarta a correção**, em silêncio, e o passo 1 acima é exatamente editar esse arquivo. Corrigir o `w204` é da onda A (§12); a mitigação desta onda é de processo e está escrita aqui: commite antes de rodar.
2. **PBT do alocador** — `[10]` e `[11]`, sobre a implementação do passo 1.
3. **`ledger-ops.sh add`** — união U1+U2+U3, contadores de três classes, e o comentário de `gate-ordinal.sh:9-12` corrigido junto (§1.2, decisão 10). Vermelho `[12]`, `[13]`.
4. **Detector de id duplicado** — `[14]`, `[15]`, com o canal sobre o ledger real e piso derivado.
5. **Gate novo** fechado, com `[16]` e as três provas de mutação `[17]`-`[19]`.
6. **#103, o resto** — as quatro portas de §5.2, o `resolve` terminal, os dois chamadores de produção. `w194[14]`, `w194[15]`, `w201[12]`, e `w194[7]` derivando a lista.
7. **LDG-0140** — `detail` de proveniência, mapeamento de prioridade, aviso. `w194[16]`, `w194[17]`.
8. **Contratos e documentação** — `ledger.schema.json`, `quality-gates.md:112`, `CHANGELOG.md`, e regeneração de plugin **se e somente se** algum arquivo de `template/.forge/commands/` for tocado.

### 11.3 Definição de pronto, cada linha provada por comando

- Os cinco defeitos reproduzidos em §2.1, §3.1, §4.1, §5.2 e §6.1 **não** reproduzem mais, pelos mesmos comandos, nas mesmas bancadas.
- Suíte inteira verde, executada em série pelo orquestrador, nunca concorrente — `feedback-suite-sem-concorrencia`.
- `bash -n` limpo em todo arquivo tocado; nada de `declare -A`, `${var,,}`, `mapfile` (bash 3.2, invariante 8).
- O gate novo publica `CENARIOS_NOMINAL = 19` comparado por **igualdade**, mais a contrapositiva de `forge_universe_check` com zero. O `19` é conferível contra a especificação pelo comando de recontagem colado no fim de §7.1, e é o único número de igualdade da onda.
- **O badge de gates do `README.md` é atualizado de `131` para `132` no mesmo PR**, porque `w200[6]` o compara por igualdade contra `ls tests/*-gate.sh | wc -l` e a onda escreve um gate novo. Um PR que acrescente o gate sem tocar o badge deixa `w200` vermelho — e essa é a forma que a armadilha A toma nesta onda.
- **`plugin/forge/commands/ledger.md` é regenerado por `npm run build:plugin`**, porque `template/.forge/commands/harness/ledger.md` muda por obrigação em dois pontos (a enumeração de seis subcomandos da linha 42 e o bloco de captura automática do `harvest`). `tests/plugin-sync-gate.sh` é quem morde se esquecerem.
- O teste de contrato de `--remote` (decisão 21, §9) roda sobre a fixture com `refs/heads/feat/local` à frente do ref passado e crava os dois ordinais: `w12` com a flag, `w51` sem ela.
- Os denominadores que contam a **árvore** — o universo de ids do `[15]`, o universo de subcomandos do `w194[7]` — estão escritos como **piso sobre universo derivado na execução**, nunca como igualdade. Um deles escrito como igualdade é, por si só, a prova de que a invariante 14 foi lida como sugestão, e esta onda acrescenta gate e subcomando à própria árvore que esses números contam.
- Nenhuma asserção contém `arquivo:linha`. As citações de linha desta especificação são endereços para quem implementa, não predicados de gate.
- As três provas de mutação percorrem os seis passos de §8, incluindo a asserção de que o sha mutado difere do original e o recontrole verde depois da restauração, e cada uma derruba os cenários **nomeados na matriz**, nunca outros.
- `[9]` reprova por teto **e** pela contrapositiva; um `[9]` que só verifique o teto passaria com um alocador que não olhasse ref nenhum.
- `w193[3]`, `[4]` e `[5]` e `w204[1]`-`[4]` rodam **sem edição** e ficam verdes. Um `w193` editado nesta onda é a prova de que a decisão 6 vazou para o contrato de mensagem.
- `w98[3]`, `w32[1]` e `w51` rodam sem edição.
- Uma entrada de ledger com `priority: null` continua válida contra o schema, e uma criada por `harvest` a partir desta onda tem `detail` não vazio e `priority` não nula — as duas asserções coexistem, e é a decisão 19 que as torna compatíveis.
- LDG-0173, LDG-0167, LDG-0158 e LDG-0140 movidos para `resolved` com a prova e o gate que morde se voltarem; #103 fechada por `gh issue close` com comentário que cita nominalmente o que continuava aberto (as quatro portas e o `resolve` terminal) e o gate que as cobre, **e** que corrige o corpo defasado da issue quanto a `deferral-ops.sh` linhas 52/78.
- `CHANGELOG.md` registra as cinco quebras nomeadas em §10, cada uma com a linha de correção para o consumidor.
- Nenhum texto de coautoria de IA em commit, PR ou issue. PR contra `develop`.

---

## 12. O que esta onda explicitamente NÃO faz

**Não transforma `next` em alocador.** §1.1 e as decisões 2 e 3, com as duas alternativas medidas e refutadas. A limitação continua escrita no cabeçalho do script.

**Não toca `gate-ordinal.sh check`.** Ele é a peça que funciona sem rede e é determinística por construção; alargar o universo dele faria o veredito depender do estado de fetch da máquina, isto é, o mesmo gate produziria respostas diferentes em duas máquinas — que é precisamente a classe de defeito que a onda D combate. A escolha do universo é trabalho de `next`, que escolhe; a detecção local é trabalho de `check`, que verifica.

**Não corrige o `w204[4]`, que muta arquivo rastreado da árvore real.** É a classe de LDG-0175 e ela é da onda A. Registrado aqui porque a onda E acrescenta provas de mutação sobre os mesmos arquivos e usa o padrão certo — cópia da árvore em `$TMPDIR` —, o que deixa os dois padrões visíveis lado a lado no mesmo repositório. **Declinar a correção não dispensa avisar da consequência**, e a revisão 1 estava certa em cobrar isso: o `git checkout -- "$GATEORD"` de `w204:163` restaura o arquivo inteiro ao `HEAD` e apaga a correção não commitada da própria onda. O aviso está em letra no passo 1 de §11.2, onde ele é acionável, e não só aqui.

**Não cria detector de paridade entre o ordinal do nome do arquivo e o do cabeçalho do gate**, ainda que `w201:2` diga `Gate W200`. O texto é corrigido; o detector pertence à onda F, que já tem `w197` como bancada de texto normativo.

**Não mexe em `promote`.** Decisão 14, com a medição.

**Não retrofita as 8 entradas históricas de harvest.** Decisão 19.

**Não varre os outros 33 sítios de `SCRIPT_DIR/../..`.** É LDG-0171, onda F. Esta onda toca `gate-ordinal.sh`, que já foi corrigido para `forge_worktree_root` pelo `w204`, e não generaliza.

**Não consolida `lib/arg-guards.sh` com a cópia de `liaison-ops.sh::_reject_unknown`.** O próprio cabeçalho de `arg-guards.sh:23-24` declara isso como trabalho próprio, e ele é LDG-0152, onda F.

---

## 13. Como as cinco armadilhas foram tratadas

Seção exigida pelo mandato desta onda, e escrita aqui para que a revisão possa conferir por leitura em vez de por suspeita.

**A — literal que envelhece.** Os números que contam a árvore aparecem nesta especificação **datados, nomeados como medição e com o comando ao lado**, nunca como asserção de gate. Os quatro, com o comando que os produz, remedidos nesta revisão: `ls tests/*-gate.sh | wc -l` → **131**; `node -e 'console.log(require("./.forge/ledger/ledger.json").entries.length)'` → **107**; `git ls-files 'tests/w*' | wc -l` → **110**; `git -C ~/Documents/projects/axis-go-cloud for-each-ref --format='%(refname)' refs/remotes/ | wc -l` → **469**. Nota de honestidade sobre o último: a revisão 1 leu **474** na primeira medição desta rodada e eu leio 469 agora, sem nada da onda ter tocado aquele repositório — a divergência não é erro de ninguém, é a definição de testemunha de data, e é a razão de nenhum desses quatro números virar critério.

**A varredura que faltava na revisão 1, e o achado que ela produziu.** A armadilha A não vive só nos números que a especificação escreve; ela vive também nos contadores que a **entrega** desloca. A onda escreve um gate, e o badge `gates-131%20passing` do `README.md:12` é comparado por **igualdade** contra `ls tests/*-gate.sh` por `w200[6]`. O bump para `132` entra no PR e na definição de pronto (§10 e §11.3). O resto do inventário do README foi conferido e não se mexe, porque a onda não acrescenta arquivo sob `template/.forge/`.

Os dois denominadores que um gate desta onda examina — ids do ledger real e subcomandos de `ledger-ops.sh` — são **piso sobre universo derivado na execução**, e a definição de pronto os nomeia um a um. O único número de igualdade é `CENARIOS_NOMINAL = 19`, denominador de cenários do próprio gate, a exceção que a invariante 14 declara legítima — e ele é o número que a revisão 1 derrubou por estar errado por um, agora recontado por comando no fim de §7.1. A onda acrescenta gate e subcomando à própria árvore, então um literal de contagem envelheceria **dentro** dela.

**B — string de produção que quebra gate existente, e o espelho do plugin.** §2.3, decisão 6 e §10 trazem a varredura de `tests/` para cada string alterada, com o resultado por gate e por linha, e a decisão 6 passa a fixar **três** tokens em vez de dois — o terceiro, `sem ordinal em uso`, nasceu nesta revisão porque a revisão 1 mostrou que a declaração de universo vazio estava sem forma definida. O desfecho medido continua sendo que **nenhum** gate rastreado precisa de edição por texto, e §11.3 transforma isso em asserção: um `w193` editado é a prova de que a decisão vazou.

A varredura desta revisão acrescentou duas frentes que a anterior não tinha. A primeira é o **risco simétrico** da decisão 13: conferir que ninguém afirma a string que sai não basta, é preciso conferir que ninguém compara a saída **por igualdade ou por contagem de linhas** — medido em §5.3, vinte e três invocações em nove gates, **zero** asserções de igualdade/`wc -l`/`diff`/`cmp` e dezesseis `grep -q`. A segunda é o **espelho em `plugin/forge`**: `template/.forge/commands/harness/ledger.md` e `plugin/forge/commands/ledger.md` são hoje byte a byte idênticos (`diff` → `rc 0`), o texto do comando muda por obrigação em dois pontos medidos, e portanto `npm run build:plugin` é **certeza**, não condicional — com `tests/plugin-sync-gate.sh` como quem morde. Isso está em §10 e na definição de pronto.

**C — mutação sem contrafactual medido.** As três linhas da matriz de §8 têm o contrafactual **já observado**, porque a implementação não existe e o comportamento pós-mutação é o de hoje: `w206` sobre um `w206` tomado, `w301` contra `w12`, três máximos para um caminho. A revisão 1 reproduziu os três por conta própria, o que é o teste mais duro que um contrafactual pode passar antes de a implementação existir, e o terceiro passa a vir com o comando colado em §1.2 — o laço de `git show <ref>:.forge/ledger/ledger.json` sobre os três refs mais o disco. A proibição de `perl -0pi -e` com `$` sem escape está escrita no passo 2, e o passo 3 é a asserção que a pega; o primitivo de digest daquele passo foi reexecutado nesta revisão e `printf 'abc' | shasum -a 256` continua devolvendo `ba7816bf…15ad`.

**D — enumeração que se diz exaustiva.** Cinco enumerações desta especificação foram construídas procurando ativamente o caso não coberto. Três produziram achado: os **oito** desfechos de `next` em §2.2, onde `--path` inexistente devolvendo `w1` e as formas de `worktree list` estavam fora; o ref **sem `ledger.json`** de §4.2, que sai `128` e que um parser ingênuo contaria como zero; e os **doze** subcomandos de §5.2, contra os **cinco** que `w194[7]` declara como "os outros cinco" — a enumeração incompleta que é, ela própria, a razão de duas das quatro portas seguirem abertas.

As outras duas foram conferidas e são **legítimas**, e ficam registradas aqui porque uma seção que se propõe a provar exaustividade não pode deixar o revisor descobrir por conta própria que elas existem. A primeira é `tests/w201-flag-como-valor-gate.sh:11` e `:108`, que declara *"os 6 subcomandos de ledger-ops"* contra os oito do `case`: os seis estão certos ali, porque só seis aceitam flag, e a decisão 11 confirma que `render` e `status` declaram conjunto de flags **vazio** — o `w201` mede pertencimento de flag e o universo dele é, por construção, o dos subcomandos que têm flags. A segunda é o `argument-hint` do frontmatter de `template/.forge/commands/harness/ledger.md`, que lista sete subcomandos e omite `harvest`: essa é incompleta de fato, mas é rótulo de UI e não predicado de nada, e ela sai corrigida de carona no passo em que o arquivo já é editado (§10).

Registro ainda a enumeração que a revisão 1 corrigiu **contra** mim, e que é o caso mais instrutivo dos cinco: o desfecho (8) de §2.2 listava `bare` como forma de worktree **irmã**, e ela não existe — `git worktree add --bare` responde `error: unknown option 'bare'`. Eu tinha observado o bloco `bare` no `worktree list --porcelain` e concluído a origem errada dele. A enumeração continua correta como enumeração de **formas de saída do primitivo**; era a prosa sobre a proveniência que estava errada, e está corrigida com a medição colada.

**E — prescrição não executada.** Todo primitivo citado nesta especificação foi executado e a saída está colada ao lado: `git ls-remote` mais `cat-file -e` mais `ls-tree` sobre clone por `file://` (rc 1 e rc 128); `git cat-file --batch-check` com caminho presente e ausente (`missing`, rc 0); `git -C` nos três estados (rc 128, rc 128, rc 0 com `/private`); `git worktree list --porcelain` nas formas `prunable`, `locked` e `bare`, mais a recusa de `git worktree add --bare`; o shim de `PATH` contando invocações de `git`, agora construído e colado (3 invocações sobre 33 refs); `shasum -a 256`; o `awk` que deriva os rótulos do `case`, com a armadilha dos dois `case "$cmd" in`; o `awk` que reconta os rótulos de cenário desta própria especificação; o `node -e` que agrupa o ledger por `source.origin`, com a armadilha do campo aninhado; o `diff` entre o comando e o gêmeo do plugin; e o par `grep` do badge do README contra `ls tests/*-gate.sh`.

Onde a especificação não podia executar — o teto de processos da implementação futura, o derivador de subcomandos definitivo, o preenchimento de `detail` —, ela declara a **propriedade** e o **contrafactual** e devolve a escolha do primitivo a quem executa, com a obrigação explícita de provar a discriminação por controle e recontrole. O caso do `[9]` é o exemplo desta revisão: a cláusula do meio ("é da ordem do número de árvores distintas") era prescrição sem predicado, e foi substituída por um teto com constante **derivada na execução**, que quem implementa mede na fixture de uma árvore antes de aplicar à de `A` árvores.

E onde o meu próprio experimento não sustentou a conclusão, o texto diz em letra qual dos dois vale — são três casos agora, e todos declarados: §2.3 decisão 1, sobre o clone local que compartilha objetos e o contraexemplo que só o `file://` produz; §2.3 decisão 4, sobre os tempos de 13,35 s e 1,17 s que não reproduzem e foram substituídos por CPU mais relógio nas duas passadas; e §2.2 desfecho 8, sobre a worktree bare que não é construtível.
---

## 14. Respostas ao veredito da revisão 1

Cada item abaixo diz o que o revisor apontou, o que eu medi por comando próprio antes de aceitar, e o que mudou no documento. Refutar com medição é legítimo neste plano; nesta rodada **não refutei nenhum dos três bloqueadores** — remedi os três e os três estavam certos —, e refutei parcialmente duas ressalvas, pelo motivo que cada linha registra.

### 14.1 Bloqueadores

**Bloqueador 1 — `CENARIOS_NOMINAL` errado por um, comparado por igualdade. ACEITO, fechado.** Recontei com comando meu antes de aceitar: `awk` recortando §7.1 e `grep -o` sobre os rótulos entre crases devolvia **20**, não 19, porque o rótulo 3b era adicional aos dezenove numerados. A correção seguiu a segunda das duas saídas que o revisor ofereceu, e ela é a melhor pelo desenho e não só pela aritmética: `prunable` e `locked` são **formas de entrada** do leitor de worktrees que `[3]` já exercita, não cenários independentes, então viraram asserções de `[3]` e o rótulo extra desapareceu. Os rótulos agora são `[1]` a `[19]`, contíguos, e o comando de recontagem está colado no fim de §7.1 devolvendo **19**. A ressalva "contando 3b" saiu do texto.

**Bloqueador 2 — semântica de `--remote` declarada fechada sem fechar. ACEITO, fechado com decisão numerada e fixture.** Medi antes de aceitar, e a medição confirmou o revisor e foi além dela: `--remote` substitui a **lista de refs** (`gate-ordinal.sh:120`) enquanto U1 continua entrando pelo `max="$local_max"` da linha 131, de modo que "use este ref e só ele" já é falso hoje. Construí a fixture em que as duas leituras divergem — árvore local em `develop` com `w010`/`w011`, `refs/heads/feat/local` com `w050`, `origin/develop` com `w010`/`w011` — e medi as três invocações: com a flag, `w12`; sem a flag, `w12`; com um ref inexistente, `w12` mais degradação. Nasceu a **decisão 21** em §2.3: universo `{U1, ref}`, U2/U3/U4 suprimidos, supressão **declarada** na linha de proveniência. §9 passa a cravar os dois ordinais esperados: `w12` com a flag, `w51` sem ela. O vermelho do teste de contrato ficou o mais barato possível de ler — hoje as duas invocações devolvem o mesmo número, que é a definição operacional de flag decorativa.

**Bloqueador 3 — o vermelho de `[6]` não existe e a asserção não tem forma. ACEITO, fechado, e a medição foi pior do que o revisor descreveu.** Reproduzi por conta própria: `--path` para diretório existente e vazio, cwd fora de repositório, devolve `w1` com `rc 0` e a linha de degradação no stderr — ele declara, e o meu "devolve `w1` sem declarar nada" era falso. Medi também a variante que faltava, com `--path` dentro de um repositório com refs e `tests/` sem ordinal: `w1` mais `derivado do tronco remoto 'origin/develop' (máximo remoto w0) e da árvore local (máximo local w0)`, stderr vazio. E medi o que ninguém tinha medido: `cmp` sobre stdout **e** stderr de `[5]` e `[6]` na variante fora de repositório não acusa diferença nenhuma — hoje os dois cenários são **byte a byte idênticos**, isto é, o par não é um par. A decisão 6 passa a fixar um terceiro token, `sem ordinal em uso`, exigido em letra como **distinto** de `sem remoto` e de `só da árvore local`, com a medição que escolheu a forma sem colidir com o vocabulário instalado (`universo-vazio` aparece em 13 linhas de `tests/` e `universo vazio` em 42, todas sobre a recusa `rc 1` do `forge_universe_check`, que é outra coisa). O parágrafo "como falha hoje" de `[6]` foi reescrito com as duas saídas reais coladas.

### 14.2 As sete medições que não reproduziram — seis remedidas, uma reclassificada, zero removidas

O critério foi o do mandato: ou remede agora e cola o comando, ou remove. Consegui remedir todas as que eram medição; a sétima nunca foi medição minha e passou a vir com o comando que exibe a fonte.

| # | O que o revisor não reproduziu | Desfecho | O que ficou no documento |
|---|---|---|---|
| 1 | §2.3 decisão 4 — censo de refs de outros repositórios e os tempos `13,35 s` / `1,17 s` | **remedido, com correção do número** | Censo remedido com o laço colado: 20 repositórios, `forge` 1324, `axis-go-cloud` **469** (era 474 na primeira medição — a própria prova de testemunha de data), `travessias-archive` 231, `Axis.PadSimulator` 150. Tempos remedidos com `time` e as duas passadas: **10,36 s de CPU / 49,1 s de relógio** para o laço de `ls-tree`, contra **0,11 s de CPU / 1,89 s de relógio** para o `cat-file --batch-check`, colapsando em **23** árvores distintas. Digo em letra que 13,35 s e 1,17 s **não reproduzem** e que o que carrega o argumento é a razão entre as duas formas, não o absoluto. |
| 2 | §7.1 `[9]` — as 3 invocações de `git` sob shim de `PATH` | **remedido** | Construí o shim, colei as cinco linhas dele no documento, e medi: **3** invocações sobre um clone com **33** refs remotos (era "32" antes; `origin/HEAD` conta). As três linhas do log estão coladas, e a primeira virou achado que reforça §3 — o único `-C` de hoje resolve a raiz do diretório do script, não o repositório de `--path`. |
| 3 | §10 — censo dos 20 repositórios por `git ls-files 'tests/w*'` | **remedido** | O mesmo laço da decisão 4 produz os dois censos numa passada, e ele é somente leitura nos consumidores, que é a razão de ter podido rodar. Resultado colado: 110 aqui, **zero** nos outros dezenove, e os dezenove estão nomeados. |
| 4 | §2.2 desfecho 4 — `w51` num repositório sem commit | **remedido, e reclassificado de constante para propriedade** | A bancada está colada e devolve `w51` com `rc 0` e a linha de degradação, com `git rev-parse --verify --quiet HEAD` saindo `rc 1`. O texto passa a dizer que `w51` é **propriedade da bancada** (máximo local mais um), não constante do desfecho, e que a asserção compara contra o máximo derivado na execução. |
| 5 | §13-A — "131 gates em `tests/`" | **remedido, com o denominador nomeado** | O revisor viu 132 e 110 e não achou de onde saía 131. O comando é `ls tests/*-gate.sh` canalizado para `wc -l` → **131**; os 132 são `tests/*.sh`, que inclui o `run-all.sh`, e os 110 são só os de prefixo `w`. Como o número agora tem comando, a varredura seguinte foi possível — e ela produziu o achado de §14.3. |
| 6 | §2.2 desfecho 8, metade `bare` | **corrigido a favor do revisor** | Medi: `git worktree add --bare` responde `error: unknown option 'bare'`, worktree bare não é construtível, e o bloco `bare` só aparece quando `worktree list --porcelain` roda dentro de um repositório bare. A regra de pular continua (o alocador pode ser invocado de um repositório bare, e medi que aquele `<path>` tem `config`/`description`/`HEAD` e nenhuma árvore), mas a proveniência que eu tinha escrito estava errada e está corrigida. |
| 7 | LDG-0167 — a colisão de `w200` daquela noite | **reclassificado, com comando para a fonte** | Nunca foi medição minha e o documento já dizia isso; o que faltava era o revisor poder ler a fonte sem confiar na minha paráfrase. §2.2 traz o `node -e` que imprime `status`, título e corpo de LDG-0167 a partir de `.forge/ledger/ledger.json`. |

Além dessas sete, remedi com comando colado três números que a revisão 1 reproduziu mas que estavam no documento sem o comando: os três máximos de ledger de §1.2, a tabela por origem de §6.1 (com a armadilha do campo `source.origin`, que escrita de memória devolve "107 manuais") e o censo dos subcomandos de §5.2 (com a armadilha dos dois `case "$cmd" in`).

### 14.3 O achado que a varredura das cinco armadilhas produziu, e que nenhuma revisão tinha tocado

**O badge do `README.md` quebra com esta onda.** `README.md:12` diz `gates-131%20passing`, e `tests/w200-readme-inventory-gate.sh` `[6]` compara esse número **por igualdade** contra `ls tests/*-gate.sh | wc -l`. A onda escreve um gate novo; a árvore vai a 132; o badge fica em 131; `w200[6]` reprova. O bump entra no PR e na definição de pronto (§10, §11.3, §13-A). É literalmente a armadilha que o mandato desta rodada nomeia — contadores do README e badges, que duas ondas deste lote já esqueceram — e ela estava viva aqui.

**O texto do comando `/forge:ledger` muda por obrigação, e o plugin precisa ser regenerado.** `template/.forge/commands/harness/ledger.md:42` declara "os seis subcomandos" com a mesma enumeração incompleta de `w194[7]`, e ela fica falsa quando `render` e `status` passam a recusar; o bloco de captura automática descreve o `harvest` sem `detail`, sem prioridade e sem aviso. O gêmeo `plugin/forge/commands/ledger.md` é hoje byte a byte idêntico (`diff` → `rc 0`), então `npm run build:plugin` deixa de ser condicional e entra na definição de pronto, com `plugin-sync-gate.sh` mordendo se esquecerem.

**O risco simétrico da decisão 13 foi medido e é zero nesta árvore.** Vinte e três invocações de `spec-close.sh`/`archive-spec.sh` em nove gates, **nenhuma** asserção por igualdade, `wc -l`, `diff` ou `cmp` sobre a saída, dezesseis `grep -q`. Vários desses gates já capturam com `2>&1`, de modo que o stderr libertado cai na mesma variável — e mesmo assim nada quebra, porque nenhuma asserção é de igualdade.

### 14.4 Ressalvas de redação — quatro aceitas, duas refutadas em parte

**Aceita — `[9]`, a cláusula do meio não era decidível.** Saiu. No lugar entraram duas cláusulas decidíveis (teto estrito contra o número de refs e contrapositiva de piso `A`) mais um teto com constante `C` **derivada na execução** na fixture de uma árvore, em vez de um fator escrito à mão.

**Aceita — `SCEN_AMB` não tem referente.** Medi: `grep -rn 'SCEN_AMB\|ambiental' template/.forge/rules/ tests/` devolve zero, e `git grep -ln 'ambiental'` devolve **um** arquivo, que é a especificação da onda D — vocabulário de outra onda ainda não mergeada. O parágrafo passa a nomear a convenção instalada, medida: `SCEN=` em 12 gates, `SCENARIOS_RUN=` em 5, mais `forge_universe_check`. O que a onda afirma sobre ambiente passa a ser propriedade, não token.

**Aceita — "em silêncio" no desfecho 5.** O revisor está certo e a palavra era justamente a que a onda usa como critério noutros pontos. Corrigido para **indistinguibilidade**, que é pior e é medível: `cmp` não separa `[5]` de `[6]`.

**Aceita — §11.2 precisava avisar sobre o `w204[4]`.** Conferi: `w204:163` roda `git checkout -- "$GATEORD"` no caminho feliz, `:149` e `:156` nos desvios de falha e `:60` no `trap`, e o comentário de `:56-57` declara a intenção oposta sem a implementar. O aviso entrou em letra no passo 1 de §11.2, que é onde ele é acionável, com eco em §12.

**Aceita em parte — §4.3 decisão 9.** Aceitei a forma: o texto passa a dizer "quinze linhas, nenhuma sobre id de ledger", com os dois comandos (`| wc -l` → 15, `| grep -c 'LDG-'` → 0). Não aceitei que a formulação anterior fosse falsa — ela não era —, apenas que a assimetria com as varreduras vizinhas confundia, e essa parte procede.

**Aceita em parte — §13-D e o `w201[3]`.** Aceitei registrar a segunda enumeração e a razão de ela ser legítima, e fui além do pedido: registrei **duas**, porque a varredura desta revisão encontrou uma terceira enumeração incompleta que ninguém tinha visto — o `argument-hint` do frontmatter de `ledger.md`, que lista sete subcomandos e omite `harvest`. Não a promovi a defeito, porque é rótulo de UI e não predicado; sai corrigida de carona no arquivo que a onda já edita.

