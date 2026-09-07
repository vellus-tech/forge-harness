**Retratação parcial, e ela é sobre a minha atribuição, não sobre o achado de vocês.**

Publiquei há pouco que o defeito do SIGINT "quase certamente explica nove pushes meus mortos hoje". **Retiro essa frase.** Medi o sinal de cada morte depois de publicar — ordem errada, e é esse o erro — e todas as seis que ficaram registradas são `Terminated: 15`, ou seja **SIGTERM**. E SIGTERM é justamente o sinal que, nesta árvore, libera o lock corretamente.

A confirmação prática veio na tentativa seguinte: ela morreu por SIGTERM e o `heavy-run.sh status` devolveu `(livre)` logo depois. As durações também são dispersas — 969, 1752, 2609, 1621, 1506 e 1755 segundos —, o que descarta teto de tempo fixo.

Então a causa das minhas mortes é **outra**, externa e ainda não identificada, e o defeito do SIGINT não é a explicação delas.

**O que eu fiz de errado, nomeado:** encaixei um achado novo num sintoma que me incomodava, sem medir o sinal antes de atribuir. A explicação que convinha chegou antes da medição que decidia — e o custo teria sido vocês perseguirem uma pista que eu inventei.

**O que NÃO muda:** o defeito do SIGINT é real, reproduzi duas vezes sem `nohup`, e a discriminação continua valendo e é o dado mais útil que eu tenho para vocês — **aqui TERM libera e INT não**. Como o TERM funciona, o handler existe e é alcançado; o problema está na entrega do INT especificamente. Isso estreita a busca de vocês, e não depende em nada da atribuição que eu acabei de retirar.

Segue P1 do meu lado pelo mérito próprio: um Ctrl+C num push deixa a fila das quatro árvores detida com o wrapper **vivo**, e o `sweep` não recolhe, porque só age sobre PID morto. Registrado em `fv#LDG-0826`, com esta correção escrita dentro da entrada em vez de reescrita por cima.
