# Onda C — liaison: transporte e configuração (especificação implementável)

Autor: especificador da Onda C. Data: 2026-09-07 (revisão 2, respondendo ao veredito da revisão 1 — ver §11). Base medida: `develop` em `3bb67f5` (`git -C . rev-parse --short HEAD` e `git -C . rev-parse --short origin/develop` devolvem os dois `3bb67f5`), `package.json` em `0.14.0`.

Escopo: issue **#123** (`fs-union` como `kind` de primeira classe — o ponto fixo que alcança worktree de branch velha), issue **#101** (`scripts` é sobrescrito pelo `forge update`, em silêncio quando não há `machinery.lock`) e **LDG-0100** (`check-liaison-acks.sh` não lê o hub para transporte `git`/`gh`). O critério que junta os três é o do plano-mestre: os três moram na fronteira entre a **configuração** que o repositório declara e a **maquinaria** que a executa, e os três falham porque alguém decidiu com base numa lista literal de nomes em vez de uma propriedade.

Esta especificação é para ser executada, não lida. Nenhum gate da suíte foi executado na sua elaboração — `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio.

**Regra de método, e ela é a invariante 19 do plano-mestre.** A especificação declara a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir; quem escolhe o primitivo é o implementador, que executa, e ele tem a obrigação de provar que o primitivo discrimina — com controle e recontrole. Comando exato só permanece aqui quando veio de uma execução minha, com a saída colada. A varredura que aplica essa regra a esta spec inteira está em §10.

**Regra de número, e ela vale sem exceção nesta revisão.** Toda afirmação numérica deste documento vem acompanhada do comando que a produziu, colado ao lado dela. E todo número que conta coisa da árvore — arquivos, worktrees, gates, declarações, entradas de lock — é **testemunha de data**, nunca critério: a asserção correspondente do gate é sempre propriedade mais piso, com denominador derivado em execução. Número sem comando citado foi removido desta revisão; não existe terceira saída.

**Aviso operacional que precede qualquer reprodução.** Toda bancada acontece em `$TMPDIR` (nesta rodada, `${TMPDIR}/ondaC-rev2/`), com o `cwd` **dentro da fixture**, nunca a partir da árvore do `forge-harness`. Nenhuma das medições abaixo escreveu em `.forge/HANDOFF.md`, `.forge/ledger/`, `.forge/liaison/` ou `template/` deste repositório, nem em repositório consumidor nenhum — tudo que tocou `~/Documents/projects/*` foi leitura.

---

## 0. Resumo do que muda

| Peça | Arquivo | Natureza |
|---|---|---|
| `fs-union` entra em `TRANSPORT_KINDS`; nasce a tabela `DIRECT_HUB_LAYOUT` | `template/.forge/scripts/lib/liaison-config.mjs` (linha 27) | contrato publicado ampliado (aditivo) |
| `validateTransport` passa a exigir `path` de `fs-union` como já exige de `fs` | `template/.forge/scripts/lib/liaison-config.mjs` (linha 90) | correção de validação — ver §1.6 C7 |
| Backend `fs-union` — alias de `fs`, existe para ser o **segundo** elo do ponto fixo | `template/.forge/scripts/lib/transports/fs-union.sh` (novo) | maquinaria nova, distribuída |
| Leitura de hub por **layout declarado**, não por lista literal de nomes; terceiro estado `NÃO VERIFICADO` com rc 2; contador de canais por categoria; regra de precedência multi-canal | `template/.forge/scripts/check-liaison-acks.sh` | contrato de saída ampliado (rc 2 novo) |
| Lista de `--kind` nas duas mensagens de uso | `template/.forge/scripts/liaison-ops.sh` (linhas 36 e 1194) | texto de ajuda |
| `enum` do `kind`, descrição do backend **e descrição de `path`** | `template/.forge/schemas/liaison-config.schema.json` | contrato publicado (documental) |
| Galho próprio para rc 2 do `check-liaison-acks.sh` — o terceiro estado deixa de ser renderizado com a frase do segundo | `template/.forge/hooks/git/pre-push` (linhas 116-121) | canal de entrega — ver §1.6 C8 |
| `fs-union` documentado no comando | `template/.forge/commands/harness/liaison.md` + regeneração do plugin por `npm run build:plugin` | doc + plugin |
| `scripts/` passa a decidir por lock: preserva-e-reporta quando há deriva | `bin/forge.mjs` | mudança de comportamento do `update` |
| Sem lock: declara nominalmente em vez de agir calado; recusa (rc 5) só no caso irrecuperável | `bin/forge.mjs` | contrato de saída ampliado (rc 5 novo) |
| Rótulo do backup passa a nomear o backup **real**, nos três estados possíveis, em **todas** as quatro mensagens | `bin/forge.mjs` (linhas 189, 640, 643 e **718**) | correção de mensagem |
| Badge `gates-N passing` e contagem `scripts/ (N)` do inventário de estrutura | `README.md` (linhas 12 e 13 do bloco de estrutura) | **edição obrigatória** — `w200` afere as duas contra a árvore real, ver §7 |
| Cenário `[4]` inverte de sentido e vira `[4a]`/`[4b]` | `tests/w101-update-preserve-gate.sh` | edição obrigatória, ver §7 |
| Gate do ponto fixo e do leitor de hub | `tests/w<NNN>-liaison-transport-fixpoint-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Gate da preservação de maquinaria no update | `tests/w<NNN>-update-machinery-preserve-gate.sh` (novo) | ordinal alocado pelo orquestrador |

Ordinais, testemunha de data: o máximo publicado hoje é **w207**, medido com `for b in origin/develop origin/main HEAD; do git ls-tree -r --name-only "$b" tests/ | grep -oE '/w[0-9]+' | sed 's|/w||' | sort -n | tail -1; done` → `207, 207, 207`. As branches remotas em voo, medidas com `git branch -r --sort=-committerdate`, são `origin/wip/upgrade-safety-ldg-0131` e `origin/wip/deepspec-run-manifest-ldg-0165`. Os dois ordinais desta onda **não são alocados aqui**: a invariante 10 atribui a alocação ao orquestrador, contra `origin/*` **e** contra as branches em voo.

Nenhum literal desta especificação entra numa asserção de gate contando arquivos rastreados, gates em `tests/`, entradas de `machinery.lock` ou nodes de grafo. Onde um número aparece numa asserção, ele é ou o denominador de cenários do próprio gate (a exceção legítima da invariante 14) ou um **piso** acompanhado da propriedade que o sustenta. As duas contagens do `README.md` são a exceção que o `w200` já governa: elas são declaradas à mão por desenho, e existe um gate cuja função é reprovar quando envelhecem.

---

## 1. ITEM 1 — issue #123: o ponto fixo é a configuração

### 1.1 O aviso do campo, conferido antes de qualquer coisa — e ele está meio certo

O plano-mestre manda conferir, antes de tudo, o aviso de que a 0.14.0 remove o `kind` e trava o push de quem o adotou. Montei um consumidor de bancada, adotei `fs-union` nele exatamente como o campo adotou (acrescentando o nome a `TRANSPORT_KINDS` e criando `lib/transports/fs-union.sh`), declarei um canal com `kind: "fs-union"` e rodei o `update` da 0.14.0.

**A primeira metade do aviso é verdadeira, e é pior do que ele diz.** A árvore que só rodou `init` não tem `machinery.lock`, então o `update` sobrescreve `scripts/lib/liaison-config.mjs`, apaga `fs-union` da lista, e não menciona o arquivo em nenhuma linha do relatório. A medição está em §2.1, com o comando; ela é a mesma fixture, e o que ela mostra em números é: rc 0, três consertos destruídos, zero linhas citando qualquer um deles.

O ponto que a fixture acrescenta ao aviso é que o backend `fs-union.sh` **sobrevive**, porque o overlay nunca deleta — de modo que a árvore fica num estado **incoerente por construção**: o backend existe e a lista de kinds não o conhece.

**A segunda metade do aviso não se reproduz nesta maquinaria.** O campo afirma que, como `check-liaison-acks.sh` é gate de `pre-push`, um comando de rotina trava todo push do repositório. Medi, na mesma fixture, imediatamente depois do update:

```
=== DEPOIS: check-liaison-acks.sh
OK liaison-acks — 0 thread(s) deste repositório examinada(s), nenhum ack pendente
OK liaison-trust — 0 mensagem(ns) com procedência coerente
rc_acks=0

=== DEPOIS: sync
transporte inválido em liaison.yaml: kind inválido: fs-union (use manual|fs|git|gh)
rc_sync=1
```

O `sync` reprova; o gate de push **aprova**. E aprova porque `check-liaison-acks.sh` nunca chama `validateTransport` — ele testa `transport.kind === 'fs' || transport.kind === 'manual'` (linha 179, conferida com `awk 'NR>=170 && NR<=195' template/.forge/scripts/check-liaison-acks.sh`) e, para qualquer outro nome, cai no fallback da réplica local sem dizer nada.

A causa da divergência está no código do campo, não no nosso: o `axis-device-platform` escreveu uma lib local, `lib/liaison-hub-path.sh`, que **não existe no template** (`ls template/.forge/scripts/lib/liaison-hub-path.sh` → *No such file or directory*), e é ela que compara o `kind` com um literal e derruba o `check-liaison-acks.sh` de lá. Quando o `update` sobrescrever o `check-liaison-acks.sh` deles pelo nosso, a lib local deixa de ser chamada e o push volta a passar — **verde, sobre um canal cujo hub ninguém mais lê**.

**Registro isto como a correção mais importante desta seção:** o dano que a 0.14.0 causa a quem adotou `fs-union` não é bloqueio de push, é o oposto — é falso-verde no gate de ack, exatamente a classe da issue #84 que o cabeçalho de `check-liaison-acks.sh` diz existir para impedir. Um bloqueio de push é ruidoso e se resolve em minutos; um gate que aprova sem ter lido o hub some por semanas.

### 1.2 O falso-verde, medido com controle e recontrole

Na mesma fixture, com `enforce: block`, pus **uma** mensagem no hub que exige ack deste repositório e que a réplica local não tem — o cenário do #84 —, e alternei apenas a linha do `kind`:

| `kind` no `liaison.yaml` | veredito de `check-liaison-acks.sh` | rc |
|---|---|---|
| `fs-union` | `OK liaison-acks — 0 thread(s) deste repositório examinada(s), nenhum ack pendente` | 0 |
| `fs` | `FAIL liaison-acks — 1 thread(s) examinada(s), 1 mensagem(ns) exigem ack deste repositório (enforce: block): canal-x/t1: peer-0001 [thread-open] de peer — contrato mudou` | 1 |
| `fs-union` (recontrole, restaurado por `cp` e conferido com `cmp -s`) | `OK liaison-acks — 0 thread(s) ... nenhum ack pendente` | 0 |

Mesmo hub, mesma mensagem, mesmo script; o `kind` foi alternado por `sed -i '' 's/kind: "fs"/kind: "fs-union"/'` no `liaison.yaml` da fixture e restaurado por `cp` do original com `cmp -s` conferindo. O nome do transporte decide se a cobrança existe. É esta tabela, e não a proposta da issue, que fixa o requisito central do item: **um `kind` novo que não ensine o leitor de hub a alcançá-lo nasce cego**, e a onda estaria trocando um defeito por outro.

### 1.3 O defeito de origem, reproduzido por mim com a árvore armada de verdade

O `axis-device-platform` **está** nesta máquina, aninhado em `~/Documents/projects/axis-go-cloud/axis-device-platform` — foi por isso que ele não apareceu no primeiro censo, que só olhava o primeiro nível.

Censo do parque dele, por conteúdo e não por relatório. Comando (leitura pura; a lista de árvores é tronco mais o que `git worktree list` declara, deduplicada):

```
ADP="$HOME/Documents/projects/axis-go-cloud/axis-device-platform"
{ echo "$ADP"; git -C "$ADP" worktree list --porcelain | awk '/^worktree /{print $2}'; } | sort -u > trees.txt
while read -r t; do c="$t/.forge/scripts/lib/transports/_common.sh"; [ -f "$c" ] && shasum -a 256 "$c" | cut -c1-12; done < trees.txt | sort | uniq -c
```

Saída, testemunha de 2026-09-07:

```
árvores (tronco + worktrees, distintas) = 33
  18 40af01cfd632
  13 28a01adc11c7
armadas (carregam 28a01adc11c7) = 13
armadas QUE conhecem fs-union = 0
sem _common.sh = 2 ; sem liaison-config.mjs = 2 ; sem liaison-ops.sh = 1
```

O sha `28a01adc…` é o mesmo que a issue nomeia. Conferi o corpo com `sed -n '/_dir_push()/,/^}/p'` sobre uma das treze (`.forge/worktrees/cert-validity/.forge/scripts/lib/transports/_common.sh`, 51 linhas por `wc -l`): o `_dir_push` é o `cp` incondicional para `$hub/log/.$LIAISON_SELF.jsonl.tmp` seguido de `mv` sobre `$hub/log/$LIAISON_SELF.jsonl`, sem classificação e sem união. As outras dezoito carregam o `_common.sh` do tronco deles, que **já** une com recusa de colisão — é o conserto local que eles escreveram, não o do template. Duas árvores não têm `.forge/scripts/lib/liaison-config.mjs` e por isso não publicam.

**A asserção do gate não usa nenhum destes números.** A propriedade é *"existe em campo, hoje, pelo menos uma árvore cujo `_dir_push` sobrescreve o log do hub pelo da réplica"*, com piso um; os números acima são a testemunha de que o piso está folgado, e envelhecem sozinhos assim que uma worktree for rebaseada.

Extraí uma das treze para bancada em `$TMPDIR` e reproduzi o dano com um hub descartável de duas linhas contra uma réplica de uma linha:

```
cp -R "$ADP/.forge/worktrees/cert-validity/.forge/scripts" "$ARM/.forge/scripts"
cd "$ARM" && FORGE_ROOT="$ARM" bash .forge/scripts/liaison-ops.sh sync canal-x --push-only
```

```
=== ARM D — kind: fs, árvore ARMADA
hub antes: 2 linha(s)
OK sync — push-only via fs (log de demo publicado)
rc=0
hub depois: 1 linha(s)
demo-0002 DESAPARECEU do hub
```

Réplica com uma linha, hub com duas, `sync --push-only`, e o hub fica com uma. A palavra `OK` na saída. Nenhum aviso. É o defeito da issue, reproduzido por mim, com o arquivo real de uma worktree real.

### 1.4 O ponto fixo, medido nas duas camadas, com contrafactual e recontrole

Na **mesma** árvore armada, restaurando o hub ao estado de controle antes de cada rodada e conferindo o sha do hub depois de cada uma. Os comandos: o `kind` foi alternado por `sed -i ''` no `liaison.yaml`; a segunda camada foi exercida acrescentando `'fs-union'` a `TRANSPORT_KINDS` na cópia de bancada de `liaison-config.mjs` por `sed -i ''`, com `cmp -s` contra o original guardado antes confirmando que a mutação **não** foi fantasma (LDG-0164).

```
hub controle = 028045d992ee (2 linhas)

=== ARM T1 — kind: fs-union, árvore velha (kind desconhecido)
transporte inválido em liaison.yaml: kind inválido: fs-union (use manual|fs|git|gh)
rc=1   HUB INTACTO (028045d992ee)

=== ARM T2 — kind na lista, BACKEND ausente
mutacao aplicada (arquivo difere do original)
FAIL: backend de transporte ausente: .../arm/.forge/scripts/lib/transports/fs-union.sh
rc=1   HUB INTACTO (028045d992ee)

=== RESTAURAÇÃO + RECONTROLE — volta para kind: fs, mesma árvore armada
restauracao conferida por cmp -s
OK sync — push-only via fs (log de demo publicado)
rc=0   HUB MUDOU — dano voltou, hub com 1 linha
```

As duas camadas existem, são independentes, e cada uma sozinha basta. O recontrole prova que foi a troca do `kind` que parou o dano, e não outra coisa da bancada.

**A propriedade que torna isto um ponto fixo, e não um remendo, é a assimetria de origem:** o `liaison.yaml` é lido de `$ROOT/.forge/liaison/`, e `ROOT` ancora no checkout principal (`forge_resolve_root`), enquanto `LIBDIR` é `$SCRIPT_DIR/lib` (`liaison-ops.sh:66`), isto é, a cópia que a árvore invocadora carrega. Configuração vem do tronco; código vem da branch. E a trava **se desarma sozinha no momento certo**: quando a branch antiga for finalmente rebaseada ou mesclada sobre `develop`, a worktree passa a carregar o código que conhece `fs-union` e que já une — deixa de falhar exatamente quando deixa de ser perigosa. Nenhuma limpeza manual, nenhuma lista de árvores a consertar.

### 1.5 O que mudou desde a proposta, e isto reescreve o desenho

A issue propõe um backend `fs-union` que "resolve o `_dir_push` no tronco, não em `$LIBDIR`, e falha fechado se o `_common.sh` do tronco não estiver lá". Essa proposta foi escrita contra o `_common.sh` de 51 linhas. **Na 0.14.0 o `fs` já une**: `_dir_push` classifica o hub em `ff`/`behind`/`diverged` e os dois primeiros passam por `_dir_push_union`, que delega a `lib/liaison-push-union.mjs`; a única recusa é bifurcação real, por `detectForks`. Conferi lendo `template/.forge/scripts/lib/transports/_common.sh` (239 linhas por `wc -l`) e o módulo.

Consequência direta: **em 0.14.0 o `fs-union` não tem comportamento próprio a entregar.** O valor dele é inteiramente o de ser um nome que a árvore velha não sabe executar. Isso muda três coisas no desenho, e as três estão fechadas em §1.6: o backend vira alias em vez de segunda implementação; a ancoragem do `LIBDIR` no tronco é recusada; e o nome ganha uma dívida de nomenclatura que precisa ser dita em letra em vez de escondida.

### 1.6 Decisões de desenho — FECHADAS

**C1. `fs-union` entra como `kind` de primeira classe, e o backend é um ALIAS de `fs`, não uma segunda implementação.**

`lib/transports/fs-union.sh` faz `source` de `fs.sh` e nada mais, com um cabeçalho que declara por extenso que a razão de existir do arquivo é ser o segundo elo do ponto fixo — a camada que reprova por **ausência de arquivo** numa árvore que não conhece o nome —, e que o comportamento é, por definição, o do `fs`.

*Alternativa descartada — reimplementar a união dentro do `fs-union.sh`.* Duas cópias da mesma semântica de publicação é a definição de drift esperando acontecer, e o próprio `liaison-push-union.mjs` justifica no cabeçalho por que a noção de divergência mora num sítio só: "reimplementá-la aqui criaria uma segunda noção de divergência que divergiria da primeira em silêncio". O argumento vale igual um nível acima.

*Alternativa descartada — ancorar o `_dir_push` do backend no tronco, como a issue propõe.* Medi para quem essa ancoragem faria diferença e a resposta é: para ninguém que possa chegar até ela. A árvore velha reprova antes, em uma das duas camadas de §1.4 — ela nunca carrega `fs-union.sh`. Sobram as árvores novas, que já são seguras. E a ancoragem introduz um risco que hoje não existe: uma worktree de branch **futura** passaria a executar o `_common.sh` do tronco, mais velho que o dela, invertendo a direção do problema.

**C2. O nome permanece `fs-union`, e a dívida de nomenclatura é declarada.**

Nove declarações `kind: "fs-union"` já existem no parque, em três arquivos de configuração do `axis-device-platform` (censo em §1.7). Adotar o nome do campo dá migração zero a quem já o usa e é o comportamento que o canal deve premiar: o campo mediu, publicou e implementou; renomear cobraria dele um trabalho que só serve à nossa estética.

A dívida é real e vai no cabeçalho do backend e na descrição do schema: em 0.14.0 o nome sugere uma política de escrita que o `fs` também tem, e o que ele de fato marca é "esta configuração exige maquinaria a partir da 0.15.0". *Alternativa descartada — um nome mais honesto, como `fs-fenced`.* Custaria três reescritas de configuração no campo e não compraria propriedade nenhuma: qualquer nome desconhecido serve de trava, e a trava não depende da semântica do nome.

**C3. A leitura de hub deixa de ser uma lista literal de nomes e passa a ser uma tabela de LAYOUT exportada por `liaison-config.mjs`.**

`export const DIRECT_HUB_LAYOUT = { fs: 'channel', 'fs-union': 'channel', manual: 'flat' };` — `channel` significa `<path>/<canal>/log` e `flat` significa `<path>/log`, que são os dois layouts que a linha 184 de `check-liaison-acks.sh` já codifica hoje em `if/else`. O leitor consulta a tabela; um `kind` válido que não esteja nela é, por definição, transporte que não publica em diretório alcançável.

Isto é o que fecha a **classe** e não o caso: hoje, acrescentar um `kind` novo em `TRANSPORT_KINDS` sem editar a linha 179 produz um canal silenciosamente cego, e foi exatamente isso que a 0.14.0 fez ao adotante do `fs-union` (§1.2). Com a tabela, o `kind` novo ou tem entrada — e o hub é lido — ou não tem, e o canal sai como `NÃO VERIFICADO`. Nunca cai calado na réplica.

*Alternativa descartada — cada backend `.sh` declarar uma função `t_hub_log_dir` e o checador invocá-la.* O checador é `node` embutido em `bash` e a leitura do hub é sistema de arquivos puro; fazer um gate de `pre-push` dar `source` num backend de transporte por canal acrescenta superfície de execução de shell a um caminho que hoje só lê arquivo, para comprar informação que uma tabela de duas colunas já dá.

**C4. Os desfechos do leitor de hub, POR CANAL, com o veredito de cada um.**

Procurei ativamente o caso não coberto, como manda a invariante 17, e a enumeração abaixo é a que sobreviveu à revisão 1 — que derrubou a versão anterior por ela se dizer exaustiva sobre rc enquanto era uma tabela por canal e o script emite um rc só. A tabela agora classifica **canal**; o rc do processo sai da regra de precedência de C4-bis.

| Estado do canal | Desfecho por canal | Categoria do contador |
|---|---|---|
| transporte com layout na tabela (`fs`, `fs-union`, `manual`) e hub legível | lê o hub; cobra o que estiver pendente | lido do hub |
| transporte com layout na tabela e **sem `path`** | `HUBFAIL`, como hoje (linhas 180-183) | hub inacessível |
| transporte com layout na tabela, `path` presente e `<hub>/log` inexistente | `HUBFAIL`, como hoje (linhas 185-188) | hub inacessível |
| transporte **válido** e sem layout na tabela (`git`, `gh`) | **`NÃO VERIFICADO`** — nomeia canal e `kind`, não conta a thread como examinada | não verificado |
| transporte com `kind` NÃO-VAZIO que `validateTransport` reprova (erro de digitação, `kind` de versão futura, `kind` com maiúsculas, `kind` que é só espaço) | **`NÃO VERIFICADO`**, citando a mensagem de `validateTransport` | não verificado |
| canal **sem bloco `transport`**, ou com `transport` sem `kind`, ou com `kind` **vazio** (`getTransport` devolve `null`) | lê a réplica local, como hoje; **não reprova** | lido da réplica |
| `liaison.yaml` ausente, ou `.forge/liaison/` ausente | `OK liaison-acks — sem canal`, como hoje (linhas 68-69) | — (não há canal) |
| `liaison.yaml` presente e `self.id` ausente, com store não vazio | `FAIL liaison-trust`, como hoje (linhas 129-133) | — (recusa anterior ao laço) |
| `channels:` presente e vazio | nenhum canal declarado; o contador publica denominador zero e o veredito o diz em letra | — (denominador zero) |

O caso que quase ficou de fora, e que decide a compatibilidade da onda inteira, é o sexto: **canal sem bloco `transport` continua lendo a réplica e continua não reprovando**. Não é leniência, é honestidade — não há hub declarado a consultar, e o cabeçalho do script já diz isso desde o #84. E é medição, não escrúpulo: `tests/w113-liaison-enforce-gate.sh` e `tests/w136-session-start-liaison-acks-gate.sh` montam os canais deles com `liaison-ops.sh open` e **nunca** chamam `transport set` (`grep -c "transport set"` → `0` nos dois). Colapsar esse caso em `NÃO VERIFICADO` deixaria os dois gates vermelhos por inteiro.

A sexta linha cobre o `kind` **vazio** por medição, e a distinção entre vazio e espaço importa porque um PBT ingênuo a atropela. Medido com `node -e` sobre `template/.forge/scripts/lib/liaison-config.mjs`:

```
""        getTransport => null            | validateTransport => (nem chamado pelo sync/leitor)
"fs"      getTransport => {"kind":"fs",…} | validateTransport => []
"fs-union" getTransport => {…}            | validateTransport => ["kind inválido: fs-union (use manual|fs|git|gh)"]
" "       getTransport => {"kind":" ",…}  | validateTransport => ["kind inválido:   (use manual|fs|git|gh)"]
"FS"      getTransport => {"kind":"FS",…} | validateTransport => ["kind inválido: FS (use manual|fs|git|gh)"]
```

String vazia é falsy e para em `getTransport` (linha 77: `if (!ch || !ch.transport || !ch.transport.kind) return null`); um único espaço é truthy e chega a `validateTransport`, que o reprova. São desfechos **diferentes** e a spec precisa dizer os dois, sob pena de a PBT de §5.3 nascer vermelha contra a implementação correta.

**C4-bis. A regra de precedência entre os desfechos do processo, porque repositório multi-canal é o caso comum e não a exceção.**

Medido, testemunha de data, com `awk '/^channels:/{c=1;next} c && /^  [a-z0-9][a-z0-9-]*:$/{n++} END{print n+0}'` sobre o `liaison.yaml` de cada consumidor: `axis-go-cloud` 3 canais, `axis-fare-validator` 3, `axis-device-platform` 3, `Axis.PadSimulator` 2, `forge-harness` 1. Quatro dos cinco declaram mais de um canal, e é por isso que a tabela por canal não basta.

A precedência é **do mais forte para o mais fraco, e o mais forte é o que menos sabe**:

1. **`HUBFAIL` (rc 1)** vence tudo. Um hub declarado e inalcançável significa que a réplica local não é fonte confiável para *aquele* canal, e o script já trata isso como recusa epistêmica incondicional (comentário em `check-liaison-acks.sh:245-247`, `case` em 248-255). Continua sendo o primeiro a sair.
2. **Ack pendente em `enforce: block` (rc 1)** vem em seguida. É dívida concreta, nomeada, com o `<canal>/<thread>: <msg_id>` que o operador precisa ver.
3. **`NÃO VERIFICADO` (rc 2)** é o último. Ele é a recusa mais fraca das três porque não afirma que existe dívida — afirma que não olhou.

O argumento que sustenta essa ordem: **os três desfechos bloqueiam o push do mesmo jeito, então a precedência não decide se o operador é interrompido, decide qual frase ele lê primeiro.** E a frase que ele precisa ler primeiro é a da dívida concreta, que ele consegue resolver hoje, e não a do canal que a onda decidiu não implementar. Um repositório com um canal `git` (rc 2) e um canal `fs` com ack pendente (rc 1) sai **rc 1**, com a cobrança do `fs` no corpo — e o `NÃO VERIFICADO` do `git` sai na mesma saída, numa linha própria, nunca suprimido. Nenhum estado desaparece; o que a precedência escolhe é o código do processo.

*Alternativa descartada — rc 2 vencer rc 1.* Faria um canal `git` declarado uma vez esconder, por tempo indeterminado, toda cobrança de ack real do repositório inteiro. É trocar o falso-verde de hoje por um falso-cinza, e a invariante 2 pede três estados distintos, não uma hierarquia que engole os outros dois.

**O que acontece com os contadores no caminho `HUBFAIL`, dito em letra porque a revisão 1 mostrou que a versão anterior não fechava.** Medi que hoje o caminho `HUBFAIL` faz `return` **antes** da linha `SCOPE` — `check-liaison-acks.sh:233-236` escreve `['HUBFAIL'].concat(hubFail)` e retorna, e a linha 240 (`SCOPE <scanned>`) fica inalcançável. Bancada com dois canais, um alcançável e um não:

```
FAIL liaison-acks — hub inacessível para pelo menos um canal; a réplica local não é fonte confiável de acks pendentes:
  canal-a: hub inacessível em '.../hub/canal-a/log' (transporte fs) — probe: liaison-ops.sh transport probe canal-a
  canal-b: hub inacessível em '.../hub-que-nao-existe/canal-b/log' (transporte fs) — probe: ...
rc=1
linhas com "thread(s)" na saída = 0

=== RECONTROLE: os dois hubs alcançáveis
OK liaison-acks — 0 thread(s) deste repositório examinada(s), nenhum ack pendente
rc=0
linhas com "thread(s)" na saída = 1
```

A decisão é: **os quatro contadores de canal saem TAMBÉM no caminho `HUBFAIL`**, porque é justamente ali que o operador mais precisa saber quantos canais o script chegou a classificar. Isso muda o caminho `HUBFAIL` de "retorna antes de contar" para "conta e retorna", e o gate mede exatamente essa diferença em `[13]`. A linha `SCOPE <threads>` continua **fora** desse caminho, porque nele não houve varredura de thread a declarar — a promessa de §5.2 é sobre os contadores de **canal**, e a redação dela foi corrigida nesta revisão para dizer isso.

**C5. `NÃO VERIFICADO` sai por rc 2, e o vocabulário é o que o repositório já usa.**

Três estados, três códigos, que é a invariante 2: `0` examinei e está limpo (ou `warn`), `1` encontrei violação, `2` não consegui verificar. O token `NÃO VERIFICADO` não é invenção desta onda — `template/.forge/hooks/git/pre-push:143` já o usa, com a mesma semântica, para o caso de `check-liaison-log-integrity.sh` ausente (`grep -n "NÃO VERIFICADO" template/.forge/hooks/git/pre-push` → linhas 143 e 181).

Conferi que o rc 2 não quebra gate nenhum, e desta vez com o universo enumerado em vez de dois nomes escolhidos. `grep -rl "check-liaison-acks" tests/` devolve dez gates: `w113`, `w135`, `w136`, `w143`, `w150`, `w151`, `w152`, `w159`, `w167`, `w191`. Destes, **cinco** substituem o script por um stub `exit 0` ou só o citam em comentário (`w135:45`, `w151:913` e `:1181`, `w152:701`, `w159:12`, `w191:56`) e portanto não afirmam rc nenhum do script real. Dos cinco restantes, `w143:285-286` captura só a saída, e `w113`, `w136`, `w150` e `w167` asseveram rc exclusivamente com `-eq 0` ou `-ne 0`. Confirmei que nenhuma asserção de rc do script usa `-eq 1`: `grep -rn -- "-eq 1 \]" tests/` devolve dez ocorrências e nenhuma delas é rc de `check-liaison-acks.sh` (`w150:193` é contador de mensagens; as demais são de `w61`, `w22`, `w106`, `w21`, `w96`, `w20` e `validators.bats`, sobre outros scripts). O `pre-push` também bloqueia por qualquer não-zero — e é exatamente esse "qualquer" que C8 conserta.

*Alternativa descartada — fazer `NÃO VERIFICADO` seguir o dial `enforce: warn|block`.* O `enforce` gradua uma dívida **social** (o ack que este repositório deve a alguém) e o script já carva as recusas **epistêmicas** para fora dele: o `trust` reprova "SEMPRE, independente de enforce" (linhas 91-93) e o hub inacessível também (comentário em 245-247, `case` em 248-255), com o argumento de que ausência de prova não vira permissão. "Não li o hub deste canal" é da segunda família, não da primeira.

**C6. A recusa é a condição de reabertura de LDG-0100, mecanizada — no repositório do ADOTANTE, e não neste.**

Hoje a condição de reabertura do LDG-0100 é uma frase — *"o primeiro canal declarado como `kind: git` ou `kind: gh` em qualquer árvore do ecossistema"* — cuja verificação depende de alguém lembrar de refazer um censo. Com C4, o primeiro canal `git` declarado **reprova o push de quem o declarou**, com uma mensagem que nomeia o item.

E aqui vai a ressalva que a revisão 1 cobrou com razão, porque a onda inteira é sobre não confiar em disciplina de gente: **a mecanização acontece no repositório do adotante, não neste.** É o push dele que passa a ser reprovado; nada nesta onda faz o `forge-harness` saber que isso aconteceu. A chegada da notícia até aqui continua dependendo de alguém abrir o item ou mandar mensagem no canal — o que a onda compra é que o adotante **não tem como não perceber**, e que a mensagem que ele lê carrega o identificador do item para citar. Fechar o segundo elo (o adotante avisar automaticamente) é trabalho de canal, e a Onda I é onde ele mora.

**C7. `validateTransport` passa a exigir `path` de `fs-union`, e isto é correção, não adição.**

A revisão 1 mostrou que a adição não era aditiva como §6 afirmava, e a medição confirma. A exigência de `path` está escrita como `if ((t.kind === 'fs' || t.kind === 'manual') && !t.path)` em `template/.forge/scripts/lib/liaison-config.mjs:90` — lista literal de nomes, exatamente a classe que a onda existe para fechar, um nível abaixo. Bancada com o template limpo, mutando **só** `TRANSPORT_KINDS` (que é tudo o que a tabela de §0 da revisão 1 listava), com `cmp -s` contra o original conferindo que a mutação não foi fantasma e com recontrole depois de restaurar:

```
=== CONTROLE (hoje): --kind fs SEM --path
transporte fs exige path                                          rc=1
=== CONTROLE (hoje): --kind fs-union (fora da lista)
kind inválido: fs-union (use manual|fs|git|gh)                    rc=1
=== MUTAÇÃO: acrescenta fs-union SÓ a TRANSPORT_KINDS
mutacao aplicada
--- --kind fs-union SEM --path
OK transport set — canal canal-x usa transporte fs-union          rc=0
--- config gravada:
    transport:
      kind: "fs-union"
--- --kind fs SEM --path (mesmo estado)
transporte fs exige path                                          rc=1
=== RESTAURAÇÃO + RECONTROLE
restaurado (cmp -s)
kind inválido: fs-union (use manual|fs|git|gh)                    rc_recontrole=1
```

Um canal `fs-union` sem `path` **passa** na validação e é **gravado** no `liaison.yaml`, enquanto o mesmo canal com `kind: "fs"` reprova. Depois, o `t_probe` de `fs.sh` — que o alias herda — exige `LIAISON_T_PATH`, de modo que a configuração inválida só falharia mais tarde e mais fundo, no `sync`, com uma mensagem que não nomeia a causa. A correção entra junto de `TRANSPORT_KINDS`, no mesmo commit, e o gate a mede em `[10]`.

A descrição de `path` no `liaison-config.schema.json` — hoje *"Obrigatório em `manual` (layout `<path>/{log,blobs}`) e em `fs` (layout `<path>/<channel>/{log,blobs}`)"*, lida do JSON por parser — passa a nomear `fs-union` também. Ela é documental, mas ficaria mentindo a partir desta onda.

**C8. O `pre-push` ganha galho próprio para rc 2, porque hoje o terceiro estado chega ao operador com a frase do segundo.**

Medi em `template/.forge/hooks/git/pre-push:116-121`: qualquer rc não-zero de `check-liaison-acks.sh` cai num único `if !`, e a mensagem é sempre a de ack pendente. Bancada com um repositório git mínimo e o script substituído por stub, controle, contrafactual e recontrole:

```
=== CONTRAFACTUAL 1: acks sai 1
rc=1   pre-push BLOQUEADO: liaison — ack pendente (rule conventions/liaison-protocol.md)
=== CONTRAFACTUAL 2: acks sai 2 (terceiro estado)
rc=1   pre-push BLOQUEADO: liaison — ack pendente (rule conventions/liaison-protocol.md)
=== RECONTROLE: acks sai 0
rc=0
```

Frase idêntica para os dois estados, e o rc do próprio hook colapsa em 1. A onda criaria o terceiro estado e o canal de entrega o devolveria ao segundo, que é literalmente a invariante 2 do plano-mestre.

A decisão é **dar galho próprio ao rc 2**, e não registrar que a mensagem genérica basta. O argumento: a mensagem de ack pendente manda o operador procurar uma dívida que não existe, e ele vai procurar — a única saída dele é rodar o check à mão e ler a saída, que é exatamente o trabalho que o hook existe para poupar. O galho novo nomeia o canal e o `kind`, cita LDG-0100, e mantém `exit 1` no hook (o push continua bloqueado; o que muda é a frase, não a política). A ordem dos testes é `rc == 2` primeiro, depois qualquer outro não-zero, para que a adição não altere o desfecho de nenhum rc existente.

*Alternativa descartada — deixar o rc 2 passar no `pre-push`.* Seria colapsar o terceiro estado no primeiro em vez de no segundo, que é a forma pior: o falso-verde que a onda existe para eliminar.

### 1.7 As duas alternativas de mecanismo, medidas em vez de deduzidas

A issue descarta a alternativa `kind: fs` com `policy: union` por raciocínio. Rodei as duas alternativas contra a **mesma** árvore armada, com o mesmo hub de duas linhas, restaurando hub e configuração entre elas e conferindo a restauração com `cmp -s`.

```
hub controle = 028045d992ee (2 linhas)

=== ALTERNATIVA A: chave de topo nova (min_machinery_version: "0.15.0"), kind segue fs
OK sync — push-only via fs (log de demo publicado)
rc=0
HUB DESTRUÍDO — a alternativa FALHA ABERTA (hub caiu de 2 para 1 linha)

=== ALTERNATIVA B: policy: "union" dentro do bloco transport
config restaurada (cmp -s); hub recontrolado ao estado de controle
transporte inválido em liaison.yaml: campo desconhecido em transport: policy
rc=1
HUB INTACTO — falha fechado

=== RECONTROLE final: config original, kind fs
OK sync — push-only via fs (log de demo publicado)
rc=0
hub: 1 linha — o dano volta quando a trava sai
```

A alternativa A — declarar a exigência como chave de topo do `liaison.yaml`, que é o desenho que parece mais honesto porque nomeia a propriedade em vez de escondê-la num nome de transporte — **falha aberta e destrói o hub**, porque `parseYamlSubset` ignora chave de topo desconhecida e `readConfig` (linhas 41-47) só normaliza `self` e `channels`. Essa medição é o argumento decisivo e nenhum dos dois documentos do campo a tinha.

A alternativa B falha fechado, e o campo está certo sobre o porquê de ela não servir: a proteção inteira depende de `liaison-config.mjs:93`, um laço cuja finalidade declarada é higiene de schema. Relaxá-lo para aceitar campos futuros é a evolução natural de um validador de configuração, e no dia em que alguém o fizer a falha vira aberta sem que ninguém perceba que quebrou uma trava.

O `kind` tem duas camadas independentes e nenhuma delas é higiene: a lista de nomes e a existência do arquivo de backend existem, as duas, para dizer "esta árvore não sabe fazer isto".

**Censo do parque, refeito por mim, e ele é testemunha de data.** A enumeração é por árvore, não por `find` solto sobre `~/Documents/projects` — a versão com `find` demora minutos e é a que produziu, numa tentativa anterior, uma saída truncada que parecia um total (ver §10). Comando:

```
for r in Axis.PadSimulator axis-go-cloud axis-fare-validator forge-harness azim-crm collatra axis-go-cloud/axis-device-platform; do
  { echo "$HOME/Documents/projects/$r"; git -C "$r" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}'; } >> trees.txt
  [ -d "$r/.forge/worktrees" ] && find "$r/.forge/worktrees" -maxdepth 1 -mindepth 1 -type d | sed "s|^|$HOME/Documents/projects/|" >> trees.txt
done
sort -u trees.txt -o trees.txt
while read -r t; do [ -f "$t/.forge/liaison/liaison.yaml" ] && echo "$t/.forge/liaison/liaison.yaml"; done < trees.txt > cfg.txt
xargs grep -hE '^[[:space:]]*kind:' < cfg.txt | sed 's/.*kind:[[:space:]]*//' | tr -d '"' | sort | uniq -c
xargs grep -lF 'fs-union' < cfg.txt
```

```
árvores enumeradas = 190
arquivos de configuração = 144
 345 fs
   9 fs-union
total = 354
arquivos com fs-union:
  .../axis-device-platform/.forge/liaison/liaison.yaml
  .../axis-device-platform/.forge/worktrees/campaign-approval/.forge/liaison/liaison.yaml
  .../axis-device-platform/.forge/worktrees/consolida-gates/.forge/liaison/liaison.yaml
```

**Triangulação por um segundo método, porque a revisão 1 obteve 143/353/344 e a diferença precisava ser explicada em vez de tolerada.** Rodei também um `find` independente, que não enumera árvore nenhuma e varre os seis diretórios de repositório inteiros podando `node_modules`, `.git`, `bin` e `obj`:

```
find Axis.PadSimulator axis-go-cloud axis-fare-validator forge-harness azim-crm collatra \
  \( -type d \( -name node_modules -o -name .git -o -name bin -o -name obj \) -prune \) -o \
  \( -type f -path '*/.forge/liaison/liaison.yaml' -print \) | sort -u
```

```
find independente = 143 arquivos ; 344 fs ; 9 fs-union
```

O `find` reproduz **exatamente** os números da revisão 1, e o `comm` entre as duas listas mostra que a diferença é **um único arquivo**: `/private/tmp/forge-baseline-wt/.forge/liaison/liaison.yaml`, um worktree de `forge-harness` que mora **fora** de `~/Documents/projects` e que só a enumeração por `git worktree list` alcança. Um arquivo, uma declaração `fs`, e daí 144 contra 143 e 345 contra 344. Os dois métodos concordam em tudo o mais, e concordam **exatamente** nas leituras decisivas.

**As leituras que decidem argumento, e nenhuma delas é o total:** zero `git`, zero `gh` e zero `manual` em todo o parque, pelos dois métodos; as nove `fs-union` estão em exatamente três arquivos, todos do `axis-device-platform`, pelos dois métodos; e nenhum outro repositório declarou um `kind` que a maquinaria não conheça. Os totais 144/354/345 envelhecem a cada `git worktree add` e existem aqui só para dizer sobre que universo as leituras decisivas foram tiradas.

---

## 2. ITEM 2 — issue #101: `scripts/` é sobrescrito, e sem lock a perda é muda

### 2.1 O defeito, reproduzido — e a linha que afirma o contrário

Fixture nova em `$TMPDIR`, `git init`, `forge init -y --no-plugin`, três consertos locais plantados em `.forge/scripts/`, e um `update --no-plugin`:

```
cd "$B/git1" && git init -q .
node <repo>/bin/forge.mjs init -y --no-plugin
for f in check-liaison-acks.sh check-secrets.sh handoff-gen.sh; do printf '\n# conserto local de bancada %s\n' "$f" >> ".forge/scripts/$f"; done
node <repo>/bin/forge.mjs update --no-plugin > u1.log 2>&1; echo "rc_update=$?"
```

```
== .forge/cache existe apos init? ==
ls: .forge/cache: No such file or directory
rc_update=0
== consertos sobreviveram? ==
check-liaison-acks.sh:0 check-secrets.sh:0 handoff-gen.sh:0
== linhas totais do log ==  30
== linhas citando os 3 arquivos ==  0
== linhas com WARN/drift/preserv ==
13:  ✓ harness: adapter claude sem drift (lockfile íntegro)
14:  ✓ harness: adapter core sem drift (lockfile íntegro)
29:  sem trabalho de produto a preservar
```

As três linhas que casam com `preserv`/`drift` são `sem trabalho de produto a preservar` e duas de `adapter ... sem drift (lockfile íntegro)`. O operador lê, no mesmo relatório em que três consertos foram destruídos, a afirmação de que não havia nada a preservar.

`forge init` não cria `machinery.lock` — a primeira linha da saída acima é a prova —, então `driftWarned` (`bin/forge.mjs:629`) nunca dispara, porque a condição dele exige `oldLock && oldLock.has(rel)`.

**O `30` é testemunha de fixture, não critério.** Ele depende de `--no-plugin`, de o alvo ser repositório git e de o `doctor` do pós-check não achar diagnóstico ausente; a mesma bancada **fora** de repositório git, com dois `update`, deu **33** (§2.2). Nenhuma asserção de gate desta spec usa o número: o que se afirma é *"zero linhas do relatório citam qualquer um dos arquivos que a execução acabou de sobrescrever"*, com o denominador de arquivos derivado da própria fixture.

Com lock, o aviso existe e aponta para o lugar errado — medido na mesma classe de fixture, depois que o primeiro `update` escreveu o lock:

```
backup: .forge copiado para .git/forge-backups/forge-2
WARN: drift local em scripts/lib/liaison-config.mjs sobrescrito pelo template (fix local em maquinaria? faça upstream; backup em .forge.bak-N)
  backup fora da árvore, em .git/forge-backups/ (não é varrido por gate nem aparece em git status)
```

Duas linhas de distância entre o caminho certo e o errado, na mesma execução. E há um quarto estado que a issue não menciona: com `--no-backup`, o aviso continua mandando o operador para `.forge.bak-N`, que não existe, **e não existe backup nenhum daquela execução**.

### 2.2 O inventário de mensagens da issue está errado — e são QUATRO strings, não três

A issue diz "três mensagens (linhas 640, 643 e 660)". A revisão 1 encontrou uma quarta que a revisão anterior desta spec não tinha, e eu a reproduzi. Comando e saída, alvo **fora** de repositório git, com dois `update` (o segundo é quem produz o `backup: ... .forge.bak-2`):

```
cd "$B/nogit" && node <repo>/bin/forge.mjs init && node <repo>/bin/forge.mjs update && node <repo>/bin/forge.mjs update > up2.log 2>&1
grep -n -i "backup" up2.log ; wc -l < up2.log ; ls -d .forge.bak-*
```

```
3:backup: .forge copiado para .forge.bak-2
4:  (fora de um repositório git: o backup ficou DENTRO da árvore — remova-o antes de rodar gates com --path)
33:  backup fora da árvore, em .git/forge-backups/ (não é varrido por gate nem aparece em git status)
33   (total de linhas)
.forge.bak-1  .forge.bak-2
```

A **mesma execução** diz, na linha 3, que o backup ficou em `.forge.bak-2` dentro da árvore, e diz na linha 33 que ele está fora da árvore, em `.git/forge-backups/`. O diretório `.git/forge-backups/` não existe. A fonte é `bin/forge.mjs:718`, guardada só por `if (!flags.noBackup)`, sem nenhum galho para o caso `gitDir === null` — enquanto a linha 606 logo acima **já calcula** o rótulo certo (`const mostra = gitDir ? relative(target, bakDir) : '.forge.bak-' + n`) e o joga fora ao sair do bloco.

Inventário completo, conferido linha a linha com `grep -n 'forge\.bak' bin/forge.mjs`:

| Linha | Texto | É mensagem impressa? | Está correto? |
|---|---|---|---|
| 135 | `case '--no-backup': ... // update: não cria .forge.bak-N` | **não**, é comentário | irrelevante |
| 182 | `--force  se .forge já existe, faz backup (.forge.bak-N) e sobrescreve.` | sim, no `--help` | **sim** — caminho `init --force`, medido abaixo |
| 189 | `--no-backup  (update) não cria .forge.bak-N (o .forge já é versionado em git)` | sim, no `--help` | **não** — o backup do `update` vai para `.git/forge-backups/forge-N` desde a #76 |
| 628 | `// ... o backup .forge.bak-N cobre.` | **não**, é comentário | irrelevante |
| 640 | `console.log('  (se o template também mudou nesses paths, reconcilie à mão — diff contra .forge.bak-N)')` | sim | **não** |
| 643 | `console.log(\`WARN: drift local em ${rel} ... backup em .forge.bak-N)\`)` | sim | **não** |
| 660 | `// Cada remoção é listada; o backup .forge.bak-N cobre.` | **não**, é comentário | irrelevante |
| **718** | `console.log('  backup fora da árvore, em .git/forge-backups/ ...')` | sim | **não** — mente no sentido oposto quando o alvo não é repositório git |
| 764 | `console.error('   --force moveria tudo para .forge.bak-N ...')` | sim | **sim** — caminho `init --force` |
| 777 | `console.log(\`backup: .forge anterior movido para .forge.bak-${n}...\`)` | sim | **sim** — caminho `init --force` |

As linhas 182, 764 e 777 são do caminho `init --force`, e eu as **executei** nesta revisão em vez de só as ler:

```
cd "$B/force" && git init -q . && node <repo>/bin/forge.mjs init -y --no-plugin && node <repo>/bin/forge.mjs init -y --force --no-plugin
```

```
backup: .forge anterior movido para .forge.bak-1
=== onde o backup foi parar? ===
.forge.bak-1
ls: .git/forge-backups: No such file or directory
```

Alvo git, `init --force`, e o backup vai para `.forge.bak-1` **dentro** da árvore — o literal está certo ali e trocá-lo introduziria o defeito oposto. `tests/w13-init-gate.sh:68` (`[ -d "$T1/.forge.bak-1" ]`) corrobora, e é o gate que reprovaria se a correção vazasse para esse caminho.

Ou seja: são **quatro** strings erradas — 189, 640, 643 e 718 —, e as três da issue estão duas certas e uma trocada. A correção do inventário entra no fechamento da #101.

### 2.3 O que a mudança faria com o parque instalado — medido, com o comando

Antes de fechar o desenho, medi quantos arquivos de `scripts/` **seriam preservados** em cada consumidor pela regra do lock, porque essa é a diferença entre "preserva conserto" e "congela maquinaria". O critério é o mesmo da regra proposta em P1: o destino existe, `sha256(destino) != sha256(template)` **e** `lock[rel] != sha256(destino)`; sem lock nada é preservado, por definição. Script (leitura pura sobre os consumidores; foi gravado em `$TMPDIR/ondaC-rev2/preserva.mjs`):

```
import { readdirSync, statSync, existsSync, readFileSync } from 'node:fs';
import { join, relative } from 'node:path'; import { createHash } from 'node:crypto';
const TPL = '<repo>/template/.forge';
const sha = (p) => createHash('sha256').update(readFileSync(p)).digest('hex');
function walk(d, base = d, out = []) { for (const e of readdirSync(d, { withFileTypes: true })) { if (e.name === '.DS_Store') continue; const p = join(d, e.name); if (e.isDirectory()) walk(p, base, out); else if (e.isFile()) out.push(relative(base, p)); } return out; }
function lockOf(forge) { const p = join(forge, 'cache', 'machinery.lock'); if (!existsSync(p)) return null; const m = new Map(); for (const l of readFileSync(p, 'utf8').split('\n')) { const g = /^([0-9a-f]{64})  (.+)$/.exec(l); if (g) m.set(g[2], g[1]); } return m; }
for (const target of process.argv.slice(2)) {
  const forge = join(target, '.forge'); if (!existsSync(forge)) { console.log(target + '\tSEM .forge'); continue; }
  const lock = lockOf(forge); const counts = {};
  for (const dir of ['scripts', 'hooks', 'commands', 'schemas', 'agents', 'rules']) {
    const tdir = join(TPL, dir); if (!existsSync(tdir)) continue; let n = 0;
    for (const rel of walk(tdir)) { const dst = join(forge, dir, rel);
      if (!existsSync(dst) || !statSync(dst).isFile()) continue;
      const dh = sha(dst); if (dh === sha(join(tdir, rel))) continue;
      if (!lock) continue; if (lock.get(dir + '/' + rel) === dh) continue; n++; }
    if (n) counts[dir] = n; }
  console.log(target + '\tlock=' + (lock ? lock.size : 'AUSENTE') + '\t' + JSON.stringify(counts));
}
```

Saída, `cd ~/Documents/projects && node preserva.mjs axis-fare-validator axis-go-cloud Axis.PadSimulator azim-crm collatra axis-go-cloud/axis-device-platform`, testemunha de 2026-09-07:

```
axis-fare-validator                 lock=401  {"scripts":26,"hooks":8,"rules":4}
axis-go-cloud                       lock=402  {"scripts":23,"hooks":4,"agents":1,"rules":10}
Axis.PadSimulator                   lock=396  {"scripts":35,"hooks":3,"commands":2,"schemas":2,"rules":3}
azim-crm                            lock=401  {"agents":1,"rules":5}
collatra                            lock=339  {"agents":4,"rules":5}
axis-go-cloud/axis-device-platform  lock=351  {"scripts":20,"hooks":6,"rules":2}
```

As colunas de `rules` e `agents` aparecem porque o script varre todos os diretórios de maquinaria; esses dois já estão em `ENRICHABLE_DIRS` (`bin/forge.mjs:352`) e **já** são preservados hoje — não são efeito desta onda e estão aqui só para que o leitor veja que o critério não os inventou.

**Esta tabela é o argumento a favor do desenho, e não contra.** Os dois repositórios que nunca editaram `scripts/` preservam **zero**: o lock discrimina defasagem de conserto exatamente como promete, e um consumidor que só ficou para trás continua recebendo o template inteiro. Os quatro que preservam algo são os quatro que editaram — e a amostra do conteúdo confirma a natureza da edição. O `archive-spec.sh` do `axis-fare-validator` difere do template, e o bloco divergente é engenharia documentada com item de ledger próprio:

```
# Raiz do TRONCO, calculada por âncora e PASSADA explicitamente (LDG-0687). Este gate lê só
# `.forge/liaison` — nada do change —, e o liaison mora uma vez só, no tronco; com `$ROOT` (a
# worktree) o pré-flight aprovava contra a cópia congelada da branch e liberava o arquivamento
# com ack de verdade pendente no canal.
```

Sobrescrever isso é destruir trabalho de engenharia com rastro; preservá-lo é o desenho pretendido pela issue.

**Os seis números são testemunha de data e nenhum entra em asserção.** A propriedade que o gate afirma é *"existe pelo menos um consumidor cujo `scripts/` a regra preservaria e pelo menos um cujo `scripts/` ela não preservaria"* — piso um de cada lado, que é o que separa "preserva conserto" de "congela maquinaria". A tabela mostra 4 e 2 hoje; a asserção sobrevive a qualquer um deles mudar.

**O risco residual, dito em voz alta:** um consumidor que consertou `check-secrets.sh` localmente deixa de receber os nossos consertos naquele arquivo, para sempre, e o relatório do `update` é a única coisa que o avisa. Essa é uma limitação real e ela **não se fecha nesta onda**: o detector persistente é o `doctor` reportando divergência contra o lock, que é LDG-0153 e vive na Onda B.

### 2.4 Decisões de desenho — FECHADAS

**P1. `scripts/` passa a decidir por lock — preserva-e-reporta quando há deriva —, num conjunto PRÓPRIO, não dentro de `ENRICHABLE_DIRS`.**

Nasce `const PRESERVED_ON_DRIFT_DIRS = ['scripts']`, que compartilha com `ENRICHABLE_DIRS` a mesma função de decisão de três galhos (`dst` ausente → escreve; `dst == lock` → escreve, upgrade limpo; caso contrário → preserva), e difere dela em duas coisas: a linha de relatório e a semântica de tombstone.

*Alternativa descartada — simplesmente acrescentar `'scripts'` a `ENRICHABLE_DIRS`.* Seria uma linha, e é errada por dois motivos medidos. Primeiro, a linha de relatório: `preservados: N arquivo(s) com customização local NÃO sobrescritos` diz ao operador que aquilo é um ponto de extensão suportado, enquanto o comentário do próprio arquivo (`bin/forge.mjs:628`) declara o contrário — "o fluxo certo para fix em maquinaria é upstream no template". Segundo, `isEnrichable` também governa o galho de tombstone (linha 667): um `scripts/*.sh` que o template removesse e que o consumidor tivesse editado passaria a sobreviver como órfão com aviso, mudando o comportamento de `w101[6]` e de `w63` sem que ninguém tivesse decidido isso.

**P2. Sem `machinery.lock`, o update DECLARA nominalmente e sobrescreve — não recusa, não preserva.**

Uma linha por arquivo, com token próprio, o caminho **real** do backup, e rc 0:

```
SEM REFERÊNCIA: scripts/check-secrets.sh difere do template e não há machinery.lock — não dá para
  distinguir conserto local de defasagem. Sobrescrito; o conteúdo anterior está em <backup real>.
```

O plano-mestre dá a régua: *"quando não dá para saber, dizer, em vez de agir calado"*. A ação continua a de hoje; o que muda é que ela deixa de ser muda.

*Alternativa descartada — preservar tudo que difere quando não há lock.* Congela a maquinaria de quem só está defasado, que é justamente a população sem lock.

*Alternativa descartada — recusar o update quando não há lock e há deriva.* Medi por que isso seria hostil: dois dos seis consumidores (`collatra` e `axis-device-platform`) **não rastreiam** `.forge/cache/machinery.lock` (`git -C <repo> ls-files -- .forge/cache/machinery.lock` sai vazio nos dois), e a Fase 1 deste plano decidiu que este repositório também não o rastreará. Para eles, todo clone novo — e todo runner de CI — começa sem lock. Recusar transformaria o primeiro `update` depois de cada clone numa parada com dezenas de arquivos, para uma condição que na maioria das vezes é defasagem trivial.

**P3. A única recusa é o caso irrecuperável, com rc 5.**

O update **reprova antes de escrever qualquer arquivo** quando as quatro condições ocorrem juntas: não há lock, `--no-backup` foi passado, existe deriva em `scripts/`, e o arquivo derivado **não está rastreado** no git do alvo. É a única combinação em que não há referência para decidir e não há de onde recuperar. A escapatória é nomeada na mensagem: tirar o `--no-backup`, ou passar `--force-machinery`.

A pergunta "está rastreado?" é respondida pelo índice, não pelo `HEAD`, e a diferença importa. Medido em bancada:

```
== repositório SEM nenhum commit
ls-files rastreado: [rastreado.txt]
ls-files solto:     []
diff HEAD rc: 128
== fora de repositório git
ls-files rc fora de repo: 128
```

`git diff HEAD` sai **128** num repositório sem commit — é o sexto desfecho que derrubou uma enumeração "exaustiva" da Onda A, e ele reaparece aqui. `git ls-files` responde certo nos dois estados e devolve rc 128 fora de repositório, que o chamador trata como "não rastreado" e não como erro. A propriedade é *"o conteúdo anterior é recuperável por alguma via"*; o primitivo é do implementador, mas ele precisa provar que discrimina os quatro estados (rastreado, solto, repositório sem commit, alvo fora de repositório).

Exposição desta recusa no parque de hoje: **nenhum consumidor está no estado que ela pega**, porque todos rastreiam `.forge/scripts`. Comando e saída, testemunha de data:

```
for r in axis-fare-validator axis-go-cloud Axis.PadSimulator azim-crm collatra axis-go-cloud/axis-device-platform; do
  echo "$r $(git -C "$HOME/Documents/projects/$r" ls-files -- .forge/scripts | wc -l)"; done
```

```
axis-fare-validator 233 ; axis-go-cloud 313 ; Axis.PadSimulator 155
azim-crm 721 ; collatra 98 ; axis-device-platform 183
```

A propriedade, e não os seis números, é *"todo consumidor conhecido rastreia pelo menos um arquivo sob `.forge/scripts`"* — piso um, seis de seis hoje. Exposição zero é o ponto: é a guarda para o estado em que ninguém está ainda, e a fixture do gate é quem o cria.

*Alternativa descartada — não recusar nunca, só declarar.* Deixaria a única porta irrecuperável aberta, com uma linha de aviso como toda proteção, num comando que roda em lote.

**P4. O rótulo do backup passa a ter três valores, calculado uma vez e usado nas QUATRO mensagens.**

O bloco que decide o destino do backup está dentro do `if (!flags.noBackup)` (linhas 575-608), então `bakDir` não é visível nas linhas 640, 643 e 718 — é por isso que as três têm literal. O rótulo sobe para o escopo da função e assume um de três valores: o caminho relativo real (`.git/forge-backups/forge-N`), `.forge.bak-N` quando o alvo não é repositório git, e um valor que diz que **não houve backup** quando `--no-backup` foi passado.

O invariante, escrito para poder ser asserido: **nenhuma das quatro mensagens de backup do caminho `update` — 189, 640, 643 e 718 — pode nomear um destino que aquela execução não usou.** Em particular, nenhuma delas cita `.git/forge-backups/` quando o alvo não é repositório git, e nenhuma cita destino algum quando `--no-backup` foi passado. A linha 189 do `--help` é corrigida junto; as linhas 182, 764 e 777 ficam como estão, pelo motivo medido em §2.2.

**P5. `hooks/`, `commands/` e `schemas/` ficam FORA do escopo, com o número que sustenta a decisão.**

A tabela de §2.3 mostra deriva em `hooks/` em quatro dos seis consumidores. Não entra nesta onda por uma razão de classe: `hooks/` é o **canal de entrega** dos gates, e um hook preservado por ser "conserto local" pode ser exatamente o que impede um gate corrigido de rodar — o risco de preservar é qualitativamente diferente do risco de preservar um script. Fica registrado como item de ledger novo (§8), com a medição e a data.

Consequência que precisa ser dita, porque decide um cenário do gate: com `scripts/` fora do galho de `driftWarned`, o `WARN: drift local` continua tendo universo — `hooks/` fornece deriva real em quatro consumidores —, então a mensagem não fica órfã e continua sendo exercida.

---

## 3. ITEM 3 — LDG-0100: decisão

**Decisão: `wont-fix`, com a condição de reabertura MECANIZADA por C4/C6 em vez de escrita.**

O censo refeito por mim (§1.7, com o comando) mede **zero `git` e zero `gh` em 354 declarações de transporte, sobre 144 arquivos de configuração em 190 árvores enumeradas**. A leitura que decide é o zero, e ela não envelhece do jeito que o total envelhece: qualquer aparecimento de um canal `git`/`gh` a derruba, e é precisamente esse aparecimento que C6 transforma em recusa de push. A condição de reabertura que o item já traz por escrito — "o primeiro canal declarado como `kind: git` ou `kind: gh` em qualquer árvore do ecossistema" — não é atendida.

*Alternativa descartada — implementar a leitura de hub para `git`/`gh` junto do #123.* Duas medições a derrubam. A primeira é a do censo: não existe hub `git` nem `gh` em lugar nenhum para exercitar a implementação, e o que ela produziria é o que a guarda de vacuidade do harness existe para reprovar — maquinaria cujo único universo é a fixture que a acompanha. A segunda é de custo e está no próprio cabeçalho do script (linhas 38-42): buscar a branch remota a cada `push` é uma decisão de rede num gate de `pre-push`, e ela merece ser tomada quando houver alguém pagando o preço.

*O que a onda entrega no lugar, e é por isso que o `wont-fix` fica honesto:* `git` e `gh` deixam de ser **aprovados em silêncio**. Hoje um canal `git` cai no fallback da réplica e o veredito diz "N thread(s) examinada(s), nenhum ack pendente" sem ter olhado para o hub — é a mesma frase que o script emitiria se tivesse olhado. Com C4 ele sai `NÃO VERIFICADO` com rc 2, nomeando o canal e o `kind`, e com C8 a frase que chega ao operador no `pre-push` é a dele, não a de ack pendente. O item continua sem ser implementado, e o instrumento para de fingir que foi.

A reclassificação exigida pelo plano-mestre é registrada no ledger com estas duas medições e com a nova condição de reabertura: **o primeiro `push` reprovado por `NÃO VERIFICADO` em canal `git`/`gh` reabre o item**, com o repositório e a data que a própria recusa carimba — e com a ressalva de C6 de que a recusa acontece na máquina do adotante, de modo que a notícia ainda depende do canal para chegar até aqui.

---

## 4. O VERMELHO, antes do verde

### 4.1 Gate 1 — `tests/w<NNN>-liaison-transport-fixpoint-gate.sh`

`DECLARADOS=15`, cenários `[0]` a `[14]`. Quatro nascem verdes por construção e a coluna diz quais: `[0]` é o contador do próprio gate, `[1]` é o controle positivo do dano, `[2]` é a propriedade que a onda precisa preservar e `[12]` é a sentinela. Onze falham hoje por ausência real.

| # | Cenário | Asserção | O vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [0] | CONTADOR DE CONTROLE | ver §5.2 | — | nasce verde, é o denominador de cenários do próprio gate |
| [1] | CONTROLE POSITIVO DO DANO — fixture ARMADA (ver a nota obrigatória abaixo), `kind: fs`, hub com uma mensagem que a réplica não tem | o hub **perde** a mensagem e o `sync` sai 0 | — | nasce verde; é a propriedade da fixture armada, não do produto, e existe para que `[2]` não fique verde por acidente |
| [2] | a MESMA fixture armada, `kind: fs-union` | `sync` reprova e o hub fica **byte-idêntico** | — | nasce verde: as duas camadas já reprovam hoje **dentro da fixture**, que é pinada e não deriva do template. É a propriedade que a onda precisa **preservar**, e M14 é a mutação que prova que ela mede |
| [3] | árvore com a maquinaria ATUAL do template, canal `kind: fs-union`, hub alcançável | `sync` publica com rc 0 | `FAIL [3]: transporte inválido em liaison.yaml: kind inválido: fs-union (use manual\|fs\|git\|gh)` | `fs-union` não está em `TRANSPORT_KINDS` e `transports/fs-union.sh` não existe |
| [4] | `check-liaison-acks.sh`, canal `fs-union`, uma mensagem `requires_ack` **só no hub**, `enforce: block` | reprova nomeando `<canal>/<thread>: <msg_id>` | `FAIL [4]: aprovou com 0 thread(s) examinada(s) — o hub tem 1 cobrança` | a linha 179 testa `fs`/`manual` literalmente e cai na réplica |
| [5] | canal `kind: git` com `remote` válido, ÚNICO canal do repositório | rc **2**, token `NÃO VERIFICADO`, canal e `kind` nomeados, e a thread **não** contada como examinada | `FAIL [5]: aprovou (rc=0) declarando thread(s) examinada(s) sobre um hub que não leu` | o terceiro estado não existe |
| [6] | canal ÚNICO com `kind` NÃO-VAZIO que `validateTransport` reprova (um erro de digitação de `fs-union`) | rc **2**, citando a mensagem de `validateTransport` | `FAIL [6]: kind inválido passou em silêncio pela réplica local (rc=0)` | `check-liaison-acks.sh` nunca chama `validateTransport` |
| [7] | canal **sem** bloco `transport`, e um segundo canal com `kind: ""` (vazio) | rc inalterado nos dois, réplica lida nos dois, e os dois contados na categoria "lido da réplica" | `FAIL [7]: o contador não distingue canal lido do hub de canal lido da réplica` | a categoria não existe |
| [8] | CONTADOR do leitor | soma das quatro categorias == canais declarados, com denominador derivado em execução; reprova quando declarados > 0 e a soma não fecha | `FAIL [8]: o veredito publica threads examinadas e nenhum número sobre canais` | o contador de canais não existe |
| [9] | CANAL REAL — `git push` de verdade numa fixture, canal `fs-union` com ack pendente no hub, `enforce: block`, hooks instalados como o `pre-push` os instala | o push é **bloqueado**, e a saída carrega o sinal positivo de que o check rodou | `FAIL [9]: o push passou com cobrança pendente no hub` | mesma ausência de `[4]`, exercida pelo canal em que ela importa |
| [10] | CONTRATO do CLI — `transport set <canal> --kind fs-union --path <dir>` | grava e responde `OK`; **e** `--kind fs-union` **sem** `--path` reprova com a mesma forma de mensagem que `--kind fs` sem `--path`; **e** o mesmo comando com o `kind` digitado errado reprova | `FAIL [10]: transport set --kind fs-union reprovou com kind inválido`, e — depois de `fs-union` entrar só em `TRANSPORT_KINDS` — `FAIL [10]: --kind fs-union sem --path gravou transporte inválido (rc=0)` | `[3]` para a primeira asserção; `liaison-config.mjs:90` decide `path` por lista literal de nomes, e por isso a segunda asserção é vermelha mesmo depois do passo 2 (medição em C7) |
| [11] | PARIDADE — `enum` do `liaison-config.schema.json` e `TRANSPORT_KINDS` declaram o mesmo **conjunto** | conjuntos idênticos, comparados como conjunto e nunca por contagem; o lado do schema é lido do `enum` do JSON **por parser** (`node -e` com `JSON.parse`), nunca por `grep` de nomes | — | nasce verde (hoje os dois têm os mesmos quatro); é guarda de regressão, e M3 prova que morde |
| [12] | SENTINELA DO PRÓPRIO GATE | `template/` sem divergência contra `HEAD` em arquivo rastreado, e o `.forge/liaison/` da raiz byte-idêntico, no início e no fim | `FAIL [12]: o gate mexeu na árvore real` | nasce verde; o vermelho dela é defeito do gate, não do produto (a disciplina de LDG-0175) |
| [13] | MULTI-CANAL — um repositório com dois canais em estados diferentes: um `kind: git` (que sairia rc 2) e um `kind: fs` com ack pendente em `enforce: block` (que sai rc 1) | rc **1** pela precedência de C4-bis; a saída contém, na mesma execução, a cobrança nominal do canal `fs` **e** a linha `NÃO VERIFICADO` do canal `git`; e uma terceira montagem, com um canal `git` e um canal `fs` de hub inalcançável, sai rc 1 pelo `HUBFAIL` **com os quatro contadores de canal presentes** | `FAIL [13]: com dois canais em estados diferentes o script não tem desfecho definido — hoje sai rc=0` | nem o rc 2 nem a precedência nem os contadores existem, e no caminho `HUBFAIL` o `return` de `check-liaison-acks.sh:233-236` acontece antes de qualquer contagem sair |
| [14] | CANAL DE ENTREGA DO TERCEIRO ESTADO — `git push` real, hooks instalados, repositório com um único canal `kind: git` | o push é bloqueado **e** a mensagem do `pre-push` nomeia o terceiro estado e o canal, sem usar a frase de ack pendente | `FAIL [14]: rc 2 chegou ao operador como "liaison — ack pendente"` | `pre-push:116-121` tem um único galho para todo rc não-zero (medição em C8) |

**Nota obrigatória sobre a fixture de `[1]` e `[2]`, e ela é normativa.** O `_common.sh` armado **não pode** ser copiado de `~/Documents/projects/...`: o gate roda em máquina que não tem o `axis-device-platform`, e ler árvore de consumidor de dentro da suíte é dependência de ambiente que a suíte não controla. A fixture monta a árvore armada ela mesma, em `$TMPDIR`, e ela é **pinada em três pontos**, nenhum deles derivado de `template/.forge`:

1. escreve o `_dir_push` destrutivo com o corpo mínimo (`cp` do próprio log da réplica para `$hub/log/.<self>.jsonl.tmp`, `mv` sobre `$hub/log/<self>.jsonl`), que é o corpo que eu extraí e descrevi em §1.3;
2. escreve um `lib/liaison-config.mjs` cujo `TRANSPORT_KINDS` **não contém** `fs-union` — nem hoje nem depois do passo 2 de §9;
3. **não** recebe `lib/transports/fs-union.sh`.

Sem os pontos 2 e 3 o cenário `[2]` inverteria de polaridade no meio da própria onda: depois que `fs-union` virar `kind` válido no template, uma fixture que derivasse dele publicaria, o hub mudaria, e a asserção "`sync` reprova e o hub fica byte-idêntico" ficaria vermelha contra a implementação **correta**. O que `[2]` mede é a árvore velha, e árvore velha se representa pinando, não copiando o presente.

**Nota obrigatória sobre `[9]` e `[14]`.** A regra `testing/gate-delivery-channel.md` exige sinal **positivo** de execução, porque um hook que não rodou produz o mesmo silêncio de um hook que aprovou. O implementador escolhe o sinal e prova que ele discrimina, rodando o mesmo cenário com o `check-liaison-acks.sh` removido do `.forge/scripts/` da fixture — o `pre-push` tem galho próprio para isso (linhas 112-115) e a mensagem dele é distinta. Em `[14]` vale a mesma exigência e mais uma: a asserção precisa distinguir a frase nova da frase de ack pendente, e não apenas constatar que o push foi bloqueado, porque bloqueio o rc 1 também produz.

### 4.2 Gate 2 — `tests/w<NNN>-update-machinery-preserve-gate.sh`

`DECLARADOS=11`, cenários `[0]` a `[10]`. **Dois** nascem verdes: `[0]`, contador do próprio gate, e `[2]`, a guarda contra congelar maquinaria. O `[6]` nasce **vermelho** nesta revisão, e por medição — é o cenário que a quarta string errada derruba.

| # | Cenário | Asserção | O vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [0] | CONTADOR DE CONTROLE | ver §5.2 | — | nasce verde |
| [1] | COM lock, script com conserto local | o arquivo fica **byte-idêntico** ao conserto e o relatório o nomeia com a linha de `scripts/` | `FAIL [1]: o conserto local foi destruído (o arquivo virou a cópia do template)` | `scripts` está fora de qualquer galho de preservação (`bin/forge.mjs:352`) |
| [2] | COM lock, script **intocado** e template mudou | sobrescrito (upgrade limpo) | — | nasce verde; é a guarda contra congelar maquinaria, e M5 prova que ela mede |
| [3] | SEM lock (árvore só-`init`), três scripts com conserto local | uma linha por arquivo, com o token de `SEM REFERÊNCIA` e o caminho **real** do backup; e **zero** linhas do relatório citando qualquer um dos três arquivos é o estado que a asserção derruba | `FAIL [3]: <N> linha(s) de saída e 0 citando os 3 arquivos destruídos` — com `<N>` **interpolado do próprio log**, nunca literal | `driftWarned` exige `oldLock && oldLock.has(rel)` (linha 629) |
| [4] | SEM lock + `--no-backup` + deriva em arquivo **não rastreado** | rc **5**, e a árvore **inteira** de `scripts/` byte-idêntica ao estado anterior | `FAIL [4]: sobrescreveu sem lock, sem backup e sem cópia no git — rc=0` | a recusa não existe, e a decisão de escrita é tomada dentro do laço, arquivo a arquivo |
| [5] | SEM lock + `--no-backup` + deriva em arquivo **rastreado** | sobrescreve, declara, rc 0 — a recusa de `[4]` é estreita e não pega este caso | `FAIL [5]: sobrescreveu em silêncio` | idem `[3]` |
| [6] | alvo **fora** de repositório git, com backup | **nenhuma** das quatro mensagens de backup do caminho `update` (as de 189, 640, 643 e 718) nomeia `.git/forge-backups/`; as que citam destino citam `.forge.bak-N`; e o diretório `.forge.bak-N` existe no disco | `FAIL [6]: a mesma execução diz ".forge.bak-2" na linha 3 e ".git/forge-backups/" na linha 33, e .git/forge-backups/ não existe` | `bin/forge.mjs:718` está dentro de `if (!flags.noBackup)` e não tem galho para `gitDir === null` (medição em §2.2) |
| [7] | `--no-backup` num alvo git, com deriva | **nenhuma** mensagem cita backup; a linha diz que não houve | `FAIL [7]: mandou o operador para .forge.bak-N, que não existe e não vai existir` | o rótulo é literal (linhas 640 e 643) |
| [8] | `hooks/` com conserto local | continua **sobrescrito**, com o `WARN: drift local` e o caminho de backup corrigido | `FAIL [8]: o aviso aponta para .forge.bak-N enquanto o backup foi para .git/forge-backups/forge-N` | mesmo literal, e este cenário garante que o `WARN` não fica sem universo |
| [9] | `--dry-run` | prevê exatamente o que `[1]` e `[3]` fazem, com os mesmos paths, e **não escreve** | `FAIL [9]: o dry-run não prevê preservação em scripts/` | a previsão de dry-run espelha `isEnrichable` (linha 552) |
| [10] | SENTINELA DO PRÓPRIO GATE | a árvore real não é tocada; o alvo é sempre `$TMPDIR` | `FAIL [10]: o gate mexeu na árvore real` | nasce verde |

**Nota sobre `[3]`, e ela existe por causa de uma ressalva da revisão 1.** A mensagem de falha traz o contador **interpolado do log daquela execução**, nunca um literal. A minha bancada deu 30 linhas num alvo git com `--no-plugin` e 33 num alvo não-git com dois `update` (§2.1 e §2.2) — o número depende de flags, de o alvo ser repositório git e do desfecho do `doctor` de pós-check, e fixá-lo transformaria o cenário em gate morto na primeira mudança de qualquer um dos três.

**Nota sobre `[4]`:** a asserção é *tree untouched*, e ela só é verdadeira se a decisão de recusar for tomada num pré-voo sobre a lista de arquivos, antes do laço que escreve (linha 619). Recusar no meio do laço deixaria a árvore pela metade, que é pior que o defeito. O implementador prova a propriedade comparando o conjunto de `sha256` de `scripts/` antes e depois, e não a existência de um arquivo específico.

---

## 5. Prova de mutação, contador de controle e níveis de teste

### 5.1 Matriz de mutação

Quatro das mutações abaixo eu executei nesta revisão, e a saída está colada em §1.4, §1.7 e C7. As demais são declaradas como **propriedade + contrafactual**, e o implementador tem a obrigação de medir o efeito real **antes** de escrever a linha da matriz — é a invariante 16, e LDG-0164 é o caso em que a mutação era `no-op` enquanto o `cmp` confirmava que o arquivo mudara.

| # | O que mutar | Gate | O gate deve ACUSAR | Contrafactual |
|---|---|---|---|---|
| M1 | remover `'fs-union'` de `TRANSPORT_KINDS` | 1 | `[3]`, `[4]`, `[9]`, `[10]`, `[11]`, `[13]`; **não** pode derrubar `[2]` | **medido** (§1.4, ARM T1): `kind inválido: fs-union (use manual\|fs\|git\|gh)`, rc 1, hub intacto. `[2]` é imune por a fixture ser pinada |
| M2 | apagar `lib/transports/fs-union.sh` | 1 | `[3]`, `[9]` | **medido** (§1.4, ARM T2): `FAIL: backend de transporte ausente: .../transports/fs-union.sh`, rc 1, hub intacto, com `cmp -s` provando que a mutação não foi fantasma |
| M3 | remover `fs-union` do `enum` do schema, mantendo em `TRANSPORT_KINDS` | 1 | `[11]` e **só** `[11]` | a ser medido; se derrubar outro cenário, o outro cenário está lendo o schema quando não devia |
| M4 | remover a entrada `'fs-union'` de `DIRECT_HUB_LAYOUT`, mantendo o `kind` válido | 1 | `[4]`, `[9]`, `[13]`; **não** pode derrubar `[3]` | é a mutação que separa "o transporte funciona" de "o gate de ack enxerga o transporte"; se `[3]` cair junto, a tabela foi consultada onde não devia |
| M5 | fazer o galho de preservação valer para **todo** arquivo de `scripts/` que difira do template, ignorando o lock | 2 | `[2]` | mede se `[2]` de fato prova que maquinaria não congela; sem isso `[2]` é decorativo |
| M6 | trocar a decisão de `PRESERVED_ON_DRIFT_DIRS` por sobrescrita (o comportamento de hoje) | 2 | `[1]` e `[9]` | é a mutação que reverte o item inteiro |
| M7 | trocar o rótulo dinâmico das linhas 640/643 pelo literal `.forge.bak-N` | 2 | `[7]` e `[8]`; **não** pode derrubar `[6]` | `[6]` mede a linha 718, que é outra fonte; se cair junto, o rótulo foi centralizado de um jeito que perdeu a distinção entre os dois sítios |
| M8 | devolver a linha 718 ao texto incondicional de hoje | 2 | `[6]` e **só** `[6]` | **medido** contra o código de hoje (§2.2): alvo não-git, backup em `.forge.bak-2`, e a linha 33 dizendo `.git/forge-backups/` num diretório que não existe |
| M9 | suprimir a recusa de rc 5, deixando o pré-voo passar | 2 | `[4]` e **só** `[4]` | se `[5]` cair junto, a recusa está larga demais e pega o caso recuperável |
| M10 | fazer o canal sem `transport` (e o de `kind` vazio) sair como `NÃO VERIFICADO` | 1 | `[7]` | é a mutação que protege a retrocompatibilidade de `w113`/`w136`; ela precisa morder aqui, dentro do gate novo, para que o achado não dependa de rodar a suíte inteira |
| M11 | reverter `validateTransport` para exigir `path` só de `fs` e `manual` | 1 | `[10]` | **medido** contra o código de hoje (C7): `--kind fs-union` sem `--path` grava com rc 0 e `OK`, enquanto `--kind fs` sem `--path` reprova, com `cmp -s` e recontrole |
| M12 | inverter a precedência de C4-bis, fazendo rc 2 vencer rc 1 | 1 | `[13]` | se `[13]` não cair, ele não está montando os dois canais em estados **diferentes**, e sim dois canais no mesmo estado |
| M13 | devolver o `pre-push` ao galho único para todo rc não-zero | 1 | `[14]`; **não** pode derrubar `[9]` | **medido** contra o código de hoje (C8): rc 1 e rc 2 produzem a mesma frase, e o recontrole com rc 0 volta a 0. `[9]` é rc 1 e continua correto sob a mutação — se cair, `[9]` está afirmando a frase em vez do bloqueio |
| M14 | dar à fixture armada de `[1]`/`[2]` um `liaison-config.mjs` que conhece `fs-union` **e** o arquivo `transports/fs-union.sh` | 1 | `[2]` | é a mutação que prova que `[2]` mede a **fixture armada** e não o template: com a fixture desarmada, o `sync` publica e o hub muda, e `[2]` tem de acusar. Sem ela, `[2]` seria verde por construção e não mediria nada |

**Restauração e recontrole.** Cada mutação é aplicada sobre uma **cópia** do arquivo em `$TMPDIR`, com o `sha256` do original guardado antes; a restauração é por `cp` da cópia intacta seguida de `cmp -s` byte a byte, e o cenário é reexecutado depois da restauração — sem esse recontrole a prova não vale (`feedback-mutacao-fantasma-restore`). Se a mutação for por `perl -0pi`, o `$` do lado direito da substituição precisa ser escapado, ou a mutação vira `no-op` enquanto o `cmp` confirma que o arquivo mudou (LDG-0164). As quatro mutações que eu executei foram feitas com `sed -i ''` sem `$` no lado direito, com `cmp -s` contra a cópia original confirmando que o arquivo mudou **e** com o efeito confirmado por comportamento observado — recusa, rc, e sha do hub.

### 5.2 Contadores de controle

**Gate 1, `[0]`:** o gate mantém `DECLARADOS=15` e um contador incrementado por cenário executado; reprova quando o executado difere do declarado. É o denominador de cenários do próprio gate, a única exceção literal legítima da invariante 14.

**Gate 2, `[0]`:** o mesmo, com `DECLARADOS=11`.

**Contador do leitor de hub (Gate 1, `[8]` e `[13]`), e este é o que importa em produção:** `check-liaison-acks.sh` passa a publicar quatro números de **canal** — canais lidos do hub, canais lidos da réplica (por não declararem transporte ou por `kind` vazio), canais `NÃO VERIFICADO`, e canais que reprovaram por hub inacessível. O **denominador é derivado em execução** (`Object.keys(doc.channels).length`), nunca literal, e o veredito reprova quando o denominador é maior que zero e a soma das quatro categorias não o iguala.

Os quatro contadores saem **em toda saída do script, inclusive no caminho `HUBFAIL`** — que hoje retorna antes de contar, medido em C4-bis. A linha `SCOPE <threads>` continua saindo apenas nos caminhos que varreram thread, porque no `HUBFAIL` não houve varredura a declarar.

**A restrição de forma, e ela é a armadilha B desta rodada, nomeada com o comando que a mede.** `tests/w150-liaison-flag-and-trust-gate.sh:374` casa `liaison-acks — [0-9]+ thread\(s\)` e a linha 376 extrai o número com `sed -n 's/.*liaison-acks — \([0-9]\{1,\}\) thread(s).*/\1/p'`. Qualquer texto inserido **entre** `liaison-acks — ` e `N thread(s)` faz as duas casarem vazio, e o gate reprova com `contou 0 thread(s)`. Os quatro contadores de canal entram, portanto, em **linha própria**, depois da linha de threads — nunca no meio dela. Esta é a restrição exata, e ela substitui a formulação vaga da revisão anterior ("continua saindo com a mesma forma").

### 5.3 Onde entra cada nível de teste

**PBT — aplica-se, em dois pontos, e os dois têm espaço de entrada de verdade.**

O primeiro é a classe que a onda fecha, e é o teste mais valioso desta especificação. Sobre `kind` gerado — os quatro válidos de hoje, `fs-union`, quase-acertos por uma letra, um único espaço, string longa, `kind` com maiúsculas, e nomes com hífen e ponto —, vale a propriedade **"todo `kind` NÃO-VAZIO produz um de três desfechos, e nenhum deles é leitura silenciosa da réplica"**: ou `validateTransport` reprova e o canal sai `NÃO VERIFICADO`, ou existe entrada em `DIRECT_HUB_LAYOUT` e o hub é lido, ou o canal sai `NÃO VERIFICADO` por não ter layout. Um `kind` não-vazio que caia fora dos três é o defeito, e é exatamente o estado em que `fs-union` deixou o adotante (§1.2).

**A string vazia é excluída do espaço gerado desta propriedade, e o motivo é medido, não estético.** `getTransport` (`liaison-config.mjs:75-78`) devolve `null` quando `!ch.transport.kind`, e string vazia é falsy — a medição está em C4. Pela sexta linha de C4, `transport` sem `kind` **deve** ler a réplica e **não** reprovar, decisão fechada de propósito para não deixar `w113` e `w136` vermelhos. Um PBT que incluísse `""` entre os três desfechos nasceria vermelho contra a implementação correta. O caso vazio tem propriedade própria, e ela também é asserida: **`kind` vazio, `transport` sem `kind` e canal sem bloco `transport` produzem os três o mesmo desfecho — réplica lida, sem recusa, contados na mesma categoria.** O `kind` que é só espaço, por ser truthy, fica na primeira propriedade e não nesta; a medição de C4 é o que separa os dois.

O K de casos gerados fica com o implementador; o piso é cobrir os quatro válidos, `fs-union`, e ao menos três formas inválidas estruturalmente distintas.

O segundo ponto é o parser de `machinery.lock` (`readMachineryLock`, `bin/forge.mjs:360-374` — conferido com `grep -n "function readMachineryLock" -A 16 bin/forge.mjs`, corrigindo a citação errada da revisão anterior): sobre linhas geradas — bem-formadas, com hash curto, com hash maiúsculo, com um espaço em vez de dois, com path contendo espaço, comentário, linha vazia, linha truncada —, vale que toda linha que não casa o padrão é **contada** como inválida e cai no fallback conservador, e que `writeMachineryLock` seguido de `readMachineryLock` é identidade sobre o conjunto de paths. O contador de linhas ilegíveis já existe e já avisa (linha 372); o que falta é prova de que ele não perde entrada em silêncio.

**Teste de contrato — aplica-se, em três fronteiras publicadas.** O `enum` de `liaison-config.schema.json` contra `TRANSPORT_KINDS` (Gate 1 `[11]`, comparação de **conjunto**, nunca de contagem, com o lado do schema lido por `JSON.parse` e não por `grep`). A tabela de `rc` de `check-liaison-acks.sh`, que ganha o valor 2 e por isso é contrato com adotante instalado — `[5]`, `[6]` e `[13]` a fixam, e `[13]` é quem fixa a precedência. A tabela de `rc` de `bin/forge.mjs`, que ganha o valor 5: conferi que `1`, `2`, `3` e `4` já estão em uso (`4` é "update rodado de dentro de um worktree linkado", linha 537) e que `5` está livre.

**Integração — é onde os dois itens de fato vivem.** Nenhum dos dois defeitos é de função: `[4]` do Gate 1 é "o leitor não alcança o hub deste canal" e `[3]` do Gate 2 é "o relatório não menciona o que o laço acabou de sobrescrever". Teste unitário sobre `getTransport` ou sobre `readMachineryLock` nasce verde e não diz nada; o cenário precisa ir do `liaison.yaml` até o veredito, e do `forge update` até o disco.

**E2E — aplica-se, e é obrigatório em dois cenários.** `[9]` e `[14]` do Gate 1 são `git push` de verdade, com os hooks instalados como o instalador os instala, porque `check-liaison-acks.sh` só existe como gate por causa desse canal — e porque a medição de C8 mostra que o canal de entrega é precisamente onde o terceiro estado se perde. Sem eles, a onda teria provado a decisão e não a entrega.

**O que não se aplica, com justificativa medida.** Não há teste de carga nem de concorrência sobre o hub: o `_dir_push` já escreve por `tmp` + `mv` e a propriedade de concorrência do store é assunto do `w169`/`w198`, que esta onda não toca. E não há teste de rede: os transportes que exigiriam rede são justamente os dois que a §3 decide **não** implementar.

---

## 6. Retrocompatibilidade

**Quem já tem `fs-union` instalado (`axis-device-platform`).** Nove declarações, três arquivos. Depois desta onda, o `update` deixa de apagar o `fs-union` da lista de kinds — mas três outras coisas acontecem e precisam ser ditas antes de eles atualizarem.

Primeira: o `check-liaison-acks.sh` local deles, que delega a `lib/liaison-hub-path.sh`, será **sobrescrito** pelo nosso, porque `check-liaison-acks.sh` está entre os arquivos derivados deles (§2.3 conta 20 em `scripts/`) — a menos que o lock deles registre o arquivo, caso em que P1 o **preserva**. Os dois desfechos são aceitáveis e o relatório dirá qual ocorreu; o que não pode acontecer é o desfecho de hoje, que é sobrescrever sem dizer.

Segunda: `lib/liaison-hub-path.sh` não existe no template e não está em `installer/removed-files.txt` (`grep -c "liaison-hub-path" installer/removed-files.txt` → `0`), então o overlay não a toca e a tombstone não a remove — ela sobrevive como lib órfã até que eles decidam.

Terceira, e esta é nova nesta revisão: com C7, `validateTransport` passa a exigir `path` de `fs-union` como já exige de `fs` — de modo que uma configuração `fs-union` sem `path`, que hoje é aceita e gravada (medição em C7), passaria a reprovar no `sync` com mensagem explícita, em vez de falhar mais fundo no `t_probe`. Isso é correção e não regressão, mas é mudança de comportamento observável e entra na mensagem de canal. Medi a exposição real deles com `for f in <os três liaison.yaml>; do grep -cE '^[[:space:]]*kind:' "$f"; grep -cE '^[[:space:]]*path:' "$f"; done` → `3` e `3` nos três arquivos: **todo canal `fs-union` do parque já declara `path`**, a exposição é zero, e o que C7 muda é que a garantia passa a existir em vez de depender de o adotante ter acertado.

**Quem nunca ouviu falar de `fs-union`.** A adição é aditiva em todos os pontos: `TRANSPORT_KINDS` cresce, o `enum` cresce, um arquivo novo aparece em `transports/`. Nenhuma configuração existente muda de significado — em particular, C7 não muda nada para `fs`, `manual`, `git` ou `gh`, porque só acrescenta um nome ao lado esquerdo da mesma condição. Os 345 canais `kind: "fs"` do parque seguem idênticos.

**Quem tem canal sem bloco `transport`, ou com `kind` vazio.** Continua exatamente como hoje, por C4 — e é a decisão que mantém `w113` e `w136` verdes.

**Quem usa `--no-backup`.** Ganha uma recusa nova (rc 5) numa combinação de quatro condições cuja exposição medida hoje é zero, e ganha mensagens que param de mentir sobre onde está o backup.

**O `pre-push` de todo consumidor.** Passa a poder reprovar por rc 2, **com galho e frase próprios** (C8). Exposição medida: zero canais `git`/`gh` em 354 declarações. O primeiro que aparecer é o que reabre LDG-0100, por desenho — na máquina dele, com a ressalva de C6.

**Ordem de entrega, e ela é obrigatória.** As duas metades — `fs-union` válido e `scripts/` preservado — precisam sair na **mesma** versão. Se `scripts/` passasse a preservar antes de `fs-union` ser válido, um adotante atualizaria, preservaria o `liaison-config.mjs` local dele (o que está certo) e ficaria com uma maquinaria meio nova e meio velha por tempo indeterminado. Se `fs-union` saísse antes, o `update` continuaria apagando a adoção em silêncio por mais uma versão. Não há ordem parcial segura, e por isso as duas metades são um PR só.

---

## 7. Gates existentes que esta onda toca — varredura da invariante 15, nominal

Varri `tests/` por cada string de produção que a onda muda e por cada contador que ela desloca, com `grep -rlF` sobre cada string e `grep -rl` sobre cada script tocado. As duas primeiras linhas da tabela são achados **desta** revisão: a varredura anterior não olhou para os contadores do `README.md`, que é a armadilha A do lote.

| Gate | Cenário / linha | O que afirma | O que esta onda faz com ele |
|---|---|---|---|
| `tests/w200-readme-inventory-gate.sh` | `[6]`, linhas 258-272 | que o badge `gates-N passing` do `README.md` **real** iguala `find "$WS/tests" -maxdepth 1 -name '*-gate.sh' \| wc -l` | **EXIGE AÇÃO.** Medido hoje: badge `gates-131` (`README.md:12`) e `ls tests/*-gate.sh \| wc -l` → `131`. Os dois gates novos levam a árvore a 133 e o badge tem de ir junto, **no mesmo commit**, ou `w200[6]` fica vermelho. Entra na definição de pronto. |
| `tests/w200-readme-inventory-gate.sh` | `[1]`, linhas 53-75 | que cada `<dir>/ (N)` do bloco de estrutura do `README.md` iguala `find "template/.forge/<dir>" -type f ! -name 'README.md' \| wc -l` | **EXIGE AÇÃO.** Medido hoje: README declara `scripts/ (136)` e o `find` devolve `136`. `lib/transports/fs-union.sh` leva a árvore a 137 e a linha do README tem de ir junto, no mesmo commit. |
| `tests/w101-update-preserve-gate.sh` | 62-68 (`[4]`) | que `scripts/handoff-gen.sh` com conserto local **é sobrescrito**, e que sai `WARN: drift local em scripts/handoff-gen.sh` | **INVERTE.** O cenário `[4]` vira `[4a]` (script preservado e reportado) e `[4b]` (um arquivo de `hooks/` sobrescrito com o `WARN` corrigido). A edição é obrigatória e entra na definição de pronto. O `grep` da linha 67 casa um **prefixo**, então a troca do sufixo `.forge.bak-N` sozinha não o quebraria — o que o quebra é P1. |
| `tests/w101-update-preserve-gate.sh` | 35, 59, 73 | `= <rel>` e `= <rel> (preservado — customização local)` para `rules/` | **intocado** — a linha de `scripts/` é distinta por P1, e a de `rules/` não muda. |
| `tests/w101-update-preserve-gate.sh` | 91 | `= <rel> (tombstone pulado` | **intocado** — é a razão de P1 não usar `ENRICHABLE_DIRS`. |
| `tests/w63-forge-update-gate.sh` | 168-181 (`[f]`) | que o backup do `update` nasce em `.git/forge-backups/forge-1`, que `.forge.bak-1` **não** aparece, e que `--no-backup` não cria nenhum dos dois | **intocado** — são asserções de sistema de arquivos sobre o **destino**, e a onda muda só o texto das mensagens. A frase `backup fora da árvore` que aparece na linha 181 é `echo` do próprio gate, não `grep` da saída do produto: conferido lendo as linhas. |
| `tests/w13-init-gate.sh` | 46, 68 | `.forge.bak-\*/` no `.gitignore` gerenciado, e `[ -d "$T1/.forge.bak-1" ]` depois de `init --force` | **intocado, e é a testemunha de §2.2** — é o gate que reprovaria se a correção das mensagens vazasse para o caminho `init --force`, onde o literal está certo. |
| `tests/w153-upgrade-safety-gate.sh` | 158-160 | que alguma lib de varredura de `template/.forge/scripts/lib/` cita `forge.bak` | **intocado** — a onda mexe em `bin/forge.mjs`, não nas libs varridas. |
| `tests/w167-liaison-hub-directed-acks-gate.sh` | 68-69, 120-121 | canais `--kind fs` | **intocado** — `fs` continua com o mesmo layout e o mesmo veredito. |
| `tests/w143`, `tests/w150` | 81-82, 138-139, 215-216, 315-316 | canais `--kind fs` | **intocado**, pelo mesmo motivo. |
| `tests/w113-liaison-enforce-gate.sh` | todos os `ACK_RC` (99, 112, 123, 130, 137, 149, 159, 180, 185) | canais **sem** `transport set` (`grep -c` → 0), com rc afirmado só por `-eq 0`/`-ne 0` | **intocado por decisão explícita** — é o caso da sexta linha de C4, e M10 existe para que essa proteção seja medida e não confiada. |
| `tests/w136-session-start-liaison-acks-gate.sh` | 106 | `^OK` para um observador, canal **sem** `transport set` | **intocado**, idem. |
| `tests/w150-liaison-flag-and-trust-gate.sh` | 374-378 | `liaison-acks — N thread(s)` com N ≥ 1, extraído por `sed` que exige os dois pedaços **contíguos** | **preservado, com a restrição nomeada em §5.2** — os contadores de canal entram em linha própria, nunca entre `liaison-acks — ` e `N thread(s)`. |
| `tests/w168-liaison-log-merge-union-gate.sh` | 128 | que o `pre-push` sinaliza `NÃO VERIFICADO` quando `check-liaison-log-integrity.sh` está ausente | **intocado** — o galho novo de C8 é outro (`check-liaison-acks.sh` com rc 2), e a asserção do `w168` é sobre a mensagem do log-integrity. O token compartilhado é intencional: é o vocabulário do repositório. |
| `tests/w160-prepush-preflight-gate.sh` | 134 | `NÃO VERIFICADO` junto de `check-worktree-prereqs.sh` | **intocado**, mesma razão. |
| `tests/w135`, `w151`, `w152`, `w159`, `w191` | 45, 913/1181, 701, 12, 56 | substituem `check-liaison-acks.sh` por stub `exit 0`, ou o citam em comentário | **intocado** — não afirmam rc do script real; entram aqui porque `grep -rl "check-liaison-acks" tests/` os devolve e a enumeração de C5 precisa nomear o universo inteiro, não uma amostra. |
| `tests/w111-liaison-sync-gate.sh` | `[11]`, `[12]` | transportes `git` e `gh` no `sync` | **intocado** — a onda não muda o `sync` de `git`/`gh`, e `w111` não invoca `check-liaison-acks.sh`. |
| `tests/plugin-sync-gate.sh` | `[1]` | `plugin/forge` byte-idêntico ao regerado de `template/.forge/commands` | **EXIGE AÇÃO:** documentar `fs-union` em `commands/harness/liaison.md` obriga a rodar `npm run build:plugin` no mesmo commit — nunca `build-plugin.sh`, que instala em `$HOME`. Conferido que o espelho `plugin/forge/commands/liaison.md` existe e hoje casa linha a linha com o original nas linhas 53, 72 e 73. |

Nenhum gate afirma as strings `kind inválido: ...`, `backend de transporte ausente`, `manual|fs|git|gh`, `reconcilie à mão`, `transporte fs exige path` ou `SCOPE ` — `grep -rlF` sobre `tests/` devolve vazio para cada uma. A varredura foi feita com `grep -rn`/`grep -rlF` sobre `tests/`, `template/`, `installer/`, `bin/`, `README.md` e `.github/`.

---

## 8. O que esta onda explicitamente NÃO faz

1. **Não implementa leitura de hub `git`/`gh`.** §3 fecha o motivo, com censo.
2. **Não estende a preservação por deriva a `hooks/`, `commands/`, `schemas/`, `contracts/` ou `capabilities/`.** §2.4 P5 dá a razão de classe e o número. Abre item de ledger novo: *"decidir a política de update para `hooks/`, onde preservar um conserto local pode ser exatamente o que impede um gate corrigido de rodar — 4 de 6 consumidores com deriva medida em 2026-09-07, pelo script de §2.3"*.
3. **Não muda o `_dir_push` nem a política de união.** A 0.14.0 já une, e as issues #117, #107, #109, #108, LDG-0153 e LDG-0163 são da Onda B.
4. **Não implementa detecção persistente de deriva no `doctor`.** É LDG-0153, Onda B. Esta onda declara a fronteira em §2.3 e não a atravessa.
5. **Não reescreve os `liaison.yaml` do parque.** As nove declarações `fs-union` do `axis-device-platform` passam a ser válidas sem que ninguém edite nada; as 345 `fs` continuam corretas.
6. **Não remove `lib/liaison-hub-path.sh` do `axis-device-platform` nem escreve em consumidor nenhum.** O que a onda deve a eles é uma mensagem no canal, que é a Onda I.
7. **Não renomeia `fs-union`.** C2, com a dívida de nomenclatura declarada em vez de escondida.
8. **Não faz o `forge-harness` descobrir sozinho que um adotante declarou canal `git`.** C6 diz em letra onde a mecanização acontece e onde ela para.
9. **Não toca a suíte `tests/run-all.sh`.** Os gates são descobertos por glob (`ls tests/*-gate.sh`, `run-all.sh:48`), então nenhum arquivo de fiação muda e nenhum literal de contagem entra no repositório — as duas contagens do `README.md` são atualizadas porque o `w200` as governa, não porque a suíte as exija.

---

## 9. Ordem de implementação e definição de pronto

1. **Vermelho primeiro, e observado.** Escrever os dois gates completos, rodar cada um, e registrar a saída de cada cenário vermelho — inclusive a confirmação de que `[0]`, `[1]`, `[2]`, `[11]` do Gate 1 e `[0]`, `[2]` do Gate 2 nascem verdes e por quê. Vermelho que não foi visto não conta.
2. **`fs-union`, a tabela de layout e a validação de `path`.** `liaison-config.mjs` (`TRANSPORT_KINDS` na linha 27, `DIRECT_HUB_LAYOUT` novo, e a condição de `path` na linha 90 — C7), `transports/fs-union.sh`, `liaison-ops.sh` (linhas 36 e 1194), `schemas/liaison-config.schema.json` (`enum`, descrição do backend **e** descrição de `path`), `commands/harness/liaison.md`, `npm run build:plugin`.
3. **O leitor de hub e o terceiro estado.** `check-liaison-acks.sh`: consulta à tabela, rc 2, contadores por categoria em linha própria, denominador derivado, contadores presentes também no caminho `HUBFAIL`, e a precedência de C4-bis.
4. **O canal de entrega.** `template/.forge/hooks/git/pre-push`: galho próprio para rc 2, testado antes do galho genérico, sem alterar o desfecho de nenhum rc existente (C8).
5. **`bin/forge.mjs`.** `PRESERVED_ON_DRIFT_DIRS`, o pré-voo da recusa rc 5, a declaração `SEM REFERÊNCIA`, o rótulo de backup de três valores, e as **quatro** linhas de mensagem: 189, 640, 643 e 718.
6. **`tests/w101-update-preserve-gate.sh`.** `[4]` vira `[4a]`/`[4b]`, com o vermelho de `[4a]` observado contra a implementação anterior ao passo 5.
7. **`README.md`.** Badge de gates e a linha `scripts/ (N)` do bloco de estrutura, atualizados com os números que `w200` calcula, no mesmo commit dos arquivos que os deslocam.
8. **Mutação.** Executar M1 a M14, uma a uma, com restauração por checksum e recontrole, e colar a saída de cada uma no PR — inclusive as quatro que já têm contrafactual medido nesta spec, porque o contrafactual medido aqui é sobre o código de hoje e o da matriz é sobre o código novo.
9. **Ledger e issues.** LDG-0100 para `wont-fix` com as duas medições e a condição mecanizada (com a ressalva de C6); #123 e #101 fechadas com a evidência; o item novo de `hooks/` aberto; a correção do inventário de mensagens de §2.2 registrada no fechamento da #101, agora com quatro strings.
10. **Suíte inteira, serializada pelo orquestrador.** Nunca em paralelo com gate manual.

**Definição de pronto:** os dois gates verdes com os contadores fechando; `w101` verde com `[4a]`/`[4b]`; `w200` verde com o badge e a contagem de `scripts/` atualizados; `plugin-sync-gate` verde depois do `build:plugin`; `bash -n` limpo em tudo que for tocado, sem `declare -A`, `${var,,}`, `mapfile` ou `readarray` (bash 3.2); as catorze mutações com saída colada; nenhum literal de contagem de arquivo novo em asserção de gate; e o PR contra `develop`, sem uma linha de coautoria de IA.

---

## 10. Varredura da invariante 19 — os comandos que esta spec prescreve

A regra é que a especificação não prescreve mecanismo que ela não executou. Passei o documento inteiro procurando comando prescrito, e o resultado é este.

**Executados por mim nesta revisão, com o comando e a saída colados ao lado do número:** o `forge init` e os `forge update` das fixtures de §2.1 (alvo git) e §2.2 (alvo não-git); o `init --force` de §2.2; o `sync --push-only` nas cinco montagens de §1.3, §1.4 e §1.7, sempre com controle, restauração conferida por `cmp -s` e recontrole; o `transport set` nas cinco formas de C7, com mutação, `cmp -s` e recontrole; o `check-liaison-acks.sh` das duas montagens de C4-bis (`HUBFAIL` e recontrole com os dois hubs alcançáveis); o `pre-push` das três montagens de C8 (rc 1, rc 2 e recontrole com rc 0); o `node -e` sobre `getTransport`/`validateTransport` de C4; o censo de `_common.sh` de §1.3 e os **dois** censos de `liaison.yaml` de §1.7 (a enumeração por árvore e o `find` independente que a triangula, com o `comm` que nomeia o único arquivo de diferença); o script de preservação por lock de §2.3; o `git ls-files -- .forge/scripts` de §2.4 P3; a contagem de canais por consumidor de C4-bis; e as varreduras de §7, inclusive a que mede o badge do `README.md` contra `ls tests/*-gate.sh | wc -l` e a contagem de `scripts/` contra `find template/.forge/scripts -type f ! -name 'README.md' | wc -l`.

**Herdado da revisão anterior e reconfirmado por leitura, não por execução nova:** as três formas de `git ls-files` de §2.4 P3 e o `git diff HEAD` que sai 128. O número e o comportamento estão colados; a execução foi da rodada anterior desta mesma spec e não foi repetida agora.

**Declarados como propriedade, sem prescrever primitivo, porque eu não os executei:** o sinal positivo de execução de `[9]` e `[14]` do Gate 1; o "tree untouched" de `[4]` do Gate 2; a resposta a "o arquivo está rastreado?" (a propriedade é recuperabilidade; medi o comportamento de `git ls-files` em três estados, mas quem escolhe e prova o primitivo é o implementador); o K do PBT de `kind` gerado; e o efeito de M3 a M7, M9, M10, M12 e M14.

**Um comando que esta spec deliberadamente NÃO prescreve:** copiar o `_common.sh` armado de `~/Documents/projects/axis-go-cloud/axis-device-platform` para dentro do gate. Eu o usei em bancada para provar que o corpo destrutivo existe em campo; usá-lo no gate criaria dependência de uma árvore de consumidor que a suíte não controla e que não existe em CI. A fixture escreve o corpo mínimo ela mesma, pinada nos três pontos da nota de §4.1.

**Duas armadilhas que evitei e que valem registro.** A primeira: o censo original que rodei foi um `find` sobre `~/Documents/projects` inteiro com `| head -60`, e ele devolveu 60 arquivos — um número que parecia um total e era um corte. A segunda, desta revisão: o mesmo `find` sem `head`, sobre a árvore inteira, foi interrompido por tempo e deixou um arquivo de lista **parcial** com 29 caminhos, que teria produzido um censo de 40 declarações se eu tivesse aceitado o arquivo em vez de conferir se o comando terminou. O censo válido de §1.7 é o que enumera árvore por árvore, é rápido, e cujo comando termina. Número que vem de saída truncada — por `head` ou por interrupção — é a forma mais barata de uma spec mentir com precisão.

---

## 11. Respostas ao veredito da revisão 1

Remedi cada afirmação do revisor com comando próprio antes de aceitá-la. Três eu refutei com medição, e as refutações estão abaixo com o comando que as sustenta.

### 11.1 Bloqueadores — todos fechados

**Bloqueador 1 (inventário de mensagens incompleto — a quarta string).** **Aceito, e reproduzido por mim.** A bancada de §2.2 mostra a mesma execução dizendo `.forge.bak-2` na linha 3 e `.git/forge-backups/` na linha 33, num alvo onde `.git/forge-backups/` não existe. `bin/forge.mjs:718` entrou na tabela de §0, no inventário de §2.2 (que agora lista as dez ocorrências de `forge.bak`, com o veredito de cada uma), em P4 e no passo 5 de §9. A frase "são três strings erradas" virou **quatro**. E o cenário `[6]` do Gate 2 foi reescrito: ele agora nomeia explicitamente as quatro mensagens que examina e afirma que **nenhuma** delas pode citar `.git/forge-backups/` quando o alvo não é repositório git — o que o faz nascer **vermelho**, não verde. A tabela de §4.2 e a matriz (M8) foram corrigidas junto.

**Bloqueador 2 (fixture armada não pinada).** **Aceito.** A nota de §4.1 agora fecha em letra que a fixture pina três coisas: o `_dir_push` destrutivo, um `lib/liaison-config.mjs` cujo `TRANSPORT_KINDS` **não** contém `fs-union`, e a **ausência** de `lib/transports/fs-union.sh`. A frase que atribuía a M1/M2 a prova de `[2]` foi removida; no lugar entrou **M14**, que desarma a fixture (dá a ela um `liaison-config.mjs` que conhece `fs-union` e o backend) e cujo contrafactual é `[2]` acusar. M1 ganhou a cláusula explícita de que **não** pode derrubar `[2]`, que é o teste de que o pinamento funcionou.

**Bloqueador 3 (PBT #1 contradiz C4).** **Aceito, com a medição que refina o achado.** Medi com `node -e` sobre `liaison-config.mjs` e a saída está em C4: `""` devolve `null` em `getTransport`, mas `" "` (um espaço) é truthy e chega a `validateTransport`, que o reprova. São desfechos diferentes, e o revisor tratou os dois juntos. A propriedade de §5.3 foi reformulada para **"todo `kind` NÃO-VAZIO produz um de três desfechos"**, a string vazia foi excluída do espaço gerado **com o motivo medido colado**, e nasceu uma segunda propriedade própria para o caso vazio — que ele, `transport` sem `kind` e canal sem bloco `transport` produzem os três o mesmo desfecho e caem na mesma categoria do contador. A sexta linha de C4 foi reescrita para nomear os três.

**Bloqueador 4 (tabela de rc sem valor para caso alcançável — multi-canal).** **Aceito, e o caso é comum como o revisor diz.** Medi os canais declarados por consumidor: 3, 3, 3, 2 e 1. C4 deixou de se intitular "exaustivos com o rc de cada um" e virou uma tabela **por canal**, com a categoria de contador de cada estado; nasceu **C4-bis** com a regra de precedência (`HUBFAIL` > ack pendente > `NÃO VERIFICADO`) e com o argumento que a sustenta — os três bloqueiam igual, então a precedência escolhe a frase, e a frase certa é a da dívida acionável. Medi também o caminho `HUBFAIL` e confirmei que ele retorna antes de qualquer contagem sair (`linhas com "thread(s)" = 0`, contra `1` no recontrole com os hubs alcançáveis); a decisão de fazer os quatro contadores saírem **também** nesse caminho está escrita, e §5.2 foi corrigida para prometer contadores de **canal** em toda saída e a linha `SCOPE` só onde houve varredura. Nasceu o cenário `[13]`, com dois canais em estados diferentes, mais uma terceira montagem que exercita `HUBFAIL` com contadores; e M12 é a mutação que o mede.

**Bloqueador 5 (a adição não é aditiva — `path` de `fs-union`).** **Aceito, e medido com controle, mutação e recontrole.** A saída está em C7: com `fs-union` só em `TRANSPORT_KINDS`, `transport set --kind fs-union` **sem** `--path` responde `OK` com rc 0 e grava `kind: "fs-union"` sem `path`, enquanto `--kind fs` sem `--path` reprova. Uma correção de citação: a condição está em `liaison-config.mjs:**90**`, não 89 — `grep -n` sobre o arquivo devolve `90:  if ((t.kind === 'fs' || t.kind === 'manual') && !t.path)`. Nasceu **C7**, a linha 90 e a descrição de `path` no schema entraram na tabela de §0 e no passo 2 de §9, `[10]` ganhou a asserção da ausência de `path`, e **M11** a mede.

**Bloqueador 6 (o terceiro estado chega com a frase do segundo).** **Aceito, e medido.** Bancada com repositório git mínimo e o `check-liaison-acks.sh` substituído por stub: rc 1 e rc 2 produzem a **mesma** frase (`pre-push BLOQUEADO: liaison — ack pendente`), e o rc do hook colapsa em 1 nos dois; recontrole com rc 0 devolve rc 0. A decisão foi **dar galho próprio ao rc 2** — não registrar que a frase genérica basta —, e ela está em **C8**, com a alternativa descartada dita. `template/.forge/hooks/git/pre-push` entrou na tabela de §0, virou o passo 4 de §9 e está na varredura de §7. Nasceu o cenário `[14]`, E2E por `git push` real com um canal `git`, e **M13** o mede — com a cláusula de que a mutação **não** pode derrubar `[9]`, que é rc 1.

### 11.2 Medições que não reproduziram — remediadas ou removidas

Nove itens. **Sete remediados com comando colado, dois removidos.** Nenhum número ficou sem comando.

| Item do veredito | Desfecho | O que mudou |
|---|---|---|
| §2.3, tabela de preservação por lock | **remedida** | O script inteiro está colado em §2.3, com o critério que o revisor teve de inventar agora escrito. Rodei e reproduzi **exatamente** os números dele: 26 / 23 / **35** / 0 / 0 / **20**. Os 34 e 16 da revisão anterior eram meus e estavam errados; a tabela foi corrigida, os `rules`/`agents` que o script devolve entraram com a nota de que já são `ENRICHABLE` hoje, e a asserção do gate passou a ser propriedade mais piso ("pelo menos um consumidor de cada lado"), nunca os seis números. As menções a "16" em §6 viraram 20. |
| §1.7, censo do parque | **remedida, e triangulada** | Comando de enumeração por árvore colado. Números novos: 190 árvores, **144** arquivos, **354** declarações, **345** `fs`, 9 `fs-union`, zero `git`/`gh`/`manual`. E rodei um segundo método independente, um `find` que não enumera nada: ele devolve **143/344/9**, que são exatamente os números do revisor. O `comm` entre as duas listas nomeia a diferença inteira — **um** arquivo, `/private/tmp/forge-baseline-wt/.forge/liaison/liaison.yaml`, um worktree de `forge-harness` fora de `~/Documents/projects` que só a enumeração por `git worktree list` alcança. Os dois métodos e os dois comandos estão colados em §1.7, e as leituras decisivas batem exatamente entre eles. As menções a "342" e "351" no resto do documento foram atualizadas. |
| §1.3, censo do `axis-device-platform` | **remedida** | Comando colado. Números novos, reproduzindo o revisor: **33** árvores, **18** com um `_common.sh` e **13** com o armado, 13 armadas, zero conhecendo `fs-union`, **2** sem `liaison-config.mjs`. Acrescentei a prova do corpo (`sed -n '/_dir_push()/,/^}/p'`, 51 linhas, `cp` + `mv` incondicional) e a frase que diz que a asserção do gate usa piso um, não os números. |
| §2.1, "linhas do log total: 30" | **remedida, e o literal saiu da asserção** | Rodei de novo com o comando colado e o **30 reproduz** — num alvo **git** com `--no-plugin`. A minha própria bancada não-git deu **33**, que é o que o revisor obteve. O texto agora diz que o número é testemunha de fixture e de quais três coisas ele depende, e a coluna "o vermelho de hoje" do cenário `[3]` do Gate 2 passou a trazer `<N>` **interpolado do log**, com nota obrigatória proibindo fixá-lo. |
| §1.3 "ARM D" e §1.4 "ARM T2" | **remedidas** | Executei as duas nesta revisão, com a árvore armada extraída de `cert-validity`, hub de controle restaurado antes de cada rodada, sha do hub conferido depois de cada uma, `cmp -s` provando que a mutação de `TRANSPORT_KINDS` não foi fantasma, e recontrole final que faz o dano voltar. Saídas coladas em §1.3 e §1.4. |
| §1.7, alternativas A e B | **remedidas** | Executei as duas, com hub de controle, restauração conferida por `cmp -s` e recontrole final. A alternativa A **destrói o hub com rc 0** (o argumento decisivo do documento agora é medição minha, não leitura); a B reprova com `campo desconhecido em transport: policy` e hub intacto. Saída colada em §1.7. |
| §2.4 P3, "os seis consumidores rastreiam `.forge/scripts` (98 a 721)" | **remedida** | Comando `git -C <repo> ls-files -- .forge/scripts \| wc -l` colado, com os seis números (233/313/155/721/98/183). A asserção virou propriedade mais piso: "todo consumidor conhecido rastreia pelo menos um arquivo sob `.forge/scripts`". |
| §2.2, "as linhas 182, 764 e 777 estão corretas" | **remedida** | Executei `init --force` num alvo git: o backup vai para `.forge.bak-1` **dentro** da árvore e `.git/forge-backups/` não existe. Saída colada, e `tests/w13-init-gate.sh:68` entrou em §7 como o gate que reprovaria se a correção vazasse para esse caminho. |
| Gate 1 `[9]` e Gate 2 `[4]` | **mantidos como propriedade** | O revisor está certo de que não os executei, e a spec nunca os prescreveu como comando. Estão declarados em §10 na lista de "propriedade sem primitivo", e a nota de `[9]`/`[14]` diz o que o implementador tem de provar. |

Duas afirmações da revisão anterior foram **removidas** em vez de remedidas, porque não sobreviveram à remedição: a atribuição a M1/M2 da prova do cenário `[2]` (bloqueador 2) e a frase de C5 que dava por exaustiva uma varredura de rc feita sobre dois gates — o universo real é de dez gates que referenciam `check-liaison-acks.sh`, e C5 agora os nomeia e diz o que cada um faz.

### 11.3 Refutações com medição

Três afirmações do revisor eu refuto, e as três com comando.

**1. O token `NÃO VERIFICADO` do `pre-push` está na linha 143, não 142.** `grep -n "NÃO VERIFICADO" template/.forge/hooks/git/pre-push` devolve `143` e `181`. A citação da revisão anterior estava certa; a correção proposta a deslocaria.

**2. `readMachineryLock` vai de 360 a 374, não de 359 a 372.** `grep -n "function readMachineryLock" -A 16 bin/forge.mjs` mostra a assinatura em `360` e o `}` de fecho em `374`; a linha 359 é a terceira do comentário de cabeçalho. A revisão anterior citava 366-379, que também estava errado — corrigi para **360-374**, que é o que a medição diz.

**3. A condição de `path` em `validateTransport` está na linha 90, não 89.** `grep -n` sobre `liaison-config.mjs` devolve `90:  if ((t.kind === 'fs' || t.kind === 'manual') && !t.path)`; a linha 89 é o `}` que fecha o `if` do `kind` inválido. O bloqueador 5 continua inteiramente válido — só a linha muda.

Sobre a citação de "hub inacessível reprova incondicionalmente": nem 245-247 (revisão anterior) nem 246-250 (revisor) descrevem o bloco inteiro. O comentário que enuncia a política está em **245-247** e o `case` que a executa está em **248-255**; a spec agora cita os dois.

### 11.4 As cinco armadilhas, varridas na spec inteira

**A — literal que envelhece em asserção, inclusive contadores do README e badges.** Achado, e é o achado desta varredura. `README.md:12` traz o badge `gates-131 passing`, e `tests/w200-readme-inventory-gate.sh:258-272` compara esse número com `find "$WS/tests" -maxdepth 1 -name '*-gate.sh' | wc -l` sobre a árvore **real** — medido hoje: `ls tests/*-gate.sh | wc -l` → `131`. Os dois gates novos levam a 133 e deixam `w200[6]` vermelho se o badge não for junto. O mesmo gate, no cenário `[1]`, compara `scripts/ (136)` do bloco de estrutura com `find template/.forge/scripts -type f ! -name 'README.md' | wc -l` → `136` hoje; `lib/transports/fs-union.sh` leva a 137. As duas linhas entraram na tabela de §0, viraram o passo 7 de §9 e estão na definição de pronto. Fora isso, varri as asserções propostas: o único literal que permanece numa asserção é o `DECLARADOS` de cada gate, que é a exceção da invariante 14, e o `30` de §2.1 saiu da coluna de vermelho do cenário `[3]` para virar contador interpolado.

**B — string de produção mudada sem varrer `tests/`, e sem o espelho em `plugin/forge`.** Varri com `grep -rlF` cada string que a onda muda. Achados: `WARN: drift local` só em `w101`; `.forge.bak-N` em `w63` e `w13`; `backup fora da árvore` em `w63` — mas conferi lendo que ali é `echo` do próprio gate na linha 181, não `grep` da saída do produto, então a linha 718 pode mudar sem quebrá-lo; `liaison-acks —` em `w150`, com a restrição de contiguidade do `sed` da linha 376 agora nomeada em §5.2; `NÃO VERIFICADO` em `w160` e `w168`, sobre outros checks. E o espelho: `plugin/forge/commands/liaison.md` existe e hoje casa com `template/.forge/commands/harness/liaison.md` nas linhas que a onda toca (53, 72, 73), de modo que documentar `fs-union` obriga `npm run build:plugin` no mesmo commit — está em §7 e na definição de pronto, com a proibição de `build-plugin.sh` (que instala em `$HOME`).

**C — linha de matriz de mutação sem contrafactual medido.** A matriz tem catorze linhas. Quatro trazem contrafactual **medido por mim** (M1, M2, M8, M11, com controle, `cmp -s` e recontrole) e dez estão declaradas como propriedade + contrafactual esperado, com a obrigação explícita — repetida no passo 8 de §9 — de o implementador medir antes de escrever a linha. Nenhuma linha afirma efeito que ninguém observou; onde eu não medi, o texto diz "a ser medido" e diz o que a mutação separa.

**D — enumeração que se diz exaustiva.** Duas encontradas e as duas corrigidas. C4 se dizia "exaustiva com o rc de cada um" sendo uma tabela por canal — virou tabela por canal, com C4-bis carregando o rc. C5 dizia ter conferido "toda asserção de rc" citando dois gates — agora enumera os dez que `grep -rl "check-liaison-acks" tests/` devolve, diz que cinco usam stub, e cola o `grep -rn -- "-eq 1 \]" tests/` que mostra que nenhuma das dez ocorrências é rc deste script. Varri o resto do documento por outras enumerações: §8 (o que a onda não faz) e §10 (comandos) são listas abertas por construção e não se declaram exaustivas; a tabela de §2.2 agora enumera **todas** as dez ocorrências de `forge.bak` em `bin/forge.mjs`, com o veredito de cada uma, e não uma seleção.

**E — prescrição de comando que nunca executei.** §10 foi reescrita e separa três categorias: executado nesta revisão com saída colada, herdado da revisão anterior e reconfirmado por leitura (só os `git ls-files`/`git diff HEAD` de P3), e declarado como propriedade sem primitivo. Tudo que estava na primeira categoria por herança e que o revisor não conseguiu reproduzir foi ou reexecutado agora (ARM D, ARM T2, alternativas A e B, `init --force`, preservação por lock, os dois censos) ou movido para a terceira. E a §10 ganhou o registro da segunda armadilha de truncamento desta rodada — o `find` interrompido que deixou uma lista parcial de 29 caminhos e teria produzido um censo de 40 declarações se eu tivesse aceitado o arquivo em vez de conferir se o comando terminou.
