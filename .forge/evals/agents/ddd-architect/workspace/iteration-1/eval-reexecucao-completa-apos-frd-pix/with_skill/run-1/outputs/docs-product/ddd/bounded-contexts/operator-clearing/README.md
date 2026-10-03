# Bounded Context Canvas - Operator Clearing

## 1. Objetivo
Apurar diariamente o repasse financeiro a cada operadora, a partir dos embarques atribuídos às suas linhas, e publicar o arquivo de repasse.

## 2. Classificação DDD
- Tipo: Supporting Subdomain
- Justificativa: sustenta a operação financeira do consórcio, mas o padrão de clearing por lote diário não é diferenciador de produto.

## 3. Responsabilidades
- Atribuir cada embarque à operadora dona da linha.
- Gerar e publicar o arquivo de repasse diário.
- Emitir arquivo de ajuste quando houver correção após publicação (NFR-05).

## 4. Fora do Escopo
- Decidir o embarque em si (consome o evento de Fare Validation).
- Processar recarga ou saldo (Card Wallet).

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Clearing | Apuração e repasse financeiro periódico entre consórcio e operadoras | |
| Arquivo de ajuste | Arquivo emitido para corrigir um repasse já publicado, sem alterar o original | Original é imutável (NFR-05) |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Operadora | Recebe o arquivo de repasse |
| Órgão gestor | Audita os registros retidos por 5 anos |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | ClearingBatch | Lote diário de apuração por operadora | Operator Clearing |
| Entity | ClearingAdjustment | Ajuste sobre um lote já publicado | Operator Clearing |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| PublishDailyClearing | Fecha e publica o arquivo de repasse do dia | Sistema (job agendado) |
| IssueClearingAdjustment | Emite arquivo de ajuste | Gestor do consórcio |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| DailyClearingFilePublished | Arquivo diário publicado e tornado imutável | Operadora (integração externa) |
| ClearingAdjustmentFileIssued | Ajuste emitido | Operadora (integração externa) |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| GET | /clearing/files/{date} | Consultar arquivo de repasse de um dia |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Fare Validation | Consome BoardingApproved e FareIntegrationApplied | Customer/Supplier |
| Sistemas das operadoras | Recebe arquivo de repasse | Open Host Service |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| clearing_batches | Lotes diários publicados | 5 anos (NFR-04) |
| clearing_adjustments | Ajustes emitidos sobre lotes já publicados | 5 anos (NFR-04) |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | — |
| Performance | — |
| Observabilidade | — |
| Disponibilidade | — |
| Compliance | Arquivo imutável após publicado; correção só via arquivo de ajuste (NFR-05); retenção de 5 anos (NFR-04) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR registrado ainda |

## 15. Riscos e Pontos de Atenção
- Nenhum ponto novo identificado nesta execução (v1.1) — contexto inalterado pelo FRD v1.3.
