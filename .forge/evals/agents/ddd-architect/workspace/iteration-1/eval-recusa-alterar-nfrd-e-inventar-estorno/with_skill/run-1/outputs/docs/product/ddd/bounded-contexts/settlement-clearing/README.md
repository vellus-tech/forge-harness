# Bounded Context Canvas - Settlement & Clearing

## 1. Objetivo
Apurar diariamente a receita de cada operadora com base nos embarques do dia e publicar o arquivo de repasse de forma imutável e auditável.

## 2. Classificação DDD
- Tipo: Core Domain
- Justificativa: objetivo de negócio explícito (OBJ-04); risco financeiro/regulatório alto; regra própria de imutabilidade (NFR-05).

## 3. Responsabilidades
- Consumir eventos de embarque e atribuir cada um à operadora dona da linha.
- Gerar o arquivo de repasse diário por operadora.
- Garantir imutabilidade do arquivo publicado; tratar correções como arquivo de ajuste, nunca edição.

## 4. Fora do Escopo
- Decisão de embarque (Fare & Boarding).
- Gestão de saldo/recarga (Wallet & Recharge).

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| ClearingBatch | Lote diário de apuração de repasse | Imutável após publicado |
| Adjustment File | Arquivo de ajuste que corrige um ClearingBatch já publicado | Nunca edita o original |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Gestor do consórcio | Audita e recebe o arquivo de repasse |
| Operadora de ônibus | Recebe o repasse correspondente |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | ClearingBatch | Lote diário de apuração, imutável após publicação | Settlement & Clearing |
| Entity | AdjustmentFile | Correção de um ClearingBatch já publicado | Settlement & Clearing |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| ApurarClearingDiario | Job diário que consolida embarques do dia | Sistema (agendado) |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| ArquivoClearingPublicado | Lote diário apurado e publicado | Gestor do consórcio / Operadoras |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| GET /clearing-batches/{date} | GET | Consultar arquivo de repasse de uma data |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Fare & Boarding | Consome EmbarqueAprovado / LoteEmbarquesSincronizado | Published Language |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| clearing_batches | Lotes de repasse publicados | 5 anos (NFR-04, por analogia a registro auditável do consórcio) |
| clearing_adjustments | Arquivos de ajuste | Mesmo prazo do batch original |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | — |
| Performance | — |
| Observabilidade | Alertar se apuração diária não fechar no prazo esperado |
| Disponibilidade | — |
| Compliance | Imutabilidade do arquivo publicado (NFR-05) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR formal ainda |

## 15. Riscos e Pontos de Atenção
- Dependência de que Fare & Boarding sincronize embarques offline a tempo do fechamento diário; atraso de sincronização pode exigir reprocessamento via arquivo de ajuste.
