# Data Model

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do data model orientado por ownership de bounded contexts (reexecução v1.1 da segmentação DDD, após FRD v1.3 — recarga via Pix) |

## 1. Princípios de Ownership
- Cada bounded context possui ownership claro sobre seus dados.
- Apenas o contexto dono pode escrever diretamente em suas tabelas ou collections.
- Outros contextos consomem via API ou evento — nunca por acesso direto ao schema de outro contexto.
- `pix_charges` é dado exclusivo de Card Wallet; nenhum outro contexto lê ou escreve nessa tabela diretamente.

## 2. Data Ownership Matrix
| Bounded Context | Entidade/Tabela/Collection | Tipo | Dono da Escrita | Consumidores | Forma de Consumo |
|---|---|---|---|---|---|
| Fare Validation | boardings | Transacional | Fare Validation | Operator Clearing | Evento (BoardingApproved) |
| Card Wallet | card_balances | Transacional | Card Wallet | Fare Validation | API (consulta de saldo) |
| Card Wallet | recharge_attempts | Transacional | Card Wallet | — | — |
| Card Wallet | pix_charges | Transacional | Card Wallet | — | — (novo, FR-10) |
| Operator Clearing | clearing_batches | Transacional | Operator Clearing | Operadoras | Arquivo (Open Host Service) |
| Operator Clearing | clearing_adjustments | Transacional | Operator Clearing | Operadoras | Arquivo (Open Host Service) |
| Identity Access | passenger_credentials | Transacional | Identity Access | Card Wallet | API (identidade autenticada) |

## 3. Entidades por Contexto

### Fare Validation
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| Boarding | Aggregate | Decisão de embarque | boardings |
| FareAmount | Value Object | Valor da tarifa aplicada | embutido em boardings |

### Card Wallet
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| CardBalance | Aggregate | Saldo do cartão | card_balances |
| RechargeAttempt | Entity | Tentativa de recarga (crédito/POS) | recharge_attempts |
| PixCharge | Entity | Cobrança Pix e status de liquidação | pix_charges (novo, FR-10) |
| Money | Value Object | Valor monetário com moeda | embutido |

### Operator Clearing
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| ClearingBatch | Aggregate | Lote diário de repasse | clearing_batches |
| ClearingAdjustment | Entity | Ajuste sobre lote publicado | clearing_adjustments |

### Identity Access
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| PassengerCredential | Aggregate | Credencial e estado de MFA | passenger_credentials |

## 4. Fronteiras de Persistência
| Origem | Destino | Permitido? | Forma Correta | Observação |
|---|---|---|---|---|
| Fare Validation | card_balances (Card Wallet) | Não | API (consulta de saldo) | Fare Validation nunca escreve diretamente no saldo |
| Operator Clearing | boardings (Fare Validation) | Não | Evento (BoardingApproved) | Clearing não lê a tabela diretamente |
| Qualquer contexto | pix_charges (Card Wallet) | Não | Nenhuma — dado interno de Card Wallet | Novo — FR-10; nenhum consumidor externo definido até o momento |

## 5. Eventos Persistidos
| Evento | Contexto Dono | Persistência | Retenção | Consumidores |
|---|---|---|---|---|
| BoardingApproved | Fare Validation | Event Bus | 5 anos (NFR-04) | Operator Clearing |
| FareIntegrationApplied | Fare Validation | Event Bus | 5 anos (NFR-04) | Operator Clearing |
| CardBalanceCredited | Card Wallet | Event Bus | 5 anos (NFR-04) | Notification (adapter) |
| PixSettlementConfirmed | Card Wallet | Event Bus | 5 anos (NFR-04) | — (novo, FR-10) |
| DailyClearingFilePublished | Operator Clearing | Arquivo + Event Bus | 5 anos (NFR-04) | Sistemas das Operadoras |

## 6. Read Models e Views
| Read Model/View | Dono | Fontes | Consumidores | Atualização |
|---|---|---|---|---|
| — | — | — | — | Nenhum read model identificado nesta execução |

## 7. Pontos a Validar
- VAL-02: até a confirmação do contrato do PSP sobre reenvio de webhook, `pix_charges` deve manter uma chave de idempotência própria (`charge_id`) para evitar crédito duplicado em `card_balances`.
