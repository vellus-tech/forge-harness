# Bounded Context Canvas - Card Wallet

## 1. Objetivo
Manter o saldo do cartão do passageiro e processar recargas por três canais — cartão de crédito no app, ponto de venda credenciado e Pix — além do bloqueio de cartão.

## 2. Classificação DDD
- Tipo: Supporting Subdomain
- Justificativa: sustenta o Core Domain (Fare Validation depende do saldo), mas não diferencia o produto.

## 3. Responsabilidades
- Manter o saldo do cartão como fonte única da verdade.
- Processar recarga por cartão de crédito, condicionada à aprovação antifraude do adquirente (FR-04).
- Processar recarga em dinheiro registrada por ponto de venda (FR-05).
- Processar recarga via Pix, condicionada à confirmação de liquidação pelo PSP via webhook (FR-10).
- Bloquear cartão por perda ou solicitação (FR-06).

## 4. Fora do Escopo
- Decidir embarque (pertence a Fare Validation — Card Wallet apenas expõe consulta de saldo).
- Tokenizar ou armazenar dados de cartão de crédito (fica no adquirente — NFR-03 mantém a Tarifa Viva fora do escopo PCI DSS relevante).
- Processar a liquidação bancária do Pix em si (é responsabilidade do PSP; Card Wallet apenas consome o resultado via webhook).

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Recarga | Operação que credita saldo ao cartão, por qualquer canal | |
| QR Code Pix | Código gerado pelo app para iniciar uma cobrança Pix (FR-10) | Termo técnico — manter em inglês/Pix conforme uso de mercado |
| PSP | Provedor de Serviços de Pagamento que processa o Pix e envia o webhook de liquidação | Sigla expandida na primeira ocorrência |
| Webhook de liquidação | Notificação HTTP assíncrona do PSP confirmando que o Pix foi liquidado | Evento externo, não evento de domínio interno |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Solicita recarga por qualquer canal |
| Ponto de venda credenciado | Registra recarga em dinheiro |
| Adquirente (cartão de crédito) | Aprova/reprova a transação de crédito |
| PSP Pix | Confirma a liquidação do Pix via webhook |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | CardBalance | Saldo do cartão e seu histórico de créditos/débitos | Card Wallet |
| Entity | RechargeAttempt | Uma tentativa de recarga por qualquer canal, com seu status | Card Wallet |
| Entity | PixCharge | Uma cobrança Pix gerada (QR Code) até sua confirmação ou expiração | Card Wallet |
| Value Object | Money | Valor monetário com moeda | Card Wallet |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| RequestAppRecharge | Inicia recarga por cartão de crédito | Passageiro |
| RegisterPOSRecharge | Registra recarga em dinheiro | Ponto de venda |
| GeneratePixCharge | Gera QR Code Pix para recarga | Passageiro |
| ConfirmPixSettlement | Processa a confirmação de liquidação recebida do PSP | PSP (webhook) |
| BlockCard | Bloqueia o cartão | Passageiro/Gestor |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| RechargeApprovedByAcquirer | Adquirente aprova a transação de crédito | Card Wallet (crédito de saldo) |
| RechargeRegisteredAtPOS | Ponto de venda confirma recarga em dinheiro | Card Wallet (crédito de saldo) |
| PixChargeGenerated | QR Code Pix foi gerado | — |
| PixSettlementConfirmed | PSP confirma liquidação via webhook (FR-10) | Card Wallet (crédito de saldo) |
| CardBalanceCredited | Saldo foi creditado, qualquer canal | Fare Validation (consulta), Notification |
| CardBlocked | Cartão foi bloqueado | Fare Validation (sincronização de bloqueio) |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| GET | /cards/{id}/balance | Consultar saldo |
| POST | /recharges/app | Iniciar recarga por cartão de crédito |
| POST | /recharges/pos | Registrar recarga em ponto de venda |
| POST | /recharges/pix/charges | Gerar QR Code Pix |
| POST | /recharges/pix/webhook | Receber confirmação de liquidação do PSP (endpoint de Anti-Corruption Layer) |
| POST | /cards/{id}/block | Bloquear cartão |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Adquirente de cartão de crédito | Recebe aprovação/reprovação | Anti-Corruption Layer |
| PSP Pix | Recebe webhook de liquidação | Anti-Corruption Layer (o payload do PSP não deve vazar para o modelo interno — traduzir para `PixSettlementConfirmed`) |
| Fare Validation | Expõe saldo para consulta na decisão de embarque | Customer/Supplier |
| Notification | Publica saldo baixo | Published Language |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| card_balances | Saldo atual por cartão | Enquanto o cartão estiver ativo |
| recharge_attempts | Histórico de tentativas de recarga (crédito e POS) | 5 anos (NFR-04) |
| pix_charges | Cobranças Pix geradas e seu status de liquidação | 5 anos (NFR-04) |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | Dados de cartão de crédito nunca trafegam nem são armazenados (NFR-03) |
| Performance | Recarga pelo app com 99,9% de disponibilidade mensal (NFR-02) |
| Observabilidade | Webhook Pix precisa de log de correlação — ver VAL-02 sobre idempotência |
| Disponibilidade | 99,9% mensal (NFR-02) |
| Compliance | Retenção de 5 anos para auditoria (NFR-04) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR registrado ainda — recomenda-se um ADR para o padrão Anti-Corruption Layer do webhook Pix quando VAL-02 for resolvido |

## 15. Riscos e Pontos de Atenção
- VAL-02: idempotência do webhook Pix não especificada no FRD v1.3 — risco de crédito duplicado se o PSP reenviar o webhook.
- Três canais de recarga assíncronos (crédito, POS, Pix) compartilham o mesmo agregado `CardBalance` — todo crédito precisa passar pela mesma invariante de não-duplicação, independentemente do canal.
