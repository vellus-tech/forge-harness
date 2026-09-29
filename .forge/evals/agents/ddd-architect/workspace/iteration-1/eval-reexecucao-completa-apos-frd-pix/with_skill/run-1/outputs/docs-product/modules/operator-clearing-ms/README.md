# Module - Operator Clearing MS

## 1. Objetivo
Apurar e publicar o repasse financeiro diário por operadora.

## 2. Bounded Context Relacionado
- Bounded Context: Operator Clearing

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| Apurar clearing diário | FR-07 |

## 4. Responsabilidades
- Consumir eventos de embarque e atribuir à operadora dona da linha.
- Publicar arquivo diário imutável; emitir arquivo de ajuste quando necessário (NFR-05).

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| PublishDailyClearingUseCase | Application Service | Fecha e publica o lote diário |
| IssueClearingAdjustmentUseCase | Application Service | Emite arquivo de ajuste |
| ClearingBatchRepository | Repository | Persiste `ClearingBatch` |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| GET | /clearing/files/{date} | Consultar arquivo do dia |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| BoardingApproved | Consome | Origem do embarque para atribuir à operadora |
| DailyClearingFilePublished | Publica | Arquivo publicado |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| clearing_batches | Lotes diários publicados |
| clearing_adjustments | Ajustes sobre lotes publicados |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| operator-clearing-ms | Requisito de imutabilidade e auditoria (NFR-05) pede ciclo de release e controle de acesso próprios |

## 10. Observações
- Nenhuma mudança nesta execução (v1.1) — módulo inalterado pelo FRD v1.3.
