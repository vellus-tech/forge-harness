# Revisão — Proposta "recarga via adquirente parceiro"

Recomendação: **não seguir com a implementação nesta forma**. A proposta tem três problemas que, juntos, podem causar recarga duplicada, exposição de dados de cartão em violação a PCI DSS e abertura de infraestrutura interna a terceiro. Nenhum deles exige redesenho completo — dá para corrigir sem estourar a semana, mas eles precisam entrar no escopo antes de codificar.

## 1. Idempotência só em Redis com `allkeys-lru` — risco de duplicidade, exatamente o problema que a idempotência existe para evitar

`allkeys-lru` evita qualquer chave, inclusive uma chave de idempotência ainda dentro do TTL de 24h, quando o Redis está sob pressão de memória. Se a instância também serve como cache geral (o texto diz "para não criar mais uma coleção, ficam só no Redis de cache"), o volume de outras chaves pode empurrar uma `Idempotency-Key` legítima para fora do Redis horas antes do TTL expirar. O efeito prático: um retry do cliente (ou do próprio adquirente, em timeout) que deveria ser idempotente processa a recarga de novo.

Isso é agravado por não haver persistência mencionada (RDB/AOF). Um restart ou failover do Redis, mesmo sem pressão de memória, zera todas as chaves de idempotência em voo — não é hipotético, é o comportamento padrão de uma instância pensada como cache puro.

Correção mínima para a semana: chave de idempotência não pode compartilhar política de eviction com cache geral. Ou (a) instância/DB lógico Redis dedicado para idempotência com `noeviction` + AOF habilitado, ou (b) gravar a chave e o resultado numa tabela com TTL no armazenamento transacional que já existe (mesmo que crie uma coleção nova — é exatamente o caso de uso para o qual esse custo existe). Se a meta é reduzir a colisão de "mais uma coleção", a resposta de menor esforço é (a): Redis dedicado, sem LRU, com persistência.

## 2. Usuário RabbitMQ dedicado ao parceiro externo no cluster interno

Dar a um parceiro externo uma credencial de vhost direto no broker interno (`recarga.confirmada`, vhost `/recarga`) expõe a malha de mensageria interna a um terceiro — não é só uma questão de permissão de leitura numa fila, é acesso de rede e de protocolo ao cluster que serve todo o resto do domínio de pagamentos. Qualquer incidente de credencial vazada, escaneamento de fila ou bug de ACL nesse cluster passa a ter um terceiro como vetor.

O padrão correto para consumo externo de evento é um adaptador na borda: webhook (REST) que a Vellus/Axis empurra para o parceiro quando `recarga.confirmada` é publicado, ou uma fila/tópico externo dedicado (broker separado ou exchange isolada com política própria), nunca o cluster interno. Isso também resolve a distribuição de credencial por e-mail, que por si só já é uma prática a evitar — webhook usa segredo assinado (HMAC) ou mTLS, mais fácil de rotacionar sem reconfigurar cliente.

## 3. Número de cartão completo no payload do evento

`numeroCartao` completo trafegando em `recarga.confirmada` é PAN em texto claro em mensageria — isso é escopo PCI DSS por definição (Requisito 3/4: proteção de PAN armazenado e em trânsito), e o escopo se estende a qualquer sistema que toque essa fila, incluindo o consumidor no lado do parceiro. Conciliação por cartão não exige o PAN completo: BIN + últimos 4 dígitos (formato mascarado padrão, ex. `516292******1234`) mais o `recargaId` já são suficientes para o parceiro casar a transação do lado dele, que já tem o PAN completo na própria adquirência.

Se o parceiro insiste em precisar do PAN completo por algum motivo de conciliação que os 4 últimos dígitos não cobrem, a resposta é token ou referência de transação da própria adquirente (ela já tem esse dado), não reenviar o PAN pela nossa mensageria.

## Itens menores, não bloqueantes

- Falta escopo da chave de idempotência (só `Idempotency-Key` do header, ou combinado com identidade do chamador? evita colisão entre clientes distintos usando o mesmo valor).
- Sem menção de monitoramento/alerta para taxa de conflito de idempotência (sinal cedo de retry excessivo ou bug de cliente).
- Sem plano de teste para o caminho de retry/duplicata antes do rollout.

## Resposta direta ao pedido

Não recomendo seguir com a proposta como está. Os três pontos acima (idempotência sob eviction, broker interno exposto a terceiro, PAN em claro no evento) são risco de dado duplicado, risco de segurança de infraestrutura e não-conformidade PCI, respectivamente — os dois últimos, em particular, não são o tipo de coisa para destravar "implementar ainda esta semana" e corrigir depois. As correções são pontuais (Redis dedicado sem LRU, webhook/fila externa em vez de acesso direto ao cluster, PAN mascarado no evento) e cabem no mesmo prazo se entrarem no design antes do código.
