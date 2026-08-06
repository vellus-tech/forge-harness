# Bugfix — tasks-meta-required

## 1. Comportamento atual (incorreto)

`TSK-01` (dependência pendurada), `TSK-02` (ciclo) e `TSK-03` (dependência para wave posterior) operam sobre as arestas declaradas nas linhas de task. Quando **nenhuma** linha carrega o bloco `(rastreia: …; paths: …; depende: …)`, `dependsOn` nasce vazio em todas as tasks, o grafo não tem aresta alguma — e um grafo sem arestas é um grafo sem defeitos. Os três checks passam sem exercitar nada, e `validate-spec` aprova o plano.

O módulo já reconhece essa classe: o comentário em `tasks-graph.mjs:107` registra que "um grafo sem arestas é um grafo sem defeitos: TSK-01, TSK-02 e TSK-03 desligavam em silêncio, que é a falha que este módulo existe para eliminar". A correção de então tratou o caso em que os metadados **existem** mas em formato não reconhecido (varredura por nome de campo, em qualquer ordem). O caso em que os metadados simplesmente **não foram escritos** continuou aberto — e é indistinguível, para o check, de um plano perfeito.

Reprodução: um plano de três tasks sem nenhum bloco de metadados produz zero achados em `checkTasksGraph` — os três checks aprovam sem ter verificado nada (`w130[16]`, caso (a)).

**Correção de premissa.** O `LDG-0011` registra que o change `create-forge-project-harness` deste repositório teria "30 tasks e ZERO arestas declaradas". Medido agora, o plano tem **19 das 30 tasks com bloco de metadados e 19 arestas declaradas**; as 11 sem bloco são as da Wave 1. O número do ledger descreve o estado de quando o item foi aberto, antes de o parser passar a reconhecer campo por nome em qualquer ordem — a mesma correção que o comentário em `tasks-graph.mjs:107` documenta. O defeito estrutural continua real e é o que este change fecha; o exemplo citado no ledger é que envelheceu, e vale corrigi-lo lá.

## 2. Comportamento esperado

- Plano com **duas ou mais tasks** em que **nenhuma** declara qualquer campo de metadados reconhecido (`rastreia`/`paths`/`depende`/`expõe`, em qualquer grafia aceita pelo parser) emite `TSK-06` **bloqueante**: os checks de grafo não tiveram insumo, e isso não pode passar por aprovação.
- Plano **parcialmente** anotado — alguma task declara metadados e outras não — emite `TSK-06` **não-bloqueante** (warn), nomeando as tasks sem bloco. A assimetria é deliberada: omissão sistemática é o artefato inteiro não alimentando o check; omissão pontual é plausivelmente uma task trivial, e bloquear ali empurraria para anotação decorativa.
- `depende: —`, `depende: nenhuma` ou `depende: n/a` **continuam válidos** e não disparam nada: declarar independência é diferente de não declarar nada. É por isso que a distinção precisa ser "a linha tem algum campo reconhecido?", e não "a lista de dependências está vazia?".
- A mensagem diz o que deixou de ser verificado (`TSK-01`, `TSK-02`, `TSK-03`), no mesmo espírito do `TSK-05` — um check que não rodou é indistinguível de um check que passou, e é por isso que ele se anuncia.

## 3. Comportamento que deve permanecer inalterado

- `TSK-01`/`TSK-02`/`TSK-03`/`TSK-04` e o `TSK-05` de wave ausente: mesmos achados, mesma classificação, mesmas mensagens.
- Toda a robustez de reconhecimento de campo do parser (ordem trocada, `rastreia` ausente, chave acentuada, bullet com asterisco, comentário HTML) — `w130[12]` cobre e não pode regredir.
- Plano com uma única task e sem metadados não emite nada: não há aresta possível, então não há check desligado em silêncio.
- `SRF-00`/`SRF-01`/`SRF-02` seguem com o comportamento e a classificação atuais.

## 4. Root cause

`checkTasksGraph` deriva todos os seus achados de fatos **presentes** no artefato (uma aresta que aponta para fora, um ciclo, uma ordem invertida, um ID duplicado). Nenhum achado nasce de uma **ausência**, e a ausência total de metadados é justamente o estado em que os fatos que ele sabe checar não existem. O `TSK-05` foi a primeira exceção a essa forma — nasceu para dizer "não consegui verificar" quando faltam waves —, mas cobriu só aquele insumo. Não foi detectado antes porque todo fixture do `w130` declara metadados: os casos foram escritos para exercitar as regras, e um plano sem metadologia nenhuma nunca entrou como entrada. É a mesma forma do `LDG-0021` — a prova mede as regras que existem, não a superfície de entrada que elas deixam passar.

## 5. Testes de regressão

- [ ] Teste que reproduz o bug: plano com 3 tasks e nenhum bloco de metadados → `TSK-06` bloqueante (hoje: zero achados).
- [ ] Plano parcialmente anotado → `TSK-06` não-bloqueante nomeando as tasks sem bloco.
- [ ] `depende: —` explícito não dispara nada; plano de uma task sem metadados não dispara nada.
- [ ] `w130[12]` (variações de escrita) e os casos de `TSK-01..05` seguem verdes.

## 6. Rastreabilidade

`LDG-0011`, registrado no dogfood do `w130`. Sem spec/baseline anterior relacionado.
