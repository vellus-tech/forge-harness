# Linguagem Ubíqua

## Visão Geral
Este documento consolida os termos de domínio por bounded context da Tarifa Viva.

## Fare & Boarding
| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Boarding | Registro de um embarque decidido pelo validador | Evitar "validação" isolado (ambíguo com FR-01) | — |
| Fare | Valor cobrado por linha, sujeito à integração temporal | Tarifa | — |
| Integração tarifária | Desconto de 50% para 2ª viagem em <60 min no mesmo cartão | Integração temporal | — |

## Wallet & Recharge
| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Wallet | Saldo do cartão e seu histórico de movimentações | Carteira | — |
| Recharge | Operação de crédito de saldo (app ou PDV) | Recarga | — |
| RefundRequest | Solicitação de estorno de uma recarga | Estorno | Regra de decisão ainda não definida (FR-11 pendente) — não confundir com "Estorno" já concedido, que este domínio ainda não modela |

## Settlement & Clearing
| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| ClearingBatch | Lote diário de apuração de repasse por operadora | Clearing, Repasse | Imutável após publicado |
| AdjustmentFile | Arquivo de ajuste que corrige um ClearingBatch já publicado | — | Nunca edita o batch original |

## Card & Identity
| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Card | Cartão físico ou virtual associado a um passageiro | Cartão | — |
| Block List | Lista de cartões bloqueados | Lista de bloqueio | Propagada por sincronização, não em tempo real |

## Notification
| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Push Notification | Mensagem enviada ao dispositivo do passageiro | Notificação | — |

## Termos ambíguos entre contextos (Ponto a Validar)
| Termo | Contexto A | Contexto B | Observação |
|---|---|---|---|
| "Validação" | FR-01 usa "validação" para a decisão de embarque | FR-04 usa "validação" para a aprovação antifraude da recarga | Mesmo termo do FRD original com dois significados; preservado como está no FRD (este agente não altera FRD), mas a linguagem ubíqua de cada BC usa "Boarding Decision" e "Antifraud Approval" respectivamente para não propagar a ambiguidade na modelagem |
