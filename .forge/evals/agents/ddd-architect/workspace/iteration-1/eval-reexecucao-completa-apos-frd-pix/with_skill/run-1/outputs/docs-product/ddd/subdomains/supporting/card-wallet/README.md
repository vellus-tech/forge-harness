# Card Wallet

## 1. Classificação
- Tipo: Supporting Subdomain

## 2. Descrição
Gestão do saldo do cartão do passageiro e dos três canais de recarga: cartão de crédito no app (FR-04), ponto de venda credenciado em dinheiro (FR-05) e, desde o FRD v1.3, Pix via QR Code no app (FR-10). Inclui também o bloqueio de cartão (FR-06).

## 3. Justificativa da Classificação
Não é core (o produto não se diferencia por "ter carteira digital" — é o mesmo padrão de qualquer bilhetagem eletrônica), mas sustenta o Core Domain (Fare Validation depende do saldo estar correto). Complexidade de negócio moderada: múltiplos canais de crédito assíncronos, cada um com sua própria confirmação externa.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-03 | Card Wallet | Manter saldo e processar recargas por múltiplos canais |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| RechargeRequestedByApp | Passageiro iniciou recarga com cartão de crédito |
| RechargeApprovedByAcquirer | Adquirente aprovou a transação de crédito |
| RechargeRegisteredAtPOS | Ponto de venda registrou recarga em dinheiro |
| PixChargeGenerated | QR Code Pix foi gerado para o passageiro (FR-10) |
| PixSettlementConfirmed | PSP confirmou a liquidação do Pix via webhook (FR-10) |
| CardBalanceCredited | Saldo do cartão foi creditado, qualquer que seja o canal |
| CardBlocked | Cartão foi bloqueado por perda ou solicitação |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| FR-04 | Recarga por cartão de crédito só é creditada após aprovação antifraude do adquirente |
| FR-05 | Ponto de venda credenciado registra recarga em dinheiro |
| FR-06 | Bloqueio de cartão chega aos validadores só na próxima sincronização — saldo pode ser gasto no intervalo |
| FR-10 | Recarga via Pix é creditada quando o PSP confirma a liquidação via webhook |
| VAL-02 | Idempotência do webhook Pix não está especificada no FRD — ver `ddd-segmentation.md §11` |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Card Wallet | Mesmo contexto — todos os canais de recarga compartilham o mesmo agregado de saldo |

## 8. Pontos a Validar
- VAL-02: confirmar com o PSP se o webhook do Pix é reenviado em timeout e se carrega chave de idempotência própria.
