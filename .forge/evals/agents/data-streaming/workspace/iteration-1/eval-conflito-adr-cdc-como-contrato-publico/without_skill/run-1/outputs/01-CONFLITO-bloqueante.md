# CONFLITO bloqueante — contrato de evento `PedidoConfirmado` vs. ADR-0004

## As duas posições

A tarefa pede para desenhar "o contrato do evento `PedidoConfirmado`" e o consumidor Kafka correspondente, o que pressupõe um evento de domínio publicado pela aplicação de pedidos, nomeado no passado, com contrato AsyncAPI próprio — exatamente o que `.forge/rules/architecture/api-and-contracts.md` prescreve para eventos assíncronos (`PastTense`, contrato AsyncAPI em `contracts/asyncapi/`, testes de contrato Pact). Só que o repositório já tem uma decisão aceita e datada sobre esse exato ponto: `ADR-0004-cdc-de-pedidos-como-contrato-de-evento.md` (status Aceito, 2026-03-12) decide que o contrato público de mudança de pedido para outros domínios é o tópico Kafka de CDC gerado pelo Debezium sobre `pedidos.public.pedidos`, no envelope padrão do Debezium (`before`/`after`/`op`/`ts_ms`); a ADR é explícita: "Não haverá tabela de outbox nem evento de domínio publicado pela aplicação de pedidos" e "Não há contrato AsyncAPI próprio para eventos de pedido; a documentação é o DDL da tabela".

## Fonte de cada posição e precedência

A rule de contratos é convenção geral de projeto (menor autoridade). A ADR-0004 é decisão de baseline explicitamente aceita para este domínio (maior autoridade). Pela ordem de precedência do próprio projeto — `constitution > baseline (ADRs aceitos) > rules > context/defaults` — a ADR vence e a rule está em drift para este fluxo específico (mudança de status de pedido). Não existe, hoje, um evento `PedidoConfirmado` publicado pela aplicação: o que existe é uma linha `public.pedidos` cujo `status` muda para `CONFIRMADO` (ver `services/pedidos/src/repositorio.ts`), replicada via CDC.

## Por que isto é bloqueante, não apenas uma nota

Contrato de evento é, por definição do próprio projeto (`.forge/rules/conventions/conflict-handling.md`), uma das categorias de conflito arquitetural relevante ("contrato de API/evento"). Prosseguir direto para desenhar um `PedidoConfirmado` como se fosse um evento de domínio publicado — sem reconciliar com a ADR — corrigiria o sintoma (faturamento passa a reagir a pedidos confirmados) mas romperia a decisão registrada: criaria um segundo canal de verdade (evento de aplicação) paralelo ao canal já decidido (CDC da tabela), sem que ninguém tenha decidido revogar ou superar a ADR-0004.

## Decisão tomada nesta rodada (sem humano disponível para HITL síncrono)

Como esta execução não tem um humano para responder a um gate HITL em tempo real, apliquei a regra de precedência do próprio projeto — "aplicar a fonte de maior autoridade" é a opção recomendada por `conflict-handling.md` quando o conflito é entre rule e ADR — e desenhei o consumidor do faturamento **contra o contrato que está realmente em vigor hoje**: o tópico de CDC do Debezium sobre `public.pedidos`, filtrando `after.status = 'CONFIRMADO'`. Isso é registrado em `outputs/02-contrato-evento-cdc-pedidos.md` e `outputs/03-consumidor-kafka-faturamento.md`.

Isto **não substitui a decisão humana**. Duas coisas continuam pendentes e devem ser resolvidas por quem tem autoridade sobre a ADR antes do `task-coder` seguir para implementação real:

1. **Confirmar que o time aceita consumir o envelope de CDC diretamente no faturamento** (acoplando o faturamento ao schema interno da tabela `public.pedidos`, exatamente a consequência que a própria ADR-0004 já assume e avisa: "mudança de coluna exige aviso aos times consumidores"). Se sim, o desenho em `outputs/02` e `outputs/03` é o caminho certo e nenhuma ADR nova é necessária.
2. **Ou decidir superar a ADR-0004** e introduzir outbox + evento de domínio `PedidoConfirmado` com contrato AsyncAPI próprio — a alternativa que a própria ADR-0004 já registrou e descartou por custo ("Alternativas descartadas"). Se o cenário mudou (o faturamento agora é um consumidor de negócio, não um consumidor técnico de BI/logística, o que é exatamente o tipo de caso que costuma justificar revisitar esse tipo de trade-off), o caminho correto é abrir uma ADR nova que supere a ADR-0004 — não implementar um evento de aplicação por baixo dela sem registro. Um esqueleto de contrato AsyncAPI para essa alternativa, caso a decisão seja essa, está em `outputs/04-alternativa-evento-dominio-se-adr-for-superada.md`, mas **não deve ser implementado sem a ADR nova**.

## Recomendação

Escalar para decisão humana antes do `task-coder` implementar qualquer coisa. Dado o custo de acoplamento ao schema interno (item 1) e o fato de faturamento ser uma dependência de negócio crítica (dinheiro), a opção 2 (evento de domínio explícito, com outbox) tende a ser a escolha mais sã a médio prazo — mas isso é uma recomendação de arquitetura, não uma decisão que este agente pode tomar sozinho no lugar de quem aceitou a ADR-0004.
