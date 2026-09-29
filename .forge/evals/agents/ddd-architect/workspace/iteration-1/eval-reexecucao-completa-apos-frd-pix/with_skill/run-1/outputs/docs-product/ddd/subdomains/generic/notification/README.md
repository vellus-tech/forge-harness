# Notification

## 1. Classificação
- Tipo: Generic Subdomain

## 2. Descrição
Envio de push notification ao app quando o saldo do passageiro cai abaixo de duas tarifas.

## 3. Justificativa da Classificação
Capacidade commodity, substituível por qualquer provedor de push (FCM/APNs) sem regra de negócio própria — não há linguagem ubíqua nem invariante que justifique um bounded context próprio.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-05 | Notification | Notificar passageiro sobre saldo baixo |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| LowBalanceNotified | Push de saldo baixo foi enviado ao passageiro |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| FR-08 | Quando o saldo cai abaixo de 2 tarifas, o app envia push |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Card Wallet | Consolidar — Notification vira adapter de saída do Card Wallet (BC-05, decisão "Consolidar com outro contexto") |

## 8. Pontos a Validar
- Nenhum ponto novo identificado nesta execução (v1.1) — subdomínio inalterado desde v1.0.
