# Especificação — worktree nasce com branch, e o que a branch não salva

Data: 2026-09-08. Autor: especificador da onda. Repositório: `forge-harness`, branch de trabalho `feat/fase1-dogfood-completo`. Ordinal alocado: **w210**.

**Nota sobre o ordinal, e ela é evidência nova para LDG-0173.** `gate-ordinal.sh next --path tests` devolveu `w209` no início desta sessão, derivado do máximo remoto `w207` em `origin/develop` e do máximo local `w208`. Meia hora depois, `tests/w209-varredura-cega-gate.sh` existia na árvore como arquivo **não rastreado**, escrito por uma cadeia irmã em voo. O alocador lê `origin/develop` e o `git ls-tree` da árvore; ele não vê arquivo não rastreado, e portanto ele não vê o trabalho de outro agente na MESMA árvore antes do primeiro commit. Esta especificação passa a alocar **w210**, conferido contra `ls tests/` (que enxerga não rastreados) e contra todas as spikes de `docs/plans/spikes/`, e o orquestrador reconfere no instante de escrever o arquivo — porque a janela que me pegou continua aberta para ele.

Esta especificação lê de `docs/plans/2026-09-07-backlog-zero.md`, itens 1 a 19 da seção "Invariantes", e do pedido do dono registrado em 2026-09-08: *"sempre que se abrir uma worktree, já se cria uma branch, mesmo que depois ela seja renomeada, para garantir rastreabilidade do trabalho e garantir que o trabalho não se perca"*.

## Sumário executivo

O pedido do dono é implementável e a medição mostra que ele é mais barato do que parecia, porque a peça que faltava não é maquinaria nova: é um gancho do git que o harness ainda não usa. Medi que `post-checkout` **dispara dentro da worktree recém-criada em `git worktree add`**, com `GIT_DIR` diferente de `GIT_COMMON_DIR`, com `$1` igual a quarenta zeros e com `git symbolic-ref -q HEAD` vazio quando o destino é destacado — e que, dali, um `git switch -c` conserta a worktree para uma branch antes de qualquer trabalho existir nela. Como `core.hooksPath` mora no `.git/config`, que é **comum a todos os worktrees**, e como `bin/forge.mjs` já o grava em caminho absoluto apontando para o tronco, esse gancho alcança inclusive worktree criada a partir de branch antiga — a única peça desta onda que atravessa a fronteira da issue #123.

O censo do orquestrador reproduz por repositório e diverge em dois totais de prosa, que são erro de soma e não de medição: as linhas da tabela somam **150** entradas de worktree e não 148, e **10** destacadas e não 9. As três faces do problema se separam assim, com os números de hoje tratados como testemunha de data:

| Face | Medido em 2026-09-08 | O que a branch obrigatória resolve |
|---|---|---|
| 1 — destacada sem nome | 10 entradas destacadas, **zero** com commit órfão | Resolve inteiramente, e de forma barata |
| 2 — trabalho não commitado | 3 das 10 destacadas com árvore suja (1, 2 e 1 linha de `status --porcelain`) | **Não resolve.** Branch não commita por ninguém |
| 3 — entulho pós-merge | 36 worktrees linkadas já mergeadas em `develop` ou `origin/develop` | Não resolve, e a remoção automática é o erro que o repositório já pagou |

O achado que reordena a face 3, e que é o mais caro desta especificação: das 36 mergeadas, **12 têm arquivo rastreado sujo, 23 têm apenas arquivo ignorado presente e exatamente 1 é removível sem perda**. O predicado `git status --porcelain` chama de "limpa" uma worktree que carrega estado local irrecuperável, e é exatamente esse colapso que destruiu `local.properties` e `build/` no incidente da issue #72. Uma varredura que removesse "as mergeadas limpas" hoje destruiria 23 árvores.

## 1. O que eu medi, com comando meu

### 1.1 O censo por repositório reproduz; dois totais de prosa não

`git -C <repo> worktree list --porcelain`, contando `^worktree ` e `^detached`:

| repositório | entradas | destacadas | orquestrador disse | confere |
|---|---|---|---|---|
| axis-go-cloud | 87 | 6 | 87 / 6 | sim |
| Axis.PadSimulator | 29 | 1 | 29 / 1 | sim |
| azim-crm | 30 | 1 | 30 / 1 | sim |
| axis-fare-validator | 2 | 1 | 2 / 1 | sim |
| forge-harness | 2 | 1 | 2 / 1 | sim |
| **soma das linhas** | **150** | **10** | 148 / 9 | **não** |

Cada linha reproduz. Os dois totais da prosa do orquestrador não são o que as linhas dele mesmo somam, e a diferença é aritmética, não de instrumento. Registro porque a especificação não pode herdar um número que ela não conferiu, e porque as duas correções empurram na direção contrária da tranquilidade: há mais worktrees e mais destacadas do que o relato dizia.

`git worktree list --porcelain` inclui o **checkout principal** como primeira entrada. Descontando os cinco troncos, as worktrees linkadas — a população sobre a qual esta onda age — são **145**.

### 1.2 Nenhum commit órfão, e três árvores sujas: as duas metades do relato confirmam

Para as 10 destacadas, `git branch -a --contains $(git rev-parse HEAD)` e `git status --porcelain`:

| worktree destacada | branches contendo o HEAD | linhas sujas |
|---|---|---|
| axis-go-cloud/.forge/worktrees/defer04-transporte-real | 19 | 0 |
| axis-go-cloud/.forge/worktrees/diag-overlay-antes | 16 | 0 |
| axis-go-cloud/.forge/worktrees/diag-po-a | 22 | 0 |
| axis-go-cloud/.forge/worktrees/diag-po-b | 16 | 0 |
| axis-go-cloud/.forge/worktrees/diag-po-c | 15 | 0 |
| axis-go-cloud/.forge/worktrees/dukpt-borda | 13 | 0 |
| Axis.PadSimulator/.forge/worktrees/audit-ldg-0489 | 4 | **1** |
| azim-crm/.forge/worktrees/mut-delete | 50 | 0 |
| axis-fare-validator/.forge/worktrees/prova-ce32d80f | 3 | **2** |
| /private/tmp/forge-baseline-wt | 7 | **1** |

O trabalho **commitado** não está se perdendo: o mínimo da coluna do meio é 3, nunca 0. E as três árvores sujas são exatamente as três que o orquestrador nomeou, com exatamente as contagens que ele nomeou. As duas afirmações dele que mais importam para o desenho — "nenhum órfão" e "três sujas" — sobrevivem à conferência independente.

### 1.3 "Mergeada" é predicado dependente de ref, e as duas refs divergem hoje nos dois sentidos

Classifiquei as 145 linkadas por `git merge-base --is-ancestor HEAD <ref>` contra `develop` **local** e `origin/develop`, separadamente:

| repositório | linkadas | destacadas | mergeada nas duas | só em `develop` local | só em `origin/develop` | viva |
|---|---|---|---|---|---|---|
| axis-go-cloud | 86 | 6 | 1 | **1** | 0 | 78 |
| Axis.PadSimulator | 28 | 1 | 14 | 0 | 0 | 13 |
| azim-crm | 29 | 1 | 15 | 0 | **5** | 8 |
| axis-fare-validator | 1 | 1 | 0 | 0 | 0 | 0 |
| forge-harness | 1 | 1 | 0 | 0 | 0 | 0 |
| **total** | **145** | **10** | **30** | **1** | **5** | **99** |

O `develop` local do `azim-crm` está **60 commits atrás** de `origin/develop`, e por isso cinco worktrees estão mergeadas para o servidor e não para a réplica local. No `axis-go-cloud` a divergência vai no sentido oposto: uma worktree é ancestral de `develop` local e não de `origin/develop`. Ou seja, **as duas escolhas ingênuas de ref erram hoje, em repositórios diferentes, em direções opostas** — é a mesma lição que o `worktree-reconcile.sh` já pagou em LDG-0056, e ela reaparece intacta neste predicado.

Total de mergeadas por "ao menos uma das duas refs": **36**. O orquestrador contou 38; a diferença é a ref escolhida e a inclusão ou não dos troncos, e nenhum dos dois números é critério — o critério está na decisão D6.

### 1.4 O número que decide a face 3: "limpa" segundo `status` não é limpa

Sobre as 36 mergeadas, cruzando `git status --porcelain` com `git clean -ndX` (o que está **ignorado e presente**, que o `status` não enxerga):

| repositório | rastreada suja | só ignorados presentes | totalmente limpa |
|---|---|---|---|
| axis-go-cloud | 0 | 1 | 1 |
| Axis.PadSimulator | 5 | 9 | 0 |
| azim-crm | 7 | 13 | 0 |
| axis-fare-validator | 0 | 0 | 0 |
| forge-harness | 0 | 0 | 0 |
| **total** | **12** | **23** | **1** |

Uma worktree em 36 é removível sem perda. Vinte e três satisfazem "limpa" por `status --porcelain` e carregam estado que a remoção apaga sem recuperação possível. Esta única linha derruba qualquer desenho que proponha varrer o entulho, e valida em retrospecto o default invertido que o `post-merge` já adotou depois da issue #72.

Custo medido do instrumento, e ele importa para a fiação: a varredura com `clean -ndX` sobre as 145 linkadas **não terminou em 590 segundos** em primeiro plano nesta máquina. O predicado de arquivo ignorado é caro e não pode entrar em caminho quente.

### 1.5 Fixture própria: quais caminhos de abertura chegam a HEAD destacado

Repositório de fixture criado sob `$TMPDIR` (nunca dentro do repositório real), com `.forge/worktrees/` e `.gitignore`. Resultado observado de `git worktree add`, lendo `git rev-parse --abbrev-ref HEAD` no destino:

| comando | HEAD resultante |
|---|---|
| `git worktree add .forge/worktrees/w1 HEAD` | **destacado** |
| `git worktree add --detach .forge/worktrees/w2 HEAD` | **destacado** |
| `git worktree add .forge/worktrees/w3` (sem ref) | branch `w3`, derivada do basename |
| `git worktree add .forge/worktrees/w4 develop` | branch `develop` |
| `git worktree add .forge/worktrees/w5 feat/x` | branch `feat/x` |

Os dois caminhos que produzem destacado são passar um **commit-ish** como ref e passar `--detach`. Os dois são o que um agente digita quando quer "a árvore como está agora", que é a operação mais comum de diagnóstico — e é exatamente o perfil dos seis `diag-*` e `dukpt-borda` do `axis-go-cloud`.

O caminho sem ref, que parece a saída óbvia, **falha de três formas distintas que eu medi**, e por isso não pode ser o default de nada:

- `git worktree add .forge/worktrees/w.lock` → `fatal: 'w.lock' is not a valid branch name`;
- `git worktree add .forge/worktrees/feat` com `feat/x` existente → `fatal: cannot lock ref 'refs/heads/feat': 'refs/heads/feat/x' exists` (colisão diretório/arquivo no namespace de refs);
- `git worktree add .forge/worktrees/develop` com `develop` já checada em outra worktree → `fatal: 'develop' is already used by worktree at ...`.

### 1.6 O hook de localização deixa passar as duas formas de destacado

`enforce-worktree-location.sh` alimentado com o JSON de `tool_input.command`, rc observado:

| comando | rc |
|---|---|
| `git worktree add .forge/worktrees/w9 HEAD` | **0** (passa) |
| `git worktree add --detach .forge/worktrees/w9 HEAD` | **0** (passa) |
| `git worktree add .forge/worktrees/w9 -b feat/y` | 0 (passa) |
| `git worktree add ../fora -b feat/x` | 2 (bloqueia) |

O guard existente cobra **localização** e é indiferente a **branch**. Ele é também `PreToolUse`, ou seja específico do Claude Code: um humano no terminal, um script, uma IDE ou outro agente não passam por ele. Esse é o buraco literal da pergunta "onde mora o enforcement, sabendo que o operador pode chamar `git worktree add` direto".

### 1.7 O achado que decide o desenho: `post-checkout` dispara em `git worktree add`

Instalei um `post-checkout` na fixture e medi. Ele dispara, com `PWD` igual à **worktree nova**:

```
args: prev=0000000000000000000000000000000000000000 new=3113ab9 isbranch=1
PWD=<repo>/.forge/worktrees/pc1
git-dir=<repo>/.git/worktrees/pc1   common=<repo>/.git
HEAD=HEAD  sym=DETACHED
```

Quatro propriedades medidas, e três delas contrariam o que a leitura ingênua da documentação sugeriria:

1. **`$3` (o flag "is branch checkout") vale `1` também na criação destacada.** Um gate ou um hook que discriminasse por `$3` nasceria morto. O discriminador correto e medido é `git symbolic-ref -q HEAD`, que sai vazio no destacado e devolve `refs/heads/<nome>` no atacado.
2. **`$1` vale quarenta zeros em `worktree add`** (nas duas formas, destacada e `-b`) e vale um sha real num `git checkout` comum. Combinado com `GIT_DIR != GIT_COMMON_DIR`, isso identifica "criação de worktree" sem ambiguidade.
3. **`git worktree add --no-checkout` NÃO dispara o hook.** Medido: a invocação com `--no-checkout` produziu zero linhas de log e a worktree ficou destacada. É o buraco desta solução e ele está nomeado na seção 7.
4. **`exit 1` no `post-checkout` NÃO aborta o `git worktree add`.** Medido: o `git worktree add` devolveu rc 1 e a worktree **continuou existindo em disco**. Recusar é o pior dos mundos — deixa a worktree destacada E devolve erro. Esta medição fecha a decisão D1: o hook **conserta**, nunca bloqueia.

### 1.8 O conserto funciona, e a cascata de nomes também

Com o hook consertando por `git switch -c`, na mesma fixture:

| cenário | observado |
|---|---|
| `worktree add <dir> HEAD` | `HEAD final: wt/rep1` — consertado |
| `worktree add <dir> -b feat/rep2` | `worktree já em branch (feat/rep2)` — no-op |
| `worktree add --no-checkout <dir> HEAD` | `HEAD final: HEAD` — **não alcançado** |

A recursão é real e precisa de guarda: `git switch -c` dispara `post-checkout` de novo. Uma variável de ambiente marcada na chamada interna e testada na entrada resolve, e eu a medi funcionando.

A primeira versão ingênua do conserto falhava em silêncio em três casos que eu medi, todos terminando com `HEAD final: HEAD` e o hook saindo 0 — o falso-verde da invariante 2, dentro do próprio conserto: nome derivado inválido (`wt/x.lock`), colisão diretório/arquivo (`wt/col` com `wt/col/a` existente) e branch já existente (`wt/dup`). Com saneamento por `git check-ref-format --branch` e uma cascata de candidatos, medi os três casos passando a resolver na primeira ou na segunda tentativa, e medi a cascata avançando até a quarta tentativa quando quatro worktrees consecutivas pedem o mesmo nome a partir do mesmo commit.

### 1.9 Renomear depois: o git já faz, e a única obrigação do harness é não atrapalhar

`git branch -m feat/x feat/x-renomeada` com `feat/x` **checada numa worktree linkada**: medido, a worktree seguiu sozinha (`rev-parse --abbrev-ref HEAD` passou a devolver `feat/x-renomeada`) e continuou sendo worktree do mesmo repositório. O `HEAD` de uma worktree atacada é uma ref simbólica, e o git a atualiza no rename.

Consequência de desenho, e é uma restrição, não uma comodidade: **nenhuma peça desta onda pode guardar o nome da branch como chave em arquivo lateral**, porque o rename que o dono pediu explicitamente quebraria o vínculo no instante seguinte. O estado do git é o registro. Um sidecar chaveado por caminho de worktree também não serve, porque `git worktree move` existe.

### 1.10 O que a branch não salva, medido

Na fixture, worktree com um arquivo não rastreado:

- `git worktree remove <dir>` → `fatal: contains modified or untracked files, use --force to delete it`. **O git já recusa.**
- `git worktree remove --force <dir>` → remove, e o arquivo some.
- Depois da remoção, `git branch` **ainda lista a branch** `w3`.

A branch sobreviveu e o trabalho não. É a demonstração direta de que criar a branch na abertura é condição necessária e não suficiente para a face 2.

## 2. Maquinaria que já existe, e o que cada peça já cobre

| Peça | Cobre hoje | Não cobre |
|---|---|---|
| `hooks/pre-tool-use/enforce-worktree-location.sh` | localização, só no Claude Code | branch; qualquer operador fora do Claude Code (medido em 1.6) |
| `hooks/git/pre-commit` | recusa commit de worktree fora de `.forge/worktrees/` | HEAD destacado |
| `hooks/git/post-merge` | **propõe** remoção de mergeadas, distingue limpa de suja, e tem a guarda de `clean -ndX` | só dispara num merge no tronco, e só varre `$ROOT/.forge/worktrees/*` |
| `scripts/worktree-reconcile.sh` | foto por worktree: branch, ahead/behind medido por `ls-remote`, sujeira, último commit | não classifica desfecho nem propõe ação; não olha arquivo ignorado |
| `scripts/doctor.sh` (378-395) | divergência de maquinaria por worktree | estado de branch e de limpeza |
| `rules/conventions/git-worktree.md` | política em prosa: sempre `-b`, sempre `.forge/worktrees/` | nada mecânico |
| `skills/using-git-worktrees/SKILL.md` | procedimento | **abençoa o destacado** em letra: *"HEAD destacado, gerenciado externamente. Será preciso criar a branch no momento de finalizar"* |
| `scripts/lib/red-replay.mjs` | cria worktree **`--detach` deliberadamente**, em `tmpdir()`, com remoção em `try/finally` | — é o uso legítimo de destacado e precisa continuar funcionando |

Duas leituras mudam o escopo desta onda e precisam ficar registradas. A primeira: **a face 3 já tem desenho correto e ele é opt-in por decisão medida** — o `post-merge` propõe em vez de remover, e o gate `w153[72]` guarda esse default com a frase "o default tem de propor". O que falta não é uma varredura nova, é uma **superfície de consulta**, porque o `post-merge` só fala no instante de um merge no tronco e ninguém que acumulou 29 worktrees no `azim-crm` estava olhando naquele instante. A segunda: **a skill autoriza em letra o estado que o dono quer proibir**, e nenhuma mudança de comportamento é coerente enquanto essa frase estiver lá.

## 3. As três faces, separadas

**Face 1 — destacada sem nome.** Dez casos, zero perda de commit, dano real é ausência de nome: não há branch para empurrar, não há PR possível, e o rastro morre na máquina quando a worktree é removida. Correção barata e é o que o dono pediu.

**Face 2 — trabalho não commitado.** Três casos, e é o único que perde dado. Branch não commita por ninguém (medido em 1.10). Qualquer solução aqui é cara ou intrusiva, e a especificação escolhe uma e escreve a razão.

**Face 3 — entulho pós-merge.** Trinta e seis casos. Não perde trabalho e é o que faz o operador não achar o que importa entre 86 entradas. A ação certa aqui é **informar melhor**, e a medição de 1.4 diz por quê: agir automaticamente sobre esta população destruiria 23 árvores.

## 4. Decisões fechadas

### D1 — O enforcement mora no `post-checkout`, e ele **conserta**, não bloqueia

**Decidido:** nasce `template/.forge/hooks/git/post-checkout`. Quando, e somente quando, as quatro condições valem — `GIT_DIR != GIT_COMMON_DIR`, `$1` igual a quarenta zeros, `git symbolic-ref -q HEAD` vazio, e o `--show-toplevel` sob `<tronco>/.forge/worktrees/` — ele cria a branch e atacha o HEAD, e imprime o nome criado junto com o comando de rename.

**Por que aqui:** é o único ponto medido que dispara em `git worktree add` **independentemente de quem digitou o comando** — humano, agente, IDE ou script. E ele é lido do `core.hooksPath`, que vive no `.git/config` comum e que o harness já grava em caminho absoluto para o tronco, o que o torna a única peça desta onda que alcança worktree criada de branch antiga (seção 7).

**Por que consertar e não recusar:** medido em 1.7, item 4 — `exit 1` no `post-checkout` não desfaz o `git worktree add`. Recusar produziria uma worktree destacada em disco **mais** um rc 1, que é estritamente pior que o estado de hoje.

**Alternativa descartada — endurecer o `enforce-worktree-location.sh` para exigir `-b`.** Ela cobre só o Claude Code (medido em 1.6), e ela recusa em vez de consertar, o que empurra o operador para reformular o comando em vez de resolver o problema. Fica como reforço opcional e explicitamente fora desta onda.

**Alternativa descartada — uma porta nova `worktree-open.sh`.** O repositório já tem três formas documentadas de abrir worktree (a rule, a skill e a tool nativa) e nenhuma das 10 destacadas de hoje teria sido evitada por uma quarta forma que o operador escolheu não chamar. Uma porta é conveniência; o hook é garantia, e ele cobre a porta que o operador de fato usou.

### D2 — Nome default `wt/<slug>`, cascata medida, terceiro estado no fim

**Decidido:** o candidato é `wt/<slug>`, onde `<slug>` é o basename do `--show-toplevel` saneado para `[A-Za-z0-9._-]` sem hífen nem ponto inicial. Cada candidato passa por `git check-ref-format --branch` antes de ser tentado, e a cascata avança para `wt/<slug>-<sha7>` e depois para sufixos numerados. A cascata tem teto declarado; esgotada, o hook **não sai 0**: imprime em `stderr` que não conseguiu dar nome àquela worktree, imprime o comando que o operador roda, e sai com código próprio.

**Por que o prefixo `wt/`:** ele é um namespace, o que torna a branch trivialmente renomeável para fora dele — e o fato de uma branch **continuar** em `wt/` é por si só o sinal legível de que ninguém a nomeou direito. O prefixo não elimina a colisão diretório/arquivo (`wt/a` contra `wt/a/b`), e por isso a cascata existe.

**Por que não derivar do basename sem prefixo, que é o que o git faz sozinho:** medido em 1.5 — falha de três formas distintas, e duas delas com mensagem que não sugere saída.

**Por que três estados e não dois:** "consegui dar nome", "já tinha nome" e "não consegui dar nome" são desfechos diferentes, e a primeira versão do conserto que eu escrevi colapsava o terceiro no primeiro saindo 0 em três casos medidos (1.8). É a invariante 2 aparecendo dentro do próprio remédio.

### D3 — Quando a branch já existe

Três casos, decididos, todos com mensagem que nomeia o estado:

1. **Existe e está checada em outra worktree** — o git recusa sozinho com o caminho da outra worktree; a cascata avança para o próximo candidato. Nunca reatachar duas worktrees à mesma branch.
2. **Existe e está livre** — a cascata avança para o próximo candidato em vez de reaproveitar. Reaproveitar uma branch livre de mesmo nome silenciosamente juntaria dois trabalhos que só têm o nome em comum, e o custo do erro é assimétrico: uma branch a mais é entulho, uma branch compartilhada por engano é histórico misturado.
3. **Não existe** — cria.

**Alternativa descartada — reaproveitar a branch livre.** Ela é atraente para o caso "reabri a worktree que eu tinha fechado", e é errada para o caso "outro agente usou esse slug semana passada". Como o hook não sabe distinguir os dois, ele escolhe o desfecho reversível.

### D4 — Escopo do conserto: `<tronco>/.forge/worktrees/` e nada além

**Decidido:** o hook conserta apenas worktree cujo `--show-toplevel` esteja sob `<tronco>/.forge/worktrees/`. Fora dali ele **avisa em `stderr` e não mexe**.

**Por quê:** `.forge/worktrees/` é o território declarado do harness — o `enforce-worktree-location.sh` bloqueia qualquer outro destino, o `post-merge` só varre ali, e o `FORGE.md` §3.3 o recomenda em letra. E, decisivamente, `red-replay.mjs` cria as worktrees efêmeras dele com `--detach` em `tmpdir()`, medido na linha 306 e no `makeWorktreePath()`: um conserto de escopo largo atacharia branch em cada replay de evidência red e deixaria lixo `wt/forge-red-replay-*` acumulando no repositório.

**Alternativa descartada — isentar o `red-replay` por variável de ambiente.** Uma cópia **antiga** do `red-replay` num worktree velho não passaria a variável, e voltaria a produzir o lixo — é literalmente o padrão da issue #123, que esta onda existe em parte para respeitar.

**Alternativa descartada — isentar por prefixo de nome (`forge-red-replay-`).** Contrato implícito em string, que é o defeito nomeado na issue #145.

**Custo aceito, escrito:** `/private/tmp/forge-baseline-wt`, a destacada e suja do próprio `forge-harness`, fica **fora do conserto** e recebe só aviso. Ela aparece na triagem da D6.

### D5 — Face 2: o harness **informa e oferece o resgate; não commita e não remove sozinho**

**Decidido:** nenhuma peça desta onda executa commit automático nem remoção. A triagem (D6) classifica e **imprime** o comando de resgate para cada worktree suja, e o comando que ela imprime commita na **própria branch da worktree** — que existe, porque a D1 garante que existe — com mensagem `wip(<slug>): resgate antes de remover a worktree`.

**Por que não commit automático:** um commit que ninguém pediu entra no histórico de uma branch que vai virar PR, e ele carrega o que estava na árvore naquele instante, inclusive segredo que o operador ainda não tinha revisado. O harness tem histórico ruim com maquinaria que escreve por conta própria: a issue #120 (`HANDOFF.md` de 290.761 bytes reduzido a 2.764, `exit 0`), LDG-0175 (gate que destruiu arquivo rastreado usado como fixture) e a issue #72 (worktree removida no merge levando `local.properties` junto). Três precedentes, três perdas, zero casos em que a automação acertou.

**Por que não recusar a remoção:** o git **já recusa** worktree suja sem `--force` (medido em 1.10). Uma recusa do harness por cima não acrescenta cobertura e não alcança `--force` nem `rm -rf`, que são os dois caminhos por onde o dado de fato some.

**O que fica descoberto, em letra:** `git worktree remove --force` digitado à mão e `rm -rf` continuam destruindo trabalho não commitado, e **nada nesta onda os alcança**. O git não oferece gancho de remoção de worktree, e o harness não vai impor alias de shell ao consumidor. A cobertura desta onda para a face 2 é: o trabalho ganha branch (D1), fica **visível** na triagem (D6), e o resgate fica a um comando copiável de distância. É menos do que o dono pediu para a face 2, e é o máximo que este mecanismo entrega honestamente.

### D6 — Face 3: `worktree-reconcile.sh --triage`, que classifica e propõe, nunca age

**Decidido:** `worktree-reconcile.sh` ganha o modo `--triage`, que classifica cada worktree linkada num de **cinco** desfechos e imprime, para cada um, o comando exato — sem executar nenhum. Os predicados de "mergeada" e de "limpa" são os **mesmos** do `post-merge`, extraídos para lib compartilhada, para que o harness não passe a ter duas definições de "limpa".

| desfecho | predicado | o que a triagem imprime |
|---|---|---|
| viva | não é ancestral da ref de integração | nada a fazer |
| destacada | `symbolic-ref -q HEAD` vazio | o `git switch -c` que dá nome |
| mergeada e totalmente limpa | ancestral, `status --porcelain` vazio **e** `clean -ndX` vazio | `git worktree remove` + `git branch -d` |
| mergeada com ignorados presentes | ancestral, `status` vazio, `clean -ndX` **não** vazio | as três primeiras linhas do `clean -ndX` e o `--force` explícito |
| mergeada e suja | ancestral, `status` não vazio | o resgate da D5, e só depois a remoção |
| **não consegui verificar** | a ref de integração não resolve, ou `develop` local diverge de `origin/develop` | a divergência medida em commits e o `git fetch` que a resolve |

O sexto desfecho é o terceiro estado e ele não é decorativo: medido em 1.3, hoje, cinco worktrees do `azim-crm` mudam de classe conforme a ref escolhida, e uma do `axis-go-cloud` muda no sentido oposto. Uma triagem que respondesse "não mergeada" para as cinco estaria mentindo com rc 0.

**Fiação, porque triagem que ninguém chama é LDG-0160 de novo:** o `doctor.sh` passa a chamar a triagem no bloco de worktrees que ele já tem (378-395), na forma **barata** — só `symbolic-ref` e `status --porcelain`, imprimindo contagem por classe e uma linha convidando ao `--triage` completo. O predicado de arquivo ignorado **não** entra no doctor: medido em 1.4, a varredura com `clean -ndX` sobre 145 worktrees não terminou em 590 segundos.

**Alternativa descartada — remover automaticamente as mergeadas limpas.** Medido em 1.4: 23 das 36 satisfazem "limpa" por `status --porcelain` e carregam estado irrecuperável. A varredura destruiria 23 árvores e sairia com código zero, que é exatamente a definição da Onda A do plano.

**Alternativa descartada — fiar a triagem no `on-session-start.sh`.** Aquele arquivo é compartilhado com a cadeia do handoff (gate `w62`) e o custo da triagem sob orçamento de sessão não está medido. Fica registrado como candidato, fora desta onda.

### D7 — A prosa que autoriza o estado proibido é corrigida junto

**Decidido:** a frase da `skills/using-git-worktrees/SKILL.md` que diz *"HEAD destacado, gerenciado externamente. Será preciso criar a branch no momento de finalizar"* é substituída pela descrição do comportamento novo, e a `rules/conventions/git-worktree.md` ganha a diretriz de que a branch nasce com a worktree, com o `wt/` como nome de partida legítimo e renomeável.

**Por quê:** a issue #126 já registrou o custo de prosa que contradiz o código — *"o defeito custa mais pelo que ensina errado do que pelo que faz"*, e ali a prosa desatualizada induziu fixture invertida em quem escreveu teste a partir dela. Deixar a skill abençoando o destacado enquanto o hook o conserta é fabricar essa mesma armadilha de propósito.

## 5. O que a onda entrega

| Peça | O que é |
|---|---|
| `template/.forge/hooks/git/post-checkout` | O conserto da D1, com as quatro condições de disparo, o discriminador `symbolic-ref` (nunca `$3`), a guarda de recursão, a cascata de nomes da D2 e o terceiro estado da D2 |
| `template/.forge/scripts/lib/worktree-classify.sh` | Os predicados compartilhados: "é ancestral de qual ref, e as duas refs concordam", "está limpa segundo `status`", "está limpa segundo `clean -ndX`". Fonte única, consumida pelo `post-merge` e pela triagem |
| `worktree-reconcile.sh --triage` | A superfície de consulta da D6, com os seis desfechos e o comando por desfecho |
| `hooks/git/post-merge` | Passa a consumir `worktree-classify.sh` em vez das próprias cópias dos predicados. **Comportamento inalterado** — o default continua propondo, a guarda de ignorados continua, e o `w153[72]` continua verde |
| `doctor.sh` | Chama a triagem barata no bloco de worktrees que já existe |
| `SKILL.md` e `git-worktree.md` | A correção da D7 |
| `tests/w210-worktree-branch-obrigatoria-gate.sh` | O gate, seção 8 |
| `tests/w147-hook-delegation-gate.sh` | Editado junto: `COBERTOS` ganha `post-checkout`, e o cenário de delegação do hook novo entra ali. Ver seção 11 |
| `CHANGELOG.md` | Entrada em `[Unreleased]` |

## 6. Retrocompatibilidade com os cinco consumidores

O hook novo é **arquivo novo** em `template/.forge/hooks/git/`, e `hooks/` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS` — o overlay do `forge update` o instala sem sobrescrever customização, porque não há customização preexistente de um arquivo que não existia. Isso não isenta a onda das issues #125 e #131 (o update desarma configuração do consumidor); só significa que esta peça não as agrava.

Efeito por consumidor, medido:

- **axis-go-cloud (86 linkadas, 6 destacadas, 78 vivas):** ganha o conserto para worktree nova. As 6 destacadas de hoje **não** são retroativamente consertadas — o hook age na criação. Elas aparecem na triagem com o comando de conserto. A triagem barata no doctor percorre 86 worktrees; o custo precisa ser medido no piloto antes do merge.
- **Axis.PadSimulator (28 linkadas, 14 mergeadas, 5 sujas, 9 com ignorados):** é o consumidor onde a triagem mais muda o dia a dia, e é onde a guarda de ignorados mais importa — **nenhuma** das mergeadas dali é removível sem perda hoje.
- **azim-crm (29 linkadas, `develop` local 60 commits atrás de `origin/develop`):** é o consumidor que exercita o terceiro estado da triagem no primeiro uso. Se a triagem não distinguisse as refs, ela classificaria 5 worktrees erradas ali.
- **axis-fare-validator (1 linkada, destacada, 2 linhas sujas):** caso mínimo, e o único onde a worktree destacada e suja é a única worktree do repositório.
- **forge-harness (1 linkada, destacada, suja, e **fora** de `.forge/worktrees/`):** exercita a D4 — recebe aviso, não conserto. É o consumidor que prova que o escopo é escopo e não retórica.

Contrato preservado: nenhuma mensagem existente muda de texto, nenhum script muda de assinatura, nenhum campo de schema muda de forma. O `post-merge` ganha uma linha, e ela SUBTRAI da população que ele remove em vez de somar — a correção está na seção 14.18, medida com controle e efeito, e o gate `w153[72]` continua verde sem edição.

## 7. A worktree de branch velha — o que esta solução alcança e o que não alcança

**Alcança:** o `post-checkout`. Porque `core.hooksPath` vive no `.git/config` **comum a todos os worktrees** e o harness já o grava em caminho absoluto apontando para o tronco (`bin/forge.mjs`, linhas 213-217 e 245; `installer/install.sh:157`; e o `doctor.sh:342` já acusa o valor relativo legado). Uma worktree criada a partir de uma branch de seis meses atrás executa o `post-checkout` **do tronco**, não o da própria árvore, porque ela não tem um. Este é o elo que a issue #123 identificou — a configuração é o único ponto lido do tronco — e é a razão de o desenho ter sido puxado para um git hook em vez de um script.

Com três condições que precisam ser ditas, e que são o terceiro estado desta cobertura:

1. Só vale onde `core.hooksPath` está **absoluto e apontando para o tronco**. Onde ele está no valor relativo legado `.forge/hooks/git`, cada worktree resolve na própria árvore e roda a cópia antiga — o `doctor` já acusa isso, e o gate `w94` já guarda a migração.
2. Só vale onde `core.hooksPath` está configurado. Repositório sem harness instalado não tem hook nenhum, e isso é a degradação legítima que o `w147[7]` já afirma.
3. Só vale para worktree **criada depois** da instalação do hook. As 10 destacadas de hoje não são alcançadas.

**Não alcança, dito em letra sem fingir cobertura:**

- `worktree-reconcile.sh --triage`, `worktree-classify.sh` e o `doctor` moram em `.forge/scripts/`, **dentro da árvore versionada**. Uma worktree criada de branch antiga carrega as cópias antigas desses três e executa as antigas. Nada nesta onda muda isso, e a única mitigação é a que o `doctor` já oferece: listar a divergência de maquinaria por worktree para que alguém decida sincronizar.
- `git worktree add --no-checkout` cria worktree destacada sem disparar `post-checkout` — medido em 1.7, item 3. É o furo desta solução e ele é estrutural: nenhum gancho do git dispara nesse caminho. A triagem o vê depois; o conserto não o vê nunca.
- `git worktree remove --force` e `rm -rf` continuam destruindo árvore suja, com ou sem branch.

## 8. O vermelho antes do verde

O gate `w210-worktree-branch-obrigatoria-gate.sh` opera sobre fixture própria sob `$TMPDIR`, nunca sobre arquivo rastreado do repositório (LDG-0175), e nunca cria worktree dentro do repositório real.

**Cenário [0] — controle de instrumento.** A fixture existe, é repositório git com ao menos um commit, tem `.forge/worktrees/` e `.gitignore`, e o caminho canônico do hook sob teste é o esperado. Sem este cenário um caminho digitado errado produziria o mesmo vermelho que a ausência real da funcionalidade — a lição do `w208[0]`.

**O vermelho de verdade, o que ele é e por que ele é honesto.** Antes de existir uma linha de `post-checkout`, o cenário [1] — instalar a fixture, rodar `git worktree add <dir sob .forge/worktrees/> HEAD`, e afirmar que `git symbolic-ref -q HEAD` no destino resolve para uma ref sob `refs/heads/` — falha porque `worktree add` com commit-ish produz HEAD destacado. Isso está medido em 1.5, na mesma fixture, **antes** de qualquer implementação: o `HEAD final` foi `HEAD`. O vermelho é a ausência real da funcionalidade e não uma asserção que falha por sintaxe, por fixture ausente ou por caminho errado.

Dezoito cenários, de `[0]` a `[17]`, com denominador **fixo** por construção:

| # | Afirma | Estado antes da implementação |
|---|---|---|
| [0] | controle de instrumento | verde por construção |
| [1] | `worktree add <dir> HEAD` sob `.forge/worktrees/` termina com HEAD **atacado** | **vermelho** — medido, HEAD destacado |
| [2] | `worktree add --detach <dir>` sob `.forge/worktrees/` termina atacado | **vermelho** |
| [3] | `worktree add <dir> -b <nome>` mantém `<nome>` e o hook não fala | verde (no-op esperado) |
| [4] | worktree destacada **fora** de `.forge/worktrees/` recebe **aviso** e continua destacada (D4) | vermelho — não há aviso nenhum hoje |
| [5] | o discriminador é `symbolic-ref` e não `$3`: um `worktree add -b` com `$3=1` **e** um `worktree add HEAD` com `$3=1` produzem desfechos **diferentes** | vermelho |
| [6] | nome derivado inválido (`x.lock`) resolve por saneamento, e o HEAD termina atacado | vermelho |
| [7] | colisão diretório/arquivo (`wt/col` com `wt/col/a`) resolve pela cascata, HEAD atacado | vermelho |
| [8] | branch `wt/<slug>` já existente **não** é reaproveitada: a branch resultante é outra, e a existente segue apontando para o commit anterior (D3) | vermelho |
| [9] | cascata esgotada → hook sai com código próprio, imprime em `stderr`, **não** sai 0 (terceiro estado) | vermelho |
| [10] | não há recursão: o `git switch -c` interno não reentra no hook, provado por contador de execuções na fixture | vermelho |
| [11] | `git branch -m` na branch criada mantém a worktree vinculada e o `abbrev-ref` acompanha (o rename que o dono pediu) | verde por propriedade do git, e é regressão declarada: quebra se alguém introduzir sidecar chaveado por nome |
| [12] | `--triage` classifica uma mergeada com **arquivo ignorado presente** como classe própria, distinta de "totalmente limpa", e **não** propõe remoção simples | vermelho |
| [13] | `--triage` com `develop` local divergente de `origin/develop` devolve **não consegui verificar** com a divergência em commits, nunca um veredito | vermelho |
| [14] | `--triage` **não executa** nada: contagem de worktrees e de branches idêntica antes e depois, e nenhum arquivo removido | vermelho — não há `--triage` |
| [15] | `post-merge` continua **propondo** e continua guardando ignorados depois da extração para lib (não-regressão do `w153[72]`) | verde, e é a asserção que impede a refatoração de mudar comportamento |
| [16] | `doctor` chama a triagem barata e imprime contagem por classe; universo varrido **não** é zero | vermelho |
| [17] | contador de controle: o gate declara `N` cenários e reprova se o número executado divergir de `N` | — |

**Contador de controle.** O denominador é o número de cenários declarados no próprio gate, que é fixo por construção e cuja divergência é justamente o achado — a única exceção legítima da invariante 14. **Nenhuma asserção deste gate carrega literal derivado da árvore.** Onde a fixture cria worktrees, ela cria um número que ela mesma escolheu e conta. Onde o gate afirma algo sobre a população real dos consumidores, ele afirma **propriedade mais piso**: "toda worktree destacada listada tem classe atribuída" e "o universo classificado é maior que zero", nunca "há 10 destacadas" nem "há 36 mergeadas" — os números de 2026-09-08 são testemunha de data e envelhecem, muito provavelmente durante a própria onda.

## 9. Prova de mutação — propriedade e contrafactual

A invariante 19 é explícita: a especificação declara a **propriedade** e o **contrafactual**, e quem implementa escolhe o primitivo e prova que ele discrimina. Nenhuma linha de `perl -0pi` é prescrita aqui, porque eu não executei nenhuma — e LDG-0164 registra duas ocorrências neste mesmo plano em que o `$` do lado direito virou variável vazia do perl, a mutação virou no-op, e o `cmp` de controle confirmou alegremente que o arquivo tinha mudado.

Toda mutação abaixo exige **controle** (o gate verde antes), **efeito** (o gate acusando, no cenário nomeado), **recontrole** (o gate verde de novo depois da restauração) e **restauração por checksum** do arquivo mutado. Sem o recontrole a prova não vale (`feedback-mutacao-fantasma-restore`).

| Propriedade sob prova | Mutação, descrita pelo efeito pretendido | Contrafactual exigido | Já medido? |
|---|---|---|---|
| O discriminador de destacado é `symbolic-ref`, não `$3` | trocar o teste de destacado pelo teste de `$3` | [5] acusa, e [1] e [2] passam a falhar — porque `$3` vale `1` nos dois casos | **sim**: medi `isbranch=1` tanto em `worktree add HEAD` quanto em `worktree add -b` |
| O hook só age em criação de worktree | remover o teste de `$1` igual a quarenta zeros | um `git checkout` comum no tronco passa a ser processado; o cenário de não-interferência acusa | **sim**: medi `prev=0000…` em `worktree add` e um sha real em `git checkout -q main` |
| O escopo é `.forge/worktrees/` | remover o teste de prefixo de caminho | [4] acusa: a worktree fora do território é consertada em vez de avisada | **sim**: `red-replay.mjs` cria em `tmpdir()`, medido na linha 306 |
| A guarda de recursão existe | remover a variável de guarda | [10] acusa por contador de execuções | **sim**: medi o `git switch -c` disparando o hook de novo |
| A cascata esgotada não sai 0 | trocar o `exit` do ramo de esgotamento por `exit 0` | [9] acusa | **sim**: a primeira versão do conserto que escrevi tinha exatamente esse defeito e produziu `HEAD final: HEAD` com hook silencioso em três casos |
| A triagem distingue ignorado de limpo | remover o predicado `clean -ndX` da classificação | [12] acusa: a classe "com ignorados" some e as árvores caem em "totalmente limpa" | **sim**: 23 das 36 mergeadas de hoje mudariam de classe |
| A triagem tem terceiro estado de ref | colapsar o desfecho "não consegui verificar" no desfecho "não mergeada" | [13] acusa | **sim**: 5 worktrees do `azim-crm` e 1 do `axis-go-cloud` mudam de classe conforme a ref, hoje |
| A triagem não age | trocar um `echo` de comando proposto pela execução do comando | [14] acusa por contagem de worktrees antes e depois | não medido; o implementador prova que discrimina |
| O `post-merge` continua propondo | reintroduzir a remoção no default | `w153[72]` acusa | já é gate existente |

**Armadilha de instrumento a evitar na implementação, medida hoje nesta máquina:** o `grep` do PATH é **ugrep 7.8.4** e, sobre arquivo com byte de controle, devolve saída vazia com rc 1 — indistinguível de "não há ocorrência" — enquanto `/usr/bin/grep` encontra e avisa. O CI roda `ubuntu-latest` com GNU grep. Toda varredura de texto deste gate usa caminho absoluto de binário e trata "vazio" como **não conclusivo** até que o universo lido seja contado.

## 10. Onde entram PBT, contrato, integração e E2E

**PBT (invariante 5).** O saneador e a cascata de nomes da D2 são um normalizador sobre espaço de entrada, que é exatamente o que LDG-0021 diz faltar. A propriedade a submeter a entrada gerada: para qualquer basename de diretório, o candidato produzido pela cascata ou passa em `git check-ref-format --branch` ou a cascata reporta esgotamento — nunca produz um nome que `git switch -c` rejeita. Os quatro exemplos escolhidos a dedo que eu medi (`x.lock`, `col`, `dup`, `zz` repetido quatro vezes) são ponto de partida, não cobertura.

**Contrato (invariante 6).** Duas fronteiras publicadas. A primeira é o conjunto de arquivos em `template/.forge/hooks/git/`, que o `w147[8]` já trata como contrato e que esta onda amplia — está na seção 11. A segunda é o vocabulário de desfechos da triagem: seis nomes que o operador e um gate alheio vão passar a citar, e mudá-los depois quebra quem os afirma.

**Integração (invariante 7).** O defeito desta onda é de fiação por natureza: `post-checkout` só existe se `core.hooksPath` apontar para ele, e a triagem só serve se alguém a chamar. Teste unitário sobre a função de classificação nasce verde e não diz nada. Os cenários [1], [2], [4], [16] exercem o caminho real, do `git worktree add` ao HEAD resultante e do `doctor` à contagem por classe.

**E2E.** O cenário [1] é o E2E do pedido do dono em uma linha: abre worktree pelo caminho que produz destacado hoje e afirma que ela nasceu com branch. O [11] é o E2E da segunda metade do pedido: renomear depois sem perder o vínculo.

**Guarda de vacuidade (invariante 18).** Todo cenário que varre um universo — hooks, worktrees, classes — publica o tamanho do universo e reprova com `universo-vazio` quando ele é zero. É o que impede o [16] de aprovar por não ter olhado para nada.

## 11. Gates que esta mudança quebra, nominalmente

Varri `tests/` antes de propor, conforme a invariante 15. Vinte e quatro gates citam `hooks/git`, `hooks.manifest`, `post-merge` ou `post-checkout`. Dois são afetados, e um deles quebra com certeza:

- **`tests/w147-hook-delegation-gate.sh`, cenário [8] — QUEBRA.** A linha 150 declara `COBERTOS="commit-msg post-merge pre-commit pre-push"` e a linha 158 reprova com *"hook '<nome>' existe em template/.forge/hooks/git/ e não tem cenário neste gate"*. Acrescentar `post-checkout` ao diretório torna este gate vermelho no instante do commit. **A edição do `w147` entra na mesma mudança**, e ela não é cosmética: o `post-checkout` precisa de um cenário de delegação próprio ali, provando que ele não conclui com sucesso quando o alvo que ele delega está ausente mas o diretório que o hospeda existe.
- **`tests/w153-upgrade-safety-gate.sh`, cenário [72] — precisa continuar verde.** Ele afirma que o `post-merge` propõe em vez de remover e que nunca toca worktree com arquivo ignorado. A extração dos predicados para `worktree-classify.sh` é refatoração de implementação e este gate é a prova de que ela não mudou comportamento. Não editar.
- **`tests/w192-declared-switch-has-reader-gate.sh`** varre `template/.forge/hooks/git/*`: o hook novo não pode declarar chave ou variável que ele mesmo não lê.
- **`tests/w97-hook-portability-gate.sh`** varre `mktemp` em todos os hooks: o `post-checkout` não usa `mktemp`; se vier a usar, o template precisa terminar nos `X` (armadilha BSD).
- **`tests/w13-init-gate.sh` e `tests/w94-hookspath-preserve-gate.sh`** afirmam o **valor** de `core.hooksPath`, não o conjunto de arquivos. Não afetados.

Nenhuma string que a produção já imprime é alterada por esta onda: as mensagens do `post-merge`, do `enforce-worktree-location.sh` e do `worktree-reconcile.sh` ficam como estão, e tudo que o hook novo imprime é texto novo.

**Fronteira com as cadeias concorrentes, declarada:** `hooks.manifest` descreve os ganchos de **`PreToolUse`**, não os hooks do git — confirmado no cabeçalho do `w208`. Esta onda não escreve nele e não toca `template/.forge/scripts/lib/secret-scan.mjs`. Se `template/.forge/commands/` vier a ser editado (não está previsto), o espelho em `plugin/forge` exige `npm run build:plugin`, nunca `build-plugin.sh`, que instala em `$HOME`.

## 12. O que esta onda explicitamente NÃO faz

1. **Não conserta retroativamente as 10 worktrees destacadas de hoje.** O hook age na criação. Elas aparecem na triagem com o comando; consertá-las é ato do operador, e o `/private/tmp/forge-baseline-wt` do próprio `forge-harness` nem isso recebe, por estar fora do território da D4.
2. **Não remove nem commita nada, em nenhuma circunstância, e não amplia o que já removia.** A triagem e o doctor não executam nada. O `post-merge` continua removendo o que já removia antes desta onda, e apenas isso: a seção 14.18 registra a correção que impede a onda de alargar aquela população, com o cenário `[20]` medindo controle e efeito lado a lado. A justificativa está na D5 e o custo está em 1.4.
3. **Não cria uma porta `worktree-open.sh`.** Justificativa na D1.
4. **Não alcança `git worktree add --no-checkout`.** Medido em 1.7, item 3: nenhum gancho do git dispara ali.
5. **Não alcança `git worktree remove --force` nem `rm -rf`.** O git não oferece gancho de remoção de worktree.
6. **Não alcança `worktree-reconcile.sh`, `worktree-classify.sh` nem `doctor.sh` dentro de worktree criada de branch antiga.** Os três moram na árvore versionada. Só o `post-checkout` atravessa, e só sob as três condições da seção 7.
7. **Não fia a triagem no `on-session-start.sh`.** Arquivo compartilhado com a cadeia do handoff (`w62`) e custo não medido sob orçamento de sessão.
8. **Não endurece o `enforce-worktree-location.sh` para exigir `-b`.** Reforço opcional, fora do escopo, e redundante com o hook.
9. **Não toca `hooks.manifest` nem `secret-scan.mjs`**, que pertencem às cadeias LDG-0177/0178 em voo.
10. **Não decide o que fazer com as 36 mergeadas.** Ela as torna legíveis e classificadas; a decisão de remover é do operador, uma a uma, com o `clean -ndX` na frente.

## 13. Definição de pronto

1. `bash -n` limpo em todo shell tocado; nada de `declare -A`, `${var,,}`, `${var^^}`, `mapfile` ou `readarray` (bash 3.2 do macOS).
2. O vermelho do `w210` **observado e colado** no PR, com a saída real de antes da implementação, e ele falha pela ausência da funcionalidade — o cenário [1] é o mesmo `git worktree add <dir> HEAD` que eu já medi produzindo `HEAD final: HEAD` na fixture.
3. `w210` verde, com contador de controle publicando `N/N` e reprovando em divergência.
4. Prova de mutação executada para as **nove** linhas da tabela da seção 9, cada uma com controle, efeito no cenário nomeado, recontrole e restauração conferida por checksum. Nenhuma linha escrita sem o efeito ter sido observado antes (invariante 16).
5. `w147` editado e verde, com cenário de delegação para o `post-checkout`.
6. `w153` verde **sem edição** — a prova de que a extração de predicados não mudou comportamento.
7. Suíte completa verde, rodada **serialmente pelo orquestrador**, nunca em concorrência com gate manual (`feedback-suite-sem-concorrencia`).
8. Piloto num consumidor real antes do merge: instalar num clone descartável do `axis-go-cloud`, medir o custo da triagem barata do doctor sobre 86 worktrees, e criar uma worktree pelos dois caminhos destacados conferindo que ela nasce com branch.
9. `CHANGELOG.md` em `[Unreleased]`.
10. Nenhum texto de coautoria de IA em commit, PR ou issue. PR contra `develop`.

## 14. Correções da implementação (2026-09-08)

Esta seção é normativa e tem precedência sobre o que a contradiz acima. Ela registra o que a revisão da especificação reprovou, o que a implementação mediu por conta própria, e onde a especificação errou. Nada aqui é reescrita cosmética: cada item foi medido antes de ser escrito.

### 14.1 A guarda de recursão por variável de ambiente sai da D1 e da seção 5, e o cenário [10] muda de enunciado

**O que a especificação dizia.** A D1 e a tabela da seção 5 mandavam implementar uma guarda de recursão por variável de ambiente, e a linha 4 da tabela de mutação da seção 9 prescrevia "remover a variável de guarda" com o cenário [10] como acusador.

**O que eu medi.** Em fixture própria sob `$TMPDIR`, com o hook contendo apenas o teste de `$1` igual a quarenta zeros e o teste de `symbolic-ref`, e sem variável de guarda nenhuma: `git worktree add -q .forge/worktrees/r2 HEAD` produziu **exatamente duas** invocações do hook, **uma** branch (`wt/r2`) e rc 0. A segunda invocação — a do `git switch -c` interno — chega com `prev=c7acdf7…`, um sha real, de modo que o teste de `$1` já a encerra na primeira linha; e `symbolic-ref` já devolve `refs/heads/wt/r2`, de modo que o segundo teste a encerraria de qualquer jeito. A recursão é impossível sob **qualquer uma das duas condições isoladamente**, e a variável de guarda seria código morto.

**A correção.** A guarda de ambiente **não** é implementada. A reentrância é contida por construção, e o hook diz isso em comentário. O cenário [10] deixa de afirmar "não reentra" — o que seria falso contra a implementação correta, porque o hook REENTRA e apenas sai cedo — e passa a afirmar **"a reentrância é contida: o hook reentra e nasce exatamente UMA branch por criação de worktree"**, medido por contagem de branches `wt/*`. A linha 4 da tabela de mutação passa a ser "remover o teste de `$1` **e** o de `symbolic-ref` ao mesmo tempo", que é a única combinação que produz laço: medido, ela produz cinco branches numa criação só, e a cascata com teto é o que faz o laço terminar.

### 14.2 O cenário de não-interferência nasce, e o denominador vai de 18 para 21

**O que a especificação dizia.** A linha 2 da tabela de mutação apontava para "o cenário de não-interferência", que não existia entre `[0]` e `[17]`.

**Por que isso importa, medido.** `core.hooksPath` é absoluto e comum, então este hook passa a rodar em **todo** checkout de **todo** worktree dos cinco consumidores: medi quatro invocações numa fixture, duas de `worktree add` e duas de `git checkout` no tronco, estas com `prev` igual a um sha real. O teste de `$1` é justamente a peça que separa criação de worktree de checkout comum, e ela ficaria sem acusador declarado.

**A correção.** Nasce o cenário `[17]`, "não-interferência", com duas metades: um `git checkout -b outra` seguido de `git checkout main` no tronco não muda o HEAD de forma inesperada e não faz nascer branch `wt/*` nenhuma; e um `git checkout --detach` **deliberado** dentro de uma worktree do território permanece destacado, porque o conserto é para a criação da worktree e desfazer uma escolha explícita do operador depois é outra coisa. A segunda metade é o que a mutação da linha 2 derruba, medido: com o teste de `$1` fora, a worktree deliberadamente destacada termina em `wt/deliberada`.

O gate cresceu mais duas vezes durante a implementação, e as duas por exigência de invariante e não por escopo: o `[18]` é o teste de propriedade que a invariante 5 pede sobre o saneador e a cascata (entrada gerada, e o desfecho nunca é "destacado com rc 0"), e o `[19]` fecha um falso-verde que eu introduzira e que nenhuma revisão tinha visto — está em 14.17. O contador de controle é o `[20]` e o denominador declarado é **21**.

### 14.3 O cenário [11] ganha poder discriminante

`git branch -m` levar a worktree junto é propriedade pura do git, e nenhuma peça desta onda participa dessa operação — um cenário que só afirmasse isso não poderia falhar contra implementação alguma. O `[11]` passa a renomear a branch **e depois rodar a triagem**, afirmando que a worktree continua classificada corretamente sob o nome novo. Aí sim um sidecar chaveado por nome de branch, ou por caminho de worktree, reprova.

### 14.4 O cenário [5] afirma o comportamento do hook, não o HEAD final

O estado declarado de `[5]` não reproduzia: **antes** de qualquer hook, `worktree add <dir> -b feat/x` já deixa a worktree em `feat/x` e `worktree add <dir> HEAD` já a deixa destacada, então "produzem desfechos diferentes" era verde na fase vermelha. O `[5]` passa a afirmar o que o HOOK faz em cada caminho, por contagem de branches `wt/*`: **zero** no caminho com `-b`, **exatamente uma** no caminho destacado. Medido, é isso que a mutação para `$3` derruba — com `$3` como discriminador o hook age também na criação com `-b`.

### 14.5 A triagem barata do doctor tem orçamento de tempo, porque ela não é barata a frio

A especificação tirou o `clean -ndX` do caminho quente com razão e herdou sem medir a premissa de que `status --porcelain` é barato. Medição da revisão, que eu adoto: em `axis-go-cloud`, com `.git` de 2,3 GB, `status --porcelain` mais `symbolic-ref` sobre 10 worktrees levou **57,9 s** na primeira passada e **87 ms** na segunda — cerca de 5,8 s por worktree a frio, ou perto de oito minutos para as 86. Um piloto que rodasse o doctor duas vezes mediria os 87 ms e aprovaria.

A correção é estrutural e não de aviso: a triagem do doctor tem **teto de tempo** (`FORGE_WT_TRIAGE_BUDGET_S`, default 5 s) e publica **quantas ficaram de fora** em vez de fingir que examinou tudo. A DoD item 8 passa a exigir que a medição do piloto seja **a frio**, em clone descartável recém-criado, e que o número publicado seja o da primeira passada.

### 14.6 O modo barato não inventa veredito: ele usa o terceiro estado

Sem o predicado de arquivo ignorado não existe "mergeada e limpa" — existe "mergeada, de índice limpo, e eu não olhei o disco". No modo barato, esse caso recebe `nao-verificado` com a razão escrita, e não `mergeada-limpa`. Isso preserva os **seis** nomes de classe do contrato e evita reintroduzir, na forma barata, exatamente o colapso que a face 3 existe para combater.

### 14.7 O `post-merge` NÃO é refatorado nesta onda

**O que a especificação dizia.** O `post-merge` passaria a consumir `worktree-classify.sh` em vez das próprias cópias dos predicados, com comportamento inalterado.

**Por que a implementação decidiu diferente.** A regra de delegação deste harness, imposta pelo `w147`, é que chamar algo que não existe é ERRO quando o diretório que hospeda o alvo existe. Fazer o `post-merge` delegar a `lib/worktree-classify.sh` criaria um **modo de falha novo** em cinco consumidores instalados: todo repositório que receba o hook novo sem receber a lib passa a ter o `post-merge` falhando, e `hooks/` e `scripts/` são sobrescritos por caminhos diferentes do overlay do update. O ganho — fonte única de predicados que, por construção desta onda, não mudam de comportamento — não paga esse risco.

**O que fecha a preocupação legítima da especificação** ("o harness não passa a ter duas definições de limpa") é o cenário `[15]`, que afirma a **equivalência medida**: a lib e o `post-merge` classificam o mesmo laboratório do mesmo jeito, sobre as duas propriedades que importam (arquivo ignorado presente, e índice sujo). Uma divergência futura entre as duas implementações fica vermelha. A extração continua desejável e vira item de ledger, não escopo desta onda. O item 6 da DoD é cumprido com o `w153[72]` verde e sem edição. O arquivo do `post-merge` não fica byte a byte como estava — a revisão adversarial encontrou um efeito de população que exige uma linha ali, e ela está na seção 14.18.

### 14.8 D6: são SEIS desfechos, não cinco

A prosa da D6 dizia "cinco" e a tabela logo abaixo trazia seis linhas. O contrato publicado é de **seis** nomes: `viva`, `destacada`, `mergeada-limpa`, `mergeada-com-ignorados`, `mergeada-suja` e `nao-verificado`.

### 14.9 O terceiro estado do hook diz que a worktree existe

O `exit 3` do esgotamento faz o `git worktree add` devolver rc não zero com a worktree **existindo em disco**. A mensagem passa a dizer em letra que a worktree existe, onde ela está, e que o código de saída não desfaz nada — porque todo chamador com `set -e` lê rc não zero como "o comando falhou". O cenário `[9]` afirma as três coisas, **e o rc**: a primeira versão do cenário afirmava só a mensagem, e a prova de mutação mostrou que ela ficava verde contra um hook que imprimisse o aviso e saísse 0. O defeito era do gate, e foi corrigido antes de a linha da matriz ser declarada.

### 14.10 `GIT_DIR != GIT_COMMON_DIR` só discrimina quando os dois lados usam o mesmo primitivo

Medido no tronco: `git rev-parse --absolute-git-dir` devolve caminho absoluto e `git rev-parse --git-common-dir` devolve `.git` **relativo**, de modo que a comparação ingênua diz "diferente" também no tronco. O hook resolve os dois lados por `cd … && pwd -P` antes de comparar. Pelo mesmo motivo, o tronco é a **primeira entrada** de `git worktree list --porcelain`, e nunca `dirname` do diretório comum.

### 14.11 O aviso da D4 é restrito à árvore do tronco

Fora do território mas **dentro** da árvore do tronco: aviso em `stderr`. Fora da árvore do tronco: silêncio absoluto. É o que mantém `red-replay.mjs` — que cria com `--detach` em `tmpdir()` — livre de ruído que reapareceria dentro de qualquer mensagem de erro do replay, sem isenção por variável de ambiente nem por prefixo de nome, que a especificação descartou com razão.

### 14.12 O bit de execução dos hooks

`template/.forge/hooks/git/*` está `-rwxr-xr-x`, e o hook novo é entregue com o mesmo modo. Um `post-checkout` sem `+x` é silenciosamente ignorado pelo git e deixaria a onda inteira inerte no consumidor com todos os gates verdes; o `w210` instala o hook por cópia e o exercita pelo `git` real, de modo que um arquivo inerte reprova em `[1]`.

### 14.13 O censo da seção 1.2 é testemunha de data e já envelheceu

A revisão mediu, menos de um dia depois, que `Axis.PadSimulator` tem 28 entradas e **zero** destacadas, e que `.forge/worktrees/audit-ldg-0489` — uma das três árvores sujas que ancoram a face 2 — não existe mais. Nenhum gate depende desses números, e a especificação foi correta em não os usar; a tabela de 1.2 e a prosa da seção 6 não devem ser recitadas como estado atual.

### 14.14 Varredura de impacto, feita e conferida

Além dos gates que a seção 11 nomeia, conferi que `tests/w107-red-replay-gate.sh` e `tests/w207-ledger-render-write-port-gate.sh` são os únicos gates que criam worktree **destacada**, e que ambos criam fora de `.forge/worktrees/` com stderr redirecionado — a D4 os mantém verdes, e ambos foram rodados e estão verdes. O critério certo, registrado para a próxima onda, não é "gates que citam `hooks/git`": é **"gates cuja fixture instala o harness e depois chama `git worktree add`"**. Conferi também que nenhum markdown de comando de `template/.forge/commands/` cria worktree (a varredura por `worktree add` ali é vazia; quem ensina o comando são quatro agents, e os quatro já usam `-b`), de modo que esta onda **não** toca `commands/` e **não** exige `npm run build:plugin`.

O `README.md` é editado junto, por exigência do `w210` — o `w200` afirma o inventário e o badge de gates contra a árvore real, e ambos mudaram: `scripts/` de 137 para 138 (a lib nova) e o badge de 133 para 134 (o gate novo).

### 14.15 A matriz de mutação, como ela ficou depois de executada

Dez linhas, cada uma com controle (gate verde antes), efeito (o gate acusando), recontrole (verde depois) e restauração conferida por `sha256`. A prova roda sobre uma **cópia** de `template/`, `bin/` e `tests/` sob `$TMPDIR`: nenhum arquivo rastreado do repositório é mutado, que é a metade de LDG-0175 que se aplica a quem executa a prova. A troca é literal, por `python3`, com recusa explícita quando o trecho não é encontrado ou é ambíguo — nunca `perl -0pi -e` com `$` do lado direito, que é a armadilha do LDG-0164.

| # | Propriedade sob prova | Mutação | Cenário que acusou, medido |
|---|---|---|---|
| 1 | o discriminador de destacado é `symbolic-ref`, nunca `$3` | trocar o teste de destacado pelo teste de `$3` | `[3]` morde primeiro (o hook passa a mexer em worktree que já tinha branch); `[5]` afirma a mesma propriedade pela contagem |
| 2 | o hook só age na CRIAÇÃO de worktree | remover o teste de `$1` igual a quarenta zeros | `[17]` — o `--detach` deliberado dentro do território termina em `wt/deliberada` |
| 3 | o escopo do conserto é `.forge/worktrees/` | remover o ramo de aviso e o teste de prefixo | `[4]` — o conserto age fora do território |
| 4 | a reentrância é contida pelas duas condições JUNTAS | remover o teste de `$1` **e** o de `symbolic-ref` | `[0]` morde primeiro, porque o próprio `worktree add -b` do controle passa a devolver rc não zero; o contrafactual de `[10]` foi medido à parte, na mesma fixture: **uma** criação de worktree produziu **8** branches `wt/*` contra a única que a asserção aceita |
| 5 | a cascata esgotada NÃO sai 0 | trocar o `exit 3` do esgotamento por `exit 0` | `[9]` — e esta linha achou um defeito no próprio gate, que afirmava só a mensagem e ficava verde; o `[9]` passou a afirmar o rc |
| 6 | a triagem distingue arquivo ignorado de árvore limpa | remover o predicado `clean -ndX` da classificação | `[12]` — a worktree com ignorados cai em `mergeada-limpa` |
| 7 | a triagem tem terceiro estado de ref | colapsar `indeterminado` em `nao` | `[13]` — a worktree em disputa recebe o veredito `viva` |
| 8 | a triagem NÃO executa o que propõe | trocar o `echo` do comando de remoção pela execução | `[14]` — a contagem de worktrees cai de 5 para 4 |
| 9 | sem ref de integração, nada vira "mergeada" | trocar as sentinelas que não resolvem por `HEAD HEAD` | `[19]` — a worktree viva de um repositório sem `develop`/`main`/`master` vira mergeada, e a triagem passa a propor remoção |
| 10 | o `post-merge` continua PROPONDO no default | trocar a condição do opt-in por `true` | `w153[72]` — gate existente, rodado sem edição |

### 14.16 Piloto medido em consumidor real, e o que ele mostrou

Leitura apenas, sem escrita nenhuma nos consumidores. `worktree-reconcile.sh --triage --barato` sobre os dois maiores, com cache já aquecido pelas leituras da própria sessão:

- **`Axis.PadSimulator`**: 33 entradas, 9 s. Classificação: 19 vivas, 5 mergeadas e sujas, 9 não verificadas, **zero** destacadas.
- **`axis-go-cloud`**: 86 entradas, 17 s. Classificação: 78 vivas, **6 destacadas**, 2 não verificadas.

As seis destacadas do `axis-go-cloud` são exatamente as que a seção 1.2 mediu, e são a população que esta onda **não** conserta retroativamente — elas aparecem na triagem com o comando de conserto, e o conserto é ato do operador. Os 17 s a quente sobre 86 worktrees confirmam a decisão do teto de tempo no doctor: com a medição a frio da revisão (5,8 s por worktree em `axis-go-cloud`), a mesma varredura sem teto passaria de oito minutos dentro de um comando que o operador roda para ter uma resposta rápida.

Uma leitura que a triagem entrega e o censo da especificação não tinha: no `Axis.PadSimulator` **nenhuma** worktree é destacada hoje, e cinco estão mergeadas e sujas. A face 2 — trabalho não commitado — é a que sobra ali depois desta onda, e é a que nenhuma peça daqui resolve.

### 14.17 Um falso-verde que a implementação introduziu, achou e fechou

A primeira versão de `forge_wt_default_refs` respondia `HEAD HEAD` quando não encontrava `develop`, `main` nem `master`. Com `HEAD` dos dois lados, **toda** worktree é ancestral de si mesma, **toda** worktree é classificada como mergeada, e a triagem passaria a propor `git worktree remove` de árvore viva com rc 0 — exatamente o falso-verde que a classe `nao-verificado` existe para impedir, entrando pela porta que ninguém olha. O caso não é hipotético para quem usa nomes de tronco fora dos três: um repositório com tronco `trunk` ou `production` cai nele inteiro.

A correção é um par de sentinelas que não resolvem em ref nenhuma, de modo que as duas leituras devolvem "não resolve", o estado é `indeterminado` e a classe é `nao-verificado`. O cenário `[19]` afirma isso sobre uma fixture cujo tronco se chama `trabalho`, e afirma também que a triagem **não propõe remoção** ali. A décima linha da matriz de mutação é a prova de que ele discrimina.

Registro o achado porque ele é a régua honesta desta onda: a revisão da especificação encontrou dois defeitos de prova, a implementação encontrou um terceiro defeito no próprio gate (o `[9]`, que afirmava a mensagem e não o rc) e um quarto no código novo (este), e os quatro só apareceram porque alguém rodou a mutação em vez de descrevê-la.

### 14.18 Correções da revisão adversarial (2026-09-08, segunda rodada)

Esta subseção tem precedência sobre tudo que a contradiz acima, inclusive sobre a 14.7. Cada item foi reproduzido com comando próprio antes de ser corrigido, e cada asserção nova teve a mutação que ela alega detectar executada com controle, efeito, recontrole e `sha256` conferido.

**O achado alto: a onda ampliava a população que o `post-merge` remove.** O `post-merge` nunca tocou worktree destacada, porque a linha 87 lê `rev-parse --abbrev-ref HEAD` e a 88 descarta quem devolve literalmente `HEAD`. Worktree de diagnóstico era imune por ESTRUTURA, não por decisão. Ao dar branch a toda worktree do território, o `post-checkout` desarmava esse filtro: medido em duas fixtures idênticas que diferiam apenas pela presença do hook, com `FORGE_WORKTREE_AUTOCLEAN=1`, o controle terminou em `removidas: 0` com o diretório intacto e o efeito em `Deleted branch wt/diag-x` e `removidas: 1`, com o diretório apagado; no default, a mesma árvore passou de zero para uma PROPOSTA, e a mensagem que a propõe anuncia o opt-in ao operador. Uma onda cujo propósito declarado é não perder trabalho não pode alargar o alcance da única peça do harness que destrói.

**A correção, e por que ela é subtrativa.** O `post-merge` ganha `case "$branch" in wt/*) continue ;; esac` logo depois de resolver a branch. `wt/` é o namespace desta onda: ele marca exatamente a worktree que teria nascido destacada, e devolvê-la à imunidade que ela tinha restaura o estado de antes, nunca o amplia. Renomeada para fora de `wt/` pelo operador, ela volta à população — que é precisamente o que acontecia antes, quando quem quisesse a worktree na limpeza tinha de nomeá-la à mão. Descartei isentar por variável de ambiente (o consumidor com cópia antiga não a passaria, que é o padrão da issue #123) e descartei registrar a lista de branches criadas em arquivo lateral (o rename que o dono pediu quebraria a chave no instante seguinte, medido em 1.9). O cenário `[20]` mede controle e efeito lado a lado com o opt-in LIGADO, que é o pior caso, e ele tem três guardas de vacuidade: o controle precisa remover ao menos uma worktree, a fixture com hook precisa ter de fato consertado a destacada, e a worktree mergeada e NOMEADA precisa continuar sendo removida — senão a correção teria desligado a limpeza em vez de contê-la.

**`--triage --barato` afirmava sobre predicado que não executou.** A classe `nao-verificado` tem causas diferentes, e o ramo de impressão as distinguia pelo MODO. No modo barato a divergência de refs recebia a explicação da omissão do predicado caro, e o operador lia "mergeada e de índice limpo" sobre uma worktree cujo estado de merge é indeterminado e cujo `git status` nunca chegou a rodar — as duas metades falsas, dentro do terceiro estado que esta triagem existe para proteger. Nasce `forge_wt_naoverificado_causa`, que responde `caminho-inexistente`, `refs-nao-decidem`, `predicado-omitido` ou `desconhecida`, e a explicação passa a sair da causa. O cenário `[21]` afirma as duas causas na mesma saída, lidas por bloco.

**A worktree destacada COM trabalho não commitado ficava invisível.** `forge_wt_classify` decide `destacada` antes de qualquer predicado de sujeira, e o ramo de impressão da triagem só dizia "sem branch". É a população onde a perda de dado de fato acontece, e é a que esta onda não conserta retroativamente. A triagem passa a rodar `forge_wt_tracked_dirty` também no ramo `destacada`, listar as linhas sujas e imprimir o resgate da D5 — sem criar classe nova, porque os seis nomes são contrato publicado. O cenário `[22]` afirma a classe, o nome do arquivo, a frase que nomeia o trabalho não commitado e a presença do resgate.

**O cenário `[6]` não media o saneamento que nomeia.** Suas duas asserções — HEAD atacado e nome válido — são satisfeitas pela cascata sozinha, porque o segundo candidato é `wt/<slug>-<sha7>` e ali `.lock` deixa de ser sufixo do componente. Apagar `slug="${slug%.lock}"` deixava os 21 cenários verdes. O `[6]` passa a recusar o sufixo de commit no nome produzido, que é o discriminador entre "resolveu por saneamento" e "resolveu por cascata".

**O controle de instrumento `[0]` exercitava o alvo.** A `mkfx` instala o `post-checkout` em `core.hooksPath` antes de o `[0]` rodar `git worktree add -b ctl`, de modo que qualquer defeito do hook derrubava o controle imprimindo o diagnóstico trocado — "o instrumento está quebrado, não o alvo". O controle passa a rodar com `core.hooksPath` apontando para diretório vazio, e o `[0]` ganha a asserção do bit de execução do hook canônico, que nenhum cenário fazia: um `post-checkout` sem `+x` é ignorado em silêncio pelo git e deixaria a onda inteira inerte no consumidor com todos os gates verdes.

**Os dois bloqueadores da revisão da especificação já estavam fechados, e eu conferi antes de mexer.** A guarda de recursão por variável de ambiente não existe no hook (`grep` por variável de guarda: zero ocorrências) e a 14.1 já registra por que ela seria código morto; o cenário de não-interferência existe e é o `[17]`, com o `--detach` deliberado que a 14.2 descreve. Nenhum dos dois foi reaberto.

**O denominador.** Os cenários vão de `[0]` a `[23]`, e o contador de controle é o `[23]`: **24** declarados. As entradas anteriores desta seção que dizem 18 ou 21 descrevem estados anteriores do gate.

**Matriz de mutação desta rodada**, sobre cópia de `template/` e `tests/` em `$TMPDIR`, troca literal por `python3` com recusa quando o trecho não é único:

| # | Propriedade sob prova | Mutação | Cenário que acusou, medido |
|---|---|---|---|
| 11 | a onda não amplia a população removida pelo `post-merge` | remover a isenção `wt/*` do `post-merge` | `[20]` — "com o hook o post-merge removeu 2 worktree(s) contra 1 sem ele" |
| 12 | o `[6]` mede o saneador, não a cascata | remover `slug="${slug%.lock}"` | `[6]` — o nome produzido passou a carregar o sufixo de commit |
| 13 | o controle `[0]` é independente do alvo | remover as duas condições de entrada do hook | `[0]` passa (o controle roda sem o hook) e quem acusa é `[3]`, com o diagnóstico certo — antes o `[0]` mordia primeiro afirmando que o instrumento estava quebrado |
| 14 | a causa do terceiro estado não se deriva do modo | fazer `forge_wt_naoverificado_causa` deixar de reportar `refs-nao-decidem` | `[21]` — a triagem voltou a afirmar "de índice limpo" sobre estado indeterminado |
| 15 | a destacada não esconde trabalho não commitado | remover o ramo de sujeira do desfecho `destacada` | `[22]` — o arquivo não commitado deixou de ser nomeado |
| 16 | o hook é entregue executável | `chmod -x` na cópia do hook | `[0]` — "o git ignora em silêncio um hook sem `+x`" |

**O que ficou de fora, com a medição.** O `w200[6]` está vermelho na árvore: o badge diz 134 gates e `ls tests/*-gate.sh` conta 135, porque quatro gates ainda não rastreados nasceram depois da conta. O `README.md` é ponto de colisão entre as ondas em voo e o número correto é derivado da árvore no instante do fechamento, então ele não é editado aqui. E a contagem por classe do `doctor` continua somando a destacada-e-suja em `destacada=`, e não em `mergeada-suja=`: o `doctor.sh` está fora do escopo desta correção, e a visibilidade da face 2 foi restaurada onde o operador vai lê-la, que é a triagem completa.
