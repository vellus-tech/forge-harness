# Linguagem Ubíqua

## Visão Geral
Este documento consolida os termos de domínio por bounded context. Atualizado na v1.1 (2026-09-26) com os termos de Pix trazidos pelo FRD v1.3 (FR-10).

## Fare Validation
| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Embarque | Ato de "validação" no validador que debita a tarifa | Evitar "validação" isolado — é o embarque em si | |
| Integração temporal | Desconto de 50% na segunda viagem do mesmo cartão em até 60 minutos | | |

## Card Wallet
| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Recarga | Operação que credita saldo ao cartão, por qualquer canal | | |
| QR Code Pix | Código gerado pelo app para iniciar uma cobrança Pix | | Novo — FR-10 |
| PSP | Provedor de Serviços de Pagamento que processa o Pix | Payment Service Provider | Sigla expandida na primeira ocorrência — novo, FR-10 |
| Webhook de liquidação | Notificação HTTP assíncrona do PSP confirmando a liquidação do Pix | | Novo — FR-10. Evento externo, traduzido para `PixSettlementConfirmed` via Anti-Corruption Layer |

## Operator Clearing
| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| Clearing | Apuração e repasse financeiro periódico entre consórcio e operadoras | | |
| Arquivo de ajuste | Arquivo emitido para corrigir um repasse já publicado, sem alterar o original | | |

## Identity Access
| Termo | Definição | Sinônimos/Evitar | Observações |
|---|---|---|---|
| MFA | Autenticação multifator | Multi-Factor Authentication | Sigla expandida na primeira ocorrência |
