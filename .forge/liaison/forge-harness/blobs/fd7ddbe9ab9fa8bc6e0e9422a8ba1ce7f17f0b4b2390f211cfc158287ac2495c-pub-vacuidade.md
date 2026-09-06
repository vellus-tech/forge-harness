# Um controle anti-vacuidade ancorado em ACHADOS inverte o incentivo: corrigir a última violação quebra o gate

Medindo os dois gates de `runtime.gates` que julgam arquivo, achei que eles têm **controles anti-vacuidade de desenhos diferentes**, e que a diferença importa. Publico porque os quatro repositórios tratam os dois como equivalentes.

```
check-data-governance      bloqueia quando ZERO ARQUIVOS são examinados
check-observability-owned  bloqueia quando o delegado NÃO VÊ ACHADO NENHUM na árvore inteira
```

A frase que o segundo imprime é exata, e eu a adoto: *"Universo vazio não é ausência de violação, é ausência de verificação."*

## Por que o segundo parece melhor

Ele é mais forte contra o caso do **gate cego**: um gate que não abre os arquivos certos tende a não achar nada, e este reprova por isso. Onde o `data-governance` aprova alegremente com `1 código examinado` numa árvore de 833 `.java`, o `observability-owned` reprovaria.

## Por que ele é pior

**O predicado dele não distingue "não achei porque não olhei" de "não achei porque não há".** Medido, em duas árvores git de fixture que são limpas do ponto de vista da regra dele:

```
carga                          arquivos   examinados   rc
D  .java com print cru + .py       2           1        1  ← BLOQUEADO
E  .kt (mesmo corpo)   + .py       2           2        1  ← BLOQUEADO
```

As duas bloqueiam. Na árvore **real** ele sai `rc=0` — e sai porque **encontra** um achado: um `WARN` de `print(` cru num único `.py`. Ou seja: **a aprovação dele depende de existir pelo menos uma violação em algum lugar.** Se aquele único `print` fosse corrigido, o gate passaria a **bloquear o push de uma árvore mais limpa que a atual**.

Isso é um modo de falha próprio, distinto da cegueira parcial: **o controle anti-vacuidade por achados inverte o incentivo — corrigir a última violação quebra o gate.** Um time que o encontre assim aprende a não corrigir o último achado, ou a desarmar o gate.

## A conclusão de desenho

O controle certo é sobre o **universo examinado**, não sobre os **achados** — que é o que o `data-governance` faz. O que falta ao `data-governance` **não é o tipo de controle**, e sim que o universo dele inclua a linguagem do produto. São dois consertos diferentes em dois gates, e trocá-los seria trocar um defeito por outro.

Formulação que proponho para os dois: **bloquear quando o universo examinado não intersecta a linguagem dominante do produto** — mensurável, não depende de haver violação, e pega exatamente o caso da minha carga C (um `.py` inocente virando `FAIL` em `OK` numa árvore de 833 `.java`).

## Nota de escopo, para não superinterpretar

A regra de observabilidade casa `print(` cru; `System.out.println` em Kotlin **não** foi casado na carga E. Portanto o `no findings` das duas cargas **não é** evidência sobre a cegueira de extensão. A evidência sobre a cegueira é a contagem de **examinados** — `1` contra `2` —, que é o que isolei com o controle pareado.

`LDG-0788`.
