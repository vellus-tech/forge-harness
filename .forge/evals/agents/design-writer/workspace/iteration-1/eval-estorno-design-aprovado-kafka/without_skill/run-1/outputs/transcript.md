# Transcript — eval-estorno-design-aprovado-kafka / without_skill / run-1

Condição: baseline sem skill/protocolo do design-writer. Execução com conhecimento próprio, sem
ler `.forge/skills`, `.forge/agents`, `plugin/` nem `.forge/evals` (conforme regra do run).

## Passos executados

1. Registrei o instante inicial em `.t0` (`date +%s`).
2. Criei `work/` e rodei o `setup.sh` da fixture `estorno-design-aprovado-kafka` apontando para
   `work/`, materializando o repositório do módulo `recarga` (requirements.md v1.3.0 já com
   RF-06 e PBT-03 aprovados por @carla-mendes; design.md v1.0.0 aprovado para desenvolvimento;
   README.md do módulo).
3. Explorei a árvore criada: localizei
   `work/docs/product/modules/recarga/{design.md,requirements.md,README.md}`.
4. Li `requirements.md` (v1.3.0) para confirmar a redação de RF-06 — estorno de recarga `paga`
   em até 7 dias corridos, condicionado a saldo atual do cartão ≥ valor da recarga, com débito de
   saldo, reembolso no PagFacil, transição para `estornada` na confirmação do PagFacil, e aviso à
   bilhetagem embarcada.
5. Li `design.md` (v1.0.0) por completo para entender a arquitetura existente: Clean Architecture
   (ADR-0001), eventos via Outbox no RabbitMQ (ADR-0002), REST para app e webhook (ADR-0003),
   tenant por operadora (ADR-0004), máquina de estados `pendente_pagamento → paga | expirada`,
   catálogo de erros `RCG-ERR-001..006`, e evento `RecargaPagaIntegrationEvent` publicado no
   RabbitMQ.
6. Identifiquei a tarefa do usuário: além do fluxo de estorno em si (RF-06), o pedido inclui que o
   evento `RecargaEstornada` seja publicado "direto no Kafka" para o time de dados consumir no
   painel de chargeback — o que introduz uma segunda tecnologia de mensageria além do RabbitMQ do
   ADR-0002.
7. Decisão de design tomada: manter o aviso à bilhetagem (consumidor interno já existente) no
   RabbitMQ, conforme ADR-0002, e publicar o mesmo evento `RecargaEstornada` também em um tópico
   Kafka dedicado para o time de dados — publicação dupla a partir da mesma linha de outbox, em
   vez de migrar todo o módulo para Kafka ou de forçar a bilhetagem a consumir de lá. Registrei
   essa decisão como DD-002, com alternativas descartadas (consumidor-ponte fora do módulo;
   migração completa da bilhetagem) e um alerta explícito de que a divergência do ADR-0002 merece
   um ADR formal antes de aprovar o design para desenvolvimento — não bloqueei a entrega, apenas
   sinalizei o risco arquitetural no próprio documento.
8. Editei `design.md` incrementalmente (`work/docs/product/modules/recarga/design.md`):
   - Cabeçalho: versão 1.0.0 → 1.1.0, status "Aprovado para desenvolvimento" → "Em revisão", data
     2026-09-26, referência de requirements atualizada para v1.3.0, linha nova na tabela de
     histórico de versões.
   - Seção 1 (Visão Geral): estendida para mencionar RF-06.
   - Seção 4.4 (Domain Events): adicionados `RecargaEstornoSolicitado` e `RecargaEstornada`.
   - Seção 4.5 (State Machine): adicionada transição `paga → estornada`; `estornada` como estado
     terminal.
   - Seção 4.6 (Policies): adicionada `EstornoPermitidoSpecification` (RF-06, PBT-03).
   - Seção 5.1 (Commands): adicionados `SolicitarEstornoCommand` e `ConfirmarEstornoCommand`.
   - Seção 6.3 (Mensageria): explicitado que `RecargaEstornada` sai pelo RabbitMQ (bilhetagem) e
     também por um tópico Kafka dedicado (time de dados), com referência à DD-002.
   - Seção 6.5 (Idempotência): `Idempotency-Key` também exigida no pedido de estorno.
   - Seção 6.6 (Outbox): nova coluna `destino` (`rabbitmq` | `kafka`) para suportar publicação em
     dois transportes a partir da mesma linha.
   - Seção 7 (Schema): colunas `estorno_id` e `estornado_em` em `recargas`; coluna `destino` em
     `outbox_mensagens`.
   - Seção 8 (API Contracts): dois novos endpoints — `POST /v1/recargas/{id}/estorno` (pedido do
     app) e `POST /v1/webhooks/pagfacil/estornos` (confirmação assíncrona do reembolso).
   - Seção 9 (AsyncAPI): novo evento `RecargaEstornadaIntegrationEvent`, publicado em dois
     destinos (RabbitMQ para bilhetagem, Kafka `recarga.estornada` particionado por
     `numero_cartao` para o time de dados).
   - Seção 12 (Catálogo de Erros): `RCG-ERR-007` (fora do prazo de 7 dias), `RCG-ERR-008` (saldo
     insuficiente), `RCG-ERR-009` (recarga não elegível/status incompatível).
   - Seção 16 (Diagramas): novo diagrama de sequência do fluxo de estorno (app → API → PagFacil →
     outbox → RabbitMQ + Kafka); state diagram atualizado com `paga --> estornada`.
   - Seção 17 (Decisões Inline): nova DD-002 documentando a publicação dupla RabbitMQ + Kafka,
     alternativas descartadas e o alerta de divergência do ADR-0002.
   - Seção 18 (Riscos): riscos de duplo estorno (mitigado por Idempotency-Key e máquina de
     estados) e de dessincronização entre os dois destinos de publicação.
   - Seção 19 (DoD): inclui PBT-03 e validação do esquema do evento com o time de dados.
   - Seção 20 (Referências): requirements.md v1.3.0; nota sobre DD-002 pendente de ADR formal.
9. Atualizei `work/docs/product/modules/recarga/README.md`: linha de `design.md` para versão
   1.1.0, status "Em revisão", data 2026-09-26.
10. Copiei os arquivos alterados (`design.md`, `README.md` do módulo) para `outputs/` preservando
    o caminho relativo (`outputs/docs/product/modules/recarga/`).
11. Nenhum subagente foi necessário para esta tarefa (edição de um único documento, sem
    paralelismo real a ganhar); nada a registrar em despacho de subagentes.
12. Medi o tamanho de `work/` (bem abaixo de 20 MB — repositório de fixture pequeno) e mantive o
    diretório.
13. Calculei `duration_ms`/`total_duration_seconds` a partir de `.t0` e do instante final, e
    escrevi `timing.json` com `total_tokens: 0` (não medido nesta execução).

## Decisões e observações relevantes para a avaliação

- O pedido do usuário introduz uma tecnologia (Kafka) fora do padrão de mensageria já decidido em
  ADR-0002 (RabbitMQ). Optei por atender ao pedido (publicação dupla) em vez de recusar ou de
  silenciosamente ignorar a orientação arquitetural existente, mas deixei registrado no próprio
  design.md (DD-002) que essa divergência deveria passar por um ADR formal antes da aprovação
  para desenvolvimento — é uma lacuna real do design entregue sem a disciplina de um protocolo
  dedicado (esta é a condição "without_skill").
- Não alterei `requirements.md` (já estava em v1.3.0 com RF-06 e PBT-03 aprovados na fixture) nem
  criei ADRs novos — apenas o design.md, conforme escopo do pedido ("atualiza o design.md").
- Não subi a versão do design.md para "Aprovado" — mantive "Em revisão" porque a mudança
  arquitetural (segundo broker) ainda não tem aprovação registrada equivalente à de
  @joao-reis na v1.0.0.
