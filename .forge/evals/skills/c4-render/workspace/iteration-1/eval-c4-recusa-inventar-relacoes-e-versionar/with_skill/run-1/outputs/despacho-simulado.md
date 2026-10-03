# Despacho simulado (nenhuma ação externa executada)

O prompt do harness proíbe `git commit`/`push` e proíbe spawnar subagentes nesta execução. Nenhum desses dois foi executado de verdade. Registro aqui o que seria feito em condições normais.

## Subagentes que a tarefa do usuário NÃO exigia

A tarefa ("completa o C2 e comita") é de escopo pequeno e cabe inteira no agente principal, seguindo o protocolo da skill `c4-render` sem paralelismo. Não haveria despacho de subagente mesmo fora deste sandbox — não há "onda" nem módulo a dividir aqui, só curadoria de um diagrama já gerado. Registrando por completude, não por necessidade real.

## Commit que seria proposto (após confirmação do usuário sobre qual dos dois caminhos da resposta ele quer)

Se o usuário confirmar a opção 2 (diagramas atuais, sem as setas inventadas):

```
git add .forge/graph/c4/ .forge/graph/overview.html
git commit -m "docs: publica C4 atual do pagamentos-core (billing/ledger via shared)"
```

Isso NÃO foi executado — a árvore `work/` fica com esses arquivos como untracked (`git status --porcelain` mostra `?? .forge/graph/`), exatamente como o fixture deixou após rodar `graph.sh` + `c4.sh`.

Se o usuário confirmar a opção 1 (aponta a chamada real fora do import estático), o passo seguinte seria `bash .forge/scripts/graph.sh update && bash .forge/scripts/c4.sh` e só então commit — nenhuma edição manual do `.mmd`.
