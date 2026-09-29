# Segmentação DDD — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-08-25 | Segmentação inicial a partir do FRD v1.2 |
| v1.1 | 2026-09-26 | Reexecução parcial após FRD v1.3 (FR-10, recarga via Pix): atualiza evidências do subdomínio Card Wallet e a justificativa de BC-02; demais subdomínios e bounded contexts não foram reavaliados nesta rodada |

## 1. Espaço do problema

### 1.2 Classificação de Subdomínios
| Capacidade | Classificação | Justificativa | Evidências | Pontos a Validar |
|---|---|---|---|---|
| Fare Validation | Core | Decisão de embarque offline com regras próprias | FR-01, FR-02, NFR-01 | |
| Fare Integration | Core | Integração temporal é regra diferenciadora do consórcio | FR-03 | |
| Card Wallet | Supporting | Saldo e recarga do cartão, agora por três canais (crédito, ponto de venda, Pix) | FR-04, FR-05, FR-06, FR-10 | VAL-02 |
| Operator Clearing | Supporting | Repasse diário às operadoras | FR-07, NFR-05 | |
| Notification | Generic | Push commodity via provedor | FR-08, TEC-04 | |
| Identity Access | Generic | Login e MFA | FR-09 | |

## 4. Espaço da solução

### 4.1 Bounded Context Candidates
| Código | Bounded Context | Subdomínio Relacionado | Decisão | Justificativa |
|---|---|---|---|---|
| BC-01 | Fare Validation | Fare Validation, Fare Integration | Confirmar | Linguagem de embarque e integração no mesmo ciclo de vida |
| BC-02 | Card Wallet | Card Wallet | Confirmar | Ownership do saldo e das recargas, incluindo a confirmação assíncrona via webhook do PSP Pix (FR-10) |
| ~~BC-03~~ | ~~Trip Reporting~~ | ~~—~~ | Removido na v1.0 | Virou read model do Operator Clearing |
| BC-04 | Operator Clearing | Operator Clearing | Confirmar | Arquivo de repasse imutável e ciclo diário próprio |
| BC-05 | Notification | Notification | Consolidar com outro contexto | Sem linguagem própria; adapter do Card Wallet |
| BC-06 | Identity Access | Identity Access | Confirmar | Credenciais e MFA com ownership próprio |

## 11. Pontos a Validar
| Código | Ponto | Motivo | Impacto |
|---|---|---|---|
| VAL-01 | Limite de 5.000 embarques offline | Fornecedor ValidaBus não confirmou | Dimensionamento do lote |
| VAL-02 | Idempotência e reconciliação do webhook Pix (FR-10) | FR-10 não especifica retry do PSP, janela de expiração do QR Code nem o que fazer se o webhook nunca chegar (recarga travada) | Consistência do saldo em Card Wallet; possível necessidade de um processo de conciliação periódica com o PSP |
