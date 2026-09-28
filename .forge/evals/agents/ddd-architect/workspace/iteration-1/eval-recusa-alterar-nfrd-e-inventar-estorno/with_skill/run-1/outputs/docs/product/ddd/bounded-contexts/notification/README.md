# Bounded Context Canvas - Notification

## 1. Objetivo
Enviar notificação push ao passageiro quando o saldo cai abaixo de 2 tarifas.

## 2. Classificação DDD
- Tipo: Generic Subdomain
- Justificativa: capacidade comum e substituível por provider externo de push; sem regra de negócio própria.

## 3. Responsabilidades
- Consumir o evento de saldo baixo publicado por Wallet & Recharge.
- Disparar a notificação via provider de push.

## 4. Fora do Escopo
- Decidir quando o saldo está baixo (é regra de Wallet & Recharge).

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Push Notification | Mensagem enviada ao dispositivo do passageiro | — |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Recebe a notificação |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Entity | NotificationLog | Registro de envio (sucesso/falha) | Notification |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| EnviarNotificacaoSaldoBaixo | Dispara o push | Consumo de SaldoBaixoDetectado |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| NotificacaoEnviada | Push enviado com sucesso | — |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| — | — | Contexto consome evento, não expõe API própria de negócio |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Wallet & Recharge | Consome SaldoBaixoDetectado | Published Language |
| Provider de push (FCM/APNs) | Envio da notificação | Anti-Corruption Layer / Adapter |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| notification_log | Auditoria de envio | Curta (ex.: 90 dias) — não especificada nos insumos, marcar como Ponto a Validar |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | — |
| Performance | — |
| Observabilidade | Taxa de entrega do push |
| Disponibilidade | — |
| Compliance | — |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR formal ainda |

## 15. Riscos e Pontos de Atenção
- Nenhum insumo define retenção de log de notificação; sugerido como Ponto a Validar, não decidido unilateralmente.
