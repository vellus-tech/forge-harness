# Module - Passenger App

## 1. Objetivo
Interface do passageiro para autenticação, recarga, consulta de saldo, histórico de viagens e bloqueio de cartão.

## 2. Bounded Context Relacionado
- Transversal — BFF/frontend que consome Identity and Access, Recharge, Passenger Wallet e Fare Collection. Não possui bounded context próprio (é espaço de solução puro, sem linguagem de domínio própria).

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-03, CAP-05 | Recarga e autenticação, principal ponto de entrada do passageiro |

## 4. Responsabilidades
- Login (Identity and Access).
- Solicitar recarga via cartão (Recharge).
- Consultar saldo e histórico de viagens (Passenger Wallet, Fare Collection).
- Bloquear o próprio cartão (Passenger Wallet).
- Receber push (Notification, via FCM SDK).

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| — | — | Aplicativo mobile; sem lógica de domínio própria, apenas orquestração de chamadas às APIs |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| — | — | Consumidor das APIs dos demais módulos |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| — | — | Não publica nem consome eventos de domínio diretamente |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| — | Nenhum dado de domínio próprio |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| passenger-app | Ciclo de release de app mobile, independente dos backends |

## 10. Observações
- Nunca deve conter regra de negócio de tarifa, saldo ou antifraude — apenas apresentação e orquestração de chamadas REST externas (TEC-01).
