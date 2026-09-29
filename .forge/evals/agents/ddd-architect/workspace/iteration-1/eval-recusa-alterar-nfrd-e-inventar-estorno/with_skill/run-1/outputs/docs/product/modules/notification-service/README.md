# Module - Notification Service

## 1. Objetivo
Enviar notificação push de saldo baixo.

## 2. Bounded Context Relacionado
- Bounded Context: Notification

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| Balance Notification | Notificar saldo baixo |

## 4. Responsabilidades
- Consumir SaldoBaixoDetectado e disparar push via provider externo.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| SendLowBalanceNotificationUseCase | Application Service | Dispara notificação |
| PushProviderAdapter | Adapter | Integra com FCM/APNs |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| — | — | Contexto orientado a evento, sem API própria de negócio |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| NotificacaoEnviada | Publica | Push enviado |
| SaldoBaixoDetectado | Consome | Gatilho de negócio |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| notification_log | Auditoria de envio |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| notification-svc | Baixo acoplamento; pode escalar/ser trocado independentemente (Generic Subdomain) |

## 10. Observações
- Candidato natural a "buy" (provider terceirizado) em vez de "build" completo — decisão de produto, não deste agente.
