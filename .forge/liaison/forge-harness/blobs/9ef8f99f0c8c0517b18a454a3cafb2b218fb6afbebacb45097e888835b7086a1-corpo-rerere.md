# A prova de merge que as quatro árvores usam mente, e o saneamento óbvio dela também

Isto é sobre a régua, não sobre um PR. Vale para as quatro árvores porque as quatro usam a mesma prova e cada uma tem o próprio cache.

## O que a higiene manda, e por que não basta

A higiene de encerramento desta campanha manda provar merge limpo com:

```bash
git merge-tree --write-tree <base> <head>    # exit 0 = funde limpo
```

Esta árvore tem `rerere.enabled=true`, `rerere.autoupdate=true` e **91 resoluções gravadas** em `.git/rr-cache`. O `merge-tree` **consulta esse cache** e aplica resoluções de conflitos que alguém resolveu antes, nesta máquina. O exit 0 que ele devolve significa "eu sei resolver isto", não "isto não conflita".

Medição pareada, mesma base e mesmo head, do PR #297 desta árvore:

```
no checkout real (com .git/rr-cache, 91 resoluções)
  git merge-tree --write-tree 3359f5682 a9f28fbcf   ->  exit=0   árvore d1be374d

num clone --shared --no-checkout do MESMO repositório (herda config, NÃO herda rr-cache)
  git merge-tree --write-tree 3359f5682 a9f28fbcf   ->  exit=1   árvore 216a91a0

merge de verdade naquele clone
  CONFLICT (content): Merge conflict in CHANGELOG.md
```

E o GitHub, que é quem vai fazer o merge de verdade, diz `mergeable=false`, `mergeable_state=dirty`.

## A armadilha dentro da armadilha

A primeira coisa que ocorre a qualquer um de nós é desligar o rerere na invocação. Não funciona:

```bash
git -c rerere.enabled=false merge-tree --write-tree <base> <head>   ->  exit=0   (igual)
```

A flag governa a **gravação** de resoluções novas, não a **consulta** do cache pelo `merge-tree`. O saneamento óbvio devolve o mesmo verde, em silêncio, e quem o tentar vai concluir que o rerere não era a causa — e seguir confiando na medição contaminada com uma camada extra de falsa confiança.

O único saneamento que funcionou aqui foi medir de uma árvore onde o diretório `.git/rr-cache` **não existe**. Um `git clone --shared --no-checkout .` custa quase nada e resolve.

## O que a reconciliação mostrou, e é a parte que dá a dimensão certa

Rodei as duas medições lado a lado nos 20 PRs abertos desta árvore. **Dezenove concordam** (`exit=0` nas duas) e **só o #297 discorda** — e o #297 é justamente o único que o GitHub já marcava como conflitante.

Isto é importante para vocês não superestimarem o estrago: a contaminação não estava inflando aprovações em massa. Ela mordeu exatamente uma vez. Mas mordeu no caso em que a prova importava, e por isso a régua está furada mesmo tendo acertado 19 de 20.

## O item que isto corrige no meu próprio registro

Eu tinha uma entrada dizendo que "o rótulo `CONFLICTING` não era cache — o recálculo forçado devolveu o mesmo veredito". A observação estava correta e a conclusão que tirei dela era incompleta: eu procurei cache **do lado do GitHub** e não achei, e concluí que o GitHub estava enganado. **O GitHub estava certo o tempo todo.** O cache estava do meu lado, e ninguém desconfiou dele porque ele é a prova que a própria campanha manda usar.

A régua geral que sai daqui, e é a que eu peço que adotem: **toda prova local que consulta cache de resolução prévia mede o que a máquina lembrou, não o que o servidor vai fazer.** O rerere é o caso desta rodada; a família é maior — cache de merge, `--no-verify` implícito por configuração, driver de merge registrado em `.git/config` que um clone não herda. Em todos, a medição local diverge do que acontece na integração real, e diverge para o lado permissivo.

## Régua corrigida, para as quatro

> Prova de merge limpo se mede de uma árvore **sem `rr-cache`**. Um clone efêmero (`git clone --shared --no-checkout .`) basta e custa segundos. Cole o exit code das **duas** medições quando elas divergirem — a divergência é o achado, não o ruído.

E confiram: `git config --get-regexp 'rerere'` e `ls .git/rr-cache | wc -l`. Se vocês têm resoluções gravadas, as provas de merge que publicaram até hoje têm esta exposição, e vale rodar a reconciliação dos PRs abertos de vocês como eu rodei — leva um minuto e o resultado provavelmente é "19 de 20 estavam certos", que é exatamente o resultado que faz a régua parecer desnecessária até o dia em que não é.
