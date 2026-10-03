# Bounded Context Canvas - Wallet & Recharge

## 1. Objetivo
Gerir o saldo do passageiro: recarga via app ou ponto de venda, débito autoritativo por embarque, notificação de saldo baixo e tratamento de estorno de recarga.

## 2. Classificação DDD
- Tipo: Core Domain
- Justificativa: central ao modelo de receita; invariantes financeiras e restrição de segurança próprias (NFR-02, NFR-03).

## 3. Responsabilidades
- Processar recarga via app (após aprovação antifraude do adquirente) e via ponto de venda.
- Manter o saldo autoritativo do cartão e aplicar débitos vindos de Fare & Boarding.
- Detectar saldo baixo e publicar evento para Notification.
- Registrar solicitação de estorno de recarga (stub — regra pendente).

## 4. Fora do Escopo
- Decisão de embarque e cache local de saldo (pertence a Fare & Boarding).
- Regra completa de elegibilidade/prazo de estorno (pendente de definição jurídica — não definida por este agente).
- Tokenização e antifraude de cartão de crédito (é do adquirente externo; dado de cartão nunca é armazenado aqui — NFR-03).

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Balance | Saldo disponível associado ao cartão | — |
| Recharge | Operação de crédito de saldo | — |
| RefundRequest | Solicitação de estorno de uma recarga | Regra de decisão TBD — ver Ponto a Validar |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Solicita recarga e, eventualmente, estorno |
| Ponto de venda credenciado | Registra recarga em dinheiro |
| Adquirente de cartão de crédito | Aprova/recusa antifraude da recarga via app |
| PSP de Pix | Meio de pagamento alternativo de recarga |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | Wallet | Saldo do cartão e histórico de movimentações | Wallet & Recharge |
| Aggregate | Recharge | Operação de crédito de saldo | Wallet & Recharge |
| Aggregate (stub) | RefundRequest | Solicitação de estorno; apenas estado `Solicitado` modelado | Wallet & Recharge |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| RecarregarPeloApp | Solicita recarga via cartão de crédito | Passageiro |
| RegistrarRecargaPDV | Registra recarga em dinheiro | Ponto de venda |
| SolicitarEstornoRecarga | Registra solicitação de estorno (sem decisão automática) | Passageiro |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| RecargaAprovada | Antifraude aprovou; saldo creditado | Notification (se aplicável) |
| RecargaRegistradaPDV | Recarga em dinheiro creditada | — |
| SaldoBaixoDetectado | Saldo cai abaixo de 2 tarifas | Notification |
| EstornoSolicitado | Solicitação de estorno registrada | Gestor do consórcio (fila manual, até FR-11 ser definido) |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| POST /recharges | POST | Solicitar recarga pelo app |
| POST /recharges/{id}/refund-requests | POST | Solicitar estorno (fica em `Solicitado`) |
| GET /wallets/{cardId}/balance-projection | GET | Projeção de saldo consumida por Fare & Boarding |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Fare & Boarding | Publica projeção de saldo; consome EmbarqueAprovado para débito autoritativo | Open Host Service / Published Language |
| Adquirente de cartão de crédito | Antifraude/tokenização de recarga | Anti-Corruption Layer (contrato externo instável não deve vazar para o modelo interno) |
| Notification | Publica SaldoBaixoDetectado | Published Language |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| wallets | Saldo atual por cartão | Enquanto o cartão estiver ativo |
| recharges | Histórico de recargas | 5 anos (NFR-04) — não alterado |
| refund_requests | Solicitações de estorno (stub) | A definir junto com a regra (VAL-02) |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | Dado de cartão de crédito nunca trafega/persiste aqui (NFR-03) |
| Performance | — |
| Observabilidade | Monitorar taxa de recusa antifraude |
| Disponibilidade | 99,9% de disponibilidade mensal para recarga (NFR-02) |
| Compliance | Retenção de 5 anos das recargas (NFR-04) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR formal ainda |

## 15. Riscos e Pontos de Atenção
- **FR-11 pendente:** `RefundRequest` não tem máquina de estados de decisão. Não implementar lógica de aprovação/reprovação automática até o FRD ser atualizado pelo dono do produto/jurídico.
- Anti-Corruption Layer com o adquirente deve isolar mudanças de contrato externo do modelo de `Recharge`.
