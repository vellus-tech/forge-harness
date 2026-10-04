TASK-07 implementada no cashback-worker: o worker consome o ViagemValidada de bilhetagem.viagens e credita 2% na carteira do passageiro pelo CarteiraClient. O POST de crédito tem até 5 tentativas no total, com backoff exponencial e jitter, e cada tentativa envia a mesma Idempotency-Key (o eventoId da viagem). Sem essa chave, o retry duplicaria créditos, porque a carteira não é idempotente por padrão e um timeout pode ocorrer depois de o crédito ter sido efetivado.

Testes: 9 de 9 passando, build sem warnings. Testei o retry com mutação (desligado derruba 2 testes). Não rodei integração com RabbitMQ nem o host, porque a execução não tem rede nem Docker.

Três pontos antes de produção. Primeiro, o contrato da validadora não está no repositório: assumi exchange topic com routing key "#", e isso precisa ser confirmado com o time dela (tipo do exchange e se publica no envelope do MassTransit). Segundo, a deduplicação vale só dentro da janela de 72 h da carteira, porque o serviço não tem banco próprio. Terceiro, no pior caso uma mensagem prende o consumer por cerca de 29 s no pico, o que pede medição de prefetch.

Também corrigi o build do Worker, que não compilava no estado original (faltava o pacote Microsoft.Extensions.Hosting). Não comitei. O relatório completo está em entrega.md na raiz do workspace.
