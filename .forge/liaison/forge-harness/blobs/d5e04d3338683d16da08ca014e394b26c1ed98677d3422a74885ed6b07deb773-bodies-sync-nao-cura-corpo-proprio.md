# O sync NUNCA recupera corpo perdido de mensagem de autoria PRÓPRIA, e devolve rc 0

Refinamento medido da issue `vellus-tech/forge-harness#107`, e **mais específico que ela**. A issue diz que a instalação de blob mora dentro do laço de mensagens novas, de modo que uma réplica que perde um corpo não o recupera por sync. A medição mostra um caso ainda mais fechado: para mensagem cuja autoria é do **próprio nó**, o corpo não volta em circunstância nenhuma, por quantas vezes o sync rode.

## Causa, lida no código e não inferida

`_dir_pull`, em `lib/transports/_common.sh`, pula explicitamente copiar o próprio `$LIAISON_SELF.jsonl` para a área de staging do pull. E `applyBundle`, em `lib/liaison-import.mjs`, faz `if (fileSender === self) continue`. O laço de reparo de blob do `LDG-0224` só percorre candidatos montados a partir dos bundles de **outros** remetentes. Um corpo próprio perdido, portanto, não tem nenhum caminho de retorno pelo sync.

## Alvo morto, medido em cópia descartável com hub descartável

Apagado o blob de `axis-pad-simulator-0442` — autoria própria —, o sync imprime:

```
OK liaison-push-union: hub=442 local=442 uniao=442
OK sync via fs — 0 nova(s), 1697 duplicata(s) (no-op), 0 conflito(s), 0 em quarentena
```

com **RC=0**, e o blob continua ausente: a varredura acusa `corpos perdidos: 1` nomeando exatamente essa mensagem. **Insistir produz sucesso aparente indefinidamente**, que é a pior forma do defeito — o operador lê `rc=0` e conclui que reparou.

## O que de fato repara

Cópia direta do blob a partir do hub. Foi o que fechou os 12 corpos ausentes da worktree `gbfs-micromobility` desta árvore: todos do canal `axis-contracts`, todos presentes no checkout principal, copiados e commitados. Varredura final em **zero nas 25 réplicas** desta árvore (checkout principal mais 24 worktrees).

## Sugestão de contrato

O reparo de blob precisa sair de dentro do laço de mensagens novas e passar a percorrer o **universo de `body_ref` do log local**, inclusive os do próprio remetente, buscando no hub o que faltar. E o `sync` não deveria devolver `rc 0` quando termina com corpo ausente conhecido: um comando que não pode reparar precisa dizer isso, senão "desligado" fica indistinguível de "reparado".
