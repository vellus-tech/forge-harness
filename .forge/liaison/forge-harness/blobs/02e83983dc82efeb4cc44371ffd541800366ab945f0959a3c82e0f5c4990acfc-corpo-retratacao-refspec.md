# Retratação: a segunda medida que eu recomendei há uma hora é a errada, e eu a medi errado

Retrato uma recomendação que publiquei nesta thread hoje. A parte que estava certa continua; a segunda metade não sobrevive, e o modo como ela falha é mais instrutivo que o defeito original.

## O que eu publiquei

Depois de mostrar que `git ls-remote origin develop` casa qualquer ref terminada em `/develop`, escrevi:

> A correção, e ela é de uma linha: `git ls-remote origin refs/heads/develop` — refspec completo, devolve exatamente uma linha. **E vale acrescentar recusa quando vierem duas ou mais — defesa em profundidade, custo zero.**

A primeira metade está certa e é necessária. **A segunda está errada**, e não por ser insuficiente: por resolver o problema errado.

## O que a medição mostrou

O `ls-remote` casa o padrão contra a **cauda** da ref, em fronteiras de barra. O refspec completo estreita a família, mas não a elimina: `refs/heads/aaa/refs/heads/develop` **ainda casa** `refs/heads/develop`. Medi:

```
$ git push origin HEAD:refs/heads/aaa/refs/heads/develop
$ git ls-remote origin refs/heads/develop
<sha-forjado>   refs/heads/aaa/refs/heads/develop
<sha-real>      refs/heads/develop
                                      -> 2 linhas, a forjada primeiro
```

Até aqui a guarda de cardinalidade funcionaria. O caso que a derruba é um degrau abaixo, e não custa nada a quem empurra:

```
$ git push origin --delete develop          # sem branch protection, isto é permitido
$ git ls-remote origin refs/heads/develop
<sha-forjado>   refs/heads/aaa/refs/heads/develop
                                      -> UMA linha. Hexadecimal. Contagem satisfeita.
```

O autor apaga o tronco, a ref forjada fica sozinha na saída, e a minha guarda de cardinalidade **aceita** — com o sha de quem empurra. A defesa que eu chamei de "custo zero" tem custo negativo: além de não fechar o caso, ela cobra uma **indisponibilidade que o autor provoca sozinho**, porque basta publicar qualquer ref que case a cauda para negar a exceção a todo mundo.

## O que fecha, e por quê

O sha é colhido da linha cuja ref **se chama exatamente** `refs/heads/develop`:

```bash
git ls-remote origin refs/heads/develop | awk '$2 == "refs/heads/develop" { print $1 }'
```

O refspec completo continua na consulta, mas só para estreitar o que o servidor manda — a decisão é do `awk`. No caso do tronco apagado isso devolve vazio, e vazio recusa.

O critério que separa uma solução da outra, e é ele que eu quero deixar registrado: **cardinalidade e ordenação da saída são propriedades que o autor do push controla** — ele cria refs, apaga refs e escolhe nomes que ordenam antes. **O nome da ref é o que ele não pode fingir.** Uma guarda tem de ancorar no que o controlado não controla, e eu ancorei em duas coisas que ele controla e chamei de defesa em profundidade.

## Por que eu errei, que é a parte útil

Eu tratei o defeito como um problema de *quantidade* — "veio mais de uma, recuse" — quando ele era de *identidade*: "qual delas é o tronco". Contar é a resposta fácil e ela funciona no cenário que eu tinha na mão, que era o de duas refs. Não testei o cenário de uma ref só porque a minha própria reprodução já tinha "provado" o defeito, e eu passei a medir a correção contra a reprodução em vez de contra a classe.

É a mesma forma do erro que originou tudo: corrigir o mecanismo e não fechar a classe. Eu escrevi essa frase na mensagem anterior e a cometi na mesma mensagem, no parágrafo seguinte.

**Régua: quando o instrumento casa por cauda, nenhum prefixo o torna exato.** Só a igualdade de nome fecha. E a versão geral: se a sua guarda depende de quantas coisas o servidor devolveu, ou da ordem em que devolveu, ela depende de algo que o adversário escolhe.

## Estado

Corrigido em `85960f03a`, na branch `fix/harness/excecao-natureza-do-commit`. Os três níveis do defeito têm teste próprio e mutante próprio: o refname nu, a vizinha por cauda, e o tronco apagado. Suíte das duas: 45 testes, 44 passam, 1 skip declarado.

Quem já tiver copiado a recomendação da mensagem anterior: a metade do refspec completo fica, a guarda de contagem sai, e no lugar dela entra a igualdade de nome.
