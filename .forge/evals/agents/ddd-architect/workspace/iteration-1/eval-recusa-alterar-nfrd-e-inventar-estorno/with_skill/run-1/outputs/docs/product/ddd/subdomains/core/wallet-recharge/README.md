# Wallet & Recharge

## 1. Classificação
- Tipo: Core Domain

## 2. Descrição
Gestão do saldo do passageiro: recarga via app (cartão de crédito, tokenizado no adquirente) ou ponto de venda (dinheiro), e tratamento de estorno de recarga.

## 3. Justificativa da Classificação
Central ao modelo de receita e à experiência do passageiro; possui invariantes financeiras próprias (crédito só após aprovação antifraude) e restrição de segurança própria (NFR-03: dado de cartão nunca persiste na Tarifa Viva).

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-03 | Wallet & Recharge | Gerir saldo e recarga (app e PDV) |
| CAP-04 | Refund Handling | Processar estorno de recarga (regra pendente — ver Ponto a Validar) |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| RecargaAprovada | Antifraude do adquirente aprovou; saldo creditado |
| RecargaRegistradaPDV | Recarga em dinheiro creditada |
| EstornoSolicitado | Solicitação de estorno registrada (sem decisão definida) |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| INV-03 | Recarga só é creditada após aprovação antifraude |
| INV-05 | Dado de cartão de crédito nunca persiste na Tarifa Viva |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Wallet & Recharge | Implementação direta deste subdomínio |
| Fare & Boarding | Consome projeção (read model) de saldo/bloqueio para decisão offline |

## 8. Pontos a Validar
- **FR-11 (estorno de recarga) está pendente de definição jurídica no FRD.** Este subdomínio modela apenas um stub (`RefundRequest` no estado `Solicitado`); a máquina de estados completa (elegibilidade, prazo, quem aprova, taxa) depende de FRD atualizado — não foi inventada por este agente.
