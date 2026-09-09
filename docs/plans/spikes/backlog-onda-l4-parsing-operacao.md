# Onda L4 — parsing e interface dos scripts de operação (especificação implementável)

Autor: especificador do subgrupo L4. Revisão 3, 2026-09-08 (revisões 1 e 2 em 2026-09-07 e 2026-09-08). Base medida: branch `feat/fase1-dogfood-completo`, `HEAD` em `cf3bbe4` (`git -C . rev-parse --short HEAD`), `v0.14.0` publicada no npm, árvore do produtor em `/Users/milton/Documents/projects/forge-harness`.

**A revisão 1 declarou a base em `1e28514`, e isso estava errado quanto ao alvo:** `git diff --name-only 1e28514..HEAD -- template/` devolve quinze arquivos, e dois deles são alvos desta onda (`liaison-ops.sh` e `deferral-ops.sh`). Reexecutei o censo inteiro contra `cf3bbe4` e ele reproduz número por número e linha por linha — 31/20/11, 3/3, 23/23, 0/0, e as onze linhas nos mesmos endereços —, de modo que nenhuma conclusão muda; o que muda é que o endereço passa a ser o da árvore em que a onda vai ser implementada. As demais quatro peças (`wave-ops.sh`, `run-manifest.sh`, `lib/run-manifest.mjs`, `validate-naming-conventions.sh`) são byte a byte idênticas entre os dois commits, medido com `git diff --quiet <sha>..HEAD -- <arquivo>` arquivo a arquivo.

Escopo: issues **#133** (a camada de guardas de parsing do `liaison-ops.sh` e do `deferral-ops.sh`), **#136** (`--help` cai no ramo de comando desconhecido), **#128** (`run-manifest.sh` descarta o `--root` do chamador) e **#129** (`validate-naming-conventions.sh` reprova todo `.cs` quando o caminho chega relativo). O critério que junta os quatro é o do plano-mestre: **um script de operação decide a partir de um argumento que ele não examinou, e sai com uma linha que parece sucesso**.

Esta especificação é para ser executada, não lida. Toda afirmação numérica abaixo traz o comando que a produziu e a saída real. **Nenhum gate da suíte foi executado na elaboração** — nem `npm test`, nem `tests/run-all.sh`, nem gate individual —, porque `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio, com log vazio. Toda reprodução aconteceu numa bancada própria sob `$TMPDIR`, com o `cwd` **dentro** da fixture, e nenhuma escrita ocorreu em `template/`, em `.forge/` da raiz nem em repositório de consumidor.

**Regra de método, e ela é a invariante 19 do plano-mestre.** O que esta especificação declara é a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir; quem escolhe o primitivo é o implementador, que executa, e ele tem a obrigação de provar que o primitivo discrimina, com controle e recontrole. Comando exato só permanece aqui quando veio de execução minha, com a saída colada — e a §12 lista, uma a uma, as execuções que sustentam cada prescrição.

**Segunda regra de método, acrescentada na revisão 2 e ela invalida o método da revisão 1: varredura de texto que devolve vazio não prova ausência.** O orquestrador mediu em 2026-09-08, e registrou como LDG-0177, que `template/.forge/scripts/lib/secret-scan.mjs` é invisível a `grep` sem `-a`, porque o detector de conteúdo binário do próprio arquivo carrega bytes de controle literais dentro de um literal de regex. Reproduzi na minha árvore, e o contraste é o controle:

```
$ file template/.forge/scripts/lib/secret-scan.mjs
template/.forge/scripts/lib/secret-scan.mjs: data
$ grep -rln 'AKIA' template/ | wc -l      → 2
$ grep -arln 'AKIA' template/ | wc -l     → 3        ← o terceiro é o próprio secret-scan.mjs
```

O arquivo mora em `template/.forge/scripts/lib/`. **A revisão 2 dizia que esse diretório é universo de cinco varreduras de ausência desta especificação, e isso é falso — medi as cinco na revisão 3, e as duas perguntas que valem têm respostas diferentes: `secret-scan.mjs` está no universo de UMA delas, e DUAS apontam para dentro de `lib/`.** A varredura de `_ap_ctx` do §0 é recursiva em `template/` e é a única que tem o `secret-scan.mjs` no universo; a de §4.3 aponta para dentro de `lib/`, mas o universo dela é um arquivo nomeado, `sync-adapters.mjs`, e portanto não alcança o `secret-scan.mjs`; e as outras três não descem a `lib/` de todo modo. Medido:

```
$ file template/.forge/scripts/lib/secret-scan.mjs        → data
$ ls template/.forge/scripts/*.sh | grep -c 'lib/'        → 0        (o glob de §3.4 não desce a lib/)
$ ls template/.forge/commands/ | head -3                  → coding docs git   (§10 não é lib/)
$ ls tests/ | grep -c 'secret-scan'                       → 0        (§2.4 varre tests/)
```

A correção não afrouxa a disciplina, ela a aponta para o lugar certo: **`-a` em toda varredura de ausência continua sendo obrigatório**, porque quem varre não sabe de antemão qual arquivo do universo carrega byte de controle — e o preço de descobrir é uma conclusão errada, não um erro. O que muda é que a justificativa deixa de ser "o arquivo está no universo de cinco varreduras" e passa a ser "o custo de estar errado é assimétrico e o `-a` é grátis".

**E o controle positivo da revisão 2 não discriminava o defeito que ele existe para pegar. Este é o bloqueador 2 da revisão 2, e reproduz.** O controle era `printf '_ap_ctx CONTROLE-POSITIVO-L4\n' > .../CONTROLE.txt`, texto puro: uma varredura que perdesse o `-a` numa refatoração continuaria achando o controle, e a asserção seguiria verde. Medido na revisão 3, com o contraste que fecha o ponto — o controle tem de carregar **byte de controle**:

```
$ CTRL="$TMPDIR/l4-ctrl3"; mkdir -p "$CTRL"; cp -R template "$CTRL/template"; cd "$CTRL"
$ printf '_ap_ctx CONTROLE-POSITIVO-L4\n'        > template/.forge/scripts/lib/CONTROLE.txt
$ printf 'x\000y_ap_ctx CONTROLE-BINARIO-L4\n'   > template/.forge/scripts/lib/CONTROLE-BIN.txt
$ file template/.forge/scripts/lib/CONTROLE.txt template/.forge/scripts/lib/CONTROLE-BIN.txt
…/CONTROLE.txt:     ASCII text
…/CONTROLE-BIN.txt: data
$ grep -arln '_ap_ctx' template          → CONTROLE-BIN.txt  e  CONTROLE.txt      (os dois)
$ grep -rln  '_ap_ctx' template          → CONTROLE.txt                            (só o de texto)
```

O controle de texto puro sai idêntico com e sem `-a` — ele assegura a si mesmo. O controle com `\000` é o único que **muda de resultado** quando o `-a` cai, que é a definição de discriminar. **Restrição fixada, e ela entra nos dois gates: o arquivo de controle positivo plantado pela varredura de ausência carrega byte de controle, e a asserção é o par — a varredura com `-a` o acha, e a mesma varredura sem `-a` NÃO o acha.** Uma asserção que só olhe a metade de cima continua sendo a asserção que não pode falhar pelo motivo que a nomeia. O conteúdo do controle é um token de contexto de parsing, nunca um literal com forma de credencial: plantar forma de credencial numa fixture é criar o achado que o `secret-scan.mjs` existe para pegar.

É a invariante 2 do plano — três estados, nunca dois — aplicada à ferramenta de medição: sem o controle, "não achei" e "não consegui ler" saem pela mesma porta silenciosa; e com um controle que não discrimina, "varri com `-a`" e "varri sem" saem pela mesma porta também.

---

## 0. Resumo — o achado que muda a natureza do subgrupo

**`template/.forge/scripts/lib/argparse.sh` nunca existiu neste repositório.** A issue #133 abre dizendo que a `v0.14.0` "troca a camada de guardas de parsing de `lib/argparse.sh` por `lib/arg-guards.sh`". Do lado do produtor essa troca não aconteceu, porque não havia o que trocar:

```
$ ls template/.forge/scripts/lib/argparse.sh
ls: template/.forge/scripts/lib/argparse.sh: No such file or directory

$ git log --all --oneline --name-status --diff-filter=AD -- '*argparse*' | wc -l
0                          (o caminho nunca foi adicionado nem removido em ref nenhuma)

$ grep -arn '_ap_ctx\|_ap_value\|_ap_unknown\|argparse_guard_value' template/ tests/ installer/ bin/ | wc -l
0                          (COM -a, e com o controle positivo do preâmbulo provando que a varredura lê o universo)
```

O arquivo é invenção **local dos consumidores**, e existe em duas formas mutuamente incompatíveis:

```
$ for d in ~/Documents/projects/*/; do f="$d/.forge/scripts/lib/argparse.sh"; [ -f "$f" ] && echo "$d $(wc -l < "$f")"; done
/Users/milton/Documents/projects/axis-fare-validator/       96 linhas
/Users/milton/Documents/projects/Axis.PadSimulator/         37 linhas
```

O do `axis-fare-validator` expõe `_ap_ctx` / `_ap_value` / `_ap_unknown`; o do `Axis.PadSimulator` expõe uma única função, `argparse_guard_value`, com assinatura e semântica diferentes. Os dois foram escritos independentemente, para a mesma propriedade, sem contato entre si.

**O que isso significa, e é o item mais importante desta onda.** A regressão que #133 descreve é real do lado do consumidor e a causa dela **não é de parsing**: é o `forge update` sobrescrevendo `scripts/` inteiro (issue #101, e as issues #125/#131/#130 da Onda L1). O consumidor acrescentou uma camada local dentro de um `MACHINERY_DIR`, o update passou por cima dos sítios de chamada e a camada ficou no disco sem ninguém a invocar. Nenhuma correção de parsing no template conserta isso; o que conserta é L1. Esta onda **não** finge o contrário — ela fecha os defeitos de parsing que reproduzem no template, e §11 registra em letra o que continua sendo de L1.

| Peça | Arquivo | Natureza |
|---|---|---|
| Guarda de valor nos 11 sítios sem ela | `template/.forge/scripts/liaison-ops.sh` | correção de defeito, medida em §1 |
| `shift` do posicional restaurado em `test`, e recusa de argumento em `test`/`status` | `template/.forge/scripts/deferral-ops.sh` | **coordenado com a Onda E** — ver §7 |
| Recusa de argumento desconhecido nos 4 subcomandos | `template/.forge/scripts/wave-ops.sh` | porta aberta medida em §2.4, ausente do censo da Onda E |
| `-h`/`--help` no dispatcher | 14 scripts de `template/.forge/scripts/` | contrato de saída novo, universo derivado em §2.2 |
| `--root` do chamador respeitado; chave repetida recusada | `template/.forge/scripts/run-manifest.sh` e `lib/run-manifest.mjs` | contrato de escrita, medido em §3 |
| Âncora nas duas pontas | `template/.forge/hooks/pre-tool-use/validate-naming-conventions.sh` | correção de predicado, medida em §4 |
| Gate A — superfície de argumento | `tests/w<NNN>-arg-surface-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Gate B — proveniência de caminho | `tests/w<NNN>-path-provenance-gate.sh` (novo) | ordinal alocado pelo orquestrador |

**Ordinais: a onda NÃO aloca.** Medido nesta revisão, com o comando que enumera **todos** os refs em vez de confiar na árvore local:

```
$ ls tests/w*-gate.sh | sed 's#.*/w\([0-9]*\)-.*#\1#' | sort -n | tail -1
207
$ for r in $(git -C . for-each-ref --format='%(refname)' refs/heads refs/remotes); do
    m=$(git -C . ls-tree --name-only "$r" tests/ | sed -n 's#^tests/w\([0-9][0-9]*\)-.*#\1#p' | sort -n | tail -1)
    [ -n "$m" ] && printf '%-58s w%s\n' "$r" "$m"
  done
refs/heads/develop                                         w207
refs/heads/feat/fase1-dogfood-completo                     w207
refs/heads/main                                            w207
refs/remotes/origin/HEAD                                   w207
refs/remotes/origin/develop                                w207
refs/remotes/origin/main                                   w207
refs/remotes/origin/wip/deepspec-run-manifest-ldg-0165     w80
refs/remotes/origin/wip/upgrade-safety-ldg-0131            w154
```

O máximo publicado é **w207** em todo ref que carrega `tests/`. A invariante 10 do plano atribui a alocação ao orquestrador, no momento de escrever o arquivo, conferida contra `origin/*` **e** contra as branches em voo desta rodada — e esta rodada tem várias frentes escrevendo gate ao mesmo tempo.

---

## 1. ITEM 1 — issue #133, a metade que reproduz: `liaison-ops.sh`

### 1.1 O censo, derivado do código

O `liaison-ops.sh` tem duas camadas de guarda hoje, e elas cobrem propriedades diferentes:

- **P1, argumento desconhecido** — `_reject_unknown`, cópia local no próprio arquivo (`liaison-ops.sh:125-134`), 23 sítios.
- **P2, flag engolida como valor** — `forge_reject_flag_as_value`, importada de `lib/arg-guards.sh`, 20 dos 31 sítios que consomem `"$2"`.

```
$ grep -acE '\-\-[a-z-]+\)[^;]*"\$\{?2' template/.forge/scripts/liaison-ops.sh           → 31
$ grep -aE '\-\-[a-z-]+\)[^;]*"\$\{?2' template/.forge/scripts/liaison-ops.sh \
    | grep -acE 'forge_reject_flag_as_value|forge_require_value|_require_value'          → 20
```

O mesmo par, rodado sobre os três irmãos, produz a tabela abaixo; os quatro números do `liaison-ops` e os oito dos irmãos foram reexecutados na revisão 2 contra `cf3bbe4`, com `-a`, e reproduzem.

Os **11** sítios sem guarda de valor, com a linha:

```
317:    --self) self_arg="$2"; shift 2 ;;
318:    --participants) participants="$2"; shift 2 ;;
771:    --thread) filter_thread="$2"; shift 2 ;;
830:  ... case "$1" in --upto) upto="$2"; shift 2 ;; *) _reject_unknown "read" "--upto" "$1" ;; esac ...
969:  ... case "$1" in --out) out_dir="$2"; shift 2 ;; *) _reject_unknown "export" "--out" "$1" ;; esac ...
985:  ... case "$1" in --from) from_dir="$2"; shift 2 ;; *) _reject_unknown "import" "--from" "$1" ;; esac ...
1133: ... case "$1" in --path) peer_path="$2"; shift 2 ;; *) _reject_unknown "peer set" "--path" "$1" ;; esac ...
1188:      --kind) t_kind="$2"; shift 2 ;;
1189:      --path) t_path="$2"; shift 2 ;;
1190:      --remote) t_remote="$2"; shift 2 ;;
1191:      --branch) t_branch="$2"; shift 2 ;;
```

**E o censo simétrico desmente a outra metade da issue.** Nos dois scripts irmãos a cobertura de P2 é total:

| script | sítios que consomem `"$2"` | com guarda de valor | sem |
|---|---:|---:|---:|
| `liaison-ops.sh` | 31 | 20 | **11** |
| `deferral-ops.sh` | 3 | 3 | 0 |
| `ledger-ops.sh` | 23 | 23 | 0 |
| `wave-ops.sh` | 0 | 0 | 0 |

O `ledger-ops.sh` chega lá por um caminho que um `grep` ingênuo pelo nome `forge_reject_flag_as_value` não enxerga: ele define `_require_value() { forge_require_value "$@"; }` (`ledger-ops.sh:52`) e passa o quarto argumento em todos os 23 sítios, e `forge_require_value` delega o pertencimento antes de testar o vazio. Registro o passo em falso porque a primeira passada do meu próprio censo contou `ledger-ops` como **0 guardados**, e a conclusão errada teria sido que ele é o pior dos três quando ele é o único íntegro. **Todos os números desta tabela são testemunha de data, não critério** — a asserção correspondente, em §6, é sobre a propriedade e sobre piso derivado na execução.

### 1.2 O defeito, reproduzido — bancada, comandos e saída

Bancada montada com `cwd` dentro dela. **Ela foi remontada do zero na revisão 2**, sob `"${TMPDIR:-/tmp}/l4-rev2"` e a partir do `template/` de `cf3bbe4`, e as onze linhas da tabela abaixo reproduziram uma a uma, com os mesmos `rc` e as mesmas mensagens:

```bash
W="${TMPDIR:-/tmp}/l4-bench"; rm -rf "$W"; mkdir -p "$W/repo"
WS=/Users/milton/Documents/projects/forge-harness
cd "$W/repo"; git init -q -b develop .; git config user.email a@b.c; git config user.name t
mkdir -p .forge; cp -R "$WS/template/.forge/scripts" .forge/scripts
printf 'x\n' > z.txt; git add -A; git commit -qm base
bash .forge/scripts/liaison-ops.sh open demo --self forge-harness --participants forge-harness,peer
```

Os onze sítios, exercitados um a um com a próxima flag do **mesmo** subcomando no lugar do valor. O `rc` foi capturado sem pipe, porque `$?` depois de `| head` devolve o status do `head` — é a mesma armadilha que #136 registra:

**A revisão 2 publicava nove invocações e falava em "três dos onze" e "seis dos onze" — o revisor pegou que a aritmética não fecha com o denominador que ela nomeia, e a saída não é reescrever a conta: é tornar a enumeração exaustiva.** Faltavam os sítios `:1190` (`--remote`) e `:1191` (`--branch`), que compartilham o laço de `transport set` com `--kind` e `--path`. Medi os dois na revisão 3 e a tabela passa a ter **uma invocação por sítio, onze para onze**, com o sítio anotado ao lado:

```
inbox demo --thread --show                    rc=0   (nenhuma thread)                                         :771
peer set demo p --path --path                 rc=0   OK peer set — p → --path (canal demo)                    :1133
open d2 --self --participants x               rc=1   FAIL: argumento inesperado 'x' para o subcomando 'open'   :317
open d3 --participants --self x               rc=1   FAIL: argumento inesperado 'x' para o subcomando 'open'   :318
read demo --upto --upto                       rc=1   mensagem '--upto' desconhecida localmente                 :830
export demo --out --out                       rc=64  mkdir: illegal option -- -                                :969
import demo --from --from                     rc=1   FAIL: '--from/log' não encontrado                         :985
transport set demo --kind --path              rc=1   kind inválido: --path (use manual|fs|git|gh)              :1188
transport set demo --path --kind              rc=1   FAIL: --kind obrigatório (manual|fs|git|gh)               :1189
transport set demo --remote --branch          rc=1   FAIL: --kind obrigatório (manual|fs|git|gh)               :1190
transport set demo --branch --kind            rc=1   FAIL: --kind obrigatório (manual|fs|git|gh)               :1191
```

`inbox demo --thread --titles-only` é uma segunda invocação do **mesmo** sítio `:771`, com o mesmo desfecho (`rc=0`, `(nenhuma thread)`); ela estava na tabela da revisão 2 e é o que fazia a contagem por invocação divergir da contagem por sítio. Os onze endereços foram reconferidos na revisão 3 e são os mesmos: `grep -anE '\-\-[a-z-]+\)[^;]*"\$\{?2' … | grep -avE 'forge_reject_flag_as_value|forge_require_value|_require_value'` devolve `317 318 771 830 969 985 1133 1188 1189 1190 1191`, onze linhas.

Controle, no mesmo canal: `inbox demo --lixo x` responde `rc=1  FAIL: flag desconhecida '--lixo' para o subcomando 'inbox'`. **Ou seja, P1 continua fechado no `liaison-ops.sh`, e a afirmação do título da issue — "flag desconhecida aceita em silêncio (rc=0)" — NÃO reproduz aqui.** O corpo da própria issue já se retrata disso ("eu me corrijo: o `arg-guards.sh` **tem** `forge_reject_unknown`"), e o que sobra dela para o `liaison-ops.sh` é P2, que reproduz inteiro.

Três coisas nessa tabela valem mais que a contagem.

**A primeira: dois dos onze saem `rc 0` e um deles ESCREVE.** O `peer set demo p --path --path` gravou o literal `--path` como caminho do peer, com `OK`, e a leitura de volta confirma:

```
$ bash .forge/scripts/liaison-ops.sh peer-path demo p ; echo "rc=$?"
--path
rc=0
$ sed -n '1,10p' .forge/liaison/liaison.yaml
self:
  id: forge-harness
channels:
  demo:
    participants:
      - forge-harness
      - peer
    peers:
      p: "--path"
```

O destino da escrita é `liaison.yaml` — que a issue #123, da Onda C, identifica como *"o ponto fixo, único elo lido do tronco"*. Um valor de lixo gravado ali com `rc 0` é escrita durável em cima da única peça de configuração que o transporte lê.

**A segunda: NOVE dos onze já saem `rc≠0`, e nenhum deles sai pela flag** — a revisão 2 dizia seis, e o número subiu porque a enumeração ficou exaustiva, o que **fortalece** o argumento em vez de o enfraquecer. `read` reprova por "mensagem desconhecida localmente", `export` por `mkdir: illegal option`, `import` por arquivo não encontrado, `transport set` por validação de enum nos quatro sítios dele, e `open` por argumento posicional inesperado nos dois dele. Um gate escrito como "exercito o sítio e exijo `rc≠0`" ficaria **verde contra o script sem guarda** em nove dos onze sítios — ou seja, em todos menos os dois que a issue já enxergava. O cabeçalho do `argparse.sh` do `axis-fare-validator` já tinha nomeado exatamente essa armadilha, com o número dele: *"em 6 dos 12 sítios do `liaison-ops.sh` a invocação com flag errada JÁ saía com `rc≠0` — mas por '--upto obrigatório' ou 'transporte não configurado', nunca pela flag"*. A asserção desta onda é sobre a **mensagem**, e §6 a escreve assim.

**A terceira: `export demo --out --out` sai `rc 64`.** Sessenta e quatro não está em tabela de rc nenhuma deste script; é o `EX_USAGE` que o `mkdir` do sistema devolve ao receber `--out` como opção. Um chamador que classifique rc por faixa lê isso como uma coisa que o harness não emite.

### 1.3 A metade que NÃO reproduz: `deferral-ops.sh`

A issue afirma que a `v0.14.0` "apagou as guardas de `test` e `status`". Não há evidência de apagamento no produtor: os dois subcomandos **nunca tiveram laço de parsing**. `deferral-ops.sh` tem 4 subcomandos e 2 laços — `raise` (`:62-68`) e `resolve` (`:93`, laço numa linha só) —, e `test` (`:114`) e `status` (`:133`) leem posicionais e ignoram o resto. Os dois endereços foram reconferidos na revisão 2 com `grep -an 'while \[ \$# -gt 0 \]' template/.forge/scripts/deferral-ops.sh`, que devolve `62` e `93`; a revisão 1 dizia `:61-68` e `:92-93` e errava a primeira linha de cada. Reproduzido:

```
raise (setup)                                        rc=0   OK raise — DEFER-01 registrado
status <id> --lixo x                                 rc=0   OPEN (1/1 open: DEFER-01)
resolve <id> DEFER-01 --note nota                    rc=0   OK resolve — DEFER-01 marcado como resolved
test <id> DEFER-01 --lixo x                          rc=0   OK test — DEFER-01 marcado como tested
status <id> depois                                   rc=0   OK (1 tested, 0 resolved, 0 open)
```

O `test` com o argumento desconhecido **gravou**: o registro passou de `resolved` para `tested` e o `--lixo x` foi descartado. Reproduzido na revisão 2, com o `status` antes e depois e o digest do arquivo:

```
$ bash "$D" raise l4-demo --reason m ; bash "$D" resolve l4-demo DEFER-01 --note n
$ bash "$D" status l4-demo                      → OK (0 tested, 1 resolved, 0 open)
$ bash "$D" test l4-demo DEFER-01 --lixo x      → OK test — DEFER-01 marcado como tested     rc=0
$ bash "$D" status l4-demo                      → OK (1 tested, 0 resolved, 0 open)
$ grep -c 'lixo' .forge/specs/active/l4-demo/deferrals.json   → 0     ← o argumento sumiu, a escrita ficou
```

**A quem pertence fechar isso — decisão de dono, e ela mudou na revisão 2.** A Onda E mediu esta porta primeiro (§5.2 dela) e a alocou na decisão 11 junto com `ledger-ops render`/`status`. A revisão 1 desta especificação declarou em letra que "esta onda não duplica esse trabalho" e, três seções adiante, mandava implementá-la — contradição que o revisor pegou com razão, e que ordem de merge não resolve. A decisão é **D17** (§1.4), e ela move os dois ramos de `deferral-ops.sh` para L4.

### 1.4 Decisões de desenho — FECHADAS

**D1. A camada de guarda continua sendo `lib/arg-guards.sh`, uma só. `lib/argparse.sh` NÃO é adotada.**

A issue pede que os dois scripts "carreguem **as duas** camadas, como o consumidor teve de fazer à mão". A propriedade que ela quer é legítima e está nomeada com precisão no corpo dela: *"`argparse.sh` declara o contexto de cada laço, o que torna a cobertura **verificável** por um teste estrutural em vez de depender de o autor ter lembrado de chamar a guarda em cada sítio"*. É verificabilidade estrutural, não uma terceira função de recusa. E ela **já existe neste repositório, para P1**, sem `_ap_ctx`:

```
$ sed -n '270,280p' tests/w150-liaison-flag-and-trust-gate.sh
[5] nenhum parser de flags sobrou com o descarte silencioso
  n_silent  = grep -c '\*) shift ;;'                → exige 0
  n_loops   = grep -c 'while \[ \$# -gt 0 \]'       → exige >= 12  (piso contra vacuidade)
  n_reject  = grep -c '\*) _reject_unknown'         → exige n_reject == n_loops
```

`w150[5]` é a derivação estrutural de P1 sobre o `liaison-ops.sh`, com piso e com contrapositiva, e ela é anterior a esta onda. **O que falta é a mesma derivação para P2**, e o material dela já está no arquivo: o conjunto de flags de cada subcomando é o segundo argumento de `_reject_unknown`, presente em 23 sítios, e os braços que consomem `"$2"` são derivávéis do corpo do `case`. `_ap_ctx` seria uma **quarta** declaração do mesmo conjunto.

*Alternativa descartada — importar o `argparse.sh` do `axis-fare-validator`.* Três razões medidas. A primeira: existem **duas** encarnações incompatíveis do arquivo no campo (`_ap_ctx/_ap_value/_ap_unknown` no `axis-fare-validator`, `argparse_guard_value` no `Axis.PadSimulator`), e adotar uma abençoa a API de um consumidor e orfana a do outro — o produtor passaria a ter três vocabulários para a mesma propriedade. A segunda: o próprio cabeçalho do teste estrutural do consumidor diz que o conjunto de `_ap_ctx` é *"uma cópia MANUAL das flags tratadas nos braços do `case`"*, e é por isso que ele precisou de uma asserção E2 para cruzar declaração com braços — adotar `_ap_ctx` importa a cópia **e** a necessidade de a conferir, enquanto derivar do `_reject_unknown` existente remove a cópia. A terceira: acrescentar 16 sítios de chamada nova a arquivos que #125/#131 já sobrescrevem mal aumenta a superfície do defeito de L1 sem fechar nada que a derivação não feche.

*Alternativa descartada — declarar o contexto só em comentário, sem função.* Uma declaração que a máquina não confronta com os braços é a deriva que o E2 do consumidor existe para pegar, com a agravante de nascer sem quem a confronte.

**D2. Os 11 sítios ganham a guarda de valor, e a asserção do gate é sobre a MENSAGEM, nunca só sobre `rc≠0`.**

Medido em §1.2, com a enumeração exaustiva da revisão 3: **nove** dos onze já saem `rc≠0` pelo motivo errado. A propriedade é: *invocado com a flag seguinte no lugar do valor, o sítio recusa **nomeando a flag-dona, o valor recusado e o subcomando**, e nenhuma escrita durável ocorre*. O contrafactual de cada linha está na tabela de §1.2.

**D3. O critério continua sendo PERTENCIMENTO ao conjunto declarado, nunca "começa com hífen", e o controle negativo é asserção.**

`arg-guards.sh:48-88` já documenta e implementa isso, e a onda não muda o critério. O controle negativo entra no gate porque ele é o que separa "fechei P2" de "proibi todo valor com hífen": `send --body '---frontmatter'` e `list --top -3` continuam aceitos, e `arg-guards.sh` já normaliza os dois idiomas de separador — vírgula-espaço no `liaison-ops.sh`, espaço no `ledger-ops.sh`/`deferral-ops.sh`.

**D4. O `liaison-ops.sh` mantém a cópia local de `_reject_unknown`, e a derivação estrutural aceita as três grafias instaladas.**

Medido: `liaison-ops.sh:125` define a própria `_reject_unknown` (uma cópia da `forge_reject_unknown`, sem as três linhas de explicação); `ledger-ops.sh:51-52` aliasa para as `forge_*`; `deferral-ops.sh` chama as `forge_*` diretamente. Consolidar é LDG-0152, onda F, e o próprio cabeçalho de `arg-guards.sh:23-24` declara isso como trabalho próprio. Esta onda não consolida — mas a derivação que ela escreve tem de sobreviver à consolidação, então ela casa **qualquer** das grafias e o cenário `[2]` de §6 exige isso em letra.

**D5. `wave-ops.sh` entra na onda para P1, e apenas para P1.**

Medido nesta rodada, e ausente do censo de portas da Onda E, que enumerou `ledger-ops` e `deferral-ops`:

```
wave-ops.sh status 2026-09-07-demo                rc=0   no waves.json
wave-ops.sh status 2026-09-07-demo --lixo x       rc=0   no waves.json      ← engolido
```

`grep -c 'while \[ \$# -gt 0 \]' template/.forge/scripts/wave-ops.sh` devolve **0** e `grep -c '_reject_unknown'` devolve **0**: o script não tem parser de flag nenhum. Ele entra porque a onda já toca os quatro scripts de operação por causa de #136, e porque uma porta aberta medida que fica de fora vira item de ledger na semana seguinte.

**O conjunto de flags aceitas por subcomando do `wave-ops.sh`, DERIVADO — e sem ele o laço de recusa quebra um gate existente.** O revisor da revisão 2 apontou que a D5 punha P1 nos quatro subcomandos sem declarar o que cada um aceita, e que `tests/w131-surface-declaration-gate.sh` invoca `close … --gate OK`. Remedi antes de aceitar, e ele está certo na substância — o endereço exato é outro: `w131:198` é o **corpo** do helper (`wave-ops.sh close chg "$@"`) e o sítio de chamada com a flag é `w131:222`, `close_wave "$T/wliar" W1 --gate OK`; há um segundo em `:253` com `--gate FAIL`. Medido:

```
$ grep -anoE '\-\-[a-z][a-z-]*' template/.forge/scripts/wave-ops.sh
7:--gate  141:--gate  144:--gate  146:--gate  147:--gate  147:--gate  152:--gate
$ grep -an '^[^#]*\-\-[a-z]' template/.forge/scripts/wave-ops.sh
152:  if [ "${2:-}" = "--gate" ]; then claimed="${3:-OK}"; fi        ← o ÚNICO sítio fora de comentário
$ grep -an '"\${\?[1-9]' template/.forge/scripts/wave-ops.sh
14:cmd="${1:-}"; shift || true     15:change_id="${1:-}"; shift || true
107:  wave_id="${1:-}"  (open)     136:  wave_id="${1:-}"  (close)     152:  (--gate)
$ grep -an 'close_wave ' tests/w131-surface-declaration-gate.sh
222:close_wave "$T/wliar" W1 --gate OK      253:close_wave "$T/wfail" W1 --gate FAIL
236:/245:/261:/306:  close_wave … W1        (sem flag)
```

`--gate` é o **único** literal de flag do arquivo inteiro, e o único sítio dele fora de comentário está no ramo `close`. O conjunto declarado por subcomando fica, então, derivado e não inventado:

| subcomando | posicionais | flags aceitas |
|---|---|---|
| `plan` | `<change-id>` | `(nenhuma)` |
| `open` | `<change-id> <wave-id>` | `(nenhuma)` |
| `close` | `<change-id> <wave-id>` | `--gate <OK\|FAIL>` |
| `status` | `<change-id>` | `(nenhuma)` |

**Restrição fixada: o laço de recusa de `close` aceita `--gate` e o valor dele, e `w131` entra na lista de gates que rodam sem edição e ficam verdes (§13.2).** Um laço ingênuo em `close` reprovaria `w131:222`, que é invocação legítima. Há uma segunda armadilha no mesmo gate, e ela é de **mensagem**: `w131:207-210` reprova quando a saída de uma recusa contém `Usage`, `obrigatório` ou `não encontrada`, porque para ele isso é "reprovou por erro de uso, não pelo gate". Nenhum dos seis sítios de chamada passa flag desconhecida, então o laço novo não é alcançado por ele — mas a mensagem de recusa do `wave-ops` não pode vazar para os caminhos que `w131` exercita.

*O que fica de fora, com a medição e a razão.* `wave-ops.sh:152` lê `--gate` por **posição** — depois dos dois `shift` de `:14-15`, `"${2:-}"` é o token imediatamente após o wave-id —, de modo que um erro de digitação não casa e o ramo do default assume. **Não medi a direção do desfecho** — o comentário de `:141-147` sugere que a ausência de `--gate` executa os gates de verdade, isto é, o erro cairia para o lado seguro, mas suposição não é medição. Entra como item de ledger a medir, não como asserção desta onda: o laço de P1 recusa flag **desconhecida** e não muda a forma como `--gate` é lido.

**D17. Os ramos `test)` e `status)` de `deferral-ops.sh` passam a ser de L4, e saem da decisão 11 da Onda E. A Onda E fica com as duas portas de `ledger-ops.sh` (`render` e `status`).**

Esta decisão fecha a contradição que o revisor da revisão 1 nomeou, e ela não é de conveniência editorial — é a única partição que mantém a correção **atômica**, e isso está medido.

O ramo `test)` precisa de duas mudanças que só valem juntas: o `shift || true` do posicional (que L4 mediu em §5.1, e que a Onda E não podia ter visto porque não é assunto de parsing) e o laço de recusa. Executei as duas metades separadas, em bancada, sobre cópias em `$TMPDIR`, com controle de digest e recontrole — e a invocação legítima, que é literalmente a linha `tests/w51-waves-progress-gate.sh:112`, muda de desfecho conforme a metade que estiver no disco:

```
laço SEM o shift    →  test <change> DEFER-01   rc=1  FAIL: argumento inesperado 'DEFER-01' para o subcomando 'test'
laço COM o shift    →  test <change> DEFER-01   rc=0  OK test — DEFER-01 marcado como tested
laço COM o shift    →  test <change> DEFER-01 --lixo x   rc=1  FAIL: flag desconhecida '--lixo' para o subcomando 'test'
```

Duas ondas escrevendo metades diferentes do mesmo ramo, em dois PRs, produzem uma janela em que `w51` está vermelho no tronco — e a janela existe em qualquer ordem de merge, porque nenhuma das duas ondas controla quando a outra entra. Um dono só, um commit, fecha a janela por construção.

A partição também **elimina a interseção de arquivos**: com D17, L4 edita `deferral-ops.sh` e `wave-ops.sh`, a Onda E edita `ledger-ops.sh`, e as duas deixam de tocar o mesmo arquivo. A §5.5 registrava uma coordenação de rebase que agora deixa de ser necessária.

E ela **não custa nada à Onda E**, porque a outra metade da decisão 11 — o literal `(nenhuma)` para conjunto de flags vazio — é convenção de **chamador**, não mudança de biblioteca. Medido na bancada, com o `arg-guards.sh` de hoje, sem tocar uma linha dele:

```
$ bash -c '. .forge/scripts/lib/arg-guards.sh; forge_reject_unknown test "(nenhuma)" "--lixo"'
FAIL: flag desconhecida '--lixo' para o subcomando 'test'
  flags aceitas em 'test': (nenhuma)
  argumento desconhecido não é descartado: o descarte engole a flag E o valor dela, e a
  operação segue com rc 0 sobre um registro incompleto.
rc=1
```

A linha sai legível e não truncada com a biblioteca instalada. Logo L4 adota o literal da decisão 11 nos dois ramos que assume, sem depender de a Onda E ter mergeado, e a Onda E o adota nos dois dela. As duas ondas passam a compartilhar uma **convenção**, não um arquivo.

*Alternativa descartada — L4 escreve só o `shift` e a Onda E escreve o laço.* É a leitura literal da revisão 1, e ela é a que produz a janela vermelha acima. Pior: o cenário `w201[12]` da Onda E, que assegura a recusa, ficaria verde sobre uma árvore em que a invocação legítima está quebrada, porque `w201[12]` não tem o par positivo — que é exatamente a correção 2 da §5.1. A implementação errada passaria no gate que a vigia e derrubaria um gate em outro arquivo.

*Alternativa descartada — a Onda E assume também o `shift`.* Ela teria de importar uma medição que não é dela para dentro de uma decisão dela, e o revisor da Onda E não tem como conferir a pré-condição sem reler esta especificação inteira. A §7 continua existindo para o resto, mas o trabalho vai para quem mediu.

---

## 2. ITEM 2 — issue #136, `--help`

### 2.1 O defeito, reproduzido — e o universo é maior que os quatro scripts da issue

A issue mediu quatro scripts numa árvore de consumidor em `template_version: 0.11.0`. Reproduzi os quatro no template de hoje e o comportamento é idêntico:

```
liaison-ops    --help  rc=1   FAIL: comando desconhecido '--help'
liaison-ops    (nada)  rc=1   Usage: liaison-ops.sh open|thread|send|inbox|read|ack|status|export|import|conflicts|peer|peer-path|transport|sync|render [args...]
liaison-ops    (inval) rc=1   FAIL: comando desconhecido 'comando-que-nao-existe'
ledger-ops     --help  rc=1   FAIL: comando desconhecido '--help'
wave-ops       --help  rc=1   Usage: wave-ops.sh plan|open|close|status <change-id> [args...]
deferral-ops   --help  rc=1   Usage: deferral-ops.sh raise|resolve|test|status <change-id> [args...]
red-evidence   --help  rc=1   FAIL (usage: red-evidence.sh record|replay|status|waive|init <change-id> [...] | ci)
```

Uma única divergência entre a cópia do consumidor e o template, e ela é cosmética: o usage do `liaison-ops` do consumidor lista `pending` e o de hoje lista `conflicts`. O defeito é o mesmo.

Acrescentei duas medições que a issue não tinha e as duas mudam decisão.

**A primeira: o canal do usage não é uniforme, e a revisão 2 mede a heterogeneidade sobre o universo inteiro em vez de sobre os cinco scripts da issue.** Entre os catorze membros do universo de §2.2, **cinco** imprimem em stderr (`liaison-ops`, `ledger-ops`, `wave-ops`, `deferral-ops`, `gate-ordinal`) e **nove** imprimem em stdout. O comando que separou os dois canais, com o `rc` capturado sem pipe:

```
$ for s in liaison-ops ledger-ops wave-ops deferral-ops red-evidence approval-log check-red-first \
           gate-ordinal graph run-gates spec-advance-module spec-close spec-new spec-transition; do
    o=$(bash .forge/scripts/$s.sh --help 2>/dev/null); rc=$?
    e=$(bash .forge/scripts/$s.sh --help 2>&1 1>/dev/null)
    printf '%-22s rc=%-3s stdout=[%.34s] stderr=[%.34s]\n' "$s" "$rc" "$(printf '%s' "$o" | head -1)" "$(printf '%s' "$e" | head -1)"
  done
```

Nos cinco scripts da issue o recorte é o que a revisão 1 publicou — quatro em stderr e o `red-evidence.sh` em stdout com a palavra `FAIL` colada:

```
liaison-ops    stdout=[]                              stderr=[Usage: liaison-ops.sh open|thr]
ledger-ops     stdout=[]                              stderr=[Usage: ledger-ops.sh add|updat]
wave-ops       stdout=[]                              stderr=[Usage: wave-ops.sh plan|open|c]
deferral-ops   stdout=[]                              stderr=[Usage: deferral-ops.sh raise|r]
red-evidence   stdout=[FAIL (usage: red-evidence.sh r] stderr=[]
```

**A segunda, e é a que derruba a avaliação de gravidade da própria issue: o `rc` NÃO é uniforme, e dois scripts do universo maior devolvem ZERO.** A issue escreve *"o `rc=1` é uniforme, então um chamador que testa o status não é enganado"*. Sobre os quatro scripts dela isso é verdade; sobre o universo de scripts com dispatcher não é:

```
approval-log           rc=1    FAIL (no active change: --help)
check-red-first        rc=1    FAIL (usage: check-red-first.sh check|status|waive <change-id> [...])
gate-ordinal           rc=2    FAIL gate-ordinal — comando desconhecido '--help' (use 'check' ou 'next')
graph                  rc=1    FAIL (usage: graph.sh build|update|validate|query <term>|path <a> <b>|…)
run-gates              rc=0      (nenhum gate declarado em runtime.gates do FORGE.md — nada a executar)
spec-close             rc=1    FAIL (no active change: --help)
spec-new               rc=2    FAIL (change-id must be kebab-case: --help)
spec-transition        rc=2    FAIL (usage: spec-transition.sh <change-id> <new-status> [--reason ...])
spec-advance-module    rc=0    SKIP (usage: spec-advance-module.sh <modulo> <implementing|implemented>)
```

O `run-gates.sh --help` sair **`rc 0`** é falso-verde, e o controle prova que é: com **nenhum** argumento ele devolve `rc 1` e o usage; com **qualquer** argumento — `--help` ou `gate-que-nao-existe` — ele devolve `rc 0` e `NO-GATES`, porque tratou o token como change-id e não encontrou gates declarados.

```
run-gates.sh                        rc=1   FAIL (usage: run-gates.sh <change-id> [wave-id] [--phase <fase>])
run-gates.sh gate-que-nao-existe    rc=0     (nenhum gate declarado em runtime.gates do FORGE.md — nada a executar)
run-gates.sh --help                 rc=0     (nenhum gate declarado em runtime.gates do FORGE.md — nada a executar)
```

Um passo de CI que rodasse `run-gates.sh --help` por engano seria reportado como aprovado. Isso é a invariante 2 do plano-mestre — "não encontrei violação" colapsado com "não rodei" — dentro do executor de gates, e é o que justifica um escopo maior que os quatro scripts da issue.

**E há um agravante que a revisão 1 não mediu e que dá a forma certa à asserção de `run-gates`.** O cabeçalho do próprio script (`run-gates.sh:6-7`, `:23-24`) documenta que a **última linha** da saída é o veredito agregado, e que o chamador o consome assim: `gate_result="$(bash .forge/scripts/run-gates.sh <id> <wave> 2>&1 | tail -1)"` seguido de `wave-ops.sh close <id> <wave> --gate "$gate_result"`. Medido:

```
$ bash .forge/scripts/run-gates.sh --help 2>/dev/null | tail -1              → NO-GATES
$ bash .forge/scripts/run-gates.sh id-que-nao-existe 2>/dev/null | tail -1   → NO-GATES
$ cmp <(bash .forge/scripts/run-gates.sh --help 2>/dev/null) \
      <(bash .forge/scripts/run-gates.sh id-que-nao-existe 2>/dev/null)      → (idênticas)
```

As duas saídas são **byte a byte idênticas**, com `rc 0` nas duas. Pedir ajuda ao executor de gates hoje não devolve ajuda: devolve um **veredito de wave**, que o idioma documentado carimba no `waves.json`. É esse o defeito de `run-gates`, e é sobre ele que a asserção `[11]` passa a ser escrita (D7).

**A terceira medição da revisão 2, e ela reduz escopo em vez de aumentar: o canal da via de ERRO também não é uniforme, e a onda não o move.** Nove dos catorze imprimem a mensagem de erro em stdout hoje. Uma prescrição de "a via de erro continua em stderr" — que era o que a revisão 1 escrevia em D6 e no cenário `[10]` — não descreve o estado de nove membros, e cumpri-la seria realocar canal em nove scripts cujo raio de quebra esta onda não mediu. D6 foi reescrita para não tocar canal de erro nenhum.

### 2.2 O universo, derivado — e o predicado que o define

Escolher os scripts a dedo produziria uma lista mantida à mão, que é a enumeração que envelhece. O universo é derivado por um predicado de duas cláusulas, medido nesta rodada:

```
$ for f in template/.forge/scripts/*.sh; do
    grep -qE 'case "\$(cmd|CMD|1|subcmd|SUBCMD|action)"? in' "$f" || continue
    u=$(grep -cE '[Uu]sage:' "$f"); h=$(grep -cE '\-h\|--help\)|--help\|-h\)' "$f")
    printf '%-28s usage=%-3s help=%s\n' "$(basename $f)" "$u" "$h"
  done
```

**23** scripts casam a primeira cláusula; **14** deles declaram um literal `Usage:`/`usage:`; **0** desses 14 tratam `-h`/`--help`.

**A revisão 1 explicava a exclusão errado, e o revisor pegou.** Ela dizia que `node-baseline.sh` e `dotnet-baseline.sh` "não têm dispatcher e por isso ficam fora do predicado". Falso: os dois **entram** pela primeira cláusula (`grep -an 'case "\$1" in'` devolve `node-baseline.sh:36` e `dotnet-baseline.sh:33`) e saem pela **segunda**, `usage=0` — eles documentam o uso em bloco de comentário, não num literal `Usage:`. O universo de 14 não muda; a razão da exclusão, sim.

**E eles não são dois, são três.** A varredura, refeita com `-a`:

```
$ grep -arlE '\-h\|--help\)|--help\|-h\)' template/.forge/scripts/*.sh
template/.forge/scripts/dotnet-baseline.sh
template/.forge/scripts/doctor.sh
template/.forge/scripts/node-baseline.sh
$ ls template/.forge/scripts/*.sh | wc -l          → 61     (controle: o universo varrido)
```

O `doctor.sh` fica fora das **duas** cláusulas — ele despacha sobre `"${1:-}"`, que a primeira cláusula não casa —, e é o adotante mais forte do idioma, porque o contrato dele já está **assegurado por teste rastreado**:

```
$ sed -n '25,29p' template/.forge/scripts/doctor.sh
  -h|--help)
    grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
    exit 0 ;;
  *) echo "Argumento desconhecido: $1 (use --install ou --report)"; exit 2 ;;
$ sed -n '218,228p' tests/snapshot/claude-contract.bats
# ── C6 — doctor.sh ───────────────────────────────────────────────────────────

@test "C6: doctor.sh --help exits 0" {
  run bash "$SCRIPTS_DIR/doctor.sh" --help
  [ "$status" -eq 0 ]
}

@test "C6: doctor.sh rejects unknown argument with exit 2" {
  run bash "$SCRIPTS_DIR/doctor.sh" --bogus-flag
  [ "$status" -eq 2 ]
}
```

Os três estados que D6 fixa já estão escritos e assegurados em um script deste repositório: ajuda sai `0`, argumento desconhecido sai `2` **nomeando o argumento**. A onda não inventa contrato — ela alarga um que já tem gate.

**Com uma ressalva que eu mesmo levanto, porque ela enfraquece o argumento e escondê-la seria o defeito que esta rodada combate:** as suítes `bats` são **puladas** quando o binário não está no PATH (`tests/run-all.sh:93-95`, `bats indisponível — %d suíte(s) puladas`), então o C6 é um adotante forte no **desenho** e condicional na **execução**. Nesta máquina `command -v bats` devolve `/opt/homebrew/bin/bats` (Bats 1.13.0) e ele roda; numa árvore sem `bats` ele não roda e não avisa mais do que a linha de skip. Isso não muda D6 — o idioma continua sendo o instalado, em três scripts —, mas significa que a garantia dos três estados nesta onda precisa vir dos cenários `[9]` e `[10]` do Gate A, que são `bash` puro, e não do C6.

O universo é: **script sob `template/.forge/scripts/` que tem dispatcher de subcomando e declara um literal de usage.** Hoje são 14; o número é testemunha de data e o gate o deriva na execução, com piso.

### 2.3 A segurança de alargar o escopo, medida antes de decidir

Acrescentar um ramo `-h|--help)` como **primeiro** ramo do dispatcher só é seguro se nenhum dos 14 já atribuir significado a esses tokens na primeira posição. Medido: o censo estático acima devolve `help=0` para os catorze, e as invocações de §2.1 mostram que os catorze tratam `--help` como comando inválido, change-id ou gate-id — nunca como algo que a onda esteja tomando de alguém. O ramo é inalcançável exceto quando o operador digita `--help` ou `-h` como **primeiro** token, e portanto não pode sombrear um valor de flag num subcomando (`gate-ordinal.sh next --path --help` continua sendo problema do parser de `next`, não do dispatcher).

**Mas "primeiro ramo do dispatcher" não descreve onde o token precisa ser tratado em cinco dos catorze, e a revisão 1 escrevia como se descrevesse.** Medido:

```
$ grep -an 'ID="${1:-}"\|^ID=\|while \[ \$# -gt 0 \]' template/.forge/scripts/{approval-log,spec-new,spec-transition,spec-close,run-gates}.sh
approval-log.sh:22:    ID="${1:-}"; shift || true
approval-log.sh:24:    while [ $# -gt 0 ]; do case "$1" in
spec-new.sh:21:        ID="${1:-}"; shift || true
spec-transition.sh:30:  ID="${1:-}"; TARGET="${2:-}"; REASON=""
spec-close.sh:27:      ID="${1:-}"; shift || true
run-gates.sh:42:      while [ $# -gt 0 ]; do          (e :50, ID="${pos[0]:-}")
```

Nesses cinco não há dispatcher de subcomando: o primeiro token é **change-id**, consumido antes de qualquer `case`, e é por isso que a saída de §2.1 é `FAIL (no active change: --help)` e `FAIL (change-id must be kebab-case: --help)`. A propriedade de `[9]` é comportamental e continua implementável nos catorze; o que a especificação precisa dizer, e agora diz, é que **em cinco deles o tratamento tem de vir antes da resolução de change-id e de raiz**, não "como primeiro ramo do dispatcher".

### 2.4 Decisões de desenho — FECHADAS

**D6. `-h` e `--help` no primeiro token imprimem o usage em stdout e saem 0. O caminho sem argumento e o de comando desconhecido saem `rc≠0` e **nomeiam o token recusado**, **no canal em que cada script já os imprime hoje** — a onda não realoca canal de erro. O idioma é o que já existe no repositório, e as DUAS isenções nominais estão medidas e coladas abaixo.**

```
$ sed -n '41p' template/.forge/scripts/node-baseline.sh
    -h|--help) sed -n '1,26p' "${BASH_SOURCE[0]}"; exit 0 ;;
$ bash .forge/scripts/node-baseline.sh --help >/dev/null 2>/dev/null; echo $?
0
$ bash .forge/scripts/node-baseline.sh --help 2>/dev/null | wc -l ; bash .forge/scripts/node-baseline.sh --help 2>&1 1>/dev/null
26
(stderr vazio)
```

A onda não inventa contrato: aplica o que três scripts já publicam e um teste rastreado já assegura (§2.2). A propriedade fixada é **três estados distinguíveis**, que é a invariante 2 aplicada a uma interface de linha de comando: pedir ajuda (`rc 0`, stdout), errar o comando (`rc≠0`, mensagem que **nomeia** o comando recusado) e não passar comando nenhum (`rc≠0`, usage). Hoje os dois primeiros são byte a byte iguais no `liaison-ops` e no `ledger-ops`, e é isso que a issue chama de indistinguibilidade.

**O que D6 deliberadamente NÃO fixa, e por medição.** A revisão 1 escrevia "continuam em stderr" para as duas vias de erro. Medido na revisão 2 sobre os catorze, **nove** imprimem a via de erro em stdout hoje (§2.1). "Continuam" era falso para nove membros, e transformar a frase em prescrição realocaria canal em nove scripts — mudança de superfície observável cujo raio esta onda não mediu, num diff que não é sobre isso. A distinguibilidade dos três estados **não depende do canal**: ela é decidida pelo `rc` e pelo conteúdo, e é assim que `[10]` passa a ser escrito. A heterogeneidade de canal vira item de ledger, com a medição já pronta, e §11 a registra como não-feita.

*Observação de implementação, medida:* o `sed -n '1,26p'` do `node-baseline.sh` imprime também a linha do shebang. A propriedade que o gate afirma é que a saída de `--help` **contém** a linha de usage do script e sai em stdout com `rc 0`; a estética do bloco fica com quem implementa.

**O QUE D6 CUSTA, medido membro a membro na revisão 3 — e é o bloqueador 1 do revisor.** A frase "nomeando o token recusado" descrevia o estado de cinco membros e prescrevia para catorze, e o revisor mostrou o agravante: dois membros não podem satisfazer nem a cláusula de `rc≠0`, e a onda declara em §11 que não vai lá. Medi as duas vias nos catorze, com o `rc` capturado sem pipe e com um token que cada script consiga de fato reconhecer como inválido — `subcmd-xyz` para os nove com dispatcher de subcomando, `NAO_KEBAB_XYZ` para os cinco em que o primeiro token é change-id (§2.3):

```
$ for s in <os 9 com dispatcher>; do out=$(bash .forge/scripts/$s.sh 'subcmd-xyz' 2>&1); rc=$?; …
liaison-ops          rc=1  nomeia=SIM    wave-ops             rc=1  nomeia=nao
ledger-ops           rc=1  nomeia=SIM    deferral-ops         rc=1  nomeia=nao
gate-ordinal         rc=2  nomeia=SIM    red-evidence         rc=1  nomeia=nao
                                          check-red-first      rc=1  nomeia=nao
                                          graph                rc=1  nomeia=nao
                                          spec-advance-module  rc=0  nomeia=nao   ← rc 0
$ for s in <os 5 sem dispatcher>; do out=$(bash .forge/scripts/$s.sh 'NAO_KEBAB_XYZ' 2>&1); rc=$?; …
approval-log         rc=1  nomeia=SIM    spec-transition      rc=2  nomeia=nao
spec-new             rc=2  nomeia=SIM    run-gates            rc=0  nomeia=nao   ← rc 0
spec-close           rc=1  nomeia=SIM
```

Seis dos catorze já nomeiam com essa fixture. **E a fixture importa, porque para um membro o estado de "token inválido" só existe com dois tokens:** o `spec-advance-module.sh` com um token cai no ramo de usage (`MOD` preenchido, `PHASE` vazio); com dois, o ramo que existe nomeia — `spec-advance-module.sh meumodulo fase-xyz` → `SKIP (fase inválida: fase-xyz — use implementing|implemented)`. **Restrição de fixture fixada: o cenário `[10]` exercita, em cada membro, a forma de invocação em que o estado de recusa daquele membro existe** — um token para os que despacham subcomando, um change-id inválido para os cinco de §2.3, e a forma de dois tokens para o `spec-advance-module`. Uma fixture que force a mesma forma nos catorze produz vermelho fabricado, que é o defeito que este bloqueador nomeia.

Com a fixture certa e tirando o `run-gates`, que é isento por inteiro nesta via, o universo de nomeação é de **treze** membros, **sete** já nomeiam e **seis ganham a nomeação nesta onda** — `wave-ops`, `deferral-ops`, `red-evidence`, `check-red-first`, `graph` e `spec-transition` —, e isso é trabalho de mensagem que a tabela de "o que quebra" de §10 não listava e agora lista. **E dois membros são ISENTOS, cada um com a medição e a razão:**

- **`run-gates.sh`, isento da via de token inválido inteira** — `rc` e nomeação. Ele não tem estado de recusa para esse token: trata-o como change-id e sai `rc 0` com `NO-GATES` (`bash .forge/scripts/run-gates.sh comando-invalido-xyz` → `rc=0`, `  (nenhum gate declarado…)`). Fechar isso é corrigir a vacuidade de `run-gates.sh <id-inexistente>`, que é **LDG-0160 e a invariante 18 do plano**, e a Onda K é dona — §11 proíbe esta onda de tocar. A via **sem argumento** dele não é isenta: ela já sai `rc 1` com `FAIL (usage: run-gates.sh …)`, medido, e continua asserida. E a distinguibilidade de `--help` continua asserida, porque é ela que carrega o achado de D7.
- **`spec-advance-module.sh`, isento da cláusula de `rc≠0` nas duas vias de erro** — e **apenas** dela. O cabeçalho do próprio script, linha 18, declara o contrato: *"Saída: 'OK …', 'NOOP (…)' ou 'SKIP (…)'; sempre exit 0 (não derruba a onda)"*, e o consumidor documentado é o `/forge:coding-loop`, para quem um vínculo best-effort que derruba a onda é pior do que um que não avança. Mudar esse `rc` é mudar o contrato de outro comando, e esta onda não o mediu. A cláusula de **nomeação** continua valendo e ele já a cumpre na via que existe: `spec-advance-module.sh meumodulo fase-xyz` → `rc 0`, `SKIP (fase inválida: fase-xyz — use implementing|implemented)`. A distinguibilidade de `--help` também continua valendo.

As duas isenções são **declaradas na spec, não deixadas para o implementador estreitar o universo por conta própria** — que é exatamente o que o revisor apontou como a segunda saída ruim. E as duas são registradas em §11 como trabalho que a onda mediu e não fez.

**D7. O `run-gates.sh` é o caso que a onda trata com prioridade dentro de #136, porque nele o defeito é falso-verde e não descoberta — e a propriedade foi REESCRITA na revisão 2, porque a da revisão 1 era insatisfazível.**

A revisão 1 escrevia: *"`run-gates.sh --help` não pode terminar com o mesmo `rc` de uma execução bem-sucedida"*. O revisor mostrou que isso contradiz o cenário `[9]`, que exige `rc 0` de todo membro do universo, e eu remedi os dois lados antes de aceitar:

```
$ sed -n '109,110p' template/.forge/scripts/run-gates.sh
if [ "$fail" -ne 0 ]; then echo "FAIL"; exit 1; fi
echo "OK"                                    ← execução bem-sucedida termina sem exit explícito: rc 0
$ sed -n '82,83p' template/.forge/scripts/run-gates.sh
  echo "NO-GATES"
  exit 0                                      ← e o caminho NO-GATES também sai 0
```

Execução bem-sucedida = `rc 0`; com D6, `--help` = `rc 0`. As duas asserções exigiam `0` e `≠0` da mesma invocação, e nenhuma implementação correta passaria nas duas. **O revisor está certo e a propriedade sai.**

O defeito real de `run-gates` nunca foi o `rc` — é que **pedir ajuda ao executor de gates devolve um veredito de wave**, e o `rc` sozinho não discrimina isso nem discriminaria depois de qualquer correção, porque `0` é o valor legítimo dos dois lados. O que discrimina é a **última linha**, que é o que o idioma documentado no cabeçalho do próprio script (`:6-7`, `:23-24`) consome via `| tail -1` e carimba no `waves.json` por `wave-ops.sh close --gate`. Medido em §2.1: hoje `--help` e `<id-inexistente>` produzem saídas **byte a byte idênticas** cuja última linha é `NO-GATES`.

A propriedade específica passa a ser, e ela é satisfazível junto com `[9]`: *a saída de `run-gates.sh --help` difere da saída de `run-gates.sh <change-id>`, e a última linha da saída de `--help` NÃO é um dos tokens de veredito (`OK`, `FAIL`, `NO-GATES`) que o chamador documentado consome*. É verificável sem literal de `rc`, morde a indistinguibilidade que a issue nomeia, e continua mordendo se alguém "consertar" o `--help` de um jeito que ainda entregue veredito.

*Alternativa descartada — corrigir também a vacuidade de `run-gates.sh <id-inexistente>` saindo `rc 0`.* Isso é LDG-0160 e a invariante 18 do plano, e a Onda K é dona dele porque o conserto é o executor de fase que ela cria. Esta onda mede o desfecho, o registra aqui e não o toca.

**D8. `help` como palavra nua NÃO é aceito.**

Medido: hoje `liaison-ops.sh help` e `ledger-ops.sh help` respondem `FAIL: comando desconhecido 'help'`, `rc 1`. A issue não pede a forma nua, e aceitar `help` cria um subcomando reservado que colide com qualquer script que venha a ter um `help` legítimo. Fica registrado como medido e fora de escopo.

**D9. A varredura da invariante 15 sobre as strings que a onda toca deu resultado nulo, e a razão de ela ter dado nulo é uma restrição de implementação, não sorte.**

```
$ grep -rn 'Usage: liaison-ops\|Usage: ledger-ops\|Usage: wave-ops\|Usage: deferral-ops\|usage: red-evidence' tests/
(vazio)
$ grep -rn 'comando desconhecido' tests/*.sh
tests/w206-strix-pentest-gate.sh:351:  *"subcomando desconhecido"*) ...   (é sobre pentest-ops, não sobre os quatro)
```

Nenhum gate rastreado afirma o texto do usage dos cinco scripts — e as duas varreduras acima foram **refeitas com `-a`** na revisão 2, com o controle positivo do preâmbulo provando que elas leem o universo. **Mas um gate depende da forma do cabeçalho deles**, e essa dependência é o risco real. Os endereços, reconferidos na revisão 2 porque a revisão 1 citava só `:204` e o revisor pediu precisão:

```
$ grep -an 'LABELS="$(grep\|n_labels="$(printf\|-ge 20\|return 99' tests/w150-liaison-flag-and-trust-gate.sh
204:LABELS="$(grep -E '^#   liaison-ops\.sh ' "$OPS" | sed …          ← a derivação começa aqui e vai até :209
209:n_labels="$(printf '%s\n' "$LABELS" | grep -c .)"
243:    *) return 99 ;;                                                ← rótulo derivado sem invocação na tabela
248:[ "${n_labels:-0}" -ge 20 ]                                       ← o piso, literal, no fonte do gate
```

`w150:204-209` deriva o universo de subcomandos de `liaison-ops.sh` das linhas de comentário `#   liaison-ops.sh <sub> ...` do próprio script; o piso `-ge 20` está em `:248` e a recusa `rc 99` em `:243`. **Restrição fixada: a implementação de `--help` não altera essas linhas de cabeçalho.** Um `--help` que reescrevesse o bloco de uso do `liaison-ops.sh` derrubaria `w150[4]` por baixo, sem tocar em nenhuma string que a varredura por texto encontraria. Isso entra na definição de pronto.

**E a folga é ZERO, medido — a revisão 1 não disse isso e devia.** Rodando a derivação do gate contra o `liaison-ops.sh` de hoje:

```
$ grep -E '^#   liaison-ops\.sh ' template/.forge/scripts/liaison-ops.sh | sed 's/^#   liaison-ops\.sh //' \
  | awk '{lbl=$1; if (NF>1 && $2 ~ /^[a-z][a-z-]*$/) lbl=lbl" "$2; print lbl}' | LC_ALL=C sort -u | grep -c .
20
```

`n_labels` é exatamente **20** contra um piso de **20**. Qualquer rótulo que o cabeçalho perca derruba `w150[4]` na hora, e qualquer rótulo que ele **ganhe** — por exemplo uma linha `#   liaison-ops.sh --help` documentando a novidade — nasce sem invocação na tabela do gate e devolve `rc 99` por `:243`. As duas direções são vermelhas: a restrição não é "não encolha o bloco", é **não mexa no bloco**.

**E o revisor da revisão 2 pegou que o texto dizia "o cenário `[12]` vigia as duas pontas" enquanto a asserção de `[12]` era só a de baixo. Ele está certo, e a ponta de cima agora é asserção, com contrafactual medido por mutação em bancada.** O primitivo que discrimina a ponta de cima é barato: um rótulo criado por linha de cabeçalho com `--help` começa por hífen, e nenhum dos vinte rótulos de hoje começa. Executado na revisão 3, por substituição integral do arquivo a partir de cópia em `$TMPDIR`, com digest antes/mutado/depois, `cmp` e recontrole:

```
sha_antes   = 5c35bf1f5fbd870f…        n_labels=20   rotulos_com_hifen=0
              ↓ mutação: awk acrescenta a linha `#   liaison-ops.sh --help` ao bloco
sha_mutado  = c443bdb92a89b361…        n_labels=21   rotulos_com_hifen=1   → "--help"
              (asserção de controle da própria mutação: sha_mutado != sha_antes  → SIM)
              ↓ restauro por cp da cópia íntegra
sha_depois  = 5c35bf1f5fbd870f…        igual_ao_antes=SIM   cmp -s → idêntico
RECONTROLE                             n_labels=20   rotulos_com_hifen=0
```

A ponta de baixo (`n_labels ≥ 20`) e a ponta de cima (`nenhum rótulo começa por -`) são quantidades **diferentes** derivadas do **mesmo** bloco, e a mutação move as duas ao mesmo tempo — o que prova que uma asserção só sobre a primeira deixa a segunda sem quem a vigie. **E o endereço do piso, que a revisão 2 errava dentro da célula de `[12]`: o literal `-ge 20` está em `w150:248`, não em `:204`; `:204-209` é a derivação.** A D9 já acertava o endereço; a célula de `[12]`, não.

---

## 3. ITEM 3 — issue #128, `run-manifest.sh`

### 3.1 O defeito, reproduzido, com controle

O mecanismo está em duas linhas, e as duas são do template de hoje:

```
$ sed -n '6p' template/.forge/scripts/run-manifest.sh
node "$SCRIPT_DIR/lib/run-manifest.mjs" "$@" --root "$ROOT"

$ sed -n '17,27p' template/.forge/scripts/lib/run-manifest.mjs
    if (a === '--command') out.commands.push(args[++i] || '');
    else if (a === '--set') out.set.push(args[++i] || '');
    else if (a.startsWith('--')) out[a.slice(2).replace(/-/g, '_')] = args[++i] || '';
    else usage();
```

A issue reproduziu com `node -e` sobre uma cópia do `parseArgs`, que é a forma que a invariante 19 desaconselha. Reproduzi pelo caminho real, com duas árvores git distintas e um controle. **A bancada inteira foi remontada e reexecutada na revisão 2**, e os SHAs abaixo são os desta rodada — a revisão 1 publicava `fd79994`/`e67ffa8`, que eram da bancada anterior e que o revisor, com razão, não conseguiu reproduzir. Os literais são **testemunhas de bancada** e não entram em asserção nenhuma: o que o gate compara é a igualdade entre o `head_sha` gravado e o SHA da árvore nomeada por `--root`, derivados os dois na execução.

```bash
$ W="${TMPDIR:-/tmp}/l4-rev2"; mkdir -p "$W/repo" "$W/outra"
$ (cd "$W/repo"  && git init -q -b develop . && git commit -q --allow-empty -m base-repo)
$ (cd "$W/outra" && git init -q -b develop . && git commit -q --allow-empty -m base-outra)
$ cp -R <template>/.forge/scripts "$W/repo/.forge/scripts"; cd "$W/repo"
$ git -C "$W/repo" rev-parse HEAD   → af74fd541a396c8f8feeb729f51fe6660a32cf24     (o WRAPPER)
$ git -C "$W/outra" rev-parse HEAD  → a441c2ba9e73f5ea67d2c7d4baa27f392f6f8799     (o CHAMADOR)

$ bash .forge/scripts/run-manifest.sh write --root "$W/outra" --stage l4-rev2 --status passed
OK run-manifest .forge/runs/20260908123030-720c036d/run-manifest.json      rc=0
   gravado em: repo/.forge/runs/…                                          ← a raiz do WRAPPER
   "head_sha": "af74fd541a396c8f8feeb729f51fe6660a32cf24"                  ← a árvore do WRAPPER

# CONTROLE — o mesmo --root, invocando o .mjs diretamente:
$ node .forge/scripts/lib/run-manifest.mjs write --root "$W/outra" --stage l4-rev2 --status passed
OK run-manifest .forge/runs/20260908123030-e2810ba8/run-manifest.json      rc=0
   gravado em: outra/.forge/runs/…                                         ← a raiz do CHAMADOR
   "head_sha": "a441c2ba9e73f5ea67d2c7d4baa27f392f6f8799"                  ← a árvore do CHAMADOR
```

A mesma pergunta, duas respostas, e a errada vem do wrapper com a palavra `OK`. O manifesto foi gravado sob a raiz do wrapper e carimbou o SHA do wrapper — a evidência afirma ter medido uma árvore que não mediu.

**Reproduzido de novo na revisão 3, em bancada montada do zero**, porque o revisor da revisão 2 registrou com razão que SHAs de bancada não são reproduzíveis por natureza e o que precisa reproduzir é o **fenômeno**: wrapper em `709d0ac`, chamador em `4c2d599`; `run-manifest.sh write --root <outra> …` gravou sob a raiz do wrapper (`gravado sob repo? SIM | sob outra? nao`) carimbando `"head_sha": "709d0ac0…"`, e o `.mjs` direto com o **mesmo** `--root` gravou sob a outra árvore (`sob outra? SIM`) carimbando `"head_sha": "4c2d599d…"`. Três bancadas independentes, três pares de SHA diferentes, o mesmo desfecho.

### 3.2 A classe é maior que `--root`, e duas portas vizinhas estão abertas

```
# chave repetida que não é --root:
$ node .forge/scripts/lib/run-manifest.mjs write --root "$W/repo" --stage PRIMEIRO --stage SEGUNDO --status passed
OK run-manifest .forge/runs/…/run-manifest.json     rc=0
  "stage": "SEGUNDO",                                        ← última ocorrência vence, em silêncio

# --root ausente:
$ node .forge/scripts/lib/run-manifest.mjs write --stage semroot --status passed
OK run-manifest .forge/runs/…/run-manifest.json     rc=0     ← grava relativo ao cwd

# --root como último token, sem valor:
$ node .forge/scripts/lib/run-manifest.mjs write --root
OK run-manifest .forge/runs/…/run-manifest.json     rc=0     ← root = '' e grava assim mesmo
```

O `usage()` do próprio arquivo declara `--root <repo>` como obrigatório e o parser não o exige; `args[++i] || ''` transforma a ausência de valor em string vazia, que `resolve('')` leva para o `cwd`. As três portas produzem o mesmo dano da issue por caminhos diferentes: um manifesto que afirma proveniência que ninguém verificou.

### 3.3 A exaustividade da enumeração, procurada ativamente

Um "recusa chave repetida" ingênuo quebra o caminho legítimo, porque **duas chaves são acumuladores por desenho**:

```
$ grep -n "out.commands.push\|out.set.push" template/.forge/scripts/lib/run-manifest.mjs
17:    if (a === '--command') out.commands.push(args[++i] || '');
18:    else if (a === '--set') out.set.push(args[++i] || '');
```

Medido: passando `--command` duas vezes, as duas entram. E há um segundo caso não coberto por uma varredura ingênua de `"$@"` do lado do shell: um `--root` que apareça como **valor** de outra flag (`--stage --root`) faria uma detecção posicionalmente cega concluir que o chamador passou raiz, o wrapper deixaria de anexar a dele, e o manifesto sairia com raiz vazia — trocando um defeito por outro da mesma família.

Os desfechos que a onda cobre, procurando o caso que falta:

1. chamador passa `--root <caminho>` → o manifesto carimba **essa** árvore.
2. chamador não passa `--root` → o wrapper anexa a dele; comportamento de hoje preservado (é o de todos os chamadores de produção).
3. chamador passa `--root` duas vezes → recusa.
4. chamador passa qualquer outra chave duas vezes → recusa, **exceto** `--command` e `--set`.
5. `--root` presente sem valor (último token) → recusa.
6. `--root` ausente por completo na invocação direta do `.mjs` → recusa.
7. `--root` aparecendo como **valor** de outra flag → o token não conta como flag do chamador; o wrapper anexa a raiz dele e o desfecho (4) ou (5) captura a inconsistência restante.
8. o subcomando ausente ou um posicional solto → já recusa hoje com `rc 2` (`usage()`), e não muda.

### 3.4 Decisões de desenho — FECHADAS

**D10. O wrapper anexa `--root "$ROOT"` apenas quando o chamador não passou nenhum, e a detecção é POSICIONAL.**

*Alternativa descartada — o wrapper recusa quando o chamador passa `--root` (opção 1 da issue).* A própria issue dá o argumento e ele é medido: gravar evidência de uma árvore que não é a raiz é caso legítimo — clone efêmero de matriz, worktree, sandbox —, e o consumidor **já teve** de contornar o wrapper chamando o `.mjs` direto (`adp#LDG-0574`). Recusar ratificaria o contorno: um wrapper cuja saída documentada é não usá-lo. A comparação com o `full-suite-manifest.sh`, que ignora o `--path` do chamador de propósito, não se transfere — lá quem verifica não deve escolher o que verifica; aqui quem **escreve** tem caso legítimo de escrever sobre outra árvore.

**D11. `parseArgs` recusa chave repetida com `rc 2`, e a lista de acumuladores é DERIVADA do código, não escrita no gate.**

`rc 2` porque é o que o `usage()` do próprio arquivo já usa para uso incorreto. A lista de exceções (`--command`, `--set`) é derivada dos ramos que fazem `push`; um acumulador novo acrescentado ao parser entra sozinho, e um acumulador que deixe de ser acumulador faz o gate reprovar. Escrever `['command','set']` no gate seria a enumeração que envelhece na primeira flag nova.

*Alternativa descartada — "última vence, mas avisa em stderr".* Manifesto é evidência. A frase da issue é a razão: *"evidência errada é pior que evidência ausente porque passa por verificada"*. Um aviso em stderr, num escritor cujos chamadores de produção redirecionam a saída conforme a conveniência de cada um, é a mesma perda com um registro que ninguém lê.

**D12. `--root` sem valor ou ausente recusa com `rc 2` em vez de resolver para o `cwd`.**

É a mesma classe da issue por um terceiro caminho: uma raiz que o parser inventou é uma proveniência que ninguém declarou. O `usage()` já promete `--root <repo>` como obrigatório; a onda faz o código cumprir a promessa.

**D13. A retrocompatibilidade foi medida antes da decisão, e ela é nula do lado do produtor.**

A revisão 1 mediu contra dois gates (`w90` e `w91`) e o revisor mostrou que a classe é maior. A varredura da revisão 2 deriva o universo em vez de o nomear, e usa `-a`:

```
$ grep -arln 'run-manifest.sh' template/.forge/scripts/*.sh
template/.forge/scripts/archive-spec.sh   eval-aggregate.sh   meta-aggregate.sh   spec-verify.sh
$ grep -arn -A12 'run-manifest.sh" write\|run-manifest.sh write' template/.forge/scripts/*.sh | grep -ac -- '--root'
0
$ grep -arln 'run-manifest' tests/*.sh
tests/w32-archive-gate.sh  tests/w80-suite-gate.sh  tests/w90-run-manifest-gate.sh
tests/w91-stage-contract-gate.sh  tests/w92-benchmark-registry-gate.sh
$ for g in w32-archive w80-suite w90-run-manifest w91-stage-contract w92-benchmark-registry; do
    f=$(ls tests/$g*.sh); printf '%-34s --root=%s\n' "$(basename $f)" "$(grep -ac -- '--root' "$f")"; done
w32-archive-gate.sh                --root=0
w80-suite-gate.sh                  --root=0
w90-run-manifest-gate.sh           --root=0
w91-stage-contract-gate.sh         --root=0
w92-benchmark-registry-gate.sh     --root=0
$ grep -ac -- '--command' tests/w90-run-manifest-gate.sh
1
```

São **cinco** gates que tocam `run-manifest`, não dois: `w32` e `w92` apenas localizam e validam manifestos já gravados pelo `spec-verify`, e `w80` cita o nome numa tabela. **Nenhum dos cinco passa `--root`.** Os quatro chamadores de produção passam `--stage`/`--change`/`--dir`/`--status`/`--inputs`/`--outputs`/`--command`/`--runner`/`--profile`/`--budget-class`, cada um **uma vez**, e nenhum passa `--root`; os que exercitam o wrapper usam `FORGE_ROOT` para posicionar a raiz. Nenhum chamador repete chave. **Nenhuma das três decisões quebra um chamador existente**, e o consumidor que hoje contorna passa a poder usar o wrapper.

---

## 4. ITEM 4 — issue #129, `validate-naming-conventions.sh`

### 4.1 O defeito, reproduzido — mesmo arquivo, duas respostas, com bash 3.2

```
$ /bin/bash --version | head -1
GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)

$ G=.forge/hooks/pre-tool-use/validate-naming-conventions.sh
rc=1   src/Axis.Transaction.Infrastructure/Communications/BanklyCommunication.cs      [HOOK] - Diretório 'Communications' não está em kebab-case
rc=0   /Users/x/repo/src/Axis.Transaction.Infrastructure/Communications/BanklyCommunication.cs
rc=1   tests/Axis.Transaction.Tests.Unit/Adapters/A.cs                                [HOOK] - Diretório 'Adapters' não está em kebab-case
rc=0   services/token-vault/src/TokenVault.Api/Endpoints/A.cs
rc=1   deploy/Helm/values.cs                                                          [HOOK] - Diretório 'Helm' não está em kebab-case
rc=0   ./src/Axis.X/Communications/A.cs
rc=1   mysrc/Communications/A.cs
rc=1   srcx/Communications/A.cs
rc=0   src/Foo/Bar.csproj
```

A linha é `template/.forge/hooks/pre-tool-use/validate-naming-conventions.sh:51`, e o padrão é `/(src|tests|services|deploy)(/|$)`, com a barra **antes** do segmento.

**O desfecho que a issue não mediu e que endurece o diagnóstico é o sexto da lista: `./src/Axis.X/Communications/A.cs` aprova, enquanto `src/Axis.X/Communications/A.cs` reprova.** As duas formas são relativas, descrevem o mesmo arquivo, e o veredito muda pelo `./`. Não é "relativo contra absoluto": é **qualquer coisa que ponha uma barra à esquerda do segmento**, e isso torna o predicado ainda menos defensável do que a issue afirma.

`deploy/Helm/values.cs` é o outro desfecho novo: a raiz `deploy/` está no conjunto de isenção e reprova pela mesma razão que `src/` e `tests/`.

### 4.2 A enumeração, procurando o caso não coberto

```
rc=0   DIR=src              [src/A.cs]                 ← BASENAME 'src' é minúsculo; a regra 2 não dispara de todo modo
rc=0   DIR=.                [A.cs]                     ← o `case` de diretórios estruturais sai 0 antes
rc=0   DIR=../src/Foo       [../src/Foo/A.cs]          ← tem '/src/' no meio
rc=1   DIR=SRC/Foo          [SRC/Foo/A.cs]             ← 'SRC' não é membro do conjunto; continua reprovando
rc=0   (sem argumento)                                 ← `[[ -z "$FILE" ]] && exit 0`
rc=0   (argumento vazio)                               ← idem
```

O caso que faltava a esta enumeração e que decide o desenho do gate é outro, e é positivo: **o gancho tem duas regras, e a regra 1 é verdadeira mesmo nos caminhos que a regra 2 reprova por engano.**

```
$ printf 'public class SqlUserRepository {}\n' > src/Foo/SqlUserRepository.cs
$ /bin/bash "$G" "src/Foo/SqlUserRepository.cs"; echo "rc=$?"
[HOOK] VIOLAÇÃO DE CONVENÇÕES DE NOMENCLATURA em: src/Foo/SqlUserRepository.cs
[HOOK]   - Prefixo de tecnologia em tipo: 'class SqlUserRepository'
[HOOK]   - Diretório 'Foo' não está em kebab-case
rc=1
```

Um gate que apenas exigisse `rc 0` para caminhos sob `src/` depois da correção seria satisfeito por uma implementação que **desligasse o gancho inteiro**. O controle que discrimina está em §4.4.

### 4.3 O canal — e ele não existe no produtor

```
$ grep -rn 'validate-naming' template/.forge/scripts/lib/sync-adapters.mjs
(vazio)
$ sed -n '233p' template/.forge/scripts/lib/sync-adapters.mjs
    const hooks = { PreToolUse: [{ matcher: 'Bash', hooks: [{ type: 'command', command: '$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh' }] }] };
$ grep -n 'naming\|pre-tool-use' template/.forge/hooks/git/pre-commit
(vazio)
$ grep -rln 'validate-naming' tests/
tests/snapshot/claude-contract.bats
```

O produtor **instala** o gancho e **não o arma**: `sync-adapters.mjs` declara um único `PreToolUse`, o do `enforce-worktree-location.sh`; o `pre-commit` do template não o chama; e o único teste que o menciona é o contrato de instalação em `bats`, que afirma que o arquivo existe, não o que ele decide — e as suítes `bats` são puladas quando o binário não está no PATH (`tests/run-all.sh:93-95`).

**Consequência para a régua da onda: o defeito reproduz no template, o canal não.** O consumidor armou o gancho por conta própria, a partir de um `pre-commit.d/04-language-and-naming.sh` que o template não distribui, alimentado por `git diff --cached --name-only` — que é o que entrega caminho relativo. E o próprio `pre-commit` do template já usa essa forma de entrada (`template/.forge/hooks/git/pre-commit:19`, `staged="$(git diff --cached --name-only --diff-filter=ACM)"`), então a forma relativa é o idioma da casa; o que falta é a ligação.

### 4.4 Decisões de desenho — FECHADAS

**D14. A âncora passa a ser nas duas pontas.**

A correção que a issue sugere é a certa, e medi-a com controle e recontrole, aplicada por substituição integral do arquivo a partir de cópia preparada em `$TMPDIR`:

```
sha_antes  = <do arquivo íntegro>
sha_com_fix ≠ sha_antes                      ← controle: a substituição não é no-op
```

Com `(^|/)(src|tests|services|deploy)(/|$)`:

```
rc=0   src/Axis.T/Communications/A.cs
rc=0   tests/Axis.T/Adapters/A.cs
rc=0   deploy/Helm/v.cs
rc=0   /Users/x/repo/src/Axis.T/Communications/A.cs
rc=0   services/tv/src/TV.Api/Endpoints/A.cs
rc=0   ./src/Axis.X/Communications/A.cs
rc=1   mysrc/Communications/A.cs
rc=1   srcx/Communications/A.cs
```

Restaurado por `cp` da cópia íntegra, `sha_depois = sha_antes`, e o recontrole devolve `rc=1` para `src/Axis.T/Communications/A.cs`. As duas metades importam: a isenção passa a alcançar a forma relativa **e** continua não alcançando nomes que apenas contêm o segmento.

**D15. O controle que separa "corrigi a âncora" de "desliguei o gancho" é asserção do gate, não observação.**

Medido depois da correção, sobre o mesmo arquivo com prefixo de tecnologia real:

```
$ /bin/bash "$G" "src/Foo/SqlUserRepository.cs"; echo "rc=$?"
[HOOK] VIOLAÇÃO DE CONVENÇÕES DE NOMENCLATURA em: src/Foo/SqlUserRepository.cs
[HOOK]   - Prefixo de tecnologia em tipo: 'class SqlUserRepository'
[HOOK] Consulte: .forge/rules/conventions/naming.md (a definir)
rc=1
```

`rc 1` preservado, a linha da regra 1 preservada e a linha da regra 2 desaparecida. É a asserção mais forte desta metade: ela reprova tanto a regressão da âncora quanto o desarme do gancho.

**D16. O gate exercita o canal REAL, montando a fiação que o consumidor documentou — e não arma o gancho no produtor.**

A rule `testing/gate-delivery-channel.md` exige prova pelo caminho pelo qual o gate roda em produção, com sinal positivo de execução. A fixture do cenário de canal monta um repositório com `core.hooksPath` apontando para um `pre-commit` que alimenta o gancho com o que `git diff --cached --name-only` entrega, estagia um `.cs` sob `src/` com diretório PascalCase, e faz um `git commit` de verdade: bloqueado antes da correção, aprovado depois, com um marcador que só o gancho certo emite para distinguir "aprovou" de "não rodou".

*Alternativa descartada — armar o gancho no `pre-commit` do template.* Isso ligaria, em toda árvore que atualizar, um gancho que hoje não roda. O canal de liaison traz a medição de um consumidor sobre a própria árvore dele, e a revisão 2 troca o número solto pelo **endereço citável**, que é o que um revisor pode conferir sem ter a árvore do consumidor:

```
$ grep -arn '13.443' .forge/liaison/forge-harness/blobs/*.md
…76d4bb35…-corpo-censo.md:25:| `validate-naming-conventions.sh` | r1 `.cs` 7 039 · r2 todos 13 452 | 13 443 |
                                **163** com path absoluto · **741** com path relativo |
$ grep -ah '76d4bb35…' .forge/liaison/forge-harness/log/*.jsonl | head -1
  msg_id=axis-go-cloud-0044  sender=axis-go-cloud  thread=upgrade-desarma-o-proprio-ponto-de-entrada
```

**Isto é medição de terceiro e eu NÃO a reproduzi** — a árvore é do consumidor e o mandato desta rodada é leitura apenas nela. O que eu reproduzi é a **proveniência**: a mensagem existe, o remetente é o `axis-go-cloud`, a thread é nomeável e o número está no corpo, no endereço acima. É justamente por ser de terceiro que ele não vira decisão desta onda: armar o gancho é decisão de produto que precisa de curadoria da regra 2 antes, e vai para o ledger. Corrigir a âncora, ao contrário, só **reduz** reprovação e não arma nada — e essa metade eu medi por conta própria, em §4.4, com controle e recontrole.

---

## 5. A reconciliação com a Onda E — o que muda, em letra

O plano-mestre registra esta como a única interação entre lotes. Li `docs/plans/spikes/backlog-onda-e-ordinal-e-escrita.md` inteira. **A Onda E não precisa ser refeita, e nenhuma decisão dela é revogada por #133.** O que ela precisa é de três correções e de uma coordenação, e as quatro estão medidas aqui.

### 5.1 Correção 1 — a decisão 11 da Onda E, aplicada literalmente, deixa `tests/w51-waves-progress-gate.sh` VERMELHO

A decisão 11 diz: *"as quatro portas ganham o laço de recusa, e `test`/`status`/`render` declaram conjunto de flags vazio com um literal legível"*. E a §10 da Onda E declara, na lista do que não quebra: *"`w51[…]`: chama `deferral-ops.sh test` e `status` **sem** argumento extra, medido nas linhas 112-113"*.

A segunda afirmação está certa quanto ao fato e errada quanto à conclusão, e a razão é uma linha que a Onda E não podia ter visto porque ela não é sobre parsing:

```
$ grep -n 'deferral_id=' template/.forge/scripts/deferral-ops.sh
89:  deferral_id="${1:-}"; shift || true
115:  deferral_id="${1:-}"; [ -n "$deferral_id" ] || { echo "FAIL: deferral-id obrigatório" >&2; exit 1; }
```

O `resolve` (linha 89) faz `shift` do posicional; o `test` (linha 115) **não faz**. Com o posicional ainda em `$1`, qualquer forma de laço de recusa recusa o próprio `<deferral-id>`. É exatamente o que #133 adverte — *"a `v0.14.0` apagou … junto, o `shift || true` do `test`"* — e reproduzi as duas formas em bancada, sobre cópias em `$TMPDIR`, com controle de sha e recontrole:

As duas variantes foram **reexecutadas na revisão 2**, porque o revisor registrou que não as tinha reproduzido. O protocolo é o de §8.3: cópia íntegra, digest antes, mutação por **geração de arquivo novo** com `awk` e `cp` por cima (nunca edição in-place com interpolação — LDG-0164), digest da mutação, execução, restauro por `cp` e recontrole.

```bash
$ D=".forge/scripts/deferral-ops.sh"; cp "$D" "$W/deferral-ops.ORIG"
$ sha_antes=$(shasum -a 256 "$D" | awk '{print $1}')
# (a) laço de recusa em test), SEM restaurar o shift — arquivo novo gerado por awk sobre a linha 115.
# A linha 115 é reemitida como está e o laço é acrescentado logo abaixo dela; o corpo exato do
# `print` está elidido aqui só para caber na página, e o que importa é a forma: arquivo NOVO,
# nunca edição in-place com interpolação.
$ awk 'NR==115 { print <a linha 115 original>; print <o laço de recusa>; next } { print }' \
    "$W/deferral-ops.ORIG" > "$W/semshift.sh" && cp "$W/semshift.sh" "$D"
$ [ "$(shasum -a 256 "$D" | awk '{print $1}')" != "$sha_antes" ] && echo "CONTROLE: sha mudou"
CONTROLE: sha mudou                                      ← a mutação não é no-op
$ bash "$D" test l4-demo DEFER-01                         # exatamente o que w51:112 faz
FAIL: argumento inesperado 'DEFER-01' para o subcomando 'test'
  flags aceitas em 'test': (nenhuma)
rc=1

# (b) laço de recusa COM o shift restaurado — a linha 115 reemitida com `; shift || true` no fim
$ awk 'NR==115 { print <a linha 115 + shift || true>; print <o laço de recusa>; next } { print }' \
    "$W/deferral-ops.ORIG" > "$W/comshift.sh" && cp "$W/comshift.sh" "$D"
$ bash "$D" test l4-demo DEFER-01          → OK test — DEFER-01 marcado como tested            rc=0
$ bash "$D" test l4-demo DEFER-01 --lixo x → FAIL: flag desconhecida '--lixo' para o subcomando 'test'   rc=1

# RESTAURO E RECONTROLE
$ cp "$W/deferral-ops.ORIG" "$D"
$ [ "$(shasum -a 256 "$D" | awk '{print $1}')" = "$sha_antes" ] && echo "sha_depois == sha_antes"
sha_depois == sha_antes
$ cmp -s "$W/deferral-ops.ORIG" "$D" && echo "cmp byte a byte OK"
cmp byte a byte OK
$ bash "$D" test l4-demo DEFER-01          → OK test — DEFER-01 marcado como tested            rc=0
```

O laço acrescentado nas duas variantes é `TEST_FLAGS="(nenhuma)"; while [ $# -gt 0 ]; do forge_reject_unknown test "$TEST_FLAGS" "$1"; done`, e o literal `(nenhuma)` é o da decisão 11 da Onda E. Que ele não trunca a linha com a `lib/arg-guards.sh` **de hoje**, sem mudar um byte da biblioteca, foi verificado por chamada direta à função:

```
$ bash -c '. .forge/scripts/lib/arg-guards.sh; forge_reject_unknown test "(nenhuma)" "--lixo"'
FAIL: flag desconhecida '--lixo' para o subcomando 'test'
  flags aceitas em 'test': (nenhuma)
rc=1
```

O recontrole é o passo que a prova não dispensa: sem ele, um `restore()` quebrado deixaria a mutação eterna e as medições seguintes mediriam a mutação (`feedback-mutacao-fantasma-restore`).

E a linha que morre é literal:

```
$ sed -n '112p' tests/w51-waves-progress-gate.sh
bash "$T/.forge/scripts/deferral-ops.sh" test w51-test DEFER-01 | grep -q "OK test"
```

**O que muda na Onda E, na forma da revisão 2:** os ramos `test)` e `status)` de `deferral-ops.sh` **saem** da decisão 11 e passam a L4 por **D17** (§1.4), justamente porque o `shift` e o laço são indivisíveis e duas ondas não conseguem garantir atomicidade entre dois PRs. A linha da §10 da Onda E que declara `w51` intocado continua precisando de correção, mas por outra razão: ela deixa de ser previsão sobre trabalho da Onda E e passa a ser dependência declarada do trabalho de L4. O `status)` não tem o problema do `shift` — `cmd` e `change_id` já foram consumidos nas linhas 26-27 e `$#` é zero na invocação legítima —, e isso também foi medido.

### 5.2 Correção 2 — `w201[12]` precisa de controle positivo pareado

O cenário novo da Onda E era *"`deferral-ops.sh test` e `status` recusam argumento desconhecido; o `deferrals.json` fica byte a byte idêntico depois da recusa"*. Sem par, ele é satisfeito por uma implementação que recuse **tudo**, inclusive o posicional — que é precisamente o modo de falha `semshift` medido acima, e ele passaria verde enquanto derrubasse `w51` num arquivo que ninguém está olhando naquele momento. **O que muda com D17:** o cenário sai de `w201` junto com a implementação e vira `[7]` do Gate A desta onda, **com o par positivo `[6]` obrigatório na mesma fixture** — `deferral-ops.sh test <change-id> <deferral-id>` com `rc 0` e `OK test`. O par não é zelo: ele é a única asserção que separa "recusei o desconhecido" de "recusei tudo", e a medição das duas variantes acima é o contrafactual dele.

### 5.3 Correção 3 — o censo de portas da Onda E é completo no escopo dela e incompleto na classe

A §5.2 da Onda E enumera **12** subcomandos (8 de `ledger-ops`, 4 de `deferral-ops`) e quatro portas abertas. Dentro do escopo declarado dela isso está correto. A classe, porém, tem uma quinta porta e ela está fora dos dois scripts:

```
$ bash .forge/scripts/wave-ops.sh status 2026-09-07-demo --lixo x ; echo "rc=$?"
no waves.json
rc=0
$ grep -c 'while \[ \$# -gt 0 \]' template/.forge/scripts/wave-ops.sh   → 0
$ grep -c '_reject_unknown' template/.forge/scripts/wave-ops.sh          → 0
```

**O que muda:** nada na Onda E. A porta do `wave-ops.sh` é assumida por **esta** onda (D5), porque L4 já toca os quatro scripts de operação por causa de #136 e porque deixar uma porta medida sem dono é como o ledger cresce. Registro aqui para que o revisor da Onda E não a cobre lá.

### 5.4 Coordenação — o badge do README não pode ser um literal em duas ondas ao mesmo tempo

A Onda E fixa, na definição de pronto dela: *"o badge de gates do `README.md` é atualizado de `131` para `132` no mesmo PR"*. Medido nesta rodada:

```
$ grep -aoE 'gates-[0-9]+' README.md | head -1                    → gates-131
$ ls tests/*-gate.sh | wc -l                                      → 131
$ grep -an 'badge_n=\|arvore_n\|!= "$arvore_n"' tests/w200-readme-inventory-gate.sh | head -3
259:badge_n="$(grep -oE 'gates-[0-9]+' "$WS/README.md" | head -1 | cut -d- -f2)"
267:elif [ "$badge_n" != "$arvore_n" ]; then          ← comparação por IGUALDADE, em :258-271
```

Badge e árvore concordam **hoje**, em 131, e é justamente por concordarem que qualquer gate novo os separa.

A Onda E escreve um gate; esta onda escreve dois; as duas miram `develop`. **Quem entrar primeiro deixa o número da outra errado**, e `w200[6]` compara por igualdade. A saída não é escolher um número: é as duas ondas declararem a **propriedade** — o badge iguala `ls tests/*-gate.sh | wc -l` no momento do PR — e o orquestrador reconciliar o literal ao escrever. **O que muda na Onda E:** a linha "de 131 para 132" vira "para o valor que `ls tests/*-gate.sh | wc -l` devolver no PR, reconferido depois de qualquer rebase sobre `develop`". Esta especificação não escreve número nenhum ali pelo mesmo motivo.

Registro também o que **não** colide: `w200[1]` confere `<dir>/ (N)` do bloco `## 📁 Estrutura` do README contra `find "<root>/<dir>" -type f ! -name 'README.md' | wc -l`, e **esta onda não acrescenta arquivo algum sob `template/.forge/`** — ela edita `liaison-ops.sh`, `deferral-ops.sh`, `wave-ops.sh`, `run-manifest.sh`, `lib/run-manifest.mjs`, `validate-naming-conventions.sh` e os demais scripts do universo de `--help`, todos preexistentes. As linhas `scripts/ (N)`, `commands/ (N)`, `schemas/ (N)` e as outras seguem corretas. **A decisão D1 é o que garante isso**: adotar `lib/argparse.sh` acrescentaria um arquivo sob `template/.forge/scripts/` e obrigaria a rederivar `scripts/ (N)` — mais uma razão medida para não a adotar.

### 5.5 O que da Onda E permanece exatamente como está

A decisão 11 quanto a `ledger-ops.sh render`/`status` e o literal `(nenhuma)` para conjunto vazio: permanece, e a forma já é a instalada — `liaison-ops.sh` usa `(nenhuma)` em sete sítios (`:499`, `:867`, `:1013`, `:1041`, `:1155`, `:1218`, `:1225`). A decisão 12 (`resolve` sobre entrada terminal), a 13 (os dois chamadores de produção), as 15-19 (harvest) e toda a metade A (alocador de ordinal) não têm interseção com L4. A §12 da Onda E — *"não consolida `lib/arg-guards.sh` com a cópia de `liaison-ops.sh::_reject_unknown`"* — permanece verdadeira, e esta onda também não consolida; o cenário `[2]` de §6 é escrito para sobreviver à consolidação quando a onda F a fizer.

**Ordem de implementação entre as duas, reescrita pela D17.** Com os ramos `test)`/`status)` alocados a L4, **as duas ondas deixam de editar o mesmo arquivo**: L4 edita `deferral-ops.sh` e `wave-ops.sh`, a Onda E edita `ledger-ops.sh`. Elas podem ser implementadas e mergeadas em qualquer ordem, em worktrees isoladas, e a coordenação que sobra é uma só e não é de código: **o badge de gates do README**, que as duas ondas deslocam e que `w200[6]` compara por igualdade (§5.4).

A restrição que continua valendo é de convenção, não de arquivo: as duas adotam o literal `(nenhuma)` da decisão 11 para conjunto de flags vazio, e §1.4/D17 mede que isso não exige mudança nenhuma em `lib/arg-guards.sh` — a biblioteca instalada já imprime a linha legível quando o chamador passa o literal.

---

## 6. O VERMELHO, antes do verde

Dois gates novos. Todo cenário abaixo falha hoje **pela ausência real da funcionalidade**, exceto os que a coluna marca como verdes por construção — que existem para contar e para vigiar, e que a §6.3 nomeia para que ninguém procure vermelho onde não há.

**Sobre literais no fonte dos gates, e a revisão 1 escrevia uma regra que se contradizia.** Ela dizia "nenhum número medido nesta especificação aparece como literal no fonte dos gates" e, duas linhas adiante, prescrevia "piso" em `[9]` e `[12]` — e piso é literal por definição. A distinção que vale, e que é a da invariante 14 do plano:

- **Contagem comparada por IGUALDADE é proibida**, salvo a exceção que a própria invariante concede: o denominador de cenários do gate (`SCEN`), que é fixo por construção e cuja divergência é o achado. Esta onda tem exatamente dois desses, e a §6.4 os recontou por comando.
- **Piso contra vacuidade é literal, e é deliberado.** Ele existe para reprovar universo vazio ou raso, e por isso é escolhido com folga — nunca colado no valor de hoje. O modelo instalado é `w150[5]`, que carrega `-ge 12` no fonte contra um `n_loops` real bem maior. Um piso colado no valor corrente é o defeito de `w150[4]`, cujo `-ge 20` está hoje contra `n_labels` exatamente 20 (§2.4/D9): folga zero, e qualquer rótulo perdido derruba na hora.

Nenhuma contagem medida nesta especificação — 31/20/11 sítios, 14 membros, 23 dispatchers, 131 gates, 12 árvores — aparece como igualdade no fonte de gate nenhum. As mensagens dos gates imprimem os contadores que eles mesmos derivaram naquela execução.

### 6.1 Gate A — `w<NNN>-arg-surface-gate.sh` (#133, #136 e a porta do `wave-ops`)

| # | Cenário | Asserção | Vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [1] | `liaison-ops inbox <ch> --thread --show` | recusa; a mensagem nomeia `--thread`, `--show` e `inbox`; nenhuma escrita no diretório do canal | `rc=0`, `(nenhuma thread)` | `liaison-ops.sh:771` consome `"$2"` sem guarda |
| [2] | ESTRUTURAL P2 — derivação sobre o escopo derivado *carrega `lib/arg-guards.sh` **e** tem ao menos um braço que consome `"$2"`*, que hoje devolve `liaison-ops.sh`, `deferral-ops.sh` e `ledger-ops.sh`. `wave-ops.sh` está FORA por não ter sítio de valor, e continua fora depois de ganhar o laço de P1 (ver a nota abaixo da tabela) | todo braço de `case` que consome `"$2"` chama guarda de valor. O gate publica, **por membro**, quantos sítios examinou e quantos guardou, e reprova em três condições **de quantidades diferentes**: `n_membros` do escopo abaixo do piso `3`; `guardados ≠ total` em qualquer membro (igualdade entre dois contadores derivados na execução, no modelo de `w150[5]`); `soma(total)` abaixo do piso folgado `40`. E um laço que não pôde ser analisado é o terceiro estado, `NÃO VERIFICADO`, que reprova em vez de aprovar | 31 sítios, 20 guardados no `liaison-ops.sh` — `20 ≠ 31` reprova; 3/3 e 23/23 nos outros dois | não existe derivação de P2 em gate nenhum; `w150[5]` deriva só P1 |
| [3] | `liaison-ops peer set <ch> <peer> --path --path` | recusa, e `liaison.yaml` fica **byte a byte idêntico** (`cmp` contra snapshot) | `rc=0`, `OK peer set — p → --path`, e `peer-path` devolve `--path` | mesmo defeito de [1], num sítio que **escreve** |
| [4] | os demais nove sítios sem guarda (`:317`, `:318`, `:830`, `:969`, `:985`, `:1188`, `:1189`, `:1190`, `:1191`) | cada um recusa **nomeando a flag-dona e o subcomando** — a asserção é sobre a mensagem, nunca sobre `rc≠0` | **os nove** já saem `rc≠0` pelo motivo errado, medido um a um em §1.2; um deles sai `rc=64` do `mkdir` | a guarda não está nesses sítios |
| [5] | CONTROLE NEGATIVO | `send --body '---frontmatter'` e um valor com hífen legítimo continuam aceitos com `rc 0` | *passa hoje* | verde por construção; separa "fechei P2" de "proibi hífen" |
| [6] | `deferral-ops test <change> <deferral-id>` legítimo | `rc 0` e `OK test` | *passa hoje* | verde por construção; é o par que a §5.2 exige, e o que morre se o `shift` não for restaurado |
| [7] | `deferral-ops test <change> <deferral-id> --lixo` | recusa, e `deferrals.json` byte a byte idêntico | `rc=0`, `OK test`, registro alterado | `test)` não tem laço de parsing |
| [8] | `deferral-ops status <change> --lixo` e `wave-ops status <change> --lixo` | recusam | `rc=0` nos dois | nenhum dos dois tem laço |
| [9] | `--help` e `-h` sobre o universo derivado de §2.2 | para **todo** membro: `rc 0`, a linha de usage em **stdout**, stderr vazio; o gate publica o tamanho do universo e reprova em zero ou abaixo do piso | 14 membros, 0 conformes; rcs 0, 1 e 2 | nenhum dos 14 tem ramo `-h\|--help` |
| [10] | CONTROLE PAREADO de [9] | **três cláusulas, com universos declarados e diferentes.** (a) DISTINGUIBILIDADE, sobre os **catorze**: a saída de `--help` difere da de token inválido e da de sem-argumento (`cmp` sobre a concatenação de stdout e stderr acusa diferença nas duas comparações). (b) NOMEAÇÃO, sobre **treze** — os catorze menos `run-gates`, que não tem estado de recusa para o token (D6): a saída de token inválido contém o token recusado. (c) `rc≠0`, sobre **treze** na via sem-argumento e **doze** na via de token inválido — as isenções são `spec-advance-module` (contrato de `exit 0` no cabeçalho `:18`, nas duas vias) e `run-gates` (LDG-0160, invariante 18, Onda K é dona, só na via de token inválido). O gate publica os três universos e reprova se algum deles cair abaixo do piso. **Sem asserção de canal na via de erro** — nove dos catorze a imprimem em stdout hoje (§2.1) e a onda não realoca canal | as duas saídas do `liaison-ops`/`ledger-ops` são idênticas; e no universo de nomeação de treze, com a fixture apropriada a cada membro, **seis** não nomeiam o token — medidos e listados em D6 | é a indistinguibilidade que a issue nomeia, e as duas isenções são medidas e declaradas aqui em vez de deixadas para o implementador estreitar o universo |
| [11] | `run-gates.sh --help` contra `run-gates.sh <change-id>` | a saída de `--help` **difere** da saída da execução (`cmp` acusa), e a **última linha** da saída de `--help` não é `OK`, `FAIL` nem `NO-GATES` — os três tokens de veredito que o chamador documentado em `run-gates.sh:6-7` consome por `\| tail -1` e carimba via `wave-ops.sh close --gate` | as duas saídas são **byte a byte idênticas**, `rc 0` nas duas, e a última linha de `--help` é `NO-GATES` | falso-verde medido em §2.1; a asserção por `rc` da revisão 1 era insatisfazível contra `[9]` e foi substituída (D7) |
| [12] | RESTRIÇÃO de `w150`, **as duas pontas** | (a) PONTA DE BAIXO: os rótulos derivados das linhas `#   liaison-ops.sh <sub> …` são em número ≥ **20**, que é o piso literal que `w150:248` carrega (a derivação em si é `w150:204-209`). (b) PONTA DE CIMA: **nenhum** rótulo derivado começa por `-` — é a forma pela qual esta onda criaria rótulo sem invocação na tabela de `w150:243` e receberia `rc 99` | *passa hoje nas duas pontas*: `n_labels` = 20, rótulos com hífen = 0 | verde por construção; é a vigilância de D9, e a ponta de cima tem contrafactual medido em §2.4 |
| [13] | PBT sobre P2 | para todo par (subcomando, flag-que-exige-valor) do universo derivado das declarações de flags, invocar com **outra** flag do mesmo subcomando no lugar do valor recusa nomeando as duas; seed fixa, shrinking, e asserção sobre o gerador de que o universo exercido não é vazio | contraexemplo já minimizado: `inbox`, `--thread`, `--show` | a guarda não existe nos 11 sítios |
| [14] | CONTADOR DE CONTROLE | `SCEN` do próprio gate comparado por igualdade, mais `forge_universe_check` com zero para provar que a guarda reprova | — | verde por construção |
| [15] | SENTINELA | `git -C <repo> diff --name-only HEAD -- template/` **e** `git -C <repo> status --porcelain -- template/` idênticos no início e no fim do gate — o segundo comando é o que pega arquivo **não rastreado**, e ele é obrigatório porque este gate PLANTA um controle positivo (§0) que só pode existir na cópia sob `$TMPDIR` | — | verde por construção; o vermelho dela é defeito do gate |
| [16]–[19] | as **quatro** provas de mutação de §8.1 (M1, M2, M3, M4) | — | — | — |

**O denominador de `[2]`, fechado em letra — e por que `wave-ops.sh` está fora.** A revisão 1 mandava derivar P2 sobre **quatro** scripts e reprovar "quando o examinado é zero", sem dizer se o denominador era agregado ou por script. As duas leituras eram defensáveis e as duas quebravam: por script, `wave-ops.sh` reprova a implementação correta por ter zero sítios que nunca existiram; agregado, um dos quatro pode cair a zero sozinho sem ninguém ver, que é justamente o que o piso deveria vigiar. Medido, e é o que fecha a questão:

```
$ for s in liaison-ops deferral-ops ledger-ops wave-ops; do
    printf '%-14s total=%s guardados=%s\n' "$s" \
      "$(grep -acE '\-\-[a-z-]+\)[^;]*"\$\{?2' template/.forge/scripts/$s.sh)" \
      "$(grep -aE '\-\-[a-z-]+\)[^;]*"\$\{?2' template/.forge/scripts/$s.sh | grep -acE 'forge_reject_flag_as_value|forge_require_value|_require_value')"; done
liaison-ops    total=31 guardados=20
deferral-ops   total=3  guardados=3
ledger-ops     total=23 guardados=23
wave-ops       total=0  guardados=0        ← universo vazio HOJE, e legitimamente
```

`wave-ops.sh` tem **zero** sítios que consomem `"$2"`, e D5 já o admitia na onda "apenas para P1". Ele fica **fora do universo de `[2]`**, e a razão é medida, não estética: `forge_universe_check` recebe uma chave por cenário e recusa universo vazio salvo isenção declarada em `.forge/empty-universe-allowlist.txt`, de modo que incluí-lo faria a implementação correta reprovar por ausência de sítios que nunca existiram. Ele continua dentro de `[8]`, que é P1 e onde ele tem porta aberta medida.

**A revisão 2 fechava aqui com "piso sobre o agregado dos três, guarda de vacuidade por script", e o revisor mostrou que a segunda metade nasce morta: se o gate deriva a lista dos scripts que TÊM sítio, um script com zero sítios nunca entra na lista, e a guarda "reprova quando qualquer um examina zero" não pode disparar. Ele está certo, e ao medir para responder achei um defeito maior — o meu próprio predicado de derivação, aplicado como escrito, devolve QUATORZE scripts, não três:**

```
$ for f in template/.forge/scripts/*.sh; do t=$(grep -acE '\-\-[a-z-]+\)[^;]*"\$\{?2' "$f"); [ "$t" -gt 0 ] || continue
    g=$(grep -aE '\-\-[a-z-]+\)[^;]*"\$\{?2' "$f" | grep -acE 'forge_reject_flag_as_value|forge_require_value|_require_value')
    printf '  %-22s total=%-3s guardados=%s\n' "$(basename $f)" "$t" "$g"; done
  approval-log.sh        total=7   guardados=0        heavy-run.sh           total=2   guardados=0
  check-heavy-mutex.sh   total=1   guardados=0        impact.sh              total=1   guardados=0
  deferral-ops.sh        total=3   guardados=3        node-baseline.sh       total=1   guardados=0
  dotnet-baseline.sh     total=1   guardados=0        spec-close.sh          total=3   guardados=0
  ledger-ops.sh          total=23  guardados=23       spec-new.sh            total=6   guardados=0
  liaison-ops.sh         total=31  guardados=20       spec-transition.sh     total=1   guardados=0
                                                      validate-archive.sh    total=1   guardados=0
                                                      worktree-reconcile.sh  total=1   guardados=0
  scripts_com_sitio=14  agregado_total=82  agregado_guardados=46
```

Onze desses catorze têm `guardados=0` e **não são alvo desta onda**. Um gate que derivasse a lista por "tem sítio de valor" reprovaria a implementação correta em onze scripts que a onda não toca — o mesmo modo de falha do bloqueador 4 da revisão 1, entrando pela porta oposta. O predicado de escopo que a spec usava estava escrito por nome (os três), e nome é a enumeração que envelhece.

**O predicado de escopo, derivado e medido.** O que separa os três scripts de operação dos outros onze é que eles **carregam a biblioteca de guardas**, e é uma condição verificável:

```
$ grep -arln 'arg-guards.sh' template/.forge/scripts/*.sh | sed 's#.*/##'
deferral-ops.sh   liaison-ops.sh   ledger-ops.sh          ← exatamente três, e são os três
$ grep -anE '^[a-z_]+\(\)' template/.forge/scripts/lib/arg-guards.sh
28:forge_reject_unknown()   64:forge_reject_flag_as_value()   96:forge_require_value()
```

**E o predicado de escopo é a conjunção de DUAS cláusulas, não uma — porque a primeira sozinha reprovaria a própria implementação desta onda.** `forge_reject_unknown` mora em `arg-guards.sh`, logo o `wave-ops.sh`, ao ganhar o laço de P1 que a D5 lhe atribui, vai passar a carregar a biblioteca; com escopo = "carrega a biblioteca", ele entraria no universo de `[2]` com `total = 0` e a guarda de vacuidade por script reprovaria a implementação correta. O escopo é, portanto: **carrega `lib/arg-guards.sh` E tem ao menos um braço que consome `"$2"`**. Hoje devolve os três; `wave-ops.sh` com o laço de P1 e sem sítio de valor continua fora, e entra sozinho no dia em que ganhar um.

**As três guardas de `[2]`, e as três são vivas porque medem quantidades DIFERENTES** — que é o critério que o revisor nomeou e que a redação anterior não satisfazia:

| guarda | quantidade | forma | hoje | o que ela pega |
|---|---|---|---|---|
| derivação | `n_membros` do escopo | piso `≥ 3` | 3 | um dos três parar de carregar a biblioteca **ou** perder todos os sítios — é a forma **viva** de "um dos três caiu a zero sozinho" |
| cobertura | `guardados` contra `total`, por membro | **igualdade entre dois contadores derivados na execução**, nunca contra literal — é a forma de `w150[5]` (`n_reject == n_loops`) | `20 ≠ 31`, `3 = 3`, `23 = 23` → **vermelho hoje** | a asserção da correção: é ela que fecha os 11 sítios |
| vacuidade agregada | `soma(total)` dos membros | piso `≥ 40`, folgado | 57 | a varredura que colapsa e passa a examinar quase nada |

O piso de `n_membros` é **colado ao valor de hoje, e isso é deliberado e diferente do defeito de `w150[4]`**: lá o piso estava colado num número que a própria onda ia mexer, aqui a lista só pode crescer — todo script que ganhe sítio de valor precisa da biblioteca para o guardar, e portanto entra no escopo. O piso de 40 sobre o agregado de 57 é o folgado, no modelo de `w150[5]`, e é ele que reprova a varredura que colapsa. Nenhum dos três números é comparado por igualdade contra literal: os dois pisos são desigualdade e a cobertura é igualdade entre dois contadores derivados no mesmo instante.

### 6.2 Gate B — `w<NNN>-path-provenance-gate.sh` (#128 e #129)

| # | Cenário | Asserção | Vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [1] | wrapper com `--root <outra-árvore>` | o manifesto carimba o `head_sha` da **outra** árvore. A asserção é a **igualdade** entre o `head_sha` gravado e `git -C <outra> rev-parse HEAD`, derivados os dois na execução — nenhum SHA literal entra no fonte do gate | carimba o SHA da árvore do wrapper (`af74fd5` na bancada da revisão 2) enquanto a outra é `a441c2b` | `run-manifest.sh:6` anexa depois de `"$@"` e o parser deixa a última vencer |
| [2] | CONTROLE PAREADO: wrapper **sem** `--root` | carimba a raiz do wrapper, como hoje | *passa hoje* | verde por construção; é o que impede a correção de virar quebra dos quatro chamadores de produção |
| [3] | chave repetida não-acumuladora (`--stage a --stage b`) | recusa com `rc 2`, e **nenhum** manifesto é escrito | `rc=0`, `"stage": "SEGUNDO"` | `parseArgs` sobrescreve por atribuição simples |
| [4] | CONTROLE de [3]: acumuladores repetidos | `--command` e `--set` repetidos continuam acumulando, com a lista de acumuladores **derivada** do código | *passa hoje* | verde por construção; sem ele a recusa de duplicata bloquearia o caminho legítimo |
| [5] | `--root` ausente e `--root` como último token sem valor, **na invocação DIRETA do `.mjs`** | recusam com `rc 2`, sem escrever manifesto. Pelo wrapper o desfecho é outro e é `[2]`: D10 manda anexar a raiz do wrapper quando o chamador não passou nenhuma, e ali a ausência de `--root` continua `rc 0` | `rc=0` nos dois, gravando relativo ao `cwd` | `args[++i] \|\| ''` transforma ausência em string vazia |
| [6] | naming hook, as duas formas do MESMO arquivo | `src/<Pascal>/<Pascal>/A.cs` e `/abs/…/src/<Pascal>/<Pascal>/A.cs` devolvem o **mesmo** veredito | `rc=1` e `rc=0` | `:51` exige barra antes do segmento |
| [7] | naming hook, isenção não alargada | `mysrc/…` e `srcx/…` continuam reprovando | *passa hoje* | verde por construção; é o que separa a correção de um afrouxamento |
| [8] | naming hook, o gancho continua vivo | `src/Foo/SqlUserRepository.cs` continua `rc 1`, com a linha da **regra 1** e **sem** a linha da regra 2 | hoje sai `rc 1` com as **duas** linhas | é o controle que reprova o desarme do gancho, e ele muda de forma com a correção |
| [9] | naming hook, os desfechos vizinhos | `tests/…`, `deploy/…` e `./src/…` relativos aprovam; `services/x/src/…` continua aprovando | `rc=1` nos dois primeiros | mesma âncora |
| [10] | CANAL REAL (#129) | num repositório fixture com `core.hooksPath` armado no idioma do consumidor, um `git commit` de verdade sobre um `.cs` estagiado sob `src/` é **bloqueado** antes da correção e **aprovado** depois, com sinal positivo de que o gancho executou | o commit é bloqueado | o predicado reprova a forma que `git diff --cached --name-only` entrega |
| [11] | CONTADOR DE CONTROLE | `SCEN` por igualdade mais `forge_universe_check` com zero | — | verde por construção |
| [12] | SENTINELA | árvore de `template/` idêntica ao `HEAD` no fim do gate, por `git diff --name-only` **e** por `git status --porcelain`, que é o que pega arquivo não rastreado plantado por engano | — | verde por construção |
| [13]–[14] | as duas provas de mutação de §8.2 | — | — | — |

### 6.3 Os cenários que NÃO têm vermelho a observar, ditos em letra

Gate A: `[5]`, `[6]`, `[12]`, `[14]` e `[15]`. Gate B: `[2]`, `[4]`, `[7]`, `[11]` e `[12]`. Eles nascem verdes por construção, contam nos denominadores dos respectivos gates e **não** devem ser procurados no passo de observação do vermelho. A revisão 2 da Onda A registrou o custo de omitir esta lista, e esta especificação a escreve antes de ser cobrada.

**E `[7]` e `[8]` NÃO estão nesta lista, o que só é verdade por causa da D17.** O revisor da revisão 1 mostrou o buraco: se a Onda E mergeasse primeiro com a decisão 11 como estava escrita, os dois cenários já estariam verdes quando o gate fosse escrito, e o passo de observação do vermelho não teria o que observar num cenário declarado vermelho — exatamente a omissão que esta seção existe para impedir, entrando pela porta da ordem de merge. Com D17, os ramos `test)` e `status)` de `deferral-ops.sh` têm **um** dono, e nenhuma outra onda pode fechá-los antes. O vermelho de `[7]` e `[8]` está medido em §1.3 e §5.3, e continua sendo `rc 0` com escrita até esta onda o fechar.

### 6.4 Os denominadores

**O `SCEN` do Gate A estava errado na revisão 1, e o revisor pegou.** Ela alocava três rótulos (`[16]–[18]`) para as provas de mutação e fechava `SCEN = 18`, enquanto §8.1 declara **quatro** mutações (M1-M4) e §13.1 repete "as mutações M1-M4". Como `SCEN` é um dos dois únicos números que a onda manda comparar por **igualdade**, uma implementação correta — que escrevesse as quatro provas como cenários — seria recusada pelo próprio contador de controle. A aritmética do texto era internamente coerente e a divergência era contra §8.1, que é quem manda na implementação. Corrigido: os rótulos de mutação do Gate A passam a ser `[16]–[19]`, um por mutação, e `SCEN` do Gate A = **19**.

Os rótulos são contíguos a partir de `[1]`, e as linhas de mutação de cada tabela carregam mais de um rótulo cada (`[16]–[19]` no Gate A, `[13]–[14]` no Gate B). O comando que recontou, e que o próximo revisor roda sem adivinhar o recorte — o `sort -n -u | tail -1` devolve o máximo e a segunda passada prova a contiguidade listando os faltantes:

```
$ F=docs/plans/spikes/backlog-onda-l4-parsing-operacao.md
$ awk '/^### 6\.1 /{f=1} /^### 6\.2 /{f=0} f' "$F" | grep -aoE '\[[0-9]+\]' | tr -d '[]' | sort -n -u | tail -1
19
$ awk '/^### 6\.2 /{f=1} /^### 6\.3 /{f=0} f' "$F" | grep -aoE '\[[0-9]+\]' | tr -d '[]' | sort -n -u | tail -1
14
$ awk '/^### 6\.1 /{f=1} /^### 6\.2 /{f=0} f' "$F" | grep -aoE '\[[0-9]+\]' | tr -d '[]' | sort -n -u > /tmp/l4a.txt
$ seq 1 19 | grep -vxF -f /tmp/l4a.txt
17
18          ← os dois únicos ausentes do texto, porque estão DENTRO da notação `[16]–[19]`
$ awk '/^### 6\.2 /{f=1} /^### 6\.3 /{f=0} f' "$F" | grep -aoE '\[[0-9]+\]' | tr -d '[]' | sort -n -u > /tmp/l4b.txt
$ seq 1 14 | grep -vxF -f /tmp/l4b.txt
(vazio)
```

`SCEN` do Gate A = **19**; `SCEN` do Gate B = **14**. Estes são os **únicos dois números de igualdade** desta onda, e são legítimos pela exceção que a invariante 14 concede: denominador de cenários do próprio gate, fixo por construção, cuja divergência é o achado. Todo outro denominador — sítios de valor, membros do universo de `--help`, subcomandos derivados — é **piso sobre universo derivado na execução**, nunca igualdade. **E a conferência que o implementador deve o próximo revisor é esta:** rodar os quatro comandos acima contra a versão da spec que ele implementou, e conferir que `SCEN` do fonte de cada gate casa com o máximo que eles devolvem. Se a spec ganhar um cenário e o `SCEN` não acompanhar, é este par que denuncia.

---

## 7. O que a Onda E precisa mudar — resumo executável

Para que o revisor da Onda E não precise reler esta especificação inteira, as cinco mudanças em forma de lista — eram quatro na revisão 1, e a primeira mudou de natureza:

1. **Decisão 11 perde duas das quatro portas.** Os ramos `test)` e `status)` de `deferral-ops.sh` passam a L4 por **D17** (§1.4), e a decisão 11 fica com as duas portas de `ledger-ops.sh` (`render` e `status`). A razão é medida e é de atomicidade: o ramo `test)` precisa do `shift || true` do posicional (linha 115) **e** do laço de recusa, e as duas metades separadas em dois PRs produzem uma janela em que `tests/w51-waves-progress-gate.sh:112` está vermelho no tronco, em qualquer ordem de merge. As duas variantes estão em §5.1, executadas em bancada com controle de digest e recontrole.
2. **§10 da Onda E** corrige a linha *"`w51[…]` … segue verde"*: com D17 ela deixa de ser previsão sobre trabalho da Onda E e passa a ser dependência declarada — `w51` segue verde porque **L4** restaura o `shift` no mesmo commit em que escreve o laço.
3. **`w201[12]` sai da Onda E** junto com a implementação, e vira `[7]` do Gate A desta onda, **com o par positivo `[6]` na mesma fixture**. Sem par, o cenário é satisfeito por uma implementação que recuse o próprio posicional — que é o modo de falha `semshift` medido em §5.1.
4. **A definição de pronto da Onda E** troca *"o badge é atualizado de 131 para 132"* por *"o badge iguala `ls tests/*-gate.sh | wc -l` no momento do PR"*, porque L4 escreve dois gates contra o mesmo alvo de merge.
5. **O literal `(nenhuma)` da decisão 11 permanece na Onda E e é adotado também por L4**, e nenhuma das duas precisa mudar `lib/arg-guards.sh`: medido em §1.4/D17, a biblioteca instalada já imprime `flags aceitas em '<sub>': (nenhuma)` sem truncar quando o chamador passa o literal. As duas ondas passam a compartilhar uma convenção, não um arquivo.

E uma nota de escopo, para que nada fique sem dono: a quinta porta aberta da mesma classe — `wave-ops.sh` — é assumida por L4, não pela Onda E. **Com as cinco mudanças acima, L4 e a Onda E deixam de editar qualquer arquivo em comum** (§5.5).

---

## 8. Prova de mutação — matriz com contrafactual JÁ MEDIDO

O que dá força a esta seção é que a implementação ainda não existe e o comportamento pós-mutação **é o comportamento de hoje**, medido nas seções anteriores.

### 8.1 Gate A

| # | Alvo | Mutação | O gate DEVE acusar | Contrafactual medido |
|---|---|---|---|---|
| M1 | `liaison-ops.sh` | remover a guarda de valor do sítio `inbox --thread` | `[1]`, `[2]` e `[13]` reprovam; `[2]` acusa a queda do contador de guardados | §1.2: `rc=0`, `(nenhuma thread)` |
| M2 | `liaison-ops.sh` | remover a guarda de valor do sítio `peer set --path` | `[3]` reprova, e o `cmp` do `liaison.yaml` acusa a escrita | §1.2: `OK peer set — p → --path`, e `peer-path` devolve `--path` |
| M3 | `deferral-ops.sh` | remover o `shift` do posicional do ramo `test)`, preservando o laço de recusa | `[6]` reprova com `FAIL: argumento inesperado 'DEFER-01'` | §5.1, variante `semshift`: `rc=1` sobre a invocação legítima |
| M4 | um script qualquer do universo de `--help` | remover o ramo `-h\|--help)` de **um** membro | `[9]` reprova **nomeando o membro**, e o contador de universo não muda | §2.1: `rc` 0, 1 ou 2 conforme o script, e o token tratado como comando inválido, change-id ou gate-id |

**Os rótulos de cenário das quatro mutações do Gate A são `[16]`, `[17]`, `[18]` e `[19]`, um por linha desta tabela, e o `SCEN` do gate é 19.** A revisão 1 alocava três rótulos para quatro mutações e fechava `SCEN = 18` — como `SCEN` é comparado por igualdade, o contador de controle recusaria a implementação correta. Corrigido em §6.1 e recontado em §6.4.

### 8.2 Gate B

| # | Alvo | Mutação | O gate DEVE acusar | Contrafactual medido |
|---|---|---|---|---|
| M5 | `run-manifest.sh` | restaurar `"$@" --root "$ROOT"` incondicional | `[1]` reprova, com o `head_sha` do wrapper | §3.1: `af74fd5` (wrapper) contra `a441c2b` (chamador) na bancada da revisão 2, e `709d0ac` contra `4c2d599` na bancada nova da revisão 3 — o fenômeno reproduz em bancada montada do zero, e os literais continuam sendo testemunha, nunca asserção |
| M6 | `validate-naming-conventions.sh` | restaurar a âncora `/(src\|…` | `[6]`, `[9]` e `[10]` reprovam; `[7]` e `[8]` continuam verdes | §4.1 e §4.4: `rc=1` na forma relativa, `rc=0` na absoluta |

### 8.3 Protocolo, os seis passos

1. Cópia íntegra do alvo para `$TMPDIR` e `sha_antes` gravado. O primitivo foi executado nesta rodada: `shasum -a 256 <arquivo> | awk '{print $1}'` devolve 64 hex numa linha, disponível no macOS sem instalar nada.
2. A mutação é aplicada por **substituição integral** do arquivo a partir de uma cópia preparada em `$TMPDIR`, nunca por edição in-place com interpolação. **Proibido explicitamente:** `perl -0pi -e 's/x/y$var/'` com `$` sem escape do lado direito — em perl aquilo é variável do **perl**, vazia, a mutação vira no-op e o `cmp` de controle confirma que o arquivo mudou enquanto o comportamento não mudou. É LDG-0164, e o passo 3 existe para pegá-lo. Segui esta regra nas três mutações que executei nesta rodada (§4.4, §5.1 e a variante `semshift`/`comshift`), todas por `awk`/`sed` gerando arquivo novo e `cp` por cima da cópia de bancada.
3. `sha_mutado`, e a asserção de controle da própria mutação: `[ "$sha_mutado" != "$sha_antes" ]`.
4. Rodar os cenários **nomeados na matriz** e exigir FAIL **pela mensagem que a asserção declara**. Um FAIL por outra mensagem não conta — e §1.2 mostra por que essa cláusula não é zelo: **nove** dos onze sítios já falham hoje por outro motivo.
5. Restauração por `cp` da cópia íntegra, `sha_depois`, e asserção `[ "$sha_depois" = "$sha_antes" ]`.
6. **Recontrole:** rodar os mesmos cenários e exigir PASS. Sem o passo 6 a prova não vale — `feedback-mutacao-fantasma-restore` registra o caso em que um `restore()` quebrado deixou a mutação eterna e ninguém viu.

**Todos os alvos são arquivos rastreados e distribuídos no tarball.** A mutação acontece sobre uma **cópia da árvore em `$TMPDIR`**, nunca sobre a árvore de trabalho — é LDG-0175, e o cenário de sentinela de cada gate (`[15]` do A, `[12]` do B) existe para provar que a disciplina foi respeitada.

---

## 9. Onde entram PBT, contrato, integração e E2E

**PBT — obrigatório num lugar, e por medição.** O espaço de entrada de P2 é o produto (subcomando × flag-que-exige-valor × flag-vizinha), derivável das declarações de flags, e ele tem dezenas de pontos: `[13]` do Gate A é o teste de propriedade, com `lib/pbt.mjs` (que existe em `template/.forge/scripts/lib/pbt.mjs` e já é usado por `w121`, `w130` e `w132`), seed fixa, shrinking e asserção sobre o gerador de que o universo exercido não é vazio. A família da rule é **invariante de preservação**: nenhuma flag do conjunto declarado pode ser aceita como valor de outra.

**Onde PBT NÃO se aplica, com a medição.** O contrato de `--help` tem domínio de três entradas por script (`--help`, `-h`, e o par de controle) sobre um universo de 14 membros: enumerar é exaustivo e gerar seria decorativo, e a rule diz em letra *"se a unidade não tem propriedade … não force"*. O predicado do gancho de nomenclatura é uma expressão regular sobre segmentos de caminho com um conjunto de isenção de quatro elementos; os desfechos foram enumerados exaustivamente em §4.2, incluindo os dois que a issue não tinha, e um gerador de caminhos aleatórios exercitaria sobretudo o ramo trivial. O parser de `run-manifest` teria espaço de entrada, mas a propriedade que importa — "chave repetida não é sobrescrita em silêncio" — é decidida por três exemplos com controle, e o quarto elemento (acumuladores) é derivado do código, não sorteado.

**Teste de contrato — três, todos com adotante instalado.**
1. **O contrato de saída dos scripts de operação.** Três estados distinguíveis (`--help` → `rc 0`/stdout; comando desconhecido → `rc≠0`/stderr/nomeia o token; sem argumento → `rc≠0`/stderr/usage). É superfície pública que viaja no tarball e os quatro consumidores a têm instalada.
2. **O contrato de escrita do `run-manifest`.** O manifesto declara `head_sha` e `dirty` de uma árvore nomeada; o contrato passa a ser que a árvore nomeada é a que o chamador pediu, e que uma raiz não resolvível recusa em vez de inventar. `template/.forge/schemas/run-manifest.schema.json` não muda — o defeito é de proveniência, não de forma.
3. **O contrato de entrada do gancho de nomenclatura.** Ele recebe um caminho em `$1` e devolve veredito; o contrato passa a ser que o veredito **não depende da grafia do caminho**. É o cenário `[6]` do Gate B, e ele é escrito como igualdade entre duas invocações, nunca como valor esperado de uma.

**Teste de integração — é o eixo, não complemento.** Nenhum dos quatro defeitos é de função pura: o `inbox` erra porque o laço não consulta o conjunto declarado, o `run-manifest` erra porque **o wrapper concatena depois**, o gancho erra porque **o invocador entrega outra forma de caminho**. Uma função testada isoladamente nasce verde nos três. Por isso todas as asserções montam repositórios git de verdade, canais de liaison de verdade e invocam os scripts como um operador os invocaria.

**E2E — um, e é o de #129.** O cenário `[10]` do Gate B faz um `git commit` real através de `core.hooksPath`, que é o caminho pelo qual o defeito chegou ao consumidor. É a exigência literal de `testing/gate-delivery-channel.md`, e §4.3 mede por que ele precisa **montar** o canal em vez de reusá-lo: o produtor instala o gancho e não o arma.

---

## 10. Retrocompatibilidade — o que já está instalado nas doze árvores de consumidor

Esta é a onda que mais precisa desta seção, porque os consumidores aplicaram a `0.14.0` no mesmo dia. **E o primeiro achado desta seção é que a superfície é maior do que o plano-mestre supõe: ele fala em "os quatro repositórios consumidores", e são doze árvores com o harness instalado.** Censo medido nesta rodada, somente leitura:

```
$ cd ~/Documents/projects && for d in */; do f="$d/.forge/forge.yaml"; [ -f "$f" ] || continue
    tv=$(grep -m1 'template_version' "$f" | sed 's/.*: *//;s/"//g')
    printf '%-26s %-12s liaison-ops=%-4s run-manifest=%-4s naming-hook=%s\n' "${d%/}" "$tv" \
      "$([ -f "$d/.forge/scripts/liaison-ops.sh" ] && echo sim || echo nao)" \
      "$([ -f "$d/.forge/scripts/run-manifest.sh" ] && echo sim || echo nao)" \
      "$([ -f "$d/.forge/hooks/pre-tool-use/validate-naming-conventions.sh" ] && echo sim || echo nao)"
  done
agent-smith                0.1.0-dev    liaison-ops=nao  run-manifest=nao  naming-hook=sim
axis-fare-validator        0.14.0       liaison-ops=sim  run-manifest=sim  naming-hook=sim
axis-go-cloud              0.14.0       liaison-ops=sim  run-manifest=sim  naming-hook=sim
Axis.AcqSimulator          0.1.0-rc22   liaison-ops=nao  run-manifest=sim  naming-hook=sim
Axis.PadSimulator          0.11.0       liaison-ops=sim  run-manifest=sim  naming-hook=sim
azim-crm                   0.1.0-rc24   liaison-ops=sim  run-manifest=sim  naming-hook=sim
collatra                   0.1.0-rc24   liaison-ops=sim  run-manifest=sim  naming-hook=sim
cpf-cnpj-validator         0.1.0-dev    liaison-ops=nao  run-manifest=nao  naming-hook=sim
docuseal                   0.1.0-rc23   liaison-ops=nao  run-manifest=sim  naming-hook=sim
forge-test                 0.1.0-dev    liaison-ops=nao  run-manifest=nao  naming-hook=sim
lionclaw                   0.14.0       liaison-ops=sim  run-manifest=sim  naming-hook=sim
payments                   0.1.0-dev    liaison-ops=nao  run-manifest=nao  naming-hook=sim

$ ls -d */ | wc -l      → 33      (controle: quantos diretórios a varredura examinou)
```

**A revisão 1 publicava `azim-crm` em `0.14.0` e eu não reproduzi isso na revisão 2** — `grep -an 'template_version' ~/Documents/projects/azim-crm/.forge/forge.yaml` devolve `5:  template_version: "0.1.0-rc24"`. São **três** árvores em `0.14.0`, não cinco: `axis-fare-validator`, `axis-go-cloud` e `lionclaw` — e esta última não aparece em nenhuma das vinte issues de campo. As três superfícies têm tamanhos diferentes e isso ordena o risco: o gancho de nomenclatura está em **12 de 12**, o `run-manifest.sh` em 9, o `liaison-ops.sh` em 6. **O defeito de maior alcance instalado desta onda é #129, o de menor gravidade aparente.** Os números são testemunha de data e nenhuma asserção os usa.

E a divergência de cada cópia contra o template de hoje, por `cmp -s`, nas **seis** árvores que carregam os quatro artefatos — a revisão 2 escrevia "cinco" numa prosa que encabeçava uma tabela de seis linhas, e o número certo é o que o próprio laço conta:

```
$ n=0; for d in */; do [ -f "$d/.forge/scripts/liaison-ops.sh" ] && [ -f "$d/.forge/scripts/deferral-ops.sh" ] \
    && [ -f "$d/.forge/scripts/run-manifest.sh" ] \
    && [ -f "$d/.forge/hooks/pre-tool-use/validate-naming-conventions.sh" ] && n=$((n+1)); done; echo $n
6
```


| repositório | `liaison-ops.sh` | `deferral-ops.sh` | `run-manifest.sh` | `validate-naming-conventions.sh` |
|---|---|---|---|---|
| axis-fare-validator | **diverge** | **diverge** | idêntico | **diverge** |
| axis-go-cloud | **diverge** | idêntico | idêntico | **diverge** |
| Axis.PadSimulator | **diverge** | **diverge** | **diverge** | idêntico |
| azim-crm | **diverge** | **diverge** | idêntico | idêntico |
| collatra | **diverge** | **diverge** | idêntico | idêntico |
| lionclaw | idêntico | idêntico | idêntico | idêntico |

**Duas linhas mudaram da revisão 1 para a 2, e as duas foram remedidas contra o `template/` de `cf3bbe4`.** O `azim-crm` não é idêntico em nada além do `run-manifest.sh` e do gancho — diverge nos dois scripts de operação —, e a revisão 1 o dava como idêntico nos quatro. E o `lionclaw`, que a revisão 1 nem listava, é a única árvore byte a byte idêntica ao template nas quatro peças, o que faz dele o consumidor onde a onda chega limpa. A tabela foi produzida por um laço de `cmp -s` arquivo a arquivo contra `template/.forge/`, com o terceiro estado (`ausente`) distinguido de `DIVERGE`.

O que cada divergência é, medido:

```
$ grep -ac '_ap_ctx' ~/Documents/projects/axis-fare-validator/.forge/scripts/{liaison-ops,deferral-ops}.sh
…/deferral-ops.sh:5      …/liaison-ops.sh:13
$ grep -acE '_reject_unknown|forge_reject_flag_as_value' ~/Documents/projects/axis-fare-validator/.forge/scripts/liaison-ops.sh
32
$ grep -an 'src|tests|services|deploy' ~/Documents/projects/axis-go-cloud/.forge/hooks/pre-tool-use/validate-naming-conventions.sh
85:if [[ "$DIR" =~ (^|/)(src|tests|services|deploy)(/|$) ]]; then
$ grep -an 'src|tests|services|deploy' ~/Documents/projects/axis-fare-validator/.forge/hooks/pre-tool-use/validate-naming-conventions.sh
77:if [[ "$DIR" =~ /(src|tests|services|deploy)(/|$) ]]; then
```

As quatro contagens foram reexecutadas na revisão 2, com `-a`, e reproduzem: 5 e 13 sítios de `_ap_ctx`, 32 chamadas das duas guardas no `liaison-ops.sh` do consumidor, e as duas âncoras nas duas pontas opostas do desenho.

**O `axis-go-cloud` já aplicou a correção de #129 na árvore dele**, exatamente na forma que D14 adota — o que é uma confirmação independente da decisão. O `axis-fare-validator` **não** aplicou, apesar de ter a cópia divergente por outros motivos, e vai receber a correção pelo update.

**O que quebra, nomeado antes de acontecer:**

| Mudança | Quem sente | O que fazer |
|---|---|---|
| `run-manifest.sh` passa a respeitar o `--root` do chamador | ninguém no produtor: **zero** chamadores de produção e **zero** gates passam `--root`, medido em §3.4 | é a correção; o `CHANGELOG` diz que o contorno de chamar o `.mjs` direto deixa de ser necessário |
| `parseArgs` recusa chave repetida com `rc 2` | quem passava a mesma flag duas vezes e não percebia; medido: nenhum chamador nem gate faz isso | é o que a issue pede; acumuladores continuam acumulando, e a lista deles é derivada |
| `--root` ausente ou vazio recusa em vez de resolver para o `cwd` | quem invoca o `.mjs` diretamente sem `--root` | mudança de contrato; entra no `CHANGELOG` com a linha de correção |
| `--help` passa de `rc≠0` para `rc 0` em 14 scripts | script de terceiro que use `--help` como sonda de existência e teste `rc≠0` | é o objetivo, e o `CHANGELOG` diz com essas palavras que os três estados passam a ser distinguíveis |
| `run-gates.sh --help` deixa de sair `rc 0` | quem tivesse um passo de CI escrito assim — e ele estaria sendo reportado como aprovado sem rodar nada | é o falso-verde que a onda fecha |
| os 11 sítios do `liaison-ops.sh` passam a recusar flag como valor | quem passava e via `OK` — inclusive o `peer set` que gravava lixo | é a issue #133 |
| `deferral-ops test`/`status` e `wave-ops` passam a recusar argumento desconhecido | quem passava argumento a mais | é o que a Onda E e esta onda pedem |
| o gancho de nomenclatura passa a **aprovar** caminhos relativos sob `src`/`tests`/`services`/`deploy` | ninguém perde recusa legítima: `mysrc`/`srcx` continuam reprovando e a regra 1 continua intacta | é a correção; `axis-go-cloud` já a tem |
| **seis scripts passam a NOMEAR o token recusado na mensagem de erro** — `wave-ops`, `deferral-ops`, `red-evidence`, `check-red-first`, `graph` e `spec-transition` | quem casa a mensagem de erro por texto exato; medido em §2.4/D6, e a varredura de `tests/` pelas sete strings devolve **zero** arquivo, com controle positivo devolvendo 4 e universo de 188 arquivos examinados | é o que torna os três estados distinguíveis; o `CHANGELOG` diz que a mensagem passa a conter o token, e as strings de usage não mudam |
| **`wave-ops.sh` passa a recusar flag desconhecida em `close`, e `--gate` continua aceito** | `tests/w131-surface-declaration-gate.sh:222` invoca `close chg W1 --gate OK`, invocação legítima que um laço ingênuo reprovaria | o conjunto declarado por subcomando está derivado em §1.4/D5, e `w131` entra na lista de gates verdes de §13.2 |

**A quebra que a onda causa numa árvore de consumidor, e ela precisa ser dita porque é a mais cara.** O `axis-fare-validator` mantém, sob `.forge/scripts/tests/`, um `argparse-structure.test.sh` e um `liaison-argparse.pbt.mjs` que **derivam o universo de flags das declarações `_ap_ctx` dos próprios scripts**, com um piso literal de 23 subcomandos. A revisão 1 afirmava isso sem endereço; a revisão 2 leu os dois arquivos (leitura apenas, o mandato não autoriza escrita em consumidor) e cola a linha:

```
$ grep -an 'SUBCOMANDOS_ESPERADOS\|UNIVERSE.length <' \
    ~/Documents/projects/axis-fare-validator/.forge/scripts/tests/liaison-argparse.pbt.mjs
233:const SUBCOMANDOS_ESPERADOS = 23;   // todo subcomando com ao menos uma flag, nos três scripts
251:if (UNIVERSE.length < SUBCOMANDOS_ESPERADOS) {
252:  console.error(`FAIL pbt — universo com ${UNIVERSE.length} subcomando(s); esperados ${SUBCOMANDOS_ESPERADOS}.`);
$ sed -n '51,56p;221,223p' …/liaison-argparse.pbt.mjs
function readUniverse(scriptPath) { … const ctxRe = /_ap_ctx\s+"([^"]+)"\s+"([^"]*)"/g; … }
const UNIVERSE = [ ...readUniverse(join(SCRIPTS, 'liaison-ops.sh')),
                   ...readUniverse(join(SCRIPTS, 'deferral-ops.sh')),
                   ...readUniverse(join(SCRIPTS, 'ledger-ops.sh')) ];
```

O universo é lido por expressão regular sobre `_ap_ctx` nos **três** scripts, sob `SCRIPTS = .forge/scripts`. Quando aquela árvore tomar a versão desta onda, os sítios de `_ap_ctx` são sobrescritos pelo template (o mecanismo é #101/#125, não esta onda), `UNIVERSE.length` vai a **zero**, e a comparação de `:251` reprova com a mensagem de `:252` — *"universo com 0 subcomando(s); esperados 23"*. Reprova pela ausência do que ele lê, não pela ausência da propriedade, que passa a estar coberta upstream por `w150[5]` (P1) e pelo cenário `[2]` do Gate A (P2). O `argparse-structure.test.sh` cai pela mesma raiz: o cabeçalho dele (`:25-26`) declara que E1 e E2 cruzam `_ap_ctx` com os braços do `case`, e sem `_ap_ctx` não há o que cruzar.

**A saída não é esconder isso nem adotar `_ap_ctx` para evitá-lo.** É três coisas, e as três entram na definição de pronto: o `CHANGELOG` nomeia a quebra e diz qual asserção upstream substitui cada um dos dois testes locais; a resposta de ack da Onda I na thread correspondente carrega a medição (11 sítios fechados, derivação de P2 com piso, censo dos quatro scripts) para que o consumidor **aposente** a camada local deliberadamente em vez de a descobrir destruída; e a onda registra em letra que o mecanismo da destruição é L1 (#101/#125/#131), que esta onda não fecha.

**Propagação e plugin.** Medido na revisão 2, com `-a` e com o controle positivo do preâmbulo: `grep -arln -- '--help' template/.forge/commands/ | wc -l` devolve **0** — nenhum comando menciona `--help` —, e `template/.forge/commands/harness/liaison.md` não faz afirmação normativa sobre a disciplina de parsing (`diff` contra `plugin/forge/commands/liaison.md` → `rc 0`, os dois byte a byte idênticos). **Logo esta onda, como especificada, não obriga a regeneração do plugin.** A restrição, que entra na definição de pronto: se a implementação decidir documentar `--help` em qualquer arquivo de `template/.forge/commands/`, o espelho é regenerado com `npm run build:plugin` — **nunca** `build-plugin.sh`, que instala em `$HOME` —, e `tests/plugin-sync-gate.sh` reprova com *"plugin/forge dessincronizado — rode: npm run build:plugin"* se esquecerem.

**A Fase 1 do plano, que está em voo nesta mesma árvore.** Medido agora: `.forge/scripts` **não existe** na raiz deste repositório. Se a Fase 1 mergear antes desta onda, passará a existir uma cópia instalada da maquinaria, e os dois gates desta onda passariam a ver dois `liaison-ops.sh`. **Restrição fixada:** as varreduras estruturais dos dois gates escopam explicitamente em `template/.forge/`, e não em `.forge/` nem no repositório inteiro. Um gate desta onda que conte ocorrências no repositório inteiro nasce com o defeito que a Fase 1 avisou que criaria.

---

## 11. O que esta onda explicitamente NÃO faz

**Não conserta o mecanismo pelo qual a camada local do consumidor foi destruída.** Esse mecanismo é o `forge update` sobrescrevendo `MACHINERY_DIRS` inteiros, e ele é #101 (Onda C) mais #125, #130, #131 e #142 (Onda L1). Sem eles, a próxima atualização do `axis-fare-validator` desfaz de novo qualquer coisa que ele tenha consertado à mão em `scripts/` — inclusive as correções desta onda, se ele as tiver antecipado. Dizer isso é o mínimo: uma onda de parsing que se apresentasse como resposta suficiente a #133 estaria vendendo o que não entrega.

**Não adota `lib/argparse.sh`.** D1, com as três razões medidas e as duas alternativas descartadas.

**Não consolida `liaison-ops.sh::_reject_unknown` com `lib/arg-guards.sh`.** É LDG-0152, onda F, e o próprio cabeçalho de `arg-guards.sh:23-24` declara isso como trabalho próprio. A derivação do cenário `[2]` é escrita para sobreviver à consolidação.

**Não arma o gancho de nomenclatura no `pre-commit` do template.** D16, com a medição de terceiro que diz por quê e com a curadoria da regra 2 que ela exigiria antes.

**Não corrige a vacuidade de `run-gates.sh <id-inexistente>` saindo `rc 0`.** É LDG-0160 e a invariante 18 do plano, e a Onda K é dona porque o conserto é o executor de fase que ela cria. A onda mede o desfecho e o registra — e, por consequência, **`run-gates.sh` é isento da via de token inválido do cenário `[10]`**, nas duas cláusulas (`rc≠0` e nomeação), porque ele não tem estado de recusa para esse token: trata-o como change-id. A via sem argumento dele não é isenta (`rc 1` com usage, medido) e a distinguibilidade de `--help` também não.

**Não muda o `exit 0` de contrato do `spec-advance-module.sh`.** O cabeçalho dele, `:18`, declara *"sempre exit 0 (não derruba a onda)"*, e o consumidor é o `/forge:coding-loop`: um vínculo best-effort que derruba a onda é pior do que um que não avança. Mudar isso é mudar o contrato de outro comando, cujo raio esta onda não mediu. **Ele é isento apenas da cláusula de `rc≠0` do cenário `[10]`**; a de nomeação continua valendo e ele já a cumpre (`SKIP (fase inválida: fase-xyz — use implementing|implemented)`, medido), e a de distinguibilidade também. Vai para o ledger como decisão a tomar por quem for dono do `coding-loop`.

**Não toca `wave-ops.sh:152`, o `--gate` lido por posição.** D5, com a razão de a direção do desfecho não ter sido medida e de suposição não valer como medição. Vai para o ledger.

**Não aceita `help` como palavra nua.** D8.

**Não uniformiza o canal da via de ERRO dos catorze scripts.** Medido na revisão 2 (§2.1): cinco imprimem a mensagem de erro em stderr e nove em stdout. A onda faz `--help` sair em stdout com `rc 0` e não move nada mais — realocar canal em nove scripts é mudança de superfície observável cujo raio de quebra esta onda não mediu, e enfiá-la neste diff misturaria assunto. A medição fica pronta no ledger para quem decidir uniformizar, e a decisão precisa vir com a varredura dos gates que capturam a saída desses nove sem `2>&1`.

**Não muda `template/.forge/schemas/run-manifest.schema.json`.** O defeito de #128 é de proveniência, não de forma do manifesto.

**Não retrofita manifestos já gravados com o `head_sha` errado.** Eles são evidência histórica de execuções que de fato aconteceram; reescrevê-los seria a segunda mentira sobre a mesma execução. O `CHANGELOG` nomeia a versão a partir da qual o carimbo é confiável.

---

## 12. Como as cinco armadilhas foram tratadas

**A — literal que envelhece.** Todo número que conta a árvore aparece aqui **datado, nomeado como medição e com o comando ao lado**, nunca como asserção de gate: 31/20/11 sítios de valor (§1.1), 23 dispatchers e 14 com usage (§2.2), 131 gates e badge 131 (§5.4), e o censo de consumidores de §10 — `ls -d */ | wc -l` → **33** diretórios examinados, **20** com `.git`, **12** com `.forge/forge.yaml`, dos quais **3** em `0.14.0`. Os três números do censo foram reexecutados na revisão 2 e um deles mudou: a revisão 1 dizia cinco árvores em `0.14.0` e a medição devolve três, porque o `azim-crm` está em `0.1.0-rc24`. O de §10 acabou produzindo achado próprio, e por isso está lá em cima e não só aqui: o plano-mestre enumera "os quatro repositórios consumidores" e a medição devolve doze, **três** delas em `0.14.0` — a revisão 2 dizia "cinco" nesta frase quatro linhas depois de declarar a correção para três, resíduo que o revisor pegou e que a remedição da revisão 3 confirma (`axis-fare-validator`, `axis-go-cloud`, `lionclaw`). A varredura dos contadores que a **entrega** desloca produziu dois achados. O primeiro é o badge, que `w200[6]` compara por igualdade e que **duas ondas desta rodada querem escrever ao mesmo tempo** — resolvido em §5.4 declarando a propriedade e devolvendo o literal ao orquestrador. O segundo é a linha `scripts/ (N)` do bloco `## 📁 Estrutura`, que `w200[1]` compara contra `find … -type f ! -name README.md | wc -l`: **esta onda não acrescenta arquivo algum sob `template/.forge/`**, e §5.4 registra que a decisão D1 é o que garante isso, porque adotar `lib/argparse.sh` obrigaria a rederivar aquela contagem. Os dois únicos números de igualdade da onda são os `SCEN` dos dois gates, recontados por comando em §6.4.

**B — string de produção que quebra gate existente, e o espelho do plugin.** A varredura de `tests/` por cada string tocada está em §2.4 (D9) e deu resultado nulo — **e na revisão 2 ela foi refeita com `-a`, com controle positivo, porque o achado LDG-0177 mostrou que uma varredura sem `-a` pode devolver vazio por não conseguir ler o universo** (preâmbulo do §0) — **e na revisão 3 o controle positivo mudou de forma, porque o da revisão 2 era texto puro e passava igual com e sem `-a`, isto é, assegurava a si mesmo: ele passa a carregar byte de controle e a asserção passa a ser o par "com `-a` acha, sem `-a` não acha"**. Nenhum gate rastreado afirma o usage dos cinco scripts nem a mensagem de comando desconhecido deles. O achado real da varredura foi **estrutural e não textual**: `w150:204-209` deriva o universo de subcomandos do `liaison-ops.sh` das linhas de cabeçalho `#   liaison-ops.sh <sub> …`, o piso `-ge 20` está em `:248` e a recusa `rc 99` em `:243`, e uma implementação de `--help` que reescrevesse aquele bloco derrubaria `w150[4]` sem tocar em string que uma varredura por texto encontraria. Virou restrição em D9 e cenário `[12]` do Gate A, este último com as **duas** pontas asseridas desde a revisão 3. O espelho do plugin foi medido e não é obrigado (§10), com a restrição condicional e o gate que morde nomeados.

**C — mutação sem contrafactual medido.** As seis linhas das matrizes de §8 têm contrafactual **já observado**, porque a implementação não existe e o comportamento pós-mutação é o de hoje: `rc=0`/`(nenhuma thread)` para M1, `OK peer set — p → --path` para M2, `FAIL: argumento inesperado 'DEFER-01'` para M3, os rcs 0/1/2 de §2.1 para M4, `af74fd5` contra `a441c2b` para M5, `rc=1` contra `rc=0` para M6. As seis foram **reexecutadas na revisão 2**, em bancada nova sob `$TMPDIR`, e as seis reproduzem.

As três mutações que eu **executei** — a correção da âncora em §4.4 e as variantes `semshift`/`comshift` em §5.1 — foram feitas por geração de arquivo novo com `awk` e `cp` por cima da cópia de bancada, **nunca por `perl -0pi` com interpolação, que é o padrão de LDG-0164**: `perl -0pi -e 's/x/y$var/'` com `$` sem escape do lado direito interpola uma variável do **perl**, vazia, e a mutação vira no-op enquanto o `cmp` de controle confirma que o arquivo mudou. As três carregam as quatro asserções do protocolo, e todas as quatro estão coladas em §5.1 e §4.4: digest antes, digest depois da mutação **diferente** do primeiro, digest após o restauro **igual** ao primeiro, e recontrole verde — mais um `cmp -s` byte a byte contra a cópia íntegra. Sem o recontrole a prova não vale, porque um `restore()` quebrado deixa a mutação eterna e as medições seguintes medem a mutação (`feedback-mutacao-fantasma-restore`).

**D — enumeração que se diz exaustiva.** Quatro enumerações desta especificação foram construídas procurando ativamente o caso não coberto, e **três produziram achado**. Em §3.3, os acumuladores `--command`/`--set`, que uma recusa ingênua de chave repetida quebraria, mais o caso do `--root` aparecendo como **valor** de outra flag, que uma detecção posicionalmente cega no shell trocaria por um defeito novo. Em §4.2, o `./src/…` que aprova hoje enquanto `src/…` reprova — o mesmo arquivo, as duas formas relativas, dois vereditos —, mais o `deploy/…` na raiz, que a issue não mediu, mais o controle da regra 1 que separa "corrigi a âncora" de "desliguei o gancho". Em §2.1, o universo de `--help` alargado de 4 para 14 scripts, que produziu o único falso-verde do subgrupo (`run-gates.sh --help` → `rc 0`) e desmentiu a própria avaliação de gravidade da issue. A quarta enumeração — os quatro subcomandos de `deferral-ops.sh` — foi conferida e está completa, e a incompletude que ela **tinha** era de outro escopo: a quinta porta da mesma classe está no `wave-ops.sh` (§5.3).

E registro **duas** enumerações que passadas minhas erraram, porque as duas são instrutivas e as duas erraram pela mesma raiz — a varredura que não consegue ver o que procura.

A primeira, da revisão 1: o censo de P2 de §1.1 contou `ledger-ops.sh` com **zero** sítios guardados, porque eu grepava pelo nome `forge_reject_flag_as_value` e aquele arquivo chama `_require_value`, um alias local de uma linha (`ledger-ops.sh:52`) que delega. A conclusão errada teria sido que o `ledger-ops` é o pior dos três quando ele é o único íntegro, e ela teria mandado a onda consertar um arquivo que não tem defeito. O censo corrigido está em §1.1 e casa com a medição independente da Onda E, que exercitou o `ledger-ops add --title --detail` e viu a recusa.

A segunda é da revisão 2 e vem do achado do orquestrador, **e ela própria errou o número, o que a revisão 3 corrige por medição**: a revisão 2 escrevia que as cinco varreduras de ausência desta especificação apontam para `template/.forge/scripts/lib/`, e apontam **duas** — a de `_ap_ctx` do §0, recursiva em `template/`, que tem o `secret-scan.mjs` no universo, e a de `validate-naming` do §4.3, que aponta para dentro de `lib/` mas cujo universo é um arquivo só. As outras três não descem a `lib/`: a de usage varre `tests/`, a de `--help` varre `template/.forge/commands/`, e a de chamadores do `run-manifest` usa o glob `template/.forge/scripts/*.sh`, que não desce (medido: `ls template/.forge/scripts/*.sh | grep -c 'lib/'` → 0). Nenhuma delas mudou de resultado quando refeita com `-a` — mas isso eu só posso afirmar agora, e a revisão 1 não podia, porque ela não tinha como distinguir "varri e não achei" de "não consegui varrer". **O erro estava na direção segura e mesmo assim precisa sair**, porque ele inflava o risco e sustentava a justificativa frouxa que o bloqueador 2 do revisor derrubou: `-a` continua obrigatório em toda varredura de ausência, e a razão é que o custo de estar errado é assimétrico, não que o arquivo esteja em cinco universos. O caso do L1 nesta mesma rodada mostra o preço: uma conclusão errada sobre ausência de detector foi confirmada por dois caminhos independentes, e o segundo caminho era este defeito. É a invariante 2 aplicada à própria ferramenta de medição, e ela agora tem controle positivo (§0).

**E — prescrição não executada.** Todo primitivo citado nesta especificação foi executado por mim, e **toda medição da revisão 1 que o revisor não conseguiu reproduzir foi reexecutada na revisão 2 com o comando colado ao lado do número, ou removida** — as três que mudaram de valor estão nomeadas em §14. A lista das execuções: a bancada de liaison com os onze sítios e o `liaison.yaml` corrompido; as duas variantes de guarda no `deferral-ops.sh` com controle de sha e recontrole; o par wrapper/`.mjs` do `run-manifest` sobre duas árvores git com SHAs distintos, incluindo as três portas vizinhas; o gancho de nomenclatura em **bash 3.2 real** (`/bin/bash --version` colado) nas nove formas de caminho, com a correção aplicada por substituição integral, controle de sha, recontrole e o controle da regra 1; os catorze scripts do universo de `--help` com `rc` capturado **sem pipe**; os controles de `run-gates.sh` sem argumento e com id inventado, que é o que transforma a observação em achado; os censos por `grep -c` sobre os quatro scripts de operação; e os `cmp -s` das cópias dos cinco consumidores contra o template.

Onde a especificação **não** podia executar — a derivação definitiva dos braços que consomem `"$2"`, o primitivo de detecção posicional de `--root` no shell, o formato final do bloco de ajuda —, ela declara a **propriedade** e o **contrafactual** e devolve a escolha do primitivo a quem executa, com a obrigação explícita de provar a discriminação por controle e recontrole. E onde o meu próprio experimento não sustentou a conclusão, o texto diz qual dos dois vale: é o caso do censo de `ledger-ops.sh` em §12-D, e o do `wave-ops.sh:152`, cuja direção de desfecho eu não medi e por isso não afirmo.

---

## 13. Ordem de implementação e definição de pronto

### 13.1 Ordem

1. **`deferral-ops.sh`, o `shift` do posicional no ramo `test)`, no MESMO commit do laço de recusa do passo 3.** Os dois são indivisíveis (D17, §1.4): o `shift` sem o laço não fecha porta nenhuma, e o laço sem o `shift` derruba `tests/w51-waves-progress-gate.sh:112`. Vermelho: `[6]` do Gate A sob M3.
2. **`liaison-ops.sh`, os 11 sítios.** Vermelho: `[1]`, `[3]`, `[4]`. Depois `[2]`, a derivação estrutural, que só faz sentido quando há o que derivar dos dois lados.
3. **`deferral-ops.sh` `test`/`status` e `wave-ops.sh`, a recusa de argumento** — de L4 por **D17**, com o literal `(nenhuma)` da decisão 11 da Onda E adotado como convenção (nenhuma mudança em `lib/arg-guards.sh`). O conjunto declarado do `wave-ops` está derivado em D5 — `plan`, `open` e `status` com `(nenhuma)`, `close` com `--gate` —, e `close` tem de continuar aceitando `--gate OK`, que é o que `tests/w131-surface-declaration-gate.sh:222` invoca. O ramo `test)` fecha junto com o passo 1, num commit só. Vermelho: `[7]`, `[8]`. Não há mais coordenação de arquivo com a Onda E (§5.5).
4. **PBT de P2**, sobre a implementação do passo 2. Vermelho: `[13]`.
5. **`--help` nos 14 membros do universo derivado, MAIS a nomeação do token nos seis que não a têm** (`wave-ops`, `deferral-ops`, `red-evidence`, `check-red-first`, `graph`, `spec-transition` — censo em §2.4/D6). Vermelho: `[9]`, `[10]`, `[11]`. Com a restrição de D9: não tocar as linhas de cabeçalho `#   liaison-ops.sh <sub> …`, e `[12]` vigia as duas pontas dessa restrição. As duas isenções de `[10]` são as de §11 e o gate as imprime.
6. **Gate A fechado**, com `[14]`, `[15]` e as quatro mutações M1-M4 como cenários `[16]`–`[19]`. `SCEN` do Gate A = **19**.
7. **`run-manifest.sh` e `lib/run-manifest.mjs`.** Vermelho: `[1]`, `[3]`, `[5]` do Gate B.
8. **`validate-naming-conventions.sh`.** Vermelho: `[6]`, `[9]`, `[10]` do Gate B.
9. **Gate B fechado**, com `[11]`, `[12]` e as mutações M5-M6.
10. **Documentação:** `CHANGELOG.md` com as oito quebras de §10, e a decisão sobre regeneração de plugin conforme §10.

### 13.2 Definição de pronto, cada linha provada por comando

- Os quatro defeitos reproduzidos em §1.2, §2.1, §3.1 e §4.1 **não** reproduzem mais, pelos mesmos comandos, nas mesmas bancadas — e as três medições que **não** reproduzem no template (a existência de `lib/argparse.sh`, a aceitação silenciosa de flag desconhecida no `liaison-ops.sh`, e a perda de guarda de valor no `deferral-ops.sh`) permanecem registradas como não-reprodução, não como trabalho feito.
- Suíte inteira verde, executada **em série** pelo orquestrador, nunca concorrente — `feedback-suite-sem-concorrencia`.
- `bash -n` limpo em todo arquivo tocado; nada de `declare -A`, `${var,,}`, `mapfile` (bash 3.2, invariante 8). O gancho de nomenclatura foi medido em `/bin/bash` 3.2.57 e continua sendo.
- Os dois gates publicam `SCEN` comparado por **igualdade** (**19** no Gate A, **14** no Gate B), mais a contrapositiva de `forge_universe_check` com zero. Todo outro denominador é **piso sobre universo derivado na execução**. O `SCEN` de cada gate é reconferido contra a spec pelos quatro comandos de §6.4 antes do PR — se a spec ganhar cenário e o `SCEN` não acompanhar, é esse par que denuncia.
- **O badge de gates do `README.md` iguala `ls tests/*-gate.sh | wc -l` no momento do PR**, reconferido depois de qualquer rebase sobre `develop`, porque `w200[6]` compara por igualdade e há outra onda desta rodada escrevendo gate contra o mesmo alvo.
- `tests/w150-liaison-flag-and-trust-gate.sh` roda **sem edição** e fica verde — em particular `[4]`, cuja derivação depende das linhas de cabeçalho de uso, e `[5]`, cuja igualdade `n_reject == n_loops` a onda não pode quebrar ao acrescentar laço em `wave-ops.sh` (que é outro arquivo).
- `tests/w51-waves-progress-gate.sh` roda sem edição e fica verde — é a asserção que prova a correção 1 de §5.1.
- `tests/w131-surface-declaration-gate.sh` roda **sem edição** e fica verde — em particular `:222`, `close_wave "$T/wliar" W1 --gate OK`, que é invocação legítima que o laço de recusa novo em `wave-ops.sh close` tem de aceitar, e `:207-210`, que reprova quando a saída de uma recusa contém `Usage`/`obrigatório`/`não encontrada`. O conjunto declarado por subcomando de `wave-ops` está derivado em §1.4/D5: `plan`, `open` e `status` com `(nenhuma)`, `close` com `--gate`.
- `tests/w201-flag-como-valor-gate.sh` roda sem edição e fica verde. E os **cinco** gates que tocam `run-manifest` — `w32`, `w80`, `w90`, `w91`, `w92`, universo derivado por `grep -arln 'run-manifest' tests/*.sh` — rodam sem edição e ficam verdes, porque nenhum deles passa `--root` nem repete chave, medido em §3.4.
- As seis provas de mutação percorrem os seis passos de §8.3, incluindo a asserção de que o sha mutado difere do original e o recontrole verde depois da restauração, e cada uma derruba os cenários **nomeados na matriz**, nunca outros.
- As varreduras estruturais dos dois gates escopam em `template/.forge/`, e a definição de pronto exige que isso seja verificado **depois** de qualquer merge da Fase 1.
- **Toda varredura de texto que os dois gates usem para afirmar ausência roda com `-a` e com contador de universo publicado.** É LDG-0177: `template/.forge/scripts/lib/secret-scan.mjs` é invisível a `grep` sem `-a`. **A justificativa que a revisão 2 colava aqui — "ele está dentro do universo de `[2]` e do universo de `--help` por diretório" — é falsa, e o revisor a derrubou; medido na revisão 3:** o universo de `[2]` são os scripts que carregam `lib/arg-guards.sh` e têm sítio de valor, e o `secret-scan.mjs` não é um deles; o universo de `--help` são os catorze `*.sh` com dispatcher e usage, e o `secret-scan.mjs` não é `.sh`; e o glob `template/.forge/scripts/*.sh` não desce a `lib/` (`ls template/.forge/scripts/*.sh | grep -c 'lib/'` → 0). A regra permanece, com a justificativa certa: **quem varre não sabe de antemão qual arquivo do universo carrega byte de controle, e o preço de descobrir é uma conclusão errada em vez de um erro** — `-a` é grátis e a assimetria é o argumento inteiro.
- **O controle positivo plantado carrega byte de controle, e a asserção é o PAR.** A varredura com `-a` acha o controle **e** a mesma varredura sem `-a` NÃO o acha. Medido em §0: um controle de texto puro sai idêntico nos dois casos e portanto assegura a si mesmo — é a asserção que não pode falhar pelo motivo que a nomeia, e é o bloqueador 2 da revisão 2. O controle é plantado **na cópia da árvore sob `$TMPDIR`**, nunca em `template/` da árvore de trabalho, e as sentinelas `[15]` do Gate A e `[12]` do Gate B provam isso por `git status --porcelain`, que é o comando que pega arquivo não rastreado. O conteúdo do controle é um token de contexto de parsing — **nunca** um literal com forma de credencial, que seria plantar na fixture o achado que o `secret-scan.mjs` existe para pegar.
- O cenário `[10]` roda com os **três universos publicados pelo gate** — distinguibilidade nos catorze, nomeação em treze, `rc≠0` em treze/doze — e as duas isenções (`run-gates` na via de token inválido, `spec-advance-module` na cláusula de `rc`) aparecem **nomeadas na saída do gate**, com a razão, para que um leitor futuro veja a exceção em vez de a deduzir do contador. Uma isenção que o gate não imprime é um universo estreitado em silêncio.
- Os **seis** scripts que ganham a nomeação do token — `wave-ops`, `deferral-ops`, `red-evidence`, `check-red-first`, `graph`, `spec-transition` — têm a mensagem alterada **sem** alterar o literal de usage deles, e a varredura de `tests/` pelas strings correspondentes (com `-a`, controle positivo devolvendo 4 e universo de 188 arquivos) continua devolvendo zero depois do diff.
- Nenhuma asserção contém `arquivo:linha`. As citações de linha desta especificação são endereços para quem implementa, não predicados de gate.
- Se qualquer arquivo de `template/.forge/commands/` for tocado, `npm run build:plugin` é rodado e `tests/plugin-sync-gate.sh` fica verde.
- `CHANGELOG.md` registra as oito quebras de §10, cada uma com a linha de correção para o consumidor, **e** a quebra dos dois testes locais do `axis-fare-validator`, com a asserção upstream que substitui cada um.
- #133, #136, #128 e #129 fechadas por `gh issue close` com comentário que cita nominalmente o que reproduziu, o que **não** reproduziu, e o gate que morde se voltar. O comentário de #133 corrige o corpo defasado quanto à existência de `lib/argparse.sh` no produtor e aponta L1 como dono do mecanismo da regressão.
- A Onda E volta à bancada com as quatro mudanças de §7, e as duas ondas são implementadas na ordem declarada em §5.5.
- Nenhum texto de coautoria de IA em commit, PR ou issue. PR contra `develop`.

---

## 14. Respostas ao veredito da revisão 1

O revisor reproduziu, por comando próprio e em bancada isolada, essencialmente toda a base factual desta especificação, e reprovou a **costura do gate**, não a base. As respostas abaixo seguem essa ordem: primeiro os quatro bloqueadores, depois as sete medições que ele listou como sem lastro, depois as ressalvas. Onde eu aceito, digo o que mudou e onde. Onde eu refuto, colo a medição.

### 14.1 Os quatro bloqueadores — todos aceitos, todos fechados

**BLOQUEADOR 1 — `[9]` contra `[11]`, e D7 contra D6. ACEITO, e a asserção foi reescrita.** Remedi os dois lados antes de aceitar, porque refutar com medição é legítimo neste plano e eu queria saber se havia refutação a fazer. Não havia: `template/.forge/scripts/run-gates.sh:110` fecha com `echo "OK"` sem `exit` explícito (`rc 0`) e `:82-83` faz `echo "NO-GATES"; exit 0`, de modo que execução bem-sucedida sai `0` nos dois caminhos; com D6, `--help` também sai `0`. As duas asserções exigiam `0` e `≠0` da mesma invocação e nenhuma implementação correta passaria nas duas. O revisor está certo em cada palavra.

O que ele também disse, e que é a parte útil, é que o defeito **sobrevive por `rc` mesmo depois de D6** — logo a propriedade precisava ser escrita sobre o que discrimina de fato. Medi o que discrimina, e é melhor do que eu esperava:

```
$ bash .forge/scripts/run-gates.sh --help 2>/dev/null | tail -1              → NO-GATES
$ bash .forge/scripts/run-gates.sh id-que-nao-existe 2>/dev/null | tail -1   → NO-GATES
$ cmp <(… --help …) <(… id-que-nao-existe …)                                 → (idênticas)
```

As duas saídas são **byte a byte idênticas**, e a última linha é o que o idioma documentado no cabeçalho do próprio script (`:6-7`, `:23-24`) consome por `| tail -1` e carimba no `waves.json` via `wave-ops.sh close --gate`. Pedir ajuda ao executor de gates hoje devolve um **veredito de wave**. A asserção `[11]` passa a ser sobre isso — a saída de `--help` difere da da execução, e a última linha dela não é `OK`, `FAIL` nem `NO-GATES` —, é satisfazível junto com `[9]`, não usa literal de `rc`, e continua mordendo se alguém "consertar" o `--help` de um jeito que ainda entregue veredito. D7 foi reescrita inteira (§2.4).

**BLOQUEADOR 2 — `SCEN` do Gate A em 18 contra as quatro mutações de §8.1. ACEITO.** Confirmei por comando — `awk '/^### 8\.1 /{f=1} /^### 8\.2 /{f=0} f' "$F" | grep -aoE '^\| M[0-9]+'` devolve `M1`, `M2`, `M3` e `M4` —, §13.1 passo 6 dizia "as mutações M1-M4" e §12-C dizia "as seis linhas das matrizes de §8" (4+2). Três rótulos para quatro provas, num número comparado por **igualdade**, recusaria a implementação correta pelo próprio contador de controle. Corrigido: `[16]–[19]`, um rótulo por mutação, `SCEN` do Gate A = **19**, recontado em §6.4 com os quatro comandos (o `seq` agora lista `17` e `18` como ausentes do texto, os dois dentro da notação de intervalo). §8.1 ganhou a linha que fixa a alocação, e §13.1 e §13.2 acompanham.

**BLOQUEADOR 3 — dono do laço de recusa em `deferral-ops.sh test`/`status`. ACEITO, e fechado por decisão de dono, não por ordem de merge.** A revisão 1 dizia em §1.3 que "esta onda NÃO duplica esse trabalho" e mandava implementá-lo em §13.1 e nos cenários `[7]`/`[8]` — contradição literal, e o revisor mostrou o agravante que eu não tinha visto: `[7]` e `[8]` não estavam na lista de §6.3, então, se a Onda E mergeasse primeiro, eles estariam verdes na hora de observar o vermelho, que é exatamente a omissão que §6.3 existe para impedir.

A decisão é **D17** (§1.4): os ramos `test)` e `status)` de `deferral-ops.sh` passam a L4 e saem da decisão 11 da Onda E, que fica com as duas portas de `ledger-ops.sh`. A razão é medida, e é de atomicidade — as duas metades do ramo `test)` mudam o desfecho da invocação legítima em direções opostas:

```
laço SEM o shift  →  test <change> DEFER-01  rc=1  FAIL: argumento inesperado 'DEFER-01'
laço COM o shift  →  test <change> DEFER-01  rc=0  OK test — DEFER-01 marcado como tested
```

Duas ondas escrevendo metades diferentes do mesmo ramo em dois PRs produzem uma janela com `w51` vermelho no tronco, em **qualquer** ordem de merge. Um dono só, um commit, fecha a janela por construção. E a partição tem um ganho que eu não esperava ao começar a medir: com ela **as duas ondas deixam de editar qualquer arquivo em comum** — L4 fica com `deferral-ops.sh` e `wave-ops.sh`, a Onda E com `ledger-ops.sh` —, e a coordenação de rebase de §5.5 deixa de ser necessária. O acoplamento que sobra é uma convenção, o literal `(nenhuma)`, e medi que ela não exige mudança nenhuma em `lib/arg-guards.sh`. §1.3, §5.1, §5.2, §5.5, §6.3, §7 e §13.1 foram reescritas.

**BLOQUEADOR 4 — o denominador de `[2]` e o `wave-ops.sh` com zero sítios. ACEITO.** A leitura do revisor está certa nas duas pontas: por script, `wave-ops.sh` reprova a implementação correta por ausência de sítios que nunca existiram; agregado, um dos quatro pode cair a zero sozinho e ninguém vê — que é justamente o que o piso deveria vigiar. O texto não fechava o denominador e as duas leituras eram defensáveis.

Fechado em letra, abaixo da tabela de §6.1, com o censo dos quatro scripts colado: `wave-ops.sh` sai do universo de `[2]` (zero sítios que consomem `"$2"`, medido, e D5 já o admitia "apenas para P1") e continua dentro de `[8]`, que é P1 e onde ele tem porta aberta medida. O denominador de `[2]` passa a ser **híbrido, com as duas metades obrigatórias**: piso sobre o **agregado dos três** scripts que têm sítio, e guarda de vacuidade **por script**. E o gate deriva a lista dos scripts que **têm** sítio em vez de a carregar escrita, de modo que `wave-ops.sh` entra sozinho no dia em que ganhar um.

> **Corrigendum da revisão 3, e ele é normativo:** este predicado, aplicado como escrito, devolve **catorze** scripts e não três — onze deles com `guardados = 0` e fora do alvo desta onda —, e faria a implementação correta reprovar. O escopo derivado que vale é o de §6.1: *carrega `lib/arg-guards.sh` **e** tem ao menos um braço que consome `"$2"`*. A medição e a razão da conjunção estão em §15.1.



### 14.2 As sete medições sem lastro — cinco remedidas, uma requalificada, uma removida

| # | Medição | Desfecho |
|---|---|---|
| 1 | SHAs de bancada `fd79994`/`e67ffa8` (§3.1, M5) | **remedida** — bancada remontada, SHAs desta rodada (`af74fd5`/`a441c2b`) com o comando de criação das duas árvores colado, e a nota em letra de que os literais são testemunha de bancada e não entram em asserção |
| 2 | Ordinal máximo w207 nas refs (§0) | **remedida** — laço sobre `git for-each-ref` mais `git ls-tree` por ref, com a saída das oito refs colada |
| 3 | Variantes `semshift`/`comshift` (§5.1) | **remedida** — reexecutadas em bancada, com digest antes/mutado/depois, `cmp` byte a byte e recontrole verde, tudo colado |
| 4 | 741/163 sobre 13.443 arquivos (§4.4, D16) | **requalificada** — não reproduzi e não posso: a árvore é do consumidor e o mandato é leitura apenas nela. Troquei o número solto pelo **endereço citável** — `blobs/76d4bb35…-corpo-censo.md:25`, mensagem `axis-go-cloud-0044`, thread `upgrade-desarma-o-proprio-ponto-de-entrada` — e mantive em letra que é medição de terceiro que não vira decisão desta onda |
| 5 | Piso de 23 subcomandos nos testes locais do `axis-fare-validator` (§10) | **remedida** — li os dois arquivos e colei `SUBCOMANDOS_ESPERADOS = 23` em `:233`, a comparação em `:251` e a mensagem de `:252`, mais o `readUniverse` que lê `_ap_ctx` dos três scripts. A previsão fica precisa: `UNIVERSE.length` vai a zero e a mensagem é *"universo com 0 subcomando(s); esperados 23"* |
| 6 | Contagens internas dos consumidores (5, 13, 32) (§10) | **remedidas** — reexecutadas com `-a`, reproduzem |
| 7 | Afirmações sobre gates não executados (w150, w200, w51) (§2.4, §5.4) | **remedidas por leitura, com os endereços corrigidos** — a derivação de `w150` é `:204-209` (a revisão 1 citava só `:204`), o piso `-ge 20` é `:248` e o `rc 99` é `:243`; `w200[6]` compara por igualdade em `:258-271`. E acrescentei o que faltava e que muda a restrição: `n_labels` é **exatamente 20** contra um piso de 20 — folga zero nas duas direções |

E uma medição da revisão 1 que ninguém cobrou e que eu **removi por conta própria**, porque a remedição a desmentiu: a afirmação de que cinco árvores de consumidor estão em `0.14.0`. São três — `grep -an 'template_version' ~/Documents/projects/azim-crm/.forge/forge.yaml` devolve `0.1.0-rc24`, não `0.14.0`. A tabela de `cmp` de §10 mudou junto, em duas linhas: o `azim-crm` **diverge** em `liaison-ops.sh` e `deferral-ops.sh` (a revisão 1 o dava como idêntico nos quatro), e o `lionclaw`, que ela nem listava, é a única árvore byte a byte idêntica ao template nas quatro peças.

### 14.3 A varredura de ausência, refeita sob o achado LDG-0177

O orquestrador mediu que `template/.forge/scripts/lib/secret-scan.mjs` é invisível a `grep` sem `-a`, e que isso já produziu conclusão errada nesta rodada. Confirmei na minha árvore — `grep -rln AKIA template/` devolve 2 e `grep -arln AKIA template/` devolve 3 — e refiz **todas** as varreduras de ausência desta especificação. São cinco. **A revisão 2 escreveu que cinco delas apontam para dentro de `template/.forge/scripts/lib/`, e a revisão 3 mediu que são duas** — o §0 traz a medição e a correção do preâmbulo. O inventário, com o universo de cada uma: `_ap_ctx`/`_ap_value`/`_ap_unknown`/`argparse_guard_value` sobre `template/ tests/ installer/ bin/`, recursiva (§0) — **tem o `secret-scan.mjs` no universo**; o usage dos cinco scripts sobre `tests/` (§2.4) — não desce a `lib/`; `--root` sobre `tests/*.sh` e `template/.forge/scripts/*.sh` (§3.4) — glob, não desce a `lib/`; `validate-naming` sobre `template/.forge/scripts/lib/sync-adapters.mjs` e o `pre-commit` (§4.3) — **dentro de `lib/`, mas o universo é um arquivo nomeado, e não é o `secret-scan.mjs`**; e `--help` sobre `template/.forge/commands/` (§10) — não é `lib/`.

**Nenhuma mudou de resultado.** Mas o valor da refação não é o resultado, é que agora existe prova de que a varredura leu o universo — e ela é um controle positivo plantado numa cópia sob `$TMPDIR` que a varredura precisa achar, colado no preâmbulo do §0. A revisão 1 não podia afirmar isso; ela distinguia dois estados onde há três.

### 14.4 As ressalvas — sete acatadas, com o que mudou

1. **`node-baseline`/`dotnet-baseline` "não têm dispatcher".** Falso, e o revisor tem razão: os dois **entram** pela primeira cláusula (`case "$1" in` em `:36` e `:33`) e saem pela segunda, `usage=0`. §2.2 reescrita.
2. **Não são dois scripts que tratam `-h|--help`, são três.** `grep -arlE` devolve também o `doctor.sh`, que trata em `:25` — e `tests/snapshot/claude-contract.bats:220-227` já assegura `--help → 0` **e** argumento desconhecido `→ 2` nomeando o argumento. É o adotante instalado mais forte do idioma que a onda adota, e agora D6 se apoia nele em vez de o ignorar.
3. **A primeira cláusula seleciona qualquer `case` sobre `$1`, não "dispatcher de subcomando".** Acatado, e medi que são **cinco** (não quatro) os membros em que o token é consumido antes de qualquer `case`: `approval-log`, `spec-new`, `spec-transition`, `spec-close` e `run-gates`. §2.3 ganhou o parágrafo e os endereços; a conclusão "primeiro ramo do dispatcher" deixou de ser a prescrição.
4. **`[12]` e a folga de `w150`.** Endereços corrigidos e a folga medida: `n_labels` é exatamente 20 contra piso 20. Acrescentei a direção que faltava — documentar `--help` naquele bloco criaria um rótulo sem invocação e reprovaria com `rc 99` por `:243` —, de modo que a restrição é **não mexa no bloco**, não "não o encolha".
5. **"Nenhum número literal no fonte dos gates" contra as prescrições de piso.** A regra se contradizia. Reescrita no preâmbulo de §6, distinguindo contagem comparada por **igualdade** (proibida, salvo os dois `SCEN`) de **piso contra vacuidade** (literal, deliberadamente folgado), com `w150[5]` como o modelo bom e `w150[4]` como o exemplo do piso colado que não deve ser imitado.
6. **§3.4 mede contra dois gates e a classe tem cinco.** Acatado: `grep -arln 'run-manifest' tests/*.sh` devolve `w32`, `w80`, `w90`, `w91` e `w92`, e conferi que nenhum dos cinco passa `--root`. A varredura agora **deriva** o universo em vez de o nomear, e §13.2 exige os cinco verdes.
7. **`[5]` do Gate B não dizia que a asserção é sobre a invocação direta do `.mjs`.** Acatado: a célula agora o diz e explica por que `[2]` não colide — pelo wrapper, D10 manda anexar a raiz e a ausência de `--root` continua `rc 0`.
8. **O endereço do laço de `resolve` em `deferral-ops.sh`.** Reconferido: `grep -an 'while \[ \$# -gt 0 \]'` devolve `62` e `93`. A revisão 1 dizia `:61-68` e `:92-93`, errando a primeira linha de cada. Corrigido em §1.3.

### 14.5 O que a revisão 2 achou por conta própria, remedindo

Três coisas, e as três mudam texto normativo.

**A base estava no commit errado.** A revisão 1 declarava `HEAD` em `1e28514`; a branch de trabalho está em `cf3bbe4`, e `git diff --name-only 1e28514..HEAD -- template/` devolve quinze arquivos, **dois deles alvos desta onda**. Reexecutei o censo inteiro contra `cf3bbe4` e ele reproduz número por número e linha por linha, então nenhuma conclusão muda — mas o endereço passa a ser o da árvore em que a onda será implementada, e as outras quatro peças foram provadas idênticas entre os dois commits, arquivo a arquivo.

**D6 prescrevia canal que nove dos catorze não têm.** Ela dizia que "o caminho sem argumento e o de comando desconhecido **continuam** em stderr". Medido sobre o universo inteiro: cinco membros imprimem a via de erro em stderr e **nove** em stdout. "Continuam" era falso para nove, e cumprir a frase realocaria canal em nove scripts cujo raio de quebra esta onda não mediu. D6 foi reescrita para não mover canal de erro nenhum, `[10]` perdeu a asserção de canal, e a heterogeneidade virou item de §11 com a medição pronta. É a única mudança desta revisão que **reduz** escopo, e ela reduz por medição.

**O contrafactual de `run-gates` é mais forte do que a revisão 1 sabia.** Ao remedir o bloqueador 1 descobri que `--help` e `<id-inexistente>` não apenas compartilham o `rc`: as saídas são **byte a byte idênticas** e a última linha é `NO-GATES`, que é o token de veredito que o chamador documentado carimba no `waves.json`. O defeito não é "ajuda sai zero", é "ajuda devolve veredito" — e a asserção nova morde essa, que é a que importa.

---

## 15. Respostas ao veredito da revisão 2

O revisor da revisão 2 reproduziu por comando próprio, em bancada isolada, praticamente tudo o que a revisão 2 remediou — os quatro bloqueadores da revisão 1, a partição D17 com as duas variantes de mutação, o `SCEN` de 19 e 14, o denominador híbrido de `[2]`, as sete medições sem lastro e a base factual inteira dos quatro defeitos. Ele reprovou dois pontos, e os dois são reais: um deles é a mesma família que a revisão 1 já havia bloqueado uma vez, remediada numa asserção e deixada de pé na irmã. Abaixo, os dois bloqueadores, as medições que ele declarou não ter feito, e as sete ressalvas. Onde aceito, digo o que mudou e onde; onde meço algo diferente do que ele mediu, colo o comando.

### 15.1 Os dois bloqueadores — aceitos, fechados, e o segundo achou um defeito maior

**BLOQUEADOR 1 — o cenário `[10]` exige `rc≠0` de vias que dois membros não têm. ACEITO.** Remedi antes de aceitar, e reproduz nas duas pontas. `bash .forge/scripts/run-gates.sh comando-invalido-xyz` devolve `rc 0` e a linha de `NO-GATES`, e §11 proíbe em letra consertar isso (LDG-0160, invariante 18, Onda K é dona); `bash .forge/scripts/spec-advance-module.sh` sem argumento devolve `rc 0` e `SKIP (usage: …)`, e a linha 18 do cabeçalho do próprio script declara *"sempre exit 0 (não derruba a onda)"* como contrato do `/forge:coding-loop`. Ele tem razão também no diagnóstico de forma: é o bloqueador 1 da revisão 1 outra vez, resolvido em `[11]` e deixado em `[10]`, contra o mesmo script.

Peguei a saída que ele mesmo indicou — a de D7, escrever sobre distinguibilidade em vez de sobre `rc` — **e a completei com o censo que faltava**, porque medir para responder mostrou que o problema é maior do que duas isenções: a cláusula "nomeando o token recusado" também não descreve o estado de oito dos catorze. Medi as duas vias nos catorze com um token que cada script consiga reconhecer como inválido (`subcmd-xyz` nos nove com dispatcher, `NAO_KEBAB_XYZ` nos cinco em que o primeiro token é change-id):

```
nomeiam hoje (6):  liaison-ops  ledger-ops  gate-ordinal  approval-log  spec-new  spec-close
não nomeiam (8):   wave-ops  deferral-ops  red-evidence  check-red-first  graph  spec-transition
                   run-gates (rc 0)   spec-advance-module (rc 0)
```

Desses oito, dois saem por isenção declarada e um sai por fixture: o `spec-advance-module` **nomeia** no ramo que de fato existe, o de dois tokens (`SKIP (fase inválida: fase-xyz — …)`), e é só a forma de um token que cai no usage. Sobram **seis** que ganham a mensagem nesta onda, e são exatamente os seis que o revisor listou.

`[10]` foi reescrito com **três cláusulas de universos declarados e diferentes** — distinguibilidade nos catorze, nomeação em treze, `rc≠0` em treze na via sem-argumento e doze na via de token inválido —, com as duas isenções **nominais, medidas e impressas pelo gate**, e com os seis scripts que ganham a nomeação registrados na tabela de "o que quebra" de §10, que não os listava. D6 ganhou o censo colado, §11 registra as duas isenções como trabalho medido e não feito, §13.1 passo 5 e §13.2 acompanham. A decisão que ele apontou como não tomada está tomada aqui, na spec, e não devolvida ao implementador.

**BLOQUEADOR 2 — o controle positivo de §0 não discrimina o defeito de LDG-0177. ACEITO, e ao medir para responder achei um defeito maior no denominador de `[2]`.** Reproduzi o contraste exato dele: `printf '_ap_ctx CONTROLE-POSITIVO-L4\n' > …/CONTROLE.txt` é achado por `grep -arln` **e** por `grep -rln`, enquanto `printf 'x\000y_ap_ctx CONTROLE-BINARIO-L4\n'` é achado só pelo primeiro. O controle de texto puro assegura a si mesmo — a asserção não pode falhar pelo motivo que a nomeia. §0 foi reescrito: o controle carrega byte de controle e **a asserção é o par**, com `-a` acha e sem `-a` não acha; §13.2 fixa isso como linha de definição de pronto, junto com a restrição de que o controle é plantado na cópia sob `$TMPDIR` e as sentinelas o provam por `git status --porcelain`, que é o comando que pega arquivo não rastreado.

Ele também mostrou que a justificativa colada em §13.2 — *"ele está dentro do universo de `[2]` e do universo de `--help` por diretório"* — não reproduz, e está certo: o `secret-scan.mjs` não é `.sh`, não carrega `arg-guards.sh`, e o glob `template/.forge/scripts/*.sh` não desce a `lib/` (`ls template/.forge/scripts/*.sh | grep -c 'lib/'` → 0). A regra do `-a` permanece com a justificativa certa, que é de assimetria de custo e não de pertencimento: quem varre não sabe de antemão qual arquivo do universo carrega byte de controle, e o preço de descobrir é uma conclusão errada em vez de um erro.

**O defeito maior, e ele é meu:** ao remedir o universo de `[2]` para responder, apliquei o predicado como a revisão 2 o escrevia — *"o gate deriva a lista dos scripts que **têm** sítio"* — sobre o diretório inteiro, e ele devolve **catorze** scripts, não três. Onze deles têm `guardados = 0` e não são alvo desta onda: `approval-log` com 7 sítios, `spec-new` com 6, `spec-close` com 3, e mais oito. Um gate escrito assim reprovaria a implementação correta em onze scripts intocados — é o bloqueador 4 da revisão 1 outra vez, entrando pela porta oposta. §6.1 tem agora o predicado de escopo derivado (*carrega `lib/arg-guards.sh` **e** tem ao menos um braço que consome `"$2"`*), que devolve exatamente os três, e a conjunção é obrigatória porque `forge_reject_unknown` mora naquela biblioteca: o `wave-ops.sh`, ao ganhar o laço de P1 que a D5 lhe dá, passaria a carregá-la e entraria no universo com `total = 0`, reprovando a própria correção desta onda.

### 15.2 As medições que o revisor declarou não ter feito

Ele foi explícito sobre o que não executou, o que é a atitude certa e o que torna o veredito auditável. Remedi cada uma por conta própria, e todas confirmam a leitura dele:

| o que ele leu sem executar | minha remedição, revisão 3 | desfecho |
|---|---|---|
| `w150:204-209` deriva LABELS; piso `-ge 20` em `:248`; `return 99` em `:243`; `n_labels` = 20 | `sed -n '204,209p'` mostra a derivação com o `awk`; `grep -an '\-ge 20\|return 99'` devolve `248` e `243`; a derivação rodada contra o `liaison-ops.sh` de hoje devolve **20** | confirmado nos quatro pontos |
| `w200:259-267` compara badge e árvore por igualdade; os dois em 131 | `grep -an 'badge_n=\|arvore_n='` devolve `259` e `260`, a mensagem de FAIL em `268`; `ls tests/*-gate.sh \| wc -l` → **131** e `grep -oE 'gates-[0-9]+' README.md` → `gates-131` | confirmado |
| `w51:112` é `deferral-ops.sh test w51-test DEFER-01 \| grep -q "OK test"` | `sed -n '112p'` devolve exatamente essa linha | confirmado |
| `w131:194-198` invoca `wave-ops.sh close chg W1 --gate OK` | **a substância é dele, o endereço é outro**: `:194` é comentário e `:198` é o corpo do helper (`close chg "$@"`); o sítio de chamada com a flag é `:222` (`--gate OK`) e há um segundo em `:253` (`--gate FAIL`) | confirmado com o endereço corrigido, e virou restrição em §1.4/D5 e §13.2 |
| `doctor.sh:25-28` trata `-h\|--help` com `exit 0` e recusa desconhecido com `exit 2` nomeando; `claude-contract.bats:220-227` assegura os dois; `run-all.sh:93-95` pula bats sem o binário | `sed -n` nos três endereços devolve exatamente o que ele descreve | confirmado |
| SHAs `af74fd5`/`a441c2b` não são reproduzíveis; o **fenômeno** é | bancada nova: wrapper `709d0ac`, chamador `4c2d599`; wrapper grava sob a própria raiz com `"head_sha": "709d0ac0…"`, `.mjs` direto grava sob a outra com `"4c2d599d…"` | fenômeno reproduzido pela terceira vez, com o terceiro par de SHAs; §3.1 e M5 registram |
| 741/163 sobre 13.443 é medição de terceiro, não reproduzível sob mandato read-only | mantida como **requalificada**, com o endereço citável que ele mesmo confirmou no log (`axis-go-cloud-0044`, thread `upgrade-desarma-o-proprio-ponto-de-entrada`, `trust: untrusted-peer`) | permanece fora de decisão desta onda |
| os dois testes locais do `axis-fare-validator` caem para universo zero — previsão não executada | permanece **previsão declarada**, sustentada por leitura: `SUBCOMANDOS_ESPERADOS = 23` em `:233`, `UNIVERSE.length < SUBCOMANDOS_ESPERADOS` em `:251`, a mensagem em `:252` e o `readUniverse` por regex de `_ap_ctx` | executá-la exigiria escrita em árvore de consumidor; §10 já a diz como previsão |

### 15.3 As oito ressalvas — todas acatadas

1. **§12-A ainda carregava "doze, cinco delas em `0.14.0`"**, quatro linhas depois de declarar a correção para três. É o resíduo exato do item que a revisão 2 dizia ter removido. Remedido — `axis-fare-validator`, `axis-go-cloud`, `lionclaw` — e a frase corrigida.
2. **§10 abria a tabela com "cinco árvores" e a tabela tem seis linhas.** Remedido com o laço que conta: são **seis** as árvores que carregam os quatro artefatos, e a prosa foi ao número que a tabela sempre teve.
3. **§14.3 dizia que as cinco varreduras de ausência apontam para dentro de `lib/`.** Não apontam: são **duas** — a de `_ap_ctx`, recursiva em `template/`, e a de `validate-naming`, cujo universo é um arquivo nomeado dentro de `lib/` que não é o `secret-scan.mjs`. §0, §12-D e §14.3 corrigidos, com os comandos que separam cada universo. Ele registra que o erro está na direção segura, e concordo — mas ele sustentava a justificativa frouxa do bloqueador 2, então sai.
4. **`[12]` vigiava só a ponta de baixo, e o piso está em `:248`, não em `:204`.** Acatado nas duas metades. A célula de `[12]` ganhou a ponta de cima — *nenhum rótulo derivado do bloco começa por `-`* —, e ela tem contrafactual **medido por mutação**: acrescentando a linha `#   liaison-ops.sh --help` ao bloco, `n_labels` vai de 20 a 21 e os rótulos com hífen de 0 a 1, com digest antes/mutado/depois, `cmp` e recontrole verde (§2.4). O endereço do piso foi corrigido dentro da célula.
5. **O denominador híbrido de `[2]` tinha cláusula nascida morta.** Acatado, e a resposta está em §15.1: as três guardas passam a medir quantidades **diferentes** — `n_membros` do escopo (piso 3), `guardados == total` por membro (igualdade entre dois contadores derivados, no modelo de `w150[5]`), e `soma(total)` (piso folgado 40). A forma viva de "um dos três caiu a zero sozinho" é a primeira, não a que estava escrita.
6. **D6 exigia nomeação que seis dos catorze não têm, e §10 não listava o trabalho.** Acatado. Meu censo devolve **oito** que não nomeiam, dos quais dois são as isenções de `[10]` e **seis** ganham a mensagem nesta onda — os mesmos seis que ele nomeou. A varredura de `tests/` pelas sete strings, com `-a`, devolve zero arquivo, com controle positivo devolvendo 4 e universo de 188 arquivos publicado; o risco da invariante 15 é vazio de fato, e o escopo agora está declarado em §10 e em §13.2.
7. **A retrocompatibilidade de `wave-ops.sh` não estava medida com o rigor da do `run-manifest`.** Acatado. §1.4/D5 traz agora o conjunto declarado por subcomando, derivado e não escrito à mão: `--gate` é o **único** literal de flag do arquivo inteiro e o único sítio dele fora de comentário está em `:152`, no ramo `close`; `plan`, `open` e `status` ficam com `(nenhuma)`. `w131` entrou na lista de gates que rodam sem edição e ficam verdes, com os dois sítios que importam nomeados (`:222`, a invocação legítima com `--gate OK`; `:207-210`, que reprova recusa cuja mensagem contenha `Usage`).
8. **§1.2 misturava linhas de invocação com sítios.** Acatado, e resolvido pela via que fortalece em vez de reescrever a conta: medi os dois sítios que faltavam (`:1190` `--remote` e `:1191` `--branch`) e a tabela passa a ter **uma invocação por sítio, onze para onze**. Os números mudam com ela — **dois** dos onze saem `rc 0` e **nove** saem `rc≠0` pelo motivo errado —, e o nove propaga para D2, para a célula de `[4]` e para o passo 4 de §8.3, onde ele é o argumento de por que a asserção é sobre a mensagem.

### 15.4 O que esta revisão mudou por conta própria, remedindo

Duas coisas, e as duas são normativas.

**O predicado de derivação de `[2]` devolvia catorze scripts, não três** (§15.1). É o achado mais caro desta rodada e ele só apareceu porque a ressalva 5 me obrigou a rodar o predicado como estava escrito em vez de o reler. O escopo derivado passa a ser a conjunção de duas cláusulas, e a segunda existe especificamente para que a implementação de P1 no `wave-ops.sh` não reprove a si mesma.

**A cláusula de nomeação de D6 custava trabalho de mensagem em seis scripts que nenhuma seção listava** (§15.1). O revisor a levantou como ressalva; ao medir, ela virou parte do bloqueador 1, porque um universo declarado como "todo membro" que só descreve seis de catorze tem o mesmo defeito das duas isenções — a diferença é que aquele o implementador podia fechar escrevendo mensagem, e este não podia fechar de jeito nenhum.
