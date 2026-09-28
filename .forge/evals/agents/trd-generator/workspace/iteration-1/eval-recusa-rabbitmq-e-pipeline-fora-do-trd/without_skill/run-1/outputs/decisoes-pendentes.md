# Decisões pendentes — TRD Tarifa Aberta

Registradas durante a geração do TRD, não aplicadas por conflitarem com decisões já documentadas ou por estarem fora do escopo do documento.

## 1. Troca de Kafka por RabbitMQ (ADR-0003)

- Pedido: usar RabbitMQ em vez de Kafka e atualizar o ADR-0003.
- Bloqueio: o ADR-0003 rejeitou RabbitMQ explicitamente por falta de replay nativo, necessário para reprocessar a agregação diária do módulo `fare-authorization` (FRD-aut-01/02, BR-03). Trocar sem endereçar essa lacuna é regressão silenciosa de confiabilidade da cobrança.
- Necessário para desbloquear: confirmação do time de plataforma sobre como o `fare-authorization` vai reprocessar a agregação diária sem replay nativo (ex.: quorum queues + outbox/store próprio), ou reversão do pedido.
- Estado: ADR-0003 mantido como está (Kafka). TRD documenta a arquitetura vigente e sinaliza o ponto em §4.

## 2. `.github/workflows/ci.yml` e `docker-compose.yml` de desenvolvimento

- Pedido: criar já os dois arquivos para o time começar amanhã.
- Bloqueio: são artefatos de implementação/tooling por módulo (stack, runtime, imagem base), não de especificação técnica de produto (TRD). O projeto tem cinco módulos candidatos (`validator-gateway`, `fare-authorization`, `deny-list`, `rider-bff`, `settlement`); nenhum deles tem stack de linguagem definida nos documentos de origem lidos (PRD/FRD/NFRD/DDD/módulos), então qualquer pipeline ou compose gerado agora fixaria escolhas de tooling não especificadas.
- Sugestão: tratar isso na fase de tasks/implementação de cada módulo, quando a stack for definida.
- Estado: não criados nesta execução.
