# Notification

## 1. Classificação
- Tipo: Generic Subdomain

## 2. Descrição
Envia push de saldo baixo ao passageiro via Firebase Cloud Messaging.

## 3. Justificativa da Classificação
Envio de notificação push é capacidade comum, já delegada a um provedor terceirizado (FCM); não há regra de negócio complexa além de disparar quando o saldo cruza o limiar.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-06 | Notification | Notificar saldo baixo |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| PushNotificationSent | Push de saldo baixo enviado com sucesso |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| RULE-08 | Push de saldo baixo dispara quando saldo < 2 tarifas (regra pertence ao Wallet; Notification apenas consome o evento `BalanceLow`) |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Notification | Contexto 1:1 com o subdomínio |

## 8. Pontos a Validar
- VAL-04 — contexto fino; avaliar se compensa mantê-lo separado ou torná-lo um serviço compartilhado entre produtos do grupo
