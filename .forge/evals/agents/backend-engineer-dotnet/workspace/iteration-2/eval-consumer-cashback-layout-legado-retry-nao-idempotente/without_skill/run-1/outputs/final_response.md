OK. TASK-07 implementada no cashback-worker, com 10 testes aprovados e build do Worker sem erros. Relatório em `work/entrega.md`.

Ponto principal: o retry de 5 tentativas só é seguro com `Idempotency-Key` estável. A carteira não é idempotente por padrão, então cada tentativa envia o `eventoId` como chave. Sem isso, um timeout já creditado geraria crédito duplicado.

Pendências antes de subir: confirmar com a validadora o tipo da mensagem, o tipo do exchange `bilhetagem.viagens` (usei `fanout`, uma suposição) e os campos do payload. Também há a janela de 72 h da chave de idempotência, que não cobre reentregas mais antigas.

Correção fora de escopo: o Worker não compilava no HEAD por falta de `Microsoft.Extensions.Hosting`. Adicionei a referência explícita.

Alterações não commitadas.
