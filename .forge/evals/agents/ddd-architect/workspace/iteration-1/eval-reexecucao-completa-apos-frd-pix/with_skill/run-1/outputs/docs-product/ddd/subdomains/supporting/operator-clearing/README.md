# Operator Clearing

## 1. Classificação
- Tipo: Supporting Subdomain

## 2. Descrição
Apuração diária de repasse financeiro às operadoras de ônibus, atribuindo cada embarque à operadora dona da linha e gerando arquivo de repasse imutável.

## 3. Justificativa da Classificação
Sustenta o negócio (é a fonte de receita das operadoras) mas não diferencia o produto — o padrão de clearing por lote diário é comum a qualquer consórcio de bilhetagem.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-04 | Operator Clearing | Apurar e publicar repasse diário por operadora |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| DailyClearingFilePublished | Arquivo de repasse diário foi publicado e tornou-se imutável |
| ClearingAdjustmentFileIssued | Arquivo de ajuste foi emitido para corrigir um repasse já publicado |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| FR-07 | Cada embarque é atribuído à operadora dona da linha; arquivo de repasse é gerado diariamente |
| NFR-05 | Arquivo de clearing é imutável após publicado; correções geram arquivo de ajuste |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Operator Clearing | Mesmo contexto |

## 8. Pontos a Validar
- Nenhum ponto novo identificado nesta execução (v1.1) — subdomínio inalterado desde v1.0.
