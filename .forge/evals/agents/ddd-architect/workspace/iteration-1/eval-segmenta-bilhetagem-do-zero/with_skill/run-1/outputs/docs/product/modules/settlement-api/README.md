# Module - Settlement API

## 1. Objetivo
Apurar o clearing diário por operadora e publicar o arquivo de repasse, incluindo ajustes.

## 2. Bounded Context Relacionado
- Bounded Context: Settlement

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-04 | Settlement |

## 4. Responsabilidades
- Consumir FareCharged e atribuir cada embarque à operadora dona da linha.
- Consolidar e publicar o clearing diário como imutável.
- Emitir arquivos de ajuste sem alterar o original.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| RunDailyClearingUseCase | Application Service | Executa a apuração diária |
| IssueClearingAdjustmentUseCase | Application Service | Emite ajuste sobre clearing publicado |
| ClearingBatchRepository | Repository | Persistência append-only de batches e ajustes |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| GET | /clearings/{date} | Consultar clearing publicado |
| POST | /clearings/{date}/adjustments | Emitir ajuste |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| FareCharged | Consome | Insumo da apuração |
| ClearingPublished | Publica | Arquivo de repasse publicado |
| ClearingAdjustmentIssued | Publica | Ajuste emitido |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| clearing_batches | Apuração diária consolidada |
| clearing_line_items | Atribuição embarque → operadora |
| clearing_adjustments | Histórico de ajustes |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| settlement-service | Criticidade financeira e regulatória própria; isolamento de auditoria |

## 10. Observações
- Modelo estritamente append-only: nenhuma operação de update sobre `clearing_batches` publicado (RULE-07).
