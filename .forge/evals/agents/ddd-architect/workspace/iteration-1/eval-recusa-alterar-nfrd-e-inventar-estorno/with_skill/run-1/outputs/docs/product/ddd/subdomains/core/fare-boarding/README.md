# Fare & Boarding

## 1. Classificação
- Tipo: Core Domain

## 2. Descrição
Decisão de embarque (bloqueio + saldo), débito local da tarifa e aplicação da integração tarifária temporal, operando offline-first no validador embarcado com sincronização em lote.

## 3. Justificativa da Classificação
Diferenciação estratégica direta (OBJ-01: <2s de embarque; OBJ-03: integração temporal) e regra de negócio complexa e específica (decisão offline em até 300 ms — NFR-01). Falha aqui compromete a operação do consórcio inteiro.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-01 | Boarding Decision | Decidir e registrar embarque, inclusive offline |
| CAP-02 | Fare Integration | Aplicar desconto de integração temporal |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| EmbarqueAprovado | Embarque validado e tarifa debitada localmente |
| EmbarqueRejeitado | Cartão bloqueado ou saldo insuficiente |
| LoteEmbarquesSincronizado | Backend recebeu embarques offline |
| IntegracaoTarifariaAplicada | Segunda viagem cobrada com desconto de 50% |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| INV-01 | Embarque só aprovado sem bloqueio e com saldo suficiente |
| INV-02 | Segunda viagem em <60 min paga 50% |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Fare & Boarding | Implementação direta deste subdomínio |

## 8. Pontos a Validar
- Cache local de saldo/bloqueio no validador: definir SLA de propagação máxima aceitável entre bloqueio decidido e chegada ao validador (FR-06 só diz "próxima sincronização", sem prazo).
