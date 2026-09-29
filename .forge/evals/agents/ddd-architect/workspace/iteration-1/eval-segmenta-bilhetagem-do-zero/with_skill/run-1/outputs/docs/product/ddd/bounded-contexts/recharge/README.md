# Bounded Context Canvas - Recharge

## 1. Objetivo
Capturar a intenção de recarga do passageiro pelos canais app (cartão de crédito, com antifraude do adquirente) e ponto de venda credenciado (dinheiro), e publicar o crédito aprovado para o Passenger Wallet.

## 2. Classificação DDD
- Tipo: Supporting Subdomain
- Justificativa: necessário para alimentar o saldo, mas a diferenciação do produto está no embarque e na integração tarifária, não na captura de recarga.

## 3. Responsabilidades
- Orquestrar a solicitação de recarga via app, delegando antifraude/tokenização ao adquirente (RULE-04, RULE-09).
- Registrar recargas em dinheiro feitas em ponto de venda credenciado.
- Publicar `RechargeApproved` / `RechargeRejected`.

## 4. Fora do Escopo
- Armazenar ou processar dados de cartão de crédito (PAN) — nunca trafega nem é armazenado aqui (RULE-09).
- Manter o saldo em si — isso é do Passenger Wallet.

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Recharge Request | Solicitação de recarga, via app ou POS | — |
| Antifraude (Fraud Check) | Validação de risco executada pelo adquirente sobre a transação de cartão | Distinto de "Boarding" em Fare Collection — ver VAL-05 |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Solicita recarga pelo app |
| Ponto de Venda Credenciado | Registra recarga em dinheiro |
| Adquirente de Cartão de Crédito | Processa antifraude e tokenização (externo) |
| PSP de Pix | Processa recarga via Pix (Ponto a Validar VAL-03) |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | RechargeRequest | Solicitação de recarga com seu status (pendente/aprovada/reprovada) | Recharge |
| Value Object | Money | Valor monetário em centavos | Recharge |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| RequestAppRecharge | Solicitar recarga via cartão de crédito no app | Passageiro |
| RegisterPosRecharge | Registrar recarga em dinheiro | Ponto de Venda Credenciado |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| RechargeApproved | Recarga aprovada (antifraude ou POS) | Passenger Wallet |
| RechargeRejected | Antifraude reprovou a transação | Notificação ao passageiro (fora do escopo deste contexto) |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| /recharges/app | POST | Solicitar recarga via app |
| /recharges/pos | POST | Registrar recarga via ponto de venda |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Adquirente de Cartão de Crédito | Antifraude e tokenização | Anti-Corruption Layer |
| PSP de Pix | Processamento de recarga via Pix | Anti-Corruption Layer (Ponto a Validar VAL-03) |
| Ponto de Venda Credenciado | Registro de recarga em dinheiro | Open Host Service (consumido pelo POS) |
| Passenger Wallet | Publica RechargeApproved | Customer/Supplier (Recharge é upstream) |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| recharge_requests | Solicitações de recarga e seu status | 5 anos (NFR-04) |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | Nunca armazenar nem transmitir PAN (NFR-03); escopo PCI DSS reduzido via tokenização no adquirente |
| Performance | Depende da latência do adquirente para antifraude (fora do controle direto) |
| Observabilidade | Monitorar taxa de reprovação por antifraude |
| Disponibilidade | 99,9% mensal (NFR-02) |
| Compliance | Retenção de 5 anos (NFR-04); escopo PCI reduzido (NFR-03) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Candidato: "ADR — Escopo PCI DSS reduzido via tokenização no adquirente" |

## 15. Riscos e Pontos de Atenção
- Risco: se a integração com PSP de Pix (VAL-03) não for confirmada, este contexto tem apenas dois canais reais (app-cartão e POS), não três.
- Atenção: nunca reutilizar o termo "validação" deste contexto para descrever o embarque de Fare Collection (VAL-05).
