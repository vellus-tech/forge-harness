# Linguagem Ubíqua

## Visão Geral
Este documento consolida os termos de domínio por bounded context. Termos gerais, comuns a todos os contextos, ficam em `docs/product/glossary/domain-glossary.md`.

## Alerta de ambiguidade — "validação" (VAL-05)

O FRD usa a palavra "validação" com dois significados diferentes:

- Em **Fare Collection**, "validação" (FR-01) é o próprio ato de embarque — o termo canônico deste documento é **Boarding (Embarque)**, nunca "validação".
- Em **Recharge**, "validação" (FR-04) é a checagem antifraude executada pelo adquirente externo — o termo canônico é **Fraud Check (Checagem Antifraude)**.

Nenhum código, evento ou API deve usar "Validate"/"Validation" de forma genérica — sempre o termo específico do contexto (`RecordBoarding` vs. `FraudCheck`).

## Fare Collection

| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Boarding (Embarque) | Ato de aproximar o cartão do validador e receber a decisão de aprovação/rejeição | Evitar "validação" | Termo canônico do FR-01 |
| Fare (Tarifa) | Valor cobrado por um embarque | — | Pode ser integral ou com desconto |
| Transfer Discount (Integração Tarifária) | Desconto de 50% aplicado à segunda viagem em linha diferente dentro de 60 minutos | Integração | RULE-03 |
| Boarding Batch (Lote de Embarque) | Conjunto de até 5.000 embarques acumulados offline até a sincronização | — | FR-02 |
| Route (Linha) | Rota operada por uma operadora específica | — | Determina a operadora dona do embarque |

## Passenger Wallet

| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Wallet (Carteira) | Agregado que representa saldo e estado de bloqueio de um cartão | Conta — evitar, pois "conta" pertence a Identity and Access | — |
| Balance (Saldo) | Crédito disponível do passageiro | — | Ver VAL-01 sobre janela offline |
| Blocklist Snapshot | Fotografia periódica de saldo/blocklist publicada para consumo offline | — | Não é fonte autoritativa em tempo real |
| Card (Cartão) | Meio físico ou virtual de acesso ao saldo | — | Distinto de Passenger Account (Identity and Access) |

## Recharge

| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Recharge Request (Solicitação de Recarga) | Pedido de recarga via app ou ponto de venda | — | — |
| Fraud Check (Checagem Antifraude) | Validação de risco executada pelo adquirente sobre a transação de cartão | Evitar "validação" isolada | Ver alerta de ambiguidade acima |

## Settlement

| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Clearing Batch (Apuração) | Consolidação diária da receita por operadora | Repasse | — |
| Clearing Line Item | Atribuição de um embarque específico a uma operadora | — | — |
| Clearing Adjustment (Arquivo de Ajuste) | Correção de um clearing já publicado, sem sobrescrevê-lo | — | RULE-07 |

## Identity and Access

| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Passenger Account (Conta do Passageiro) | Credencial de acesso do passageiro ao app | — | Distinto de Card (meio de embarque) |

## Notification

| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Push Notification | Mensagem enviada ao dispositivo do passageiro via FCM | — | — |
