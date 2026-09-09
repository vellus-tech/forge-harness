# Onda L3 — `pre-push`: custo, instrumentação e worktree (especificação implementável)

Autor: especificador do subgrupo L3. Revisão 3, de 2026-09-08, respondendo ao veredito da revisão 1 (§9) e ao da revisão 2 (§10). Base medida: branch `feat/fase1-dogfood-completo`, `template_version` 0.14.0 publicada no npm, `template/.forge/hooks/git/pre-push` com 500 linhas (`wc -l < template/.forge/hooks/git/pre-push` → `500`).

Escopo: issues **#132** e **#134** (tratadas como **um item com duas consequências**, conforme o plano-mestre), **#135** e **#141**.

Esta especificação é para ser executada, não lida. Toda afirmação numérica traz o comando que a produziu e a saída colada; onde o número não sobreviveu à remedição, ele foi corrigido ou removido, e a §9 (revisão 2) e a §10 (revisão 3) listam qual foi qual. Toda bancada rodou sob `$TMPDIR`, com o `cwd` dentro da fixture, e a árvore real do repositório não foi escrita em momento nenhum além deste arquivo.

**Uma correção de método que precede tudo, e que invalidou parte da revisão 1: varredura de texto que devolve vazio não prova ausência.** `template/.forge/scripts/lib/secret-scan.mjs` é UTF-8 válido, o node o executa certo, e o `grep` sem `-a` o pula sem uma linha de aviso, porque o literal de regex do detector de binário do próprio arquivo carrega os bytes de controle LITERAIS. Medido:

```
$ python3 -c "
d=open('template/.forge/scripts/lib/secret-scan.mjs','rb').read()
print('tamanho',len(d))
for b in (0,8,0x0e,0x1f): print(hex(b), d.find(bytes([b])))"
tamanho 12587
0x0 8521
0x8 8523
0xe 8524
0x1f 8526

$ find tests template -type f | while read -r f; do t=$(file -b "$f"); case "$t" in *text*|*script*|*JSON*|*Unicode*) ;; *) echo "$t :: $f";; esac; done | grep -v empty | grep -v DS_Store
data :: template/.forge/scripts/lib/secret-scan.mjs
```

Controle positivo, com um token que o arquivo comprovadamente contém e que não tem forma de credencial:

```
$ grep -arln 'export function' template/.forge/scripts/lib/ | wc -l
      31
$ grep -rln 'export function' template/.forge/scripts/lib/ | wc -l
      30
$ diff <(grep -arln 'secret' template/.forge/scripts/lib/ | sort) <(grep -rln 'secret' template/.forge/scripts/lib/ | sort)
2d1
< template/.forge/scripts/lib/secret-scan.mjs
```

Um arquivo some da varredura e nada avisa. **Toda varredura desta especificação que afirma AUSÊNCIA foi refeita com `-a`**, e o `data` acima é o único arquivo de `tests/` e `template/` que o `file` não classifica como texto, de modo que o universo das varreduras é agora conhecido em vez de suposto. É a invariante 2 do plano-mestre — três estados, nunca dois — aplicada à ferramenta de medição em vez de ao objeto medido.

**Regra de método, e ela é a invariante 19 do plano-mestre.** A especificação declara a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir; quem escolhe o primitivo é o implementador, que executa, e ele prova que o primitivo discrimina. Comando exato só permanece aqui quando veio de execução minha, com a saída colada. A §8 registra as **sete** vezes em que eu mesmo escrevi uma hipótese e a medição a derrubou — duas na revisão 1, cinco a mais na revisão 2, e três dessas cinco são erros que o revisor apontou e que eu confirmei remedindo.

---

## 0. Resumo do que muda

| Peça | Arquivo | Natureza |
|---|---|---|
| Curto-circuito de push de deleção pura, com desfecho nomeado e contador | `template/.forge/hooks/git/pre-push` | comportamento novo; nenhuma string existente muda |
| Teto de tempo em `run_check`, com os três estados de tempo e mensagem que nomeia o check | `template/.forge/hooks/git/pre-push` | comportamento novo, opt-in por valor |
| Resolução da delegação na árvore do hook — 6 sítios | `template/.forge/hooks/git/pre-push` | precedência nova; as recusas existentes são preservadas literalmente |
| Resolução da delegação na árvore do hook — 1 sítio | `template/.forge/hooks/git/pre-commit` | idem |
| Resolução da delegação na árvore do hook — 1 sítio | `template/.forge/hooks/git/commit-msg` | idem |
| Resolução da delegação na árvore do hook — 2 sítios | `template/.forge/hooks/git/post-merge` | idem |
| Resolução da delegação na árvore do hook — 2 sítios | `template/.forge/hooks/git/lib/check-red-first.sh` | idem |
| Anúncio do nome do teste **antes** de executá-lo | `template/.forge/scripts/tests/run-all.sh` | linha nova; nenhuma linha existente muda |
| Anúncio do nome do gate **antes** de executá-lo | `tests/run-all.sh` | linha nova; não distribuído |
| Fixture de `w97:38` passa a alimentar `local_sha` **não zero** | `tests/w97-hook-portability-gate.sh` | **obrigatório**: o gate fica VERMELHO sem isso, medido em §7.1. Não é "real": a fixture faz `git init` sem commit e não há sha real ali |
| Gate de escopo e tempo do `pre-push` | `tests/w<NNN>-prepush-escopo-e-tempo-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Gate de resolução de delegação | `tests/w<NNN>-delegacao-arvore-do-hook-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Badge `gates-N` do README | `README.md` | **obrigatório**: dois gates novos, o badge sobe 2 (ver §7) |

**São sete arquivos de produção — cinco de maquinaria de hook e dois runners — mais o README e o fixture de `w97`.** A revisão 1 listava cinco e nomeava dois hooks, o que contradizia D14 (§4.3), que fecha a decisão de aplicar a precedência a toda a classe. A contradição está resolvida a favor de D14, com o universo remedido em §4.3 e coberto pelo cenário de auto-ironia `[19]` do gate 2.

**A contagem por arquivo desta tabela é derivada da MESMA varredura que sustenta D14, não escrita à mão — foi assim que a revisão 2 deixou passar um sítio de `pre-push` a menos.** Medido:

```
$ grep -arn 'BLOQUEADO\|FALHOU' template/.forge/hooks/ | grep -ai 'ausente\|existe mas\|não existe\|não —\|sumiu' \
    | sed 's|template/.forge/hooks/||' | cut -d: -f1 | sort | uniq -c
   1 git/commit-msg
   2 git/lib/check-red-first.sh
   2 git/post-merge
   1 git/pre-commit
   9 git/pre-push
```

Nove recusas no `pre-push`, das quais **três estão fora da classe com motivo escrito** (`:176`, `:391`, `:455`, tabela de §4.3) — restam **6**. Com 1 + 1 + 2 + 2 dos outros quatro arquivos, o total é **12**, que é o número que §4.3 usa três vezes. A linha de `pre-push` desta tabela dizia 5 e o total dava 11: era o resíduo do bloqueador 3 da revisão 1, e ele fica registrado como tal na §10.

**Nenhum arquivo novo sob `template/.forge/scripts/`**, e isso é decisão, não acaso: a linha `└── scripts/ (136)` do README é conferida por `w200` contra `find template/.forge/scripts -type f ! -name README.md | wc -l`, e manter o conjunto intacto tira essa contagem do caminho crítico da onda. Medido hoje:

```
$ grep -n 'scripts/ (' README.md
235:└── scripts/ (136)      # engine determinista (graph, archive, eval, provenance, hooks, …) — inclui lib/ e tests/
$ find template/.forge/scripts -type f ! -name README.md | wc -l
     136
```

O `check-red-first.sh` que a onda edita mora em `template/.forge/hooks/git/lib/`, não em `scripts/`, e portanto não entra nessa contagem.

**Nenhum arquivo sob `template/.forge/commands/`**, então `npm run build:plugin` não é necessário e o `plugin-sync-gate` não é tocado. Conferido por execução, não por leitura da tabela: `ls plugin/forge/` devolve só `commands`, e a varredura de §7 mostra que o gate de sincronia compara exclusivamente `template/.forge/commands` com `plugin/forge/commands`.

Ordinais: o máximo publicado é **w207**, remedido em 2026-09-08 sobre TODAS as refs remotas, não sobre uma lista escrita à mão:

```
$ git for-each-ref --format='%(refname)' refs/remotes/origin | while read -r b; do m=$(git ls-tree -r --name-only "$b" tests/ 2>/dev/null | grep -oE '/w[0-9]+' | sed 's|/w||' | sort -n | tail -1); [ -n "$m" ] && echo "$m $b"; done | sort -rn | head -5
207 refs/remotes/origin/main
207 refs/remotes/origin/HEAD
207 refs/remotes/origin/develop
154 refs/remotes/origin/wip/upgrade-safety-ldg-0131
80 refs/remotes/origin/wip/deepspec-run-manifest-ldg-0165
``` Os dois ordinais desta onda **não são alocados aqui**: a invariante 10 atribui a alocação ao orquestrador, no momento de escrever o arquivo, contra `origin/*` **e** contra as branches em voo desta rodada.

---

## 1. A régua da onda — o que reproduz no template e o que não reproduz

Esta é a primeira obrigação do subgrupo e vem antes de qualquer decisão de desenho. As quatro issues são medições de terceiro, feitas na árvore instalada do consumidor. Reproduzi cada uma aqui, no `template/`.

| Issue | Metade | Reproduz no template? | Consequência |
|---|---|---|---|
| #132 / #134 | push de deleção pura paga `typecheck`, `test`, gates de `runtime.gates` e `harness-tests` | **SIM**, medido em §2.1 | correção é de produto, no template |
| #132 | o mecanismo específico: sentinela `_viu_ref` colapsando "entrada vazia" com "só deleções", e a função `push_diff_todo_seguro` | **NÃO** — nenhum dos três símbolos existe no template | ver §1.1 |
| #134 | um manifesto órfão de `pre-push` por deleção | **NÃO** — o `pre-push` do template não carimba manifesto nenhum | ver §1.2 |
| #135 | `run_check` sem teto enquanto `forge_run_gate` tem 300 s | **SIM**, medido em §3.1 com contrafactual | correção é de produto |
| #135 | `run-all.sh` só imprime o nome do teste depois de ele terminar | **SIM**, medido em §3.2, nos **dois** runners | correção é de produto |
| #141 | `core.hooksPath` absoluto + delegação por `$ROOT` bloqueia o commit em worktree | **SIM**, medido em §4.1, com a mensagem literal da issue | correção é de produto |

### 1.1 O mecanismo de #132 não existe no template, e isso muda o diagnóstico

```
$ grep -arn 'push_diff_todo_seguro\|_viu_ref\|_pular_suite' template/ tests/ ; echo "rc=$?"
rc=1
```

O `-a` não é cosmético e o controle positivo do MESMO comando prova que a varredura leu o universo — se ela não lesse, o vazio acima não significaria nada:

```
$ grep -arln 'export function' template/ tests/ | wc -l
      42
$ grep -rln 'export function' template/ tests/ | wc -l
      41
```

A issue #132 cita `pre-push:291-315` "na numeração da árvore do consumidor" e transcreve um laço com `_todas_seguras`, `_viu_ref` e `push_diff_todo_seguro`. Nada disso é do harness: é maquinaria local do `Axis-Mobfintech/Axis.DevicePlatform`, repositório que **não está nesta máquina** (`ls -d ~/Documents/projects/*Device*` → sem correspondência), de modo que a árvore de origem daquela medição não pôde ser inspecionada.

**O que isso significa, em letra.** A análise causal da #132 está correta sobre o consumidor e **não descreve o template** — no template não há sentinela colapsando dois estados, porque não há curto-circuito nenhum a colapsar. A consequência, porém, é idêntica e pior: no template a deleção pura paga a suíte **sempre**, não só quando uma sentinela erra. A correção, portanto, não é "consertar `_viu_ref`": é **criar** o curto-circuito que o consumidor já criou por conta própria, com a distinção de três estados que a #132 pede, e distribuí-lo. O parágrafo da #132 sobre entrada vazia continua sendo a especificação certa do comportamento desejado; ele só não é a descrição de um defeito do template.

Uma segunda leitura, e ela é a que justifica a régua: **o campo consertou primeiro e o produto ficou atrás**. O `axis-fare-validator` já tem o curto-circuito na cópia dele, com 688 linhas contra as 500 do template. Os dois trechos citados foram inspecionados, não presumidos:

```
$ sed -n '33,35p;64,66p' ~/Documents/projects/axis-fare-validator/.forge/hooks/git/pre-push
# ── PUSH DE DELEÇÃO: o universo dos checks caros é a ÁRVORE, e deleção não publica árvore ──────
#
# MEDIDO em 2026-09-07 (R40), ao remover 25 branches remotas autorizadas: `git push origin
if [ "$_pp_n_refs" -gt 0 ] && [ "$_pp_todas_delecoes" -eq 1 ]; then
  echo "pre-push: push de DELEÇÃO — ${_pp_n_refs} ref(s), todas com local_sha zero. ..."
  exit 0
```

E a inspeção muda uma coisa: a implementação dele usa um **booleano** (`_pp_todas_delecoes`, zerado por qualquer ref com `local_sha` não zero) e não distingue a linha não classificável. É exatamente a forma que D1 recusa, e agora a recusa está medida no código do consumidor em vez de deduzida da transcrição da issue. Isso não é divergência inocente — `hooks` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS` (`bin/forge.mjs:307,352`), então o próximo `forge update` **sobrescreve o arquivo inteiro** e apaga o conserto do consumidor. É o mecanismo da issue #101 e da Onda L1, e ele torna esta onda urgente por um motivo que nenhuma das quatro issues declara: enquanto o template não tiver a guarda, o updater é um vetor de regressão contra quem já a tem.

### 1.2 O manifesto órfão de #134 não reproduz aqui, e a correção muda de lugar

```
$ grep -an 'run-manifest\|stamp' template/.forge/hooks/git/pre-push ; echo "rc=$?"
rc=1
$ ls template/.forge/scripts/prepush-manifest.sh
ls: template/.forge/scripts/prepush-manifest.sh: No such file or directory
$ grep -arni 'push[._]refs' template/ | wc -l
       5
$ grep -arni 'push[._]refs' template/ | grep -ci 'FORGE_PUSH_REFS_FILE'
5
$ grep -arni 'push[._]refs' template/ | grep -vi 'FORGE_PUSH_REFS_FILE' ; echo "rc=$?"
rc=1
```

A terceira varredura é a que a revisão 2 colou errada, e a explicação colada era falsa. Ela estava escrita como `grep -arn 'push\.refs\|push_refs' template/ | grep -v FORGE_PUSH_REFS` com `rc=0` e a glosa "casa só ocorrências de `FORGE_PUSH_REFS_FILE`, que o filtro remove". **Não casa nada:** `push_refs` é minúsculo e `FORGE_PUSH_REFS_FILE` é maiúsculo, de modo que o primeiro `grep` já devolve zero linhas e o pipeline devolve `rc=1`, não 0 — o revisor mediu isso e eu reproduzi. A forma acima é a correta e traz o controle positivo no meio: as cinco ocorrências de `push[._]refs` em `template/` existem, todas as cinco são `FORGE_PUSH_REFS_FILE`, o filtro remove as cinco, e o `rc=1` final é ausência real de um bloco `push.refs` de manifesto — não ausência de leitura.

O `pre-push` do template não carimba manifesto de execução. O `stamp` citado pela #134 vem de `PREPUSH_MANIFEST_SH`, maquinaria local do consumidor sobre `run-manifest/v1`, e a citação foi conferida:

```
$ grep -an 'PREPUSH_MANIFEST_SH\|run-manifest' ~/Documents/projects/axis-fare-validator/.forge/hooks/git/pre-push | head -4
360:# execução pode ter mudado — não é hipótese, é o LDG-0471, o `run-manifest.mjs` do template
378:PREPUSH_MANIFEST_SH="$ROOT/.forge/scripts/prepush-manifest.sh"
379:if [ -f "$PREPUSH_MANIFEST_SH" ]; then
380:  PREPUSH_MANIFEST="$(FORGE_PUSH_REFS_FILE="$FORGE_PUSH_REFS_FILE" bash "$PREPUSH_MANIFEST_SH" stamp \\
```

**O que isso significa.** A metade "um órfão por deleção" é **defeito de instalação, não de produto**, e esta onda não a corrige — não há como corrigir um artefato que o template não produz. O que a onda faz é garantir que, se o template um dia carimbar, o carimbo já nasça do lado certo da fronteira: o curto-circuito é o **primeiro** bloco depois da escrita de `FORGE_PUSH_REFS_FILE`, antes de qualquer delegação, e o cenário `[7]` do gate 1 asserta essa posição estaticamente. É a única forma de fechar a classe sem inventar o defeito para poder consertá-lo.

O ack ao `axis-fare-validator` precisa dizer isto sem contornar: a correção dele está certa, o template vai passar a trazê-la, e a metade do manifesto continua sendo dele porque a maquinaria é dele.

### 1.3 Retificação de um número do plano-mestre

O plano diz que "os quatro já aplicaram a 0.14.0". Medido:

```
$ for d in ~/Documents/projects/*/.forge/forge.yaml; do r=$(basename $(dirname $(dirname $d))); grep -m1 template_version "$d" | tr -d ' ' | sed "s|^|  $r |"; done
  axis-fare-validator template_version:"0.14.0"
  axis-go-cloud       template_version:"0.14.0"
  Axis.PadSimulator   template_version:"0.11.0"
  azim-crm            template_version:"0.14.0"
  lionclaw            template_version:"0.14.0"
```

**Três dos quatro estão na 0.14.0; o `Axis.PadSimulator` está na 0.11.0**, e o `lionclaw`, que não é um dos quatro, também está na 0.14.0. A diferença importa para a §4.5: o `Axis.PadSimulator` tem 28 worktrees e um `pre-push` de 327 linhas, versão anterior, então a retrocompatibilidade da onda precisa valer para duas gerações de maquinaria instalada, não uma.

---

## 2. ITEM 1 — #132 e #134: o push que não publica árvore paga a árvore inteira

### 2.1 O defeito, reproduzido

Bancada: repositório git em `$TMPDIR` com `.forge/` do template copiado, `FORGE.md` cujos `typecheck` e `test` são sondas que criam um arquivo-marcador, `runtime.gates` declarando um gate que também marca, e `.forge/scripts/tests/run-all.sh` substituído por outra sonda. O marcador é o sinal **positivo** de execução exigido pela rule `testing/gate-delivery-channel.md`: a ausência de erro não prova que o check não rodou.

```
$ cd "$R" && printf '(delete) 0000000000000000000000000000000000000000 refs/heads/morta 1111111111111111111111111111111111111111\n' \
  | bash "$WS/template/.forge/hooks/git/pre-push" origin git@example:x.git
OK liaison-acks — sem canal
OK liaison-log-integrity — sem canal
pre-push: shell-lints — 0 arquivo(s) .sh no diff publicado; nada a varrer
pre-push: typecheck OK
pre-push: test OK
pre-push: harness-tests OK
forge-push-ahead: NÃO MEDIDO — remoção de ref (2026-09-07 21:17:42 -0300)
pre-push OK
rc=0
marcas: harness-tests.ran test.ran typecheck.ran
```

Com `runtime.gates: check-marca` declarado, a quarta marca aparece junto:

```
pre-push: runtime.gates — 1 gate(s) de fase 'source' de 1 declarado(s)
marcas: gate-check-marca.ran harness-tests.ran test.ran typecheck.ran
```

**As quatro famílias caras rodam num push que apaga uma ref.** E a leitura mais dura da saída acima é que **dois blocos do mesmo arquivo já sabem discriminar a deleção** — o `shell-lints` diz "0 arquivo(s) .sh no diff publicado" e o `check-push-ahead` diz "NÃO MEDIDO — remoção de ref" — enquanto os quatro caros seguem em frente. O hook não é cego à deleção; ele é cego a ela exatamente onde custa.

Cinco formatos medidos contra o hook de hoje, com as mesmas sondas:

| Formato | rc | caros rodaram |
|---|---|---|
| `[A]` deleção pura, 1 ref | 0 | typecheck, test, harness-tests |
| `[B]` deleção pura, 3 refs | 0 | typecheck, test, harness-tests |
| `[C]` misto (1 deleção + 1 publicação) | 0 | typecheck, test, harness-tests |
| `[D]` stdin vazio | 0 | typecheck, test, harness-tests |
| `[E]` publicação pura | 0 | typecheck, test, harness-tests |

Cinco entradas semanticamente distintas, um único comportamento. `[C]`, `[D]` e `[E]` estão corretos por acidente, não por decisão.

### 2.2 Enumeração exaustiva dos formatos, e o sexto caso que a derruba

A invariante 17 exige procurar ativamente o caso não coberto. Rodei mais seis formatos contra a **implementação** de §2.4 (não contra o hook de hoje), justamente para achar onde ela erra:

| Formato | Classificação da implementação | Correto? |
|---|---|---|
| `[F]` deleção com terminador CRLF | deleção → pula | **sim** — o `\r` cai no último campo, nunca no `local_sha` |
| `[G]` deleção seguida de linha em branco | deleção → pula | sim — a linha vazia não conta como ref |
| `[H]` deleção sem newline final | deleção → pula | sim — `pre-push:31` reescreve o payload com `printf '%s\n'` e normaliza o terminador |
| `[I]` deleção de **tag** | deleção → pula | sim — apagar tag também não publica árvore |
| `[J]` linha malformada com 2 campos, sendo o segundo o sha zero | deleção → **pula** | **NÃO** |
| `[K]` campos separados por múltiplos espaços | deleção → pula | sim — `IFS=' '` colapsa runs de espaço |

**`[J]` é o sexto caso, e ele é a invariante 2 aparecendo dentro da própria correção.** Uma linha que este parser não consegue classificar não é "nada a provar": é "não consegui saber o que este push carrega". Colapsar os dois no mesmo `exit 0` é reproduzir, dentro do remédio, o defeito que o remédio existe para curar — e a #132 diz isso com todas as letras ao separar "entrada vazia" de "só deleções". Uma linha só é contada como deleção quando tem os **quatro** campos não vazios e o segundo é o sha zero; qualquer outra forma conta como conteúdo, e conteúdo faz a suíte rodar. É a saída conservadora, e a assimetria é deliberada: errar para o lado de rodar custa tempo, errar para o lado de pular custa cobertura.

O `git` nunca produz uma linha `[J]`. Isso não é argumento para não tratá-la: o hook também não escolhe quem escreve no stdin dele, e o `pre-push` já é invocado com payload sintético por seis gates da própria suíte.

### 2.3 O custo, e por que ele não é conveniência

Estes números são **medição de terceiro**, feita no `Axis-Mobfintech/Axis.DevicePlatform`, que não está nesta máquina — eu não os reproduzi e não tenho como. O que eu posso lastrear é a **procedência**, e ela foi conferida linha a linha no corpo das issues:

```
$ grep -n '28 minutos\|21 de 50\|load 37' <corpo da #132>
39:... já foi medido detido por **mais de 28 minutos** por uma frente vizinha (`adp#LDG-0590`), e uma
    execução de pre-push sob contenção mediu **21 de 50 suítes de shell em 15 minutos com load 37**
    sem terminar (`adp#LDG-0622`).
$ grep -n '25 execuções\|~70 segundos' <corpo da #134>
16:As 25 seriam **25 execuções completas** de uma suíte que custa mais de 10 minutos nesta árvore.
18:Depois do curto-circuito, as 25 fecharam em **~70 segundos no total**, `rc=0` em todas.
```

Cada número traz o item de ledger do consumidor que o produziu (`adp#LDG-0590`, `adp#LDG-0622`), e é assim que eles devem ser lidos: como relato citável de campo, nunca como medição desta especificação. Nenhuma decisão de desenho desta onda depende do valor deles — o que decide é o defeito reproduzido em §2.1, no template, nesta máquina.

O efeito de segunda ordem é o que decide: **ninguém apaga branch**, e o parque de refs cresce sem limite. A #132 registra que a remoção de sete pontas já absorvidas pelo tronco foi **adiada** por causa deste defeito — sete refs com `git rev-list --count origin/develop..<ref>` igual a zero, que não custariam nada para apagar. Um gate cujo custo faz o operador desistir da higiene que o gate deveria proteger não é caro: é contraproducente.

### 2.4 Decisões de desenho — FECHADAS

**D1. O critério é "toda ref deste push tem `local_sha` zero", contado por dois contadores, nunca por um booleano.**

Um contador de refs vistas e um de refs com conteúdo. `refs > 0 && com_conteúdo == 0` é deleção pura e pula; `com_conteúdo > 0` roda; `refs == 0` (entrada vazia) roda. Três estados, três desfechos, cada um dito em voz alta.

*Alternativa descartada — o booleano que a #132 transcreve do consumidor.* Um único `_viu_ref` não consegue representar três estados, e é exatamente por isso que ele colapsou dois lá. Copiar a forma que falhou seria importar o defeito junto com a correção.

*Alternativa descartada — testar só `case "$lsha" in *[!0]*)`, o idioma que o próprio `pre-push` já usa nas linhas 79 e 269.* Esse teste aceita qualquer string composta só de zeros, de qualquer comprimento. Ele está correto onde é usado hoje (dentro de um laço, para pular a ref individual), e é inseguro como critério de **pular a suíte inteira**, porque a decisão passa a depender de uma forma frouxa. A comparação é com o literal de 40 zeros, o mesmo que as linhas 80 e 273 já usam para o `rsha`.

**D2. O curto-circuito é o primeiro bloco depois da escrita de `FORGE_PUSH_REFS_FILE`, e sai com `exit 0`.**

Antes de qualquer delegação. Duas razões, e a segunda é a que fecha a metade não reproduzível de #134: qualquer efeito colateral que o hook venha a ganhar — carimbo de manifesto inclusive — nasce automaticamente **depois** do curto-circuito, sem que ninguém precise lembrar. O cenário `[7]` do gate 1 asserta a posição.

*Alternativa descartada — pular apenas os quatro blocos caros, mantendo os baratos.* Ela é defensável e eu a considerei seriamente, porque `check-liaison-acks` e `check-docs-reviewed` não são checks de árvore e uma deleção não deveria dispensá-los. Cai por duas medições. A primeira: o `axis-fare-validator` já implementou a saída total e a operou em campo, e divergir dele agora significa que o `forge update` vai **mudar o comportamento** de um consumidor que já mediu o dele — custo alto para ganho hipotético. A segunda: o único desses checks com poder de bloqueio real sobre uma deleção seria o de acks, e um operador impedido de apagar uma branch morta por causa de um ack pendente usa `--no-verify` e desliga tudo, que é o desfecho que a #141 documenta como o pior. A recusa de acks continua valendo em todo push que publica.

**D3. A saída é falada, nomeia a contagem, e é distinta de "o gate aprovou".**

A linha diz quantas refs, que nenhuma tem conteúdo a provar, e quais famílias deixaram de rodar. "Pulei porque não se aplica" e "rodei e passou" não podem terminar no mesmo silêncio; é a issue #49, que este arquivo já cita em seis lugares.

**D4. Linha não classificável conta como conteúdo, e o hook diz que não conseguiu classificar.**

O caso `[J]` de §2.2. A linha impressa nomeia quantas linhas não foram classificadas, para que "não consegui" nunca vire indistinguível de "não havia".

**D5. `runtime.gates` de fase `source` também é pulada.**

Um gate de fase `source` lê a árvore de fontes por definição — é o que a rule `testing/gate-delivery-channel.md` estabelece ao dizer que o contrato de gate do harness é "inteiramente em forma de árvore de fontes". Numa deleção não há árvore publicada para ele medir. A alternativa (rodar os gates e pular só typecheck/test) foi descartada por incoerência: ela mediria a árvore de trabalho para provar algo sobre um push que não a carrega, que é o "escopo ancorado errado" que a #134 nomeia.

### 2.5 O VERMELHO, antes do verde — gate 1

Gate novo `tests/w<NNN>-prepush-escopo-e-tempo-gate.sh`, cobrindo os itens 1 e 2 desta onda (o escopo do push e a política de tempo vivem no mesmo arquivo e no mesmo caminho de execução). **`DECLARADOS=15`**, denominador fixo por construção — a revisão 1 declarava 14 e o cenário `[15]` nasce da medição de D7 (§3.4).

Os cenários `[8]` a `[13]` pertencem ao item #135 e estão descritos aqui por coesão de gate; a justificativa deles está na §3.

| # | Cenário | Asserção | Mensagem do vermelho hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [1] | deleção pura, 1 ref | nenhuma marca de execução cara; rc 0; a saída nomeia o desfecho e a contagem | `FAIL [1]: push de deleção pura executou typecheck, test, harness-tests (3 marcas)` | não existe curto-circuito nenhum — medido em §2.1 |
| [2] | deleção pura, 3 refs | idem, e a contagem impressa é 3 | `FAIL [2]: ...` | idem |
| [3] | misto: 1 deleção + 1 publicação | as marcas caras **existem**; a linha de deleção **não** aparece | — | nasce verde hoje; é o cenário que todo conserto ingênuo quebra |
| [4] | stdin vazio | as marcas caras existem; a saída distingue "vazio" de "só deleções" | `FAIL [4]: entrada vazia não foi nomeada como estado próprio` | hoje o hook não imprime nada sobre a forma do push |
| [5] | deleção de tag | nenhuma marca cara | `FAIL [5]: ...` | idem [1] |
| [6] | linha com 2 campos, segundo = sha zero | as marcas caras **existem**, e a saída diz que houve linha não classificada | `FAIL [6]: linha não classificável foi tratada como nada a provar` | não há parser, logo não há classe "não classificável" |
| [7] | **estático**: o bloco de curto-circuito aparece antes da primeira delegação do arquivo | o índice da linha do curto-circuito é menor que o da **única** ocorrência de `^HOOK_LIB_DIR=` (ancorada em início de linha), e o gate reprova se essa ocorrência não for única | `FAIL [7]: o curto-circuito não existe no arquivo` | idem |
| [8] | teto declarado, check que o excede | o check é interrompido, rc ≠ 0, e a mensagem nomeia **o check** e **o teto** | `FAIL [8]: o check de 5 s completou sob teto de 2 s — run_check não tem teto` | medido em §3.1: `run_check` ignora o teto |
| [9] | teto declarado, check dentro do teto | passa, e o desfecho **não** é "estourou" | — | nasce verde; é o controle negativo de [8] |
| [10] | teto **não** declarado, medido **no `harness-tests`**, em fixture que **declara** `runtime.gates` | a saída nomeia a política em vigor ("sem teto") para aquele check | `FAIL [10]: a política de tempo não é declarada` | hoje não há política nenhuma a declarar |
| [11] | check que sai com rc 142 **por conta própria**, dentro do teto | é reportado como reprovação, **não** como estouro de teto | `FAIL [11]: rc 142 legítimo classificado como estouro` | medido em §3.1: o rc sozinho não discrimina |
| [12] | suíte com um teste que pendura, morta por fora | a última linha do log nomeia **o teste em curso**, não o último concluído | `FAIL [12]: o log nomeia b-rapido (concluído) e não c-pendura (em curso)` | medido em §3.2 |
| [13] | suíte normal | as linhas de desfecho existentes (`✓`, `✗`, contador, `PASS=`) continuam presentes | — | nasce verde; é a guarda de retrocompatibilidade de [12] |
| [14] | contador de controle do próprio gate | 15 de 15 cenários executados | — | verde por construção |
| [15] | **uniformidade da política na mesma execução**: um único push cujo `FORGE.md` declara `runtime.gates`, com o ambiente **sem** a variável de orçamento | a política de tempo reportada é a **mesma** para `typecheck` e para `harness-tests` | `FAIL [15]: typecheck reporta 'sem teto' e harness-tests reporta 300 s no mesmo push` | medido em §3.4: `pre-push:401` sourceia `forge-runtime.sh` entre os dois pares de `run_check`, e `forge-runtime.sh:20` injeta o default de 300 s |

Três cenários — `[3]`, `[9]`, `[13]` — **nascem verdes** e estão aqui como controles negativos, não como cobertura nova; `[14]` é a sentinela do próprio gate. Onze dos quinze falham hoje por ausência real da funcionalidade.

O cenário `[15]` é a guarda que faltava na revisão 1 e é o que impede a implementação de "ler `FORGE_GATE_TIMEOUT_S` dentro de `run_check`", que é a leitura ingênua e a errada. Ele é vermelho hoje por ausência real — não existe política de tempo nenhuma a comparar — e continua vermelho contra a implementação ingênua, que é o que faz dele um teste e não uma anotação.

Todo número que aparece na coluna "Mensagem do vermelho hoje" é valor medido na bancada e serve para o implementador reconhecer o vermelho. **Nenhum deles é literal no fonte do gate:** a mensagem imprime o que o gate mediu naquela execução, e a asserção é sobre a propriedade.

### 2.6 Prova de mutação — remedida na revisão 2, com controle, recontrole e a bancada colada

A revisão 1 colou uma saída de bancada que não podia ser rerodada, porque a implementação mutada vivia num `$TMPDIR` que já não existe. A bancada foi **reconstruída do zero em 2026-09-08** e as quatro mutações abaixo são medidas de novo, com o comando ao lado.

A implementação de referência (D1 a D4) foi escrita numa cópia do `pre-push` sob `$TMPDIR`, contra um repositório git com `.forge/scripts/` do template, `FORGE.md` cujos `typecheck` e `test` são sondas `touch` e `run-all.sh` substituído por outra sonda. A marca de arquivo é o sinal **positivo** exigido pela rule `testing/gate-delivery-channel.md`: ausência de erro não prova que o check não rodou.

Estado da implementação, antes de qualquer mutação:

```
  [A] rc=0 caro=[] delecao_dita=1 vazio_dito=0
  [B] rc=0 caro=[] delecao_dita=1 vazio_dito=0
  [C] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [D] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=1
  [E] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [J] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
```

| Mutação | O que muda | Cenário derrubado, MEDIDO | Recontrole |
|---|---|---|---|
| M1 | `if [ "$_pp_refs" -eq 0 ]` → `if [ 1 -eq 0 ]` (remove a guarda de entrada vazia) | `[D]` cai: `caro=[] delecao_dita=1` — o stdin vazio passa a ser tratado como deleção | restaurado por `cp`, `cmp -s` limpo, `[D]` volta |
| M2 | `elif [ "$_pp_conteudo" -eq 0 ]` → `elif [ "$_pp_conteudo" -lt "$_pp_refs" ]` ("alguma" em vez de "todas") | `[C]` cai: o misto passa a ser pulado | idem, `[C]` volta |
| M3 | remover o bloco inteiro — é literalmente o `pre-push` do template de hoje | `[A]`, `[B]` e `[J]` caem juntos: nenhum desfecho é nomeado e os caros rodam em tudo | o bloco de volta e os três voltam |
| M4 | `[ -n "${_pp_rr:-}" ] && [ -n "${_pp_rs:-}" ]` → `true` (desfaz D4) | `[J]` cai: a linha de 2 campos vira deleção e pula a suíte | idem, `[J]` volta |

Saída integral da bancada, as quatro:

```
=== M1 — remover a guarda de entrada vazia (refs > 0)
  (cmp: arquivo mudou; bash -n limpo)
  [A] rc=0 caro=[] delecao_dita=1 vazio_dito=0
  [C] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [D] rc=0 caro=[] delecao_dita=1 vazio_dito=0                              <-- caiu
  [E] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [J] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  (restaurado byte a byte)
=== M2 — 'alguma deleção' em vez de 'todas deleções'
  (cmp: arquivo mudou; bash -n limpo)
  [A] rc=0 caro=[] delecao_dita=1 vazio_dito=0
  [C] rc=0 caro=[] delecao_dita=1 vazio_dito=0                              <-- caiu
  [D] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=1
  [E] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [J] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  (restaurado byte a byte)
=== M3 — remover o bloco inteiro (o hook do template, sem modificação)
  [A] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0  <-- caiu
  [B] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0  <-- caiu
  [C] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [D] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [E] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [J] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0  <-- caiu
=== M4 — aceitar linha de 2 campos como deleção (desfazer D4)
  (cmp: arquivo mudou; bash -n limpo)
  [A] rc=0 caro=[] delecao_dita=1 vazio_dito=0
  [C] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [D] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=1
  [E] rc=0 caro=[harness-tests test typecheck] delecao_dita=0 vazio_dito=0
  [J] rc=0 caro=[] delecao_dita=1 vazio_dito=0                              <-- caiu
  (restaurado byte a byte)
```

Cada mutação isola exatamente um cenário — M3 isola a família de deleção inteira, que é o esperado de remover a funcionalidade — e deixa os demais verdes. Uma mutação que derrubasse tudo não distinguiria guarda nenhuma.

**M5 — mover o curto-circuito para depois da primeira delegação — é estática e foi medida por índice de linha**, não por comportamento:

```
  pre-push.impl (com o curto-circuito): curto-circuito=32  primeira ^HOOK_LIB_DIR==56
  pre-push (template, hoje):            curto-circuito=AUSENTE  primeira ^HOOK_LIB_DIR==37
$ grep -ac 'HOOK_LIB_DIR' template/.forge/hooks/git/pre-push
5
$ grep -ac '^HOOK_LIB_DIR=' template/.forge/hooks/git/pre-push
1
```

A âncora do cenário `[7]` é `^HOOK_LIB_DIR=`, ancorada em início de linha, e ela é **única** — 1 das 5 ocorrências do identificador. A revisão 1 dizia só "o índice de `HOOK_LIB_DIR=`" e deixava aberto contra qual das cinco comparar; o gate compara contra a única que é atribuição no topo do arquivo, e a asserção inclui provar que ela ocorre exatamente uma vez, para que um refactor que duplique a atribuição reprove em vez de comparar contra a ocorrência errada.

**Mecânica obrigatória, e é onde este programa já se enganou quatro vezes.** O controle vem da **árvore de trabalho** (`cp "$ALVO" "$ORIG"`), nunca do HEAD, porque as mutações rodam **depois** da implementação e um controle vindo do HEAD apagaria trabalho não commitado com o `cmp` confirmando alegremente. Depois de restaurar, `cmp -s` prova a restauração byte a byte, e a asserção derrubada é **reexecutada** e tem de voltar a passar; `feedback-mutacao-fantasma-restore` registra o `restore()` quebrado que deixou a mutação eterna sem ninguém ver.

**A revisão 1 prescrevia `perl -0pi -e` com aspas simples e `$` escapado, e a revisão 2 retira essa prescrição, porque eu a rodei e ela saiu no-op nos padrões desta onda.** Os padrões contêm `${_pp_ls:-}`, e o `-}` dentro de um `\Q…\E` fez o perl abortar com `syntax error at -e line 1, near "-}"`; sem o `cmp` de controle a mutação teria sido registrada como aplicada. A propriedade que precisa valer é: **a mutação muda bytes (`cmp` acusa), mantém o arquivo sintaticamente válido (`bash -n` limpo) e muda o comportamento observado (o conjunto de marcas muda)**; as três juntas, nunca só a primeira. Qual primitivo entrega isso é escolha do implementador, que executa — invariante 19. A minha bancada usou `python3` com `assert s.count(padrão) == 1` antes de substituir, que é como o no-op deixa de ser possível em silêncio.

### 2.7 PBT — onde há espaço de entrada

O espaço de entrada é o **payload de refs do stdin**, e ele é gerado: `n` linhas, cada uma sorteada entre deleção (`local_sha` zero), publicação de ref nova (`remote_sha` zero), publicação sobre ref existente, deleção de tag, e linha malformada.

Ferramenta: `template/.forge/scripts/lib/pbt.mjs`, harness zero-dep já entregue e coberto por `w121`, com `forAll`, `gen`, shrinking e seed reprodutível.

Propriedades, e as três são falsas hoje ou vazias hoje:

- **P1 — monotonicidade do escopo:** para todo payload, se **alguma** linha tem `local_sha` diferente de zero **ou** alguma linha é não classificável, então as marcas caras existem. Hoje ela é **verdadeira por vacuidade**, porque as marcas existem sempre; ela vira asserção real depois de D1 e é o que impede um conserto que pule demais.
- **P2 — o complemento:** para todo payload com pelo menos uma linha e todas as linhas classificadas como deleção bem-formada, nenhuma marca cara existe. Hoje é **falsa em 100% das entradas** — medido em `[A]` e `[B]`.
- **P3 — o desfecho é sempre nomeado:** para todo payload, a saída contém exatamente uma das três linhas de classificação (deleção pura / entrada vazia / há conteúdo), e nunca duas. É a propriedade que impede o terceiro estado de sumir num refactor.

Três exemplos escolhidos a dedo não cobrem esse espaço: as combinações que interessam são as **mistas**, e elas são exponenciais no número de linhas. O contador de execuções do `forAll` é publicado com a seed, porque um PBT que rodou zero casos aprova por não ter olhado.

### 2.8 Contador de controle, denominador fixo

O gate publica, e reprova em zero:

```
OK prepush-escopo-e-tempo/universo — 15 cenário(s) executado(s) de 15 declarado(s)
```

`DECLARADOS=15` é literal no fonte, e isso **não** colide com a invariante 14: o universo deste gate é a lista de cenários que o próprio arquivo declara, fechada e conhecida em tempo de escrita, e a divergência é justamente o achado. É a única exceção legítima que o plano-mestre admite.

O que **não** pode ser literal: qualquer número derivado da árvore. O cenário `[7]` compara **índices de linha entre si**, nunca contra um número escrito; o `[2]` imprime a contagem que ele mesmo mediu; o PBT publica `runs` e `seed`.

### 2.9 Níveis de teste

| Nível | Entra? | Onde |
|---|---|---|
| Unitário | **não** | não há função nova isolável: o parser de refs vive dentro do hook e testá-lo fora do hook seria testar a cópia, não o canal. É a lacuna que a rule `gate-delivery-channel` nomeia. |
| Propriedade (PBT) | **sim** | §2.7, sobre o payload gerado |
| Contrato | **sim, restrito** | o formato de linha do stdin do `pre-push` é contrato do **git**, não do harness: a onda não o altera, e o cenário `[6]` é a asserção de que uma forma fora do contrato é tratada como inconclusiva. Nenhuma chave de `forge.schema.json` é acrescentada (ver D8, §3.4), então não há contrato publicado novo a versionar. |
| Integração | **sim** | cenários `[1]`–`[7]`, hook completo com `.forge/` real e sondas |
| E2E | **sim** | pelo menos um cenário faz `git push` de verdade contra um remoto `--bare`, com `core.hooksPath` absoluto — é o padrão que `w190` já estabeleceu (`w190:104-105`), e sem ele a prova mede o script e não o canal |

### 2.10 Retrocompatibilidade

**O que já está instalado, remedido na revisão 2.** A revisão 1 afirmava que o `pre-push` do `azim-crm` era byte-idêntico ao template, e ele mede 189 linhas contra as 500 do template. O único byte-idêntico é o `lionclaw`, que a revisão 1 nem listava:

```
$ for r in azim-crm Axis.PadSimulator axis-go-cloud lionclaw axis-fare-validator; do
    p=~/Documents/projects/$r/.forge/hooks/git/pre-push
    cmp -s "$p" template/.forge/hooks/git/pre-push && c=IDENTICO || c=DIVERGE
    printf '%-22s pre-push=%sL  %s\n' "$r" "$(wc -l < "$p" | tr -d ' ')" "$c"; done
azim-crm               pre-push=189L  DIVERGE
Axis.PadSimulator      pre-push=327L  DIVERGE
axis-go-cloud          pre-push=500L  DIVERGE
lionclaw               pre-push=500L  IDENTICO
axis-fare-validator    pre-push=688L  DIVERGE
$ wc -l < template/.forge/hooks/git/pre-push
     500
```

**Quatro dos cinco `pre-push` instalados divergem do template**, cada um por um motivo diferente, e um deles com 189 linhas — menos de 40% do arquivo atual, ou seja, várias gerações atrás.

**O que quebra, e é o achado mais importante desta seção.** `hooks` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS`, então o `forge update` que trouxer esta onda **sobrescreve o `pre-push` inteiro dos quatro**. Consequências, uma a uma:

- `azim-crm`: o `pre-push` instalado tem 189 linhas e diverge; a sobrescrita salta várias gerações de uma vez e o curto-circuito chega junto com tudo o mais. **Não é caminho feliz**, e o mesmo repositório perde a customização de 271 linhas do `pre-commit` (§4.5).
- `lionclaw`: `pre-push` byte-idêntico ao template — ganha o curto-circuito, nada perde. É o único caminho feliz medido.
- `axis-fare-validator`: **perde o curto-circuito próprio e o carimbo de manifesto**, e recebe o do template no lugar. O curto-circuito é substituído por um equivalente (a semântica de D1 é a mesma que a linha 64 dele implementa); o carimbo de manifesto é maquinaria dele e **some**. Isso não é dano desta onda, é o dano da issue #101/#125 que a Onda L1 trata, mas esta onda é o gatilho que o dispara, e o ack precisa avisar antes do update, não depois.
- `axis-go-cloud`: `core.hooksPath` aponta para `.githooks`, custom, e os hooks do Forge **não executam** ali (`ls ~/Documents/projects/axis-go-cloud/.githooks/` mostra maquinaria própria; `grep 'forge\|check-secrets' .githooks/pre-commit` não devolve nada). O arquivo é sobrescrito e o comportamento não muda, porque ninguém o invoca.
- `Axis.PadSimulator`: salta duas gerações de uma vez. O curto-circuito chega junto com tudo o que a 0.12.0, 0.13.0 e 0.14.0 mudaram no hook, e o risco não é desta onda.

**O que a onda garante sobre compatibilidade.** Nenhuma string existente do `pre-push` muda: o curto-circuito **acrescenta** uma linha e um `exit 0`; as linhas `pre-push: typecheck OK`, `pre-push: test OK`, `pre-push OK` e todas as de bloqueio continuam idênticas. Um consumidor que faça `grep` da saída do hook em automação própria não é afetado no caminho que já exercitava. A varredura que sustenta essa afirmação está na §7.

**Quem não quebra e por quê.** Um repositório sem `.forge/FORGE.md` sai em `pre-push:147` com "pre-push OK (sem harness)" antes de chegar em typecheck — mas **depois** do curto-circuito, que fica no topo. Isso é melhoria, não regressão: hoje esse repositório já não paga a suíte; amanhã ele também dirá em voz alta por que não pagou.

---

## 3. ITEM 2 — #135: custo acumulado sem instrumentação, e a inconsistência de duas políticas de tempo

Este é o item mais sutil da onda, e a frase decisiva está na própria issue: **não há deadlock**. Cinco pushes morreram "no `harness-tests`, sem nenhum FAIL", e a hipótese de travamento estava errada — era custo acumulado somado a um hook mudo. É a invariante 2 do plano-mestre aplicada a **tempo** em vez de a veredito: "terminou dentro do orçamento", "excedeu o orçamento" e "não há orçamento declarado" são três estados, e hoje o `pre-push` tem um só.

### 3.1 A inconsistência de política, reproduzida com contrafactual

O grep que a issue prescreve, executado:

```
$ grep -aA6 "^run_check()" template/.forge/hooks/git/pre-push | grep -aE "alarm|timeout|perl" ; echo "rc=$?"
rc=1

$ grep -an 'FORGE_GATE_TIMEOUT_S\|alarm' template/.forge/scripts/lib/forge-runtime.sh
20:FORGE_GATE_TIMEOUT_S="${FORGE_GATE_TIMEOUT_S:-300}"
49:  perl -e "alarm $FORGE_GATE_TIMEOUT_S; exec @ARGV" -- bash -c "cd '$root' && $cmd" >"$log" 2>&1
```

O grep vazio confirma a metade negativa; a metade positiva precisa de contrafactual, e ele foi **remedido em 2026-09-08 com comando executável**, porque a revisão 1 colou marcadores (`<sha>`, `<zero>`) e um decorrido de 9 s que não decorre de um único `sleep 5`. Bancada: repositório git em `$TMPDIR` com o `.forge/scripts/` do template, `FORGE.md` declarando `typecheck: sleep 5`, `local_sha` real do HEAD:

```
$ printf 'runtime:\n  typecheck: sleep 5\n  test:\n' > "$R/.forge/FORGE.md"
$ SHA=$(git -C "$R" rev-parse HEAD); t0=$(date +%s)
$ printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$SHA" \
    | FORGE_GATE_TIMEOUT_S=2 bash template/.forge/hooks/git/pre-push origin file://"$R" ; rc=$?
$ t1=$(date +%s); echo "rc=$rc, decorrido=$((t1-t0))s"
run_check com FORGE_GATE_TIMEOUT_S=2 e typecheck='sleep 5': rc=0, decorrido=6s
pre-push: typecheck OK
```

Seis segundos, não nove: os 5 s do `sleep` mais cerca de 1 s do resto do hook. O `typecheck` **completou** sob um teto de 2 s declarado no ambiente, e o hook o reportou como `OK`.

Do outro lado, o mesmo trabalho pelo primitivo que tem teto:

```
$ FORGE_GATE_TIMEOUT_S=2 bash -c '. template/.forge/scripts/lib/forge-runtime.sh
    log=$(mktemp); for cmd in "sleep 5" "exit 1" "exit 142" "echo LINHA-ANTES; sleep 5; echo LINHA-DEPOIS"; do
      t0=$(date +%s); forge_run_gate sonda "$cmd" "$log" "$PWD" >/dev/null 2>&1; rc=$?; t1=$(date +%s)
      printf "cmd=%-46s cap=%ss -> rc=%-4s decorrido=%ss log=%sB\n" "$cmd" "$FORGE_GATE_TIMEOUT_S" "$rc" "$((t1-t0))" "$(wc -c < "$log" | tr -d " ")"
    done; echo "--- log do último ---"; cat "$log"'
cmd='sleep 5'                                      cap=2s -> rc=142  decorrido=2s log=0B
cmd='exit 1'                                       cap=2s -> rc=1    decorrido=0s log=0B
cmd='exit 142'                                     cap=2s -> rc=142  decorrido=0s log=0B
cmd='echo LINHA-ANTES; sleep 5; echo LINHA-DEPOIS' cap=2s -> rc=142  decorrido=2s log=12B
--- log do último ---
LINHA-ANTES
```

Uma execução só entrega os três achados de uma vez, e é a que a revisão 2 cola no lugar das três medições separadas da revisão 1.

**A mesma variável, o mesmo trabalho, dois comportamentos:** `forge_run_gate` mata em 2 s com rc 142; `run_check` deixa correr os 5 s e sai 0. Duas políticas de tempo para a mesma classe de trabalho, e a que roda no caminho mais caro é a que não tem.

Três medições adicionais que a issue não faz e que mudam o desenho:

**(a) o rc 142 não discrimina.** Nas linhas 1 e 3 da saída acima, `sleep 5` morto pelo teto e `exit 142` voluntário devolvem o **mesmo** rc 142; o que os separa é o decorrido (2 s contra 0 s), nunca o rc. Uma implementação que infira "estourou" a partir do rc está errada, e o cenário `[11]` do gate 1 é a guarda.

**(b) o teto não alcança os netos.** Medido:

```
$ perl -e 'alarm 1; exec @ARGV' -- bash -c 'sleep 4 & wait' ; echo "rc do perl=$?"
rc do perl=142
$ pgrep -fl 'sleep 4' >/dev/null && echo "NETO SOBREVIVEU ao alarm (o kill não alcança os filhos)"
NETO SOBREVIVEU ao alarm (o kill não alcança os filhos)
```

O `alarm` mata o processo exec'ado, não o grupo. Uma suíte que põe trabalho em background deixa órfãos consumindo a máquina depois de o teto ter sido "respeitado". É exatamente o que a própria #135 relata sobre o cronômetro que o consumidor escreveu (`o kill -9 do subshell dele não alcança os filhos`), e significa que **o teto é um limite sobre quanto o hook espera, nunca uma garantia de limpeza de processos**. A especificação não pode prometer o que o primitivo não entrega, e a mensagem de estouro não deve sugerir que a máquina foi liberada.

**(c) o log de um check morto preserva o que já tinha sido impresso.** É a linha 4 da saída acima: `log=12B`, e o conteúdo é `LINHA-ANTES` — o que foi impresso antes da morte sobrevive, o que viria depois não existe.

Isso é a chave do diagnóstico, e é o que liga esta metade à próxima: **o conteúdo do log no instante da morte é a única testemunha do que estava rodando**, e o valor dele depende inteiramente de o runner ter anunciado o nome antes.

### 3.2 A suíte muda, reproduzida — e o diagnóstico que ela torna impossível

`template/.forge/scripts/tests/run-all.sh:36-44` imprime `✓ <nome>` **depois** de o teste retornar, e `tests/run-all.sh:76,80` fazem o mesmo com o corpus deste repositório. As duas citações foram conferidas:

```
$ grep -an 'run_one()' -A 5 template/.forge/scripts/tests/run-all.sh
36:run_one() {  # run_one <arquivo> <comando...>
37-  local nome="$1"; shift
38-  if "$@" >/dev/null 2>&1; then
39-    pass=$((pass + 1)); printf '  ✓ %s\n' "$nome"
40-  else
41-    fail=$((fail + 1)); failed="$failed $nome"; printf '  ✗ %s\n' "$nome"
$ grep -an '✓\|✗' tests/run-all.sh | head -2
76:    printf '  \033[32m✓\033[0m %s\n' "$name"
80:    printf '  \033[31m✗\033[0m %s\n' "$name"
```

A consequência foi **remedida em 2026-09-08**, com fixture de quatro testes — `a-rapido`, `b-rapido`, `c-pendura` (`sleep 30`) e `d-rapido` — morta por fora aos 3 s:

```
$ perl -e 'alarm 3; exec @ARGV' -- bash -c "bash '$B/run-all.sh' --path '$B/tests'" > "$B/log.hoje" 2>&1; echo "rc=$?"
rc=142
$ tail -6 "$B/log.hoje"
  ✓ a-rapido.test.sh
  ✓ b-rapido.test.sh
```

**O log nomeia `b-rapido`, que terminou, e não menciona `c-pendura`, que estava rodando.** O operador recebe um log que aponta para o lugar errado e nenhum sinal de que algo pendurou. Foi essa assinatura que sustentou a hipótese de deadlock por cinco tentativas.

Contrafactual, medido no mesmo instante, com uma única linha (`printf '  > %s\n' "$nome"`) acrescentada logo depois de `local nome="$1"; shift`, com `cmp` acusando a diferença e `bash -n` limpo:

```
$ perl -e 'alarm 3; exec @ARGV' -- bash -c "bash '$B/run-all.antes.sh' --path '$B/tests'" > "$B/log.antes" 2>&1; echo "rc=$?"
rc=142
$ tail -8 "$B/log.antes"
  > a-rapido.test.sh
  ✓ a-rapido.test.sh
  > b-rapido.test.sh
  ✓ b-rapido.test.sh
  > c-pendura.test.sh
```

A última linha passa a nomear exatamente o teste em curso. A cadeia inteira do diagnóstico é: anúncio-antes torna o log testemunha; o teto mata e o log sobrevive (medição (c)); a mensagem de estouro nomeia o check e o teto. Nenhuma das três peças resolve sozinha, e é por isso que a #135 pede as três.

### 3.3 Um efeito colateral que a issue não vê, e que este repositório sofre

`run-gates.sh:101-105` e `spec-verify.sh:53-57` chamam `forge_run_gate` e reportam o resultado como `passed` ou `failed`. Não há terceira palavra:

```
$ grep -arn '142\|TIMEOUT\|Alarm' template/.forge/scripts/run-gates.sh template/.forge/scripts/spec-verify.sh ; echo "rc=$?"
rc=1
$ grep -arc 'forge_run_gate' template/.forge/scripts/run-gates.sh template/.forge/scripts/spec-verify.sh
template/.forge/scripts/run-gates.sh:1
template/.forge/scripts/spec-verify.sh:2
$ grep -an 'forge_run_gate' template/.forge/scripts/run-gates.sh template/.forge/scripts/spec-verify.sh
template/.forge/scripts/run-gates.sh:101:  if forge_run_gate "$gate" "bash '$script' '$ID'" "$log" "$ROOT"; then
template/.forge/scripts/spec-verify.sh:20:# forge-runtime.sh para forge_get_runtime/forge_run_gate/forge_runtime_gates.
template/.forge/scripts/spec-verify.sh:54:  if forge_run_gate "$name" "$cmd" "$log" "$ROOT"; then
```

O segundo comando é o controle positivo do primeiro: os dois arquivos são legíveis pela varredura e ambos chamam `forge_run_gate`, de modo que o vazio do primeiro é ausência real do vocabulário de estouro, não ausência de leitura. **A revisão 2 colou `run-gates.sh:2`; o número é 1.** O terceiro comando existe porque a contagem sozinha não distingue chamada de menção em comentário — no `spec-verify.sh` uma das duas ocorrências é comentário (`:20`) e só `:54` é chamada, e no `run-gates.sh` a única ocorrência (`:101`) é chamada. O controle continua cumprindo o papel, e agora ele mostra o que conta.

Ou seja: **onde o teto existe, o estouro é registrado como reprovação**. No `spec-verify.sh` isso vai para dentro do `run-manifest/v1`, com `status: failed`, e o manifesto — que existe justamente para provar sob que condições a execução ocorreu — passa a afirmar um veredito que nunca foi produzido. É a mesma família de LDG-0157 (rc ≠ 0 do executor lido como violação do verificado) por outra porta.

Esta onda **não** reescreve o vocabulário de `run-gates.sh` nem de `spec-verify.sh`: isso é mudança de contrato de manifesto, com adotante instalado, e pertence a um item próprio. O que ela faz é não repetir o defeito no caminho novo — o `run_check` do `pre-push` distingue as três palavras desde o primeiro dia — e registrar o achado (§6, item de ledger novo).

### 3.4 Decisões de desenho — FECHADAS

**D6. O mecanismo de tempo passa a ser um só; o número não.**

O `run_check` do `pre-push` ganha teto pelo mesmo primitivo que `forge_run_gate` usa, e o orçamento continua sendo declarado pelo operador na mesma variável `FORGE_GATE_TIMEOUT_S`. A #135 pede "que a política de tempo seja UMA" e é isso que se entrega: um mecanismo, uma variável na interface, um vocabulário. Dentro do hook os quatro checks caros passam **todos** por `run_check` — nenhum deles chama `forge_run_gate`, medido:

```
$ grep -an 'forge_run_gate' template/.forge/hooks/git/pre-push ; echo "rc=$?"
rc=1
$ grep -ac 'run_check' template/.forge/hooks/git/pre-push
5
$ grep -arln 'forge_run_gate' template/
template/.forge/scripts/lib/forge-runtime.sh
template/.forge/scripts/run-gates.sh
template/.forge/scripts/spec-verify.sh
```

A segunda linha é o controle positivo da primeira: o arquivo é legível pela varredura e tem cinco ocorrências de `run_check`, então o vazio de `forge_run_gate` é ausência real.

**D7. O orçamento é lido UMA vez, antes de qualquer `source`, e a política default é "sem teto", declarada em voz alta.**

Esta decisão foi **reescrita na revisão 2**, porque a redação da revisão 1 — "`FORGE_GATE_TIMEOUT_S` ausente ou `0` significa sem teto" — apoiava-se numa premissa que **não vale dentro do `pre-push`**, e a implementação fiel à letra dela produziria exatamente o desfecho que ela proíbe. O revisor achou; eu remedi e confirmo.

**A medição.** Uma cópia do hook, com uma linha de depuração dentro de `run_check` imprimindo o estado da variável, contra um repositório de bancada onde só a declaração de `runtime.gates` no `FORGE.md` muda entre as duas execuções:

```
$ python3 -c "...insere 'echo DBG label=\$label FORGE_GATE_TIMEOUT_S=[\${FORGE_GATE_TIMEOUT_S:-<UNSET>}]' depois de 'local label=\"\$1\" cmd=\"\$2\" log'..."
$ printf 'runtime:\n  typecheck: true\n  test: true\n  gates: check-marca\n' > "$R/.forge/FORGE.md"
$ printf 'refs/heads/main %s refs/heads/main 0000...0\n' "$(git -C "$R" rev-parse HEAD)" | bash "$HK" origin file://"$R" 2>&1 | grep -a DBG
DBG label=typecheck FORGE_GATE_TIMEOUT_S=[<UNSET>]
DBG label=test FORGE_GATE_TIMEOUT_S=[<UNSET>]
DBG label=check-marca FORGE_GATE_TIMEOUT_S=[300]
DBG label=harness-tests FORGE_GATE_TIMEOUT_S=[300]

$ printf 'runtime:\n  typecheck: true\n  test: true\n' > "$R/.forge/FORGE.md"    # contraprova: MESMO hook, só o FORGE.md muda
$ ...mesma invocação... | grep -a DBG
DBG label=typecheck FORGE_GATE_TIMEOUT_S=[<UNSET>]
DBG label=test FORGE_GATE_TIMEOUT_S=[<UNSET>]
DBG label=harness-tests FORGE_GATE_TIMEOUT_S=[<UNSET>]
```

**A mesma variável tem dois valores dentro da mesma execução do mesmo hook.** A causa é estrutural e está nas linhas do arquivo: `run_check` de `typecheck` e `test` são invocados nas linhas 324-325, e os de `runtime.gates` e `harness-tests` nas linhas 450 e 478, enquanto `. "$RUNTIME_LIB"` está na linha 401, **entre** os dois pares, dentro do `if [ -n "$(gates_key_present)" ]` da linha 370 — e `forge-runtime.sh:20` aplica `FORGE_GATE_TIMEOUT_S="${FORGE_GATE_TIMEOUT_S:-300}"` ao ser sourceada. A contraprova isola a causa: mesmo hook, mesmo check, só muda a declaração de `gates:`.

**Por que isso é um defeito e não uma curiosidade.** Três dos cinco consumidores declaram `runtime.gates` — medido em §4.2 — de modo que ler a variável crua dentro de `run_check` entregaria (i) duas políticas de tempo na mesma execução, no item que existe para ter uma só; (ii) teto de 300 s no `harness-tests` por default, que é o "push lento vira push impossível" que esta mesma decisão proíbe; e (iii) um cenário `[10]` que passa ou falha conforme o check inspecionado e conforme o fixture declarar `gates:` — falso-verde ou vermelho fabricado, à escolha do acaso.

**A decisão, então, em duas metades.**

*Metade 1 — de onde o orçamento é lido.* O `run_check` **não** lê `FORGE_GATE_TIMEOUT_S` diretamente. O hook toma um snapshot do valor que o **operador** declarou, uma única vez, antes de qualquer `source`, e `run_check` lê apenas o snapshot. Medido, com o snapshot posto imediatamente antes de `INPUT="$(cat)"`:

```
$ # com 'gates:' declarado, ambiente sem a variável
DBG label=typecheck     CAP=[<SEM TETO>] var=[<UNSET>]
DBG label=test          CAP=[<SEM TETO>] var=[<UNSET>]
DBG label=check-marca   CAP=[<SEM TETO>] var=[300]
DBG label=harness-tests CAP=[<SEM TETO>] var=[300]

$ # com 'gates:' declarado, FORGE_GATE_TIMEOUT_S=7 no ambiente
DBG label=typecheck     CAP=[7] var=[7]
DBG label=test          CAP=[7] var=[7]
DBG label=check-marca   CAP=[7] var=[7]
DBG label=harness-tests CAP=[7] var=[7]

$ # sem 'gates:', ambiente sem a variável
DBG label=typecheck     CAP=[<SEM TETO>] var=[<UNSET>]
DBG label=test          CAP=[<SEM TETO>] var=[<UNSET>]
DBG label=harness-tests CAP=[<SEM TETO>] var=[<UNSET>]
```

O `CAP` é uniforme nos quatro checks e nos três estados; o `var` cru continua contaminado, e é por isso que ele não pode ser a fonte. O nome do snapshot é escolha do implementador; a **propriedade** que a implementação tem de satisfazer é: *o valor que decide o teto de um check é o mesmo para todos os checks da mesma execução, e é o que o operador declarou, independentemente de o `FORGE.md` declarar `runtime.gates`*. O cenário `[15]` do gate 1 é a asserção disso, e ele é vermelho hoje por ausência real do snapshot.

*Metade 2 — qual é o default.* Aplicar 300 s ao `run_check` quebraria push legítimo em produção: a própria #135 mede uma suíte de consumidor que passa de 600 s e quatro testes que somam quase 8 minutos, e a suíte deste repositório leva dezenas de minutos. Escolher outro número seria pior, porque **eu não medi nenhuma suíte de consumidor nesta onda** e um default sem medição é um número inventado com aparência de engenharia. Então: snapshot ausente ou `0` significa **sem teto**, e o hook **diz isso**, nomeando o check — "harness-tests: sem teto de tempo declarado". Declarado, o teto vale e o estouro é nomeado. Três estados, e o terceiro é o honesto.

**O que esta decisão NÃO faz, e precisa estar escrito:** ela não muda o default de `forge_run_gate`, que continua 300 s para `run-gates.sh` e `spec-verify.sh`. A política é uma **dentro do hook**; entre o hook e os runners de gate ela continua sendo duas, e o motivo é contrato com adotante instalado, não descuido — mudar o default de `forge_run_gate` altera o comportamento de dois scripts distribuídos e entra no item de ledger da §6.

*Alternativa descartada — default numérico grande (por exemplo 3600 s).* Ela é atraente e cai por dois motivos medidos. Primeiro, ninguém sabe se 3600 s cobre a suíte do `Axis.PadSimulator` ou do `axis-go-cloud`, porque não medi nenhuma das duas. Segundo, o único ganho de um teto grande sobre nenhum teto é matar um travamento genuíno — e a #135 estabelece que **não havia travamento**: o problema era diagnóstico, e o diagnóstico é resolvido por D9 sem depender de número nenhum.

*Alternativa descartada — chave nova em `forge.schema.json` (`prepush.timeout_s`).* O schema já tem **quatro** `timeout_s`, e o idioma existe. A revisão 1 dizia três e nomeava três; a remedição enumerou os donos pelo próprio JSON, em vez de contar linhas:

```
$ grep -an 'timeout_s' template/.forge/schemas/forge.schema.json
220:                    "timeout_s": {
637:            "timeout_s": {
653:            "timeout_s": {
666:            "timeout_s": {
$ python3 -c "...caminha o schema e imprime o dono de cada propriedade 'timeout_s'..."
  -> runtime.pentest.strix
  -> heavy_mutex
  -> push_ahead
  -> worktree_reconcile
```

O quarto é `runtime.pentest.strix.timeout_s`, da onda do perfil strix, e é da mesma natureza — teto de execução de trabalho caro. Cai por dois motivos: cria uma **segunda** política de tempo no exato item que pede uma só, e `w192-declared-switch-has-reader-gate` mais `w199-schema-reader-parity-gate` obrigam leitor no mesmo change para toda chave declarada — custo de contrato publicado por zero comportamento que a variável de ambiente já não dê. Fica registrado como candidato para depois de as quatro suítes serem cronometradas.

**D8. O estouro é discriminado por sinal independente do rc.**

Medição (a) da §3.1: rc 142 é ambíguo, e a saída colada lá mostra `sleep 5` morto pelo teto e `exit 142` voluntário devolvendo o mesmo número. A propriedade que precisa valer é *o hook classifica como estouro exatamente quando o teto foi atingido, e nunca quando o check terminou por conta própria com qualquer rc*. O contrafactual que a mutação tem de produzir é o cenário `[11]`: um check que sai 142 em menos tempo que o teto **não** pode aparecer como estouro. O primitivo é escolha do implementador — tempo decorrido comparado ao teto, sentinela escrita pelo invólucro, ou outro — e ele prova que discrimina, com o cenário `[9]` como controle negativo. **Não prescrevo comando aqui porque não executei um que discrimine os três casos.**

**D9. Os dois runners anunciam o nome antes de executar, e nenhuma linha existente muda.**

Uma linha nova antes do `if` que executa. As linhas `✓`, `✗`, `harness-tests: N arquivo(s) examinado(s) — PASS=… FAIL=…` e `OK harness-tests` ficam idênticas, palavra por palavra — a varredura que sustenta isso está na §7. O `tests/run-all.sh` deste repositório recebe o mesmo tratamento porque sofre do mesmo defeito e é onde a suíte de 40 minutos roda; ele não é distribuído (`package.json:files` não o inclui), então não tem custo de contrato.

*Alternativa descartada — um teto por teste dentro do `run-all.sh`, como pede o item 3 da issue.* Ela precisa de um número por teste, e o mesmo argumento de D7 se aplica com mais força: a #135 mede um teste legítimo de 200 s. Sem cronometrar as quatro suítes, qualquer teto por teste é chute. Fica para o item de ledger da §6, junto com a medição que o desbloqueia.

**D10. O `run_check` continua capturando a saída em arquivo, e não passa a transmitir ao vivo.**

*Alternativa descartada — `tee` para stdout.* Os comentários de `pre-push:4` e `pre-push:211-212`, mais a disciplina §17.6 de overflow de contexto, existem por um motivo: a saída de uma suíte inteira no terminal do push é ruído que ninguém lê, e num agente é contexto queimado. O que o operador precisa não é da saída inteira: é de saber **em que estágio** o hook está. Isso é resolvido por uma linha de anúncio por check no `pre-push` (`> harness-tests (sem teto declarado)`) mais o anúncio-antes do runner dentro do log, que é onde o `tail` vai buscá-lo quando algo der errado.

### 3.5 Mutação, PBT, contador e níveis

**Mutações do item 2**, todas `A MEDIR` porque o alvo não existe hoje — e a regra vale integralmente: se a mutação sair no-op, quem se corrige é o **cenário**, nunca a linha.

| Mutação | O gate tem de dizer |
|---|---|
| M6 — remover o teto de `run_check` (o estado de hoje) | `FAIL [8]` apenas; `[9]` e `[11]` continuam verdes |
| M7 — inferir estouro pelo rc 142 (desfazer D8) | `FAIL [11]` apenas |
| M8 — silenciar o estado "sem teto declarado" | `FAIL [10]` **e** `FAIL [15]` — `[15]` compara a política reportada entre `typecheck` e `harness-tests`, e uma política silenciada não é comparável; a revisão 2 escrevia "`[10]` apenas", que era leitura e não medição |
| M8b — trocar o snapshot pela leitura crua de `FORGE_GATE_TIMEOUT_S` dentro de `run_check` (a implementação ingênua) | `FAIL [15]` apenas; `[8]`, `[9]` e `[11]` continuam verdes, porque com o teto declarado no ambiente as duas leituras coincidem — é precisamente por isso que `[15]` precisa de fixture **sem** a variável e **com** `gates:` |
| M9 — mover o anúncio do `run_one` para depois da execução (o estado de hoje) | `FAIL [12]` apenas; `[13]` continua verde |
| M10 — trocar `✓` por outro token no `run_one` | `FAIL [13]` apenas — é a guarda de retrocompatibilidade mordendo |

**PBT:** não se aplica a este item, e a justificativa é medida, não conveniente. O espaço de entrada de `run_check` é um par (comando, teto), e o que interessa não é a variedade do comando: são três classes de desfecho (termina antes do teto com rc 0; termina antes do teto com rc ≠ 0, inclusive 142; não termina). Gerar comandos aleatórios exercitaria a mesma classe milhares de vezes sem aumentar cobertura, e o custo é tempo de relógio real — um PBT com `runs=100` sobre um teto de 2 s custa até 200 s de suíte. Os três cenários enumerados `[8]`, `[9]`, `[11]` cobrem a partição inteira, e o argumento de que ela é a partição inteira está em §3.1(a).

**Contador:** os sete cenários deste item (`[8]`–`[13]` e `[15]`) contam para o `DECLARADOS=15` do gate 1; não há contador separado.

**Níveis:** integração nos seis cenários (hook completo com `FORGE.md` real e checks-sonda); E2E no cenário de `git push` real; contrato **não se aplica**, porque D7 e D8 não acrescentam chave de schema nem alteram formato de manifesto — a decisão de não alterar `run-gates.sh`/`spec-verify.sh` (§3.3) é justamente o que mantém o contrato do `run-manifest/v1` intocado nesta onda.

---

## 4. ITEM 3 — #141: o hook mora numa árvore e procura o que executa em outra

### 4.1 O defeito, reproduzido — com a mensagem literal da issue

O trecho que a issue cita existe no template, palavra por palavra:

```
$ sed -n '74,78p' template/.forge/hooks/git/pre-commit    # com -a não se aplica: sed lê o arquivo inteiro
SECRETS="$ROOT/.forge/scripts/check-secrets.sh"
if [ ! -f "$SECRETS" ] && [ -d "$ROOT/.forge/scripts" ]; then
  echo "pre-commit BLOQUEADO: .forge/scripts/ existe mas check-secrets.sh não — a delegação aponta para um alvo ausente"
  fail=1
fi
```

Bancada: tronco com `.forge/hooks/git/pre-commit` do template e um `.forge/scripts/` que **não** tem `check-secrets.sh` (o estado de uma branch anterior à delegação), `core.hooksPath` absoluto para o tronco, e um worktree em `.forge/worktrees/feat-x`.

```
$ cd "$M/.forge/worktrees/feat-x" && git add novo.txt && git commit -m "feat: algo sem relacao"
pre-commit BLOQUEADO: .forge/scripts/ existe mas check-secrets.sh não — a delegação aponta para um alvo ausente
rc=1
```

E a assimetria, que é o coração da issue — simulei o overlay do `forge upgrade` no tronco criando o `check-secrets.sh` **não versionado**:

```
$ git -C "$M" status --porcelain .forge/scripts/check-secrets.sh
?? .forge/scripts/check-secrets.sh
$ cd "$M" && git commit -m "chore: tronco commita"
[main 14ee2df] chore: tronco commita          <-- o tronco commita
$ cd "$M/.forge/worktrees/feat-x" && git commit -m "feat: worktree tenta de novo"
pre-commit BLOQUEADO: ...                     <-- o worktree continua parado
$ git -C "$M/.forge/worktrees/feat-x" log --oneline -1
a793952 base                                  <-- o commit não aconteceu
```

Reproduz inteiramente, no template, na mesma forma que o campo mediu.

**Um segundo bloqueio, encontrado no caminho e que a issue não menciona.** A primeira tentativa da bancada pôs o worktree fora de `.forge/worktrees/` e caiu num guard anterior:

```
pre-commit BLOQUEADO: worktree fora de .forge/worktrees/ (regra §20.4)
```

Ele é `pre-commit:9-17` e é intencional. Registro porque muda o roteiro de reprodução: quem tentar reproduzir a #141 com um worktree em lugar arbitrário vai encontrar a mensagem errada e concluir a coisa errada.

### 4.2 A exposição hoje, remedida na revisão 2 pelo predicado certo

**A tabela da revisão 1 estava errada, e o erro era de método.** Ela classificava como bloqueado todo worktree com `.forge/scripts/` e sem `check-secrets.sh`, sem conferir se o **hook instalado daquele repositório** contém a delegação. Um proxy não é a coisa; o revisor mostrou o furo no repositório que era a evidência principal, e a remedição confirma.

O predicado certo tem três conjunções, e a primeira é a que faltava: (i) o `core.hooksPath` do repositório aponta para os hooks do Forge **e** o `pre-commit` instalado ali contém a delegação a `check-secrets`; (ii) o worktree tem `.forge/scripts/`; (iii) o worktree não tem `check-secrets.sh`.

```
$ for r in azim-crm Axis.PadSimulator axis-go-cloud lionclaw axis-fare-validator; do
    hp=$(git -C "$r" config --get core.hooksPath); pc="$hp/pre-commit"
    if [ -n "$hp" ] && [ -f "$pc" ] && grep -aq 'check-secrets' "$pc"; then canal=SIM; else canal=NAO; fi
    n=0; sem=0; bloq=0
    while read -r w; do n=$((n+1))
      if [ -d "$w/.forge/scripts" ] && [ ! -f "$w/.forge/scripts/check-secrets.sh" ]; then
        sem=$((sem+1)); [ "$canal" = SIM ] && bloq=$((bloq+1)); fi
    done < <(git -C "$r" worktree list | tail -n +2 | awk '{print $1}')
    printf '%-22s wt=%-3s hook_delega=%-4s sem_alvo=%-3s BLOQUEADOS=%s\n' "$r" "$n" "$canal" "$sem" "$bloq"
  done
azim-crm               wt=28  hook_delega=NAO  sem_alvo=28  BLOQUEADOS=0
Axis.PadSimulator      wt=28  hook_delega=SIM  sem_alvo=21  BLOQUEADOS=21
axis-go-cloud          wt=86  hook_delega=NAO  sem_alvo=81  BLOQUEADOS=0
lionclaw               wt=1   hook_delega=SIM  sem_alvo=0   BLOQUEADOS=0
axis-fare-validator    wt=1   hook_delega=SIM  sem_alvo=0   BLOQUEADOS=0
```

**Vinte e um worktrees com o commit bloqueado neste instante, todos no `Axis.PadSimulator`** — não cinquenta em três repositórios. O `azim-crm`, que é o repositório da issue, tem **zero**, porque o `pre-commit` instalado dele não tem a delegação:

```
$ wc -l < ~/Documents/projects/azim-crm/.forge/hooks/git/pre-commit
     271
$ grep -ac 'check-secrets' ~/Documents/projects/azim-crm/.forge/hooks/git/pre-commit
0
$ cmp -s ~/Documents/projects/azim-crm/.forge/hooks/git/pre-commit template/.forge/hooks/git/pre-commit && echo IDENTICO || echo DIVERGE
DIVERGE
```

O ecossistema inteiro, remedido no mesmo dia:

```
$ cd ~/Documents/projects && for d in */; do r=${d%/}; n=$(git -C "$r" worktree list 2>/dev/null | tail -n +2 | wc -l | tr -d ' '); [ "$n" = 0 ] && continue
    hp=$(git -C "$r" config --get core.hooksPath || echo -); printf '%-24s %3s worktrees  hooksPath=%s\n' "$r" "$n" "$hp"; done
agent-smith                1 worktrees  hooksPath=
axis-fare-validator        1 worktrees  hooksPath=/Users/milton/Documents/projects/axis-fare-validator/.forge/hooks/git
axis-go-cloud             86 worktrees  hooksPath=/Users/milton/Documents/projects/axis-go-cloud/.githooks
Axis.PadSimulator         28 worktrees  hooksPath=/Users/milton/Documents/projects/Axis.PadSimulator/.forge/hooks/git
azim-crm                  28 worktrees  hooksPath=/Users/milton/Documents/projects/azim-crm/.forge/hooks/git
forge-harness              1 worktrees  hooksPath=
lionclaw                   1 worktrees  hooksPath=/Users/milton/Documents/projects/lionclaw/.forge/hooks/git
prospera                   1 worktrees  hooksPath=/Users/milton/Documents/projects/prospera/.git/hooks
travessias-archive-2026-05-13   1 worktrees  hooksPath=
travessias                 4 worktrees  hooksPath=.husky/_
TOTAL worktrees linkados: 152 | atrás de hooksPath absoluto para os hooks do Forge: 58
```

**152 worktrees linkados, 58 atrás de um `core.hooksPath` absoluto para os hooks do Forge** — não 157 e 61 da revisão 1. Não é um fluxo marginal: é o fluxo que o `FORGE.md` §3.3 recomenda.

**Os dois números do `axis-go-cloud` — 86 worktrees dele, 152 no ecossistema — são os de 2026-09-08 e já mudaram três vezes nesta rodada:** a revisão 1 mediu 88, a revisão 2 colou 83, o revisor mediu 86 e eu remedi 86 hoje. Isso é a demonstração da própria advertência do parágrafo final desta seção, e é por isso que **nenhuma das três contagens de worktree entra em asserção de gate**. Os dois números que carregam decisão — os **21** bloqueados do `Axis.PadSimulator` e os **58** atrás do `hooksPath` do Forge — reproduzem estáveis desde a revisão 2, e são esses que sustentam a §4.5 e o plano de ack.

**O que a correção do número muda, e o que ela não muda.** Não muda D11 nem D12: o defeito reproduz **no template**, medido em §4.1, com a mensagem literal da issue, e um defeito de produto não deixa de existir porque poucos o estão sofrendo hoje. Muda duas coisas: a urgência relativa de #141 contra os outros itens da onda, que cai; e, sobretudo, a §4.5, que a revisão 1 escrevia com base no número errado e que está reaberta abaixo. Todos os números desta seção são **fotografia de 2026-09-08** — worktrees nascem e morrem entre uma revisão e a seguinte, medido, e o gate asserta a propriedade, nunca a contagem.

### 4.3 Decisões de desenho — FECHADAS

**D11. `core.hooksPath` continua ABSOLUTO. A sugestão 1 da issue é recusada.**

Gravar `.forge/hooks/git` relativo é **o defeito da issue #41**, corrigido e guardado. `core.hooksPath` vive no `.git/config` **comum**; um valor relativo é resolvido por cada worktree contra a própria árvore, de modo que um hook novo, versionado e já mergeado, não bloqueia nada em worktree nenhum — e a única evidência disso é o commit proibido passando em silêncio. Isso está escrito em três lugares que a onda não pode contradizer sem os reabrir: a rule `conventions/machinery-propagation.md` ("Config local que aponta para maquinaria aponta para o tronco, em caminho absoluto"), o comentário de `bin/forge.mjs:213-217`, e o gate:

```
tests/w137-worktree-machinery-gate.sh:72
  *)  echo "FAIL [2]: core.hooksPath relativo ('$hp') — cada worktree resolve na PRÓPRIA árvore, que tem a cópia antiga dos hooks"; exit 1 ;;
```

A sugestão 1 quebraria `w137[2]` de frente. Ela também tem um efeito que o autor da issue não considerou e que é mais grave que o bloqueio: com hooksPath relativo, o worktree cuja branch **não tem** `.forge/hooks/git` não roda hook nenhum — o commit passa sem gate algum, em silêncio, que é estritamente pior que um commit bloqueado com mensagem.

A observação da issue continua correta e é o que a próxima decisão ataca: **quem separa hook de scripts é a instalação**. A saída é fazer o hook resolver o que ele delega, não mudar onde ele mora.

**D12. A delegação resolve primeiro no checkout que está commitando; se não achar, na árvore onde o hook mora; e só recusa quando não achar em nenhuma das duas — e o fallback vive DENTRO do ramo de recusa que já existe, nunca antes dele.**

Precedência: `$ROOT/.forge/scripts/<alvo>` vence sempre, porque um consumidor tem razão legítima para armar um detector próprio na própria árvore (é literalmente a issue #125). O fallback existe porque o hook em execução **veio** da outra árvore, e exigir dele um contrato que a branch corrente nunca declarou é cobrar de quem não tem como pagar. A recusa continua existindo, com a mensagem literal de hoje, quando nem uma nem outra tem o alvo.

**A pré-condição de engate, que a revisão 2 não declarava e sem a qual D12 revoga uma doutrina escrita nos próprios hooks.** Cada um dos doze sítios já tem uma guarda de instalação própria — `[ -d "$ROOT/.forge/scripts" ]` em `pre-commit:75`, `commit-msg:29`, `pre-push:72,112`, `post-merge:58` e `check-red-first.sh:88`; `[ -d "$ROOT/.forge/scripts/lib" ]` em `pre-push:233` e `post-merge:38`; `[ -d "$HOOK_LIB_DIR" ]` em `pre-push:40`; e o ramo "há `.sh` a varrer" em `pre-push:309`. **O fallback entra dentro dessa guarda, substituindo o `exit 1`, e nunca antes dela.** Escrito assim, o no-op de repositório sem harness é preservado por construção, e não por lembrança: `commit-msg:19-27` e `pre-push:33-37` dizem em letra que "o no-op só é legítimo quando o harness NÃO está instalado", e o cenário `[5]` do gate 2 declara essa propriedade como nascida verde. Medido em bancada sob `$TMPDIR`, com a árvore do hook separada do checkout, `bash -n` limpo, `cmp` acusando a mudança e restauração byte a byte no fim:

```
# árvore do hook: cópia de template/.forge; checkout: repositório git SEM .forge/ nenhum
$ printf 'refs/heads/main <sha> refs/heads/main <zero>' | bash "$HT/.forge/hooks/git/pre-push" origin "file://$PWD"
pre-push OK (sem harness)                       <-- BASELINE, rc=0
$ # mesmo comando, com D12 aplicado a AI_CHECK e ACKS DENTRO do ramo de recusa
pre-push OK (sem harness)                       <-- rc=0, no-op PRESERVADO

# controle positivo, no mesmo par de árvores: checkout COM .forge/scripts/ e SEM o alvo
$ # contra o hook BASELINE
pre-push BLOQUEADO: .forge/scripts/ existe mas check-ai-attribution.sh não — delegação em alvo ausente
$ # contra o hook com D12
pre-push: check-ai-attribution.sh resolvido na árvore do HOOK (/var/.../arvore-do-hook) — este checkout não o tem
pre-push: check-liaison-acks.sh resolvido na árvore do HOOK (/var/.../arvore-do-hook) — este checkout não o tem
OK liaison-acks — sem canal
```

As duas metades são obrigatórias juntas: a primeira sozinha ("o no-op continua no-op") é satisfeita por um fallback que nunca engaja, e a segunda sozinha não prova que ele não engaja onde não deve. **O custo desta pré-condição está registrado e não é zero:** um worktree cuja branch não tem `.forge/` nenhum segue sem gate algum, que é o desfecho que D11 chama de estritamente pior. É o preço de não fazer o hook de uma árvore executar contra um repositório que nunca declarou harness, e a alternativa — engajar o fallback sem guarda — é pior, porque generaliza a execução cruzada para repositórios de terceiros que só compartilham o `hooksPath`.

**A derivação da árvore do hook depende da PROFUNDIDADE do arquivo, e a fórmula única que a revisão 2 colou erra por um nível na lib.** `${BASH_SOURCE[0]}` dentro de um arquivo sourceado é o arquivo sourceado, não quem o sourceou. Medido:

```
$ # sonda em .forge/hooks/git/pre-push e em .forge/hooks/git/lib/probe.sh, com RAIZ = .../raiz
  hook: ../../..    -> /var/.../raiz            <-- certo
  lib:  ../../..    -> /var/.../raiz/.forge     <-- ERRADO, um nível curto
  lib:  ../../../.. -> /var/.../raiz            <-- certo
```

Por isso `HOOK_TREE` é derivado **uma vez**, no hook (`../../..` a partir de `hooks/git/<hook>`), e **injetado** nas libs pelo mesmo idioma que o `REPO` já usa hoje — `REPO="$ROOT" check_red_first` vira `REPO="$ROOT" HOOK_TREE="$HOOK_TREE" check_red_first` (`pre-push:50,61`). A lib mantém um default próprio para o uso standalone que o cabeçalho dela declara (`check-red-first.sh:8-9`), e esse default usa `../../../..`, não `../../..`. Os cenários `[11]` e `[18]` do gate 2 são os dois que mordem se a fórmula for copiada sem ajustar a profundidade.

**A âncora do cenário `[7]` do gate 1 tem de continuar única depois de D12.** `^HOOK_LIB_DIR=` é hoje 1 ocorrência ancorada em início de linha, de 5 do identificador, e `pre-push:41` é um dos sítios que esta onda edita — um fallback escrito como segunda atribuição em coluna zero faria `[7]` reprovar por desenho, num vermelho fabricado. A forma de D12 medida na bancada acrescenta `HOOK_TREE=` em coluna zero e **não** duplica `^HOOK_LIB_DIR=`; medido depois da mutação: `grep -ac '^HOOK_LIB_DIR=' → 1`.

**Remedido na revisão 2 com uma implementação de D12 escrita de novo, sob `$TMPDIR`, e `git commit` real em cada forma.** O ramo do fallback deriva a árvore do hook do próprio arquivo em execução (`dirname "${BASH_SOURCE[0]}"/../../..`) e nunca compara caminhos — ver a retratação da §8. A sonda de `check-secrets` escreve um arquivo-marcador, porque "commitou sem erro" é satisfeito por um hook que não delegou para ninguém.

```
### [a] worktree SEM o alvo, tronco COM
    pre-commit: check-secrets resolvido na árvore do HOOK (/var/.../b5/a) — este checkout não o tem
    pre-commit OK
    [feat/x 916a7df] chore: s1
    rc=0
    MARCA: a sonda do tronco EXECUTOU

### [b] checkout principal, ambos SEM o alvo (a mesma árvore)
    pre-commit BLOQUEADO: .forge/scripts/ existe mas check-secrets.sh não — a delegação aponta para um alvo ausente
    rc=1                                            <-- w147[6] preservado

### [c] worktree e tronco, ambos SEM o alvo, com .forge/scripts/ RASTREADO no worktree
    pre-commit BLOQUEADO: .forge/scripts/ existe mas check-secrets.sh não — a delegação aponta para um alvo ausente
    rc=1                                            <-- não é válvula de escape

### [d] worktree COM alvo PRÓPRIO, tronco com outro — precedência
    pre-commit OK
    [feat/z 56f70e1] chore: d
    marca: d.mark.WORKTREE
    (marca do TRONCO ausente — precedência CERTA)
```

**A linha de fallback nasce com acentuação correta** — "resolvido na **árvore** do HOOK … este checkout **não** o tem". A revisão 1 colou o texto sem acentos, artefato da bancada, e uma string de produção que nasce assim passa a ter gate afirmando-a e fica cara de corrigir depois.

**E a forma `[c]` da revisão 1 media falso, o que só apareceu ao rerodá-la.** Na primeira construção da bancada o `.forge/scripts/` do worktree existia apenas como diretório vazio no tronco — e o git não versiona diretório vazio, de modo que o worktree nascia **sem** `.forge/scripts/`, a pré-condição `[ -d "$ROOT/.forge/scripts" ]` do guard não era satisfeita, e o commit passava com `pre-commit OK` e rc 0. Medido:

```
### [c] (fixture da revisão 1: .forge/scripts/ vazio, não rastreado)
    pre-commit OK
    [feat/y b705683] chore: c
    rc=0                                            <-- FALSO-VERDE do fixture, não do desenho
```

A correção é do **fixture**, não do desenho: o worktree precisa ter `.forge/scripts/` **rastreado** — na bancada, com um `outro-gate.sh` versionado dentro — e aí `[c]` bloqueia como escrito. Isto é obrigação normativa dos cenários `[2]` e `[3]` do gate 2 — os dois que asseveram o BLOQUEIO e que portanto dependem da pré-condição do guard — e não uma nota: um fixture que não satisfaz a pré-condição do guard testa o guard errado e aprova por não ter olhado.

E o gate delegado **de fato roda** contra o índice do worktree, não do tronco, porque `check-secrets.sh` resolve a raiz por `FORGE_ROOT` e usa `git -C "$ROOT"` em toda leitura (`check-secrets.sh:61-65,107-137`):

```
$ FORGE_ROOT="$W" bash "$M/.forge/scripts/check-secrets.sh" staged
OK secrets/scan-set — 1 arquivo(s) versionado(s) varrido(s) em índice (staged)
OK secrets — nenhum segredo em 1 arquivo(s) versionado(s) (índice (staged))
```

Um arquivo — o que estava staged no **worktree**. O escopo está ancorado certo.

*Alternativa descartada — sugestão 2 da issue, degradar para `WARN`.* Ela desarma o gate de segredo em todo worktree em que o hook hoje bloqueia — 21 medidos em §4.2, e o número certo é irrelevante para o argumento, porque desarmar por atacado um detector de segredo é errado com um worktree ou com cinquenta — e desarmar guarda de segurança é o dano que a Onda L1 desta mesma rodada existe para reparar. Ela também quebra `w147[6]`, que asserta o bloqueio nominalmente. E ela é desnecessária: D12 faz o gate **rodar**, que é estritamente melhor que avisar que ele não rodou.

*Alternativa descartada — predicar em "isto é um worktree linkado?" (`GIT_DIR != COMMON_DIR`).* Ela funciona e é mais frágil por dois motivos. Primeiro, ela não cobre o caso de um `hooksPath` apontando para uma árvore terceira que não é nem o tronco nem o worktree. Segundo, ela convida a uma comparação de caminhos, e comparação de caminhos no macOS é armadilha: medido, `git rev-parse --show-toplevel` devolve `/private/var/folders/...` enquanto `cd "$(dirname "$BASH_SOURCE")" && pwd` devolve `/var/folders/...` para o mesmo lugar, porque `/var` é symlink para `/private/var` e `pwd` é lógico. `bin/forge.mjs:530` já paga esse pedágio com `realpathSync` e o comentário dele conta que a primeira versão do guard matava o `w94` em silêncio. D12 não compara caminho nenhum — testa a existência do arquivo nos dois lugares, em ordem — e por isso não tem essa superfície.

**D13. O fallback é dito em voz alta, sempre que dispara.**

"Resolvi na árvore do hook porque este checkout não tem" é informação que o operador precisa: ela explica por que o gate rodou, de onde veio o código que rodou, e sugere `forge upgrade` na branch. Silêncio aqui recriaria a classe do "não verifiquei" invisível.

**D14. A regra vale para toda a classe de delegação em alvo ausente, não só para `check-secrets.sh` — e a classe foi remedida, porque a varredura da revisão 1 era falsamente exaustiva.**

A revisão 1 enumerou por `grep -rn 'existe mas' template/.forge/hooks/`, chamou o resultado de nove e listou dez. Os dois defeitos foram corrigidos, e o segundo é o grave: **o idioma `existe mas` não é a classe**. Varredura ampla, por desfecho em vez de por frase:

```
$ grep -arn 'BLOQUEADO\|FALHOU' template/.forge/hooks/ | grep -ai 'ausente\|existe mas\|não existe\|não —\|sumiu' | sed 's|template/.forge/hooks/||'
git/commit-msg:30:            .forge/scripts/ existe mas check-ai-attribution.sh não
git/pre-push:41:             $HOOK_LIB_DIR existe mas $(basename "$1") não
git/pre-push:73:             .forge/scripts/ existe mas check-ai-attribution.sh não
git/pre-push:113:            .forge/scripts/ existe mas check-liaison-acks.sh não
git/pre-push:176:            pré-condições de worktree ausentes (issue #81)
git/pre-push:234:            .forge/scripts/lib/ existe mas heavy-mutex.sh não
git/pre-push:309:            este push publica N arquivo(s) .sh e .forge/scripts/<lint>.sh não existe
git/pre-push:391:            runtime.gates declara '<...>' e .forge/scripts/ não existe neste checkout
git/pre-push:455:            gate '<g>' declarado em runtime.gates e <script> não existe
git/pre-push:480:            .forge/scripts/tests/ existe mas run-all.sh não
git/pre-commit:76:           .forge/scripts/ existe mas check-secrets.sh não
git/post-merge:39:           .forge/scripts/lib/ existe mas changelog-from-merge.mjs não
git/post-merge:59:           .forge/scripts/ existe mas check-liaison-log-integrity.sh não
git/lib/check-red-first.sh:89:  .forge/scripts/ existe mas check-red-first.sh não
git/lib/check-red-first.sh:93:  .forge/scripts/lib/gate-universe.sh ausente

$ grep -arn 'BLOQUEADO\|FALHOU' template/.forge/hooks/ | grep -aci 'ausente\|existe mas\|não existe\|não —\|sumiu'
15
$ grep -arn 'existe mas' template/.forge/hooks/ | wc -l
      10
```

**Quinze recusas, das quais o idioma `existe mas` pegava dez.** Os cinco a mais incluem `pre-push:309` e `check-red-first.sh:93`, que são exatamente da classe e teriam ficado de fora — a onda "consertaria um e deixaria doze" pela mesma varredura que ela usava para provar que não faria isso.

**A classe, classificada sítio a sítio, e a classificação é medida, não assumida.** Doze dos quinze são "o alvo é maquinaria do harness que a branch corrente pode não ter"; três não são, e cada exclusão tem motivo:

| Sítio | Alvo | Na classe? | Por quê |
|---|---|---|---|
| `pre-commit:76` | `check-secrets.sh` | **sim** | resolve a raiz por `FORGE_ROOT` (`check-secrets.sh:61-65`), então lê o checkout que está commitando |
| `commit-msg:30` | `check-ai-attribution.sh` | **sim** | idem (`check-ai-attribution.sh:23-26`) |
| `pre-push:41` | libs de hook (`check-docs-reviewed.sh`, `check-red-first.sh`) | **sim** | as libs leem `REPO`, injetado pelo hook (`check-docs-reviewed.sh:9-10`, `check-red-first.sh:12-13`) |
| `pre-push:73` | `check-ai-attribution.sh` | **sim** | idem `commit-msg:30` |
| `pre-push:113` | `check-liaison-acks.sh` | **sim** | resolve por `forge_resolve_root` (`check-liaison-acks.sh:60`), que aponta para o **tronco** por norma — o fallback muda de onde vem o script, nunca o que ele lê |
| `pre-push:234` | `heavy-mutex.sh` | **sim** | lê `${FORGE_ROOT:-$(git rev-parse --show-toplevel)}/.forge/forge.yaml` (`heavy-mutex.sh:86,230,683`) |
| `pre-push:309` | lint de shell declarado em `SHELL_LINTS` | **sim** | invocado com `FORGE_ROOT="$ROOT"` (`pre-push:314`); a guarda já vive dentro do ramo "há `.sh` a varrer", que é a doutrina desta decisão aplicada por outro caminho |
| `pre-push:480` | `tests/run-all.sh` | **sim, com uma condição** | ver abaixo |
| `post-merge:39` | `changelog-from-merge.mjs` | **sim** | invocado como `node "$CHANGELOG_GEN" "$ROOT"` — a raiz é argumento explícito |
| `post-merge:59` | `check-liaison-log-integrity.sh` | **sim** | invocado com `FORGE_ROOT="$ROOT"` (`post-merge:53`) |
| `check-red-first.sh:89` | `check-red-first.sh` (o script, não a lib) | **sim** | a lib já opera sobre `REPO` |
| `check-red-first.sh:93` | `lib/gate-universe.sh` | **sim** | é lib pura, sem raiz própria |
| `pre-push:176` | `check-worktree-prereqs.sh` **presente e reprovando** | não | o alvo existe e o veredito é dele; o `elif` de `:180` já é a forma degradada, e é de lá que esta decisão tira a doutrina |
| `pre-push:391` | nenhum — `.forge/scripts/` inteiro ausente | não | sem `.forge/scripts/` não há harness instalado neste checkout, e o hook já decidiu esse caminho |
| `pre-push:455` | gate declarado em `runtime.gates` | não | o contrato foi declarado pelo **`FORGE.md` deste checkout**; não é cobrar de quem não tem como pagar, é cobrar de quem escreveu a cobrança |

**A classe, contada por arquivo — e é esta contagem que a tabela de §0 tem de repetir.** A revisão 2 escreveu a tabela de §0 à mão e pôs 5 sítios no `pre-push`, somando 11, enquanto esta seção enumerava 6 e dizia doze três vezes. Era o resíduo do bloqueador 3 da revisão 1, e o revisor o achou. A contagem agora é derivada:

```
$ grep -arn 'BLOQUEADO\|FALHOU' template/.forge/hooks/ | grep -ai 'ausente\|existe mas\|não existe\|não —\|sumiu' \
    | sed 's|template/.forge/hooks/||' | cut -d: -f1 | sort | uniq -c
   1 git/commit-msg
   2 git/lib/check-red-first.sh
   2 git/post-merge
   1 git/pre-commit
   9 git/pre-push
```

| Arquivo | Recusas na varredura | Fora da classe | **Na classe** |
|---|---|---|---|
| `pre-push` | 9 | 3 (`:176`, `:391`, `:455`) | **6** |
| `post-merge` | 2 | 0 | **2** |
| `lib/check-red-first.sh` | 2 | 0 | **2** |
| `commit-msg` | 1 | 0 | **1** |
| `pre-commit` | 1 | 0 | **1** |
| **total** | **15** | **3** | **12** |

**A condição do `pre-push:480`, e ela foi medida.** `run-all.sh:25` ancora o universo em `DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, e o hook o invoca **sem** `--path` (`pre-push:478`). Um fallback ingênuo ali faria o worktree rodar o corpus do TRONCO e reportá-lo como `harness-tests` do checkout — mudança do que é verificado, não de onde mora o verificador, que é dano pior que o bloqueio. Medido:

```
$ bash "$B/tronco/.forge/scripts/tests/run-all.sh"
  ✓ t-tronco-1.test.sh
  ✓ t-tronco-2.test.sh
harness-tests: 2 arquivo(s) examinado(s) — PASS=2 FAIL=0
$ bash "$B/tronco/.forge/scripts/tests/run-all.sh" --path "$B/worktree/.forge/scripts/tests"
  ✓ t-worktree-unico.test.sh
harness-tests: 1 arquivo(s) examinado(s) — PASS=1 FAIL=0
```

Então `pre-push:480` entra na classe **com o corpus ancorado explicitamente no checkout**: o runner pode vir da árvore do hook, o universo examinado é sempre `$ROOT/.forge/scripts/tests`, e o cenário `[12]` do gate 2 asserta a contagem do worktree (1) contra a do tronco (2) — a discriminação existe porque os dois números diferem por construção da fixture.

Consertar um e deixar doze é o padrão que LDG-0171 registra e que o plano-mestre condena nominalmente. Por isso §0 lista **sete** arquivos de produção, o DoD da §6 cobra `bash -n` nos sete, e o cenário `[19]` do gate 2 é a auto-ironia que reprova quando um sítio da classe nasce sem cenário. **A revisão 2 dizia que esse cenário usava "o idioma que `w147[8]` já usa para os hooks", e essa frase era o defeito:** o `COBERTOS` de `w147[8]` é por ARQUIVO, e cobertura por arquivo aqui deixaria seis dos doze sítios mudando sem uma asserção sequer, com o gate verde afirmando o contrário. A unidade de cobertura desta onda é o **sítio**, está escrita em letra em §4.4, e é por isso que o gate 2 tem vinte cenários e não quatorze.

Dois sítios já degradam para aviso em vez de bloquear — `check-worktree-prereqs.sh` (`pre-push:173,181`) e `check-liaison-log-integrity.sh` (`pre-push:142-143`) — e o comentário deles diz exatamente por quê: *"uma worktree que ainda não trouxe o commit deste script, mas herda o hook novo de outra, bloquearia por causa alheia"*. **A doutrina já está escrita no arquivo; ela só não foi aplicada aos sítios que bloqueiam.** Esta onda não inventa política: aplica a que o próprio arquivo declara, e da forma melhor — resolvendo em vez de degradando.

*Alternativa descartada — converter os doze sítios em avisos, para uniformizar com os dois que já degradam.* Perderia cobertura real no checkout principal, onde a ausência do alvo é de fato instalação corrompida — e é o que o cenário `[2]` do gate 2 guarda.

**D15. A sugestão 3 da issue — o `forge upgrade` avisar que há worktrees ativos — não entra nesta onda.**

O `doctor` já lista, por worktree linkado, quantos arquivos de maquinaria divergem do tronco e quantos commits o worktree está à frente (`doctor.sh:378-395`), e a rule `machinery-propagation.md` registra isso como contrato. Um aviso adicional no `upgrade` não desbloquearia ninguém: o bloqueio continuaria mordendo, e o operador continuaria com `--no-verify` como única saída. Depois de D12 o aviso perde a razão de ser. Fica registrado como não feito, com o motivo, e não como esquecimento.

### 4.4 O VERMELHO, antes do verde — gate 2

Gate novo `tests/w<NNN>-delegacao-arvore-do-hook-gate.sh`. **`DECLARADOS=20`**, denominador fixo.

**A unidade de cobertura é o SÍTIO, não o arquivo — e esta frase é normativa, não comentário.** A revisão 2 declarava 14 cenários e citava `w147[8]` como modelo; o `COBERTOS` de `w147[8]` é por arquivo, e sob essa leitura o gate ficaria verde afirmando cobrir a classe enquanto `pre-push:41`, `pre-push:73`, `pre-push:234`, `pre-push:309`, `post-merge:39` e `check-red-first.sh:89` mudavam sem uma asserção sequer — verde que afirma mais do que mede, na guarda que existe justamente para impedir o padrão do LDG-0171. Sob a leitura por sítio, que é a que a mensagem de falha do cenário de auto-ironia escreve, o gate com 14 cenários **nunca poderia ficar verde**, porque seis sítios ficariam acusados e `DECLARADOS` é denominador fixo. As duas leituras eram ruins e a escolha não estava no documento. Ela está agora: **coberto = sítio**, os seis sítios descobertos ganharam cenário próprio, e `DECLARADOS` subiu de 14 para 20 para acomodá-los.

| # | Cenário | Sítio coberto | Asserção | Mensagem do vermelho hoje | Por que falha por ausência real |
|---|---|---|---|---|---|
| [1] | `pre-commit`: worktree sem o alvo, tronco com | `pre-commit:76` | `git commit` **sucede**, o marcador da sonda existe, e a saída diz onde resolveu | `FAIL [1]: commit bloqueado no worktree por alvo que a branch nunca declarou (rc=1)` | não há fallback: `pre-commit:74` resolve só por `$ROOT` |
| [2] | `pre-commit`: checkout principal, ambos sem o alvo | `pre-commit:76` | `git commit` **falha**, e a mensagem nomeia o alvo | — | nasce verde; é a guarda que preserva `w147[6]` |
| [3] | `pre-commit`: worktree e tronco ambos sem o alvo, **com `.forge/scripts/` rastreado no worktree** | `pre-commit:76` | `git commit` **falha** | — | nasce verde; prova que [1] não é válvula de escape. A fixture **tem de** versionar algo dentro de `.forge/scripts/`, senão o guard não é alcançado e o cenário aprova sem olhar — medido em §4.3 |
| [4] | `pre-commit`: worktree **com** alvo próprio, tronco com outro | `pre-commit:76` | o alvo do **worktree** roda (marcadores distinguíveis), e a linha de fallback **não** aparece | — | **nasce verde, e a revisão 2 dizia o contrário.** Medido na revisão 3: contra o `pre-commit` de HOJE, sem fallback nenhum, o commit passa com `pre-commit OK`, a marca é `marca.WORKTREE`, a do tronco não existe e a linha de fallback não aparece — a asserção já é satisfeita. É controle de precedência, e quem o faz morder é M12 |
| [5] | repositório sem `.forge/` nenhum | — (a pré-condição de D12) | os hooks seguem no-op, rc 0 | — | nasce verde; é a degradação legítima, e é o cenário que a pré-condição de engate de D12 protege |
| [6] | canal real: `git commit` de verdade, com `core.hooksPath` absoluto | `pre-commit:76` | o marcador da sonda prova execução — nunca a ausência de erro | `FAIL [6]: ...` | idem [1] |
| [7] | mutação de canal: `core.hooksPath` para um diretório sem o hook | — (mede o canal) | `[1]` deixa de valer, e o gate acusa | — | prova que [1] media o canal e não o script |
| [8] | `commit-msg`: worktree sem `check-ai-attribution.sh`, tronco com | `commit-msg:30` | a mensagem de commit é aceita e o marcador prova que o gate do tronco rodou | `FAIL [8]: commit-msg bloqueou no worktree por alvo que a branch nunca declarou` | `commit-msg:30` resolve só por `$ROOT` |
| [9] | `pre-push`: worktree sem `check-liaison-acks.sh`, tronco com | `pre-push:113` | o push não é bloqueado e o marcador prova execução | `FAIL [9]: pre-push bloqueou no worktree (pre-push:113)` | `pre-push:113` resolve só por `$ROOT`. **Vermelho medido na revisão 3:** contra o hook de hoje, checkout com `.forge/scripts/` e sem o alvo devolve `pre-push BLOQUEADO: .forge/scripts/ existe mas check-liaison-acks.sh não` |
| [10] | `post-merge`: worktree sem `check-liaison-log-integrity.sh`, tronco com | `post-merge:59` | o hook **não** reporta `post-merge INCOMPLETO`, e o marcador prova execução | `FAIL [10]: post-merge INCOMPLETO por alvo que a branch nunca declarou` | `post-merge:59` resolve só por `$ROOT` |
| [11] | `lib/check-red-first.sh`: worktree sem `lib/gate-universe.sh`, tronco com | `check-red-first.sh:93` | o push não é bloqueado e o contador de universo do red-first é publicado | `FAIL [11]: check-red-first.sh:93 bloqueou sem o gate-universe.sh da árvore do hook` | `check-red-first.sh:93` resolve só por `$REPO`. É um dos dois cenários que mordem se a fórmula de `HOOK_TREE` for copiada sem ajustar a profundidade da lib (§4.3) |
| [12] | `harness-tests`: worktree sem `tests/run-all.sh`, tronco com **dois** testes e o worktree com **um** | `pre-push:480` | a suíte roda e examina **1** arquivo, o do worktree — nunca 2 | `FAIL [12]: harness-tests examinou 2 arquivo(s), o corpus do TRONCO` | `pre-push:478` invoca sem `--path`, e `run-all.sh:25` ancora no `dirname` do próprio arquivo |
| [13] | `pre-push`: worktree com `hooks/git/lib/` presente e **sem** `check-docs-reviewed.sh`, tronco com | `pre-push:41` | o push não é bloqueado e o marcador de `check_docs_reviewed` prova execução | `FAIL [13]: pre-push:41 bloqueou no worktree por lib que a branch nunca declarou` | `require_hook_lib` resolve só sob `$HOOK_LIB_DIR`, que é `$ROOT/.forge/hooks/git/lib`. **Vermelho medido:** `pre-push BLOQUEADO: <...>/.forge/hooks/git/lib existe mas check-docs-reviewed.sh não —`. A fixture **tem de** deixar `lib/` presente e não vazio, senão a guarda `[ -d "$HOOK_LIB_DIR" ]` (`pre-push:40`) não é alcançada e o cenário aprova sem olhar — mesma obrigação de [3] |
| [14] | `pre-push`: worktree sem `check-ai-attribution.sh`, tronco com | `pre-push:73` | o push não é bloqueado e o marcador prova execução | `FAIL [14]: pre-push:73 bloqueou no worktree por alvo que a branch nunca declarou` | `pre-push:73` resolve só por `$ROOT`. **Vermelho medido:** `pre-push BLOQUEADO: .forge/scripts/ existe mas check-ai-attribution.sh não — delegação em alvo ausente` |
| [15] | `pre-push`: worktree com `.forge/scripts/lib/` presente e **sem** `heavy-mutex.sh`, tronco com, e `heavy_mutex.enabled: true` no `forge.yaml` do worktree | `pre-push:234` | o push não é bloqueado, a linha de fallback nomeia `heavy-mutex.sh`, **e** o marcador de aquisição do mutex prova execução — o sinal positivo é obrigatório porque com o default desligado o não-bloqueio sozinho é indistinguível de "a lib nunca foi usada" | `FAIL [15]: pre-push:234 bloqueou no worktree por lib que a branch nunca declarou` | `pre-push:233` resolve só por `$ROOT`. **Vermelho medido:** `pre-push BLOQUEADO: .forge/scripts/lib/ existe mas heavy-mutex.sh não — delegação em alvo ausente.` |
| [16] | `pre-push`: push que publica um `.sh`, worktree sem o lint declarado em `SHELL_LINTS`, tronco com | `pre-push:309` | o push não é bloqueado e o marcador do lint prova execução, com `FORGE_ROOT="$ROOT"` preservado | `FAIL [16]: pre-push:309 bloqueou no worktree por lint que a branch nunca declarou` | `pre-push:309` resolve só por `$ROOT`. O par negativo — lint ausente nas **duas** árvores continua bloqueando — já é assertado nominalmente por `w190[11]`, e §7.1 traz a medição de que `w190[11]` sobrevive a D12 neste sítio |
| [17] | `post-merge`: worktree com `.forge/scripts/lib/` presente e **sem** `changelog-from-merge.mjs`, tronco com | `post-merge:39` | o hook **não** reporta `post-merge FALHOU`, e o marcador do gerador prova execução | `FAIL [17]: post-merge FALHOU por alvo que a branch nunca declarou` | `post-merge:38` resolve só por `$ROOT`. **Vermelho medido:** `post-merge FALHOU: .forge/scripts/lib/ existe mas changelog-from-merge.mjs não —` |
| [18] | `lib/check-red-first.sh`: worktree com `.forge/scripts/` presente e **sem** `check-red-first.sh` (o script), tronco com | `check-red-first.sh:89` | o push não é bloqueado e o veredito estático do red-first é publicado | `FAIL [18]: check-red-first.sh:89 bloqueou sem o script da árvore do hook` | `check-red-first.sh:88` resolve só por `$REPO`. **Vermelho medido:** `pre-push BLOQUEADO: .forge/scripts/ existe mas check-red-first.sh não — o gate de red-first sumiu.` É o segundo cenário que morde a profundidade errada de `HOOK_TREE` na lib |
| [19] | **auto-ironia**: todo sítio da classe tem cenário **próprio** aqui | a classe inteira | o gate recomputa a varredura ampla de `template/.forge/hooks/`, monta a classe, e cruza com um mapa `COBERTOS` declarado no fonte que liga cada sítio (`<arquivo>:<linha>`) ao **número do cenário** que o exercita; reprova se um sítio da classe não tem entrada, se uma entrada aponta para um cenário que não foi executado nesta corrida, ou se uma entrada não casa mais nenhuma linha da varredura | `FAIL [19]: sítio <arquivo:linha> na classe e sem cenário` / `FAIL [19]: entrada <arquivo:linha> não casa mais a varredura — a classe mudou e ninguém reauditou` | verde por construção **depois** de os doze sítios entrarem; vermelho enquanto faltar um |
| [20] | contador de controle | — | 20 de 20 cenários executados | — | verde por construção |

**Treze dos vinte falham hoje por ausência real** — `[1]`, `[6]`, `[8]`, `[9]`, `[10]`, `[11]`, `[12]`, `[13]`, `[14]`, `[15]`, `[16]`, `[17]` e `[18]`. **Quatro nascem verdes como controles negativos** — `[2]`, `[3]`, `[4]` e `[5]`. `[7]` é a mutação de canal, `[19]` é a guarda de classe e `[20]` é a sentinela. Treze mais quatro mais três fecha vinte.

**O `[4]` mudou de lado na revisão 3, e por medição minha.** A revisão 2 o listava entre os que falham hoje, com a justificativa "idem [1]: não há fallback". A justificativa não se sustenta: `[4]` põe o alvo **no próprio worktree**, e `$ROOT/.forge/scripts/check-secrets.sh` existe ali, de modo que o hook de hoje já resolve certo. Medido em bancada, com `git worktree add` sob `.forge/worktrees/` (a guarda de `pre-commit` recusa worktree fora dali) e sondas distinguíveis nas duas árvores: `pre-commit OK`, rc 0, `marca.WORKTREE` presente, marca do tronco ausente, zero linhas casando "árvore do HOOK". `[4]` é controle, e é M12 — inverter a precedência — que o faz morder.

**Como `[19]` fica decidível, e por que a lista de sítios é literal deliberado.** O `COBERTOS` do gate é um mapa `<arquivo>:<linha> → <cenário>` com doze entradas, e o `EXCLUIDOS` é um mapa `<arquivo>:<linha> → <motivo>` com três (`pre-push:176`, `:391`, `:455`). Os números de linha **envelhecem no primeiro hook editado**, e isso é o comportamento desejado, não um defeito: quando um sítio da classe muda de lugar, o gate reprova e obriga a reauditar a classe, que é exatamente o que ninguém fez entre a revisão 1 e a 2. É a mesma exceção de universo fechado que a invariante 14 concede a `DECLARADOS`, e está registrada como tal na tabela de §7. **Ela não viola a regra de §2.8 ("nada de número derivado da árvore como literal"), e a diferença importa:** `COBERTOS` não é um número comparado contra uma contagem — é um conjunto cruzado com a varredura que o próprio gate recomputa, e a divergência reprova nos dois sentidos, tanto o sítio sem entrada quanto a entrada sem sítio. Um literal que só pode estar certo se a varredura o confirmar não é um número copiado: é uma asserção. **O implementador preenche `COBERTOS` com as linhas medidas na árvore no momento em que o gate fica verde, nunca copiadas desta especificação** — as citadas aqui são de 2026-09-08 e a onda edita todos os doze sítios.

O sinal positivo de execução em `[1]`, `[6]`, `[8]`–`[18]` é obrigatório e não é detalhe: o `pre-commit` **captura** a saída do `check-secrets.sh` no caminho de sucesso (`pre-commit:79-90`, "imprimir isso em TODO commit limpo transformaria o sinal em ruído"), de modo que "commitou sem erro" é satisfeito por um hook que não delegou para ninguém. A fixture instala uma sonda que escreve um arquivo-marcador, no idioma que `w151` já usa com `$MARK`.

**Mutações do item 3:**

| Mutação | O gate tem de dizer | Estado |
|---|---|---|
| M11 — remover o fallback (o estado de hoje) | `FAIL` nos treze cenários de ausência (`[1]`, `[6]`, `[8]`–`[18]`); `[2]`, `[3]`, `[4]` e `[5]` verdes | **MEDIDO** em `pre-commit:76` (§4.1) e, na revisão 3, em `pre-push:41`, `:73`, `:113`, `:234`, `post-merge:39` e `check-red-first.sh:89`, cada um com a recusa literal colada nesta tabela; A MEDIR nos demais sítios |
| M12 — inverter a precedência (árvore do hook antes do checkout) | `FAIL [4]` apenas | A MEDIR |
| M13 — fazer o fallback avisar em vez de resolver (sugestão 2 da issue) | `FAIL` nos treze cenários de ausência, **por marcador ausente e não por bloqueio** — é a diferença entre M13 e M11, e é o que prova que a asserção mede execução; `[2]`, `[3]`, `[4]` e `[5]` verdes | A MEDIR |
| M14 — apontar `core.hooksPath` para um diretório vazio | `FAIL [7]` — a mutação de canal | A MEDIR |
| M15 — invocar `run-all.sh` da árvore do hook **sem** `--path` (o fallback ingênuo do `pre-push:480`) | `FAIL [12]` apenas — a contagem sobe de 1 para 2 | **MEDIDO** em §4.3: `2 arquivo(s) examinado(s)` contra `1 arquivo(s) examinado(s)` |
| M16 — remover um sítio da classe do `COBERTOS` | `FAIL [19]` apenas | A MEDIR |
| M17 — derivar `HOOK_TREE` na lib com `../../..` em vez de `../../../..` | `FAIL [11]` e `FAIL [18]` — os dois sítios que vivem em `hooks/git/lib/` | **MEDIDO** estaticamente em §4.3: a fórmula resolve `.forge/` em vez da raiz, e o fallback não acha nada |
| M18 — engajar o fallback **antes** da guarda de instalação do sítio (a letra de D12 sem a pré-condição) | `FAIL [5]` — o repositório sem `.forge/` passa a executar script da outra árvore | **MEDIDO** em §4.3: a saída ganha `OK liaison-acks — sem canal` num repositório sem harness nenhum |

**PBT:** não se aplica. O espaço é o produto cartesiano de dois booleanos (alvo presente no checkout × alvo presente na árvore do hook) vezes duas topologias (checkout principal × worktree linkado) — oito combinações, das quais duas são impossíveis por construção (no checkout principal as duas árvores são a mesma, então os dois booleanos não podem divergir). As seis restantes estão **enumeradas** nos cenários `[1]`–`[5]` mais o caso trivial. Um gerador aleatório sobre seis pontos não é PBT, é sorteio com passos extras. O que multiplica esse espaço nesta onda não é a variedade da entrada e sim o número de **sítios**, e sítio é enumeração fechada e verificável — que é exatamente o que o cenário `[19]` faz, por varredura, no lugar de um gerador.

**Contrato:** o contrato aqui é a **mensagem de recusa**, que tem gate afirmando-a (`w147[6]`, `case "$out" in *check-secrets.sh*`) e adotante instalado. Ela é preservada literalmente. O cenário `[2]` é o teste de contrato, e a §7 traz a varredura que o sustenta.

**Níveis:** integração em `[1]`–`[5]` e `[8]`–`[18]`; E2E em `[6]` e `[7]`, com `git worktree add` e `git commit` reais; unitário **não se aplica**, porque a unidade é a resolução de caminho dentro do hook e testá-la fora do hook mediria uma cópia.

### 4.5 Retrocompatibilidade — reaberta na revisão 2

**O que quebra: nada, e a afirmação tem prova.** A mudança é uma precedência **acrescentada** antes de uma recusa **preservada**. No checkout principal — que é onde os três gates existentes (`w147`, `w137`, `w191`) exercitam o `pre-commit`, verificado por leitura de `mkrepo` em `w147:33-42` e de `w137:77-78` — as duas árvores são a mesma, o fallback não tem onde resolver, e o comportamento é idêntico ao de hoje. Medido em `[b]` da §4.3.

**Nenhum gate existente exercita o `pre-commit` a partir de um worktree linkado.** Varredura: `grep -rln 'hooks/git/pre-commit' tests/` devolve `w137`, `w147` e `w191`; destes, só `w137` chama `git worktree add`, e ele **substitui** o `pre-commit` por um stub de duas linhas (`w137:77-78`), então não asserta o conteúdo do hook real. Ou seja: o comportamento em worktree é terreno descoberto, e o vermelho de `[1]` é genuíno.

**Quem ganha imediatamente:** os **21** worktrees do `Axis.PadSimulator` voltam a commitar assim que o `forge update` chegar. O `azim-crm` não ganha nada por esta via, porque o `pre-commit` instalado dele não tem a delegação; o `axis-go-cloud` não muda, porque os hooks do Forge não executam ali; `lionclaw` e `axis-fare-validator` não têm worktree sem o alvo.

**Quem precisa de aviso antes do update: o `azim-crm`, e a revisão 1 dizia que ninguém precisava.** O predicado remedido de §4.2 desmontou a afirmação junto com o número. Medido:

```
$ for r in azim-crm Axis.PadSimulator axis-go-cloud lionclaw axis-fare-validator; do
    p=~/Documents/projects/$r/.forge/hooks/git/pre-commit
    [ -f "$p" ] || { printf '%-22s (sem pre-commit)\n' "$r"; continue; }
    cmp -s "$p" template/.forge/hooks/git/pre-commit && c=IDENTICO || c=DIVERGE
    printf '%-22s pre-commit=%sL %s\n' "$r" "$(wc -l < "$p" | tr -d ' ')" "$c"; done
azim-crm               pre-commit=271L DIVERGE
Axis.PadSimulator      pre-commit=93L IDENTICO
axis-go-cloud          (sem pre-commit)
lionclaw               pre-commit=93L IDENTICO
axis-fare-validator    pre-commit=93L IDENTICO
$ grep -an -i 'customiza\|restaurad' ~/Documents/projects/azim-crm/.forge/hooks/git/pre-commit | head -2
60:# Customização local: o overlay do harness upstream (rc24) removeu este bloco por não conhecê-lo.
61:# Restaurado deliberadamente — o job `grpc-dockerfile-copies-gate` do CI cobre o PR, mas o ponto
$ grep -ac 'BLOQUEADO\|FALHOU' ~/Documents/projects/azim-crm/.forge/hooks/git/pre-commit
19
$ grep -an 'MACHINERY_DIRS = \|ENRICHABLE_DIRS = ' bin/forge.mjs
307:const MACHINERY_DIRS = ['agents', 'capabilities', 'commands', 'contracts', 'hooks', 'schemas', 'scripts', 'skills', 'templates', 'rules'];
352:const ENRICHABLE_DIRS = ['agents', 'rules', 'skills', 'templates'];
```

O `pre-commit` do `azim-crm` tem 271 linhas contra as 93 do template, 19 linhas de recusa próprias, e um comentário **no próprio arquivo** dizendo que um overlay anterior (rc24) já apagou um bloco local e ele foi restaurado à mão. Como `hooks` está em `MACHINERY_DIRS` (`bin/forge.mjs:307`) e fora de `ENRICHABLE_DIRS` (`:352`), o `forge update` que carrega esta onda **sobrescreve o arquivo inteiro** e apaga aquele trabalho pela segunda vez. Seria a Onda L3 entregando, no item que a revisão 1 chamava de "propagação limpa", a mesma classe de dano que a Onda L1 existe para reparar.

**Consequência para o plano de ack, e ela é dura:** o ack ao `azim-crm` sai **antes** do release, nomeando o arquivo, as 271 linhas e o mecanismo (`MACHINERY_DIRS`), e propondo que a customização local seja preservada num ponto que o overlay não toca — ou que o update seja adiado naquele repositório até L1 entrar. **Nenhum dos três itens desta onda tem propagação limpa**, e a frase da revisão 1 que dizia o contrário foi removida em vez de reescrita.

O `Axis.PadSimulator`, o `lionclaw` e o `axis-fare-validator` continuam com `pre-commit` byte-idêntico ao template, e para esses três a sobrescrita do `pre-commit` não destrói nada.

---

## 5. O que a Onda L3 explicitamente NÃO faz

1. **Não carimba manifesto de `pre-push` e não conserta o órfão de #134.** O template não produz o artefato (§1.2). O que ela faz é fixar a **posição** do curto-circuito para que um carimbo futuro nasça do lado certo, e o cenário `[7]` guarda a posição.
2. **Não muda `core.hooksPath` para relativo.** D11, com `w137[2]`, a rule `machinery-propagation.md` e a issue #41.
3. **Não escolhe um teto numérico para o `run_check`.** D7. Nenhuma suíte de consumidor foi cronometrada nesta onda, e um default inventado converteria push lento em push impossível em quatro repositórios.
4. **Não acrescenta chave a `forge.schema.json`.** D7, alternativa descartada. Sem chave nova não há obrigação de leitor por `w192`/`w199` nem contrato publicado novo.
5. **Não reescreve o vocabulário de `run-gates.sh` nem de `spec-verify.sh`.** O achado de §3.3 — estouro de teto registrado como `status: failed` no `run-manifest/v1` — é real e é mudança de contrato com adotante instalado. Vira item de ledger (§6).
6. **Não põe teto por teste dentro dos runners.** D9, alternativa descartada; depende de cronometrar as quatro suítes.
7. **Não faz o `forge upgrade` avisar sobre worktrees ativos.** D15.
8. **Não toca em `template/.forge/commands/`,** logo não regenera o plugin.
9. **Não trata o desarme de configuração pelo `forge update` (#125, #131, #130, #142).** É a Onda L1, e o acoplamento está nomeado em §1.1 e §2.10: L3 é o gatilho que faz o defeito de L1 morder o `axis-fare-validator`, então a ordem de merge importa e está na §6.
10. **Não muda o default de 300 s do `forge_run_gate`.** D7, metade 2. A política de tempo passa a ser uma **dentro do `pre-push`**; entre o hook e `run-gates.sh`/`spec-verify.sh` ela continua sendo duas, porque mudar o default de `forge_run_gate` altera o comportamento de dois scripts distribuídos com adotante instalado. Vira item de ledger junto com o achado da §3.3.
11. **Não trata o heavy-mutex (#137, #144).** É a Onda L2. O curto-circuito de deleção **reduz** a disputa pelo mutex, porque uma deleção deixa de entrar na fila — mas isso é efeito colateral benéfico, não a correção dos dois relógios.

---

## 6. Ordem de execução e definição de pronto

**Ordem obrigatória dentro da onda**, e ela não é arbitrária:

1. Alocar os dois ordinais (orquestrador, contra `origin/*` **e** contra as branches em voo desta rodada — invariante 10).
2. Escrever os dois gates completos e **observar o vermelho**, cenário a cenário, com a mensagem de cada um registrada. Onze de quinze no gate 1 e **treze de vinte** no gate 2 têm de falhar por ausência real; os controles negativos — `[3]`, `[9]` e `[13]` no gate 1, `[2]`, `[3]`, `[4]` e `[5]` no gate 2 — têm de passar já.
3. Implementar o item 3 (#141) primeiro. É o que desbloqueia os 21 worktrees medidos em §4.2 — inclusive worktrees em que o próprio trabalho desta rodada pode estar acontecendo. A revisão 1 o chamava também de "o de retrocompatibilidade limpa", e isso deixou de valer com a §4.5 reaberta: ele é o de menor superfície de código e o de **maior** superfície de propagação, porque é o que expõe a customização de 271 linhas do `azim-crm`.
4. Implementar o item 1 (#132/#134).
5. Implementar o item 2 (#135), na ordem D9 (visibilidade, risco zero) → D7/D8 (teto, opt-in).
6. Rodar as mutações M5, M6, M7, M8, M8b, M9, M10, M12, M13, M14 e M16 contra a implementação (M1, M2, M3 e M4 já foram medidas em §2.6; M15 em §4.3; M11 em parte, M17 e M18 na bancada da revisão 3, §4.3 e §4.4), com controle da árvore de trabalho, restauração por `cmp` e recontrole. Corrigir a linha da matriz quando o efeito medido divergir; corrigir o **cenário** quando a mutação sair no-op.
7. Editar o fixture de `tests/w97-hook-portability-gate.sh:38` e reconferir `w97` verde contra a implementação **e** contra o hook de hoje (§7.1 mede que as duas passam com o fixture novo).
8. Atualizar o badge `gates-N` do README (§7).
9. Suíte inteira verde, serializada pelo orquestrador (invariante 9).

**Ordem entre ondas:** o merge de L3 antes de L1 expõe o `axis-fare-validator` à sobrescrita do `pre-push` dele (§2.10). Ou L1 entra antes, ou o ack ao `axis-fare-validator` sai **antes** do release, avisando para preservar o carimbo de manifesto. Registro a dependência; a escolha é do orquestrador.

**Definição de pronto:**

- `bash -n` limpo nos **sete** arquivos de produção tocados — `pre-push`, `pre-commit`, `commit-msg`, `post-merge`, `lib/check-red-first.sh`, `template/.forge/scripts/tests/run-all.sh` e `tests/run-all.sh`; nada de `declare -A`, `${var,,}`, `mapfile` (invariante 8).
- Os dois gates verdes, cada um imprimindo o contador com denominador fixo (`15` e `20`), e reprovando se o contador não bater.
- **O mapa `COBERTOS` do cenário `[19]` do gate 2 preenchido com as doze linhas medidas na árvore no momento em que o gate fica verde**, nunca copiadas desta especificação, e o `EXCLUIDOS` com as três exclusões e o motivo de cada uma. A unidade é o sítio: doze entradas para doze sítios, cada uma apontando para o número de um cenário que a corrida executou.
- **`tests/w97-hook-portability-gate.sh:38` editado no MESMO change**, com `local_sha` **não zero** no lugar dos 40 zeros — a fixture faz `git init` sem commit, então não há sha real disponível ali, e a própria bancada de §7.1 usou `1111…1`; a revisão 2 escrevia "real", que a medição não sustenta. §7.1 mede que sem essa edição o gate fica vermelho contra a implementação correta de D1/D2, e a invariante 15 nomeia `w97` como um dos quatro que uma onda anterior quase deixou vermelhos pelo mesmo descuido.
- `w97`, `w61`, `w107`, `w113`, `w135`, `w146`, `w147`, `w151`, `w152`, `w160`, `w168`, `w191` e **`w190`** verdes — os **treze** gates que EXECUTAM o `pre-push`, medidos um a um em §7.1 — mais `w137` e `w200`.
- Badge do README batendo com `find tests -maxdepth 1 -name '*-gate.sh' | wc -l`.
- As três issues fechadas com a evidência: #132 e #134 juntas, com a nota de que o mecanismo `_viu_ref` era do consumidor e a metade do manifesto não se aplica; #135 com as três peças do diagnóstico; #141 com a recusa da sugestão 1, a medição remedida de 21 worktrees bloqueados num único repositório, e a nota de que o `azim-crm`, que abriu a issue, **não** está entre os bloqueados porque o `pre-commit` instalado dele não tem a delegação.
- **Um item de ledger novo**, aberto pela onda: *estouro de teto em `forge_run_gate` é reportado como `failed` por `run-gates.sh` e por `spec-verify.sh`, e entra no `run-manifest/v1` como veredito que nunca foi produzido* (§3.3).
- **Um segundo item de ledger**, aberto pela onda: *cronometrar as suítes dos quatro consumidores para decidir o teto default de `run_check` e o teto por teste dos runners* (D7 e D9, alternativas descartadas).

---

## 7. Varredura das invariantes 14 e 15

**Invariante 15 — toda string de produção que a onda toca, e os gates que a afirmam.**

| String | Muda? | Gates que a afirmam |
|---|---|---|
| `pre-commit BLOQUEADO: .forge/scripts/ existe mas check-secrets.sh não — a delegação aponta para um alvo ausente` | **não** | `w147[6]` (`case "$out" in *check-secrets.sh*`) |
| `pre-push: typecheck OK` / `pre-push: test OK` | **não** | `w135[3]` (`grep -q 'typecheck OK'`, `grep -q 'test OK'`) |
| `pre-push OK` | **não** | `w147[7]`, `w190`, `w152` |
| `✓ <nome>` / `✗ <nome>` do `run_one` | **não** — o anúncio é linha **nova** | nenhum gate de `tests/` afirma essas linhas do runner do template (varredura abaixo) |
| `harness-tests: N arquivo(s) examinado(s) — PASS=… FAIL=…`, `OK harness-tests` | **não** | idem |
| linha nova de deleção, linha nova de teto, linha nova de fallback | **novas** | nenhum gate existente as afirma |

Varredura executada, com `-a` e com controle positivo: `grep -arn 'harness-tests —\|arquivo(s) examinado(s)\|OK harness-tests\|PASS=' tests/` devolve **apenas** `tests/run-all.sh`, que é o runner deste repositório e não um gate. Nenhum gate afirma o vocabulário do runner do template. O universo dessa varredura é conhecido: o único arquivo de `tests/` e `template/` que o `file` não classifica como texto é `template/.forge/scripts/lib/secret-scan.mjs` (medido no cabeçalho deste documento), e ele não está em `tests/`; além disso `grep -arln 'pre-push' tests/` e a mesma varredura sem `-a` devolvem **o mesmo conjunto de dezenove arquivos**, o que confirma que nada de `tests/` está invisível ao `grep`.

### 7.1 Os treze gates que EXECUTAM o `pre-push`, MEDIDOS um a um — e os dois erros de universo

**O universo desta seção foi definido errado duas vezes, e a segunda vez foi minha.** A revisão 1 concluiu, por inspeção do formato de payload de três gates, que "nenhum gate existente quebra pelo curto-circuito" — leitura de fixture em vez de execução. A revisão 2 corrigiu o método e errou o **predicado**: definiu o universo por `grep -arln 'hooks/git/pre-push' tests/`, que casa o literal de caminho e devolve doze. O `w190` executa o hook pelo **canal real** — `git push` contra um remoto `--bare`, com `core.hooksPath` absoluto (`w190:105`) — e nunca escreve aquele literal, então ficou de fora de uma tabela cujo título prometia exaustividade. Ele está no DoD como gate que precisa ficar verde. Predicado remedido: **executa o `pre-push`, por invocação direta do arquivo ou por `git push` com `core.hooksPath` apontando para uma árvore que o contém.** Medido:

```
$ grep -arln 'pre-push' tests/ | wc -l
      19
$ grep -arln 'hooks/git/pre-push' tests/ | wc -l
      12
$ comm -12 <(grep -arln 'pre-push' tests/ | sort) <(grep -arln 'git .*push' tests/*.sh | sort)
tests/w135-push-refs-export-gate.sh
tests/w151-heavy-mutex-gate.sh
tests/w152-push-ahead-gate.sh
tests/w175-worktree-reconcile-remote-gate.sh
tests/w190-pre-push-gate-reader-gate.sh
tests/w97-hook-portability-gate.sh
```

Dezenove gates **mencionam** o `pre-push`; treze o **executam**. Dos seis que mencionam sem executar, `w175` cita em comentário (`w175:8`) e não configura `hooksPath`; `w120` (`:132`), `w150` (`:68`) e `w167` (`:48`) invocam o script delegado diretamente — `check-ai-attribution.sh`, `check-liaison-acks.sh` — e não o hook; `w106` configura `core.hooksPath` (`:49`) mas nunca faz `git push`, e o alvo dele é `check-red-first.sh` invocado direto (`:41`); `w153` escreve um `pre-push` sintético de duas linhas em `.githooks/` (`:120`), que não é o do template. O décimo terceiro executante é o `w190`, e ele entra na tabela abaixo.

Bancada: cópia do repositório inteiro sob `$TMPDIR` (sem `node_modules` e sem `.git`), o curto-circuito de D1/D2 aplicado ao `template/.forge/hooks/git/pre-push` de lá, cada gate rodado individualmente contra o baseline e contra a implementação.

| Gate | Baseline (hook de hoje) | Com o curto-circuito | Veredito |
|---|---|---|---|
| `w61` | rc=0 | rc=0 | verde nos dois |
| **`w97`** | **rc=0 `PASS`** | **rc=1 `FAIL [3] (esperava aviso de skip)`** | **QUEBRA** |
| `w107` | rc=0 | rc=0 `OK [20]` | verde nos dois |
| `w113` | rc=0 | rc=0 `OK [12]` | verde nos dois |
| `w135` | rc=0 | rc=0 `OK [4]` | verde nos dois |
| `w146` | rc=0 | rc=0 `OK [7] — 13 gate(s) verificados` | verde nos dois |
| `w147` | rc=0 | rc=0 `OK [8] — 4 hook(s) examinado(s)` | verde nos dois |
| `w151` | rc=0 `PASS (56 cenário(s), 286s)` | rc=0 `PASS (56 cenário(s), 286s)` | verde nos dois |
| `w152` | rc=0 `PASS (32 cenário(s), 56s)` | rc=0 `OK [31]` | verde nos dois |
| `w160` | rc=0 | rc=0 `OK [6]` | verde nos dois |
| `w168` | rc=0 | rc=0 `OK [8]` | verde nos dois |
| `w191` | rc=0 | rc=0 `OK [8] — mutou, reprovou, restaurou, voltou a passar` | verde nos dois |
| **`w190`** | **rc=0 `PASS`** | **rc=0 `PASS`** | **verde nos dois** — medido na revisão 3 |

**A medição de `w190`, e ela cobre mais que D1/D2.** A retratação 3 da §8 escreve a régua "o universo dos gates que o invocam roda inteiro"; a revisão 2 aplicou essa régua **só ao item 1**, com o curto-circuito de D1/D2, e nunca a D7, D9 ou D12. O revisor apontou, e a revisão 3 fechou a lacuna no ponto onde ela morde: `w190[11]` asserta **nominalmente** a recusa de `pre-push:309`, que é um dos dois sítios que a revisão 2 acrescentou à classe de D14 — se D12 mudasse aquele sítio para resolver na árvore do hook, o gate poderia deixar de ver a recusa que ele afirma. Medido em três estados, na mesma bancada, com `bash -n` limpo, `cmp` acusando cada mutação e restauração byte a byte entre elas:

```
$ bash tests/w190-pre-push-gate-reader-gate.sh                       # BASELINE
OK w190/cenarios/universo — 13 cenário(s) de push examinado(s) (canal real (git push))
PASS w190-pre-push-gate-reader                                        rc=0

$ # com o curto-circuito de D1/D2 aplicado ao pre-push da bancada
PASS w190-pre-push-gate-reader                                        rc=0

$ # com D12 aplicado ao sítio pre-push:309 (fallback DENTRO do ramo de recusa) e HOOK_TREE em coluna zero
OK [11] — pre-push BLOQUEADO: este push publica 1 arquivo(s) .sh e .forge/scripts/check-heredoc-hash.sh não existe.
PASS w190-pre-push-gate-reader                                        rc=0
$ grep -ac '^HOOK_LIB_DIR=' template/.forge/hooks/git/pre-push        # âncora do [7] do gate 1
1
```

`w190[11]` sobrevive a D12 porque na fixture dele a árvore do hook e o checkout são a **mesma** — `core.hooksPath` aponta para `$r/.forge/hooks/git`, dentro do próprio repositório de teste —, de modo que o fallback não tem outra árvore onde procurar e a recusa é preservada. Isso é medição, não leitura: eu apliquei D12 ao sítio e rodei. **O que continua não medido, e fica dito em vez de coberto por uma frase genérica:** D7 e D9 não foram rodados contra este universo, porque as duas mudam o `run_check` e o `run_one`, que os treze gates exercitam pelo mesmo caminho de sempre; o passo 9 da §6 é onde isso fecha, e a régua da retratação 3 vale para elas também.

**A causa da quebra de `w97`.** A linha 38 do gate define o payload:

```
$ sed -n '38p' tests/w97-hook-portability-gate.sh
FEED='refs/heads/main 0000000000000000000000000000000000000000 refs/heads/main 0000000000000000000000000000000000000000'
```

São quatro campos não vazios com o **segundo** — o `local_sha` — em sha zero: deleção pura pelo critério literal de D1. O cenário `[3]` asserta `grep -q 'typecheck PULADO'`, e o curto-circuito sai antes de `run_check` existir, de modo que a linha nunca é impressa. A intenção do `w97[3]` não tem nada a ver com deleção — ele testa que o gate JS degrada sem `node_modules` — e o sha zero no `local_sha` é acidente de fixture, não asserção.

**A decisão, e ela é da especificação, não do implementador: o fixture de `w97:38` passa a alimentar um `local_sha` não zero.** Medido nos dois estados, o que prova que a edição é retrocompatível e não um remendo que só funciona depois da implementação:

```
$ # fixture com local_sha = 1111…1, contra o hook COM o curto-circuito
OK [3] (skip sem deps; executa com deps)
PASS w97-hook-portability-gate
$ # fixture com local_sha = 1111…1, contra o hook de HOJE, sem o curto-circuito
OK [3] (skip sem deps; executa com deps)
PASS w97-hook-portability-gate
```

Por isso `tests/w97-hook-portability-gate.sh` está em §0 como arquivo tocado, está na ordem de execução da §6 como passo próprio, e `w97` encabeça a lista nominal do DoD. É a invariante 15 aplicada onde ela nomeia `w97` — e o que a fez falhar na revisão 1 não foi esquecer de varrer, foi varrer por leitura em vez de por execução.

**Os payloads dos demais, para o registro:** `w135[3]` monta 12000 linhas com `local_sha` `aaaa…` (publicação), `w151` usa `refs/heads/main <sha> refs/heads/main <zero>` (publicação de ref nova), e `w152[17]` é o único com `(delete)` mas invoca `check-push-ahead.sh` diretamente, nunca o hook. A leitura estava certa nos três; ela só não era exaustiva, e a execução foi.

**Sobre o espelho no plugin:** `plugin/forge/` contém **apenas** `commands/`, e o `plugin-sync-gate` compara `template/.forge/commands` com `plugin/forge/commands`. Esta onda não toca arquivo algum sob `template/.forge/commands/`, então não há espelho a sincronizar e `npm run build:plugin` não é necessário.

```
$ ls plugin/forge/
commands
$ grep -an 'template/.forge/commands' tests/plugin-sync-gate.sh
3:#   [1] plugin/forge regenerado de template/.forge/commands é byte-idêntico ao commitado
6:#   [3] o plugin achata sem colisão e cobre TODOS os comandos de template/.forge/commands
18:echo "[1] plugin/forge em sincronia com template/.forge/commands"
20:  --commands template/.forge/commands --out "$T/forge" --version "$PKGV" >/dev/null
36:SRC_N="$(find template/.forge/commands -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')"
44:if find plugin/forge/commands template/.forge/commands -name 'skill.md' | grep -q .; then
```

A revisão 2 colava este mesmo comando com `| head -2` e as linhas 20 e 36 como saída. **O `head -2` real devolve as linhas 3 e 6, que são comentário de cabeçalho** — 20 e 36 são a terceira e a quinta ocorrências. O comando não produzia a saída colada; o `head` saiu e as seis ocorrências estão acima, de modo que dá para ver que as duas operativas (`:20` e `:36`) comparam `template/.forge/commands` com `plugin/forge/commands` e nada mais.

**Invariante 14 — todo literal desta especificação que envelhece, e o que fazer com ele.**

| Literal | Onde aparece | Envelhece? | Tratamento |
|---|---|---|---|
| badge `gates-131` | `README.md` | **sim, nesta onda** | dois gates novos ⇒ o badge **tem de** subir para 133; `w200[6]` compara com `find tests -maxdepth 1 -name '*-gate.sh' \| wc -l`, e o valor tem de ser derivado no momento, não copiado daqui. Medido hoje: `grep -n 'gates-[0-9]' README.md` → `12:...gates-131%20passing...` e `find tests -maxdepth 1 -name '*-gate.sh' \| wc -l` → `131`, ou seja, o badge bate com a árvore **agora** e vai deixar de bater no instante em que o primeiro gate novo for escrito |
| `scripts/ (136)` | `README.md:235` | **não nesta onda** | a onda não cria arquivo sob `template/.forge/scripts/` (§0); se o implementador criar um, esta linha sobe junto ou `w200` reprova |
| máximo de ordinal `w207` | §0 | **sim, e talvez hoje** | é fotografia; a alocação é do orquestrador, no momento de escrever, contra `origin/*` e as branches em voo |
| 500 / 688 / 327 linhas dos `pre-push` | §1.1, §2.10 | sim | são medições datadas de 2026-09-07, citadas como evidência de divergência, nunca assertadas por gate |
| 21 worktrees bloqueados, 152 no ecossistema, 58 atrás do hooksPath do Forge | §4.2 | sim | medição de 2026-09-08; o gate asserta a **propriedade** (worktree sem o alvo commita), nunca a contagem. Os números da revisão 1 (50 e 157) mediam falso e foram substituídos, não corrigidos na margem; o do ecossistema já mudou três vezes nesta rodada (88 → 83 → 152), e é a demonstração de por que ele não entra em asserção |
| 21 no `Axis.PadSimulator`, 0 nos demais | §4.2 | sim | idem |
| 271 linhas do `pre-commit` do `azim-crm`, 19 recusas locais | §4.5 | sim | medição datada, e é o que sustenta o ack — se o número mudar, o ack precisa ser refeito, não o gate |
| `DECLARADOS=15` e `DECLARADOS=20` dos dois gates novos | fonte dos gates | **não** | universo fechado do próprio gate; a exceção legítima da invariante 14 |
| mapa `COBERTOS` do cenário `[19]` (doze `<arquivo>:<linha>`) e `EXCLUIDOS` (três) | fonte do gate 2 | **sim, e de propósito** | envelhecer é a função: quando um sítio da classe muda de lugar, o gate reprova e obriga a reauditar a classe — que é o passo que ninguém deu entre a revisão 1 e a 2. As linhas são preenchidas pelo implementador contra a árvore, nunca copiadas desta especificação |
| 12 sítios da classe de delegação, 15 recusas na varredura ampla | §0, §4.3 | **sim** | e é justamente por isso que o cenário `[19]` do gate 2 **recomputa** a varredura em tempo de execução em vez de comparar com estes números. A tabela de §0 passou a derivar a contagem por arquivo da MESMA varredura, em vez de repeti-la à mão — foi assim que a revisão 2 perdeu um sítio de `pre-push` |
| 300 s do `FORGE_GATE_TIMEOUT_S` | §3.1 | não | é o default do código, citado do fonte |
| tamanhos e rc das bancadas | §2, §3, §4 | sim | são o vermelho a reconhecer; a asserção é sobre a propriedade, e o gate imprime o que ele mesmo mediu |

---

## 8. Retratações de método desta especificação

Treze, e as treze são minhas. As duas primeiras são da revisão 1, escritas antes de qualquer revisor olhar; as cinco seguintes são da revisão 2, e três delas — a terceira, a quarta e a sexta — foram apontadas pelo revisor e confirmadas por remedição minha; as seis últimas são da revisão 3, e a décima primeira eu achei sozinho, medindo o que ninguém tinha me pedido para remedir.

**A primeira.** Escrevi a mutação `M-141` — trocar `pwd -P` por `pwd` na comparação de caminhos do fallback — esperando que ela mordesse, porque eu tinha acabado de medir que `/var` e `/private/var` divergem no macOS. Rodei, e ela saiu **no-op**: o checkout principal continuou commitando sem imprimir a linha de fallback, antes e depois da mutação, com o `cmp` confirmando que o arquivo mudou. A causa é que o ramo do fallback só é avaliado quando o alvo primário está ausente, e no checkout principal as duas árvores são a mesma, de modo que a comparação de caminhos é **inalcançável**. A regra do plano-mestre diz que num no-op quem se corrige é o cenário, e aqui a conclusão foi mais forte: a comparação de caminhos é **redundante**, porque o teste de existência na árvore do hook já basta. Removi a comparação, remedi as três formas, e as três continuam discriminando (§4.3). O trecho ficou mais curto e sem a superfície do symlink. A medição do `/var`→`/private/var` continua na §4.3 como o motivo de a alternativa por `GIT_DIR != COMMON_DIR` ter sido descartada — que é onde ela morde de verdade.

**A segunda.** Escrevi a enumeração de formatos de push com cinco casos e a chamei de completa antes de testá-la. Ao procurar ativamente o sexto, como a invariante 17 manda, encontrei `[J]`: uma linha com dois campos, sendo o segundo o sha zero, é classificada como deleção e faz a suíte inteira ser pulada. É a invariante 2 violada dentro do próprio remédio, e ela virou a decisão D4 e o cenário `[6]`. Sem procurar, a onda teria entregue um curto-circuito que colapsa "não consegui classificar" com "nada a provar" — exatamente o defeito que a issue #132 descreve, na correção da issue #132.

**A terceira, e ela é a maior — da revisão 2.** Escrevi em §7 que "nenhum gate existente quebra pelo curto-circuito" tendo **lido** o formato de payload de três gates. O revisor mediu e achou o quarto; eu remedi e confirmo: `w97` vai de `PASS` a `FAIL [3]` contra a implementação correta de D1/D2, porque `w97:38` alimenta quatro campos com o `local_sha` em sha zero, que é deleção pura pelo critério literal da minha própria decisão. O erro não foi deixar de varrer — a varredura estava lá, com os doze gates enumerados corretamente. O erro foi **concluir por leitura o que só a execução decide**, e a leitura estava certa nos três gates que eu li e muda a nada sobre o quarto que eu não li. A régua que fica: quando a mudança é de comportamento do hook, o universo dos gates que o invocam roda inteiro, um a um, antes de a especificação afirmar qualquer coisa sobre eles. A revisão 2 escreveu aqui "está feito em §7.1, doze de doze", e **doze era o universo errado** — ver a retratação 13.

**A quarta.** Escrevi que a classe de D14 era enumerável por `grep -rn 'existe mas' template/.forge/hooks/` e chamei o resultado de completo. Uma varredura por **desfecho** em vez de por **frase** devolve quinze recusas onde o idioma pegava dez, e as cinco a mais incluem duas que são exatamente da classe (`pre-push:309` e `check-red-first.sh:93`). É a invariante 17 — enumeração falsamente exaustiva — cometida dentro do parágrafo que citava LDG-0171 para condenar "consertar um e deixar oito". A saída não foi corrigir o numeral: foi trocar o predicado e, sobretudo, escrever o cenário de auto-ironia do gate 2 (`[13]` na revisão 2, `[19]` desde a revisão 3), que **recomputa** a varredura em tempo de execução — porque uma lista escrita à mão numa especificação envelhece no primeiro hook novo, e a lista da revisão 1 já tinha envelhecido antes de ser escrita.

**A quinta.** Escrevi que a bancada de mutação usaria `perl -0pi -e` com aspas simples e `$` escapado, citando LDG-0164 como a lição aprendida. Rodei, e o perl abortou com `syntax error at -e line 1, near "-}"` nos padrões desta onda, que contêm `${_pp_ls:-}` — a mutação saiu no-op e só o `cmp` de controle acusou. É a invariante 19 no parágrafo em que eu a estava citando: **prescrevi um mecanismo que eu não tinha executado com os padrões desta onda**. A prescrição saiu da §2.6 e no lugar dela ficou a propriedade — bytes mudam, `bash -n` limpa, comportamento muda — com o primitivo entregue ao implementador, que executa.

**A sexta.** Colei em §4.3 uma forma `[c]` ("worktree e tronco, ambos sem o alvo → BLOQUEADO, rc=1") que **mede falso** na fixture que eu construí. Ao rerodá-la, o commit passou com `pre-commit OK` e rc 0: o `.forge/scripts/` do tronco era diretório vazio, o git não versiona diretório vazio, o worktree nascia sem ele, e a pré-condição `[ -d "$ROOT/.forge/scripts" ]` do guard nunca era alcançada. O cenário aprovava por não ter olhado — falso-verde de fixture, a família da invariante 3, dentro da seção que ensina a evitá-la. A correção é do fixture, e ela virou obrigação normativa dos cenários `[2]` e `[3]` do gate 2.

**A sétima, pequena e cara.** Colei a linha de fallback sem acentuação — "resolvido na arvore do HOOK … este checkout nao o tem" — que é artefato de bancada e é justamente o texto que vira string de produção com gate afirmando-a. Corrigida em §4.3, e ela nasce acentuada.

**A oitava, e é a pior da revisão 3, porque eu escrevi a explicação da saída em vez de rodar o comando.** A terceira varredura da §1.2 estava colada como `grep -arn 'push\.refs\|push_refs' template/ | grep -v FORGE_PUSH_REFS` com `rc=0` e a glosa "casa só ocorrências de `FORGE_PUSH_REFS_FILE`, que o filtro remove". O padrão é minúsculo, o identificador é maiúsculo, o primeiro `grep` casa **zero** linhas e o pipeline devolve `rc=1`. Não é um erro de transcrição: é uma **explicação inventada para uma saída que eu não observei**, num documento cuja regra de abertura é que toda afirmação numérica traga o comando que a produziu. Pior, ela é da mesma família do LDG-0177 que o cabeçalho deste arquivo ensina: eu li um vazio e contei uma história sobre ele em vez de pôr um controle positivo ao lado. A varredura foi trocada por uma correta, com o controle positivo no meio (§1.2), e a conclusão — que não sobrevivia àquele comando — se sustenta pelo caminho que sempre esteve ao lado dela.

**A nona.** Colei em §7 o comando do espelho do plugin com `| head -2` e com as linhas 20 e 36 como saída. O `head -2` devolve as linhas 3 e 6, que são comentário de cabeçalho; 20 e 36 são a terceira e a quinta ocorrências. Recortei a saída para as linhas que sustentavam a conclusão e apresentei o recorte como se fosse o que o comando imprime. O `head` saiu, as seis ocorrências estão coladas, e o leitor vê o que eu vi.

**A décima.** Colei em §3.3 `template/.forge/scripts/run-gates.sh:2` como controle positivo; a contagem é **1**. O controle continuava cumprindo o papel — o arquivo é legível e contém o token — e por isso o erro passou por duas revisões: um número errado dentro de um controle que funciona não muda a conclusão e por isso ninguém o confere. Acrescentei o `grep -an` que mostra as linhas, que é o que distingue chamada de menção em comentário e o que torna o controle conferível.

**A décima primeira, e ela é minha por inteiro, porque ninguém a apontou.** O cenário `[4]` do gate 2 estava listado entre os que "falham hoje por ausência real", com a justificativa "idem [1]: não há fallback". Fui medir para escrever o vermelho dele e ele **nasce verde**: `[4]` põe o alvo no próprio worktree, `$ROOT/.forge/scripts/check-secrets.sh` existe ali, e o hook de hoje já resolve certo — `pre-commit OK`, rc 0, marca do worktree presente, marca do tronco ausente, zero linhas de fallback. Eu tinha copiado a justificativa de `[1]` para uma fixture que não é a de `[1]`. O contador "oito dos quatorze falham hoje" estava errado por isso também, e a correção mudou a classificação do cenário, não o numeral: `[4]` é controle de precedência, e quem o faz morder é M12.

**A décima segunda.** Escrevi que o cenário de auto-ironia usava "o idioma que `w147[8]` já usa para os hooks" e declarei 14 cenários. O `COBERTOS` de `w147[8]` é por **arquivo**; a mensagem de falha que eu escrevi para o cenário é por **sítio**; e as duas leituras dão vereditos opostos — uma deixa o gate impossível de ficar verde com denominador fixo, a outra o deixa verde afirmando cobrir doze sítios enquanto seis não têm asserção nenhuma. Escrevi uma guarda contra "consertar um e deixar doze" cuja regra de cobertura eu não tinha decidido, e deixei a escolha para o implementador descobrir com a suíte na mão. A unidade agora está em letra — **sítio** —, os seis sítios descobertos ganharam cenário próprio com o vermelho de cada um medido, e `DECLARADOS` foi de 14 para 20.

**A décima terceira, e ela é a retratação 3 uma camada abaixo.** Depois de me corrigir por concluir por leitura o que só a execução decide, defini o universo de §7.1 por `grep -arln 'hooks/git/pre-push' tests/` — um **literal de caminho** — e chamei os doze de exaustivos. O `w190` executa o `pre-push` pelo canal real, com `git push` e `core.hooksPath` absoluto, e nunca escreve aquele literal: ele estava no meu próprio DoD como gate que precisa ficar verde e fora da tabela que prometia tê-lo medido. Corrigi o método e mantive o predicado errado, que é a forma mais cara de errar — a régua nova foi aplicada a um universo que ela mesma não delimitava. O predicado passou a ser "executa o `pre-push`", medido por invocação direta **ou** por `git push` com `hooksPath`; são treze, e o décimo terceiro foi rodado em três estados. Registro junto o limite que sobra: eu apliquei essa régua a D1/D2 e a D12, nunca a D7 nem a D9, e isso está dito em §7.1 em vez de coberto pela frase "o universo roda inteiro".

---

## 9. Respostas ao veredito da revisão 1

> **Esta seção é registro do que a revisão 2 fez, e os números dela são os de então.** Onde a revisão 3 mudou um número ou uma numeração de cenário, a §10 diz qual e por quê: o gate 2 foi de `DECLARADOS=14` para `20` e o cenário de auto-ironia deixou de ser o `[13]` e passou a ser o `[19]`; as contagens de worktree do `axis-go-cloud` e do ecossistema foram remedidas de 83 e 149 para 86 e 152; e a tabela de §0 passou a listar 6 sítios de `pre-push` e 12 no total, contra os 5 e 11 que a revisão 2 deixou.

Quatro bloqueadores e onze medições sem lastro. **Nenhuma refutação: os quatro bloqueadores reproduzem, cada um com bancada minha, e três deles ficaram piores do que o revisor mediu.** As respostas abaixo dizem o que mudou no documento, não o que eu penso da crítica.

### Os quatro bloqueadores

**Bloqueador 1 — `w97[3]` quebra e a §7 afirmava o contrário. FECHADO, e a medição foi ampliada.** Reproduzi na minha própria bancada: cópia de `template/.forge/hooks/` e de `tests/w97-hook-portability-gate.sh` sob `$TMPDIR`, controle `PASS`, curto-circuito de D1/D2 inserido depois da escrita de `FORGE_PUSH_REFS_FILE`, `bash -n` limpo, `cmp` acusando diferença, gate → `FAIL [3] (esperava aviso de skip)`, restauração por `cp`, `cmp -s` byte a byte, gate → `PASS` de novo. Em vez de parar no gate que o revisor achou, rodei **os doze** que citam o `pre-push`, contra o baseline e contra a implementação: onze verdes nos dois estados, `w97` o único que quebra (§7.1). A decisão está tomada na especificação, não delegada: `w97:38` passa a alimentar `local_sha` real, e medi que o gate passa com o fixture novo **nos dois** estados do hook, o que torna a edição retrocompatível em vez de remendo. `w97` entrou em §0, na ordem da §6 e encabeça a lista nominal do DoD.

**Bloqueador 2 — D7 apoiada em premissa que não vale no processo alvo. FECHADO, com D7 reescrita.** Reproduzi a contaminação com hook instrumentado e contraprova de uma variável só (`gates:` declarado versus não declarado, mesmo hook, mesmo check): `typecheck` e `test` com a variável `<UNSET>`, `check-marca` e `harness-tests` com `300`, porque `pre-push:401` sourceia `forge-runtime.sh` entre os dois pares de `run_check` e `forge-runtime.sh:20` injeta o default. D7 foi partida em duas metades: **de onde o orçamento é lido** — um snapshot tomado antes de qualquer `source`, cuja uniformidade nos quatro checks e nos três estados eu medi e colei — e **qual é o default**, que continua "sem teto" pelo mesmo argumento de sempre. O cenário `[10]` passou a fixar o check (`harness-tests`) e a fixture (`gates:` declarado), e nasceu o cenário `[15]`, que asserta que a política é a mesma para `typecheck` e para `harness-tests` no mesmo push — a guarda que reprova a implementação ingênua. `DECLARADOS` do gate 1 subiu de 14 para 15, e a mutação `M8b` é a que morde exatamente ali.

**Bloqueador 3 — contradição entre §0 e D14, com a contagem errada. FECHADO a favor de D14, e a contagem estava errada nos dois sentidos.** A varredura por `existe mas` devolve dez e a especificação dizia nove; mas o defeito maior é que **o idioma não é a classe**: uma varredura por desfecho devolve quinze recusas, das quais doze são da classe, incluindo `pre-push:309` e `check-red-first.sh:93` que o idioma não pegava. §0 passou a listar **sete** arquivos de produção, o DoD cobra `bash -n` nos sete, e o gate 2 foi de `DECLARADOS=8` para `DECLARADOS=14`, com cenário próprio para `commit-msg`, `pre-push`, `post-merge`, `check-red-first.sh` e `harness-tests`, mais o cenário `[13]` de auto-ironia que recomputa a classe em tempo de execução (renumerado para `[19]` na revisão 3, com `DECLARADOS` em 20 — §10). Sobre `pre-push:480`, que o revisor apontou como mudança de custo não medida: **medi**. `run-all.sh:25` ancora o universo no `dirname` do próprio arquivo e o hook invoca sem `--path`, então o fallback ingênuo faria o worktree rodar o corpus do tronco — `2 arquivo(s) examinado(s)` contra `1 arquivo(s) examinado(s)` na bancada. O sítio entra na classe com o corpus ancorado explicitamente no checkout, e o cenário `[12]` asserta a contagem do worktree contra a do tronco. As três exclusões (`pre-push:176`, `:391`, `:455`) estão escritas com motivo cada uma, em tabela, e não por omissão.

**Bloqueador 4 — a medição de exposição de §4.2 não reproduz. FECHADO, e o erro era de método.** Confirmo tudo: o `pre-commit` instalado do `azim-crm` tem 271 linhas, diverge do template e não contém uma ocorrência de `check-secrets`; os 28 worktrees dele **não** estão bloqueados. Remedi com o predicado certo — o hook instalado contém a delegação? — e o total cai de 50 em três repositórios para **21 num só**, o `Axis.PadSimulator`. Também remedi o ecossistema: 149 worktrees linkados e 58 atrás do `hooksPath` do Forge, não 157 e 61 (remedido de novo para 152 na revisão 3 — §10). A §4.5 foi reaberta e inverteu: **o `azim-crm` precisa de aviso antes do update**, porque `hooks` está em `MACHINERY_DIRS` (`bin/forge.mjs:307`) e fora de `ENRICHABLE_DIRS` (`:352`), e o arquivo dele registra em comentário que um overlay anterior já apagou trabalho local uma vez. A frase "o único dos três itens desta onda cuja propagação é limpa" foi **removida**, não reescrita: nenhum dos três tem propagação limpa. O que não mudou é D11 e D12 — o defeito reproduz no template, com a mensagem literal da issue, e um defeito de produto não deixa de existir porque poucos o sofrem hoje.

### As onze medições sem lastro

Seis remedidas com comando colado, duas corrigidas por medição nova, uma trocada por lastro de procedência, duas substituídas. **Nenhuma ficou no documento sem comando ao lado.**

| Medição | Desfecho | Onde |
|---|---|---|
| §3.1, contrafactual de `run_check` ("rc=0, decorrido=9s") | **remedida**: `decorrido=6s`, com comando executável e `local_sha` real; o `9s` era irreprodutível e saiu | §3.1 |
| §3.1, as três medições finas (rc 142 ambíguo, alarm não alcança o neto, log do morto) | **remedidas** numa execução só, com a saída das quatro linhas colada | §3.1 |
| §2.6, matriz M1/M2/M3 e a saída integral | **remedida**: bancada reconstruída do zero, M1/M2/M3 refeitas e **M4 saiu de "A MEDIR" para MEDIDO**; M5 medida estaticamente por índice de linha | §2.6 |
| §2.6, prescrição do `perl -0pi -e` | **removida**: rodei e saiu no-op nos padrões desta onda; ficou a propriedade, não o primitivo | §2.6, §8 |
| §3.2, fixture de quatro testes e o contrafactual do anúncio-antes | **remedida**, com `cmp` e `bash -n` no contrafactual e as duas saídas coladas | §3.2 |
| §4.3, as três formas do fallback e a linha de fallback | **remedidas** com implementação nova de D12 e `git commit` real; a forma `[c]` **media falso** e virou retratação; a linha nasce acentuada; entrou uma quarta forma `[d]` para a precedência | §4.3, §8 |
| §4.2, tabela de exposição inteira | **substituída** pelo predicado certo | §4.2 |
| §2.10, "`azim-crm` é byte-idêntico ao template" (pre-push) | **corrigida**: 189 linhas, `DIVERGE`; o byte-idêntico é o `lionclaw`, que a revisão 1 nem listava | §2.10 |
| §1.1, curto-circuito do `axis-fare-validator` em `:33-67` e carimbo em `:380` | **remedida por inspeção dos trechos**, e ela rendeu um achado: a implementação dele usa o booleano que D1 recusa | §1.1 |
| §2.3, números de campo do consumidor | **mantidos com lastro de procedência**: não são reproduzíveis nesta máquina, então cada um traz a linha do corpo da issue e o item de ledger do consumidor que o produziu, e a especificação diz em letra que são relato citável, não medição minha | §2.3 |
| §0, "o máximo publicado é w207" | **remedida** sobre todas as refs remotas em vez de uma lista escrita à mão; continua 207 | §0 |
| §3.4, "o schema já tem três `timeout_s`" | **corrigida**: são quatro, e o quarto é `runtime.pentest.strix.timeout_s`, enumerado pelo próprio JSON em vez de contado por linha | §3.4 |

### As ressalvas

- **Numeral de D14** — resolvido junto com o bloqueador 3, e para um número diferente do que a ressalva pedia: não é nove nem dez, é doze na classe, de quinze recusas.
- **Acentuação da linha de fallback** — corrigida, e a linha nasce acentuada (§4.3).
- **Âncora do cenário `[7]`** — fixada: `^HOOK_LIB_DIR=`, ancorada em início de linha, e medi que ela é única (1 de 5 ocorrências do identificador). O gate reprova se ela deixar de ser única, para que um refactor que duplique a atribuição não faça a comparação silenciosamente contra a ocorrência errada.
- **Nível unitário do parser de refs** — mantido como "não se aplica", com o registro que a ressalva pede: o parser é o tipo de unidade que a invariante 5 nomeia, o PBT de §2.7 o cobre pelo canal do hook, e isso custa tempo de relógio real. O `forAll` publica `runs` e `seed`, e o custo de execução dentro do gate é responsabilidade do implementador ao escolher `runs` — um PBT que rode zero casos aprova por não ter olhado, e um que rode mil torna a suíte impagável.
- **Checagem de citações de linha** — registro que ela foi refeita nesta revisão para todas as citações novas, e que as citações da revisão 1 que o revisor amostrou continuam conferindo.

---

## 10. Respostas ao veredito da revisão 2

Um bloqueador remanescente, um bloqueador novo, quatro medições sem lastro e seis ressalvas. **Nenhuma refutação: os dois bloqueadores reproduzem, as quatro medições sem lastro reproduzem, e as seis ressalvas reproduzem — remedi cada uma com comando meu antes de aceitar a afirmação do revisor, e uma delas rendeu um defeito que ninguém tinha apontado (o cenário `[4]`, retratação 11).**

### O bloqueador remanescente

**Resíduo do bloqueador 3 — §0 conta 5 sítios de `pre-push` e 11 no total, contra os 6 e 12 de D14. FECHADO, e a correção é de método, não de numeral.** Reproduzi a varredura ampla e ela devolve as quinze recusas, com nove no `pre-push`; três estão fora da classe com motivo escrito, restam seis, e com 1 + 1 + 2 + 2 dos outros quatro arquivos o total é doze. O revisor está certo em cada número. **A causa é que a tabela de §0 era escrita à mão enquanto D14 era derivada de comando** — foi por isso que a contradição que a revisão 1 mandou reconciliar voltou em escala menor, no arquivo onde ela sumiria sob a leitura por arquivo do cenário de auto-ironia. A correção não foi trocar 5 por 6: §0 passou a **derivar** a contagem por arquivo da mesma varredura, com o `uniq -c` colado e a tabela `recusas → fora da classe → na classe` que fecha em 12, e §4.3 traz a mesma tabela para que as duas seções não possam divergir de novo sem que o mesmo comando as contradiga.

### O bloqueador novo

**Cenário `[13]` do gate 2 — a regra de cobertura não era decidível, e as duas leituras eram defeituosas. FECHADO, e o diagnóstico do revisor está inteiro: eu escrevi uma guarda cuja regra eu não tinha decidido.** Reproduzi a enumeração: a classe tem doze sítios, os quatorze cenários exercitavam seis, e ficavam sem cenário `pre-push:41`, `pre-push:73`, `pre-push:234`, `pre-push:309`, `post-merge:39` e `check-red-first.sh:89`. Sob a leitura por sítio — a que a minha própria mensagem de falha escreve e a que M16 exige — o gate nunca poderia ficar verde com `DECLARADOS=14` fixo. Sob a leitura por arquivo — a de `w147[8]`, que eu citei como modelo — o gate ficaria verde afirmando cobrir doze sítios enquanto seis mudavam sem asserção. **A escolha está no documento agora, em letra: coberto = SÍTIO**, e ela está no primeiro parágrafo da §4.4 como frase normativa, não como comentário.

Os seis sítios descobertos ganharam cenário próprio — `[13]` a `[18]` —, o cenário de auto-ironia passou a `[19]`, o contador de controle a `[20]` e `DECLARADOS` foi de 14 para 20. **O vermelho de cada um dos seis foi medido, não presumido**, com o hook de hoje rodado da árvore de bancada contra um checkout que não tem o alvo: `pre-push:41` devolve `BLOQUEADO: <...>/hooks/git/lib existe mas check-docs-reviewed.sh não`; `pre-push:73` devolve `BLOQUEADO: .forge/scripts/ existe mas check-ai-attribution.sh não`; `pre-push:234` devolve `BLOQUEADO: .forge/scripts/lib/ existe mas heavy-mutex.sh não`; `post-merge:39` devolve `FALHOU: .forge/scripts/lib/ existe mas changelog-from-merge.mjs não`; `check-red-first.sh:89` devolve `BLOQUEADO: .forge/scripts/ existe mas check-red-first.sh não`; e `pre-push:309` já tem a recusa assertada nominalmente por `w190[11]`. As saídas estão coladas na coluna "Por que falha por ausência real" da tabela de §4.4.

O `[19]` também deixou de ser uma promessa: ele declara um mapa `COBERTOS` de `<arquivo>:<linha> → <cenário>` com doze entradas e um `EXCLUIDOS` com três, recomputa a varredura, e reprova em três direções — sítio da classe sem entrada, entrada apontando para cenário que não rodou, e entrada que não casa mais nenhuma linha da varredura. A terceira é a que impede o modo de falha silencioso que a revisão 2 sofreu: uma lista que envelheceu e passou a não casar nada.

**Ao varrer o resto do documento atrás do efeito colateral desta correção, achei um defeito que o revisor não tinha apontado.** O cenário `[4]` estava listado entre os que falham hoje; medi e ele nasce verde, porque a fixture dele põe o alvo no próprio worktree. Está na retratação 11, e mudou o contador de "oito dos quatorze" para "treze dos vinte" com quatro controles negativos em vez de três.

### As quatro medições sem lastro

Todas reproduzidas com comando meu, e **todas as quatro reprovam a favor do revisor**. Nenhuma sobrou no documento sem comando ao lado.

| Medição | Desfecho | Onde |
|---|---|---|
| §1.2, terceira varredura (`push_refs` com `rc=0` e a glosa do filtro) | **substituída**. O padrão casa zero linhas em `template/` porque é minúsculo e o identificador é maiúsculo; o pipeline devolve `rc=1`. A explicação era inventada. A varredura nova é `grep -arni 'push[._]refs'`, com o controle positivo no meio: 5 ocorrências, 5 removidas pelo filtro, `rc=1` de ausência real | §1.2, retratação 8 |
| §7, espelho do plugin (`head -2` com as linhas 20 e 36) | **corrigida**. O `head -2` devolve as linhas 3 e 6; 20 e 36 são a terceira e a quinta ocorrências. O `head` saiu e as seis ocorrências estão coladas | §7, retratação 9 |
| §3.3, controle positivo (`run-gates.sh:2`) | **corrigida**: é 1, e a única chamada está em `:101`. Entrou o `grep -an` que mostra as linhas, porque a contagem sozinha não distingue chamada de comentário — no `spec-verify.sh` uma das duas é comentário | §3.3, retratação 10 |
| §4.2 e §4.5, worktrees do `axis-go-cloud` (83) e do ecossistema (149) | **remedidas**: 86 e 152 hoje, os mesmos que o revisor mediu. A revisão 1 tinha medido 88. Entrou um parágrafo dizendo que esse número mudou três vezes nesta rodada e que por isso nenhuma contagem de worktree entra em asserção de gate; os dois que carregam decisão — 21 bloqueados e 58 atrás do `hooksPath` do Forge — reproduzem estáveis | §4.2 |

### As seis ressalvas

Nenhuma foi tratada como "não bloqueia, então fica" — cinco viraram texto normativo e uma virou linha de matriz corrigida.

- **D12 sem a pré-condição de engate.** Reproduzi o achado do revisor: aplicar a letra de D12 sem guarda faz o hook de uma árvore executar contra um repositório que não tem `.forge/` nenhum. D12 passou a dizer, em negrito, que **o fallback vive dentro do ramo de recusa que já existe**, nunca antes dele — assim o no-op é preservado por construção e não por lembrança, e cada um dos doze sítios já traz a guarda que o protege (`pre-commit:75`, `commit-msg:29`, `pre-push:40,72,112,233`, `post-merge:38,58`, `check-red-first.sh:88`, mais o ramo "há `.sh` a varrer" de `pre-push:309`). Medi as duas metades juntas: no-op preservado no repositório sem harness, **e** fallback engajando no checkout que tem `.forge/scripts/` sem o alvo — porque a primeira sozinha é satisfeita por um fallback que nunca dispara. O custo da pré-condição está registrado em letra: o worktree cuja branch não tem `.forge/` segue sem gate algum, que é o desfecho que D11 chama de estritamente pior. Virou também a mutação M18.
- **A fórmula `dirname "${BASH_SOURCE[0]}"/../../..` erra por um nível na lib.** Reproduzi com sonda nos dois arquivos: no hook resolve a raiz, na lib resolve `.forge/`. `HOOK_TREE` passou a ser derivado **uma vez** no hook e **injetado** nas libs pelo mesmo idioma que o `REPO` já usa (`pre-push:50,61`), com um default próprio de profundidade `../../../..` para o uso standalone que o cabeçalho da lib declara. Virou a mutação M17, e os cenários `[11]` e `[18]` são os dois que a mordem.
- **§7.1 definia o universo pelo literal de caminho e concluía "doze de doze".** Reproduzi: dezenove gates mencionam o `pre-push`, doze casam o literal, e treze o **executam** — o décimo terceiro é o `w190`, que empurra pelo canal real com `core.hooksPath` absoluto. O predicado foi trocado por "executa o `pre-push`", os seis que mencionam sem executar estão nomeados um a um com o motivo, e `w190` entrou na tabela **medido**: verde no baseline, verde com D1/D2, e verde com D12 aplicado ao `pre-push:309` — que é o sítio cuja recusa o `w190[11]` asserta nominalmente. A régua da retratação 3 ("o universo dos gates que o invocam roda inteiro") tinha sido aplicada só ao item 1, e isso agora está dito onde estava coberto por uma frase genérica: D7 e D9 continuam não rodados contra este universo, e o passo 9 da §6 é onde fecham. Virou a retratação 13, porque o defeito não é do revisor ter achado o décimo terceiro gate — é de eu ter corrigido o método na revisão 2 e mantido o predicado errado.
- **A âncora `^HOOK_LIB_DIR=` do cenário `[7]` do gate 1 tem de continuar única depois de D12.** Medi antes e depois: 1 ocorrência ancorada, de 5 do identificador, e a forma de D12 da bancada acrescenta `HOOK_TREE=` em coluna zero sem duplicar a âncora. Está escrito em D12 como obrigação, para que o implementador não fabrique o vermelho.
- **O DoD pedia `local_sha` real em `w97:38` e a fixture faz `git init` sem commit.** Trocado por **não zero**, que é o que a bancada de §7.1 de fato usou (`1111…1`).
- **A linha M8 da matriz de §3.5.** Corrigida para `FAIL [10]` **e** `FAIL [15]`, com o motivo escrito: `[15]` compara a política reportada entre `typecheck` e `harness-tests`, e política silenciada não é comparável. Continua `A MEDIR`, porque o alvo não existe — mas deixou de afirmar um efeito que a leitura já contradizia.
