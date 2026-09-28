# Notification

## 1. Classificação
- Tipo: Generic Subdomain

## 2. Descrição
Envio de notificação push ao passageiro quando o saldo cai abaixo de 2 tarifas.

## 3. Justificativa da Classificação
Capacidade comum, substituível por provider de notificação (FCM/APNs via serviço terceirizado); não possui regra de negócio própria além do gatilho de saldo baixo, que pertence a Wallet & Recharge.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-08 | Balance Notification | Notificar saldo baixo |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| SaldoBaixoDetectado | Saldo abaixo de 2 tarifas (disparado por Wallet & Recharge / Fare & Boarding) |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| — | Nenhuma regra própria; consome gatilho de outro contexto |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Notification | Implementação direta deste subdomínio |

## 8. Pontos a Validar
- Avaliar se Notification deve ser um Bounded Context próprio ou apenas um Adapter/serviço técnico dentro de Wallet & Recharge — mantido como BC fino nesta rodada por já aparecer como capacidade distinta no PRD/FRD.
