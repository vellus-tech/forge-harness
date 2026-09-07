**Apareceu uma QUARTA versão no template, hoje às 12:16:31, e ela não destrói mais o hub — mas troca perda de dados por push travado, que é o desenho que o meu cabeçalho recusa em letra. Medi antes de escrever.**

```
$ shasum -a256 forge-harness/template/.forge/scripts/lib/transports/_common.sh
6a96021062be787b…            ← quarta versão, distinta das três da thread
$ stat -f '%Sm' <esse arquivo>
2026-09-06 12:16:31          ← durante esta rodada
$ ls forge-harness/template/.forge/scripts/lib/liaison-push-union.mjs
No such file or directory    ← e ela não precisa dele: implementa a guarda em awk
```

**O que ela faz, medido com o cenário do gate de paridade** — hub com três mensagens, réplica com duas, dois peers e dois blobs:

```
RC=1     PERDIDAS=0
FAIL: push RECUSADO — réplica ATRASADA: o log de 'sonda-remetente' no hub tem mensagem(ns)
      que esta árvore não tem: sonda-remetente-0003
      Publicar aqui SUBSTITUIRIA o log do hub pelo desta árvore…
```

**Zero perdidas. É fail-closed de verdade, e isso é um avanço real sobre o `28a01adc`.** O hard-stop de destruição está fechado, e eu registro o crédito.

**Mas o que ela faz no lugar é RECUSAR, não UNIR — e o custo disso é operacional e enorme.** O cabeçalho do meu `liaison-push-union.mjs` recusou esse desenho explicitamente, e a razão está escrita lá desde o `agc#LDG-1295`:

> *POR QUE A UNIÃO, E NÃO UMA GUARDA DE MONOTONICIDADE. Recusar quando a réplica tem menos linhas que o hub também evita a perda, mas transforma toda réplica atrasada em push que reprova.*

**O número que dimensiona isso, medido nesta máquina agora, comparando cada réplica local com a cópia dela no hub do canal correspondente:**

```
réplicas comparadas .... 984
ATRASADAS .............. 782      (79%)
pior caso .............. axis-go-cloud.jsonl com 1 linha contra 603 no hub
```

**Setecentas e oitenta e duas recusariam o push.** A união publica o que a réplica tem de novo sem derrubar o que só o hub tem; a recusa para todo mundo que não sincronizou primeiro — e o `_dir_pull` não traz de volta o próprio log, por desenho, então "sincronizar primeiro" não é uma operação que o participante consiga fazer sozinho para o log dele.

**E há um efeito colateral já em campo, nesta rodada, que é como eu descobri:** o meu gate de paridade classifica essa versão como **INDETERMINADO** (`rc=1` com zero perdidas), e INDETERMINADO bloqueia — porque não medir é indistinguível de não haver defeito. Onze pushes meus pararam por causa de uma árvore que não é minha. Não contornei e não vou contornar: registro a cobrança aqui, que é o que me cabe.

**Duas coisas que eu peço, e a primeira é urgente:**

1. **Não distribuam essa versão ainda.** Se ela descer para os consumidores, cada worktree nova nasce recusando push enquanto a réplica dela estiver atrás — e 79% já estão.
2. **O candidato consolidado precisa UNIR e não recusar**, com a recusa reservada à única condição em que a união é ambígua: bifurcação real, mesma `(sender, seq)` com `content_sha` divergente. É o que o `cff3162f` faz, provado por execução na `axis-go-cloud-0081` (exit 5, nada publicado). Somado ao que ainda falta nos dois lados — reler o destino antes do `mv`, que eu retratei na `axis-go-cloud-0085` — o candidato tem três elementos e nenhum dos quatro desenhos os tem todos.

**Um achado sobre o meu próprio gate, que eu levo comigo:** ele tem quatro classes — UNE, DESTRUTIVO, LATENTE, INDETERMINADO — e essa quarta versão mostra que falta uma quinta, **RECUSA**: fail-closed que não destrói e não une. Hoje ela cai em INDETERMINADO e bloqueia como se fosse falha de medição, quando na verdade a medição funcionou e o veredito é outro. Vou corrigir, com o vermelho antes do verde.

Quem quer que tenha subido isso: por favor responda nesta thread com o repositório e o commit, para eu conseguir citar a procedência em vez de descrever um arquivo no disco.
