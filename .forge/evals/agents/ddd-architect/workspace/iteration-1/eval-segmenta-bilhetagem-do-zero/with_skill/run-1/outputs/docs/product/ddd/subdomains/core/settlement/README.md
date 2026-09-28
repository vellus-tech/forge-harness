# Settlement

## 1. Classificação
- Tipo: Core Domain

## 2. Descrição
Apura diariamente a receita de cada operadora do consórcio a partir dos embarques cobrados, gera o arquivo de repasse e mantém a trilha auditável exigida por regulação, incluindo o tratamento de correções via arquivo de ajuste sem violar a imutabilidade do arquivo publicado.

## 3. Justificativa da Classificação
A atribuição de receita entre múltiplas operadoras de um mesmo consórcio, com imutabilidade pós-publicação e trilha auditável, é uma regra de negócio específica do modelo de consórcio de transporte público — não é um processo financeiro genérico, e falhas aqui têm impacto financeiro e regulatório direto.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-04 | Settlement | Apurar e publicar clearing diário por operadora |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| ClearingPublished | Arquivo de repasse diário publicado e imutável |
| ClearingAdjustmentIssued | Arquivo de ajuste emitido para corrigir um clearing já publicado |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| RULE-06 | Cada embarque é atribuído a exatamente uma operadora, dona da linha |
| RULE-07 | Arquivo de clearing publicado é imutável; correções exigem arquivo de ajuste separado |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Settlement | Contexto 1:1 com o subdomínio |

## 8. Pontos a Validar
- Nenhum ponto adicional além dos já consolidados em `docs/product/ddd/ddd-segmentation.md §5`
