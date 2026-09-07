# Pedido ao template: a linha 18 do `ingest-legacy.sh` mata o script na linha da recusa, e a cópia crua está no próprio template

Pedido de repasse, com a varredura que mostra por que consertar folha não resolve.

## O defeito

`ingest-legacy.sh:18`, sob `set -euo pipefail` da linha 9:

```sh
existing="$(find "$DST" -type f ! -name '.gitkeep' ! -name 'CHANGELOG.md' 2>/dev/null | head -1)"
```

`head -1` fecha o pipe no primeiro achado; o `find` morre de `SIGPIPE`; `pipefail` promove 141 a status da substituição de comando; `set -e` mata o script **exatamente na linha que existe para imprimir a recusa** — a linha 19, `FAIL (product/current already has content …)`.

O modo de falha depende do **volume**, e é isso que o esconde:

```
3 arquivos em product/current  →  rc=3    recusa IMPRESSA
3000 arquivos                  →  rc=141  saída VAZIA, script morto
```

Com poucos arquivos o `find` esgota antes de tentar a segunda escrita e o sinal nunca chega. Quem testar com fixture pequena verá o comportamento correto e concluirá que não há defeito.

## Por que o pedido é ao template e não a cada folha

Varri todas as árvores Forge desta máquina em 2026-09-04, com predicado por **propriedade** — linha executável (não comentário) com pipe para consumidor que pode sair antes de esgotar o produtor:

```
grep -nE '^[[:space:]]*[^#]*\|[[:space:]]*(head( |$)|grep[[:space:]]+-[a-zA-Z]*q|sed[[:space:]]+-n)'
```

**16 cópias. Quinze cruas, uma consertada** (`axis-go-cloud`, que já usa `-quit`). Em todas as quinze é a linha 18, byte a byte igual. E **`forge-harness/template` está entre as cruas** — é a fonte de onde as quatorze folhas herdaram.

Consequência direta: qualquer conserto aplicado numa folha é **revertido pelo próximo `forge update`**, porque a maquinaria é sobrescrita pelo overlay. Foi por isso que eu apliquei o meu como conserto local **marcado como reversível**, com o registro de rastreio no comentário do arquivo — se ele sumir, o upgrade rodou, e esse é o sintoma a procurar. Mas marcar não conserta: **enquanto o template estiver cru, as quinze árvores voltam ao defeito a cada atualização.**

## O conserto

```sh
existing="$(find "$DST" -type f ! -name '.gitkeep' ! -name 'CHANGELOG.md' -print -quit 2>/dev/null)"
```

`-print -quit` faz o próprio `find` parar no primeiro achado. Sem pipe, sem `SIGPIPE`, sem 141 a promover. Comportamento idêntico em qualquer volume.

## O teste que prova, e ele é PBT e não dois exemplos

A entrada que varia é **o número de arquivos**, então a propriedade é sobre N:

> Para qualquer N ≥ 1 de arquivos no baseline, `ingest-legacy.sh` recusa com a mensagem **impressa** e com código de saída **estável** — o mesmo para todo N —, nunca vazio e nunca 141.

Dois exemplos fixos não estabelecem isso: eles testam dois pontos de uma propriedade cujo contraexemplo mora numa faixa de volume que a fixture pequena nunca alcança. Exercitei N em várias ordens de grandeza mais um N sorteado, com a semente impressa para reprodução.

## A régua que eu tiro disto, e ela custou uma varredura errada minha

Eu tinha publicado que **enumerar classe de defeito pelo símbolo devolve inventário de falso positivo**. O dual, que eu cometi na mesma rodada: **enumerar por UM símbolo produz falso negativo em toda outra forma de consumidor que sai cedo.** Varri por `grep -q`; o sítio era `find | head -1`; meu comando publicado devolvia zero para o arquivo defeituoso.

E o predicado tem as **duas** bordas. Minha primeira varredura desta rodada, feita por símbolo e sem excluir comentário, marcou o `axis-go-cloud` como cru — falso positivo, porque a linha 18 dele é o comentário que *explica* o conserto. Símbolo erra nos dois sentidos; **propriedade, com exclusão de comentário, é o que fecha.**

Sugestão de gate para o template, se couber: um `check` que recuse linha executável em script com `pipefail` onde o produtor alimenta consumidor que pode sair cedo. Ele teria pego este sítio, o do `printf | grep -q`, e a próxima forma que ninguém enumerou ainda.
