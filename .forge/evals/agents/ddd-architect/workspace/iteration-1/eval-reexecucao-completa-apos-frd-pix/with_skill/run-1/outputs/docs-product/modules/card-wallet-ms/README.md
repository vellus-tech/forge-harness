# Module - Card Wallet MS

## 1. Objetivo
Manter o saldo do cartão e processar recarga por cartão de crédito, ponto de venda e Pix, além de bloqueio de cartão.

## 2. Bounded Context Relacionado
- Bounded Context: Card Wallet

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| Consultar/creditar saldo | Fonte única da verdade do saldo |
| Recarregar por crédito | FR-04 |
| Recarregar por POS | FR-05 |
| Recarregar via Pix | FR-10 — novo na v1.1 |
| Bloquear cartão | FR-06 |

## 4. Responsabilidades
- Creditar saldo somente após confirmação externa (adquirente, POS ou PSP Pix).
- Garantir idempotência de crédito por tentativa de recarga, qualquer canal.
- Traduzir o webhook do PSP Pix para `PixSettlementConfirmed` via Anti-Corruption Layer.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| CreditBalanceUseCase | Application Service | Credita saldo a partir de qualquer canal confirmado |
| GeneratePixChargeUseCase | Application Service | Gera QR Code Pix (novo — FR-10) |
| ConfirmPixSettlementUseCase | Application Service | Processa webhook do PSP e credita saldo (novo — FR-10) |
| RequestAppRechargeUseCase | Application Service | Inicia recarga por cartão de crédito |
| RegisterPOSRechargeUseCase | Application Service | Registra recarga em dinheiro |
| BlockCardUseCase | Application Service | Bloqueia cartão |
| CardBalanceRepository | Repository | Persiste `CardBalance` |
| PixPSPAdapter | Adapter | Anti-Corruption Layer do webhook do PSP Pix (novo — FR-10) |
| AcquirerAdapter | Adapter | Anti-Corruption Layer do adquirente de crédito |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| GET | /cards/{id}/balance | Consultar saldo |
| POST | /recharges/app | Recarga por crédito |
| POST | /recharges/pos | Recarga por POS |
| POST | /recharges/pix/charges | Gerar QR Code Pix (novo — FR-10) |
| POST | /recharges/pix/webhook | Receber liquidação do PSP (novo — FR-10) |
| POST | /cards/{id}/block | Bloquear cartão |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| CardBalanceCredited | Publica | Saldo creditado por qualquer canal |
| PixChargeGenerated | Publica | QR Code Pix gerado (novo — FR-10) |
| PixSettlementConfirmed | Publica | Liquidação Pix confirmada (novo — FR-10) |
| CardBlocked | Publica | Cartão bloqueado |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| card_balances | Saldo atual |
| recharge_attempts | Histórico de tentativas de recarga (crédito/POS) |
| pix_charges | Cobranças Pix e seu status de liquidação (novo — FR-10) |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| card-wallet-ms | Ownership próprio de saldo, disponibilidade de 99,9% (NFR-02) e escopo PCI reduzido (NFR-03) justificam ciclo de release independente |

## 10. Observações
- VAL-02: o design de `ConfirmPixSettlementUseCase` deve ser idempotente por `charge_id` até que o contrato do PSP confirme reenvio de webhook.
