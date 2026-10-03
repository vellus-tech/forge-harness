# Bounded Context Canvas - Notification

## 1. Objetivo
Notificar o passageiro por push quando o saldo estiver baixo.

## 2. Classificação DDD
- Tipo: Generic Subdomain
- Justificativa: capacidade comum, delegada a provedor terceirizado (FCM).

## 3. Responsabilidades
- Consumir `BalanceLow` publicado pelo Passenger Wallet.
- Enviar push via FCM e registrar o resultado do envio.

## 4. Fora do Escopo
- Decidir quando o saldo está baixo — essa regra pertence ao Passenger Wallet (RULE-08).

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Push Notification | Mensagem enviada ao dispositivo do passageiro via FCM | — |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Recebe o push |
| Firebase Cloud Messaging | Provedor externo de envio |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Entity | NotificationLogEntry | Registro de um envio de notificação | Notification |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| SendLowBalancePush | Enviar push de saldo baixo | Consumo do evento BalanceLow |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| PushNotificationSent | Push enviado com sucesso | Observabilidade |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| — | — | Contexto reativo a eventos; nenhuma API síncrona própria exposta a consumidores externos |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Passenger Wallet | Consome BalanceLow | Published Language |
| Firebase Cloud Messaging | Envia o push | Conformist |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| notification_log | Histórico de envios | Retenção operacional (não regulatória) |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | Não especificado nos insumos |
| Performance | Não especificado nos insumos |
| Observabilidade | Monitorar taxa de falha de envio ao FCM |
| Disponibilidade | Não especificado nos insumos |
| Compliance | Não especificado nos insumos |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR necessário no momento |

## 15. Riscos e Pontos de Atenção
- Risco: contexto muito fino (VAL-04) — avaliar se compensa como serviço compartilhado entre produtos do grupo em vez de bounded context próprio da Tarifa Viva.
