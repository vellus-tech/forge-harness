# Data Model — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do data model orientado por ownership de bounded contexts |

## 1. Princípios de Ownership
- Cada bounded context possui ownership claro sobre seus dados; um único schema PostgreSQL por serviço (TEC-02).
- Apenas o contexto dono pode escrever diretamente em suas tabelas.
- Outros contextos consomem via evento (fila RabbitMQ), API REST/gRPC ou read model — nunca via acesso direto ao schema de outro contexto.
- Não há Shared Kernel de dados; `Money` é compartilhado apenas como tipo de valor (biblioteca), não como tabela.
- Joins diretos entre schemas de contextos diferentes são proibidos.

## 2. Data Ownership Matrix
| Bounded Context | Entidade/Tabela/Collection | Tipo | Dono da Escrita | Consumidores | Forma de Consumo |
|---|---|---|---|---|---|
| Fare Collection | boardings | Transacional | Fare Collection | Passenger Wallet, Settlement | Evento (FareCharged, BoardingRejected) |
| Fare Collection | tariff_rules | Referência | Fare Collection | — | Interno |
| Fare Collection | boarding_batches | Transacional | Fare Collection | — | Interno (idempotência de sincronização) |
| Passenger Wallet | wallets | Transacional | Passenger Wallet | Fare Collection | Read Model (BlocklistSnapshot) |
| Passenger Wallet | balance_ledger_entries | Transacional | Passenger Wallet | Settlement (auditoria) | Evento (BalanceDebited) |
| Passenger Wallet | card_block_list | Transacional | Passenger Wallet | Fare Collection | Read Model (BlocklistSnapshot) |
| Recharge | recharge_requests | Transacional | Recharge | Passenger Wallet | Evento (RechargeApproved) |
| Settlement | clearing_batches | Transacional (append-only) | Settlement | Operadoras | API/Arquivo (Open Host Service) |
| Settlement | clearing_line_items | Transacional | Settlement | — | Interno |
| Settlement | clearing_adjustments | Transacional (append-only) | Settlement | Operadoras | API/Arquivo |
| Identity and Access | passenger_accounts | Transacional | Identity and Access | Passenger Wallet, Recharge, Fare Collection | API (token/identidade, Conformist) |
| Notification | notification_log | Operacional | Notification | — | Interno |

## 3. Entidades por Contexto

### Fare Collection
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| Boarding | Aggregate | Registro de um embarque, com decisão e tarifa aplicada | boardings |
| TariffRule | Value Object | Tarifa vigente por linha e regra de integração temporal | tariff_rules |
| BoardingBatch | Entity | Controle de lote sincronizado do validador | boarding_batches |
| Fare | Value Object | Valor monetário da tarifa aplicada | embutido em boardings |

### Passenger Wallet
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| Wallet | Aggregate | Saldo e estado de bloqueio de um cartão | wallets |
| BalanceLedgerEntry | Entity | Lançamento individual de crédito/débito | balance_ledger_entries |
| BlocklistSnapshot | Read Model | Fotografia consistente publicada para consumo offline | derivado de wallets + card_block_list |

### Recharge
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| RechargeRequest | Aggregate | Solicitação de recarga com status | recharge_requests |

### Settlement
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| ClearingBatch | Aggregate | Apuração diária consolidada por operadora | clearing_batches |
| ClearingLineItem | Entity | Atribuição de um embarque a uma operadora | clearing_line_items |
| ClearingAdjustment | Entity | Correção pós-publicação | clearing_adjustments |

### Identity and Access
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| PassengerAccount | Aggregate | Credencial e configuração de MFA | passenger_accounts |

### Notification
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| NotificationLogEntry | Event | Registro de um envio de push | notification_log |

## 4. Fronteiras de Persistência
| Origem | Destino | Permitido? | Forma Correta | Observação |
|---|---|---|---|---|
| Fare Collection | Passenger Wallet (banco) | Não | Evento (FareCharged) | Nunca ler/escrever diretamente em `wallets` |
| Passenger Wallet | Fare Collection (banco) | Não | Read Model (BlocklistSnapshot) | Snapshot é a única forma de leitura cross-context |
| Recharge | Passenger Wallet (banco) | Não | Evento (RechargeApproved) | — |
| Fare Collection | Settlement (banco) | Não | Evento (FareCharged) | — |
| Qualquer contexto | passenger_accounts (Identity) | Não | API de identidade (token) | Conformist ao contrato de Identity |
| Qualquer serviço | recharge_requests (dados de cartão) | Não aplicável | PAN nunca é persistido em nenhum schema da Tarifa Viva | NFR-03 |

## 5. Eventos Persistidos
| Evento | Contexto Dono | Persistência | Retenção | Consumidores |
|---|---|---|---|---|
| FareCharged | Fare Collection | boardings + outbox de eventos | 5 anos (NFR-04) | Passenger Wallet, Settlement |
| BoardingRejected | Fare Collection | boardings + outbox de eventos | 5 anos | Auditoria interna |
| RechargeApproved | Recharge | recharge_requests + outbox de eventos | 5 anos | Passenger Wallet |
| BalanceLow | Passenger Wallet | outbox de eventos (não persistido como tabela própria) | Operacional | Notification |
| ClearingPublished | Settlement | clearing_batches (imutável) | 5 anos | Operadoras |
| ClearingAdjustmentIssued | Settlement | clearing_adjustments (append-only) | 5 anos | Operadoras, auditoria |

## 6. Read Models e Views
| Read Model/View | Dono | Fontes | Consumidores | Atualização |
|---|---|---|---|---|
| BlocklistSnapshot | Passenger Wallet | wallets, card_block_list | Fare Collection (via ACL do validador) | Periódica (a definir com produto — candidata a cada sincronização de garagem) |
| BoardingHistory (30 dias) | Fare Collection | boardings | Passenger App | Em tempo real (consulta direta ao read model, janela de 30 dias sobre a retenção de 5 anos — ver VAL-06) |

## 7. Pontos a Validar
- VAL-01 — comportamento do ledger (`balance_ledger_entries`) diante de saldo insuficiente detectado apenas na reconciliação pós-embarque offline.
- VAL-06 — confirmar que a janela de exibição de 30 dias ao passageiro (PRD §5) é uma visão sobre o armazenamento de 5 anos (NFR-04), não uma política de retenção distinta.
