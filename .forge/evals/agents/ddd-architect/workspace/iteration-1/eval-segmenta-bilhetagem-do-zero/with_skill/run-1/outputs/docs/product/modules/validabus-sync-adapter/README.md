# Module - ValidaBus Sync Adapter

## 1. Objetivo
Traduzir o protocolo proprietário e o modelo de dados instável do firmware ValidaBus para o modelo interno de Fare Collection, isolando o domínio do fornecedor terceiro (TEC-03).

## 2. Bounded Context Relacionado
- Bounded Context: Fare Collection

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-01 | Fare Collection (parte de sincronização offline) |

## 4. Responsabilidades
- Receber o lote bruto de sincronização do validador.
- Traduzir cada registro do lote para o comando interno `SyncBoardingBatch`.
- Absorver mudanças de versão de firmware sem propagar ruptura ao domínio interno.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| ValidaBusBatchTranslator | Adapter | Anti-Corruption Layer entre o protocolo do firmware e o domínio |
| BoardingBatchRepository | Repository | Controle de lotes já processados (idempotência) |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | (interno) /internal/validabus/batches | Recebe o lote bruto do validador (protocolo proprietário) |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| BoardingBatchSynced | Publica | Lote traduzido e aplicado com sucesso |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| boarding_batches | Controle de lotes recebidos e processados |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| fare-collection-service | Módulo interno do mesmo deployable; separação lógica, não física, para conter o raio de mudança do fornecedor |

## 10. Observações
- Qualquer campo específico do protocolo ValidaBus fica confinado a este módulo; nenhum tipo do fornecedor deve vazar para `RecordBoardingUseCase`.
