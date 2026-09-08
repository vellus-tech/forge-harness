# Onda L6 — prosa que contradiz o código, e três defeitos isolados (especificação implementável)

Autor: especificador do subgrupo L6 da Onda L. Data da revisão 2: **2026-09-08** (a revisão 1 é de 2026-09-07 e toda medição abaixo foi refeita hoje). Base medida: branch `feat/fase1-dogfood-completo`, `v0.14.0` publicada no npm. Tamanho da suíte hoje, com o comando: `find tests -maxdepth 1 -name '*.sh' | wc -l` → **132**, e `find tests -maxdepth 1 -name '*-gate.sh' | wc -l` → **131**, que é o denominador do badge. Os dois números envelhecem a cada gate novo e **nenhuma asserção desta onda depende deles** — estão aqui como referência datada, e §6 diz o que se atualiza no commit.

Escopo: issues **#126** (o cabeçalho do `_common.sh` afirma que `behind` é recusado e o código o une), **#127** (a varredura de vazamento do `doctor` desce em `.forge/worktrees/` e o predicado mede menção de texto como se fosse configuração), **#140** (o gate A4 `native-control` reprova o componente criado para pagar a dívida que ele mede) e **#145** (`/forge:pentest scan` não alcança o toolchain vendorizado pelo consumidor).

Esta especificação é para ser executada, não lida. Toda afirmação numérica abaixo traz **o comando que a produziu, colado ao lado do número**, e toda saída colada veio de uma execução minha, hoje, em bancada sob `$TMPDIR` com o `cwd` dentro da fixture. **Nenhum gate da suíte foi executado na elaboração** — `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio, com log vazio. As únicas execuções contra a árvore real deste repositório foram leituras (`grep`, `find`, `git ls-tree`), nenhuma escrita; as escritas foram todas em `$TMPDIR`.

### O instrumento de medição, antes das medições — e ele estava quebrado

O orquestrador registrou como LDG-0177 que `template/.forge/scripts/lib/secret-scan.mjs` é invisível a `grep` sem `-a`, e mandou provar que toda varredura de ausência conseguiu **ler o universo**. Fui medir e o achado é maior do que o registrado, porque a causa não é só o arquivo:

```
$ type grep
grep is a shell function from ~/.claude/shell-snapshots/snapshot-zsh-<id>.sh
$ declare -f grep | grep -o 'ARGV0=ugrep .*--exclude-dir=.sl'
ARGV0=ugrep "$_cc_bin" -G --ignore-files --hidden -I --exclude-dir=.git … --exclude-dir=.sl
```

**O `grep` da sessão do agente não é `/usr/bin/grep`: é uma função de shell que delega a `ugrep` com `-I` (pula arquivo binário) e `--ignore-files` (respeita `.gitignore`/`.ignore`).** Medido com controle positivo, plantando `<PROJECT_CANARIO>` dentro do `secret-scan.mjs` de uma instalação limpa em `$TMPDIR`:

```
$ /usr/bin/grep -rl '<PROJECT_CANARIO>' "$R/.forge"        → .forge/scripts/lib/secret-scan.mjs   ← ACHA
$ /usr/bin/grep -rn '<PROJECT_CANARIO>' "$R/.forge"        → Binary file .forge/scripts/lib/secret-scan.mjs matches   ← acha, SEM número de linha
$ /usr/bin/grep -arn '<PROJECT_CANARIO>' "$R/.forge"       → .forge/scripts/lib/secret-scan.mjs:254:// <PROJECT_CANARIO>
$ grep -rl '<PROJECT_CANARIO>' "$R/.forge"                 → (vazio)   ← o wrapper da sessão PULA, sem uma linha de aviso
$ grep -arl '<PROJECT_CANARIO>' "$R/.forge"                → .forge/scripts/lib/secret-scan.mjs
```

Três consequências, e as três mudam o que esta especificação pode afirmar:

1. **A auditoria por texto desta rodada rodou num instrumento com dois filtros silenciosos.** `-I` pula binário; `--ignore-files` pula arquivo casado por `.gitignore`. Uma varredura que devolveu vazio pode ter devolvido vazio por qualquer dos dois, e nenhum dos dois imprime aviso.
2. **A linha de produção do `doctor` não é cega**, ao contrário do que a generalização de LDG-0177 sugere: ela usa `grep -rl`, e `/usr/bin/grep -rl` **reporta** o arquivo binário (é o `-n` que perde o número de linha, e é o wrapper da sessão que pula o arquivo inteiro). Medido acima, com o canário plantado e removido, e com recontrole: `/usr/bin/grep -rl '<PROJECT_CANARIO>' "$R/.forge"` → vazio depois da restauração.
3. **Toda varredura de ausência desta especificação foi refeita com `/usr/bin/grep -a`**, e cada uma vem com o censo do seu universo. Censo do universo, medido hoje: `for f in tests/*; do file -b "$f" | grep -q '^data' && echo "$f"; done` → **nenhum** arquivo de `tests/` é ilegível como texto; a mesma varredura sobre `template/.forge` devolve **exatamente um**, `template/.forge/scripts/lib/secret-scan.mjs`. É o universo inteiro do risco, e ele está nomeado.

**A invariante 19 do plano-mestre governa o que segue.** A especificação declara a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir; quem escolhe o primitivo é o implementador, que executa, e ele tem a obrigação de provar que o primitivo escolhido discrimina — com controle e recontrole. Comando exato só aparece abaixo quando veio de uma execução minha, com a saída colada.

A revisão 1 reprovou por dois bloqueadores e listou nove medições sem lastro. As respostas item a item estão em §9; o corpo abaixo já está corrigido, e as duas decisões que os bloqueadores derrubaram — D3 e D6 — foram **reescritas sobre medição nova**, não emendadas.

---

## 0. Resumo do que muda

| Peça | Arquivo | Natureza |
|---|---|---|
| Cabeçalho vira contrato executável de desfechos; a prosa que contradiz é marcada como histórica | `template/.forge/scripts/lib/transports/_common.sh` | comentário; **zero mudança de comportamento** |
| As **duas** varreduras (vazamento e órfãos) passam a ter universo por **inclusão** da fonte canônica de configuração — diretórios diferentes em cada uma, mais os oito arquivos canônicos de topo do `.forge/` nas duas —, com terceiro estado declarado por universo | `template/.forge/scripts/doctor.sh` | predicado novo, mensagens de OK inalteradas |
| Aviso de `tool_dir` com toolchain em disco e `runtime.pentest` ausente | `template/.forge/scripts/doctor.sh` | linha informativa nova, nunca `miss` |
| A4 deixa de ser receita `rg` e vira scanner determinístico que reconhece os dois escapes da regra 12 | `template/.forge/skills/frontend-ui-review/SKILL.md` + `scripts/scan-native-controls.py` (novo) | instrumento novo, classificação advisory declarada |
| Nome da imagem derivado do `tool_dir`, tag configurável nunca `latest`, contrato do entrypoint verificado antes de executar | `template/.forge/scripts/pentest-ops.sh` | contrato de configuração ampliado, rc 4 novo no perfil mobile |
| Contrato do entrypoint documentado, com espelho regenerado | `template/.forge/commands/waves/pentest.md` + `plugin/forge/commands/pentest.md` | documentação de contrato implícito que passa a ser explícito |
| Gate do contrato executável de desfechos do push | `tests/w<NNN>-transport-contract-coherence-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Gate do universo do doctor | `tests/w<NNN>-doctor-scan-universe-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Gate do A4 discriminante | cenários novos em `tests/w96-frontend-ui-review-gate.sh` | gate existente, ampliado — **sem ordinal novo** |
| Gate do contrato de imagem e de entrypoint do pentest | `tests/w<NNN>-pentest-image-contract-gate.sh` (novo) | ordinal alocado pelo orquestrador |

Ordinais: o máximo publicado é **w207**, remedido em 2026-09-08 em todas as refs (`git for-each-ref refs/remotes` lista `origin/develop`, `origin/main`, `origin/wip/deepspec-run-manifest-ldg-0165` e `origin/wip/upgrade-safety-ldg-0131`, e as locais são `develop`, `main` e `feat/fase1-dogfood-completo`) com `for b in origin/develop origin/main HEAD feat/fase1-dogfood-completo origin/wip/deepspec-run-manifest-ldg-0165 origin/wip/upgrade-safety-ldg-0131; do git ls-tree -r --name-only "$b" tests/ | grep -oE '/w[0-9]+' | sed 's|/w||' | sort -n | tail -1; done` → `207, 207, 207, 207, 80, 154`. Os três ordinais desta onda **não são alocados aqui**: a invariante 10 do plano-mestre atribui a alocação ao orquestrador, no momento de escrever o arquivo, contra `origin/*` **e** contra as branches em voo desta rodada.

---

## 0.1 A régua da onda — o que reproduziu, o que não reproduziu, e o que isso muda

A primeira obrigação deste subgrupo era reproduzir cada defeito na árvore do produtor antes de especificar correção, porque várias issues da Onda L descrevem a cópia **instalada** no consumidor, que diverge do template por caminhos que o próprio backlog registra (LDG-0161, #101, #131). O resultado da reprodução muda o desenho de um dos quatro itens e precisa vir antes de tudo.

| Item | Reproduz no `template/`? | Consequência |
|---|---|---|
| **#126** | **Sim, integralmente.** O cabeçalho em `_common.sh:19-20` afirma que recusar é a única saída para `behind`, "inclusive sob reparo"; o `case 1` de `_dir_push` une e devolve `0`. Medido por execução em §1.1 | correção no template, como a issue pede |
| **#127 (custo)** | **Sim, no código; não, no estado desta árvore.** As linhas `doctor.sh:115` e `:119` varrem `$ROOT/.forge` inteiro e filtram apenas a saída, exatamente como a issue descreve (a numeração da 0.6.0 era `:100`/`:104`). O `.forge/` **desta** árvore tem 345 arquivos e `worktrees/` vazio (`find .forge -type f | wc -l` → 345 e `find .forge/worktrees -type f 2>/dev/null | wc -l` → 0, medidos em 2026-09-08), então aqui o custo não morde — ele morde em qualquer consumidor com worktree, e §2.1 mede um com 5.973.514 arquivos sob `.forge/worktrees/` | correção no template; a reprodução do custo exige fixture com worktrees, e ela está em §2.1 |
| **#127 (predicado)** | **Sim, e está VIVO nesta árvore.** A linha de produção, rodada em leitura contra o `.forge/` da raiz, acusa **14 arquivos**, todos blobs, logs `.jsonl` e `CHANNEL.md` do liaison. Nenhum é configuração. Medido em §2.2 | correção no template, e o produtor é a primeira vítima |
| **#140** | **NÃO.** O script `check-frontend-design-system.sh` **não existe no `template/`** e não está no `machinery.lock` de consumidor nenhum: ele é gate **local** do `azim-crm`, 871 linhas, escrito lá. O harness não produz o instrumento que a issue reprova. Medido em §3.1 | **o achado mais importante desta onda.** A correção do script não é do produtor; o que é do produtor é a regra 12, a receita A4 da skill e a classificação — e §3.2 mede que a metade do template é pior do que a issue supõe: a receita A4 (`SKILL.md:89-91`) tem **poder discriminante zero** entre controle domado e não-domado |
| **#145** | **Sim, os três, verbatim.** `PENTEST_IMAGE="forge-pentest"` em `pentest-ops.sh:26`; `:latest` em **nove** sítios — `/usr/bin/grep -an ':latest' template/.forge/scripts/pentest-ops.sh` devolve as linhas 180, 181, 221, 222, 224, 226, 233, 261 e 281, e `/usr/bin/grep -ao ':latest' template/.forge/scripts/pentest-ops.sh | wc -l` devolve 9 —, incluindo o `docker build -t` de `:224`; e `pentest-scan "/work/$apkbase" /out` em `:261-262`, sem uma linha de contrato em `SKILL.md`, no engine ou em template de Dockerfile — o harness **não entrega Dockerfile de pentest nenhum** (`find template -iname '*ockerfile*'` devolve só `hooks/pre-commit/check-dockerfile-multiarch.sh`) | correção no template, como a issue pede |

**O que o achado negativo de #140 significa em letra, porque ele redistribui trabalho.** Ou a cópia do consumidor está defasada, ou o defeito é de instalação e não de produto, e a correção muda de lugar — e aqui é a terceira possibilidade, mais simples e mais incômoda: **o artefato nunca foi do produto.** O consumidor escreveu um gate próprio, ancorou-o na regra 12 que o harness distribui, e mediu contra o harness um defeito que é dele. Fechar a issue "corrigindo o A4" no template seria fechá-la sobre um arquivo que não existe aqui. O que o produtor deve a esta issue é o que ele de fato produz — e §3 mostra que essa parte está pior do que o relato.

---

## 1. ITEM 1 — issue #126

### 1.1 A contradição, reproduzida por execução

O cabeçalho de `template/.forge/scripts/lib/transports/_common.sh`, linhas 19-20, no arquivo de sha256 `50f684c86a57114a6ba46362e568109c7cf3ac8097709d936c683ca890744da5` com 239 linhas (`shasum -a 256 template/.forge/scripts/lib/transports/_common.sh` e `wc -l < …`, medidos em 2026-09-08):

```
#   behind   — o hub tem um `msg_id` que esta réplica NÃO tem. Publicar apaga uma mensagem que só
#              existe lá. É a issue #101, e recusar é a única saída — inclusive sob reparo.
```

O `case 1` de `_dir_push` (linhas 165-179 do mesmo arquivo) une e devolve `0`, e o comentário local diz isso por extenso. Não há ambiguidade de leitura: as duas afirmações estão vivas no mesmo arquivo, a 150 linhas de distância, e são contraditórias.

Reprodução por execução, refeita em 2026-09-08 em bancada sob `$TMPDIR`, com o `cwd` dentro da fixture e o `_common.sh` real carregado por `.` a partir de um arquivo de script real — hub com `axis-0001,axis-0002,axis-0003`, réplica com `axis-0001,axis-0002,axis-0009`. O script da bancada, na íntegra, porque a assinatura de `_dir_push` é uma armadilha (abaixo):

```bash
#!/usr/bin/env bash
set -uo pipefail
export LIAISON_SELF=axis
export LIAISON_CHANNEL_DIR="$L/rep"          # OBRIGATÓRIO: _dir_push lê a origem daqui, não de argumento
. "$REPO/template/.forge/scripts/lib/transports/_common.sh"
out="$(_dir_push_classify "$L/hub" "$L/rep/log/axis.jsonl")"; rc=$?
echo "classify rc=$rc stdout=[$out]"
_dir_push "$L/hub"; prc=$?                    # UM argumento só — o hub
echo "push rc=$prc"
```

```
classify rc=1 stdout=[behind axis-0003]
OK liaison-push-union: hub=3 local=3 união=4
push rc=0
hub tem axis-0003 (só do hub)?  1
hub tem axis-0009 (só da rep)?  1
linhas no hub: 4
```

**`behind` é classificado, o push devolve `0`, e o hub termina com a união das duas árvores.** O comportamento é o certo — é o que `w198` trava e o que `axis-go-cloud-0086` cobrou do campo. Errada é a prosa.

Uma armadilha de bancada que custou uma iteração e vale como aviso ao implementador, porque ela produz um falso vermelho: `_dir_push_union` resolve o módulo por `libdir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`, e quando o `_common.sh` é carregado a partir de um comando passado por `-c` o `BASH_SOURCE[0]` não é o arquivo do transporte — a resolução cai no diretório do script efêmero, o módulo "não existe", e o push recusa com `rc=1` por indisponibilidade de `node`. Lido de fora, isso parece confirmar o cabeçalho. **A reprodução tem de rodar a partir de um arquivo de script real**, e a segunda armadilha é o campo do JSON: o módulo exige `sender`, não `from`, e recusa com `exit 4` (`log local linha N tem sender="…"`) quando o esquema está errado — outra recusa que, lida sem cuidado, "confirma" a prosa. E uma terceira, medida na revisão 2 e que custou uma execução: **`_dir_push` recebe UM argumento, o diretório do hub** (`_common.sh:138-140`), e lê a origem de `$LIAISON_CHANNEL_DIR`. Chamá-lo como `_dir_push "$hub" "$own"`, que é a forma que a leitura casual do `_dir_push_classify` sugere, morre com `_common.sh: line 140: LIAISON_CHANNEL_DIR: unbound variable` sob `set -u` — mais uma recusa que, lida sem cuidado, "confirma" o cabeçalho. As três foram observadas antes da medição final e estão registradas aqui exatamente para que o implementador não as tome por comportamento.

### 1.2 A tabela de desfechos, medida e com exaustividade procurada

A invariante 17 do plano-mestre exige que toda enumeração de estados procure ativamente o caso não coberto. Rodei oito na revisão 1 e **um nono na revisão 2**, procurando de novo; três deles não são deduzíveis do cabeçalho:

| Estado da fixture | `_dir_push_classify` | `_dir_push` | Efeito no hub |
|---|---|---|---|
| local é superconjunto do hub | `ff`, rc 0 | rc 0 | une (2 linhas) |
| hub tem `msg_id` que a réplica não tem | `behind axis-0003`, rc 1 | **rc 0** | **une** (3 linhas: preserva a do hub e publica a da réplica) |
| mesmo `(sender,seq)` com `content_sha` distinto | `diverged axis-0002`, rc 2 | rc 1 | **intacto** — recusa |
| idem, com `LIAISON_PUSH_REPAIR=1` | `diverged axis-0002`, rc 2 | rc 0 | substituído pela versão local |
| hub **sem** log do remetente | `ff`, rc 0 | rc 0 | criado (1 linha) |
| hub com log de **zero byte** | `ff`, rc 0 | rc 0 | criado (1 linha) — o `-s` em vez de `-f` é deliberado e está comentado no arquivo |
| log próprio com mensagem de **terceiro** | `ff`, rc 0 | **rc 1** | intacto — `FAIL liaison-push-union: log local linha 2 tem sender="outro"` |
| log local com **JSON ilegível** | `ff`, rc 0 | **rc 1** | intacto — `FAIL liaison-push-union: log local linha 2 não é JSON válido` |
| **`node` ausente do `PATH`** (ou o módulo de união ausente) | `ff`, rc 0 | **rc 1** | intacto — `FAIL: push RECUSADO — a união do log exige node e '<mod>', e um dos dois não está disponível.` |

As três últimas linhas são o caso que o cabeçalho não enumera e que nenhuma leitura da prosa antecipa: a classificação diz `ff` — o estado mais benigno — e o push recusa mesmo assim, porque a recusa vem do módulo de união e não do classificador. **Um leitor que confie no cabeçalho conclui que `ff` sempre publica.** É o mesmo defeito de ensino da issue, por uma segunda porta, e é por isso que a correção não pode ser "arrumar duas linhas".

**O nono estado é achado da revisão 2 e ele não estava na revisão 1**, o que é a própria invariante 17 aplicada de novo em vez de dada por cumprida. Medido em bancada com um `PATH` reduzido a `bash sed awk grep cat cp mv mkdir find wc sort dirname basename`, sem `node`:

```
classify rc=0 stdout=[ff]  (esperado: ff, rc 0)
FAIL: push RECUSADO — a união do log exige node e '<repo>/template/.forge/scripts/lib/liaison-push-union.mjs', e um dos dois não está disponível.
      Publicar sem unir SUBSTITUIRIA o log do hub por esta réplica, apagando mensagem já
      publicada por outra réplica da mesma identidade (issue #101). Não saber unir é
      motivo de rigor, não de publicação.
push rc=1
```

Ele importa por dois motivos independentes. Primeiro, é a **terceira** porta pela qual `ff` não publica, e o cabeçalho de hoje não enumera nenhuma das três. Segundo, e mais grave, ele colapsa dois estados que a invariante 2 do plano-mestre separa: `_dir_push` devolve **rc 1** tanto para "recusei porque há bifurcação" (`_common.sh:184`) quanto para "não consegui unir porque falta ferramenta" (`:105`) quanto para "não consegui classificar" (`:199`). "Não encontrei violação", "encontrei violação" e "não consegui verificar" têm o mesmo código de saída aqui. **Esta onda não muda esse rc** — §7 diz por quê —, mas o contrato de D1 declara os três desfechos com a causa nomeada, que é o que o leitor precisa e é o que hoje não existe em lugar nenhum, e §7 abre o item de ledger.

Um décimo desfecho, achado na varredura e deliberadamente **fora do escopo desta onda**: `_dir_push_classify` chamado com o log próprio **ausente** faz o `awk` falhar e devolver `rc=2`, que o `case` de `_dir_push` leria como `diverged`. Em produção o caminho é inalcançável, porque `_dir_push` guarda com `[ -f "$own" ]` antes de chamar. Registro o achado, não o corrijo aqui, e §7 diz por quê.

### 1.3 O dano é de ensino, e o canal por onde ele chega é a leitura

Este item é de natureza diferente dos outros três desta onda, e a especificação precisa dizer isso: **não há execução que produza o dano.** O `_common.sh` de hoje faz a coisa certa em todos os nove estados acima — inclusive no nono, em que recusar por não saber unir é a decisão certa. O dano de #126 — e esta frase é **relato de campo da issue #126, não medição minha**, porque as três árvores não estão nesta máquina — é que três repositórios consumidores foram instruídos a provar que "o `_common.sh` novo recusa `behind`", os três mediram e os três refutaram, e uma fixture escrita a partir do cabeçalho **reprovaria o comportamento correto** — e, pior, passaria contra um stub destrutivo pelo motivo errado, porque sobrescrita silenciosa também não é recusa.

O canal, então, é o leitor: humano ou agente que abre o arquivo pelo topo. A prova de canal exigida por `testing/gate-delivery-channel.md` aqui não é "rodar o hook"; é **executar aquilo que o cabeçalho afirma** e comparar com o que ele afirma. Um gate que só verificasse o comportamento (o `w198` já faz isso, e faz bem) deixaria a prosa livre para mentir de novo — e essa é exatamente a lacuna que produziu #126.

**Medi a lacuna em vez de afirmá-la**, porque a revisão 1 apontou, com razão, que "o `w198` verde o tempo todo" é frase que eu não podia sustentar sem rodar o gate, e rodar gate está proibido nesta rodada. O que sustenta a mesma conclusão sem executar nada: `/usr/bin/grep -acn 'behind' tests/w198-liaison-push-union-gate.sh` devolve **0**. O gate que trava o comportamento **não menciona o token do estado cujo cabeçalho mente**, e portanto nenhuma edição do cabeçalho o move em direção nenhuma. Não é preciso saber se ele está verde: ele é indiferente ao texto, e é essa indiferença que a onda fecha. A cobrança de campo também não depende de eu ler a thread do liaison: `axis-go-cloud-0086` está citada **no próprio cabeçalho do `w198`** (`/usr/bin/grep -arln 'axis-go-cloud-0086' . --exclude-dir=.git` → `CHANGELOG.md`, `tests/w198-…`, `tests/w195-…`, `template/.forge/scripts/lib/liaison-push-union.mjs` e quatro logs do canal), com o texto "o campo mediu essa versão e cobrou o desenho por escrito (`axis-go-cloud-0086`)". A premissa está na árvore rastreada, não na minha memória.

Vale registrar uma assimetria medida (`/usr/bin/grep -an 'RECUSANDO\|POR QUE A UNIÃO SUBSTITUIU A RECUSA' template/.forge/scripts/lib/liaison-push-union.mjs` → linhas 10 e 13), porque ela reforça o diagnóstico: o módulo irmão `lib/liaison-push-union.mjs` tem, no cabeçalho, a prosa **correta e atual** ("A issue #101 fechou esse buraco RECUSANDO o push da réplica atrasada… POR QUE A UNIÃO SUBSTITUIU A RECUSA"), e o cabeçalho do `w198` também. Três arquivos foram atualizados quando a decisão mudou; um não foi. Não é ignorância do autor da mudança — é ausência de mecanismo.

### 1.4 Decisões de desenho — FECHADAS

**D1. O cabeçalho passa a declarar um CONTRATO EXECUTÁVEL de desfechos, num bloco delimitado e legível por máquina, e o gate executa cada linha dele.**

A propriedade é: para cada linha do contrato existe uma fixture que produz aquele estado, e o `rc` e o efeito medidos batem com os declarados. A prosa deixa de ser afirmação sobre o código e passa a ser **a asserção** — quem muda o código sem mudar o bloco derruba o gate, e quem muda o bloco sem mudar o código também.

*Alternativa descartada — varrer a prosa por palavra ("recusa", "une") e reprovar quando a palavra errada aparecer perto do token `behind`.* É literalmente o defeito 2 da #127, do outro lado do espelho: medir **menção de texto** como se fosse comportamento. Produziria falso-vermelho no primeiro parágrafo que explicasse a história ("a primeira correção recusava") e falso-verde em qualquer paráfrase. Um predicado sobre prosa livre não tem poder discriminante — §3.2 mede o custo exato desse erro noutro instrumento deste mesmo repositório.

*Alternativa descartada — gerar o cabeçalho a partir do código.* Não há introspecção de `case` em bash 3.2 que produza a tabela sem duplicar a lógica num parser, e um parser de `case` seria uma segunda definição do comportamento — a mesma classe de defeito que `liaison-push-union.mjs` evita ao delegar `detectForks` em vez de reimplementá-lo.

*Alternativa descartada — apagar o cabeçalho.* O cabeçalho é o que ensina, e é bom: as trinta linhas sobre por que `diverged` não pode ser aceito automaticamente são a melhor documentação do módulo. O problema não é haver prosa; é haver prosa **normativa** fora do alcance de qualquer verificação.

**D2. As linhas 19-20 não são apagadas: são reescritas com a decisão atual, e a afirmação antiga permanece marcada como histórica.**

A issue pede isso em letra ("se a menção à #101 no cabeçalho descreve o estado anterior, dizer isso"), e a razão é de ensino: a #101 continua sendo o motivo pelo qual o `cp` incondicional morreu, e apagar a referência apagaria o porquê. A forma é um marcador explícito (`HISTÓRICO:`) na linha que descreve o estado anterior, e o contrato de D1 carrega a decisão vigente.

**D3 (REESCRITA na revisão 2 — a versão anterior era o BLOQUEADOR 2). A metade textual do gate mede AFIRMAÇÃO DE DESFECHO, não ocorrência de token, e o predicado foi medido antes de ser escrito.**

A revisão 1 reprovou a versão anterior desta decisão, e a crítica está certa. O predicado antigo era "toda ocorrência dos tokens `ff`, `behind` e `diverged` no cabeçalho está dentro do bloco de contrato ou marcada como `HISTÓRICO:`". Medi a região e a crítica se confirma inteira:

```
$ f=template/.forge/scripts/lib/transports/_common.sh
$ awk 'NR>1 && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/ {print NR-1; exit}' "$f"
42                                        # o cabeçalho é 1-42; a linha 43 é `_dir_push_classify() {`
$ sed -n '1,42p' "$f" | /usr/bin/grep -an -E '(^|[^[:alnum:]_])(ff|behind|diverged)([^[:alnum:]_]|$)' | cut -d: -f1
19 21 23 42
```

Das quatro, **uma** mente (a 19) e **três** são corretas e vigentes: a 21 define `diverged`, a 23 abre as trinta linhas que D1 recusa apagar, e a 42 é o contrato de saída de `_dir_push_classify`. O predicado antigo só tinha dois desfechos e os dois eram defeito, como o revisor mostrou: ou vermelho fabricado sobre prosa correta, ou um bloco de contrato tão largo que engole o cabeçalho e o cenário nunca falha.

**O predicado novo é a interseção de dois conjuntos fechados, os dois declarados dentro do bloco de contrato e versionados com ele:**

- **T** — os três tokens de classificação: `ff`, `behind`, `diverged`, casados com **fronteira de palavra**. Medi o efeito da fronteira neste cabeçalho e ele é **nulo hoje**: com e sem a fronteira a varredura devolve as mesmas quatro linhas (19, 21, 23, 42), porque nenhuma linha do cabeçalho contém `diff`, `off` ou `buffer`. A fronteira fica assim mesmo, como defesa para o próximo arquivo que D4 inscrever, e fica registrado que ela **não** discrimina nada no arquivo de hoje — dizer o contrário seria vender poder que a medição não mostra;
- **V** — o léxico de **desfecho de `_dir_push`**: `publica`, `une`/`unir`, `recusa`, `substitui`, `sobrescreve`, `apaga`, e as flexões que compartilham o radical.

Uma linha do cabeçalho, **fora** do bloco de contrato, que contenha um elemento de T **e** um de V é uma afirmação de desfecho, e ela tem de estar marcada `HISTÓRICO:`. Linha com token e sem verbo de desfecho é descrição, não norma, e o gate não a toca.

**Medido antes de escrever, com controle, dois contrafactuais e recontrole**, sobre cópias em `$TMPDIR` (o arquivo rastreado nunca foi tocado; `cmp -s` confirma no fim):

| Estado do arquivo | linhas sinalizadas | esperado |
|---|---|---|
| CONTROLE — o `_common.sh` de hoje | **1** — `19:#   behind   — … Publicar apaga uma mensagem que só` | 1, e é exatamente a que mente |
| CF-A — 19-20 reescritas com `HISTÓRICO:` (a correção que D2 manda fazer) | **0** | 0 |
| CF-B — ANTI-VACUIDADE, **sobre a base CF-A**: linha nova com token e **sem** verbo de desfecho (`#   ff       — o log local é superconjunto do log do hub.`) | **0** | 0 — o predicado não dispara em descrição |
| CF-C — M3, **sobre a base CF-A**: linha nova com token **e** verbo, não marcada (`#   behind   — o transporte recusa a publicação e não une nada.`) | **1**, nomeando a linha | 1 |
| RECONTROLE — restaura o controle | **1** | 1 |

CF-B é a metade que faltava e é o que separa este predicado do anterior: sem ela, "0 sinalizadas" em CF-A seria indistinguível de um predicado que parou de enxergar. As linhas 21, 23 e 42 sobrevivem sem marcação e sem mentira, e é isso que o revisor pedia e que a versão anterior não conseguia entregar.

**Sobre qual base cada contrafactual roda, porque a revisão 2 não dizia e a diferença é de dois números.** CF-B e CF-C são medidos sobre **CF-A** — isto é, com as linhas 19-20 já reescritas com `HISTÓRICO:` —, e não sobre o CONTROLE. A ressalva do revisor é procedente e eu remedi as quatro leituras de uma vez, com todas as mutações conferidas por `cmp -s` contra no-op antes de valerem:

```
CONTROLE            = 1
CF-A                = 0
CF-B sobre CONTROLE = 1      CF-B sobre CF-A = 0
CF-C sobre CONTROLE = 2      CF-C sobre CF-A = 1
```

A razão da escolha é que CF-B e CF-C respondem "o predicado enxerga a linha NOVA?", e sobre o CONTROLE a linha 19 continua lá somando 1 a toda leitura — a resposta viria embutida num número que não é sobre a linha nova. A tabela acima é a que vale, e a coluna "esperado" dela é a leitura sobre CF-A.

**O segundo limite do predicado, que a revisão 2 não declarava: a granularidade.** T ∩ V é avaliado **por linha**, e uma reintrodução da mentira partida em duas — token numa linha, verbo normativo na seguinte — passa. O limite não é hipótese: medi o contrafactual sobre CF-A, com uma mentira partida (`#   behind   — o hub tem um msg_id que esta réplica não tem.` seguida de `#              Publicar apaga essa mensagem, e recusar é a única saída.`) e a leitura é **0**. E ele é exatamente a forma da mentira de hoje: as linhas 19 e 20 são um par, a 20 é quem carrega o verbo normativo (`recusar é a única saída`) sem nenhum token de T, e o CONTROLE só devolve 1 porque a 19 por acaso carrega token e verbo juntos. Isto **não** desfaz o cenário `[3]` — a mentira de hoje é pega, D2 manda reescrever as duas linhas, e a família do limite é a mesma já declarada para V —, e o remédio é o mesmo: os dois números publicados (`|T|` e `|T ∩ V|`) tornam visível o encolhimento, e a onda seguinte que quiser fechar a granularidade estende o predicado para a janela de continuação (linha de comentário indentada logo abaixo de uma linha com token) em vez de fingir que ele já a cobre.

**O limite, declarado porque ele existe.** V é um conjunto fechado, e uma linha que minta usando um verbo fora dele passa. Não há saída boa disso — prosa livre não tem predicado total —, e a resposta não é fingir cobertura: é publicar os dois números. O gate imprime `|T|` (ocorrências de token no cabeçalho) e `|T ∩ V|` (afirmações de desfecho), e uma queda de `|T|` sem mudança no arquivo é sinal de que o predicado encolheu. Isto é allowlist sobre universo fechado e pequeno — o cabeçalho de um arquivo, 42 linhas hoje —, não denylist sobre "tudo menos exceções": a distinção que a #127 paga caro e que §2.3 recolhe como lição transversal desta onda.

**D4. A adoção é opt-in por presença do marcador, e o universo do gate é derivado, nunca literal.**

O universo é "arquivos de `template/.forge/` que contêm o marcador de abertura do contrato". Esta onda inscreve **um** (`_common.sh`), e a asserção de piso é `>= 1`, jamais `== 1`: a Fase 0 do plano-mestre tem um caso da mesma classe (`pentest.md` dizia "quatro raízes" enquanto o engine varria seis), e a onda seguinte que inscrever um segundo arquivo não pode ser obrigada a editar este gate. Contador de controle publicado com o número de arquivos inscritos **e** o número de linhas de contrato executadas, com reprovação em zero nos dois.

**D5. O contrato declara desfecho por estado, e os NOVE estados de §1.2 entram — os nove, não os quatro do cabeçalho de hoje.**

Incluir os três estados de recusa que **não** vêm do classificador (`sender` alheio, JSON ilegível, `node`/módulo indisponível) é o que impede que a correção conserte a frase e preserve a lacuna: nos três a classificação diz `ff` e o push recusa. O nono, medido só na revisão 2, é também o que dá ao contrato a **causa** de cada rc 1, que é a informação que hoje não existe em lugar nenhum. O estado do log próprio ausente **não** entra, porque é inalcançável a partir de `_dir_push` e inscrevê-lo obrigaria o gate a exercitar um caminho que a produção não tem — gate que mede caminho morto compra cobertura falsa.

O piso do gate é **`>= 8` linhas de contrato**, derivado em execução e nunca `== 9`: nove é o que a onda inscreve hoje, o piso é o que a asserção trava, e a onda seguinte que descobrir um décimo estado alcançável não pode ser obrigada a editar este gate para inscrevê-lo.

### 1.5 O VERMELHO, antes do verde

Gate novo `tests/w<NNN>-transport-contract-coherence-gate.sh`. Todo cenário roda com o `cwd` dentro da fixture, sob `$TMPDIR`, e o `_common.sh` é carregado a partir de um arquivo de script real, pelo motivo medido em §1.1.

| # | Cenário | Asserção | Mensagem do vermelho hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [1] | o arquivo declara um bloco de contrato | o bloco existe, é parseável, declara T e V, e tem `>= 8` linhas de desfecho | `FAIL [1]: nenhum bloco de contrato executável em _common.sh — a prosa do cabeçalho não é verificável por ninguém` | o bloco não existe; o cabeçalho é prosa livre |
| [2] | cada linha do contrato é executada contra fixture e o `rc` medido bate com o declarado | todas as linhas declaradas conferem, com o contador derivado publicado (hoje seriam 9) | `FAIL [2]: sem contrato não há o que executar` | idem [1] |
| [3] | coerência do cabeçalho: **afirmação de desfecho** (T ∩ V) fora do bloco e sem marcação histórica | zero afirmações não marcadas, com `\|T\|` e `\|T ∩ V\|` publicados | `FAIL [3]: afirmação de desfecho não marcada na l.19 — 'behind' com 'Publicar apaga', enquanto o contrato e a execução dizem união (cabeçalho examinado: 42 linhas; \|T\|=4; \|T ∩ V\|=1)` | a linha 19 existe hoje, sem marcação, afirmando o oposto do medido — medido em §1.4, controle = 1 |
| [4] | CONTADOR DE CONTROLE do próprio gate | `DECLARADOS=7`, conferido contra o contador incrementado por cenário | — | **não falha por ausência** — verde por construção |
| [5] | CONTADOR DE UNIVERSO | `>= 1` arquivo inscrito e `>= 8` linhas de contrato executadas; zero reprova | `FAIL [5]: 0 arquivo(s) inscrito(s) no contrato executável — universo vazio` | com o marcador ausente o universo é zero, e um gate sem este cenário aprovaria por não ter olhado nada |
| [6] | SENTINELA DO PRÓPRIO GATE | `git -C <repo> diff --name-only HEAD -- template/` idêntico no início e no fim | `FAIL [6]: o gate mexeu na árvore real` | **não falha por ausência** — é a sentinela; o vermelho dela é defeito do gate, não do produto |
| [7] | ANTI-VACUIDADE DO PREDICADO DE `[3]`: cabeçalho de fixture com token de T e **sem** verbo de V | `[3]` fica **verde** — descrição não é norma | `FAIL [7]: o predicado do cabeçalho dispara em linha descritiva; ele está medindo ocorrência de token, e é o defeito que a revisão 1 reprovou` | é o par de `[3]`: sem ele, um predicado cego e um predicado correto produzem o mesmo verde. Medido em §1.4 (CF-B = 0) |

O `[3]` é o cenário que fecha #126 e é o único que hoje é vermelho **pelo conteúdo do arquivo rastreado**, não pela ausência de maquinaria — e isso é uma propriedade e não um problema: é a definição de red-first para um defeito cujo dano é o próprio texto. O `[7]` existe porque `[3]` sozinho não distingue predicado correto de predicado cego, e os dois só valem juntos: `[3]` prova que ele acusa a linha que mente, `[7]` prova que ele não acusa as três que não mentem.

### 1.6 Prova de mutação, com controle e recontrole

Alvo: `template/.forge/scripts/lib/transports/_common.sh`. As duas mutações vão em **sentidos opostos**, e é essa oposição que prova que a prosa e o código estão amarrados um ao outro em vez de apenas coexistirem.

| Mutação | O que muta | O gate tem de dizer | Estado | Recontrole |
|---|---|---|---|---|
| M1 — trocar, no bloco de contrato, o desfecho de `behind` de "une, rc 0" para "recusa, rc 1", **sem tocar no código** | prosa | `FAIL [2]`, nomeando a linha `behind` e os dois valores (declarado × medido) | A MEDIR — o bloco ainda não existe | restaurar e `[2]` volta a passar |
| M2 — trocar o `case 1` de `_dir_push` para `return 1` sem unir, **sem tocar no bloco** | código | `FAIL [2]`, nomeando a mesma linha `behind`, com os papéis invertidos | A MEDIR | restaurar e `[2]` volta a passar |
| M3 — reintroduzir, no cabeçalho e fora do bloco, uma linha com token **e** verbo de desfecho, não marcada | prosa | `FAIL [3]`, nomeando a linha e os dois conjuntos | **MEDIDO em §1.4 (CF-C): o predicado sinaliza 1 linha, a nova** — resta o implementador medir a mensagem do gate | restaurar e `[3]` volta a passar; recontrole medido (volta a 1, que é o estado de hoje) |
| M3b — CONTRAFACTUAL DE M3: acrescentar, fora do bloco, uma linha com token e **sem** verbo de desfecho | prosa | **nada** — `[3]` continua verde e `[7]` também | **MEDIDO em §1.4 (CF-B): 0 linhas sinalizadas** | restaurar |
| M4 — remover o marcador de abertura do contrato do `_common.sh` | prosa | `FAIL [5]` por universo vazio, **nunca** `OK` silencioso | A MEDIR | restaurar e `[5]` volta a passar |

M3 e M3b são o par que a revisão 1 provou ser necessário: uma mutação que derruba e outra que **não pode** derrubar. Uma matriz com M3 sozinha registraria "a guarda foi testada" tendo testado só a metade que acusa, e é assim que nasce um predicado que acusa tudo. As duas já vêm medidas de §1.4, e o implementador as reexecuta contra o gate real em vez de contra o meu recorte.

**M1 e M2 têm de derrubar a MESMA asserção por caminhos opostos, e isso é o critério de aceite da mutação, não um detalhe.** Se M1 derruba `[2]` e M2 não, o gate está lendo prosa e não executando; se M2 derruba e M1 não, o gate está executando e ignorando a prosa — e nos dois casos #126 pode voltar. O implementador roda as duas e cola as duas saídas no PR.

M4 é obrigatória porque sem ela o gate teria a saída mais barata possível para ficar verde: apagar o marcador. É a mesma lição do `[2]` do `w200` (README-fixture sem linha de contagem reprova pela guarda de piso).

Mecânica obrigatória, e é idioma do repositório, não invenção desta spec: controle por `cp "$ALVO" "$ORIG"` **vindo da árvore de trabalho, nunca do HEAD** (as mutações rodam depois da implementação não commitada, e um controle do HEAD apagaria o trabalho enquanto o `cmp` confirmaria alegremente que a restauração bateu); mutação com aspas **simples** no `perl -0pi` e todo `$` do lado direito escapado, porque `perl -0pi -e "s/a/$x/"` interpola `$x` do **perl**, vazio, e a mutação vira no-op silencioso enquanto o `cmp` confirma que o arquivo mudou (LDG-0164, e o plano-mestre registra que isso aconteceu duas vezes nesta rodada, inclusive com quem conhecia a regra); restauração conferida byte a byte por `cmp -s`; e recontrole reexecutando a asserção derrubada, sem o qual a prova não vale (`feedback-mutacao-fantasma-restore`).

O alvo é arquivo rastreado sob `template/`, que é o que a sentinela da Onda A existe para proibir. Não há contradição, pelo mesmo argumento que a Onda A já registrou: a sentinela compara **depois** de o gate terminar, o gate restaura antes de terminar, e se a restauração falhar quem pega é a própria sentinela, no gate seguinte da suíte. O cenário `[6]` é a metade local dessa disciplina.

### 1.7 PBT — onde há espaço de entrada

**Aplica-se, e o espaço é o par de logs.** A propriedade que a issue #101 estabeleceu e que a união preserva é: **para todo par (log do hub, log local) sem bifurcação, o conjunto de `msg_id` do hub depois do push é superconjunto do conjunto antes.** Isto é uma propriedade sobre entrada gerada — número de mensagens, sobreposição, ordem, `seq` com buracos, acentuação no corpo —, e três exemplos escolhidos a dedo não a cobrem.

Ferramenta: `template/.forge/scripts/lib/pbt.mjs`, harness zero-dep já entregue e coberto por `w121`, com `forAll`, `gen`, shrinking e seed reprodutível. O contrato do template é zero dependência, então não se importa fast-check.

Duas propriedades, e a segunda existe porque a primeira sozinha é satisfeita por um push que nunca escreve:

- **P1 — monotonicidade do hub:** para todo par sem bifurcação, `msg_ids(hub_depois) ⊇ msg_ids(hub_antes)`.
- **P2 — progresso:** para todo par sem bifurcação em que o local tem ao menos um `msg_id` que o hub não tem, `msg_ids(hub_depois) ⊋ msg_ids(hub_antes)`.

O contador do PBT é próprio (`runs` do `forAll`, com a `seed` impressa), porque um PBT que rodou zero casos aprova por não ter olhado. **Não** duplicar aqui a cobertura de bifurcação: `w198[4]` já a trava, e `w195` cobre monotonicidade por outro ângulo — o implementador confere a fronteira antes de escrever, para não pagar duas vezes pelo mesmo cenário.

### 1.8 Contador de controle, denominador fixo

O gate publica duas linhas e reprova em zero nas duas:

```
OK transport-contract/universo — N arquivo(s) inscrito(s), M linha(s) de contrato executada(s)
OK transport-contract/cabecalho — H linha(s) de cabeçalho examinada(s), |T|=t, |T ∩ V|=v
OK transport-contract/cenarios — 7 cenário(s) executado(s) de 7 declarado(s)
```

A segunda linha é o instrumento de D3 contra o encolhimento do próprio predicado: `H`, `t` e `v` são derivados em execução, e um `t` que caia sem o arquivo mudar denuncia um predicado que parou de enxergar. O denominador de cenários é literal (`DECLARADOS=7`) e isso é correto: é a única exceção que a invariante 14 do plano-mestre admite, porque o universo é a lista que o próprio arquivo declara, fechada e conhecida em tempo de escrita, e a divergência é justamente o achado. Os denominadores de arquivos inscritos e de linhas de contrato são **pisos derivados em execução**, nunca literais, pelo motivo de D4.

Chave de allowlist de universo vazio: **nenhuma.** O universo é derivado da árvore do próprio template, que a onda inscreve; vazio aqui é sempre defeito.

### 1.9 Níveis de teste

- **Unitário:** `[1]` e `[3]`, sobre o parsing do bloco e a varredura do cabeçalho.
- **Integração:** `[2]`, que é o coração do gate — carrega o `_common.sh` real e executa `_dir_push` contra hub e réplica de verdade, com o módulo de união real e `node` real. Não é o script invocado direto: é o caminho pelo qual a decisão acontece em produção.
- **PBT:** §1.7.
- **Contrato:** o bloco de D1 **é** o teste de contrato; não há segundo instrumento a construir. O `_common.sh` é fronteira publicada — está no `machinery.lock` dos consumidores (LDG-0153 registra que o doctor ainda não informa divergência dele contra o template) e o campo escreve testes a partir do cabeçalho, o que é precisamente o dano de #126.
- **E2E — não se aplica, com motivo medido.** O canal do dano é a leitura, e não há E2E roteirizável sobre "um humano ou agente lê o topo do arquivo e conclui X". Fingir um seria teatro. A fronteira scriptável termina em `[2]` e `[3]`, e ela cobre as duas metades do defeito: o que o código faz e o que o texto afirma.

### 1.10 Retrocompatibilidade

**Nada quebra, e é preciso dizer por quê em vez de só afirmar.** A mudança é integralmente de comentário: nenhuma linha executável de `_common.sh` muda, nenhum `rc` muda, nenhuma string que a produção imprime muda. A varredura de `tests/` pelas strings do arquivo, refeita com `/usr/bin/grep -arn` (o wrapper da sessão pula binário e arquivo ignorado pelo git; nenhum arquivo de `tests/` é binário, e isso foi conferido — ver o preâmbulo), devolve `push RECUSADO` em `w195:303` e `DIVERGÊNCIA` em `w110:237` e `w193:149`. Fui ler as três em vez de classificá-las de memória: `w195:303` e `w193:149` são **mensagens de FAIL dos próprios gates** e `w110:237` é **comentário**; nenhuma das três é asserção sobre a saída da produção. E `liaison-push-union` em `w198`, que afirma comportamento e não texto. **Nenhum gate afirma o cabeçalho** — `/usr/bin/grep -acn 'behind' tests/w198-liaison-push-union-gate.sh` → 0.

Registro, porque a revisão 2 encontrou: `push RECUSADO` **é** string de produção do `_common.sh`, em três sítios (`/usr/bin/grep -arn 'push RECUSADO' template/` → `:105`, `:184`, `:199`). A onda não a muda, e nenhum gate a afirma sobre saída de produção — mas classificá-la como "irrelevante", como a revisão 1 fazia, era classificar sem olhar. Ela é relevante e está livre; são coisas diferentes.

**O que os consumidores têm instalado.** `scripts/lib/transports/_common.sh` está no `machinery.lock` de **6 dos 8** repositórios com `.forge/` completo — `Axis.AcqSimulator` e `docuseal` têm lock mas nenhuma entrada para o arquivo, isto é, carregam maquinaria de uma release anterior à existência do transporte. Comando, rodado em 2026-09-08 sobre `~/Documents/projects` (os oito com `machinery.lock`: `axis-fare-validator`, `axis-go-cloud`, `Axis.AcqSimulator`, `Axis.PadSimulator`, `azim-crm`, `collatra`, `docuseal`, `lionclaw`): `for d in <os oito>; do /usr/bin/grep -aq 'scripts/lib/transports/_common.sh' "$d/.forge/cache/machinery.lock" && echo "$d"; done` → seis, sem `Axis.AcqSimulator` e sem `docuseal`; e o arquivo também não está no disco desses dois. E `scripts` está em `MACHINERY_DIRS` (`bin/forge.mjs:307`) e **fora** de `ENRICHABLE_DIRS` (`:352`), de modo que o próximo overlay sobrescreve o arquivo nos seis. Para esta onda isso é benigno e até desejável: o que o overlay leva é comentário corrigido. Mas há uma consequência que o release precisa dizer ao campo, porque três consumidores **escreveram fixture a partir do cabeçalho errado** — isto é relato da issue #126 ("Três repositórios consumidores foram instruídos por mim a provar que o `_common.sh` novo recusa `behind`"), não medição minha, porque as três árvores não estão nesta máquina. A correção do texto não conserta as fixtures deles, e uma fixture que espera recusa para réplica atrasada continuará reprovando o comportamento correto até que alguém a reescreva. O ack da Onda I dessas threads carrega essa frase, não uma promessa genérica.

**Dependência nomeada:** LDG-0153 (Onda B) faz o doctor informar divergência do `_common.sh` local contra o template. Esta onda não depende dele e não o antecipa; só registra que, enquanto ele não fechar, um consumidor com patch local neste arquivo não é avisado antes de perdê-lo.

---

## 2. ITEM 2 — issue #127

Dois defeitos no mesmo gate, e eles são tratados separadamente porque têm naturezas opostas: um é de **custo** e faz o gate não terminar; o outro é de **predicado** e faz o gate ficar cronicamente vermelho pelo motivo errado. O segundo é falso-vermelho — a imagem espelhada do falso-verde que a Onda D combate — e o remédio de um não é o remédio do outro.

### 2.1 Defeito 1 — a varredura desce em `.forge/worktrees/`

As linhas de produção, hoje, em `template/.forge/scripts/doctor.sh:114-119`:

```sh
USER_DATA='/(specs|worktrees|product|evals|custom)/'
leaks="$(grep -rl '\.claude/' "$ROOT/.forge" 2>/dev/null | grep -vE "/(adapters|scripts|hooks)/|/commands/harness/|$USER_DATA" | wc -l | tr -d ' ')"
…
orphans="$(grep -rl '<PROJECT_[A-Z_]*>' "$ROOT/.forge" 2>/dev/null | grep -vE "/templates/|$USER_DATA" | wc -l | tr -d ' ')"
```

O filtro está correto e o resultado também — `$USER_DATA` já descarta `worktrees` —, mas **a varredura já foi paga**. Reproduzido em fixture sob `$TMPDIR` com 25 arquivos de fonte canônica (15 em `rules/`, 10 em `agents/`) e 3.001 sob `.forge/worktrees/wt1/node_modules/`, com os comandos colados:

```bash
echo "universo total .forge : $(find "$C/.forge" -type f | wc -l)"
echo "sob worktrees        : $(find "$C/.forge/worktrees" -type f | wc -l)"
echo "com  worktrees: $(/usr/bin/grep -arl '' "$C/.forge" | wc -l)"
echo "sem  worktrees: $(/usr/bin/grep -arl '' --exclude-dir=worktrees "$C/.forge" | wc -l)"
```

```
universo total .forge : 3026
sob worktrees        : 3001
--- custo: arquivos ABERTOS pela varredura, com e sem --exclude-dir=worktrees
com  worktrees: 3026
sem  worktrees: 25
--- a SAÍDA da linha de produção muda com --exclude-dir=worktrees?
IDÊNTICA (só o custo muda)
```

**A saída é byte a byte idêntica; só o custo muda.** É a mesma conclusão do conserto local do consumidor, agora medida aqui.

**E com CONTROLE POSITIVO, que faltava na revisão 1** — sem ele, "IDÊNTICA" seria satisfeita por duas saídas vazias, que é precisamente a vacuidade que a Onda D combate. Plantei uma violação real sob `rules/` e remedi:

```
com: [.forge/rules/violador.md]
sem: [.forge/rules/violador.md]
IDÊNTICA E NÃO VAZIA
```

A escala real, **remedida integralmente na revisão 2** porque a revisão 1 declarou números que ela mesma não conseguiu reconferir e que já tinham envelhecido. Comando, na íntegra, rodado em segundo plano contra os treze repositórios de `~/Documents/projects` com `.forge/`, com carimbo de data no fim da saída:

```bash
for d in agent-smith axis-fare-validator axis-go-cloud Axis.AcqSimulator Axis.PadSimulator \
         azim-crm collatra cpf-cnpj-validator docuseal forge-harness forge-test lionclaw payments; do
  t=$(find "$d/.forge" -type f 2>/dev/null | wc -l)
  w=$(find "$d/.forge/worktrees" -type f 2>/dev/null | wc -l)
  printf '%-24s %12s %12s\n' "$d" "$t" "$w"
done
echo "DATA: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

Saída, `DATA: 2026-09-08T12:49:24Z`:

| Repositório | arquivos sob `.forge/` | sob `.forge/worktrees/` | fração |
|---|---:|---:|---:|
| **axis-go-cloud** | **5.983.604** | **5.980.925** | **99,96%** |
| azim-crm | 422.882 | 421.506 | 99,67% |
| Axis.PadSimulator | 273.873 | 272.036 | 99,33% |
| agent-smith | 96.690 | 96.425 | 99,73% |
| lionclaw | 70.162 | 69.725 | 99,38% |
| axis-fare-validator | 11.563 | 9.220 | 79,74% |
| **forge-harness** | **345** | **0** | **0%** |
| collatra (577), payments (512), Axis.AcqSimulator (407), docuseal (330), cpf-cnpj-validator (261), forge-test (123) | 123–577 | 0 | 0% |

**Os números mudaram entre a revisão 1 e a 2, e é essa a informação útil.** `axis-go-cloud` foi de 5.976.165 para 5.983.604 em um dia; `azim-crm`, de 415.139 para 422.882. Worktrees crescem, e por isso **nenhuma asserção desta onda cita qualquer destes números**: a propriedade que o gate trava é "a varredura não abre arquivo sob `.forge/worktrees/`" (§2.4, `[4]`), que não envelhece. A tabela existe para dimensionar a fração e a ordem de grandeza, e as duas se mantiveram: seis repositórios acima de 79%, cinco acima de 99%.

O número de campo era 465.115; o pior caso medido aqui é **doze vezes maior**. E a linha do `forge-harness` é a razão pela qual esta seção existe: **na árvore do produtor o custo não morde**, porque `.forge/worktrees/` está vazio. O defeito é do código, não do estado desta árvore — quem o especifica precisa da fixture, e quem duvidar dele nesta árvore não o encontrará.

O próprio comando que produziu a tabela levou **mais de vinte minutos** no `axis-go-cloud` e teve de ser mandado para segundo plano nas duas revisões, o que é a reprodução acidental e independente do relato de campo ("duas execuções do doctor foram abandonadas presas nesse `grep`"): um gate que não termina não é um gate.

**O que desta tabela é portante e o que é ilustração, dito em letra porque o revisor não a reproduziu e não deve ter de reproduzi-la.** As duas pontas que decidem o argumento são baratas e eu as remedi em 2026-09-08 às `13:28:16Z`, junto com o universo: `find .forge -type f | wc -l` na raiz deste repositório devolve **345** e `find .forge/worktrees -type f 2>/dev/null | wc -l` devolve **0** (é a ponta que diz que na árvore do produtor o custo não morde), e `cd ~/Documents/projects && for d in */; do [ -d "$d/.forge" ] && echo "${d%/}"; done | sort` enumera exatamente **treze** repositórios, nome a nome idênticos aos da tabela (é o universo, que prova que a lista não foi escrita à mão). O resto da tabela — as seis frações acima de 79% e os números de sete dígitos — é **ilustração de ordem de grandeza e nada mais**: nenhuma asserção desta onda os cita, a propriedade travada por `[4]` de §2.4 é "a varredura não abre arquivo sob `.forge/worktrees/`", que não envelhece, e os próprios números mudaram em um dia. Quem revisar esta onda pode pular a linha do `axis-go-cloud` sem perder nada do argumento.

### 2.2 Defeito 2 — o predicado, e ele está vivo nesta árvore

O predicado pergunta "este arquivo **contém** o texto `.claude/`?" quando a pergunta é "esta **configuração referencia** `.claude/`?". Reproduzido em fixture sob `$TMPDIR` refeita em 2026-09-08, com `liaison/` e `ledger/` povoados com corpo de mensagem que fala sobre o diretório, uma configuração limpa em `rules/`/`agents/`/`skills/`/`templates/`, e um arquivo de maquinaria em `commands/harness/` que a denylist de hoje já exclui:

```bash
# bruto, antes do filtro
/usr/bin/grep -arl '\.claude/' "$F/.forge"
# a linha de produção, verbatim de doctor.sh:115
USER_DATA='/(specs|worktrees|product|evals|custom)/'
/usr/bin/grep -arl '\.claude/' "$F/.forge" 2>/dev/null \
  | /usr/bin/grep -vE "/(adapters|scripts|hooks)/|/commands/harness/|$USER_DATA"
```

```
arquivos casados pelo grep BRUTO (antes do filtro): 5
   .forge/commands/harness/sync-adapters.md      ← maquinaria, corretamente filtrada
   .forge/ledger/LEDGER.md
   .forge/liaison/canal/blobs/deadbeef
   .forge/liaison/canal/CHANNEL.md
   .forge/liaison/canal/log/axis.jsonl
leaks reportado pelo doctor                       : 4
--- quais arquivos o doctor acusa:
.forge/ledger/LEDGER.md
.forge/liaison/canal/blobs/deadbeef
.forge/liaison/canal/CHANNEL.md
.forge/liaison/canal/log/axis.jsonl
```

E a mesma linha de produção, rodada **em leitura** contra o `.forge/` da raiz deste repositório, devolve **14 arquivos** — onze blobs de corpo de mensagem, dois logs `.jsonl` (`axis-pad-simulator`, `axis-fare-validator`) e o `CHANNEL.md` do canal. **Zero configuração.** Os catorze nomes saíram do comando acima com `$F` trocado pela raiz do repositório, e o número é o mesmo com e sem `-a` (14 nos dois), o que era preciso conferir depois de LDG-0177. A string aparece porque os agentes conversam sobre o diretório `.claude/` nas mensagens do liaison, e vão continuar conversando — `wc -l .forge/liaison/forge-harness/log/*.jsonl` devolve **382** linhas somadas entre os participantes, e cresce a cada rodada. O `doctor` deste repositório reporta hoje `✗ harness: 14 arquivo(s) da fonte canônica com refs .claude/` e sai `1`; o produtor é a primeira vítima do próprio defeito.

Uma medição que decide o desenho e refuta a solução óbvia, e a issue já a antecipava — com controle, porque "nenhuma linha" precisa ser distinguido de "a varredura não olhou":

```bash
/usr/bin/grep -arl '' --exclude-dir=liaison "$F/.forge/templates"   # → (nenhuma linha)
/usr/bin/grep -arl ''                        "$F/.forge/templates"   # → .forge/templates/liaison/CHANNEL.md
```

`--exclude-dir` casa por *basename*, então excluir `liaison` cega também `.forge/templates/liaison/CHANNEL.md`, que é fonte canônica e tem de continuar vigiada — e a segunda linha prova que o arquivo existe e é legível, isto é, que o vazio da primeira é cegueira e não ausência. Qualquer exclusão de conteúdo do consumidor precisa ser **ancorada no caminho a partir de `.forge/`**, nunca por nome de diretório. Medido também o efeito completo, com uma violação plantada em `rules/conventions/` e outra em `templates/liaison/CHANNEL.md`: a varredura ancorada acha as duas; a mesma varredura com `--exclude-dir=liaison` acha só a primeira.

### 2.3 Decisões de desenho — FECHADAS

**D6 (REESCRITA na revisão 3 — a versão da revisão 1 era o BLOQUEADOR 1 e a da revisão 2 era o BLOQUEADOR NOVO). Cada uma das DUAS varreduras ganha o SEU universo de inclusão; os dois universos têm componentes de DIRETÓRIO diferentes, porque a medição diz que eles são diferentes, e a MESMA componente de ARQUIVOS DE TOPO, porque é ali que mora a configuração canônica que dá razão de existir aos dois varredores.**

A versão anterior nomeava um universo único — `rules/`, `agents/`, `skills/`, `commands/`, `templates/` e `hooks/` — e dizia "tudo o mais fica fora por não estar dentro", sem reconciliar com as exceções que a própria linha de produção aplica **dentro** desses diretórios. O revisor mediu e está certo. Remedi numa instalação limpa (`node bin/forge.mjs init --yes --no-plugin --source template/.forge` sobre um git novo em `$TMPDIR`), com o censo completo por diretório de topo:

```bash
for d in $(ls "$R/.forge"); do
  p="$R/.forge/$d"; [ -d "$p" ] || continue
  printf '%-14s arqs=%-6s com .claude/=%-3s com <PROJECT_*>=%s\n' "$d" \
    "$(find "$p" -type f | wc -l)" \
    "$(/usr/bin/grep -arl '\.claude/' "$p" | wc -l)" \
    "$(/usr/bin/grep -arl '<PROJECT_[A-Z_]*>' "$p" | wc -l)"
done
```

| diretório | arquivos | com `.claude/` | com `<PROJECT_*>` |
|---|---:|---:|---:|
| rules | 51 | 0 | 0 |
| agents | 48 | 0 | 0 |
| skills | 20 | 0 | 0 |
| commands | 57 | **2** (`commands/harness/build-plugin.md`, `commands/harness/sync-adapters.md`) | 0 |
| templates | 21 | 0 | **1** (`templates/FORGE.md`) |
| hooks | 13 | **1** (`hooks/git/lib/check-docs-reviewed.sh`) | 0 |
| adapters | 10 | 2 | 0 |
| scripts | 136 | 5 | 0 |
| schemas / contracts / capabilities / evals / product / specs / custom / ledger / liaison | 1–28 | 0 | 0 |

O censo é **exaustivo por construção** — o laço itera `ls "$R/.forge"` inteiro, não uma lista escrita à mão —, e é isso que autoriza a frase "estes são todos os arquivos que justificam exceção". A invariante 17 pede que a enumeração procure o caso não coberto; aqui o caso não coberto seria um diretório que eu não tivesse pensado em olhar, e o laço olha todos.

**A leitura literal da D6 anterior punha o `doctor` em `✗` nas duas linhas numa instalação limpa**, e o doctor de hoje imprime `✓` nas duas (medido: `bash "$R/.forge/scripts/doctor.sh"` → `✓ harness: fonte canônica sem refs .claude/` e `✓ harness: sem placeholders <PROJECT_*> órfãos`, rc 0). Três gates existentes dependem dessas duas linhas — `w63[g]` (`:185-186`), `w158` e `npx-pack-gate` —, e D10 declara que elas ficam byte-idênticas. As duas afirmações não podiam valer juntas, e o revisor tem razão em chamar isso de decisão deixada em aberto.

**A decisão, agora fechada e ancorada na medição:**

- **Universo da varredura de VAZAMENTO (`.claude/`):** os diretórios `rules/`, `agents/`, `skills/`, `templates/`, e `commands/` **exceto** `commands/harness/`, **mais os oito arquivos canônicos de topo do `.forge/`**.
- **Universo da varredura de ÓRFÃOS (`<PROJECT_*>`):** os diretórios `rules/`, `agents/`, `skills/`, `commands/`, `hooks/` — e **não** `templates/` —, **mais os mesmos oito arquivos canônicos de topo do `.forge/`**.

**A componente de ARQUIVOS DE TOPO, e por que ela é o coração dos dois varredores.** A revisão 2 escreveu os dois universos como listas de **diretórios**, e o revisor mediu a consequência: `FORGE.md`, `context.md`, `constitution.md` e `forge.yaml` moram na **raiz** do `.forge/` e não estavam em nenhuma das duas listas — isto é, a versão anterior desligava a varredura exatamente sobre os arquivos que o cabeçalho do `w158` nomeia como a razão de o varredor de órfãos existir ("alguém instalou o harness e não preencheu FORGE.md/context.md/constitution.md"). Reproduzi o dano nos dois varredores, na instalação limpa, com controle positivo e recontrole, e os três números que importam saem em cada bloco: o que o doctor de hoje diz, o que o universo da revisão 2 devolvia e o que o universo desta revisão devolve.

```bash
R=$B/R   # instalação limpa: node bin/forge.mjs init --yes --no-plugin --source template/.forge
d(){ (cd "$R" && bash .forge/scripts/doctor.sh --report 2>&1 | /usr/bin/grep -E 'refs \.claude|placeholders'); }
printf '\n<!-- controle: <PROJECT_SLUG> -->\n' >> "$R/.forge/FORGE.md"          # órfãos
printf '\nOs agentes leem `.claude/agents/` gerado.\n' >> "$R/.forge/constitution.md"  # vazamento
```

```
== CP-1 órfãos: <PROJECT_SLUG> plantado em .forge/FORGE.md
doctor hoje:   ✗ harness: 1 arquivo(s) com placeholders <PROJECT_*> não preenchidos
universo NOVO  (com topo): 1  -> .forge/FORGE.md
universo REV2  (só dirs) : 0
restaurado (cmp ok)
RECONTROLE: doctor=  ✓ harness: sem placeholders <PROJECT_*> órfãos | novo=0

== CP-2 vazamento: ref .claude/ plantada em .forge/constitution.md
doctor hoje:   ✗ harness: 1 arquivo(s) da fonte canônica com refs .claude/
universo NOVO  (com topo): 1  -> .forge/constitution.md
universo REV2  (só dirs) : 0
restaurado (cmp ok)
RECONTROLE: doctor=  ✓ harness: fonte canônica sem refs .claude/ | novo=0
```

**A lista dos oito é fechada, e ela não é "todo arquivo de topo": é o conjunto que o instalador materializa.** Censo exaustivo dos dois lados, com a data:

```bash
find template/.forge -maxdepth 1 -type f | sed 's|.*/||' | sort          # o que o instalador materializa
for f in "$R"/.forge/*; do [ -f "$f" ] || continue; printf '%-30s .claude/=%-3s <PROJECT_*>=%s\n' \
  "$(basename "$f")" "$(/usr/bin/grep -ac '\.claude/' "$f")" "$(/usr/bin/grep -ac '<PROJECT_[A-Z_]*>' "$f")"; done
```

Os oito são `FORGE.md`, `context.md`, `constitution.md`, `forge.yaml`, `runners.yaml`, `README.md`, `secrets-allowlist.txt` e `empty-universe-allowlist.txt`, e na instalação limpa **os oito devolvem zero nos dois predicados** — é por isso que o doctor continua imprimindo `✓✓` e saindo `0`.

**O que os consumidores acrescentam no topo, e por que fica de fora — medido, não presumido.** Varri os treze repositórios com `.forge/` comparando o topo real contra os oito nomes do template (`DATA: 2026-09-08T13:19:17Z` e `13:22:00Z`): os extras são `HANDOFF.md` (em seis repositórios), `SESSIONS.local.md` e `machinery-exceptions.txt` (`axis-fare-validator`) e um `redefinir-senha-lionclaw.sh` (`lionclaw`) — relatório gerado, log local de sessão e script do projeto, nenhum deles fonte canônica do harness. A diferença é medível hoje e ela vai na direção certa: no `axis-fare-validator` o topo tem **3** arquivos casando `.claude/` sob a varredura de hoje e **1** sob o universo novo, porque `HANDOFF.md` e `SESSIONS.local.md` saem — prosa narrativa, exatamente a mesma classe dos blobs do liaison que §2.2 mede — enquanto `FORGE.md` fica, e fica acusado. No `lionclaw` o número não muda: 1 em ambos, e é o `FORGE.md:23`, que carrega `lint: bash .claude/scripts/doctor.sh` numa chave de runtime. Escolher "todo arquivo de topo" em vez da lista fechada traria de volta a narrativa do consumidor **e** o `.DS_Store` que existe no `.forge/` desta árvore, que é binário e onde `grep` sem `-a` devolve silêncio (LDG-0177).

**A lista de oito nomes é literal e ela envelhece — e por isso ela é vigiada, não confiada.** O gate compara a lista que o doctor carrega contra `find template/.forge -maxdepth 1 -type f`, e o contrafactual foi medido em cópia sob `$TMPDIR`: com o template de hoje as duas listas são idênticas; acrescentando um nono arquivo de topo (`policies.yaml`) à cópia, a comparação **acusa** `policies.yaml`. É a invariante 14 aplicada ao único literal que esta decisão introduz — quem acrescentar arquivo canônico de topo ao template sem inscrevê-lo no universo derruba o gate, em vez de perder a varredura em silêncio.

Cada diferença entre as duas listas tem um arquivo medido que a justifica, e é isso que a torna auditável em vez de arbitrária: `hooks/` sai do vazamento porque `hooks/git/lib/check-docs-reviewed.sh` nomeia legitimamente o diretório gerado; `commands/harness/` sai do vazamento pelos dois comandos de maquinaria que existem para gerar esse diretório; `templates/` sai dos órfãos porque `templates/FORGE.md` **é** o scaffold e carrega `<PROJECT_*>` por definição. `adapters/` e `scripts/` ficam fora dos dois por serem maquinaria gerada e engine, não configuração — e ficar de fora aqui é o mesmo que a denylist de hoje já faz para o vazamento; para os órfãos é mudança de escopo, declarada em letra em vez de deixada implícita, que é a segunda ressalva do revisor.

**A componente de topo é idêntica nos dois universos e portanto não acrescenta diferença nenhuma entre eles; das três diferenças que restam, duas são ausência de lista e só UMA é exceção de subcaminho** — a distinção importa e a revisão 1 não a fazia. `hooks/` simplesmente não entra no universo de vazamento e `templates/` não entra no de órfãos: não há exceção a manter, há uma lista que não os contém. `commands/harness/` é a única exceção de subcaminho que sobra, e ela é finita, medida (12 arquivos, dos quais **2** casariam a varredura de vazamento — os dois nomeados acima; `find "$R/.forge/commands/harness" -type f | wc -l` → 12) e vigiada: o gate publica o tamanho de cada um dos dois universos **e** quantos arquivos `commands/harness/` isentou (`[2b]` de §2.4), de modo que uma exceção que engorde apareça no log. Uma denylist, por contraste, cresce com o dado do **consumidor** — `liaison/`, `ledger/`, `pentest-findings/`, e o próximo diretório de dado nasce falso-positivo por padrão —, e é esse crescimento que a inclusão elimina. A crítica da revisão 1 à frase "a denylist ancorada obriga cada exclusão a ser escrita duas vezes" também procede: essa frase era falsa e saiu. O que a inclusão resolve é o **custo** (a varredura não desce em `worktrees/` por construção) e o **crescimento com dado do consumidor**; o que ela não faz é abolir exceção de maquinaria, e fingir que fazia era o defeito.

*Alternativa descartada — acrescentar `liaison/` e `ledger/` à denylist existente.* É o conserto que o consumidor aplicou localmente, e ele está certo para o caso dele. Como política do template ele é a manutenção eterna: o `pentest-findings/` já existiria hoje, e o próximo diretório de dado nasce falso-positivo por padrão. Além disso ele não resolve o custo — `grep -rl` continua descendo em `worktrees/` e filtrando a saída.

*Alternativa descartada — um universo único para as duas varreduras, com as exceções aplicadas a ambas.* Foi a versão da revisão 1 e ela colapsa duas perguntas diferentes numa lista só: `templates/` **tem** de ser vigiado contra vazamento (é o cenário `[3]` de §2.4, com `templates/liaison/CHANNEL.md`) e **não pode** ser vigiado contra órfãos. Uma lista só obrigaria a escolher qual das duas asserções perder.

**D7. A exclusão de `worktrees` do custo é provada em separado, mesmo vindo de graça com D6.**

Com o universo por inclusão, `worktrees/` deixa de ser varrido por construção. Ainda assim o gate tem um cenário que mede o **custo** — que a varredura não desce em `.forge/worktrees/` — e não só o **resultado**. A razão é que D6 é reversível por uma linha, e um gate que só medisse o resultado ficaria verde depois de alguém voltar à denylist "porque era mais simples", com o custo de volta e ninguém sabendo. A propriedade a asserir é: **o número de arquivos abertos pela varredura não cresce quando `.forge/worktrees/` cresce.** O primitivo que mede isso é escolha do implementador — contagem de arquivos visitados, tempo, ou instrumentação do varredor — e ele prova que o primitivo discrimina antes de escrever a asserção, com uma fixture em que a subárvore de worktrees é grande o bastante para o sinal existir.

**D8. Toda âncora de caminho é a partir de `.forge/`, e o gate tem um cenário que prova a distinção.**

Medido em §2.2: `--exclude-dir=<nome>` casa por basename. O cenário planta um arquivo de configuração **real** e violador em `.forge/templates/liaison/CHANNEL.md` e exige que o gate o acuse — se a exclusão for por nome, o gate fica cego e o cenário vermelho.

**D9 (AJUSTADA na revisão 3 pelo efeito colateral da D6). Universo de inclusão vazio é o TERCEIRO ESTADO, ele é declarado POR UNIVERSO, e ele NÃO é mais alcançável nesta árvore — a componente de topo o preencheu.**

A revisão 2 dizia que o universo vazio era alcançável hoje na raiz deste repositório, e isso valia enquanto o universo era só a lista de diretórios: os seis têm **zero** arquivos aqui, porque o dogfood é incompleto e a Fase 1 do plano-mestre é o que muda isso. Com a componente de topo da D6 a medição vira outra, e eu a refiz em 2026-09-08 antes de reescrever esta decisão:

```
raiz do forge-harness (dogfood incompleto):
  topo canônico presente : .forge/FORGE.md .forge/secrets-allowlist.txt .forge/empty-universe-allowlist.txt
  universo VAZAMENTO     : 3 arquivo(s)  -> violações: 0
  universo ÓRFÃOS        : 3 arquivo(s)  -> violações: 0
  só a componente de diretórios: 0 diretório(s) existente(s)
azim-crm (consumidor completo):
  topo canônico presente : FORGE.md context.md constitution.md forge.yaml runners.yaml README.md
  universo VAZAMENTO     : 195  ÓRFÃOS: 200
```

**A consequência é dupla e a onda assume as duas.** Primeira: a **allowlist da raiz não ganha chave nenhuma** — o universo aqui é 3 e não 0, e escrever uma isenção para um vazio que a medição não mostra seria fabricar dispensa. Segunda: o terceiro estado continua sendo obrigatório e continua sendo implementado, porque `.forge/` sem nenhum dos oito nomes e sem nenhum diretório de inclusão é alcançável — é o que um `FORGE_ROOT` apontado para árvore errada ou uma instalação interrompida produz —, mas ele passa a ser exercitado **por fixture** (`[5]` de §2.4) e não pelo estado desta árvore. Um doctor que dissesse `✓ harness: fonte canônica sem refs .claude/` sobre universo zero estaria aprovando por não ter olhado nada, que é a invariante 2 do plano-mestre e o assunto de quatro itens que ele fecha. A saída é `forge_universe_check` (`lib/gate-universe.sh`), com os três estados que ele já implementa, e a chamada é **uma por universo** — dois universos de tamanhos diferentes são duas declarações, e colapsá-las numa só faria um universo cheio esconder o outro vazio.

*Alternativa descartada — tratar universo vazio como sucesso silencioso.* É o defeito que o `forge_universe_check` existe para impedir, e a entrada de allowlist continua sendo a forma de dizer "sei que está vazio e por quê", versionada e revisável, em vez de operada por memória de agente — só que esta onda, medida, não precisa de nenhuma.

*Alternativa descartada — deixar o terceiro estado sobre a UNIÃO dos dois universos.* A união é não-vazia sempre que qualquer um dos dois tiver arquivo, de modo que o varredor de órfãos poderia ficar cego com o de vazamento cheio e ninguém veria. Duas perguntas, duas declarações.

**D10. As mensagens de OK do doctor NÃO mudam.**

`w63[g]` afirma, com `grep -qi`, as strings `sem refs .claude` e `sem placeholders` na saída do doctor, e `w158` e `npx-pack-gate` afirmam `sem placeholders`. As duas linhas de `ok()` ficam byte-idênticas. A linha de `miss()` (`harness: N arquivo(s) da fonte canônica com refs .claude/`) **não é afirmada por gate nenhum** — varredura de `tests/` por `fonte canônica com refs` devolve zero arquivos — e pode ganhar o escopo examinado sem quebrar nada; o implementador reconfere a varredura antes de editar, porque outras ondas desta rodada tocam gates.

**D11. O doctor ganha uma linha informativa sobre `tool_dir` com toolchain em disco e `runtime.pentest` ausente — `info`, nunca `miss`.**

É o quarto ponto, menor, da issue #145, e ele mora aqui porque o arquivo é o mesmo. Medido: `/usr/bin/grep -ac 'pentest' template/.forge/scripts/doctor.sh` devolve **0** — o `doctor.sh` não menciona `pentest` em nenhuma linha. E, segundo a issue #145 (relato de campo, não medição minha), um consumidor com `tools/pentest/Dockerfile` em disco há semanas via `/forge:pentest` responder "nenhum toolchain configurado". Capacidade instalada e não declarada é capacidade que ninguém consegue invocar.

*Alternativa descartada — reprovar (`miss`, `MISSING_DIAG=1`).* Um projeto não-mobile com um diretório `tools/pentest/` legítimo passaria a ter o doctor vermelho, e §2.2 é exatamente a lição de que gate cronicamente vermelho por motivo errado deixa de proteger. `info` informa sem punir.

### 2.4 O VERMELHO, antes do verde

Gate novo `tests/w<NNN>-doctor-scan-universe-gate.sh`, todo ele sobre fixtures em `$TMPDIR` com `FORGE_ROOT` apontando para dentro delas — nunca contra a árvore real, porque `doctor.sh` faz `cd "$ROOT"`.

| # | Cenário | Asserção | Mensagem do vermelho hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [1] | dado do consumidor: `liaison/` e `ledger/` com corpo de mensagem citando `.claude/`, e zero violação de configuração | doctor reporta **zero** vazamento e a linha de OK aparece | `FAIL [1]: o doctor acusou 4 arquivo(s) de dado do consumidor (blobs/log/CHANNEL/LEDGER) como configuração` | o universo é `$ROOT/.forge` inteiro; o predicado não distingue dado de configuração |
| [2] | violação REAL de configuração plantada em `.forge/rules/conventions/<arquivo>.md` | doctor acusa **exatamente esse arquivo**, pelo nome, e sai 1 | `FAIL [2]: com o dado do consumidor no universo, a violação real chega misturada a 4 falsos e ninguém a lê` | é o controle positivo: sem ele, D6 poderia ser "não olhar para nada" |
| [2b] | RETROCOMPATIBILIDADE: **instalação limpa** feita por `bin/forge.mjs init --yes --no-plugin --source template/.forge`, com os quatro arquivos de maquinaria que a §2.3 mede (`hooks/git/lib/check-docs-reviewed.sh`, `commands/harness/build-plugin.md`, `commands/harness/sync-adapters.md`, `templates/FORGE.md`) presentes e intocados | o doctor imprime as **duas** linhas de OK, byte-idênticas às de hoje, e sai `0`; e o gate publica o tamanho dos dois universos (medidos: 193 e 197) e quantos arquivos a exceção de subcaminho isentou | `FAIL [2b]: sob o universo novo o doctor reprovou uma instalação limpa — N em vazamento, M em órfãos` | **não falha por ausência** — verde por construção, e é deliberado: é o controle que impede que D6 quebre `w63[g]`, `w158` e `npx-pack-gate`, exatamente o cenário que a fixture da revisão 1 não tinha e que reprovou a onda |
| [2c] | ARQUIVOS CANÔNICOS DE TOPO, nos dois varredores: `<PROJECT_SLUG>` plantado em `.forge/FORGE.md` e ref `.claude/` plantada em `.forge/constitution.md`, um de cada vez, com restauração conferida por `cmp -s`; e, no mesmo cenário, a **forma exata da fixture do `w158[2]`** — um `template/.forge/` com apenas `scripts/doctor.sh`, `FORGE.md`, `context.md` e `constitution.md`, sem nenhum diretório de inclusão | cada plantio é acusado **pelo nome do arquivo**, exatamente `1`, e a fixture do `w158[2]` devolve exatamente `3` | `FAIL [2c]: a configuração canônica de topo saiu do universo — o plantio em .forge/FORGE.md devolveu 0 e o doctor de hoje devolve 1` | **não falha por ausência** — verde por construção, porque o doctor de hoje já acusa os três casos; é o controle de retrocompatibilidade que faltava na revisão 2 e sem o qual `w158[2]` e `w158[4]` cairiam contra a implementação correta |
| [3] | violação plantada em `.forge/templates/liaison/CHANNEL.md` | doctor **acusa** — a exclusão é ancorada em caminho, não em basename; e `templates/` está no universo de **vazamento** (nunca no de órfãos) | `FAIL [3]: com --exclude-dir=liaison a fonte canônica sob templates/ ficaria cega (medido: zero arquivos varridos, contra um sem a exclusão)` | hoje o arquivo é acusado por acidente (tudo é varrido); sob a correção ingênua ele ficaria cego, e este cenário é o que trava a correção certa |
| [4] | CUSTO: fixture com subárvore grande em `.forge/worktrees/` | a varredura não abre arquivo sob `worktrees/`; propriedade e não literal | `FAIL [4]: a varredura abriu N arquivo(s) sob .forge/worktrees/` | `grep -rl` desce em tudo e filtra só a saída |
| [5] | TERCEIRO ESTADO, **por universo**: fixture sem nenhum diretório de inclusão **e** sem nenhum dos oito arquivos canônicos de topo — as duas componentes ausentes, porque com qualquer uma delas presente o universo não é vazio (medido: a raiz deste repositório tem 3 e não 0) | `forge_universe_check` é chamado **uma vez por universo** e reprova por `universo-vazio`, **ou** aprova com justificativa declarada quando a chave está na allowlist com `# motivo:` — e os dois ramos são exercitados; um universo vazio com o outro cheio reprova | `FAIL [5]: universo vazio aprovou em silêncio` | o doctor de hoje não tem contador de universo; universo vazio e universo limpo terminam no mesmo `ok()` |
| [6] | `tool_dir` com `Dockerfile` presente e `runtime.pentest` ausente | doctor emite a linha informativa e **não** muda o rc | `FAIL [6]: doctor não menciona pentest em linha nenhuma` | `grep -n pentest doctor.sh` devolve zero |
| [7] | CONTADOR DE CONTROLE do próprio gate | `DECLARADOS=10` conferido | — | verde por construção |
| [8] | SENTINELA DO PRÓPRIO GATE | árvore rastreada intacta ao fim | `FAIL [8]: o gate mexeu na árvore real` | verde por construção |

O `[2]` é obrigatório e é a metade que impede a correção preguiçosa: uma inclusão que por engano deixasse `rules/` de fora tornaria `[1]` verde e o gate inteiro inútil. `[1]` sem `[2]` mediria a ausência de trabalho.

O `[2b]` é a lição direta do BLOQUEADOR 1 e ele muda a natureza da bancada: **a fixture sintética não basta**, porque o defeito da D6 anterior morava justamente nos arquivos que uma fixture escrita à mão não pensa em criar. `[2b]` roda o instalador real e mede a árvore que o consumidor recebe, que é onde a decisão de universo cobra o preço.

### 2.5 Prova de mutação

| Mutação | Alvo | O gate tem de dizer | Estado | Recontrole |
|---|---|---|---|---|
| M5 — remover `rules/` do universo de inclusão | doctor | `FAIL [2]` apenas; `[1]` continua verde, o que é a prova de que `[1]` sozinho não mede nada | A MEDIR | restaurar e `[2]` volta a passar |
| M6 — voltar o universo para `$ROOT/.forge` com denylist | doctor | `FAIL [1]` **e** `FAIL [4]` — o predicado e o custo voltam juntos, porque são a mesma decisão | A MEDIR | restaurar e os dois voltam a passar |
| M7 — trocar a âncora de caminho por `--exclude-dir` de basename | doctor | `FAIL [3]` apenas | A MEDIR — e o efeito medido em §2.2 é que a varredura sob `templates/` devolve zero arquivos | restaurar e `[3]` volta a passar |
| M8 — remover a chamada a `forge_universe_check` | doctor | `FAIL [5]` apenas | A MEDIR | restaurar e `[5]` volta a passar |
| M5b — remover a exceção `commands/harness/` do universo de vazamento | doctor | `FAIL [2b]` apenas, nomeando os **dois** arquivos de maquinaria (medido em §2.3) | A MEDIR — é o contrafactual do BLOQUEADOR 1: prova que `[2b]` morde | restaurar e `[2b]` volta a passar |
| M5c — acrescentar `templates/` ao universo de **órfãos** | doctor | `FAIL [2b]` apenas, nomeando `templates/FORGE.md` | A MEDIR — é o mesmo contrafactual pelo segundo varredor | restaurar |
| M5d — remover a componente de arquivos de topo dos **dois** universos (a D6 da revisão 2) | doctor | `FAIL [2c]` apenas, nas três leituras: plantio em `.forge/FORGE.md`, plantio em `.forge/constitution.md` e fixture do `w158[2]` | A MEDIR pelo gate — o efeito já foi medido em bancada e é `0` contra `1`, `0` contra `1` e `0` contra `3` (§2.3), que é o BLOQUEADOR NOVO da revisão 2 | restaurar e `[2c]` volta a passar |

A mecânica obrigatória de §1.6 vale aqui palavra por palavra e não se repete: controle vindo da **árvore de trabalho** e nunca do HEAD, aspas **simples** no `perl -0pi` com todo `$` do lado direito escapado (LDG-0164 — `perl -0pi -e "s/a/$x/"` interpola `$x` do *perl*, vazio, e a mutação vira no-op silencioso enquanto o `cmp` confirma alegremente que o arquivo mudou), restauração conferida por `cmp -s`, e recontrole reexecutando a asserção derrubada.

A regra da matriz vale integralmente: **linha nenhuma é escrita antes de a mutação ser rodada e o efeito observado**, e quando a mutação sai no-op quem se corrige é o **cenário**, cujo sinal não discrimina, nunca a linha. Enfraquecer a linha diante de um no-op é registrar por escrito que a guarda foi testada quando ela não foi.

Para M6 há um risco específico e nomeado: numa fixture pequena a diferença de custo pode não produzir sinal, e a linha `FAIL [4]` viraria hipótese. O implementador dimensiona a subárvore de worktrees da fixture até o sinal existir de forma estável, e mede — não deduz — o piso a partir do qual ele existe.

### 2.6 Contador de controle e níveis de teste

O gate publica `OK doctor-scan-universe/cenarios — 10 cenário(s) executado(s) de 10 declarado(s)`, com denominador literal pela mesma exceção de §1.8. O **doctor** publica **duas** linhas de tamanho de universo, uma por varredura e cada uma dizendo de qual ela fala (`vazamento: N arquivo(s) de configuração` e `órfãos: N arquivo(s) de configuração`), pela via de `forge_universe_check` — a ressalva do revisor é procedente e uma linha só sobre dois universos de tamanhos diferentes não diz nada. Esses números são derivados, nunca literais, porque crescem a cada rule nova. O gate publica também o tamanho dos dois universos e quantos arquivos a única exceção de subcaminho isentou — na instalação limpa de hoje, medidos e não estimados, `vazamento: 193 arquivo(s) examinado(s), commands/harness/ isentou 12 (2 deles casariam)` e `órfãos: 197 arquivo(s) examinado(s)` —, pelo motivo de D6: exceção que engorda em silêncio vira denylist. Os 193 são 185 sob os diretórios mais os 8 de topo, e os 197 são 189 mais os mesmos 8; a aritmética é publicada junto para que a componente de topo não possa desaparecer sem que o número caia. Os dois totais são derivados em execução, nunca literais.

- **Unitário:** `[3]` e `[6]`.
- **Integração:** `[1]`, `[2]`, `[2b]`, `[2c]`, `[4]` e `[5]` — o `doctor.sh` real, executado com `FORGE_ROOT` para dentro da fixture (e, em `[2b]`, sobre uma instalação real produzida por `bin/forge.mjs init`), com a saída lida do processo. Não é a função extraída e testada isolada: é o script pelo qual a decisão chega.
- **Canal de entrega:** o canal real do doctor em produção é `validate-harness.sh:16`, que agrega `doctor.sh --report` e transforma rc≠0 em `FAIL (doctor reported missing load-bearing diagnostics)`. **É por esse canal que o falso-vermelho de §2.2 cobra o pedágio**, e o gate tem um cenário que o exercita: com a fixture de `[1]`, `validate-harness.sh` sai `0` e imprime `OK harness`; com a de `[2]`, sai `1` nomeando o doctor. Sem isso o gate provaria o alvo e não o canal, que é a metade onde `testing/gate-delivery-channel.md` diz que o defeito mora com mais frequência.
- **PBT — não se aplica, com motivo.** O espaço de entrada aqui é um conjunto de caminhos, e a decisão é uma partição por prefixo, sem aritmética, sem parsing e sem ordem. As propriedades interessantes ("todo caminho sob um diretório de inclusão é examinado; nenhum caminho fora é") são exatamente as asserções de `[1]`-`[3]`, e uma geração aleatória de caminhos as reafirmaria sem cobrir espaço novo. O que existe de espaço de entrada de verdade é a **prosa dos blobs do liaison**, e ela já é coberta pelo controle positivo de `[2]`.
- **E2E — não se aplica.** O doctor é um script determinístico sem passo de modelo; `[1]`-`[6]` mais o cenário de `validate-harness.sh` esgotam a fronteira scriptável.

### 2.7 Retrocompatibilidade

**O que já está instalado nos consumidores.** `scripts/doctor.sh` está no `machinery.lock` dos oito repositórios com `.forge/` completo, e `scripts` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS`: o overlay do próximo `forge update` **sobrescreve** o arquivo. Isso tem uma consequência que a issue já nomeia e que esta onda tem de assumir em vez de descobrir depois: **o consumidor `Axis.DevicePlatform` corrigiu os dois defeitos localmente (commits `fb43dd9` e `7f5bd4f`, ledger local `adp#LDG-0610` e `adp#LDG-0611`), e o overlay vai reinstalar os dois defeitos por cima**, na mesma classe de #101. **Esta é premissa de campo, NÃO reproduzida por mim, e a fonte é única e nomeada:** o corpo da issue #127, linhas 4 e 48. Conferi o que dava para conferir daqui e o resultado é negativo nos dois caminhos — `ls ~/Documents/projects/Axis.DevicePlatform` → `No such file or directory` (o repositório não está nesta máquina; os treze com `.forge/` estão enumerados em §2.1), e `/usr/bin/grep -arln 'fb43dd9\|7f5bd4f\|LDG-0610\|LDG-0611' . --exclude-dir=.git` devolve **só esta especificação**, isto é, nem o canal de liaison deste repositório carrega a referência, embora ele tenha 106 mensagens do `axis-device-platform`. A frase sobre o overlay reinstalar os defeitos **naquele consumidor** depende dessa premissa e cai com ela. O que NÃO depende, e é o que a onda usa para decidir, é a medição local: `scripts` está em `MACHINERY_DIRS` (`bin/forge.mjs:307`) e fora de `ENRICHABLE_DIRS` (`:352`), logo o overlay sobrescreve `scripts/doctor.sh` em **todos** os oito consumidores com lock, tenham eles patch local ou não. A exigência de que a release chegue antes do próximo `forge update` vale por essa medição, e continuaria valendo mesmo que a premissa de campo fosse falsa. O aviso de drift do updater imprime o caminho nominalmente e o backup vai para `.git/forge-backups/forge-N`, então a perda não é muda — mas ela é real, e o release desta onda tem de chegar **antes** de o consumidor rodar um update, ou o conserto local dele é revertido para ser reintroduzido pela versão upstream em seguida. O ack da thread correspondente carrega a data da release.

**O que muda de comportamento para o adotante.** Nos consumidores com liaison ativo — e são pelo menos quatro —, o doctor **deixa de reportar** um vazamento que ele reportava. É mudança visível, é deliberada, e é a direção certa: os arquivos que ele deixa de acusar são corpo de mensagem e log, nunca configuração. O mesmo vale, medido, na raiz do `.forge/`: no `axis-fare-validator` o topo tem hoje **3** arquivos casando `.claude/` e passa a ter **1**, porque `HANDOFF.md` (relatório gerado) e `SESSIONS.local.md` (log local de sessão) saem do universo enquanto `FORGE.md` fica e continua acusado; no `lionclaw` o número não muda (1 nos dois, o `FORGE.md:23`, que carrega `lint: bash .claude/scripts/doctor.sh`). Nos outros onze o topo já devolve zero nos dois predicados. Nos consumidores sem liaison o resto do resultado não muda.

**O que não quebra.** `w63[g]` afirma as duas strings de OK com `grep -qi` (`tests/w63-forge-update-gate.sh:185-186`, lidas hoje), que ficam idênticas — e `grep -qi` sobre a saída inteira sobrevive a uma linha nova, que é a conferência que a revisão 1 fez sem registrar e que fica registrada aqui: a linha nova de D9 (`N arquivo(s) de configuração`) não quebra `w63[g]` nem `w158`, porque nenhum dos dois afirma número de linhas nem ordem da saída (`/usr/bin/grep -acn 'grep -q' tests/w158-doctor-placeholder-scope-gate.sh` devolve **6**, nas linhas 45, 64, 74, 79, 86 e 93, todos `grep -q "<substring>" <<<"$out"` — a revisão 2 dizia cinco e o revisor está certo; o número saiu corrigido aqui e nos dois outros sítios que o repetiam); `w158` exercita o guard de placeholders sob `FORGE_ROOT` com specs arquivadas e baseline citando `<PROJECT_ID>` em prosa, e o universo por inclusão **não contém** `specs/` nem `product/`, de modo que os cenários `[1]` e `[3]` do `w158` continuam valendo por construção.

**Os dois cenários do `w158` que a D6 da revisão 2 derrubava, e a medição que mostra que a desta revisão os preserva.** A justificativa que a revisão 2 dava ao implementador aqui era falsa e ela saiu: dizia "confira o `[2]` porque `templates/` está na inclusão", mas `templates/` está fora do universo de **órfãos** em letra desde a própria D6, e os três arquivos que o cenário usa não estão sob `templates/` de todo jeito — estão na **raiz** do `.forge/` aninhado. Reconstruí a fixture do `[2]` (um `template/.forge/` com apenas `scripts/doctor.sh`, `FORGE.md`, `context.md` e `constitution.md`, sem `FORGE_ROOT`) e remedi o `[4]` (um `<PROJECT_SLUG>` plantado no `FORGE.md` do projeto instalado, sob `FORGE_ROOT`), comparando as três leituras:

```
fixture w158[2] — doctor hoje (sem FORGE_ROOT):  ✗ harness: 3 arquivo(s) com placeholders <PROJECT_*> não preenchidos
  universo NOVO  (com topo): 3   -> .forge/constitution.md .forge/context.md .forge/FORGE.md
  universo REV2  (só dirs) : 0   ← o BLOQUEADOR NOVO: nenhum dos cinco diretórios sequer existe nessa fixture

w158[4] — <PROJECT_SLUG> no FORGE.md do projeto real, sob FORGE_ROOT:
  doctor hoje:  ✗ harness: 1 arquivo(s) com placeholders <PROJECT_*> não preenchidos
  universo NOVO  (com topo): 1   -> .forge/FORGE.md
  universo REV2  (só dirs) : 0
  restaurado (cmp ok); recontrole = 0
```

`w158[2]` afirma `grep -q "arquivo(s) com placeholders"` e `w158[4]` afirma `grep -q "1 arquivo(s) com placeholders"`: os dois voltam a valer, com o número exato, e o implementador reconfere as duas leituras acima antes de declarar a onda pronta. `npx-pack-gate` afirma `sem placeholders` sobre o pacote publicado. Nenhuma asserção existente precisa ser afrouxada, e afrouxar alguma delas na implementação é achado da revisão adversarial.

---

## 3. ITEM 3 — issue #140

### 3.1 O que NÃO reproduz, e o que isso significa

O gate `A4 native-control` de `.forge/scripts/check-frontend-design-system.sh` **não existe no `template/`**:

```
$ ls template/.forge/scripts/ | grep -i front
validate-frontmatter.sh
$ /usr/bin/grep -arln 'native-control' . --exclude-dir=.git
./docs/plans/2026-09-07-backlog-zero.md
./docs/plans/spikes/backlog-onda-l6-prosa-e-isolados.md      # esta especificação, que agora cita a string
$ /usr/bin/grep -arl 'A4 ' . --exclude-dir=.git | wc -l      # CONTROLE POSITIVO da mesma varredura
6
```

A única ocorrência da string `native-control` no repositório inteiro, fora desta especificação, é a linha do próprio plano-mestre que descreve a issue — e a varredura foi refeita com `/usr/bin/grep -ar` (não com o `grep` da sessão, que pula binário e arquivo ignorado pelo git; ver o preâmbulo), com controle positivo que prova que ela estava lendo. E no consumidor:

```
$ ls -la ~/Documents/projects/azim-crm/.forge/scripts/check-frontend-design-system.sh
-rwxr-xr-x  43256 bytes
$ wc -l < ~/Documents/projects/azim-crm/.forge/scripts/check-frontend-design-system.sh
871
$ /usr/bin/grep -ac 'check-frontend-design-system' ~/Documents/projects/azim-crm/.forge/cache/machinery.lock
0
$ for d in <os oito com lock>; do /usr/bin/grep -aq 'check-frontend-design-system' "$d/.forge/cache/machinery.lock" && echo "$d"; done
(nenhum)
```

**O script é gate local do consumidor, escrito lá, fora da maquinaria distribuída.** Não veio de release nenhuma, nenhum overlay o instalou, e nenhum overlay vai sobrescrevê-lo. A issue foi aberta contra o harness porque o gate ancora explicitamente na regra 12 de `rules/frontend/design-system.md` e na Fase A da skill `frontend-ui-review`, que **são** do harness — mas o instrumento que reprova, a comparação por arquivo contra baseline, a recusa do `--update-baseline` e o empurrão para `--no-verify` são todos dele.

Isso não desqualifica a issue; redistribui o trabalho. O que o produtor deve a ela é a parte que o produtor produz, e §3.2 mede que essa parte está pior do que o relato sugere.

### 3.2 O que reproduz, e é pior: a receita A4 do template tem poder discriminante ZERO

A regra 12 (`template/.forge/rules/frontend/design-system.md:37`, conferida por `/usr/bin/grep -an 'Controle nativo do browser é domado' template/.forge/rules/frontend/design-system.md`) admite duas saídas: *"Todo controle nativo é ponto de fuga do DS até ser explicitamente estilizado nos pseudo-elementos **ou** encapsulado num componente do DS."* A receita A4 que a skill entrega ocupa as linhas **89-91** de `template/.forge/skills/frontend-ui-review/SKILL.md` — a 88 é a abertura da cerca ```` ```bash ````, e a revisão 1 dizia 91-93, o que estava errado (`/usr/bin/grep -an 'rg -n\|design-system.\|controles-nativos' template/.forge/skills/frontend-ui-review/SKILL.md` → 89, 90, 91 e, separadamente, a classificação em 157). É esta, literal:

```bash
rg -n 'type="(file|color|date|time|range|checkbox|radio)"|<select\b' <src_dir> \
   | grep -v 'design-system' \
   && echo "WARN controles nativos — verificar estilo/encapsulamento" || echo "OK controles-nativos"
```

Reproduzido em fixture com três componentes — um **domado** (CSS irmão com `::-webkit-color-swatch` e `::-moz-color-swatch`), um **não-domado** (CSS irmão sem nenhum pseudo-elemento) e um **encapsulado** sob um caminho que contém `design-system`:

```
=== receita A4 (SKILL.md:89-91), universo inteiro:
src/Domado/A.tsx:1:export const A = () => <input type="color" className={s.i} />;
src/NaoDomado/B.tsx:1:export const B = () => <input type="color" />;
WARN controles nativos

=== o predicado distingue DOMADO de NÃO-DOMADO?
Domado       ocorrências=1 veredito=WARN
NaoDomado    ocorrências=1 veredito=WARN

=== e o CSS irmão, que é o escape que a regra 12 lista PRIMEIRO:
Domado       pseudo-elementos no CSS irmão: 2
NaoDomado    pseudo-elementos no CSS irmão: 0
```

As duas últimas linhas são o par que fecha o argumento e que faltava na revisão 1: **existe sinal, e ele é limpo — 2 contra 0 —, e o instrumento do template não o lê.** Não é que a distinção seja difícil; é que a receita procura no arquivo errado.

**O predicado do template não distingue conformidade de violação.** Ele reconhece o escape do *encapsulamento* — e mesmo esse por substring de caminho, um proxy fraco —, e é **cego** ao escape que a própria regra 12 lista primeiro, a estilização dos pseudo-elementos. Não é falso positivo ocasional: é um instrumento cujo veredito é idêntico nos dois lados da regra que ele mede.

É o mesmo mecanismo do defeito 2 da #127, num segundo instrumento do mesmo repositório: **medir menção de texto como se fosse conformidade.** E ele produz o WARN crônico que a issue descreve chegando ao consumidor como FAIL, com o número que o próprio relato traz — 13 dos 62 controles do baseline congelado já estavam domados e eram contados como dívida.

### 3.3 Decisões de desenho — FECHADAS

**D12. A receita A4 deixa de ser um `rg` em prosa e vira scanner determinístico, irmão do `scan-phantom-tokens.py`, que reconhece OS DOIS escapes da regra 12.**

O escape por pseudo-elemento é verificado no **CSS irmão** — mesmo diretório do markup —, deliberadamente e não no monorepo inteiro: um `.module.css` em outro diretório não isenta ninguém, porque a prova de domesticação tem de estar onde o componente está. A tabela de seletores que prova cada controle é a que o consumidor mediu e vale como ponto de partida, não como lista fechada: `color` → `::-webkit-color-swatch` / `::-moz-color-swatch`; `file` → `::file-selector-button` / `::-webkit-file-upload-button`; `range` → `::-webkit-slider-thumb` / `::-moz-range-thumb` / `appearance:none`; `date|time|datetime-local|month|week` → `::-webkit-calendar-picker-indicator` / `::-webkit-datetime-edit`; `<select>` → `appearance:none`, porque não há pseudo padronizado nos dois motores.

O escape por encapsulamento deixa de ser substring de caminho e passa a ser declarado: o scanner recebe o(s) diretório(s) do design system como argumento, do mesmo jeito que `scan-phantom-tokens.py` recebe o arquivo de tokens e a allowlist. Substring de caminho é a mesma classe de erro de `--exclude-dir` por basename, medida em §2.2.

*Alternativa descartada — manter o `rg` e só acrescentar um segundo `grep -v` para pseudo-elementos.* Um `grep` que procura pseudo-elemento no mesmo arquivo do markup não acha nada, porque o markup está em `.tsx` e o CSS em `.module.css`; e um que procure na árvore inteira isenta o componente errado. A correlação markup↔CSS irmão exige percorrer diretório, e isso não cabe num pipeline de uma linha sem virar ilegível.

A linguagem do scanner fica aberta e tem uma consequência medida: se ele for Python, como o irmão `scan-phantom-tokens.py`, ele herda o `SKIP (python3 ausente)` da **linha 15** do `w96` (`/usr/bin/grep -an 'python3 ausente' tests/w96-frontend-ui-review-gate.sh` → `15:`; a revisão 2 dizia 16 nos dois sítios), que hoje imprime `SKIP` **e** `PASS` e sai `0` antes de qualquer cenário — o terceiro estado tem de sobreviver à ampliação (§3.6). Se for bash 3.2, não herda o SKIP mas paga a correlação de diretórios em shell. O implementador escolhe e prova.

*Alternativa descartada — declarar A4 "não verificável automaticamente" e removê-lo.* O incidente que originou o A4 está registrado no anexo da própria skill (botão "Escolher arquivo" cinza do SO, swatch com borda nativa) e é real. Remover o gate por ele ser mal construído é jogar fora o achado junto com o instrumento.

**D13. A classificação do A4 é ADVISORY, declarada em letra na skill E na regra, e a divergência do consumidor é nomeada em vez de contornada.**

A skill classifica A4 como `[OK|WARN]` (`SKILL.md:157` — `sed -n '157p' template/.forge/skills/frontend-ui-review/SKILL.md` → `  [OK|WARN] A4 controles-nativos`) e o script do consumidor bloqueia com rc 1. As duas superfícies precisam concordar, e a que o harness controla é a skill — então o harness declara: **A4 é advisory**, e um gate que bloqueie sobre A4 está divergindo de uma classificação declarada, o que é decisão legítima do projeto desde que consciente.

*Alternativa descartada — tornar A4 bloqueante no template.* O template não tem script de A4 com que bloquear (§3.1), e mesmo com o scanner de D12 um A4 bloqueante herdaria o problema de fundo da issue: uma dívida herdada grande o bastante para o primeiro componente novo bater na parede. A1 e A2 são bloqueantes porque medem ausência (token fantasma não definido) e têm remédio local; A4 mede um passivo de superfície inteira. A saída para quem quiser bloquear é o baseline congelado, e o baseline é decisão do projeto, não do template.

**D14. A onda NÃO adota `check-frontend-design-system.sh` no template, e a medição sustenta a recusa.**

O script tem 871 linhas e depende **duramente** de `pnpm-workspace.yaml` — `FAIL A5 coverage — pnpm-workspace.yaml não existe em {root}` —, dos globs de workspace e das dependências `workspace:*` declaradas em cada `package.json`. Medido em 2026-09-08 com `for d in <os treze>; do [ -f "$d/pnpm-workspace.yaml" ] && echo "$d"; done`: **2 têm `pnpm-workspace.yaml` (`axis-go-cloud` e `azim-crm`), 11 não têm.** A dependência dura está em `check-frontend-design-system.sh:194` (`WORKSPACE = root / "pnpm-workspace.yaml"`) e `:200` (`print(f"FAIL  A5 coverage        — pnpm-workspace.yaml não existe em {root}")`). Distribuir esse gate seria entregar a onze consumidores um script que reprova na primeira linha ou aprova por vacuidade — e a Onda D deste mesmo plano existe porque aprovar por vacuidade é o mecanismo que mais mordeu este programa.

**D15. O consumidor é respondido pelo canal de liaison, com o que reproduziu e o que não, e um item de ledger registra a decisão de não adotar.**

O ack diz três coisas, nesta ordem, porque a terceira é a que tem valor para quem abriu a issue: que o script é dele e o harness não pode consertá-lo por overlay; que a metade do harness estava pior do que o relato — a receita A4 não distinguia domado de não-domado, e portanto o baseline congelado de 62 que "media conformidade em boa parte" tinha uma segunda causa além da que ele encontrou; e que a correção do scanner e a classificação advisory chegam por release, disponíveis para ele portar para o gate local dele se quiser. Item de ledger: "adoção do `check-frontend-design-system.sh` no template — bloqueada por dependência de `pnpm-workspace.yaml` (2 de 13 consumidores); reavaliar quando existir uma abstração de superfície independente de gerenciador".

### 3.4 O VERMELHO, antes do verde

Os cenários entram em **`tests/w96-frontend-ui-review-gate.sh`**, que já existe e já exercita o scanner de A1 como núcleo executável. **Nenhum ordinal novo é alocado para este item** — ampliar o gate do assunto é mais barato que criar um segundo, e a invariante 10 diz que ordinal é recurso que se paga uma vez.

| # | Cenário | Asserção | Mensagem do vermelho hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [5] | controle nativo **domado** (CSS irmão com os pseudo dos dois motores) | scanner sai `0` e **não** reporta o componente | `FAIL [5]: scanner de controle nativo ausente (template/.forge/skills/frontend-ui-review/scripts/scan-native-controls.py)` | o scanner não existe; a receita é `rg` em prosa |
| [6] | controle nativo **não-domado** (CSS irmão sem pseudo) | scanner sai `1` e reporta o arquivo **pelo nome** | idem | idem |
| [7] | ANTI-VACUIDADE: [5] e [6] com o **mesmo** `input`, mudando só o CSS irmão | o veredito difere entre os dois — é o par que impede que o verde de [5] venha de o scanner ter parado de enxergar controle nativo | `FAIL [7]: o predicado dá o mesmo veredito para domado e não-domado (medido hoje: 1 ocorrência de cada, WARN nos dois)` | é a reprodução de §3.2 virada em asserção |
| [8] | encapsulamento declarado: componente sob o diretório de DS passado por argumento | scanner sai `0`; e o **mesmo arquivo**, com o argumento ausente, sai `1` | `FAIL [8]: o escape de encapsulamento é substring de caminho, não declaração` | hoje é `grep -v 'design-system'` |
| [9] | CONTADOR do scanner | número de controles nativos examinados publicado; zero reprova | `FAIL [9]: scanner sem contador — aprovaria por não ter olhado nada` | não existe |
| [10] | classificação declarada e coerente | `SKILL.md` diz A4 advisory no formato de saída **e** na descrição do gate; a rule 12 aponta a classificação | `FAIL [10]: a skill classifica A4 como advisory na linha de saída e o texto do gate não diz nada` | a classificação existe em um lugar só e não é afirmada por gate nenhum |

O `[7]` é o cenário que fecha #140 do lado do produtor, e é o par de fixtures que o consumidor já provou ser o certo (`30-controle-nativo-domado` / `31-controle-nativo-nao-domado`, mesma tela, mesmo `input`, só muda o CSS irmão). Crédito onde é devido: a forma da prova veio do relato dele.

### 3.5 Prova de mutação

| Mutação | Alvo | O gate tem de dizer | Estado | Recontrole |
|---|---|---|---|---|
| M9 — remover do scanner a checagem de CSS irmão | scanner | `FAIL [5]` e `FAIL [7]`; `[6]` continua verde | A MEDIR | restaurar e os dois voltam a passar |
| M10 — remover do scanner o reconhecimento de controle nativo no markup | scanner | `FAIL [6]` e `FAIL [7]` e `FAIL [9]` (contador zera) | A MEDIR — é a mutação que prova que `[5]` não é verde por cegueira | restaurar |
| M11 — trocar o argumento de diretório de DS por substring de caminho | scanner | `FAIL [8]` apenas | A MEDIR | restaurar e `[8]` volta a passar |
| M12 — trocar, na `SKILL.md`, `[OK\|WARN] A4` por `[OK\|FAIL] A4` | skill | `FAIL [10]` | A MEDIR | restaurar e `[10]` volta a passar |

M9 e M10 juntas são o que dá sentido a `[7]`: uma derruba o lado domado, a outra derruba o lado não-domado, e um predicado que sobreviva às duas não está medindo a regra.

A mecânica obrigatória de §1.6 vale aqui integralmente e não se repete: controle da árvore de trabalho, aspas simples no `perl -0pi` com `$` escapado (LDG-0164), `cmp -s` na restauração, recontrole reexecutando a asserção derrubada. E a regra de §2.5 também: mutação que sai no-op corrige o **cenário**, nunca a linha da matriz.

### 3.6 Contador, níveis e retrocompatibilidade

O `w96` de hoje não publica contador de cenários; a ampliação **acrescenta um**, com denominador literal `DECLARADOS=11` — os cinco que o gate já tem (`[1]`, `[2]`, `[2b]`, `[3]`, `[4]`) mais os seis desta onda —, porque o universo é a lista de cenários do próprio arquivo. O scanner publica o seu próprio contador, derivado (`N controle(s) nativo(s) examinado(s)`), e reprova em zero. Uma armadilha nominal do `w96`: ele **pula tudo** com `SKIP (python3 ausente)` e sai `0` na **linha 15** — `/usr/bin/grep -an 'python3 ausente' tests/w96-frontend-ui-review-gate.sh` devolve `15:`, e a revisão 2 dizia 16 —, antes de qualquer cenário — o contador de cenários tem de reportar `0 de 11` nesse caminho e o `SKIP` tem de ser distinguível de `PASS` na saída, senão a ampliação nasce com o terceiro estado colapsado no verde, que é a invariante 2 do plano-mestre.

- **Unitário:** `[5]`, `[6]`, `[8]`.
- **PBT — não se aplica, com motivo medido.** O espaço de entrada do scanner é markup e CSS, e o que ele decide é uma correlação entre dois arquivos vizinhos por um conjunto **finito e enumerado** de seletores. Gerar markup aleatório testaria o parser de `rg`, não a regra. O par de fixtures de `[7]`, com uma variável isolada, cobre exatamente o que precisa ser coberto, e `[9]` impede que ele fique vazio.
- **Contrato:** `[10]`. A `SKILL.md` é fronteira publicada — ela está no `machinery.lock` dos oito consumidores — e a classificação advisory passa a ser afirmada.
- **Integração e E2E — não se aplicam.** A skill é lida e executada por um modelo; não há canal determinístico entre a `SKILL.md` e o veredito além do scanner, que `[5]`-`[9]` exercitam direto. Fingir um E2E sobre o passo do modelo seria teatro.

**Retrocompatibilidade, e ela tem uma armadilha nominal.** `w96[4]`, na **linha 72** do gate, afirma com `grep -q` a string literal **`Controle nativo do browser é domado`** em `template/.forge/rules/frontend/design-system.md` — `/usr/bin/grep -an 'Controle nativo do browser é domado' tests/w96-frontend-ui-review-gate.sh` devolve `72:`, e a tabela de §5 da revisão 1 dizia 73, o que estava errado. A regra 12 começa exatamente com essa frase, e qualquer reescrita da abertura dela derruba `w96[4]`. **A frase não muda**; o que a regra ganha é a menção à classificação, depois dela. A varredura de `tests/` pelas outras strings do assunto (`controles-nativos`, `controle nativo`) devolve **zero** arquivos — com `/usr/bin/grep -arn`, e com o censo do universo já feito (nenhum arquivo de `tests/` é ilegível como texto; ver o preâmbulo), então o vazio é ausência e não cegueira. Nada mais está preso.

**A correção chega aos oito consumidores, e isso é medido, não suposto.** `skills` está em `MACHINERY_DIRS` **e** em `ENRICHABLE_DIRS` (`bin/forge.mjs:307` e `:352`), o que normalmente significaria que um consumidor com customização local manteria a versão dele e ficaria sem a correção. Não é o caso: `skills/frontend-ui-review/SKILL.md` está no `machinery.lock` dos **8 de 8**, e em todos os 8 o sha256 local bate simultaneamente com o do lock e com o do template desta branch — comando: `tpl=$(shasum -a 256 template/.forge/skills/frontend-ui-review/SKILL.md); for d in <os 8>; do compara local × lock × tpl; done` → `==lock ==tpl` nas oito linhas. Comando, rodado em 2026-09-08: `TPL=$(shasum -a 256 template/.forge/skills/frontend-ui-review/SKILL.md | awk '{print $1}')` e, por consumidor, a comparação de `shasum` local contra a entrada do lock e contra `$TPL` — saída `==lock ==tpl` nas oito linhas, com `$TPL = 5a688f790676952ecd1938ca075264360cc4f05554fb4d897506cce096034e7a`. **Zero patch local**, logo o caminho enriquecível decide sobrescrever e a correção chega inteira. Se algum consumidor customizar a `SKILL.md` entre esta especificação e a release, ele fica sem a correção e o ack precisa dizer isso — o implementador remede a tabela antes do release em vez de repetir este parágrafo de memória.

O `README.md` conta `skills/   (20)` (linha 232), e o critério que `w200[1]` aplica é `find template/.forge/skills -type f ! -name 'README.md' | wc -l`, medido hoje em **20**; o scanner novo torna **21**. A linha é atualizada no mesmo commit, sob pena de `w200[1]` reprovar com `inventário do README defasado em 'template/.forge/skills/' — declarado (20), real (21)`.

---

## 4. ITEM 4 — issue #145

### 4.1 Os três defeitos, reproduzidos verbatim no template

São três defeitos **independentes** no mesmo caminho de código, e nenhum aparece como erro claro: o comando ou builda uma segunda imagem de 1,7 GB em silêncio, ou morre com um `FAIL` genérico.

**Defeito 1 — o nome da imagem é fixo no engine e ignora o `tool_dir` do consumidor.** `template/.forge/scripts/pentest-ops.sh:26` é `PENTEST_IMAGE="forge-pentest"`, constante de topo, e as **nove** referências a ela nunca consultam a configuração. Nove, não sete — a revisão 1 escreveu "sete" e listou nove números, e o número certo é o da lista; `/usr/bin/grep -an ':latest' template/.forge/scripts/pentest-ops.sh` devolve `:180`, `:181`, `:221`, `:222`, `:224`, `:226`, `:233`, `:261` e `:281`, e `/usr/bin/grep -ao ':latest' template/.forge/scripts/pentest-ops.sh | wc -l` devolve 9. O bloco `runtime.pentest` deixa o consumidor declarar `tool_dir`, e é de lá que sai o `Dockerfile` **e** o `docker-compose.yml` — mas o único lugar do engine que abre o compose é `cmd_deactivate` (`:287-288`, `docker compose -f "$td/docker-compose.yml" down -v`; `/usr/bin/grep -an 'docker-compose.yml' template/.forge/scripts/pentest-ops.sh` devolve exatamente essas duas linhas, e `:286` é o `td="$(pentest_tool_dir)"` que as precede — a ressalva da revisão 1 sobre `:286-289` não procede, porque quem **abre** o compose são a 287 e a 288), isto é, **o engine já sabe que o compose existe e ainda assim não lê o nome da imagem dele**. O consumidor declara `image: axis/pentest:dev`, a imagem existe em disco com 1,7 GB, e o `status` responde `toolchain buildado: não (rode /forge:pentest activate para buildar)` — e um `activate` construiria `forge-pentest:latest` ao lado dela.

**Defeito 2 — a tag é `latest`, e isso viola uma regra que o próprio harness distribui.** `pentest-ops.sh:224` é `run_to 1200 docker build -t "$PENTEST_IMAGE:latest" "$td"`. E `template/.forge/rules/conventions/docker-naming.md:53` diz, em negrito, ***"`latest` é PROIBIDA em qualquer ambiente (local, dev, stg, prd)"***, com a linha `:111` repetindo entre os anti-patterns (`/usr/bin/grep -an 'latest' template/.forge/rules/conventions/docker-naming.md` → exatamente `53:` e `111:`). A regra não é do consumidor: é do harness, e ela está instalada em todos os consumidores medidos (`grep -rn latest ~/Documents/projects/*/.forge/rules/conventions/docker-naming.md` devolve as mesmas duas linhas em cada um). **O harness entrega um comando que cria uma tag `latest` e uma rule que a proíbe, no mesmo pacote**, e o consumidor não tem como impedir sem editar um arquivo que está no `machinery.lock` — dívida que o próximo overlay desfaz.

**Defeito 3 — o `scan` invoca um entrypoint que o harness nunca especificou.** `pentest-ops.sh:261-262`:

```
    "$PENTEST_IMAGE:latest" \
    pentest-scan "/work/$apkbase" /out || { echo "FAIL pentest:scan — workflow estático falhou"; return 1; }
```

`pentest-scan <apk> <outdir>` é um **contrato de imagem** com nome e aridade específicos, e ele não está escrito em lugar nenhum. Medido: `find template -iname '*ockerfile*'` devolve **apenas** `template/.forge/hooks/pre-commit/check-dockerfile-multiarch.sh`, isto é, **o harness não entrega template de Dockerfile de pentest nenhum**; `/usr/bin/grep -acn 'pentest-scan' template/.forge/commands/waves/pentest.md` devolve **0**; e o cabeçalho do engine documenta `skill`, `bench_device`, `apk_path` e `tool_dir` como se qualquer toolchain servisse. O `Dockerfile` vendorizado do consumidor termina em `CMD ["bash"]` e não tem `pentest-scan`, e o comando falha com `FAIL pentest:scan — workflow estático falhou`, indistinguível de "a análise achou um problema" e de "o APK não pôde ser lido". Este é o mais grave dos três porque é **contrato implícito**: o harness documenta a configuração como se ela bastasse, e exige em silêncio uma imagem que exponha um binário.

### 4.2 A assimetria que fecha o argumento, e ela está no mesmo arquivo

O perfil **strix** do mesmo `pentest-ops.sh` fixa a imagem por **digest completo** — `image_digest: "ghcr.io/usestrix/strix-sandbox@sha256:<64 hex minúsculos>"`, com `R4/imagem-nao-fixada` recusando quando o formato não confere ou a imagem não está no daemon local, e `cli_version` obrigatória porque "fixação opcional é fixação que ninguém fixa". São **nove** recusas de pré-voo antes de o processo subir, e elas estão em `commands/waves/pentest.md:139-147`, não em `:118-142` como a revisão 1 escreveu: `/usr/bin/grep -ao 'R[0-9]\+/[a-z-]*' template/.forge/commands/waves/pentest.md | sort -u` devolve nove tokens — `R1/opt-in-bancada`, `R2/alvo-nao-autorizado`, `R3/autorizacao-nao-registrada`, `R4/imagem-nao-fixada`, `R5/teto-de-gasto`, `R6/kill-switch-de-egresso`, `R7/rede-dedicada`, `R8/skills-do-fornecedor`, `R9/binario-e-versao` — e a mesma varredura com `-n` os localiza nas linhas 139 a 147, uma por linha. rc **4** para pré-voo recusado ou inconclusivo (`/usr/bin/grep -an 'return 4' template/.forge/scripts/pentest-ops.sh` → `:1018`, `:1026`, `:1032`, `:1043`), e um manifesto que registra sob que contenção a execução ocorreu.

O perfil **mobile**, no mesmo arquivo, tem nome de imagem hardcoded, tag `latest`, zero verificação e um `FAIL` genérico. As duas disciplinas convivem a setecentas linhas de distância. Isto não é argumento retórico: é a prova de que o vocabulário certo já existe neste engine e a correção não precisa inventar nada — só estender ao perfil que ficou para trás.

### 4.3 Decisões de desenho — FECHADAS

**D16. O nome da imagem passa a ser resolvido por precedência declarada, e o `status` diz QUAL referência procurou.**

Precedência: `runtime.pentest.image` explícito > `image:` do `docker-compose.yml` sob `tool_dir` > o nome fixo `forge-pentest`, como último recurso e não como primeira escolha. A propriedade que o gate trava é: **para cada uma das três origens, a referência que o engine procura é a que aquela origem declara**, e o `status` a imprime — de modo que `toolchain buildado: não` deixe de colapsar com "buildado sob outro nome". A linha de `status` de hoje (`toolchain buildado: sim|não`) não é afirmada por gate nenhum (varredura de `tests/` por `toolchain buildado` devolve zero), então ela pode ganhar a referência.

*Alternativa descartada — derivar só do compose, sem `runtime.pentest.image`.* Nem todo consumidor tem compose (o `Dockerfile` sozinho é suficiente para `activate`), e a issue mede um que tem os dois. A chave explícita é o ponto fixo para quem não tem compose, e o compose é a conveniência para quem tem.

*Alternativa descartada — `docker compose config --images` para resolver o nome.* É a resposta correta em teoria e cara na prática: exige o binário `docker compose` disponível só para **ler um nome**, o que torna `status` — hoje puro texto até a checagem de imagem — dependente do daemon, e obriga um `run_to` a mais no caminho de leitura. Extrair o `image:` do YAML é escolha do implementador, e ele prova que o primitivo escolhido resolve o caso medido (`image: axis/pentest:dev` com `container_name` na linha seguinte) e recusa em vez de adivinhar quando o compose tem mais de um serviço.

**D17. A tag vem da configuração, com default derivado, e `latest` deixa de aparecer no engine.**

`runtime.pentest.tag`, default `dev`. Quando a referência vem do compose com tag embutida (`axis/pentest:dev`), a tag é a do compose e a chave não é consultada — referência completa vence referência montada. A propriedade que o gate trava é dupla: o engine **não contém a string `:latest` em sítio nenhum**, e a tag efetiva é a declarada.

*Alternativa descartada — manter `latest` e documentar a exceção.* O harness distribui a rule que a proíbe. Uma exceção documentada no próprio pacote que entrega a proibição é a definição de norma que não se aplica a quem a escreve, e a issue nomeia o custo exato: o consumidor não consegue corrigir sem editar arquivo do `machinery.lock`.

**D18. O `scan` verifica o contrato do entrypoint ANTES de executar, e recusa com rc 4 e a razão nomeada.**

Três estados, nunca dois — invariante 2 do plano-mestre: `0` o workflow rodou e produziu findings; `1` o workflow rodou e reprovou; **`4`** não foi possível executar, com a razão nomeada (imagem ausente sob a referência procurada, ou imagem presente sem o entrypoint `pentest-scan`). O rc 4 **não é invenção desta onda**: é o vocabulário que o perfil strix do mesmo arquivo já usa para pré-voo recusado e inconclusivo (`:1018`, `:1026`, `:1032`, `:1043`), e reusá-lo é coerência, não expansão.

*Alternativa descartada — o harness ENTREGAR o `pentest-scan`, montando um script do próprio `.forge/` dentro do container.* A issue oferece essa saída e ela é tentadora, mas ela transfere para o harness a responsabilidade pelo **workflow interno** do toolchain — qual jadx, qual apktool, qual semgrep, com que regras —, que é exatamente o que `tool_dir` existe para delegar ao consumidor; e o mount exigiria sobrepor o `ENTRYPOINT` que a imagem declarada no compose pode já definir, criando um segundo contrato implícito para substituir o primeiro. O harness declara o contrato e verifica que ele é honrado; quem o implementa é a imagem.

*Alternativa descartada — o harness entregar um template de Dockerfile.* Congelaria no template uma escolha de toolchain de 1,7 GB, e onze dos treze consumidores medidos não são mobile.

**D19. O contrato passa a estar escrito onde o consumidor o lê: no `pentest.md`, no cabeçalho do engine e na saída do `status`.**

`pentest-scan <caminho-do-apk-no-container> <diretório-de-saída>`, com o `PENTEST_SKILL` no ambiente. Como `template/.forge/commands/` é tocado, o espelho `plugin/forge/commands/pentest.md` é regenerado por **`npm run build:plugin`** — nunca `build-plugin.sh`, que instala em `$HOME` — sob pena de o `plugin-sync-gate` reprovar.

**D20. O `doctor` acusa `tool_dir` com toolchain em disco e `runtime.pentest` ausente, como `info`.**

É D11 de §2.3, e vive lá porque o arquivo é o `doctor.sh`. Registrado aqui para que a leitura de #145 encontre a resposta ao quarto ponto dela.

### 4.4 O VERMELHO, antes do verde

Gate novo `tests/w<NNN>-pentest-image-contract-gate.sh`, com stubs de `docker` e `adb` num `PATH` dedicado, no molde do `w142` — determinístico, sem tocar o host, sem docker real.

| # | Cenário | Asserção | Mensagem do vermelho hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [1] | `runtime.pentest.image` declarado | o engine procura **essa** referência, e o `status` a imprime | `FAIL [1]: o engine procurou 'forge-pentest:latest' e a config declara outra imagem` | `PENTEST_IMAGE` é constante de topo (`:26`) e a chave `image` não é lida |
| [2] | sem `image`, com `docker-compose.yml` sob `tool_dir` declarando `image:` | o engine deriva a referência do compose | `FAIL [2]: compose declara <ref> e o engine procurou 'forge-pentest:latest'` | o compose só é aberto em `deactivate` (`:287`) |
| [3] | sem `image` e sem compose | o engine cai no nome fixo, e o `status` **diz que caiu** | `FAIL [3]: status não diz qual referência procurou — 'não buildado' colapsa com 'buildado sob outro nome'` | o `status` imprime a constante sem dizer de onde ela veio |
| [4] | tag: `runtime.pentest.tag` ausente | a tag efetiva é `dev`, e **`:latest` não aparece no engine** | `FAIL [4]: N sítio(s) do engine usam ':latest', proibido por rules/conventions/docker-naming.md:53` — **N derivado por varredura, nunca literal**; hoje N=9 | `:latest` está literal em `:180`, `:181`, `:221`, `:222`, `:224`, `:226`, `:233`, `:261` e `:281` (nove, medidos em §4.1) |
| [5] | imagem **ausente** sob a referência procurada | `scan` recusa com **rc 4**, nomeando a referência, e **não** invoca `docker run` | `FAIL [5]: scan rc=1 com a mesma mensagem de 'workflow falhou' — não distingue 'não consegui executar' de 'reprovou'` | `cmd_scan` só conhece rc 0 e 1 |
| [6] | imagem presente **sem** o entrypoint `pentest-scan` | `scan` recusa com **rc 4**, nomeando o binário ausente, antes de rodar o workflow | `FAIL [6]: FAIL pentest:scan — workflow estático falhou (indistinguível de análise que achou problema)` | não há verificação de contrato em sítio nenhum |
| [7] | imagem presente **com** o entrypoint | `scan` executa e sai `0` | — mede o caminho feliz e impede que [5]/[6] sejam satisfeitos por um `scan` que recusa sempre | — |
| [8] | CONTRATO DOCUMENTADO | `pentest.md` e o cabeçalho do engine descrevem `pentest-scan <apk> <outdir>`; espelho do plugin idêntico | `FAIL [8]: 'pentest-scan' não aparece em pentest.md nem no cabeçalho do engine` | `grep -n pentest-scan template/.forge/commands/waves/pentest.md` devolve zero |
| [9] | CONTADOR DE CONTROLE | `DECLARADOS=10` conferido | — | verde por construção |
| [10] | SENTINELA DO PRÓPRIO GATE | árvore rastreada intacta ao fim | `FAIL [10]: o gate mexeu na árvore real` | verde por construção |

O `[7]` é obrigatório e é o que impede a correção preguiçosa: uma verificação que recusasse sempre tornaria `[5]` e `[6]` verdes e o comando inútil. Ele é ao par de `[5]`/`[6]` o que o `[2]` é ao `[1]` em §2.4.

### 4.5 Prova de mutação

| Mutação | Alvo | O gate tem de dizer | Estado | Recontrole |
|---|---|---|---|---|
| M13 — voltar `PENTEST_IMAGE` a constante ignorando a config | engine | `FAIL [1]`, `FAIL [2]`; `[3]` continua verde, porque nele o fallback **é** o comportamento certo | A MEDIR | restaurar e os dois voltam a passar |
| M14 — reintroduzir `:latest` num único sítio | engine | `FAIL [4]`, nomeando o sítio | A MEDIR | restaurar e `[4]` volta a passar |
| M15 — remover a verificação do entrypoint, mantendo a da imagem | engine | `FAIL [6]` apenas; `[5]` continua verde | A MEDIR — a separação é o que prova que as duas recusas são independentes | restaurar |
| M16 — trocar o rc 4 da recusa por rc 1 | engine | `FAIL [5]` **e** `FAIL [6]` | A MEDIR | restaurar |
| M17 — remover a linha de contrato do `pentest.md` | doc | `FAIL [8]` | A MEDIR | restaurar e `[8]` volta a passar |

M15 existe porque as duas recusas de D18 têm causas diferentes e remédios diferentes — "buildar a imagem" e "expor o binário" —, e um gate que as colapsasse deixaria o operador com a mesma adivinhação que a issue reclama. É o mesmo defeito que §1.2 mediu no `_common.sh`, onde três causas saem com o mesmo rc 1: aqui a onda evita nascer com ele, lá ela documenta e registra no ledger.

A mecânica obrigatória de §1.6 vale aqui integralmente e não se repete: controle da árvore de trabalho, aspas simples no `perl -0pi` com `$` escapado (LDG-0164), `cmp -s` na restauração, recontrole reexecutando a asserção derrubada. E a regra de §2.5 também: mutação que sai no-op corrige o **cenário**, nunca a linha da matriz.

### 4.6 Contador, níveis e retrocompatibilidade — a parte mais delicada desta onda

O gate publica `OK pentest-image-contract/cenarios — 10 cenário(s) executado(s) de 10 declarado(s)`, denominador literal pela exceção de §1.8. O cenário `[4]` publica o número de sítios de `:latest` encontrados, **derivado por varredura e nunca literal** — e é por isso que os três números divergentes da revisão 1 ("sete" no texto, nove na lista, oito na tabela) não eram bloqueador, mas eram medição que não reproduz, e por isso foram remedidos: são **nove**.

- **Unitário:** `[1]`, `[2]`, `[3]`, `[4]`, `[8]`.
- **Integração:** `[5]`, `[6]`, `[7]` — o `pentest-ops.sh` real com stubs de `docker` no `PATH`, exercitando `cmd_scan` de ponta a ponta e lendo o rc do processo.
- **Contrato:** `[8]` mais a paridade com o espelho do plugin. O bloco `runtime.pentest` é fronteira publicada e ganha duas chaves opcionais (`image`, `tag`); a ausência das duas tem de produzir o comportamento de hoje, e é isso que `[3]` e `[4]` travam juntos.
- **PBT — não se aplica, com motivo.** O espaço de entrada é uma precedência de três origens, enumerada e fechada, e os três ramos são `[1]`, `[2]` e `[3]`. O único parsing de verdade é o do `image:` do compose, e o espaço interessante dele — mais de um serviço, tag embutida ou não, aspas — é finito e cabe em cenários nomeados, onde o vermelho é legível. Gerar YAML aleatório testaria o extrator contra um oráculo que a onda teria de escrever, e o oráculo é o defeito.
- **E2E — não se aplica, com motivo medido.** Um E2E real exigiria `docker build` de uma imagem de toolchain de 1,7 GB, e o plano-mestre e a convenção do repositório proíbem `docker build` em subagente por estourar o watchdog. A fronteira scriptável termina nos stubs, e ela cobre as três recusas.

**Retrocompatibilidade — os dois gates que já exercitam este engine, e a armadilha medida nos stubs deles.**

`w142` e `w206` rodam `pentest-ops.sh` com stubs de `docker`. Extraí o stub do `w142` e o executei com os subcomandos que um pré-voo de D18 usaria:

```
docker compose -f x.yml config --images                           rc=0 stdout=[]
docker image inspect -f {{.Config.Entrypoint}} axis/pentest:dev   rc=0 stdout=[]
docker run --rm --entrypoint sh img -c 'command -v pentest-scan'  rc=0 stdout=[]
```

**O stub devolve rc 0 com stdout VAZIO para todos.** As duas consequências são opostas e as duas são armadilhas:

- uma verificação que decida **pelo rc** passa em silêncio contra os stubs de hoje — e a asserção nova nasceria **vazia** nos gates existentes, aprovando por não ter olhado nada;
- uma verificação que decida **por stdout não vazio** recusa contra os stubs de hoje — e derruba `w206[1]`, que afirma `rc1c -eq 0` e `rc1x -eq 0` para `scan` (linhas 346 e 353, `retrocompatibilidade mobile: activate/scan/status/deactivate intocados`).

Portanto, **qualquer que seja o primitivo, os stubs de `w142` e `w206` são estendidos no mesmo commit**, e o implementador mede qual dos dois efeitos ocorre antes de escrever a asserção. Isto é a **única exceção** ao item 5 de §7 ("a onda não toca o `w206`"), e ela fica dita aqui e lá em vez de ficar escondida numa subordinada: o `w206` é tocado **só** no bloco do stub de `docker`, nunca nas asserções, nunca no perfil strix. `w142[4]` (`bench_warn "$out4c"`) sobrevive nos dois casos **se e somente se** a recusa vier depois de `print_bench_only_warning`. E aqui a revisão 1 afirmou o que não tinha lido: `print_bench_only_warning` **não** é a primeira linha de `cmd_scan`, é a **quarta instrução**, na linha `:243`. `cmd_scan` abre em `:236` e a ordem medida é `local target="${1:-}"` (`:237`), o guard `has_pentest_config`/`not_configured_notice` que devolve `0` (`:238-241`), o guard de `target` vazio (`:242`) e só então `print_bench_only_warning` (`:243`). O argumento substantivo não muda — a recusa nova de D18 tem de vir **depois** da linha 243 —, mas a posição é essa, medida com `sed -n '236,244p' template/.forge/scripts/pentest-ops.sh`, e o implementador confere de novo em vez de assumir.

Duas outras asserções existentes prendem o trabalho, e as duas são nominais:

- **`w142[9]`** varre o engine sanitizado e reprova qualquer invocação de `docker`/`adb` (subcomandos `build|run|image|ps|rm|volume|compose` e `devices|kill-server|start-server|connect`) **não** embrulhada em `run_to`, com a única exceção do `exec docker run` interativo. Toda chamada nova de D16/D18 nasce embrulhada, com timeout explícito.
- **`w142[1]`** e **`w206[1]`** afirmam a string `nenhum toolchain de pentest configurado` na saída do `status` sem config. Essa mensagem **não muda**.

A varredura das demais strings de produção deste engine em `tests/` devolve: `forge-pentest` só em `w206:221`, e ali é `NET_NAME="forge-pentest-isolated"` — nome de rede do perfil strix, **outra constante**, que a onda não toca; `PENTEST_IMAGE`, `pentest-scan`, `toolchain buildado`, `workflow estático` e `tool_dir` não aparecem em gate nenhum.

**O que já está instalado nos consumidores, e aqui a revisão 1 errou o número.** `scripts/pentest-ops.sh` está **no disco** de 5 dos 8 (`axis-fare-validator`, `axis-go-cloud`, `Axis.PadSimulator`, `azim-crm`, `lionclaw`) e **no `machinery.lock` de apenas 4**: o `azim-crm` tem o arquivo em disco e **nenhuma entrada** para ele no lock. Medido: `/usr/bin/grep -ac 'pentest' ~/Documents/projects/azim-crm/.forge/cache/machinery.lock` → `0`, enquanto `ls -la …/.forge/scripts/pentest-ops.sh` mostra 54.402 bytes em disco; o cabeçalho do lock diz `template v0.1.0-rc24`, isto é, ele é anterior ao comando e nunca foi reescrito. O controle positivo da mesma varredura, `/usr/bin/grep -an 'scripts/doctor.sh' …/machinery.lock`, devolve a linha 225, então o vazio do `pentest` é ausência e não cegueira. A distinção importa: `scripts` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS`, então o overlay sobrescreve nos **cinco** que têm o arquivo — mas no `azim-crm` a sobrescrita é **muda**, porque sem entrada no lock não há referência de drift para o updater comparar. É a mesma lacuna que LDG-0153 nomeia, de novo. Como a onda **acrescenta** chaves opcionais e preserva o fallback, um consumidor sem `image` e sem `tag` continua com o mesmo nome de imagem de hoje e **muda apenas a tag**, de `latest` para `dev`. Isso é mudança visível e precisa ser dita ao campo: **quem já buildou `forge-pentest:latest` verá `activate` buildar `forge-pentest:dev`** — uma vez, e nunca mais. A alternativa (manter `latest` como default para não rebuildar) preservaria a violação da rule que a onda existe para fechar; o custo de um rebuild é o preço, e o release o anuncia em vez de deixar o campo descobrir. O consumidor da issue, que declara `image: axis/pentest:dev` no compose, passa a ser alcançado sem rebuild nenhum, que é o desfecho que ele pediu.

**A onda NÃO toca o perfil strix.** As nove recusas de pré-voo, o `image_digest`, o manifesto e as asserções do `w206` ficam como estão — a única exceção é o bloco do stub de `docker` do `w206`, pelo motivo medido acima; `[1]` do `w206` é o contrato de retrocompatibilidade mobile e ele continua valendo palavra por palavra.

---

## 5. Invariante 15 — a varredura nominal de strings de produção

Antes de qualquer mudança de mensagem, a varredura completa sobre `tests/`, **refeita em 2026-09-08 com `/usr/bin/grep -arn` e com o universo conferido** — `for f in tests/*; do file -b "$f" | grep -q '^data' && echo "$f"; done` não devolve nada, isto é, nenhum arquivo de `tests/` é ilegível como texto, e `/usr/bin/grep -arl 'FAIL' tests/ | wc -l` devolve 126, que é o controle positivo de que a varredura estava lendo. Vazio nesta tabela é ausência, e agora isso está provado em vez de suposto:

| String de produção | Gates que a afirmam | Decisão desta onda |
|---|---|---|
| `sem refs .claude` | `w63-forge-update-gate.sh:185` | **não muda** |
| `sem placeholders` | `w63:186`, `w158-doctor-placeholder-scope-gate.sh`, `npx-pack-gate.sh` | **não muda** |
| `fonte canônica com refs` | nenhum | pode ganhar o escopo examinado |
| `Controle nativo do browser é domado` | `w96-frontend-ui-review-gate.sh:72` | **não muda** — a regra 12 ganha texto depois da frase, nunca no lugar dela |
| `controles-nativos`, `controle nativo` | nenhum | livre |
| `nenhum toolchain de pentest configurado` | `w142:104`, `w206:344` | **não muda** |
| `toolchain buildado`, `workflow estático`, `PENTEST_IMAGE`, `pentest-scan`, `tool_dir` | nenhum | livres |
| `forge-pentest` | `w206:221`, e ali é `NET_NAME="forge-pentest-isolated"` do perfil strix | a onda não toca essa constante |
| `push RECUSADO` | `w195:303`, e a linha foi lida: é a **mensagem de FAIL do próprio gate**, não asserção sobre a saída da produção | **string de produção** (`_common.sh:105`, `:184`, `:199`), livre porque gate nenhum a afirma — a onda não a muda |
| `DIVERGÊNCIA` | `w110:237` (comentário) e `w193:149` (mensagem de FAIL do gate) — as duas lidas, nenhuma é asserção | **string de produção** (`_common.sh:184`), livre pelo mesmo motivo |
| `vazamento: N arquivo(s) de configuração` e `órfãos: N arquivo(s) de configuração` (as DUAS linhas novas de D9 — uma por universo) | nenhum | **linhas novas**, e elas são seguras: `w63[g]` usa `grep -qi` sobre a saída inteira (`:185-186`) e os **seis** usos de `grep -q` do `w158` (linhas 45, 64, 74, 79, 86 e 93 — `/usr/bin/grep -acn 'grep -q' tests/w158-doctor-placeholder-scope-gate.sh` devolve 6; a revisão 2 dizia cinco) são `grep -q "<substring>" <<<"$out"`; nenhum dos dois afirma número de linhas nem ordem, então duas linhas a mais não os movem |
| `liaison-push-union` | `w198` | a onda não muda a mensagem do módulo |

**Regeneração de espelho:** `template/.forge/commands/waves/pentest.md` é tocado por D19, logo `npm run build:plugin` é obrigatório e `tests/plugin-sync-gate.sh` é a prova. Medido em 2026-09-08: os dois arquivos são hoje byte-idênticos (`shasum -a 256 template/.forge/commands/waves/pentest.md plugin/forge/commands/pentest.md` → `6520bfa76877e1dddf82616e282fbc62d86394aa77009b938563c7c1c078d77f` nos dois), o script npm existe (`node -e` sobre `package.json` → `build:plugin => node template/.forge/scripts/lib/plugin-build.mjs --commands template/.forge/commands --out plugin/forge --version $npm_package_version`) e o gate compara por `diff -r "$T/forge" plugin/forge` (linha 21, lida). Nunca `build-plugin.sh`, que instala em `$HOME`. Nenhum outro arquivo sob `template/.forge/commands/` é tocado.

## 6. Invariante 14 — os literais que envelhecem, e onde eles moram

Nenhuma asserção desta onda conta arquivos rastreados, gates em `tests/`, entradas de `machinery.lock` ou nodes do grafo. As únicas contagens literais são os denominadores de cenário dos três gates (`7`, `10`, `10`) e o do `w96` ampliado (`11`), que são a exceção legítima: universo fechado, declarado pelo próprio arquivo, cuja divergência é o achado.

Três contagens **fora** dos gates envelhecem com esta onda e têm de ser atualizadas no mesmo commit — é a armadilha que derrubou duas especificações desta rodada:

1. **O badge `gates-N` do README.** `w200[6]` compara `grep -oE 'gates-[0-9]+' "$WS/README.md"` com `find "$WS/tests" -maxdepth 1 -name '*-gate.sh' | wc -l` (linhas 259-260 do gate, lidas). Medido em 2026-09-08: badge `gates-131` e árvore `131` — batem. Cada gate novo com sufixo `-gate.sh` incrementa os dois. Esta onda entrega **três** arquivos novos com esse sufixo; o valor final depende das outras ondas em voo, então **nenhum literal entra nesta especificação** — a propriedade é "badge == contagem, no commit".
2. **A linha `scripts/ (136)` do README** (linha 235), conferida por `w200[1]` com o critério `find "$root/scripts" -type f ! -name 'README.md' | wc -l` (a função `confere`, a partir da linha 53 do gate, lida). Medido em 2026-09-08: declarado 136, real 136. Esta onda **não** cria arquivo sob `template/.forge/scripts/` — as correções são in-place em `doctor.sh` e `pentest-ops.sh` — então a linha não muda; se o implementador extrair um lib novo, ele atualiza a linha.
3. **A linha `skills/   (20)` do README** (linha 232 — atenção, são três espaços entre `skills/` e o parêntese, e uma varredura por `'skills/ ('` devolve vazio por isso; o regex do gate é `([A-Za-z0-9_.-]+)/[[:space:]]+\(([0-9]+)\)`), mesmo critério. Medido em 2026-09-08: declarado 20, real 20. O scanner de D12 (`skills/frontend-ui-review/scripts/scan-native-controls.py`) torna **21**, e a linha é atualizada no mesmo commit. Esta é a mais fácil de esquecer, porque o arquivo novo não está sob `scripts/`.

E uma quarta, que é o único literal que a D6 introduz: **os oito nomes de arquivo canônico de topo do `.forge/`** (`FORGE.md`, `context.md`, `constitution.md`, `forge.yaml`, `runners.yaml`, `README.md`, `secrets-allowlist.txt`, `empty-universe-allowlist.txt`). Ele envelhece no instante em que o template ganhar um nono arquivo de topo, e por isso ele é vigiado por comparação e não por confiança: o gate confronta a lista carregada pelo doctor com `find template/.forge -maxdepth 1 -type f`, e o contrafactual foi medido em cópia sob `$TMPDIR` — com o template de hoje as listas são idênticas; com um `policies.yaml` acrescentado à cópia, a comparação acusa `policies.yaml`. É a mesma exceção legítima dos denominadores de cenário: universo fechado, declarado pelo próprio repositório, cuja divergência é o achado.

**E uma contagem que a revisão 2 previa e que a medição desta revisão CANCELOU: a allowlist da RAIZ não ganha chave nenhuma.** A revisão 2 dizia que o cenário `[5]` de §2.4 exigiria uma entrada em `<repo>/.forge/empty-universe-allowlist.txt` enquanto a Fase 1 não completasse a instalação da maquinaria aqui, e isso era verdade enquanto o universo era só a lista de diretórios (os seis têm zero arquivos nesta árvore). Com a componente de topo da D6 o universo desta raiz é **3** e não 0 — `FORGE.md`, `secrets-allowlist.txt` e `empty-universe-allowlist.txt`, medidos em §2.3 —, logo não há vazio a isentar e escrever a isenção seria fabricar dispensa. A distinção de arquivo continua registrada porque ela vale para a próxima onda que precisar de uma isenção: o arquivo é o do dogfood, `<repo>/.forge/empty-universe-allowlist.txt`, que hoje tem exatamente uma entrada (`red-first-ci`), **jamais** `template/.forge/empty-universe-allowlist.txt`, que é distribuído e onde uma isenção viajaria para os treze consumidores como dispensa permanente de um vazio que só existe aqui; `find . -name 'empty-universe-allowlist.txt' -not -path './.git/*'` devolve os dois arquivos e eles são visivelmente diferentes — o do template é o documento de formato, sem entrada nenhuma. Toda entrada precisa de `# motivo:`, e entrada anônima reprova por integridade, por desenho do `forge_universe_waiver`.

E uma quinta, que a revisão 2 acrescenta porque ela é o instrumento e não o conteúdo: **toda varredura de ausência desta especificação usa `/usr/bin/grep -a`**, nunca o `grep` da sessão do agente, e vem com o censo do universo ou com controle positivo. O motivo está no preâmbulo, e a regra em uma frase é a invariante 2 aplicada à ferramenta: varredura que devolve vazio tem três desfechos — "não existe", "existe e eu não li", "não consegui ler" —, e sem o censo os três colapsam no primeiro.

## 7. O que a Onda L6 explicitamente NÃO faz

1. **Não adota `check-frontend-design-system.sh` no template.** 871 linhas, dependência dura de `pnpm-workspace.yaml`, presente em 2 de 13 consumidores medidos. Item de ledger aberto com a condição de reabertura escrita (§3.3, D14).
2. **Não torna o A4 bloqueante.** A classificação declarada é advisory, e o argumento medido está em D13.
3. **Não corrige o `_dir_push_classify` chamado com log próprio ausente**, o décimo desfecho de §1.2, porque o caminho é inalcançável a partir de `_dir_push` — que guarda com `[ -f "$own" ]` — e inscrevê-lo obrigaria o gate a exercitar caminho morto. Fica registrado, não corrigido.
3b. **Não separa os três rc 1 de `_dir_push`** — "há bifurcação" (`:184`), "não consegui unir por falta de `node` ou do módulo" (`:105`) e "não consegui classificar" (`:199`) saem todos com o mesmo código, o que é a invariante 2 violada no transporte e foi medido na revisão 2 (§1.2, nono estado). Mudar o rc é mudança de comportamento num arquivo que está no `machinery.lock` de seis consumidores, e §7, item 4, proíbe qualquer alteração executável de `_common.sh` nesta onda. O que a onda entrega é o **contrato declarando os três com a causa nomeada**, que é o que falta ao leitor hoje, mais um item de ledger: "separar o rc de `_dir_push` entre recusa por bifurcação e impossibilidade de verificar — hoje os três saem 1; exige decisão de contrato porque consumidores já leem esse rc".
4. **Não muda comportamento nenhum do `_common.sh`.** #126 é integralmente de comentário mais gate, e qualquer alteração executável naquele arquivo nesta onda é achado da revisão adversarial.
5. **Não toca o perfil strix do `pentest-ops.sh`.** Do `w206` a onda toca **um único bloco**, o do stub de `docker`, pelo motivo medido em §4.6 — nenhuma asserção, nenhuma linha do perfil strix. A exceção está dita aqui e em §4.6, nas duas pontas, porque na revisão 1 ela existia só numa subordinada e o revisor teve de ir procurá-la.
6. **Não entrega `pentest-scan`, nem por template de Dockerfile nem por mount** — declara o contrato e verifica que ele é honrado (D18, com as duas alternativas descartadas e o porquê).
7. **Não generaliza o contrato executável de D1 para outros arquivos de política.** O caso de "quatro raízes contra seis" da Fase 0 é da mesma classe e é o candidato natural — e ele **já foi corrigido nesta branch**, o que eu conferi em vez de repetir o plano-mestre: `/usr/bin/grep -acn 'quatro raízes' template/.forge/commands/waves/pentest.md` devolve `0` e `/usr/bin/grep -acn 'seis raízes' …` devolve `1`, com o espelho `plugin/forge/commands/pentest.md` também em `1`. A classe continua aberta mesmo com o sítio fechado, que é justamente o argumento; inscrevê-lo exige um censo de arquivos que declaram política, e o gate desta onda já nasce com universo derivado e piso `>= 1` justamente para que a onda seguinte inscreva sem tocar nele.
8. **Não resolve LDG-0153** (o doctor informar divergência do `_common.sh` contra o template), que é Onda B, embora ele seja vizinho de #126.
9. **Não reconcilia com a Onda L4/Onda E.** A única interação entre lotes que o plano-mestre registra é #133 × Onda E, sobre `arg-guards.sh`; nenhum dos quatro itens deste subgrupo toca `lib/argparse.sh` nem `lib/arg-guards.sh`, e o `pentest-ops.sh` faz o próprio `case` de subcomandos sem passar por nenhum dos dois.

## 8. Ordem de execução e definição de pronto

1. **Ordinal.** O orquestrador aloca os três ordinais contra `origin/*` **e** contra as branches em voo desta rodada, no momento de escrever cada arquivo. Máximo publicado medido: `w207`.
2. **Vermelho observado e registrado**, gate por gate, antes de uma linha de implementação. A onda declara **33 cenários** — 7 no gate de #126, 10 no de #127, 6 acrescentados ao `w96` por #140 e 10 no de #145 (7+10+6+10 = 33) — e **24 deles são vermelhos hoje**. Os **nove** restantes nascem verdes por construção e a tabela de cada item os identifica um a um: os seis contadores de controle e sentinelas — `[4]` e `[6]` do gate de #126, `[7]` e `[8]` do gate de #127, `[9]` e `[10]` do gate de #145 —, mais o caminho feliz `[7]` do gate de #145, que existe para impedir que uma recusa incondicional satisfaça `[5]` e `[6]`, mais `[2b]` e `[2c]` do gate de #127, que são os dois controles de retrocompatibilidade e nascem verdes porque o doctor de hoje já passa nos dois (medido em §2.3). Cenário que nasce verde **não** tem vermelho a observar, e declarar que tem é a forma mais barata de fabricar red-first.

   **O rótulo dos 24, corrigido pela ressalva do revisor:** eles não são todos "vermelhos por ausência de maquinaria". São **23 por ausência real** — a maquinaria não existe e o gate não tem o que exercitar — e **1 pelo CONTEÚDO de um arquivo rastreado**: o `[3]` do gate de #126, cujo vermelho é a linha 19 do `_common.sh` afirmando o oposto do que o código faz (§1.5 diz isso em letra, e a §8 da revisão 2 o contava junto com os outros sem dizer). O vermelho existe e está medido (controle = 1); o que estava errado era um rótulo cobrindo dois fenômenos, e para um defeito cujo dano **é** o texto, vermelho por conteúdo é a única forma que red-first pode tomar.
3. **Implementação**, item a item, na ordem #126 → #127 → #140 → #145. A ordem não é arbitrária: #126 é comentário mais gate e não pode quebrar nada, o que dá uma bancada estável; #127 muda o `doctor.sh`, que é o arquivo que #145 também toca em D20; #140 é independente; #145 é o mais caro e o que mais mexe com gates existentes.
4. **Mutação com contrafactual medido**, uma a uma, com controle vindo da árvore de trabalho, restauração conferida por `cmp -s` e recontrole reexecutando a asserção derrubada. Toda linha da matriz que divergir do medido se corrige no PR — e toda mutação que sair no-op corrige o **cenário**, não a linha.
5. **`npm run build:plugin`** depois de tocar `commands/waves/pentest.md`, e `plugin-sync-gate` verde.
6. **README:** badge de gates e linha `skills/ (N)` atualizados no mesmo commit.
7. **Suíte inteira verde, rodada pelo orquestrador, serializada.** Nenhum subagente roda a suíte; nenhum gate manual roda em concorrência com ela.
8. **Ledger e liaison:** o item de D14 aberto, mais o item do rc colapsado de §7.3b; os acks das threads de #126, #127 e #140 escritos **depois** do merge, carregando a entrega e não a promessa, e o de #140 dizendo em letra que o script é do consumidor e que a metade do harness estava pior do que o relato.
9. **PR contra `develop`**, sem texto de coautoria de IA, com as saídas de mutação coladas.

**Definição de pronto do subgrupo:** as quatro issues fechadas como `resolved`, cada uma com a prova de que o defeito descrito não reproduz mais e com um gate que morde se ele voltar — e a de #140 fechada com a medição que sustenta o desvio de escopo, porque fechar por reclassificação silenciosa não conta e o harness já reprovou essa saída em LDG-0053 e LDG-0061.

---

## 9. Respostas ao veredito da revisão 1

O revisor reproduziu quase tudo o que a revisão 1 afirmava, e o crédito é dele: os oito desfechos de `_dir_push`, o custo em fixture, a refutação do `--exclude-dir` por basename, o predicado vivo nesta árvore, o poder discriminante zero da receita A4, os três defeitos de #145 verbatim, o achado negativo de #140 e o censo de locks. O que ele reprovou eram duas decisões, e as duas estavam mesmo em aberto. Abaixo, item a item, o que mudou e o que foi medido para mudar.

### BLOQUEADOR 1 — D6 punha três gates no vermelho

**Aceito integralmente, e a decisão foi reescrita, não emendada.** Remedi na instalação limpa que o revisor descreve e cheguei aos mesmos quatro arquivos: `hooks/git/lib/check-docs-reviewed.sh`, `commands/harness/build-plugin.md` e `commands/harness/sync-adapters.md` com `.claude/`, e `templates/FORGE.md` com `<PROJECT_*>`. O doctor de hoje imprime `✓` nas duas linhas e sai `0`; sob a leitura literal da D6 anterior imprimiria `✗` nas duas.

O que mudou: **as duas varreduras passam a ter universos declarados separadamente**, e a diferença entre eles é exatamente o conjunto de arquivos medidos. `hooks/` e `commands/harness/` saem do universo de **vazamento**; `templates/` sai do de **órfãos** e permanece no de vazamento, que é o que o cenário `[3]` exige. A frase "a denylist ancorada obriga cada exclusão a ser escrita duas vezes", que o revisor apontou como premissa refutada pela medição, foi removida — ela era falsa. E a onda ganhou o cenário `[2b]`, que roda o **instalador real** e mede a árvore que o consumidor recebe, mais duas mutações (`M5b`, `M5c`) cujo contrafactual é exatamente reintroduzir o bloqueador. A crítica de que a fixture sintética não pegaria o erro está certa e é a razão de `[2b]` existir.

A ressalva conexa — "falta a frase que diga se a varredura de órfãos muda de universo" — está atendida: a D6 nova diz as duas listas em letra, e diz que `scripts/` e `adapters/` saem do universo de órfãos, o que é mudança de escopo declarada em vez de implícita.

### BLOQUEADOR 2 — D3 só tinha dois desfechos e os dois eram defeito

**Aceito integralmente.** Medi a região e confirmei o diagnóstico linha a linha: cabeçalho 1-42, tokens em 19, 21, 23 e 42, e das quatro só a 19 mente. O predicado antigo era sobre **ocorrência de token**, e o revisor tem razão de que ele resolvia em vermelho fabricado ou em gate morto.

O predicado novo é **T ∩ V** — token de classificação **e** verbo de desfecho, os dois conjuntos declarados dentro do bloco de contrato. Medido antes de escrever, com controle (1 linha, a 19), dois contrafactuais (CF-A com a marcação `HISTÓRICO:` → 0; CF-B com token e sem verbo → 0, que é a anti-vacuidade que faltava) e recontrole (volta a 1). As linhas 21, 23 e 42 sobrevivem sem marcação e sem mentira. A matriz de mutação ganhou `M3b`, o contrafactual de `M3`, e a tabela de cenários ganhou `[7]`, que reprova se o predicado voltar a disparar em prosa descritiva. O limite do predicado — V é fechado, e uma mentira que evite o léxico passa — está declarado, e o gate publica `|T|` e `|T ∩ V|` para que o encolhimento dele seja visível.

### As nove medições sem lastro

Regra que segui: **remedir e colar o comando, ou remover**. Nenhuma ficou sem uma das duas.

| # | Medição apontada | Desfecho |
|---|---|---|
| 1 | sítios de `:latest` — "sete" no texto, nove na lista, oito na tabela | **REMEDIDA e corrigida para nove**, com `/usr/bin/grep -an ':latest' …` e `… -ao … \| wc -l` → 9, colados em §4.1; a tabela de §4.4 passa a dizer "N derivado por varredura" e nomeia os nove sítios |
| 2 | localização da receita A4 — `SKILL.md:91-93` | **REMEDIDA: é 89-91**, a 88 é a abertura da cerca. O revisor está certo; corrigido em §3.2 e §0 do item 3, com o comando |
| 3 | linha do `w96` — "72" no texto e "73" na tabela de §5 | **REMEDIDA: é 72**, e a tabela de §5 foi corrigida. O comando está em §3.6 |
| 4 | `print_bench_only_warning` "primeira linha de `cmd_scan`" | **REMEDIDA e a afirmação estava errada**: é a **quarta** instrução, em `:243`, depois de `local target`, do guard de configuração e do guard de alvo vazio. §4.6 traz a ordem completa com o comando. O argumento substantivo não muda |
| 5 | escala nos consumidores — 5.976.165 / 415.139 etc., não reproduzidos | **REMEDIDA por inteiro**, os treze repositórios, com o comando colado e carimbo `DATA: 2026-09-08T12:49:24Z`. Os números **mudaram em um dia** (`axis-go-cloud` 5.976.165 → 5.983.604; `azim-crm` 415.139 → 422.882), e a spec agora diz em letra que **nenhuma asserção depende deles** e que a propriedade travada é "a varredura não abre arquivo sob `worktrees/`" |
| 6 | `Axis.DevicePlatform` — commits `fb43dd9`/`7f5bd4f`, `adp#LDG-0610/0611` | **MANTIDA, e agora rotulada como premissa de campo não reproduzida**, com a fonte única nomeada (issue #127, linhas 4 e 48) e com as duas conferências negativas que dava para fazer daqui: o repositório não está nesta máquina, e a varredura da árvore inteira pelos quatro identificadores devolve só esta especificação, mesmo com 106 mensagens do `axis-device-platform` no canal. Fica dito que a frase sobre o overlay cai com a premissa |
| 7 | fixture de §2.2 — "5 casados / 4 reportados" | **REMEDIDA**, a fixture foi reconstruída e os dois números reproduzem, agora com os cinco nomes impressos, com a linha de produção colada verbatim, e com o quinto arquivo (`commands/harness/sync-adapters.md`) identificado como o que a denylist filtra |
| 8 | nove recusas de pré-voo em `pentest.md:118-142` | **REMEDIDA: são nove, e o intervalo é `:139-147`**, não `:118-142`. Os nove tokens estão listados em §4.2, com o comando |
| 9 | "`w198` verde o tempo todo" e `axis-go-cloud-0086` | **REESCRITA para uma afirmação que eu posso sustentar sem rodar gate**: `/usr/bin/grep -acn 'behind' tests/w198-…` → **0**, isto é, o gate não menciona o token cujo cabeçalho mente, e portanto é indiferente ao texto. E `axis-go-cloud-0086` está citada **no cabeçalho do próprio `w198`**, na árvore rastreada, não na minha memória |

### As ressalvas

- **`empty-universe-allowlist.txt` ambíguo.** Corrigido: §2.3 (D9) e §6 dizem `<repo>/.forge/empty-universe-allowlist.txt`, com a frase que explica por que o do template não serve.
- **Escopo da varredura de órfãos não dito.** Corrigido pela D6 nova, que declara as duas listas.
- **§5 não cobria a linha nova do doctor.** Corrigido: a tabela ganhou a linha, com a conferência que o revisor fez e não registrou — `w63[g]` usa `grep -qi` e os usos de `grep -q` do `w158` são todos `grep -q "<substring>" <<<"$out"`, nenhum afirma número de linhas nem ordem. *(Retificação da revisão 3: eu escrevi "os cinco usos" aqui e em §5, e são **seis** — `/usr/bin/grep -acn 'grep -q' tests/w158-doctor-placeholder-scope-gate.sh` devolve 6, nas linhas 45, 64, 74, 79, 86 e 93. A afirmação substantiva continua de pé; o número estava errado nos dois sítios e saiu corrigido nos dois.)*
- **A exceção do stub do `w206` estava escondida.** Corrigida nas duas pontas: §4.6 e §7, item 5, agora dizem a mesma frase.
- **`cmd_deactivate` em `:287-288` × `:286-289`.** **Refutada com medição**: `/usr/bin/grep -an 'docker-compose.yml' template/.forge/scripts/pentest-ops.sh` devolve exatamente `287` e `288`. A linha 286 é `td="$(pentest_tool_dir)"`, que resolve o diretório e não abre o compose. `:287-288` está certo e fica.

### O que a revisão 2 achou por conta própria

Três coisas, e as três são consequência de levar a sério a instrução de provar que a varredura leu o universo.

1. **O instrumento de medição desta rodada tinha dois filtros silenciosos**, e não é só o `secret-scan.mjs`: o `grep` da sessão do agente é uma função que delega a `ugrep` com `-I` e `--ignore-files`. O achado do orquestrador (LDG-0177) é real e a regra que ele extrai é a certa, mas o mecanismo é mais amplo do que o registrado, e a linha de produção do `doctor` — que usa `grep -rl` — **não** é cega, ao contrário do que a generalização sugeriria. Está tudo medido no preâmbulo, com canário plantado e removido e recontrole.
2. **Um nono desfecho de `_dir_push`**, não visto na revisão 1: com `node` fora do `PATH`, a classificação diz `ff` e o push recusa com rc 1. É a terceira porta pela qual `ff` não publica, e ela expõe uma violação da invariante 2 dentro do transporte — três causas diferentes saem com o mesmo rc 1. A onda documenta as três no contrato, não muda o rc, e abre item de ledger (§7.3b).
3. **`pentest-ops.sh` está no `machinery.lock` de 4 consumidores, não de 5.** O `azim-crm` tem o arquivo em disco e nenhuma entrada no lock, cujo cabeçalho ainda diz `v0.1.0-rc24`. O revisor havia confirmado "5/8" da revisão 1; o número certo é 5 em disco e 4 no lock, e a diferença importa porque é onde a sobrescrita do overlay acontece sem referência de drift.

---

## 10. Respostas ao veredito da revisão 2

O revisor reproduziu por medição própria, e não pelo meu relato, os dois bloqueadores que a revisão 2 dizia ter fechado: o predicado T ∩ V de D3 nos cinco estados da tabela de §1.4, e o censo exaustivo dos dezessete diretórios de topo da instalação limpa de D6, linha a linha, com o doctor em `✓✓` e rc 0. O crédito é dele, e a reprovação também: ele achou, na aritmética que a **minha própria** §2.6 publicava, a prova de que os dois universos que eu havia escrito eram listas de diretórios e que a configuração canônica de topo do `.forge/` não estava em nenhum dos dois. Abaixo, o que mudou, o que eu medi para mudar e onde a correção precisou varrer o resto do documento.

### BLOQUEADOR NOVO — D6 tirava os arquivos canônicos de topo dos dois universos

**Aceito integralmente, e a decisão foi reescrita pela terceira vez, não emendada.** A leitura do revisor está certa em cada passo, e eu a remedi antes de aceitar: numa instalação limpa sob `$TMPDIR`, um `<PROJECT_SLUG>` acrescentado a `.forge/FORGE.md` faz o doctor de hoje imprimir `✗ harness: 1 arquivo(s) com placeholders <PROJECT_*> não preenchidos` e o universo de órfãos da revisão 2 devolver **0**; uma linha citando `.claude/agents/` acrescentada a `.forge/constitution.md` faz o doctor de hoje imprimir `✗ harness: 1 arquivo(s) da fonte canônica com refs .claude/` e o universo de vazamento da revisão 2 devolver **0**; os dois restaurados com `cmp -s` e os dois recontroles voltando a `✓`/`0`. Reconstruí também a fixture do `w158[2]` e a leitura é `3` sob o universo desta revisão contra `0` sob o da revisão 2, com o doctor de hoje em `3`; e o `w158[4]`, que afirma `1 arquivo(s) com placeholders`, dá `1` contra `0`.

A decisão que faltava, e que o revisor tem razão em dizer que não era de implementação: **os arquivos canônicos de topo entram nos dois universos, por caminho explícito**, numa lista fechada de oito nomes que é exatamente o que `find template/.forge -maxdepth 1 -type f` materializa. E ela não é "todo arquivo de topo": os extras que os consumidores criam ali — `HANDOFF.md`, `SESSIONS.local.md`, `machinery-exceptions.txt`, um script solto — são relatório gerado, log local e código do projeto, e o `.forge/` desta raiz ainda tem um `.DS_Store` binário, onde `grep` sem `-a` devolveria silêncio.

**A varredura do efeito colateral, que é o padrão que derrubou as duas rodadas anteriores, foi feita item a item e é o que segue.** Contadores: 185 e 189 viraram **193 e 197** em §2.6, com a aritmética das duas componentes publicada junto para que a de topo não possa sumir sem o número cair. Cenários: o gate ganhou `[2c]`, que planta nos dois varredores e reconstrói a forma da fixture do `w158[2]`, e o denominador foi de 9 para **10** em `[7]` e em §2.6. Mutação: entrou `M5d`, cujo contrafactual é literalmente reintroduzir este bloqueador, com o efeito já medido em bancada (`0` contra `1`, `0` contra `1`, `0` contra `3`). Retrocompatibilidade: a frase de §2.7 que mandava conferir o `w158[2]` "porque `templates/` está na inclusão" era falsa no meu próprio texto — `templates/` está fora do universo de órfãos em letra desde a D6 da revisão 2, e os três arquivos do cenário estão na raiz do `.forge/` aninhado — e ela saiu, substituída pelas duas leituras medidas. §8: 32 cenários viraram **33** e os verdes por construção, oito viraram **nove** (7+10+6+10 = 33, menos nove = 24). §0: a linha do resumo dizia "varredura de vazamento" no singular e passou a dizer as duas, com a componente de topo.

**E um efeito colateral que a correção criou noutra decisão, encontrado por varredura e não por sorte: a D9 caiu.** A revisão 2 afirmava que o universo vazio era alcançável hoje nesta árvore e que a allowlist da raiz ganharia uma chave. Com a componente de topo isso deixou de ser verdade, e eu medi antes de reescrever: o `.forge/` desta raiz tem `FORGE.md`, `secrets-allowlist.txt` e `empty-universe-allowlist.txt`, logo os dois universos aqui têm **3** arquivos e não 0. A onda **não** ganha entrada de allowlist — escrevê-la seria fabricar dispensa de um vazio que a medição não mostra —, o terceiro estado continua obrigatório e passa a ser exercitado por fixture com as **duas** componentes ausentes, e a chamada a `forge_universe_check` passa a ser uma por universo, com a alternativa da união descartada em letra porque ela deixaria um varredor cego esconder-se atrás do outro cheio. A quarta contagem de §6 foi trocada na mesma passagem: saiu a allowlist e entrou o único literal que a D6 introduz — os oito nomes —, vigiado por comparação contra o topo do template, com o contrafactual medido (`policies.yaml` acrescentado a uma cópia é acusado).

### As ressalvas, todas fechadas com medição

| # | Ressalva | Desfecho |
|---|---|---|
| 1 | CF-B e CF-C de §1.4 são medidos sobre a base CF-A e a tabela não dizia | **Aceita e remedida nas quatro leituras.** `CF-B sobre CONTROLE = 1` e `CF-C sobre CONTROLE = 2`; `CF-B sobre CF-A = 0` e `CF-C sobre CF-A = 1`, que são os números da spec. A tabela passou a dizer a base em cada linha, e o parágrafo novo explica **por que** a base é CF-A: sobre o CONTROLE a linha 19 soma 1 a toda leitura e a resposta sobre a linha nova viria embutida num número que não é sobre ela |
| 2 | O predicado T ∩ V é por linha, e o limite de granularidade não estava declarado | **Aceita, medida e declarada.** Rodei o contrafactual da mentira partida em duas linhas (token numa, verbo normativo na seguinte) sobre CF-A: a leitura é **0**, o limite é real, e ele é exatamente a forma da mentira de hoje — a 20 carrega `recusar é a única saída` sem token, e o CONTROLE só devolve 1 porque a 19 carrega os dois juntos. Está escrito com a mesma honestidade que V ganhou, com o remédio nomeado para a onda seguinte (janela de continuação) em vez de fingir cobertura |
| 3 | §5 e §9 diziam "os cinco usos do `w158`" e são seis | **Aceita e corrigida nos três sítios** (§2.7, §5 e §9). `/usr/bin/grep -acn 'grep -q' tests/w158-doctor-placeholder-scope-gate.sh` devolve **6**, nas linhas 45, 64, 74, 79, 86 e 93; a afirmação substantiva — todos são `grep -q "<substring>" <<<"$out"`, nenhum afirma número de linhas nem ordem — continua de pé |
| 4 | §3.6 dizia linha 16 para o `SKIP (python3 ausente)` do `w96` e é a 15 | **Aceita e corrigida**, com o comando colado: `/usr/bin/grep -an 'python3 ausente' tests/w96-frontend-ui-review-gate.sh` devolve `15:`. O argumento (o terceiro estado sobrevive à ampliação e o contador reporta `0 de 11` nesse caminho) não muda |
| 5 | Uma linha de universo no doctor para dois universos de tamanhos diferentes, e `[5]`/D9 falando de "os seis diretórios" no singular | **Aceita e resolvida nas duas pontas.** O doctor passa a publicar **duas** linhas, cada uma nomeando a sua varredura (`vazamento:` e `órfãos:`), e o terceiro estado passa a ser declarado por universo, com a fixture de `[5]` exigindo as duas componentes ausentes e com a união descartada em letra |
| 6 | §8 conta o `[3]` do gate de #126 entre os "24 vermelhos por ausência real", e ele é vermelho pelo conteúdo do arquivo rastreado | **Aceita e o rótulo foi partido.** São **23 por ausência de maquinaria e 1 por conteúdo**, dito em letra, com a razão: para um defeito cujo dano **é** o texto, vermelho por conteúdo é a única forma que red-first pode tomar. O número 24 não muda, o rótulo sim |

### As medições sem lastro que o revisor listou

As três estavam rotuladas e ele as aceitou como inofensivas; ainda assim cada uma ganhou o que faltava para ninguém ter de aceitar rótulo no lugar de comando. A tabela de escala de §2.1 passou a dizer, em letra, o que dela é portante — as duas pontas, remedidas por mim em 2026-09-08 às `13:28:16Z`: `345` arquivos sob `.forge/` e `0` sob `.forge/worktrees/` nesta raiz, e a enumeração dos **treze** repositórios com `.forge/` derivada por laço sobre `~/Documents/projects` — e o que dela é ilustração de ordem de grandeza que nenhuma asserção cita, de modo que quem revisar pode pular a linha do `axis-go-cloud` sem perder o argumento. O relato de campo da #126 e a premissa do `Axis.DevicePlatform` continuam rotulados como o que são, com fonte única nomeada e com o argumento operativo já redirecionado para medição local — nos dois casos a conclusão não depende da parte não reproduzida, e isso está escrito onde a afirmação mora.

### O que a revisão 3 achou por conta própria

1. **A minha bancada estava rodando em `zsh` e o `zsh` não faz word splitting de variável não citada.** A primeira leitura dos universos novos devolveu `topo presentes: 0` — não porque os arquivos faltassem, mas porque `for f in $FORGE_TOP_FILES` itera **uma** palavra em `zsh` e oito em `bash`. O `[ -f ]` era falso para o nome concatenado, e a medição teria "confirmado" em silêncio que a componente de topo não achava nada. Só apareceu porque o número (`0`) contradizia o `find` que eu tinha rodado dois comandos antes. A regra que fica: **toda bancada que mede comportamento de gate roda sob `bash`, que é o interpretador do gate**, e não sob o shell da sessão — medir no interpretador errado é a mesma classe do `grep` sem `-a` de LDG-0177, um vazio que não é ausência.
2. **Dois consumidores estão hoje com a linha de vazamento do doctor vermelha por arquivo de topo, e um deles pela razão certa.** `axis-fare-validator` tem três (`FORGE.md`, `HANDOFF.md`, `SESSIONS.local.md`) e `lionclaw` tem um (`FORGE.md:23`, com `lint: bash .claude/scripts/doctor.sh` numa chave de runtime). Sob o universo desta revisão o primeiro cai para um e o segundo continua em um: a narrativa sai, a configuração fica. É a mesma tese de §2.2 medida numa parte da árvore que nem a issue #127 nem as duas revisões anteriores tinham olhado.
3. **O `.forge/` desta raiz tem um `.DS_Store`**, isto é, um arquivo binário de topo. Ele é o argumento concreto contra a versão preguiçosa desta correção ("põe todo arquivo de topo no universo"): a lista fechada de oito nomes o deixa fora por construção, enquanto a versão preguiçosa o poria dentro de um `grep` que, sem `-a`, devolveria silêncio sobre ele.
