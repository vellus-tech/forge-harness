# Module - Passenger Wallet API

## 1. Objetivo
Manter o saldo autoritativo e a blocklist do passageiro, reconciliar débitos e créditos, e publicar o snapshot consumido offline.

## 2. Bounded Context Relacionado
- Bounded Context: Passenger Wallet

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-02 | Passenger Wallet |

## 4. Responsabilidades
- Reconciliar `FareCharged` como débito autoritativo.
- Aplicar `RechargeApproved` como crédito.
- Bloquear/desbloquear cartão.
- Publicar `BlocklistSnapshotPublished` e disparar `BalanceLow`.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| ReconcileFareChargeUseCase | Application Service | Aplica débito autoritativo a partir do evento |
| CreditBalanceUseCase | Application Service | Aplica crédito a partir de recarga aprovada |
| BlockCardUseCase | Application Service | Bloqueia/desbloqueia cartão |
| WalletRepository | Repository | Persistência de wallets e ledger |
| PublishBlocklistSnapshotUseCase | Adapter | Gera o snapshot consumido pelo Fare Collection |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | /wallets/{cardId}/block | Bloquear cartão |
| GET | /wallets/{cardId}/balance | Consultar saldo |
| GET | /wallets/blocklist-snapshot | Snapshot para consumo offline |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| FareCharged | Consome | Insumo da reconciliação de débito |
| RechargeApproved | Consome | Insumo do crédito |
| BalanceCredited, BalanceDebited, CardBlocked, BalanceLow, BlocklistSnapshotPublished | Publica | Eventos próprios do Wallet |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| wallets | Saldo e estado de bloqueio |
| balance_ledger_entries | Histórico de lançamentos |
| card_block_list | Cartões bloqueados |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| passenger-wallet-service | Ativo financeiro central; ciclo de release e criticidade próprios |

## 10. Observações
- VAL-01 precisa ser resolvido antes de definir o comportamento exato de `ReconcileFareChargeUseCase` diante de saldo insuficiente pós-fato.
