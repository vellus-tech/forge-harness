# Bounded Context Canvas - Settlement

## 1. Objetivo
Apurar diariamente a receita de cada operadora a partir dos embarques cobrados, publicar o arquivo de repasse imutável e tratar correções por meio de arquivos de ajuste.

## 2. Classificação DDD
- Tipo: Core Domain
- Justificativa: atribuição de receita multi-operadora com imutabilidade e trilha auditável é regra específica do modelo de consórcio.

## 3. Responsabilidades
- Consumir `FareCharged` e atribuir cada embarque à operadora dona da linha (RULE-06).
- Consolidar o batch diário de clearing por operadora.
- Publicar o arquivo de repasse como imutável (RULE-07).
- Emitir arquivos de ajuste quando houver correção pós-publicação, sem alterar o arquivo original.

## 4. Fora do Escopo
- Decidir ou registrar o embarque em si — isso é do Fare Collection.
- Processar pagamento às operadoras (transferência bancária efetiva) — fora do escopo descrito nos insumos; tratado como saída de arquivo consumido externamente.

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Clearing Batch | Apuração diária consolidada por operadora | — |
| Clearing Line Item | Atribuição de um embarque específico a uma operadora dentro do batch | — |
| Clearing Adjustment | Arquivo de ajuste que corrige um clearing já publicado, sem sobrescrevê-lo | RULE-07 |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Gestor do Consórcio | Aciona/acompanha a apuração e emite ajustes |
| Operadora de Ônibus | Consome o arquivo de repasse gerado |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | ClearingBatch | Apuração diária consolidada | Settlement |
| Entity | ClearingLineItem | Atribuição de um embarque a uma operadora | Settlement |
| Value Object | Money | Valor monetário em centavos | Settlement |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| RunDailyClearing | Executar a apuração do dia | Scheduler / Gestor |
| IssueClearingAdjustment | Emitir arquivo de ajuste para um clearing já publicado | Gestor |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| ClearingPublished | Arquivo de repasse diário publicado | Operadoras (via arquivo/API) |
| ClearingAdjustmentIssued | Ajuste emitido | Operadoras, auditoria |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| /clearings/{date} | GET | Consultar o clearing publicado de uma data |
| /clearings/{date}/adjustments | POST | Emitir ajuste sobre um clearing publicado |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Fare Collection | Consome FareCharged como insumo de apuração | Published Language |
| Operadoras (sistemas externos) | Consomem o arquivo de repasse | Open Host Service |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| clearing_batches | Apuração diária consolidada | 5 anos (NFR-04) |
| clearing_line_items | Atribuição embarque → operadora | 5 anos |
| clearing_adjustments | Histórico de ajustes emitidos | 5 anos |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | Acesso de escrita restrito ao processo de apuração; nenhuma escrita manual direta |
| Performance | Processamento em lote diário, fora do caminho crítico de embarque |
| Observabilidade | Alertar sobre embarques sem operadora atribuível |
| Disponibilidade | Deve concluir a apuração diária dentro da janela operacional do consórcio |
| Compliance | Imutabilidade pós-publicação (NFR-05) e retenção de 5 anos (NFR-04) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Candidato: "ADR — Modelo append-only para clearing e ajustes" |

## 15. Riscos e Pontos de Atenção
- Risco: embarque sem linha/operadora identificável (dado inconsistente vindo de Fare Collection) bloqueia a apuração — precisa de fila de exceção.
- Atenção: nunca modelar `IssueClearingAdjustment` como update do batch original — sempre um novo registro (RULE-07).
