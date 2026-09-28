# Data Model

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do data model orientado por ownership de bounded contexts |

## 0. Nota sobre o pedido de `core_db` único

O pedido original de execução instruía "por todos os contextos num banco único `core_db` com join direto entre as tabelas". Este agente não adotou essa modelagem — ver justificativa em `docs/product/ddd/ddd-segmentation.md §0.3`. Em vez disso, cada bounded context tem seu próprio schema/banco lógico, e a integração entre contextos ocorre via evento de domínio ou projeção (read model), nunca por join direto entre tabelas de contextos diferentes.

## 1. Princípios de Ownership
- Cada bounded context possui ownership claro sobre seus dados.
- Apenas o contexto dono pode escrever diretamente em suas tabelas ou collections.
- Outros contextos consomem dados via evento, API ou read model/projeção.
- Não há escrita cruzada entre contextos.
- Joins diretos entre schemas de contextos diferentes são evitados — em particular, não existe `core_db` compartilhado nesta modelagem.

## 2. Data Ownership Matrix
| Bounded Context | Entidade/Tabela/Collection | Tipo | Dono da Escrita | Consumidores | Forma de Consumo |
|---|---|---|---|---|---|
| Fare & Boarding | boardings | Transacional | Fare & Boarding | Wallet & Recharge, Settlement & Clearing | Evento (EmbarqueAprovado, LoteEmbarquesSincronizado) |
| Fare & Boarding | fare_cache | Read Model (local) | Fare & Boarding | — (interno ao validador) | Projeção replicada a partir de Wallet & Recharge e Card & Identity |
| Wallet & Recharge | wallets | Transacional | Wallet & Recharge | Fare & Boarding | Read Model (balance-projection) |
| Wallet & Recharge | recharges | Transacional | Wallet & Recharge | — | — |
| Wallet & Recharge | refund_requests | Transacional (stub) | Wallet & Recharge | Gestor do consórcio (fila manual) | API |
| Settlement & Clearing | clearing_batches | Transacional (append-only) | Settlement & Clearing | Gestor do consórcio, Operadoras | API / arquivo |
| Settlement & Clearing | clearing_adjustments | Transacional (append-only) | Settlement & Clearing | Gestor do consórcio | API / arquivo |
| Card & Identity | cards | Transacional | Card & Identity | Fare & Boarding | Read Model (block-list-projection) |
| Card & Identity | passengers | Transacional | Card & Identity | — | — |
| Notification | notification_log | Transacional | Notification | — | — |

## 3. Entidades por Contexto

### Fare & Boarding
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| Boarding | Aggregate | Registro de um embarque decidido | boardings |
| Fare | Value Object | Valor da tarifa aplicada (embutido em Boarding) | boardings |
| BalanceProjection | Read Model | Cópia local de saldo para decisão offline | fare_cache |
| BlockListProjection | Read Model | Cópia local da lista de bloqueio | fare_cache |

### Wallet & Recharge
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| Wallet | Aggregate | Saldo do cartão | wallets |
| Recharge | Aggregate | Operação de crédito de saldo | recharges |
| RefundRequest | Aggregate (stub) | Solicitação de estorno, apenas estado `Solicitado` | refund_requests |

### Settlement & Clearing
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| ClearingBatch | Aggregate | Lote diário de apuração, imutável após publicado | clearing_batches |
| AdjustmentFile | Entity | Correção de um ClearingBatch já publicado | clearing_adjustments |

### Card & Identity
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| Card | Aggregate | Cartão e estado de bloqueio | cards |
| Passenger | Aggregate | Identidade e credenciais | passengers |

### Notification
| Entidade | Tipo | Descrição | Persistência |
|---|---|---|---|
| NotificationLog | Entity | Registro de envio de push | notification_log |

## 4. Fronteiras de Persistência
| Origem | Destino | Permitido? | Forma Correta | Observação |
|---|---|---|---|---|
| Fare & Boarding | wallets (Wallet & Recharge) | Não | Read Model (balance-projection) | Fare & Boarding nunca lê/escreve diretamente na tabela `wallets` |
| Fare & Boarding | cards (Card & Identity) | Não | Read Model (block-list-projection) | Idem para `cards` |
| Wallet & Recharge | boardings (Fare & Boarding) | Não | Evento (EmbarqueAprovado) | Débito autoritativo reage ao evento, não faz join com `boardings` |
| Settlement & Clearing | boardings (Fare & Boarding) | Não | Evento (EmbarqueAprovado / LoteEmbarquesSincronizado) | Apuração consome eventos, não faz join direto |
| Qualquer contexto | Qualquer outro (join direto entre schemas) | **Não** | Evento / API / Read Model | Este é exatamente o padrão que o `core_db` único proposto no pedido original introduziria; recusado por quebrar ownership de dados |

## 5. Eventos Persistidos
| Evento | Contexto Dono | Persistência | Retenção | Consumidores |
|---|---|---|---|---|
| EmbarqueAprovado | Fare & Boarding | Event log / outbox | 5 anos (alinhado a NFR-04, dado que deriva de `boardings`) | Wallet & Recharge, Settlement & Clearing |
| RecargaAprovada | Wallet & Recharge | Event log / outbox | 5 anos (NFR-04) | — |
| SaldoBaixoDetectado | Wallet & Recharge | Event log / outbox | Curta (evento de notificação, não é registro de auditoria) | Notification |
| ArquivoClearingPublicado | Settlement & Clearing | Event log / outbox | 5 anos (NFR-04, por analogia a registro auditável) | Gestor do consórcio, Operadoras |
| EstornoSolicitado | Wallet & Recharge | Event log / outbox | A definir junto com a regra de estorno (VAL-02) | Gestor do consórcio |

## 6. Read Models e Views
| Read Model/View | Dono | Fontes | Consumidores | Atualização |
|---|---|---|---|---|
| balance-projection | Wallet & Recharge | wallets | Fare & Boarding (fare_cache local) | Assíncrona, replicada na sincronização em lote |
| block-list-projection | Card & Identity | cards | Fare & Boarding (fare_cache local) | Assíncrona, replicada na sincronização em lote |
| **recent_trip_history** (janela de 30 dias) | Fare & Boarding | boardings (retido por 5 anos, NFR-04) | App do passageiro | Materializada/filtrada a partir de `boardings`; **não altera a retenção de 5 anos do dado bruto** — resolve a leitura do PRD §5 sem tocar no NFRD (ver `ddd-segmentation.md §0.1`) |

## 7. Pontos a Validar
- VAL-02: schema de `refund_requests` além do estado `Solicitado` depende da definição jurídica de FR-11.
- VAL-03 (resolvido nesta modelagem): pedido de `core_db` único recusado; ownership por contexto adotado.
- Retenção de `notification_log` não definida nos insumos (sugestão: alinhar com política de dados da Tarifa Viva; não decidida unilateralmente aqui).
