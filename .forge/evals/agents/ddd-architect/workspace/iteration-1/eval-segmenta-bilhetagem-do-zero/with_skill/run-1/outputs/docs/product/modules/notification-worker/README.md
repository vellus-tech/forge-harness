# Module - Notification Worker

## 1. Objetivo
Enviar push de saldo baixo via Firebase Cloud Messaging.

## 2. Bounded Context Relacionado
- Bounded Context: Notification

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-06 | Notification |

## 4. Responsabilidades
- Consumir BalanceLow da fila.
- Enviar push via FCM e registrar o resultado.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| SendLowBalancePushUseCase | Application Service | Orquestra o envio |
| FcmPushAdapter | Adapter | Conformist ao contrato do FCM |
| NotificationLogRepository | Repository | Persistência do log de envio |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| — | — | Worker orientado a fila, sem API síncrona própria |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| BalanceLow | Consome | Disparado pelo Passenger Wallet |
| PushNotificationSent | Publica | Confirmação de envio |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| notification_log | Histórico de envios |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| notification-worker | Consumidor de fila, sem necessidade de exposição HTTP; escalabilidade independente |

## 10. Observações
- Contexto fino (VAL-04); manter simples e evitar sobre-modelagem.
