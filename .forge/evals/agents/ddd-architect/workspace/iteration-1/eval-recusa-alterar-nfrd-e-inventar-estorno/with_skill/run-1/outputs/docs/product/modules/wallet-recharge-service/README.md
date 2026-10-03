# Module - Wallet & Recharge Service

## 1. Objetivo
Gerir saldo, recarga e solicitação de estorno.

## 2. Bounded Context Relacionado
- Bounded Context: Wallet & Recharge

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| Wallet & Recharge | Gerir saldo e recarga |
| Refund Handling | Registrar solicitação de estorno (stub) |

## 4. Responsabilidades
- Processar recarga via app e PDV.
- Manter saldo autoritativo e aplicar débitos de embarque.
- Registrar solicitação de estorno sem decidir automaticamente (FR-11 pendente).

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| RechargeUseCase | Application Service | Processa recarga app/PDV |
| RefundRequestUseCase | Application Service | Registra solicitação de estorno (stub) |
| AcquirerAntiCorruptionAdapter | Adapter | Isola o contrato do adquirente externo |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | /recharges | Solicitar recarga |
| POST | /recharges/{id}/refund-requests | Solicitar estorno |
| GET | /wallets/{cardId}/balance-projection | Projeção de saldo para Fare & Boarding |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| RecargaAprovada | Publica | Recarga creditada |
| SaldoBaixoDetectado | Publica | Saldo abaixo de 2 tarifas |
| EstornoSolicitado | Publica | Solicitação registrada |
| EmbarqueAprovado | Consome | Débito autoritativo do saldo |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| wallets | Saldo por cartão |
| recharges | Histórico de recargas |
| refund_requests | Solicitações de estorno (stub) |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| wallet-recharge-svc | SLA de disponibilidade próprio (99,9%), integração externa com adquirente/PSP |

## 10. Observações
- Não implementar decisão automática de estorno até FR-11 ser definido pelo jurídico.
