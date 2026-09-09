# Onda L2 — heavy-mutex: os dois relógios e a posse órfã (especificação implementável)

Autor: especificador do subgrupo L2 da Onda L. Data: 2026-09-07. Base medida: branch `feat/fase1-dogfood-completo`, `template/.forge/scripts/lib/heavy-mutex.sh` com 932 linhas (`wc -l`), sha256 `f84a84ed55fd…`.

Escopo: issues **#137** (o teto de espera de quem aguarda contra o teto de posse de quem detém) e **#144** (o `pre-push` órfão que continua segurando o lock depois que o `git push` morre). As duas são medições de campo dos consumidores, e a régua da Onda L manda reproduzi-las **aqui, no template**, antes de especificar correção — porque o backlog já registra, em LDG-0161, na #101 e na #131, que a cópia instalada diverge da árvore do produtor.

Reproduzi. E o resultado da reprodução é o achado mais importante deste subgrupo: **a #137, como está escrita, NÃO reproduz no template — porque o mecanismo que ela descreve não existe aqui.** A seção 1 mede isso, nomeia de onde vieram as duas medições de campo, e mostra que o defeito do template é da mesma família e **pior** do que o descrito.

Nenhum gate da suíte foi executado na elaboração desta especificação — `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio. Toda bancada rodou sob `$TMPDIR`, com `cwd` dentro da fixture, e a trava `FORGE_HEAVY_MUTEX_TESTING=1` da própria biblioteca garante que nada tocou o lock real da máquina.

**Regra de método, que é a invariante 19 do plano-mestre.** Esta especificação declara a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir. Onde há comando exato, ele veio de execução minha e a saída está colada. Onde não rodei, digo que não rodei. Esta onda tem uma razão extra para essa disciplina: quatro das decisões de desenho abaixo mudaram **depois** de a bancada contradizer o que eu ia escrever, e a seção 2 é literalmente a lista dessas contradições.

---

## 0. Resumo do que muda

| Peça | Arquivo | Natureza |
|---|---|---|
| Recuperação de posse por **beneficiário morto** (fecha #144) | `template/.forge/scripts/lib/heavy-mutex.sh` | comportamento novo |
| Recuperação de posse por **idade**, com teto derivado do teto de espera (fecha #137) | `template/.forge/scripts/lib/heavy-mutex.sh` | comportamento novo |
| Encerramento do detentor com escalada `TERM → graça → KILL` e **remoção só depois de morte confirmada** | `template/.forge/scripts/lib/heavy-mutex.sh` | primitivo novo, sem caminho destrutivo sobre detentor vivo |
| `--beneficiary <pid>` com validação numérica; `--label` vazio recusado | `template/.forge/scripts/lib/heavy-mutex.sh` | contrato de argumento ampliado |
| `forge_heavy_mutex_status` distingue posse legítima, órfã por beneficiário e estagnada | `template/.forge/scripts/lib/heavy-mutex.sh` | terceiro estado no diagnóstico |
| O hook declara o beneficiário (`--beneficiary "$PPID"`) | `template/.forge/hooks/git/pre-push` | fiação — é o canal onde os dois defeitos foram medidos |
| `heavy_mutex.stale_after_s` publicado, e `heavy_mutex.root` aceitando o token que o leitor já aceita | `template/.forge/schemas/forge.schema.json` | contrato publicado |
| Bloco `heavy_mutex` documentando a chave nova | `template/.forge/forge.yaml` | config entregue |
| Gate do subgrupo | `tests/w<NNN>-heavy-mutex-posse-gate.sh` (novo) | ordinal alocado pelo orquestrador |

Ordinais: o máximo publicado hoje é **w207**, medido com `for b in origin/develop origin/main HEAD origin/wip/deepspec-run-manifest-ldg-0165 origin/wip/upgrade-safety-ldg-0131; do git ls-tree -r --name-only "$b" tests/ | grep -oE '/w[0-9]+' | sed 's|/w||' | sort -n | tail -1; done` → `207, 207, 207, 80, 154`. O ordinal desta onda **não é alocado aqui**: a invariante 10 atribui a alocação ao orquestrador, no momento de escrever o arquivo, contra `origin/*` **e** contra as branches em voo desta rodada.

**Nenhum arquivo sob `template/.forge/commands/` é tocado**, então `npm run build:plugin` não entra nesta onda e o `plugin-sync-gate` não é afetado. A afirmação é medida e não suposta, em duas metades: o escopo do gate é `template/.forge/commands` contra `plugin/forge/commands` (linhas 18-20 e 36-37 do arquivo), e `grep -arln 'heavy_mutex' plugin/` devolve **vazio**, ou seja o espelho não carrega nenhuma cópia do que esta onda edita. Se a implementação decidir documentar as chaves novas num comando, a regeneração passa a ser obrigatória — e por `npm run build:plugin`, nunca por `build-plugin.sh`, que instala em `$HOME`.

---

## 1. A régua da Onda L — o que reproduz aqui, e o que não reproduz

### 1.1 #137 NÃO reproduz no template, porque o teto de posse não existe aqui

A issue afirma, em letra, que os dois valores são defaults do código e cita duas linhas:

```
lib/heavy-mutex.sh:802   local stale_after="${_s_env:-${_s_yaml:-3600}}"
lib/heavy-mutex.sh:803   local label="carga pesada" timeout="${_t_env:-${_t_yaml:-1800}}" waited=0 holder
```

No template a segunda linha existe — é a **729**, conferida com `sed -n '729p'` — e a primeira **não existe em lugar nenhum**. Duas varreduras, e a segunda existe porque a primeira sai vazia e **varredura vazia não prova ausência** (é a invariante 2 aplicada ao próprio instrumento, e o achado LDG-0177 desta rodada mostra um arquivo do template que some de `grep` sem `-a`):

```
$ grep -arn 'stale_after\|STALE_AFTER' template/ bin/ installer/ ; echo "rc=$?"
rc=1

$ grep -arn '_fhm_reclaim_orphan' template/ bin/ installer/
template/.forge/scripts/heavy-run.sh:108:        _FHM_LOCK="$HR_LOCK" _fhm_reclaim_orphan "$hp" && n=$((n+1))
template/.forge/scripts/lib/heavy-mutex.sh:614:_fhm_reclaim_orphan() {  # _fhm_reclaim_orphan <pid-esperado>
template/.forge/scripts/lib/heavy-mutex.sh:878:        _fhm_reclaim_orphan "$holder" || true
```

**Prova de que a varredura leu o universo, e ela é obrigatória em toda afirmação de ausência desta especificação.** O `-a` está em todas elas de propósito, e o universo foi enumerado em vez de suposto: `for f in $(git ls-files template/ bin/ installer/ tests/); do grep -qI . "$f" || echo "BINARIO-PARA-GREP: $f"; done` devolve 18 caminhos, dos quais 17 são `.gitkeep` de zero byte e **um** é conteúdo real — `template/.forge/scripts/lib/secret-scan.mjs`, que o `file` classifica como `data` porque o detector de binário dele carrega bytes de controle literais dentro do literal de regex. É o arquivo do LDG-0177, ele é o único ponto cego possível deste universo, e ele não contém nenhuma das strings desta onda (medido com `-a`, que o lê). O par comando/saída acima é o que a revisão 1 pegou errado: a especificação anterior colava três linhas de `_fhm_reclaim_orphan` debaixo de um comando que casa `stale_after`, e aquele comando devolve rc 1 com saída vazia.

O par de linhas citado pela issue é de **outra árvore**. Censo das cinco árvores desta máquina que têm a biblioteca instalada, refeito com `grep -ac`:

```
$ for d in ~/Documents/projects/*/; do f="$d.forge/scripts/lib/heavy-mutex.sh"; [ -f "$f" ] && \
    printf '%-20s | %4s linhas | stale_after(-a): %s | sha %s\n' "$(basename "$d")" \
    "$(wc -l < "$f" | tr -d ' ')" "$(grep -ac stale_after "$f")" "$(shasum -a 256 "$f" | cut -c1-12)"; done
axis-fare-validator  |  972 linhas | stale_after(-a): 0 | sha 54c174cc4d55
axis-go-cloud        |  932 linhas | stale_after(-a): 0 | sha f84a84ed55fd
Axis.PadSimulator    | 1082 linhas | stale_after(-a): 6 | sha 7ac8b542099b
azim-crm             |  932 linhas | stale_after(-a): 0 | sha f84a84ed55fd
lionclaw             |  932 linhas | stale_after(-a): 0 | sha f84a84ed55fd
template             |  932 linhas | stale_after(-a): 0 | sha f84a84ed55fd
```

O `stale_after` existe em **uma** árvore, a do `Axis.PadSimulator`, como **patch local não declarado**, e a linha 802 daquele arquivo é exatamente a linha citada pela issue:

```
$ sed -n '800,803p' ~/Documents/projects/Axis.PadSimulator/.forge/scripts/lib/heavy-mutex.sh
    esac
  fi
  local stale_after="${_s_env:-${_s_yaml:-3600}}"
  local label="carga pesada" timeout="${_t_env:-${_t_yaml:-1800}}" waited=0 holder
```

**O que isso significa, e é a conclusão que a régua da Onda L pede em letra.** A #137 descreve corretamente uma aritmética ruim — mas a aritmética é a de um **conserto local que o campo escreveu sozinho**, não a do produto. No template não há relação entre dois relógios porque só existe um relógio. E o estado do template é **pior** que o descrito pela issue: um detentor vivo que não libera bloqueia a máquina **para sempre**, porque toda a recuperação passa por `_fhm_alive`, e um detentor vivo, por construção, nunca é órfão para ela.

Reproduzi o estado do template com uma posse de 100.000 segundos e um detentor vivo, com o `cwd` dentro da fixture e a saída completa colada em §1.3, de onde estas duas linhas vêm:

```
idade da posse: 100000s | estado do dono: S
STALE_AFTER_S=<nao-definida>   rc=75 decorrido=6s lock-existe=SIM reaping-na-saida=0 mencoes-a-orfandade=0
STALE_AFTER_S=1                rc=75 decorrido=6s lock-existe=SIM reaping-na-saida=0 mencoes-a-orfandade=0
```

Duas leituras. A primeira é que a posse de vinte e sete horas **não é recolhida**: o esperante desiste com 75 e o lock permanece. A segunda é que `FORGE_HEAVY_MUTEX_STALE_AFTER_S` — a variável que a biblioteca do consumidor e a legada leem — é **inerte no template**: com ela em `1` o resultado é idêntico, incluindo o tempo decorrido. Um operador do campo que a exporte acreditando ter ajustado o comportamento não ajustou nada, que é a definição de config publicada sem leitor, invertida: aqui a variável sequer é publicada e mesmo assim já circula no ecossistema.

Consequência de método: **a correção não muda de lugar** — ela é do produto, aqui, upstream. O que muda é o diagnóstico que vai para a issue no fechamento: a #137 fecha com a correção da atribuição, e não com um `resolved` que finja que a aritmética `1800/3600` estava no template.

### 1.2 As duas medições de campo vieram da biblioteca LEGADA, e as strings provam

As duas issues colam a mesma mensagem de espera:

```
pre-push: aguardando o mutex da máquina (dono: 96410) para a suíte do pre-push.
pre-push BLOQUEADO: TIMEOUT após 1800s esperando o mutex da máquina (dono: 54025).
  Outra carga pesada está em execução. Aguarde, ou identifique o dono com: ps -p 54025
```

Nenhuma dessas strings existe no template, e a varredura que afirma isso vem com controle positivo, porque vazio sozinho não prova nada: `grep -arn 'aguardando o mutex da máquina' template/` devolve rc 1 e saída vazia, enquanto o **mesmo padrão** contra `~/Documents/projects/Axis.PadSimulator/.forge/hooks/git/lib/heavy-mutex.sh` devolve 1 ocorrência — o instrumento acha a string quando ela está lá. O template diz outra coisa: `heavy-mutex: AGUARDANDO — <label>` (linha 419) e `heavy-mutex: TIMEOUT após ${waited}s esperando o mutex da máquina.` (linha 884). As strings da issue existem, literais, naquele arquivo legado — 177 linhas, o protocolo que o `pre-push` daquele repositório usa (`heavy_mutex_acquire "a suíte do pre-push"`, linha 301 do hook dele), com `stale_after="${FORGE_HEAVY_MUTEX_STALE_AFTER_S:-3600}"` na linha 48 e a mensagem `Outra carga pesada está em execução` na 147.

Do outro lado do mesmo evento, o dump do lock em #137 traz `owner`, `label`, `state`, `acquired_at` e `cmd` — campos que **só** o `_fhm_claim` do template escreve (linhas 644-663) — e o `label` é `pre-push de axis-fare-validator`, que é literalmente o que `template/.forge/hooks/git/pre-push:245` monta com `--label "pre-push de $(basename "$ROOT")"`.

Então o evento medido em campo é **entre bibliotecas**: o detentor era o `pre-push` do `axis-fare-validator` com a biblioteca do harness, e o esperante que imprimiu as duas mensagens era o `pre-push` do `Axis.PadSimulator` com a biblioteca legada. Isso não invalida nada do que o campo mediu — invalida a **atribuição** de linha e de default, e é exatamente a divergência que a régua desta onda manda procurar antes de especificar.

### 1.3 #144 REPRODUZ no template, e pelo canal real

O mecanismo da órfandade reproduz num `git push` de verdade, com o hook do próprio git, em fixture sob `$TMPDIR` — repositório e remoto criados na bancada, hook `pre-push` que grava o próprio pid e o `$PPID` num arquivo e dorme, `git push` lançado em segundo plano e depois morto pelo pid que o hook registrou:

```
hook pid=37338 PPID=37331
cmd do PPID: /Applications/Xcode.app/Contents/Developer/usr/bin/git -C <bancada>/repo push -q file://<bancada>/remoto main
ppid do PPID: 37309
ANTES: hook=37338 ppid-do-hook=37331 | processo 37331 vivo? S
DEPOIS de matar o pai do hook: hook vivo? S | ppid do hook agora=1 | pai=morto
```

O hook sobrevive à morte do `git push` e é reparentado para o `launchd`, com `ppid` 1 — palavra por palavra o que a issue descreve. E a metade que interessa ao mutex também reproduz, com um detentor órfão segurando o lock, aqui montado como um `sleep` reparentado (`( cmd & )`) e um lock com `pid`, `token`, `nonce` e `acquired_at` de 100.000 segundos atrás:

```
orfao pid=51660 ppid=1 estado=SN cmd=sleep 600
idade da posse: 100000s | estado do dono: S
_fhm_alive: VIVO (rc 0) — nenhum caminho de reclaim se aplica
--- forge_heavy_mutex_status:
recurso ..... r13
lock ........ <bancada>/r13.lock (âncora: FORGE_HEAVY_MUTEX_ROOT (isolado — não serializa com o resto da máquina))
fila ........ DESLIGADA — 0 ticket(s) (disputa sem ordem)
detentor .... PID 51660 há 00:00
status rc=1
STALE_AFTER_S=<nao-definida>   rc=75 decorrido=6s lock-existe=SIM reaping-na-saida=0 mencoes-a-orfandade=0
STALE_AFTER_S=1                rc=75 decorrido=6s lock-existe=SIM reaping-na-saida=0 mencoes-a-orfandade=0
--- campos do lock apos aquisicao REAL sem contencao:
acquired_at cmd label nonce owner pid state token
```

Cinco fatos que a implementação usa, e o quinto só apareceu nesta remedição. O `_fhm_alive` classifica o órfão como **vivo**, e classifica certo — ele está vivo. O esperante desiste com 75 e o lock fica, com zero menções a órfandade na saída (contadas por `grep -cie 'orf\|estagnad\|benefici'`). O lock grava oito campos, **nenhum deles ligado a quem consome o resultado** — não há `ppid`, não há pid do processo servido —, então a informação que separaria "posse legítima" de "posse que não serve a ninguém" não é gravada e nenhum leitor pode inferi-la depois.

O quarto é que o `forge_heavy_mutex_status` anuncia o órfão como detentor normal, sem uma palavra sobre órfandade. E o quinto, que a revisão 1 desta especificação não tinha e que muda o que o cenário `[19]` precisa medir: **o "há 00:00" da linha de detentor NÃO é a idade da posse, é a idade do PROCESSO.** A linha 466 da biblioteca computa `age="$(LC_ALL=C ps -o etime= -p "$hp")"`, ou seja o `etime` do detentor, e nunca lê `acquired_at`. Na bancada acima a posse tem 100.000 segundos declarados e o `sleep` tinha acabado de nascer, e o status imprimiu `há 00:00` — os dois relógios do título desta onda já estão trocados dentro do diagnóstico de hoje. O estado "estagnada" que D5 introduz precisa ser computado de `acquired_at`, e o `[19]` precisa asseverar essa origem, senão o campo novo herda o número errado.

### 1.4 O `label` vazio do item 4 da #144 não vem do template

A issue observa que o `label` daquela aquisição saiu vazio e pede que ele seja sempre preenchido. Medi as três origens possíveis, com a biblioteca real do template em (A) e (B) e com a biblioteca legada do `Axis.PadSimulator` em (C), toda a bancada sob `$TMPDIR` e com `FORGE_HEAVY_MUTEX_TESTING=1` mais `FORGE_HEAVY_MUTEX_ROOT` nas duas primeiras:

```
=== A) template: --label "" produz label vazio?
rc=0 label=[] bytes=1
=== B) template: label default (sem --label)
label=[carga pesada]
=== C) biblioteca LEGADA (Axis.PadSimulator/.forge/hooks/git/lib/heavy-mutex.sh, 177 linhas), TMPDIR desviado para a bancada
rc=0
<bancada>/axis-heavy-suite.lock
acquired_at pid
```

O lock do protocolo legado **não tem arquivo `label`** — o `ls` do diretório em (C) devolve literalmente `acquired_at pid` e nada mais. Um diagnóstico que faça `cat "$lock/label"` sobre um lock legado imprime vazio porque o arquivo não existe, não porque alguém gravou vazio. A aquisição observada em #144 tinha `label` vazio e `ppid` 1: é um lock **legado**, e o item 4 da issue, tomado como defeito do template, não procede.

O que **procede** é um buraco menor e adjacente, medido em (A): o template aceita `--label ""`, devolve `rc 0` e grava um campo de diagnóstico de 1 byte (a quebra de linha). Isso é a classe da #103 (`forge_require_value` testando só `[ -n ]`) por um terceiro caminho, e fecha aqui com custo perto de zero — ver D8.

### 1.5 Um terceiro defeito, encontrado no caminho: o schema recusa o que o leitor aceita

Validando os `forge.yaml` dos cinco consumidores contra `$defs/forgeManifest` do `template/.forge/schemas/forge.schema.json`, com o mesmo `ajv` e as mesmas opções de `tools/validate-forge.mjs` (`new Ajv2020({allErrors:true, strict:true, allowUnionTypes:true})` sobre `withDefs($defs.forgeManifest)`), documento a documento e com o bloco `heavy_mutex` de cada um impresso ao lado do veredito:

```
$ node <script que compila o mesmo schema do validate-forge.mjs e valida os cinco forge.yaml>
axis-fare-validator   INVALIDA | erros-totais: 2 | erros-em-heavy_mutex: 1 | /heavy_mutex/root must match pattern "^/"
                        bloco heavy_mutex: {"enabled":true,"resource":"axis-heavy-suite","root":"${TMPDIR:-/tmp}","timeout_s":1800}
axis-go-cloud         INVALIDA | erros-totais: 1 | erros-em-heavy_mutex: 0
                        bloco heavy_mutex: {"enabled":false,"resource":"forge-heavy-suite","timeout_s":1800}
Axis.PadSimulator     INVALIDA | erros-totais: 3 | erros-em-heavy_mutex: 2 | /heavy_mutex must NOT have additional properties {"additionalProperty":"stale_after_s"} ; /heavy_mutex/root must match pattern "^/"
                        bloco heavy_mutex: {"enabled":true,"resource":"axis-heavy-suite","root":"${TMPDIR:-/tmp}","timeout_s":1800,"stale_after_s":3600}
azim-crm              INVALIDA | erros-totais: 1 | erros-em-heavy_mutex: 0
                        bloco heavy_mutex: undefined
lionclaw              INVALIDA | erros-totais: 1 | erros-em-heavy_mutex: 0
                        bloco heavy_mutex: {"enabled":false,"resource":"forge-heavy-suite","timeout_s":1800}
```

A coluna do bloco é o que torna a tabela auditável em vez de um veredito de fé, e ela já corrige uma afirmação que a revisão 1 desta especificação carregava: o `azim-crm` **não** declara bloco `heavy_mutex` nenhum, então ele não está com `enabled: false` por declaração e sim por default da biblioteca. Confirmado com controle positivo, porque uma varredura vazia não prova ausência: `grep -an -A6 'heavy_mutex' ~/Documents/projects/azim-crm/.forge/forge.yaml` sai sem casar, enquanto o mesmo comando contra o `lionclaw` devolve as linhas 99-102 (`heavy_mutex:`, `enabled: false`, `resource: forge-heavy-suite`, `timeout_s: 1800`).

Duas coisas, e as duas são da vizinhança exata desta onda.

A primeira é que a chave que o campo precisou inventar — `stale_after_s` — é **ilegal no contrato publicado**, porque o bloco `heavy_mutex` tem `additionalProperties: false`. O consumidor não tinha por onde declarar legalmente o que ele mediu ser necessário.

A segunda é uma paridade quebrada entre schema e leitor, da classe que o `w199` existe para fechar: `heavy_mutex.root` tem `"pattern": "^/"` no schema, e o **token literal** `${TMPDIR:-/tmp}` é o valor que a biblioteca aceita de propósito, que o `w154[d]` **exige** que ela aceite, e que os dois repositórios com o mutex ligado declaram. O harness ensina e cobra uma forma que o próprio contrato reprova. Os cinco reprovam também por outros motivos, fora do escopo desta onda; o que entra aqui são as duas linhas de `heavy_mutex`.

Nota de contexto, para não superestimar o dano: nenhum passo do fluxo do consumidor valida o `forge.yaml` contra o schema hoje. Medido com `grep -arl 'forge.schema.json' . --exclude-dir=node_modules --exclude-dir=.git`, que devolve 38 caminhos — `tools/validate-forge.mjs`, exatamente cinco gates deste repositório (`w20`, `w112`, `w153`, `w192`, `w199`), o próprio schema e o `README.md` dele, e o resto sendo documentação, ledger e specs arquivadas. O que importa é o recorte executável, e ele é vazio de verdade: **nenhum** caminho sob `template/.forge/scripts/` aparece na lista, que é o diretório inteiro que o consumidor executa. É por isso que os dois erros nunca apareceram para o campo, e é também por isso que corrigi-los não quebra nada em execução: eles são contrato, não comportamento.

---

## 2. O que a bancada mediu e que mudou o desenho

Esta seção existe porque quatro decisões abaixo seriam outras se eu as tivesse deduzido. Todas as saídas vêm de bancada sob `$TMPDIR` com a biblioteca real.

**2.1 — SIGTERM ao detentor é DIFERIDO enquanto ele está num comando em primeiro plano.** É a medição que mais muda o desenho, porque o remédio óbvio — mandar um sinal educado e esperar que o `trap` libere — é inerte contra o detentor real. Remedida em 2026-09-08, com o detentor adquirindo pela biblioteca real sob `FORGE_HEAVY_MUTEX_TESTING=1` e `FORGE_HEAVY_MUTEX_ROOT`, e com a única diferença entre as duas primeiras linhas sendo a forma do trabalho (`sleep 300` contra `sleep 300 & wait`):

```
trabalho=fg     sinal=TERM liberou=NAO  em=8s detentor=vivo
trabalho=wait   sinal=TERM liberou=SIM  em=1s detentor=morto
trabalho=fg     sinal=KILL liberou=NAO  em=8s detentor=morto
```

A segunda linha é o controle pareado e ela é o que torna a primeira interpretável: o `trap` **funciona** — quando o detentor está bloqueado em `wait`, ele libera em um segundo. O que não funciona é o `trap` chegar, porque o bash adia a execução de handler até o comando em primeiro plano terminar. E o detentor real é exatamente isso: o `run_check` do `pre-push` roda `typecheck` e `test` em primeiro plano, por minutos. **A carência de cortesia do patch do consumidor e da biblioteca legada é, na prática, tempo perdido**: ela expira quase sempre, e o caminho normal passa a ser o recolhimento forçado.

A terceira linha fecha o desenho: sob `KILL` o detentor morre e **o lock não é liberado**, porque `SIGKILL` não roda `trap` nenhum. Ou seja, depois da escalada o lock vira um órfão clássico de dono morto — que é precisamente o estado que `_fhm_reclaim_orphan` já sabe tratar, com `mv` atômico e reconferência de `pid`. Daí D4: esta onda **não cria um caminho que remova o lock de um detentor vivo**. Ela **converte** posse ilegítima em posse de dono morto, e delega a remoção ao primitivo que já existe e já é testado.

O `em=8s` das linhas 1 e 3 é o teto de observação da bancada (40 voltas de 0,2s), não uma medição de latência: nas duas o lock **nunca** foi liberado, e o número diz há quanto tempo eu parei de olhar.

**2.2 — Ceifa de grupo é arma que dispara para trás, medido.** Tentei estender o encerramento ao grupo de processos do detentor, para alcançar os netos. Remedido em 2026-09-08, com o PID do neto **capturado em arquivo pelo próprio detentor** e não inferido:

```
detentor=34519 pgid=34508 | neto=34522 | pgid-do-reclamante=34508 | mesmo-grupo? SIM
apos KILL no DETENTOR:  detentor=morto  neto=S
--- a linha seguinte seria 'kill -9 -34508' e ela mataria este shell, porque o grupo e o mesmo
```

A ceifa nunca chegou a ser executada, e não por cautela: numa primeira passagem desta remedição ela foi executada e matou o processo que a executava, porque o detentor e o reclamante estavam no **mesmo grupo**. Isso não é artefato da bancada — é a situação normal quando dois processos descendem do mesmo shell sem controle de jobs. Uma ceifa de grupo sem guarda de "o grupo do detentor não é o meu" é um reclamante que se suicida, e o lock fica.

**Uma armadilha de medição que esta remedição pagou, e que o implementador vai encontrar nos cenários `[11]` e `[12]`:** a primeira versão desta bancada não conseguiu capturar o PID do neto e caiu no default de `${NETO:-0}`, e `kill -0 0` **devolve sucesso** porque o PID 0 endereça o grupo de processos do próprio chamador. O `neto=S` saía verde sem que houvesse neto nenhum. Toda asserção de vida sobre PID lido de arquivo precisa de guarda `[ -n "$p" ] && [ "$p" -gt 1 ]` antes do `kill -0`, e isso vale para o campo `beneficiary` que esta onda introduz — é o mesmo defeito, com a mesma forma, no código de produção.

A mesma saída traz o custo de **não** ceifar: `neto=S`, o neto sobrevive ao `KILL` do detentor. Encerrar o detentor libera o lock e deixa a carga rodando. Ver D10, que decide não ceifar nesta onda, e a seção 9, que declara a consequência em vez de escondê-la.

**2.3 — O nome do diretório de evidência importa, e o patch do consumidor errou nele.** O `sweep` do `heavy-run.sh` recolhe evidências de reivindicação atropelada extraindo o PID do nome e só apaga quando esse PID não existe mais; a extração é a **linha 117** do arquivo, copiada literalmente para a bancada: `rpid="$(printf '%s' "${rp##*.reaping.}" | cut -d. -f1)"`. O patch do `Axis.PadSimulator` nomeia a evidência de posse estagnada como `<lock>.reaping.stale.$$.<ts>.<rand>`, e com isso — remedido em 2026-09-08, com o criador da evidência sendo o **próprio shell da bancada**, cuja vida é comprovada na última linha, que é o controle positivo sem o qual o `SIM` não distinguiria "extraiu errado" de "o processo morreu mesmo":

```
nome=.reaping.36130.1788000000.9                    rpid=[36130]  sweep-recolhe-mesmo-com-o-criador-VIVO=nao
nome=.reaping.stale.36130.1788000000.9              rpid=[stale]  sweep-recolhe-mesmo-com-o-criador-VIVO=SIM
controle: o criador (36130) esta vivo? SIM
```

Com o marcador na frente, o campo extraído é a palavra `stale`, `ps -o lstart= -p stale` devolve vazio, e o `sweep` apaga a evidência **com o processo que a criou ainda vivo** — que é o oposto do que a guarda existe para fazer. Daí D6: a evidência desta onda usa a **mesma forma de nome** que o caminho de órfão já usa, com o PID no primeiro campo.

**2.4 — No `pre-push` real, `$PPID` é o `git push`.** Remedido em 2026-09-08 com um push de verdade contra um remoto local `file://`, com um hook que grava `$$` e `$PPID` num arquivo antes de dormir. É a mesma bancada de §1.3 e a saída inteira está lá; o recorte é este:

```
hook pid=37338 PPID=37331
cmd do PPID: /Applications/Xcode.app/Contents/Developer/usr/bin/git -C <bancada>/repo push -q file://<bancada>/remoto main
ppid do PPID: 37309
```

É o que torna `--beneficiary "$PPID"` no hook uma declaração correta por construção, e não uma heurística: o pai do hook **é** quem lê o código de saída dele. E `template/.forge/hooks/git/pre-push:245` está no nível de topo do script, não dentro de subshell nem de função lançada em segundo plano, então o `$PPID` que ele lê é esse mesmo (conferido com `grep -an 'forge_heavy_mutex_acquire' template/.forge/hooks/git/pre-push`, que devolve uma única linha, a 245).

## 3. Decisões de desenho — FECHADAS

**D1. O critério de posse órfã é o BENEFICIÁRIO DECLARADO, nunca `ppid == 1`.**

O lock passa a gravar dois campos novos, `beneficiary` e `beneficiary_token`, escritos por `_fhm_claim` quando e somente quando o chamador declarou `--beneficiary <pid>`. Um esperante que observe um detentor **vivo** cujo beneficiário declarado está **morto** trata a posse como ilegítima de imediato.

*Alternativa descartada — reclamar quando `ppid` do detentor é 1, que é a sugestão 1 da issue.* Reparentação para o `launchd` não é evidência de que ninguém lê o resultado, e há pelo menos quatro casos legítimos com `ppid` 1: `heavy-run.sh` lançado com `nohup` ou `&` e o terminal fechado, que é uso documentado do wrapper e cujo trabalho é querido; um processo iniciado por um `LaunchAgent`, que nasce com `ppid` 1; qualquer processo dentro de um contêiner, onde o init do contêiner é o pai de tudo; e um runner de CI daemonizado. A régua de exaustividade da invariante 17 se aplica aqui e a enumeração acima é o resultado de procurá-la: `ppid == 1` classifica os quatro como descartáveis e mata trabalho legítimo. O beneficiário declarado não tem esse problema porque **quem sabe se a morte do pai esvazia o trabalho é o chamador**, e só ele.

*Alternativa descartada — inferir o beneficiário como `$PPID` dentro da própria biblioteca, sem declaração.* Isso reintroduz o caso do `nohup` por outra porta: o `heavy-run.sh` teria um beneficiário inferido que morre legitimamente, e a carga seria recolhida no meio. A biblioteca não pode saber; o hook sabe.

**D2. Beneficiário ausente NÃO é reclamável por esse caminho, e isso é a garantia de interoperabilidade.**

Lock sem o campo `beneficiary` — todo lock do protocolo legado, todo lock criado pelo `heavy-run.sh`, e todo lock criado por uma versão anterior desta biblioteca durante a implantação — cai apenas no teto de idade de D3. É o mesmo idioma que `_fhm_alive` já aplica ao token ausente (`[ -n "$want" ] || return 0`): identidade que não temos não vira licença para destruir.

Terceiro caso da enumeração, e ele precisa de resposta própria: `beneficiary` presente e `beneficiary_token` ausente ou vazio. A identidade disponível é só o PID, e um PID reciclado se pareceria com um beneficiário vivo — o que erra para o lado seguro. Decisão: com token ausente, o beneficiário é considerado **vivo** se o PID existir, e a posse não é reclamável por D1.

**D3. O teto de POSSE é derivado do teto de ESPERA, e nunca o contrário.**

A precedência do teto de posse é `FORGE_HEAVY_MUTEX_STALE_AFTER_S` > `heavy_mutex.stale_after_s` do `forge.yaml` > **metade do teto de espera efetivo**, com a metade calculada em aritmética inteira de bash (`$(( timeout / 2 ))`, piso) e depois submetida à invariante de D4, que é quem decide o valor final. Valor `0` é válido nos três degraus e significa "recuperação por idade desligada", exatamente como `0` já significa "recusa imediata" para o teto de espera. Valor presente e não numérico avisa em stderr e devolve a vez ao degrau de baixo, que é a disciplina já estabelecida em `forge_heavy_mutex_acquire:705-727` e afirmada pelo `w151[49]` da linha 1241 (o gate tem **dois** cenários rotulados `[49]`, um em 742 e outro em 1241; todas as citações desta especificação são ao segundo, e a etiqueta duplicada é do gate existente, não desta onda).

**O `0` é a VÁLVULA DE ESCAPE, e ela precisa estar publicada porque a invariante de D4 torna os dois tetos um botão só.** O maior teto de posse efetivo que um repositório consegue obter é `teto de espera − reserva` — com os defaults, `1800 − 6 = 1794` —, e não existe declaração que o ultrapasse, porque D4 rebaixa. Um repositório cuja suíte pesada legitimamente dura mais que isso tem exatamente duas saídas, e as duas precisam estar escritas na `description` da chave e na mensagem de liaison: aumentar o teto de espera junto, ou declarar `stale_after_s: 0` e ficar com o comportamento de hoje, em que a recuperação só age sobre detentor morto e sobre beneficiário morto. Isso não é hipótese de laboratório — é o estado dos dois consumidores que de fato têm o mutex ligado, medido em §8, e o efeito de produto está lá.

*Alternativa descartada — derivar o teto de espera do teto de posse, que é a sugestão 1 da #137 (`timeout_s = stale_after_s + margem`).* Com o `stale_after_s` de 3600 que o campo declara, o teto de espera viraria mais de uma hora: um `git push` que não termina por sessenta minutos. A rule `conventions/heavy-resource-serialization.md` já decidiu isso em outro contexto e a frase serve palavra por palavra — *"aumentar o tempo de espera não corrige inanição"*. E o efeito colateral é o que o enunciado deste subgrupo antecipa: alongar a espera **agrava a #144**, porque o esperante passa mais tempo preso atrás de um detentor que não serve a ninguém. Derivar na direção oposta corrige a #137 sem alongar espera nenhuma.

*Alternativa descartada — publicar um default fixo, como o 3600 do consumidor.* Um número fixo escolhido a dedo reintroduz a relação quebrada assim que alguém declara `timeout_s: 600`: o teto de posse continuaria em 3600 e o esperante voltaria a desistir antes de o recolhimento poder agir — o defeito da #137 com valores diferentes. O default derivado faz a relação valer **por construção** para qualquer teto de espera.

**D4. A relação é uma INVARIANTE, não um default; o rebaixamento vale para os dois caminhos e o AVISO só existe onde há um número declarado a contradizer.**

Seja `reserva = graça + poll da cabeça`, onde a graça é `FORGE_HEAVY_MUTEX_STALE_GRACE_S`, variável de ambiente **NOVA** desta onda, com default 5, e o poll da cabeça é `FORGE_HEAVY_MUTEX_POLL_HEAD_S`, que **já existe** na biblioteca com default 1 (linhas 856-857 e 897-898, conferidas com `grep -an 'POLL_HEAD_S'`). Com os defaults, `reserva = 6`. A propriedade que a biblioteca garante é:

> teto de posse efetivo **maior que zero** implica **teto de posse efetivo + reserva ≤ teto de espera**.

Quando o valor **declarado** viola a relação, ele é **rebaixado** para `teto de espera − reserva`, com um aviso que nomeia os três números — o declarado, o efetivo e o teto de espera. Quando `teto de espera − reserva` não é positivo, a recuperação por idade fica **desligada** para aquela aquisição, e o aviso diz isso: com um teto de espera de zero ou de poucos segundos, o chamador pediu recusa quase imediata e não há tempo para recolher coisa alguma.

**A CONSEQUÊNCIA ARITMÉTICA da invariante, e ela é fechada — foi o bloqueador da revisão 2 e governa a §4 inteira.** O ramo de idade dispara na primeira volta em que `agora − acquired_at > efetivo`, isto é em `waited = max(0, efetivo − idade inicial)`. Como a invariante dá `efetivo ≤ espera − reserva` sempre que `efetivo > 0`, segue `waited ≤ efetivo ≤ espera − reserva < espera`: **com o ramo armado e um lock cuja idade é legível, o disparo acontece SEMPRE antes do teto de espera, mesmo para a posse mais nova possível.** Logo, contra um detentor vivo que não solta, o desfecho de uma espera com o ramo armado é **sempre o recolhimento e nunca o 75** — e não existe parametrização que salve o contrário, porque salvá-lo exigiria `espera < efetivo`, que é a negação da invariante. Medido por enumeração exaustiva da derivação candidata, `espera` de 0 a 200 cruzado com quinze valores declarados mais o caminho derivado, testando as duas propriedades em cada combinação (`efetivo + reserva ≤ espera`, e `waited < espera` com idade inicial zero):

```
$ . ./teor.sh; for t in $(seq 0 200); do for d in "" 0 1 2 3 5 7 10 30 60 300 900 1800 3600 100000; do ... done; done
RESERVA=6
combinacoes com ramo ARMADO: 2716 | violacoes: 0
```

A folga entre o disparo e o teto é, no mínimo, a própria reserva — que é para isso que ela existe: é o tempo que a escalada `TERM → graça → KILL` precisa para caber dentro do teto de espera. Medido na mesma bancada:

```
espera  declarado efetivo   disparo-w folga-ate-o-teto
6       <derivado> 0         -         DESLIGADO
7       <derivado> 1         1         6s
9       <derivado> 3         3         6s
11      <derivado> 5         5         6s
20      3600      14        14        6s
1800    <derivado> 900       900       900s
1800    0         0         -         DESLIGADO
1800    3600      1794      1794      6s
```

O ramo arma a partir de `espera = 7` em **todos** os caminhos — derivado e declarado —, e `stale_after_s: 0` o mantém desligado em qualquer teto de espera.

**Enumeração exaustiva dos modos pelos quais um esperante ainda pode sair 75 contra um detentor VIVO**, e ela é a régua que a §4.1 aplica cenário a cenário: **(i)** desligado por **aritmética** — `espera ≤ reserva`, o efetivo é zero; **(ii)** desligado por **declaração** — `stale_after_s: 0` em qualquer degrau, com qualquer teto de espera; **(iii)** armado com **idade não computável** — a primeira linha da tabela de leitura de D5, que é o caso do lock sem `acquired_at`. Não há um quarto modo: o `case` da derivação e a tabela de D5 esgotam as entradas, e a enumeração é a leitura direta dos dois. Todo cenário da §4 que assevera 75 contra detentor vivo **declara em letra qual dos três modos o sustenta**, e a §4.1 é essa declaração.

**O caminho DERIVADO também é rebaixado, e ele é SILENCIOSO.** É a lacuna que a revisão 1 nomeou, e ela é numericamente dominante em vez de marginal. Com `reserva = 6` e a metade calculada em aritmética inteira de bash (`$(( t / 2 ))`, que é piso), a metade só sobrevive à invariante a partir de um teto de espera de **11** segundos; abaixo disso o efetivo é sempre `espera − 6`, e a partir de `espera ≤ 6` a recuperação por idade fica desligada. A tabela abaixo é medida, não deduzida — bancada em bash 3.2 rodando a derivação candidata:

```
$ . ./derive.sh; for t in 0 1 2 4 5 6 7 9 10 11 12 13 20 30 1800; do printf '%-8s %-14s %s\n' "$t" "$(( t / 2 ))" "$(efetivo "$t")"; done
RESERVA=6
espera   metade-derivada efetivo-sem-declarado
0        0              0 (desligado)
1        0              0 (desligado)
2        1              0 (desligado, teto de espera <= reserva)
4        2              0 (desligado, teto de espera <= reserva)
5        2              0 (desligado, teto de espera <= reserva)
6        3              0 (desligado, teto de espera <= reserva)
7        3              1 (REBAIXADO de )
9        4              3 (REBAIXADO de )
10       5              4 (REBAIXADO de )
11       5              5
12       6              6
13       6              6
20       10             10
30       15             15
1800     900            900
```

O `REBAIXADO de ` com o campo vazio nas linhas 7, 9 e 10 é literalmente o defeito: no caminho derivado **não existe declarado a nomear**, e um aviso de três números com um deles em branco é ruído com aparência de diagnóstico. Decisão: **o rebaixamento do valor derivado não emite aviso.** A justificativa não é estética, é de alcance — a faixa `espera < 11` cobre a maioria das fixtures do `w151` (`--timeout 2`, `4`, `5`, `6`, `9`) e qualquer consumidor que aperte o teto, então avisar ali imprimiria em quase toda espera curta contendida uma linha sobre a qual o operador não tem ação nenhuma, porque ele não declarou número nenhum. É o `w154[f]` palavra por palavra: *"aviso que aparece sem problema é ruído, e ruído é o que ensina a ignorar aviso"*.

O que substitui o aviso, e mantém honesto o terceiro estado da invariante 2, é **diagnóstico e não alerta**: quando há contenção observada, a linha `espera ......` que o `_fhm_diag` já imprime ganha, no fim, o teto de posse efetivo daquela aquisição e a palavra `desligada` quando ele é zero. É um campo a mais numa linha que já existe, no bloco que só sai sob contenção, e ele responde à pergunta que o operador de fato faz ao ver um push preso: *"esta espera vai recolher a posse do outro em algum momento, ou não?"*. Nenhum gate assevera essa linha — medido em §8, com `grep -aFrln 'espera ...... ' tests/` devolvendo vazio e com controle positivo sobre a lib.

O cenário `[27](a)` guarda o silêncio do caminho derivado, e a mutação **M14** é o contrafactual dela. (A revisão anterior desta especificação apontava aqui para o `[26]`, que é a matriz de leitura de `beneficiary` e não tem nada com o silêncio do rebaixamento — erro de referência cruzada achado na varredura desta revisão, não pelo veredito. A M14 sempre disse `FAIL [27](a)`, então o texto e a matriz se contradiziam.)

*Alternativa descartada — recusar a aquisição quando a relação é violada.* Reprovar um `git push` por causa da relação entre dois valores de configuração é transformar uma imprecisão de config em bloqueio de trabalho, e é assim que um gate vira `--no-verify` de hábito. O rebaixamento entrega o comportamento correto e informa.

*Alternativa descartada — avisar também no caminho derivado, com dois números em vez de três.* Ela é coerente e foi descartada pelo alcance medido acima: a faixa em que ela dispararia é a faixa comum, o operador não tem ação, e o aviso competiria com o bloco de contenção que já explica a situação inteira.

O aviso do caminho declarado é emitido **uma vez por aquisição e só quando há contenção observada** — na primeira volta do laço em que existe detentor —, nunca no caminho livre, pelo mesmo motivo do `w154[f]`.

**D5. A ordem é beneficiário → idade, as duas mensagens são distintas, e campo AUSENTE ou ILEGÍVEL nunca é licença para reclamar.**

Beneficiário morto é **certeza** ("ninguém vai ler o resultado"); idade excedida é **heurística** ("está demorando demais"). Avaliar a certeza primeiro reclama mais cedo e com melhor justificativa, e as duas classes precisam de vocabulário próprio no diagnóstico, porque quem investiga precisa saber qual dos dois motivos derrubou a posse.

Ordem completa no laço, e as três primeiras não mudam: reentrância por linhagem, lock sem `pid` legível, dono morto por `_fhm_alive`, **beneficiário morto**, **idade acima do teto**.

**A semântica de LEITURA de cada campo novo, que a revisão 1 pegou em aberto e que é onde as duas implementações plausíveis divergem em quem morre.** Cada ramo lê campos que podem estar ausentes, vazios, não numéricos ou de outro protocolo, e a regra é única e vale para os dois: **a ausência de identidade não é licença para destruir**, que é o mesmo idioma que `_fhm_alive` já aplica ao token (`[ -n "$want" ] || return 0`).

| Estado do campo lido | Ramo de IDADE (`acquired_at`) | Ramo de BENEFICIÁRIO (`beneficiary`) |
|---|---|---|
| ausente (arquivo não existe) | **não reclamável por idade** — a idade não pode ser computada, e "não sei a idade" não é "é velho" | **não reclamável por beneficiário** (é D2, e é a garantia de interoperabilidade) |
| presente e vazio | **não reclamável por idade** | **não reclamável por beneficiário** |
| presente e não numérico | **não reclamável por idade** | **não reclamável por beneficiário** |
| presente, numérico e ≤ 0 | **não reclamável por idade** (`acquired_at` de 0 ou negativo é lixo, não é 1970) | **não reclamável por beneficiário** — o PID 0 endereça o grupo do próprio chamador e `kill -0 0` devolve SUCESSO, medido em §2.2; sem a guarda `[ "$b" -gt 1 ]` um campo corrompido para `0` vira "beneficiário vivo" por acidente, e para `-1` vira o grupo inteiro |
| presente, numérico e no futuro | **não reclamável por idade** — relógio que anda para trás não produz posse velha | — |
| presente e válido | reclamável se `agora − acquired_at > teto de posse efetivo` | reclamável se o PID não existir mais, com a ressalva de token de D2 |

Em todos os casos de "não reclamável", o esperante **continua esperando** e o desfecho, esgotado o teto, é o 75 de sempre — não há caminho novo que remova lock por falta de informação.

**A razão pela qual isto não é preciosismo, e ela é um vermelho medido num gate existente.** O campo `acquired_at` é escrito pela biblioteca na linha 659 e **nunca lido por ninguém hoje**: `grep -arn 'acquired_at' tests/ template/` devolve exatamente uma linha, a 659, com a saída colada abaixo. Dentro do `_fhm_claim` o `pid` é escrito na linha 644 e o `acquired_at` só na 659, então existe uma janela de produção real em que o lock tem dono legível e não tem idade. E na suíte esse estado é a regra: o helper `mk_lock` do `w151` (linhas 44-49) grava `pid`, `token` e `nonce` e **nunca** `acquired_at`, e o mesmo vale para os locks montados à mão dos cenários `[20]`, `[31]` e `[49]`, mais o lock vazio do `[9]`.

```
$ grep -arn 'acquired_at' tests/ template/
template/.forge/scripts/lib/heavy-mutex.sh:659:  printf '%s
' "$(date +%s)" > "$_FHM_LOCK/acquired_at" 2>/dev/null
```

Com a leitura oposta — "idade ausente é idade infinita" — o `w151[49](c)` ficaria **vermelho contra uma implementação que seguiu esta especificação**. Aquele cenário roda o esperante com `FORGE_HEAVY_MUTEX_TIMEOUT_S=9` contra um `sleeper` VIVO sobre um lock sem `acquired_at`, e assevera `[ "${r49% *}" = "75" ] && [ "$s49" -ge 8 ]`; sob D3+D4 o teto de posse efetivo com espera 9 é `9 − 6 = 3s` (a metade, 4, viola a relação e é rebaixada), e sob a leitura oposta o ramo de idade é alcançado **na primeira volta**, em `waited = 0` — porque "ausente" passaria a significar "infinitamente velho" e não "três segundos de idade" —, de modo que o esperante mataria o detentor e adquiriria com rc 0 por volta dos **5 a 6 segundos**, que é a graça mais um poll. As duas metades da asserção caem: o rc deixa de ser 75 e o `s49` fica abaixo de 8. A revisão 2 pegou este número errado na revisão anterior desta especificação, que dizia "aos ~3s": o 3 é o teto de posse **efetivo**, não o instante do disparo sob M13. A conclusão não muda, e ela é a mesma que fechou o bloqueador 1. Uma linha de decisão separa isso de um gate rastreado vermelho no dia da entrega.

O cenário `[25]` existe para morder exatamente essa linha, e a mutação M13 é o contrafactual dela.

**D6. O encerramento é `TERM → graça → KILL`, e a remoção só acontece depois de a morte do detentor ser CONFIRMADA.**

Esta é a decisão que a bancada de 2.1 impôs e é o que separa esta especificação do patch do consumidor e da biblioteca legada, que fazem `rm -rf` sobre um detentor que pode estar vivo — trocando um travamento por duas cargas pesadas simultâneas, que é o desfecho que o primitivo inteiro existe para impedir.

A sequência é: `TERM` ao detentor; espera de graça, encerrada assim que o lock sumir; se o lock persiste, `KILL` ao detentor; releitura do estado do detentor. **Só quando `_fhm_alive` do detentor passa a ser falso** o recolhimento acontece, e ele acontece por `_fhm_reclaim_orphan`, que já existe, já faz `mv` atômico para nome exclusivo e já reconfere `pid` antes de apagar. Se a morte não puder ser confirmada — outro uid, permissão negada, `kill` inócuo —, a posse **não é recolhida**, o esperante segue esperando e, esgotado o teto de espera, sai com 75 e uma mensagem que diz que o recolhimento foi tentado e falhou, e por quê. É o terceiro estado da invariante 2 aplicado à recuperação: "recolhi", "não precisei recolher" e "tentei e não consegui" são desfechos distintos.

O nome do diretório de evidência é `<lock>.reaping.<pid-do-reclamante>.<ts>.<rand>`, idêntico em forma ao que `_fhm_reclaim_orphan` já usa, pelo motivo medido em 2.3.

**D7. O relógio da espera avança pela graça consumida, e o teto é testado DENTRO do ramo.**

O ramo de recolhimento termina em `continue`, que pula a checagem de teto no fim do laço. Sem incrementar `waited` pela graça e sem testar o teto ali dentro, um recolhimento que falhe de forma persistente — lock recriado por terceiro a cada volta, detentor imortal, permissão negada — vira laço quente infinito, e num `pre-push` isso é um `git push` que não termina, sem um 75 para explicar. É o mesmo modo de falha que a validação de `timeout_s` já existe para impedir (`w151[49]`), reintroduzido pela porta dos fundos, e o patch do `Axis.PadSimulator` registra em comentário que a regressão anti-mutante dele pegou exatamente isso.

**D8. `--beneficiary` valida o valor; `--label` passa a recusar vazio.**

`--beneficiary` só aceita inteiro positivo, e qualquer outra coisa devolve 64 — a mesma forma que `--timeout` já usa. Isso a torna imune por construção à classe da #103 (`--beneficiary --timeout 5` grava `--timeout` num campo), sem depender da Onda E.

`--label ""` passa a devolver 64 em vez de gravar um campo de diagnóstico vazio, que é o buraco medido em 1.4(A). Nenhum chamador do template passa label vazio — `pre-push:245` monta `"pre-push de <basename>"` e `heavy-run.sh:176` faz `--label "${LABEL:-$*}"` —, então a recusa não muda comportamento de nenhum caminho existente.

**D9. O `pre-push` declara o beneficiário; o `heavy-run.sh` NÃO declara.**

`template/.forge/hooks/git/pre-push:245` passa a ser `forge_heavy_mutex_acquire --label "pre-push de $(basename "$ROOT")" --beneficiary "$PPID"`, medido em 2.4 como sendo o processo `git push`. O `heavy-run.sh` continua sem declarar, e isso é decisão e não omissão: o wrapper é o caminho por onde alguém legitimamente detaça uma carga longa, e um beneficiário inferido ali seria a morte do caso `nohup` de D1.

**D10. Esta onda não ceifa grupo de processos.**

Medido em 2.2: sem uma guarda que prove que o grupo do detentor não é o do reclamante, a ceifa mata o reclamante — e a guarda correta exige gravar no lock o `pgid` e a sessão do detentor, mais uma decisão sobre o que fazer quando eles coincidem. O encerramento desta onda alcança o detentor, não os descendentes dele.

A consequência é declarada, não escondida, e é medida (`neto=S` depois do `KILL`): depois do recolhimento, os descendentes do detentor podem continuar rodando **com o lock livre**. Isso é a classe já catalogada no canal de liaison, na thread `mutex-nao-atravessa-a-fronteira-do-harness` — `axis-go-cloud-0071` retrata a conclusão anterior e nomeia o defeito real como *"o gate 06 liberar o lock e deixar a suíte ÓRFÃ rodando cinco minutos"*, e `axis-fare-validator-0058` mede que a saída **normal** do `heavy-run.sh` (`wait`, `rc=$?`, `release`, `exit`) não tem ceifa de grupo nenhuma, ao contrário do caminho de sinal, que tem. Confirmei a assimetria no template: `_hr_sig` sinaliza `-$HR_CHILD` e as quatro últimas linhas do arquivo não sinalizam nada.

Comparação honesta com o estado de hoje, que é o que sustenta a decisão: hoje a carga órfã roda **e** ninguém mais consegue empurrar; depois desta onda a carga órfã roda **e** alguém consegue empurrar. A violação de concorrência não é criada por esta onda, ela já existe; o que muda é que o travamento deixa de existir. Item de ledger novo em D12.

**D11. O recolhimento imprime o censo de descendentes do detentor, medido ANTES do encerramento.**

Uma única passada de `ps` antes do `TERM`, contando os processos cujo pai é o detentor, e o número entra na mensagem. É diagnóstico, não ação: converte a violação silenciosa de D10 numa violação **nomeada**, e é a única forma de o operador saber que sobrou carga. Precisa ser antes do encerramento porque depois dele os filhos são reparentados e o vínculo de `ppid` some — que é a mesma reparentação de #144, agora do outro lado.

**D12. As chaves publicadas ganham lugar no contrato, e o defeito de paridade da 1.5 é corrigido junto.**

No `forge.schema.json`, sob `heavy_mutex`: `stale_after_s` (inteiro ≥ 0) é acrescentado, e o `"pattern": "^/"` de `root` é relaxado para aceitar **exatamente** o que o leitor aceita, e nada mais. O `case` de `_fhm_resolve_root` tem **três** braços legítimos, conferidos nas linhas 101-119 da biblioteca — o vazio (`'') : ;;`, linha 102, que devolve a vez ao default), o token literal `${TMPDIR:-/tmp}` (linha 103) e `/*` (linha 118) —, então o padrão novo é a união dos **três** e não de dois: qualquer outro valor continua reprovando no schema, como já reprova no leitor (linha 119, que imprime `heavy_mutex.root inválido no forge.yaml (%s) — exigido caminho ABSOLUTO; usando /tmp`). Deixar o schema recusando o que o leitor aceita e o gate cobra é a instância exata de LDG-0159 dentro do change que existe para fechar a vizinhança.

**A revisão 2 pegou o braço vazio de fora, e ela tinha razão — a paridade "dos dois últimos braços" da revisão anterior deixava `heavy_mutex.root: ""` reprovando no schema e passando em silêncio no leitor, que é LDG-0159 sobrando por um fio dentro do change que existe para fechá-lo.** O padrão que fecha os três é `^(?:|\$\{TMPDIR:-/tmp\}|/.*)$`, e a paridade dele é medida com o validador que o repositório de fato usa, não deduzida:

```
$ node -e '...ajv.compile({type:"string",pattern:"^(?:|\\$\\{TMPDIR:-/tmp\\}|/.*)$"})...'
VALIDA ""
VALIDA "${TMPDIR:-/tmp}"
VALIDA "/tmp"
RECUSA "relativo/nao-absoluto"
RECUSA "tmp"
```

E os quatro casos vizinhos que **precisam** continuar reprovando, porque o `case` do leitor também os reprova — `$TMPDIR`, `${TMPDIR}`, `${TMPDIR:-/tmp}/extra` e ` /tmp` com espaço à frente — reprovam todos, medidos na mesma bancada. A alternativa descartada é apertar o leitor para recusar o vazio: seria mudança de comportamento para quem já tem `root: ""` no arquivo, contra uma correção aditiva que restaura a paridade sem tocar em execução nenhuma. **Armadilha de escrita, e ela vale a linha porque o arquivo é JSON e não regex solto:** o padrão acima é a *expressão*; dentro do `forge.schema.json` cada contrabarra é dobrada, e um `\$` que chegue simples ao arquivo faz o `$` virar âncora de fim de linha e o padrão passar a aceitar coisa que o leitor recusa — a asserção de `[21]` sobre `relativo/nao-absoluto` é o que morde nesse caso.

**A `description` do bloco muda junto, e isso não é cosmético.** A `description` de `heavy_mutex` hoje diz, em letra: *"O lock mora em /tmp por caminho fixo, nunca em $TMPDIR: no macOS o TMPDIR é por usuário E por contexto de invocação, então um lock ancorado nele particiona a exclusão"*. Relaxar o `pattern` sem tocar nela publicaria um contrato que **aceita a forma que a própria prosa chama de defeito** — o adotante leria a proibição e veria o schema validar. O texto novo precisa dizer as duas coisas que o leitor de fato implementa e que os comentários da biblioteca (linhas 100-118) já explicam: `${TMPDIR:-/tmp}` é aceito como **token literal, nunca avaliado**, e existe para um único fim, que é convergir com o protocolo legado durante a migração de um host inteiro; e ele continua sendo a forma que **particiona** a exclusão quando usada fora desse fim. Isso é edição de string publicada, então entra na varredura de §8 como qualquer outra.

**O predicado que torna essa edição asseverável, e ele existe porque a revisão 2 mostrou que sem ele a linha M15 é decorativa.** "A `description` não contradiz mais o que o `pattern` aceita" é afirmação sobre prosa e não tem forma mecânica. A forma mecânica declarada é: a `description` do bloco `heavy_mutex` **não** contém a string literal `nunca em $TMPDIR` **e** contém a string literal `${TMPDIR:-/tmp}`, as duas medidas com `grep -aF` sobre `template/.forge/schemas/forge.schema.json`. O controle é o estado de hoje, que é o oposto exato do exigido nas duas metades:

```
$ grep -acF 'nunca em $TMPDIR' template/.forge/schemas/forge.schema.json
1
$ grep -acF '${TMPDIR:-/tmp}' template/.forge/schemas/forge.schema.json
0
```

A `description` de `root` ganha junto a menção ao braço vazio (`""` significa "usar o default", e é o que o leitor já faz) e a do bloco ganha a válvula de escape de D3 (`stale_after_s: 0` desliga a recuperação por idade), porque um contrato que publica o botão sem publicar o desligamento entrega metade da decisão.

`stale_grace_s` **não** é publicado como chave do `forge.yaml` e fica só na variável de ambiente `FORGE_HEAVY_MUTEX_STALE_GRACE_S`, que é nova (medido: `grep -arn 'STALE_GRACE' template/ bin/ installer/ tests/` sai vazio, e o controle positivo do universo está em §1.1). A razão é a do `w192`: toda chave publicada promete alguma coisa ao adotante e precisa de leitor e de gate, e a graça é botão de operação de uma máquina, não contrato de um repositório. O que é contrato de repositório é quanto tempo a suíte pesada daquele repositório legitimamente dura, e isso é `stale_after_s`.

**D13. Item de ledger novo, aberto por esta onda:** "ceifa de grupo no recolhimento de posse e na saída normal do `heavy-run.sh` — o encerramento do detentor não alcança descendentes (medido: neto sobrevive ao KILL), e a ceifa ingênua mata o reclamante quando os grupos coincidem (medido); exige gravar `pgid` e sessão no lock, e vale para o caminho de saída normal do wrapper, que hoje só o caminho de sinal cobre". Sem ele, a onda que existe para desfazer travamento entrega uma violação de concorrência sem registro.

---

## 4. O VERMELHO, antes do verde

Gate novo, `tests/w<NNN>-heavy-mutex-posse-gate.sh`.

**Por que gate novo e não cenários no `w151`.** Duas razões medidas. A primeira é o orçamento: o `w151` declara `GATE_BUDGET_S="${W151_BUDGET_S:-600}"` na linha 90, e a derivação desse 600 está escrita no cabeçalho do próprio arquivo, nas linhas 75-78 — *"Medido neste branch, com a máquina ociosa: 305s, 319s e 325s (…) O gasto solo está, portanto, em torno de 330s"*. **Esse número é citação do arquivo, não medição minha**: eu não rodei o `w151` na elaboração desta especificação, pela regra de não concorrência de `feedback-suite-sem-concorrencia`, e o que eu conferi foram as duas linhas (90 e 1343) e o texto da derivação. Os cenários desta onda são esperas reais de segundos, então acrescentá-los obriga a refazer aquela derivação e aproxima o teto do gasto, que é justamente o defeito que o comentário do `w151` diz ter acabado de corrigir. A segunda razão é o contador: o `w151` e o `w154` asseveram `SCENARIOS_RUN -gt 0` (linha 1343 do `w151`), que é piso e não denominador fixo, e a invariante 3 do plano-mestre exige denominador fixo para trabalho novo. Um gate próprio nasce com o denominador certo sem ter de mexer no contador dos dois existentes.

*Alternativa descartada — estender o `w151`.* Além do custo acima, um vermelho de posse órfã sairia rotulado como `w151-heavy-mutex`, misturado a trinta e sete outros cenários, e a leitura do log deixaria de dizer qual classe caiu.

A coluna "estado hoje" diz, para cada cenário, se ele falha por **ausência real** da funcionalidade ou se nasce verde por construção — a disciplina que a Onda A fixou depois de a revisão pegar dois cenários declarados como vermelhos que não eram. Esta tabela é a **autoridade** sobre quem é vermelho e quem não é, e o passo 2 da §10 lê daqui em vez de repetir um número: pela contagem desta revisão são vinte e sete cenários, dos quais **cinco** são "verde hoje por vacuidade" (`[3]`, `[6]`, `[8]`, `[11]`, `[18]`), dois são "não falha por ausência" (`[23]` e `[24]`), **três** são mistos, com uma metade vermelha e a outra verde por construção (`[2]`, `[10]` e `[27]`), e os outros dezessete são vermelho por ausência real, inteiros. **A contagem mudou nesta revisão** porque o `[2]` deixou de ser verde inteiro: a consequência aritmética de D4 tornou insatisfazível a contrapositiva que ele asseverava, e o cenário foi reescrito em dois arranjos, um deles vermelho por ausência real. Cinco mais dois mais três mais dezessete são vinte e sete, que é o `DECLARADOS` da §7. Todo número que aparece na coluna de mensagem é valor da minha fixture e serve para o implementador reconhecer o vermelho; **nenhum é literal no fonte do gate**, que imprime o que ele mesmo mediu naquela execução.

| # | Cenário | Estado da fixture | Asserção | Estado hoje e por quê |
|---|---|---|---|---|
| [1] | posse com idade muito acima do teto, detentor VIVO, com beneficiário vivo | lock com `acquired_at` antigo, detentor `sleep` rastreado, `stale_after_s` pequeno declarado, teto de espera folgado — a pré-condição é `declarado + reserva ≤ espera`, medida pelo implementador, para que o valor declarado governe em vez de ser rebaixado | o esperante **adquire** (rc 0), a saída nomeia a posse estagnada com PID e idade, e o lock final pertence ao esperante (`pid` e `nonce` dele) | **vermelho por ausência real** — não há nenhum caminho de recuperação por idade; medido: rc 75, lock intacto |
| [2] | discriminador contra "recolhe sempre", em DOIS arranjos, porque a contrapositiva ingênua é insatisfazível | (a) ramo **ARMADO**: `stale_after_s: D` declarado com `D ≥ 2·reserva`, teto de espera `E ≥ D + reserva`, lock com `acquired_at` de AGORA (posse NOVA), detentor vivo que não solta, beneficiário vivo; (b) ramo **DESLIGADO POR ARITMÉTICA**: teto de espera `≤ reserva` medida, posse VELHA, detentor vivo. Os dois números saem da reserva medida pelo implementador, nunca fixados | em (a) o esperante **adquire**, e o que o cenário assevera é o **instante**: o decorrido até a aquisição é **≥ D**, e uma sonda tomada antes de `D` ainda vê o `nonce` original no lock; em (b) rc 75 e o lock final tem o `nonce` original | **misto.** (a) é **vermelho por ausência real** — hoje não há recolhimento nenhum, o esperante nunca adquire e o decorrido nunca satisfaz a asserção; (b) é verde hoje por vacuidade — declarado. **Por que dois arranjos e nenhuma asserção de "não recolhe" contra o ramo armado:** a revisão 2 provou, e a consequência aritmética escrita em D4 fecha, que com o ramo armado e idade legível o recolhimento acontece SEMPRE antes do teto de espera — a versão anterior deste cenário asseverava rc 75 nessa condição, e isso era vermelho fabricado no dia da entrega. O discriminador contra "recolhe sempre" continua existindo, mas ele é **temporal** em (a) e **de regime** em (b). A metade (b) é, além disso, a única asserção do gate sobre a proteção aritmética da reserva, da qual **sete** cenários do `w151` dependem (§8) |
| [3] | `stale_after_s: 0` desliga a recuperação por idade | idêntico a [1], com a chave em `0` | rc 75, lock preservado, **e** nenhuma linha de recolhimento na saída | verde hoje por vacuidade — declarado; discrimina contra implementação que ignore a chave. É o cenário que sustenta o modo **(ii)** de D4, do qual dependem **treze** linhas da §4.1: `[7]`, `[8]`, `[9]`, `[10](a)`, `[11]`, `[12]`, `[13]`, `[14]`, `[15]`, `[16]`, `[17]`, `[18]` e `[26]` |
| [4] | teto derivado: sem a chave, o teto de posse é metade do teto de espera — e o que discrimina é o INSTANTE do recolhimento, não o desfecho | **teto de espera ≥ 11**, que é a pré-condição numérica medida em D4 e sem a qual este cenário é vermelho fabricado; a fixture DERIVA os números da reserva medida pelo implementador em vez de fixá-los, e reprova se `metade + reserva > espera`; duas posses de idades conhecidas em torno da metade, uma acima e uma abaixo, com folga maior que a granularidade de um segundo do `date +%s` | a posse **acima** da metade é recolhida na primeira volta (decorrido ≤ reserva mais folga) e a **abaixo** só depois de pelo menos `metade − idade` segundos; o **delta** entre os dois decorridos é a medição da metade derivada, e as duas terminam em rc 0 | **vermelho por ausência real** — não há derivação nenhuma. **Correção desta revisão, achada varrendo a §4 atrás do efeito colateral do bloqueador novo:** a versão anterior asseverava que a posse abaixo da metade **não** é recolhida, o que a consequência aritmética de D4 torna insatisfazível pelo mesmo motivo que derrubou o `[2]` — com o ramo armado ela também é recolhida, só que mais tarde. O revisor não nomeou este cenário; ele cai pela mesma aritmética |
| [5] | INVARIANTE da relação: `stale_after_s` declarado MAIOR que o teto de espera | `timeout_s` pequeno e `stale_after_s` grande, posse velha, detentor vivo. **Pré-condição numérica, irmã da do `[4]` e pelo mesmo motivo:** o teto de espera tem de ser **maior que a reserva medida pelo implementador** (com os defaults, maior que 6) e ainda deixar folga de ao menos dois polls para a escalada caber — a fixture deriva `espera = reserva + folga` da reserva medida e **reprova** se `espera ≤ reserva`, porque nesse regime D4 desliga o ramo, o esperante sai 75 e o cenário fica vermelho contra uma implementação correta. Os tetos hoje usados na suíte (`--timeout 2`, `4`, `5`, `6`) caem todos nesse buraco. E a posse tem de ser velha o bastante para o disparo cair em `waited = 0` (`idade ≥ espera − reserva`), senão o cenário mede o relógio e não o rebaixamento | o esperante adquire **dentro do teto de espera**, com o decorrido em torno da reserva, e o aviso nomeia declarado, efetivo e teto de espera | **vermelho por ausência real** — é a #137 na forma generalizada, e hoje o esperante só desiste |
| [6] | o aviso do rebaixamento **não** aparece no caminho livre | mesmo `forge.yaml` de [5], lock livre | rc 0 e **nenhum** aviso de rebaixamento na saída | verde hoje por vacuidade — declarado; é a guarda de ruído do `w154[f]` |
| [7] | ÓRFÃO por beneficiário morto: detentor VIVO, beneficiário declarado e MORTO | lock com `beneficiary` de um PID morto, detentor `sleep` vivo, posse **recente**, e **`stale_after_s: 0` declarado**, que desliga o ramo de idade e faz o recolhimento ser provadamente pelo caminho de beneficiário em vez de por corrida entre os dois ramos. **Pré-condição numérica, irmã da do `[4]`:** o teto de espera tem de ser **maior que a reserva medida** — TERM mais graça mais KILL mais confirmação não cabem abaixo dela, e com `espera ≤ reserva` o esperante sai 75 no meio da escalada —, derivado da reserva pelo implementador, com reprovação do cenário se `espera ≤ reserva` | o esperante adquire com o teto de posse **desligado**, o que prova que o caminho é o de beneficiário, e a mensagem diz beneficiário, não idade | **vermelho por ausência real** — é a #144; medido: `_fhm_alive` diz vivo, rc 75 |
| [8] | contrapositiva de [7]: beneficiário VIVO com token conferindo | idêntico a [7], beneficiário vivo, **e `stale_after_s: 0` declarado** — a cláusula é obrigatória e não decorativa: com o ramo de idade armado, D4 garante que a posse é recolhida por idade antes do teto de espera, e o cenário cairia contra uma implementação correta, ou passaria pelo motivo errado se a fixture por acaso omitisse `acquired_at` | rc 75 e lock preservado | verde hoje por vacuidade — declarado; discrimina contra "reclamar todo detentor vivo". O modo que sustenta o 75 é o **(ii)** da enumeração de D4, e ele está declarado em vez de acidental |
| [9] | beneficiário com PID RECICLADO: PID vivo, token divergente | `beneficiary` de um PID vivo, `beneficiary_token` de outro processo, **`stale_after_s: 0` declarado** e teto de espera maior que a reserva medida | tratado como morto, posse recolhida, e a mensagem é a de beneficiário | **vermelho por ausência real** — e discrimina contra checagem por PID puro |
| [10] | beneficiário AUSENTE (lock legado, `heavy-run.sh`, versão anterior), em DOIS arranjos de regime | (a) lock sem os campos novos, detentor vivo, **`stale_after_s: 0` declarado**; (b) o mesmo lock, agora com `acquired_at` velho e o ramo de idade **armado** (teto de espera maior que a reserva) | em (a) **não** é recolhido — rc 75, lock intacto, e nenhuma menção a beneficiário na saída; em (b) é recolhido por IDADE e a mensagem é a de idade, nunca a de beneficiário | **misto.** (b) é **vermelho por ausência real**; (a) é a garantia de interoperabilidade de D2 e nasce verde. O `stale_after_s: 0` de (a) é o que torna o rc asseverável: sem ele, com o ramo armado, o lock de (a) seria recolhido por idade e o cenário mediria outra coisa |
| [11] | `ppid` do detentor é 1 com beneficiário VIVO | detentor órfão reparentado (`( cmd & )`), `beneficiary` vivo, **`stale_after_s: 0` declarado** — mesma obrigação de `[8]`, e pelo mesmo motivo | **não** é recolhido: rc 75 e lock intacto | verde hoje por vacuidade — declarado; é o cenário que reprova a implementação ingênua da sugestão 1 da #144, e por isso vale a linha. Modo **(ii)** de D4 |
| [12] | `ppid` do detentor NÃO é 1 e o beneficiário está morto | detentor filho normal do gate, `beneficiary` morto, **`stale_after_s: 0` declarado**, teto de espera maior que a reserva medida | **é** recolhido, com a mensagem de beneficiário | **vermelho por ausência real**; par com [11], os dois juntos provam que o critério não é `ppid` |
| [13] | encerramento educado: detentor bloqueado em `wait`, com trap armado | detentor real que adquire pela biblioteca e espera por `wait`; o gatilho do recolhimento é o **beneficiário morto**, com **`stale_after_s: 0` declarado** para que o instante do disparo seja `waited = 0` e a medição da graça não fique dependendo do relógio de idade | o lock some **durante a graça**, a mensagem diz que o detentor liberou após o sinal, e **não** há recolhimento forçado | **vermelho por ausência real** — não há sinal nenhum sendo enviado hoje |
| [14] | escalada: detentor em comando de PRIMEIRO PLANO, que ignora `TERM` na prática | detentor real cujo trabalho é comando em primeiro plano; mesmo gatilho e mesmo `stale_after_s: 0` de [13], pelo mesmo motivo | a graça expira, a escalada mata o detentor, a morte é confirmada, e só então o lock é recolhido | **vermelho por ausência real**; é o caso REAL (2.1), e sem ele o gate mediria só o caminho fácil |
| [15] | morte NÃO confirmada ⇒ recolhimento RECUSADO | detentor que a bancada torna inalcançável ao encerramento; ver a nota abaixo da tabela. Mesmo gatilho de beneficiário e mesmo `stale_after_s: 0`, sem o qual o 75 asseverado aqui teria um segundo caminho para nascer e o cenário não distinguiria "recusei recolher" de "recolhi por idade e falhei" | o lock **não** é removido, o esperante sai 75, e a mensagem distingue "tentei recolher e não consegui" de "não precisei recolher" | **vermelho por ausência real** — o terceiro estado não existe |
| [16] | TERMINAÇÃO: recolhimento que falha de forma persistente não vira laço infinito | terceiro recria o lock a cada volta; mesmo gatilho de beneficiário e mesmo `stale_after_s: 0` de [13] | o esperante **termina** com 75 dentro de um teto de parede próprio do cenário | **vermelho por ausência real** — hoje o ramo nem existe; é a asserção que impede D7 de ser esquecido |
| [17] | CANAL REAL: `pre-push` do template com o lock tomado por um detentor cujo beneficiário morreu | fixture git com hook real, `heavy_mutex.enabled: true`, **`heavy_mutex.stale_after_s: 0` no `forge.yaml` da fixture** — sem ela o recolhimento poderia sair pelo ramo de idade e o cenário deixaria de provar o canal do beneficiário, que é o que a M8 muta —, e um sinal positivo de execução da carga | o push **não** fica preso: o hook recolhe a posse e a carga executa, com o marcador que só ela escreve | **vermelho por ausência real** — e é a exigência de `testing/gate-delivery-channel.md`, porque o defeito foi medido nesse canal |
| [18] | CANAL REAL, contrapositiva: detentor com beneficiário VIVO e posse nova | mesmo arranjo, beneficiário vivo, **e o mesmo `stale_after_s: 0` no `forge.yaml` da fixture** — aqui a cláusula é a diferença entre verde e vermelho fabricado, porque com o ramo armado a posse nova é recolhida antes do teto de espera (D4) e o push deixaria de ser bloqueado. É o mesmo achado que derrubou `[8]` e `[11]`, estendido ao canal real por varredura desta revisão; o revisor não nomeou este cenário | o hook **não** executa a carga (o marcador não existe) e o push é bloqueado | verde hoje por vacuidade — declarado; é a guarda contra um recolhimento que passe a atropelar posse legítima pelo canal real. Modo **(ii)** de D4 |
| [19] | CONTRATO de `forge_heavy_mutex_status`, e a ORIGEM do número da idade | os três estados de posse, com um detentor recém-nascido segurando um lock de `acquired_at` antigo | a saída distingue posse legítima, posse órfã por beneficiário e posse estagnada; a idade da posse estagnada vem de `acquired_at` e **não** do `ps -o etime=` do detentor (a fixture separa os dois: processo novo, posse velha); e o rc continua 1 com lock tomado e 0 com lock livre | **vermelho por ausência real** para os dois estados novos; a origem do número é vermelha hoje por outro motivo, medido em §1.3 — o `há 00:00` de hoje é o `etime` do processo, e um estado "estagnada" que herde essa origem imprime o número errado; o rc é contrato de hoje e **não** muda. O `status` é leitura e não entra no laço de espera, então nenhum regime de D4 o alcança |
| [20] | CONTRATO de argumento | — | `--beneficiary` sem valor, com valor não numérico, ou com uma flag como valor devolve 64; `--label ""` devolve 64; `--label` legítimo continua gravando | **vermelho por ausência real** para `--beneficiary`; medido para `--label ""`, que hoje grava campo vazio |
| [21] | CONTRATO de schema, com PARIDADE exata em vez de relaxamento genérico | seis `forge.yaml` sintéticos, um por asserção de validação, mais um predicado de prosa sobre a `description` | `heavy_mutex.stale_after_s` inteiro ≥ 0 valida; `stale_after_s` negativo e `stale_after_s: "abc"` **não** validam; `heavy_mutex.root` com o token literal `${TMPDIR:-/tmp}` valida; **`heavy_mutex.root: ""` valida**, que é o primeiro braço do `case` do leitor e a metade que a revisão 2 pegou faltando na paridade; `heavy_mutex.root: relativo/nao-absoluto` continua **não** validando, que é a metade sem a qual o relaxamento seria um `pattern` inútil; e o predicado de prosa, agora **mecânico e não retórico**: a `description` do bloco `heavy_mutex` **não** contém a string literal `nunca em $TMPDIR` **e** contém a string literal `${TMPDIR:-/tmp}`, as duas medidas com `grep -aF` sobre o arquivo do schema | **vermelho por ausência real** — medido em §1.5 (`additionalProperty: stale_after_s` e `must match pattern ^/`, sobre os `forge.yaml` reais de dois consumidores) e em D12 para as duas metades do predicado de prosa, que hoje devolvem 1 e 0 ocorrências, isto é o oposto exato do exigido |
| [22] | PBT sobre a derivação do teto efetivo | ver §6 | a invariante de D4 vale para toda entrada gerada, **e a consequência dela também**: para todo efetivo positivo, `efetivo < espera` — que é a propriedade da qual o §4.1 inteiro depende | **vermelho por ausência real** — a função não existe |
| [23] | CONTADOR DE CONTROLE | — | ver §7 | **não falha por ausência** — verde por construção |
| [24] | SENTINELA de isolamento | — | o lock real da máquina (`/tmp/forge-heavy-suite.lock` e o do recurso declarado) tem o mesmo estado no início e no fim do gate, e o conjunto de `<lock>.reaping.*` sob a raiz real tem delta vazio | **não falha por ausência** — é a sentinela do próprio gate, e o vermelho dela é defeito do gate |
| [25] | LEITURA de campo ausente ou ilegível: idade não computável NÃO é reclamável por idade | matriz de locks de detentor VIVO **e sem o campo `beneficiary`** (para que o único ramo capaz de agir seja o de idade, por D2), com teto de espera ≥ 11 e sem `stale_after_s` declarado — o ramo de idade fica ARMADO —, variando só o campo `acquired_at`: ausente, vazio, `abc`, `0`, `-1` e um carimbo no futuro; o controle pareado é o mesmo lock com `acquired_at` genuinamente velho | nas seis variações o esperante **não** recolhe e sai 75 com o lock intacto; no controle ele recolhe — sem o controle o cenário aprovaria uma implementação que nunca recolhe nada | **vermelho por ausência real** nas duas metades hoje (não há ramo de idade), e é o cenário que impede a leitura "ausente = infinitamente velho", que deixaria `w151[49](c)` vermelho — ver D5. É o único cenário do gate que assevera 75 contra detentor vivo pelo modo **(iii)** de D4, e por isso a ausência de `beneficiary` na fixture é cláusula e não detalhe |
| [26] | LEITURA de `beneficiary` malformado NÃO é reclamável por beneficiário, e `0` não vira "vivo" | mesma matriz, agora sobre `beneficiary`: ausente, vazio, `abc`, `0`, `-1`, e um `beneficiary` válido de PID MORTO como controle pareado — **com `stale_after_s: 0` declarado em todas as sete variações**, sem o qual os locks carimbados com `acquired_at` válido seriam recolhidos por idade em `espera − reserva` e a asserção sobre o rc mediria o ramo errado. É a ressalva da revisão 2, aceita: sem a cláusula, a asserção teria de ser sobre a MENSAGEM; com ela, o rc volta a ser asseverável e a mensagem também | nas cinco variações malformadas o esperante **não** recolhe por beneficiário — rc 75, lock intacto; no controle ele recolhe e a mensagem é a de beneficiário | **vermelho por ausência real**; o caso `0` é o que a bancada de §2.2 mostrou morder de verdade, porque `kill -0 0` devolve sucesso e um campo corrompido para zero se pareceria com beneficiário vivo |
| [27] | SILÊNCIO do rebaixamento derivado, e ruído do rebaixamento declarado | dois arranjos com contenção observada e detentor vivo: (a) sem `stale_after_s` declarado e teto de espera 9, em que o efetivo cai de 4 para 3 pelo caminho derivado; (b) com `stale_after_s: 3600` declarado e teto de espera 20, em que o efetivo cai para 14 | em (a) **nenhuma** linha de aviso de rebaixamento na saída, e a linha `espera ......` do bloco de contenção informa o teto de posse efetivo; em (b) o aviso existe e nomeia os três números. **Nos dois arranjos o ramo de idade está ARMADO e o desfecho é o recolhimento** (aos ~3s em (a), aos ~14s em (b)): a asserção é sobre a SAÍDA observada no primeiro bloco de contenção, nunca sobre o rc, e a fixture captura a saída até o primeiro bloco em vez de esperar o desfecho | **vermelho por ausência real** em (b); a metade (a) é a guarda de ruído e nasce verde — ela existe para reprovar a implementação que passa a avisar em toda espera curta, que é a leitura alternativa que D4 descarta |

### 4.1 Regime do ramo de idade em cada cenário — a declaração que a consequência aritmética de D4 exige

A consequência aritmética escrita em D4 diz que, **com o ramo de idade armado e a idade legível, um detentor vivo que não solta é SEMPRE recolhido antes do teto de espera**. Isso torna "o esperante sai 75 contra um detentor vivo" uma asserção que só é satisfazível em três regimes, e a enumeração deles é exaustiva porque ela é a leitura direta do `case` da derivação mais a primeira linha da tabela de D5: **(i) desligado por aritmética** (`espera ≤ reserva`, o efetivo é zero); **(ii) desligado por declaração** (`stale_after_s: 0` em qualquer degrau, com qualquer teto de espera); **(iii) armado com idade não computável** (lock sem `acquired_at` legível).

A tabela abaixo declara o regime de cada um dos vinte e sete cenários e o modo que sustenta o desfecho. Ela é a régua que impede a classe de defeito que derrubou a revisão 2: um cenário que assevere 75 sem declarar o modo passa hoje por vacuidade e cai na entrega, e um cenário que assevere "não recolhe" com o ramo armado é vermelho fabricado. **Toda linha desta tabela é conferível contra a tabela da §4 sem sair do documento**, e as duas mudam juntas.

| Cenário | Regime do ramo de idade | Como o regime é fixado | Desfecho asseverado contra o detentor |
|---|---|---|---|
| `[1]` | ARMADO | `stale_after_s` pequeno declarado, `declarado + reserva ≤ espera` | recolhimento por idade (rc 0) |
| `[2](a)` | ARMADO | `stale_after_s: D` declarado, `D ≥ 2·reserva`, `espera ≥ D + reserva` | recolhimento por idade, **não antes de `D`** |
| `[2](b)` | DESLIGADO — modo (i) | `espera ≤ reserva` | rc 75, lock intacto |
| `[3]` | DESLIGADO — modo (ii) | `stale_after_s: 0` | rc 75, lock intacto, sem linha de recolhimento |
| `[4]` | ARMADO | caminho derivado, `espera ≥ 11` | recolhimento das DUAS posses, em instantes distintos |
| `[5]` | ARMADO | declarado maior que a espera, rebaixado para `espera − reserva`; `espera > reserva` | recolhimento por idade dentro do teto de espera, com aviso |
| `[6]` | irrelevante | lock LIVRE, não há detentor | rc 0, sem aviso |
| `[7]` | DESLIGADO — modo (ii) | `stale_after_s: 0`, `espera > reserva` | recolhimento por BENEFICIÁRIO (rc 0) |
| `[8]` | DESLIGADO — modo (ii) | `stale_after_s: 0` | rc 75, lock intacto |
| `[9]` | DESLIGADO — modo (ii) | `stale_after_s: 0`, `espera > reserva` | recolhimento por BENEFICIÁRIO (rc 0) |
| `[10](a)` | DESLIGADO — modo (ii) | `stale_after_s: 0` | rc 75, sem menção a beneficiário |
| `[10](b)` | ARMADO | `stale_after_s` pequeno, `espera > reserva` | recolhimento por IDADE (rc 0) |
| `[11]` | DESLIGADO — modo (ii) | `stale_after_s: 0` | rc 75, lock intacto |
| `[12]` | DESLIGADO — modo (ii) | `stale_after_s: 0`, `espera > reserva` | recolhimento por BENEFICIÁRIO (rc 0) |
| `[13]` | DESLIGADO — modo (ii) | `stale_after_s: 0`, `espera > reserva` | liberação do detentor DURANTE a graça |
| `[14]` | DESLIGADO — modo (ii) | `stale_after_s: 0`, `espera > reserva` | escalada, morte confirmada, recolhimento |
| `[15]` | DESLIGADO — modo (ii) | `stale_after_s: 0`, `espera > reserva` | rc 75 com a terceira mensagem |
| `[16]` | DESLIGADO — modo (ii) | `stale_after_s: 0` | rc 75 dentro do teto de parede do cenário |
| `[17]` | DESLIGADO — modo (ii) | `stale_after_s: 0` no `forge.yaml` da fixture | push passa, carga executa |
| `[18]` | DESLIGADO — modo (ii) | `stale_after_s: 0` no `forge.yaml` da fixture | push bloqueado, carga NÃO executa |
| `[19]` | fora do laço | `status` é leitura, não espera | três estados no diagnóstico |
| `[20]` | fora do laço | contrato de argumento | rc 64 e rc 0 conforme o caso |
| `[21]` | fora do laço | contrato de schema | validação e predicado de prosa |
| `[22]` | fora do laço | PBT sobre a função pura | a invariante e a consequência |
| `[23]` | fora do laço | contador de controle | 27 de 27 |
| `[24]` | fora do laço | sentinela de isolamento | delta vazio na raiz real |
| `[25]` | ARMADO — modo (iii) | `espera ≥ 11`, sem `stale_after_s`, sem `beneficiary`, `acquired_at` ilegível | rc 75 nas seis variações; recolhimento no controle |
| `[26]` | DESLIGADO — modo (ii) | `stale_after_s: 0` nas sete variações | rc 75 nas cinco malformadas; recolhimento no controle |
| `[27](a)` | ARMADO | derivado, `espera 9`, efetivo 3 | asserção sobre a SAÍDA do primeiro bloco de contenção |
| `[27](b)` | ARMADO | declarado 3600, `espera 20`, efetivo 14 | asserção sobre a SAÍDA do primeiro bloco de contenção |

Trinta linhas para vinte e sete cenários, porque `[2]`, `[10]` e `[27]` têm dois arranjos cada — que é exatamente a contagem de mistos declarada acima da tabela da §4, e o subcontador de cada um deles está na §7.

**A leitura desta tabela, e ela é a resposta ao bloqueador novo da revisão 2.** **Dez** linhas asseveram rc 75 ou "não recolhe" contra um detentor vivo, e **nenhuma** delas o faz com o ramo armado e a idade legível: **oito** estão no modo (ii) por `stale_after_s: 0` declarado (`[3]`, `[8]`, `[10](a)`, `[11]`, `[15]`, `[16]`, `[18]`, `[26]`), **uma** (`[2](b)`) está no modo (i) por `espera ≤ reserva`, e **uma** (`[25]`) está no modo (iii) e é o cenário que existe para medir justamente esse modo. Oito mais uma mais uma são dez.

A dependência que isso cria é nominal e não escondida. **Catorze** das trinta linhas estão no modo (ii); uma delas é o próprio `[3]`, que é quem assevera que `stale_after_s: 0` é honrado, e as outras **treze** dependem dele — `[7]`, `[8]`, `[9]`, `[10](a)`, `[11]`, `[12]`, `[13]`, `[14]`, `[15]`, `[16]`, `[17]`, `[18]` e `[26]`. É concentração de risco e está escrita: se a implementação ignorar o `0`, treze linhas medem outra coisa e uma só cai. Quem cobre o resto é a mutação **M16**, que encarna a implementação que recolhe sempre e derruba **nove** das trinta linhas da §4.1 de uma vez, que se desdobram em **dezoito** asserções — e é por isso que ela existe.

**Nota de [15], e ela é onde o implementador tem trabalho de prova, não de escrita.** "Morte não confirmada" precisa de uma fixture que produza um detentor que sobreviva ao encerramento, e as três montagens óbvias têm problema: outro uid exige privilégio que a suíte não tem; um processo imune a `KILL` não existe em espaço de usuário; e substituir o `kill` por um stub testa o stub. A propriedade a provar é: **o recolhimento não acontece quando `_fhm_alive` do detentor continua verdadeiro depois da escalada, e o esperante sai 75 com a terceira mensagem**. O implementador escolhe como produzir esse estado — uma sonda de teste no molde das **duas** que a biblioteca já tem é o caminho que o próprio arquivo já legitimou para cenários que não podem depender de vencer uma corrida — e **prova que a fixture produz o estado antes de rodar a asserção**, colando a saída no PR. Sem essa prova, [15] mede outra coisa e a mutação M6 vira no-op.

As duas sondas existentes são `FORGE_HEAVY_MUTEX_REVOKE_PROBE` (linha 647) e `FORGE_HEAVY_MUTEX_STEAL_PROBE` (linha 651), e são só essas duas: a revisão 1 desta especificação citava uma terceira, `FORGE_HEAVY_MUTEX_CLAIM_HOLD_S`, que **não existe** — `grep -arn 'CLAIM_HOLD' tests/ template/ bin/ installer/` devolve rc 1 e saída vazia, com o universo da varredura provado em §1.1.

**Nota de [13] e [14], e ela é a medição de 2.1 virando obrigação.** Os dois cenários só discriminam se o trabalho do detentor for de naturezas **diferentes**: em [13] ele espera por `wait`, e o `trap` roda em ~1s; em [14] ele está num comando em primeiro plano, e o `trap` não roda dentro da graça. Uma fixture que use a mesma forma nos dois faz um dos dois medir o outro. E o `>/dev/null 2>&1` no lançamento em segundo plano é obrigatório: sem ele, `P="$(lanca)"` fica pendurado até o fim do `sleep`, porque o processo em segundo plano herda o descritor da substituição de comando. Isso não é teoria — perdi uma bancada inteira para esse exato descuido, que o cabeçalho do `w151` já documenta na função `sleeper`.

**Nota de [17] e [18] — o sinal positivo de execução.** `gate-delivery-channel.md` exige que a prova de canal distinga "não encontrei violação" de "não rodei". Em [17] o sinal é o marcador que a carga do `pre-push` escreve; em [18] é a **ausência** dele somada ao rc de bloqueio do hook, que juntos são um estado observável e não um silêncio. O `w151[36]` já monta um `pre-push` real com stubs neutros dos alvos declarados e é a fixture a reaproveitar.

---

## 5. Prova de mutação, com controle e recontrole

Alvos: `template/.forge/scripts/lib/heavy-mutex.sh`, `template/.forge/hooks/git/pre-push` e `template/.forge/schemas/forge.schema.json`.

São **dezessete** linhas, e todas elas são **A MEDIR**, e a razão é dita em vez de escondida: os alvos das mutações **não existem hoje**, então cada linha é hipótese até o passo 6 da §10. A regra do plano-mestre vale integralmente, e tem uma exceção obrigatória: quando a mutação sai **no-op**, quem se corrige não é a linha, é o **cenário**, cujo sinal não discrimina. Enfraquecer a linha nesse caso é registrar por escrito que a guarda foi testada quando ela não foi, que é o padrão de LDG-0164 e de `feedback-mutacao-fantasma-restore`.

| Mutação | Alvo | O gate tem de dizer |
|---|---|---|
| M1 — remover a checagem de beneficiário do laço | lib | `FAIL [7]`, `[9]`, `[12]`, `[13]`, `[14]`, `[15]`, `[16]`, `[17]` e o controle de `[26]` — a lista cresceu nesta revisão porque `[13]` a `[16]` passaram a ter o beneficiário morto como gatilho declarado do recolhimento (§4.1), e sem a checagem eles não têm outro caminho, já que o ramo de idade está desligado por `stale_after_s: 0` naqueles cenários. Continuam verdes `[1]`, `[2]`, `[4]`, `[5]` e `[25]`, que caem no caminho de idade |
| M2 — remover a checagem de idade do laço | lib | `FAIL [1]`, `[2](a)`, `[4]`, `[5]`, `[10](b)`, `[27]` na metade que assevera o teto efetivo na linha de contenção, e o **controle** de `[25]`, que é o único lock daquele cenário que deve ser recolhido por idade; `[7]` e os demais cenários de beneficiário continuam verdes. O controle de `[25]` entrou nesta revisão: sem ele a linha deixava de fora a única asserção positiva de recolhimento por idade da matriz de leitura |
| M3 — desfazer a derivação, fixando o teto de posse num literal | lib | `FAIL [4]` apenas; `[1]` continua verde porque ele declara a chave. **Pré-condição da mutação, e ela existe porque a revisão 1 mostrou que sem isso a linha é no-op numa faixa inteira:** o literal precisa ser diferente do valor que a derivação produz na fixture do `[4]`, e como o `[4]` roda com teto de espera ≥ 11 o valor derivado é conhecido; o implementador **mede** o efetivo antes e depois da mutação (a linha `espera ......` do bloco de contenção o imprime, por D4) e só registra a linha se os dois números diferirem. Com teto de espera abaixo de 11 a derivação não governa nada, porque o rebaixamento de D4 decide sozinho, e a mutação seria o padrão de LDG-0164 com outro rosto |
| M4 — desfazer o rebaixamento de D4, honrando o valor declarado | lib | `FAIL [5]`; `[6]` continua verde, porque sem rebaixamento não há aviso a suprimir |
| M5 — trocar o critério de D1 por `ppid == 1` | lib | `FAIL [11]` e `FAIL [12]` — os dois, e em direções opostas: `[11]` passa a recolher posse legítima e `[12]` deixa de recolher a ilegítima. É a mutação mais importante da matriz, porque ela é a implementação que a issue sugere |
| M6 — remover a confirmação de morte, recolhendo logo depois da escalada | lib | `FAIL [15]`; `[14]` continua verde, porque nele a morte de fato ocorre |
| M7 — remover o incremento de `waited` pela graça e o teste de teto dentro do ramo (desfazer D7) | lib | `FAIL [16]` por estouro do teto de parede do cenário, nunca por asserção de conteúdo |
| M8 — retirar `--beneficiary` da chamada do hook | hook | `FAIL [17]` apenas; `[7]` continua verde, porque ele chama a biblioteca direto. É a mutação de **canal** que `gate-delivery-channel.md` exige |
| M9 — aceitar `--beneficiary` sem validar o valor | lib | `FAIL [20]` apenas |
| M10 — devolver o `pattern` de `root` e remover `stale_after_s` do schema | schema | `FAIL [21]` apenas, e a mutação tem **três** metades porque a paridade tem três braços: reverter o `pattern` para `^/` derruba de uma vez as asserções do token literal **e** do valor vazio, então o implementador as roda separadas — `^/` sozinho, depois `^(?:\$\{TMPDIR:-/tmp\}|/.*)$` (que aceita o token e recusa o vazio, e é exatamente a paridade incompleta da revisão anterior) —, e a terceira metade é remover a propriedade `stale_after_s`. Sem a segunda, a correção do braço vazio entra sem que nada morda, que é como LDG-0159 sobreviveu da primeira vez |
| M15 — devolver a `description` do bloco `heavy_mutex` ao texto que proíbe `$TMPDIR`, mantendo o `pattern` novo | schema | `FAIL [21]` no **predicado mecânico** de D12, e não numa asserção de prosa: a mutação repõe a string literal `nunca em $TMPDIR` e retira a string literal `${TMPDIR:-/tmp}`, e as duas metades do predicado (`grep -aF`, contagem 0 exigida na primeira e ≥ 1 na segunda) invertem. É a mutação que existe porque a asserção correspondente é a única do `[21]` que não é sobre validação e sim sobre o contrato **dizer** o que ele faz — sem ela, o schema volta a ensinar o oposto do que aceita e nada acusa. **A revisão 2 estava certa em chamar a versão anterior de decorativa:** ela asseverava "a description não contradiz mais o que o pattern aceita", que não tem alvo mecânico; o predicado de D12 tem, e o controle dele está medido lá |
| M11 — emitir o aviso de rebaixamento incondicionalmente | lib | `FAIL [6]` apenas; `[5]` continua verde |
| M12 — renomear a evidência para `<lock>.reaping.stale.<pid>…` | lib | `FAIL` do cenário de `sweep`, que precisa existir **dentro de `[14]`**, com nome próprio na linha de log, porque `[14]` é o único cenário em que o recolhimento de fato ocorre por escalada e produz evidência nova. **Ressalva de escopo, declarada porque ela muda o que a linha prova:** se a delegação de D6 ao `_fhm_reclaim_orphan` for total, como o texto de D6 diz, esta onda não cria sítio novo de nomeação e a mutação passa a mutar `heavy-mutex.sh:616`, que é código pré-existente. A linha continua valendo — ela prova que o cenário novo **cobre** a invariante de nomeação, que hoje nenhum cenário cobre —, mas ela é prova sobre invariante herdada e não sobre a decisão D6, e o PR precisa dizer isso ao registrá-la |
| M13 — tratar `acquired_at` ausente ou ilegível como infinitamente velho (desfazer a tabela de leitura de D5) | lib | `FAIL [25]` nas seis variações, e é a mutação que fecha o BLOQUEADOR 1 da revisão 1: sem ela, a leitura oposta entra na implementação sem que nada morda, e o preço é o `w151[49](c)` vermelho — que o gate desta onda **não** veria, porque ele é de outro arquivo. Por isso o passo 6 da §10 manda rodar o `w151` inteiro sob esta mutação, e não só o gate novo. **Nenhum outro cenário do gate novo muda sob ela**, e isso é conferível pela §4.1: `[10](a)`, `[8]`, `[11]`, `[18]` e os demais que asseveram 75 estão no modo (ii), com o ramo desligado por declaração, então a leitura de `acquired_at` não é alcançada ali |
| M14 — emitir o aviso de rebaixamento também no caminho derivado | lib | `FAIL [27](a)` apenas; `[27](b)` continua verde, porque o aviso do caminho declarado não muda. É o contrafactual da decisão de silêncio de D4, e sem ele a decisão fica escrita sem guarda |
| M16 — RECOLHER SEMPRE: tratar todo detentor vivo como posse ilegítima, ignorando o teto de posse, o `stale_after_s: 0` e a tabela de leitura de D5 | lib | `FAIL [2](a)` (o decorrido até a aquisição cai para a ordem da reserva, muito abaixo de `D`), `FAIL [2](b)`, `[3]`, `[8]`, `[10](a)`, `[11]`, `[18]`, as seis variações de `[25]` e as cinco de `[26]`. Continuam verdes todos os cenários de recolhimento legítimo — `[1]`, `[4]`, `[5]`, `[7]`, `[9]`, `[12]`, `[17]` —, que é o que torna a mutação discriminante em vez de destrutiva. **É a mutação que a revisão 2 mostrou faltar:** a especificação nomeava o par `[1]`+`[2]` como o discriminador contra "recolhe sempre", mas a contrapositiva daquele par era insatisfazível e nenhuma linha desta matriz encarnava a implementação errada. Agora encarna, e ela morde em **nove** linhas da §4.1, que são **dezoito** asserções: sete linhas de asserção única mais as seis variações do `[25]` e as cinco do `[26]` |
| M17 — colapsar os dois estados novos do `forge_heavy_mutex_status` num só, e fazer a idade da posse estagnada vir do `ps -o etime=` do detentor em vez do `acquired_at` do lock | lib | `FAIL [19]` nas duas metades, e em direções distintas: o colapso derruba a distinção entre posse órfã por beneficiário e posse estagnada, e a troca de origem derruba o número, porque a fixture do `[19]` separa os dois de propósito (detentor recém-nascido segurando lock de `acquired_at` antigo). **Esta linha é achado desta revisão, não do veredito:** varrendo a matriz atrás de cenário sem contrafactual, o `[19]` era o único cenário de decisão sem mutação nenhuma apontando para ele — e a origem do número é exatamente o defeito que a §1.3 mediu no `há 00:00` de hoje, medido de novo nesta rodada na linha **464** da biblioteca (`age="$(LC_ALL=C ps -o etime= -p "$hp" ...)"`), que alimenta a **466** |

**Quais cenários NÃO têm mutação apontando para eles, e por quê — a enumeração existe para que a lacuna seja declarada em vez de descoberta.** Dos vinte e sete, três: o `[22]`, que não precisa de linha própria porque **M3** e **M4** já mutam a função que ele submete ao PBT e a invariante cai sob as duas; e o `[23]` e o `[24]`, que são o contador de controle e a sentinela de isolamento do próprio gate — mutar o produto para derrubá-los testaria o gate e não a biblioteca, e o vermelho deles é sempre defeito do gate. Todos os outros vinte e quatro têm ao menos uma mutação nomeada acima. O `[19]` estava nesta lista até esta revisão, indevidamente, e saiu dela com a **M17**.

Mecânica obrigatória, e é o idioma do repositório, não invenção desta spec:

```bash
ORIG="$T/heavy-mutex.sh.orig"
cp "$ALVO" "$ORIG"          # CONTROLE VEM DA ÁRVORE DE TRABALHO, NUNCA DO HEAD.
# mutação — aspas SIMPLES no perl, e '$' do lado direito SEMPRE escapado.
# LDG-0164: com aspas duplas, o $x do lado direito é variável do PERL, vazia, e a mutação vira
# no-op silencioso enquanto o `cmp` confirma alegremente que o arquivo mudou.
perl -0pi -e 's/<padrão>/<substituto com \$ escapado>/' "$ALVO"
# ... roda as asserções, observa o FAIL esperado ...
cp "$ORIG" "$ALVO"
cmp -s "$ALVO" "$ORIG" || { echo "FAIL: restauração não bateu byte a byte"; exit 1; }
# RECONTROLE — sem isto a prova não vale: um restore quebrado deixa a mutação eterna e ninguém vê.
<reexecuta a asserção que a mutação derrubou; ela TEM de voltar a passar>
```

`cp "$ALVO" "$ORIG"` e não `git show HEAD:<path>`: as mutações rodam **depois** de implementar, e um controle vindo do HEAD é a versão pré-implementação — o `cp` de volta apagaria o trabalho não commitado e o `cmp` confirmaria que a restauração bateu.

Três alvos são arquivos **rastreados sob `template/`**, que é o que a sentinela de integridade da Onda A existe para proibir. Não há contradição, e vale a mesma nota que aquela onda faz: a sentinela compara **depois** de o gate terminar, o gate restaura antes de terminar, e se a restauração falhar quem pega é a própria sentinela, no gate seguinte da suíte.

---

## 6. Níveis de teste — onde cada um entra, e onde não se aplica

- **Unitário:** `[1]`-`[16]`, `[19]`, `[20]`, as duas matrizes de leitura `[25]` e `[26]`, e o par de arranjos de `[27]` — que não é matriz de leitura e sim de ruído, razão pela qual a §7 conta os subcontadores por regra (todo cenário com mais de um arranjo) e não por rótulo. Todos sobre a biblioteca em fixtures de `mktemp -d`, com `FORGE_HEAVY_MUTEX_TESTING=1` e `FORGE_HEAVY_MUTEX_ROOT` — a trava positiva que a própria biblioteca impõe (`_fhm_resolve_root:130-131`) e que impede a suíte de virar a carga que o mutex existe para conter.

- **PBT:** `[22]`, sobre a função de derivação do teto efetivo. O espaço de entrada é a quádrupla `(teto de espera, teto declarado, graça, poll)` sobre inteiros não negativos, e a propriedade é a invariante de D4 **mais a consequência dela**, em quatro partes: o efetivo é zero, ou o efetivo mais a reserva é menor ou igual ao teto de espera; o efetivo nunca é maior que o declarado quando o declarado é positivo; um declarado de zero produz sempre efetivo zero; e — a parte que entrou nesta revisão — **todo efetivo positivo é estritamente menor que o teto de espera**, que é a propriedade da qual a §4.1 inteira depende e que a bancada de D4 mediu por enumeração em 2716 combinações. Sem essa quarta parte, o PBT aprovaria uma derivação que arma o ramo sem deixar tempo para a escalada. **Não se usa `lib/pbt.mjs` aqui, e o motivo é medido, não preferência:** a função sob teste é bash, e reimplementá-la em JavaScript para submetê-la ao harness testaria a reimplementação, não o alvo — que é a forma mais cara de gate morto. A geração é um laço do próprio gate com semente impressa e reprodutível, com número de casos publicado (um PBT que rodou zero casos aprova por não ter olhado) e com pelo menos um **caso de veredito conhecido** dentro do próprio censo, que é a regra que `axis-fare-validator-0097` registrou no canal depois de publicar um zero absoluto sobre um universo que ele sabia não ser vazio.

- **Contrato:** `[19]`, `[20]` e `[21]`. As três fronteiras publicadas desta onda são a assinatura de `forge_heavy_mutex_acquire` (documentada no cabeçalho do `heavy-run.sh` e usada pelo `pre-push:245`), a saída de `forge_heavy_mutex_status` (consumida pelo `doctor.sh:206-208`, que a imprime inteira numa linha) e o bloco `heavy_mutex` do `forge.schema.json`. **Correção de uma afirmação da revisão 1 desta especificação**, que dizia que as três estavam no `machinery.lock` "de todos os cinco" consumidores: o lock não mora em `.forge/machinery.lock` e sim em **`.forge/cache/machinery.lock`** (`bin/forge.mjs:361` e `:384`), e com o caminho certo a medição é **quatro de cinco** — o `azim-crm` tem lock de 341 linhas gerado na `v0.1.0-rc24` e **sem** entrada para `scripts/lib/heavy-mutex.sh`. A conclusão não muda: mudança ali é mudança de contrato com adotante instalado e precisa de asserção que morda. O que muda é que o `azim-crm` não tem referência de drift para esse arquivo, o que é a mesma lacuna de LDG-0153 vista de outro ângulo.

- **Integração e canal real:** `[17]` e `[18]`, com `git push` de verdade sobre a fixture, pelo hook do próprio git. É onde os dois defeitos foram medidos em campo e é o que `gate-delivery-channel.md` exige. O `w151[36]` e o `[37]` já montam esse arranjo e são a base a reaproveitar.

- **E2E — não se aplica, com o motivo medido.** O E2E honesto desta onda seria dois `git push` concorrentes de dois repositórios distintos disputando o lock da máquina, com um deles morrendo no meio. Ele não cabe na suíte por duas razões que medi: a suíte **não tolera concorrência** (`feedback-suite-sem-concorrencia` registra falha fantasma em gate alheio, com log vazio), e um cenário que dispute o lock **real** contradiz a trava positiva que a própria biblioteca impõe e que o `w151[0]` afirma. A fronteira roteirizável termina em `[17]`/`[18]`, que exercitam o hook real contra um detentor real numa raiz isolada — e a diferença para o E2E é o segundo repositório, não o mecanismo.

---

## 7. Contador de controle, denominador fixo

O gate publica, e reprova em zero ou em divergência:

```
OK heavy-mutex-posse/universo — 27 cenário(s) executado(s) de 27 declarado(s)
```

Denominador **fixo e literal no fonte** (`DECLARADOS=27`), conferido contra o contador incrementado por cenário. Cenário que deixe de rodar por `case` que não casa, por `continue` ou por variável vazia derruba o gate em vez de sumir do log. É a única categoria de literal que a invariante 14 permite: o universo deste gate é a lista que o próprio arquivo declara, fechada por construção em tempo de escrita, e a divergência entre executado e declarado **é** o achado que o contador existe para produzir. Se a implementação acrescentar ou fundir cenários, o número muda **no mesmo commit** e a §4 é a autoridade de quem existe.

A regra do subcontador é declarada em vez de listada, para que ela não envelheça quando um cenário ganhar arranjo: **todo cenário com mais de um arranjo ou variação publica o próprio subcontador**, e reprova em divergência como o gate reprova. Pela §4 e pela §4.1 desta revisão eles são **seis**: `[2]` com 2 arranjos, `[10]` com 2, `[21]` com 6 documentos sintéticos mais 1 predicado de prosa, `[25]` com 6 variações mais 1 controle, `[26]` com 5 mais 1, e `[27]` com 2 arranjos. O motivo é o mesmo pelo qual o gate publica o dele: uma matriz que rode três das sete variações passa sem que nada acuse, e é assim que uma tabela de leitura vira decorativa. O `[2]` e o `[10]` entraram nesta lista nesta revisão, porque foi nesta revisão que os dois ganharam o segundo arranjo — e um arranjo de regime que deixe de rodar é exatamente o defeito que a §4.1 existe para impedir.

O PBT de `[22]` tem contador próprio, com o número de casos e a semente impressos, pelo mesmo motivo.

Chave de allowlist de universo vazio: **nenhuma**. Este universo nunca é legitimamente vazio, então não há entrada a declarar em `empty-universe-allowlist.txt` e o gate **não** usa `forge_universe_check` — a grafia da linha de contador é a acima, deliberadamente diferente da da lib, exatamente como a Onda A já decidiu para o gate cujo vazio não é legítimo.

O gate declara também um **teto de parede** próprio, no molde do `w151` e do `w154` (`W<NNN>_BUDGET_S`), com a derivação escrita no cabeçalho a partir do gasto solo medido pelo implementador em máquina ociosa, e com margem declarada. Não fixo aqui um número: seria prescrição de mecanismo não executado, e o gasto depende de quanto o implementador consegue encurtar as esperas sem descaracterizar `[13]`, `[14]` e `[16]`, que são cenários de tempo real por natureza.

---

## 8. Retrocompatibilidade — os cinco consumidores, medidos

**Estado de instalação, medido e não suposto — e a revisão 1 desta especificação errou aqui.** Ela afirmava que "os quatro repositórios do canal mais o `lionclaw` já aplicaram a 0.14.0". Falso: o cabeçalho de cada `.forge/cache/machinery.lock` registra a versão do template da última aplicação, e são **três** em 0.14.0, não cinco.

```
$ for r in axis-fare-validator axis-go-cloud Axis.PadSimulator azim-crm lionclaw; do lk=~/Documents/projects/$r/.forge/cache/machinery.lock; printf '%-20s linhas=%-5s heavy-mutex.sh: %s | %s\n' "$r" "$(wc -l < "$lk"|tr -d ' ')" "$(grep -ac 'scripts/lib/heavy-mutex.sh' "$lk")" "$(head -1 "$lk" | cut -c1-70)"; done
axis-fare-validator  linhas=403   heavy-mutex.sh: 1 | # forge machinery.lock — sha256 dos arquivos do template v0.14.0
axis-go-cloud        linhas=404   heavy-mutex.sh: 1 | # forge machinery.lock — sha256 dos arquivos do template v0.14.0
Axis.PadSimulator    linhas=398   heavy-mutex.sh: 1 | # forge machinery.lock — sha256 dos arquivos do template v0.11.0
azim-crm             linhas=341   heavy-mutex.sh: 0 | # forge machinery.lock — sha256 dos arquivos do template v0.1.0-rc24
lionclaw             linhas=403   heavy-mutex.sh: 1 | # forge machinery.lock — sha256 dos arquivos do template v0.14.0
```

Isso muda duas coisas desta seção. O `Axis.PadSimulator` — que é o repositório do patch local e o do protocolo legado — está **três releases atrás**, então o `forge update` que traz esta onda para ele traz junto tudo de 0.11.0 a 0.15.0, e a sobrescrita do patch não é um evento isolado. E o `azim-crm`, em `v0.1.0-rc24`, não tem sequer entrada de `heavy-mutex.sh` no lock.

**Quem tem o mutex ligado.** Dois de cinco: `axis-fare-validator` (`enabled: true`, `resource: axis-heavy-suite`, `root: "${TMPDIR:-/tmp}"`, `timeout_s: 1800`) e `Axis.PadSimulator` (mesmas três primeiras chaves, mais `stale_after_s: 3600`). O `axis-go-cloud` e o `lionclaw` declaram `enabled: false` com `resource: forge-heavy-suite` e `timeout_s: 1800`. O `azim-crm` **não declara bloco `heavy_mutex` nenhum** — correção de outra afirmação da revisão 1, que o descrevia como "enabled: false com o default": ele cai nos defaults da biblioteca por ausência, não por declaração, e a diferença importa porque quem não declara não aparece numa varredura de `forge.yaml`. Os cinco blocos estão colados em §1.5.

**Quem tem patch local na biblioteca.** Remedido com o caminho certo do lock (`.forge/cache/machinery.lock`; a revisão 1 procurava em `.forge/machinery.lock`, que não existe em nenhum dos cinco, e por isso a coluna "vs-lock" dela era inteiramente errada):

```
$ TPL_SHA=$(shasum -a 256 template/.forge/scripts/lib/heavy-mutex.sh | cut -d' ' -f1); for r in …; do … done
template sha: f84a84ed55fd
axis-fare-validator  local=54c174cc4d55 lock=f84a84ed55fd vs-lock=DIVERGE     vs-template=DIVERGE excecao=SIM
axis-go-cloud        local=f84a84ed55fd lock=f84a84ed55fd vs-lock=igual       vs-template=igual   excecao=nao
Axis.PadSimulator    local=7ac8b542099b lock=f84a84ed55fd vs-lock=DIVERGE     vs-template=DIVERGE excecao=nao
azim-crm             local=f84a84ed55fd lock=              vs-lock=sem-entrada vs-template=igual   excecao=nao
lionclaw             local=f84a84ed55fd lock=f84a84ed55fd vs-lock=igual       vs-template=igual   excecao=nao
```

A exceção do `axis-fare-validator` é a **linha 86** de `.forge/machinery-exceptions.txt`, com o sha do template e o motivo (`ancora o lock por chave do forge.yaml, não só por TMPDIR`). O `Axis.PadSimulator` não é "sem exceção declarada": ele **não tem o arquivo** `machinery-exceptions.txt` (medido com `ls`, que devolve `No such file or directory`), o que é um estado distinto e pior, porque nem a proteção da #131 nem uma correção dela o alcançam sem que alguém crie o arquivo primeiro.

**O que a release desta onda faz com os dois patches, lido no código do update e não suposto.** `scripts` está em `MACHINERY_DIRS` (`bin/forge.mjs:307`) e **fora** de `ENRICHABLE_DIRS` (`:352`), então o overlay sobrescreve o diretório inteiro. Isso tem três consequências e cada uma exige providência:

1. **O patch do `Axis.PadSimulator` é a recuperação por idade, e ele será sobrescrito.** É o único código em produção na máquina que hoje desfaz um travamento por detentor vivo — é ele que a medição de #137 vê agir quando a posse passa de 3600s. Esta onda **absorve a capacidade upstream**, com desenho diferente e melhor (D3, D4, D6), e é por isso que ela é urgente e não pode esperar: sem a absorção, o próximo `forge update` daquele repositório remove a recuperação e a máquina volta ao estado de #137 sem que nada explique. E como aquele repositório está em 0.11.0, o update que fará isso é grande, o que aumenta a chance de o WARN da sobrescrita passar despercebido no meio do log.
2. **O patch do `axis-fare-validator` tem exceção declarada** (`machinery-exceptions.txt`, linha 86). O `check-machinery-drift.sh` honra o arquivo; o **updater não sabe que ele existe**, e isso é a issue #131, que é da Onda L1. Esta onda não a resolve e depende dela para que a exceção daquele repositório sobreviva; a dependência está nomeada e não bloqueia, porque o conteúdo do patch daquele consumidor é a ancoragem por `forge.yaml`, que o template já tem.
3. **A sobrescrita não é muda, mas o aviso aponta para o lugar errado:** `bin/forge.mjs:628-643` compara local contra lock e contra template e imprime `WARN: drift local em <path> sobrescrito pelo template (fix local em maquinaria? faça upstream; backup em .forge.bak-N)` — e o destino **real** do backup é `.git/forge-backups/forge-N` (`bin/forge.mjs:598`), não `.forge.bak-N`. Quem ler o WARN procura no lugar que a mensagem indica e não acha. A divergência é item da Onda C/#101 e **não** desta onda; ela está registrada aqui porque a mensagem do liaison do passo 9 precisa dar o caminho certo, e não o da mensagem.

**O que muda de comportamento para quem já instalou.**

- **`Axis.PadSimulator`**: `stale_after_s: 3600` declarado contra `timeout_s: 1800` viola a invariante de D4 e passa a ser **rebaixado**, com aviso, para `1800 − 6 = 1794`. Isso muda o número que aquele repositório declarou — e muda para o valor que faz a #137 deixar de existir, que é o que ele pediu. O aviso nomeia os três números. Além disso, o `stale_after_s` daquele `forge.yaml` **passa a ser legal**: hoje ele reprova o schema com `additionalProperty`, medido em §1.5.
- **`axis-fare-validator` e `Axis.PadSimulator`**: `root: "${TMPDIR:-/tmp}"` passa a validar contra o schema, que hoje o recusa por `pattern`. Ganho puro, sem mudança de execução.
- **Todos os cinco**: a aquisição do `pre-push` passa a gravar dois campos a mais no lock. Campo novo em diretório de lock é aditivo — `_fhm_reclaim_orphan` lê `pid` e `token`, `release` lê `pid` e `nonce`, o `sweep` lê `pid` e `token`, e o protocolo legado lê `pid` e `acquired_at`. Nenhum deles enumera o diretório, então nenhum quebra.
- **Ninguém** vê o teto de espera mudar: o default 1800 fica como está, e o `w151[49]` da linha 1241 continua valendo palavra por palavra, porque ele exercita valores explícitos e não o default.
- **Todos os cinco, e este é o marcador que faltava — é MUDANÇA DE COMPORTAMENTO SOBRE POSSE LEGÍTIMA, não só sobre posse travada.** Pela consequência aritmética de D4, com o ramo armado **qualquer** posse que ultrapasse o teto efetivo enquanto alguém espera passa a ser encerrada, inclusive posse legítima e progredindo. Com os defaults (`timeout_s: 1800`, sem `stale_after_s`), o efetivo é **900s**: uma suíte pesada legítima que passe de quinze minutos com outro repositório esperando é interrompida com `TERM → graça → KILL`. Os dois repositórios que de fato têm o mutex ligado são exatamente os que isso alcança, e os `forge.yaml` deles dizem em letra que quinze minutos é pouco: o `Axis.PadSimulator` declara `stale_after_s: 3600` com o comentário *"3600 é o dobro do teto de espera: uma suíte pesada legítima cabe folgadamente em uma hora nas quatro árvores"* — e esse 3600 passa a ser rebaixado para 1794 —, e o `axis-fare-validator` declara `enabled: true` com `timeout_s: 1800` e **sem** `stale_after_s`, sobre um repositório cujo próprio comentário diz que *"dispara Gradle no push e divide a máquina com outros três"*, o que o deixa com o efetivo derivado de 900s. **O teto máximo obtenível é `teto de espera − reserva`**, então uma posse legítima de quarenta e cinco minutos não é protegível sem aumentar o teto de espera junto — a invariante de D4 faz dos dois um botão só, e isso é o preço declarado da decisão, não um efeito colateral. As duas saídas são as de D3 e as duas vão para o canal: aumentar `timeout_s` junto, ou declarar `stale_after_s: 0` e ficar com o comportamento de hoje. Sem este marcador, a onda entregaria uma interrupção de trabalho legítimo em três repositórios sem um único aviso escrito — foi o item (iv) do bloqueador novo da revisão 2, e ele estava certo.

**Convivência entre versões durante a implantação, que é o cenário real e precisa estar em letra.** Enquanto os cinco não estiverem na mesma versão — e a medição acima mostra que eles já não estão, com três versões diferentes instaladas hoje —, o mesmo lock é disputado por três protocolos.

- Esperante **novo** atrás de detentor **antigo**: o lock não tem `beneficiary`, então D2 se aplica; e ele também não tem `beneficiary_token`, o que cai na primeira linha da tabela de leitura de D5. A posse só é recolhível por idade. Correto e conservador.
- Esperante **antigo** atrás de detentor **novo**: comportamento idêntico ao de hoje — desiste com 75 no teto de espera. Nenhuma regressão.
- Esperante **legado** (o `hooks/git/lib/heavy-mutex.sh` do `Axis.PadSimulator`) atrás de detentor **novo**: o legado tem teto de posse 3600 (`stale_after="${FORGE_HEAVY_MUTEX_STALE_AFTER_S:-3600}"`, linha 48) e remove o lock com `rm -rf` conferindo só o `pid`, **sem** confirmar que o detentor morreu. É um risco pré-existente do legado, que esta onda não cria e não pode corrigir do lado do template. O que ela muda é a assimetria: o lado novo passa a recolher **antes** (com `timeout_s: 1800` o teto derivado é 900s contra 3600s) e a recolher **com segurança** (D6), de modo que o caminho perigoso raramente é o que age. Isso precisa ir para o canal de liaison, na thread `mutex-nao-atravessa-a-fronteira-do-harness`, antes da release.

**O que não quebra na suíte — varredura de STRINGS, refeita com `-a` e com `-F`.** A varredura da revisão 1 usava `grep` com padrão contendo pontos, e ponto é curinga em expressão regular: `grep -rln 'detentor ....' tests/` casava a palavra `detentor` seguida de quatro caracteres quaisquer e devolvia o `w151`, o que produziu a conclusão errada de que o gate afirma aquela linha. Com `grep -aFrln`, que é o instrumento certo para string literal, **nenhuma** das linhas de diagnóstico da biblioteca é afirmada por gate nenhum:

```
$ for s in 'AGUARDANDO — ' 'detentor .... PID' 'recurso ..... ' 'fila ........ ' 'espera ...... ' 'nota ........ ' 'ETA ......... ' 'TIMEOUT após' 'lock ........ '; do printf '%-24s %s\n' "[$s]" "$(grep -aFrln "$s" tests/ | tr '\n' ' ')"; done
[AGUARDANDO — ]
[detentor .... PID]
[recurso ..... ]
[fila ........ ]
[espera ...... ]
[nota ........ ]
[ETA ......... ]
[TIMEOUT após]
[lock ........ ]
```

Nove padrões, nove vazios. Controle positivo, sem o qual o vazio não vale: `grep -aFn 'espera ...... ' template/.forge/scripts/lib/heavy-mutex.sh` devolve a linha 439, e `grep -aFn 'detentor .... PID'` sobre o mesmo arquivo devolve 424, 466, 468 e 886 — o instrumento acha a string onde ela está. Isso libera D4 a acrescentar um campo à linha `espera ......` e D5/D11 a acrescentarem linhas ao bloco de diagnóstico.

**A única string de produção que esta onda REESCREVE é a `description` do bloco `heavy_mutex` no schema (D12), e ela foi varrida como manda a invariante 15:** `grep -arln 'O lock mora em /tmp por caminho fixo' . --exclude-dir=node_modules --exclude-dir=.git` devolve **dois** caminhos, `template/.forge/schemas/forge.schema.json` (a própria fonte) e esta especificação. Nenhum gate a afirma, nenhum arquivo de documentação a repete, e o espelho `plugin/forge` não a carrega (`grep -arln 'heavy_mutex' plugin/` devolve vazio, medido em §0). Todo o resto do que a onda produz é **adição**, nunca reescrita.

O que os gates **de fato** afirmam da saída da biblioteca é outra lista, extraída do próprio `w151` com `grep -an 'grep -q' tests/w151-heavy-mutex-gate.sh | grep -aoE 'grep -q[i]? "[^"]+"' | sort -u`: `adquirido`, `ancestral`, `passou a ser detido por processo ancestral`, `fila`, `fila LIGADA`, `livre`, `heavy-mutex`, `incompleto`, `revogado`, `não consegui remover`, `destino de ticket ocupado por terceiro`, `1 lock` e `justificativa declarada`. **Nenhuma dessas treze é reescrita por esta onda** — todas as mensagens da onda são adição. O `w154` afirma só recibos de âncora, por `grep -qF` sobre caminhos calculados, e não passa perto do laço de espera. O `w153[75]` só confere que `heavy_mutex.root` existe em `properties` do schema (linhas 144-153), então acrescentar propriedade não o afeta. O `w192` lista apenas chaves `quality.*` como interruptores load-bearing, então `stale_after_s` não entra naquele censo. E as strings novas desta onda não colidem com nada: `estagnad`, `beneficiar` e `beneficiary` devolvem **zero** ocorrências em `tests/ template/ bin/ installer/` com `grep -arn`, com o universo dessa varredura provado em §1.1.

**O que não quebra na suíte — varredura de COMPORTAMENTO, que a revisão 1 não fez e que é onde estava o risco real.** A varredura de strings acima é necessária e não é suficiente: esta onda introduz, para todo mundo, um teto de posse onde não havia nenhum, e isso muda o desfecho de **todo** cenário existente que espera atrás de um detentor vivo. A proteção não pode ser acidental, então ela é nominal. Foram enumerados todos os cenários do `w151` em que um esperante contende com um lock TOMADO, com o teto de espera de cada um e o teto de posse efetivo que D3+D4 produzem para ele (`reserva = 6`; efetivo `= 0` para espera ≤ 6, `= espera − 6` para 7 ≤ espera ≤ 10, `= espera / 2` a partir de 11):

| Cenário do `w151` | Linha | Teto de espera | Detentor | Efetivo sob D3+D4 | Por que sobrevive |
|---|---|---|---|---|---|
| `[2]` | 192 | 2 | vivo, aquisição REAL, segura 30s | **0 — desligado** | teto de espera ≤ reserva: o ramo de idade nem é armado |
| `[8]` | 368 | 2 | vivo, `mk_lock` (sem `acquired_at`) | **0 — desligado** | idem, e além disso o lock não tem idade legível (D5) |
| `[20]` | 410 | 2 | vivo, lock legado só com `pid` | **0 — desligado** | idem, e o lock legado é o caso da primeira linha da tabela de D5 |
| `[36]` | 935 | 2 (`TIMEOUT_S=2`) | vivo, `mk_lock` | **0 — desligado** | idem; é o canal real, e é o cenário que mais me preocupava |
| `[49](a)`,`(b)` | 1277, 1283 | 4 (do `forge.yaml`) | vivo, lock à mão sem `acquired_at` | **0 — desligado** | teto de espera ≤ reserva |
| `[31]` | 574 | 3 | vivo, lock à mão com `pid=$$` do próprio gate e token divergente, sem `acquired_at` | **0 — desligado** | teto de espera ≤ reserva; e, se algum dia a espera daquele cenário subir, a segunda proteção é a de D5, porque o lock não tem idade. **Esta linha entrou na revisão 3**: a revisão 2 mostrou que a tabela reivindicava exaustividade e deixava o `[31]` de fora, o que é exatamente o defeito que a exaustividade existe para impedir — nenhum desfecho muda, o errado era a afirmação |
| `[49](e)` | 1297, 1299 | 0 | vivo | **0 — desligado** | recusa imediata, não há laço |
| **`[49](c)`** | **1287** | **9** | **vivo, lock à mão sem `acquired_at`** | **3 — ARMADO** | **é o único que sobrevive por DECISÃO e não por aritmética**: o ramo de idade está armado com efetivo 3 numa espera de 9, e o que impede o recolhimento é a primeira linha da tabela de leitura de D5 — sob a leitura oposta (M13) o disparo sai na **primeira volta**, em `waited = 0`, e o recolhimento em ~5-6s pela graça, o que derruba as duas metades da asserção (`rc 75` e `s49 ≥ 8`); a revisão 2 corrigiu aqui o "aos ~3s" da revisão anterior, que confundia o teto efetivo com o instante do disparo. O que impede o recolhimento continua sendo a primeira linha da tabela de leitura de D5 (`acquired_at` ausente não é reclamável por idade). Sem essa decisão o cenário fica vermelho — é o BLOQUEADOR 1 |
| `[9]` | 379 | 12 | **sem detentor** (lock vazio, sem `pid`) | 6 — armado | o ramo de idade só é avaliado quando há `pid` legível; este lock cai no ramo `incompleto`, que age aos 3 polls |
| `[17]` | 534 | 30 | vivo, aquisição REAL, segura ~1s | 15 — armado | a posse mais velha que qualquer esperante observa tem ~1s, contra teto de 15s |
| `[16]` | 1068/1077 | 20 | vivo, aquisição REAL, segura 1,2s | 10 — armado | posse máxima de 1,2s contra teto de 10s |
| `[32]` | 604 e 611 | 30 (pai e filho; o terceiro, de espera 10, é o DETENTOR e adquire sobre lock livre) | vivo, aquisição REAL, segura 4s | 15 — armado | posse máxima de 4s contra teto de 15s: é a **menor margem de toda a suíte** entre os cenários com o ramo armado, e por isso ela está escrita aqui em vez de descoberta na entrega |
| `[10]`,`[12]`,`[13]`,`[14]`,`[34]`,`[48]`,`[55]` | 494/476/484/505/638/671/1016 | 3 a 60 | **lock LIVRE**, contenção por ticket de fila | — | o ramo de idade pertence ao caminho de lock tomado; fila é outro caminho, e nenhum destes chega a observar detentor. O `[10]` (linha 494, `--timeout 6`, ticket órfão na cabeça) entrou nesta revisão pelo mesmo motivo que o `[31]`: a revisão 2 o pegou de fora da enumeração |

**Treze** linhas, e a leitura delas é o que a revisão 1 exigia em letra e a revisão 2 corrigiu na contagem. **Sete** linhas sobrevivem porque a reserva de D4 desliga a recuperação por idade com teto de espera ≤ 6 — `[2]`, `[8]`, `[20]`, `[36]`, `[49](a)(b)`, `[49](e)` e o `[31]` acrescentado nesta revisão —, e isso é proteção **aritmética**, que vale por construção mas não estava nomeada em lugar nenhum antes da revisão 2, o que a tornava acidental do ponto de vista de quem vai implementar. **Uma** — o `[49](c)` — sobrevive só pela decisão de leitura de D5, e é o BLOQUEADOR 1 da revisão 1. **Três** (`[17]`, `[16]`, `[32]`) sobrevivem por margem de tempo. E **o resto** — os sete de fila mais o `[9]` — não toca o caminho de idade.

**As três de margem de tempo precisam de uma frase que a consequência aritmética de D4 torna obrigatória, e ela é o que separa margem de garantia.** O teorema de D4 diz que um detentor vivo **que não solta** é sempre recolhido antes do teto de espera quando o ramo está armado e a idade é legível — os três cenários armados do `w151` sobrevivem porque o detentor deles **solta**, em 1s (`[17]`), 1,2s (`[16]`) e 4s (`[32]`), contra tetos efetivos de 15, 10 e 15 segundos. A condição de segurança é, portanto, `posse máxima observada < efetivo`, e não "o detentor está vivo": se algum dia um desses cenários passar a segurar o lock por mais tempo que o efetivo, ele será recolhido e o gate cai — o que não é regressão desta onda e sim a mesma aritmética agindo. A menor margem de toda a suíte é a do `[32]`, 4s contra 15s, e ela está escrita aqui em vez de descoberta na entrega.

Duas obrigações saem daí para o passo 6 da §10, e as duas são sobre rodar o `w151`, não o gate novo: a suíte inteira roda sob a mutação **M13** (que é a que derruba o `[49](c)`), e ela roda sob **M2** também, porque remover a checagem de idade não pode fazer nenhum destes doze mudar de desfecho — se fizer, algum deles estava dependendo do ramo novo sem que a tabela soubesse.

**Onde a onda muda contagem afirmada por gate.** O badge de gates do `README.md` é conferido pelo `w200[6]` (linhas **253-272**; a revisão 2 corrigiu o começo do intervalo que a revisão anterior dava como 258 — a 258 é o `echo` do rótulo e o bloco do cenário abre no cabeçalho da 253, medido com `awk`) contra `find "$WS/tests" -maxdepth 1 -name '*-gate.sh' | wc -l`. **Nenhum número é escrito aqui de propósito**, porque outras ondas desta rodada também acrescentam gates e qualquer literal envelhece antes da entrega; a medição de 2026-09-08 é `BADGE=131 ARVORE=131`, e o que vale na entrega é a igualdade remedida no mesmo commit, cujo comando está na definição de pronto da §10. A linha `scripts/ (N)` do bloco de estrutura do `README.md` (linha 235, hoje `136`) **não** muda: ela conta os arquivos rastreados sob `template/.forge/scripts` (`git ls-files template/.forge/scripts | wc -l` = 136, medido no mesmo dia), e esta onda não acrescenta arquivo algum ali — ela edita `lib/heavy-mutex.sh`, e os outros arquivos tocados moram em `hooks/`, `schemas/` e na raiz de `.forge/`. Se a implementação decidir extrair a derivação de D3/D4 para um arquivo novo sob `scripts/lib/`, essa linha passa a mudar e entra na definição de pronto junto com o badge.

---

## 9. O que a Onda L2 explicitamente NÃO faz

- **Não ceifa grupo de processos** (D10). Medido em 2.2: a ceifa ingênua mata o reclamante quando os grupos coincidem, e a guarda correta exige gravar `pgid` e sessão no lock. Consequência declarada e medida (`neto=S` após o `KILL`): descendentes do detentor podem sobreviver ao recolhimento e rodar com o lock livre. Vira LDG-0<novo> (D13).
- **Não corrige a saída normal do `heavy-run.sh`**, que libera o lock sem ceifar o grupo do filho (confirmado nas quatro últimas linhas do arquivo, contra o `_hr_sig` que ceifa). É a metade que `axis-fare-validator-0058` registra como aberta no canal, e entra no mesmo item de ledger de D13.
- **Não corrige a disciplina de relógio do ramo IRMÃO, que tem o mesmo defeito que D7 conserta.** `heavy-mutex.sh:877-880` faz `_fhm_reclaim_orphan "$holder" || true; continue` **sem** incrementar `waited` e **sem** testar o teto — exatamente a forma que D7 declara inaceitável para o ramo novo. Não é dívida criada por esta onda, mas ela passa a escrever a disciplina correta ao lado da incorreta, no mesmo laço e a poucas linhas de distância, e deixar isso sem registro é ensinar as duas formas ao mesmo tempo. Entra no item de ledger de D13, com o caminho e as linhas.
- **Não muda o default do teto de espera.** 1800 fica. Mudá-lo é contrato com cinco adotantes instalados por um ganho que a derivação de D3 já entrega.
- **Não protege posse legítima mais longa que o teto de espera menos a reserva.** A invariante de D4 faz do teto de posse e do teto de espera um botão só: o maior efetivo obtenível é `espera − reserva`, e com os defaults isso é 1794s. Um repositório cuja suíte pesada legitimamente passe disso tem de aumentar o teto de espera junto ou declarar `stale_after_s: 0`. Não há terceira saída, e não há como pedir "posse longa com espera curta" — pedir isso é pedir a negação da invariante. Está em letra na §8, é o preço declarado da decisão de D3, e é o quinto fato da mensagem de liaison do passo 9.
- **Não implementa heartbeat nem detecção de progresso por CPU** (sugestão 3 da #137). O motivo se apoia num dado **de campo, que eu não reproduzi e não posso reproduzir aqui**, e ele fica marcado como tal: a #137 relata que o detentor daquele evento consumiu 0,11s de CPU em 56 minutos (e, num segundo parágrafo da mesma issue, 0,07s em 59 minutos — a issue diverge de si mesma na terceira casa, o que não muda a ordem de grandeza nem a conclusão). O que é medido **aqui** é a metade que decide: aquele detentor era um `pre-push` da biblioteca **legada**, provado em §1.2 pelas strings, e a legada não escreve heartbeat e não vai passar a escrever. Um mecanismo que exige cooperação do detentor não alcança o detentor que de fato trava a máquina; um teto de idade alcança. Se a proporção de detentores cooperativos mudar, o heartbeat volta como refinamento — com dado, não por simetria.
- **Não altera o `label` gravado por caminho nenhum existente** — só recusa o valor vazio explícito (D8). E **não** corrige o `label` vazio observado em #144, porque ele vem de um lock do protocolo legado, que não tem o campo (medido em 1.4). A correção daquele lado é do consumidor, no arquivo dele, e a mensagem de liaison precisa dizer isso em vez de prometer o que o template não pode entregar.
- **Não toca em `lib/arg-guards.sh` nem na classe da #103.** `--beneficiary` valida por conta própria, com o mesmo idioma de `--timeout`, e por isso não depende da reconciliação entre a Onda E e a #133.
- **Não faz a `#131` nem a `#142`**, que são L1 e mexem no updater e no `resource`. A dependência com a #131 está nomeada em §8 e não bloqueia.
- **Não valida `forge.yaml` contra o schema em nenhum passo do consumidor.** A onda corrige o schema; quem passar a executá-lo é decisão de outra frente, e fingir o contrário faria a correção parecer maior do que é.

---

## 10. Ordem de execução e definição de pronto

1. Alocar o ordinal com o orquestrador (invariante 10), contra `origin/*` **e** contra as branches em voo. Máximo publicado em 2026-09-08: **w207** — medição datada, a ser refeita no momento da alocação, com o comando abaixo, que **enumera** as refs em vez de listar um punhado delas à mão (a lista fixa da revisão 1 era enumeração falsamente exaustiva: ela não veria uma branch nova criada nesta mesma rodada):

```
$ git fetch --quiet origin; for b in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin); do n=$(git ls-tree -r --name-only "$b" tests/ 2>/dev/null | grep -oE '/w[0-9]+' | sed 's|/w||' | sort -n | tail -1); [ -n "$n" ] && printf '%-60s %s\n' "$b" "$n"; done | sort -k2 -n | tail -5
origin/wip/deepspec-run-manifest-ldg-0165                    80
origin/wip/upgrade-safety-ldg-0131                           154
origin                                                       207
origin/develop                                               207
origin/main                                                  207
```
2. Escrever o gate **inteiro**, com os 27 cenários, o contador, o teto de parede derivado e as mutações. Executar. **Colar a saída vermelha no PR**, cenário a cenário, e marcar explicitamente os que a tabela da §4 declara verdes por construção — a tabela é a autoridade e a contagem dela está escrita lá, justamente para o passo não repetir um número que envelhece. Ler também a §4.1 e conferir, cenário a cenário, que o **regime declarado** do ramo de idade é o que a fixture de fato monta: um cenário que assevere 75 contra detentor vivo sem estar num dos três modos de D4 é vermelho fabricado, e foi essa classe que derrubou a revisão 2. Um vermelho num desses no passo 2 é defeito da fixture, não do produto.
3. Antes de escrever a asserção de `[15]`, provar que a fixture produz o estado "morte não confirmada", com a saída colada. Antes de escrever `[13]` e `[14]`, provar que as duas fixtures produzem regimes de `trap` **diferentes**, remedindo o que a §2.1 mediu. Antes de escrever `[4]`, **medir a reserva** que a implementação de fato usa e derivar dela o teto de espera da fixture, reprovando o cenário se `metade + reserva > espera` — sem isso o `[4]` é vermelho fabricado, que foi o segundo bloqueador desta revisão. E em `[26]`, guardar todo `kill -0` sobre PID lido de arquivo com `[ -n "$p" ] && [ "$p" -gt 1 ]`, pelo motivo medido em §2.2. **E antes de escrever `[5]` e `[7]`, medir a reserva e derivar dela o teto de espera das duas fixtures**, com reprovação do cenário se `espera ≤ reserva` — é a mesma cláusula do `[4]`, estendida aos dois irmãos que a revisão 2 pegou sem ela: no `[5]` porque o regime desligado faz o esperante sair 75 contra uma implementação correta, e no `[7]` porque `TERM` mais graça mais `KILL` mais confirmação não cabem num teto menor que a reserva. **E, para as catorze linhas que a §4.1 põe no modo (ii), conferir que o `stale_after_s: 0` chega mesmo ao leitor** — declarar a chave e não medir que ela foi lida é fabricar o regime no papel: a fixture imprime o teto efetivo pela linha `espera ......` do bloco de contenção (D4) e o cenário reprova se ele não vier `desligada`.
4. Implementar na biblioteca: campos `beneficiary` e `beneficiary_token` no `_fhm_claim`; leitor de `stale_after_s` com as três precedências; derivação e rebaixamento de D3/D4 com aviso lazy; checagem de beneficiário e de idade na ordem de D5; encerramento com escalada e confirmação de morte de D6; avanço do relógio e teste de teto dentro do ramo de D7; validação de `--beneficiary` e `--label` de D8; censo de descendentes de D11; três estados no `forge_heavy_mutex_status`.
5. Implementar a fiação: `--beneficiary "$PPID"` no `pre-push`, chave e documentação no `forge.yaml` do template, `stale_after_s` e o `pattern` de `root` no schema.
6. Executar as **dezessete** mutações, observar cada `FAIL` esperado, restaurar por `cp` da árvore de trabalho com `cmp -s`, e **recontrolar** cada uma. Antes de registrar qualquer linha da matriz, provar que a mutação **morde**: uma mutação no-op corrige o cenário, nunca a linha. Três delas — **M13**, **M2** e **M16** — rodam com a suíte inteira e não só com o gate novo, porque o que elas podem derrubar mora no `w151` e não aqui; a tabela de comportamento da §8 diz exatamente quais **treze** linhas daquele arquivo observar. A M16 entrou nessa lista porque "recolhe sempre" atropela justamente as sete linhas que sobrevivem pela aritmética da reserva e as três que sobrevivem por margem de tempo — se ela não derrubar nenhuma delas, a tabela da §8 está descrevendo outra implementação.
7. Suíte inteira verde, com `bash -n` limpo em tudo que foi tocado — bash 3.2, sem `declare -A`, `${var,,}`, `${var^^}`, `mapfile` nem `readarray`.
8. `CHANGELOG.md`; issues **#137** e **#144** fechadas, e a de #137 com a **correção do diagnóstico** da §1.1 escrita no fechamento, porque fechar por reclassificação silenciosa é o que o plano-mestre proíbe; item de ledger novo de D13.
9. Mensagem no canal de liaison, na thread `mutex-nao-atravessa-a-fronteira-do-harness`, com **seis** fatos. Os quatro primeiros: a recuperação por idade foi absorvida upstream e o patch local do `Axis.PadSimulator` será sobrescrito pelo overlay; o `stale_after_s: 3600` daquele repositório passa a ser rebaixado para 1794, com o motivo; o `label` vazio observado vem do lock legado e o template não pode corrigi-lo; e a assimetria de tetos entre a biblioteca nova e a legada durante a implantação. O **quinto** é o marcador de comportamento que a revisão 2 exigiu e que é o mais acionável dos seis: **com o mutex ligado e sem `stale_after_s` declarado, uma posse legítima que passe de 900s com alguém esperando passa a ser encerrada** — alcança o `axis-fare-validator`, que dispara Gradle no push e não declara a chave —, e as duas saídas são aumentar `timeout_s` junto ou declarar `stale_after_s: 0`; a mensagem precisa dizer que o teto máximo obtenível é `timeout_s − 6` e que uma suíte de uma hora, que é o número que o `forge.yaml` do `Axis.PadSimulator` chama de legítimo, **não** cabe sob um `timeout_s: 1800`. O **sexto** é o caminho do backup, porque a mensagem que o `forge update` imprime diz `.forge.bak-N` e o destino real é `.git/forge-backups/forge-N` (§8, item 3) — mandar o destinatário procurar onde a ferramenta diz é mandá-lo procurar onde não está.
10. PR contra `develop`, sem texto de coautoria de IA.

**Definição de pronto, verificável por comando:**

```
bash tests/w<NNN>-heavy-mutex-posse-gate.sh    → PASS, com o contador 27/27 e o teto de parede
bash tests/w151-heavy-mutex-gate.sh            → PASS  (nenhuma string afirmada por ele mudou)
bash tests/w154-heavy-mutex-yaml-root-gate.sh  → PASS  (o [d] continua exigindo o token literal)
bash tests/w153-upgrade-safety-gate.sh         → PASS  (o [75] continua achando heavy_mutex.root)
bash tests/w200-readme-inventory-gate.sh       → PASS  (badge e árvore concordam, os dois remedidos)
node tools/validate-forge.mjs                  → OK    (o forge.yaml do template contra o schema novo)
npm test                                        → suíte 100% verde
gh issue view 137 --json state                 → CLOSED
gh issue view 144 --json state                 → CLOSED

# badge do README — igualdade remedida no mesmo commit, nunca literal.
# Medido em 2026-09-08: BADGE=131 ARVORE=131. O que vale na entrega é a igualdade, não o número.
BADGE=$(grep -aoE 'gates-[0-9]+' README.md | head -1 | cut -d- -f2)
ARVORE=$(ls tests/*-gate.sh | wc -l | tr -d ' ')
[ "$BADGE" = "$ARVORE" ]

# linha `scripts/ (N)` do README — esta onda NÃO deve mudá-la; a igualdade é a asserção.
# Medido em 2026-09-08: as duas devolvem 136.
grep -aoE 'scripts/ \(([0-9]+)\)' README.md
git ls-files template/.forge/scripts | wc -l | tr -d ' '
```

E quatro verificações que não são de comando e são as que importam:

- Rodar o cenário `[17]` **contra o `pre-push` de hoje**, antes de qualquer implementação, e observar o push ficar preso até o teto — é o vermelho do canal, e sem ele `[17]` mede o alvo e não o canal.
- Conferir, ao fim de tudo, que o lock real da máquina não foi tocado: `/tmp/forge-heavy-suite.lock` e `${TMPDIR}/axis-heavy-suite.lock` com o mesmo estado de antes, e nenhum `.reaping.*` novo em nenhuma das duas raízes. É o que `[24]` automatiza e é o motivo de a biblioteca ter a trava positiva.
- Rodar `bash template/.forge/scripts/check-heavy-mutex.sh --path .` sobre o repositório inteiro depois da implementação — é o `w151[46b]`, e ele é o cenário que já pegou uma vez o gate reprovando o próprio template.
- Ler a mensagem de rebaixamento de D4 em voz alta com os números do `Axis.PadSimulator` (3600 declarado, teto de espera 1800, efetivo 1794) e confirmar que ela é acionável em uma linha: um operador que a leia precisa saber o que declarou, o que vale, e por quê.
- Confirmar, com o `forge.yaml` sintético de `[27](a)`, que a espera curta contendida **não** imprime aviso nenhum de rebaixamento — é a metade da decisão de D4 que só um humano lendo a saída inteira percebe, porque um gate que procura ausência de string aprova também quando a saída inteira sumiu.
- Reler a §4.1 contra o gate escrito, linha a linha, e confirmar que **cada** cenário que assevera 75 ou "não recolhe" contra detentor vivo está num dos três modos de D4 e que a fixture o produz de fato. É a verificação que não tem comando porque ela é de correspondência entre duas tabelas, e é a que a revisão 2 provou ser a mais cara de pular: um único cenário fora de regime é vermelho fabricado no dia da entrega.
- Confirmar que a `description` do bloco `heavy_mutex` e a de `root` publicam a válvula de escape (`stale_after_s: 0`) e o teto máximo obtenível (`timeout_s − reserva`). O `[21]` assevera o predicado do `$TMPDIR`; esta linha é sobre o adotante conseguir agir, e ela é humana de propósito.

---

## 11. Respostas ao veredito da revisão 1

Toda afirmação do revisor foi **remedida com comando meu** antes de ser aceita, e onde a remedição discordou dele a discordância está escrita com o número novo. Nenhuma medição desta seção veio de execução de gate: a proibição de concorrência de `feedback-suite-sem-concorrencia` continua valendo, e o que eu li de `tests/` eu li como texto.

### Os quatro bloqueadores

**Bloqueador 1 — semântica de leitura de campo ausente ou ilegível.** Aceito integralmente e fechado em **D5**, com a tabela de seis estados por ramo. Remedi as três medições em que ele se apoia e as três batem: `grep -arn 'acquired_at' tests/ template/` devolve exatamente uma linha (a 659 da biblioteca), o helper `mk_lock` do `w151` (linhas 44-49) grava `pid`, `token` e `nonce` e nunca `acquired_at`, e o `w151[49](c)` roda com espera 9 contra um `sleeper` vivo sobre um lock sem idade. Uma correção de detalhe: o `pid` é escrito na linha **644**, não 641 (o `_fhm_claim` começa em 639). A conclusão é a dele e o preço é o que ele disse — com "ausente = velho", `w151[49](c)` fica vermelho contra uma implementação correta. Entraram os cenários `[25]` e `[26]` e a mutação **M13**, e o passo 6 da §10 passa a rodar a suíte inteira sob ela.

**Bloqueador 2 — o `[4]` e a M3 falsos numa faixa de valores.** Aceito, com **um número corrigido por medição**. O revisor situa a fronteira em "teto de espera maior ou igual a 12"; medindo a derivação em aritmética inteira de bash, que é onde ela vai viver, a metade é `$(( t / 2 ))` e portanto **piso**, e a fronteira real é **11**: com espera 11 a metade é 5, `5 + 6 = 11 ≤ 11`, e a relação sobrevive. A tabela medida está em D4 e cobre de 0 a 1800. O `[4]` passou a declarar a pré-condição `espera ≥ 11` **e** a derivar os números da reserva medida pelo implementador em vez de fixá-los, e a M3 ganhou a exigência de medir o efetivo antes e depois para provar que a mutação morde.

**Bloqueador 3 — o aviso quando quem viola a relação é o valor DERIVADO.** Aceito e decidido em **D4**: o rebaixamento derivado é **silencioso**, e o que substitui o aviso é um campo a mais na linha `espera ......` do bloco de contenção, que já existe e que nenhum gate assevera (medido com `grep -aFrln`, com controle positivo na lib). A decisão tem alternativa descartada escrita, cenário que a guarda (`[27]`) e contrafactual (**M14**). O alcance que o revisor apontou está medido e é o que sustenta a decisão: a faixa `espera < 11` cobre `--timeout 2`, `4`, `5`, `6` e `9`, que é a maioria das fixtures do `w151`.

**Bloqueador 4 — a §8 varria strings e não comportamento.** Aceito, e a §8 ganhou a tabela nominal de **doze** cenários do `w151` que contendem com lock tomado, com linha, teto de espera, natureza do detentor e teto de posse efetivo sob D3+D4. O resultado nomeia a proteção que era acidental: seis sobrevivem pela aritmética da reserva, um (`[49](c)`) só pela decisão de D5, três por margem de tempo — a menor sendo 4s de posse contra 15s de teto no `[32]` —, e o resto não toca o caminho. **Refutação parcial, com medição:** a varredura de strings da revisão 1 estava errada por outro motivo, e ele é meu. Eu havia escrito que `detentor ....` "só aparece na lib e no `w151`"; o padrão tem pontos, ponto é curinga em regex, e o que casava era `detentor` seguido de quatro caracteres quaisquer. Com `grep -aFrln`, nove padrões de diagnóstico da biblioteca devolvem **nove vazios** em `tests/`, com controle positivo na lib — nenhum gate afirma nenhuma dessas linhas, o que é uma conclusão mais forte do que a que eu tinha e não a que eu tinha escrito.

### As medições sem lastro — dez itens, dez desfechos

Nove foram **remedidas com comando colado**; **uma foi removida** e substituída pela citação da fonte; e uma décima primeira, que o revisor não listou, caiu por conta própria quando a remedição a contradisse.

| # | Item do veredito | Desfecho |
|---|---|---|
| 1 | §1.1, o par comando/saída inconsistente | **Corrigido**: a §1.1 agora traz duas varreduras, a de `stale_after` com rc 1 e saída vazia e a de `_fhm_reclaim_orphan` com as três linhas, mais a prova de que a varredura leu o universo |
| 2 | `FORGE_HEAVY_MUTEX_CLAIM_HOLD_S` não existe | **Removida**. Confirmado: `grep -arn 'CLAIM_HOLD' tests/ template/ bin/ installer/` devolve rc 1. A nota de `[15]` cita agora só as duas sondas reais, `REVOKE_PROBE` (647) e `STEAL_PROBE` (651) |
| 3 | §2.1, a tabela de SIGTERM diferido | **Remedida em 2026-09-08**, saída colada, com o controle pareado em `wait`. As três linhas reproduzem idênticas. Acrescentei o que faltava: o `em=8s` é o teto de observação da bancada, não latência |
| 4 | §2.2, a ceifa de grupo | **Remedida**, saída colada, agora com o PID do neto **capturado em arquivo** e não inferido. E a remedição pagou uma armadilha que virou parágrafo próprio e obrigação do passo 3: `kill -0 0` devolve sucesso, então um `${NETO:-0}` fabricava `neto=S` sem neto nenhum |
| 5 | §2.3, o nome da evidência de sweep | **Remedida**, com a linha 117 do `heavy-run.sh` copiada literalmente e um **controle positivo** novo: o criador da evidência é o próprio shell da bancada, e a última linha prova que ele está vivo |
| 6 | §2.4, `$PPID` num `git push` real | **Remedida**, com push de verdade contra remoto `file://`, saída colada |
| 7 | §1.3, o par ANTES/DEPOIS com `git push` real | **Remedido**, mesma bancada do item 6, saída colada. E a remedição achou um fato **novo**, que muda o `[19]`: o `há 00:00` do status é `ps -o etime=` do processo, não a idade da posse |
| 8 | §1.5, os cinco `forge.yaml` contra o schema | **Remedida documento a documento**, com o bloco `heavy_mutex` de cada um impresso ao lado. E ela **corrigiu uma afirmação minha**: o `azim-crm` não declara bloco nenhum |
| 9 | §4, o "gasto solo medido de ~330s" do `w151` | **Removida como medição minha e substituída pela citação da fonte**: o número está no cabeçalho do `w151`, linhas 75-78, e a §4 agora diz em letra que eu não rodei aquele gate |
| 10 | A CPU de 0,11s em 56 minutos, vinda da #137 | **Mantida, marcada como não reproduzível aqui**, com a divergência interna da própria issue registrada (0,11s/56min num parágrafo, 0,07s/59min noutro) e com a separação explícita entre o que é dado de campo e o que eu medi |
| 11 | *(não listado pelo revisor)* — "os cinco já aplicaram a 0.14.0" e "as três fronteiras estão no `machinery.lock` de todos os cinco" | **As duas caíram na remedição.** O lock mora em `.forge/cache/machinery.lock`, não em `.forge/machinery.lock`, e com o caminho certo são **três** repositórios em 0.14.0 (o `Axis.PadSimulator` está em 0.11.0 e o `azim-crm` em 0.1.0-rc24) e **quatro de cinco** com entrada para `heavy-mutex.sh`. Foi a mesma lição do LDG-0177 num terceiro rosto: a primeira varredura saiu vazia e eu quase a li como resposta |

### As ressalvas

| Ressalva | O que mudou |
|---|---|
| §10 passo 2 dizia "seis" e a tabela tem oito e meio | A §4 passou a declarar a contagem e a dizer que ela é a autoridade; o passo 2 lê de lá em vez de repetir número |
| M12 aponta para alvo sem linha, e muta código pré-existente | A M12 passou a apontar para `[14]` nominalmente, e a ressalva de escopo está escrita na própria linha: se a delegação a `_fhm_reclaim_orphan` for total, a mutação prova invariante herdada e não a decisão D6, e o PR precisa dizer isso |
| D12 relaxa o `pattern` e deixa a `description` argumentando o contrário | Aceito e corrigido: a `description` muda junto, e o `pattern` novo é **paridade exata** com os dois braços que o leitor aceita, não relaxamento genérico — caminho relativo continua reprovando nos dois lados |
| §8 item 3 manda procurar o backup onde a mensagem não indica | Corrigido, com as duas linhas do `bin/forge.mjs` (598 e 643), e o caminho certo virou o quinto fato da mensagem de liaison do passo 9 |
| D4 não dizia que a graça é variável NOVA e o poll da cabeça já existe | Corrigido na primeira frase de D4, com as linhas do poll da cabeça (856-857 e 897-898) e a varredura vazia da graça |
| `w151[49]` é etiqueta ambígua: existem dois `[49]` | Registrado em D3, com as duas linhas (742 e 1241) e a declaração de que todas as citações desta especificação são ao segundo |
| D7 conserta o ramo novo e o irmão tem o mesmo defeito | Aceito: `heavy-mutex.sh:877-880` entrou na §9 como item nomeado e no item de ledger de D13 |

---

## 12. Respostas ao veredito da revisão 2

Mesma disciplina da §11: toda afirmação do revisor foi **remedida com comando meu** antes de ser aceita, e onde a remedição achou mais do que ele apontou, o que ela achou está escrito com o número novo. Nenhum gate foi executado nesta rodada — a proibição de concorrência de `feedback-suite-sem-concorrencia` continua valendo, e o que eu li de `tests/` eu li como texto, com `awk` numerando as linhas. Toda bancada rodou sob `$TMPDIR`, com `cwd` dentro da fixture.

### O bloqueador remanescente

**Remanescente 1(b) — a pré-condição numérica do `[4]` não chegou aos irmãos `[5]` e `[7]`.** Aceito integralmente, e a remedição mostrou que ele estava certo pelos dois motivos que dá. No `[5]`, os tetos que a suíte usa hoje (`--timeout 2`, `4`, `5`, `6`) caem todos no regime que D4 desliga — medido na bancada da derivação, o ramo só arma a partir de `espera = 7` em qualquer caminho —, então um `[5]` montado com um deles sai 75 contra uma implementação correta. No `[7]`, `TERM` mais graça mais `KILL` mais confirmação não cabem abaixo da reserva. Os dois ganharam a mesma cláusula do `[4]`: pré-condição declarada, números derivados da reserva **medida pelo implementador** em vez de fixados, e reprovação do cenário quando a pré-condição não vale. O passo 3 da §10 passou a mandar medir para os três, e não só para o `[4]`.

### O bloqueador novo

**Novo 1 — a consequência aritmética de D4 torna `[2]` insatisfazível, e o discriminador contra "recolhe sempre" fica sem sítio.** Aceito integralmente, e **remedido por enumeração exaustiva** antes de aceito. Rodei a derivação candidata sobre `espera` de 0 a 200 cruzado com quinze valores declarados mais o caminho derivado, testando em cada combinação as duas propriedades: `efetivo + reserva ≤ espera`, e `waited < espera` para a posse mais nova possível. **2716 combinações com o ramo armado, zero violações.** O revisor está certo em cada passo: `waited ≤ efetivo ≤ espera − reserva < espera`, salvar o `[2]` exigiria `espera < efetivo`, que é a negação da invariante, e portanto não existe parametrização que o salve.

O que fiz com isso, e é mais do que ele pediu, porque a correção mínima que ele propõe não sobrevive à varredura que o próprio padrão de falha desta spec exige:

1. **A consequência virou texto normativo em D4**, com a bancada colada, a tabela de instantes de disparo (que mostra a folga mínima sendo exatamente a reserva — que é para isso que ela existe) e a **enumeração exaustiva dos três modos** em que um 75 contra detentor vivo continua satisfazível: (i) desligado por aritmética, (ii) desligado por declaração, (iii) armado com idade não computável. A enumeração é exaustiva porque é a leitura direta do `case` da derivação mais a primeira linha da tabela de D5.
2. **A §4.1 é nova e declara o regime de cada um dos vinte e sete cenários**, com trinta linhas porque `[2]`, `[10]` e `[27]` têm dois arranjos. É a régua que o revisor pediu ("escrever na §4 o regime de cada cenário"), e ela é conferível contra a tabela da §4 sem sair do documento.
3. **O `[2]` foi reescrito em dois arranjos**, um armado com asserção **temporal** (adquire, mas não antes de `D`) e um desligado por aritmética com asserção de regime (rc 75). A metade (b) é, de quebra, a única asserção do gate sobre a proteção aritmética da reserva, da qual sete linhas do `w151` dependem — antes disso, aquela proteção estava descrita na §8 e não estava asseverada em lugar nenhum.
4. **O `[8]`, o `[11]` e — achado meu, o revisor não o nomeou — o `[18]` ganharam a condição em letra**: `stale_after_s: 0` declarado. O `[18]` tem exatamente a mesma forma dos outros dois, no canal real, e cairia pelo mesmo motivo.
5. **O `[4]` caiu junto, e o revisor não o pegou.** A varredura que o enunciado desta rodada manda fazer — "toda linha de matriz aponta para cenário que existe, com o efeito que você mediu?" — mostrou que a asserção "a posse abaixo da metade **não** é recolhida" é insatisfazível pelo mesmíssimo teorema: com o ramo armado ela também é recolhida, só que mais tarde. O `[4]` passou a medir o **instante**, e o delta entre os dois decorridos é a medição da metade derivada — que é um teste melhor da derivação do que o que estava escrito.
6. **A mesma varredura alcançou `[10]`, `[13]`, `[14]`, `[15]`, `[16]`, `[25]`, `[26]` e `[27](a)`**, que precisavam de regime declarado por motivos próprios: gatilho determinístico nos quatro de encerramento, isolamento do ramo nos dois de matriz, e asserção sobre a saída em vez do rc no `[27](a)`.
7. **A M16 e a M17 são novas. A M16 é o sítio que faltava para a guarda contra "recolhe sempre"** — recolher todo detentor vivo derruba **nove** linhas da §4.1 — `[2](a)`, `[2](b)`, `[3]`, `[8]`, `[10](a)`, `[11]`, `[18]`, `[25]` e `[26]` —, que são **dezoito** asserções contando as seis variações do `[25]` e as cinco do `[26]`, e nenhum cenário de recolhimento legítimo. O `[15]` e o `[16]` continuam verdes sob ela de propósito: naqueles dois a recusa do recolhimento não vem do teto e sim da morte não confirmada e do lock recriado, então recolher sempre não muda o desfecho. O revisor tinha razão em dizer que o par `[1]`+`[2]` deixara de discriminar; o que substitui o par é uma mutação, que é mais forte do que um par de cenários. A **M17** é achado meu e não do veredito: varrendo a matriz atrás de cenário sem contrafactual, o `[19]` era o único cenário de decisão sem mutação nenhuma apontando para ele — os dois estados novos do `status` e a origem do número da idade entravam sem guarda. A §5 passou a declarar em letra quais cenários ficam deliberadamente sem contrafactual (`[22]`, coberto por M3 e M4; `[23]` e `[24]`, que são sentinelas do próprio gate) para que a próxima lacuna também seja declarada em vez de descoberta.
9. **Um erro de referência cruzada, achado pela mesma varredura e que a revisão 2 não pegou.** O fecho de D4 dizia *"o cenário `[26]` guarda o silêncio do caminho derivado, e a mutação M14 é o contrafactual dela"* — mas o `[26]` é a matriz de leitura de `beneficiary` e quem guarda o silêncio é o `[27](a)`, que é justamente o que a linha da M14 sempre disse (`FAIL [27](a)`). O texto e a matriz se contradiziam desde a revisão anterior. Corrigido em D4, com a contradição registrada na própria frase.
10. **Duas seções que mencionavam as peças mudadas e que precisavam acompanhar.** A §6 dizia "as três matrizes de leitura `[25]`, `[26]` e `[27]`", e o `[27]` nunca foi matriz de leitura — passou a nomear as duas de leitura mais o par de arranjos do `[27]`, e a remeter à regra de subcontador da §7 em vez de a um rótulo. E o PBT do `[22]` ganhou a **quarta** parte da propriedade — todo efetivo positivo é estritamente menor que o teto de espera —, sem a qual ele aprovaria uma derivação que arma o ramo sem deixar tempo para a escalada, que é exatamente o que o teorema de D4 proíbe.
8. **O item (iv) — o fato de produto ausente da §8 — virou o quinto marcador de comportamento**, e a remedição o deixou pior do que o revisor descreveu: não é só que uma posse acima de 900s passa a ser encerrada, é que os dois `forge.yaml` dos repositórios que de fato têm o mutex ligado dizem em letra que quinze minutos é pouco. O `Axis.PadSimulator` declara `stale_after_s: 3600` com o comentário *"uma suíte pesada legítima cabe folgadamente em uma hora nas quatro árvores"*, e o `axis-fare-validator` declara `enabled: true` sem `stale_after_s` sobre um repositório que *"dispara Gradle no push"*. Como o teto máximo obtenível é `espera − reserva`, uma suíte de uma hora **não é protegível** sob `timeout_s: 1800`. Isso entrou em D3 como válvula de escape publicada (`stale_after_s: 0`), na §8 como marcador, na §9 como limite declarado, na `description` do schema, e virou o quinto fato da mensagem de liaison.

### As ressalvas

| Ressalva | Remedição e desfecho |
|---|---|
| A §8 reivindica exaustividade e deixa `[31]` e `[10]` de fora | **Aceita, remedida e corrigida.** Medido com `awk`: o `[31]` abre na 569 e o `forge_heavy_mutex_acquire --timeout 3` está na **574**, com o lock montado à mão nas 576-578 (`pid=$$` do próprio gate, token divergente, **sem** `acquired_at`) — é lock TOMADO e vira a **décima terceira** linha da tabela, no regime desligado por espera ≤ reserva, com a proteção de D5 por trás. O `[10]` abre na 489 com o acquire na **494** (`--timeout 6`) e só monta `w151res.q`, nunca `w151res.lock` — é contenção de **fila** com lock LIVRE, e entrou na linha de fila, que passou de seis para sete cenários. Nenhum desfecho muda; a afirmação de exaustividade é que estava errada, e ela era o instrumento que fechou o bloqueador 4 da revisão 1 |
| M15 assevera prosa e não tem alvo mecânico | **Aceita e fechada com predicado medido.** A forma mecânica é: a `description` do bloco `heavy_mutex` **não** contém `nunca em $TMPDIR` **e** contém `${TMPDIR:-/tmp}`, as duas com `grep -aF`. O controle é o estado de hoje, que é o oposto exato nas duas metades — `grep -acF 'nunca em $TMPDIR'` devolve **1** e `grep -acF '${TMPDIR:-/tmp}'` devolve **0** sobre o `forge.schema.json` |
| D12 deixa o braço vazio de fora da paridade | **Aceita e fechada, e ela era bloqueio disfarçado de ressalva.** O `case` de `_fhm_resolve_root` tem três braços legítimos, conferidos linha a linha: `'') : ;;` na **102**, o token literal na **103**, `/*` na **118**, e o `*)` que recusa na **119**. O padrão novo é a união dos **três**, `^(?:|\$\{TMPDIR:-/tmp\}|/.*)$`, e a paridade foi medida com **ajv**, que é o validador que o repositório usa: valida `""`, o token e `/tmp`; recusa `relativo/nao-absoluto`, `tmp`, `$TMPDIR`, `${TMPDIR}`, `${TMPDIR:-/tmp}/extra` e ` /tmp`. A M10 passou de duas para três metades, porque a metade do meio — o padrão que aceita o token e recusa o vazio — é exatamente a paridade incompleta da revisão anterior, e sem ela a correção do braço vazio entraria sem que nada mordesse |
| `[26]` não diz se os locks da matriz carregam `acquired_at` | **Aceita, e resolvida pela raiz em vez de pela mensagem.** O revisor propõe mover a asserção do rc para a mensagem; eu declarei `stale_after_s: 0` nas sete variações, o que desliga o ramo de idade e devolve o rc à condição de asseverável — a asserção fica sobre o rc **e** sobre a mensagem, que é mais forte do que a saída proposta |
| A citação `w200[6], linhas 258-272` erra o começo | **Aceita e corrigida para 253-272**, medido com `awk`: a 253 é o cabeçalho do bloco, a 258 é o `echo` do rótulo e o cenário fecha na 272 |
| Em D5, o `[49](c)` é alcançado na primeira volta e não "aos ~3s" | **Aceita e corrigida em D5 e na tabela da §8.** Sob a leitura de M13, "ausente" significa "infinitamente velho" e o disparo sai em `waited = 0`, com o recolhimento em ~5-6s pela graça; o 3 é o teto **efetivo** com espera 9, não o instante do disparo. As duas metades da asserção do gate (`rc 75` e `s49 ≥ 8`) caem do mesmo jeito, então a conclusão não muda e a M13 continua mordendo |

### As medições que o revisor declarou não ter reexecutado

Ele listou sete e não as chama de sem lastro — ele diz, corretamente, que são medição minha que a revisão dele não repetiu. O desfecho de cada uma:

| Item | Desfecho |
|---|---|
| §2.1, a tabela de SIGTERM diferido | **Mantida como medição minha, com o comando e a saída já colados na §2.1 desde a revisão 2.** O revisor conferiu o mecanismo por leitura e achou a conclusão coerente com o bash; não há o que remediar sem reexecutar, e reexecutar não muda o que já está colado |
| §2.2, a ceifa de grupo | **Mantida, e o revisor confirmou a parte que importa por conta própria:** `kill -0 0` devolve rc 0 nesta máquina, o que torna a guarda `[ "$b" -gt 1 ]` de D5 obrigatória. Ela está em D5, no `[26]` e no passo 3 da §10 |
| §2.3, o nome da evidência de sweep | **Mantida**, e remedi a linha que é o mecanismo inteiro: `heavy-run.sh:117` é `rpid="$(printf '%s' "${rp##*.reaping.}" | cut -d. -f1)"`, conferida com `awk` nesta rodada |
| §2.4 e §1.3, o `git push` real | **Mantidas.** Remedi as duas âncoras que o revisor cita: `pre-push:245` é `forge_heavy_mutex_acquire --label "pre-push de $(basename "$ROOT")" || exit $?`, chamada única e de nível de topo; e a **464** é `age="$(LC_ALL=C ps -o etime= -p "$hp" ...)"`, que alimenta a **466** — é dali que sai o `há 00:00` do status, e é o achado que o `[19]` tira |
| §4, o gasto solo de ~330s do `w151` | **Mantida como citação da fonte, e remedida nesta rodada:** as linhas 75-78 do gate trazem *"305s, 319s e 325s (…) O gasto solo está, portanto, em torno de 330s"* e a linha 90 é `GATE_BUDGET_S="${W151_BUDGET_S:-600}"`. Continuo não tendo rodado aquele gate, e a §4 continua dizendo isso em letra |
| A CPU de campo da #137 | **Mantida, marcada como não reproduzível aqui**, com a divergência interna da issue registrada. O revisor confirmou que a divergência existe mesmo no corpo dela |
| Nenhum gate executado | **Correto, e nesta rodada também não.** A varredura de controle que sustenta a §8 foi refeita como texto: `grep -aFc 'espera ...... '` devolve **1** na biblioteca e `grep -aFrln` devolve **zero** arquivos em `tests/` — o instrumento acha a string onde ela está e não a acha onde eu afirmo que ela não está |

### O que esta revisão mudou de contagem, e onde conferir

Este é o bloco que existe porque o padrão que derrubou as duas rodadas anteriores é a correção que muda uma peça e não varre o resto atrás do efeito colateral.

| Contador | Antes | Agora | Onde |
|---|---|---|---|
| Cenários declarados | 27 | **27** (inalterado; o `DECLARADOS` da §7 não muda) | §4, §7 |
| Verdes por vacuidade | 6 (`[2]`,`[3]`,`[6]`,`[8]`,`[11]`,`[18]`) | **5** (`[3]`,`[6]`,`[8]`,`[11]`,`[18]`) | §4 |
| Mistos | 2 (`[10]`,`[27]`) | **3** (`[2]`,`[10]`,`[27]`) | §4 |
| Estruturais e vermelhos inteiros | 2 e 17 | **2 e 17** (inalterados) | §4 |
| Linhas da tabela de regime | — | **30** para 27 cenários | §4.1 (nova) |
| Mutações | 15 | **17** (M16 e M17 novas) | §5, §10 passo 6 |
| Mutações que rodam a suíte inteira | 2 (M13, M2) | **3** (mais M16) | §10 passo 6 |
| Subcontadores de matriz | 3 (`[25]`,`[26]`,`[27]`) | **6** (mais `[2]`,`[10]`,`[21]`), por regra declarada e não por lista | §7 |
| Linhas da tabela de comportamento do `w151` | 12 | **13** (mais `[31]`) | §8 |
| Cenários do `w151` protegidos pela aritmética da reserva | 6 | **7** | §8 |
| Cenários de fila do `w151` | 6 | **7** (mais `[10]`) | §8 |
| Marcadores de "o que muda para quem já instalou" | 4 | **5** | §8 |
| Fatos da mensagem de liaison | 5 | **6** | §10 passo 9 |
| Metades da M10 | 2 | **3** | §5 |
| Braços na paridade schema/leitor | 2 | **3** | D12, `[21]` |

Cinco mais dois mais três mais dezessete são vinte e sete, que é o `DECLARADOS` da §7 e o denominador do `[23]`. As trinta linhas da §4.1 são os vinte e sete cenários mais os três segundos arranjos de `[2]`, `[10]` e `[27]`, que são exatamente os três mistos. As dezessete mutações são M1 a M17, sem buraco, e a §5 declara quais três cenários ficam deliberadamente sem contrafactual e por quê. As treze linhas da §8 são sete do regime desligado, uma do `[49](c)`, três de margem de tempo, uma do `[9]` e uma de fila com sete cenários dentro.
