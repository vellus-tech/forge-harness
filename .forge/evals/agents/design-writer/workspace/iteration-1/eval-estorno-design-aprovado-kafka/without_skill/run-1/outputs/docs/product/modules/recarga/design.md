# RCG — Recarga de Cartão de Transporte
**Design Técnico**

- Versão: 1.1.0
- Data: 2026-09-26
- Status: Em revisão (atualização para RF-06 — estorno)
- Referência base: docs/product/modules/recarga/requirements.md v1.3.0
- ADRs aplicáveis: ADR-0001, ADR-0002, ADR-0003, ADR-0004
- Rules aplicáveis: `.forge/rules/`

## Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|------------------------|
| 1.0.0 | 2026-09-20 | Aprovado para desenvolvimento | Criação inicial do documento, aprovado por @joao-reis |
| 1.1.0 | 2026-09-26 | Em revisão | Adiciona RF-06 (estorno de recarga): endpoint de estorno, débito de saldo, reembolso no PagFacil, aviso à bilhetagem e publicação de `RecargaEstornada` no Kafka para o time de dados |

## 1. Visão Geral

Serviço `Recarga` que cria cobranças no PagFacil, confirma pagamento por webhook, credita saldo uma única vez, notifica a bilhetagem embarcada (RF-01 a RF-05) e permite o estorno de uma recarga já paga (RF-06), com débito de saldo, reembolso no PagFacil e publicação do evento de estorno tanto no barramento interno quanto no Kafka consumido pelo time de dados.

## 2. Princípios e Decisões Macro

Clean Architecture (ADR-0001), eventos via Outbox no RabbitMQ (ADR-0002), REST para o app e para o webhook do PagFacil (ADR-0003), tenant = operadora (ADR-0004).

## 3. Estrutura da Solução

`Recarga.Domain`, `Recarga.Application`, `Recarga.Infrastructure`, `Recarga.Api`, `Recarga.Contracts`, com projetos de teste correspondentes e `Recarga.Architecture.Tests` (NetArchTest).

## 4. Modelo de Domínio

### 4.1 Aggregates

`Recarga` (raiz): id, tenant_id, numero_cartao, valor (Objeto de valor `Dinheiro` em centavos), meio_pagamento, status, cobranca_id. Invariante: crédito de saldo só na transição `pendente_pagamento → paga` (RF-03). `SaldoCartao` (raiz): numero_cartao, saldo_centavos, versao (concorrência otimista).

### 4.2 Entidades

`TentativaWebhook` (dentro de `Recarga`): payload_hash, recebido_em.

### 4.3 Objetos de valor

`Dinheiro` (long centavos, valida RF-02), `NumeroCartao`, `CobrancaId`.

### 4.4 Domain Events

`RecargaSolicitada`, `RecargaPaga`, `RecargaExpirada`, `RecargaEstornoSolicitado`, `RecargaEstornada` (RF-06).

### 4.5 State Machines

`pendente_pagamento → paga | expirada`; `paga → estornada` (RF-06, dentro de 7 dias corridos e saldo atual do cartão ≥ valor da recarga). Estados terminais: `estornada`, `expirada`.

### 4.6 Policies / Specifications

`ValorRecargaPermitidoSpecification` (RF-02, PBT-02). `EstornoPermitidoSpecification` (RF-06, PBT-03): recarga em status `paga`, dentro de 7 dias corridos da confirmação de pagamento, e saldo atual do cartão maior ou igual ao valor original da recarga.

## 5. Application Layer

### 5.1 Commands

`SolicitarRecargaCommand` (RF-01), `ConfirmarPagamentoCommand` (RF-03), `ExpirarRecargasCommand` (RF-04, job a cada minuto), `SolicitarEstornoCommand` (RF-06), `ConfirmarEstornoCommand` (RF-06, disparado pela confirmação do reembolso no PagFacil).

### 5.2 Queries

`ListarRecargasQuery` (RF-05), paginação por cursor.

### 5.3 Handlers

Um handler MediatR por command/query.

### 5.4 Pipeline Behaviors

Validation, Logging, Transaction, Idempotency.

### 5.5 Validações de Aplicação

FluentValidation na borda; RF-02 no domínio.

## 6. Infrastructure Layer

### 6.1 Persistência

EF Core 8 + PostgreSQL 16.

### 6.2 Cache

Não aplicável nesta versão.

### 6.3 Mensageria

RabbitMQ, exchange `mobi.eventos`, routing key `<tenant>.recarga.<evento>` (ADR-0002), usado para `RecargaPaga` e para o aviso de débito à bilhetagem em `RecargaEstornada`. Adicionalmente, `RecargaEstornada` é publicado também em um tópico Kafka dedicado (`recarga.estornada`, ver seção 9 e DD-002) para consumo pelo time de dados no painel de chargeback — esta é a primeira integração do módulo com Kafka; RabbitMQ permanece o barramento padrão para os demais eventos e para os consumidores internos (bilhetagem).

### 6.4 Integrações Externas

`PagFacilClient` (REST): timeout 3 s, 2 retries com backoff, circuit breaker Polly (5 falhas / 30 s).

### 6.5 Idempotência

Webhook deduplicado por `cobranca_id` + status; header `Idempotency-Key` em RF-01 e RF-06 (o pedido de estorno também exige `Idempotency-Key` para evitar duplo débito em reenvio do app).

### 6.6 Outbox / Inbox

Tabela `outbox_mensagens`, publicador em background a cada 1 s. O publicador do outbox passa a suportar dois destinos por mensagem (RabbitMQ e, para `RecargaEstornada`, também Kafka), controlados por uma coluna `destino` na tabela.

## 7. Schema / Modelo de Persistência

`recargas` (id uuid pk, tenant_id uuid, numero_cartao char(16), valor_centavos bigint, meio_pagamento text, status text, cobranca_id text unique, estorno_id text nullable, estornado_em timestamptz nullable, criado_em, atualizado_em, criado_por); índice (tenant_id, numero_cartao, criado_em desc). `saldos_cartao` (tenant_id, numero_cartao pk composta, saldo_centavos bigint, versao int). `auditoria_recargas` (id, tenant_id, recarga_id, status_anterior, status_novo, autor, origem, instante), retenção 5 anos (RNF-03). `outbox_mensagens` ganha a coluna `destino` (`rabbitmq` | `kafka`) para roteamento do publicador (seção 6.6).

## 8. API Contracts

- `POST /v1/recargas` — JWT do app; body `{numero_cartao, valor_centavos, meio_pagamento}`; 201; erros RCG-ERR-001, 002, 003, 010.
- `GET /v1/recargas?cursor=&limite=` — JWT do app; 200; erros RCG-ERR-004.
- `POST /v1/webhooks/pagfacil` — assinatura HMAC do PagFacil; 204; erros RCG-ERR-005, 006.
- `POST /v1/recargas/{id}/estorno` — JWT do app; a recarga precisa estar `paga`, pertencer ao `sub` do token e estar dentro de 7 dias corridos da confirmação; 202 (estorno assíncrono, aguarda confirmação do PagFacil); erros RCG-ERR-002, 007, 008, 009, 010.
- `POST /v1/webhooks/pagfacil/estornos` — assinatura HMAC do PagFacil, confirmação assíncrona do reembolso; 204; erros RCG-ERR-005, 006.

## 9. AsyncAPI / Eventos Publicados e Consumidos

Publicado: `RecargaPagaIntegrationEvent` v1 (`recarga_id`, `numero_cartao`, `valor_centavos`, `event_version`, `correlation_id`, `causation_id`, `idempotency_key`), routing key `<tenant>.recarga.paga` no RabbitMQ, consumido pela bilhetagem embarcada (RNF-04).

Publicado (RF-06): `RecargaEstornadaIntegrationEvent` v1 (`recarga_id`, `numero_cartao`, `valor_centavos`, `estorno_id`, `motivo`, `event_version`, `correlation_id`, `causation_id`, `idempotency_key`) em dois destinos: (a) RabbitMQ, routing key `<tenant>.recarga.estornada`, consumido pela bilhetagem embarcada para o aviso de débito (mesmo contrato de entrega ao menos uma vez de RNF-04); (b) tópico Kafka `recarga.estornada` (partição por `numero_cartao`, chave = `numero_cartao`), consumido pelo time de dados para o painel de chargeback — ver DD-002 sobre a dualidade de transporte e seus riscos.

## 10. Segurança

JWT com claim `tenant` e `sub`; o cartão precisa estar vinculado ao `sub` (RNF-02); webhook validado por HMAC-SHA256 com segredo no Vault; `numero_cartao` mascarado em logs (últimos 4).

## 11. Observabilidade

Logs estruturados com `correlation_id`; métricas `recarga_solicitada_total`, `recarga_paga_total`, `webhook_duplicado_total`, `outbox_atraso_segundos`; alerta se `outbox_atraso_segundos` > 30 por 5 min.

## 12. Catálogo de Erros

| Código | Mensagem | HTTP Status | Quando ocorre | Ação recomendada |
|--------|----------|-------------|---------------|------------------|
| `RCG-ERR-001` | Valor de recarga fora da faixa permitida | 422 | RF-02 violado | Informar valor entre R$ 5,00 e R$ 500,00 múltiplo de R$ 0,50 |
| `RCG-ERR-002` | Cartão não encontrado | 404 | Cartão inexistente ou não vinculado ao usuário | Verificar o cartão |
| `RCG-ERR-003` | Meio de pagamento indisponível | 503 | PagFacil fora ou circuito aberto | Tentar novamente mais tarde |
| `RCG-ERR-004` | Parâmetro de paginação inválido | 400 | Cursor ou limite inválido | Corrigir parâmetros |
| `RCG-ERR-005` | Assinatura do webhook inválida | 401 | HMAC não confere | Nenhuma (log de segurança) |
| `RCG-ERR-006` | Cobrança desconhecida | 404 | cobranca_id sem recarga | Conciliação manual |
| `RCG-ERR-007` | Recarga fora do prazo de estorno | 422 | Mais de 7 dias corridos desde a confirmação do pagamento | Não é possível estornar; abrir chamado com a operadora |
| `RCG-ERR-008` | Saldo insuficiente para estorno | 422 | Saldo atual do cartão menor que o valor da recarga | Aguardar saldo suficiente antes de solicitar o estorno |
| `RCG-ERR-009` | Recarga não elegível para estorno | 409 | Recarga não está em status `paga` (ex.: já estornada, expirada ou pendente) | Verificar o status atual da recarga |
| `RCG-ERR-010` | Requisição duplicada com corpo divergente | 409 | Idempotency-Key reutilizada | Gerar nova chave |

## 13. Testes

Domínio: xUnit + FsCheck para PBT-01 e PBT-02. Aplicação: handlers com fakes. Infraestrutura: Testcontainers PostgreSQL e RabbitMQ. API: WebApplicationFactory. Arquitetura: NetArchTest. Contrato: Pact com a bilhetagem.

## 14. Multi-tenancy

Filtro global EF por `tenant_id` do claim `tenant` (ADR-0004); routing keys prefixadas pelo tenant.

## 15. Performance e Escalabilidade

RNF-01: p95 < 400 ms medido por histograma `recarga_solicitar_duracao_ms`; 3 réplicas com HPA por CPU 70 %.

## 16. Diagramas

### 16.1 C4 Level 1 - System Context

App, Recarga, PagFacil e Bilhetagem.

```mermaid
flowchart LR
    App[App Mobi] --> Rcg[Servico Recarga]
    Rcg --> Pag[PagFacil]
    Pag --> Rcg
    Rcg --> Bil[Bilhetagem]
```

### 16.2 C4 Level 2 - Container

```mermaid
flowchart LR
    Api[Recarga Api] --> Db[(PostgreSQL)]
    Api --> Mq[RabbitMQ]
```

### 16.3 C4 Level 3 - Component

Não aplicável nesta versão.

### 16.4 Sequence Diagrams

```mermaid
sequenceDiagram
    PagFacil->>Api: webhook pago
    Api->>Db: credita saldo e grava outbox
    Api->>RabbitMQ: RecargaPaga
```

Fluxo de estorno (RF-06):

```mermaid
sequenceDiagram
    App->>Api: POST /v1/recargas/{id}/estorno
    Api->>Db: valida elegibilidade (paga, <= 7 dias, saldo >= valor)
    Api->>Db: debita saldo e grava outbox (estorno solicitado)
    Api->>PagFacil: solicita reembolso da cobranca
    PagFacil-->>Api: webhook de confirmacao do reembolso
    Api->>Db: marca recarga como estornada e grava outbox (RecargaEstornada)
    Api->>RabbitMQ: RecargaEstornada (aviso de debito a bilhetagem)
    Api->>Kafka: RecargaEstornada (painel de chargeback)
```

### 16.5 State Diagrams

```mermaid
stateDiagram-v2
    [*] --> pendente_pagamento
    pendente_pagamento --> paga
    pendente_pagamento --> expirada
    paga --> estornada
```

## 17. Decisões Inline

### DD-001 - Concorrência otimista no saldo

**Contexto:** webhooks repetidos e concorrentes (RF-03).

**Decisão:** coluna `versao` em `saldos_cartao` com retry de 3 tentativas.

**Justificativa:** evita lock pessimista na tabela mais acessada.

**Alternativas:** `SELECT FOR UPDATE` (rejeitado por contenção em pico).

**Impacto:** conflito raro gera retry e latência extra.

### DD-002 - Publicação dupla de `RecargaEstornada` (RabbitMQ + Kafka)

**Contexto:** RF-06 exige avisar a bilhetagem embarcada do débito (consumidor interno, já integrado via RabbitMQ pelo ADR-0002) e, adicionalmente, o time de dados quer consumir o mesmo evento direto de um tópico Kafka para o painel de chargeback.

**Decisão:** o outbox publica `RecargaEstornada` duas vezes a partir da mesma linha de outbox: uma no RabbitMQ (routing key `<tenant>.recarga.estornada`, consumida pela bilhetagem) e outra em um tópico Kafka dedicado (`recarga.estornada`, consumido pelo time de dados).

**Justificativa:** atende ao pedido do time de dados sem alterar o transporte já usado pela bilhetagem.

**Alternativas:** (a) publicar só no RabbitMQ e o time de dados assinar via um consumidor-ponte que replica para o Kafka — mais aderente ao ADR-0002 (RabbitMQ como único barramento de eventos do domínio) e evita introduzir um segundo broker no módulo, mas empurra a integração para outro serviço/PR; (b) publicar só no Kafka e migrar a bilhetagem também para lá — fora de escopo de RF-06 e quebra o consumidor já em produção. Optou-se pela publicação dupla (a) por ser a mudança mínima que atende ao pedido explícito do time de dados sem tocar no consumidor de bilhetagem.

**Impacto:** introduz Kafka como segunda tecnologia de mensageria no módulo, hoje mono-broker (ADR-0002); a linha de outbox precisa ser marcada como entregue somente quando os dois destinos confirmarem, ou aceitar entrega ao menos uma vez independente por destino (adotado, mesma semântica de RNF-04); operação passa a depender de disponibilidade e observabilidade de dois brokers. **Este ponto é uma divergência de ADR-0002 e deveria ser submetido a um ADR próprio antes da implementação** — este design registra a decisão para viabilizar RF-06, mas recomenda-se validar com arquitetura se a alternativa (a) (consumidor-ponte fora deste módulo) não é preferível antes de aprovar esta versão para desenvolvimento.

## 18. Riscos

Webhook do PagFacil fora de ordem; mitigado por máquina de estados e conciliação diária. Estorno solicitado duas vezes para a mesma recarga (duplo clique, reenvio do app); mitigado por `Idempotency-Key` e pela máquina de estados (`paga → estornada` é transição única). Falha de publicação em um dos dois destinos de `RecargaEstornada` (RabbitMQ ok, Kafka fora, ou vice-versa) deixa os dois consumidores dessincronizados; mitigado por retry do publicador do outbox por destino e alerta de atraso (seção 11). Introdução do Kafka como segundo broker aumenta a superfície operacional do módulo (ver DD-002).

## 19. Definition of Done

Todos os RF/RNF/PBT com teste verde, incluindo PBT-03; NetArchTest verde; contrato Pact publicado (bilhetagem); esquema do evento `RecargaEstornada` publicado e validado para o consumidor Kafka do time de dados; dashboards criados.

## 20. Referências

requirements.md v1.3.0; ADR-0001 a ADR-0004; DD-002 (pendente de ADR formal, ver seção 17).
