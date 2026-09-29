# Module - Recharge API

## 1. Objetivo
Orquestrar as solicitações de recarga via app e ponto de venda.

## 2. Bounded Context Relacionado
- Bounded Context: Recharge

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-03 | Recharge |

## 4. Responsabilidades
- Receber solicitação de recarga via app e delegar antifraude ao Payment Provider Adapters.
- Registrar recarga em dinheiro via ponto de venda.
- Publicar RechargeApproved / RechargeRejected.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| RequestAppRechargeUseCase | Application Service | Orquestra recarga via cartão de crédito |
| RegisterPosRechargeUseCase | Application Service | Registra recarga em dinheiro |
| RechargeRequestRepository | Repository | Persistência das solicitações |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | /recharges/app | Solicitar recarga via app |
| POST | /recharges/pos | Registrar recarga via ponto de venda |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| RechargeApproved | Publica | Recarga aprovada |
| RechargeRejected | Publica | Recarga reprovada pelo antifraude |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| recharge_requests | Solicitações de recarga e status |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| recharge-service | SLA de disponibilidade próprio (99,9%) e escopo PCI reduzido isolável |

## 10. Observações
- Nunca modela nem persiste PAN — delega inteiramente ao Payment Provider Adapters (NFR-03).
