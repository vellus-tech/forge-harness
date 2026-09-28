# Module - Payment Provider Adapters

## 1. Objetivo
Isolar o domínio de Recharge dos contratos externos do adquirente de cartão de crédito e do PSP de Pix.

## 2. Bounded Context Relacionado
- Bounded Context: Recharge

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-03 | Recharge (parte de integração externa) |

## 4. Responsabilidades
- Traduzir a chamada de antifraude/tokenização do adquirente para o modelo interno.
- Traduzir a chamada de pagamento via Pix do PSP externo (Ponto a Validar VAL-03).

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| AcquirerFraudCheckAdapter | Adapter | Anti-Corruption Layer para o adquirente de cartão |
| PixPaymentAdapter | Adapter | Anti-Corruption Layer para o PSP de Pix |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| — | — | Módulo interno, sem API pública própria |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| — | — | Módulo síncrono; resultado retorna ao Recharge API, que publica os eventos de domínio |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| — | Nenhum dado próprio; nunca persiste PAN (NFR-03) |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| recharge-service | Módulo interno do mesmo deployable, separado logicamente para conter o raio de mudança de contratos externos |

## 10. Observações
- Confirmar VAL-03 antes de investir na implementação do PixPaymentAdapter.
