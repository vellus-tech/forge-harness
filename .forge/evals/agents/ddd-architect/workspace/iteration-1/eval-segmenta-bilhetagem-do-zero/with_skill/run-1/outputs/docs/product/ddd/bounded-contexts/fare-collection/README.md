# Bounded Context Canvas - Fare Collection

## 1. Objetivo
Decidir e registrar embarques do passageiro — checagem de blocklist e saldo, débito de tarifa (com integração tarifária quando aplicável) — inclusive quando o validador está offline, e sincronizar o lote com o backend quando reconectar.

## 2. Classificação DDD
- Tipo: Core Domain
- Justificativa: diferenciador direto do produto (OBJ-01), regra de negócio complexa e específica, risco operacional altíssimo, sem solução de prateleira.

## 3. Responsabilidades
- Receber e traduzir os lotes de sincronização do firmware ValidaBus (via Anti-Corruption Layer).
- Aplicar a política de tarifa vigente por linha, incluindo a integração tarifária temporal (RULE-03).
- Registrar cada embarque (aprovado ou rejeitado) como fato imutável.
- Publicar `FareCharged` / `BoardingRejected` para os contextos consumidores (Passenger Wallet, Settlement).
- Expor o histórico de viagens do passageiro (read model dos últimos 30 dias) para o app.

## 4. Fora do Escopo
- Manter o saldo autoritativo do passageiro — isso é do Passenger Wallet.
- Calcular o repasse por operadora — isso é do Settlement.
- A decisão de embarque em si, quando executada no firmware do validador, roda em software de terceiro (ValidaBus); este contexto modela apenas o que a Tarifa Viva controla: a política publicada ao validador e a ingestão do resultado sincronizado.

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Boarding (Embarque) | Ato de aproximar o cartão e receber a decisão de aprovação/rejeição | Nunca chamar de "validação" neste contexto — ver VAL-05 |
| Fare (Tarifa) | Valor cobrado por um embarque | Pode ser integral ou com desconto de integração |
| Transfer Discount (Integração Tarifária) | Desconto de 50% na segunda viagem em linha diferente dentro de 60 minutos | RULE-03 |
| Boarding Batch | Lote de até 5.000 embarques acumulados offline | FR-02 |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Aproxima o cartão para embarcar |
| Validador Embarcado (ValidaBus) | Executa a decisão local e envia o lote sincronizado |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | Boarding | Registro de um embarque com decisão e tarifa aplicada | Fare Collection |
| Value Object | Fare | Valor monetário da tarifa aplicada, em centavos | Fare Collection |
| Value Object | TariffRule | Regra de tarifa vigente por linha, incluindo integração temporal | Fare Collection |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| SyncBoardingBatch | Ingerir lote de embarques sincronizado pelo validador | Validador Embarcado (via ACL) |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| FareCharged | Embarque aprovado e tarifa debitada | Passenger Wallet, Settlement |
| BoardingRejected | Embarque negado (bloqueio ou saldo insuficiente) | Passenger Wallet (para métricas/auditoria) |
| BoardingBatchSynced | Lote sincronizado com sucesso | Observabilidade interna |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| /boardings/sync-batches | POST | Ingestão do lote sincronizado pelo validador (via ACL) |
| /boardings/history | GET | Histórico de viagens do passageiro (read model 30 dias) |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Firmware ValidaBus | Fornece decisões locais e lotes de sincronização | Anti-Corruption Layer |
| Passenger Wallet | Consome BlocklistSnapshot publicado pelo Wallet | Published Language / Read Model |
| Passenger Wallet | Publica FareCharged para reconciliação de saldo | Published Language |
| Settlement | Publica FareCharged como insumo de apuração | Published Language |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| boardings | Registro de cada embarque (aprovado/rejeitado) | 5 anos (NFR-04) |
| boarding_batches | Controle de lotes de sincronização recebidos | 5 anos |
| tariff_rules | Tarifa vigente por linha e regra de integração temporal | Vigência corrente + histórico |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | Isolar o domínio interno do protocolo proprietário do ValidaBus (ACL obrigatória) |
| Performance | Decisão local em até 300ms (fora do caminho crítico do backend); ingestão de lote assíncrona |
| Observabilidade | Rastrear taxa de rejeição e latência de sincronização de lote |
| Disponibilidade | Deve tolerar desconexão prolongada do validador sem perda de embarques (buffer de 5.000) |
| Compliance | Retenção de 5 anos (NFR-04) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR existente ainda; candidato: "ADR — Anti-Corruption Layer para protocolo ValidaBus" |

## 15. Riscos e Pontos de Atenção
- Risco: acoplamento acidental ao modelo de dados instável do ValidaBus se a ACL não for mantida rigorosamente isolada (TEC-03).
- Risco: divergência entre o saldo local decidido offline e o saldo autoritativo do Wallet — ver VAL-01.
- Atenção: o termo "validação" é usado no FRD tanto para este contexto (ato de embarque) quanto para o antifraude do Recharge — ver VAL-05 e o glossário.
