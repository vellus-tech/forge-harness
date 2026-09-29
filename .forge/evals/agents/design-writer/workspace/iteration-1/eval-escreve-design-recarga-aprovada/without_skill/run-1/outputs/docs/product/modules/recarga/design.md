# RCG — Recarga de Cartão de Transporte
**Design Técnico**

- Versão: 0.1.0
- Data: 2026-09-26
- Baseado em: requirements.md v1.2.0 (aprovado por @carla-mendes e @joao-reis em 2026-09-18)
- ADRs aplicados: ADR-0001 (stack .NET/PostgreSQL), ADR-0002 (RabbitMQ/Outbox), ADR-0003 (gRPC interno/REST externo), ADR-0004 (multi-tenancy por operadora)

## 1. Visão geral

O módulo RCG expõe uma API REST para o app Mobi solicitar e consultar recargas de saldo, integra de forma assíncrona com o gateway de pagamento externo PagFacil via webhook, e publica um evento de integração para a bilhetagem embarcada assim que o saldo é creditado. Segue Clean Architecture em cinco projetos por ADR-0001: `Recarga.Domain`, `Recarga.Application`, `Recarga.Infrastructure`, `Recarga.Api` e `Recarga.Contracts`.

Como a comunicação com PagFacil é com um terceiro, ela é REST (webhook recebido, checkout consultado por REST) por ADR-0003. A notificação para a bilhetagem embarcada é interna ao ecossistema Mobi e assíncrona, então usa evento no RabbitMQ (ADR-0002) em vez de gRPC síncrono — o requisito RNF-04 pede entrega "ao menos uma vez" em até 60 s, o que é natural para uma fila com Inbox/DLQ e não exigiria uma chamada síncrona bloqueante.

## 2. Modelo de domínio

### 2.1 Agregado `Recarga`

Raiz do agregado, em `Recarga.Domain`.

- `id` (uuid, gerado no servidor)
- `tenant_id` (uuid, a operadora — ADR-0004)
- `numero_cartao` (string, 16 dígitos)
- `usuario_id` (uuid, dono da recarga, para RNF-02 de isolamento)
- `valor_centavos` (bigint, ADR-0001 exige monetário como bigint em centavos)
- `meio_pagamento` (enum: `pix`, `cartao_credito`)
- `status` (enum: `pendente_pagamento`, `paga`, `expirada`)
- `pagfacil_referencia` (string, id da cobrança no PagFacil)
- `criada_em`, `atualizada_em`, `expira_em` (timestamptz)

Transições de estado válidas (máquina de estados do agregado):

```
pendente_pagamento --(webhook pago, antes de expira_em)--> paga
pendente_pagamento --(job de expiração, agora >= expira_em)--> expirada
paga / expirada --(qualquer evento)--> inalterado (transição final)
```

Qualquer webhook que chegue com a recarga já em `paga` ou `expirada` é apenas registrado para conciliação (RF-04) e não dispara novo crédito — é a base da idempotência exigida por RF-03/PBT-01.

### 2.2 Entidade `RecargaAuditoria`

Uma linha por mudança de status (RNF-03: autor, instante, origem, retenção de 5 anos). Nunca é atualizada, só inserida (append-only).

- `id`, `recarga_id`, `status_anterior`, `status_novo`, `origem` (`api`, `webhook_pagfacil`, `job_expiracao`), `autor` (`usuario_id` ou `sistema`), `criado_em`

### 2.3 Persistência (PostgreSQL 16 / EF Core, ADR-0001)

Tabelas físicas em snake_case: `recargas` e `recarga_auditorias`. Ambas com `tenant_id uuid not null` e índice composto começando por `tenant_id`, conforme ADR-0004; o EF Core aplica o filtro global de tenant a partir do claim `tenant` do JWT — nenhuma query do módulo precisa (nem pode) filtrar `tenant_id` manualmente, o que também cobre RNF-02.

Índices adicionais:

- `recargas (tenant_id, usuario_id, criada_em desc)` para a listagem paginada de RF-05.
- `recargas (pagfacil_referencia)` único, para casar o webhook com a recarga.
- `recargas (status, expira_em)` para o job de expiração varrer só `pendente_pagamento` vencidas.

## 3. API REST (para o app Mobi — ADR-0003)

Contrato OpenAPI 3.1, prefixo `/api/v1/recargas`. Autenticação por JWT com claim `tenant`.

- `POST /api/v1/recargas` — RF-01. Corpo: `numero_cartao`, `valor_centavos`, `meio_pagamento`. Valida RF-02 (500 ≤ v ≤ 50000, v múltiplo de 50 — PBT-02). Cria a recarga em `pendente_pagamento` com `expira_em = agora + 30min`, chama o PagFacil (client HTTP com timeout de 3 s, RNF-01) para gerar a cobrança e devolve QR Pix ou URL de checkout. Se o PagFacil não responder dentro do timeout, a recarga permanece `pendente_pagamento` e o cliente pode tentar consultar/recriar — a criação da recarga em si não deve depender da resposta do PagFacil ultrapassar o orçamento de latência de RNF-01 (que exclui explicitamente a latência do PagFacil).
- `GET /api/v1/recargas` — RF-05. Paginação por cursor (`criada_em`, `id`) para evitar problemas de offset com inserções concorrentes, ordenado do mais recente para o mais antigo, restrito a `usuario_id` do token e ao tenant do JWT.
- `GET /api/v1/recargas/{id}` — consulta pontual, mesma restrição de posse.

## 4. Webhook do PagFacil

- `POST /api/v1/webhooks/pagfacil` — endpoint REST dedicado, fora do prefixo `/v1/recargas` autenticado por usuário; autenticado por segredo compartilhado/assinatura do PagFacil (verificação de assinatura HMAC no cabeçalho, conforme contrato do gateway).
- Fluxo (handler em `Recarga.Application`, command `ConfirmarPagamentoRecarga`):
  1. Localiza a recarga por `pagfacil_referencia`.
  2. Se não encontrada, responde 404 e loga para investigação (não deve acontecer em operação normal).
  3. Se a recarga já está em `paga` ou `expirada`, registra o webhook em `recarga_auditorias` com `origem = webhook_pagfacil` sem mudar o status e sem creditar saldo de novo — é isso que garante RF-03/PBT-01 mesmo com webhook duplicado ou reentregue pelo PagFacil.
  4. Se está `pendente_pagamento` e `agora < expira_em`: dentro de uma única transação de banco, atualiza status para `paga`, credita o saldo do cartão (chamada ao serviço/tabela de saldo do cartão, também sob o mesmo `tenant_id`), grava a linha de auditoria, e grava na tabela de outbox o evento `RecargaPaga` (Transactional Outbox, ADR-0002) — tudo atômico, então não existe estado em que o saldo foi creditado mas o evento não foi gravado, nem o inverso.
  5. Se está `pendente_pagamento` mas `agora >= expira_em` (webhook atrasado após expiração — RF-04): marca a recarga como `expirada` (se o job de expiração ainda não passou) e registra o webhook para conciliação, sem creditar saldo.
- A idempotência do passo 3 é a peça central de PBT-01: não importa quantos webhooks (N ≥ 1) cheguem para a mesma recarga, apenas a primeira transição `pendente_pagamento -> paga` credita saldo; as demais só auditam.

## 5. Job de expiração (RF-04)

Job periódico (a cada 1 minuto) em `Recarga.Infrastructure`, roda por tenant: `update recargas set status = 'expirada' where status = 'pendente_pagamento' and expira_em <= now()`, seguido da inserção correspondente em `recarga_auditorias` com `origem = job_expiracao`. O índice `(status, expira_em)` mantém essa varredura barata.

## 6. Evento de integração `RecargaPaga` (RabbitMQ, ADR-0002)

Publicado no exchange `mobi.eventos` (topic), routing key prefixada pelo tenant (`<tenant_id>.recarga.paga`, conforme ADR-0004). Payload:

```json
{
  "event_version": 1,
  "correlation_id": "...",
  "causation_id": "...",
  "idempotency_key": "<recarga_id>",
  "tenant_id": "...",
  "numero_cartao": "...",
  "valor_centavos": 0,
  "saldo_atual_centavos": 0,
  "creditado_em": "2026-09-26T00:00:00Z"
}
```

A bilhetagem embarcada consome via Inbox (deduplicação por `idempotency_key = recarga_id`) e atualiza a lista de créditos pendentes dos validadores. O uso de Outbox no publisher e Inbox no consumidor, mais o SLA de consumo, cobre RNF-04 (entrega ao menos uma vez em até 60 s); o tempo de 60 s é orçamento operacional do consumidor e da fila, não uma chamada síncrona bloqueante — se a fila atrasar, o worker de monitoramento de idade de mensagem (fora do escopo deste módulo, item de observabilidade da plataforma) deve alertar antes de estourar o SLA. Falha permanente de consumo cai na DLQ `recarga.paga.dlq` após 5 tentativas com backoff exponencial, por ADR-0002.

## 7. Auditoria e observabilidade (RNF-03)

Toda escrita em `recarga_auditorias` carrega autor, instante e origem; a tabela nunca é expurgada antes de 5 anos (retenção controlada por rotina de arquivamento fora deste módulo, não por delete direto). Logs estruturados incluem `correlation_id`/`causation_id` do evento para permitir rastrear uma recarga do webhook até o consumo pela bilhetagem.

## 8. Riscos e pontos em aberto

- O contrato exato do webhook do PagFacil (payload, assinatura, retry policy deles) não está documentado nos ADRs disponíveis; assumi HMAC por cabeçalho como prática comum de gateway de pagamento, mas isso precisa ser confirmado com a documentação do PagFacil antes da implementação.
- Não há ADR ou requisito definindo o nome/proprietário do serviço de saldo do cartão nem se ele já existe como agregado próprio (bounded context da bilhetagem) ou se este módulo é dono do saldo. Assumi que o crédito de saldo acontece na mesma transação da confirmação de pagamento, dentro deste módulo; se o saldo pertencer a outro serviço, o passo 4 da seção 4 muda de "update local" para uma chamada gRPC interna (ADR-0003) dentro da mesma unidade lógica de trabalho, com compensação em caso de falha — decisão que precisa de confirmação antes de virar tasks.
- Rate limit e proteção contra abuso no `POST /recargas` (ex.: um usuário criando recargas em loop) não estão nos requisitos; sinalizo para a próxima rodada de requirements caso o time de segurança exija.
