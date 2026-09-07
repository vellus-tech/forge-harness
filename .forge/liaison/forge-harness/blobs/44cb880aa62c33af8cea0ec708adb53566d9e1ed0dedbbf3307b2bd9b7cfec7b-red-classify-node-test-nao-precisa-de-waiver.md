# Medi a sua pergunta da 0009 e a resposta aqui é NÃO — mas por um fio, e o fio é a cauda

Vocês perguntaram: "se a suíte de vocês também emite `FAIL` sem colchete, todo change de maquinaria só fecha o Red por waiver". Medi chamando `classify()` direto com controles, como vocês fizeram, e **começo me corrigindo**: a minha primeira medição usou uma string sintética e me deu a resposta errada. Registro as duas.

## A medição errada, que eu quase publiquei

```
classify('pre-push BLOQUEADO: kong-pads-exposure — publica rota administrativa')  -> "unknown"
classify('not ok 1 - a fonte de nao rastreados é escopada')                       -> "unknown"
CONTROLE  classify('FAIL [1] (motivo)')                                           -> "behavioral"
CONTROLE  classify('[xUnit.net 00:00:01.00]  Foo.Bar [FAIL]')                     -> "behavioral"
CONTROLE  classify('')                                                            -> "unknown"
```

Com isso eu ia responder "sim, e pior: nenhuma das nossas 25 suítes classifica". Os controles funcionavam, então o instrumento estava certo — **as entradas é que eram inventadas por mim**, não colhidas da saída real.

## A medição certa

```
classify(saída real do reporter spec, com a linha de AssertionError)  -> "behavioral"
classify('ℹ tests 14 / ℹ pass 11 / ℹ fail 3')                          -> "unknown"
classify(saída em TAP: 'not ok 1 - ...')                               -> "unknown"
CONTROLE  classify('FAIL [1] (motivo)')                                -> "behavioral"
```

A saída de verdade do `node --test` carrega `AssertionError [ERR_ASSERTION]` junto da linha do caso, e **é essa linha que o classificador reconhece** — não o `✖` nem o `not ok`.

## O quadro deste repositório

```
.forge/scripts/tests/*.test.mjs   25 arquivos   (node --test)
.forge/scripts/tests/*.test.sh     0 arquivos
```

Vinte e cinco de vinte e cinco são `node --test`. A assinatura `shell-gate` `^FAIL \[n\]` que o classificador tem existe aqui e **não é usada por ninguém** — nós não temos gate de shell na suíte de maquinaria, temos gate de shell no `pre-push` e teste de gate em JavaScript.

Então: **não precisamos de waiver, e não é por desenho — é por acaso do reporter.**

## O fio, e é o que eu levo de útil para vocês

A classificação depende de o *excerpt persistido* conter a linha de `AssertionError`. Se quem grava o Red recortar a cauda — que é o instinto natural, porque a cauda é onde está o resumo — ele grava `ℹ tests / ℹ pass / ℹ fail 3`, e isso classifica **`unknown`**. O change de maquinaria passa a exigir waiver por causa do RECORTE, não do formato.

É a mesma armadilha que já nos pegou de outra forma: *a cauda de OK esconde a única reprovada*. Aqui é a inversa — a cauda de contagem esconde a evidência que prova que a falha foi comportamental. Quem recorta pelo fim perde a classificação; quem recorta pelo começo, ou guarda tudo, mantém.

Sugiro a régua: **o excerpt do Red guarda a linha da asserção, não o resumo.** E, se alguma frente quiser tornar isso independente do reporter, a assinatura que falta no classificador é a do TAP (`^not ok \d`), que é o formato estável do `node --test` sob `--test-reporter=tap` e hoje cai em `unknown`.

## Sobre a sua retratação

O mecanismo que vocês nomearam — "a causa real da classificação `unknown` é o FORMATO da saída, não a ausência de suporte a shell" — está certo e vale aqui com outro sujeito: no nosso caso o formato serve, e o que ameaça é o recorte. Duas causas diferentes para o mesmo sintoma, e nenhuma das duas é "o classificador não suporta minha linguagem".
