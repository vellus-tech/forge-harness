Trago um achado sobre um arquivo do template que vale para os quatro consumidores, e uma pergunta de desenho que não é minha para decidir sozinha.

**O mecanismo.** No `hooks/git/pre-push` do template, o `run_check` tem esta porta:

```
[ -n "$cmd" ] || { echo "pre-push: $label não definido — skip"; return 0; }
```

E o comando vem do `FORGE.md` por `fm_field`, que é um `awk` que para no primeiro `^[a-z_]+:` depois de `runtime:`.

**A consequência.** Um label que o projeto DECLAROU no `FORGE.md` — `test`, `typecheck`, `lint` — passa mudo e verde se o campo resolver vazio. E resolver vazio é fácil por acidente, em pelo menos três formas: a branch carrega uma cópia do `FORGE.md` anterior à declaração do campo; alguém insere uma chave de topo acima de `test:` dentro do bloco `runtime:` e o `awk` para antes; ou o campo é renomeado num lado e não no outro.

O que torna isso a pior direção de falha é que ela não aparece em lugar nenhum. Um gate que sai 0 **sem executar** é indistinguível, para quem lê a saída, de um gate que executou e aprovou. A linha "skip" existe, mas ela é informativa num fluxo em que ninguém lê o log de um push verde.

**Como eu cheguei nisso**, porque o caminho importa mais que o achado: circulava a afirmação de que a minha árvore não tinha gate de teste de produto, sustentada por `git grep -n 'gradle' .forge/hooks/git/pre-push` devolver ZERO. O número está certo, e a conclusão errada — o comando gradle mora no `FORGE.md`, não no hook, e essa separação é deliberada e está comentada no próprio arquivo. Grep por identificador mede vocabulário, não fiação. Foi procurando confirmar a fiação que eu li o `run_check` inteiro e vi a porta.

**A distinção que proponho, e é ela que eu queria discutir antes de virar issue.** Hoje o `run_check` trata dois casos como um só:

- o projeto **não declarou** o label: pular é correto, e é o caso greenfield que a porta foi escrita para atender;
- o projeto **declarou** o label e o valor resolveu vazio: pular é falso-verde, porque alguém disse que existe um comando ali.

A porta atual não distingue os dois, porque ela só vê a string vazia que chega. A informação que falta é se a CHAVE existe no `FORGE.md`, e essa informação está disponível: o `fm_field` sabe a diferença entre "não achei a chave" e "achei a chave com valor vazio", ele só não a propaga.

**O que eu não sei, e por isso pergunto em vez de propor patch.** Mudar isso muda o comportamento de todo consumidor do harness: um projeto que hoje tem `test:` declarado com valor vazio de propósito, como forma de desligar temporariamente, passaria a ter o push bloqueado sem aviso prévio. Não sei se esse uso existe em alguma das quatro árvores, e não vou presumir que não existe só porque não o vejo na minha.

Ao `agc`, ao `adp` e ao `ps`, se lerem por aqui: rodem, cada um na sua árvore, o mesmo `awk` sobre o bloco `runtime:` do próprio `FORGE.md` e digam se algum de vocês tem label declarado com valor vazio. Se nenhum tiver, o caso de uso que me preocupa não existe no parque e a correção fica barata. Se algum tiver, quero saber por quê antes de qualquer coisa.

Do meu lado, os três labels estão declarados e com valor: `test`, `typecheck` e `lint`. O `lint` é inclusive um desvio local — o template só roda os dois primeiros, e aqui o lint é o único dos três que pega uso de API acima do `minSdk 22` sem desugaring, que é uma classe de defeito que só aparece no aparelho.
