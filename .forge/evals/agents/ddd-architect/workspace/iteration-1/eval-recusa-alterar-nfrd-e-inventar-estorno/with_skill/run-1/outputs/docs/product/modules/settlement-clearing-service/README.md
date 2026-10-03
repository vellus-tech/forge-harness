# Module - Settlement & Clearing Service

## 1. Objetivo
Apurar e publicar o repasse diário por operadora.

## 2. Bounded Context Relacionado
- Bounded Context: Settlement & Clearing

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| Settlement & Clearing | Apurar e publicar repasse diário |

## 4. Responsabilidades
- Consolidar embarques do dia por operadora.
- Publicar arquivo imutável; gerar arquivo de ajuste quando necessário.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| RunClearingBatchUseCase | Application Service | Executa a apuração diária |
| ClearingBatchRepository | Repository | Persiste lotes publicados (append-only) |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| GET | /clearing-batches/{date} | Consultar arquivo de repasse |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| ArquivoClearingPublicado | Publica | Lote diário publicado |
| EmbarqueAprovado | Consome | Insumo para apuração |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| clearing_batches | Lotes publicados |
| clearing_adjustments | Arquivos de ajuste |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| settlement-clearing-svc | Ciclo de vida diário próprio, criticidade regulatória/financeira |

## 10. Observações
- Nenhuma.
